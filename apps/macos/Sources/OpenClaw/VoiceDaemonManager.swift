import Foundation
import OSLog

@MainActor
final class VoiceDaemonManager {
    static let shared = VoiceDaemonManager()

    enum Status: Equatable {
        case stopped
        case starting
        case running(details: String?)
        case failed(String)
    }

    private(set) var status: Status = .stopped
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let logger = Logger(subsystem: "ai.openclaw", category: "voice-daemon")

    func startIfNeeded() {
        if case .running = self.status { return }
        if case .starting = self.status { return }
        self.status = .starting
        Task { await self.startAsync() }
    }

    func start() {
        self.status = .starting
        Task { await self.startAsync() }
    }

    private func startAsync() async {
        self.stopProcess()

        guard let entry = await self.resolveEntrypoint() else {
            self.status = .failed("voice daemon entrypoint missing")
            self.logger.error("voice daemon start failed: entrypoint missing")
            return
        }

        guard let bunPath = await self.ensureBunInstalled() else {
            self.status = .failed("bun not available")
            self.logger.error("voice daemon start failed: bun not available")
            return
        }

        let workDir = entry.workDir
        let bunDir = (bunPath as NSString).deletingLastPathComponent

        if entry.installable,
           !(await self.ensureDependencies(workDir: workDir, bunPath: bunPath, bunDir: bunDir))
        {
            self.status = .failed("voice daemon deps missing")
            self.logger.error("voice daemon start failed: deps missing")
            return
        }

        let cmd = [bunPath, "run", entry.scriptPath]
        let env = await self.buildEnvironment(bunDir: bunDir)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = cmd
        process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                if proc.terminationStatus == 0 {
                    self.status = .stopped
                } else {
                    self.status = .failed("exit \(proc.terminationStatus)")
                }
                self.logger.error("voice daemon exited code=\(proc.terminationStatus)")
            }
        }

        do {
            try process.run()
            self.process = process
            self.status = .running(details: "pid \(process.processIdentifier)")
            self.logger.info("voice daemon started pid=\(process.processIdentifier)")
        } catch {
            self.status = .failed("failed to start")
            self.logger.error("voice daemon start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        self.stopProcess()
        self.status = .stopped
    }

    private func stopProcess() {
        self.process?.terminate()
        self.process = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil
    }

    private func resolveEntrypoint() async -> (scriptPath: String, workDir: String, installable: Bool)? {
        if let bundledRoot = self.bundleEntrypointRoot() {
            if let prepared = await self.prepareWorkingCopy(from: bundledRoot) {
                return (scriptPath: prepared.scriptPath, workDir: prepared.workDir, installable: true)
            }
        }
        #if DEBUG
        let projectRoot = CommandResolver.projectRoot()
        let pkgRoot = projectRoot.appendingPathComponent("apps/voice-video-daemon")
        let script = pkgRoot.appendingPathComponent("src/server.ts")
        if FileManager.default.isReadableFile(atPath: script.path) {
            return (scriptPath: "src/server.ts", workDir: pkgRoot.path, installable: false)
        }
        #endif
        return nil
    }

    private func bundleEntrypointRoot() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let root = resources.appendingPathComponent("voice-daemon")
        let script = root.appendingPathComponent("src/server.ts")
        guard FileManager.default.isReadableFile(atPath: script.path) else { return nil }
        return root
    }

    private func prepareWorkingCopy(from sourceRoot: URL) async -> (scriptPath: String, workDir: String)? {
        let targetRoot = OpenClawPaths.stateDirURL.appendingPathComponent("voice-daemon", isDirectory: true)
        let marker = targetRoot.appendingPathComponent(".version")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let needsCopy = !FileManager.default.fileExists(atPath: targetRoot.path)
            || !FileManager.default.fileExists(atPath: marker.path)
            || (try? String(contentsOf: marker))?.trimmingCharacters(in: .whitespacesAndNewlines) != version

        if needsCopy {
            do {
                if FileManager.default.fileExists(atPath: targetRoot.path) {
                    try FileManager.default.removeItem(at: targetRoot)
                }
                try FileManager.default.createDirectory(
                    at: OpenClawPaths.stateDirURL,
                    withIntermediateDirectories: true,
                    attributes: nil)
                try FileManager.default.copyItem(at: sourceRoot, to: targetRoot)
                try version.write(to: marker, atomically: true, encoding: .utf8)
            } catch {
                self.logger.error("voice daemon copy failed: \(error.localizedDescription)")
                return nil
            }
        }

        let script = targetRoot.appendingPathComponent("src/server.ts")
        guard FileManager.default.isReadableFile(atPath: script.path) else { return nil }
        return (scriptPath: "src/server.ts", workDir: targetRoot.path)
    }

    private func ensureBunInstalled() async -> String? {
        if let bun = CommandResolver.findExecutable(
            named: "bun",
            searchPaths: CommandResolver.preferredPaths())
        {
            return bun
        }
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".bun/bin/bun")
        if FileManager.default.isExecutableFile(atPath: defaultPath.path) {
            return defaultPath.path
        }

        self.logger.info("bun missing; attempting install")
        let install = await ShellExecutor.runDetailed(
            command: ["/bin/bash", "-lc", "curl -fsSL https://bun.sh/install | bash"],
            cwd: nil,
            env: ProcessInfo.processInfo.environment,
            timeout: 900)
        if install.success,
           FileManager.default.isExecutableFile(atPath: defaultPath.path)
        {
            return defaultPath.path
        }

        self.logger.error("bun install failed: \(install.errorMessage ?? "unknown")")
        return CommandResolver.findExecutable(
            named: "bun",
            searchPaths: CommandResolver.preferredPaths())
    }

    private func ensureDependencies(workDir: String, bunPath: String, bunDir: String) async -> Bool {
        let nodeModules = URL(fileURLWithPath: workDir).appendingPathComponent("node_modules")
        let opus = nodeModules.appendingPathComponent("@discordjs/opus")
        if FileManager.default.fileExists(atPath: opus.path) {
            return true
        }

        self.logger.info("voice daemon deps missing; installing")
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ([bunDir] + CommandResolver.preferredPaths()).joined(separator: ":")
        let install = await ShellExecutor.runDetailed(
            command: [bunPath, "install"],
            cwd: workDir,
            env: env,
            timeout: 900)
        if install.success {
            return FileManager.default.fileExists(atPath: opus.path)
        }
        self.logger.error("voice daemon deps install failed: \(install.errorMessage ?? "unknown")")
        return false
    }

    private func buildEnvironment(bunDir: String) async -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ([bunDir] + CommandResolver.preferredPaths()).joined(separator: ":")
        env["MYCAT_USE_GATEWAY"] = "1"
        if let config = try? await GatewayEndpointStore.shared.requireConfig() {
            let url = self.toWebSocketURL(config.url)
            env["MYCAT_GATEWAY_URL"] = url.absoluteString
            if let token = config.token { env["MYCAT_GATEWAY_TOKEN"] = token }
            if let password = config.password { env["MYCAT_GATEWAY_PASSWORD"] = password }
        }
        return env
    }

    private func toWebSocketURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        if components.scheme == "https" { components.scheme = "wss" }
        if components.scheme == "http" { components.scheme = "ws" }
        return components.url ?? url
    }
}

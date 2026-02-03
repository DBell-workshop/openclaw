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

        guard let bunPath = CommandResolver.findExecutable(
            named: "bun",
            searchPaths: CommandResolver.preferredPaths())
        else {
            self.status = .failed("bun not found in PATH")
            self.logger.error("voice daemon start failed: bun not found")
            return
        }

        guard let entry = self.resolveEntrypoint() else {
            self.status = .failed("voice daemon entrypoint missing")
            self.logger.error("voice daemon start failed: entrypoint missing")
            return
        }

        let workDir = entry.workDir
        let cmd = [bunPath, "run", entry.scriptPath]
        let env = await self.buildEnvironment()

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

    private func resolveEntrypoint() -> (scriptPath: String, workDir: String)? {
        if let bundled = self.bundleEntrypoint() {
            return bundled
        }
        let projectRoot = CommandResolver.projectRoot()
        let pkgRoot = projectRoot.appendingPathComponent("apps/voice-video-daemon")
        let script = pkgRoot.appendingPathComponent("src/server.ts")
        if FileManager.default.isReadableFile(atPath: script.path) {
            return (scriptPath: "src/server.ts", workDir: pkgRoot.path)
        }
        return nil
    }

    private func bundleEntrypoint() -> (scriptPath: String, workDir: String)? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let root = resources.appendingPathComponent("voice-daemon")
        let script = root.appendingPathComponent("src/server.ts")
        guard FileManager.default.isReadableFile(atPath: script.path) else { return nil }
        return (scriptPath: "src/server.ts", workDir: root.path)
    }

    private func buildEnvironment() async -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = CommandResolver.preferredPaths().joined(separator: ":")
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

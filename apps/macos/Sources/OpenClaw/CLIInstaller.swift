import Foundation

@MainActor
enum CLIInstaller {
    private struct InstallResult {
        let message: String
    }

    private static var inFlightInstall: Task<InstallResult, Never>?

    static func installedLocation() -> String? {
        self.installedLocation(
            searchPaths: CommandResolver.preferredPaths(),
            fileManager: .default)
    }

    static func installedLocation(
        searchPaths: [String],
        fileManager: FileManager) -> String?
    {
        for basePath in searchPaths {
            let candidate = URL(fileURLWithPath: basePath).appendingPathComponent("openclaw").path
            var isDirectory: ObjCBool = false

            guard fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                continue
            }

            guard fileManager.isExecutableFile(atPath: candidate) else { continue }

            return candidate
        }

        return nil
    }

    static func isInstalled() -> Bool {
        self.installedLocation() != nil
    }

    static func install(statusHandler: @escaping @MainActor @Sendable (String) async -> Void) async {
        let expected = GatewayEnvironment.expectedGatewayVersionString() ?? "latest"
        let prefix = Self.installPrefix()
        await statusHandler("Installing openclaw CLI…")

        if let existing = self.inFlightInstall {
            let result = await existing.value
            await statusHandler(result.message)
            return
        }

        let task = Task { await self.performInstall(version: expected, prefix: prefix) }
        self.inFlightInstall = task
        let result = await task.value
        self.inFlightInstall = nil
        await statusHandler(result.message)
    }

    private static func installPrefix() -> String {
        FileManager().homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .path
    }

    private static func performInstall(version: String, prefix: String) async -> InstallResult {
        var response = await self.runInstallScript(version: version, prefix: prefix)
        if !response.success, self.shouldRetryInstall(response) {
            _ = await ShellExecutor.runDetailed(
                command: self.cleanupBrokenInstallCommand(prefix: prefix),
                cwd: nil,
                env: nil,
                timeout: 60)
            response = await self.runInstallScript(version: version, prefix: prefix)
        }
        return self.mapInstallResult(response)
    }

    private static func runInstallScript(version: String, prefix: String) async -> ShellExecutor.ShellResult {
        let cmd = self.installScriptCommand(version: version, prefix: prefix)
        return await ShellExecutor.runDetailed(command: cmd, cwd: nil, env: nil, timeout: 900)
    }

    private static func mapInstallResult(_ response: ShellExecutor.ShellResult) -> InstallResult {
        if response.success {
            let parsed = self.parseInstallEvents(response.stdout)
            let installedVersion = parsed.last { $0.event == "done" }?.version
            let summary = installedVersion.map { "Installed openclaw \($0)." } ?? "Installed openclaw."
            return InstallResult(message: summary)
        }

        let parsed = self.parseInstallEvents(response.stdout)
        if let error = parsed.last(where: { $0.event == "error" })?.message {
            return InstallResult(message: "Install failed: \(error)")
        }

        let detail = response.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = response.errorMessage ?? "install failed"
        return InstallResult(message: "Install failed: \(detail.isEmpty ? fallback : detail)")
    }

    private static func shouldRetryInstall(_ response: ShellExecutor.ShellResult) -> Bool {
        let combined = "\(response.stdout)\n\(response.stderr)\n\(response.errorMessage ?? "")"
            .lowercased()
        if combined.contains("eexist"),
           combined.contains("/bin/openclaw")
        {
            return true
        }
        if combined.contains("enoent"),
           combined.contains("node_modules/openclaw/package.json")
        {
            return true
        }
        return false
    }

    private static func installScriptCommand(version: String, prefix: String) -> [String] {
        let escapedVersion = self.shellEscape(version)
        let escapedPrefix = self.shellEscape(prefix)
        let script = """
        prefix=\(escapedPrefix)
        mkdir -p "$prefix/bin" "$prefix/lib/node_modules"
        rm -f "$prefix/bin/openclaw"
        if [ -d "$prefix/lib/node_modules/openclaw" ] && [ ! -f "$prefix/lib/node_modules/openclaw/package.json" ]; then
          rm -rf "$prefix/lib/node_modules/openclaw"
        fi
        curl -fsSL https://openclaw.bot/install-cli.sh | \
        bash -s -- --json --no-onboard --prefix "$prefix" --version \(escapedVersion)
        """
        return ["/bin/bash", "-lc", script]
    }

    private static func cleanupBrokenInstallCommand(prefix: String) -> [String] {
        let escapedPrefix = self.shellEscape(prefix)
        let script = """
        prefix=\(escapedPrefix)
        mkdir -p "$prefix/bin" "$prefix/lib/node_modules"
        rm -f "$prefix/bin/openclaw"
        if [ -d "$prefix/lib/node_modules/openclaw" ] && [ ! -f "$prefix/lib/node_modules/openclaw/package.json" ]; then
          rm -rf "$prefix/lib/node_modules/openclaw"
        fi
        """
        return ["/bin/bash", "-lc", script]
    }

    private static func parseInstallEvents(_ output: String) -> [InstallEvent] {
        let decoder = JSONDecoder()
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
        var events: [InstallEvent] = []
        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }
            if let event = try? decoder.decode(InstallEvent.self, from: data) {
                events.append(event)
            }
        }
        return events
    }

    private static func shellEscape(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

private struct InstallEvent: Decodable {
    let event: String
    let version: String?
    let message: String?
}

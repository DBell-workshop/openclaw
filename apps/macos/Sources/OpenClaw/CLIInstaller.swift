import Foundation

@MainActor
enum CLIInstaller {
    private struct InstallResult {
        let message: String
    }

    private struct InstallAttempt {
        let version: String
        let cleanupBeforeInstall: Bool
    }

    private static let installScriptURL = "https://openclaw.ai/install-cli.sh"
    private static let installFallbackVersion = "latest"
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
        let normalized = self.normalizeVersion(version)
        let attempts = self.installAttempts(primaryVersion: normalized)

        var lastResponse: ShellExecutor.ShellResult?
        for attempt in attempts {
            if attempt.cleanupBeforeInstall {
                _ = await ShellExecutor.runDetailed(
                    command: self.cleanupBrokenInstallCommand(prefix: prefix),
                    cwd: nil,
                    env: nil,
                    timeout: 60)
            }

            let response = await self.runInstallScript(version: attempt.version, prefix: prefix)
            if response.success {
                return self.mapInstallResult(response)
            }

            lastResponse = response
            if !self.shouldRetryInstall(response), attempt.version == self.installFallbackVersion {
                break
            }
        }

        if let lastResponse {
            return self.mapInstallResult(lastResponse)
        }
        return InstallResult(message: "Install failed: unknown error")
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
        let combined = self.combinedInstallOutput(response)
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
        if combined.contains("enotempty"),
           combined.contains("node_modules/openclaw")
        {
            return true
        }
        if combined.contains("command sh -c node scripts/postinstall.js"),
           combined.contains("enoent")
        {
            return true
        }
        return false
    }

    private static func installScriptCommand(version: String, prefix: String) -> [String] {
        let escapedVersion = self.shellEscape(version)
        let escapedPrefix = self.shellEscape(prefix)
        let escapedScriptURL = self.shellEscape(self.installScriptURL)
        let script = """
        prefix=\(escapedPrefix)
        mkdir -p "$prefix/bin" "$prefix/lib/node_modules"
        rm -f "$prefix/bin/openclaw"
        if [ -d "$prefix/lib/node_modules/openclaw" ] && [ ! -f "$prefix/lib/node_modules/openclaw/package.json" ]; then
          rm -rf "$prefix/lib/node_modules/openclaw"
        fi
        curl -fsSL \(escapedScriptURL) | \
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
        rm -rf "$prefix/lib/node_modules/openclaw"
        """
        return ["/bin/bash", "-lc", script]
    }

    private static func normalizeVersion(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? self.installFallbackVersion : trimmed
    }

    private static func installAttempts(primaryVersion: String) -> [InstallAttempt] {
        if primaryVersion == self.installFallbackVersion {
            return [
                InstallAttempt(version: primaryVersion, cleanupBeforeInstall: false),
                InstallAttempt(version: primaryVersion, cleanupBeforeInstall: true),
            ]
        }
        return [
            InstallAttempt(version: primaryVersion, cleanupBeforeInstall: false),
            InstallAttempt(version: primaryVersion, cleanupBeforeInstall: true),
            InstallAttempt(version: self.installFallbackVersion, cleanupBeforeInstall: true),
        ]
    }

    private static func combinedInstallOutput(_ response: ShellExecutor.ShellResult) -> String {
        "\(response.stdout)\n\(response.stderr)\n\(response.errorMessage ?? "")"
            .lowercased()
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

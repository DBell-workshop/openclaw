import AppKit
import OpenClawChatUI
import OpenClawDiscovery
import OpenClawIPC
import SwiftUI

extension OnboardingView {
    @ViewBuilder
    func pageView(for pageIndex: Int) -> some View {
        switch pageIndex {
        case 0:
            self.welcomePage()
        case 1:
            self.connectionPage()
        case 2:
            self.anthropicAuthPage()
        case 3:
            self.wizardPage()
        case 5:
            self.permissionsPage()
        case 6:
            self.cliPage()
        case 8:
            self.onboardingChatPage()
        case 9:
            self.readyPage()
        default:
            EmptyView()
        }
    }

    func welcomePage() -> some View {
        self.onboardingPage {
            VStack(spacing: 22) {
                Text(self.t(.welcomeTitle))
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(self.t(.welcomeSubtitle))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 560)
                    .fixedSize(horizontal: false, vertical: true)

                self.onboardingCard(spacing: 12, padding: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color(nsColor: .systemOrange))
                            .frame(width: 22)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(self.t(.securityNoticeTitle))
                                .font(.title3.weight(.semibold))
                            Text(self.t(.securityNoticeBody))
                                .font(.body)
                                .lineSpacing(2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: 520)

                VStack(spacing: 8) {
                    Text(self.t(.legalAgreementPrefix))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button(self.t(.termsOfService)) {
                            self.presentedLegalDocument = .terms
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Text(self.t(.legalConnector))
                            .foregroundStyle(.secondary)

                        Button(self.t(.privacyPolicy)) {
                            self.presentedLegalDocument = .privacy
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
            }
            .padding(.top, 16)
        }
    }

    func connectionPage() -> some View {
        self.onboardingPage {
            Text(self.t(.chooseGatewayTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.chooseGatewaySubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingCard(spacing: 12, padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    let localSubtitle: String = {
                        guard let probe = self.localGatewayProbe else {
                            return self.t(.thisMacSubtitleDefault)
                        }
                        let base = probe.expected
                            ? self.t(.localGatewayDetected)
                            : self.tf(.portInUse, probe.port)
                        let command = probe.command.isEmpty ? "" : " (\(probe.command) pid \(probe.pid))"
                        return "\(base)\(command). \(self.t(.willAttach))"
                    }()
                    self.connectionChoiceButton(
                        title: self.t(.thisMacTitle),
                        subtitle: localSubtitle,
                        selected: self.state.connectionMode == .local)
                    {
                        self.selectLocalGateway()
                    }

                    Divider().padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(self.gatewayDiscovery.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if self.gatewayDiscovery.gateways.isEmpty {
                            ProgressView().controlSize(.small)
                            Button(self.t(.refresh)) {
                                self.gatewayDiscovery.refreshWideAreaFallbackNow(timeoutSeconds: 5.0)
                            }
                            .buttonStyle(.link)
                            .help(self.t(.refreshDiscoveryHelp))
                        }
                        Spacer(minLength: 0)
                    }

                    if self.gatewayDiscovery.gateways.isEmpty {
                        Text(self.t(.searchingGateways))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(self.t(.nearbyGateways))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            ForEach(self.gatewayDiscovery.gateways.prefix(6)) { gateway in
                                self.connectionChoiceButton(
                                    title: gateway.displayName,
                                    subtitle: self.gatewaySubtitle(for: gateway),
                                    selected: self.isSelectedGateway(gateway))
                                {
                                    self.selectRemoteGateway(gateway)
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor)))
                    }

                    self.connectionChoiceButton(
                        title: self.t(.configureLater),
                        subtitle: self.t(.configureLaterSubtitle),
                        selected: self.state.connectionMode == .unconfigured)
                    {
                        self.selectUnconfiguredGateway()
                    }

                    Button(self.showAdvancedConnection ? self.t(.hideAdvanced) : self.t(.advanced)) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            self.showAdvancedConnection.toggle()
                        }
                        if self.showAdvancedConnection, self.state.connectionMode != .remote {
                            self.state.connectionMode = .remote
                        }
                    }
                    .buttonStyle(.link)

                    if self.showAdvancedConnection {
                        let labelWidth: CGFloat = 110
                        let fieldWidth: CGFloat = 320

                        VStack(alignment: .leading, spacing: 10) {
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                                GridRow {
                                    Text(self.t(.transport))
                                        .font(.callout.weight(.semibold))
                                        .frame(width: labelWidth, alignment: .leading)
                                    Picker(self.t(.transport), selection: self.$state.remoteTransport) {
                                        Text(self.t(.sshTunnel)).tag(AppState.RemoteTransport.ssh)
                                        Text(self.t(.directWs)).tag(AppState.RemoteTransport.direct)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: fieldWidth)
                                }
                                if self.state.remoteTransport == .direct {
                                    GridRow {
                                        Text(self.t(.gatewayUrl))
                                            .font(.callout.weight(.semibold))
                                            .frame(width: labelWidth, alignment: .leading)
                                        TextField("wss://gateway.example.ts.net", text: self.$state.remoteUrl)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: fieldWidth)
                                    }
                                }
                                if self.state.remoteTransport == .ssh {
                                    GridRow {
                                        Text(self.t(.sshTarget))
                                            .font(.callout.weight(.semibold))
                                            .frame(width: labelWidth, alignment: .leading)
                                        TextField("user@host[:port]", text: self.$state.remoteTarget)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: fieldWidth)
                                    }
                                    if let message = CommandResolver
                                        .sshTargetValidationMessage(self.state.remoteTarget)
                                    {
                                        GridRow {
                                            Text("")
                                                .frame(width: labelWidth, alignment: .leading)
                                            Text(message)
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                                .frame(width: fieldWidth, alignment: .leading)
                                        }
                                    }
                                    GridRow {
                                        Text(self.t(.identityFile))
                                            .font(.callout.weight(.semibold))
                                            .frame(width: labelWidth, alignment: .leading)
                                        TextField("/Users/you/.ssh/id_ed25519", text: self.$state.remoteIdentity)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: fieldWidth)
                                    }
                                    GridRow {
                                        Text(self.t(.projectRoot))
                                            .font(.callout.weight(.semibold))
                                            .frame(width: labelWidth, alignment: .leading)
                                        TextField("/home/you/Projects/openclaw", text: self.$state.remoteProjectRoot)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: fieldWidth)
                                    }
                                    GridRow {
                                        Text(self.t(.cliPath))
                                            .font(.callout.weight(.semibold))
                                            .frame(width: labelWidth, alignment: .leading)
                                        TextField(
                                            "/Applications/MyCatCat.app/.../openclaw",
                                            text: self.$state.remoteCliPath)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: fieldWidth)
                                    }
                                }
                            }

                            Text(self.state.remoteTransport == .direct
                                ? self.t(.directTip)
                                : self.t(.sshTip))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    func gatewaySubtitle(for gateway: GatewayDiscoveryModel.DiscoveredGateway) -> String? {
        if self.state.remoteTransport == .direct {
            return GatewayDiscoveryHelpers.directUrl(for: gateway) ?? self.t(.gatewayPairingOnly)
        }
        if let host = GatewayDiscoveryHelpers.sanitizedTailnetHost(gateway.tailnetDns) ?? gateway.lanHost {
            let portSuffix = gateway.sshPort != 22 ? " · ssh \(gateway.sshPort)" : ""
            return "\(host)\(portSuffix)"
        }
        return self.t(.gatewayPairingOnly)
    }

    func isSelectedGateway(_ gateway: GatewayDiscoveryModel.DiscoveredGateway) -> Bool {
        guard self.state.connectionMode == .remote else { return false }
        let preferred = self.preferredGatewayID ?? GatewayDiscoveryPreferences.preferredStableID()
        return preferred == gateway.stableID
    }

    func connectionChoiceButton(
        title: String,
        subtitle: String?,
        selected: Bool,
        action: @escaping () -> Void) -> some View
    {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                action()
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        selected ? Color.accentColor.opacity(0.45) : Color.clear,
                        lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    func anthropicAuthPage() -> some View {
        self.onboardingPage {
            Text("Connect Claude")
                .font(.largeTitle.weight(.semibold))
            Text("Give your model the token it needs!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .fixedSize(horizontal: false, vertical: true)
            Text("OpenClaw supports any model — we strongly recommend Opus 4.5 for the best experience.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingCard(spacing: 12, padding: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(self.anthropicAuthVerified ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(
                        self.anthropicAuthConnected
                            ? (self.anthropicAuthVerified
                                ? "Claude connected (OAuth) — verified"
                                : "Claude connected (OAuth)")
                            : "Not connected yet")
                        .font(.headline)
                    Spacer()
                }

                if self.anthropicAuthConnected, self.anthropicAuthVerifying {
                    Text("Verifying OAuth…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !self.anthropicAuthConnected {
                    Text(self.anthropicAuthDetectedStatus.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if self.anthropicAuthVerified, let date = self.anthropicAuthVerifiedAt {
                    Text("Detected working OAuth (\(date.formatted(date: .abbreviated, time: .shortened))).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(
                    "This lets OpenClaw use Claude immediately. Credentials are stored at " +
                        "`~/.openclaw/credentials/oauth.json` (owner-only).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Text(OpenClawOAuthStore.oauthURL().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([OpenClawOAuthStore.oauthURL()])
                    }
                    .buttonStyle(.bordered)

                    Button("Refresh") {
                        self.refreshAnthropicOAuthStatus()
                    }
                    .buttonStyle(.bordered)
                }

                Divider().padding(.vertical, 2)

                HStack(spacing: 12) {
                    if !self.anthropicAuthVerified {
                        if self.anthropicAuthConnected {
                            Button("Verify") {
                                Task { await self.verifyAnthropicOAuthIfNeeded(force: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.anthropicAuthBusy || self.anthropicAuthVerifying)

                            if self.anthropicAuthVerificationFailed {
                                Button("Re-auth (OAuth)") {
                                    self.startAnthropicOAuth()
                                }
                                .buttonStyle(.bordered)
                                .disabled(self.anthropicAuthBusy || self.anthropicAuthVerifying)
                            }
                        } else {
                            Button {
                                self.startAnthropicOAuth()
                            } label: {
                                if self.anthropicAuthBusy {
                                    ProgressView()
                                } else {
                                    Text("Open Claude sign-in (OAuth)")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.anthropicAuthBusy)
                        }
                    }
                }

                if !self.anthropicAuthVerified, self.anthropicAuthPKCE != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste the `code#state` value")
                            .font(.headline)
                        TextField("code#state", text: self.$anthropicAuthCode)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Auto-detect from clipboard", isOn: self.$anthropicAuthAutoDetectClipboard)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .disabled(self.anthropicAuthBusy)

                        Toggle("Auto-connect when detected", isOn: self.$anthropicAuthAutoConnectClipboard)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .disabled(self.anthropicAuthBusy)

                        Button("Connect") {
                            Task { await self.finishAnthropicOAuth() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            self.anthropicAuthBusy ||
                                self.anthropicAuthCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .onReceive(Self.clipboardPoll) { _ in
                        self.pollAnthropicClipboardIfNeeded()
                    }
                }

                self.onboardingCard(spacing: 8, padding: 12) {
                    Text("API key (advanced)")
                        .font(.headline)
                    Text(
                        "You can also use an Anthropic API key, but this UI is instructions-only for now " +
                            "(GUI apps don’t automatically inherit your shell env vars like `ANTHROPIC_API_KEY`).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .shadow(color: .clear, radius: 0)
                .background(Color.clear)

                if let status = self.anthropicAuthStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task { await self.verifyAnthropicOAuthIfNeeded() }
    }

    func permissionsPage() -> some View {
        self.onboardingPage {
            Text(self.t(.grantPermissionsTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.grantPermissionsSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingCard(spacing: 8, padding: 12) {
                ForEach(Capability.allCases, id: \.self) { cap in
                    PermissionRow(
                        capability: cap,
                        status: self.permissionMonitor.status[cap] ?? false,
                        compact: true)
                    {
                        Task { await self.request(cap) }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await self.refreshPerms() }
                    } label: {
                        Label(self.t(.refresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(self.t(.refreshStatusHelp))
                    if self.isRequesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    func cliPage() -> some View {
        self.onboardingPage {
            Text(self.t(.installCliTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.installCliSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingCard(spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        Task { await self.installCLI() }
                    } label: {
                        let title = self.cliInstalled ? self.t(.reinstallCli) : self.t(.installCli)
                        ZStack {
                            Text(title)
                                .opacity(self.installingCLI ? 0 : 1)
                            if self.installingCLI {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.installingCLI)

                    Button(self.copied ? self.t(.copied) : self.t(.copyInstallCommand)) {
                        self.copyToPasteboard(self.devLinkCommand)
                    }
                    .disabled(self.installingCLI)

                    if self.cliInstalled, let loc = self.cliInstallLocation {
                        Label(self.tf(.installedAt, loc), systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                if let cliStatus {
                    Text(cliStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !self.cliInstalled, self.cliInstallLocation == nil {
                    Text(self.t(.cliInstallNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func workspacePage() -> some View {
        self.onboardingPage {
            Text(self.t(.workspaceTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.workspaceSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingCard(spacing: 10) {
                if self.state.connectionMode == .remote {
                    Text("Remote gateway detected")
                        .font(.headline)
                    Text(
                        "Create the workspace on the remote host (SSH in first). " +
                            "The macOS app can’t write files on your gateway over SSH yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(self.copied ? "Copied" : "Copy setup command") {
                        self.copyToPasteboard(self.workspaceBootstrapCommand)
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workspace folder")
                            .font(.headline)
                        TextField(
                            AgentWorkspace.displayPath(for: OpenClawConfigFile.defaultWorkspaceURL()),
                            text: self.$workspacePath)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 12) {
                            Button {
                                Task { await self.applyWorkspace() }
                            } label: {
                                if self.workspaceApplying {
                                    ProgressView()
                                } else {
                                    Text("Create workspace")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.workspaceApplying)

                            Button("Open folder") {
                                let url = AgentWorkspace.resolveWorkspaceURL(from: self.workspacePath)
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.bordered)
                            .disabled(self.workspaceApplying)

                            Button("Save in config") {
                                Task {
                                    let url = AgentWorkspace.resolveWorkspaceURL(from: self.workspacePath)
                                    let saved = await self.saveAgentWorkspace(AgentWorkspace.displayPath(for: url))
                                    if saved {
                                        self.workspaceStatus =
                                            "Saved to ~/.openclaw/openclaw.json (agents.defaults.workspace)"
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(self.workspaceApplying)
                        }
                    }

                    if let workspaceStatus {
                        Text(workspaceStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(self.t(.workspaceTip))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    func onboardingChatPage() -> some View {
        VStack(spacing: 16) {
            Text(self.t(.meetAgentTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.meetAgentSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingGlassCard(padding: 8) {
                OpenClawChatView(viewModel: self.onboardingChatModel, style: .onboarding)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 28)
        .frame(width: self.pageWidth, height: self.contentHeight, alignment: .top)
    }

    func readyPage() -> some View {
        self.onboardingPage {
            Text(self.t(.allSetTitle))
                .font(.largeTitle.weight(.semibold))
            self.onboardingCard {
                if self.state.connectionMode == .unconfigured {
                    self.featureRow(
                        title: self.t(.configureLaterReadyTitle),
                        subtitle: self.t(.configureLaterReadySubtitle),
                        systemImage: "gearshape")
                    Divider()
                        .padding(.vertical, 6)
                }
                if self.state.connectionMode == .remote {
                    self.featureRow(
                        title: self.t(.remoteChecklistTitle),
                        subtitle: self.t(.remoteChecklistSubtitle),
                        systemImage: "network")
                    Divider()
                        .padding(.vertical, 6)
                }
                self.featureRow(
                    title: self.t(.openMenuBarTitle),
                    subtitle: self.t(.openMenuBarSubtitle),
                    systemImage: "bubble.left.and.bubble.right")
                self.featureActionRow(
                    title: self.t(.connectChannelsTitle),
                    subtitle: self.t(.connectChannelsSubtitle),
                    systemImage: "link",
                    buttonTitle: self.t(.openSettingsChannels))
                {
                    self.openSettings(tab: .channels)
                }
                self.featureRow(
                    title: self.t(.tryVoiceWakeTitle),
                    subtitle: self.t(.tryVoiceWakeSubtitle),
                    systemImage: "waveform.circle")
                self.featureRow(
                    title: self.t(.panelCanvasTitle),
                    subtitle: self.t(.panelCanvasSubtitle),
                    systemImage: "rectangle.inset.filled.and.person.filled")
                self.featureActionRow(
                    title: self.t(.morePowersTitle),
                    subtitle: self.t(.morePowersSubtitle),
                    systemImage: "sparkles",
                    buttonTitle: self.t(.openSettingsSkills))
                {
                    self.openSettings(tab: .skills)
                }
                self.skillsOverview
                Toggle(self.t(.launchAtLogin), isOn: self.$state.launchAtLogin)
                    .onChange(of: self.state.launchAtLogin) { _, newValue in
                        AppStateStore.updateLaunchAtLogin(enabled: newValue)
                    }
            }
        }
        .task { await self.maybeLoadOnboardingSkills() }
    }

    private func maybeLoadOnboardingSkills() async {
        guard !self.didLoadOnboardingSkills else { return }
        self.didLoadOnboardingSkills = true
        await self.onboardingSkillsModel.refresh()
    }

    private var skillsOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 6)

            HStack(spacing: 10) {
                Text(self.t(.skillsIncluded))
                    .font(.headline)
                Spacer(minLength: 0)
                if self.onboardingSkillsModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(self.t(.refresh)) {
                        Task { await self.onboardingSkillsModel.refresh() }
                    }
                    .buttonStyle(.link)
                }
            }

            if let error = self.onboardingSkillsModel.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.t(.couldntLoadSkillsTitle))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(self.t(.couldntLoadSkillsBody))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(self.tf(.detailsPrefix, String(describing: error)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if self.onboardingSkillsModel.skills.isEmpty {
                Text(self.t(.noSkillsYet))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(self.onboardingSkillsModel.skills) { skill in
                            HStack(alignment: .top, spacing: 10) {
                                Text(skill.emoji ?? "✨")
                                    .font(.callout)
                                    .frame(width: 22, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.name)
                                        .font(.callout.weight(.semibold))
                                    Text(skill.description)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor)))
                }
                .frame(maxHeight: 160)
            }
        }
    }
}

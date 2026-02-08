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
        case 7:
            self.voiceAssistantPage()
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
                    .font(.largeTitle.weight(.semibold))
                Text(self.t(.welcomeSubtitle))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 560)
                    .fixedSize(horizontal: false, vertical: true)

                self.onboardingCard(spacing: 10, padding: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(nsColor: .systemOrange))
                            .frame(width: 22)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(self.t(.securityNoticeTitle))
                                .font(.headline)
                            Text(self.t(.securityNoticeBody))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: 520)
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
                                    if let message = CommandResolver.sshTargetValidationMessage(self.state.remoteTarget) {
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
            Text(self.t(.connectClaudeTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.connectClaudeSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
                .fixedSize(horizontal: false, vertical: true)
            Text(self.t(.connectClaudeSupportNote))
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
                                ? self.t(.claudeConnectedVerified)
                                : self.t(.claudeConnected))
                            : self.t(.notConnectedYet))
                        .font(.headline)
                    Spacer()
                }

                if self.anthropicAuthConnected, self.anthropicAuthVerifying {
                    Text(self.t(.verifyingOAuth))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !self.anthropicAuthConnected {
                    Text(self.anthropicAuthDetectedStatus.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if self.anthropicAuthVerified, let date = self.anthropicAuthVerifiedAt {
                    Text(self.tf(.detectedWorkingOAuth, date.formatted(date: .abbreviated, time: .shortened)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(self.t(.oauthStorageNote))
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

                    Button(self.t(.reveal)) {
                        NSWorkspace.shared.activateFileViewerSelecting([OpenClawOAuthStore.oauthURL()])
                    }
                    .buttonStyle(.bordered)

                    Button(self.t(.refresh)) {
                        self.refreshAnthropicOAuthStatus()
                    }
                    .buttonStyle(.bordered)
                }

                Divider().padding(.vertical, 2)

                HStack(spacing: 12) {
                    if !self.anthropicAuthVerified {
                        if self.anthropicAuthConnected {
                            Button(self.t(.verify)) {
                                Task { await self.verifyAnthropicOAuthIfNeeded(force: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.anthropicAuthBusy || self.anthropicAuthVerifying)

                            if self.anthropicAuthVerificationFailed {
                                Button(self.t(.reauthOAuth)) {
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
                                    Text(self.t(.openClaudeSignIn))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.anthropicAuthBusy)
                        }
                    }
                }

                if !self.anthropicAuthVerified, self.anthropicAuthPKCE != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(self.t(.pasteCodeState))
                            .font(.headline)
                        TextField("code#state", text: self.$anthropicAuthCode)
                            .textFieldStyle(.roundedBorder)

                        Toggle(self.t(.autoDetectClipboard), isOn: self.$anthropicAuthAutoDetectClipboard)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .disabled(self.anthropicAuthBusy)

                        Toggle(self.t(.autoConnectClipboard), isOn: self.$anthropicAuthAutoConnectClipboard)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .disabled(self.anthropicAuthBusy)

                        Button(self.t(.connect)) {
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
                    Text(self.t(.apiKeyAdvanced))
                        .font(.headline)
                    Text(self.t(.apiKeyAdvancedBody))
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

    func voiceAssistantPage() -> some View {
        self.onboardingPage {
            Text(self.t(.setupVoiceTitle))
                .font(.largeTitle.weight(.semibold))
            Text(self.t(.setupVoiceSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)

            self.onboardingCard(spacing: 14, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(self.t(.voiceDaemonTitle))
                            .font(.headline)
                        HStack(spacing: 8) {
                            Text(self.voiceDaemonStatusLabel)
                                .font(.callout.weight(.semibold))
                            Spacer(minLength: 0)
                            Button(self.voiceDaemonActionLabel) {
                                self.voiceDaemon.start()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(self.voiceDaemonIsBusy)
                            if self.voiceDaemonIsBusy {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        if let note = self.voiceDaemon.statusNote, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let err = self.voiceDaemon.lastError, !err.isEmpty {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Text(self.t(.voiceDaemonNote))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(self.t(.micSpeechTitle))
                            .font(.headline)
                        HStack(spacing: 8) {
                            Image(systemName: self.voicePermissionsGranted
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill")
                                .foregroundStyle(self.voicePermissionsGranted
                                    ? Color(nsColor: .systemGreen)
                                    : Color(nsColor: .systemOrange))
                            Text(self.voicePermissionsGranted ? self.t(.accessGranted) : self.t(.needsAccess))
                                .font(.callout.weight(.semibold))
                            Spacer(minLength: 0)
                            Button(self.voicePermissionsGranted ? self.t(.refresh) : self.t(.grantAccess)) {
                                Task { await self.requestVoicePermissions() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(self.requestingVoicePermissions)
                            if self.requestingVoicePermissions {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                            Text(
                                self.voicePermissionsGranted
                                    ? self.t(.voiceCanListen)
                                    : self.t(.voiceNeedsAccess))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(self.t(.voiceWidgetTitle))
                            .font(.headline)
                        HStack(spacing: 10) {
                            Button(self.t(.openVoiceWidget)) {
                                VoiceWidgetWebPanelController.shared.show(pinned: true)
                            }
                            .buttonStyle(.borderedProminent)
                            Toggle(self.t(.autoShowOnSpeech), isOn: self.$voiceWidgetAutoWake)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(self.t(.widgetLanguage))
                                .font(.subheadline.weight(.semibold))
                            Picker(self.t(.widgetLanguage), selection: self.$voiceWidgetLang) {
                                Text("English").tag("en")
                                Text("中文").tag("zh")
                            }
                            .pickerStyle(.segmented)
                        }
                        Text(self.t(.widgetFloatingNote))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    Text(self.t(.remoteGatewayDetected))
                        .font(.headline)
                    Text(self.t(.remoteGatewayNote))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(self.copied ? self.t(.copied) : self.t(.copySetupCommand)) {
                        self.copyToPasteboard(self.workspaceBootstrapCommand)
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(self.t(.workspaceFolder))
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
                                    Text(self.t(.createWorkspace))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.workspaceApplying)

                            Button(self.t(.openFolder)) {
                                let url = AgentWorkspace.resolveWorkspaceURL(from: self.workspacePath)
                                NSWorkspace.shared.open(url)
                            }
                            .buttonStyle(.bordered)
                            .disabled(self.workspaceApplying)

                            Button(self.t(.saveInConfig)) {
                                Task {
                                    let url = AgentWorkspace.resolveWorkspaceURL(from: self.workspacePath)
                                    let saved = await self.saveAgentWorkspace(AgentWorkspace.displayPath(for: url))
                                    if saved {
                                        self.workspaceStatus = self.t(.workspaceSaved)
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

    private var voiceDaemonStatusLabel: String {
        switch self.voiceDaemon.status {
        case .stopped:
            return self.t(.voiceDaemonStopped)
        case .starting:
            return self.t(.voiceDaemonStarting)
        case let .running(details):
            if let details, !details.isEmpty {
                return self.tf(.voiceDaemonRunningDetails, details)
            }
            return self.t(.voiceDaemonRunning)
        case let .failed(reason):
            if reason.isEmpty { return self.t(.voiceDaemonFailed) }
            return self.tf(.voiceDaemonFailedDetails, reason)
        }
    }

    private var voiceDaemonActionLabel: String {
        switch self.voiceDaemon.status {
        case .running:
            return self.t(.voiceDaemonRestart)
        case .starting:
            return self.t(.voiceDaemonStarting)
        case .stopped, .failed:
            return self.t(.voiceDaemonRetry)
        }
    }

    private var voiceDaemonIsBusy: Bool {
        if case .starting = self.voiceDaemon.status { return true }
        return false
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
                    Text(self.tf(.detailsPrefix, error))
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

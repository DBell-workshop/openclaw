import Foundation

enum OnboardingLanguage: String, CaseIterable {
    case en = "en"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja = "ja"

    var displayName: String {
        switch self {
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        case .zhHant:
            return "繁體中文"
        case .ja:
            return "日本語"
        }
    }

    static func preferredDefault() -> OnboardingLanguage {
        return .en
    }

    static func fromDefaults() -> OnboardingLanguage {
        let stored = UserDefaults.standard.string(forKey: onboardingLanguageKey) ?? ""
        if let lang = OnboardingLanguage(rawValue: stored) {
            return lang
        }
        return preferredDefault()
    }
}

enum OnboardingCopyKey: String {
    case languageLabel
    case back
    case next
    case finish
    case welcomeTitle
    case welcomeSubtitle
    case securityNoticeTitle
    case securityNoticeBody
    case legalAgreementPrefix
    case legalConnector
    case termsOfService
    case privacyPolicy
    case chooseGatewayTitle
    case chooseGatewaySubtitle
    case thisMacTitle
    case thisMacSubtitleDefault
    case localGatewayDetected
    case portInUse
    case willAttach
    case searchingGateways
    case nearbyGateways
    case refresh
    case refreshStatusHelp
    case configureLater
    case configureLaterSubtitle
    case advanced
    case hideAdvanced
    case transport
    case sshTunnel
    case directWs
    case gatewayUrl
    case sshTarget
    case identityFile
    case projectRoot
    case cliPath
    case directTip
    case sshTip
    case gatewayPairingOnly
    case refreshDiscoveryHelp
    case connectClaudeTitle
    case connectClaudeSubtitle
    case connectClaudeSupportNote
    case claudeConnectedVerified
    case claudeConnected
    case notConnectedYet
    case verifyingOAuth
    case detectedWorkingOAuth
    case oauthStorageNote
    case reveal
    case verify
    case reauthOAuth
    case openClaudeSignIn
    case pasteCodeState
    case autoDetectClipboard
    case autoConnectClipboard
    case connect
    case apiKeyAdvanced
    case apiKeyAdvancedBody
    case browserOpenedStatus
    case oauthStartFailed
    case oauthFailedInvalidCode
    case oauthConnectedStatus
    case oauthFailedStatus
    case oauthClipboardDetected
    case oauthVerifyFailedMissingRefresh
    case oauthVerified
    case oauthVerifyFailed
    case grantPermissionsTitle
    case grantPermissionsSubtitle
    case setupVoiceTitle
    case setupVoiceSubtitle
    case voiceDaemonTitle
    case voiceDaemonNote
    case micSpeechTitle
    case accessGranted
    case needsAccess
    case grantAccess
    case voiceCanListen
    case voiceNeedsAccess
    case voiceWidgetTitle
    case openVoiceWidget
    case autoShowOnSpeech
    case widgetLanguage
    case widgetFloatingNote
    case voiceDaemonStopped
    case voiceDaemonStarting
    case voiceDaemonRunning
    case voiceDaemonRunningDetails
    case voiceDaemonFailed
    case voiceDaemonFailedDetails
    case voiceDaemonRestart
    case voiceDaemonRetry
    case installCliTitle
    case installCliSubtitle
    case reinstallCli
    case installCli
    case copied
    case copyInstallCommand
    case installedAt
    case cliInstallNote
    case workspaceTitle
    case workspaceSubtitle
    case remoteGatewayDetected
    case remoteGatewayNote
    case copySetupCommand
    case workspaceFolder
    case createWorkspace
    case openFolder
    case saveInConfig
    case workspaceSaved
    case workspaceTip
    case meetAgentTitle
    case meetAgentSubtitle
    case onboardingChatPrompt
    case allSetTitle
    case configureLaterReadyTitle
    case configureLaterReadySubtitle
    case remoteChecklistTitle
    case remoteChecklistSubtitle
    case openMenuBarTitle
    case openMenuBarSubtitle
    case connectChannelsTitle
    case connectChannelsSubtitle
    case openSettingsChannels
    case tryVoiceWakeTitle
    case tryVoiceWakeSubtitle
    case panelCanvasTitle
    case panelCanvasSubtitle
    case morePowersTitle
    case morePowersSubtitle
    case openSettingsSkills
    case launchAtLogin
    case skillsIncluded
    case couldntLoadSkillsTitle
    case couldntLoadSkillsBody
    case detailsPrefix
    case noSkillsYet
    case setupWizardTitle
    case setupWizardSubtitle
    case wizardError
    case retry
    case startingWizard
    case wizardComplete
    case waitingWizard
    case gatewayDepsInstallingTitle
    case gatewayDepsInstallingSubtitle
    case wizardUnsupportedStep
    case wizardRun
    case wizardContinue
}

enum OnboardingCopy {
    private static let table: [OnboardingLanguage: [OnboardingCopyKey: String]] = [
        .en: [
            .languageLabel: "Language",
            .back: "Back",
            .next: "Next",
            .finish: "Finish",
            .welcomeTitle: "Welcome to MyCatCat",
            .welcomeSubtitle: "MyCatCat is a personal AI assistant that can connect to WhatsApp or Telegram.",
            .securityNoticeTitle: "Security notice",
            .securityNoticeBody: """
            The connected AI agent (e.g. Claude) can trigger powerful actions on your Mac, including running commands, reading/writing files, and capturing screenshots — depending on the permissions you grant.

            Only enable MyCatCat if you understand the risks and trust the prompts and integrations you use.
            """,
            .legalAgreementPrefix: "By continuing, you agree to the",
            .legalConnector: "and",
            .termsOfService: "Terms of Service",
            .privacyPolicy: "Privacy Policy",
            .chooseGatewayTitle: "Choose your Gateway",
            .chooseGatewaySubtitle: "MyCatCat uses a single Gateway that stays running. Pick this Mac, connect to a discovered gateway nearby, or configure later.",
            .thisMacTitle: "This Mac",
            .thisMacSubtitleDefault: "Gateway starts automatically on this Mac.",
            .localGatewayDetected: "Existing gateway detected",
            .portInUse: "Port %d already in use",
            .willAttach: "Will attach.",
            .searchingGateways: "Searching for nearby gateways…",
            .nearbyGateways: "Nearby gateways",
            .refresh: "Refresh",
            .refreshStatusHelp: "Refresh status",
            .configureLater: "Configure later",
            .configureLaterSubtitle: "Don’t start the Gateway yet.",
            .advanced: "Advanced…",
            .hideAdvanced: "Hide Advanced",
            .transport: "Transport",
            .sshTunnel: "SSH tunnel",
            .directWs: "Direct (ws/wss)",
            .gatewayUrl: "Gateway URL",
            .sshTarget: "SSH target",
            .identityFile: "Identity file",
            .projectRoot: "Project root",
            .cliPath: "CLI path",
            .directTip: "Tip: use Tailscale Serve so the gateway has a valid HTTPS cert.",
            .sshTip: "Tip: keep Tailscale enabled so your gateway stays reachable.",
            .gatewayPairingOnly: "Gateway pairing only",
            .refreshDiscoveryHelp: "Retry Tailscale discovery (DNS-SD).",
            .connectClaudeTitle: "Connect Claude",
            .connectClaudeSubtitle: "Give your model the token it needs!",
            .connectClaudeSupportNote: "MyCatCat supports any model — we strongly recommend Opus 4.5 for the best experience.",
            .claudeConnectedVerified: "Claude connected (OAuth) — verified",
            .claudeConnected: "Claude connected (OAuth)",
            .notConnectedYet: "Not connected yet",
            .verifyingOAuth: "Verifying OAuth…",
            .detectedWorkingOAuth: "Detected working OAuth (%@).",
            .oauthStorageNote: "This lets MyCatCat use Claude immediately. Credentials are stored at `~/.openclaw/credentials/oauth.json` (owner-only).",
            .reveal: "Reveal",
            .verify: "Verify",
            .reauthOAuth: "Re-auth (OAuth)",
            .openClaudeSignIn: "Open Claude sign-in (OAuth)",
            .pasteCodeState: "Paste the `code#state` value",
            .autoDetectClipboard: "Auto-detect from clipboard",
            .autoConnectClipboard: "Auto-connect when detected",
            .connect: "Connect",
            .apiKeyAdvanced: "API key (advanced)",
            .apiKeyAdvancedBody: "You can also use an Anthropic API key, but this UI is instructions-only for now (GUI apps don’t automatically inherit your shell env vars like `ANTHROPIC_API_KEY`).",
            .browserOpenedStatus: "Browser opened. After approving, paste the `code#state` value here.",
            .oauthStartFailed: "Failed to start OAuth: %@",
            .oauthFailedInvalidCode: "OAuth failed: missing or invalid code/state.",
            .oauthConnectedStatus: "Connected. MyCatCat can now use Claude.",
            .oauthFailedStatus: "OAuth failed: %@",
            .oauthClipboardDetected: "Detected `code#state` from clipboard.",
            .oauthVerifyFailedMissingRefresh: "OAuth verification failed: missing refresh token.",
            .oauthVerified: "OAuth detected and verified.",
            .oauthVerifyFailed: "OAuth verification failed: %@",
            .grantPermissionsTitle: "Grant permissions",
            .grantPermissionsSubtitle: "These macOS permissions let MyCatCat automate apps and capture context on this Mac.",
            .setupVoiceTitle: "Set up Voice",
            .setupVoiceSubtitle: "Enable voice access, start the daemon, and open the floating widget.",
            .voiceDaemonTitle: "Voice daemon",
            .voiceDaemonNote: "The daemon connects to your Gateway LLM and streams real-time speech.",
            .micSpeechTitle: "Microphone + Speech",
            .accessGranted: "Access granted",
            .needsAccess: "Needs access",
            .grantAccess: "Grant access",
            .voiceCanListen: "Voice can listen and transcribe in real time.",
            .voiceNeedsAccess: "Required for voice wake and streaming transcription.",
            .voiceWidgetTitle: "Voice Widget",
            .openVoiceWidget: "Open Voice Widget",
            .autoShowOnSpeech: "Auto-show on speech",
            .widgetLanguage: "Widget language",
            .widgetFloatingNote: "The widget stays floating and remembers its last position.",
            .voiceDaemonStopped: "Stopped",
            .voiceDaemonStarting: "Starting…",
            .voiceDaemonRunning: "Running",
            .voiceDaemonRunningDetails: "Running (%@)",
            .voiceDaemonFailed: "Failed",
            .voiceDaemonFailedDetails: "Failed (%@)",
            .voiceDaemonRestart: "Restart voice daemon",
            .voiceDaemonRetry: "Retry voice daemon",
            .installCliTitle: "Install the CLI",
            .installCliSubtitle: "Required for local mode: installs `openclaw` so launchd can run the gateway.",
            .reinstallCli: "Reinstall CLI",
            .installCli: "Install CLI",
            .copied: "Copied",
            .copyInstallCommand: "Copy install command",
            .installedAt: "Installed at %@",
            .cliInstallNote: """
            Installs a user-space Node 22+ runtime and the CLI (no Homebrew).
            Rerun anytime to reinstall or update.
            """,
            .workspaceTitle: "Agent workspace",
            .workspaceSubtitle: "MyCatCat runs the agent from a dedicated workspace so it can load `AGENTS.md` and write files there without mixing into your other projects.",
            .remoteGatewayDetected: "Remote gateway detected",
            .remoteGatewayNote: "Create the workspace on the remote host (SSH in first). The macOS app can’t write files on your gateway over SSH yet.",
            .copySetupCommand: "Copy setup command",
            .workspaceFolder: "Workspace folder",
            .createWorkspace: "Create workspace",
            .openFolder: "Open folder",
            .saveInConfig: "Save in config",
            .workspaceSaved: "Saved to ~/.openclaw/openclaw.json (agents.defaults.workspace)",
            .workspaceTip: "Tip: edit AGENTS.md in this folder to shape the assistant’s behavior. For backup, make the workspace a private git repo so your agent’s “memory” is versioned.",
            .meetAgentTitle: "Meet your agent",
            .meetAgentSubtitle: "This is a dedicated onboarding chat. Your agent will introduce itself, learn who you are, and help you connect WhatsApp or Telegram if you want.",
            .onboardingChatPrompt: "Hi! I just installed MyCatCat and you’re my brand‑new agent. Please start the first‑run ritual from BOOTSTRAP.md, ask one question at a time, and before we talk about WhatsApp/Telegram, visit soul.md with me to craft SOUL.md: ask what matters to me and how you should be. Then guide me through choosing how we should talk (web‑only, WhatsApp, or Telegram).",
            .allSetTitle: "All set",
            .configureLaterReadyTitle: "Configure later",
            .configureLaterReadySubtitle: "Pick Local or Remote in Settings → General whenever you’re ready.",
            .remoteChecklistTitle: "Remote gateway checklist",
            .remoteChecklistSubtitle: "On your gateway host: install/update the `openclaw` package and make sure credentials exist (typically `~/.openclaw/credentials/oauth.json`). Then connect again if needed.",
            .openMenuBarTitle: "Open the menu bar panel",
            .openMenuBarSubtitle: "Click the MyCatCat menu bar icon for quick chat and status.",
            .connectChannelsTitle: "Connect WhatsApp or Telegram",
            .connectChannelsSubtitle: "Open Settings → Channels to link channels and monitor status.",
            .openSettingsChannels: "Open Settings → Channels",
            .tryVoiceWakeTitle: "Try Voice Wake",
            .tryVoiceWakeSubtitle: "Enable Voice Wake in Settings for hands-free commands with a live transcript overlay.",
            .panelCanvasTitle: "Use the panel + Canvas",
            .panelCanvasSubtitle: "Open the menu bar panel for quick chat; the agent can show previews and richer visuals in Canvas.",
            .morePowersTitle: "Give your agent more powers",
            .morePowersSubtitle: "Enable optional skills (Peekaboo, oracle, camsnap, …) from Settings → Skills.",
            .openSettingsSkills: "Open Settings → Skills",
            .launchAtLogin: "Launch at login",
            .skillsIncluded: "Skills included",
            .couldntLoadSkillsTitle: "Couldn’t load skills from the Gateway.",
            .couldntLoadSkillsBody: "Make sure the Gateway is running and connected, then hit Refresh (or open Settings → Skills).",
            .detailsPrefix: "Details: %@",
            .noSkillsYet: "No skills reported yet.",
            .setupWizardTitle: "Setup Wizard",
            .setupWizardSubtitle: "Follow the guided setup from the Gateway. This keeps onboarding in sync with the CLI.",
            .wizardError: "Wizard error",
            .retry: "Retry",
            .startingWizard: "Starting wizard…",
            .wizardComplete: "Wizard complete. Continue to the next step.",
            .waitingWizard: "Waiting for wizard…",
            .gatewayDepsInstallingTitle: "Installing required components…",
            .gatewayDepsInstallingSubtitle: "First launch may take up to 1-2 minutes. Please keep this window open.",
            .wizardUnsupportedStep: "Unsupported step type",
            .wizardRun: "Run",
            .wizardContinue: "Continue",
        ],
        .zhHans: [
            .languageLabel: "语言",
            .back: "返回",
            .next: "下一步",
            .finish: "完成",
            .welcomeTitle: "欢迎使用 MyCatCat",
            .welcomeSubtitle: "MyCatCat 是一款个人 AI 助理，可连接 WhatsApp 或 Telegram。",
            .securityNoticeTitle: "安全提示",
            .securityNoticeBody: """
            连接的 AI 助理（如 Claude）可能在你的 Mac 上执行强力操作，包括运行命令、读写文件、截屏等——取决于你授予的权限。

            只有在理解风险并信任所使用的提示与集成时才启用 MyCatCat。
            """,
            .legalAgreementPrefix: "继续即表示你同意",
            .legalConnector: "与",
            .termsOfService: "《用户使用协议》",
            .privacyPolicy: "《隐私政策》",
            .chooseGatewayTitle: "选择网关",
            .chooseGatewaySubtitle: "MyCatCat 使用一个持续运行的网关。可选择本机、连接附近发现的网关，或稍后配置。",
            .thisMacTitle: "本机",
            .thisMacSubtitleDefault: "网关会在这台 Mac 上自动启动。",
            .localGatewayDetected: "检测到已有网关",
            .portInUse: "端口 %d 已被占用",
            .willAttach: "将直接连接。",
            .searchingGateways: "正在搜索附近的网关…",
            .nearbyGateways: "附近的网关",
            .refresh: "刷新",
            .refreshStatusHelp: "刷新状态",
            .configureLater: "稍后配置",
            .configureLaterSubtitle: "暂不启动网关。",
            .advanced: "高级…",
            .hideAdvanced: "隐藏高级设置",
            .transport: "传输方式",
            .sshTunnel: "SSH 隧道",
            .directWs: "直连（ws/wss）",
            .gatewayUrl: "网关地址",
            .sshTarget: "SSH 目标",
            .identityFile: "密钥文件",
            .projectRoot: "项目根目录",
            .cliPath: "CLI 路径",
            .directTip: "提示：使用 Tailscale Serve 以便网关具备有效的 HTTPS 证书。",
            .sshTip: "提示：保持 Tailscale 启用以确保网关可达。",
            .gatewayPairingOnly: "仅用于网关配对",
            .refreshDiscoveryHelp: "重试 Tailscale 发现（DNS‑SD）。",
            .connectClaudeTitle: "连接 Claude",
            .connectClaudeSubtitle: "给模型提供所需凭证！",
            .connectClaudeSupportNote: "MyCatCat 支持任意模型——强烈推荐 Opus 4.5 以获得最佳体验。",
            .claudeConnectedVerified: "Claude 已连接（OAuth）— 已验证",
            .claudeConnected: "Claude 已连接（OAuth）",
            .notConnectedYet: "尚未连接",
            .verifyingOAuth: "正在验证 OAuth…",
            .detectedWorkingOAuth: "检测到可用的 OAuth（%@）。",
            .oauthStorageNote: "这样 MyCatCat 可立即使用 Claude。凭证存储在 `~/.openclaw/credentials/oauth.json`（仅当前用户可访问）。",
            .reveal: "在 Finder 中显示",
            .verify: "验证",
            .reauthOAuth: "重新授权（OAuth）",
            .openClaudeSignIn: "打开 Claude 登录（OAuth）",
            .pasteCodeState: "粘贴 `code#state` 值",
            .autoDetectClipboard: "从剪贴板自动识别",
            .autoConnectClipboard: "识别后自动连接",
            .connect: "连接",
            .apiKeyAdvanced: "API Key（高级）",
            .apiKeyAdvancedBody: "你也可以使用 Anthropic API Key，但该界面目前仅提供说明（GUI 应用不会自动继承终端环境变量，如 `ANTHROPIC_API_KEY`）。",
            .browserOpenedStatus: "已打开浏览器。授权后请在此粘贴 `code#state`。",
            .oauthStartFailed: "启动 OAuth 失败：%@",
            .oauthFailedInvalidCode: "OAuth 失败：code/state 缺失或无效。",
            .oauthConnectedStatus: "连接成功，MyCatCat 现在可以使用 Claude。",
            .oauthFailedStatus: "OAuth 失败：%@",
            .oauthClipboardDetected: "已从剪贴板检测到 `code#state`。",
            .oauthVerifyFailedMissingRefresh: "OAuth 验证失败：缺少 refresh token。",
            .oauthVerified: "OAuth 已检测并验证通过。",
            .oauthVerifyFailed: "OAuth 验证失败：%@",
            .grantPermissionsTitle: "授权权限",
            .grantPermissionsSubtitle: "这些 macOS 权限让 MyCatCat 可以自动化应用并捕捉此 Mac 上的上下文。",
            .setupVoiceTitle: "设置语音",
            .setupVoiceSubtitle: "开启语音权限，启动守护进程并打开悬浮小组件。",
            .voiceDaemonTitle: "语音守护进程",
            .voiceDaemonNote: "守护进程会连接网关 LLM 并进行实时语音流处理。",
            .micSpeechTitle: "麦克风与语音识别",
            .accessGranted: "已授权",
            .needsAccess: "需要授权",
            .grantAccess: "授权",
            .voiceCanListen: "语音可实时监听并转写。",
            .voiceNeedsAccess: "需要授权用于语音唤醒与实时转写。",
            .voiceWidgetTitle: "语音小组件",
            .openVoiceWidget: "打开语音小组件",
            .autoShowOnSpeech: "说话时自动显示",
            .widgetLanguage: "小组件语言",
            .widgetFloatingNote: "小组件会保持悬浮并记住上次位置。",
            .voiceDaemonStopped: "已停止",
            .voiceDaemonStarting: "启动中…",
            .voiceDaemonRunning: "运行中",
            .voiceDaemonRunningDetails: "运行中（%@）",
            .voiceDaemonFailed: "失败",
            .voiceDaemonFailedDetails: "失败（%@）",
            .voiceDaemonRestart: "重启语音守护进程",
            .voiceDaemonRetry: "重试语音守护进程",
            .installCliTitle: "安装 CLI",
            .installCliSubtitle: "本地模式需要安装 `openclaw`，以便 launchd 运行网关。",
            .reinstallCli: "重新安装 CLI",
            .installCli: "安装 CLI",
            .copied: "已复制",
            .copyInstallCommand: "复制安装命令",
            .installedAt: "已安装到 %@",
            .cliInstallNote: """
            会安装用户态 Node 22+ 运行时与 CLI（无需 Homebrew）。
            可随时重新运行以重装或更新。
            """,
            .workspaceTitle: "代理工作区",
            .workspaceSubtitle: "MyCatCat 在独立工作区运行代理，以便加载 `AGENTS.md` 并写入文件，避免混入其他项目。",
            .remoteGatewayDetected: "检测到远程网关",
            .remoteGatewayNote: "请在远程主机上创建工作区（先 SSH 登录）。macOS App 目前无法通过 SSH 在网关上写文件。",
            .copySetupCommand: "复制设置命令",
            .workspaceFolder: "工作区目录",
            .createWorkspace: "创建工作区",
            .openFolder: "打开文件夹",
            .saveInConfig: "保存到配置",
            .workspaceSaved: "已保存到 ~/.openclaw/openclaw.json（agents.defaults.workspace）",
            .workspaceTip: "提示：在此文件夹编辑 AGENTS.md 以塑造助手行为。建议把工作区建为私有 Git 仓库，便于版本化“记忆”。",
            .meetAgentTitle: "认识你的助手",
            .meetAgentSubtitle: "这是专用的新手对话。你的助手会自我介绍，了解你，并在需要时帮助你连接 WhatsApp 或 Telegram。",
            .onboardingChatPrompt: "你好！我刚安装了 MyCatCat，你是我全新的助手。请先从 BOOTSTRAP.md 开始首次启动流程，一次只问一个问题。在讨论 WhatsApp/Telegram 之前，请和我一起查看 soul.md 并创建 SOUL.md：询问我在意什么，以及你应该以怎样的方式陪伴我。然后引导我选择沟通方式（仅网页、WhatsApp 或 Telegram）。",
            .allSetTitle: "准备就绪",
            .configureLaterReadyTitle: "稍后配置",
            .configureLaterReadySubtitle: "准备好后在 设置 → 通用 中选择 本地 或 远程。",
            .remoteChecklistTitle: "远程网关检查清单",
            .remoteChecklistSubtitle: "在你的网关主机上：安装/更新 `openclaw` 包并确保凭证存在（通常是 `~/.openclaw/credentials/oauth.json`）。如有需要请重新连接。",
            .openMenuBarTitle: "打开菜单栏面板",
            .openMenuBarSubtitle: "点击菜单栏中的 MyCatCat 图标进行快速对话和查看状态。",
            .connectChannelsTitle: "连接 WhatsApp 或 Telegram",
            .connectChannelsSubtitle: "打开 设置 → 渠道 进行绑定并查看状态。",
            .openSettingsChannels: "打开 设置 → 渠道",
            .tryVoiceWakeTitle: "试用语音唤醒",
            .tryVoiceWakeSubtitle: "在设置中启用语音唤醒，实现免手动指令和实时转写叠层。",
            .panelCanvasTitle: "使用面板与 Canvas",
            .panelCanvasSubtitle: "打开菜单栏面板进行快速对话；Canvas 可展示更丰富的可视化。",
            .morePowersTitle: "赋予助手更多能力",
            .morePowersSubtitle: "在 设置 → Skills 中启用可选技能（Peekaboo、oracle、camsnap…）。",
            .openSettingsSkills: "打开 设置 → Skills",
            .launchAtLogin: "登录时启动",
            .skillsIncluded: "已包含的技能",
            .couldntLoadSkillsTitle: "无法从网关加载技能。",
            .couldntLoadSkillsBody: "请确认网关在运行且已连接，然后点击刷新（或打开 设置 → Skills）。",
            .detailsPrefix: "详情：%@",
            .noSkillsYet: "尚未获取到技能列表。",
            .setupWizardTitle: "设置向导",
            .setupWizardSubtitle: "按照网关提供的引导完成设置，以保持与 CLI 同步。",
            .wizardError: "向导出错",
            .retry: "重试",
            .startingWizard: "正在启动向导…",
            .wizardComplete: "向导完成，请继续下一步。",
            .waitingWizard: "正在等待向导…",
            .gatewayDepsInstallingTitle: "正在自动安装依赖…",
            .gatewayDepsInstallingSubtitle: "首次启动可能需要 1-2 分钟，请保持此窗口开启。",
            .wizardUnsupportedStep: "不支持的步骤类型",
            .wizardRun: "运行",
            .wizardContinue: "继续",
        ],
        .zhHant: [
            .languageLabel: "語言",
            .back: "返回",
            .next: "下一步",
            .finish: "完成",
            .welcomeTitle: "歡迎使用 MyCatCat",
            .welcomeSubtitle: "MyCatCat 是一款個人 AI 助理，可連接 WhatsApp 或 Telegram。",
            .securityNoticeTitle: "安全提示",
            .securityNoticeBody: """
            連接的 AI 助理（如 Claude）可能在你的 Mac 上執行強力操作，包括執行命令、讀寫檔案、截圖等——取決於你授予的權限。

            只有在理解風險並信任所使用的提示與整合時才啟用 MyCatCat。
            """,
            .legalAgreementPrefix: "繼續即表示你同意",
            .legalConnector: "與",
            .termsOfService: "《使用者協議》",
            .privacyPolicy: "《隱私政策》",
            .chooseGatewayTitle: "選擇網關",
            .chooseGatewaySubtitle: "MyCatCat 使用一個持續運行的網關。可選擇本機、連接附近發現的網關，或稍後設定。",
            .thisMacTitle: "本機",
            .thisMacSubtitleDefault: "網關會在這台 Mac 上自動啟動。",
            .localGatewayDetected: "偵測到已有網關",
            .portInUse: "連接埠 %d 已被佔用",
            .willAttach: "將直接連線。",
            .searchingGateways: "正在搜尋附近的網關…",
            .nearbyGateways: "附近的網關",
            .refresh: "重新整理",
            .refreshStatusHelp: "重新整理狀態",
            .configureLater: "稍後設定",
            .configureLaterSubtitle: "暫不啟動網關。",
            .advanced: "進階…",
            .hideAdvanced: "隱藏進階設定",
            .transport: "傳輸方式",
            .sshTunnel: "SSH 隧道",
            .directWs: "直連（ws/wss）",
            .gatewayUrl: "網關位址",
            .sshTarget: "SSH 目標",
            .identityFile: "金鑰檔案",
            .projectRoot: "專案根目錄",
            .cliPath: "CLI 路徑",
            .directTip: "提示：使用 Tailscale Serve 讓網關具備有效的 HTTPS 憑證。",
            .sshTip: "提示：保持 Tailscale 啟用以確保網關可達。",
            .gatewayPairingOnly: "僅用於網關配對",
            .refreshDiscoveryHelp: "重試 Tailscale 發現（DNS‑SD）。",
            .connectClaudeTitle: "連接 Claude",
            .connectClaudeSubtitle: "給模型提供所需憑證！",
            .connectClaudeSupportNote: "MyCatCat 支援任何模型——強烈建議 Opus 4.5 以獲得最佳體驗。",
            .claudeConnectedVerified: "Claude 已連線（OAuth）— 已驗證",
            .claudeConnected: "Claude 已連線（OAuth）",
            .notConnectedYet: "尚未連線",
            .verifyingOAuth: "正在驗證 OAuth…",
            .detectedWorkingOAuth: "偵測到可用的 OAuth（%@）。",
            .oauthStorageNote: "這樣 MyCatCat 可立即使用 Claude。憑證存放於 `~/.openclaw/credentials/oauth.json`（僅目前使用者可存取）。",
            .reveal: "在 Finder 中顯示",
            .verify: "驗證",
            .reauthOAuth: "重新授權（OAuth）",
            .openClaudeSignIn: "開啟 Claude 登入（OAuth）",
            .pasteCodeState: "貼上 `code#state` 值",
            .autoDetectClipboard: "從剪貼簿自動辨識",
            .autoConnectClipboard: "辨識後自動連線",
            .connect: "連線",
            .apiKeyAdvanced: "API Key（進階）",
            .apiKeyAdvancedBody: "你也可以使用 Anthropic API Key，但此介面目前僅提供說明（GUI 應用不會自動繼承終端環境變數，如 `ANTHROPIC_API_KEY`）。",
            .browserOpenedStatus: "已開啟瀏覽器。授權後請在此貼上 `code#state`。",
            .oauthStartFailed: "啟動 OAuth 失敗：%@",
            .oauthFailedInvalidCode: "OAuth 失敗：code/state 缺失或無效。",
            .oauthConnectedStatus: "連線成功，MyCatCat 現在可以使用 Claude。",
            .oauthFailedStatus: "OAuth 失敗：%@",
            .oauthClipboardDetected: "已從剪貼簿偵測到 `code#state`。",
            .oauthVerifyFailedMissingRefresh: "OAuth 驗證失敗：缺少 refresh token。",
            .oauthVerified: "OAuth 已偵測並驗證通過。",
            .oauthVerifyFailed: "OAuth 驗證失敗：%@",
            .grantPermissionsTitle: "授權權限",
            .grantPermissionsSubtitle: "這些 macOS 權限讓 MyCatCat 可以自動化應用並擷取此 Mac 上的上下文。",
            .setupVoiceTitle: "設定語音",
            .setupVoiceSubtitle: "啟用語音權限、啟動守護程式並開啟懸浮小工具。",
            .voiceDaemonTitle: "語音守護程式",
            .voiceDaemonNote: "守護程式會連接網關 LLM 並進行即時語音串流處理。",
            .micSpeechTitle: "麥克風與語音辨識",
            .accessGranted: "已授權",
            .needsAccess: "需要授權",
            .grantAccess: "授權",
            .voiceCanListen: "語音可即時聆聽並轉寫。",
            .voiceNeedsAccess: "需要授權用於語音喚醒與即時轉寫。",
            .voiceWidgetTitle: "語音小工具",
            .openVoiceWidget: "開啟語音小工具",
            .autoShowOnSpeech: "說話時自動顯示",
            .widgetLanguage: "小工具語言",
            .widgetFloatingNote: "小工具會保持懸浮並記住上次位置。",
            .voiceDaemonStopped: "已停止",
            .voiceDaemonStarting: "啟動中…",
            .voiceDaemonRunning: "運行中",
            .voiceDaemonRunningDetails: "運行中（%@）",
            .voiceDaemonFailed: "失敗",
            .voiceDaemonFailedDetails: "失敗（%@）",
            .voiceDaemonRestart: "重新啟動語音守護程式",
            .voiceDaemonRetry: "重試語音守護程式",
            .installCliTitle: "安裝 CLI",
            .installCliSubtitle: "本機模式需要安裝 `openclaw`，以便 launchd 執行網關。",
            .reinstallCli: "重新安裝 CLI",
            .installCli: "安裝 CLI",
            .copied: "已複製",
            .copyInstallCommand: "複製安裝命令",
            .installedAt: "已安裝到 %@",
            .cliInstallNote: """
            會安裝使用者層級的 Node 22+ 執行環境與 CLI（不需要 Homebrew）。
            可隨時重新執行以重裝或更新。
            """,
            .workspaceTitle: "代理工作區",
            .workspaceSubtitle: "MyCatCat 在獨立工作區運行代理，以便載入 `AGENTS.md` 並寫入檔案，避免混入其他專案。",
            .remoteGatewayDetected: "偵測到遠端網關",
            .remoteGatewayNote: "請在遠端主機上建立工作區（先 SSH 登入）。macOS App 目前無法透過 SSH 在網關上寫入檔案。",
            .copySetupCommand: "複製設定命令",
            .workspaceFolder: "工作區資料夾",
            .createWorkspace: "建立工作區",
            .openFolder: "開啟資料夾",
            .saveInConfig: "儲存到設定",
            .workspaceSaved: "已儲存到 ~/.openclaw/openclaw.json（agents.defaults.workspace）",
            .workspaceTip: "提示：在此資料夾編輯 AGENTS.md 以塑造助手行為。建議將工作區設為私有 Git 倉庫，便於版本化「記憶」。",
            .meetAgentTitle: "認識你的助手",
            .meetAgentSubtitle: "這是專用的新手對話。你的助手會自我介紹、了解你，並在需要時協助你連接 WhatsApp 或 Telegram。",
            .onboardingChatPrompt: "你好！我剛安裝了 MyCatCat，你是我全新的助手。請先從 BOOTSTRAP.md 開始首次啟動流程，一次只問一個問題。在討論 WhatsApp/Telegram 之前，請和我一起查看 soul.md 並建立 SOUL.md：詢問我在意什麼，以及你應該以怎樣的方式陪伴我。然後引導我選擇溝通方式（僅網頁、WhatsApp 或 Telegram）。",
            .allSetTitle: "準備就緒",
            .configureLaterReadyTitle: "稍後設定",
            .configureLaterReadySubtitle: "準備好後在 設定 → 一般 中選擇 本機 或 遠端。",
            .remoteChecklistTitle: "遠端網關檢查清單",
            .remoteChecklistSubtitle: "在你的網關主機上：安裝/更新 `openclaw` 套件並確保憑證存在（通常為 `~/.openclaw/credentials/oauth.json`）。如有需要請重新連線。",
            .openMenuBarTitle: "開啟選單列面板",
            .openMenuBarSubtitle: "點擊選單列中的 MyCatCat 圖示即可快速對話與查看狀態。",
            .connectChannelsTitle: "連接 WhatsApp 或 Telegram",
            .connectChannelsSubtitle: "開啟 設定 → 渠道 進行綁定並查看狀態。",
            .openSettingsChannels: "開啟 設定 → 渠道",
            .tryVoiceWakeTitle: "試用語音喚醒",
            .tryVoiceWakeSubtitle: "在設定中啟用語音喚醒，支援免手動指令與即時轉寫疊層。",
            .panelCanvasTitle: "使用面板與 Canvas",
            .panelCanvasSubtitle: "開啟選單列面板進行快速對話；Canvas 可展示更豐富的視覺內容。",
            .morePowersTitle: "賦予助手更多能力",
            .morePowersSubtitle: "在 設定 → Skills 中啟用可選技能（Peekaboo、oracle、camsnap…）。",
            .openSettingsSkills: "開啟 設定 → Skills",
            .launchAtLogin: "登入時啟動",
            .skillsIncluded: "已包含的技能",
            .couldntLoadSkillsTitle: "無法從網關載入技能。",
            .couldntLoadSkillsBody: "請確認網關正在運行且已連線，然後點擊重新整理（或開啟 設定 → Skills）。",
            .detailsPrefix: "詳情：%@",
            .noSkillsYet: "尚未取得技能列表。",
            .setupWizardTitle: "設定精靈",
            .setupWizardSubtitle: "按照網關提供的引導完成設定，以保持與 CLI 同步。",
            .wizardError: "精靈出錯",
            .retry: "重試",
            .startingWizard: "正在啟動精靈…",
            .wizardComplete: "精靈完成，請繼續下一步。",
            .waitingWizard: "正在等待精靈…",
            .gatewayDepsInstallingTitle: "正在自動安裝依賴…",
            .gatewayDepsInstallingSubtitle: "首次啟動可能需要 1-2 分鐘，請保持此視窗開啟。",
            .wizardUnsupportedStep: "不支援的步驟類型",
            .wizardRun: "執行",
            .wizardContinue: "繼續",
        ],
        .ja: [
            .languageLabel: "言語",
            .back: "戻る",
            .next: "次へ",
            .finish: "完了",
            .welcomeTitle: "MyCatCat へようこそ",
            .welcomeSubtitle: "MyCatCat は WhatsApp / Telegram に接続できるパーソナル AI アシスタントです。",
            .securityNoticeTitle: "セキュリティ注意",
            .securityNoticeBody: """
            接続された AI エージェント（例：Claude）は、付与した権限に応じて、コマンド実行・ファイルの読み書き・スクリーンショット取得など強力な操作を行えます。

            リスクを理解し、利用するプロンプトや連携を信頼できる場合にのみ MyCatCat を有効化してください。
            """,
            .legalAgreementPrefix: "続行すると、次に同意したものとみなされます:",
            .legalConnector: "および",
            .termsOfService: "利用規約",
            .privacyPolicy: "プライバシーポリシー",
            .chooseGatewayTitle: "ゲートウェイを選択",
            .chooseGatewaySubtitle: "MyCatCat は常駐する 1 つのゲートウェイを使用します。この Mac を使うか、近くで検出したゲートウェイに接続するか、後で設定してください。",
            .thisMacTitle: "この Mac",
            .thisMacSubtitleDefault: "この Mac でゲートウェイを自動的に起動します。",
            .localGatewayDetected: "既存のゲートウェイを検出しました",
            .portInUse: "ポート %d は既に使用中です",
            .willAttach: "接続して利用します。",
            .searchingGateways: "近くのゲートウェイを検索中…",
            .nearbyGateways: "近くのゲートウェイ",
            .refresh: "更新",
            .refreshStatusHelp: "状態を更新",
            .configureLater: "後で設定",
            .configureLaterSubtitle: "今はゲートウェイを起動しません。",
            .advanced: "詳細…",
            .hideAdvanced: "詳細を隠す",
            .transport: "接続方式",
            .sshTunnel: "SSH トンネル",
            .directWs: "直接（ws/wss）",
            .gatewayUrl: "ゲートウェイ URL",
            .sshTarget: "SSH ターゲット",
            .identityFile: "鍵ファイル",
            .projectRoot: "プロジェクトルート",
            .cliPath: "CLI パス",
            .directTip: "ヒント: Tailscale Serve を使ってゲートウェイに有効な HTTPS 証明書を付与してください。",
            .sshTip: "ヒント: ゲートウェイに到達できるよう Tailscale を有効に保ってください。",
            .gatewayPairingOnly: "ゲートウェイのペアリングのみ",
            .refreshDiscoveryHelp: "Tailscale 検出を再試行（DNS‑SD）。",
            .connectClaudeTitle: "Claude を接続",
            .connectClaudeSubtitle: "モデルに必要なトークンを渡しましょう！",
            .connectClaudeSupportNote: "MyCatCat はあらゆるモデルに対応していますが、最高の体験には Opus 4.5 を強く推奨します。",
            .claudeConnectedVerified: "Claude に接続済み（OAuth）— 検証済み",
            .claudeConnected: "Claude に接続済み（OAuth）",
            .notConnectedYet: "まだ接続されていません",
            .verifyingOAuth: "OAuth を検証中…",
            .detectedWorkingOAuth: "有効な OAuth を検出しました（%@）。",
            .oauthStorageNote: "これにより MyCatCat が直ちに Claude を利用できます。認証情報は `~/.openclaw/credentials/oauth.json` に保存されます（所有者のみ）。",
            .reveal: "Finder で表示",
            .verify: "検証",
            .reauthOAuth: "再認証（OAuth）",
            .openClaudeSignIn: "Claude のサインインを開く（OAuth）",
            .pasteCodeState: "`code#state` を貼り付け",
            .autoDetectClipboard: "クリップボードから自動検出",
            .autoConnectClipboard: "検出したら自動接続",
            .connect: "接続",
            .apiKeyAdvanced: "API キー（詳細）",
            .apiKeyAdvancedBody: "Anthropic API キーも利用できますが、この画面は手順のみです（GUI アプリは `ANTHROPIC_API_KEY` などのシェル環境変数を自動で引き継ぎません）。",
            .browserOpenedStatus: "ブラウザを開きました。承認後、`code#state` をここに貼り付けてください。",
            .oauthStartFailed: "OAuth の開始に失敗しました: %@",
            .oauthFailedInvalidCode: "OAuth 失敗: code/state が不足または無効です。",
            .oauthConnectedStatus: "接続完了。MyCatCat で Claude を利用できます。",
            .oauthFailedStatus: "OAuth 失敗: %@",
            .oauthClipboardDetected: "クリップボードから `code#state` を検出しました。",
            .oauthVerifyFailedMissingRefresh: "OAuth 検証失敗: refresh token がありません。",
            .oauthVerified: "OAuth を検出して検証しました。",
            .oauthVerifyFailed: "OAuth 検証失敗: %@",
            .grantPermissionsTitle: "権限を付与",
            .grantPermissionsSubtitle: "これらの macOS 権限により、MyCatCat がアプリ操作やこの Mac のコンテキスト取得を行えます。",
            .setupVoiceTitle: "音声設定",
            .setupVoiceSubtitle: "音声アクセスを有効化し、デーモンを起動してフローティングウィジェットを開きます。",
            .voiceDaemonTitle: "音声デーモン",
            .voiceDaemonNote: "デーモンはゲートウェイ LLM に接続し、リアルタイム音声をストリーミングします。",
            .micSpeechTitle: "マイク + 音声認識",
            .accessGranted: "アクセス許可済み",
            .needsAccess: "許可が必要",
            .grantAccess: "許可する",
            .voiceCanListen: "リアルタイムで聴取・文字起こしできます。",
            .voiceNeedsAccess: "音声ウェイクとリアルタイム文字起こしに必要です。",
            .voiceWidgetTitle: "音声ウィジェット",
            .openVoiceWidget: "音声ウィジェットを開く",
            .autoShowOnSpeech: "発話時に自動表示",
            .widgetLanguage: "ウィジェット言語",
            .widgetFloatingNote: "ウィジェットは常にフローティングし、最後の位置を記憶します。",
            .voiceDaemonStopped: "停止",
            .voiceDaemonStarting: "起動中…",
            .voiceDaemonRunning: "実行中",
            .voiceDaemonRunningDetails: "実行中（%@）",
            .voiceDaemonFailed: "失敗",
            .voiceDaemonFailedDetails: "失敗（%@）",
            .voiceDaemonRestart: "音声デーモンを再起動",
            .voiceDaemonRetry: "音声デーモンを再試行",
            .installCliTitle: "CLI をインストール",
            .installCliSubtitle: "ローカルモードに必要です。`openclaw` をインストールして launchd がゲートウェイを起動できるようにします。",
            .reinstallCli: "CLI を再インストール",
            .installCli: "CLI をインストール",
            .copied: "コピー済み",
            .copyInstallCommand: "インストールコマンドをコピー",
            .installedAt: "インストール先: %@",
            .cliInstallNote: """
            ユーザー領域の Node 22+ ランタイムと CLI をインストールします（Homebrew 不要）。
            いつでも再実行して再インストール／更新できます。
            """,
            .workspaceTitle: "エージェントのワークスペース",
            .workspaceSubtitle: "MyCatCat は専用のワークスペースでエージェントを実行し、`AGENTS.md` の読み込みやファイル書き込みを他のプロジェクトから分離します。",
            .remoteGatewayDetected: "リモートゲートウェイを検出",
            .remoteGatewayNote: "リモートホスト上でワークスペースを作成してください（先に SSH で接続）。macOS アプリはまだ SSH 経由の書き込みに対応していません。",
            .copySetupCommand: "セットアップコマンドをコピー",
            .workspaceFolder: "ワークスペースフォルダ",
            .createWorkspace: "ワークスペースを作成",
            .openFolder: "フォルダを開く",
            .saveInConfig: "設定に保存",
            .workspaceSaved: "保存先: ~/.openclaw/openclaw.json（agents.defaults.workspace）",
            .workspaceTip: "ヒント: このフォルダの AGENTS.md を編集して助手の振る舞いを調整できます。バックアップには、ワークスペースをプライベート Git リポジトリにして「記憶」をバージョン管理するのがおすすめです。",
            .meetAgentTitle: "エージェントに会う",
            .meetAgentSubtitle: "これは専用のオンボーディングチャットです。エージェントが自己紹介し、あなたのことを学び、必要なら WhatsApp / Telegram の接続を手伝います。",
            .onboardingChatPrompt: "こんにちは！MyCatCat をインストールしたばかりで、あなたが新しいエージェントです。まず BOOTSTRAP.md の初回手順を始めてください。質問は一度に一つずつ。WhatsApp/Telegram の話に入る前に、soul.md を一緒に確認して SOUL.md を作成してください。私が大切にしていることと、あなたがどのように振る舞うべきかを聞いてください。その後、会話方法（Web のみ／WhatsApp／Telegram）を選ぶよう案内してください。",
            .allSetTitle: "準備完了",
            .configureLaterReadyTitle: "後で設定",
            .configureLaterReadySubtitle: "準備ができたら 設定 → 一般 でローカル／リモートを選択してください。",
            .remoteChecklistTitle: "リモートゲートウェイのチェックリスト",
            .remoteChecklistSubtitle: "ゲートウェイ側で `openclaw` パッケージをインストール／更新し、認証情報（通常 `~/.openclaw/credentials/oauth.json`）があることを確認してください。必要なら再接続します。",
            .openMenuBarTitle: "メニューバーパネルを開く",
            .openMenuBarSubtitle: "メニューバーの MyCatCat アイコンをクリックして、簡易チャットと状態確認を行います。",
            .connectChannelsTitle: "WhatsApp / Telegram を接続",
            .connectChannelsSubtitle: "設定 → チャンネル を開き、連携と状態確認を行います。",
            .openSettingsChannels: "設定 → チャンネル を開く",
            .tryVoiceWakeTitle: "音声ウェイクを試す",
            .tryVoiceWakeSubtitle: "設定で音声ウェイクを有効にすると、ハンズフリー操作とリアルタイム文字起こしが使えます。",
            .panelCanvasTitle: "パネル + Canvas を使う",
            .panelCanvasSubtitle: "メニューバーパネルで素早くチャットできます。Canvas ではより豊かなビジュアルを表示できます。",
            .morePowersTitle: "助手にさらに能力を付与",
            .morePowersSubtitle: "設定 → Skills でオプション技能（Peekaboo、oracle、camsnap…）を有効化できます。",
            .openSettingsSkills: "設定 → Skills を開く",
            .launchAtLogin: "ログイン時に起動",
            .skillsIncluded: "含まれるスキル",
            .couldntLoadSkillsTitle: "ゲートウェイからスキルを取得できませんでした。",
            .couldntLoadSkillsBody: "ゲートウェイが起動・接続されていることを確認し、更新を押してください（または 設定 → Skills を開いてください）。",
            .detailsPrefix: "詳細: %@",
            .noSkillsYet: "まだスキルが報告されていません。",
            .setupWizardTitle: "セットアップウィザード",
            .setupWizardSubtitle: "ゲートウェイのガイドに従って設定します。CLI とオンボーディングを同期できます。",
            .wizardError: "ウィザードエラー",
            .retry: "再試行",
            .startingWizard: "ウィザードを開始中…",
            .wizardComplete: "ウィザード完了。次のステップへ進んでください。",
            .waitingWizard: "ウィザードを待機中…",
            .gatewayDepsInstallingTitle: "必要コンポーネントを自動インストール中…",
            .gatewayDepsInstallingSubtitle: "初回起動は 1〜2 分かかることがあります。ウィンドウを閉じずにお待ちください。",
            .wizardUnsupportedStep: "未対応のステップタイプ",
            .wizardRun: "実行",
            .wizardContinue: "続行",
        ],
    ]

    static func text(_ key: OnboardingCopyKey, lang: OnboardingLanguage) -> String {
        if let value = table[lang]?[key] {
            return value
        }
        if let fallback = table[.en]?[key] {
            return fallback
        }
        return key.rawValue
    }

    static func text(_ key: OnboardingCopyKey) -> String {
        text(key, lang: OnboardingLanguage.fromDefaults())
    }
}

extension OnboardingView {
    var onboardingLanguage: OnboardingLanguage {
        OnboardingLanguage(rawValue: self.onboardingLanguageRaw) ?? OnboardingLanguage.preferredDefault()
    }

    func ensureOnboardingLanguage() {
        if OnboardingLanguage(rawValue: self.onboardingLanguageRaw) == nil {
            self.onboardingLanguageRaw = OnboardingLanguage.preferredDefault().rawValue
        }
    }

    func t(_ key: OnboardingCopyKey) -> String {
        OnboardingCopy.text(key, lang: self.onboardingLanguage)
    }

    func tf(_ key: OnboardingCopyKey, _ args: CVarArg...) -> String {
        let format = self.t(key)
        return String(format: format, locale: Locale(identifier: self.onboardingLanguage.rawValue), arguments: args)
    }
}

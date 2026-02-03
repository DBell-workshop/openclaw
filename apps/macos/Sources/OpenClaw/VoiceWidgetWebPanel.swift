import AppKit
import Foundation
import WebKit

@MainActor
final class VoiceWidgetWebPanelController {
    static let shared = VoiceWidgetWebPanelController()

    private var panel: NSPanel?
    private var webView: WKWebView?
    private var moveObserver: NSObjectProtocol?
    private var resizeObserver: NSObjectProtocol?

    private let panelSize = NSSize(width: 340, height: 520)

    func toggle() {
        if self.isVisible {
            self.close()
        } else {
            self.show()
        }
    }

    var isVisible: Bool {
        self.panel?.isVisible ?? false
    }

    func show() {
        self.ensurePanel()
        self.restoreFrameIfNeeded()
        self.loadIfNeeded()
        self.panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UserDefaults.standard.set(true, forKey: voiceWidgetVisibleKey)
    }

    func close() {
        self.panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: voiceWidgetVisibleKey)
    }

    private func ensurePanel() {
        if self.panel != nil { return }
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: self.panelSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = NSWindow.Level.floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container

        self.webView = webView
        self.panel = panel
        self.installFrameObservers(for: panel)
    }

    private func loadIfNeeded() {
        guard let webView else { return }
        let raw = UserDefaults.standard.string(forKey: voiceWidgetUrlKey) ?? "http://localhost:5173"
        guard let url = URL(string: raw) else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    private func installFrameObservers(for panel: NSPanel) {
        let center = NotificationCenter.default
        self.moveObserver = center.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.storeFrame(panel.frame)
        }
        self.resizeObserver = center.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.storeFrame(panel.frame)
        }
    }

    private func restoreFrameIfNeeded() {
        guard let panel else { return }
        if let raw = UserDefaults.standard.string(forKey: voiceWidgetFrameKey) {
            let restored = NSRectFromString(raw)
            if restored.width > 0, restored.height > 0 {
                panel.setFrame(restored, display: false)
                WindowPlacement.ensureOnScreen(
                    window: panel,
                    defaultSize: self.panelSize,
                    fallback: { screen in
                        WindowPlacement.topRightFrame(size: self.panelSize, padding: 16, on: screen)
                    })
                return
            }
        }
        let fallback = WindowPlacement.topRightFrame(size: self.panelSize, padding: 16)
        panel.setFrame(fallback, display: false)
    }

    private func storeFrame(_ frame: NSRect) {
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: voiceWidgetFrameKey)
    }
}

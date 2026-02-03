import AppKit
import Foundation
import WebKit

@MainActor
final class VoiceWidgetWebPanelController {
    static let shared = VoiceWidgetWebPanelController()

    private var panel: NSPanel?
    private var webView: WKWebView?

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
        self.loadIfNeeded()
        self.panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        self.panel?.orderOut(nil)
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
    }

    private func loadIfNeeded() {
        guard let webView else { return }
        let raw = UserDefaults.standard.string(forKey: voiceWidgetUrlKey) ?? "http://localhost:5173"
        guard let url = URL(string: raw) else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

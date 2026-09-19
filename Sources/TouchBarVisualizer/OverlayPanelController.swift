import AppKit
import WebKit

final class OverlayPanelController {
    private let panel: NSPanel
    private let webView: WKWebView
    private var lastSend: TimeInterval = 0
    private let minInterval: TimeInterval = 1.0 / 60.0 // caps evaluateJavaScript rate

    // Hotkey toggle "pins" the panel open, overriding the idle auto-hide below.
    private var isPinned = false
    private var hideWorkItem: DispatchWorkItem?
    private let idleHideDelay: TimeInterval = 1.5
    private let actionHideDelay: TimeInterval = 2.5

    init() {
        let barSize = NSRect(x: 0, y: 0, width: 680, height: 118)
        let webView = WKWebView(frame: barSize)
        webView.setValue(false, forKey: "drawsBackground") // let the CSS transparent background show through
        self.webView = webView

        let panel = NSPanel(
            contentRect: barSize,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.contentView = webView
        self.panel = panel

        loadOverlay()
        positionPanel()
    }

    private func loadOverlay() {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "overlay") else {
            NSLog("TouchBarVisualizer: overlay resources missing from bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Hotkey-driven: pins the panel open regardless of touch activity, or closes it.
    func toggle() {
        hideWorkItem?.cancel()
        if panel.isVisible {
            isPinned = false
            panel.orderOut(nil)
        } else {
            isPinned = true
            positionPanel()
            panel.orderFrontRegardless()
        }
    }

    /// Must be called on the main thread.
    func sendTouch(x: Float, active: Bool) {
        if active {
            revealPanel(hideAfter: idleHideDelay)
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSend >= minInterval else { return }
        lastSend = now
        let js = "window.onTouchPosition && window.onTouchPosition({x: \(x), active: \(active)});"
        webView.evaluateJavaScript(js)
    }

    /// A recognized brightness/volume/media-style action was pressed. Shown
    /// as a text label, held a bit longer than a plain touch since it's meant
    /// to be read, not just glanced at.
    func sendAction(_ label: String) {
        revealPanel(hideAfter: actionHideDelay)
        let escaped = label.replacingOccurrences(of: "\"", with: "\\\"")
        webView.evaluateJavaScript("window.onAction && window.onAction(\"\(escaped)\");")
    }

    /// Shows the panel (if hidden) and (re)schedules the idle auto-hide,
    /// unless pinned open via the hotkey.
    private func revealPanel(hideAfter delay: TimeInterval) {
        if !panel.isVisible {
            positionPanel()
            panel.orderFrontRegardless()
        }

        hideWorkItem?.cancel()
        guard !isPinned else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPinned else { return }
            self.panel.orderOut(nil)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

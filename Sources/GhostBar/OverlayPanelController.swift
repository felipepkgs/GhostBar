import AppKit
import WebKit

final class OverlayPanelController: NSObject {
    private let panel: NSPanel
    private let webView: WKWebView
    private var lastSend: TimeInterval = 0
    private let minInterval: TimeInterval = 1.0 / 60.0 // caps evaluateJavaScript rate

    // Hotkey toggle "pins" the panel open, overriding the idle auto-hide below.
    private var isPinned = false
    private var hideWorkItem: DispatchWorkItem?
    private let idleHideDelay: TimeInterval = 1.5
    private let actionHideDelay: TimeInterval = 2.5

    private let showAnimDuration: TimeInterval = 0.22
    private let hideAnimDuration: TimeInterval = 0.28

    private static let originDefaultsKey = "GhostBar.panelOrigin"

    override init() {
        let barSize = NSRect(x: 0, y: 0, width: 680, height: 118)

        // A real NSVisualEffectView gives the panel genuine macOS frosted
        // glass reading the desktop behind it — CSS backdrop-filter alone
        // can't do this over a fully transparent window, since there's no
        // rendered content behind the page for the compositor to blur.
        let glass = NSVisualEffectView(frame: barSize)
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 22
        glass.layer?.masksToBounds = true
        glass.layer?.borderWidth = 1
        glass.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor

        let webView = WKWebView(frame: glass.bounds)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground") // let the glass show through the page
        self.webView = webView
        glass.addSubview(webView)

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
        panel.contentView = glass
        self.panel = panel

        super.init()

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification, object: panel
        )

        loadOverlay()
        positionPanel()
    }

    /// Remembers a manually dragged position across launches; otherwise
    /// centers low on the main screen, roughly under the physical Touch Bar.
    @objc private func panelDidMove() {
        let origin = panel.frame.origin
        UserDefaults.standard.set(
            "\(origin.x),\(origin.y)", forKey: Self.originDefaultsKey
        )
    }

    private func loadOverlay() {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "overlay") else {
            NSLog("GhostBar: overlay resources missing from bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func positionPanel() {
        if let saved = UserDefaults.standard.string(forKey: Self.originDefaultsKey) {
            let parts = saved.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                let origin = NSPoint(x: parts[0], y: parts[1])
                let candidate = NSRect(origin: origin, size: panel.frame.size)
                // Checked against every connected screen, not just the
                // built-in one below — a saved drag position should still
                // be honored wherever it currently lands.
                if NSScreen.screens.contains(where: { $0.frame.intersects(candidate) }) {
                    panel.setFrameOrigin(origin)
                    return
                }
            }
        }

        // Default placement anchors to the built-in display specifically —
        // the physical Touch Bar lives there, not on whichever screen macOS
        // currently considers "main" (which follows keyboard focus and can
        // be an external monitor).
        guard let screen = builtInScreen() ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
        }
    }

    /// Hotkey-driven: pins the panel open regardless of touch activity, or closes it.
    func toggle() {
        hideWorkItem?.cancel()
        if panel.isVisible {
            isPinned = false
            fadeOut()
        } else {
            isPinned = true
            positionPanel()
            fadeIn()
        }
    }

    private func fadeIn() {
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = showAnimDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = hideAnimDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.panel.alphaValue == 0 else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        })
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
            fadeIn()
        }

        hideWorkItem?.cancel()
        guard !isPinned else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPinned else { return }
            self.fadeOut()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

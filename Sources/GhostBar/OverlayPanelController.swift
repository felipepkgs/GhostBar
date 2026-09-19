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
    // Read live from Settings (Preferences) rather than cached at init, so a
    // change takes effect on the very next touch/action without a relaunch.
    private var idleHideDelay: TimeInterval { Settings.idleHideDelay }
    private var actionHideDelay: TimeInterval { Settings.actionHideDelay }

    private let showAnimDuration: TimeInterval = 0.22
    private let hideAnimDuration: TimeInterval = 0.28

    private static let originDefaultsKey = "GhostBar.panelOrigin"

    // NSWindow.didMoveNotification fires for both a real user drag AND our
    // own positionPanel() calling setFrameOrigin — without this flag,
    // positionPanel()'s very first auto-placement got immediately saved as
    // if the user had dragged it there, and every subsequent call took the
    // "saved position" early-return path forever, freezing the panel on
    // whatever screen it first happened to appear on (cursorScreen()/
    // builtInScreen() never ran again after that).
    private var isRepositioningProgrammatically = false

    // The screen positionPanel() last placed the panel on — compared against
    // the cursor's current screen on every touch tick so the panel follows
    // live as you move to another monitor, instead of only re-resolving at
    // the start of a new gesture (which meant lifting your finger and
    // waiting for a fade before a screen change took effect).
    private var currentScreen: NSScreen?

    private let stripReader = ControlStripReader()

    // Sized for one row (only one is ever shown now — see setMode in app.js)
    // plus #stack's padding; was 118 back when both rows stacked visibly at
    // once. Preferences' "Panel size" scales this — see applyPanelSize().
    private static let baseSize = NSSize(width: 680, height: 82)

    override init() {
        let barSize = NSRect(origin: .zero, size: Self.baseSize)

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
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )

        loadOverlay()
        positionPanel()
    }

    /// Remembers a manually dragged position across launches; otherwise
    /// centers low on the main screen, roughly under the physical Touch Bar.
    /// Ignores moves positionPanel() made itself — see
    /// isRepositioningProgrammatically's comment.
    @objc private func panelDidMove() {
        guard !isRepositioningProgrammatically else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set(
            "\(origin.x),\(origin.y)", forKey: Self.originDefaultsKey
        )
    }

    private func setPanelOrigin(_ origin: NSPoint) {
        isRepositioningProgrammatically = true
        panel.setFrameOrigin(origin)
        isRepositioningProgrammatically = false
    }

    /// Without this, switching apps while the panel is already visible (or
    /// mid idle-hide countdown — still `isVisible` until it fully fades)
    /// left the stale mode/layout on screen until the panel closed and
    /// reopened. refreshLiveLayout is also called in fadeIn(), so this only
    /// needs to cover the "already showing" case.
    @objc private func frontmostAppChanged() {
        guard panel.isVisible else { return }
        refreshLiveLayout()
    }

    private func loadOverlay() {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "overlay") else {
            NSLog("GhostBar: overlay resources missing from bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    /// Always resolves the screen fresh (cursor's screen wins, falling back
    /// to the built-in display then NSScreen.main) — the panel is glued to
    /// wherever the user is actually looking, not pinned to whichever screen
    /// it first happened to appear on. A manually dragged position is only
    /// honored when it lands on THAT resolved screen, so dragging on one
    /// monitor can't freeze the panel there once the cursor moves to another.
    private func positionPanel() {
        applyPanelSize()

        guard let screen = cursorScreen() ?? builtInScreen() ?? NSScreen.main else { return }
        currentScreen = screen

        if let saved = UserDefaults.standard.string(forKey: Self.originDefaultsKey) {
            let parts = saved.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                let origin = NSPoint(x: parts[0], y: parts[1])
                let candidate = NSRect(origin: origin, size: panel.frame.size)
                if screen.frame.intersects(candidate) {
                    setPanelOrigin(origin)
                    return
                }
            }
        }

        let frame = screen.visibleFrame
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + 60
        setPanelOrigin(NSPoint(x: x, y: y))
    }

    /// Applies Preferences' panel-size scale, resized around the panel's
    /// current center — positionPanel() re-derives the real origin right
    /// after this runs anyway, so keeping the center is just a reasonable
    /// starting point, not the final placement. contentView (the glass) and
    /// the web view both auto-resize to match via their autoresizing masks.
    private func applyPanelSize() {
        let scale = CGFloat(Settings.panelScale)
        let newSize = NSSize(width: Self.baseSize.width * scale, height: Self.baseSize.height * scale)
        guard panel.frame.size != newSize else { return }

        let old = panel.frame
        let newOrigin = NSPoint(x: old.midX - newSize.width / 2, y: old.midY - newSize.height / 2)
        isRepositioningProgrammatically = true
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
        isRepositioningProgrammatically = false
    }

    /// Re-resolves the cursor's screen and repositions only if it actually
    /// differs from where the panel currently sits — called on every touch
    /// tick so the panel tracks the cursor live, without doing the full
    /// UserDefaults/screen-matching work on every single call.
    private func repositionIfScreenChanged() {
        guard cursorScreen() ?? builtInScreen() ?? NSScreen.main !== currentScreen else { return }
        positionPanel()
    }

    private func cursorScreen() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
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
        refreshLiveLayout()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        let restingAlpha = CGFloat(Settings.panelOpacity)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = showAnimDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = restingAlpha
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

    /// Preferences' "Reset Position" — forgets any manually dragged spot and
    /// re-centers on the cursor's current screen.
    func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.originDefaultsKey)
        positionPanel()
    }

    /// Preferences' "Preview" — shows the panel with whatever draft
    /// size/opacity/hide-delay is currently set, without needing the
    /// physical Touch Bar. Forces a fresh fadeIn even if already visible, so
    /// a changed setting is actually reflected rather than silently no-op'd
    /// by fadeIn's `!panel.isVisible` guard.
    func preview() {
        if panel.isVisible {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
        revealPanel(hideAfter: 3.0)
    }

    /// Must be called on the main thread.
    func sendTouch(x: Float, active: Bool) {
        if active {
            repositionIfScreenChanged()
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
        repositionIfScreenChanged()
        revealPanel(hideAfter: actionHideDelay)
        let escaped = label.replacingOccurrences(of: "\"", with: "\\\"")
        webView.evaluateJavaScript("window.onAction && window.onAction(\"\(escaped)\");")
    }

    /// Shows the panel (if hidden) and (re)schedules the idle auto-hide,
    /// unless pinned open via the hotkey. Screen tracking itself now happens
    /// in repositionIfScreenChanged(), called on every touch tick regardless
    /// of visibility — this just handles the fade and the hide timer.
    private func revealPanel(hideAfter delay: TimeInterval) {
        if !panel.isVisible {
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

    /// Re-reads the user's real Control Strip layout and current
    /// presentation mode and pushes both to the page. Called right before
    /// every show rather than continuously — see ControlStripReader's
    /// header comment for why that's sufficient.
    private func refreshLiveLayout() {
        let items = stripReader.currentStripItems()
        let mode = stripReader.currentMode(frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

        if let itemsJSON = Self.encode(items) {
            webView.evaluateJavaScript("window.setControlStrip && window.setControlStrip(\(itemsJSON));")
        }
        let modeLiteral = mode == .functionKeys ? "functionKeys" : "controlStrip"
        webView.evaluateJavaScript("window.setMode && window.setMode(\"\(modeLiteral)\");")
    }

    private struct JSONIcon: Encodable {
        let type: String // "emoji" | "image" | "image-small"
        let value: String
    }

    private struct JSONStripItem: Encodable {
        let kind: String
        let icons: [JSONIcon]
    }

    private static func encodeIcon(_ icon: ControlStripReader.Icon) -> JSONIcon {
        switch icon {
        case .emoji(let value): return JSONIcon(type: "emoji", value: value)
        case .image(let filename): return JSONIcon(type: "image", value: filename)
        case .imageSmall(let filename): return JSONIcon(type: "image-small", value: filename)
        }
    }

    private static func encode(_ items: [ControlStripReader.ItemKind]) -> String? {
        let encodable: [JSONStripItem] = items.map { item in
            switch item {
            case .single(let icon):
                return JSONStripItem(kind: "single", icons: [encodeIcon(icon)])
            case .group(let icons):
                return JSONStripItem(kind: "group", icons: icons.map(encodeIcon))
            case .flexibleSpace:
                return JSONStripItem(kind: "space", icons: [])
            }
        }
        guard let data = try? JSONEncoder().encode(encodable) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

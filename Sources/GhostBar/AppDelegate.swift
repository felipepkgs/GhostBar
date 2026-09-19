import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var loginItem: NSMenuItem!
    private let overlay = OverlayPanelController()
    private let touchReader = TouchPositionReader.shared
    private let actionReader = ActionKeyReader()
    private let hotkeys = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicateInstanceRunning() else {
            NSLog("GhostBar: another instance is already running — quitting this one")
            NSApp.terminate(nil)
            return
        }

        setupStatusItem()

        touchReader.onTouch = { [weak self] x, active in
            self?.overlay.sendTouch(x: x, active: active)
        }
        touchReader.start()

        actionReader.onAction = { [weak self] label in
            self?.overlay.sendAction(label)
        }
        actionReader.start()

        hotkeys.onToggle = { [weak self] in
            self?.overlay.toggle()
        }
        hotkeys.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchReader.stop()
        actionReader.stop()
        hotkeys.unregister()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.and.hand.point.up.left.filled",
            accessibilityDescription: "GhostBar"
        )

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Overlay (⌃⌥⌘T)", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleOverlay() {
        overlay.toggle()
    }

    /// Guards against two instances registering the same global hotkey and
    /// event monitors at once (happened during development: a `swift build`
    /// debug run left running alongside the bundled .app).
    /// ponytail: `swift run` has no bundle identifier, so that path falls
    /// back to matching by process name — a false positive is only possible
    /// against another unrelated process that happens to share the same
    /// name, an acceptable ceiling for a dev-only code path.
    private func isDuplicateInstanceRunning() -> Bool {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier != myPID }

        if let bundleID = Bundle.main.bundleIdentifier {
            return others.contains { $0.bundleIdentifier == bundleID }
        }
        let myName = ProcessInfo.processInfo.processName
        return others.contains { $0.localizedName == myName }
    }

    /// Only takes effect when running as the bundled GhostBar.app (built via
    /// Scripts/build_app.sh) — SMAppService needs a real app bundle identity
    /// to register a login item against. Under `swift run` this will log an
    /// error and no-op rather than crash.
    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } catch {
            NSLog("GhostBar: login item toggle failed (expected under `swift run`): \(error)")
        }
    }
}

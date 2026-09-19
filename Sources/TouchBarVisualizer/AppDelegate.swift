import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let overlay = OverlayPanelController()
    private let touchReader = TouchPositionReader.shared
    private let actionReader = ActionKeyReader()
    private let hotkeys = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            systemSymbolName: "hand.point.up.left",
            accessibilityDescription: "Touch Bar Visualizer"
        )

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Overlay (⌃⌥⌘T)", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleOverlay() {
        overlay.toggle()
    }
}

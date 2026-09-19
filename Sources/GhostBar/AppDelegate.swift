import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var loginItem: NSMenuItem!
    private let overlay = OverlayPanelController()
    private let touchReader = TouchPositionReader.shared
    private let actionReader = ActionKeyReader()
    private let hotkeys = HotkeyManager()
    private var preferencesWindow: SwiftUIWindowController<PreferencesView>?
    private var onboardingWindow: SwiftUIWindowController<OnboardingView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isDuplicateInstanceRunning() else {
            NSLog("GhostBar: another instance is already running — quitting this one")
            NSApp.terminate(nil)
            return
        }

        setupStatusItem()
        showOnboardingIfNeeded()
        UpdateChecker.checkOnLaunch { [weak self] release in
            guard let release else { return }
            self?.presentUpdateAvailable(release)
        }

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
        // Icons8 "Glyph Neue" ghost glyph (Resources/statusbar/) — on-theme
        // with the app's name. Template mode lets AppKit recolor it for the
        // light/dark menu bar automatically, same as an SF Symbol would.
        // Bundle.image(forResource:) only searches the bundle's top-level
        // Resources/, not subdirectories — needs the explicit lookup, same
        // as loadOverlay()'s subdirectory: "overlay" below.
        if let url = Bundle.module.url(forResource: "ghost-icon", withExtension: "png", subdirectory: "statusbar"),
           let icon = NSImage(contentsOf: url) {
            icon.isTemplate = true
            icon.size = NSSize(width: 18, height: 18)
            icon.accessibilityDescription = "GhostBar"
            statusItem.button?.image = icon
        } else {
            NSLog("GhostBar: status bar icon missing from bundle")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Overlay (⌃⌥⌘T)", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesNow), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About GhostBar", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func toggleOverlay() {
        overlay.toggle()
    }

    @objc private func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = SwiftUIWindowController(
                title: "GhostBar Preferences",
                content: PreferencesView(overlay: overlay)
            )
        }
        preferencesWindow?.show()
    }

    private func showOnboardingIfNeeded() {
        guard !Settings.hasOnboarded else { return }
        let controller = SwiftUIWindowController(
            title: "Welcome",
            content: OnboardingView { [weak self] in
                Settings.hasOnboarded = true
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        )
        onboardingWindow = controller
        controller.show()
    }

    @objc private func checkForUpdatesNow() {
        UpdateChecker.checkNow { [weak self] release in
            guard let self else { return }
            guard let release else {
                let alert = NSAlert()
                alert.messageText = "You're up to date"
                alert.informativeText = "GhostBar \(AppVersion.current) is the latest version."
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
                return
            }
            self.presentUpdateAvailable(release)
        }
    }

    private func presentUpdateAvailable(_ release: UpdateChecker.Release) {
        let alert = NSAlert()
        alert.messageText = "GhostBar \(release.tagName) is available"
        alert.informativeText = "You're on \(AppVersion.current). Installed via Homebrew? Just run `brew upgrade`. Otherwise, grab the new build from the release page."
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: release.htmlURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Required placement for the Icons8 free-license attribution (Control
    /// Strip icons in Resources/overlay/icons/) — see also README's Credits
    /// section, the license's other allowed placement.
    @objc private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Touch Bar icons by ",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        credits.append(NSAttributedString(
            string: "Icons8",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: URL(string: "https://icons8.com")!,
            ]
        ))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
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

    @objc private func toggleLoginItem() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }
}

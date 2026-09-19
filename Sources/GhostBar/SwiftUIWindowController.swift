import AppKit
import SwiftUI

/// Minimal NSWindowController wrapper for hosting a SwiftUI view as its own
/// window — shared by Preferences and the first-launch onboarding dialog so
/// neither has to hand-roll NSWindow setup.
final class SwiftUIWindowController<Content: View>: NSWindowController, NSWindowDelegate {
    private var onClose: (() -> Void)?

    convenience init(title: String, content: Content, onClose: (() -> Void)? = nil) {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        self.onClose = onClose
        window.delegate = self
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

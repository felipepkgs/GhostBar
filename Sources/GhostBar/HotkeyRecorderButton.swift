import SwiftUI
import AppKit
import Carbon

/// AppKit-backed, not SwiftUI @State — this toolchain (CommandLineTools
/// only, no Xcode.app) can't resolve @State's macro plugin for SPM builds
/// (see OnboardingView/PreferencesView). "Press keys…" recording feedback
/// is handled imperatively via a plain NSButton instead.
struct HotkeyRecorderButton: NSViewRepresentable {
    let hotkeys: HotkeyManager

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            title: HotkeyManager.currentDescription,
            target: context.coordinator,
            action: #selector(Coordinator.startRecording)
        )
        button.bezelStyle = .rounded
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(hotkeys: hotkeys)
    }

    final class Coordinator: NSObject {
        private let hotkeys: HotkeyManager
        weak var button: NSButton?
        private var monitor: Any?

        init(hotkeys: HotkeyManager) {
            self.hotkeys = hotkeys
        }

        @objc func startRecording() {
            button?.title = "Press keys… (Esc to cancel)"
            // Local monitor: only fires while GhostBar itself is key, which
            // is exactly the Preferences-window-focused context this runs
            // in — no need for a global monitor (or Accessibility trust)
            // just to capture the next key combo.
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }

                if event.keyCode == UInt16(kVK_Escape) {
                    self.finishRecording()
                    return nil
                }

                var modifiers: UInt32 = 0
                if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
                if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
                if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
                if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }

                // Require at least one modifier — a bare letter key would
                // make GhostBar's shortcut swallow ordinary typing.
                guard modifiers != 0 else { return nil }

                Settings.setHotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                self.hotkeys.reregister()
                self.finishRecording()
                return nil
            }
        }

        private func finishRecording() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            button?.title = HotkeyManager.currentDescription
        }
    }
}

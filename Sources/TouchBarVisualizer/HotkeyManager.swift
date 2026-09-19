import Carbon
import AppKit

/// Global toggle shortcut, hand-rolled via Carbon instead of a library.
/// ponytail: macOS Sequoia+ rejects hotkeys using ONLY Option or Option+Shift
/// as modifiers (-9868 eventInternalErr). Default combo includes Cmd, which
/// is unaffected — if a future OS also restricts Cmd combos, switch to
/// sindresorhus/KeyboardShortcuts instead of chasing Carbon workarounds.
final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue().onToggle?()
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(1), id: 1)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        RegisterEventHotKey(UInt32(kVK_ANSI_T), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

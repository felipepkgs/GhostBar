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
    private var handlerInstalled = false

    static var defaultKeyCode: UInt32 { UInt32(kVK_ANSI_T) }
    static var defaultModifiers: UInt32 { UInt32(controlKey | optionKey | cmdKey) }

    func register() {
        if !handlerInstalled {
            installEventHandler()
            handlerInstalled = true
        }

        let keyCode = Settings.hotkeyKeyCode ?? Self.defaultKeyCode
        let modifiers = Settings.hotkeyModifiers ?? Self.defaultModifiers
        let hotKeyID = EventHotKeyID(signature: OSType(1), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    /// Preferences' hotkey recorder calls this right after saving a new
    /// combo — unregisters the old key/modifier pair and registers the new
    /// one, without reinstalling the (process-wide, only-needed-once) event
    /// handler itself.
    func reregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        register()
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    private func installEventHandler() {
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
    }

    // MARK: - Display

    static var currentDescription: String {
        describe(
            keyCode: Settings.hotkeyKeyCode ?? defaultKeyCode,
            modifiers: Settings.hotkeyModifiers ?? defaultModifiers
        )
    }

    static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        symbols += keyName(keyCode)
        return symbols
    }

    // Covers the realistic range of hotkey choices (letters, digits,
    // function keys, a few named keys) — anything outside this falls back
    // to a raw code rather than chasing full keyboard-layout translation
    // for a display label.
    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5", UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space", UInt32(kVK_Tab): "Tab", UInt32(kVK_Return): "Return",
        UInt32(kVK_Delete): "Delete", UInt32(kVK_Escape): "Esc",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
    ]

    private static func keyName(_ code: UInt32) -> String {
        keyNames[code] ?? "Key \(code)"
    }
}

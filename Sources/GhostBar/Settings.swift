import Foundation

/// UserDefaults keys shared between Settings (Swift-side reads) and
/// PreferencesView (@AppStorage writes) — one source of truth for both.
enum SettingsKey {
    static let idleHideDelay = "GhostBar.idleHideDelay"
    static let actionHideDelay = "GhostBar.actionHideDelay"
    static let panelScale = "GhostBar.panelScale"
    static let panelOpacity = "GhostBar.panelOpacity"
    static let hasOnboarded = "GhostBar.hasOnboarded"
    static let lastUpdateCheck = "GhostBar.lastUpdateCheck"
    static let hotkeyKeyCode = "GhostBar.hotkeyKeyCode"
    static let hotkeyModifiers = "GhostBar.hotkeyModifiers"
    static let panelTheme = "GhostBar.panelTheme"
}

/// Read-side for OverlayPanelController. Defaults are inlined here rather
/// than via UserDefaults.register(defaults:) — that call would need to run
/// before OverlayPanelController's own property initializers, which is
/// ordering-fragile; a nil-coalesced fallback isn't.
enum Settings {
    static var idleHideDelay: Double {
        UserDefaults.standard.object(forKey: SettingsKey.idleHideDelay) as? Double ?? 1.5
    }

    static var actionHideDelay: Double {
        UserDefaults.standard.object(forKey: SettingsKey.actionHideDelay) as? Double ?? 2.5
    }

    static var panelScale: Double {
        UserDefaults.standard.object(forKey: SettingsKey.panelScale) as? Double ?? 1.0
    }

    static var panelOpacity: Double {
        UserDefaults.standard.object(forKey: SettingsKey.panelOpacity) as? Double ?? 1.0
    }

    static var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: SettingsKey.hasOnboarded) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKey.hasOnboarded) }
    }

    // nil (unset) means "use HotkeyManager's built-in default" — kept as
    // plain Int/UInt32 here rather than importing Carbon just for two
    // constants; HotkeyManager (which already imports Carbon) owns the
    // actual default values and the recorded-combo -> display-string logic.
    static var hotkeyKeyCode: UInt32? {
        (UserDefaults.standard.object(forKey: SettingsKey.hotkeyKeyCode) as? Int).map(UInt32.init)
    }

    static var hotkeyModifiers: UInt32? {
        (UserDefaults.standard.object(forKey: SettingsKey.hotkeyModifiers) as? Int).map(UInt32.init)
    }

    static func setHotkey(keyCode: UInt32, modifiers: UInt32) {
        UserDefaults.standard.set(Int(keyCode), forKey: SettingsKey.hotkeyKeyCode)
        UserDefaults.standard.set(Int(modifiers), forKey: SettingsKey.hotkeyModifiers)
    }

    static var panelTheme: PanelTheme {
        PanelTheme(rawValue: UserDefaults.standard.string(forKey: SettingsKey.panelTheme) ?? "") ?? .vapor
    }
}

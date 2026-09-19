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
}

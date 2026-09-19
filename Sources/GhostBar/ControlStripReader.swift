import AppKit

/// Reads the user's REAL Control Strip customization and current Touch Bar
/// mode, instead of guessing. Both live in ordinary (if undocumented)
/// per-user preference domains, readable via public CFPreferences API — no
/// private framework, no shelling out to `defaults read`.
///
/// ponytail: no file-watcher/Darwin-notification subscription here — these
/// reads are cheap, and correctness only matters at the moment the panel is
/// about to show. OverlayPanelController re-reads right before every
/// fade-in instead, which makes a live-update mechanism unnecessary.
final class ControlStripReader {
    private let stripDomain = "com.apple.controlstrip" as CFString
    private let agentDomain = "com.apple.touchbar.agent" as CFString

    enum ItemKind {
        case single(icon: String)
        case group(icons: [String])
        case flexibleSpace
    }

    enum Mode {
        case functionKeys
        case controlStrip
    }

    // Apple's stock default order, used when the user has never customized
    // their Control Strip (i.e. the "FullCustomized" key is simply absent).
    private static let defaultOrder = [
        "com.apple.system.group.brightness",
        "com.apple.system.mission-control",
        "com.apple.system.launchpad",
        "com.apple.system.group.keyboard-brightness",
        "com.apple.system.group.media",
        "com.apple.system.group.volume",
        "com.apple.system.siri",
    ]

    // Identifier -> render info, reverse-engineered from ControlStrip.app's
    // string table. Icons stay emoji to match the overlay's existing visual
    // style — ponytail: swap for SF Symbol images if the overlay ever moves
    // off inline emoji text.
    private static let knownItems: [String: ItemKind] = [
        "com.apple.system.group.brightness": .group(icons: ["🔅", "🔆"]),
        "com.apple.system.group.keyboard-brightness": .group(icons: ["⌨−", "⌨+"]),
        "com.apple.system.group.media": .group(icons: ["⏪", "⏯", "⏩"]),
        "com.apple.system.group.volume": .group(icons: ["🔇", "🔉", "🔊"]),
        "com.apple.system.mission-control": .single(icon: "🖥"),
        "com.apple.system.launchpad": .single(icon: "▦"),
        "com.apple.system.siri": .single(icon: "✨"),
        // Not a dedicated key on every Touch Bar keyboard — some models
        // fold Esc into the Control Strip itself instead.
        "com.apple.system.esc": .single(icon: "esc"),
        "com.apple.system.airplay": .single(icon: "📶"),
        "com.apple.system.dictation": .single(icon: "🎙"),
        "com.apple.system.do-not-disturb": .single(icon: "🌙"),
        "com.apple.system.notification-center": .single(icon: "🔔"),
        "com.apple.system.screen-lock": .single(icon: "🔒"),
        "com.apple.system.screen-saver": .single(icon: "🖼"),
        "com.apple.system.screencapture": .single(icon: "📸"),
        "com.apple.system.search": .single(icon: "🔍"),
        "com.apple.system.show-desktop": .single(icon: "🗔"),
        "com.apple.system.sleep": .single(icon: "🌒"),
        "com.apple.system.workflows": .single(icon: "⚙️"),
        "com.apple.system.night-shift": .single(icon: "🌗"),
        "com.apple.system.handwriting": .single(icon: "✍️"),
        "com.apple.system.input-menu": .single(icon: "🌐"),
        "NSTouchBarItemIdentifierFlexibleSpace": .flexibleSpace,
    ]

    /// Ordered render items for the user's actual customized Control Strip.
    /// Unknown identifiers (future macOS additions this app doesn't know
    /// about yet) are skipped rather than rendered as a blank pill.
    func currentStripItems() -> [ItemKind] {
        CFPreferencesAppSynchronize(stripDomain)
        let identifiers = CFPreferencesCopyAppValue("FullCustomized" as CFString, stripDomain) as? [String]
            ?? Self.defaultOrder
        return identifiers.compactMap { Self.knownItems[$0] }
    }

    /// The Touch Bar mode currently active for the given frontmost app,
    /// falling back to the global default when there's no per-app override.
    func currentMode(frontmostBundleID: String?) -> Mode {
        CFPreferencesAppSynchronize(agentDomain)
        let perApp = CFPreferencesCopyAppValue("PresentationModePerApp" as CFString, agentDomain) as? [String: String]
        if let bundleID = frontmostBundleID, let override = perApp?[bundleID] {
            return override == "functionKeys" ? .functionKeys : .controlStrip
        }
        let global = CFPreferencesCopyAppValue("PresentationModeGlobal" as CFString, agentDomain) as? String
        return global == "functionKeys" ? .functionKeys : .controlStrip
    }
}

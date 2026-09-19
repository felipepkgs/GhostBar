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

    /// Icons by Icons8 (icons8.com) for the curated identifiers below;
    /// emoji/text for the long-tail ones that don't have a curated asset.
    enum Icon {
        case emoji(String)
        case image(String) // filename under Resources/overlay/icons/
        // Same asset as .image, rendered smaller — conveys "less" (e.g. the
        // reduce-brightness side of a pair) without needing a dedicated
        // graded icon, since Icons8's free set doesn't have one.
        case imageSmall(String)
    }

    enum ItemKind {
        case single(icon: Icon)
        case group(icons: [Icon])
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
    // string table. The common/likely-visible identifiers get a curated
    // Icons8 image (see Resources/overlay/icons/ — attribution lives in the
    // About panel and README per Icons8's free-license terms); rarer
    // long-tail ones fall back to emoji rather than chasing an icon for
    // every possible identifier up front.
    private static let knownItems: [String: ItemKind] = [
        // Icons8's free set has no graded sun (dim vs. bright) — same sun
        // asset for both, just rendered smaller on the "reduce" side.
        "com.apple.system.group.brightness": .group(icons: [.imageSmall("brightness.png"), .image("brightness.png")]),
        "com.apple.system.group.keyboard-brightness": .group(icons: [.image("keyboard-brightness.png"), .image("keyboard-brightness.png")]),
        "com.apple.system.group.media": .group(icons: [.image("media-rewind.png"), .image("media-play-pause.png"), .image("media-fast-forward.png")]),
        "com.apple.system.group.volume": .group(icons: [.image("volume-mute.png"), .image("volume-down.png"), .image("volume-up.png")]),
        "com.apple.system.mission-control": .single(icon: .image("mission-control.png")),
        "com.apple.system.launchpad": .single(icon: .image("launchpad.png")),
        "com.apple.system.siri": .single(icon: .image("siri.png")),
        // Not a dedicated key on every Touch Bar keyboard — some models
        // fold Esc into the Control Strip itself instead.
        "com.apple.system.esc": .single(icon: .emoji("esc")),
        "com.apple.system.airplay": .single(icon: .image("airplay.png")),
        "com.apple.system.dictation": .single(icon: .image("dictation.png")),
        "com.apple.system.do-not-disturb": .single(icon: .image("do-not-disturb.png")),
        "com.apple.system.notification-center": .single(icon: .image("notification-center.png")),
        "com.apple.system.screen-lock": .single(icon: .image("screen-lock.png")),
        "com.apple.system.screen-saver": .single(icon: .emoji("🖼")),
        "com.apple.system.screencapture": .single(icon: .image("screencapture.png")),
        // Deliberate, not a placeholder — user's pick, not meant to look like Spotlight.
        "com.apple.system.search": .single(icon: .emoji("👾")),
        "com.apple.system.show-desktop": .single(icon: .emoji("🗔")),
        "com.apple.system.sleep": .single(icon: .emoji("🌒")),
        "com.apple.system.workflows": .single(icon: .emoji("⚙️")),
        "com.apple.system.night-shift": .single(icon: .emoji("🌗")),
        "com.apple.system.handwriting": .single(icon: .emoji("✍️")),
        "com.apple.system.input-menu": .single(icon: .emoji("🌐")),
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

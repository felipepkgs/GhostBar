import Foundation

enum AppVersion {
    /// Reads the real .app bundle's CFBundleShortVersionString (bump that
    /// in Packaging/Info.plist alongside the git tag on each release — see
    /// README's release flow) so there's one source of truth instead of two
    /// hand-maintained strings. `swift run` has no real Info.plist to read
    /// (Bundle.main resolves to a bare Mach-O, not GhostBar.app), so this
    /// fallback only ever shows up in dev builds, never a shipped one.
    static let current: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0-dev"
    }()
}

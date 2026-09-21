import Foundation

/// Ensures only one GhostBar process runs at a time, regardless of how it
/// was launched (`swift run`, a bare dev binary, or the packaged `.app`) —
/// a second launch quits itself immediately rather than fighting the first
/// over the menu bar item, hotkey registration, and overlay panel. Chose
/// silent self-quit over activating the existing instance: this is a
/// menu-bar-only accessory app with no main window to bring forward, so
/// there's nothing meaningful to "activate."
///
/// Replaces an earlier `NSWorkspace.runningApplications`-based check that
/// used to live in AppDelegate (bundle-identifier match, falling back to
/// process-name match when `Bundle.main.bundleIdentifier` is nil — true
/// for a bare dev binary with no `.app` wrapper, confirmed earlier this
/// session via a UserDefaults domain test). That approach was a genuine
/// TOCTOU race: two instances launched close together could each check
/// "is anyone else running?" before either had finished registering with
/// NSWorkspace, and both would pass. `flock()` is atomic and kernel-
/// enforced instead of list-and-search, so it can't race that way, and it
/// works identically across `swift run`, the bare binary, and the real
/// `.app` — no bundle identity required at all.
enum SingleInstanceLock {
    // Kept open for the process lifetime so the lock releases automatically
    // on quit, crash, or force-quit — no unlock-on-quit path to skip.
    private static var lockFileDescriptor: Int32 = -1

    /// Call once, as early as possible in startup, before any UI setup.
    /// Terminates the process immediately if another instance already
    /// holds the lock.
    static func acquireOrExit() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/GhostBar")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let lockPath = dir.appendingPathComponent("instance.lock").path

        let fd = open(lockPath, O_CREAT | O_WRONLY, 0o644)
        guard fd != -1 else { return } // can't create the lock file — fail open rather than blocking launch

        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            FileHandle.standardError.write(Data("GhostBar is already running — quitting this instance.\n".utf8))
            exit(0)
        }

        lockFileDescriptor = fd
    }
}

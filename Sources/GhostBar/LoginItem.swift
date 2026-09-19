import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService.mainApp — shared by the menu bar toggle,
/// Preferences, and first-launch onboarding, all of which need to read/set
/// the same "Launch at Login" state.
///
/// Only takes effect when running as the bundled GhostBar.app (built via
/// Scripts/build_app.sh) — SMAppService needs a real app bundle identity to
/// register a login item against. Under `swift run` this logs and no-ops.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("GhostBar: login item toggle failed (expected under `swift run`): \(error)")
        }
    }
}

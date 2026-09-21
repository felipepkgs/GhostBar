# Architecture

A thin Swift/AppKit shell handles the private-framework plumbing and window
management; the actual visual layer is plain HTML/CSS/JS in a `WKWebView`,
so the overlay's look and feel can be iterated on without touching Swift.

| File | Responsibility |
|---|---|
| `AppDelegate.swift` | Menu bar item, wires up every other piece, onboarding/Preferences/update-check triggers |
| `HotkeyManager.swift` | Global toggle hotkey via Carbon (`RegisterEventHotKey`), rebindable via Preferences |
| `HotkeyRecorderButton.swift` | Preferences' "press keys to rebind" control (AppKit-backed, see its header comment) |
| `TouchPositionReader.swift` | Live touch position via `MultitouchSupport.framework` |
| `ActionKeyReader.swift` | Named system actions via `NSEvent.systemDefined` |
| `OverlayPanelController.swift` | The floating panel (`NSVisualEffectView` glass), auto show/hide, cursor-follow positioning, native → JS bridge |
| `ControlStripReader.swift` | Reads the user's real Control Strip layout + Touch Bar mode via `CFPreferences` |
| `PanelTheme.swift` | The five selectable visual themes — native chrome (corner radius, border) per theme, see [Themes](themes.md) |
| `Settings.swift` | `UserDefaults`-backed Preferences values, read live by `OverlayPanelController` |
| `PreferencesView.swift` | The Preferences window (SwiftUI) |
| `OnboardingView.swift` | The first-launch welcome window (SwiftUI) |
| `SwiftUIWindowController.swift` | Thin `NSWindowController` shared by Preferences and onboarding |
| `LoginItem.swift` | `SMAppService` wrapper shared by the menu item, Preferences, and onboarding |
| `UpdateChecker.swift` / `Version.swift` | GitHub Releases version check |
| `Resources/overlay/` | The actual UI: `index.html`, `style.css` (base look + per-theme overrides), `app.js`, `icons/` |
| `Resources/statusbar/` | Menu bar icon (`ghost-icon.png`) |
| `Packaging/` | `Info.plist` + `AppIcon.icns` for the `.app` bundle |
| `Scripts/build_app.sh` | Assembles `GhostBar.app` from a release build |
| `Scripts/generate_icon.swift` / `.sh` | Composites `AppIcon.icns` from `assets/ghost-source.png` — same ghost glyph as the menu bar icon, so Finder/Dock/Raycast/Spotlight match — only needs re-running if the icon design changes |
| `.github/workflows/release.yml` | Builds, tags, and releases on every `master` push that touches source/packaging; auto-bumps the patch version unless the commit already bumped it; updates the Homebrew tap |

Every private-framework symbol is resolved via `dlopen`/`dlsym` at runtime,
never linked at build time — a missing or renamed symbol on some future
macOS disables that one feature instead of crashing the app.

## Building and running

For quick iteration, straight from the terminal:

```sh
git pull https://github.com/felipepkgs/GhostBar.git
swift run
```

For a real double-clickable app with a Dock/menu-bar icon and working
"Launch at Login" (`SMAppService` needs an actual bundle identity for that):

```sh
./Scripts/build_app.sh
open GhostBar.app          # or drag it into /Applications first
```

This is ad-hoc signed (`codesign -s -`), not Developer-ID notarized — that
costs money and isn't set up yet, so Gatekeeper will warn on first launch.
Right-click → Open once to clear it, same as any other unsigned app.

No Xcode project, no external dependencies. Requires an unsandboxed,
non-App-Store build either way, since private framework access won't pass
App Review — this is meant for personal use, not distribution.

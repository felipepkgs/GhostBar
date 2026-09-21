# Architecture

Thin Swift/AppKit shell for private-framework plumbing and window
management; the overlay's visuals are plain HTML/CSS/JS in a `WKWebView`.

| File | Responsibility |
|---|---|
| `AppDelegate.swift` | Menu bar item, wiring, onboarding/Preferences/update-check triggers |
| `HotkeyManager.swift` / `HotkeyRecorderButton.swift` | Global toggle hotkey (Carbon), rebindable in Preferences |
| `TouchPositionReader.swift` | Live touch position (`MultitouchSupport.framework`) |
| `ActionKeyReader.swift` | Named system actions (`NSEvent.systemDefined`) |
| `OverlayPanelController.swift` | The floating glass panel, show/hide, positioning, native ↔ JS bridge |
| `ControlStripReader.swift` | Real Control Strip layout + Touch Bar mode (`CFPreferences`) |
| `PanelTheme.swift` | The selectable themes — see [Themes](themes.md) |
| `Settings.swift` | `UserDefaults`-backed Preferences values |
| `PreferencesView.swift` / `OnboardingView.swift` / `SwiftUIWindowController.swift` | Preferences + first-launch windows (SwiftUI) |
| `SingleInstanceLock.swift` | Atomic `flock`-based single-instance guard |
| `LoginItem.swift` | `SMAppService` wrapper |
| `UpdateChecker.swift` / `Version.swift` | GitHub Releases version check |
| `Resources/overlay/` | `index.html`, `style.css`, `app.js`, `icons/` |
| `Packaging/` | `Info.plist` + `AppIcon.icns` |
| `Scripts/` | `build_app.sh`, icon generation |
| `.github/workflows/release.yml` | Build, tag, release, Homebrew tap update — see [Releasing](releasing.md) |

Private framework symbols are resolved via `dlopen`/`dlsym` at runtime,
never linked at build time.

## Building from source

```sh
swift run                    # quick iteration
./Scripts/build_app.sh && open GhostBar.app   # real .app bundle
```

Ad-hoc signed, not notarized — Gatekeeper will warn on first launch
(right-click → Open once). No Xcode project, no external dependencies.

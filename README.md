# GhostBar

## Context-aware GhostBar display
<img width="599" height="130" alt="Gravação 2026-09-19 at 00 14 19" src="https://github.com/user-attachments/assets/3cfc8b37-b367-4935-b3df-170f5f82fe97" />

> It shows the current bar for the active window

My Touch Bar's OLED panel is dead — but the digitizer underneath it isn't. The
display and the touch sensor are separate hardware paths that failed
independently, so every tap still registers, I just can't see it happen. This
app is a floating on-screen stand-in: it shows where you're touching in real
time, and flashes up the name of anything you press that maps to a system
action (brightness, volume, media keys).

It cannot show you the *actual* pixels your apps are drawing on the Touch Bar
— that turned out to be architecturally out of reach on this hardware (more
on that below). What it gives you instead is everything that's
independently, definitively knowable: raw touch position, named system
actions, and — read straight from macOS's own preferences, not inferred —
which mode (Function Keys or Control Strip) is actually active right now
and what your real Control Strip layout is.

## What it does

- **Live finger-position dot.** Tracks your touch on the physical Touch Bar
  in real time via the same low-level digitizer API trackpad-visualizer tools
  use (`MultitouchSupport.framework`, filtered to the Touch Bar's device
  family), rendered as a glowing, gently pulsing dot on a floating panel.
- **Real macOS frosted glass, not a painted rectangle.** The panel is backed
  by a genuine `NSVisualEffectView` (`.hudWindow` vibrancy), so it reads and
  blurs your actual desktop behind it the same way Control Center or a
  notification does — CSS alone can't fake this over a transparent window.
- **Touch feedback on the strip itself.** As the dot crosses a key, that
  segment lights up — a bit of the tactile "did I actually hit that" signal
  the dead display would normally give you.
- **Asserts your real mode — Function Keys or Control Strip — it doesn't
  guess.** `ControlStripReader` reads macOS's own preference domains
  (`com.apple.controlstrip`, `com.apple.touchbar.agent`) via the public
  `CFPreferences` API, definitively determining which mode is active for
  the frontmost app right now (per-app overrides included) and your actual
  customized Control Strip button layout — not an inference from context,
  not a static reference chart. Only the row that's actually active is
  shown, and it refreshes live the moment you switch apps.
- **Follows your cursor across monitors.** On a multi-display setup, the
  panel tracks whichever screen your cursor is currently on, live — checked
  on every touch, not just at the start of a new gesture — while still
  honoring a manually dragged position on that same screen.
- **Named action toasts.** Touch Bar presses for brightness/volume/mute/
  media playback/keyboard illumination fire the same system-wide
  `NSEvent.systemDefined` events physical F-keys do — fully public API, no
  private frameworks involved. When one fires, an icon + label pill scales
  and fades in over the panel for a couple of seconds.
- **Auto show/hide, with a memory.** The panel appears the moment you touch
  the Touch Bar and fades (not snaps) out ~1.5s after you lift your finger.
  Drag it anywhere on screen and it reopens there next time, across
  relaunches.
- **Global hotkey.** `⌃⌥⌘T` by default — pins the panel open (or closes it),
  overriding auto-hide until you toggle it again. Rebindable in Preferences.
- **Preferences.** Hide-after-touch and hide-after-action delays, panel size
  and opacity, a Preview button (stays open while Preferences is open,
  instead of auto-hiding after a few seconds) to see changes without
  touching the physical Touch Bar, Reset Position, and a recorder to rebind
  the global hotkey — all backed by `UserDefaults`, applied live with no
  relaunch needed.
- **Checks for updates.** Compares the latest GitHub release tag against the
  running version on launch (throttled to once a day) and via a "Check for
  Updates…" menu item — no Sparkle, no self-replacing binary, just an alert
  pointing you at the release page or `brew upgrade`.
- **First-launch welcome.** A one-time window explaining what GhostBar does
  and surfacing "Launch at Login" immediately, instead of leaving it buried
  in the menu.
- **Lives in the menu bar.** No Dock icon, no window chrome — just a small
  status item with a toggle, Preferences, Launch at Login, Check for
  Updates, About, and quit.

## Why it can't mirror actual content

Touch Bar content lives behind two different private, undocumented Apple
frameworks depending on what you're trying to do with it:

- **Touch position** — `MultitouchSupport.framework`. Well-precedented,
  low-risk, and this is what powers the dot.
- **Content mirroring** — `DFRFoundation.framework`'s display-stream API
  (`DFRTouchBarCreateDisplayStream`). This one was fully reverse-engineered
  for this project — the real Objective-C selector
  (`initWithTouchBar:properties:queue:handler:`) was confirmed via runtime
  introspection, not guesswork, and calling it live didn't crash and
  returned valid objects. But it never delivered a single frame, including
  during active interaction. `DFRPlacementIsVisible()` reports `0` — the OS
  itself considers this Touch Bar's content not visible, almost certainly
  because it isn't bothering to render anything to a panel it has detected
  as non-functional. There's nothing at the source for a capture API to
  capture, no matter how correctly it's called.

So: touch input and system-level key actions are independently observable
and reliable. Arbitrary per-app Touch Bar content (a text editor's custom
buttons, Safari's tab strip, etc.) is not — it never leaves the owning app's
process as a system-wide signal, mirrored or otherwise.

**Same wall, different API: system-wide Now Playing info.** Showing the
current track/artist under the Control Strip's media controls looked
promising — `MediaRemote.framework`'s `MRMediaRemoteGetNowPlayingInfo` is
the same technique various third-party Now Playing menu bar utilities have
used. Got the call itself right (its completion handler is a real
Objective-C block, not a plain C function pointer — needs `@convention(block)`
on that parameter, confirmed live: without it the callback still fires, just
reads garbage instead of crashing). With that fixed, the call cleanly
returns `nil` — not garbage, a real "no info" — for tracks Control Center's
own Now Playing widget shows fine at the same moment (verified against both
Music.app and a Safari tab). That gap between "the system clearly has the
data" and "this call reports none of it" points at the same class of thing
DFRTouchBarCreateDisplayStream hit: real data gated behind an entitlement
first-party processes like Control Center have and an ad-hoc-signed
third-party app doesn't. Tracked in [#9](https://github.com/felipepkgs/GhostBar/issues/9)
in case that ever changes.

## Building and running

The easiest way to install it — via [Homebrew](https://brew.sh):

```sh
brew tap felipepkgs/ghostbar
brew install --cask ghostbar
```

Same ad-hoc-signed, unsigned-by-Apple caveat as below; the cask clears the
Gatekeeper quarantine flag for you, so there's no manual right-click → Open
step needed.

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

## Architecture

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
| `Settings.swift` | `UserDefaults`-backed Preferences values, read live by `OverlayPanelController` |
| `PreferencesView.swift` | The Preferences window (SwiftUI) |
| `OnboardingView.swift` | The first-launch welcome window (SwiftUI) |
| `SwiftUIWindowController.swift` | Thin `NSWindowController` shared by Preferences and onboarding |
| `LoginItem.swift` | `SMAppService` wrapper shared by the menu item, Preferences, and onboarding |
| `UpdateChecker.swift` / `Version.swift` | GitHub Releases version check |
| `Resources/overlay/` | The actual UI: `index.html`, `style.css`, `app.js`, `icons/` |
| `Resources/statusbar/` | Menu bar icon (`ghost-icon.png`) |
| `Packaging/` | `Info.plist` + `AppIcon.icns` for the `.app` bundle |
| `Scripts/build_app.sh` | Assembles `GhostBar.app` from a release build |
| `Scripts/generate_icon.swift` / `.sh` | Composites `AppIcon.icns` from `assets/ghost-source.png` — same ghost glyph as the menu bar icon, so Finder/Dock/Raycast/Spotlight match — only needs re-running if the icon design changes |
| `.github/workflows/release.yml` | Builds, tags, and releases on every `master` push that touches source/packaging; auto-bumps the patch version unless the commit already bumped it; updates the Homebrew tap |

Every private-framework symbol is resolved via `dlopen`/`dlsym` at runtime,
never linked at build time — a missing or renamed symbol on some future
macOS disables that one feature instead of crashing the app.

## Releasing

Every push to `master` that touches `Sources/`, `Package.swift`,
`Packaging/`, or the build/icon scripts triggers `.github/workflows/release.yml`:
it builds and zips `GhostBar.app`, auto-bumps `Packaging/Info.plist`'s patch
version (unless that commit already set a fresh, unreleased version — e.g. a
manual minor/major bump), tags and publishes a GitHub Release, then updates
the `felipepkgs/homebrew-ghostbar` cask's version and checksum. No manual
`build_app.sh` / `gh release create` dance needed for routine changes.

The Homebrew-tap step needs a `HOMEBREW_TAP_TOKEN` repo secret — a
fine-grained PAT scoped to `felipepkgs/homebrew-ghostbar` with Contents:
read & write, created at github.com/settings/tokens and set via
`gh secret set HOMEBREW_TAP_TOKEN --repo felipepkgs/GhostBar`. Until that
secret exists, the GhostBar release itself still succeeds — only the tap
update fails.

## Credits

Control Strip icons (`Resources/overlay/icons/`), the menu bar glyph
(`Resources/statusbar/`), and the app icon (`Scripts/assets/ghost-source.png`,
composited into `AppIcon.icns`) are by [Icons8](https://icons8.com), used
under their free license.

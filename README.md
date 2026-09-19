# GhostBar
<img width="593" height="142" alt="Gravação 2026-09-18 at 22 24 19" src="https://github.com/user-attachments/assets/0bf6f686-a1b3-4b08-9f23-34fa4a40ba6d" />

My Touch Bar's OLED panel is dead — but the digitizer underneath it isn't. The
display and the touch sensor are separate hardware paths that failed
independently, so every tap still registers, I just can't see it happen. This
app is a floating on-screen stand-in: it shows where you're touching in real
time, and flashes up the name of anything you press that maps to a system
action (brightness, volume, media keys).

It cannot show you the *actual* pixels your apps are drawing on the Touch Bar
— that turned out to be architecturally out of reach on this hardware (more
on that below). What it gives you instead is everything that's independently
observable: raw touch position, and named system actions.

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
- **Two stacked reference strips.** Since the dot's x-position is just a
  normalized `[0, 1]` fraction across the bar — layout-agnostic — it's drawn
  on *two* rows at once: a Function Keys layout (F1–F12) and the stock
  Control Strip layout, pixel-matched to the real default layout's grouping
  and gaps. You can't know programmatically which mode the real Touch Bar is
  in, but you can usually tell by context, and seeing the dot against both
  guides is enough to know what you're about to press.
- **Named action toasts.** Touch Bar presses for brightness/volume/mute/
  media playback/keyboard illumination fire the same system-wide
  `NSEvent.systemDefined` events physical F-keys do — fully public API, no
  private frameworks involved. When one fires, an icon + label pill scales
  and fades in over the panel for a couple of seconds.
- **Auto show/hide, with a memory.** The panel appears the moment you touch
  the Touch Bar and fades (not snaps) out ~1.5s after you lift your finger.
  Drag it anywhere on screen and it reopens there next time, across
  relaunches.
- **Global hotkey.** `⌃⌥⌘T` pins the panel open (or closes it), overriding
  auto-hide until you toggle it again.
- **Lives in the menu bar.** No Dock icon, no window chrome — just a small
  status item with a toggle, an optional "Launch at Login", and quit.

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

## Architecture

A thin Swift/AppKit shell handles the private-framework plumbing and window
management; the actual visual layer is plain HTML/CSS/JS in a `WKWebView`,
so the overlay's look and feel can be iterated on without touching Swift.

| File | Responsibility |
|---|---|
| `AppDelegate.swift` | Menu bar item, "Launch at Login" (`ServiceManagement`), wires up the other pieces |
| `HotkeyManager.swift` | Global `⌃⌥⌘T` toggle via Carbon (`RegisterEventHotKey`) |
| `TouchPositionReader.swift` | Live touch position via `MultitouchSupport.framework` |
| `ActionKeyReader.swift` | Named system actions via `NSEvent.systemDefined` |
| `OverlayPanelController.swift` | The floating panel (`NSVisualEffectView` glass), auto show/hide, remembered position, native → JS bridge |
| `ControlStripReader.swift` | Reads the user's real Control Strip layout + Touch Bar mode via `CFPreferences` |
| `Resources/overlay/` | The actual UI: `index.html`, `style.css`, `app.js`, `icons/` |
| `Packaging/` | `Info.plist` + `AppIcon.icns` for the `.app` bundle |
| `Scripts/build_app.sh` | Assembles `GhostBar.app` from a release build |
| `Scripts/generate_icon.swift` / `.sh` | Draws `AppIcon.icns` from scratch (pill + glow dot, matching the overlay's own look) — only needs re-running if the icon design changes |

Every private-framework symbol is resolved via `dlopen`/`dlsym` at runtime,
never linked at build time — a missing or renamed symbol on some future
macOS disables that one feature instead of crashing the app.

## Credits

Control Strip icons (`Resources/overlay/icons/`) are by [Icons8](https://icons8.com),
used under their free license.

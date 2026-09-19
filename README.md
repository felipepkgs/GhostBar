# TouchBarVisualizer
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
  family), rendered as a glowing dot on a floating panel.
- **Two stacked reference strips.** Since the dot's x-position is just a
  normalized `[0, 1]` fraction across the bar — layout-agnostic — it's drawn
  on *two* rows at once: a Function Keys layout (F1–F12) and the stock
  Control Strip layout (brightness, Mission Control, Spotlight, dictation,
  Do Not Disturb, volume). You can't know programmatically which mode the
  real Touch Bar is in, but you can usually tell by context, and seeing the
  dot against both guides is enough to know what you're about to press.
- **Named action flashes.** Touch Bar presses for brightness/volume/mute/
  media playback/keyboard illumination fire the same system-wide
  `NSEvent.systemDefined` events physical F-keys do — fully public API, no
  private frameworks involved. When one fires, its name flashes across the
  panel for a couple of seconds.
- **Auto show/hide.** The panel appears the moment you touch the Touch Bar
  and fades out ~1.5s after you lift your finger — no need to reach for a
  shortcut just to glance at it.
- **Global hotkey.** `⌃⌥⌘T` pins the panel open (or closes it), overriding
  auto-hide until you toggle it again.
- **Lives in the menu bar.** No Dock icon, no window chrome — just a small
  status item with a toggle and quit.

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

```sh
git pull https://github.com/felipepkgs/GhostBar.git
swift run
```

No Xcode project, no external dependencies. Requires an unsandboxed,
non-App-Store build, since private framework access won't pass App Review —
this is meant to run locally via `swift run` or as a Developer-ID-signed
build for personal use.

## Architecture

A thin Swift/AppKit shell handles the private-framework plumbing and window
management; the actual visual layer is plain HTML/CSS/JS in a `WKWebView`,
so the overlay's look and feel can be iterated on without touching Swift.

| File | Responsibility |
|---|---|
| `AppDelegate.swift` | Menu bar item, wires up the other pieces |
| `HotkeyManager.swift` | Global `⌃⌥⌘T` toggle via Carbon (`RegisterEventHotKey`) |
| `TouchPositionReader.swift` | Live touch position via `MultitouchSupport.framework` |
| `ActionKeyReader.swift` | Named system actions via `NSEvent.systemDefined` |
| `OverlayPanelController.swift` | The floating panel, auto show/hide, native → JS bridge |
| `Resources/overlay/` | The actual UI: `index.html`, `style.css`, `app.js` |

Every private-framework symbol is resolved via `dlopen`/`dlsym` at runtime,
never linked at build time — a missing or renamed symbol on some future
macOS disables that one feature instead of crashing the app.

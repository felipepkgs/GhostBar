# GhostBar

## Context-aware GhostBar display
<img width="599" height="130" alt="Gravação 2026-09-19 at 00 14 19" src="https://github.com/user-attachments/assets/3cfc8b37-b367-4935-b3df-170f5f82fe97" />

> It shows the current bar for the active window

My Touch Bar's OLED panel is dead, but the digitizer underneath it still
works — every tap registers, I just can't see it. This app is a floating
on-screen stand-in: it shows where you're touching in real time, and
flashes the name of anything you press that maps to a system action
(brightness, volume, media keys).

It can't show the *actual* pixels your apps draw on the Touch Bar — see
[Investigated dead ends](docs/dead-ends.md) for why. What it gives you
instead: raw touch position, named system actions, and your real Control
Strip layout + active mode, read straight from macOS's own preferences.

## What it does

- **Live finger-position dot**, tracked via the same low-level digitizer API
  trackpad-visualizer tools use, rendered as a glowing dot on a floating
  glass panel (a genuine `NSVisualEffectView`, not a painted rectangle).
- **Touch feedback on the strip itself** — the segment under the dot lights
  up as it crosses.
- **Asserts your real mode** (Function Keys or Control Strip) from macOS's
  own preferences — not a guess — and refreshes live as you switch apps.
- **Follows your cursor across monitors**, checked on every touch, while
  still honoring a manually dragged position on that screen.
- **Named action toasts** for brightness/volume/mute/media/keyboard-
  illumination presses.
- **Auto show/hide with a memory** — appears on touch, fades ~1.5s after you
  lift your finger, and reopens wherever you last dragged it.
- **Selectable themes**, including three material finishes (Gold, Silver,
  Carbon Fiber) — see [Themes](docs/themes.md).
- **Global hotkey** (`⌃⌥⌘T` by default, rebindable) to pin the panel open.
- **Preferences** for hide delays, panel size/opacity, theme, position reset,
  and the hotkey — all applied live, no relaunch needed.
- **Checks for updates** against the latest GitHub release (throttled daily),
  no Sparkle, no self-replacing binary.
- **First-launch welcome window** and **Launch at Login**.
- **Lives in the menu bar** — no Dock icon, no window chrome.

## Install

```sh
brew tap felipepkgs/ghostbar
brew install --cask ghostbar
```

Ad-hoc signed, not Developer-ID notarized — the cask clears the Gatekeeper
quarantine flag for you, so no manual right-click → Open step is needed.

For building from source, dev iteration, and architecture details, see
[docs/architecture.md](docs/architecture.md).

## Docs

- [Architecture](docs/architecture.md) — file-by-file breakdown, building from source
- [Themes](docs/themes.md) — the visual themes, with screenshots
- [Investigated dead ends](docs/dead-ends.md) — Touch Bar content mirroring, Now Playing info
- [Releasing](docs/releasing.md) — how the auto-release + Homebrew tap pipeline works

## Credits

Control Strip icons (`Resources/overlay/icons/`), the menu bar glyph
(`Resources/statusbar/`), and the app icon (`Scripts/assets/ghost-source.png`,
composited into `AppIcon.icns`) are by [Icons8](https://icons8.com), used
under their free license.

# Investigated dead ends

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

## Same wall, different API: system-wide Now Playing info

Showing the current track/artist under the Control Strip's media controls
looked promising — `MediaRemote.framework`'s `MRMediaRemoteGetNowPlayingInfo`
is the same technique various third-party Now Playing menu bar utilities
have used. Got the call itself right (its completion handler is a real
Objective-C block, not a plain C function pointer — needs `@convention(block)`
on that parameter, confirmed live: without it the callback still fires, just
reads garbage instead of crashing). With that fixed, the call cleanly
returns `nil` — not garbage, a real "no info" — for tracks Control Center's
own Now Playing widget shows fine at the same moment (verified against both
Music.app and a Safari tab). That gap between "the system clearly has the
data" and "this call reports none of it" points at the same class of thing
`DFRTouchBarCreateDisplayStream` hit: real data gated behind an entitlement
first-party processes like Control Center have and an ad-hoc-signed
third-party app doesn't. Tracked in
[#9](https://github.com/felipepkgs/GhostBar/issues/9) in case that ever
changes.

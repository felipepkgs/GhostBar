# Investigated dead ends

- **Touch Bar content mirroring** (`DFRTouchBarCreateDisplayStream`) —
  correctly reverse-engineered and called, never delivers a frame.
  `DFRPlacementIsVisible()` reports `0`.
- **System-wide Now Playing info** (`MediaRemote.framework`) — the call
  itself is confirmed correct, but returns `nil` even when Control Center's
  own widget shows the data live. Tracked in
  [#9](https://github.com/felipepkgs/GhostBar/issues/9).

Both point to the same wall: the OS has the data, but it's gated behind an
entitlement first-party processes have and a third-party ad-hoc-signed app
doesn't.

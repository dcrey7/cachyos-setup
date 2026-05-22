# Cover Switch morph transition and ping-pong navigation

**Date:** 2026-05-22

## What shipped

- Added a separate `morphLayer` above the Cover Switch card scene. It uses a
  `KWin.WindowThumbnail` mirror of the active or selected window as a fake
  Wayland-safe morph, because tabbox QML cannot transform the real live
  client window.
- On open, the mirror starts at the full switcher surface size and animates
  into the current PathView card thumbnail rect over 220 ms with
  `Easing.OutCubic`.
- On close, the selected card thumbnail rect is captured immediately, then the
  mirror animates back to full surface size over 180 ms while fading out.
- The existing card fade remains, and the delegate open-scale animation is
  kept as `0.8 * PathView.scale` to `1.0 * PathView.scale`.
- Replaced PathView's wrapping key navigation with a ping-pong sweep. Repeated
  Tab, Backtab, arrow, or KWin-provided index steps move one index at a time,
  reverse at either endpoint, and never wrap from last to first.

## Compromises

- This is still a thumbnail-based illusion, not a real live-window morph.
  KWin owns the actual client surfaces on Wayland, so QML can only mirror a
  window into the tabbox surface.
- If the current delegate is not available early during open, the morph falls
  back to model index 0, which is normally KWin's last-focused window entry.
- Mouse clicks still jump directly to the clicked card. The next keyboard step
  resumes the sweep from that card and reverses inward if the clicked card is
  an endpoint.

## Preserved behavior

- No card path geometry, rotations, scale waypoints, preview ratio, dim layer,
  color palette, runtime panel reserve, or `PathView.highlightMoveDuration`
  values were changed.

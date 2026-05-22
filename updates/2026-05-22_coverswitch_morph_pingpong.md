# Cover Switch morph transition and wrap navigation

**Date:** 2026-05-22

## Superseded: previous ping-pong behavior

The earlier version of this note said Cover Switch shipped a ping-pong sweep
that reversed logical navigation at the first and last window. That behavior
was rejected and has been superseded.

## Corrected behavior

- Added a separate `morphLayer` above the Cover Switch card scene. It uses a
  `KWin.WindowThumbnail` mirror of the active or selected window as a fake
  Wayland-safe morph, because tabbox QML cannot transform the real live
  client window.
- On open, the mirror starts at the full switcher surface size and animates
  into a deterministic center-card rect over 220 ms with
  `Easing.OutCubic`.
- On close, the same center-card rect is used immediately, then the
  mirror animates back to full surface size over 180 ms while fading out.
- The morph layer now animates `x`, `y`, `width`, and `height` directly, so
  non-screen-shaped windows can land on the exact center-card rectangle.
- The existing card fade remains, and the delegate open-scale animation is
  kept as `0.8 * PathView.scale` to `1.0 * PathView.scale`.
- Restored cyclic navigation: repeated forward steps move `A -> B -> C -> A`.
  Before each index change, `PathView.movementDirection` is set explicitly.
  Normal forward steps use `PathView.Positive`; the last-to-first wrap uses
  `PathView.Negative` so the visual transit rewinds through intermediate
  cards. Normal backward steps use `PathView.Negative`; the first-to-last wrap
  uses `PathView.Positive`.

## Morph rect correction

The morph target no longer uses `thumbnail.mapToItem(...)`. PathView applies
scale, rotation, and highlight positioning at render time, so the inner
thumbnail's mapped logical geometry can be smaller than the rendered center
card and offset from it.

The replacement computes the target from the stable center-card measurements:
`thumbnailView.width * thumbnailView.previewRatio` for width, the current
thumbnail aspect ratio when available, and centered `x/y` within the switcher
window. That makes the open morph land at the same visual center as the
PathPercent `0.50` card with `PathView.scale = 1.0`.

## Compromises

- This is still a thumbnail-based illusion, not a real live-window morph.
  KWin owns the actual client surfaces on Wayland, so QML can only mirror a
  window into the tabbox surface.
- If the current delegate is not available early during open, the morph aspect
  falls back to the switcher window aspect.
- Mouse clicks still jump directly to the clicked card, but the transition now
  uses the same explicit movement-direction rule as keyboard navigation.

## Preserved behavior

- No card path geometry, rotations, scale waypoints, preview ratio, dim layer,
  color palette, runtime panel reserve, or `PathView.highlightMoveDuration`
  values were changed.

## Smoke test

With three windows, the intended manual smoke test is: hold Alt+Tab until the
selection reaches C, press Tab once more, and confirm the logical selection
wraps to A while the visual transit rewinds backward through B. Continuing Tab
should then advance A -> B -> C forward again. For the morph, open Alt+Tab and
confirm the active-window thumbnail contracts to a card-sized image centered in
the switcher, then closes by expanding from that same centered position.

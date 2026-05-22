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

The replacement now uses the live delegate root as the size source instead of
the earlier `thumbnailView.width * thumbnailView.previewRatio` width-only
formula. The delegate root is the rendered card container:

```qml
width: thumbnailView.boxWidth
height: thumbnailView.boxHeight
scale: PathView.onPath ? openScale * PathView.scale : 0
```

So the target rect is:

```text
width  = thumbnailView.currentItem.width  * effectiveScale
height = thumbnailView.currentItem.height * effectiveScale
```

where `effectiveScale` is the delegate's live `scale`, with `PathView.scale`
as the lower bound. The lower bound avoids targeting the temporary 0.8
open-scale while the switcher is still appearing. The rect is still recentered
inside the switcher window instead of trusting `mapToItem()` for position,
because the center card must stay visually centered.

On the current full-HD-ish layout this means the center target is the rendered
delegate card box, approximately `window.width * 0.45` by
`window.height * 0.45`, multiplied by center `PathView.scale = 1.0`, rather
than a window-aspect-derived thumbnail rectangle.

## Wrap animation smoothing

Wrap direction remains cyclic and reversed at the ends: last-to-first uses
`PathView.Negative`, and first-to-last uses `PathView.Positive`.

To smooth the visible rewind, each index transition now sets
`PathView.highlightMoveDuration` from the travel distance before changing the
index:

```text
duration = max(220 ms, distance * 160 ms)
```

Adjacent moves therefore stay at 220 ms. A wrap across `N` windows gets
`(N - 1) * 160 ms`, then a timer restores the base 220 ms after the move.
This keeps PathView's own movement model, avoiding a manual `offset`
animation because offset wrapping is fragile with `pathItemCount`,
`preferredHighlightBegin`, and explicit `movementDirection`.

## Compromises

- This is still a thumbnail-based illusion, not a real live-window morph.
  KWin owns the actual client surfaces on Wayland, so QML can only mirror a
  window into the tabbox surface.
- If the current delegate is not available early during open, the morph aspect
  is unavailable and the morph is skipped for that frame instead of guessing
  from the switcher window aspect.
- Mouse clicks still jump directly to the clicked card, but the transition now
  uses the same explicit movement-direction rule as keyboard navigation.

## Preserved behavior

- No card path geometry, rotations, scale waypoints, preview ratio, dim layer,
  color palette, or runtime panel reserve values were changed.

## Smoke test

With three windows, the intended manual smoke test is: hold Alt+Tab until the
selection reaches C, press Tab once more, and confirm the logical selection
wraps to A while the visual transit rewinds backward through B. Continuing Tab
should then advance A -> B -> C forward again. For the morph, open Alt+Tab and
confirm the active-window thumbnail contracts to a card-sized image centered in
the switcher, then closes by expanding from that same centered position.

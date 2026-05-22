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

## Round 8 follow-up: settled open morph target

The first Round 8 correction still sampled live delegate state:

```qml
scale: PathView.onPath ? openScale * PathView.scale : 0
```

That made the morph target flaky during startup because `openScale` animates
from `0.8` to `1.0` while PathView is also settling its attributes. Sampling
`item.scale` or `item.PathView.scale` could therefore capture a transient
value and make the fake morph land smaller or larger than the final card.

The target now uses only the settled card dimensions:

```qml
function rectForCenterCard() {
    var w = thumbnailView.boxWidth
    var h = thumbnailView.boxHeight
    return {
        x: Math.round((window.width - w) / 2),
        y: Math.round((window.height - h) / 2),
        width: w,
        height: h
    }
}
```

This deliberately targets the post-open center card size. The thumbnail mirror
and the delegate `openScale` animation run in parallel and converge on the
same final `boxWidth x boxHeight` card.

Temporary diagnostics were added for this round:

- A red transparent outline is shown for about 1.4 seconds on switcher open at
  the exact `rectForCenterCard()` target.
- `console.log()` prints `coverswitch center-card-rect ...` with `x`, `y`,
  `width`, `height`, `boxWidth`, `boxHeight`, and the switcher window size.

If that outline is still visibly off, the next diagnosis is to gate
`rectForCenterCard()` behind `thumbnailView.flicking === false &&
thumbnailView.moving === false` so the diagnostic never samples during a path
move.

## Round 8 follow-up: close morph activation path

The close morph was not visible on Alt-release because KWin closes the tabbox
surface almost immediately when the modifier is released. The QML `Behavior`
animations can be started from `onVisibleChanged: false`, but the surface is
already leaving the compositor, so the user sees the selected client focus
instead of a 180 ms zoom.

I chose Plan A for the explicit confirmation path. The local Plasma 6
thumbnail-grid switcher at
`/usr/share/kwin-wayland/tabbox/thumbnail_grid/contents/ui/main.qml` activates
clicked windows with:

```qml
tabBox.model.activate(index)
```

The current KDE developer window-switcher documentation lists the exposed
switcher API as `model`, `screenGeometry`, `visible`, `allDesktops`, and
`currentIndex`, and says `currentIndex` updates the selected item. It does not
document a `tabBox.accept()` or `tabBox.tabBoxSelected()` method. Runtime API
enumeration is now also logged on QML component creation with the prefix
`coverswitch tabBox.` and explicitly logs the type of
`tabBox.model.activate`.

Enter, keypad Enter, and Space now call `confirmSelection(event)`, which:

1. accepts the key event;
2. starts the close morph from the settled center-card rect to full switcher
   size over 180 ms;
3. waits on `closeMorphCompleteTimer`;
4. calls `tabBox.model.activate(thumbnailView.currentIndex)`.

Alt-release remains compositor-limited: once KWin starts hiding the tabbox,
the QML surface is torn down too quickly for a close animation to be visible.
A true Alt-release zoom-into-app would need a KWin C++ effect or a compositor
owned transition, not only a tabbox QML layout.

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
- The close morph is visible for the explicit Enter/Space activation path.
  Alt-release still snaps because KWin removes the tabbox surface before the
  QML animation can reach the screen.
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
should then advance A -> B -> C forward again.

For the open morph, open Alt+Tab and confirm the active-window thumbnail
contracts to the red outlined center-card target. Then check the log:

```bash
journalctl --user -b 0 --no-pager -g 'coverswitch center-card-rect|coverswitch tabBox' | tail -200
```

For the close morph, hold Alt after opening the switcher, select a different
card with Tab/arrow keys, then press Enter or Space while the switcher is still
visible. The selected window thumbnail should expand toward full switcher size
before the actual window is activated. Releasing Alt still uses KWin's
immediate commit path and may snap.

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

That round changed the target to use only the settled outer card dimensions:

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

That avoided transient open-scale sampling but still assumed every visible
thumbnail filled the full `boxWidth x boxHeight` card. Round 10 supersedes that
target with the current window's fitted thumbnail dimensions.

## Round 10 follow-up: per-window morph target

The fixed `boxWidth x boxHeight` morph target was removed because the visible
delegate thumbnail is not always that shape. The delegate keeps its outer item
at `thumbnailView.boxWidth x thumbnailView.boxHeight`, then scales the
`KWin.WindowThumbnail` inside that box with:

```qml
readonly property real thumbnailFitScale: Math.min(
    width / Math.max(1, thumbnail.implicitWidth),
    height / Math.max(1, thumbnail.implicitHeight))

KWin.WindowThumbnail {
    width: Math.round(Math.max(1, implicitWidth) * delegateItem.thumbnailFitScale)
    height: Math.round(Math.max(1, implicitHeight) * delegateItem.thumbnailFitScale)
}
```

`rectForCenterCard()` now mirrors that exact sizing rule. It reads the current
delegate's `thumbnailItem`, uses `implicitWidth / implicitHeight` as the
primary source size because that is what the delegate uses, then falls back to
`sourceSize`, live `width / height`, and finally `1920 / 1080` if the
thumbnail exposes no usable dimensions.

The temporary red transparent target outline from the diagnostic round was
deleted. The `coverswitch center-card-rect ...` journal logging remains.

The active morph layer also refreshes when the current index changes, so
tabbing to a different window while the morph is still visible retargets the
mirror to the newly selected card dimensions.

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
duration = max(220 ms, distance * 110 ms)
```

Adjacent moves therefore stay at 220 ms. A wrap across `N` windows now gets
`(N - 1) * 110 ms`, then a timer restores the base 220 ms after the move.
The previous `160 ms` multiplier made longer rewinds feel too slow, especially
the common three-window `C -> A` path where the distance is 2.

Multi-step wraps also enable a one-shot `Behavior on offset` while the
rewind is in progress:

```qml
Behavior on offset {
    enabled: thumbnailView.wrapInProgress
    NumberAnimation {
        duration: thumbnailView.highlightMoveDuration
        easing.type: Easing.OutBack
        easing.overshoot: 1.7
    }
}
```

This uses PathView's own movement model and only changes the interpolation
curve during `distance > 1` wraps. The reset timer clears
`wrapInProgress`, so normal adjacent Tab presses keep the base 220 ms
movement without the arrival wobble.

## Compromises

- This is still a thumbnail-based illusion, not a real live-window morph.
  KWin owns the actual client surfaces on Wayland, so QML can only mirror a
  window into the tabbox surface.
- The close morph is visible for the explicit Enter/Space activation path.
  Alt-release is still under investigation because KWin appears to remove the
  tabbox surface before a QML animation can reach the screen.
- If the current delegate is not available early during open, the morph aspect
  is unavailable and the morph is skipped for that frame instead of guessing
  from the switcher window aspect.
- Mouse clicks still jump directly to the clicked card, but the transition now
  uses the same explicit movement-direction rule as keyboard navigation.

## Round 11 follow-up: open morph Y target

The open morph target no longer centers itself against the whole switcher
window:

```qml
y: Math.round((window.height - h) / 2)
```

That was too low after the panel-visible workaround, because the card deck is
intentionally above the window midpoint to leave room for the title strip and
the 40-50 px bottom panel reserve.

`rectForCenterCard()` now uses the actual card path center:

```qml
var cardCenterY = thumbnailView.centerY ? thumbnailView.centerY : window.height / 2
var targetY = Math.round(cardCenterY - h / 2)
```

`thumbnailView.centerY` is a live property in this layout
(`readonly property real centerY: height * 0.48`), so no mapped delegate
fallback was needed. X remains screen-centered to avoid pulling in side-card
PathView offsets.

Temporary confirmation logging was added:

```text
coverswitch morph y: <targetY> vs cardCenterY: <cardCenterY>
```

## Round 11 follow-up: Alt-release close reinvestigation

No previous `coverswitch.signal` journal entries existed in the current boot,
so there was no timestamp evidence to promote a hidden pre-teardown signal yet.
The QML now logs all candidate teardown signals with timestamps:

```qml
Connections {
    target: tabBox
    ignoreUnknownSignals: true
    function onVisibleChanged()      { console.log("coverswitch.signal visibleChanged=" + tabBox.visible + " t=" + Date.now()) }
    function onCurrentIndexChanged() { console.log("coverswitch.signal currentIndexChanged=" + tabBox.currentIndex + " t=" + Date.now()) }
    function onSelectedItemChanged() { console.log("coverswitch.signal selectedItemChanged=" + (tabBox.selectedItem || "") + " t=" + Date.now()) }
    function onAboutToHide()         { console.log("coverswitch.signal aboutToHide t=" + Date.now()) }
}
```

The switcher window is also watched through `Connections { target: window }`
for `aboutToHide` and `closing`, using `ignoreUnknownSignals` so the layout
keeps loading on Plasma builds that do not expose those signals.

Runtime API enumeration was tightened to emit `coverswitch.fn` lines for
callable properties and now also enumerates `tabBox.model`. Local installed
QML still only shows the stock thumbnail grid activating selections through
`tabBox.model.activate(index)`.

Manual evidence to collect after Alt+Tab then releasing Alt, without Enter:

```bash
journalctl --user -b 0 --no-pager -g 'coverswitch.signal|coverswitch.win|coverswitch.fn|coverswitch.sig|coverswitch model type' | tail -80
```

Decision-tree status for this patch: Plan B, live tracking. No hook has been
wired yet because no timestamp evidence exists for a signal that fires before
`coverswitch.signal visibleChanged=false`. Instead, the morph mirror now stays
active on the selected card after the open animation and continues to retarget
on selection changes. If KWin still tears down immediately on Alt-release, the
last QML frame it can render has the mirror at the card position rather than
having no morph layer at all.

If the new log shows a signal before `coverswitch.signal visibleChanged=false`,
that signal can replace Plan B: trigger the 180 ms close morph and delay
`tabBox.model.activate(index)`. If the only sequence is `visibleChanged=true`
followed by `visibleChanged=false` and live tracking does not help visually,
the previous limitation stands and the dead Alt-release close path should be
removed or replaced with a compositor-owned effect.

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

## Round 13 follow-up: compositor-owned close zoom

Added a separate KWin JavaScript effect package at
`assets/kwin-effects/coverswitch-zoom-in`. This is intentionally not part of
the tabbox QML package: the QML layout owns the switcher surface and can keep
the live thumbnail/card tracking illusion while the switcher is visible, but
Plasma 6.6 closes that surface within about one frame of Alt release. The
scripted effect listens to KWin's effect-side `tabBoxAdded`,
`tabBoxUpdated`, and `tabBoxClosed` lifecycle signals and animates the real
selected client after the tabbox surface is gone.

The effect captures the active window at `tabBoxAdded`, tracks
`effects.currentTabBoxWindow` during `tabBoxUpdated`, and skips the close
animation if the selected window never changed. On close it estimates the
center Cover Switch card as `45% x 45%` of the target window's output
geometry, matching the current QML layout's `boxWidth` and `boxHeight`
calibration. The compositor animation uses `Effect.Size`,
`Effect.Translation`, and `Effect.Opacity` over 180 ms with
`QEasingCurve.OutCubic`.

`install.sh` now deploys the package to
`~/.local/share/kwin/effects/coverswitch-zoom-in`, enables it with the
`[Plugins] coverswitch-zoom-inEnabled=true` kwinrc key, calls KWin
`reconfigure`, and asks the Effects D-Bus interface to load the effect. A
logout/login is still the cleanest validation path for a newly installed user
effect.

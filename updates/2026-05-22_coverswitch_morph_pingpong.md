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
- The QML morph is now open-only. Close zoom is owned by the separate KWin
  JavaScript effect added in Round 13.
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

The Round 12 active-morph retargeting behavior was later superseded because
it left the `z: 50` mirror covering the PathView during navigation.

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

At the time, Enter, keypad Enter, and Space called `confirmSelection(event)`,
which:

1. accepts the key event;
2. starts the close morph from the settled center-card rect to full switcher
   size over 180 ms;
3. waits on `closeMorphCompleteTimer`;
4. calls `tabBox.model.activate(thumbnailView.currentIndex)`.

This Enter/Space QML close path was later removed in Round 14 after the
Round 13 KWin effect took ownership of close zooms.

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

`rectForCenterCard()` was first changed to use the card path center:

```qml
var cardCenterY = thumbnailView.centerY ? thumbnailView.centerY : window.height / 2
var targetY = Math.round(cardCenterY - h / 2)
```

`thumbnailView.centerY` is a live property in this layout
(`readonly property real centerY: height * 0.48`), and every PathLine in the
deck uses that y value. User testing still showed the morph landing below the
rendered cards, so the theoretical path y is not a reliable proxy for the
delegate's visible center.

## Round 12 follow-up: live delegate Y target

`rectForCenterCard()` now keeps the existing per-window width and height
calculation, but reads the current delegate's rendered center in the morph
layer parent coordinate space:

```qml
var item = thumbnailView.currentItem
var mapped = item.mapToItem(morphLayer.parent, item.width / 2, item.height / 2)
var cardCenterY = (mapped && mapped.y > 0)
                  ? mapped.y
                  : (thumbnailView.centerY ? thumbnailView.centerY : window.height / 2)
var targetY = Math.round(cardCenterY - h / 2)
```

This uses the actual post-PathView-placement delegate center when available.
If the delegate is not ready, or maps to a non-positive y during early layout,
the fallback remains the documented `thumbnailView.centerY`, then
`window.height / 2`. X remains screen-centered to avoid pulling in side-card
PathView offsets.

Temporary comparison logging was added:

```text
coverswitch y debug centerY=<thumbnailView.centerY> mappedY=<mapped.y> chosen=<cardCenterY>
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

Decision-tree status for that patch was Plan B, live tracking. That approach
has now been superseded by the Round 13 compositor-owned close effect and was
removed from the QML. Keeping the `z: 50` mirror alive over the PathView hid
the real card animation during Tab navigation.

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

## Round 14 follow-up: transient open morph

The QML morph layer is now a one-shot open transition again. On each new
switcher open, `startOpenMorph()` stops any previous fade timer/animation,
reactivates the mirror, sets opacity to `1`, places it at the full switcher
surface, then animates it to the current center-card rect over 220 ms.

After the open target is set, `morphFadeOutTimer` starts with a 250 ms
interval. When it fires, `morphLayer.fadeOut()` runs a 120 ms
`NumberAnimation` from the current opacity to `0`; when the fade stops at
zero, `morphLayer.active = false`, which removes it through
`visible: active`.

The Round 12 live tracking hook was removed from both keyboard-driven wrapped
navigation and `onCurrentIndexChanged`. The morph no longer changes
`windowId` or retargets itself during Tab navigation, so the PathView cards
and their own movement animation are visible after the open fade.

The QML close morph and its Enter/Space delay timer were removed. Enter,
keypad Enter, and Space now call `tabBox.model.activate(index)` directly; the
Round 13 KWin effect owns the close zoom through `tabBoxClosed` and falls
back to the new active window if needed.

## Round 15 follow-up: KWin effect diagnostics

Added runtime logging to
`assets/kwin-effects/coverswitch-zoom-in/contents/code/main.js` so the close
zoom failure can be separated into package-load, signal, target-selection, and
animation-shape problems. The effect now logs `init()`, signal types, exposed
`effects` keys, connect success/failure, every tabbox signal handler, skipped
animation reasons, computed size/translation values, the returned animation id,
and animation-end cleanup.

The local Plasma 6.6 scripted effects under `/usr/share/kwin-wayland/effects`
were checked before patching. `squash` and `maximize` both use the same
canonical animation shape used here:

```javascript
{
    type: Effect.Size,
    from: { value1: oldWidth, value2: oldHeight },
    to: { value1: newWidth, value2: newHeight }
}
```

`/usr/include/kwin/effect/effecthandler.h` also confirms the effect-side
signals `tabBoxAdded(int)`, `tabBoxClosed()`, and `tabBoxUpdated()` still exist.

After redeploying to `~/.local/share/kwin/effects/coverswitch-zoom-in` and
unloading/loading through D-Bus, the journal showed:

```text
coverswitch-zoom-in EFFECT init called
coverswitch-zoom-in effects.tabBoxAdded type=function
coverswitch-zoom-in effects.tabBoxClosed type=function
coverswitch-zoom-in effects.tabBoxUpdated type=function
coverswitch-zoom-in effects.currentTabBoxWindow type=undefined
coverswitch-zoom-in effects.currentTabBoxWindowList type=undefined
coverswitch-zoom-in EFFECT signals connected OK
coverswitch-zoom-in loadConfig duration=180
```

That proves the package is accepted, `init()` is running, and the tabbox signal
names resolve in this session. The current smoking gun is target discovery:
`effects.currentTabBoxWindow` and `effects.currentTabBoxWindowList` are not
exposed to JavaScript on this Plasma 6.6 runtime even though they exist in the
C++ effect handler API. `Effect` enum keys also do not enumerate through
`Object.keys()`/`for...in`, so enum availability must be validated by use or
direct type/value logging rather than key enumeration.

`install.sh` now unloads `coverswitch-zoom-in` before loading it again, so
rerunning the installer refreshes the user effect script body instead of
leaving an already-loaded copy in memory.

## Round 16 follow-up: activeWindow close target

The close zoom no longer depends on `effects.currentTabBoxWindow` or
`effects.currentTabBoxWindowList`. Round 15 diagnostics showed both values are
`undefined` in Plasma 6.6's scripted-effect JavaScript runtime, so the effect
could load and connect its signals but never discover a valid target through
the tabbox-current-window path.

`coverswitch-zoom-in` now snapshots `effects.activeWindow` at `tabBoxAdded` as
the session start window. `tabBoxUpdated` is intentionally a no-op. On
`tabBoxClosed`, KWin has already activated the chosen client, so the effect
reads `effects.activeWindow` again and compares it with the start snapshot. If
the end window is missing or unchanged, it skips the animation as a dismissed
or unchanged switcher session. If the end window is different, it calls
`runZoomIn(endWindow)`.

The animation wrapper now uses the same object shape validated against KWin's
`squash` and `maximize` effects:

```javascript
animate({
    window: window,
    curve: QEasingCurve.OutCubic,
    duration: coverSwitchZoomInEffect.duration,
    keepAlive: false,
    animations: [
        { type: Effect.Size,        from: { value1: cardW,     value2: cardH    }, to: { value1: rect.width, value2: rect.height } },
        { type: Effect.Translation, from: { value1: fromTransX, value2: fromTransY }, to: { value1: 0,          value2: 0 } },
        { type: Effect.Opacity,     from: 0.85,                                       to: 1.0 }
    ]
});
```

The translation is now a direct offset from the target window's actual
top-left: `fromTransX = cardX - rect.x` and `fromTransY = cardY - rect.y`.
That makes the visual start at the center card rectangle before growing into
the real window geometry.

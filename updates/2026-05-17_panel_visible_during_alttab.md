# Keeping the KDE panel visible during Alt-Tab — research + workaround

**Date:** 2026-05-17 (continuation of cover switch GNOME parity work)

## The problem
After the cover switch QML loaded and looked right (cards, hinge, animation),
one stubborn issue remained: the **KDE panel/taskbar disappeared during
Alt-Tab**, the same way the KDE stock cover switch hides it. The GNOME
CoverflowAltTab extension keeps the top bar visible, and the user wanted the
same.

## What we tried, in order

1. **`color: "transparent"` on the fullscreen Window.**
   Result: KWin's compositor still drew our window above the panel layer; the
   panel did not peek through transparent regions. No effect.

2. **Drop `visibility: Window.FullScreen` + remove `Qt.Popup`, shrink height
   by 40 px (the panel height we set in install.sh) using
   `tabBox.screenGeometry.height - 40`.**
   Result: Taskbar appeared, but the Window also narrowed in width — black
   bars on left/right. `tabBox.screenGeometry.width` is not the raw screen
   width on this Wayland setup.

3. **Switch geometry source to `Screen.desktopAvailableWidth/Height`.**
   Result: No more black bars (`desktopAvailableWidth = Screen.width = 1920`
   in our test) — but `desktopAvailableHeight` returned the full `1080`
   instead of subtracting the panel, so the panel got covered again.

4. **Render the backdrop in a sub-Item sized `parent.height - 40` while
   keeping the window fullscreen.**
   Result: Two backgrounds visible — our `KWin.DesktopBackground` for the top
   region, and the compositor's actual wallpaper in the uncovered strip — a
   small but visible misalignment seam.

5. **Final approach: shrink the actual window itself to
   `Screen.width × (Screen.height − 40)` at `(0, 0)`, without
   `Window.FullScreen` and without `Qt.Popup`.**
   Result: ✅ Full screen width, no black bars, taskbar visible. The bottom
   40 px of the screen is never covered by our tabbox surface, so the panel
   renders there normally.

## Why a "transparent strip" can't reveal the panel

KWin's source places internal `QQuickWindow`s (which is what tabbox layouts
are) into `OverlayLayer`, while docks/panels live in a layer below it:

- KDE switcher docs: <https://develop.kde.org/docs/plasma/windowswitcher/>
- `SwitcherItem::screenGeometry()`:
  <https://invent.kde.org/plasma/kwin/-/raw/master/src/tabbox/switcheritem.cpp>
- `Window::belongsToLayer()`:
  <https://invent.kde.org/plasma/kwin/-/raw/master/src/window.cpp>

Because the tabbox surface is always above the panel in stacking order, no
amount of QML transparency can reveal the panel beneath. The only thing that
works is for the tabbox window to physically not occupy the panel region.

KDE's stock cover switch has the exact same behavior — it covers the panel —
because its Window is `Window.FullScreen + Qt.Popup`, so the choice of
non-fullscreen+shrunk is what unlocks the panel.

## What GNOME does differently (and why we can't copy it)

`CoverflowSwitcher` adds a Clutter actor directly to `Main.uiGroup` inside
the GNOME Shell process and hides `global.window_group`. GNOME's top panel
is a sibling actor in the same scene graph, so the shell can keep the panel
above the cover deck without dealing with a separate surface at all.

KWin gives QML tabbox layouts a separate Wayland surface; there is no way
from QML to inject the panel into our own surface or to put ourselves into
the panel's layer.

## The shipped solution (see `assets/coverswitch/contents/ui/main.qml`)

```qml
Window {
    id: window
    readonly property int rawScreenWidth: Math.max(
        Screen.width,
        tabBox.screenGeometry.width,
        Screen.desktopAvailableWidth)
    readonly property int rawScreenHeight: Math.max(
        Screen.height,
        tabBox.screenGeometry.height,
        Screen.desktopAvailableHeight)

    x: tabBox.screenGeometry.x
    y: tabBox.screenGeometry.y
    width: rawScreenWidth
    height: Math.max(1, rawScreenHeight - tabBox.panelReserve)   // 40 px
    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
    visibility: Window.Windowed
    visible: true
    color: "transparent"
    ...
}
```

The constant `panelReserve = 40` matches the panel height set elsewhere in
`install.sh`. If the user re-themes the panel, the reserve will need to
change — this is the one fragile bit, but it's the only workable approach
inside KWin's current architecture.

## Other tunings shipped alongside the panel fix

- Cards: 3 fanned waypoints per side at `0.40 / 0.43 / 0.46 / 0.50 / 0.54 /
  0.57 / 0.60` of screen width with rotations `60° / 45° / 30° / 0° / -30° /
  -45° / -60°` and scales `0.50 / 0.65 / 0.85 / 1.00 / 0.85 / 0.65 / 0.50`.
- `previewRatio: 0.45` for card size.
- `highlightMoveDuration: 300` ms, no `Behavior on rotationAngle` (that was
  desyncing rotation from path position).
- `KWin.DesktopBackground` + dim `Rectangle { opacity: 0.35 }` as the
  backdrop (no blur, no live windows).
- Bottom title label anchored just below the center card via
  `y: thumbnailView.centerY + thumbnailView.boxHeight * 0.5 + Kirigami.Units.gridUnit`.
- `Binding { when: ... !== undefined }` wraps the
  `KWin.DesktopBackground.desktop` assignment to avoid the early-load
  "Unable to assign [undefined] to KWin::VirtualDesktop*" error.

## Natural scrolling on the touchpad

Separate small change requested in the same session: enable natural
scrolling for the laptop touchpad. Added to `install.sh`:

```bash
for inputdir in /sys/class/input/event*/device; do
  name=$(cat "$inputdir/name" 2>/dev/null) || continue
  echo "$name" | grep -qi touchpad || continue
  vendor=$(cat "$inputdir/id/vendor" 2>/dev/null)
  product=$(cat "$inputdir/id/product" 2>/dev/null)
  [[ -n "$vendor" && -n "$product" ]] || continue
  vendor_dec=$((16#$vendor))
  product_dec=$((16#$product))
  kwriteconfig6 --file kcminputrc \
    --group "Libinput" --group "$vendor_dec" --group "$product_dec" --group "$name" \
    --key NaturalScroll --type bool true
done
qdbus6 org.kde.KWin /KWin reconfigure
```

This enumerates touchpad-class input devices and sets per-device
`NaturalScroll=true` in `~/.config/kcminputrc`, then asks KWin to re-read
input config.

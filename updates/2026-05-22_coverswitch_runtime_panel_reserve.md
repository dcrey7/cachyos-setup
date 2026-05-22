# Cover Switch panel reserve now refreshes at runtime

**Date:** 2026-05-22

## Goal

The previous install-time substitution correctly detected the bottom panel
height, but it baked that value into the installed Cover Switch QML. Changing
the panel height later required re-running `install.sh`.

## Plasma tested

- `plasmashell 6.6.5`
- `kwin 6.6.5`
- One output: `1920x1080`
- Bottom panel before and after test restore: `50`

The user asked about Plasma 6.6.4; this machine is currently on 6.6.5.

## Runtime geometry result

The useful live property is KWin's client area, not Qt's install-time fallback:

```js
workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop)
```

From a one-shot KWin script:

```text
coverswitch-clientarea-probe2 clientArea-Maximize-output-desktop {"x":0,"y":0,"width":1920,"height":1030,"left":0,"right":1920,"top":0,"bottom":1030} 0 0 1920 1030
coverswitch-clientarea-probe2 clientArea-FullScreen-output-desktop {"x":0,"y":0,"width":1920,"height":1080,"left":0,"right":1920,"top":0,"bottom":1080} 0 0 1920 1080
```

That gives `1080 - 1030 = 50`, matching the live panel height from:

```bash
qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript 'panels().forEach(p => print(p.location + ":" + p.height))'
```

## Runtime height-change check

After temporarily changing the panel to 60 px via plasmashell scripting, KWin's
client area updated immediately:

```text
bottom:60
coverswitch-runtime-reserve-check height60 full 1920x1080 available 1920x1020 reserve 60
bottom:50
coverswitch-runtime-reserve-check height50 full 1920x1080 available 1920x1030 reserve 50
```

The panel was restored to 50 px after the check.

## What shipped

`assets/coverswitch/contents/ui/main.qml` now keeps the substituted
install-time reserve as a fallback default, but recomputes `panelReserve` from
`KWin.Workspace.clientArea(KWin.MaximizeArea, output, currentDesktop)` when the
component completes and whenever the tabbox becomes visible. That means the
next Alt+Tab refreshes the reserve after a panel-height change, without
re-running `install.sh`.

No KWin script fallback was added because the KWin client-area runtime source
works and updates when the panel height changes.

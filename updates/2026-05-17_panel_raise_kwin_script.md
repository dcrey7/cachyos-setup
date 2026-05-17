# 2026-05-17: Tabbox panel raise research

## Result

The `coverswitch_g19` quick fix is the useful runtime change: it keeps the
`coverswitch_g18` geometry and card path unchanged, but reduces the wallpaper
dim overlay from `0.35` to `0.12`.

The KWin script approach is not enough to justify a fullscreen
`coverswitch_g20` yet.

## What was tested

Installed a proof-of-concept ordinary KWin script at:

`~/.local/share/kwin/scripts/tabbox-panel-raise/`

It can:

- Find the Plasma panel as a managed dock window.
- Set `panel.keepAbove = true`.
- Call `workspace.raiseWindow(panel)`.
- Notice the tabbox surface indirectly through `workspace.windowAdded`.

Runtime journal output:

```text
panel-raise: loaded; ordinary KWin scripts have no tabbox-open signal
panel-raise: startup: found 1 dock window(s)
panel-raise: startup: before caption= dock=true managed=true keepAbove=false layer=3 geometry=0,1040 1920x40
panel-raise: startup: after  caption= dock=true managed=true keepAbove=true layer=3 geometry=0,1040 1920x40
panel-raise: windowAdded: caption= dock=false managed=true keepAbove=false layer=9 geometry=0,0 1920x1040
coverswitch_g19 windowGeometry: 0 0 1920 1040 panelReserve 40
```

## API findings

Official KWin scripting API:

- Ordinary `KWin/Script` exposes `workspace.windowAdded`,
  `workspace.windowActivated`, `workspace.raiseWindow(window)`, `window.dock`,
  and writable `window.keepAbove`.
- `tabBoxAdded`, `tabBoxClosed`, and `tabBoxUpdated` are documented under the
  scripted effects API, not ordinary KWin scripts.
- The g19 tabbox window did show up through the generic `windowAdded` signal,
  but as a non-dock window with `layer=9`, not as a typed tabbox event.

Local headers:

- `/usr/include/kwin/window.h` confirms `dock` is read-only and `keepAbove` is
  writable on managed `Window` objects.
- `/usr/include/kwin/workspace.h` confirms `raiseWindow(Window *)`.
- `/usr/include/kwin/effect/globals.h` orders layers with `AboveLayer` before
  `OverlayLayer`. The panel stayed at layer `3` after `keepAbove`; the tabbox
  surface appeared at layer `9`.

## Conclusion

Do not switch to fullscreen g20 based on the ordinary script alone. The script
can react when the tabbox surface is created, but the observed layer ordering
still says `keepAbove` + `raiseWindow(panel)` is probably insufficient to place
the panel above a tabbox overlay surface. A real fullscreen-with-panel solution
would likely need either a scripted effect that participates in tabbox handling
or a lower-level KWin/plugin change that can place the panel above that surface.

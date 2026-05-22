# Cover Switch multi-monitor panel regression

**Date:** 2026-05-22  
**Time:** 22:54:33 UTC

## Current status

The Cover Switch Alt+Tab geometry is currently not solved. During the latest
debugging pass, several uncommitted edits were made to both:

- `assets/coverswitch/contents/ui/main.qml`
- `~/.local/share/kwin/tabbox/coverswitch/contents/ui/main.qml`

The user reports the current result is still broken:

- Black side edges remain, even with only the external monitor enabled.
- Earlier attempts also made the tabbox overlap or hide the panel/taskbar.
- The previous committed behavior was closer for panel visibility, but failed
  on extended display because the switcher could split across laptop and
  monitor.

Do not assume the current uncommitted QML is a good baseline.

## Required behavior

Cover Switch must satisfy all of these at the same time:

- The panel/taskbar must always remain visible during Alt+Tab.
- The tabbox surface must never overlap the panel, even slightly.
- There must be no black edges on the left or right.
- It must work with only the laptop screen, only the monitor, and extended
  display with either screen primary.
- It must be dynamic. Do not hardcode monitor sizes or panel heights.
- Apply any final fix to both the repo asset and the installed live copy if
  testing locally.

## Important old finding

The panel cannot be revealed with transparency. KWin tabbox surfaces are above
the panel layer, so the only reliable way to keep the panel visible is for the
tabbox window to physically not occupy the panel region.

The previous working single-screen pattern was:

```qml
Window {
    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
    visibility: Window.Windowed
    height: Math.max(1, rawScreenHeight - tabBox.panelReserve)
}
```

The unresolved problem is choosing a truly full-width per-output rectangle
without falling back to global or virtual desktop geometry that spans outputs.

## What went wrong in the latest attempt

Several geometry sources were tried:

- `tabBox.screenGeometry`: avoids spanning, but historically produced black
  side bars because it was not the raw output width on this Wayland setup.
- `Screen.width` / `Screen.height`: worked in the old single-screen case, but
  can be wrong with multi-monitor or cached screen state.
- `Screen.desktopAvailableWidth` / `Screen.desktopAvailableHeight`: helped the
  old black-bar case, but can behave like global/virtual desktop geometry and
  caused the switcher to split across displays.
- `KWin.Workspace.clientArea(KWin.MaximizeArea, ...)`: good for calculating the
  panel reserve, but using it as the whole window rectangle can create side
  gaps because it is a work area, not the raw output rectangle.
- `KWin.Workspace.clientArea(KWin.ScreenArea, ...)`: should represent the raw
  output, but the current edits still did not resolve the observed black edges,
  so the runtime QML values need to be measured before further changes.

## Recommended next step

Before changing QML again, add a temporary diagnostic log or probe that captures
the actual runtime values during Alt+Tab:

- `tabBox.screenGeometry`
- `Screen.width`, `Screen.height`
- `Screen.virtualX`, `Screen.virtualY`
- `KWin.Workspace.clientArea(KWin.ScreenArea, output, desktop)`
- `KWin.Workspace.clientArea(KWin.MaximizeArea, output, desktop)`
- final `window.x`, `window.y`, `window.width`, `window.height`
- final `panelReserve`

Only after those values are known should the geometry be changed again.

## Caution

The live installed copy may differ from the last committed known-good behavior.
If the immediate goal is to recover the old panel-visible behavior, compare or
restore from the last committed `assets/coverswitch/contents/ui/main.qml` first,
then re-apply a smaller multi-monitor fix.

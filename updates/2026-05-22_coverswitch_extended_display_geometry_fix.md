# 2026-05-22 23:09 UTC - Cover Switch Extended Display Geometry Fix

## Issue
- Cover Switch worked correctly when only one output was enabled.
- In extended-display mode, Cover Switch could span both laptop and monitor.
- Failed intermediate fixes caused black left/right edges on the primary laptop display.

## Confirmed Fix
- Keep the previous working single-screen behavior:
  - `Screen.width`
  - `Screen.height`
  - original `safeBackdrop`, `KWin.DesktopBackground`, and dark overlay sizing
  - original `output: KWin.Workspace.screenAt(...)` desktop background binding
- Remove only the virtual desktop sizing:
  - `Screen.desktopAvailableWidth`
  - `Screen.desktopAvailableHeight`

## Reason
- `Screen.width` / `Screen.height` are needed for the no-black-edge behavior seen in the
  known-good single-screen version.
- `Screen.desktopAvailableWidth` / `Screen.desktopAvailableHeight` can represent the combined
  virtual desktop in an extended-display layout, which caused Cover Switch to split across
  laptop and monitor.

## Verification
- User tested the live QML after KWin reload.
- Extended display no longer splits Cover Switch across laptop and monitor.
- Primary laptop screen has no black left/right edges.
- Monitor screen has no black left/right edges.
- Panel/taskbar-safe behavior from the previous working commit is preserved.

## Notes
- `~/.local/share/plasmalogin/wayland-session.log` was empty during debugging.
- `journalctl --user` had no useful KWin/QML entries in the live session.
- KWin support info confirmed physical output geometry:
  - eDP-1: `0,0,1920x1080`
  - HDMI-A-1: `1920,0,2560x1440`
  - scale `1` on both outputs

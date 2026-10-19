# ShojiWM desktop: shoji-picks icons, fork commit 77e3960

- Date: 2026-10-19 22:34 UTC (2026-10-20 00:34 CEST)

## Files changed

- `shojiwm/icons/build.py` (new): builds the theme
- `shojiwm/icons/shoji-picks/` (new): the built theme, 260 files
- `shojiwm/icons/README.md` (new): the icon rules and picks
- `shojiwm/install.sh`: step 7 installs the icons; fork commit 2ccc3b9 -> 77e3960

## Problem

- Yaru put generic icons on some System Settings pages.
- The folders were blue. Abhishek wants Windows yellow, with the symbols kept.
- Some app icons were not the ones he wants: Spectacle, Kate, KWrite, Dolphin,
  and the calculator "=".

## Intended behaviour

- Every icon keeps its own shape, and the dark-theme variants are used.
- Calculator: orange "=" (Mac). Spectacle: scissors (Windows Snipping Tool).
- Dolphin: open Microsoft yellow folder, no blue bar. Settings app: Ubuntu (Yaru) gear. Kate: Windows Notepad. KWrite: yellow notes pad.
- Folders: yellow, with amber symbols (house, page, arrow, note, picture, film).
- Settings: Win11 icons, one per page; Breeze where Win11 repeats one.

The fork commit 77e3960 brings the latest ShojiWM config:

- windows keep sizes on swap
- close goes back to the left page
- 14 px traffic lights
- minimized windows come back at their old size
- Super+Shift+H restores the last minimized window

## Tested

- Rendered all 74 Settings icon names, the folders and the taskbar apps
  with Qt's icon lookup (offscreen) in shoji-picks. All resolve to the
  intended files.
- `bash -n shojiwm/install.sh` passes.
- Set live with `/usr/lib/plasma-changeicons shoji-picks`.
- Not tested: a full fresh run of `install.sh`.

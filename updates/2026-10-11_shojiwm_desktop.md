# ShojiWM desktop session

- Date: 2026-10-11
- Time: 20:43 UTC

## Files changed

- `shojiwm/` (new):
  - `patches/`: 33 ShojiWM commits on top of upstream `13c8eca`.
  - `config/`: a snapshot of the ShojiWM config.
  - `lockscreen/hyprlock.conf`
  - `install.sh`
  - `README.md`
- `assets/plasmoids/cachyos-workspace-indicator/contents/ui/main.qml`: a click now switches through `contents/code/switch.sh`.
- `assets/plasmoids/cachyos-workspace-indicator/contents/code/switch.sh` (new).
- `README.md`: a short section that points to `shojiwm/`.

## Problem

Abhishek wants ShojiWM's tiling, Alt+Tab and effects, but with his KDE look:
taskbar, Kickoff, calendar, workspace circles, Wobbly and Magic Lamp.
Without KWin, plasmashell had no window list, no popup placement and no desktops.
Spectacle could not capture.

## Intended behaviour

ShojiWM is a second login session with the same KDE look. See `shojiwm/README.md`.

## Workspace circles widget

`VirtualDesktopInfo.requestActivate` cannot be called from QML. So the old
fallback (`qdbus6 org.kde.KWin /KWin setCurrentDesktop`) did nothing under ShojiWM.
`switch.sh` now uses ShojiWM's IPC socket when the desktop id is `MONITOR:INDEX`,
and KWin's `VirtualDesktopManager.current` otherwise.

## Tested

The tests ran on the live ShojiWM session on DP-2 at 2560x1440.

Checked with screenshots:
- Taskbar, Kickoff with apps, and the calendar popup.
- Workspace circles.
- The Window View.
- Magic Lamp and Coverflow, captured mid-animation.

Checked with commands:
- Spectacle full-screen and active-window captures.
- `cargo test -p shojiwm_lib`: 279 passed.

Patches:
- The 33 patches were applied with `git am` to a clean clone at upstream `13c8eca`.
- The resulting tree is identical to the working branch (tree `527c118`).

## Not tested

- `shojiwm/install.sh` end to end on a fresh machine (build and sudo install).
- A real click on a workspace circle under plain KWin. `switch.sh` was only run
  under ShojiWM.
- Multi-monitor.

## Remaining risk

- A big KDE update can change the protocols, which can break the taskbar under ShojiWM.
- Plain KDE is not affected.

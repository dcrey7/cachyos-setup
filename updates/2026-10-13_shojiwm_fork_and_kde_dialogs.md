# ShojiWM: install from the fork, KDE file dialogs

- Date: 2026-10-13
- Time: 22:28 UTC (00:28 CEST)

## Files changed

- `shojiwm/install.sh`:
  - clones the fork `dcrey7/ShojiWM` at a pinned commit (`FORK_COMMIT`)
  - installs `xdg-desktop-portal-kde`
  - sets the KDE file and app chooser
- `shojiwm/patches/`: removed.
- `shojiwm/config/`: refreshed from the pinned commit.
- `shojiwm/README.md`: the install steps, the file table and the keys table.

## Problem

1. **The upload dialog was broken.** ShojiWM's `dist/install.sh` rewrites `~/.config/xdg-desktop-portal/shojiwm-portals.conf` with GTK dialogs only. GTK's file chooser draws an empty frame around itself on ShojiWM, as seen in the Chrome and WhatsApp upload dialog.
2. **The patches were out of date.** Our branch now merges upstream `main`, and a merge does not export well as `git format-patch` patches.

## Intended behaviour

- File pickers open KDE's dialog. It floats, centred, also on tiled workspaces.
- The installer builds exactly the tested fork commit.

## Tested

- `bash -n shojiwm/install.sh`: the syntax is OK.
- The portal settings, applied by hand on the live machine: a FileChooser request opens `org.freedesktop.impl.portal.desktop.kde`.
- The pinned commit `f6c70e2`:
  - `cargo test --workspace`: 383 passed, 0 failed
  - the TypeScript suites pass

## Not tested

- `shojiwm/install.sh` end to end on a fresh machine.

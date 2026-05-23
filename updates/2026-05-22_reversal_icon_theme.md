# 2026-05-22 - Reversal Icon Theme

## Change
- Replaced the Win11 icon theme install path with Reversal.
- `install.sh` now installs `reversal-icon-theme-git` from AUR.
- `install.sh` prefers `Reversal-dark` and falls back to `Reversal`.
- `README.md` now documents Reversal as the global Plasma icon theme.
- `uninstall.sh` can remove `reversal-icon-theme-git` when it was installed by this setup.

## Compatibility
- `uninstall.sh` keeps legacy cleanup for `win11-icon-theme-git` so older installs can still be cleaned up.

## Live State
- Current machine already has `reversal-icon-theme-git` installed.
- Current Plasma icon theme is `Reversal-dark`.

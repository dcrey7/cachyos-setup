# cachyos-setup

Post-install KDE Plasma 6 tweaks for CachyOS. The installer is idempotent and can be re-run safely.

## What it installs

- WhiteSur-Dark window decoration with buttons kept on the right.
- Darkly Qt application style, Darkly color scheme, and transparent Darkly widget opacity settings.
- Breeze Dark Plasma desktop theme so `panelOpacity=translucent` actually makes panels see-through.
- KWin effects: Magic Lamp, Wobbly Windows, Glide, Sheet, Fade Desktop, Cube, tuned blur, and a custom Cover Switch zoom-in activation effect.
- Cover Switch and Flip Switch tabbox layouts rescued from the KDE MR !91 fork; Cover Switch refreshes the bottom panel reserve from KWin at Alt+Tab runtime, uses thumbnail zoom open/close transitions, and wraps through windows while forcing wrap animations to travel through the stack.
- Panel layout tweaks, a custom circular numbered workspace indicator next to Kickoff, centered taskbar with spacers, non-floating translucent panels, battery percentage, and clock layout.
- Centered floating KRunner, with the Meta key bound to open centered search instead of Kickoff.
- Custom Kickoff application-menu icon from `assets/icons/`.
- Custom Plasma 6 workspace-indicator plasmoid from `assets/plasmoids/`.
- Transparent Konsole profile and colorscheme from `assets/konsole/`.
- VSCode native title bar settings when VSCode is present.
- Optional `zsh-setup` integration from `https://github.com/dcrey7/zsh-setup`.

## Run

```bash
bash install.sh
```

Rebuild Darkly even if it is already installed:

```bash
bash install.sh --force-darkly
```

The script creates timestamped backups under `~/.config/cachyos-setup-backup-*` and updates `~/.config/cachyos-setup-backup-latest`.

`bash uninstall.sh` restores those backups when available, removes generated theme/plasmoid/KWin/Konsole assets, resets known fallback defaults, and best-effort runs `~/zsh-setup/uninstall.sh`.

## Live USB caveat

If this is run from a live session, changes usually do not persist after reboot. Run it from the installed CachyOS system for permanent configuration.

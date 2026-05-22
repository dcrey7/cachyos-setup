# Uninstall Rewrite

Rewrote `uninstall.sh` to track the full `install.sh` surface area instead of only a small KWin/panel subset.

- Keeps backup restore as the first and cleanest path for `kwinrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `kglobalshortcutsrc`, `kdeglobals`, `darklyrc`, `konsolerc`, and `krunnerrc`.
- Adds fallback Plasma 6 default resets for decoration, KWin effects, tabbox, shortcuts, KRunner, panel opacity/floating, battery, pager, Kickoff icon, workspace indicator, touchpad natural scrolling, and Konsole when a backup file is unavailable.
- Removes generated user assets: Cover Switch, Flip Switch, coverswitch-zoom-in, workspace indicator plasmoid, custom Kickoff icon, and transparent Konsole profile/colorscheme.
- Uses KWin effect unload/load calls and a plasmashell restart so deleted effects and plasmoids are not kept alive in memory.
- Calls `~/zsh-setup/uninstall.sh` best-effort and documents limitations in the script caveats.
- Leaves packages and the system Darkly plugin in place by default, with explicit flags for package/Darkly removal.

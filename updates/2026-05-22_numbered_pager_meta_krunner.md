# Circular workspace indicator and Meta-to-KRunner automation

`install.sh` now installs a tiny Plasma 6 plasmoid at:

```text
~/.local/share/plasma/plasmoids/cachyos.workspace-indicator
```

The source lives under `assets/plasmoids/cachyos-workspace-indicator/`. It
renders virtual desktops as circular numbered buttons with the active desktop
filled using the Plasma highlight color.

Existing `org.kde.plasma.pager` panel applets are rewritten in-place to use
`plugin=cachyos.workspace-indicator`, preserving the same applet ID and
`AppletOrder` slot. If a panel has Kickoff but no pager/indicator, the script
adds the new applet immediately after Kickoff. Re-running remains idempotent
and does not duplicate the indicator.

The QML uses `org.kde.taskmanager`'s `VirtualDesktopInfo` for desktop count,
IDs, and current-desktop tracking on Plasma 6.6. Click activation targets KWin
desktop numbers through the session's KWin D-Bus endpoint.

The Meta key shortcut is moved from Kickoff to KRunner:

```ini
[plasmashell]
activate application launcher=none,Meta,Activate Application Launcher

[krunner.desktop]
_launch=Meta,Alt+Space,Run Command Interface
```

The script asks `kglobalaccel` and KWin to re-read the changed shortcuts and
restarts `plasmashell` so the live session picks up the new ownership.

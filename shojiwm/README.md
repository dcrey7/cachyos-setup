# ShojiWM desktop

A second login session next to plain KDE. It runs [ShojiWM](https://github.com/bea4dev/ShojiWM)
(a Wayland compositor configured in TypeScript) instead of KWin. KDE's
plasmashell still draws the taskbar, Kickoff, calendar and notifications.

```
┌──────────────────────────────────────────────────┐
│ KDE plasmashell: taskbar, Kickoff, calendar,     │
│ notifications, wallpaper, workspace circles      │
├──────────────────────────────────────────────────┤
│ ShojiWM (replaces KWin): scrolling tiling,       │
│ Coverflow Alt+Tab, liquid glass, Wobbly drag,    │
│ Magic Lamp, Window View, Mac traffic lights      │
└──────────────────────────────────────────────────┘
```

Plain KDE is untouched: pick "Plasma" at the login screen to use it.

## Install

```bash
bash shojiwm/install.sh
```

It asks for your password once. Then log out and pick "ShojiWM" at login.

What it does:

1. Installs `seatd`, `hyprlock`, `swayidle`, `python-gobject`, `python-pyqt6` and `grim`.
2. Clones upstream ShojiWM to `~/Downloads/work/ShojiWM` (or `$SHOJIWM_SRC_DIR`),
   checks out commit `13c8eca` and applies `patches/` on branch `cachyos-shojiwm`.
3. Builds and installs it with ShojiWM's own `dist/install.sh`.
4. Copies the config to `~/.config/shojiwm/src` and backs up the old one.
5. Copies the hyprlock lock screen, if you have none.
6. Installs the workspace circles widget.

## What is in here

| Path | What it is |
|---|---|
| `patches/` | Our ShojiWM commits on top of upstream (`git format-patch`). |
| `config/` | A readable copy of the ShojiWM config the patches install. |
| `lockscreen/hyprlock.conf` | The lock screen: blurred wallpaper, clock, password field. |
| `install.sh` | The installer above. |

The workspace circles widget lives with the other plasmoids in
`assets/plasmoids/cachyos-workspace-indicator`.

## What the patches add to ShojiWM

KDE protocols, so plasmashell works without KWin:

- `org_kde_plasma_window_management`: the taskbar lists, groups and activates windows.
- `org_kde_plasma_shell`: Kickoff, the calendar and other popups float where Plasma asks.
- `org_kde_plasma_virtual_desktop_management`: workspaces for the workspace circles.
- `xdg_toplevel_tag_v1`: stops Spectacle's region mode from crashing.

KWin D-Bus stand-ins (small helpers in `config/src/helpers/`):

- `org.kde.KWin.Effect.WindowView1`: a click on a grouped taskbar icon shows that app's windows side by side.
- `org.kde.KWin.ScreenShot2`: Spectacle works (Print, Super+Print, Shift+Print, Super+Shift+S).

Effects, ported from their original code:

- Wobbly drag: KWin's wobblywindows physics, level 2, with 80% opacity while dragging.
- Magic Lamp: KWin's magiclamp, into and out of the app's taskbar icon. It runs on minimize, restore and app open.
- Coverflow Alt+Tab: GNOME's Coverflow Alt-Tab layout, with Flip 3D's intro, outro, backdrop and white glow.
- Sliding popups: KWin's slidingpopups. Kickoff, the calendar and the tray popups slide out of the panel (150 ms).
- Window grid (Super+Tab) and Window View: windows in balanced rows and columns. The hovered card shows the traffic lights, so you can close, minimize or maximize from the view.

Session pieces:

- plasmashell runs with `XDG_CURRENT_DESKTOP=KDE` and `XDG_MENU_PREFIX=plasma-`.
- kglobalacceld runs on its X11 backend, so Kickoff has its shortcut.
- The polkit agent, hyprlock and swayidle run, and Ctrl+Alt+Delete logs out.

## Keys

| Key | Action |
|---|---|
| Super tap | Kickoff |
| Alt+Tab | Coverflow switcher |
| Super+Tab | Window grid: every window, in rows and columns |
| Super+Down | Window View of the app you used last |
| Super+N, Super+FN, Ctrl+FN | Go to workspace N |
| Super+Shift+N | Send the focused window to workspace N |
| Super+Ctrl+Up/Down | Previous / next workspace |
| Super+Alt+Up/Down | Focus up / down inside a stacked column |
| Super+L | Lock |
| Ctrl+Alt+Delete | Log out |
| Print, Super+Print, Shift+Print, Super+Shift+S | Spectacle |

## Known gaps

- Closing a window uses ShojiWM's animation, not KWin's Glide.
- Spectacle "window under cursor" captures the active window. Screen recording does not work.
- ShojiWM's tile animation takes 500 ms. KDE's geometry change takes 62.5 ms.

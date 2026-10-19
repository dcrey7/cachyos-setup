# shoji-picks icon theme

A small icon theme with hand-picked icons. For every other icon it falls back
to Yaru-blue-kde, then Breeze dark, then the app's own icon.

## The rules

1. Every icon keeps its own shape. No circle or square mask on app icons.
2. Pick the best icon per app, from Mac, Windows or Linux styles.
3. The desktop is dark: take dark-theme variants (Win11-dark, breeze-dark).
4. Settings pages: one different icon per page. No repeats.

## The picks

| What | Icon | Source |
|---|---|---|
| Calculator (KCalc) | Yaru, the blue "=" made orange like the Mac one | Yaru-blue, recoloured |
| Screenshot (Spectacle) | Scissors, like the Windows Snipping Tool | Win11-dark |
| File manager (Dolphin) | Open Microsoft yellow folder, no blue bar | Win11-dark |
| Settings app | Ubuntu gear | Yaru |
| Folders (Home, Documents, Pictures, ...) | Yaru folders in Windows yellow, symbols in amber | Yaru-blue, recoloured |
| Kate | Windows Notepad | Win11-dark |
| KWrite | Yellow notes pad, like Apple Notes | Win11-dark |
| System Settings pages | Win11; Breeze where Win11 repeats an icon | Win11-dark, breeze-dark |

VS Code, Chrome, OBS and the terminal keep the icons they have now.

## Change a pick

1. Edit the lists at the top of `build.py`.
2. Build: `uv run shojiwm/icons/build.py`
3. Install: copy `shoji-picks` to `~/.local/share/icons/`, then run
   `/usr/lib/plasma-changeicons shoji-picks`.

`build.py` reads the Win11-dark and Yaru-blue-kde themes from
`~/.local/share/icons`. The main `install.sh` installs Win11; Yaru-blue-kde is
a local build (see the ShojiWM setup notes).

## Licence

The Win11 icons come from the Win11 icon theme by yeyushengfan258 (GPL-3.0).
The Yaru icons come from Ubuntu's Yaru theme (CC BY-SA 4.0). The Breeze icons
come from KDE (LGPL-3.0).

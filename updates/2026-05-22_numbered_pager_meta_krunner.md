# Numbered pager and Meta-to-KRunner automation

`install.sh` now configures existing `org.kde.plasma.pager` panel applets to
show desktop numbers instead of miniature desktop previews:

```ini
[Containments][<panel_id>][Applets][<pager_id>][Configuration][General]
displayedText=Number
currentDesktopSelected=DoNothing
showWindowOutlines=false
```

The pager applet is also reconciled in `AppletOrder` so the first pager on a
panel sits immediately after Kickoff. Existing spacer and margin-separator
logic is preserved, and missing pagers are left alone.

The Meta key shortcut is moved from Kickoff to KRunner:

```ini
[plasmashell]
activate application launcher=none,Meta,Activate Application Launcher

[krunner.desktop]
_launch=Meta,Alt+Space,Run Command Interface
```

The script asks `kglobalaccel` and KWin to re-read the changed shortcuts and
restarts `plasmashell` so the live session picks up the new ownership.

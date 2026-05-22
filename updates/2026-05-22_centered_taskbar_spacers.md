# Centered taskbar spacers are now automated

**Date:** 2026-05-22

`install.sh` now reconciles each Plasma panel's `AppletOrder` so the
`org.kde.plasma.icontasks` taskbar is flanked by
`org.kde.plasma.panelspacer` widgets. This preserves existing applets such as
Kickoff, Pager, System Tray, and Digital Clock, and only adds missing spacer
applets when needed.

The installer discovers panel containment IDs dynamically, allocates new
applet IDs above the current maximum applet ID, writes spacer applet blocks via
`kwriteconfig6`, and restarts `plasmashell` so the live session picks up the
updated panel config without requiring logout.

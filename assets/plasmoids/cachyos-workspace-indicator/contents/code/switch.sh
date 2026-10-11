#!/usr/bin/env bash
# Switch to a workspace. $1 is the desktop id from the Pager data:
# - under ShojiWM it is "MONITOR:INDEX" (for example "DP-2:3"),
# - under KWin it is a desktop UUID.
set -u
id="${1:-}"
socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/shojiwm-${WAYLAND_DISPLAY:-wayland-0}.sock"

if [[ "$id" == *:* && -S "$socket" ]]; then
    monitor="${id%:*}"
    index="${id##*:}"
    printf '{"method":"workspaces.activate","params":{"monitor":"%s","index":%d}}\n' \
        "$monitor" "$index" | python3 -c '
import socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.sendall(sys.stdin.buffer.read())
' "$socket"
else
    busctl --user set-property org.kde.KWin /VirtualDesktopManager \
        org.kde.KWin.VirtualDesktopManager current s "$id"
fi

#!/usr/bin/env bash
# Build KDE's taskbar with the Mac-style hover zoom and install it for this
# user (no sudo). The ShojiWM config starts plasmashell with this plugin only
# while plasma-desktop is the version written to built-for.
#
#   bash shojiwm/dock-zoom/install.sh      build, install, restart the panel
#   bash shojiwm/dock-zoom/uninstall.sh    back to the normal taskbar
#
# After a KDE update, the taskbar has no zoom until you run this again
# (with the matching plasma-desktop source; see README.md).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${XDG_CACHE_HOME:-$HOME/.cache}/dock-zoom-build"
DEST="$HOME/.local/lib/dock-zoom"

echo "==> Build (cmake, Release)"
cmake -Wno-dev -S "$HERE" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD" -j"$(nproc)"

echo "==> Install to $DEST"
mkdir -p "$DEST/plugins/plasma/applets"
install -m755 "$BUILD/bin/plasma/applets/org.kde.plasma.taskmanager.so" \
    "$DEST/plugins/plasma/applets/org.kde.plasma.taskmanager.so"
pacman -Q plasma-desktop > "$DEST/built-for"
echo "    built for: $(cat "$DEST/built-for")"

echo "==> Restart the panel (ShojiWM starts it again)"
pkill -x plasmashell || true

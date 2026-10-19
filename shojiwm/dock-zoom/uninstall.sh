#!/usr/bin/env bash
# Remove the zoom taskbar: the normal KDE taskbar comes back.
set -euo pipefail
rm -rf "$HOME/.local/lib/dock-zoom"
pkill -x plasmashell || true
echo "Done: normal KDE taskbar."

#!/usr/bin/env bash
# Install the ShojiWM desktop: ShojiWM (a Wayland compositor) with the KDE
# Plasma shell on top, the look from this repo, and our ShojiWM changes.
#
#   KDE parts (plasmashell): taskbar, Kickoff, calendar, notifications
#   ShojiWM (replaces KWin):  tiling, Coverflow Alt+Tab, liquid glass,
#                              Wobbly drag, Magic Lamp, Window View
#
# Run it from your own terminal. It asks for your password once (pacman and
# the ShojiWM install need it):
#   bash shojiwm/install.sh
#
# Then log out (Ctrl+Alt+Delete inside ShojiWM) and pick "ShojiWM" at login.
# Plain KDE stays available: pick "Plasma" at login.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
SRC_DIR="${SHOJIWM_SRC_DIR:-$HOME/Downloads/work/ShojiWM}"
UPSTREAM_URL="https://github.com/bea4dev/ShojiWM.git"
# The upstream commit our patches apply on top of.
UPSTREAM_BASE="13c8eca5753b027e118ab051d941ff4208e65507"
BRANCH="cachyos-shojiwm"
CONFIG_DIR="$HOME/.config/shojiwm"

echo "==> 1/6  Packages ShojiWM needs (seat access, lock screen, idle lock)"
sudo pacman -S --needed seatd hyprlock swayidle python-gobject python-pyqt6 grim

if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo (Rust) is missing. Install rustup, then run this again:" >&2
    echo "  sudo pacman -S --needed rustup && rustup default stable" >&2
    exit 1
fi

echo "==> 2/6  ShojiWM source at $SRC_DIR (upstream $UPSTREAM_BASE + our patches)"
if [[ ! -d "$SRC_DIR/.git" ]]; then
    git clone "$UPSTREAM_URL" "$SRC_DIR"
fi
git -C "$SRC_DIR" fetch origin
if git -C "$SRC_DIR" rev-parse --verify --quiet "$BRANCH" >/dev/null; then
    echo "    branch $BRANCH already exists; leaving it as it is"
    git -C "$SRC_DIR" switch "$BRANCH"
else
    git -C "$SRC_DIR" switch -c "$BRANCH" "$UPSTREAM_BASE"
    git -C "$SRC_DIR" -c user.name="cachyos-setup" -c user.email="cachyos-setup@localhost" \
        am --committer-date-is-author-date "$HERE"/patches/*.patch
fi

echo "==> 3/6  Build and install ShojiWM (cargo build, then sudo install)"
# dist/install.sh keeps an existing ~/.config/shojiwm; step 4 updates it.
(cd "$SRC_DIR" && ./dist/install.sh)

echo "==> 4/6  ShojiWM config -> $CONFIG_DIR/src (old one backed up)"
if [[ -d "$CONFIG_DIR/src" ]]; then
    cp -a "$CONFIG_DIR/src" "$CONFIG_DIR/src.backup-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$CONFIG_DIR/src"
cp -a "$SRC_DIR/packages/config/src/." "$CONFIG_DIR/src/"

echo "==> 5/6  Lock screen (hyprlock) config"
mkdir -p "$HOME/.config/hypr"
if [[ -f "$HOME/.config/hypr/hyprlock.conf" ]]; then
    echo "    keeping your existing ~/.config/hypr/hyprlock.conf"
else
    cp "$HERE/lockscreen/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
fi

echo "==> 6/6  Workspace circles widget (also installed by the main install.sh)"
PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/cachyos.workspace-indicator"
rm -rf "$PLASMOID_DEST"
mkdir -p "$(dirname "$PLASMOID_DEST")"
cp -r "$REPO_ROOT/assets/plasmoids/cachyos-workspace-indicator" "$PLASMOID_DEST"
chmod +x "$PLASMOID_DEST/contents/code/switch.sh"

echo
echo "Done. Log out and pick ShojiWM at the login screen."

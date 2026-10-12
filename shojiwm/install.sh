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
# Our ShojiWM: upstream bea4dev/ShojiWM plus the KDE Plasma work, on our fork.
FORK_URL="https://github.com/dcrey7/ShojiWM.git"
# The fork commit this setup is tested with (branch kde-plasma-session).
FORK_COMMIT="f6c70e2b99a99d9ec7a3224ecdd1b6c09ce7953a"
BRANCH="cachyos-shojiwm"
CONFIG_DIR="$HOME/.config/shojiwm"
PORTALS_CONF="$HOME/.config/xdg-desktop-portal/shojiwm-portals.conf"

echo "==> 1/6  Packages ShojiWM needs (seat access, lock screen, idle lock)"
sudo pacman -S --needed seatd hyprlock swayidle python-gobject python-pyqt6 grim xdg-desktop-portal-kde

if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo (Rust) is missing. Install rustup, then run this again:" >&2
    echo "  sudo pacman -S --needed rustup && rustup default stable" >&2
    exit 1
fi

echo "==> 2/6  ShojiWM source at $SRC_DIR (fork commit ${FORK_COMMIT:0:7})"
if [[ ! -d "$SRC_DIR/.git" ]]; then
    git clone "$FORK_URL" "$SRC_DIR"
fi
if ! git -C "$SRC_DIR" remote get-url cachyos-fork >/dev/null 2>&1; then
    git -C "$SRC_DIR" remote add cachyos-fork "$FORK_URL"
fi
git -C "$SRC_DIR" fetch cachyos-fork kde-plasma-session
if git -C "$SRC_DIR" rev-parse --verify --quiet "$BRANCH" >/dev/null; then
    echo "    branch $BRANCH already exists; leaving it as it is"
    git -C "$SRC_DIR" switch "$BRANCH"
else
    git -C "$SRC_DIR" switch -c "$BRANCH" "$FORK_COMMIT"
fi

echo "==> 3/6  Build and install ShojiWM (cargo build, then sudo install)"
# dist/install.sh keeps an existing ~/.config/shojiwm; step 4 updates it.
(cd "$SRC_DIR" && ./dist/install.sh)

# dist/install.sh writes the portal settings with GTK dialogs only. GTK's file
# chooser draws an empty frame on ShojiWM, so use KDE's (the Dolphin-style
# "Open" dialog) for files and for picking apps.
echo "    using KDE file dialogs ($PORTALS_CONF)"
mkdir -p "$(dirname "$PORTALS_CONF")"
cat > "$PORTALS_CONF" <<'EOF'
[preferred]
default=gtk
org.freedesktop.impl.portal.ScreenCast=shojiwm
org.freedesktop.impl.portal.FileChooser=kde
org.freedesktop.impl.portal.AppChooser=kde
EOF
systemctl --user restart xdg-desktop-portal || true

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

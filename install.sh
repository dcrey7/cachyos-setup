#!/usr/bin/env bash
# CachyOS / KDE Plasma 6 desktop tweaks:
#   - macOS WhiteSur-Dark window decoration with traffic-light buttons on the RIGHT
#   - Magic Lamp minimize animation
#   - Auto-patch VSCode to use native title bar (if installed)
#
# (Panel size/floating is left alone -- tweak that via Plasma's GUI:
#  right-click panel -> Panel Configuration -> drag the top edge to resize,
#  or use the "More Options" menu in edit mode for the Floating toggle.)
#
# Idempotent. Run again safely. Wayland-aware (Plasma 6 / KWin Wayland tested).
set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------
echo "==> 0/6  Sanity checks"

if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]]; then
  echo "    ERROR: This script targets KDE Plasma. XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}'." >&2
  exit 1
fi

if ! command -v plasmashell >/dev/null 2>&1; then
  echo "    ERROR: plasmashell not found." >&2
  exit 1
fi
plasma_ver="$(plasmashell --version 2>/dev/null | awk '{print $2}')"
echo "    Plasma: $plasma_ver"

if [[ "${plasma_ver%%.*}" -lt 6 ]]; then
  echo "    ERROR: This script targets Plasma 6.x. Detected $plasma_ver." >&2
  exit 1
fi

for cmd in kwriteconfig6 qdbus6 paru; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "    ERROR: '$cmd' not found in PATH." >&2
    exit 1
  fi
done
echo "    All required tools present (kwriteconfig6, qdbus6, paru)."

# ---------------------------------------------------------------------------
# 1. Back up config so uninstall can restore exactly
# ---------------------------------------------------------------------------
echo "==> 1/6  Backup current config"
ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.config/cachyos-setup-backup-$ts"
mkdir -p "$backup_dir"
if [[ -f "$HOME/.config/kwinrc" ]]; then
  cp "$HOME/.config/kwinrc" "$backup_dir/kwinrc"
  echo "    Backed up kwinrc -> $backup_dir/kwinrc"
fi
# Marker symlink uninstall.sh follows to find the latest backup
ln -sfn "$backup_dir" "$HOME/.config/cachyos-setup-backup-latest"
echo "    Latest backup symlinked at ~/.config/cachyos-setup-backup-latest"

# ---------------------------------------------------------------------------
# 2. Install WhiteSur KDE theme via AUR
# ---------------------------------------------------------------------------
echo "==> 2/6  WhiteSur-kde theme"
if pacman -Qi whitesur-kde-theme >/dev/null 2>&1; then
  echo "    Already installed (pacman db)."
  echo "installed_by_us=0" > "$backup_dir/whitesur.state"
else
  echo "    Installing via paru (sudo may prompt; needs build deps)..."
  paru -S --needed --noconfirm whitesur-kde-theme
  echo "installed_by_us=1" > "$backup_dir/whitesur.state"
fi

# Verify the aurorae theme dir actually exists somewhere KWin will look
if [[ ! -d /usr/share/aurorae/themes/WhiteSur-dark && ! -d "$HOME/.local/share/aurorae/themes/WhiteSur-dark" ]]; then
  echo "    WARNING: WhiteSur-dark aurorae theme directory not found after install." >&2
  echo "             Window decoration step may not apply until KWin can find the theme." >&2
fi

# ---------------------------------------------------------------------------
# 3. Window decoration: WhiteSur-Dark with buttons on the right
# ---------------------------------------------------------------------------
echo "==> 3/6  Window decoration (WhiteSur-Dark, buttons on right)"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key library  "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key theme    "__aurorae__svg__WhiteSur-dark"
# Layout: M (app menu) on the left, I=minimize A=maximize X=close on the right.
# Order is left-to-right within each side, so X (close) ends up at the far right edge.
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnLeft  "M"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnRight "IAX"
echo "    Aurorae theme + button layout written to ~/.config/kwinrc"

# ---------------------------------------------------------------------------
# 4. Magic Lamp minimize effect
# ---------------------------------------------------------------------------
echo "==> 4/6  Magic Lamp minimize effect"
kwriteconfig6 --file kwinrc --group "Plugins" --key magiclampEnabled         --type bool true
kwriteconfig6 --file kwinrc --group "Plugins" --key minimizeanimationEnabled --type bool false
echo "    Magic Lamp enabled, default minimize animation disabled"

# ---------------------------------------------------------------------------
# 5. Reload KWin so decoration + effects take effect (Wayland-safe)
# ---------------------------------------------------------------------------
echo "==> 5/6  Reloading KWin config"
if qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1; then
  echo "    KWin reconfigured."
else
  echo "    WARNING: qdbus6 KWin reconfigure failed. You may need to log out/in." >&2
fi

# ---------------------------------------------------------------------------
# 6. Per-app: VSCode native title bar (only if VSCode is installed)
# ---------------------------------------------------------------------------
echo "==> 6/6  Per-app title-bar tweaks"
vscode_settings="$HOME/.config/Code/User/settings.json"
if [[ -d "$HOME/.config/Code" ]]; then
  mkdir -p "$(dirname "$vscode_settings")"
  if [[ ! -f "$vscode_settings" ]]; then
    echo '{}' > "$vscode_settings"
  fi
  cp "$vscode_settings" "$backup_dir/Code-settings.json"
  # Use python to do a safe JSON edit (Plasma 6 always pulls python in via deps).
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$vscode_settings" <<'PY'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f: data = json.load(f)
except Exception:
    data = {}
data["window.titleBarStyle"] = "native"
data["window.customTitleBarVisibility"] = "never"
with open(p, "w") as f: json.dump(data, f, indent=2)
PY
    echo "    Patched VSCode settings.json (native title bar)."
  else
    echo "    python3 not found; skipping VSCode patch."
  fi
else
  echo "    VSCode not installed (~/.config/Code missing); skipping."
fi

# ---------------------------------------------------------------------------
echo ""
echo "✓ Done. Backup at: $backup_dir"
echo ""
echo "Manual one-time toggles for apps that draw their own title bar:"
echo ""
echo "  Firefox     about:config -> browser.tabs.inTitlebar = 0"
echo "              (or: Customize Toolbar -> tick 'Title Bar')"
echo ""
echo "  Chromium/   Settings -> Appearance -> 'Use system title bar and borders'"
echo "  Chrome/     (toggle on)"
echo "  Brave"
echo ""
echo "  Electron apps (Discord, Slack, Spotify) typically can't be changed."
echo ""
echo "If the title bar doesn't change on already-open windows, close and"
echo "reopen them -- KWin only re-decorates on next map. If decoration still"
echo "looks like the default, open:"
echo "  System Settings -> Window Decorations -> Apply"
echo "(KDE sometimes needs one manual click to fully commit the change.)"

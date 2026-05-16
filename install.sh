#!/usr/bin/env bash
# CachyOS / KDE Plasma 6 desktop tweaks:
#   - Taskbar: flush with bottom, height 40
#   - WhiteSur-Dark window decoration, traffic-light buttons on the RIGHT
#   - Magic Lamp minimize effect (700ms duration, independent of global anim speed)
#   - Battery applet: show percentage on icon, force always-visible in tray
#   - Auto-patch VSCode to use native title bar (if installed)
#
# Idempotent. Run again safely. Wayland-aware (Plasma 6 / KWin Wayland).
set -euo pipefail

# ---------------------------------------------------------------------------
echo "==> 0/7  Sanity checks"

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

for cmd in kwriteconfig6 kreadconfig6 qdbus6 paru python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "    ERROR: '$cmd' not found in PATH." >&2
    exit 1
  fi
done
echo "    All required tools present."

# ---------------------------------------------------------------------------
echo "==> 1/7  Backup current config"
ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.config/cachyos-setup-backup-$ts"
mkdir -p "$backup_dir"
for f in kwinrc plasma-org.kde.plasma.desktop-appletsrc; do
  if [[ -f "$HOME/.config/$f" ]]; then
    cp "$HOME/.config/$f" "$backup_dir/$f"
    echo "    Backed up $f"
  fi
done
ln -sfn "$backup_dir" "$HOME/.config/cachyos-setup-backup-latest"
echo "    Latest backup symlinked at ~/.config/cachyos-setup-backup-latest"

# ---------------------------------------------------------------------------
echo "==> 2/7  WhiteSur-kde theme (AUR)"
if pacman -Qi whitesur-kde-theme >/dev/null 2>&1; then
  echo "    Already installed."
  echo "installed_by_us=0" > "$backup_dir/whitesur.state"
else
  echo "    Installing via paru..."
  paru -S --needed --noconfirm whitesur-kde-theme
  echo "installed_by_us=1" > "$backup_dir/whitesur.state"
fi
if [[ ! -d /usr/share/aurorae/themes/WhiteSur-dark && ! -d "$HOME/.local/share/aurorae/themes/WhiteSur-dark" ]]; then
  echo "    WARNING: WhiteSur-dark aurorae theme directory not found." >&2
fi

# ---------------------------------------------------------------------------
echo "==> 3/7  Window decoration + buttons-on-right"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key library  "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key theme    "__aurorae__svg__WhiteSur-dark"
# Letters: M=menu, I=minimize, A=maximize, X=close. Left-to-right within each side.
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnLeft  "M"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnRight "IAX"
echo "    WhiteSur-dark; menu on left, min/max/close on right"

# ---------------------------------------------------------------------------
echo "==> 4/7  Magic Lamp minimize effect (700ms)"
# Plasma 6 default minimize effect is "squash", not the old "minimizeanimation".
kwriteconfig6 --file kwinrc --group "Plugins" --key squashEnabled    --type bool false
kwriteconfig6 --file kwinrc --group "Plugins" --key magiclampEnabled --type bool true
# Fixed 700ms; doesn't scale with global AnimationDurationFactor.
kwriteconfig6 --file kwinrc --group "Effect-magiclamp" --key AnimationDuration 700

# `KWin reconfigure` rereads kwinrc but does NOT load/unload effects on Wayland.
# We have to swap them explicitly via the Effects D-Bus interface.
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect squash    >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect   magiclamp >/dev/null 2>&1 || true
echo "    squash unloaded, magiclamp loaded (700ms genie)"

# ---------------------------------------------------------------------------
echo "==> 5/7  Panel: flush + height 40 + battery percentage"
# Find the systemtray containment and the battery child-applet ID dynamically,
# so this works on any Plasma 6 layout (IDs differ per system).
appletsrc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

# Parse the INI to find both the battery applet path (3 levels deep, inside
# systemtray) and the digital-clock applet path (2 levels deep, direct child
# of the panel). IDs differ per system, so we discover them rather than
# hard-coding.
read -r BAT_CID BAT_TRAY_AID BAT_AID CLOCK_CID CLOCK_AID < <(python3 - "$appletsrc" <<'PY'
import re, sys
path = sys.argv[1]
nested_re = re.compile(r"^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]\[Applets\]\[(\d+)\]$")
flat_re   = re.compile(r"^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]$")
plugin_re = re.compile(r"^plugin=(.+)$")

section_kind, section = None, None
battery = clock = None
with open(path) as f:
    for line in f:
        line = line.rstrip()
        m = nested_re.match(line)
        if m:
            section_kind, section = "nested", m.groups()
            continue
        m = flat_re.match(line)
        if m:
            section_kind, section = "flat", m.groups()
            continue
        m = plugin_re.match(line)
        if m and section:
            plug = m.group(1)
            if plug == "org.kde.plasma.battery" and section_kind == "nested":
                battery = section
            elif plug == "org.kde.plasma.digitalclock" and section_kind == "flat":
                clock = section
            section_kind, section = None, None
print(*(battery or ("", "", "")), *(clock or ("", "")))
PY
)
if [[ -n "$BAT_AID" ]]; then
  echo "    Battery applet path: Containments[$BAT_CID]/Applets[$BAT_TRAY_AID]/Applets[$BAT_AID]"
fi
TRAY_AID="$BAT_TRAY_AID"  # systemtray is the parent of the battery applet

# Plasmashell holds the in-memory state and overwrites file on graceful exit,
# so SIGKILL it, write the file, then restart. The panel disappears for ~1s.
echo "    Restarting plasmashell to apply battery + tray config (panel will flicker)..."
pkill -9 plasmashell 2>/dev/null || true
sleep 1

if [[ -n "$BAT_AID" ]]; then
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
    --group "Containments" --group "$BAT_CID" \
    --group "Applets" --group "$TRAY_AID" \
    --group "Applets" --group "$BAT_AID" \
    --group "Configuration" --group "General" \
    --key showPercentage --type bool true
  # Belt-and-braces: force battery to be in always-visible items.
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
    --group "Containments" --group "$BAT_CID" \
    --group "Applets" --group "$TRAY_AID" \
    --group "General" \
    --key shownItems "org.kde.plasma.battery"
  echo "    Battery: showPercentage=true, pinned to shownItems"
else
  echo "    WARNING: No battery applet found (desktop without battery?). Skipping."
fi

# Digital clock: time and date side by side instead of stacked
if [[ -n "$CLOCK_AID" ]]; then
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
    --group "Containments" --group "$CLOCK_CID" \
    --group "Applets" --group "$CLOCK_AID" \
    --group "Configuration" --group "Appearance" \
    --key dateDisplayFormat "BesideTime"
  echo "    Clock: date beside time (not stacked)"
fi

nohup kstart plasmashell >/dev/null 2>&1 & disown
sleep 3

# Panel size + floating via scripting API (works post-restart)
qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript '
  for (var id of panelIds) {
    var p = panelById(id);
    p.floating = false;
    p.height   = 40;
  }
' >/dev/null 2>&1 && echo "    Panel: floating=false, height=40"

# ---------------------------------------------------------------------------
echo "==> 6/7  VSCode native title bar (if installed)"
vscode_settings="$HOME/.config/Code/User/settings.json"
if [[ -d "$HOME/.config/Code" ]]; then
  mkdir -p "$(dirname "$vscode_settings")"
  [[ -f "$vscode_settings" ]] || echo '{}' > "$vscode_settings"
  cp "$vscode_settings" "$backup_dir/Code-settings.json"
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
  echo "    Patched VSCode settings.json"
else
  echo "    VSCode not installed; skipping."
fi

# ---------------------------------------------------------------------------
echo ""
echo "✓ Done. Backup at: $backup_dir"
echo ""
echo "Manual one-time toggles for apps with their own title bars:"
echo "  Firefox       about:config -> browser.tabs.inTitlebar = 0"
echo "  Chrome/Brave  Settings -> Appearance -> 'Use system title bar and borders'"
echo ""
echo "Keyboard shortcuts you may want to know:"
echo "  Meta + Up      -> Quick-tile top half"
echo "  Meta + Down    -> Quick-tile bottom half (or restore from tile)"
echo "  Meta + Left/Right -> Quick-tile left/right half"
echo "  Meta + PgUp    -> Maximize / unmaximize"
echo ""
echo "Window decoration sometimes needs a click in System Settings to fully commit:"
echo "  System Settings -> Window Decorations -> Apply"

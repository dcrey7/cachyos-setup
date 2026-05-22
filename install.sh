#!/usr/bin/env bash
# CachyOS / KDE Plasma 6 desktop tweaks:
#   - Taskbar: flush with bottom edge
#   - Darkly application style with transparent widgets
#   - WhiteSur-Dark window decoration, traffic-light buttons on the RIGHT
#   - Magic Lamp minimize effect (700ms duration, independent of global anim speed)
#   - Eye candy: Wobbly Windows (drag), Glide (open), Sheet (dialogs)
#   - Blur tuning, translucent Breeze Dark panel, centered KRunner
#   - Custom Kickoff application-menu icon
#   - Transparent Konsole profile
#   - Fade Desktop animation when switching virtual desktops (replaces Slide)
#   - Cube effect via kdeplasma-addons (Meta+C to activate)
#   - Battery applet: show percentage on icon, force always-visible in tray
#   - Auto-patch VSCode to use native title bar (if installed)
#   - Optional zsh-setup integration
#
# Idempotent. Run again safely. Wayland-aware (Plasma 6 / KWin Wayland).
set -euo pipefail

# ---------------------------------------------------------------------------
echo "==> 0/12  Sanity checks"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$REPO_DIR/assets"
appletsrc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
FORCE_DARKLY=0
for arg in "$@"; do
  case "$arg" in
    --force-darkly) FORCE_DARKLY=1 ;;
    *)
      echo "    ERROR: Unknown option '$arg'." >&2
      echo "    Usage: $0 [--force-darkly]" >&2
      exit 1
      ;;
  esac
done

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
echo "==> 1/12  Backup current config"
ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.config/cachyos-setup-backup-$ts"
mkdir -p "$backup_dir"
for f in kwinrc plasma-org.kde.plasma.desktop-appletsrc kdeglobals darklyrc konsolerc krunnerrc; do
  if [[ -f "$HOME/.config/$f" ]]; then
    cp "$HOME/.config/$f" "$backup_dir/$f"
    echo "    Backed up $f"
  fi
done
ln -sfn "$backup_dir" "$HOME/.config/cachyos-setup-backup-latest"
echo "    Latest backup symlinked at ~/.config/cachyos-setup-backup-latest"

# ---------------------------------------------------------------------------
echo "==> 2/12  WhiteSur-kde theme (AUR)"
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
echo "==> 3/12  Darkly application style + transparent widgets"
if [[ -f /usr/lib/qt6/plugins/styles/darkly6.so && "$FORCE_DARKLY" -eq 0 ]]; then
  echo "    Darkly already installed. Use --force-darkly to rebuild."
else
  echo "    Installing Darkly build dependencies..."
  sudo pacman -S --needed --noconfirm \
    cmake extra-cmake-modules kdecoration qt6-declarative kcoreaddons kcmutils \
    kcolorscheme kconfig kguiaddons kiconthemes kwindowsystem gcc make

  darkly_build_dir="/tmp/Darkly-build"
  rm -rf "$darkly_build_dir"
  if git clone --depth=1 https://github.com/Bali10050/Darkly.git "$darkly_build_dir"; then
    if (cd "$darkly_build_dir" && ./install.sh qt6); then
      echo "    Darkly installed."
    else
      echo "    WARNING: Darkly installer failed; continuing without aborting." >&2
    fi
  else
    echo "    WARNING: Darkly clone failed; continuing without aborting." >&2
  fi
fi

kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly
plasma-apply-colorscheme Darkly >/dev/null 2>&1 || echo "    WARNING: Could not apply Darkly color scheme." >&2
# Use Breeze Dark for Plasma shell: Darkly's panel SVG is opaque and ignores panelOpacity.
plasma-apply-desktoptheme breeze-dark >/dev/null 2>&1 || echo "    WARNING: Could not apply Breeze Dark desktop theme." >&2
kwriteconfig6 --file darklyrc --group Style --key MenuOpacity 80
kwriteconfig6 --file darklyrc --group Style --key MenuBarOpacity 80
kwriteconfig6 --file darklyrc --group Style --key ToolBarOpacity 80
kwriteconfig6 --file darklyrc --group Style --key TabBarOpacity 80
kwriteconfig6 --file darklyrc --group Style --key DolphinSidebarOpacity 70
kwriteconfig6 --file darklyrc --group Style --key DolphinViewOpacity 100
echo "    Darkly widget style applied; Breeze Dark desktop theme keeps panels translucent."

# ---------------------------------------------------------------------------
echo "==> 4/12  Window decoration + buttons-on-right"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key library  "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key theme    "__aurorae__svg__WhiteSur-dark"
# Letters: M=menu, I=minimize, A=maximize, X=close. Left-to-right within each side.
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnLeft  "M"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnRight "IAX"
echo "    WhiteSur-dark; menu on left, min/max/close on right"

# ---------------------------------------------------------------------------
echo "==> 5/12  KWin effects (Magic Lamp + Wobbly/Glide/Sheet + Fade Desktop + Cube)"

# Make sure kdeplasma-addons is installed (it provides the Cube effect on
# Plasma 6 -- the classic one was removed and rewritten as a QML addon).
if pacman -Qi kdeplasma-addons >/dev/null 2>&1; then
  echo "    kdeplasma-addons already installed."
  echo "installed_by_us=0" > "$backup_dir/kdeplasma-addons.state"
else
  echo "    Installing kdeplasma-addons (brings the Cube effect)..."
  sudo pacman -S --needed --noconfirm kdeplasma-addons
  echo "installed_by_us=1" > "$backup_dir/kdeplasma-addons.state"
fi

# Minimize: Plasma 6 default is "squash". Swap to Magic Lamp.
kwriteconfig6 --file kwinrc --group "Plugins" --key squashEnabled    --type bool false
kwriteconfig6 --file kwinrc --group "Plugins" --key magiclampEnabled --type bool true
# Magic Lamp duration: fixed 700ms, doesn't scale with AnimationDurationFactor.
kwriteconfig6 --file kwinrc --group "Effect-magiclamp" --key AnimationDuration 700

# Window eye candy.
kwriteconfig6 --file kwinrc --group "Plugins" --key wobblywindowsEnabled --type bool true
kwriteconfig6 --file kwinrc --group "Plugins" --key glideEnabled         --type bool true
kwriteconfig6 --file kwinrc --group "Plugins" --key sheetEnabled         --type bool true

# Virtual desktop switching: prefer Fade over the default Slide. Both are
# built-in and only one can be active at a time.
kwriteconfig6 --file kwinrc --group "Plugins" --key slideEnabled       --type bool false
kwriteconfig6 --file kwinrc --group "Plugins" --key fadedesktopEnabled --type bool true

# Cube (Meta+C activates it). Built-in once kdeplasma-addons is installed.
kwriteconfig6 --file kwinrc --group "Plugins" --key cubeEnabled --type bool true

# Blur tuning for transparent menus, panels, and Konsole.
kwriteconfig6 --file kwinrc --group "Plugins" --key blurEnabled --type bool true
kwriteconfig6 --file kwinrc --group "Effect-blur" --key BlurStrength 10
kwriteconfig6 --file kwinrc --group "Effect-blur" --key NoiseStrength 0

# `KWin reconfigure` rereads kwinrc but does NOT load/unload effects on
# Wayland -- we have to swap them explicitly via the Effects D-Bus interface.
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
for effect_off in squash slide; do
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$effect_off" >/dev/null 2>&1 || true
done
for effect_on in magiclamp wobblywindows glide sheet fadedesktop cube; do
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$effect_on" >/dev/null 2>&1 || true
done
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect blur >/dev/null 2>&1 || true
echo "    Effects loaded: magiclamp(700ms), wobbly, glide, sheet, fadedesktop, cube, blur"

# ---------------------------------------------------------------------------
echo "==> 6/12  Cover Switch + Flip Switch tabbox layouts (rescued from KDE MR !91)"
#
# Honest context: the 3D Cover Switch / Flip Switch from KDE 4.x/5.x was REMOVED
# in Plasma 6 and there is NO replacement in the official KDE Store, AUR, or
# any community project as of 2026.
#
# What we do here: install the QML rewrite that Ismael Asensio wrote in 2021
# (merge request !91 in kdeplasma-addons -- abandoned, branch deleted upstream,
# but we rescued the .qml + metadata from the MR patch file). It was written
# for Plasma 5.24, so it MAY need import tweaks on your specific Plasma 6
# point release.
#
# If after install the layouts don't show up in System Settings -> Task
# Switcher or KWin throws QML errors, see the diagnostic message at the bottom
# of this step.

ASSETS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assets"
TABBOX_DIR="$HOME/.local/share/kwin/tabbox"
mkdir -p "$TABBOX_DIR"

panel_reserve=""
panel_reserve_source=""

is_positive_int() {
  [[ "$1" =~ ^[0-9]+$ && "$1" -gt 0 ]]
}

panel_reserve="$(
  qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript '
    var p = panels().find(function(p){ return p.location === "bottom"; });
    if (p) print(p.height);
  ' 2>/dev/null | grep -E '^[0-9]+$' | head -1
)" || true

if is_positive_int "$panel_reserve"; then
  panel_reserve_source="live"
else
  panel_reserve=""
  mapfile -t bottom_panel_ids < <(
    awk '
      function remember_panel() {
        if (id != "" && is_panel && location == "4" && !seen[id]++) {
          print id
        }
      }

      /^\[Containments\]\[[0-9]+\]$/ {
        remember_panel()
        id = $0
        sub(/^\[Containments\]\[/, "", id)
        sub(/\]$/, "", id)
        is_panel = 0
        location = ""
        next
      }

      /^\[/ {
        remember_panel()
        id = ""
        is_panel = 0
        location = ""
        next
      }

      id != "" && /^plugin=org\.kde\.panel$/ {
        is_panel = 1
        next
      }

      id != "" && /^location=4$/ {
        location = "4"
        next
      }

      END {
        remember_panel()
      }
    ' "$appletsrc" 2>/dev/null
  )

  for panel_id in "${bottom_panel_ids[@]}"; do
    candidate="$(
      kreadconfig6 --file plasmashellrc \
        --group "PlasmaViews" \
        --group "Panel $panel_id" \
        --group "Defaults" \
        --key thickness 2>/dev/null
    )" || true
    if is_positive_int "$candidate"; then
      panel_reserve="$candidate"
      panel_reserve_source="plasmashellrc"
      break
    fi
  done
fi

if ! is_positive_int "$panel_reserve"; then
  panel_reserve=44
  panel_reserve_source="default"
fi
echo "    Cover Switch fallback panel reserve: ${panel_reserve}px (${panel_reserve_source}); QML refreshes from KWin clientArea at runtime"

for layout in coverswitch flipswitch; do
  src="$ASSETS_DIR/$layout"
  dest="$TABBOX_DIR/$layout"
  if [[ ! -d "$src" ]]; then
    echo "    SKIP  $layout: $src missing (run from inside the cloned repo)"
    continue
  fi
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -r "$src"/* "$dest/"
  if [[ "$layout" == "coverswitch" ]]; then
    sed "s/__PANEL_RESERVE__/$panel_reserve/g" \
      "$src/contents/ui/main.qml" > "$dest/contents/ui/main.qml"
  fi
  echo "    installed $layout -> $dest"
done

# Set Cover Switch as main Alt+Tab style, Flip Switch as Alt+Shift+Tab alt.
kwriteconfig6 --file kwinrc --group "TabBox" --key LayoutName "coverswitch"
kwriteconfig6 --file kwinrc --group "TabBoxAlternative" --key LayoutName "flipswitch"
# Disable the show-delay so the switcher appears instantly on Alt-Tab press.
kwriteconfig6 --file kwinrc --group "TabBox" --key ShowDelay --type bool false
kwriteconfig6 --file kwinrc --group "TabBox" --key DelayTime 0
# Make sure tabbox actually shows
kwriteconfig6 --file kwinrc --group "TabBox" --key HighlightWindows --type bool true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
echo "    kwinrc: TabBox=coverswitch, TabBoxAlternative=flipswitch"

# Diagnostic: print where to look if it doesn't work.
cat <<EOF
    If Alt+Tab still uses the default switcher after re-login:
      1. Check kwin loaded the package:  ls $TABBOX_DIR
      2. Check kwin QML errors:          journalctl --user -b 0 -g 'kwin.*qml\\|coverswitch\\|flipswitch' | tail -20
      3. Most likely fix is updating QML imports in $TABBOX_DIR/coverswitch/contents/ui/main.qml:
         old: 'import org.kde.plasma.core 2.0 as PlasmaCore'  ->  '2.1' or '6.0'
         old: 'import org.kde.kwin 2.0 as KWin'               ->  '3.0'
      4. If broken beyond repair, open the file and remove this section.
EOF

# ---------------------------------------------------------------------------
echo "==> 7/12  Panel: non-floating + translucent + battery percentage"
# Find the systemtray containment and the battery child-applet ID dynamically,
# so this works on any Plasma 6 layout (IDs differ per system).

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
mapfile -t PANEL_IDS < <(awk '
  /^\[Containments\]\[[0-9]+\]$/ {
    section = $0
    id = section
    sub(/^\[Containments\]\[/, "", id)
    sub(/\]$/, "", id)
    next
  }
  /^plugin=org\.kde\.panel$/ && id != "" {
    print id
    id = ""
  }
' "$appletsrc" 2>/dev/null | sort -n -u)
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

if [[ "${#PANEL_IDS[@]}" -gt 0 ]]; then
  for panel_id in "${PANEL_IDS[@]}"; do
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
      --group "Containments" --group "$panel_id" \
      --group "General" \
      --key panelOpacity 2
    kwriteconfig6 --file plasmashellrc \
      --group "PlasmaViews" --group "Panel $panel_id" \
      --key floating --type bool false
  done
  echo "    Panel opacity: translucent for containment IDs ${PANEL_IDS[*]}"
  echo "    Panel floating: false for containment IDs ${PANEL_IDS[*]}"
else
  echo "    WARNING: No panel containments found for panelOpacity/floating." >&2
fi

nohup kstart plasmashell >/dev/null 2>&1 & disown
sleep 3

# Panel floating via scripting API (works post-restart)
qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript '
  for (var id of panelIds) {
    var p = panelById(id);
    p.floating = false;
  }
' >/dev/null 2>&1 && echo "    Panel: floating=false"

kwriteconfig6 --file krunnerrc --group General --key FreeFloating --type bool true
kwriteconfig6 --file krunnerrc --group General --key Position Center
echo "    KRunner: centered free-floating launcher"

# ---------------------------------------------------------------------------
echo "==> 8/12  Touchpad: enable natural scrolling"
# Per-device libinput config in ~/.config/kcminputrc. Enumerates touchpad-class
# devices via /sys/class/input and writes NaturalScroll=true for each.
touched_any=0
for inputdir in /sys/class/input/event*/device; do
  [[ -r "$inputdir/name" ]] || continue
  name="$(cat "$inputdir/name" 2>/dev/null)"
  echo "$name" | grep -qi touchpad || continue
  vendor="$(cat "$inputdir/id/vendor" 2>/dev/null)"
  product="$(cat "$inputdir/id/product" 2>/dev/null)"
  [[ -n "$vendor" && -n "$product" ]] || continue
  vendor_dec=$((16#$vendor))
  product_dec=$((16#$product))
  kwriteconfig6 --file kcminputrc \
    --group "Libinput" --group "$vendor_dec" --group "$product_dec" --group "$name" \
    --key NaturalScroll --type bool true
  echo "    NaturalScroll=true for $name"
  touched_any=1
done
if [[ $touched_any -eq 1 ]]; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
else
  echo "    No touchpad-class device found, skipping."
fi

# ---------------------------------------------------------------------------
echo "==> 9/12  Kickoff custom application-menu icon"
kickoff_icon_assets="$ASSETS_DIR/icons"
kickoff_icon_src="$kickoff_icon_assets/applicationMenu-nhsoft.svg"
kickoff_icon_dir="$HOME/.local/share/icons/cachyos-setup"
kickoff_icon_dest="$kickoff_icon_dir/applicationMenu-nhsoft.svg"

if [[ -f "$kickoff_icon_src" ]]; then
  mkdir -p "$kickoff_icon_dir"
  cp "$kickoff_icon_src" "$kickoff_icon_dest"

  mapfile -t KICKOFF_APPLETS < <(python3 - "$appletsrc" <<'PY'
import re, sys
path = sys.argv[1]
flat_re = re.compile(r"^\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]$")
plugin_re = re.compile(r"^plugin=(.+)$")

section = None
try:
    with open(path) as f:
        for line in f:
            line = line.rstrip()
            m = flat_re.match(line)
            if m:
                section = m.groups()
                continue
            if line.startswith("["):
                section = None
                continue
            m = plugin_re.match(line)
            if m and section:
                if m.group(1) == "org.kde.plasma.kickoff":
                    print(*section)
                section = None
except FileNotFoundError:
    pass
PY
)

  if [[ "${#KICKOFF_APPLETS[@]}" -gt 0 ]]; then
    for applet_path in "${KICKOFF_APPLETS[@]}"; do
      read -r panel_id applet_id <<< "$applet_path"
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$applet_id" \
        --group "Configuration" --group "General" \
        --key icon "$kickoff_icon_dest"
      echo "    Kickoff icon: Containments[$panel_id]/Applets[$applet_id]"
    done
  else
    echo "    WARNING: No Kickoff applets found; icon asset installed only." >&2
  fi
else
  echo "    WARNING: Kickoff icon asset missing under $kickoff_icon_assets; skipping." >&2
fi

# ---------------------------------------------------------------------------
echo "==> 10/12  Konsole transparent profile"
konsole_assets="$ASSETS_DIR/konsole"
konsole_dir="$HOME/.local/share/konsole"
if [[ -f "$konsole_assets/Transparent.profile" && -f "$konsole_assets/WhiteOnBlackTransparent.colorscheme" ]]; then
  mkdir -p "$konsole_dir"
  cp "$konsole_assets/Transparent.profile" "$konsole_dir/Transparent.profile"
  cp "$konsole_assets/WhiteOnBlackTransparent.colorscheme" "$konsole_dir/WhiteOnBlackTransparent.colorscheme"
  kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile Transparent.profile
  echo "    Konsole: Transparent.profile installed and set as default"
else
  echo "    WARNING: Konsole template files missing under $konsole_assets; skipping." >&2
fi

# ---------------------------------------------------------------------------
echo "==> 11/12  VSCode native title bar (if installed)"
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
echo "==> 12/12  Install zsh-setup"
zsh_setup_dir="$HOME/zsh-setup"
if [[ ! -d "$zsh_setup_dir" ]]; then
  if git clone --depth=1 https://github.com/dcrey7/zsh-setup.git "$zsh_setup_dir"; then
    echo "    zsh-setup cloned."
  else
    echo "    WARNING: Could not clone zsh-setup; continuing without aborting." >&2
  fi
else
  echo "    zsh-setup already present."
fi
if [[ -f "$zsh_setup_dir/install.sh" ]]; then
  bash "$zsh_setup_dir/install.sh" || echo "    WARNING: zsh-setup installer failed; continuing without aborting." >&2
else
  echo "    WARNING: $zsh_setup_dir/install.sh not found; skipping zsh-setup install." >&2
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

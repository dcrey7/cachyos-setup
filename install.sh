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
#   - Slide animation when switching virtual desktops (Plasma default)
#   - Cube effect via kdeplasma-addons (Meta+C to activate)
#   - Battery applet: show percentage on icon, force always-visible in tray
#   - Custom circular numbered workspace indicator near Kickoff
#   - Meta key opens the default CachyOS Kickoff application menu
#   - Auto-patch VSCode to use native title bar (if installed)
#   - Optional zsh-setup integration
#
# Idempotent. Run again safely. Wayland-aware (Plasma 6 / KWin Wayland).
set -uo pipefail

# ---------------------------------------------------------------------------
echo "==> 0/16  Sanity checks + prerequisite bootstrap"

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

# --- Refresh pacman databases up front so every later `pacman -S` resolves.
# On a fresh CachyOS live USB the DBs are not synced; without -Sy you get
# "error: target not found: cmake" etc. when we try to install build deps.
echo "    Refreshing pacman databases (sudo pacman -Sy)..."
if ! sudo pacman -Sy --noconfirm >/dev/null 2>&1; then
  echo "    WARNING: pacman -Sy failed; later package installs may fail too." >&2
fi

# --- Bootstrap required CLI tools that may be missing on a fresh CachyOS box.
# Each tool maps to one pacman package. paru/python3/qdbus6 etc. are almost
# always preinstalled on CachyOS KDE, but we don't assume it.
declare -A TOOL_PKG=(
  [kwriteconfig6]=kf6-kconfig
  [kreadconfig6]=kf6-kconfig
  [qdbus6]=qt6-tools
  [python3]=python
  [paru]=paru
  [git]=git
  [curl]=curl
)
missing_pkgs=()
for cmd in "${!TOOL_PKG[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    pkg="${TOOL_PKG[$cmd]}"
    if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
      missing_pkgs+=("$pkg")
    fi
  fi
done
if (( ${#missing_pkgs[@]} > 0 )); then
  echo "    Installing missing prerequisite packages: ${missing_pkgs[*]}"
  if sudo pacman -S --needed --noconfirm "${missing_pkgs[@]}"; then
    # Record which packages WE installed so uninstall.sh can roll them back
    # without touching pre-existing system packages. Two stores: a pending
    # per-run file (migrated into backup_dir in section 1) for legacy
    # consumers, and the global ledger (initialized in section 1) for the
    # cumulative cross-run truth.
    mkdir -p "$HOME/.config" 2>/dev/null || true
    bootstrap_state_dir="$HOME/.config/cachyos-setup-bootstrap-pending"
    mkdir -p "$bootstrap_state_dir" 2>/dev/null || true
    printf '%s\n' "${missing_pkgs[@]}" > "$bootstrap_state_dir/bootstrap-pkgs.state"
    # Pending mark in a sidecar file consumed by section 1; mark_installed_by_us
    # is only defined in section 1, so we cannot call it from here yet.
    printf '%s\n' "${missing_pkgs[@]}" >> "$bootstrap_state_dir/global-pending.list"
  else
    echo "    WARNING: some prerequisite packages failed to install; continuing." >&2
  fi
fi

# Final hard check: if anything is still missing, bail with a clear message.
for cmd in kwriteconfig6 kreadconfig6 qdbus6 paru python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "    ERROR: '$cmd' still not found after bootstrap. Install it manually and rerun." >&2
    exit 1
  fi
done
echo "    All required tools present."

# Re-enable strict errors after the best-effort bootstrap section.
set -e

# ---------------------------------------------------------------------------
echo "==> 1/16  Backup current config"
ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="$HOME/.config/cachyos-setup-backup-$ts"
mkdir -p "$backup_dir"
for f in kwinrc plasma-org.kde.plasma.desktop-appletsrc kglobalshortcutsrc kdeglobals darklyrc konsolerc krunnerrc; do
  if [[ -f "$HOME/.config/$f" ]]; then
    cp "$HOME/.config/$f" "$backup_dir/$f"
    echo "    Backed up $f"
  fi
done
ln -sfn "$backup_dir" "$HOME/.config/cachyos-setup-backup-latest"
echo "    Latest backup symlinked at ~/.config/cachyos-setup-backup-latest"

# Migrate any pending bootstrap state (recorded in section 0 before backup_dir
# existed) so uninstall.sh sees it under the backup directory.
bootstrap_state_dir="$HOME/.config/cachyos-setup-bootstrap-pending"
if [[ -f "$bootstrap_state_dir/bootstrap-pkgs.state" ]]; then
  mv "$bootstrap_state_dir/bootstrap-pkgs.state" "$backup_dir/bootstrap-pkgs.state"
  rmdir "$bootstrap_state_dir" 2>/dev/null || true
  echo "    Recorded bootstrap-pkgs.state from prerequisite install"
fi

# Global "installed by us" ledger. Cumulative across install runs so a second
# install that finds a package already present (because a prior run installed
# it) still leaves uninstall.sh authoritative info to remove it later.
GLOBAL_PKG_STATE="$HOME/.local/share/cachyos-setup/installed-by-us.list"
mkdir -p "$(dirname "$GLOBAL_PKG_STATE")"
touch "$GLOBAL_PKG_STATE"
mark_installed_by_us() {
  local pkg="$1"
  grep -qxF "$pkg" "$GLOBAL_PKG_STATE" || echo "$pkg" >> "$GLOBAL_PKG_STATE"
}
# Seed the ledger from any pre-existing per-backup state files left by earlier
# runs (where the package was marked installed_by_us=1). Idempotent: if a
# package is already in the ledger, mark_installed_by_us is a no-op.
shopt -s nullglob
for prev_state in "$HOME"/.config/cachyos-setup-backup-*/whitesur.state; do
  if grep -q '^installed_by_us=1' "$prev_state" 2>/dev/null; then
    mark_installed_by_us whitesur-kde-theme
  fi
done
for prev_state in "$HOME"/.config/cachyos-setup-backup-*/kdeplasma-addons.state; do
  if grep -q '^installed_by_us=1' "$prev_state" 2>/dev/null; then
    mark_installed_by_us kdeplasma-addons
  fi
done
for prev_state in "$HOME"/.config/cachyos-setup-backup-*/win11-icon.state; do
  if grep -q '^installed_by_us=1' "$prev_state" 2>/dev/null; then
    mark_installed_by_us win11-icon-theme-git
  fi
done
for prev_state in "$HOME"/.config/cachyos-setup-backup-*/darkly-build-deps.state \
                  "$HOME"/.config/cachyos-setup-backup-*/bootstrap-pkgs.state; do
  while IFS= read -r prev_pkg; do
    [[ -n "$prev_pkg" ]] && mark_installed_by_us "$prev_pkg"
  done < "$prev_state" 2>/dev/null
done
shopt -u nullglob

# Drain any pending bootstrap-pkg marks (recorded in section 0 before this
# helper existed).
if [[ -f "$bootstrap_state_dir/global-pending.list" ]]; then
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && mark_installed_by_us "$pkg"
  done < "$bootstrap_state_dir/global-pending.list"
  rm -f "$bootstrap_state_dir/global-pending.list"
fi

# ---------------------------------------------------------------------------
echo "==> 2/16  WhiteSur-kde theme (AUR)"
if pacman -Qi whitesur-kde-theme >/dev/null 2>&1; then
  echo "    Already installed."
  echo "installed_by_us=0" > "$backup_dir/whitesur.state"
else
  echo "    Installing via paru..."
  paru -S --needed --noconfirm whitesur-kde-theme
  echo "installed_by_us=1" > "$backup_dir/whitesur.state"
  mark_installed_by_us whitesur-kde-theme
fi
if [[ ! -d /usr/share/aurorae/themes/WhiteSur-dark && ! -d "$HOME/.local/share/aurorae/themes/WhiteSur-dark" ]]; then
  echo "    WARNING: WhiteSur-dark aurorae theme directory not found." >&2
fi

# ---------------------------------------------------------------------------
echo "==> 3/16  Darkly application style + transparent widgets"
if [[ -f /usr/lib/qt6/plugins/styles/darkly6.so && "$FORCE_DARKLY" -eq 0 ]]; then
  echo "    Darkly already installed. Use --force-darkly to rebuild."
else
  # Gate each build-dep on pacman -Qi so we only install what's actually missing.
  # On a fresh CachyOS box most of these aren't there; on a returning box they
  # already are. Either way, we pacman -Sy first to make sure DBs are fresh.
  darkly_build_deps=(cmake extra-cmake-modules kdecoration qt6-declarative
    kcoreaddons kcmutils kcolorscheme kconfig kguiaddons kiconthemes
    kwindowsystem gcc make)
  missing_build_deps=()
  for pkg in "${darkly_build_deps[@]}"; do
    pacman -Qi "$pkg" >/dev/null 2>&1 || missing_build_deps+=("$pkg")
  done
  if (( ${#missing_build_deps[@]} > 0 )); then
    echo "    Installing Darkly build dependencies: ${missing_build_deps[*]}"
    sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
    if sudo pacman -S --needed --noconfirm "${missing_build_deps[@]}"; then
      # Record only the packages we actually installed so uninstall.sh can
      # remove them without touching pre-existing system packages.
      printf '%s\n' "${missing_build_deps[@]}" > "$backup_dir/darkly-build-deps.state"
      for pkg in "${missing_build_deps[@]}"; do
        mark_installed_by_us "$pkg"
      done
    else
      echo "    WARNING: Some Darkly build deps failed to install; build may fail." >&2
    fi
  else
    echo "    Darkly build deps already installed."
  fi

  darkly_build_dir="/tmp/Darkly-build"
  rm -rf "$darkly_build_dir"
  if git clone --depth=1 https://github.com/Bali10050/Darkly.git "$darkly_build_dir"; then
    # Upstream install.sh returns non-zero even on a successful "Installation
    # completed!" run, so we re-check the on-disk artifact instead of trusting
    # the exit code. If darkly6.so landed in qt6 plugins, treat it as success.
    (cd "$darkly_build_dir" && ./install.sh qt6) || true
    if [[ -f /usr/lib/qt6/plugins/styles/darkly6.so ]]; then
      echo "    Darkly installed (darkly6.so in /usr/lib/qt6/plugins/styles)."
    else
      echo "    WARNING: Darkly installer ran but darkly6.so is missing; continuing." >&2
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
echo "==> 4/16  Window decoration + buttons-on-right"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key library  "org.kde.kwin.aurorae"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key theme    "__aurorae__svg__WhiteSur-dark"
# Letters: M=menu, I=minimize, A=maximize, X=close. Left-to-right within each side.
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnLeft  "M"
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnRight "IAX"
echo "    WhiteSur-dark; menu on left, min/max/close on right"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Up,Meta+PgUp,Maximize Window"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,Meta+Up,Quick Tile Window to the Top"
echo "    KWin shortcut: Meta+Up maximizes instead of quick-tiling to top"

# ---------------------------------------------------------------------------
echo "==> 5/16  KWin effects (Magic Lamp + Wobbly/Glide/Sheet + Slide + Cube)"

# Make sure kdeplasma-addons is installed (it provides the Cube effect on
# Plasma 6 -- the classic one was removed and rewritten as a QML addon).
if pacman -Qi kdeplasma-addons >/dev/null 2>&1; then
  echo "    kdeplasma-addons already installed."
  echo "installed_by_us=0" > "$backup_dir/kdeplasma-addons.state"
else
  echo "    Installing kdeplasma-addons (brings the Cube effect)..."
  sudo pacman -S --needed --noconfirm kdeplasma-addons
  echo "installed_by_us=1" > "$backup_dir/kdeplasma-addons.state"
  mark_installed_by_us kdeplasma-addons
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

# Virtual desktop switching: use Slide (Plasma's default). Both are built-in
# and only one can be active at a time.
kwriteconfig6 --file kwinrc --group "Plugins" --key slideEnabled       --type bool true
kwriteconfig6 --file kwinrc --group "Plugins" --key fadedesktopEnabled --type bool false

# Cube (Meta+C activates it). Built-in once kdeplasma-addons is installed.
kwriteconfig6 --file kwinrc --group "Plugins" --key cubeEnabled --type bool true

# Blur tuning for transparent menus, panels, and Konsole.
kwriteconfig6 --file kwinrc --group "Plugins" --key blurEnabled --type bool true
kwriteconfig6 --file kwinrc --group "Effect-blur" --key BlurStrength 10
kwriteconfig6 --file kwinrc --group "Effect-blur" --key NoiseStrength 0

# `KWin reconfigure` rereads kwinrc but does NOT load/unload effects on
# Wayland -- we have to swap them explicitly via the Effects D-Bus interface.
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
for effect_off in squash fadedesktop; do
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$effect_off" >/dev/null 2>&1 || true
done
for effect_on in magiclamp wobblywindows glide sheet slide cube; do
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$effect_on" >/dev/null 2>&1 || true
done
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect blur >/dev/null 2>&1 || true
echo "    Effects loaded: magiclamp(700ms), wobbly, glide, sheet, slide, cube, blur"

# ---------------------------------------------------------------------------
echo "==> 6/16  Cover Switch + Flip Switch tabbox layouts (rescued from KDE MR !91)"
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
echo "==> 7/16  Cover Switch zoom-in close effect"

EFFECT_SRC="$ASSETS_DIR/kwin-effects/coverswitch-zoom-in"
EFFECT_DEST="$HOME/.local/share/kwin/effects/coverswitch-zoom-in"

if [[ -d "$EFFECT_SRC" ]]; then
  mkdir -p "$(dirname "$EFFECT_DEST")"
  rm -rf "$EFFECT_DEST"
  cp -r "$EFFECT_SRC" "$EFFECT_DEST"
  echo "    Installed effect -> $EFFECT_DEST"

  kwriteconfig6 --file kwinrc --group "Plugins" --key coverswitch-zoom-inEnabled --type bool true
  echo "    Enabled coverswitch-zoom-in"

  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect coverswitch-zoom-in >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect coverswitch-zoom-in >/dev/null 2>&1 || true
else
  echo "    SKIP  coverswitch-zoom-in: $EFFECT_SRC missing"
fi

# ---------------------------------------------------------------------------
echo "==> 8/16  Custom workspace indicator plasmoid"
PLASMOID_SRC="$ASSETS_DIR/plasmoids/cachyos-workspace-indicator"
PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/cachyos.workspace-indicator"
if [[ -d "$PLASMOID_SRC" ]]; then
  mkdir -p "$(dirname "$PLASMOID_DEST")"
  rm -rf "$PLASMOID_DEST"
  cp -r "$PLASMOID_SRC" "$PLASMOID_DEST"
  echo "    Installed plasmoid -> $PLASMOID_DEST"
else
  echo "    WARNING: Workspace indicator plasmoid source missing under $PLASMOID_SRC; skipping." >&2
fi

# ---------------------------------------------------------------------------
echo "==> 9/16  Panel: non-floating + translucent + circular workspace indicator + centered taskbar + battery percentage"
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

# Plasmashell holds in-memory panel state, so stop it before writing panel
# config and restart it after the updates. The panel disappears for ~1s.
echo "    Restarting plasmashell to apply panel config (panel will flicker)..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
pkill -9 plasmashell 2>/dev/null || true

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

# Digital clock: time and date side by side, with a custom date format.
# Date format renders as "May | Fri | 22/05/2026 |" (MMM | ddd | dd/MM/yyyy |).
if [[ -n "$CLOCK_AID" ]]; then
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
    --group "Containments" --group "$CLOCK_CID" \
    --group "Applets" --group "$CLOCK_AID" \
    --group "Configuration" --group "Appearance" \
    --key dateDisplayFormat "BesideTime"
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
    --group "Containments" --group "$CLOCK_CID" \
    --group "Applets" --group "$CLOCK_AID" \
    --group "Configuration" --group "Appearance" \
    --key dateFormat "custom"
  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
    --group "Containments" --group "$CLOCK_CID" \
    --group "Applets" --group "$CLOCK_AID" \
    --group "Configuration" --group "Appearance" \
    --key customDateFormat "MMM | ddd | dd/MM/yyyy |"
  echo "    Clock: date beside time, custom format 'MMM | ddd | dd/MM/yyyy |'"
fi

if [[ "${#PANEL_IDS[@]}" -gt 0 ]]; then
  # Strip cosmetic clutter from panels first: marginsseparator and showdesktop
  # (peek-at-desktop). Keeps panelspacers — those are added later by the
  # centered-taskbar reconciliation. Symmetric with uninstall.sh section 8.
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" "${PANEL_IDS[@]}" <<'PY' || true
import configparser, re, sys
TARGETS = {
    "org.kde.plasma.marginsseparator",
    "org.kde.plasma.showdesktop",
}
p = sys.argv[1]
panels = set(sys.argv[2:])
cp = configparser.RawConfigParser()
cp.optionxform = str
cp.read(p)
removed = []
for s in list(cp.sections()):
    m = re.fullmatch(r"Containments\]\[(\d+)\]\[Applets\]\[(\d+)", s.replace("][", "]["))
    if m and m.group(1) in panels:
        if cp.get(s, "plugin", fallback="") in TARGETS:
            removed.append((m.group(1), m.group(2)))
            cp.remove_section(s)
            prefix = f"Containments][{m.group(1)}][Applets][{m.group(2)}]["
            for s2 in list(cp.sections()):
                if s2.startswith(prefix):
                    cp.remove_section(s2)
for pid in panels:
    sec = f"Containments][{pid}][General"
    if cp.has_section(sec) and cp.has_option(sec, "AppletOrder"):
        order = cp.get(sec, "AppletOrder").split(";")
        bad = {aid for ppid, aid in removed if ppid == pid}
        order = [x for x in order if x not in bad]
        cp.set(sec, "AppletOrder", ";".join(order))
with open(p, "w") as f:
    cp.write(f, space_around_delimiters=False)
print(f"    Stripped {len(removed)} cosmetic applet(s) (marginsseparator/showdesktop)")
PY
  fi
  for panel_id in "${PANEL_IDS[@]}"; do
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
      --group "Containments" --group "$panel_id" \
      --group "General" \
      --key panelOpacity 2
    kwriteconfig6 --file plasmashellrc \
      --group "PlasmaViews" --group "Panel $panel_id" \
      --key floating --type bool false
    # Panel height: 40px (default is 44). Stored under PlasmaViews/Panel N/Defaults.
    kwriteconfig6 --file plasmashellrc \
      --group "PlasmaViews" --group "Panel $panel_id" --group "Defaults" \
      --key thickness 40
  done
  echo "    Panel opacity: translucent for containment IDs ${PANEL_IDS[*]}"
  echo "    Panel floating: false for containment IDs ${PANEL_IDS[*]}"
  echo "    Panel thickness: 40px for containment IDs ${PANEL_IDS[*]}"

  next_panel_applet_id="$(python3 - "$appletsrc" <<'PY'
import re
import sys

max_id = 0
applet_re = re.compile(r"\[Applets\]\[(\d+)\]")
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        for line in f:
            for match in applet_re.finditer(line):
                max_id = max(max_id, int(match.group(1)))
except FileNotFoundError:
    pass
print(max_id + 1)
PY
)"

  workspace_indicator_any=0
  workspace_indicator_reordered_any=0
  for panel_id in "${PANEL_IDS[@]}"; do
    applet_order_raw="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
      --group "Containments" --group "$panel_id" \
      --group "General" \
      --key AppletOrder 2>/dev/null || true)"
    [[ -n "$applet_order_raw" ]] || continue

    IFS=';' read -r -a applet_order <<< "$applet_order_raw"
    kickoff_id=""
    workspace_indicator_id=""
    workspace_indicator_index=-1
    has_workspace_indicator=0
    has_stock_pager=0

    for i in "${!applet_order[@]}"; do
      applet_id="${applet_order[$i]}"
      [[ -n "$applet_id" ]] || continue
      plugin="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$applet_id" \
        --key plugin 2>/dev/null || true)"

      if [[ "$plugin" == "org.kde.plasma.kickoff" && -z "$kickoff_id" ]]; then
        kickoff_id="$applet_id"
      elif [[ "$plugin" == "cachyos.workspace-indicator" ]]; then
        has_workspace_indicator=1
        if [[ -z "$workspace_indicator_id" ]]; then
          workspace_indicator_id="$applet_id"
          workspace_indicator_index="$i"
        fi
      elif [[ "$plugin" == "org.kde.plasma.pager" ]]; then
        has_stock_pager=1
        if [[ -z "$workspace_indicator_id" ]]; then
          workspace_indicator_id="$applet_id"
          workspace_indicator_index="$i"
        fi
        kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
          --group "Containments" --group "$panel_id" \
          --group "Applets" --group "$applet_id" \
          --key plugin "cachyos.workspace-indicator"
        echo "    Panel $panel_id: replaced pager applet $applet_id with cachyos.workspace-indicator"
      fi
    done

    if [[ -z "$workspace_indicator_id" && -n "$kickoff_id" ]]; then
      workspace_indicator_id="$next_panel_applet_id"
      next_panel_applet_id=$((next_panel_applet_id + 1))
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$workspace_indicator_id" \
        --key immutability 1
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$workspace_indicator_id" \
        --key plugin "cachyos.workspace-indicator"
      applet_order_with_indicator=()
      for applet_id in "${applet_order[@]}"; do
        [[ -n "$applet_id" ]] || continue
        applet_order_with_indicator+=("$applet_id")
        [[ "$applet_id" == "$kickoff_id" ]] && applet_order_with_indicator+=("$workspace_indicator_id")
      done
      applet_order=("${applet_order_with_indicator[@]}")
      applet_order_raw="$(IFS=';'; echo "${applet_order[*]}")"
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "General" \
        --key AppletOrder "$applet_order_raw"
      workspace_indicator_index=-1
      echo "    Panel $panel_id: added workspace indicator $workspace_indicator_id after Kickoff $kickoff_id"
    fi

    [[ -n "$workspace_indicator_id" ]] && workspace_indicator_any=1

    if [[ -n "$kickoff_id" && -n "$workspace_indicator_id" ]]; then
      new_order=()
      for applet_id in "${applet_order[@]}"; do
        [[ -n "$applet_id" ]] || continue
        [[ "$applet_id" == "$workspace_indicator_id" ]] && continue
        new_order+=("$applet_id")
        [[ "$applet_id" == "$kickoff_id" ]] && new_order+=("$workspace_indicator_id")
      done
      new_order_raw="$(IFS=';'; echo "${new_order[*]}")"
      if [[ "$new_order_raw" != "$applet_order_raw" ]]; then
        kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
          --group "Containments" --group "$panel_id" \
          --group "General" \
          --key AppletOrder "$new_order_raw"
        workspace_indicator_reordered_any=1
        echo "    Panel $panel_id: moved workspace indicator $workspace_indicator_id immediately after Kickoff $kickoff_id -> $new_order_raw"
      elif (( workspace_indicator_index >= 0 )); then
        echo "    Panel $panel_id: workspace indicator $workspace_indicator_id already immediately after Kickoff $kickoff_id"
      fi
    elif [[ -n "$workspace_indicator_id" ]]; then
      echo "    Panel $panel_id: workspace indicator present but no Kickoff applet; leaving order unchanged"
    elif (( has_stock_pager == 0 && has_workspace_indicator == 0 )); then
      echo "    Panel $panel_id: no pager or Kickoff applet; leaving workspace indicator absent"
    fi
  done
  if (( workspace_indicator_any == 0 )); then
    echo "    Workspace indicator: no panel received cachyos.workspace-indicator"
  fi
  if (( workspace_indicator_reordered_any == 0 )); then
    echo "    Workspace indicator order: no changes needed"
  fi

  centered_any=0
  for panel_id in "${PANEL_IDS[@]}"; do
    applet_order_raw="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
      --group "Containments" --group "$panel_id" \
      --group "General" \
      --key AppletOrder 2>/dev/null || true)"
    [[ -n "$applet_order_raw" ]] || continue

    IFS=';' read -r -a applet_order <<< "$applet_order_raw"
    icontasks_id=""
    icontasks_index=-1
    spacer_count=0
    spacer_ids=()

    for i in "${!applet_order[@]}"; do
      applet_id="${applet_order[$i]}"
      [[ -n "$applet_id" ]] || continue
      plugin="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$applet_id" \
        --key plugin 2>/dev/null || true)"
      if [[ "$plugin" == "org.kde.plasma.icontasks" && -z "$icontasks_id" ]]; then
        icontasks_id="$applet_id"
        icontasks_index="$i"
      elif [[ "$plugin" == "org.kde.plasma.panelspacer" ]]; then
        spacer_ids+=("$applet_id")
        spacer_count=$((spacer_count + 1))
      fi
    done

    if [[ -z "$icontasks_id" ]]; then
      echo "    Panel $panel_id: no icontasks applet; leaving custom panel order unchanged"
      continue
    fi

    if (( spacer_count >= 2 )); then
      echo "    Panel $panel_id: already has ${spacer_count} panel spacers"
      continue
    fi

    left_plugin=""
    right_plugin=""
    if (( icontasks_index > 0 )); then
      left_id="${applet_order[$((icontasks_index - 1))]}"
      left_plugin="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$left_id" \
        --key plugin 2>/dev/null || true)"
    fi
    if (( icontasks_index < ${#applet_order[@]} - 1 )); then
      right_id="${applet_order[$((icontasks_index + 1))]}"
      right_plugin="$(kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$right_id" \
        --key plugin 2>/dev/null || true)"
    fi

    need_left=0
    need_right=0
    [[ "$left_plugin" == "org.kde.plasma.panelspacer" ]] || need_left=1
    [[ "$right_plugin" == "org.kde.plasma.panelspacer" ]] || need_right=1
    if (( need_left == 0 && need_right == 0 )); then
      echo "    Panel $panel_id: icontasks already flanked by panel spacers"
      continue
    fi

    left_spacer_id=""
    right_spacer_id=""
    reused_spacer_id=""
    if (( spacer_count == 1 && need_left == 1 && need_right == 1 )); then
      reused_spacer_id="${spacer_ids[0]}"
      left_spacer_id="$reused_spacer_id"
    fi

    if (( need_left == 1 )) && [[ -z "$left_spacer_id" ]]; then
      left_spacer_id="$next_panel_applet_id"
      next_panel_applet_id=$((next_panel_applet_id + 1))
    fi
    if (( need_right == 1 )); then
      right_spacer_id="$next_panel_applet_id"
      next_panel_applet_id=$((next_panel_applet_id + 1))
    fi

    for new_spacer_id in "$left_spacer_id" "$right_spacer_id"; do
      [[ -n "$new_spacer_id" && "$new_spacer_id" != "$reused_spacer_id" ]] || continue
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$new_spacer_id" \
        --key immutability 1
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "Applets" --group "$new_spacer_id" \
        --key plugin "org.kde.plasma.panelspacer"
    done

    new_order=()
    for applet_id in "${applet_order[@]}"; do
      [[ -n "$applet_id" ]] || continue
      [[ -n "$reused_spacer_id" && "$applet_id" == "$reused_spacer_id" ]] && continue
      if [[ "$applet_id" == "$icontasks_id" ]]; then
        [[ -n "$left_spacer_id" ]] && new_order+=("$left_spacer_id")
        new_order+=("$applet_id")
        [[ -n "$right_spacer_id" ]] && new_order+=("$right_spacer_id")
      else
        new_order+=("$applet_id")
      fi
    done
    new_order_raw="$(IFS=';'; echo "${new_order[*]}")"

    if [[ "$new_order_raw" != "$applet_order_raw" ]]; then
      kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group "Containments" --group "$panel_id" \
        --group "General" \
        --key AppletOrder "$new_order_raw"
      centered_any=1
      echo "    Panel $panel_id: centered icontasks AppletOrder -> $new_order_raw"
    fi
  done
  if (( centered_any == 0 )); then
    echo "    Panel taskbar spacers: no changes needed"
  fi
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
echo "==> 10/16  Keyboard shortcuts: Meta opens Kickoff (default CachyOS app menu)"
launcher_shortcut_key="activate application launcher"
launcher_shortcut_current="$(kreadconfig6 --file kglobalshortcutsrc \
  --group "plasmashell" \
  --key "$launcher_shortcut_key" 2>/dev/null || true)"
krunner_shortcut_current="$(kreadconfig6 --file kglobalshortcutsrc \
  --group "krunner.desktop" \
  --key "_launch" 2>/dev/null || true)"

kwriteconfig6 --file kglobalshortcutsrc \
  --group "plasmashell" \
  --key "$launcher_shortcut_key" \
  "Meta,Meta,Activate Application Launcher"
kwriteconfig6 --file kglobalshortcutsrc \
  --group "krunner.desktop" \
  --key "_launch" \
  "Alt+Space,Alt+Space,Run Command Interface"

echo "    plasmashell/$launcher_shortcut_key: ${launcher_shortcut_current:-<unset>} -> Meta,Meta,Activate Application Launcher"
echo "    krunner.desktop/_launch: ${krunner_shortcut_current:-<unset>} -> Alt+Space,Alt+Space,Run Command Interface"
qdbus6 org.kde.kglobalaccel /component/plasmashell org.kde.kglobalaccel.Component.cleanUp >/dev/null 2>&1 || true
qdbus6 org.kde.kglobalaccel /component/krunner_desktop org.kde.kglobalaccel.Component.cleanUp >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

echo "    Restarting plasmashell so Meta shortcut ownership is re-read..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
pkill -9 plasmashell 2>/dev/null || true
nohup kstart plasmashell >/dev/null 2>&1 & disown
sleep 3

# ---------------------------------------------------------------------------
echo "==> 11/16  Touchpad: enable natural scrolling"
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
echo "==> 12/16  Kickoff custom application-menu icon"
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
echo "==> 13/16  Konsole transparent profile"
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
echo "==> 14/16  VSCode native title bar (if installed)"
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
echo "==> 15/16  Win11 icon theme (yeyushengfan258, AUR)"
# Icon theme from https://github.com/yeyushengfan258/Win11-icon-theme, packaged
# in AUR as `win11-icon-theme-git`. Installed via paru. After install the theme
# is at /usr/share/icons/Win11 -- we set it as the global Plasma icon theme.
if pacman -Qi win11-icon-theme-git >/dev/null 2>&1; then
  echo "    win11-icon-theme-git already installed."
  echo "installed_by_us=0" > "$backup_dir/win11-icon.state"
else
  echo "    Installing win11-icon-theme-git via paru..."
  if paru -S --needed --noconfirm win11-icon-theme-git; then
    echo "installed_by_us=1" > "$backup_dir/win11-icon.state"
    mark_installed_by_us win11-icon-theme-git
  else
    echo "    WARNING: win11-icon-theme-git install failed; continuing without aborting." >&2
    echo "installed_by_us=0" > "$backup_dir/win11-icon.state"
  fi
fi
# Pick whichever Win11* theme variant is actually present on disk (the AUR
# package historically ships a few; we prefer plain "Win11" but fall back).
win11_icon_name=""
for cand in Win11 Win11-dark Win11-black Win11-light; do
  if [[ -d "/usr/share/icons/$cand" || -d "$HOME/.local/share/icons/$cand" ]]; then
    win11_icon_name="$cand"
    break
  fi
done
if [[ -n "$win11_icon_name" ]]; then
  kwriteconfig6 --file kdeglobals --group Icons --key Theme "$win11_icon_name"
  if command -v plasma-changeicons >/dev/null 2>&1; then
    plasma-changeicons "$win11_icon_name" >/dev/null 2>&1 || true
  fi
  echo "    Icon theme set to $win11_icon_name"
else
  echo "    WARNING: No Win11* icon theme directory found; icon theme not changed." >&2
fi

# ---------------------------------------------------------------------------
echo "==> 16/16  Install zsh-setup"
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
# Final plasmashell restart: picks up changes written after section 10's
# restart -- in particular the Kickoff custom application-menu icon (section
# 12), Konsole defaults (13), and Win11 icon theme (15). Without this, the
# kickoff button keeps showing the old icon until the next logout/login.
echo "Restarting plasmashell once more so post-section-10 writes take effect..."
kquitapp6 plasmashell 2>/dev/null || true
sleep 1
pkill -9 plasmashell 2>/dev/null || true
nohup kstart plasmashell >/dev/null 2>&1 & disown
sleep 2

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

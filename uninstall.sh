#!/usr/bin/env bash
# Reverses cachyos-setup install.sh tweaks as far as possible.
#
# Strategy:
#   1. Prefer restoring the timestamped backup created by install.sh:
#      ~/.config/cachyos-setup-backup-latest
#   2. Delete files/directories install.sh created.
#   3. If a backed-up config file is missing, reset only the keys install.sh
#      touched to conservative Plasma 6 defaults.
#   4. Unload custom KWin effects and restart Plasma shell so deleted QML is not
#      held in memory.
#
# Caveats:
#   - Panel spacers cannot be reliably distinguished from user-created spacers
#     unless the original appletsrc backup is available. Without that backup,
#     this script leaves panel spacers in place.
#   - The system Darkly binary at /usr/lib/qt6/plugins/styles/darkly6.so needs
#     sudo and has no install marker from install.sh. It is left in place unless
#     you pass --remove-darkly-binary.
#   - WhiteSur and kdeplasma-addons packages are left in place by default unless
#     install.sh's package state marker says this repo installed them and you
#     pass --remove-packages.
#   - Any changes made after install.sh ran but before uninstall.sh runs may be
#     overwritten when a backup file is restored.
set -uo pipefail

REMOVE_PACKAGES=0
REMOVE_DARKLY_BINARY=0
REMOVE_ZSH_REPO=0
YES=0

for arg in "$@"; do
  case "$arg" in
    --remove-packages) REMOVE_PACKAGES=1 ;;
    --remove-darkly-binary) REMOVE_DARKLY_BINARY=1 ;;
    --remove-zsh-repo) REMOVE_ZSH_REPO=1 ;;
    -y|--yes) YES=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: bash uninstall.sh [options]

Options:
  -y, --yes                Do not prompt for confirmation.
  --remove-packages        Remove packages install.sh marked as installed by it.
  --remove-darkly-binary   Try to remove /usr/lib/qt6/plugins/styles/darkly6.so.
  --remove-zsh-repo        Delete ~/zsh-setup after running its uninstall.sh.
EOF
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option '$arg'." >&2
      exit 1
      ;;
  esac
done

backup_link="$HOME/.config/cachyos-setup-backup-latest"
backup_dir=""
if [[ -e "$backup_link" ]]; then
  backup_dir="$(readlink -f "$backup_link" 2>/dev/null || printf '%s' "$backup_link")"
fi

warn() {
  echo "    WARNING: $*" >&2
}

run() {
  "$@"
  local status=$?
  if [[ "$status" -ne 0 ]]; then
    warn "failed: $*"
  fi
  return "$status"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

have_python() {
  have python3
}

restore_config() {
  local name="$1"
  if [[ -n "$backup_dir" && -f "$backup_dir/$name" ]]; then
    mkdir -p "$HOME/.config"
    if run cp "$backup_dir/$name" "$HOME/.config/$name"; then
      echo "    Restored ~/.config/$name"
      return 0
    fi
    return 1
  fi
  echo "    No backup for ~/.config/$name"
  return 1
}

delete_key() {
  have kwriteconfig6 || return 0
  kwriteconfig6 "$@" --delete >/dev/null 2>&1 || true
}

write_key() {
  have kwriteconfig6 || return 0
  kwriteconfig6 "$@" >/dev/null 2>&1 || warn "kwriteconfig6 failed: $*"
}

kwin_effect() {
  have qdbus6 || return 0
  qdbus6 org.kde.KWin /Effects "org.kde.kwin.Effects.$1" "$2" >/dev/null 2>&1 || true
}

restart_plasmashell() {
  have kquitapp6 && kquitapp6 plasmashell >/dev/null 2>&1 || true
  sleep 1
  pkill -9 plasmashell >/dev/null 2>&1 || true
  if have kstart; then
    nohup kstart plasmashell >/dev/null 2>&1 &
    disown 2>/dev/null || true
  elif have kstart6; then
    nohup kstart6 plasmashell >/dev/null 2>&1 &
    disown 2>/dev/null || true
  elif have plasmashell; then
    nohup plasmashell >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
}

if [[ -z "$backup_dir" || ! -d "$backup_dir" ]]; then
  echo "WARNING: No backup found at $backup_link." >&2
  echo "         Will use fallback default resets and generated-file cleanup only." >&2
fi

echo "This will undo cachyos-setup tweaks."
if [[ -n "$backup_dir" && -d "$backup_dir" ]]; then
  echo "Backup restore source: $backup_dir"
else
  echo "Backup restore source: none"
fi
echo "A logout and login is still recommended after completion."
echo ""
if [[ "$YES" -ne 1 ]]; then
  read -r -p "Continue? [y/N] " confirm
  [[ "${confirm:-}" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }
fi

# ---------------------------------------------------------------------------
echo "==> 1/15  Restore backed-up KDE and app settings"
restored_kwin=0
restored_applets=0
restored_shortcuts=0
restored_kdeglobals=0
restored_darkly=0
restored_konsole=0
restored_krunner=0

restore_config kwinrc && restored_kwin=1
restore_config plasma-org.kde.plasma.desktop-appletsrc && restored_applets=1
restore_config kglobalshortcutsrc && restored_shortcuts=1
restore_config kdeglobals && restored_kdeglobals=1
restore_config darklyrc && restored_darkly=1
restore_config konsolerc && restored_konsole=1
restore_config krunnerrc && restored_krunner=1

# ---------------------------------------------------------------------------
echo "==> 2/15  WhiteSur-kde theme package"
if [[ "$REMOVE_PACKAGES" -eq 1 && -n "$backup_dir" && -f "$backup_dir/whitesur.state" ]] \
  && grep -q '^installed_by_us=1' "$backup_dir/whitesur.state"; then
  if have paru && pacman -Qi whitesur-kde-theme >/dev/null 2>&1; then
    run paru -Rns --noconfirm whitesur-kde-theme
  else
    echo "    whitesur-kde-theme not installed or paru unavailable"
  fi
else
  echo "    Leaving WhiteSur package in place by default"
fi

# ---------------------------------------------------------------------------
echo "==> 3/15  Darkly application style + transparency"
if [[ "$restored_kdeglobals" -eq 0 ]]; then
  write_key --file kdeglobals --group KDE --key widgetStyle Breeze
  if have plasma-apply-colorscheme; then
    plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || warn "Could not apply BreezeDark color scheme"
  fi
  if have plasma-apply-desktoptheme; then
    plasma-apply-desktoptheme default >/dev/null 2>&1 || plasma-apply-desktoptheme breeze-dark >/dev/null 2>&1 || warn "Could not apply default desktop theme"
  fi
else
  echo "    kdeglobals restored from backup; not overriding preinstall style/theme"
fi
if [[ "$restored_darkly" -eq 0 ]]; then
  rm -f "$HOME/.config/darklyrc" 2>/dev/null || warn "Could not remove ~/.config/darklyrc"
else
  echo "    darklyrc restored from backup"
fi
if [[ "$REMOVE_DARKLY_BINARY" -eq 1 ]]; then
  if [[ -f /usr/lib/qt6/plugins/styles/darkly6.so ]]; then
    run sudo rm -f /usr/lib/qt6/plugins/styles/darkly6.so
  else
    echo "    Darkly binary not present"
  fi
else
  echo "    Leaving system Darkly binary in place"
fi

# ---------------------------------------------------------------------------
echo "==> 4/15  Window decoration + buttons"
if [[ "$restored_kwin" -eq 0 ]]; then
  write_key --file kwinrc --group "org.kde.kdecoration2" --key library "org.kde.breeze"
  write_key --file kwinrc --group "org.kde.kdecoration2" --key theme "Breeze"
  write_key --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnLeft "M"
  write_key --file kwinrc --group "org.kde.kdecoration2" --key ButtonsOnRight "IAX"
else
  echo "    kwinrc restored from backup; decoration returned to preinstall state"
fi

# ---------------------------------------------------------------------------
echo "==> 5/15  KWin effects + Meta+Up shortcuts"
if [[ "$restored_kwin" -eq 0 ]]; then
  write_key --file kwinrc --group Plugins --key magiclampEnabled --type bool false
  write_key --file kwinrc --group Plugins --key wobblywindowsEnabled --type bool false
  write_key --file kwinrc --group Plugins --key glideEnabled --type bool false
  write_key --file kwinrc --group Plugins --key sheetEnabled --type bool false
  write_key --file kwinrc --group Plugins --key cubeEnabled --type bool false
  write_key --file kwinrc --group Plugins --key fadedesktopEnabled --type bool false
  write_key --file kwinrc --group Plugins --key slideEnabled --type bool true
  write_key --file kwinrc --group Plugins --key squashEnabled --type bool true
  write_key --file kwinrc --group Plugins --key blurEnabled --type bool true
  write_key --file kwinrc --group Effect-blur --key BlurStrength 5
  write_key --file kwinrc --group Effect-blur --key NoiseStrength 0
fi
if [[ "$restored_shortcuts" -eq 0 ]]; then
  write_key --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+PgUp,Meta+PgUp,Maximize Window"
  write_key --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "Meta+Up,Meta+Up,Quick Tile Window to the Top"
fi
for off in magiclamp wobblywindows glide sheet fadedesktop cube coverswitch-zoom-in; do
  kwin_effect unloadEffect "$off"
done
for on in squash slide blur; do
  kwin_effect loadEffect "$on"
done

# ---------------------------------------------------------------------------
echo "==> 6/15  Cover Switch + Flip Switch tabbox layouts"
if [[ "$restored_kwin" -eq 0 ]]; then
  write_key --file kwinrc --group TabBox --key LayoutName "org.kde.breeze.desktop"
  write_key --file kwinrc --group TabBoxAlternative --key LayoutName "org.kde.breeze.desktop"
  delete_key --file kwinrc --group TabBox --key ShowDelay
  delete_key --file kwinrc --group TabBox --key DelayTime
  delete_key --file kwinrc --group TabBox --key HighlightWindows
fi
rm -rf "$HOME/.local/share/kwin/tabbox/coverswitch" "$HOME/.local/share/kwin/tabbox/flipswitch" 2>/dev/null || warn "Could not remove tabbox layouts"
echo "    Removed custom tabbox layout directories if present"

# ---------------------------------------------------------------------------
echo "==> 7/15  Panel opacity, floating state, battery, and clock"
if [[ "$restored_applets" -eq 0 ]]; then
  if [[ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] && have python3; then
    python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PY' || true
import configparser, re, sys
path = sys.argv[1]
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(path)
for section in list(cp.sections()):
    if re.fullmatch(r"Containments\]\[\d+\]\[General", section):
        cp[section]["panelOpacity"] = "0"
    if section.endswith("][Configuration][General"):
        if "showPercentage" in cp[section]:
            cp[section].pop("showPercentage", None)
        if "shownItems" in cp[section] and cp[section].get("shownItems") == "org.kde.plasma.battery":
            cp[section].pop("shownItems", None)
    if section.endswith("][Configuration][Appearance"):
        cp[section].pop("dateDisplayFormat", None)
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY
  fi
  if [[ -f "$HOME/.config/plasmashellrc" ]] && have python3; then
    python3 - "$HOME/.config/plasmashellrc" <<'PY' || true
import configparser, re, sys
path = sys.argv[1]
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(path)
for section in cp.sections():
    if re.fullmatch(r"PlasmaViews\]\[Panel \d+", section):
        cp[section]["floating"] = "true"
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY
  fi
else
  echo "    appletsrc restored from backup; panel/battery/clock returned to preinstall state"
fi

# ---------------------------------------------------------------------------
echo "==> 8/15  Centered taskbar spacers"
if [[ "$restored_applets" -eq 1 ]]; then
  echo "    Original panel layout restored from backup"
else
  echo "    Leaving panel spacers in place; no reliable marker identifies ours"
fi

# ---------------------------------------------------------------------------
echo "==> 9/15  Numbered pager/workspace indicator settings"
if [[ "$restored_applets" -eq 0 && -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] && have_python; then
  python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PY' || true
import configparser, sys
path = sys.argv[1]
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(path)
for section in list(cp.sections()):
    if section.endswith("][Configuration][General"):
        for key in ("displayedText", "showWindowOutlines", "currentDesktopSelected"):
            cp[section].pop(key, None)
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY
else
  echo "    Pager settings restored from backup or python3 unavailable"
fi

# ---------------------------------------------------------------------------
echo "==> 10/15  Touchpad natural scrolling"
if [[ -f "$HOME/.config/kcminputrc" ]] && have python3; then
  python3 - "$HOME/.config/kcminputrc" <<'PY' || true
import configparser, sys
path = sys.argv[1]
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(path)
for section in cp.sections():
    if section.startswith("Libinput]["):
        cp[section]["NaturalScroll"] = "false"
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY
  echo "    NaturalScroll=false for Libinput sections"
else
  echo "    kcminputrc or python3 unavailable; skipping"
fi

# ---------------------------------------------------------------------------
echo "==> 11/15  Kickoff custom icon"
if [[ "$restored_applets" -eq 0 && -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] && have_python; then
  python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PY' || true
import configparser, sys
path = sys.argv[1]
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(path)
for section in cp.sections():
    if section.endswith("][Configuration][General"):
        icon = cp[section].get("icon", "")
        if "cachyos-setup/applicationMenu-nhsoft.svg" in icon:
            cp[section].pop("icon", None)
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY
fi
rm -rf "$HOME/.local/share/icons/cachyos-setup" 2>/dev/null || warn "Could not remove custom Kickoff icon directory"
echo "    Removed custom Kickoff icon assets"

# ---------------------------------------------------------------------------
echo "==> 12/15  Workspace indicator plasmoid"
if [[ "$restored_applets" -eq 0 && -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] && have_python; then
  python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PY' || true
import configparser, sys
path = sys.argv[1]
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(path)
for section in cp.sections():
    if cp[section].get("plugin") == "cachyos.workspace-indicator":
        cp[section]["plugin"] = "org.kde.plasma.pager"
with open(path, "w") as f:
    cp.write(f, space_around_delimiters=False)
PY
fi
rm -rf "$HOME/.local/share/plasma/plasmoids/cachyos.workspace-indicator" 2>/dev/null || warn "Could not remove workspace indicator plasmoid"
echo "    Removed custom workspace indicator plasmoid"

# ---------------------------------------------------------------------------
echo "==> 13/15  Cover Switch zoom-in KWin effect"
kwin_effect unloadEffect coverswitch-zoom-in
if [[ "$restored_kwin" -eq 0 ]]; then
  write_key --file kwinrc --group Plugins --key coverswitch-zoom-inEnabled --type bool false
fi
rm -rf "$HOME/.local/share/kwin/effects/coverswitch-zoom-in" 2>/dev/null || warn "Could not remove coverswitch-zoom-in effect"
echo "    Disabled and removed coverswitch-zoom-in"

# ---------------------------------------------------------------------------
echo "==> 14/15  Shortcuts, KRunner, Konsole, VSCode, and zsh"
if [[ "$restored_shortcuts" -eq 0 ]]; then
  write_key --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" "Meta,Meta,Activate Application Launcher"
  write_key --file kglobalshortcutsrc --group "krunner.desktop" --key "_launch" "Alt+Space,Alt+F2,Run Command Interface"
fi
if [[ "$restored_krunner" -eq 0 ]]; then
  delete_key --file krunnerrc --group General --key FreeFloating
  delete_key --file krunnerrc --group General --key Position
fi
rm -f "$HOME/.local/share/konsole/Transparent.profile" "$HOME/.local/share/konsole/WhiteOnBlackTransparent.colorscheme" 2>/dev/null || warn "Could not remove Konsole profile files"
if [[ "$restored_konsole" -eq 0 ]]; then
  delete_key --file konsolerc --group "Desktop Entry" --key DefaultProfile
fi
vscode_settings="$HOME/.config/Code/User/settings.json"
if [[ -n "$backup_dir" && -f "$backup_dir/Code-settings.json" ]]; then
  mkdir -p "$(dirname "$vscode_settings")"
  run cp "$backup_dir/Code-settings.json" "$vscode_settings"
  echo "    Restored VSCode settings.json"
else
  echo "    No VSCode settings backup; leaving current settings"
fi
if [[ -f "$HOME/zsh-setup/uninstall.sh" ]]; then
  (cd "$HOME/zsh-setup" && bash uninstall.sh) || warn "zsh-setup uninstall failed"
else
  echo "    ~/zsh-setup/uninstall.sh not found; skipping zsh cleanup"
fi
if [[ "$REMOVE_ZSH_REPO" -eq 1 && -d "$HOME/zsh-setup" ]]; then
  rm -rf "$HOME/zsh-setup" 2>/dev/null || warn "Could not remove ~/zsh-setup"
fi

# ---------------------------------------------------------------------------
echo "==> 15/15  Packages and final Plasma/KWin reload"
if [[ "$REMOVE_PACKAGES" -eq 1 && -n "$backup_dir" && -f "$backup_dir/kdeplasma-addons.state" ]] \
  && grep -q '^installed_by_us=1' "$backup_dir/kdeplasma-addons.state"; then
  if pacman -Qi kdeplasma-addons >/dev/null 2>&1; then
    run sudo pacman -R --noconfirm kdeplasma-addons
  else
    echo "    kdeplasma-addons not installed"
  fi
else
  echo "    Leaving kdeplasma-addons in place by default"
fi
if have qdbus6; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi
restart_plasmashell

echo ""
echo "Done. Backup directory kept at: ${backup_dir:-<none>}"
echo "Log out and back in to fully clear cached KWin, Plasma, shortcut, and shell state."

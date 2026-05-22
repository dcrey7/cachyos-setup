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
echo "==> 3/15  Darkly application style + transparency + Look-and-Feel"
if [[ "$restored_kdeglobals" -eq 0 ]]; then
  write_key --file kdeglobals --group KDE --key widgetStyle Breeze
  if have plasma-apply-colorscheme; then
    plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 || warn "Could not apply BreezeDark color scheme"
  fi
  if have plasma-apply-desktoptheme; then
    plasma-apply-desktoptheme default >/dev/null 2>&1 || plasma-apply-desktoptheme breeze-dark >/dev/null 2>&1 || warn "Could not apply default desktop theme"
  fi

  # Restore stock CachyOS Look-and-Feel (Sweet-Mars on default install)
  # falling back to BreezeDark if Sweet-Mars isn't available.
  if have plasma-apply-lookandfeel; then
    plasma-apply-lookandfeel -a org.kde.breezedark.desktop >/dev/null 2>&1 \
      || plasma-apply-lookandfeel -a Sweet-Ambar-Blue >/dev/null 2>&1 \
      || warn "Could not apply BreezeDark or Sweet-Ambar-Blue look-and-feel"
  fi

  # Reset icon theme away from Win11 / WhiteSur to a sane default.
  write_key --file kdeglobals --group Icons --key Theme breeze-dark

  # Reset wallpaper to CachyOS default (cachyos.svg) via plasmashell scripting.
  if have qdbus6; then
    qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript '
      var ds = desktops();
      for (var i = 0; i < ds.length; i++) {
        var d = ds[i];
        d.wallpaperPlugin = "org.kde.image";
        d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
        d.writeConfig("Image", "file:///usr/share/wallpapers/cachyos.svg");
      }
    ' >/dev/null 2>&1 || warn "Could not reset wallpaper via plasmashell scripting"
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
echo "==> 8/15  Restore stock CachyOS panel layout"
if [[ "$restored_applets" -eq 1 ]]; then
  echo "    Original panel layout restored from backup"
elif [[ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] && have_python; then
  # Stock CachyOS Plasma 6 panel order is:
  #   kickoff -> pager -> icontasks -> marginsseparator -> systemtray ->
  #   digitalclock -> showdesktop (peek-at-desktop)
  #
  # cachyos-setup adds panelspacers (round 19) and may have removed
  # showdesktop / extra marginsseparators along the way. This step:
  #   - Removes ALL panelspacer applets (install.sh adds them).
  #   - Removes EXTRA marginsseparators beyond the first one.
  #   - Adds a showdesktop applet at the end if none present.
  #   - Adds a marginsseparator before systemtray if none present.
  python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PY' || true
import configparser, re, sys
p = sys.argv[1]
cp = configparser.RawConfigParser()
cp.optionxform = str
cp.read(p)
panels = []
for s in cp.sections():
    m = re.fullmatch(r"Containments\]\[(\d+)", s.replace("][", "]["))
    if m and cp.get(s, "plugin", fallback="") == "org.kde.panel":
        panels.append(m.group(1))

def all_applet_ids():
    ids = set()
    for s in cp.sections():
        m = re.fullmatch(r"Containments\]\[\d+\]\[Applets\]\[(\d+)", s.replace("][", "]["))
        if m:
            ids.add(int(m.group(1)))
    return ids

next_id = max(all_applet_ids() | {0}) + 1

removed_panelspacer = 0
removed_extra_sep = 0
added_showdesktop = 0
added_marginsseparator = 0

for pid in panels:
    sec_general = f"Containments][{pid}][General"
    if not (cp.has_section(sec_general) and cp.has_option(sec_general, "AppletOrder")):
        continue
    order = cp.get(sec_general, "AppletOrder").split(";")
    order = [x for x in order if x]
    plug_of = {}
    for aid in order:
        sec_a = f"Containments][{pid}][Applets][{aid}"
        plug_of[aid] = cp.get(sec_a, "plugin", fallback="") if cp.has_section(sec_a) else ""

    # 1) Remove ALL panelspacer applets
    to_remove = [aid for aid in order if plug_of.get(aid) == "org.kde.plasma.panelspacer"]
    # 2) Remove EXTRA marginsseparators (keep only the first one)
    kept_first_sep = False
    for aid in order:
        if plug_of.get(aid) == "org.kde.plasma.marginsseparator":
            if not kept_first_sep:
                kept_first_sep = True
            else:
                to_remove.append(aid)

    for aid in to_remove:
        if plug_of.get(aid) == "org.kde.plasma.panelspacer":
            removed_panelspacer += 1
        else:
            removed_extra_sep += 1
        sec_a = f"Containments][{pid}][Applets][{aid}"
        if cp.has_section(sec_a):
            cp.remove_section(sec_a)
        prefix = f"Containments][{pid}][Applets][{aid}]["
        for s2 in list(cp.sections()):
            if s2.startswith(prefix):
                cp.remove_section(s2)
    order = [x for x in order if x not in set(to_remove)]
    plug_of = {aid: plug_of[aid] for aid in order if aid in plug_of}

    # 3) Add marginsseparator before systemtray if none present
    has_sep = any(plug_of.get(aid) == "org.kde.plasma.marginsseparator" for aid in order)
    if not has_sep:
        try:
            st_idx = next(i for i, aid in enumerate(order) if plug_of.get(aid) == "org.kde.plasma.systemtray")
        except StopIteration:
            st_idx = len(order)
        new_aid = str(next_id); next_id += 1
        sec_a = f"Containments][{pid}][Applets][{new_aid}"
        cp.add_section(sec_a)
        cp.set(sec_a, "immutability", "1")
        cp.set(sec_a, "plugin", "org.kde.plasma.marginsseparator")
        order.insert(st_idx, new_aid)
        added_marginsseparator += 1

    # 4) Add showdesktop at the end if none present
    has_showdesktop = any(plug_of.get(aid) == "org.kde.plasma.showdesktop" for aid in order)
    if not has_showdesktop:
        new_aid = str(next_id); next_id += 1
        sec_a = f"Containments][{pid}][Applets][{new_aid}"
        cp.add_section(sec_a)
        cp.set(sec_a, "immutability", "1")
        cp.set(sec_a, "plugin", "org.kde.plasma.showdesktop")
        order.append(new_aid)
        added_showdesktop += 1

    cp.set(sec_general, "AppletOrder", ";".join(order))

with open(p, "w") as f:
    cp.write(f, space_around_delimiters=False)
print(f"    Removed {removed_panelspacer} panelspacer, {removed_extra_sep} extra marginsseparator")
print(f"    Added   {added_marginsseparator} marginsseparator, {added_showdesktop} showdesktop")
PY
else
  echo "    Could not access appletsrc; skipping panel layout restore"
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
  (cd "$HOME/zsh-setup" && bash uninstall.sh -y) || warn "zsh-setup uninstall failed"
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

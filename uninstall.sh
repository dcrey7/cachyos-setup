#!/usr/bin/env bash
# Reverses cachyos-setup install.sh tweaks:
#   - Restores kwinrc + plasma-org.kde.plasma.desktop-appletsrc from backup
#   - Unloads our effects, reloads Plasma 6 defaults (squash + slide)
#   - Restores VSCode settings.json if patched
#   - Removes WhiteSur-kde theme + kdeplasma-addons if WE installed them
set -euo pipefail

backup_link="$HOME/.config/cachyos-setup-backup-latest"
if [[ ! -L "$backup_link" && ! -d "$backup_link" ]]; then
  echo "ERROR: No backup found at $backup_link." >&2
  echo "       Did you ever run install.sh? Aborting." >&2
  exit 1
fi
backup_dir="$(readlink -f "$backup_link")"

echo "This will undo cachyos-setup tweaks using backup: $backup_dir"
echo "  - Restore ~/.config/kwinrc"
echo "  - Restore ~/.config/plasma-org.kde.plasma.desktop-appletsrc"
echo "  - Unload magiclamp, reload squash (Plasma 6 default minimize)"
echo "  - Restore VSCode settings (if patched)"
echo "  - Remove WhiteSur-kde theme (only if install.sh installed it)"
echo ""
read -r -p "Continue? [y/N] " confirm
[[ "${confirm:-}" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
echo "==> 1/5  Restore kwinrc"
if [[ -f "$backup_dir/kwinrc" ]]; then
  cp "$backup_dir/kwinrc" "$HOME/.config/kwinrc"
  echo "    Restored ~/.config/kwinrc from backup"
else
  # No prior kwinrc -- remove just the keys install.sh wrote
  for key in library theme ButtonsOnLeft ButtonsOnRight; do
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "$key" --delete || true
  done
  for key in magiclampEnabled squashEnabled wobblywindowsEnabled glideEnabled \
             sheetEnabled slideEnabled fadedesktopEnabled cubeEnabled; do
    kwriteconfig6 --file kwinrc --group "Plugins" --key "$key" --delete || true
  done
  kwriteconfig6 --file kwinrc --group "Effect-magiclamp" --key AnimationDuration --delete || true
  for grp in TabBox TabBoxAlternative; do
    for key in LayoutName HighlightWindows ShowDelay DelayTime; do
      kwriteconfig6 --file kwinrc --group "$grp" --key "$key" --delete || true
    done
  done
  echo "    No kwinrc backup; deleted only the keys install.sh wrote"
fi

# Remove the rescued Cover Switch / Flip Switch tabbox QML if we installed it
for layout in coverswitch flipswitch; do
  if [[ -d "$HOME/.local/share/kwin/tabbox/$layout" ]]; then
    rm -rf "$HOME/.local/share/kwin/tabbox/$layout"
    echo "    removed ~/.local/share/kwin/tabbox/$layout"
  fi
done

# ---------------------------------------------------------------------------
echo "==> 2/5  Reload KWin + swap effects back to Plasma 6 defaults"
if command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  for off in magiclamp wobblywindows glide sheet fadedesktop cube; do
    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "$off" >/dev/null 2>&1 || true
  done
  for on in squash slide; do
    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "$on" >/dev/null 2>&1 || true
  done
  echo "    KWin: extras unloaded, defaults (squash + slide) loaded"
fi

# ---------------------------------------------------------------------------
echo "==> 3/5  Restore plasma appletsrc (panel/battery)"
if [[ -f "$backup_dir/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
  pkill -9 plasmashell 2>/dev/null || true
  sleep 1
  cp "$backup_dir/plasma-org.kde.plasma.desktop-appletsrc" \
     "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  nohup kstart plasmashell >/dev/null 2>&1 & disown
  sleep 2
  echo "    Restored appletsrc and restarted plasmashell"
else
  echo "    No plasma appletsrc backup; skipping"
fi

# ---------------------------------------------------------------------------
echo "==> 4/5  VSCode settings"
vscode_settings="$HOME/.config/Code/User/settings.json"
if [[ -f "$backup_dir/Code-settings.json" ]]; then
  cp "$backup_dir/Code-settings.json" "$vscode_settings"
  echo "    Restored VSCode settings.json"
else
  echo "    No VSCode backup; nothing to restore"
fi

# ---------------------------------------------------------------------------
echo "==> 5/5  Packages installed by install.sh"
for pkg_state in whitesur kdeplasma-addons; do
  case "$pkg_state" in
    whitesur)         pkg=whitesur-kde-theme  ;;
    kdeplasma-addons) pkg=kdeplasma-addons    ;;
  esac
  sf="$backup_dir/${pkg_state}.state"
  if [[ -f "$sf" ]] && grep -q '^installed_by_us=1' "$sf"; then
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
      echo "    Removing $pkg (install.sh installed it)..."
      sudo pacman -R --noconfirm "$pkg"
    else
      echo "    $pkg: marked as ours but pacman doesn't see it; skipping."
    fi
  else
    echo "    $pkg: not installed by us, leaving in place."
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "✓ Done. Backup directory kept at: $backup_dir"
echo "  (Delete it manually once you're sure things look right.)"

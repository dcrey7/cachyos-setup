#!/usr/bin/env bash
# Reverses cachyos-setup install.sh tweaks:
#   - Restores kwinrc + plasma-org.kde.plasma.desktop-appletsrc from backup
#   - Unloads magiclamp, reloads squash (Plasma 6 default minimize effect)
#   - Restores VSCode settings.json if patched
#   - Removes WhiteSur-kde theme if WE installed it
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
  for key in magiclampEnabled squashEnabled; do
    kwriteconfig6 --file kwinrc --group "Plugins" --key "$key" --delete || true
  done
  kwriteconfig6 --file kwinrc --group "Effect-magiclamp" --key AnimationDuration --delete || true
  echo "    No kwinrc backup; deleted only the keys install.sh wrote"
fi

# ---------------------------------------------------------------------------
echo "==> 2/5  Reload KWin + swap effects back"
if command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect magiclamp >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect   squash    >/dev/null 2>&1 || true
  echo "    KWin: magiclamp unloaded, squash loaded"
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
echo "==> 5/5  WhiteSur-kde theme"
state_file="$backup_dir/whitesur.state"
if [[ -f "$state_file" ]] && grep -q '^installed_by_us=1' "$state_file"; then
  if pacman -Qi whitesur-kde-theme >/dev/null 2>&1; then
    echo "    install.sh installed it -- removing via paru..."
    paru -R --noconfirm whitesur-kde-theme
  else
    echo "    Marked as installed by us but pacman doesn't see it; skipping."
  fi
else
  echo "    Not installed by us -- leaving it in place."
fi

# ---------------------------------------------------------------------------
echo ""
echo "✓ Done. Backup directory kept at: $backup_dir"
echo "  (Delete it manually once you're sure things look right.)"

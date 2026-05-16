#!/usr/bin/env bash
# Reverses cachyos-setup install.sh tweaks:
#   - Restores kwinrc from the most recent backup (decoration + Magic Lamp keys)
#   - Restores VSCode settings.json if we patched it
#   - Removes WhiteSur-kde theme if WE installed it (leaves it alone otherwise)
#
# (Panel settings are not touched -- they were never modified by install.sh.)
set -euo pipefail

backup_link="$HOME/.config/cachyos-setup-backup-latest"
if [[ ! -L "$backup_link" && ! -d "$backup_link" ]]; then
  echo "ERROR: No backup found at $backup_link." >&2
  echo "       Did you ever run install.sh? Aborting to avoid making things worse." >&2
  exit 1
fi
backup_dir="$(readlink -f "$backup_link")"

echo "This will undo cachyos-setup tweaks using backup: $backup_dir"
echo "  - Restore ~/.config/kwinrc"
echo "  - Disable Magic Lamp (via kwinrc restore)"
echo "  - Restore VSCode settings (if patched)"
echo "  - Remove WhiteSur-kde theme (only if install.sh installed it)"
echo ""
read -r -p "Continue? [y/N] " confirm
[[ "${confirm:-}" =~ ^[Yy] ]] || { echo "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
echo "==> 1/4  Restore kwinrc"
if [[ -f "$backup_dir/kwinrc" ]]; then
  cp "$backup_dir/kwinrc" "$HOME/.config/kwinrc"
  echo "    Restored ~/.config/kwinrc from backup"
else
  # No prior kwinrc -- remove the keys we set, leave the rest intact
  for key in library theme ButtonsOnLeft ButtonsOnRight; do
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "$key" --delete || true
  done
  for key in magiclampEnabled minimizeanimationEnabled; do
    kwriteconfig6 --file kwinrc --group "Plugins" --key "$key" --delete || true
  done
  echo "    No kwinrc backup; deleted only the keys install.sh wrote"
fi

# ---------------------------------------------------------------------------
echo "==> 2/4  Reload KWin"
if command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
    && echo "    KWin reconfigured." \
    || echo "    WARNING: qdbus6 KWin reconfigure failed; log out/in to apply."
fi

# ---------------------------------------------------------------------------
echo "==> 3/4  VSCode settings"
vscode_settings="$HOME/.config/Code/User/settings.json"
if [[ -f "$backup_dir/Code-settings.json" ]]; then
  cp "$backup_dir/Code-settings.json" "$vscode_settings"
  echo "    Restored VSCode settings.json from backup"
else
  echo "    No VSCode backup; nothing to restore"
fi

# ---------------------------------------------------------------------------
echo "==> 4/4  WhiteSur-kde theme"
state_file="$backup_dir/whitesur.state"
if [[ -f "$state_file" ]] && grep -q '^installed_by_us=1' "$state_file"; then
  if pacman -Qi whitesur-kde-theme >/dev/null 2>&1; then
    echo "    install.sh installed it -- removing via paru..."
    paru -R --noconfirm whitesur-kde-theme
  else
    echo "    Marked as installed by us but pacman doesn't see it; skipping."
  fi
else
  echo "    Not installed by us (or unknown) -- leaving it in place."
fi

# ---------------------------------------------------------------------------
echo ""
echo "✓ Done. Backup directory kept at: $backup_dir"
echo "  (Delete it manually once you're sure things look right.)"

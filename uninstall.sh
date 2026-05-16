#!/usr/bin/env bash
# Reverses the cachy-desktop install.sh tweaks:
#   - Restores kwinrc + plasma appletsrc from the most recent backup
#   - Disables Magic Lamp, re-enables default minimize animation
#   - Floating panel back on, default height
#   - Restores VSCode settings.json if we patched it
#   - Removes WhiteSur-kde theme if WE installed it (leaves it alone otherwise)
set -euo pipefail

backup_link="$HOME/.config/cachy-desktop-backup-latest"
if [[ ! -L "$backup_link" && ! -d "$backup_link" ]]; then
  echo "ERROR: No backup found at $backup_link." >&2
  echo "       Did you ever run install.sh? Aborting to avoid making things worse." >&2
  exit 1
fi
backup_dir="$(readlink -f "$backup_link")"

echo "This will undo cachy-desktop tweaks using backup: $backup_dir"
echo "  - Restore ~/.config/kwinrc and plasma appletsrc"
echo "  - Disable Magic Lamp"
echo "  - Float panel, reset height"
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
echo "==> 2/5  Reload KWin"
if command -v qdbus6 >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
    && echo "    KWin reconfigured." \
    || echo "    WARNING: qdbus6 KWin reconfigure failed; log out/in to apply."
fi

# ---------------------------------------------------------------------------
echo "==> 3/5  Panel: floating back on, default height"
if command -v qdbus6 >/dev/null 2>&1; then
  script='
    var ids = panelIds;
    for (var i = 0; i < ids.length; i++) {
      var p = panelById(ids[i]);
      p.floating = true;
      p.height   = 44;
    }
  '
  qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript "$script" >/dev/null 2>&1 \
    && echo "    Panel(s) reset (floating=true, height=44)." \
    || echo "    WARNING: PlasmaShell scripting call failed."
fi

# Also restore appletsrc if available -- some panel settings (location, lengthMode)
# aren't covered by the two keys above.
if [[ -f "$backup_dir/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
  cp "$backup_dir/plasma-org.kde.plasma.desktop-appletsrc" \
     "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  echo "    Restored plasma appletsrc (will fully apply after logout/login)"
fi

# ---------------------------------------------------------------------------
echo "==> 4/5  VSCode settings"
vscode_settings="$HOME/.config/Code/User/settings.json"
if [[ -f "$backup_dir/Code-settings.json" ]]; then
  cp "$backup_dir/Code-settings.json" "$vscode_settings"
  echo "    Restored VSCode settings.json from backup"
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
  echo "    Not installed by us (or unknown) -- leaving it in place."
fi

# ---------------------------------------------------------------------------
echo ""
echo "✓ Done. Backup directory kept at: $backup_dir"
echo "  (Delete it manually once you're sure things look right.)"
echo ""
echo "If the panel still looks customized, log out and back in --"
echo "plasmashell caches its layout in memory."

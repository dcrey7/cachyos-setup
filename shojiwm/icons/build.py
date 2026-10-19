# /// script
# dependencies = ["numpy", "pillow"]
# ///
"""Build the shoji-picks icon theme: hand-picked icons on top of Yaru.

Every icon keeps its own shape; nothing is put in a circle or a square.

    calculator      Yaru, with the blue "=" made orange (like the Mac one)
    Spectacle       Win11 scissors (like the Windows Snipping Tool)
    Dolphin         Win11 open yellow folder (Microsoft yellow, no blue bar)
    folders         Yaru folders, blue made Windows yellow (symbols kept)
    Kate            Win11 Notepad
    KWrite          Win11 yellow notes pad (like Apple Notes)
    Settings app    Ubuntu (Yaru) gear
    Settings pages  Win11, one different icon per page; Breeze where Win11
                    repeats one

Run it again after you change a pick:
    uv run shojiwm/icons/build.py
The result is shojiwm/icons/shoji-picks; install.sh copies it.
"""

import hashlib
import os
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ICONS = Path.home() / ".local/share/icons"
WIN11 = ICONS / "Win11-dark"
YARU_BASE = ICONS / "Yaru-kde-base"
BREEZE = Path("/usr/share/icons/breeze-dark")
YARU = ICONS / "Yaru-blue-kde"
OUT = Path(__file__).parent / "shoji-picks"

# Icon name -> the Win11 icon to use for it.
WIN11_APPS = {
    "spectacle": "spectacle",
    "org.kde.spectacle": "spectacle",
    "applets-screenshooter": "spectacle",
    "org.kde.dolphin": "folder-open",
    "system-file-manager": "folder-open",
    "kate": "kate",
    "org.kde.kate": "kate",
    "accessories-text-editor": "kate",
    "kwrite": "org.kde.kwrite",
    "org.kde.kwrite": "org.kde.kwrite",
}

# The Settings app keeps the Ubuntu (Yaru) gear.
GEAR_NAMES = ["preferences-system", "systemsettings", "org.kde.systemsettings"]

# The icons of the System Settings pages and groups (from the KCM plugins).
# The "-symbolic" ones stay Breeze: they are one-colour line icons that the
# tray uses too.
SETTINGS = """
applications-all input-keyboard-virtual krunner ktip lighttable
network-wireless-hotspot plasma-search preferences-desktop
preferences-desktop-accessibility preferences-desktop-activities
preferences-desktop-animations preferences-desktop-baloo preferences-desktop-color
preferences-desktop-cursors preferences-desktop-default-applications
preferences-desktop-display preferences-desktop-display-randr
preferences-desktop-effects preferences-desktop-feedback
preferences-desktop-filetype-association preferences-desktop-font
preferences-desktop-font-installer preferences-desktop-gaming
preferences-desktop-icons preferences-desktop-keyboard
preferences-desktop-keyboard-shortcut preferences-desktop-locale
preferences-desktop-mouse preferences-desktop-multimedia
preferences-desktop-notification-bell preferences-desktop-peripherals
preferences-desktop-plasma-theme preferences-desktop-search
preferences-desktop-sound preferences-desktop-tablet
preferences-desktop-theme-applications preferences-desktop-theme-global
preferences-desktop-theme-windowdecorations preferences-desktop-thunderbolt
preferences-desktop-touchpad preferences-desktop-touchscreen
preferences-desktop-user preferences-desktop-user-password
preferences-desktop-virtual preferences-desktop-wallpaper
preferences-online-accounts preferences-security preferences-security-firewall
preferences-system preferences-system-bluetooth preferences-system-disks
preferences-system-login preferences-system-network
preferences-system-network-connection preferences-system-network-proxy
preferences-system-power-management preferences-system-session-services
preferences-system-splash preferences-system-tabbox preferences-system-time
preferences-system-users preferences-system-windows
preferences-system-windows-actions preferences-web-browser-shortcuts
redshift-status-on smartphone system-log-out system-run user-trash xorg
""".split()

# The folder icons Yaru draws in blue.
YARU_FOLDERS = [
    "folder", "folder-open", "folder-documents", "folder-download",
    "folder-music", "folder-pictures", "folder-videos", "folder-templates",
    "folder-publicshare", "folder-remote", "folder-recent", "folder-dropbox",
    "inode-directory", "insync-folder", "user-desktop", "user-home",
]
# Yaru draws "folder-download"; some apps ask for "folder-downloads".
FOLDER_ALIASES = {"folder-downloads": "folder-download"}

CALCULATOR_NAMES = ["accessories-calculator", "org.kde.kcalc"]
SIZES = ["16x16", "24x24", "32x32", "48x48", "256x256"]
MAC_ORANGE = (36 / 360, 0.96, 1.15)  # hue, max saturation, brightness gain
WINDOWS_YELLOW = (44 / 360, 0.78, 1.12)
FOLDER_DARK_PART = (32 / 360, 0.82)  # symbol and back flap: amber-orange


def find_icon(theme: Path, name: str) -> Path | None:
    """The SVG for `name` in a theme (any folder), with links resolved."""
    hits = [
        Path(root) / f
        for root, _, files in os.walk(theme, followlinks=True)
        for f in files
        if f == f"{name}.svg"
    ]
    if not hits:
        return None
    # Prefer the scalable one, else the biggest fixed size.
    def size(p: Path) -> int:
        nums = [int(part) for part in p.parts if part.isdigit()]
        return 10_000 if "scalable" in p.parts else max(nums, default=0)

    return max(hits, key=size).resolve()


def file_hash(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def put_svg(src: Path, kind: str, name: str) -> None:
    dest = OUT / "scalable" / kind / f"{name}.svg"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)


def rgb_to_hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    v = rgb.max(-1)
    c = v - rgb.min(-1)
    s = np.where(v > 0, c / np.maximum(v, 1e-9), 0)
    safe_c = np.maximum(c, 1e-9)
    h = np.select(
        [v == r, v == g],
        [((g - b) / safe_c) % 6, (b - r) / safe_c + 2],
        (r - g) / safe_c + 4,
    ) / 6
    return np.where(c > 0, h, 0), s, v


def hsv_to_rgb(h: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1)


def recolor_blue(src: Path, dest: Path, colour: tuple[float, float, float], dark_part: tuple[float, float] | None = None) -> None:
    """Give the blue pixels a new colour; keep the light and shade of each one.

    `dark_part` (hue, brightness) recolours the dark blue pixels on their own:
    on a folder those are the symbol and the back flap.
    """
    hue, max_s, gain = colour
    img = np.asarray(Image.open(src).convert("RGBA")).astype(float) / 255
    h, s, v = rgb_to_hsv(img[..., :3])
    blue = (h > 180 / 360) & (h < 250 / 360) & (s > 0.3)
    new_h, new_s, new_v = np.full_like(h, hue), np.minimum(s, max_s), np.minimum(v * gain, 1)
    if dark_part:
        dark = v < 0.78
        new_h = np.where(dark, dark_part[0], new_h)
        new_s = np.where(dark, 1.0, new_s)
        new_v = np.where(dark, np.minimum(v / 0.68 * dark_part[1], 1), new_v)
    new_rgb = hsv_to_rgb(new_h, new_s, new_v)
    img[..., :3] = np.where(blue[..., None], new_rgb, img[..., :3])
    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((img * 255).round().astype(np.uint8)).save(dest)


def build_settings() -> list[str]:
    """Win11 for each Settings icon; Breeze where Win11 repeats an icon."""
    used: set[str] = set()
    notes = []
    for name in SETTINGS:
        win = find_icon(WIN11, name)
        if win and file_hash(win) not in used:
            used.add(file_hash(win))
            put_svg(win, "settings", name)
            continue
        breeze = find_icon(BREEZE, name)
        if breeze and file_hash(breeze) not in used:
            used.add(file_hash(breeze))
            put_svg(breeze, "settings", name)
            notes.append(f"{name}: Breeze ({'Win11 repeats' if win else 'not in Win11'})")
        else:
            notes.append(f"{name}: left to Yaru/Breeze (no unique icon)")
    return notes


def write_index(dirs: list[str]) -> None:
    lines = [
        "[Icon Theme]",
        "Name=shoji-picks",
        "Comment=Hand-picked icons (Mac calculator, Windows snip, yellow folders, Win11 settings) on Yaru",
        "Inherits=Yaru-blue-kde,breeze-dark,breeze,hicolor",
        f"Directories={','.join(dirs)}",
        "",
    ]
    contexts = {"apps": "Applications", "places": "Places", "settings": "Applications"}
    for d in dirs:
        lines.append(f"[{d}]")
        lines.append(f"Context={contexts[d.split('/')[-1]]}")
        if d.startswith("scalable"):
            lines += ["Size=256", "MinSize=8", "MaxSize=512", "Type=Scalable"]
        else:
            size, _, scale = d.split("/")[0].partition("@")
            lines.append(f"Size={size.split('x')[0]}")
            if scale:
                lines.append(f"Scale={scale.rstrip('x')}")
            lines.append("Type=Fixed")
        lines.append("")
    (OUT / "index.theme").write_text("\n".join(lines))


def main() -> None:
    shutil.rmtree(OUT, ignore_errors=True)
    notes = build_settings()
    # The app picks and the gear win over the Settings list (both name
    # system-file-manager and preferences-system): drop the Settings copy.
    for name, source in WIN11_APPS.items():
        put_svg(find_icon(WIN11, source), "apps", name)
    for name in [*WIN11_APPS, *GEAR_NAMES]:
        (OUT / "scalable" / "settings" / f"{name}.svg").unlink(missing_ok=True)

    fixed_dirs = []
    for size in SIZES:
        for folder in (size, f"{size}@2x"):
            src = YARU / folder / "apps" / "accessories-calculator.png"
            for name in CALCULATOR_NAMES:
                recolor_blue(src, OUT / folder / "apps" / f"{name}.png", MAC_ORANGE)
            for name in GEAR_NAMES:
                shutil.copyfile(YARU_BASE / folder / "apps" / "preferences-system.png", OUT / folder / "apps" / f"{name}.png")
            fixed_dirs.append(f"{folder}/apps")
            places = YARU / folder / "places"
            for name in YARU_FOLDERS:
                if (places / f"{name}.png").exists():
                    recolor_blue(places / f"{name}.png", OUT / folder / "places" / f"{name}.png", WINDOWS_YELLOW, FOLDER_DARK_PART)
            for alias, name in FOLDER_ALIASES.items():
                if (places / f"{name}.png").exists():
                    recolor_blue(places / f"{name}.png", OUT / folder / "places" / f"{alias}.png", WINDOWS_YELLOW, FOLDER_DARK_PART)
            fixed_dirs.append(f"{folder}/places")

    write_index(fixed_dirs + ["scalable/apps", "scalable/settings"])
    count = sum(1 for p in OUT.rglob("*") if p.is_file())
    print(f"built {OUT} ({count} files)")
    for note in notes:
        print("  " + note)


if __name__ == "__main__":
    main()

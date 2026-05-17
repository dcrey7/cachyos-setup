# Cover Switch / Flip Switch — GNOME parity tuning

**Date:** 2026-05-17 22:30

## What was reported

Live test on CachyOS / Plasma 6 showed two visual bugs vs the GNOME
CoverflowAltTab the user is comparing against:

1. **Window appears twice** — the live Firefox window was visible behind the
   center coverflow card. The PlasmaCore.Dialog at `Floating` location does
   not blank the workspace, so the real window kept rendering behind the
   ThumbnailItem mirror.
2. **Side cards spread too far apart** — the original MR !91 QML laid cards
   along a wide PathView (x = 0.10 → 0.90 of screen width). GNOME's algorithm
   stacks side cards at fixed anchors (`xOffsetLeft = 20%`,
   `xOffsetRight = 80%`) so off-center cards collapse behind the front one
   instead of fanning out across the screen.

## GNOME source the fixes are based on

Studied:
- `coverflowSwitcher.js` (325 lines) — extracted positioning math:
  `xOffsetLeft = width * (0.5 * (1 - ratio) - 0.1 * ratio)` with default
  ratio = 0.5 → `xOffsetLeft = width * 0.20`.
- `switcher.js` (1497 lines) — confirmed dim background mechanism via
  `dimBackground()` tweening to `dim_factor = 1.0`.
- `platform.js` (686 lines) — `_backgroundShade` actor draws full-screen
  RGB(0,0,0) with `opacity 255` animated in over 200 ms.
- `schemas/org.gnome.shell.extensions.coverflowalttab.gschema.xml` —
  confirmed defaults: `coverflow-window-angle = 90`,
  `preview-to-monitor-ratio = 0.5`, `dim-factor = 1.0`,
  `animation-time = 0.2`, `switcher-background-color = (0,0,0)`.

## Changes

### `assets/coverswitch/contents/ui/main.qml`

- **Added full-screen `Rectangle` dim overlay** at `z: -10`, `color: "black"`,
  `opacity: 0.88`. Mirrors GNOME's `dim-factor` (slightly less than 1.0 so the
  panel edges peek through, which matches the visual feel).
- **Wrapped `mainItem` in plain `Item`** so the dim rectangle can occupy the
  full screen geometry while the `ColumnLayout` sits inside it.
- **Tightened PathView curve**: cards now stack at 30%-34% (left) and
  66%-70% (right) of screen width instead of spreading 10%-90%. The
  PathQuad center anchor is at 50%. Side cards stack at the anchors rather
  than fanning.
- **Sharper rotation** (75°, up from 70°) to be closer to GNOME's 90°.
- **`pathItemCount: 7`** down from 13 so fewer side cards are visible at
  once → cleaner stack.
- **Per-card opacity fade** based on `PathView.scale` so back-of-stack
  cards are slightly dimmer (depth cue).
- **Animation duration 200 ms** (was `veryLongDuration / sqrt(N+1)`),
  matching GNOME's `animation-time = 0.2`.
- **Removed the FrameSvgItem highlight** — GNOME has no equivalent and the
  rectangle outline looked out of place over the dim overlay.
- **`Qt.Popup | Qt.FramelessWindowHint`** added to dialog flags so the
  window covers the workspace cleanly.
- **Caption colour set to `"white"`** since the background is now black.

### `assets/flipswitch/contents/ui/main.qml`

- Same dim overlay + dialog flag changes applied (the side-card spacing
  in flipswitch is correct since cards are stacked vertically — only the
  background needed fixing).

## What was NOT changed

- `KWin.ThumbnailItem` continues to render the live window content via the
  compositor. This is the equivalent of GNOME's `windowActor.get_texture()`
  approach. Both render LIVE — they're not screenshots.
- The metadata.json / metadata.desktop are unchanged.
- The install + uninstall scripts are unchanged; they already install these
  QML files from `assets/` into `~/.local/share/kwin/tabbox/`.

## Known limitations / possible next iterations

- Cannot test from this machine (Ubuntu GNOME, not Plasma 6). Reported back
  by user is needed.
- The QML imports still target Plasma 5 versions (`org.kde.plasma.core 2.0`,
  `org.kde.kwin 2.0`). If Plasma 6.6 has bumped to `2.1` or `3.0`, may need
  a follow-up patch.
- GNOME's coverflow animates with cubic ease-out (`userChoice`); QML's
  PathView interpolates linearly by default. Visual difference is minor but
  exists.

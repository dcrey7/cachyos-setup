# Cover Switch 2 background, larger cards, and zoom-in alignment

**Date:** 2026-05-29
**UTC time:** 08:54:24 UTC

## Files changed

- `assets/coverswitch2/contents/ui/main.qml`
- `~/.local/share/kwin/tabbox/coverswitch2/contents/ui/main.qml`
- `assets/kwin-effects/coverswitch2-zoom-in/contents/code/main.js`
- `~/.local/share/kwin/effects/coverswitch2-zoom-in/contents/code/main.js`
- `updates/2026-05-29_coverswitch2_background_cards_zoom.md`

## Runtime geometry observed before layout edits

- KWin version: `6.6.5`
- Qt version: `6.11.1`
- Operation mode: Wayland
- Active output: `HDMI-A-1`
- KWin output geometry: `0,0 2560x1440`
- KWin output scale: `1`
- KWin `ScreenArea`: `0,0 2560x1440`
- KWin `MaximizeArea`: `0,0 2560x1400`
- Plasma panel/taskbar reserve: bottom panel `40`; panel length `2560`
- Final tabbox window geometry from the current QML formula:
  `x=tabBox.screenGeometry.x`, `y=tabBox.screenGeometry.y`,
  `width=rawScreenWidth`, `height=rawScreenHeight - panelReserve`, which is
  expected to resolve to `0,0 2560x1400` in this single-output session.

Qt `Screen.*` and `tabBox.screenGeometry` did not emit fresh QML-side log lines
after `qdbus6 org.kde.KWin /KWin reconfigure`; KWin continued reporting cached
old line numbers before the final reload attempt. Because of that, the layout
change avoids new absolute geometry constants and keeps the existing dynamic
`Screen`/KWin client-area reserve path.

## Observed problem

Cover Switch 2 kept the desired zoom-out-to-card-stack visual and panel-visible
geometry, but the wallpaper background could sometimes fall back to a plain dark
surface. The installed QML also had repeated `Unable to assign [undefined] to
QUuid` warnings from clearing the morph thumbnail id, and an older warning about
conflicting `visible` and `visibility` properties.

The card stack also felt too small, the wrap from the last card back to the
first card was too slow, and the close-side zoom effect still started from the
old smaller `45%` card footprint.

Follow-up: after the live reload, the tabbox showed black screen edges on the
left and right. This matched the earlier regression documented in
`updates/2026-05-22_coverswitch_extended_display_geometry_fix.md`, where the
verified fix required `Screen.width` / `Screen.height` for the backdrop and
overlay sizing plus the original
`output: KWin.Workspace.screenAt(Qt.point(...))` desktop background binding.

## Intended behavior

The background keeps the custom non-fullscreen tabbox window so the bottom panel
remains visible. After the black-edge regression, the backdrop, desktop
background, dim overlay sizing, and `DesktopBackground.output` binding were
restored to the previously verified no-black-edge path without reducing the
larger card stack.

Cards now use a larger `60%` preview footprint. The wrap transition from last to
first is treated as a short `125ms` low-overshoot `OutBack` offset animation
instead of a long multi-card traversal, so it has a small landing bounce instead
of stopping flat. A follow-up adds a tiny horizontal post-wrap wiggle on the
card stack: `14px`, `-7px`, `3px`, then back to `0`.

The open morph thumbnail is destroyed through a `Loader` when inactive instead
of assigning `undefined` to `wId`. The close-side `coverswitch2-zoom-in` effect
now starts from the same larger `60%` card footprint, prefers KWin
`MaximizeArea` when available, and uses the same `220ms` timing as the opening
morph.

## Tested / not tested

- `node --check assets/kwin-effects/coverswitch2-zoom-in/contents/code/main.js`
- Deployed the QML and effect to the installed local copies.
- Verified installed files byte-match the repo copies with `cmp -s`.
- Reloaded KWin config and unloaded/loaded the `coverswitch2-zoom-in` effect.
- Confirmed KWin support info lists `coverswitch2-zoom-in` as loaded.
- Invoked `Walk Through Windows` once through KGlobalAccel; no new
  `coverswitch2`, QML, `Unable to assign`, or conflicting-property journal
  entries appeared afterward.
- Follow-up live reload after KWin appeared to keep the old switcher in memory:
  cleared `~/.cache/kwin/qmlcache`, temporarily changed `[TabBox] LayoutName`
  to `flipswitch`, ran KWin reconfigure, restored `coverswitch2`, ran KWin
  reconfigure again, and reloaded `coverswitch2-zoom-in`.
- Follow-up black-edge fix restored the previously verified `Screen.width` /
  `Screen.height` backdrop, desktop background, and overlay sizing, then also
  restored the old `DesktopBackground.output: KWin.Workspace.screenAt(...)`
  binding from commit `d9129b5`. It was deployed to the installed QML and KWin
  was reloaded with the same cache-clear and layout-toggle path.
- Follow-up wrap bounce changed the wrap duration to `125ms`, enabled the
  existing `OutBack` offset behavior for wrap transitions, and limited wrap
  overshoot to `0.65`.
- Follow-up horizontal wrap wiggle adds a short `wrapBounceX` transform sequence
  to the `PathView` only after wrap transitions.
- `qmlformat` / `qmlformat6` was not available.
- `install.sh` was not run.
- Visual timing was not manually verified with a human-held Alt+Tab cycle.

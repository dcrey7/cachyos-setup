# Cover Switch 2 package ID split

**Date:** 2026-05-24  
**UTC time:** 21:11:16 UTC

## Files changed

- `AGENTS.md`
- `README.md`
- `install.sh`
- `uninstall.sh`
- `assets/coverswitch2/metadata.json`
- `assets/coverswitch2/metadata.desktop`
- `assets/coverswitch2/contents/ui/main.qml`
- `assets/kwin-effects/coverswitch2-zoom-in/metadata.json`
- `assets/kwin-effects/coverswitch2-zoom-in/contents/code/main.js`

## Observed problem

The custom Cover Switch package used the same `coverswitch` ID as the system
Plasma package. Installing from this repo would place a user-local
`~/.local/share/kwin/tabbox/coverswitch` package above the system package and
effectively override the installed Cover Switch. The custom zoom effect also
used the generic `coverswitch-zoom-in` ID.

The QML package also depended on `install.sh` replacing `__PANEL_RESERVE__`,
which is not suitable for a standalone package that could be tested locally or
distributed through a store.

## Intended behavior

The custom switcher now installs as `coverswitch2`, and the optional KWin
effect installs as `coverswitch2-zoom-in`. This lets the custom animation
coexist with the system `coverswitch` package. The installer selects
`coverswitch2` for Alt+Tab but no longer writes into the system package ID or
copies the repo Flip Switch over the packaged `flipswitch`.

The QML now has a real fallback panel reserve value and keeps the runtime KWin
client-area refresh path. Debug logging is disabled by default in both the QML
layout and the KWin effect.

## Tested / not tested

Tested with static shell/QML/metadata inspection only. `install.sh` was not
run, KWin was not reloaded, and no local package was installed into
`~/.local/share/kwin`.

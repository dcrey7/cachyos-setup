# 2026-05-17 animation polish

## Coverswitch g21

- Added a 160ms `Easing.OutCubic` fade-in wrapper around the dim layer and card scene. The desktop background remains immediate so the native wallpaper still covers the full 1920x1080 output while the visible switcher content fades in.
- Reduced `PathView.highlightMoveDuration` from 300ms to 220ms for snappier cycling without changing the established path geometry, card scale, rotation, or title placement.

## PathView easing notes

`PathView.highlightMoveDuration` controls the built-in highlight movement timing, but it does not expose an easing curve for that interpolation. Explicit easing would require taking over movement, usually by driving `offset` with a `NumberAnimation`. That is more fragile here because `offset` interacts with `pathItemCount`, wrapping, `preferredHighlightBegin`, and the switcher's manually chosen movement direction.

For this pass, the safer polish is to keep PathView's own index movement and shorten its duration. That preserves wrapping behavior and avoids new offset math in the Alt+Tab path.

## Wayland behavior

On Wayland, KWin owns the live windows and the tabbox QML only owns the switcher surface, so the live window cannot morph into a card from QML alone. A full live-window-to-card transform would need a KWin effect. The fade is compositor-friendly and should follow normal KWin/Qt Quick frame timing and vsync, but exact frame pacing still depends on compositor load and output refresh.

# Claude Instructions

Keep an update log for this repo.

For every non-trivial change, make or update a Markdown note in `updates/`
using the current date and UTC time. Include what changed, why it changed,
what was tested, and any remaining risk.

For Cover Switch / Alt+Tab work, preserve these requirements:

- panel/taskbar visible during Alt+Tab
- no overlap with the panel/taskbar
- no black edges on the left or right
- works with laptop only, monitor only, and extended displays
- works regardless of which screen is primary
- no hardcoded monitor dimensions
- no hardcoded panel height

Before changing geometry logic, record the runtime values used by KWin/QML.
The latest known issue is documented in:

```text
updates/2026-05-22_coverswitch_multimonitor_panel_regression.md
```

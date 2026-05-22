# Agent Instructions

This repository uses the `updates/` folder as a dated engineering log.

When making meaningful changes, create or update a Markdown file under
`updates/` with:

- the current date
- the current UTC time
- the files changed
- the observed problem
- the intended behavior
- what was tested or not tested

Prefer filenames like:

```text
updates/YYYY-MM-DD_short_topic.md
```

For Cover Switch or KWin geometry work, do not make blind layout changes.
Document the runtime geometry values first, especially:

- `tabBox.screenGeometry`
- Qt `Screen.*` values
- KWin `ScreenArea`
- KWin `MaximizeArea`
- final tabbox window geometry
- panel/taskbar reserve

Any local test fix for Cover Switch usually needs to be applied to both:

- `assets/coverswitch/contents/ui/main.qml`
- `~/.local/share/kwin/tabbox/coverswitch/contents/ui/main.qml`

Do not run `install.sh` just to test Cover Switch QML unless explicitly asked.
Patch the installed QML directly for local testing and reload KWin.

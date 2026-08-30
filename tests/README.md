# Frontend regression checks

Requires Node.js and the official Luau CLI (https://github.com/luau-lang/luau/releases).

```text
node tests/run_ui_tests.js /path/to/luau
luau-compile --null src/ui/init.lua src/ui/utils.lua src/ui/components.lua src/ui/window.lua
```

The runner executes the current UI source with a small Roblox API double. It checks the category rail, section grouping, desktop/phone layout transitions, search, component values/callbacks, expanding controls, the RT3 stat API, camera changes, cleanup, and the actual Blox Fruits/Universal UI constructors.

These are behavior tests, not a Roblox renderer. Inspect desktop and mobile screenshots in Roblox before claiming pixel-perfect layout or executor compatibility.

## Architecture

- `src/ui/window.lua`: window, category rail, responsive sections, search, dashboard, notifications and lifecycle.
- `src/ui/components.lua`: controls with the existing `Create*` API, plus the new section containers.
- `src/ui/utils.lua`: shared palette, input and animation helpers.
- `src/ui/init.lua`: loads the three modules; no second styling layer overwrites their geometry.

`controller.lua`, `responsive.lua`, and `watchdog.lua` were retired. Their old versions remain recoverable in Git history.

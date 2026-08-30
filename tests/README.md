# Frontend regression checks

Requires Node.js and the official Luau CLI (https://github.com/luau-lang/luau/releases).

```text
node tests/run_ui_tests.js /path/to/luau
luau-compile --null src/ui/init.lua src/ui/utils.lua src/ui/components.lua src/ui/window.lua
```

The runner executes the current UI source with a small Roblox API double. It checks the category rail, section grouping, desktop/phone layout transitions, search, component values/callbacks, expanding controls, the RT3 stat API, camera changes, cleanup, and the actual Blox Fruits/Universal UI constructors.

These are behavior tests, not a Roblox renderer. Inspect desktop and mobile screenshots in Roblox before claiming pixel-perfect layout or executor compatibility.

`fruit_vfx_tests.luau` also exercises the actual Rumble VFX module: all-attribute snapshots, Default slot discovery, seven Shifted slots, the original-skin option, removal of newly created attributes, external updates, replaced instances, malformed/missing data, failed transactions, and dependent selector/button callbacks.

## Fruit VFX behavior

In Blox Fruits, open **Visual/ESP → Skins / cores das frutas**, choose **Rumble**, then choose a color and form. Nothing is changed until **Aplicar cor selecionada** is pressed. Supported presets are Red, Orange, Yellow, Green, Cyan, Blue, Purple, Pink, White and Black (localized in the menu).

- **Normal (Default)** reads the existing numbered `Default_ColorN` attributes and modifies only supported color slots already present.
- **Transformada (Shifted)** uses the seven `Shifted_ColorN` slots from the supplied Rumble script.
- **Original** restores the state captured before this module's first edit on that instance, not a hardcoded cyan palette. The snapshot is in memory for this session; it cannot recover changes made before this module ran.
- Rollback/restore only touches attributes edited by this module. Attributes that were absent are removed again. Unrelated attributes are left alone, and external color updates are preserved with a warning.
- Missing folders/data do not trigger guessing, remote calls, or polling. Reapply manually after replacing/equipping the fruit. Restoring is attempted when the feature is destroyed.

This changes local VFX attributes, not account ownership of skins, and makes no anti-cheat or universal compatibility guarantee.

## Architecture

- `src/ui/window.lua`: window, category rail, responsive sections, search, dashboard, notifications and lifecycle.
- `src/ui/components.lua`: controls with the existing `Create*` API, plus the new section containers.
- `src/ui/utils.lua`: shared palette, input and animation helpers.
- `src/ui/init.lua`: loads the three modules; no second styling layer overwrites their geometry.

`controller.lua`, `responsive.lua`, and `watchdog.lua` were retired. Their old versions remain recoverable in Git history.

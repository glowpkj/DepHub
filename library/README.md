# DepHub Library

The library is split into reusable modules instead of one standalone script.

## Structure

- `init.lua` loads and caches the library modules, replaces an older DepHub window and mounts the selected game content.
- `theme.lua` is the single color/theme source.
- `utils.lua` contains lifecycle-aware UI helpers, text creation, tweening and formatting.
- `components.lua` implements sections, labels, buttons, toggles, sliders, dropdowns, inputs, keybinds and RGB colors.
- `window.lua` owns the screen, sidebar, pages, navigation, dragging, notifications, responsive behavior and cleanup.
- `content/*.lua` connects the components to Universal, Blox Fruits and Restaurant Tycoon 3 backends.

The normal entry point is `DepHub.lua`; it initializes the selected backend first and then calls `Library.new` with the correct mode. The resulting window is available at:

```lua
getgenv().__DEPHUB.Frontend
```

## Window API

```lua
local page = window:CreateTab("TOOLS", "TOOLS")
local section = window:CreateSection(page, "MOVEMENT")

window:CreateToggle(section, {
    Title = "FEATURE",
    Description = "DESCRIPTION",
    Default = false,
    Callback = function(enabled) end
})

window:Notify("TITLE", "MESSAGE", 3, "Success")
window:OpenPage("TOOLS")
window:SetOpen(false)
window:Destroy()
```

Every value component returns a wrapper with `GetValue()` and `SetValue(value, silent)`.
Dropdowns also provide `GetValues()` and `SetValues(values, selected, silent)`. Sections
provide `SetVisible(bool)`. All callbacks are protected; errors are shown as notifications.

The window adapts its width, sidebar, padding and control layout to the current camera
viewport. `RightControl` toggles it by default and can be changed from the Config tab.

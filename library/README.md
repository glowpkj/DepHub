# DepHub — Linoria

`linoria.lua` is the only frontend rendering library. It is based on the source requested at:
https://github.com/ro0ti/Roblox-Scripting-UI/tree/main/Linoria%20Lib

Original file: `Linoria Lib/Linoria Lib Source.lua`.
Original blob: `5ce532748c72ffe021112be612cc1b4da14a6ab8`.

The previous init/theme/utils/components/window/compact modules and content directory have been removed. Game definitions now live under `src/frontend`; they bind backend actions to native Linoria controls and do not render a separate UI.

Normal hub entry point: `DepHub.lua`. The selected frontend is `getgenv().__DEPHUB.Frontend`; its native Linoria instance is `.Library`.

## Native API for standalone scripts

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/codex/aotr-integration/library/linoria.lua"))()
local Window = Library:CreateWindow("DEPHUB")
local Main = Window:AddTab("Main")
local Group = Main:AddLeftGroupbox("Features")
local Toggle = Group:AddToggle("Example", { Text = "Example", Default = false })
Toggle:OnChanged(function() print(Toggle.Value) end)
Window:SetVisible(true)
-- Library:Unload() releases this library instance.
```

This particular source expects a string title, rather than the options table shown in a newer example. Color/key addons return their parent label; access the picker through `Library.Options[id]`. Native OnChanged invokes its callback on registration; the DepHub adapter suppresses that initial call to prevent starting features automatically.

Local source fixes add owned connection/task cleanup, Unload/OnUnload, visibility control, corrected input/dropdown callbacks, normal cursor use and scrolling columns. See `LINORIA_MIGRATION_REPORT.md` at the repository root for provenance, tests and runtime limitations.

RightControl is the default hub menu key. Use the native key picker to change it, and the Unload button to stop both UI and backend. ThemeManager/SaveManager and configuration autoload are not imported.

local sourceUrl = "https://raw.githubusercontent.com/glowpkj/DepHub/fix/dephubv2-core-ux/src/dephubv2lib.lua"
local Library = assert(loadstring(game:HttpGet(sourceUrl))(), "DepHubV2 failed to load")

local function check(name, callback)
local ok, result = pcall(callback)
if not ok then
error("SMOKE TEST FAILED: " .. name .. " | " .. tostring(result), 0)
end
print("SMOKE TEST PASSED: " .. name)
return result
end

local window = check("MakeWindow", function()
return Library:MakeWindow({
Title = "DepHubV2 Smoke Test",
SubTitle = "Core, lifecycle and controls",
ScriptFolder = "DepHubV2Smoke"
})
end)

local firstTab = check("MakeTab", function()
return window:MakeTab({Title = "Primary"})
end)

local toggle = check("AddToggle and flag compatibility", function()
local option = firstTab:AddToggle({
Title = "Toggle",
Default = false,
Flag = "smoke_toggle",
Callback = function() end
})
option:SetValue(true)
assert(window:GetFlag("smoke_toggle") == 0)
option:SetValue(false)
assert(window:GetFlag("smoke_toggle") == 1)
option:SetEnabled(false)
option:SetEnabled(true)
return option
end)

local button = check("AddButton loading and enabled states", function()
local option = firstTab:AddButton({
Title = "Button",
Callback = function() end
})
option:SetLoading(true)
option:SetLoading(false)
option:SetEnabled(false)
option:SetEnabled(true)
option:SetTooltip("Smoke test tooltip")
return option
end)

local textBox = check("AddTextBox error state", function()
local option = firstTab:AddTextBox({
Title = "TextBox",
Default = "Initial",
Flag = "smoke_text",
Callback = function() end
})
option:SetError(true)
option:SetError(false)
option:SetEnabled(false)
option:SetEnabled(true)
option:SetTooltip("Text input tooltip")
return option
end)

local slider = check("AddSlider touch-safe value API", function()
local option = firstTab:AddSlider({
Title = "Slider",
Min = 0,
Max = 10,
Increment = 0.3,
Default = 1,
Flag = "smoke_slider",
Callback = function() end
})
option:SetValue(5.1)
assert(math.abs(option.Value - 5.1) < 0.000001)
option:SetEnabled(false)
option:SetEnabled(true)
return option
end)

local dropdown = check("AddDropdown and SetEnabled", function()
local option = firstTab:AddDropdown({
Title = "Dropdown",
Options = {"Alpha", "Beta", "Gamma"},
Default = "Alpha",
Flag = "smoke_dropdown",
Callback = function() end
})
option:SetEnabled(false)
option:SetEnabled(true)
option:SetEnabled({Alpha = false})
option:SetEnabled({Alpha = true})
option:Clear()
option:Add("Alpha", "Beta", "Gamma")
option:NewOptions("One", "Two")
return option
end)

local keybind = check("AddKeybind and SetKeyCode", function()
local option = firstTab:AddKeybind({
Title = "Keybind",
KeyCode = Enum.KeyCode.G,
Flag = "smoke_keybind",
Callback = function() end
})
option:SetKeyCode(Enum.KeyCode.H)
option:SetEnabled(false)
option:SetEnabled(true)
return option
end)

local colorPicker = check("AddColorPicker and flag storage", function()
local option = firstTab:AddColorPicker({
Title = "Color",
Default = Color3.fromRGB(120, 80, 220),
Flag = "smoke_color",
Callback = function() end
})
option:SetColor(Color3.fromRGB(20, 160, 120))
assert(type(window:GetFlag("smoke_color")) == "string")
option:SetEnabled(false)
option:SetEnabled(true)
return option
end)

local progress = check("AddProgressBar", function()
local option = firstTab:AddProgressBar({
Title = "Progress",
Description = "Progress bar smoke test"
})
option:SetValue(55)
option:SetValue(100)
return option
end)

check("AddLabel and AddDivider", function()
firstTab:AddLabel("Smoke label")
firstTab:AddDivider()
firstTab:AddParagraph("Paragraph", "Paragraph should not react like a button")
firstTab:AddSection("Section")
end)

check("SetTheme and SetAccent", function()
Library:SetTheme("Light")
Library:SetAccent(Color3.fromRGB(120, 90, 240))
Library:SetTheme("Darker")
Library:SetTheme("Light")
Library:SetTheme("Darker")
end)

check("ReadFile, WriteFile and delete", function()
assert(window:WriteFile("smoke.txt", "DepHubV2"))
assert(window:ReadFile("smoke.txt") == "DepHubV2")
assert(window:WriteFile("smoke.txt", nil))
end)

check("Notify with invalid icon", function()
window:Notify({
Title = "Invalid icon test",
Content = "This notification must still render and close.",
Icon = "__unknown_icon__",
Duration = 0.5
})
end)

check("Dialog lifecycle", function()
local dialog = window:Dialog({
Title = "Smoke dialog",
Content = "Dialog should fade in and out.",
Options = {
{Title = "Close", Callback = function() end}
}
})
assert(dialog)
dialog:Close()
end)

check("Tab destroy and fallback selection", function()
local secondTab = window:MakeTab({Title = "Secondary"})
secondTab:Select()
secondTab:Destroy()
assert(firstTab.IS_DESTROYED ~= true)
firstTab:Select()
end)

task.wait(1)
check("Window and library cleanup", function()
window:Destroy()
Library:Destroy()
end)

print("DepHubV2 smoke test completed.")

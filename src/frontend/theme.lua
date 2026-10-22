-- DepHub frontend theme tokens (v2).
-- Kept in lockstep with the inlined Theme table in src/frontend/init.lua.
-- Loaded as a plain chunk (no require), so this file returns a table.

local function rgb(r, g, b) return {r = r, g = g, b = b} end

local Theme = {}

Theme.Bg           = rgb(21, 21, 21)
Theme.Panel        = rgb(24, 24, 24)
Theme.Sidebar      = rgb(19, 19, 19)
Theme.Header       = rgb(24, 24, 24)
Theme.Border       = rgb(43, 43, 43)
Theme.BorderSoft   = rgb(34, 34, 34)
Theme.TextBright   = rgb(239, 239, 239)
Theme.Text         = rgb(206, 206, 206)
Theme.TextDim      = rgb(128, 128, 128)
Theme.TextQuiet    = rgb(110, 110, 110)
Theme.Accent       = rgb(221, 221, 221)
Theme.AccentInk    = rgb(24, 24, 24)
Theme.NavActive    = rgb(30, 30, 30)
Theme.NavHover     = rgb(26, 26, 26)
Theme.Field        = rgb(17, 17, 17)
Theme.FieldBorder  = rgb(51, 51, 51)
Theme.FieldFocus   = rgb(119, 119, 119)
Theme.ToggleOff    = rgb(48, 48, 48)
Theme.ToggleOn     = rgb(221, 221, 221)
Theme.ToggleKnob   = rgb(148, 148, 148)
Theme.ToggleKnobOn = rgb(24, 24, 24)
Theme.RowHover     = rgb(28, 28, 28)
Theme.Action       = rgb(29, 29, 29)
Theme.ActionHover  = rgb(39, 39, 39)
Theme.ActionBorder = rgb(58, 58, 58)
Theme.Primary      = rgb(221, 221, 221)
Theme.PrimaryHover = rgb(239, 239, 239)
Theme.PrimaryInk   = rgb(24, 24, 24)
Theme.Toast        = rgb(28, 28, 28)
Theme.ToastBorder  = rgb(60, 60, 60)
Theme.ToastError   = rgb(121, 80, 80)
Theme.ScrollBar    = rgb(58, 58, 58)

Theme.WindowW      = 620
Theme.WindowH      = 460
Theme.SidebarW     = 160
Theme.HeaderH      = 48

return Theme
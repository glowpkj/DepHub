-- DepHub UI kit
--
-- One small helper every backend uses to build its part of the shared shell in
-- the repository's standard shape:
--
--     Category (finalidade: Visual / Combat / Farm / Movement / Player /
--               World / Misc / Settings)
--       └─ Tab
--            └─ Section (Left or Right)
--                 └─ Toggle / Slider / Dropdown / Button / Input / Paragraph
--
-- Why this exists: exactly the same three-step dance (create the category, make
-- the tab inside it, then make a section with a valid column) was hand-written
-- in every backend, and the copy in some of them passed the column argument in
-- the wrong slot -- which makes Library:CreateSection error, the pcall swallow
-- it, and the whole tab render EMPTY. Centralizing it here means there is one
-- correct implementation instead of N chances to get it wrong.
--
-- The kit is purely a thin wrapper over env.__DEPHUB.UI. It never makes a GUI of
-- its own and never touches anything outside the API the shell exposes.

local env = type(getgenv) == "function" and getgenv() or _G

local Kit = {}

-- Icons for the standard categories, so every game's sidebar looks the same for
-- the same finalidade. Names are theme icon names (see the shell's GetIcon).
local CATEGORY_ICONS = {
    Visual = "eye",
    Combat = "crosshair",
    Farm = "wheat",
    Movement = "move-3d",
    Player = "user",
    World = "globe",
    Misc = "wrench",
    Settings = "settings",
}

-- Resolve the shared shell. Returns nil (never errors) when there is no UI, so
-- a backend can call the kit unconditionally and simply build nothing.
local function window()
    local ui = env.__DEPHUB and env.__DEPHUB.UI
    if type(ui) == "table" and type(ui.CreateTab) == "function" then return ui end
    return nil
end

-- Create a category once. Idempotent: a second call for the same name is a
-- no-op, so two features in the same finalidade never collide.
function Kit.Category(name, icon)
    local ui = window()
    if not ui then return false end
    if type(ui.CreateCategory) ~= "function" then return false end
    local ok = pcall(function() ui:CreateCategory(name, icon or CATEGORY_ICONS[name] or "layers") end)
    return ok
end

-- Create a tab inside a category. Category defaults to the tab's own name so a
-- single-tab game stays trivial, but the normal call passes the finalidade:
--     Kit.Tab("ESP", "Visual")
function Kit.Tab(name, category)
    local ui = window()
    if not ui then return nil end
    category = category or name
    Kit.Category(category)
    local ok, tab = pcall(function() return ui:CreateTab(name, category) end)
    if ok and tab then return tab end
    return nil
end

-- Create a section on a tab. The column MUST be "Left" or "Right" (anything else
-- makes the shell drop the section and leave the tab empty); we clamp it here so
-- a backend can never pass the wrong value.
function Kit.Section(tab, title, column)
    if not (tab and type(tab.CreateSection) == "function") then return nil end
    if column ~= "Left" and column ~= "Right" then column = "Left" end
    local ok, section = pcall(function() return tab:CreateSection(title, column) end)
    if ok then return section end
    return nil
end

-- One-call convenience: tab (in a category) + section, which is the shape almost
-- every feature uses. Returns the section (or nil).
function Kit.Panel(tabName, category, sectionTitle, column)
    local tab = Kit.Tab(tabName, category)
    if not tab then return nil end
    return Kit.Section(tab, sectionTitle or tabName, column)
end

-- The standard categories a backend may use, in the order they should appear.
-- Kept here so every game presents the same finalidades in the same order.
Kit.CATEGORIES = { "Visual", "Combat", "Farm", "Movement", "Player", "World", "Misc", "Settings" }

-- Group controls side by side on one line. Returns a row handle with the same
-- Create* builders a section has (CreateToggle / CreateSlider / ...). The row
-- shares its width across the controls added to it, so a toggle and the slider
-- that drives it sit on one line instead of two full-width rows.
function Kit.Row(section)
    if not (section and type(section.CreateRow) == "function") then return nil end
    local ok, row = pcall(function() return section:CreateRow() end)
    if ok and row then return row end
    return nil
end

-- Group controls as a named vertical stack (same stacked look, one box).
function Kit.Stack(section)
    if not (section and type(section.CreateStack) == "function") then return nil end
    local ok, stack = pcall(function() return section:CreateStack() end)
    if ok and stack then return stack end
    return nil
end

function Kit.categoryIcon(name)
    return CATEGORY_ICONS[name] or "layers"
end

return Kit

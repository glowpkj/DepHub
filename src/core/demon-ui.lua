-- Shared DepHub shell.
--
-- Every game gets the exact same interface: the same library, the same theme,
-- the same size, the same tab/section/control API. The backend of each game is
-- what fills that shell with its own tabs and controls — the shell itself never
-- knows which game it is running and never adds anything game-specific.
--
-- Stable API handed to every backend through env.__DEPHUB.UI:
--   UI:CreateCategory(name, icon)          -- only when a backend wants categories
--   UI:CreateTab(name, category)           -- returns a tab wrapper or nil
--   tab:CreateSection(title, column)       -- "Left" (default) or "Right"
--   section:CreateToggle/Slider/Dropdown/Button/Input/Paragraph(...)
--   UI:Notify(title, message, kind)
--   UI:SetCurrentSea(sea)                  -- category switching, opt-in per backend
--   UI:Destroy()

local DemonUI = {}
DemonUI.__index = DemonUI

-- Window options are shared by every game so the interface is identical
-- everywhere. Changing anything here changes it for all games at once.
local WINDOW_OPTIONS = {
    Title = "DepHub",
    Author = "DepHub",
    Theme = "Monochrome",
    TabPosition = "Side",
    CategoryAlign = "Center",
    ToggleKey = Enum.KeyCode.RightControl,
    Acrylic = true,
    AcrylicBlur = 18,
    Size = UDim2.fromOffset(900, 580),
    ThemeAutoLoad = false,
    SoundsEnabled = true,
    Tooltip = true
}

-- The one category every game has. Backends that want more (for example the
-- Blox Fruits sea categories) create them explicitly through CreateCategory.
local DEFAULT_CATEGORY = "General"

-- The theme module lives in the repository as a normal, editable source file.
-- It is not fetched from a third-party URL and not re-compiled from a blob:
-- it is loaded through the same module path everything else uses, so editing
-- src/core/ui/demon-theme.luau is editing the UI directly.
local THEME_PATHS = {
    "src/core/ui/demon-theme.luau",
    "src/core/ui/demon-theme.lua"
}

local function fetchThemeSource()
    local env = type(getgenv) == "function" and getgenv() or _G
    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)
        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)
        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)
        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)
    local base = (env.__DEPHUB and env.__DEPHUB.SourceBaseURL) or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    for _, path in ipairs(THEME_PATHS) do
        if resolver then
            local ok, source = pcall(resolver, base .. path)
            if ok and type(source) == "string" and #source > 0 then return source end
        end
        local ok, source = pcall(function() return game:HttpGet(base .. path) end)
        if ok and type(source) == "string" and #source > 0 then return source end
    end
    return nil
end

local cachedTheme = nil

local function loadTheme()
    if cachedTheme then return cachedTheme end
    local source = fetchThemeSource()
    if type(source) ~= "string" or #source == 0 then
        error("Falha ao carregar src/core/ui/demon-theme.luau: nenhuma copia disponivel")
    end
    local chunk, compileError = loadstring(source)
    if not chunk then error("Falha ao compilar demon-theme.luau: " .. tostring(compileError)) end
    local okRun, export = pcall(chunk)
    if not okRun or type(export) ~= "table" or type(export.new) ~= "function" then
        error("demon-theme.luau não retornou uma biblioteca válida: " .. tostring(export))
    end
    cachedTheme = export
    return export
end

local function normalizeSea(sea)
    local value = tostring(sea or "")
    local lower = value:lower()
    if value == "1" or lower:find("sea1") or lower:find("first") or lower == "sea 1" then return "Sea1" end
    if value == "2" or lower:find("sea2") or lower:find("second") or lower == "sea 2" then return "Sea2" end
    if value == "3" or lower:find("sea3") or lower:find("third") or lower == "sea 3" then return "Sea3" end
    return value
end

-- Resolve the category a backend asked for. Backends that pass "All" (or
-- nothing) want the shared default; backends that pass a real category name
-- (a Blox Fruits sea, for example) get exactly that.
local function resolveCategory(category)
    local value = tostring(category or "")
    if value == "" or value == "All" then return DEFAULT_CATEGORY end
    if value == "Sea1" then return "Sea 1" end
    if value == "Sea2" then return "Sea 2" end
    if value == "Sea3" then return "Sea 3" end
    if value == "Sea1,Sea2" or value == "Sea2,Sea1" then return "Sea 1/2" end
    if value == "Sea2,Sea3" or value == "Sea3,Sea2" then return "Sea 2/3" end
    return value
end

function DemonUI.new(options)
    options = options or {}
    local export = loadTheme()
    local library = export.new({
        Title = options.Name or WINDOW_OPTIONS.Title,
        Version = options.Version or "0.0.0",
        Author = WINDOW_OPTIONS.Author,
        Theme = WINDOW_OPTIONS.Theme,
        TabPosition = WINDOW_OPTIONS.TabPosition,
        CategoryAlign = WINDOW_OPTIONS.CategoryAlign,
        ToggleKey = WINDOW_OPTIONS.ToggleKey,
        Acrylic = WINDOW_OPTIONS.Acrylic,
        AcrylicBlur = WINDOW_OPTIONS.AcrylicBlur,
        Size = WINDOW_OPTIONS.Size,
        ThemeAutoLoad = WINDOW_OPTIONS.ThemeAutoLoad,
        SoundsEnabled = WINDOW_OPTIONS.SoundsEnabled,
        Tooltip = WINDOW_OPTIONS.Tooltip
    })
    local self = setmetatable({
        Library = library,
        Tabs = {},
        Categories = {},
        CurrentSea = "Sea1",
        Destroyed = false
    }, DemonUI)
    self:CreateCategory(DEFAULT_CATEGORY, "layers")
    return self
end

-- Backends call this to add a category of their own. The shell does not
-- pre-create game categories, so a game can never show another game's tabs.
function DemonUI:CreateCategory(name, icon)
    name = tostring(name or DEFAULT_CATEGORY)
    if self.Categories[name] then return true end
    local ok = pcall(function() self.Library:CreateCategory(name, icon or "layers") end)
    if ok then self.Categories[name] = true end
    return ok
end

function DemonUI:CreateTab(name, category)
    if self.Destroyed then return nil end
    name = tostring(name)
    category = resolveCategory(category)
    if not self.Categories[category] then self:CreateCategory(category) end
    local ok, result = pcall(function() self.Library:CreateTab(category, name) end)
    local state = self.Library._STATE
    local tabExists = state and state.ContentPages and state.ContentPages[name] ~= nil
    if not ok or not tabExists then
        pcall(function() self.Library:Notify("DepHub", "Falha ao criar aba " .. name .. ": " .. tostring(result), "error") end)
        return nil
    end
    local record = {Adapter = self, Name = name, Category = category, Key = category .. "|" .. name, Control = state.ContentPages[name], Sections = {}, Visible = true}
    function record:CreateSection(title, column)
        title = tostring(title or self.Name)
        if self.Sections[title] then return self.Sections[title] end
        local sectionColumn = column or "Left"
        local section = self.Adapter.Library:CreateSection(self.Name, title, nil, true, sectionColumn, "layers")
        local wrapper = {Adapter = self.Adapter, Control = section, Title = title}
        function wrapper:CreateToggle(label, initial, callback)
            return self.Adapter.Library:AddToggle(self.Control, label, initial == true, callback)
        end
        function wrapper:CreateSlider(label, minimum, maximum, initial, callback)
            return self.Adapter.Library:AddSlider(self.Control, label, tonumber(minimum) or 0, tonumber(maximum) or 100, tonumber(initial) or tonumber(minimum) or 0, 0, callback)
        end
        function wrapper:CreateDropdown(label, options, initial, callback)
            local list = {}
            for _, option in ipairs(type(options) == "table" and options or {}) do list[#list + 1] = tostring(option) end
            if #list == 0 then list = {"None"} end
            local index = 1
            for i, option in ipairs(list) do
                if tostring(option) == tostring(initial) then index = i break end
            end
            return self.Adapter.Library:AddDropdown(self.Control, label, list, index, function(_, value)
                if callback then callback(value) end
            end)
        end
        function wrapper:CreateButton(label, callback)
            return self.Adapter.Library:AddButton(self.Control, label, callback)
        end
        function wrapper:CreateInput(label, placeholder, initial, callback)
            local item = {Value = tostring(initial or "")}
            item.Control = self.Adapter.Library:AddTextbox(self.Control, label, tostring(placeholder or initial or ""), function(value)
                item.Value = tostring(value or "")
                if callback then callback(value) end
            end)
            return item
        end
        function wrapper:CreateParagraph(titleText, bodyText)
            return self.Adapter.Library:AddParagraph(self.Control, tostring(titleText or ""), tostring(bodyText or ""))
        end
        self.Sections[title] = wrapper
        return wrapper
    end
    function record:SetVisible(visible)
        self.Visible = visible == true
        self.Adapter:_refreshVisibility()
    end
    self.Tabs[record.Key] = record
    return record
end

-- Category switch used by backends that group tabs by a value (Blox Fruits
-- seas). Categories not managed by the backend are left untouched.
function DemonUI:_refreshVisibility()
    if self.Destroyed then return end
    local state = self.Library._STATE
    if type(state) ~= "table" then return end
    local sea = normalizeSea(self.CurrentSea)
    for category, data in pairs(state.CategoryButtons or {}) do
        local visible = category == DEFAULT_CATEGORY
        if category == "Sea 1" then visible = sea == "Sea1" end
        if category == "Sea 2" then visible = sea == "Sea2" end
        if category == "Sea 3" then visible = sea == "Sea3" end
        if category == "Sea 1/2" then visible = sea == "Sea1" or sea == "Sea2" end
        if category == "Sea 2/3" then visible = sea == "Sea2" or sea == "Sea3" end
        local button = data.button or data
        if button and button:IsA("GuiObject") then button.Visible = visible end
        if data.group and data.group:IsA("GuiObject") then data.group.Visible = visible end
        if data.tabList and data.tabList:IsA("GuiObject") then data.tabList.Visible = visible end
        if data.button and data.button.Parent and data.button.Parent:IsA("GuiObject") then
            data.button.Parent.Visible = visible
        end
    end
    for _, tab in pairs(self.Tabs) do
        if not tab.Visible then
            local page = state.ContentPages and state.ContentPages[tab.Name]
            if page then page.Visible = false end
        end
    end
    local activeCategory = state.ActiveCategory
    local activeTab = state.ActiveTab
    local activeData = activeTab and (self.Tabs[tostring(activeCategory or DEFAULT_CATEGORY) .. "|" .. activeTab] or self.Tabs[activeTab])
    if activeData and not activeData.Visible then
        pcall(function() self.Library:SetActiveCategory(DEFAULT_CATEGORY, "Home") end)
    elseif activeCategory and activeCategory ~= DEFAULT_CATEGORY then
        local catData = state.CategoryButtons and state.CategoryButtons[activeCategory]
        if catData and catData.button and not catData.button.Visible then
            pcall(function() self.Library:SetActiveCategory(DEFAULT_CATEGORY, "Info") end)
        end
    end
end

function DemonUI:SetCurrentSea(sea)
    self.CurrentSea = normalizeSea(sea)
    self:_refreshVisibility()
end

function DemonUI:Notify(title, message, kind)
    if self.Library and not self.Destroyed then
        return self.Library:Notify(tostring(title or "DepHub"), tostring(message or ""), kind or "info")
    end
end

function DemonUI:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Library then pcall(function() self.Library:Destroy() end) end
    table.clear(self.Tabs)
    table.clear(self.Categories)
end

return DemonUI

local DemonUI = {}
DemonUI.__index = DemonUI

local LIBRARY_URL = "https://raw.githubusercontent.com/rapzxcwxcorparation/DemonOfDarknessUI/refs/heads/main/DOD.luau"

local function loadLibrary()
    local ok, source = pcall(function() return game:HttpGet(LIBRARY_URL) end)
    if not ok or type(source) ~= "string" or #source == 0 then
        error("Falha ao baixar DemonOfDarknessUI: " .. tostring(source))
    end
    local chunk, compileError = loadstring(source)
    if not chunk then error("Falha ao compilar DemonOfDarknessUI: " .. tostring(compileError)) end
    local okRun, export = pcall(chunk)
    if not okRun or type(export) ~= "table" or type(export.new) ~= "function" then
        error("DemonOfDarknessUI não retornou uma biblioteca válida: " .. tostring(export))
    end
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

local function categoryFor(sea)
    if not sea or sea == "" or sea == "All" then return "General" end
    if sea == "Sea1" then return "Sea 1" end
    if sea == "Sea2" then return "Sea 2" end
    if sea == "Sea3" then return "Sea 3" end
    if sea == "Sea1,Sea2" or sea == "Sea2,Sea1" then return "Sea 1/2" end
    if sea == "Sea2,Sea3" or sea == "Sea3,Sea2" then return "Sea 2/3" end
    return "General"
end

function DemonUI.new(options)
    options = options or {}
    local export = loadLibrary()
    local library = export.new({
        Title = options.Name or "DepHub",
        Version = options.Version or "0.0.54",
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
    })
    local self = setmetatable({
        Library = library,
        Tabs = {},
        Categories = {},
        CurrentSea = "Sea1",
        Destroyed = false
    }, DemonUI)
    for _, category in ipairs({"General", "Sea 1", "Sea 2", "Sea 3", "Sea 1/2", "Sea 2/3"}) do
        library:CreateCategory(category, "layers")
        self.Categories[category] = true
    end
    return self
end

function DemonUI:CreateTab(name, sea)
    if self.Destroyed then return nil end
    name = tostring(name)
    local category = categoryFor(sea)
    local ok, tab = pcall(function() return self.Library:CreateTab(category, name) end)
    if not ok or not tab then
        self.Library:Notify("DepHub", "Falha ao criar aba " .. name .. ": " .. tostring(tab), "error")
        return nil
    end
    local record = {Adapter = self, Name = name, Category = category, Key = category .. "|" .. name, Control = tab, Sections = {}, Visible = true}
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

function DemonUI:_refreshVisibility()
    if self.Destroyed then return end
    local sea = normalizeSea(self.CurrentSea)
    for category, data in pairs(self.Library._STATE.CategoryButtons or {}) do
        local visible = category == "General"
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
            local page = self.Library._STATE.ContentPages and self.Library._STATE.ContentPages[tab.Name]
            if page then page.Visible = false end
        end
    end
    local activeCategory = self.Library._STATE.ActiveCategory
    local activeTab = self.Library._STATE.ActiveTab
    local activeData = activeTab and (self.Tabs[tostring(activeCategory or "General") .. "|" .. activeTab] or self.Tabs[activeTab])
    if activeData and not activeData.Visible then
        pcall(function() self.Library:SetActiveCategory("General", "Home") end)
    elseif activeCategory and activeCategory ~= "General" then
        local catData = self.Library._STATE.CategoryButtons and self.Library._STATE.CategoryButtons[activeCategory]
        if catData and catData.button and not catData.button.Visible then
            pcall(function() self.Library:SetActiveCategory("General", "Info") end)
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

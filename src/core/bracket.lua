local BracketAdapter = {}
BracketAdapter.__index = BracketAdapter

local BRACKET_URL = "https://raw.githubusercontent.com/AlexR32/Bracket/main/BracketV34.lua"

local function loadSource()
    local requestFunctions = {}
    if type(request) == "function" then requestFunctions[#requestFunctions + 1] = request end
    if type(http_request) == "function" then requestFunctions[#requestFunctions + 1] = http_request end
    if type(syn) == "table" and type(syn.request) == "function" then requestFunctions[#requestFunctions + 1] = syn.request end
    local lastError = "Sem resposta HTTP"
    for _, requestFunction in ipairs(requestFunctions) do
        local ok, response = pcall(requestFunction, {Url = BRACKET_URL, Method = "GET"})
        if ok and type(response) == "table" then
            local body = response.Body or response.body
            local status = tonumber(response.StatusCode or response.Status or 200) or 200
            if status >= 200 and status < 400 and type(body) == "string" and #body > 0 then return body end
            lastError = "HTTP " .. tostring(status)
        elseif not ok then
            lastError = tostring(response)
        end
    end
    local ok, body = pcall(function() return game:HttpGet(BRACKET_URL) end)
    if ok and type(body) == "string" and #body > 0 then return body end
    error("Falha ao baixar Bracket: " .. tostring(ok and lastError or body))
end

local function call(target, method, ...)
    if type(target) ~= "table" or type(target[method]) ~= "function" then return false, nil end
    local ok, result = pcall(target[method], target, ...)
    return ok, result
end

local Item = {}
Item.__index = Item

function Item:Set(value)
    self.Value = value
    local control = self.Control
    if type(control) ~= "table" then return end
    if type(control.SetValue) == "function" then
        pcall(control.SetValue, control, value)
    elseif type(control.UpdateColor) == "function" then
        pcall(control.UpdateColor, control, value)
    elseif type(control.SetText) == "function" then
        pcall(control.SetText, control, tostring(value))
    end
end

function Item:SetText(value)
    self.Value = value
    local control = self.Control
    if type(control) ~= "table" then return end
    if type(control.SetText) == "function" then
        pcall(control.SetText, control, tostring(value))
    elseif type(control.SetValue) == "function" then
        pcall(control.SetValue, control, tostring(value))
    end
end

function Item:SetAvailableState(value)
    self.Available = value == true
end

local Section = {}
Section.__index = Section

local function createSectionControl(section, method, config)
    local internal = section and section.Internal
    local fn = type(internal) == "table" and internal[method]
    if type(fn) ~= "function" then return nil end
    local ok, control = pcall(fn, section, config)
    if ok then return control end
    return nil
end

function Section:CreateToggle(title, initial, callback)
    local control = createSectionControl(self.Control, "Toggle", {Name = tostring(title), Value = initial == true, Callback = callback})
    return setmetatable({Control = control, Value = initial == true}, Item)
end

function Section:CreateCheckbox(title, initial, callback)
    return self:CreateToggle(title, initial, callback)
end

function Section:CreateSlider(title, minimum, maximum, initial, callback)
    local control = createSectionControl(self.Control, "Slider", {
        Name = tostring(title),
        Min = tonumber(minimum) or 0,
        Max = tonumber(maximum) or 100,
        Value = tonumber(initial) or tonumber(minimum) or 0,
        Precise = 0,
        Callback = callback
    })
    return setmetatable({Control = control, Value = initial}, Item)
end

function Section:CreateDropdown(title, options, initial, callback)
    local list = {}
    for _, option in ipairs(type(options) == "table" and options or {}) do
        local optionName = tostring(option)
        list[#list + 1] = {
            Name = optionName,
            Mode = "Button",
            Value = optionName == initial,
            Callback = function()
                if callback then callback(optionName) end
            end
        }
    end
    local control = createSectionControl(self.Control, "Dropdown", {Name = tostring(title), List = list})
    local item = setmetatable({Control = control, Value = initial}, Item)
    if initial ~= nil and type(control) == "table" and type(control.SetValue) == "function" then
        pcall(control.SetValue, control, {initial})
    end
    return item
end

function Section:CreateInput(title, placeholder, initial, callback)
    local item
    local control = createSectionControl(self.Control, "Textbox", {
        Name = tostring(title),
        Value = tostring(initial or ""),
        Placeholder = tostring(placeholder or ""),
        NumbersOnly = false,
        Callback = function(value)
            if item then item.Value = tostring(value or "") end
            if callback then callback(value) end
        end
    })
    item = setmetatable({Control = control, Value = tostring(initial or "")}, Item)
    return item
end

function Section:CreateButton(title, callback)
    local control = createSectionControl(self.Control, "Button", {Name = tostring(title), Callback = callback})
    return setmetatable({Control = control}, Item)
end

function Section:CreateColorPicker(title, initial, callback)
    local defaultColor = typeof(initial) == "Color3" and initial or Color3.fromRGB(255, 255, 255)
    local control = createSectionControl(self.Control, "Colorpicker", {
        Name = tostring(title),
        Value = {0, 0, 1, 0, false},
        Callback = function(_, color)
            if callback then callback(color or defaultColor) end
        end
    })
    if type(control) == "table" and type(control.SetValue) == "function" then
        pcall(control.SetValue, control, {0, 0, 1, 0, false})
    end
    return setmetatable({Control = control, Value = defaultColor}, Item)
end

function Section:CreateParagraph(title, description)
    local text = tostring(title or "")
    if description and tostring(description) ~= "" then text = text .. "\n" .. tostring(description) end
    local control = createSectionControl(self.Control, "Label", {Text = text})
    return setmetatable({Control = control, Value = text}, Item)
end

function Section:CreateLabel(value)
    return self:CreateParagraph(value, "")
end

local Tab = {}
Tab.__index = Tab

function Tab:CreateSection(title)
    local ok, control = call(self.Control, "Section", {Name = tostring(title), Side = "Left"})
    if not ok or type(control) ~= "table" then control = self.Control end
    return setmetatable({Control = control, Title = tostring(title)}, Section)
end

function Tab:SetVisible(value)
    value = value == true
    local wasSelected = self.Control and self.Control.Asset and self.Control.Asset.Visible == true
    self.Visible = value
    if self.Control and self.Control.Asset then self.Control.Asset.Visible = value end
    if self.Control and self.Control.ButtonAsset then self.Control.ButtonAsset.Visible = value end
    if wasSelected and not value and self.Adapter then
        for _, tab in ipairs(self.Adapter.Tabs) do
            if tab.Visible and tab.Control and tab.Control.Asset and tab.Control.ButtonAsset then
                pcall(function()
                    self.Adapter.Bracket.Utilities.ChooseTab(tab.Control.ButtonAsset, tab.Control.Asset)
                end)
                break
            end
        end
    end
end

function BracketAdapter.new(config)
    config = config or {}
    if type(loadstring) ~= "function" then error("Bracket requer loadstring neste ambiente") end
    local chunk, compileError = loadstring(loadSource())
    if type(chunk) ~= "function" then error("Falha ao compilar Bracket: " .. tostring(compileError)) end
    local Bracket = chunk()
    if type(Bracket) ~= "table" or type(Bracket.Window) ~= "function" then error("Bracket nao retornou uma biblioteca valida") end
    local rawWindow = Bracket:Window({
        Name = config.Name or "DepHub",
        Enabled = true,
        Color = Color3.fromRGB(130, 90, 220),
        Size = UDim2.fromOffset(820, 540),
        Position = UDim2.new(0.5, -410, 0.5, -270)
    })
    local self = setmetatable({
        Name = config.Name or "DepHub",
        Bracket = Bracket,
        RawWindow = rawWindow,
        Tabs = {},
        Flags = {},
        Destroyed = false,
        Visible = true
    }, BracketAdapter)
    local inputService = game:GetService("UserInputService")
    self.InputConnection = inputService.InputBegan:Connect(function(input, processed)
        if processed or self.Destroyed then return end
        if input.KeyCode == (config.ToggleKeyCode or Enum.KeyCode.LeftControl) then
            self:SetVisible(not self.Visible)
        end
    end)
    return self
end

function BracketAdapter:CreateTab(name)
    local ok, control = call(self.RawWindow, "Tab", {Name = tostring(name)})
    if not ok or type(control) ~= "table" then error("Bracket nao conseguiu criar a aba " .. tostring(name)) end
    local tab = setmetatable({Control = control, Title = tostring(name), Visible = true, Adapter = self}, Tab)
    self.Tabs[#self.Tabs + 1] = tab
    return tab
end

function BracketAdapter:Notify(title, message, duration)
    local ok = false
    if self.Bracket and type(self.Bracket.Push) == "function" then
        ok = pcall(self.Bracket.Push, self.Bracket, {
            Title = tostring(title or "DepHub"),
            Description = tostring(message or ""),
            Duration = tonumber(duration) or 3
        })
    end
    if not ok then pcall(print, "[DepHub] " .. tostring(title or "DepHub") .. ": " .. tostring(message or "")) end
end

function BracketAdapter:SetVisible(value)
    if self.Destroyed then return end
    self.Visible = value == true
    if type(self.RawWindow) == "table" then self.RawWindow.Enabled = self.Visible end
end

function BracketAdapter:IsVisible()
    return self.Visible
end

function BracketAdapter:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.InputConnection then pcall(function() self.InputConnection:Disconnect() end) end
    if type(self.RawWindow) == "table" then
        self.RawWindow.Enabled = false
        local screen = self.Bracket and self.Bracket.Screen
        if screen then pcall(function() screen:Destroy() end) end
    end
end

return BracketAdapter

local WindUIAdapter = {}
WindUIAdapter.__index = WindUIAdapter

local WINDUI_URL = "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"

local function safeCall(target, method, ...)
    if type(target) ~= "table" or type(target[method]) ~= "function" then
        return false, nil
    end
    local ok, result = pcall(target[method], target, ...)
    return ok, result
end

local function makeElement(parent, method, config)
    if type(parent) ~= "table" or type(parent[method]) ~= "function" then
        return nil
    end
    local ok, result = pcall(parent[method], parent, config)
    if ok then
        return result
    end
    return nil
end

local Item = {}
Item.__index = Item

function Item:Set(value)
    self.Value = value
    local control = self.Control
    if type(control) ~= "table" then
        return
    end
    if type(control.Set) == "function" then
        pcall(control.Set, control, value)
    elseif type(control.SetValue) == "function" then
        pcall(control.SetValue, control, value)
    end
end

function Item:SetText(value)
    self.Value = value
    local control = self.Control
    if type(control) ~= "table" then
        return
    end
    if type(control.SetDesc) == "function" then
        pcall(control.SetDesc, control, tostring(value))
    elseif type(control.SetDescription) == "function" then
        pcall(control.SetDescription, control, tostring(value))
    elseif type(control.SetTitle) == "function" then
        pcall(control.SetTitle, control, tostring(value))
    end
end

function Item:SetAvailableState(value)
    local control = self.Control
    if type(control) == "table" and type(control.SetLocked) == "function" then
        pcall(control.SetLocked, control, not value)
    end
end

local Section = {}
Section.__index = Section

function Section:CreateToggle(title, initial, callback)
    local control = makeElement(self.Control, "Toggle", {
        Title = tostring(title),
        Value = initial == true,
        Callback = callback
    })
    return setmetatable({Control = control, Value = initial == true}, Item)
end

function Section:CreateCheckbox(title, initial, callback)
    return self:CreateToggle(title, initial, callback)
end

function Section:CreateSlider(title, minimum, maximum, initial, callback)
    local control = makeElement(self.Control, "Slider", {
        Title = tostring(title),
        Step = 1,
        Value = {
            Min = tonumber(minimum) or 0,
            Max = tonumber(maximum) or 100,
            Default = tonumber(initial) or tonumber(minimum) or 0
        },
        Callback = callback
    })
    return setmetatable({Control = control, Value = initial}, Item)
end

function Section:CreateDropdown(title, options, initial, callback)
    local values = {}
    for _, option in ipairs(type(options) == "table" and options or {}) do
        values[#values + 1] = tostring(option)
    end
    local selected = initial
    if type(selected) == "number" then
        selected = values[selected]
    end
    local control = makeElement(self.Control, "Dropdown", {
        Title = tostring(title),
        Values = values,
        Value = selected,
        AllowNone = true,
        Callback = function(value)
            if type(value) == "table" then
                value = value.Title or value.Value or value[1]
            end
            if callback then callback(value) end
        end
    })
    return setmetatable({Control = control, Value = selected}, Item)
end

function Section:CreateInput(title, placeholder, initial, callback)
    local control = makeElement(self.Control, "Input", {
        Title = tostring(title),
        Placeholder = tostring(placeholder or ""),
        Value = tostring(initial or ""),
        Callback = callback
    })
    return setmetatable({Control = control, Value = initial}, Item)
end

function Section:CreateButton(title, callback)
    local control = makeElement(self.Control, "Button", {
        Title = tostring(title),
        Callback = callback
    })
    return setmetatable({Control = control}, Item)
end

function Section:CreateColorPicker(title, initial, callback)
    local control = makeElement(self.Control, "Colorpicker", {
        Title = tostring(title),
        Default = initial,
        Callback = callback
    })
    return setmetatable({Control = control, Value = initial}, Item)
end

function Section:CreateParagraph(title, description)
    local control = makeElement(self.Control, "Paragraph", {
        Title = tostring(title or ""),
        Desc = tostring(description or "")
    })
    if not control then
        control = makeElement(self.Control, "Section", {
            Title = tostring(title or ""),
            TextSize = 14
        })
    end
    return setmetatable({Control = control, Value = description or title}, Item)
end

function Section:CreateLabel(value)
    return self:CreateParagraph(tostring(value), "")
end

local Tab = {}
Tab.__index = Tab

function Tab:CreateSection(title)
    local control = makeElement(self.Control, "Section", {
        Title = tostring(title),
        Box = true,
        BoxBorder = true,
        Opened = true
    })
    return setmetatable({Control = control or self.Control, Title = title}, Section)
end

function Tab:SetVisible(value)
    self.Visible = value == true
    local control = self.Control
    if type(control) ~= "table" then return end
    if type(control.SetVisible) == "function" then
        pcall(control.SetVisible, control, self.Visible)
    elseif type(control.Page) == "Instance" then
        pcall(function()
            control.Page.Visible = self.Visible
            if control.NavButton then control.NavButton.Visible = self.Visible end
            if control.TabButton then control.TabButton.Visible = self.Visible end
        end)
    end
end

local function fetchWindUISource()
    local requestFunctions = {}
    if type(request) == "function" then requestFunctions[#requestFunctions + 1] = request end
    if type(http_request) == "function" then requestFunctions[#requestFunctions + 1] = http_request end
    if type(syn) == "table" and type(syn.request) == "function" then requestFunctions[#requestFunctions + 1] = syn.request end
    local lastError = "Sem resposta HTTP"
    for _, requestFunction in ipairs(requestFunctions) do
        local ok, response = pcall(requestFunction, {Url = WINDUI_URL, Method = "GET"})
        if ok and type(response) == "table" then
            local body = response.Body or response.body
            local status = tonumber(response.StatusCode or response.status_code or 200) or 200
            if status >= 200 and status < 400 and type(body) == "string" and #body > 0 then
                return body
            end
            lastError = "HTTP " .. tostring(status)
        elseif not ok then
            lastError = tostring(response)
        end
    end
    local ok, source = pcall(function() return game:HttpGet(WINDUI_URL) end)
    if ok and type(source) == "string" and #source > 0 then
        return source
    end
    error("Falha ao baixar WindUI: " .. tostring(ok and lastError or source))
end

function WindUIAdapter.new(config)
    config = config or {}
    local loader = loadstring
    if type(loader) ~= "function" then
        error("WindUI requer loadstring neste ambiente")
    end
    local source = fetchWindUISource()
    local chunk, compileError = loader(source)
    if type(chunk) ~= "function" then
        error("Falha ao compilar WindUI: " .. tostring(compileError))
    end
    local WindUI = chunk()
    if type(WindUI) ~= "table" or type(WindUI.CreateWindow) ~= "function" then
        error("WindUI nao retornou uma biblioteca valida")
    end

    local rawWindow = WindUI:CreateWindow({
        Title = config.Name or "DepHub",
        Author = "DepHub",
        Folder = "DepHub",
        Icon = "solar:planet-bold-duotone",
        NewElements = true,
        HideSearchBar = false,
        OpenButton = {
            Title = "Abrir DepHub",
            Enabled = true,
            Draggable = true,
            OnlyMobile = false,
            Scale = 0.65
        },
        Topbar = {
            Height = 44,
            ButtonsType = "Default"
        }
    })

    local self = setmetatable({
        Name = config.Name or "DepHub",
        WindUI = WindUI,
        RawWindow = rawWindow,
        Tabs = {},
        Flags = {},
        Destroyed = false,
        Visible = true
    }, WindUIAdapter)

    local key = config.ToggleKeyCode or Enum.KeyCode.LeftControl
    if type(rawWindow.SetToggleKey) == "function" then
        pcall(rawWindow.SetToggleKey, rawWindow, key)
    end

    return self
end

function WindUIAdapter:CreateTab(name)
    local control = makeElement(self.RawWindow, "Tab", {
        Title = tostring(name),
        Icon = "solar:widget-5-bold-duotone",
        Border = true
    })
    local tab = setmetatable({
        Control = control,
        Title = tostring(name),
        Visible = true
    }, Tab)
    self.Tabs[#self.Tabs + 1] = tab
    return tab
end

function WindUIAdapter:Notify(title, message, duration)
    if self.WindUI and type(self.WindUI.Notify) == "function" then
        pcall(self.WindUI.Notify, self.WindUI, {
            Title = tostring(title or "DepHub"),
            Content = tostring(message or ""),
            Duration = tonumber(duration) or 3
        })
    end
end

function WindUIAdapter:SetVisible(value)
    if self.Destroyed then return end
    value = value == true
    if self.Visible == value then return end
    self.Visible = value
    local raw = self.RawWindow
    local method = value and "Open" or "Close"
    if type(raw) == "table" and type(raw[method]) == "function" then
        pcall(raw[method], raw)
    elseif type(raw) == "table" and type(raw.SetVisible) == "function" then
        pcall(raw.SetVisible, raw, value)
    elseif type(raw) == "table" and type(raw.Toggle) == "function" then
        pcall(raw.Toggle, raw)
    end
end

function WindUIAdapter:IsVisible()
    return self.Visible
end

function WindUIAdapter:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    safeCall(self.RawWindow, "Destroy")
end

return WindUIAdapter

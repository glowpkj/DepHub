-- Headless UI for the vendored Blox Fruits modules.
--
-- The open-source script builds its own window through this module. DepHub does
-- not ship that window: the frontend here renders nothing and instead records
-- every control (toggle, slider, dropdown, textbox) so the DepHub panel or a
-- future library can drive the same state through the backend contract.
--
-- The API surface mirrors the original ui.lua exactly (build/addTab/page/
-- section/button/toggle/slider/dropdown/stat/textbox/output/notify/stop), so
-- the feature modules run unchanged.

local UI = {}

UI.tabs = {}
UI._controls = {}
UI._defs = {}
UI._current = nil
UI._currentSea = "Sea1"
UI._seaHooks = {}
UI._searchQ = ""
UI._core = nil
UI.gui = nil
UI.notifications = {}
UI.lastNotification = nil
UI.stats = {}

local function keyFor(page, title)
    local name = page and page.Name or "?"
    return tostring(name) .. " / " .. tostring(title)
end

local function register(page, title, api, kind, extra)
    local key = keyFor(page, title)
    if UI._controls[key] then
        local suffix = 2
        while UI._controls[key .. " #" .. suffix] do suffix += 1 end
        key = key .. " #" .. suffix
    end
    local definition = {
        key = key,
        page = page and page.Name or "?",
        sea = page and page.sea or nil,
        title = tostring(title),
        kind = kind,
        get = api.Get,
        set = api.Set
    }
    for name, value in pairs(extra or {}) do definition[name] = value end
    UI._controls[key] = definition
    UI._defs[#UI._defs + 1] = definition
    if page then page.controls[#page.controls + 1] = definition end
    return definition
end

local function newPage(name, sea)
    local page = {Name = tostring(name), sea = sea, controls = {}}
    UI.tabs[page.Name] = page
    return page
end

function UI.build(Core)
    UI._core = Core
    UI.tabs, UI._controls, UI._defs, UI.stats = {}, {}, {}, {}
    UI._current, UI._currentSea = nil, "Sea1"
    return UI
end

function UI.addTab(name, desc, sea)
    local page = UI.tabs[name] or newPage(name, sea)
    page.desc, page.sea = desc, sea or page.sea
    if not UI._current then UI._current = page.Name end
    return page
end

function UI.page(name)
    return UI.tabs[name]
end

function UI.select(name)
    if UI.tabs[name] then UI._current = name end
end

function UI.refreshTabs() end

function UI.onSea(fn)
    UI._seaHooks[#UI._seaHooks + 1] = fn
    pcall(fn, UI._currentSea)
end

local function normalizeSea(sea)
    local value = tostring(sea or "")
    local lower = value:lower()
    if value == "1" or lower:find("sea1") or lower:find("first") or lower == "sea 1" then return "Sea1" end
    if value == "2" or lower:find("sea2") or lower:find("second") or lower == "sea 2" then return "Sea2" end
    if value == "3" or lower:find("sea3") or lower:find("third") or lower == "sea 3" then return "Sea3" end
    return value
end

function UI.setSea(sea)
    sea = normalizeSea(sea)
    if sea ~= "" and sea ~= UI._currentSea then
        UI._currentSea = sea
        for _, fn in ipairs(UI._seaHooks) do pcall(fn, sea) end
    end
end

-- The feature modules treat the section/label pair as real instances (they call
-- FindFirstChildWhichIsA("TextLabel") and then write .Text to show status). Give
-- them a stand-in label so those status paths run instead of blowing up.
local function labelStub(text)
    return {ClassName = "TextLabel", Text = text or "", Visible = true}
end

function UI.section(page, title)
    local holder = {Name = tostring(title), Parent = page, _label = labelStub(tostring(title))}
    function holder:FindFirstChildWhichIsA(class)
        if class == "TextLabel" then return self._label end
        return nil
    end
    function holder:FindFirstChild() return nil end
    return holder
end

function UI.button(page, title, desc, callback)
    local button = {Name = tostring(title), Activated = {Connect = function() end}}
    function button:FindFirstChildWhichIsA() return nil end
    local api = {}
    function api.Get() return false end
    function api.Set(value)
        if value == true and callback then callback() end
    end
    register(page, title, api, "button", {default = false, description = desc})
    return button
end

function UI.toggle(page, title, desc, default, callback)
    local state = default == true
    local api = {}
    function api.Get()
        return state
    end
    function api.Set(value)
        state = value == true
        if callback then callback(state) end
    end
    register(page, title, api, "toggle", {default = default == true})
    if state then api.Set(true) end
    return api
end

function UI.slider(page, title, desc, minimum, maximum, default, callback)
    local min, max = tonumber(minimum) or 0, tonumber(maximum) or 100
    -- Only round to whole numbers when the slider itself is whole-numbered. A
    -- fractional range (e.g. an attack interval of 0.05..2s) must keep its
    -- precision, otherwise every value rounds to an integer and the control can
    -- never express the low end of its own range.
    local integral = (min == math.floor(min)) and (max == math.floor(max))
    local value = math.clamp(tonumber(default) or min, min, max)
    local api = {}
    function api.Get()
        return value
    end
    function api.Set(nextValue)
        local next = tonumber(nextValue) or value
        if integral then next = math.floor(next + 0.5) end
        value = math.clamp(next, min, max)
        if callback then callback(value) end
    end
    register(page, title, api, "slider", {min = min, max = max, default = value})
    api.Set(value)
    return api
end

function UI.dropdown(page, title, desc, options, callback)
    options = type(options) == "table" and options or {}
    local current = options[1]
    local api = {}
    function api.Get()
        return current
    end
    function api.Set(option)
        current = option
        if callback then callback(option) end
    end
    register(page, title, api, "dropdown", {options = options, default = current})
    return api
end

function UI.stat(page, label)
    local stat = {Name = tostring(label), ClassName = "TextLabel", _text = ""}
    setmetatable(stat, {
        __index = function(self, key)
            if key == "Text" then return rawget(self, "_text") end
        end,
        __newindex = function(self, key, value)
            if key == "Text" then
                rawset(self, "_text", tostring(value or ""))
                UI.stats[tostring(label)] = tostring(value or "")
            else
                rawset(self, key, value)
            end
        end
    })
    function stat:FindFirstChildWhichIsA(class) return class == "TextLabel" and self or nil end
    UI.stats[tostring(label)] = stat.Text
    return stat
end

function UI.textbox(page, placeholder, callback)
    local box = {Text = "", PlaceholderText = placeholder or ""}
    register(page, placeholder or "textbox", {
        Get = function() return box.Text end,
        Set = function(value)
            box.Text = tostring(value or "")
            if callback then callback(box.Text) end
        end
    }, "textbox", {default = ""})
    return box
end

function UI.output(page)
    return {Text = ""}
end

function UI.notify(text, duration)
    UI.lastNotification = tostring(text)
    UI.notifications[#UI.notifications + 1] = UI.lastNotification
    return nil
end

function UI.stop()
    UI.tabs, UI._controls, UI._defs = {}, {}, {}
    UI._current = nil
end

return UI

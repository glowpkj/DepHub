-- Shared DepHub shell, backed by the vendored RedzLib (src/dephubv2lib.lua).
--
-- Every game gets the exact same interface: the same library, the same size, the
-- same tab/section/control API. The backend of each game fills that shell with
-- its own tabs and controls -- the shell itself never knows which game it is
-- running and never adds anything game-specific.
--
-- RedzLib's own API is lower level than what the backends were written against:
--   * it has no "category" concept (DepHub groups tabs by purpose),
--   * `Tab:AddSection(title)` takes a bare string and is only a visual header --
--     controls are always appended to the TAB, not to the section,
--   * there is no row/stack container, no `Toggle()` and no dashboard builder.
--
-- This module is the adapter: it loads RedzLib and presents the stable DepHub
-- contract the backends, ui-kit, diagnostics and the loader already use, mapping
-- each call onto the RedzLib call that produces the same result.
--
-- Stable API handed to every backend through env.__DEPHUB.UI:
--   UI:CreateCategory(name, icon)          -- groups tabs by purpose
--   UI:CreateTab(name, category)           -- returns a tab wrapper or nil
--   tab:CreateSection(title, column)       -- "Left" (default) or "Right"
--   section:CreateToggle/Slider/Dropdown/Button/Input/Paragraph(...)
--   section:CreateRow() / section:CreateStack()   -- grouping handles
--   UI:Notify(title, message, kind)
--   UI:SetCurrentSea(sea)                  -- kept for compatibility; no-op filter
--   UI:Destroy()

local DemonUI = {}
DemonUI.__index = DemonUI

-- Window options shared by every game so the interface is identical everywhere.
-- Changing anything here changes it for all games at once.
local WINDOW_OPTIONS = {
    Title = "DepHub",
    SubTitle = "DepHub",
    Size = UDim2.fromOffset(900, 580)
}

-- The one category every game has. Backends that want more (the Blox Fruits
-- purpose groups) create them explicitly through CreateCategory.
local DEFAULT_CATEGORY = "General"

-- RedzLib lives in the repository as a normal, editable source file. It is not
-- fetched from a third-party URL: it is loaded through the same module path
-- everything else uses, so editing src/dephubv2lib.lua is editing the UI.
local LIBRARY_PATHS = {
    "src/dephubv2lib.lua",
    "dephubv2lib.lua"
}

local function fetchLibrarySource()
    local env = type(getgenv) == "function" and getgenv() or _G
    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)
        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)
        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)
        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)
    local base = (env.__DEPHUB and env.__DEPHUB.SourceBaseURL) or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    for _, path in ipairs(LIBRARY_PATHS) do
        if resolver then
            local ok, source = pcall(resolver, base .. path)
            if ok and type(source) == "string" and #source > 0 then return source end
        end
        local ok, source = pcall(function() return game:HttpGet(base .. path) end)
        if ok and type(source) == "string" and #source > 0 then return source end
    end
    return nil
end

local cachedLibrary = nil

local function loadLibrary()
    if cachedLibrary then return cachedLibrary end
    local source = fetchLibrarySource()
    if type(source) ~= "string" or #source == 0 then
        error("Failed to load src/dephubv2lib.lua: no copy available")
    end
    local chunk, compileError = loadstring(source)
    if not chunk then error("Failed to compile dephubv2lib.lua: " .. tostring(compileError)) end
    local okRun, export = pcall(chunk)
    if not okRun or type(export) ~= "table" or type(export.MakeWindow) ~= "function" then
        error("dephubv2lib.lua did not return a valid library: " .. tostring(export))
    end
    cachedLibrary = export
    return export
end

-- ===========================================================================
-- Section wrapper
--
-- RedzLib has no section *container*: `Tab:AddSection(title)` returns a header
-- object and every control added afterwards lands below it on the tab. DepHub's
-- backends expect a section handle they can add controls to, so the wrapper
-- simply forwards each builder to the tab. Visually the result is identical:
-- the header is drawn, then the controls the backend adds for that section.
-- ===========================================================================

local function makeSection(adapter, tabHandle, title)
    local section = { Adapter = adapter, Control = tabHandle, Title = title }

    function section:CreateToggle(label, initial, callback)
        return tabHandle:AddToggle({
            Name = tostring(label),
            Default = initial == true,
            Callback = callback
        })
    end

    function section:CreateSlider(label, minimum, maximum, initial, callback)
        local lo = tonumber(minimum) or 0
        local hi = tonumber(maximum) or 100
        local start = tonumber(initial)
        if start == nil then start = lo end
        -- RedzLib requires min < max and a positive increment; derive a sane
        -- step from the range so callers keep passing plain numbers.
        local range = hi - lo
        local step = 1
        if range > 0 and range <= 1 then step = 0.01
        elseif range > 1000 then step = math.max(1, math.floor(range / 1000)) end
        if hi <= lo then hi = lo + step end
        return tabHandle:AddSlider({
            Name = tostring(label),
            Min = lo,
            Max = hi,
            Increment = step,
            Default = start,
            Callback = callback
        })
    end

    function section:CreateDropdown(label, options, initial, callback)
        local list = {}
        for _, option in ipairs(type(options) == "table" and options or {}) do
            list[#list + 1] = tostring(option)
        end
        if #list == 0 then list = { "None" } end
        local default = tostring(initial or list[1])
        return tabHandle:AddDropdown({
            Name = tostring(label),
            Options = list,
            Default = default,
            Callback = function(value) if callback then callback(value) end end
        })
    end

    function section:CreateButton(label, callback)
        return tabHandle:AddButton({
            Name = tostring(label),
            Callback = callback
        })
    end

    -- DepHub's input handle is a small record: `.Value` holds the current text
    -- and `.Control` is the underlying object (diagnostics clears it with
    -- `.Control:Set("")`). RedzLib's textbox exposes `Set`/`SetText`, so the
    -- handle simply forwards.
    function section:CreateInput(label, placeholder, initial, callback)
        local handle = { Value = tostring(initial or "") }
        handle.Control = tabHandle:AddTextBox({
            Name = tostring(label),
            Placeholder = tostring(placeholder or ""),
            Default = tostring(initial or ""),
            Callback = function(value)
                handle.Value = tostring(value or "")
                if callback then callback(value) end
            end
        })
        return handle
    end

    function section:CreateParagraph(titleText, bodyText)
        return tabHandle:AddParagraph(tostring(titleText or ""), tostring(bodyText or ""))
    end

    -- RedzLib stacks every control vertically and has no side-by-side container,
    -- so a "row" is a pass-through handle onto the same tab. The controls still
    -- render (stacked) and every backend call site keeps working unchanged.
    function section:CreateRow()
        return section
    end

    function section:CreateStack()
        return section
    end

    return section
end

-- ===========================================================================
-- Dashboard builders
--
-- The loader builds a fixed Dashboard tab for every game and calls two library
-- methods for it. RedzLib has neither, so the adapter provides them on top of
-- RedzLib primitives: a greeting/identity banner and a live metrics block. Both
-- keep the same signature the loader already calls.
-- ===========================================================================

local function greetingText()
    local hour = tonumber(os.date("%H")) or 12
    if hour >= 5 and hour < 12 then return "Good Morning"
    elseif hour >= 12 and hour < 17 then return "Good Afternoon"
    elseif hour >= 17 and hour < 20 then return "Good Evening"
    else return "Good Night" end
end

-- RedzLib does not expose the services it resolved; the adapter re-reads the two
-- the dashboard needs. Kept lazy so a missing service never breaks loading.
local Services = setmetatable({}, {
    __index = function(self, name)
        local ok, service = pcall(function() return game:GetService(name) end)
        local value = ok and service or nil
        rawset(self, name, value)
        return value
    end
})

local function installDashboardBuilders(adapter, library)
    function library:CreateDashboardBanner(tabName)
        local record = adapter._tabByName[tabName]
        if not record or not record.Control then return nil end
        local player = Services.Players and Services.Players.LocalPlayer
        local displayName = "Player"
        if player then displayName = tostring(player.DisplayName or player.Name or "Player") end
        record.Control:AddSection("Dashboard")
        local banner = record.Control:AddParagraph(
            greetingText() .. ", " .. displayName,
            "Signed in to DepHub. Everything below is built live from this game."
        )
        return banner
    end

    function library:CreatePerformanceDashboard(tabName, columnName)
        local record = adapter._tabByName[tabName]
        if not record or not record.Control then return nil end
        local metrics = record.Control:AddParagraph("Performance", "Session started")
        local startedAt = os.clock()
        local runService = Services.RunService
        if runService and type(runService.RenderStepped) == "table" and type(runService.RenderStepped.Connect) == "function" then
            local lastFrame = os.clock()
            local frames = 0
            local accum = 0
            adapter._metricsConnection = runService.RenderStepped:Connect(function(deltaTime)
                local now = os.clock()
                frames = frames + 1
                accum = accum + (tonumber(deltaTime) or (now - lastFrame))
                lastFrame = now
                if accum >= 1 then
                    local fps = math.floor(frames / accum)
                    local elapsed = now - startedAt
                    pcall(function()
                        metrics:SetTitle(string.format("Performance  ·  %d FPS", fps))
                        metrics:SetDescription(string.format("Session %02d:%02d:%02d", math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), math.floor(elapsed % 60)))
                    end)
                    frames = 0
                    accum = 0
                end
            end)
        end
        return metrics
    end
end

-- ===========================================================================
-- Shell construction
-- ===========================================================================

function DemonUI.new(options)
    options = options or {}
    local library = loadLibrary()

    local window = library:MakeWindow({
        Title = options.Name or WINDOW_OPTIONS.Title,
        SubTitle = options.Version and ("v" .. tostring(options.Version)) or WINDOW_OPTIONS.SubTitle
    })

    local self = setmetatable({
        Library = library,
        Window = window,
        Tabs = {},
        Categories = {},
        CurrentSea = "Sea1",
        SearchQuery = "",
        Destroyed = false,
        _tabByName = {}
    }, DemonUI)

    self:CreateCategory(DEFAULT_CATEGORY, "layers")

    -- Keep RedzLib's dashboard builders on the library object so the loader's
    -- `window.Library:CreateDashboardBanner(...)` calls resolve.
    installDashboardBuilders(self, library)

    -- Open/close the panel without the keyboard. Some executers deliver
    -- InputBegan with gameProcessed=true, so the shell ignores the toggle key on
    -- purpose; this global flips the window's visibility directly and doubles as
    -- a probe (if __DEPHUB_TOGGLE() works but the key does not, it is the
    -- executor). RedzLib has no Toggle() of its own, so the adapter provides it.
    function library:Toggle()
        if self.Destroyed then return false end
        window:Minimize()
        return true
    end

    local env = type(getgenv) == "function" and getgenv() or _G
    env.__DEPHUB_TOGGLE = function()
        if self.Destroyed or not self.Library then return false end
        pcall(function() self.Library:Toggle() end)
        return true
    end

    return self
end

-- Backends call this to add a category of their own. RedzLib has no category
-- concept, so the adapter records the group here; tabs keep the category name so
-- any consumer that inspects `tab.Category` still sees it. Idempotent.
function DemonUI:CreateCategory(name, icon)
    name = tostring(name or DEFAULT_CATEGORY)
    if self.Categories[name] then return true end
    self.Categories[name] = true
    return true
end

function DemonUI:CreateTab(name, category)
    if self.Destroyed then return nil end
    name = tostring(name)
    category = tostring(category or DEFAULT_CATEGORY)
    if not self.Categories[category] then self:CreateCategory(category) end

    local existing = self.Tabs[category .. "|" .. name]
    if existing then return existing end

    -- RedzLib keys tabs by title, so a name has to be unique across the window.
    -- Two categories wanting a tab called "Farm" get distinct titles.
    local title = name
    if self._tabByName[title] then title = name .. " · " .. category end

    local ok, tabHandle = pcall(function() return self.Window:MakeTab({ Title = title }) end)
    if not ok or type(tabHandle) ~= "table" then
        return nil, tostring(tabHandle)
    end

    local record = {
        Adapter = self,
        Name = title,
        DisplayName = name,
        Category = category,
        Key = category .. "|" .. name,
        Control = tabHandle,
        Sections = {},
        Visible = true,
        Sea = nil
    }

    function record:CreateSection(sectionTitle, column)
        sectionTitle = tostring(sectionTitle or self.DisplayName)
        if self.Sections[sectionTitle] then return self.Sections[sectionTitle] end
        local handled = pcall(function() self.Control:AddSection(sectionTitle) end)
        if not handled then return nil end
        local wrapper = makeSection(self.Adapter, self.Control, sectionTitle)
        self.Sections[sectionTitle] = wrapper
        return wrapper
    end

    function record:SetVisible(visible)
        self.Visible = visible == true
        pcall(function() self.Control:SetVisible(self.Visible) end)
    end

    self.Tabs[record.Key] = record
    self._tabByName[title] = record
    return record
end

-- Sea filtering is kept for API compatibility. DepHub's backends do not call it
-- today; when they do, a tab scoped to a sea is simply hidden while another sea
-- is active. RedzLib hides a tab with Tab:SetVisible, which covers both its
-- button and its content page in one call.
function DemonUI:_tabMatchesSea(tab, sea)
    local scope = tab.Sea
    if scope == nil or scope == "" or scope == "All" then return true end
    local lower = tostring(scope):lower()
    if lower:find("sea1") and sea == "Sea1" then return true end
    if lower:find("sea2") and sea == "Sea2" then return true end
    if lower:find("sea3") and sea == "Sea3" then return true end
    return lower == tostring(sea):lower()
end

function DemonUI:_refreshVisibility()
    if self.Destroyed then return end
    local sea = self.CurrentSea
    for _, tab in pairs(self.Tabs) do
        local matches = self:_tabMatchesSea(tab, sea)
        local label = tostring(tab.DisplayName or tab.Name or ""):lower()
        local matchesQuery = self.SearchQuery == "" or label:find(self.SearchQuery, 1, true) ~= nil
        local visible = matches and matchesQuery
        tab.Visible = visible
        pcall(function() tab.Control:SetVisible(visible) end)
    end
end

function DemonUI:SetCurrentSea(sea)
    self.CurrentSea = tostring(sea or "Sea1")
    self:_refreshVisibility()
end

-- Feature search: hides tabs whose name does not contain the query. Combines
-- with the sea filter; an empty query matches everything.
function DemonUI:Search(query)
    self.SearchQuery = tostring(query or ""):lower()
    self:_refreshVisibility()
end

function DemonUI:Notify(title, message, kind)
    if self.Destroyed then return end
    pcall(function()
        self.Window:Notify({
            Title = tostring(title or "DepHub"),
            Content = tostring(message or ""),
            Duration = 4
        })
    end)
end

function DemonUI:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self._metricsConnection then
        pcall(function() self._metricsConnection:Disconnect() end)
        self._metricsConnection = nil
    end
    pcall(function() self.Library:Destroy() end)
    table.clear(self.Tabs)
    table.clear(self.Categories)
    table.clear(self._tabByName)
end

return DemonUI

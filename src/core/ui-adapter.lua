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
--   UI:CreateTab(name, category, icon)     -- returns a tab wrapper or nil; icon
--                                          --   is a Unicode emoji (or asset id)
--   tab:CreateSection(title, column)       -- "Left" (default) or "Right"
--   section:CreateToggle/Slider/Dropdown/Button/Input/Paragraph(...)
--   section:CreateMultiDropdown(label, options, initial, callback)  -- multi-select;
--                                          --   callback gets an array of names
--   section:CreateRow() / section:CreateStack()   -- grouping handles
--   UI:Notify(title, message, kind)
--   UI:SetCurrentSea(sea)                  -- kept for compatibility; no-op filter
--   UI:Destroy()

local DemonUI = {}
DemonUI.__index = DemonUI

-- Window options shared by every game so the interface is identical everywhere.
-- Changing anything here changes it for all games at once.
--
-- Size is a large fixed pixel size. RedzLib reads the starting window size from
-- Library.Default.UISize (a UDim2), not from MakeWindow options. The UI keeps a
-- native 1:1 scale and enforces a large minimum size so old saved settings cannot
-- reopen the panel as a tiny window.
local WINDOW_OPTIONS = {
    Title = "DepHub",
    SubTitle = "DepHub",
    Size = { 900, 500 },
    -- The global open/close key is bound by the adapter and can be overridden per run.
    ToggleKey = Enum.KeyCode.B
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

    -- Multi-select dropdown: RedzLib supports it natively
    -- (`AddDropdown{ MultiSelect = true }`). The callback receives a SET table
    -- ({ "Dragon" = true }) -- the DepHub contract hands back a plain ARRAY of the
    -- selected names instead, in the option order, so backends never depend on
    -- the library's internal shape. `initial` is an array of pre-selected names.
    -- The returned handle also exposes `:Set(names)` to restore a saved selection
    -- (it re-adds the names, which is how RedzLib selects programmatically).
    function section:CreateMultiDropdown(label, options, initial, callback)
        local list = {}
        for _, option in ipairs(type(options) == "table" and options or {}) do
            list[#list + 1] = tostring(option)
        end
        if #list == 0 then list = {"None"} end

        local selected = {}
        local suppressCallback = false

        local function asArray()
            local out = {}
            for _, name in ipairs(list) do
                if selected[name] then out[#out + 1] = name end
            end
            return out
        end

        local initialList = {}
        for _, name in ipairs(type(initial) == "table" and initial or {}) do
            local key = tostring(name)
            selected[key] = true
            initialList[#initialList + 1] = key
        end

        local handle = tabHandle:AddDropdown({
            Name = tostring(label),
            Options = list,
            Default = initialList,
            MultiSelect = true,
            Callback = function(value)
                selected = {}
                if type(value) == "table" then
                    for name, isSelected in pairs(value) do
                        if isSelected then selected[tostring(name)] = true end
                    end
                end
                if callback and not suppressCallback then
                    callback(asArray())
                end
            end
        })

        if handle and type(handle) == "table" then
            handle.SetSilent = function(_, names)
                local wanted = {}
                for _, name in ipairs(type(names) == "table" and names or {}) do
                    local key = tostring(name)
                    for _, option in ipairs(list) do
                        if option == key then wanted[key] = true; break end
                    end
                end

                suppressCallback = true
                if type(handle.Clear) == "function" then
                    pcall(function() handle:Clear() end)
                end

                if type(handle.Add) == "function" then
                    for _, option in ipairs(list) do
                        if wanted[option] then
                            pcall(function() handle:Add(option) end)
                        end
                    end
                end

                if type(handle.Select) == "function" then
                    for _, option in ipairs(list) do
                        if wanted[option] then
                            pcall(function() handle:Select(option, true) end)
                        end
                    end
                end

                selected = wanted
                suppressCallback = false
                return true
            end

            handle.Set = function(_, names)
                local ok = handle:SetSilent(names)
                if ok and callback then callback(asArray()) end
                return ok
            end
        end

        return handle
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
    -- handle forwards. O handle tambem expoe `Set`/`SetValue` proprios, que e o
    -- contrato que o config-store procura em todo handle (Apply): sem isso, um
    -- valor salvo num campo de texto nao voltava pra tela, so o efeito rodava.
    -- `Set` move o texto SEM re-disparar o callback -- o Apply ja roda o efeito;
    -- a RedzLib so dispara o callback no FocusLost, nao no SetText.
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
        handle.Set = function(_, value)
            local text = tostring(value or "")
            handle.Value = text
            local control = handle.Control
            if control then
                if type(control.Set) == "function" then pcall(control.Set, control, text)
                elseif type(control.SetText) == "function" then pcall(control.SetText, control, text) end
            end
            return text
        end
        handle.SetValue = handle.Set
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
    -- Real RedzLib has no dashboard builders, so the adapter supplies them. A
    -- test double (or a future library that grows its own) already providing them
    -- keeps its implementation.
    if type(library.CreateDashboardBanner) ~= "function" then
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
    end

    if type(library.CreatePerformanceDashboard) ~= "function" then
        function library:CreatePerformanceDashboard(tabName, columnName)
            local record = adapter._tabByName[tabName]
            if not record or not record.Control then return nil end
            local metrics = record.Control:AddParagraph("Performance", "Session started")
            local startedAt = os.clock()
            local runService = Services.RunService
            -- RenderStepped e um RBXScriptSignal, NAO uma tabela Lua: a checagem
            -- antiga (type(...) == "table") era falsa no Roblox e o medidor de
            -- FPS nunca conectava. A propria conexao protegida por pcall e a
            -- validacao -- se o sinal nao existir/conectar, nao ha medidor.
            if runService then
                local lastFrame = os.clock()
                local frames = 0
                local accum = 0
                local ok, connection = pcall(function()
                    return runService.RenderStepped:Connect(function(deltaTime)
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
                end)
                if ok and connection then adapter._metricsConnection = connection end
            end
            return metrics
        end
    end
end

-- ===========================================================================
-- Shell construction
-- ===========================================================================

function DemonUI.new(options)
    options = options or {}
    local library = loadLibrary()

    -- MakeWindow ignores a Size option; set the default UDim2 before constructing
    -- the window. The library clamps this to 850..1000 by 480..500 pixels.
    local size = options.Size or WINDOW_OPTIONS.Size
    if type(size) == "table" and type(size[1]) == "number" and type(size[2]) == "number"
        and type(library.Default) == "table" then
        library.Default.UISize = UDim2.fromOffset(size[1], size[2])
    end

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

    -- The global open/close probe: flips the window without the keyboard (some
    -- executers deliver InputBegan with gameProcessed=true). If __DEPHUB_TOGGLE()
    -- works but the key does not, it is the executor. RedzLib's window has no
    -- Toggle() of its own (only Minimize(), which flips the main frame's
    -- Visible), so the adapter exposes it.
    function library:Toggle()
        if self.Destroyed then return false end
        local ok = pcall(function() window:Minimize() end)
        return ok
    end

    local env = type(getgenv) == "function" and getgenv() or _G
    -- Guarda a closure publicada em self: no Destroy so removemos a chave global
    -- se ela AINDA for esta funcao (senao outra sessao a sobrescreveu e a dela
    -- ficaria orfa). Devolve o resultado REAL do toggle, nao um true de fachada.
    self.ToggleCallback = function()
        if self.Destroyed or not self.Library then return false end
        return self.Library:Toggle() == true
    end
    env.__DEPHUB_TOGGLE = self.ToggleCallback

    -- Ignore the executor's gameProcessed flag. A focused TextBox is the only
    -- case where typing B should not toggle the interface.
    local UserInputService = game:GetService("UserInputService")
    local savedKey = type(env.__DEPHUB_PANEL_KEY) == "string" and Enum.KeyCode[env.__DEPHUB_PANEL_KEY] or nil
    self.ToggleKey = options.ToggleKey or savedKey or WINDOW_OPTIONS.ToggleKey
    self._capturingToggleKey = false

    function self:SetToggleKey(keyCode)
        if self.Destroyed or typeof(keyCode) ~= "EnumItem" or keyCode.EnumType ~= Enum.KeyCode then
            return false
        end
        if keyCode == Enum.KeyCode.Unknown then return false end
        self.ToggleKey = keyCode
        env.__DEPHUB_PANEL_KEY = keyCode.Name
        return true
    end

    local okConnect, connection = pcall(function()
        return UserInputService.InputBegan:Connect(function(io)
            if self.Destroyed or self._capturingToggleKey then return end
            if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if io.KeyCode ~= self.ToggleKey then return end

            local focused = nil
            pcall(function()
                focused = UserInputService:GetFocusedTextBox()
            end)
            if focused then return end
            pcall(function() self.Library:Toggle() end)
        end)
    end)
    if okConnect and connection then self._toggleKeyConnection = connection end

    local settingsTab = self:CreateTab("Interface", "Settings", "keyboard")
    if settingsTab then
        local settingsSection = settingsTab:CreateSection("Panel")
        if settingsSection then
            local currentKeyParagraph = settingsSection:CreateParagraph(
                "Tecla de abertura/fechamento",
                "Tecla atual: " .. self.ToggleKey.Name
            )
            settingsSection:CreateButton("Alterar tecla do painel", function()
                if self.Destroyed or self._capturingToggleKey then return end
                self._capturingToggleKey = true
                self:Notify("Atalho do painel", "Pressione uma tecla. ESC cancela.", "info")

                local captureConnection
                captureConnection = UserInputService.InputBegan:Connect(function(io)
                    if self.Destroyed then
                        if captureConnection then captureConnection:Disconnect() end
                        self._toggleKeyCaptureConnection = nil
                        self._capturingToggleKey = false
                        return
                    end
                    if io.UserInputType ~= Enum.UserInputType.Keyboard then return end

                    local focused = nil
                    pcall(function()
                        focused = UserInputService:GetFocusedTextBox()
                    end)
                    if focused then return end

                    if io.KeyCode == Enum.KeyCode.Escape then
                        self._capturingToggleKey = false
                        captureConnection:Disconnect()
                        self._toggleKeyCaptureConnection = nil
                        self:Notify("Atalho do painel", "Alteração cancelada.", "info")
                        return
                    end

                    if io.KeyCode == Enum.KeyCode.Unknown then return end

                    self:SetToggleKey(io.KeyCode)
                    self._capturingToggleKey = false
                    captureConnection:Disconnect()
                    self._toggleKeyCaptureConnection = nil
                    if currentKeyParagraph and type(currentKeyParagraph.SetDescription) == "function" then
                        pcall(function()
                            currentKeyParagraph:SetDescription("Tecla atual: " .. io.KeyCode.Name)
                        end)
                    end
                    self:Notify("Atalho atualizado", "O painel agora abre e fecha com " .. io.KeyCode.Name .. ".", "success")
                end)
                self._toggleKeyCaptureConnection = captureConnection
            end)
        end
    end

    return self
end

-- Backends call this to add a category of their own. RedzLib has no category
-- concept, so the adapter records the group here; tabs keep the category name so
-- any consumer that inspects `tab.Category` still sees it. Idempotent. When the
-- underlying library happens to model categories (a test double, or a future
-- library), the call is forwarded so its own bookkeeping stays in step.
function DemonUI:CreateCategory(name, icon)
    name = tostring(name or DEFAULT_CATEGORY)
    if self.Categories[name] then return true end
    self.Categories[name] = true
    if type(self.Library.CreateCategory) == "function" then
        pcall(function() self.Library:CreateCategory(name, icon) end)
    end
    return true
end

function DemonUI:CreateTab(name, category, icon)
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

    -- The icon is a catalogue NAME (e.g. "rocket") the library resolves to a real
    -- asset id, or a raw asset id. A name that is not in the catalogue resolves to
    -- nothing, and the tab renders without an icon; nil means no icon too.
    local options = { Title = title }
    if type(icon) == "string" and #icon > 0 then options.Icon = icon end

    local ok, tabHandle = pcall(function() return self.Window:MakeTab(options) end)
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
    self._capturingToggleKey = false
    if self._toggleKeyCaptureConnection then
        pcall(function() self._toggleKeyCaptureConnection:Disconnect() end)
        self._toggleKeyCaptureConnection = nil
    end
    if self._toggleKeyConnection then
        pcall(function() self._toggleKeyConnection:Disconnect() end)
        self._toggleKeyConnection = nil
    end
    if self._metricsConnection then
        pcall(function() self._metricsConnection:Disconnect() end)
        self._metricsConnection = nil
    end
    pcall(function() self.Library:Destroy() end)
    -- Remove a sonda global SO se ela ainda for a desta sessao. Se outra sessao a
    -- sobrescreveu, nao apagamos a dela.
    local env = type(getgenv) == "function" and getgenv() or _G
    if self.ToggleCallback and env.__DEPHUB_TOGGLE == self.ToggleCallback then
        env.__DEPHUB_TOGGLE = nil
    end
    self.ToggleCallback = nil
    table.clear(self.Tabs)
    table.clear(self.Categories)
    table.clear(self._tabByName)
end

return DemonUI

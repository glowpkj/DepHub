-- Render smoke test for the real UI stack.
--
-- The backend harness stubs the shell's library (DOD_LIBRARY_STUB) and its
-- Instance double deliberately rejects GUI classes, so nothing else in the suite
-- ever loads the REAL src/dephubv2lib.lua or the REAL src/core/demon-ui.lua.
-- That meant a regression in either could pass every test and only show up
-- in-game.
--
-- This block fills the gap: it builds a permissive Roblox GUI double, loads the
-- real RedzLib source (_THEME_SOURCE) and the real adapter source, then drives
-- the whole shell contract the backends use -- categories, tabs, sections, every
-- control, rows/stacks, the sea filter, search, the dashboard builders, the
-- __DEPHUB_TOGGLE global and Destroy. It does not claim in-game fidelity: it
-- claims the modules compile, load and build.
do
    local function renderSignal()
        local connections = {}
        local signal = {}
        function signal:Connect(fn)
            local connection = {fn = fn, Disconnect = function() end}
            connections[#connections + 1] = fn
            return connection
        end
        -- Alguns testes precisam disparar o evento (ex.: o minimizador filtra
        -- InputBegan processado). O stub antigo so aceitava Connect.
        function signal:Fire(...)
            for _, fn in ipairs(connections) do pcall(fn, ...) end
        end
        return signal
    end

    -- A permissive GUI double: instances parent by name, expose the events the
    -- library connects, and accept any property write.
    local function renderInstance(class)
        local raw = {ClassName = class, Name = "", _kids = {}, _attrs = {}, Visible = true, Text = ""}
        function raw:IsA(c)
            return c == class or c == "Instance" or c == "GuiObject" or c == "Frame"
        end
        function raw:GetChildren() return self._kids end
        function raw:ClearAllChildren() self._kids = {} end
        function raw:Destroy() end
        function raw:SetAttribute(k, v) self._attrs[k] = v end
        function raw:GetAttribute(k) return self._attrs[k] end
        function raw:GetAttributeChangedSignal() return renderSignal() end
        function raw:GetPropertyChangedSignal() return renderSignal() end
        function raw:WaitForChild() return raw end
        function raw:FindFirstChild(name)
            for _, kid in ipairs(self._kids) do if kid.Name == name then return kid end end
            return nil
        end
        function raw:FindFirstChildOfClass(c)
            for _, kid in ipairs(self._kids) do
                if pcall(function() return kid:IsA(c) end) and kid:IsA(c) then return kid end
            end
            return nil
        end
        function raw:FindFirstAncestorOfClass() return nil end
        function raw:IsDescendantOf() return false end
        function raw:GetDescendants() return self._kids end
        function raw:GetFullName() return self.Name end
        function raw:Clone() return renderInstance(class) end
        function raw:CaptureFocus() end
        for _, eventName in ipairs({
            "Destroying", "Activated", "MouseEnter", "MouseLeave", "MouseButton1Down",
            "MouseButton1Up", "InputBegan", "InputChanged", "Changed", "AncestryChanged",
            "ChildAdded", "ChildRemoved", "Focused", "FocusLost", "TextChanged",
            "SelectionGained", "SelectionLost", "TouchTap", "TouchLongPress", "TouchPan",
            "MouseWheelForward", "MouseWheelBackward", "HoverEnter", "HoverLeave",
            "WindowFocused", "WindowFocusReleased", "ReturnPressedFromOnScreenKeyboard",
        }) do
            raw[eventName] = renderSignal()
        end

        local proxy
        proxy = setmetatable({}, {
            __index = function(_, key)
                local value = raw[key]
                if value ~= nil then return value end
                for _, kid in ipairs(raw._kids) do
                    if kid.Name == key then return kid end
                end
                return nil
            end,
            __newindex = function(_, key, value)
                if key == "Parent" then
                    local old = raw.Parent
                    if old and old._kids then
                        for i, kid in ipairs(old._kids) do
                            if kid == proxy then table.remove(old._kids, i) break end
                        end
                    end
                    raw.Parent = value
                    if value and value._kids then value._kids[#value._kids + 1] = proxy end
                else
                    raw[key] = value
                end
            end,
        })
        return proxy
    end

    local renderServices = {
        Debris = {AddItem = function() end},
        MarketplaceService = {GetProductInfo = function() return {} end, PromptGamePassPurchase = function() end},
        UserInputService = {
            InputChanged = renderSignal(), InputBegan = renderSignal(), InputEnded = renderSignal(),
            GetStringForKeyCode = function() return "" end,
            GetKeysPressed = function() return {} end,
        },
        TweenService = {
            Create = function() return {Play = function() end, Cancel = function() end, Completed = renderSignal()} end,
        },
        HttpService = {
            JSONDecode = function() return {} end,
            JSONEncode = function() return "{}" end,
            GetAsync = function() end,
        },
        RunService = {Heartbeat = renderSignal(), RenderStepped = renderSignal(), Stepped = renderSignal()},
        Players = {},
        CoreGui = renderInstance("CoreGui"),
    }
    local renderPlayer = renderInstance("Player")
    renderPlayer.UserId = 1
    renderPlayer.DisplayName = "Tester"
    renderPlayer.Name = "Tester"
    function renderPlayer:GetMouse() return renderInstance("Mouse") end
    renderServices.Players.LocalPlayer = renderPlayer
    renderServices.Workspace = renderInstance("Workspace")
    renderServices.Workspace.CurrentCamera = {ViewportSize = {X = 1920, Y = 1080}}

    -- EnumItem double: value+Name+EnumType, flagged so typeof() reports it as an
    -- EnumItem (RedzLib's KeyCode validator runs an EnumItem type check).
    local ENUMITEM = {}
    local function renderEnumItem(enumType, name, value)
        local item = setmetatable({
            Name = name, Value = value or 0, EnumType = enumType, _isEnumItem = true,
        }, {__index = function(_, key)
            if key == "IsA" then return function(self, c) return c == "EnumItem" end end
            return nil
        end})
        return item
    end
    local function renderEnumType(enumName, names)
        local et = {_items = {}, GetEnumItems = function(self) return self._items end}
        local byName = {}
        for i, n in ipairs(names) do
            local item = renderEnumItem(et, n, i)
            et._items[i] = item
            byName[n] = item
        end
        et.__index = function(_, key) return byName[key] end
        return setmetatable(et, et)
    end

    local renderEnum = setmetatable({}, {
        __index = function()
            return setmetatable({}, {__index = function() return 0 end})
        end,
    })
    local renderKeyCode = renderEnumType("KeyCode", {"N", "M", "Unknown"})
    renderEnum.KeyCode = renderKeyCode
    renderEnum.UserInputType = {
        MouseButton1 = renderEnumItem("UserInputType", "MouseButton1", 1),
        Touch = renderEnumItem("UserInputType", "Touch", 2),
        MouseMovement = renderEnumItem("UserInputType", "MouseMovement", 3),
        Keyboard = renderEnumItem("UserInputType", "Keyboard", 4),
    }
    renderEnum.UserInputState = {End = 1}
    renderEnum.PlaybackState = {Playing = 1}

    local renderColor3 = setmetatable({}, {
        __index = function(_, key)
            if key == "fromRGB" then return function(r, g, b) return {R = r, G = g, B = b} end end
            if key == "new" then return function() return {} end end
            return {}
        end,
    })

    local renderEnv = {
        game = {
            GetService = function(_, name) return renderServices[name] or {} end,
            HttpGet = function() return "" end,
        },
        workspace = renderServices.Workspace,
        Instance = {new = renderInstance},
        Enum = renderEnum,
        Color3 = renderColor3,
        ColorSequence = {new = function(t) return t or {} end},
        ColorSequenceKeypoint = {new = function(t, c) return {Time = t, Value = c} end},
        UDim = {new = function(s, o) return {Scale = s, Offset = o} end},
        UDim2 = {
            new = function(xs, xo, ys, yo) return {X = {Scale = xs, Offset = xo}, Y = {Scale = ys, Offset = yo}} end,
            fromOffset = function(x, y) return {X = {Scale = 0, Offset = x}, Y = {Scale = 0, Offset = y}} end,
            fromScale = function(x, y) return {X = {Scale = x, Offset = 0}, Y = {Scale = y, Offset = 0}} end,
        },
        Vector2 = {new = function(x, y) return {X = x, Y = y, Unit = {X = 0, Y = 0}} end},
        CFrame = {new = function() return {} end},
        Rect = {new = function() return {} end},
        TweenInfo = {new = function() return {} end},
        NumberSequence = {new = function() return {} end},
        Random = {new = function() return {NextNumber = function() return 0.5 end, NextInteger = function(a) return a end} end},
        tick = function() return 0 end,
        os = os,
        typeof = function(v)
            if type(v) == "table" and v._isEnumItem then return "EnumItem" end
            return type(v)
        end,
        gethui = function() return renderServices.CoreGui end,
        cloneref = function(v) return v end,
        hookfunction = function() end,
        makefolder = function() end,
        writefile = function() end,
        readfile = function() return "{}" end,
        delfile = function() end,
        delfolder = function() end,
        isfolder = function() return false end,
        isfile = function() return false end,
        getcustomasset = function(x) return x end,
        setclipboard = function() end,
        task = {
            spawn = function(fn, ...) return fn(...) end,
            delay = function() end,
            defer = function() end,
            wait = function() end,
        },
        require = function() return nil end,
        utf8 = utf8,
    }
    renderEnv.getgenv = function() return renderEnv end
    renderEnv._G = renderEnv
    renderEnv.type = type
    renderEnv.pairs = pairs
    renderEnv.ipairs = ipairs
    renderEnv.rawget = rawget
    renderEnv.rawset = rawset
    renderEnv.setmetatable = setmetatable
    renderEnv.getmetatable = getmetatable
    renderEnv.table = table
    renderEnv.string = string
    renderEnv.math = math
    renderEnv.select = select
    renderEnv.tostring = tostring
    renderEnv.tonumber = tonumber
    renderEnv.error = error
    renderEnv.assert = assert
    renderEnv.pcall = pcall
    renderEnv.print = print

    -- loadstring in the real executor inherits the caller's environment; the
    -- standalone Luau binary resets it, so restore it here.
    local rawLoadstring = loadstring
    local function renderLoadstring(source, name)
        local chunk = rawLoadstring(source, name)
        if chunk then pcall(setfenv, chunk, renderEnv) end
        return chunk
    end
    renderEnv.loadstring = renderLoadstring
    renderEnv.setfenv = setfenv

    local librarySource = assert(_THEME_SOURCE, "library source not injected")
    local libraryChunk, libraryCompileError = renderLoadstring(librarySource, "dephubv2lib")
    check(libraryChunk ~= nil, "src/dephubv2lib.lua compiles: " .. tostring(libraryCompileError))
    local libraryOk, library = pcall(libraryChunk)
    check(libraryOk, "src/dephubv2lib.lua runs: " .. tostring(library))
    check(type(library) == "table", "src/dephubv2lib.lua returns a table export")
    check(type(library.MakeWindow) == "function", "the library exposes MakeWindow")
    check(type(library.GetIconByName) == "function", "the library exposes GetIconByName")
    check(type(library.SetTheme) == "function", "the library exposes SetTheme")

    local window = library:MakeWindow({Title = "DepHub Test", SubTitle = "render"})
    check(type(window) == "table", "MakeWindow returns a window")
    check(type(window.MakeTab) == "function", "the window exposes MakeTab")
    check(type(window.Notify) == "function", "the window exposes Notify")
    check(type(window.SelectTab) == "function", "the window exposes SelectTab")

    -- NewMinimizer (RedzLib): a tecla N alterna o frame principal. Bug: o handler
    -- nao filtrava gameProcessed, entao a tecla disparava enquanto o usuario
    -- digitava (chat/TextBox). Prova: input processado NAO minimiza; input de
    -- teclado nao-processado NAO; toque/mouse NAO.
    do
        local input = renderServices.UserInputService
        local mainFrame = window:GetElements().MainFrame
        check(type(mainFrame) == "table", "o window expoe MainFrame via GetElements")
        local shownBefore = mainFrame.Visible

        local minimizer = window:NewMinimizer(renderEnum.KeyCode.N)
        check(type(minimizer) == "table" and minimizer.KeyCode == renderEnum.KeyCode.N, "NewMinimizer devolve um handle com o KeyCode")

        -- Tecla N, mas com gameProcessed=true (usuario digitando): ignora.
        input.InputBegan:Fire({KeyCode = renderEnum.KeyCode.N, UserInputType = renderEnum.UserInputType.Keyboard}, true)
        check(mainFrame.Visible == shownBefore, "input processado NAO minimiza (nao dispara digitando)")

        -- Toque no mesmo KeyCode: ignora (so teclado).
        input.InputBegan:Fire({KeyCode = renderEnum.KeyCode.N, UserInputType = renderEnum.UserInputType.Touch}, false)
        check(mainFrame.Visible == shownBefore, "input nao-teclado NAO minimiza")

        -- Tecla N limpa: alterna.
        input.InputBegan:Fire({KeyCode = renderEnum.KeyCode.N, UserInputType = renderEnum.UserInputType.Keyboard}, false)
        check(mainFrame.Visible ~= shownBefore, "tecla N nao-processada alterna o frame")

        -- Outra tecla limpa: nao alterna.
        local shownAfter = mainFrame.Visible
        input.InputBegan:Fire({KeyCode = renderEnum.KeyCode.M, UserInputType = renderEnum.UserInputType.Keyboard}, false)
        check(mainFrame.Visible == shownAfter, "outra tecla NAO minimiza")
    end

    -- The library reads its starting size from Default.UISize. Prove the value
    -- the shell writes is a well-formed UDim2 the library can offset from (a
    -- malformed one would make the window zero-sized / off-screen).
    do
        local defaultSize = library.Default.UISize
        check(type(defaultSize) == "table" and type(defaultSize.X) == "table" and type(defaultSize.X.Offset) == "number",
            "Default.UISize is a UDim2 with numeric offsets")
    end

    local tab = window:MakeTab({Title = "Home"})
    check(type(tab) == "table", "MakeTab returns a tab")
    check(tab.IS_A_TAB == true, "the tab marks itself as a tab")
    check(type(tab.AddSection) == "function", "the tab exposes AddSection")
    check(type(tab.AddToggle) == "function", "the tab exposes AddToggle")
    check(type(tab.SetVisible) == "function", "the tab exposes SetVisible")

    local section = tab:AddSection("Section A")
    check(type(section) == "table", "AddSection returns a header object")
    check(section.Kind == "Section", "the section header is tagged as a Section")

    local toggle = tab:AddToggle({Name = "My toggle", Default = true})
    check(type(toggle) == "table", "AddToggle returns a handle")
    check(toggle.Value == true, "the toggle keeps its default value")
    check(toggle.Kind == "Toggle", "the toggle is tagged as a Toggle")

    local slider = tab:AddSlider({Name = "My slider", Min = 0, Max = 100, Default = 25, Increment = 1})
    check(type(slider) == "table", "AddSlider returns a handle")
    check(slider.Value == 25, "the slider keeps its default value")

    local dropdown = tab:AddDropdown({Name = "My dropdown", Options = {"A", "B"}, Default = "A"})
    check(type(dropdown) == "table", "AddDropdown returns a handle")

    -- Multi-select dropdown (RedzLib native): Depot's Skip/Keep lists use it.
    local multi = tab:AddDropdown({Name = "My multi", Options = {"Dragon", "Leopard"}, Default = {"Dragon"}, MultiSelect = true})
    check(type(multi) == "table", "AddDropdown with MultiSelect returns a handle")
    check(multi.Kind == "Dropdown", "the multi-select dropdown is tagged as a Dropdown")

    -- Icons are catalogue names now: a known name resolves to an asset id. An
    -- unknown name (or an emoji) resolves to nothing and the tab is built with no
    -- icon -- both must succeed without error.
    local namedTab = window:MakeTab({Title = "Named Tab", Icon = "search"})
    check(type(namedTab) == "table", "MakeTab accepts a named icon")
    local unknownIconTab = window:MakeTab({Title = "Unknown Icon", Icon = "not-a-real-icon-name"})
    check(type(unknownIconTab) == "table", "MakeTab tolerates an unknown icon name")
    local emojiTab = window:MakeTab({Title = "Emoji Tab", Icon = "🍎"})
    check(type(emojiTab) == "table", "MakeTab tolerates an emoji icon (no icon drawn)")

    local button = tab:AddButton({Name = "Click", Callback = function() end})
    check(type(button) == "table", "AddButton returns a handle")

    local textbox = tab:AddTextBox({Name = "Input", Default = "", Placeholder = "type"})
    check(type(textbox) == "table", "AddTextBox returns a handle")
    check(type(textbox.Set) == "function", "the textbox exposes Set")

    local paragraph = tab:AddParagraph("Title", "Body")
    check(type(paragraph) == "table", "AddParagraph returns a handle")
    check(paragraph.Kind == "Paragraph", "the paragraph is tagged as a Paragraph")

    window:Notify({Title = "Hello", Content = "World", Duration = 3})
    check(true, "Notify runs without error")

    -- Now the adapter itself, against the library just built.
    local adapterSource = _ADAPTER_SOURCE
    if type(adapterSource) == "string" then
        renderEnv.__DEPHUB = {SourceBaseURL = "https://example.invalid/"}
        renderEnv.__dephubHttpGet = function(url)
            if url:find("dephubv2lib", 1, true) then return librarySource end
            return nil
        end
        local adapterChunk, adapterError = renderLoadstring(adapterSource, "demon-ui")
        check(adapterChunk ~= nil, "src/core/demon-ui.lua compiles: " .. tostring(adapterError))
        local adapterOk, adapter = pcall(adapterChunk)
        check(adapterOk, "src/core/demon-ui.lua runs: " .. tostring(adapter))
        check(type(adapter) == "table" and type(adapter.new) == "function", "the adapter exposes new")

        local ui = adapter.new({Name = "DepHub", Version = "0.0.0"})
        check(type(ui) == "table", "the adapter builds a shell")
        check(ui:CreateCategory("Farm", "sprout") == true, "the shell creates a category")

        -- The compact size is written where the real library reads it.
        local appliedSize = ui.Library.Default and ui.Library.Default.UISize
        check(appliedSize and appliedSize.X.Offset == 600 and appliedSize.Y.Offset == 420, "the shell applies the 600x420 size")

        local shellTab = ui:CreateTab("Auto Farm", "Farm", "sprout")
        check(type(shellTab) == "table", "the shell creates a tab with a named icon")
        check(shellTab.Key == "Farm|Auto Farm", "the tab records its category key")
        check(ui:CreateTab("Auto Farm", "Farm") == shellTab, "the shell reuses the same tab")

        local shellSection = shellTab:CreateSection("FRUIT")
        check(type(shellSection) == "table", "the shell creates a section")
        check(type(shellSection:CreateToggle("Auto collect", true)) == "table", "section CreateToggle works")
        check(type(shellSection:CreateSlider("Range", 10, 200, 55)) == "table", "section CreateSlider works")
        check(type(shellSection:CreateDropdown("Island", {"One", "Two"}, "One")) == "table", "section CreateDropdown works")
        local multiHandle = shellSection:CreateMultiDropdown("Skip list", {"Dragon", "Leopard"}, {"Dragon"}, function() end)
        check(type(multiHandle) == "table", "section CreateMultiDropdown works")
        check(type(multiHandle.Set) == "function", "the multi-dropdown handle exposes Set for restore")
        check(type(shellSection:CreateButton("Go", function() end)) == "table", "section CreateButton works")
        check(type(shellSection:CreateParagraph("Info", "Body")) == "table", "section CreateParagraph works")
        local input = shellSection:CreateInput("Command", "placeholder", "")
        check(type(input) == "table" and type(input.Control) == "table", "section CreateInput returns a control record")
        check(type(shellSection:CreateRow()) == "table", "section CreateRow returns a handle")
        check(type(shellSection:CreateStack()) == "table", "section CreateStack returns a handle")

        check(type(ui.Library.CreateDashboardBanner) == "function", "the shell provides CreateDashboardBanner")
        check(type(ui.Library.CreatePerformanceDashboard) == "function", "the shell provides CreatePerformanceDashboard")
        local dashboardTab = ui:CreateTab("Dashboard", "General")
        check(pcall(function() return ui.Library:CreateDashboardBanner(dashboardTab.Name) end), "the dashboard banner builds")
        check(pcall(function() return ui.Library:CreatePerformanceDashboard(dashboardTab.Name, "Right") end), "the dashboard metrics build")

        check(type(renderEnv.__DEPHUB_TOGGLE) == "function", "the shell publishes __DEPHUB_TOGGLE")
        check(renderEnv.__DEPHUB_TOGGLE() == true, "the toggle global reports success")
        check(ui.ToggleCallback == renderEnv.__DEPHUB_TOGGLE, "a shell guarda a closure publicada em ToggleCallback")

        ui:SetCurrentSea("Sea2")
        shellTab.Sea = "Sea1"
        ui:_refreshVisibility()
        check(shellTab.Visible == false, "a tab scoped to another sea is hidden")
        shellTab.Sea = nil
        ui:_refreshVisibility()
        check(shellTab.Visible == true, "an unscoped tab shows again")

        ui:Destroy()
        check(ui.Destroyed == true, "Destroy flags the shell")
        check(renderEnv.__DEPHUB_TOGGLE == nil, "Destroy remove a sonda global __DEPHUB_TOGGLE da sessao")

        -- A guarda do Destroy em si: remove a sonda SO se ela ainda for a desta
        -- sessao. Testada direto no metodo (a library so deixa criar 1 Window, o
        -- que impede um segundo shell real no processo).
        local function fakeShell(toggleGlobal)
            return {
                Destroyed = false, Tabs = {}, Categories = {}, _tabByName = {},
                Library = {Destroy = function() end},
                ToggleCallback = toggleGlobal,
            }
        end

        -- Caso 1: o global ainda e o nosso -> limpa.
        local own = function() return true end
        renderEnv.__DEPHUB_TOGGLE = own
        local shellA = fakeShell(own)
        adapter.Destroy(shellA)
        check(renderEnv.__DEPHUB_TOGGLE == nil, "Destroy limpa a sonda quando ela ainda e a da sessao")
        check(shellA.ToggleCallback == nil, "Destroy zera o ToggleCallback")

        -- Caso 2: outra sessao sobrescreveu o global -> nao apaga a dela.
        local foreign = function() return "foreign" end
        renderEnv.__DEPHUB_TOGGLE = foreign
        local shellB = fakeShell(own)
        adapter.Destroy(shellB)
        check(renderEnv.__DEPHUB_TOGGLE == foreign, "Destroy nao apaga a sonda de outra sessao")
        check(shellB.ToggleCallback == nil, "Destroy zera o ToggleCallback mesmo sem limpar o global alheio")
        renderEnv.__DEPHUB_TOGGLE = nil
    end
end

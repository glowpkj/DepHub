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
        -- Debug: dispara propagando erro (pra ver onde o handler quebra).
        function signal:FireRaw(...)
            for _, fn in ipairs(connections) do fn(...) end
        end
        -- O popup de dropdown da lib chama Completed:Wait() ao abrir/fechar. Sem o
        -- Wait o tween "trava" e a flag de fechamento fica presa true -- o dropdown
        -- nunca mais abre. Modelar aqui mantem o double fiel ao Roblox.
        function signal:Wait() return nil end
        return signal
    end

    -- A permissive GUI double: instances parent by name, expose the events the
    -- library connects, and accept any property write.
    local function renderInstance(class)
        local raw = {ClassName = class, Name = "", _kids = {}, _attrs = {}, Visible = true, Text = ""}
        -- A lib le AbsoluteSize/AbsolutePosition dos frames (posicionamento do popup,
        -- escala). Sem eles, a matematica do popup estoura. Valores plausiveis.
        if class == "ScreenGui" then
            raw.AbsoluteSize = {X = 1920, Y = 1080}
            raw.AbsolutePosition = {X = 0, Y = 0}
        else
            raw.AbsoluteSize = {X = 200, Y = 21}
            raw.AbsolutePosition = {X = 100, Y = 100}
        end
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
        -- O Instance real indexa DIRETO e tambem pelos DESCENDENTES (via
        -- descendant lookup), nao so pelos filhos de primeiro nivel. O popup do
        -- dropdown e uma arvore aninhada (overlay -> frame "Dropdown" -> opcoes),
        -- entao o teste precisa da busca descendente para achar o frame do popup
        -- e medir posicao/tamanho de verdade.
        function raw:FindFirstChildRecursive(name)
            for _, kid in ipairs(self._kids) do
                if kid.Name == name then return kid end
                local found = kid.FindFirstChildRecursive and kid:FindFirstChildRecursive(name)
                if found then return found end
            end
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
                -- Busca por NOME nos filhos diretos (o Instance real indexa filhos
                -- diretos pelo nome) e, se nao achar, nos DESCENDENTES.
                for _, kid in ipairs(raw._kids) do
                    if kid.Name == key then return kid end
                end
                local function deep(node, name)
                    local kids = node._kids
                    if not kids and node.__proxy then kids = node.__proxy._kids end
                    for _, kid in ipairs(kids or {}) do
                        if kid.Name == name then return kid end
                        local found = deep(kid, name)
                        if found then return found end
                    end
                    return nil
                end
                local found = deep(raw, key)
                if found then return found end
                -- A lib procura filhos sem nome pela CLASSE (ex.: option.TextLabel,
                -- option.Frame). O Instance real da lib expoe esses atalhos; aqui
                -- derivamos do ClassName do filho pra o double ser fiel.
                for _, kid in ipairs(raw._kids) do
                    local kc = kid.ClassName
                    if type(kc) == "string" and kc == key then return kid end
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
        -- Back-reference: `deep` precisa da tabela crua por tras de um proxy.
        raw.__proxy = proxy
        raw._isInstance = true
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
            -- FIDELIDADE: no Roblox real `typeof(<Instance>) == "Instance"`.
            -- A lib decide por `typeof` se um argumento posicional e o Parent ou
            -- uma tabela de propriedades. Reportando "table" para uma Instance, o
            -- double montava a arvore de forma diferente do jogo -- o frame pai
            -- virava "props" e a pasta Dropdowns ficava vazia, o que escondia o
            -- bug de posicionamento do popup. Reportar "Instance" deixa o double
            -- fiel e o teste de geometria mede o que o jogo mede.
            if type(v) == "table" and v._isInstance then return "Instance" end
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

    -- O default de um dropdown MULTI tem que ser ARRAY: a lib varre `for i=1,#Default`.
    -- Um SET {Dragon=true} faz o loop rodar zero vezes, nada fica selecionado e o
    -- campo renderiza o placeholder "..." -- o dropdown que parecia nao-selecionavel
    -- no painel. Aqui provamos que o array default seleciona de verdade e que o
    -- campo renderiza o nome escolhido.
    do
        local selectedCount = 0
        local dragonSelected = false
        for _, option in ipairs(multi.DROPDOWN_OPTIONS) do
            if option.Selected then
                selectedCount = selectedCount + 1
                if option.Name == "Dragon" then dragonSelected = true end
            end
        end
        check(selectedCount == 1 and dragonSelected,
            "com Default array o dropdown multi ja nasce com 'Dragon' selecionado")
    end

    -- ABRIR: clicar no campo abre o popup e marca Opened; clicar de novo fecha.
    -- Era o "nao abre pra selecionar" do usuario.
    do
        local holder = multi.VISIBLE_ELEMENT
        check(type(holder) == "table", "o dropdown expoe o campo clicavel (VISIBLE_ELEMENT)")

        -- ANTES de abrir, o popup NAO pode estar visivel em lugar nenhum -- era o
        -- "box escuro com a lupa" preso sobre o conteudo que o usuario viu.
        local dropdownsFolder = window:GetElements().Dropdowns
        if type(dropdownsFolder) == "table" then
            local strayVisible = false
            for _, kid in ipairs(dropdownsFolder:GetChildren()) do
                if kid.Visible then strayVisible = true end
            end
            check(not strayVisible, "com o dropdown fechado o popup nao fica visivel (sem box solto)")
        end

        check(multi.Opened ~= true, "o dropdown nasce fechado")
        -- O click abre. Se `aC` (flag de fechamento) ficar preso true, o OpenDropdown
        -- recusa -- diagnostico primeiro.
        holder.Activated:Fire()
        check(multi.Opened == true, "clicar no campo ABRE o dropdown (Opened=true) [Opened="
            .. tostring(multi.Opened) .. " type=" .. type(holder.Activated) .. "]")
        -- O popup tem que ganhar pai (a pasta Dropdowns) pra renderizar.
        if type(dropdownsFolder) == "table" then
            local found = false
            for _, kid in ipairs(dropdownsFolder:GetChildren()) do
                if kid.Visible then found = true end
            end
            check(found, "o popup do dropdown aparece com um filho visivel ao abrir")
        end
        holder.Activated:Fire()
        check(multi.Opened == false, "clicar de novo FECHA o dropdown (Opened=false)")
    end

    -- GEOMETRIA: com a pasta Dropdowns exposta, provamos que o popup que abriu    -- tem pai certo, esta visivel com altura > 0 e cai dentro da tela. Era
    -- exatamente o que faltava: o teste antigo so olhava GetElements().Dropdowns,
    -- que nunca existiu -- entao as assercoes de visibilidade eram puladas em
    -- silencio e o bug do popup passou.
    do
        local geo = tab:AddDropdown({Name = "Geo", Options = {"Z", "X", "C", "V", "F"}, Default = {"F"}, MultiSelect = true})
        local geoFolder = window:GetElements().Dropdowns
        check(type(geoFolder) == "table", "a pasta Dropdowns e alcancavel por GetElements")

        -- Geometria realista: o campo fica no canto inferior direito do painel.
        -- O popup ancora no CAMPO (o frame 150x18 dentro da linha), nao na linha:
        -- `X.SetHolder(aH)` no AddDropdown. Localiza-lo e o que o teste precisa
        -- fazer para medir a posicao de verdade.
        local geoRow = geo.VISIBLE_ELEMENT
        geoRow.AbsolutePosition = {X = 1100, Y = 600}
        geoRow.AbsoluteSize = {X = 300, Y = 24}
        local geoHolder
        do
            local function findField(node)
                for _, kid in ipairs(node._kids or {}) do
                    if kid.ClassName == "Frame" and (kid.Size and kid.Size.X.Offset or 0) >= 100
                        and (kid.Size and kid.Size.Y.Offset or 0) <= 24 then
                        return kid
                    end
                    local found = findField(kid)
                    if found then return found end
                end
                return nil
            end
            geoHolder = findField(geoRow)
        end
        check(geoHolder ~= nil, "o teste localiza o campo clicavel do dropdown")
        geoHolder.AbsolutePosition = {X = 1157, Y = 600}
        geoHolder.AbsoluteSize = {X = 150, Y = 18}
        geoRow.Activated:Fire()
        check(geo.Opened == true, "o dropdown de geometria abre")

        local openChild
        for _, kid in ipairs(geoFolder:GetChildren()) do
            if kid.Visible then openChild = kid end
        end
        check(openChild ~= nil, "o popup fica parentado na pasta Dropdowns ao abrir")
        if openChild then
            -- O popup real e o overlay `ar`, que contem o frame "Dropdown".
            local frame = openChild:FindFirstChildRecursive("Dropdown") or openChild
            local sizeY = frame.Size and frame.Size.Y or nil
            if sizeY then
                check((sizeY.Offset or 0) > 0 or (sizeY.Scale or 0) > 0,
                    "o popup tem altura diferente de zero (nao sai invisivel)")
            end
            local posX = frame.Position and frame.Position.X
            -- O ANCHOR e o critério que o bug quebrava: o popup e parentado FORA
            -- do UIScale do painel, entao a posicao tem que ser a do CAMPO em
            -- pixels de tela crus. A versao antiga dividia por `ad.Scale` (>= 1)
            -- e o popup caia a esquerda do campo -- "abre deslocado / nao aparece".
            -- Aqui o campo esta em X=1157: a posicao tem que bater com ele (com
            -- folga de 1 px), nao com 1157/escala.
            if posX then
                local x = posX.Offset or 0
                check(math.abs(x - 1157) <= 1,
                    "o popup abre alinhado ao campo em X cru (campo 1157, popup " .. tostring(x) .. ")")
                check(x <= 1920, "o popup fica dentro da tela (x=" .. tostring(x) .. ")")
            end
        end

        geoRow.Activated:Fire()
        check(geo.Opened == false, "o dropdown de geometria fecha")
        local stillVisible = false
        for _, kid in ipairs(geoFolder:GetChildren()) do
            if kid.Visible then stillVisible = true end
        end
        check(not stillVisible, "ao fechar nenhum popup fica visivel na pasta Dropdowns")
    end

    -- CONTEUDO DO POPUP: o usuario reporta que o multi-dropdown (exception keys,
    -- Skip/Keep) nao aparece, mas o dropdown SIMPLES (Island) funciona. Aqui
    -- abrimos o popup do multi e conferimos que ele realmente renderiza LINHAS de
    -- opcao (nao so um frame vazio) e que a posicao/tamanho fazem sentido.
    do
        local probe = tab:AddDropdown({Name = "ContentProbe", Options = {"Alpha", "Beta", "Gamma"}, Default = {"Alpha"}, MultiSelect = true})
        local probeFolder = window:GetElements().Dropdowns
        local probeRow = probe.VISIBLE_ELEMENT
        probeRow.AbsolutePosition = {X = 1100, Y = 600}
        probeRow.AbsoluteSize = {X = 300, Y = 24}
        -- O CAMPO e o frame 150x18 dentro da linha.
        local function findField(node)
            for _, kid in ipairs(node._kids or {}) do
                if kid.ClassName == "Frame" and (kid.Size and kid.Size.X.Offset or 0) >= 100
                    and (kid.Size and kid.Size.Y.Offset or 0) <= 24 then
                    return kid
                end
                local found = findField(kid)
                if found then return found end
            end
            return nil
        end
        local probeField = findField(probeRow)
        if probeField then
            probeField.AbsolutePosition = {X = 1157, Y = 600}
            probeField.AbsoluteSize = {X = 150, Y = 18}
        end
        probeRow.Activated:Fire()
        check(probe.Opened == true, "o multi-dropdown de conteudo abre")

        -- Conta as linhas de opcao dentro do popup: cada opcao e um TextButton
        -- cujo TextLabel filho carrega o nome da opcao (o texto NAO fica no
        -- TextButton em si -- fica no TextLabel; o probe antigo procurava no
        -- lugar errado e contava zero).
        local function countOptions(node, depth)
            local count = 0
            if depth > 6 then return 0 end
            for _, kid in ipairs(node._kids or {}) do
                if kid.ClassName == "TextLabel" then
                    local t = kid.Text
                    if t == "Alpha" or t == "Beta" or t == "Gamma" then count = count + 1 end
                end
                count = count + countOptions(kid, depth + 1)
            end
            return count
        end
        local popupChild
        for _, kid in ipairs(probeFolder:GetChildren()) do
            if kid.Visible then popupChild = kid end
        end
        local rendered = popupChild and countOptions(popupChild, 0) or 0
        check(rendered >= 3, "o popup do multi-dropdown renderiza as 3 linhas de opcao [rendered=" .. tostring(rendered) .. "]")

        probeRow.Activated:Fire()
        check(probe.Opened == false, "o multi-dropdown de conteudo fecha")
    end

    -- MULTI vs SIMPLES pelo CAMPO: o usuario so ve o dropdown simples (Island)
    -- funcionar. Os dois tem que abrir com o texto do default no campo, e o
    -- restore (Clear + Add) tem que produzir a selecao pedida -- nao uma sobra da
    -- anterior. A lib guarda a selecao num CONJUNTO interno que o CLEAR_DROPDOWN
    -- nao zera; reaplicar uma config sobre uma selecao ja existente perderia
    -- itens. Este teste trava isso.
    do
        local function fieldText(row)
            local function findField(node)
                for _, kid in ipairs(node._kids or {}) do
                    if kid.ClassName == "Frame" and (kid.Size and kid.Size.X.Offset or 0) >= 100 then
                        return kid
                    end
                    local f = findField(kid)
                    if f then return f end
                end
                return nil
            end
            local field = findField(row)
            if not field then return nil end
            for _, kid in ipairs(field._kids or {}) do
                if kid.ClassName == "TextLabel" then return kid.Text end
            end
            return nil
        end

        local single = tab:AddDropdown({Name = "SingleD", Options = {"One", "Two"}, Default = "One"})
        check(fieldText(single.VISIBLE_ELEMENT) == "One", "o dropdown simples abre com o default no campo")

        local mm = tab:AddDropdown({Name = "MultiD", Options = {"Alpha", "Beta", "Gamma"}, Default = {"Alpha"}, MultiSelect = true})
        check(fieldText(mm.VISIBLE_ELEMENT) == "Alpha", "o multi-dropdown abre com o default no campo")

        -- Restore: trocar a selecao de {Alpha} para {Beta, Gamma} tem que deixar
        -- EXATAMENTE esses dois -- nem Alpha sobrando, nem vazio. O caminho real do
        -- restore e Clear + Add + Select (o Add nao seleciona; o Select sim).
        mm:Clear()
        mm:Add("Beta")
        mm:Add("Gamma")
        if type(mm.Select) == "function" then
            mm:Select("Beta", true)
            mm:Select("Gamma", true)
        end
        -- O rotulo do campo e atualizado por um debounce de 100ms (task.delay), que
        -- no harness e no-op; entao conferimos o ESTADO da selecao (a opcao marcada),
        -- que e o que o rotulo vai refletir no jogo.
        local function isSelected(handle, name)
            for _, option in ipairs(handle.DROPDOWN_OPTIONS or {}) do
                if option.Name == name then return option.Selected == true end
            end
            return false
        end
        check(isSelected(mm, "Beta") and isSelected(mm, "Gamma"),
            "o restore marca as opcoes pedidas")
        check(not isSelected(mm, "Alpha"),
            "e NAO deixa sobra da selecao anterior (Alpha desmarcado)")

        if type(mm.Select) == "function" then
            mm:Select("Gamma", false)
            check(not isSelected(mm, "Gamma"), "o Select(false) desmarca a opcao")
        end
    end

    -- RESTORE (nivel da lib): reaplicar uma selecao salva com Clear + Add tem que
    -- deixar o dropdown de pe e com opcoes.
    do
        local names = {}
        for _, option in ipairs(multi.DROPDOWN_OPTIONS) do names[#names + 1] = option.Name end
        check(#names >= 1, "o dropdown multi expoe as opcoes para o restore")
        local okRestore = pcall(function()
            if type(multi.Set) == "function" then
                multi:Set({"Dragon"})
            elseif type(multi.CLEAR_DROPDOWN) == "function" then
                multi.CLEAR_DROPDOWN()
                multi.ADD_DROPDOWN_OPTION("Dragon")
            end
        end)
        check(okRestore, "reaplicar a selecao salva nao estoura")
        local after = 0
        for _, option in ipairs(multi.DROPDOWN_OPTIONS or {}) do after = after + 1 end
        check(after >= 1, "depois do restore o dropdown ainda tem opcoes")
    end

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

        -- The fixed large size is written where the real library reads it.
        local appliedSize = ui.Library.Default and ui.Library.Default.UISize
        check(appliedSize and appliedSize.X.Offset == 900 and appliedSize.Y.Offset == 500, "the shell applies the 900x500 size")

        local mainFrame = ui.Window:GetElements().MainFrame
        local inputService = renderServices.UserInputService
        local visibleBefore = mainFrame.Visible
        inputService.InputBegan:Fire({
            KeyCode = renderEnum.KeyCode.B,
            UserInputType = renderEnum.UserInputType.Keyboard
        }, true)
        check(mainFrame.Visible ~= visibleBefore, "tecla B alterna o painel mesmo quando o executor marca a entrada como processada")
        local visibleAfter = mainFrame.Visible
        inputService.InputBegan:Fire({
            KeyCode = renderEnum.KeyCode.N,
            UserInputType = renderEnum.UserInputType.Keyboard
        }, false)
        check(mainFrame.Visible == visibleAfter, "tecla antiga N nao alterna o painel")

        local shellTab = ui:CreateTab("Auto Farm", "Farm", "sprout")
        check(type(shellTab) == "table", "the shell creates a tab with a named icon")
        check(shellTab.Key == "Farm|Auto Farm", "the tab records its category key")
        check(ui:CreateTab("Auto Farm", "Farm") == shellTab, "the shell reuses the same tab")

        local shellSection = shellTab:CreateSection("FRUIT")
        check(type(shellSection) == "table", "the shell creates a section")
        check(type(shellSection:CreateToggle("Auto collect", true)) == "table", "section CreateToggle works")
        check(type(shellSection:CreateSlider("Range", 10, 200, 55)) == "table", "section CreateSlider works")
        check(type(shellSection:CreateDropdown("Island", {"One", "Two"}, "One")) == "table", "section CreateDropdown works")
        local restored = nil
        local multiHandle = shellSection:CreateMultiDropdown("Skip list", {"Dragon", "Leopard"}, {"Dragon"}, function(sel) restored = sel end)
        check(type(multiHandle) == "table", "section CreateMultiDropdown works")
        check(type(multiHandle.Set) == "function", "the multi-dropdown handle exposes Set for restore")
        -- O config-store prefere o `Set` do handle ao `apply` do registro sempre
        -- que o handle "pode dirigir" -- e um handle multi nao tem `.Value`, entao
        -- `Value ~= valor` e sempre true. Sem o callback dentro do `Set`, restaurar
        -- uma config moveria a UI mas NUNCA avisaria a feature (as exception keys
        -- do silent aim ficariam as antigas). Prova que o restore dispara.
        multiHandle:Set({"Leopard"})
        check(type(restored) == "table" and restored[1] == "Leopard" and #restored == 1,
            "o Set do multi-dropdown dispara o callback com o array selecionado")
        multiHandle:Set({"Dragon", "Leopard"})
        check(type(restored) == "table" and #restored == 2,
            "o Set devolve as duas opcoes na ordem da lista")
        check(type(shellSection:CreateButton("Go", function() end)) == "table", "section CreateButton works")
        check(type(shellSection:CreateParagraph("Info", "Body")) == "table", "section CreateParagraph works")
        local input = shellSection:CreateInput("Command", "placeholder", "")
        check(type(input) == "table" and type(input.Control) == "table", "section CreateInput returns a control record")
        -- O handle de input expoe Set/SetValue proprios (o contrato que o
        -- config-store procura em todo handle): sem isso, um valor salvo num
        -- campo de texto nao voltava pra tela.
        check(type(input.Set) == "function", "o handle de input expoe Set")
        check(type(input.SetValue) == "function", "o handle de input expoe SetValue")
        input:Set("novo comando")
        check(input.Value == "novo comando", "Set atualiza o Value do handle")
        local textboxText = input.Control.TEXTBOX and input.Control.TEXTBOX.Text
        check(textboxText == "novo comando", "Set empurra o texto pro textbox real do controle")
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

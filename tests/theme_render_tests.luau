-- Real theme smoke test.
--
-- The backend harness stubs demon-theme.luau (DOD_LIBRARY_STUB) and its Instance
-- double deliberately rejects GUI classes, so nothing else in the suite ever
-- loads the real src/core/ui/demon-theme.luau. That meant a regression in the
-- theme could pass every test and only show up in-game.
--
-- This block fills the gap: it loads the REAL theme source, compiles it, runs
-- export.new(...) against a permissive Roblox double, then creates a
-- category/tab/section and a couple of controls and destroys the window. It
-- does not claim in-game fidelity -- it claims the module loads and builds.
do
    local ThemeColor3 = {}
    local colorMeta = {
        __eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end,
    }
    function ThemeColor3.new(r, g, b)
        r, g, b = r or 0, g or 0, b or 0
        local c = {R = r, G = g, B = b, __color = true}
        function c:Lerp(other, t)
            return ThemeColor3.new(r + (other.R - r) * t, g + (other.G - g) * t, b + (other.B - b) * t)
        end
        function c:ToHSV()
            local max = math.max(r, g, b)
            local min = math.min(r, g, b)
            local h, s = 0, max == 0 and 0 or (max - min) / max
            if max ~= min then
                if max == r then h = (g - b) / (max - min) % 6
                elseif max == g then h = (b - r) / (max - min) + 2
                else h = (r - g) / (max - min) + 4 end
                h = h / 6
            end
            return h, s, max
        end
        function c:ToHex() return "FFFFFF" end
        return setmetatable(c, colorMeta)
    end
    function ThemeColor3.fromRGB(r, g, b) return ThemeColor3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
    function ThemeColor3.fromHSV(h, s, v)
        return ThemeColor3.new(v or 0, v or 0, v or 0)
    end

    local ThemeUDim = {}
    function ThemeUDim.new(scale, offset) return {Scale = scale or 0, Offset = offset or 0} end

    local ThemeUDim2 = {}
    local udim2Meta = {}
    udim2Meta.__index = udim2Meta
    function udim2Meta:Lerp(other, t)
        return ThemeUDim2.new(
            self.X.Scale + (other.X.Scale - self.X.Scale) * t,
            self.X.Offset + (other.X.Offset - self.X.Offset) * t,
            self.Y.Scale + (other.Y.Scale - self.Y.Scale) * t,
            self.Y.Offset + (other.Y.Offset - self.Y.Offset) * t)
    end
    function ThemeUDim2.new(xs, xo, ys, yo)
        return setmetatable({__udim2 = true, X = ThemeUDim.new(xs, xo), Y = ThemeUDim.new(ys, yo)}, udim2Meta)
    end
    function ThemeUDim2.fromOffset(x, y) return ThemeUDim2.new(0, x, 0, y) end
    function ThemeUDim2.fromScale(x, y) return ThemeUDim2.new(x, 0, y, 0) end

    local function themeSignal()
        local event = {connections = {}, fired = 0}
        function event:Connect(fn)
            local connection = {Connected = true, fn = fn}
            function connection:Disconnect() self.Connected = false end
            self.connections[#self.connections + 1] = connection
            return connection
        end
        function event:Once(fn)
            local connection
            connection = self:Connect(function(...) connection:Disconnect(); fn(...) end)
            return connection
        end
        function event:Fire(...)
            event.fired += 1
            for _, connection in ipairs(table.clone(self.connections)) do
                if connection.Connected then connection.fn(...) end
            end
        end
        return event
    end

    local ThemeVector2 = {}
    local vector2Meta = {}
    vector2Meta.__index = vector2Meta
    local function v2num(n) return type(n) == "number" and n or 0 end
    vector2Meta.__add = function(a, b) return ThemeVector2.new(v2num(a.X) + v2num(b.X), v2num(a.Y) + v2num(b.Y)) end
    vector2Meta.__sub = function(a, b) return ThemeVector2.new(v2num(a.X) - v2num(b.X), v2num(a.Y) - v2num(b.Y)) end
    vector2Meta.__mul = function(a, b)
        if type(a) == "number" then return ThemeVector2.new(a * v2num(b.X), a * v2num(b.Y)) end
        if type(b) == "number" then return ThemeVector2.new(v2num(a.X) * b, v2num(a.Y) * b) end
        return ThemeVector2.new(v2num(a.X) * v2num(b.X), v2num(a.Y) * v2num(b.Y))
    end
    vector2Meta.__div = function(a, b)
        if type(b) == "number" then return ThemeVector2.new(v2num(a.X) / b, v2num(a.Y) / b) end
        return ThemeVector2.new(0, 0)
    end
    vector2Meta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
    function ThemeVector2.new(x, y) return setmetatable({X = x or 0, Y = y or 0, Magnitude = math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2)}, vector2Meta) end
    function ThemeVector2.zero() return ThemeVector2.new(0, 0) end

    local themeInstanceMeta = {}
    local themeMethods = {}

    -- A permissive wildcard for any property/method the theme touches that the
    -- double does not model. It is callable (so `obj:SomeMethod()` works), indexable
    -- (so `obj.Something.X` works) and does arithmetic as 0 (so `width * 0.96`
    -- stays a number). This lets the whole GUI tree build without enumerating
    -- every Roblox property; the test asserts the build succeeds, not pixel maths.
    local wildcardMeta = {}
    local wildcard = setmetatable({}, wildcardMeta)
    wildcardMeta.__index = function() return wildcard end
    wildcardMeta.__call = function() return wildcard end
    wildcardMeta.__add = function(a, b) return (type(a) == "number" and a or 0) + (type(b) == "number" and b or 0) end
    wildcardMeta.__sub = function(a, b) return (type(a) == "number" and a or 0) - (type(b) == "number" and b or 0) end
    wildcardMeta.__mul = function(a, b) return (type(a) == "number" and a or 0) * (type(b) == "number" and b or 0) end
    wildcardMeta.__div = function(a, b) return (type(b) == "number" and b ~= 0) and ((type(a) == "number" and a or 0) / b) or 0 end
    wildcardMeta.__unm = function() return 0 end
    wildcardMeta.__len = function() return 0 end
    wildcardMeta.__eq = function() return true end
    wildcardMeta.__lt = function() return false end
    wildcardMeta.__le = function() return true end
    wildcardMeta.__tostring = function() return "" end
    wildcardMeta.__concat = function(a, b) return tostring(a) .. tostring(b) end

    -- Property reads the theme compares or does arithmetic on must return the
    -- right *kind* of value, or `wildcard <= 0` blows up (Luau will not run a
    -- table-vs-number `__le`). Vector2-typed GUI properties yield a Vector2;
    -- a few scalar ones yield 0. Everything else falls back to the wildcard,
    -- which is fine for enums, Color3 and instance references.
    local VECTOR_PROPS = {
        AbsoluteCanvasSize = true, AbsoluteContentSize = true, AbsolutePosition = true,
        AbsoluteSize = true, CanvasPosition = true, CanvasSize = true,
        ViewportSize = true, WindowSize = true, TextBounds = true,
        MaxSize = true, MinSize = true, AnchorPoint = true,
    }
    local NUMBER_PROPS = {
        BackgroundTransparency = true, TextTransparency = true, TextStrokeTransparency = true,
        ImageTransparency = true, Rotation = true, Thickness = true, ZIndex = true,
        LayoutOrder = true, CellPadding = true, CellSize = true, ScrollBarThickness = true,
        ScrollBarImageTransparency = true, TextSize = true, MaxTextSize = true, MinTextSize = true,
        PaddingLeft = true, PaddingRight = true, PaddingTop = true, PaddingBottom = true,
        PlaybackSpeed = true, Volume = true, Magnitude = true, Scale = true, Offset = true,
    }

    function themeInstanceMeta:__index(key)
        if key == "Parent" then return self._props.Parent end
        local own = self._props[key]
        if own ~= nil then return own end
        local method = themeMethods[key]
        if method ~= nil then return method end
        if VECTOR_PROPS[key] then return ThemeVector2.new(0, 0) end
        if NUMBER_PROPS[key] then return 0 end
        return wildcard
    end
    function themeInstanceMeta:__newindex(key, value)
        if key == "Parent" then
            local old = self._props.Parent
            if old then
                for i, child in ipairs(old._children) do
                    if child == self then table.remove(old._children, i) break end
                end
            end
            self._props.Parent = value
            if value then value._children[#value._children + 1] = self end
        else
            self._props[key] = value
        end
    end
    function themeMethods:GetChildren() return table.clone(self._children) end
    function themeMethods:GetDescendants()
        local result = {}
        for _, child in ipairs(self._children) do
            result[#result + 1] = child
            for _, descendant in ipairs(child:GetDescendants()) do result[#result + 1] = descendant end
        end
        return result
    end
    function themeMethods:FindFirstChild(name) for _, c in ipairs(self._children) do if c._props.Name == name then return c end end end
    function themeMethods:FindFirstChildOfClass(class) for _, c in ipairs(self._children) do if c._props.ClassName == class then return c end end end
    function themeMethods:FindFirstChildWhichIsA(class) return self:FindFirstChildOfClass(class) end
    function themeMethods:WaitForChild(name) return self:FindFirstChild(name) end
    function themeMethods:IsA(class)
        local actual = self._props.ClassName
        if class == actual then return true end
        if class == "GuiObject" then
            return actual == "Frame" or actual == "TextLabel" or actual == "TextButton"
                or actual == "ImageLabel" or actual == "ImageButton" or actual == "ScrollingFrame"
                or actual == "TextBox" or actual == "CanvasGroup"
        end
        if class == "BasePart" then return actual == "Part" or actual == "MeshPart" end
        return false
    end
    function themeMethods:IsDescendantOf(ancestor)
        local parent = self._props.Parent
        while parent do if parent == ancestor then return true end; parent = parent._props.Parent end
        return false
    end
    function themeMethods:GetPropertyChangedSignal(property)
        self._propertySignals = self._propertySignals or {}
        self._propertySignals[property] = self._propertySignals[property] or themeSignal()
        return self._propertySignals[property]
    end
    function themeMethods:GetAttribute(key) return self._attributes[key] end
    function themeMethods:SetAttribute(key, value) self._attributes[key] = value end
    function themeMethods:GetAttributes() return table.clone(self._attributes) end
    function themeMethods:Destroy()
        self.Destroyed = true
        for _, child in ipairs(self:GetChildren()) do child:Destroy() end
        self.Parent = nil
    end
    function themeMethods:ClearAllChildren() for _, child in ipairs(self:GetChildren()) do child:Destroy() end end
    function themeMethods:Clone() return ThemeInstance.new(self._props.ClassName) end
    function themeMethods:GetFullName() return self._props.Name or self._props.ClassName end
    function themeMethods:Play() self.Playing = true end
    function themeMethods:Stop() self.Playing = false end

    local ThemeInstance = {}
    local themeInstanceCount = 0
    function ThemeInstance.new(class)
        themeInstanceCount += 1
        if themeInstanceCount > 20000 then
            error("[theme-double] Instance.new called " .. themeInstanceCount .. " times -- likely an unbounded init loop (class=" .. tostring(class) .. ")", 2)
        end
        local object = setmetatable({
            _props = {ClassName = class, Name = class, Visible = true, Text = "", Parent = nil, AbsoluteSize = ThemeVector2.new(900, 580)},
            _children = {},
            _attributes = {},
        }, themeInstanceMeta)
        object.ChildAdded = themeSignal()
        object.ChildRemoved = themeSignal()
        object.DescendantAdded = themeSignal()
        object.DescendantRemoving = themeSignal()
        object.Changed = themeSignal()
        object.AncestryChanged = themeSignal()
        object.InputBegan = themeSignal()
        object.InputEnded = themeSignal()
        object.InputChanged = themeSignal()
        object.MouseButton1Click = themeSignal()
        object.MouseEnter = themeSignal()
        object.MouseLeave = themeSignal()
        object.MouseMoved = themeSignal()
        object.Activated = themeSignal()
        object.Focused = themeSignal()
        object.FocusLost = themeSignal()
        object.ReturnPressedFromOnScreenKeyboard = themeSignal()
        object.Ended = themeSignal()
        object.Completed = themeSignal()
        return object
    end

    local ThemeEnum = setmetatable({}, {__index = function(t, key)
        local values = setmetatable({}, {__index = function(s, name)
            local item = {Name = name, EnumType = s, Value = name, __enumItem = true}
            rawset(s, name, item)
            return item
        end})
        rawset(t, key, values)
        return values
    end})

    -- Services are plain tables, not theme instances, so give each the
    -- property-changed signal the theme binds (for example MouseIconEnabled).
    local function withPropSignals(service)
        local signals = {}
        service.GetPropertyChangedSignal = function(_, property)
            signals[property] = signals[property] or themeSignal()
            return signals[property]
        end
        return service
    end

    local function themeTypeof(value)
        if type(value) == "table" then
            if value.__color then return "Color3" end
            if value.__enumItem then return "EnumItem" end
            if value.__udim2 then return "UDim2" end
            if value.__udim then return "UDim" end
            if value.__tweenInfo then return "TweenInfo" end
            if value.ClassName then return "Instance" end
        end
        local builtin = typeof
        return builtin(value)
    end

    local ThemeTweenInfo = {}
    function ThemeTweenInfo.new(...) return {__tweenInfo = true, args = {...}} end

    local themeServices = {}
    local themePlayer = ThemeInstance.new("Player")
    themePlayer.UserId = 1
    themePlayer.Name = "TestPlayer"
    themePlayer.DisplayName = "TestPlayer"
    themePlayer.CharacterAdded = themeSignal()
    themePlayer.CharacterRemoving = themeSignal()
    themePlayer.Idled = themeSignal()
    themePlayer.ChildAdded = themeSignal()
    themePlayer.ChildRemoved = themeSignal()
    themePlayer.CameraMaxZoomDistance = 128

    local players = {LocalPlayer = themePlayer, PlayerAdded = themeSignal(), PlayerRemoving = themeSignal()}
    function players:GetPlayers() return {themePlayer} end
    function players:GetPlayerFromCharacter() return themePlayer end
    function players:GetUserIdFromNameAsync() return 1 end
    function players:GetNameFromUserIdAsync() return "TestPlayer" end

    local runService = {RenderStepped = themeSignal(), Stepped = themeSignal(), Heartbeat = themeSignal(), PreRender = themeSignal(), PreSimulation = themeSignal(), PostSimulation = themeSignal()}
    function runService:IsClient() return true end
    function runService:IsStudio() return false end
    function runService:IsRunning() return true end

    local userInput = {
        InputBegan = themeSignal(), InputEnded = themeSignal(), InputChanged = themeSignal(),
        TouchEnabled = false, MouseEnabled = true, KeyboardEnabled = true, MouseBehavior = ThemeEnum.MouseBehavior.Default,
    }
    function userInput:GetMouseLocation() return ThemeVector2.new(400, 300) end
    function userInput:GetFocusedTextBox() return nil end
    function userInput:IsKeyDown() return false end
    function userInput:GetKeysPressed() return {} end

    local coreGui = ThemeInstance.new("CoreGui")
    coreGui.Name = "CoreGui"

    local lighting = ThemeInstance.new("Lighting")
    lighting.Name = "Lighting"
    lighting.ClockTime = 14
    lighting.Brightness = 2
    lighting.Ambient = ThemeColor3.fromRGB(70, 70, 70)
    lighting.OutdoorAmbient = ThemeColor3.fromRGB(70, 70, 70)

    local workspaceService = ThemeInstance.new("Workspace")
    workspaceService.Name = "Workspace"
    workspaceService.Gravity = 196.2
    workspaceService.CurrentCamera = ThemeInstance.new("Camera")
    workspaceService.CurrentCamera.Name = "Camera"
    workspaceService.CurrentCamera.CFrame = {__cframe = true}
    function workspaceService:Raycast() return nil end

    local tweenService = {}
    function tweenService:Create(_, object, info, goal)
        local tween = {Play = function() end, Cancel = function() end, Pause = function() end, Completed = themeSignal()}
        return tween
    end

    local marketplace = {}
    function marketplace:GetProductInfo() return {Name = "Test", PriceInRobux = 0} end

    local textService = {}
    function textService:GetTextSize(text, size) return ThemeVector2.new(#tostring(text) * size * 0.5, size) end

    local httpService = {}
    function httpService:JSONEncode(value) return "{}" end
    function httpService:JSONDecode(value) return {} end
    function httpService:GenerateGUID() return "00000000-0000-0000-0000-000000000000" end
    function httpService:UrlEncode(value) return tostring(value) end

    local statsService = {}
    function statsService:GetTotalMemoryUsageMb() return 512 end
    statsService.ChildAdded = themeSignal()

    local soundService = ThemeInstance.new("SoundService")
    soundService.Name = "SoundService"

    local teleportService = {}
    function teleportService:Teleport() end
    function teleportService:TeleportToPlaceInstance() end

    themeServices = {
        Players = withPropSignals(players), RunService = withPropSignals(runService), UserInputService = withPropSignals(userInput),
        CoreGui = coreGui, Lighting = lighting, Workspace = workspaceService,
        TweenService = withPropSignals(tweenService), MarketplaceService = withPropSignals(marketplace),
        TextService = withPropSignals(textService), HttpService = withPropSignals(httpService), Stats = withPropSignals(statsService),
        SoundService = soundService, TeleportService = withPropSignals(teleportService),
        ReplicatedStorage = ThemeInstance.new("ReplicatedStorage"),
        TextChatService = ThemeInstance.new("TextChatService"),
        Teams = ThemeInstance.new("Teams"),
    }

    local themeGame = {PlaceId = 1, GameId = 2, JobId = "theme-smoke"}
    function themeGame:GetService(name) return themeServices[name] or ThemeInstance.new(name) end
    function themeGame:IsLoaded() return true end
    function themeGame:GetFullName() return "Game" end
    function themeGame:HttpGet(url)
        -- The theme pulls the optional Icons library from GitHub, then fetches each
        -- split part through the same resolver path. Both are served locally so the
        -- smoke test stays offline; any other fetch fails loudly.
        if tostring(url):find("Icons", 1, true) then
            return "return {SetIconsType=function() end, GetIcon=function() return nil end}"
        end
        local rel = tostring(url):gsub("^https://raw.githubusercontent.com/glowpkj/DepHub/main/", ""):gsub("%?.*$", "")
        if _THEME_PARTS and _THEME_PARTS[rel] then return _THEME_PARTS[rel] end
        error("Unexpected HTTP in theme smoke test: " .. tostring(url))
    end
    function themeGame:HttpGetAsync(url) return self:HttpGet(url) end
    function themeGame:GetObjects() return {} end

    local themeEnv = {}
    themeEnv.game = themeGame
    themeEnv.workspace = workspaceService
    themeEnv.Enum = ThemeEnum
    themeEnv.Instance = ThemeInstance
    themeEnv.Color3 = ThemeColor3
    themeEnv.ColorSequence = {new = function(a, b) return {__colorSequence = true, Color = a, Color2 = b} end}
    themeEnv.ColorSequenceKeypoint = {new = function(t, c) return {Time = t, Value = c, __colorSequence = true} end}
    themeEnv.NumberSequence = {new = function(a, b) return {__numberSequence = true, Value = a, Value2 = b} end}
    themeEnv.NumberSequenceKeypoint = {new = function(t, v) return {Time = t, Value = v, __numberSequence = true} end}
    themeEnv.NumberRange = {new = function(a, b) return {Min = a or 0, Max = b or a or 0} end}
    themeEnv.UDim = ThemeUDim
    themeEnv.UDim2 = ThemeUDim2
    themeEnv.Vector2 = ThemeVector2
    themeEnv.Vector3 = {new = function(x, y, z) return {X = x or 0, Y = y or 0, Z = z or 0, __vector = true} end}
    themeEnv.CFrame = {new = function(...) return {__cframe = true} end, lookAt = function() return {__cframe = true} end, Angles = function() return {__cframe = true} end}
    themeEnv.TweenInfo = ThemeTweenInfo
    themeEnv.RaycastParams = {new = function() return {FilterDescendantsInstances = {}} end}
    themeEnv.Rect = {new = function(...) return setmetatable({}, {__index = function() return 0 end}) end}
    themeEnv.typeof = themeTypeof
    themeEnv.type = type
    themeEnv.math = math
    themeEnv.table = table
    themeEnv.string = string
    themeEnv.os = os
    themeEnv.pcall = pcall
    themeEnv.xpcall = xpcall
    themeEnv.error = error
    themeEnv.assert = assert
    themeEnv.tostring = tostring
    themeEnv.tonumber = tonumber
    themeEnv.ipairs = ipairs
    themeEnv.pairs = pairs
    themeEnv.next = next
    themeEnv.select = select
    themeEnv.unpack = table.unpack
    themeEnv.setmetatable = setmetatable
    themeEnv.getmetatable = getmetatable
    themeEnv.rawget = rawget
    themeEnv.rawset = rawset
    themeEnv.tick = function() return os.clock() end
    themeEnv.time = function() return os.clock() end
    themeEnv.wait = function() end
    themeEnv.spawn = function(fn, ...) return fn end
    themeEnv.delay = function(_, fn, ...) return fn end
    themeEnv.setfenv = function(fn, env2)
        if type(fn) == "function" then setfenv(fn, env2) end
        return fn
    end
    themeEnv.gethui = function() return coreGui end
    themeEnv.getcustomasset = function(p) return "rbxasset://" .. tostring(p) end
    themeEnv.identifyexecutor = function() return "ThemeSmoke", "1.0" end
    themeEnv.request = function() return {StatusCode = 200, Body = "{}"} end
    themeEnv["typeof"] = themeTypeof
    themeEnv.loadstring = function(source)
        local fn, err = loadstring(source)
        if fn then setfenv(fn, themeEnv) end
        return fn, err
    end

    -- Single flat environment the theme chunk runs in. `getgenv`/`getfenv` return
    -- it so the theme's `(getgenv and getgenv()) or _G` pattern resolves here.
    local themeEnvSel = themeEnv
    themeEnvSel._G = themeEnvSel
    themeEnvSel.getgenv = function() return themeEnvSel end
    themeEnvSel.getfenv = function() return themeEnvSel end

    -- Task scheduler double. Deferred work is QUEUED, not run inline: the theme
    -- starts watchdog/restore loops with task.spawn/defer, and running those
    -- synchronously during construction never terminates. The queue is flushed a
    -- bounded number of times after the window is built.
    local themeDeferred = {}
    local themeWaitCount = 0
    themeEnvSel.task = {
        wait = function()
            themeWaitCount += 1
            if themeWaitCount > 5000 then
                error("[theme-double] task.wait called " .. themeWaitCount .. " times -- unbounded init loop", 2)
            end
        end,
        cancel = function() end,
        defer = function(fn, ...) themeDeferred[#themeDeferred + 1] = {fn = fn, args = {...}} end,
        delay = function(_, fn, ...) themeDeferred[#themeDeferred + 1] = {fn = fn, args = {...}} end,
        spawn = function(fn, ...) themeDeferred[#themeDeferred + 1] = {fn = fn, args = {...}}; return fn end,
    }
    themeEnvSel.FlushThemeDeferred = function(rounds)
        for _ = 1, rounds or 4 do
            local pending = themeDeferred
            themeDeferred = {}
            for _, entry in ipairs(pending) do
                pcall(entry.fn, table.unpack(entry.args))
            end
            if #themeDeferred == 0 then break end
        end
    end

    local themeSource = assert(_THEME_SOURCE, "theme source not injected")
    local themeChunk, themeCompileError = themeEnvSel.loadstring(themeSource)
    check(themeChunk ~= nil, "demon-theme.luau compiles: " .. tostring(themeCompileError))

    local themeOk, themeExport = pcall(themeChunk)
    check(themeOk, "demon-theme.luau runs: " .. tostring(themeExport))
    check(type(themeExport) == "table", "demon-theme.luau returns a table export")
    check(type(themeExport.new) == "function", "export.new is a function")
    check(type(themeExport.CreateWindow) == "function", "export.CreateWindow is a function")
    check(type(themeExport.Themes) == "table", "export.Themes is a table")
    check(type(themeExport.WeatherTypes) == "table", "export.WeatherTypes is a table")
    check(type(themeExport.FocusOverlayTypes) == "table", "export.FocusOverlayTypes is a table")

    -- Build a window exactly the way demon-ui.lua does.
    local buildOk, library = pcall(themeExport.new, {
        Title = "DepHub",
        Version = "0.0.0",
        Author = "DepHub",
        Theme = "Monochrome",
        TabPosition = "Side",
        CategoryAlign = "Center",
        ToggleKey = ThemeEnum.KeyCode.N,
        Acrylic = true,
        AcrylicBlur = 18,
        Size = ThemeUDim2.fromOffset(900, 580),
        ThemeAutoLoad = false,
        SoundsEnabled = true,
        Tooltip = true,
    })
    check(buildOk, "export.new builds a window: " .. tostring(library))
    check(type(library) == "table", "the built window is a table")
    check(type(library._STATE) == "table", "the window carries its _STATE")
    check(type(library._UI) == "table" and library._UI.MainContainer ~= nil, "the window built a main container")
    check(library._initialized == true, "the window finished initialising")

    -- Run the queued deferred work (watchdog/restore kicks) a bounded number of
    -- rounds; a healthy window settles, it never keeps queueing forever.
    themeEnvSel.FlushThemeDeferred(4)

    -- Theming, navigation and a real tab/section/control round trip.
    check(pcall(function() library:CreateCategory("General", "layers") end), "CreateCategory succeeds")
    local tab = library:CreateTab("General", "Smoke")
    check(tab ~= nil and library._STATE.ContentPages["Smoke"] ~= nil, "CreateTab registers a content page")
    local section = library:CreateSection("Smoke", "Settings", nil, true, "Left", "layers")
    check(section ~= nil, "CreateSection returns a section")
    check(pcall(function() library:AddToggle(section, "Enabled", false, function() end) end), "AddToggle builds a control")
    check(pcall(function() library:AddSlider(section, "Amount", 0, 100, 50, 0, function() end) end), "AddSlider builds a control")
    check(pcall(function() library:AddButton(section, "Run", function() end) end), "AddButton builds a control")

    local dashboardTab = library:CreateStandaloneTab("Dashboard", "house")
    check(dashboardTab ~= nil and library._STATE.ContentPages["Dashboard"] ~= nil, "Dashboard standalone destination registers a content page")
    check(library._STATE.CategoryButtons.Dashboard.isStandalone == true, "Dashboard is not nested inside General")
    check(library._STATE.TabCategories.Dashboard == "Dashboard", "Dashboard owns its top-level navigation category")
    local configurableToggle = library:AddToggle(section, "Configurable", false, function() end)
    local toggleSettings = configurableToggle:CreateSettings("CONFIGURAÇÕES")
    check(type(toggleSettings) == "table" and type(toggleSettings.CreateSlider) == "function", "toggle exposes expandable settings controls")
    for _, method in ipairs({"CreateToggle", "CreateSlider", "CreateDropdown", "CreateButton", "CreateInput", "CreateParagraph", "CreateKeybind", "CreateMultiDropdown", "CreateColorPicker", "CreateLabel", "CreateSeparator", "CreateChipBar"}) do
        check(type(toggleSettings[method]) == "function", "toggle settings expose " .. method)
    end
    local invalidImport = library:ImportConfig("invalid")
    check(invalidImport == false, "ImportConfig rejects non-table payloads")
    local validImport, appliedImport, totalImport = library:ImportConfig({_controls = "invalid"}, true)
    check(validImport == true and appliedImport == 0 and totalImport == 0, "ImportConfig safely ignores malformed control maps")
    check(pcall(function() library:CreateDashboardBanner("Dashboard") end), "CreateDashboardBanner builds the dashboard banner")
    check(pcall(function() library:CreatePerformanceDashboard("Dashboard", "Right") end), "CreatePerformanceDashboard builds the dashboard metrics")
    -- The banner reads _STATE.TabTopContainers[tabName], so its presence proves
    -- the tab really exists where the dashboard builders look for it.
    check(library._STATE.TabTopContainers ~= nil and library._STATE.TabTopContainers["Dashboard"] ~= nil, "Dashboard tab has a top container")

    -- Mouse ownership is scoped to the panel being open. MouseBehavior belongs to
    -- the game's camera controller and is never snapshotted/restored: doing that
    -- re-locked the pointer to the centre on close whenever the game had been
    -- holding LockCenter -- the "mouse travado" bug. Only MouseIconEnabled is ours
    -- while open, and close always returns a visible cursor.
    -- The window starts open, so close it first to reach the closed state.
    if library._STATE.GuiVisible then library:Toggle() end
    library._STATE.AnimatingGui = false
    check(library._STATE.GuiVisible == false, "the window starts open and closes on first toggle")

    -- Simulate a game that hides its cursor and locks it to the centre while play
    -- is in progress (first person / aiming), then open the panel.
    userInput.MouseIconEnabled = false
    userInput.MouseBehavior = ThemeEnum.MouseBehavior.LockCenter
    library:Toggle() -- open: must free the mouse and take over cursor visibility
    check(userInput.MouseBehavior == ThemeEnum.MouseBehavior.Default, "opening frees the mouse")
    check(userInput.MouseIconEnabled == false, "opening hides the OS cursor behind the custom one")
    runService.RenderStepped:Fire(0.016)
    check(userInput.MouseBehavior == ThemeEnum.MouseBehavior.Default, "an open panel keeps the mouse free")

    library._STATE.AnimatingGui = false
    library:Toggle() -- close: hand the mouse back to the game and show a cursor
    check(userInput.MouseIconEnabled == true, "closing hands back a visible cursor")
    check(userInput.MouseBehavior == ThemeEnum.MouseBehavior.Default,
        "closing never re-locks the mouse to the game's old LockCenter")

    -- While the panel is closed nothing may touch the mouse, so hovering the
    -- restore pill can no longer hide the OS cursor out from under the game.
    userInput.MouseIconEnabled = true
    userInput.MouseBehavior = ThemeEnum.MouseBehavior.LockCenter -- the game re-locks it itself
    runService.RenderStepped:Fire(0.016)
    check(userInput.MouseIconEnabled == true, "a closed panel leaves the cursor visible")
    check(userInput.MouseBehavior == ThemeEnum.MouseBehavior.LockCenter,
        "a closed panel leaves the game's mouse behaviour alone")

    check(pcall(function() library:SetTheme("Monochrome") end), "SetTheme succeeds")
    check(pcall(function() library:Notify("T", "M") end), "Notify succeeds")
    check(pcall(function() library:Destroy() end), "Destroy succeeds")
    check(library._STATE.Destroyed == true, "Destroy marks the window destroyed")
end

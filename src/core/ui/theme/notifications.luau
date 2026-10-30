--[[
  NOTIFICATIONS + config save/load/import/export

  Split out of src/core/ui/demon-theme.luau (original lines 1779-2488).
  The body below is the original section, unchanged except for the shared
  reduced-motion flag (ctx.SharedReduced.value). The orchestrator loads this
  part with a shared context; it adds methods to the one Library table.
]]
local __CTX = ...
local SharedReduced = __CTX.SharedReduced
local Library = __CTX.Library
local D = __CTX.D
local Fn = __CTX.Fn
local GetIcon = __CTX.GetIcon
local getCam = __CTX.getCam
local GetGuiParent = __CTX.GetGuiParent
local findInGuiParents = __CTX.findInGuiParents
local GuiParent = __CTX.GuiParent
local TweenService = __CTX.TweenService
local GuiSound = __CTX.GuiSound
local Players = __CTX.Players
local RunService = __CTX.RunService
local MarketplaceService = __CTX.MarketplaceService
local Stats = __CTX.Stats
local UserInputService = __CTX.UserInputService
local CoreGui = __CTX.CoreGui
local Lighting = __CTX.Lighting
local SoundService = __CTX.SoundService
local LocalPlayer = __CTX.LocalPlayer
local IconsV2 = __CTX.IconsV2
local WEATHER_PRESETS = __CTX.WEATHER_PRESETS
local randomFloat = __CTX.randomFloat
local SubTabModule = __CTX.SubTabModule
local SUBTAB_DEFAULT_THEME = __CTX.SUBTAB_DEFAULT_THEME

-- =========================================================
-- NOTIFICATIONS
-- =========================================================

function Library:_initNotifications()
    local gui = Instance.new("ScreenGui")
    gui.Name = "DoD_UI_Notifications"
    gui.Parent = GuiParent
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 2000
    self._UI.NotifGui = gui
end

function Library:SetNotificationPosition(pos)
    if self:_isDead() then return end
    self._NotifPosition = tostring(pos or "TopRight")
    self:_updateNotifPositions()
end

function Library:SetFavoritesOnly(enabled)
    if self:_isDead() then return end
    self._STATE.FavoritesOnly = enabled and true or false
    local icon = self._UI.FavoritesToggleIcon
    if icon then
        TweenService:Create(icon, TweenInfo.new(0.15), {
            ImageColor3 = self._STATE.FavoritesOnly and self._Colors.Accent or self._Colors.TextDim,
            ImageTransparency = self._STATE.FavoritesOnly and 0 or 0.4,
        }):Play()
    end
    if self._STATE.FavoritesOnly then
        local count = 0
        for _ in pairs(self._STATE.Favorites or {}) do count = count + 1 end
        if count == 0 then
            self:Notify("FAVORITES", "No favorites yet — right-click any control to add one", "info")
        end
    end
    self:_applySearchFilter()
end

function Library:Confirm(title, text, onYes, onNo)
    if self:_isDead() then return end
    if not self._UI.MainContainer or not self._UI.MainContainer.Parent then return end
    -- Drop any stale modal first: the old guard returned while this cleanup was
    -- unreachable, so one interrupted Confirm locked the API forever.
    if self._ActiveConfirm then
        pcall(function() self._ActiveConfirm:Destroy() end)
        self._ActiveConfirm = nil
    end
    self._ConfirmAnimating = true

    local overlay = Instance.new("TextButton")
    overlay.Name = "DoD_ConfirmOverlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 1
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.ZIndex = 9500
    -- Parented to MainContainer (not the ScreenGui) so closing/minimising the
    -- window takes the modal with it instead of leaving a full-screen click trap.
    overlay.Parent = self._UI.MainContainer

    local _cCam = getCam()
    local _cVpX = (_cCam and _cCam.ViewportSize.X) or 800
    local _cVpY = (_cCam and _cCam.ViewportSize.Y) or 600
    local _cMob = self._isMobile
    local _cPanelW = math.min(340, _cVpX - 24)
    local _cPanelH = _cMob and math.min(200, _cVpY - 24) or 176
    local _cPad = 16
    local _cGap = 8
    local _cBtnW = _cMob and math.floor((_cPanelW - _cPad * 2 - _cGap) / 2) or 148
    local _cBtnH = _cMob and 44 or 34
    local panel = Instance.new("Frame", overlay)
    panel.Size = UDim2.fromOffset(_cPanelW, _cPanelH)
    panel.Position = UDim2.new(0.5, 0, 0.5, 30)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BackgroundColor3 = self._Colors.Bg2
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ZIndex = 9501
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    local panelStroke = Instance.new("UIStroke", panel)
    panelStroke.Color = self._Colors.Accent
    panelStroke.Thickness = 1
    panelStroke.Transparency = 0.2
    panelStroke.ZIndex = 9501

    local icon = Instance.new("ImageLabel", panel)
    icon.Size = UDim2.fromOffset(28, 28)
    icon.Position = UDim2.new(0, 16, 0, 16)
    icon.BackgroundTransparency = 1
    icon.Image = GetIcon("alert-triangle")
    icon.ImageColor3 = self._Colors.Accent
    icon.ImageTransparency = 1
    icon.ZIndex = 9502

    local titleLbl = Instance.new("TextLabel", panel)
    titleLbl.Size = UDim2.new(1, -58, 0, 22)
    titleLbl.Position = UDim2.new(0, 52, 0, 18)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = tostring(title or "Confirm")
    titleLbl.TextColor3 = self._Colors.Text
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTransparency = 1
    titleLbl.ZIndex = 9502

    local textLbl = Instance.new("TextLabel", panel)
    textLbl.Size = UDim2.new(1, -32, 0, 60)
    textLbl.Position = UDim2.new(0, 16, 0, 48)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = tostring(text or "")
    textLbl.TextColor3 = self._Colors.TextDim
    textLbl.Font = Enum.Font.GothamMedium
    textLbl.TextSize = 11
    textLbl.TextWrapped = true
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.TextYAlignment = Enum.TextYAlignment.Top
    textLbl.TextTransparency = 1
    textLbl.ZIndex = 9502

    local cancel = Instance.new("TextButton", panel)
    cancel.Size = UDim2.fromOffset(_cBtnW, _cBtnH)
    cancel.Position = UDim2.new(0, _cPad, 1, -(_cBtnH + _cPad))
    cancel.BackgroundColor3 = self._Colors.Card
    cancel.Text = "Cancel"
    cancel.TextColor3 = self._Colors.Text
    cancel.Font = Enum.Font.GothamBold
    cancel.TextSize = 12
    cancel.AutoButtonColor = false
    cancel.ZIndex = 9502
    Instance.new("UICorner", cancel).CornerRadius = UDim.new(0, 8)

    local cancelStroke = Instance.new("UIStroke", cancel)
    cancelStroke.Color = self._Colors.Border
    cancelStroke.Thickness = 1
    cancelStroke.ZIndex = 9502

    local confirm = Instance.new("TextButton", panel)
    confirm.Size = UDim2.fromOffset(_cBtnW, _cBtnH)
    confirm.Position = UDim2.new(1, -(_cBtnW + _cPad), 1, -(_cBtnH + _cPad))
    confirm.BackgroundColor3 = self._Colors.Accent
    confirm.Text = "Confirm"
    confirm.TextColor3 = Fn.accentTextColor(self._Colors.Accent)
    confirm.Font = Enum.Font.GothamBold
    confirm.TextSize = 12
    confirm.AutoButtonColor = false
    confirm.ZIndex = 9502
    Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 8)

    local confirmStroke = Instance.new("UIStroke", confirm)
    confirmStroke.Color = self._Colors.Accent
    confirmStroke.Thickness = 1
    confirmStroke.ZIndex = 9502

    Fn.bindPressAnimation(cancel)
    Fn.bindPressAnimation(confirm)

    local closed = false
    local function close(confirmed)
        if closed then return end
        closed = true
        self._ConfirmAnimating = false
        if self._ActiveConfirm == overlay then self._ActiveConfirm = nil end
        TweenService:Create(overlay, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
        local info = TweenInfo.new(0.15)
        TweenService:Create(panel, info, {BackgroundTransparency = 1}):Play()
        TweenService:Create(titleLbl, info, {TextTransparency = 1}):Play()
        TweenService:Create(textLbl, info, {TextTransparency = 1}):Play()
        TweenService:Create(icon, info, {ImageTransparency = 1}):Play()
        TweenService:Create(cancel, info, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        TweenService:Create(confirm, info, {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        task.delay(0.18, function()
            if overlay.Parent then overlay:Destroy() end
            if self._ActiveConfirm == overlay then self._ActiveConfirm = nil end
            self._ConfirmAnimating = false
            if self:_isDead() then return end
            if confirmed then
                if onYes then
                    local ok, err = pcall(onYes)
                    if not ok then warn("[DoD UI] Confirm onYes failed: " .. tostring(err)) end
                end
            else
                if onNo then
                    local ok, err = pcall(onNo)
                    if not ok then warn("[DoD UI] Confirm onNo failed: " .. tostring(err)) end
                end
            end
        end)
    end

    cancel.MouseButton1Click:Connect(function() close(false) end)
    confirm.MouseButton1Click:Connect(function() close(true) end)
    overlay.MouseButton1Click:Connect(function() close(false) end)

    self._ActiveConfirm = overlay

    TweenService:Create(overlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.4}):Play()
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }):Play()
    TweenService:Create(titleLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(textLbl, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
    TweenService:Create(icon, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()

    return overlay
end

function Library:_updateNotifPositions()
    local pos = self._NotifPosition or "TopRight"
    for index, frame in ipairs(self._STATE.activeNotifs) do
        local targetY = 15 + ((index - 1) * 65)
        local targetX = UDim2.new(1, -282, 0, targetY)
        
        if pos == "TopLeft" then
            targetX = UDim2.new(0, 15, 0, targetY)
        elseif pos == "BottomLeft" then
            targetX = UDim2.new(0, 15, 1, -targetY - 56)
        elseif pos == "BottomRight" then
            targetX = UDim2.new(1, -282, 1, -targetY - 56)
        end
        
        TweenService:Create(
            frame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {Position = targetX}
        ):Play()
    end
end

function Library:ExportConfig()
    if self:_isDead() then return {} end
    local out = { _version = self.Version, _theme = self.ThemeName, _controls = {}, _timestamp = os.time() }
    local failures = 0
    for id, entry in pairs(self._STATE.ConfigRegistry or {}) do
        local ok, val = pcall(entry.get)
        if ok and val ~= nil then
            out._controls[id] = val
        elseif not ok then
            -- Track failures instead of silently writing an incomplete config.
            failures = failures + 1
        end
    end
    self._lastExportFailures = failures
    out._favorites = {}
    for id, val in pairs(self._STATE.Favorites or {}) do
        if val then table.insert(out._favorites, id) end
    end
    return out
end

function Library:ImportConfig(config, silent)
    if self:_isDead() or type(config) ~= "table" then return false, 0, 0 end
    if config._theme and D.Themes[config._theme] then
        self:SetTheme(config._theme, true)
    end
    if type(config._favorites) == "table" then
        table.clear(self._STATE.Favorites)
        for _, id in ipairs(config._favorites) do
            if type(id) == "string" then
                self._STATE.Favorites[id] = true
            end
        end
        for id in pairs(self._STATE.FavoriteStars or {}) do
            self:_updateFavoriteStar(id)
        end
        self:_applySearchFilter()
    end
    local applied, total = 0, 0
    local controls = type(config._controls) == "table" and config._controls or {}
    for id, val in pairs(controls) do
        total = total + 1
        local entry = self._STATE.ConfigRegistry and self._STATE.ConfigRegistry[id]
        if entry and entry.set then
            -- The setter's second argument means "do not fire the user callback".
            -- It used to be hard-coded true, so loading a config only repainted
            -- the widgets and never applied anything to the script that owns them.
            local ok = pcall(entry.set, val, silent == true)
            if ok then applied = applied + 1 end
        end
    end
    if not silent then
        local complete = applied == total
        self:Notify("CONFIG", "Imported " .. applied .. "/" .. total .. " settings", complete and "success" or "warning")
    end
    return true, applied, total
end

function Library:GetConfigs(force)
    if self._configsCache and not force then
        return self._configsCache
    end
    local configs = {}
    local prefix = "DoD_UI_"
    local suffix = ".json"
    
    pcall(function()
        if listfiles and type(listfiles) == "function" then
            for _, file in ipairs(listfiles()) do
                local base = string.match(tostring(file), "[^\\/]+$") or tostring(file)
                if string.sub(base, 1, #prefix) == prefix and string.sub(base, -#suffix) == suffix then
                    local ok, content = pcall(readfile, file)
                    local timestamp = 0
                    if ok and content then
                        local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(content) end)
                        if ok2 and data and data._timestamp then
                            timestamp = data._timestamp
                        end
                    end
                    local name = string.match(base, "^" .. prefix .. "(.+)%.json$")
                        or string.sub(base, #prefix + 1, #base - #suffix)
                    table.insert(configs, { name = name, file = file, time = timestamp })
                end
            end
        end
        -- Always merge the in-memory store, so configs saved on executors without
        -- a filesystem still show up.
        local g = (getgenv and getgenv()) or _G
        if g.__DoDConfigs then
            local seen = {}
            for _, entry in ipairs(configs) do seen[entry.name] = true end
            for name, json in pairs(g.__DoDConfigs) do
                if not seen[name] then
                    local timestamp = 0
                    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(json) end)
                    if ok and data and data._timestamp then
                        timestamp = data._timestamp
                    end
                    table.insert(configs, { name = name, file = nil, time = timestamp })
                end
            end
        end
    end)

    table.sort(configs, function(a, b)
        return (a.time or 0) > (b.time or 0)
    end)

    self._configsCache = configs
    return configs
end

function Library:SaveConfig(name, silent)
    if self:_isDead() then return false end
    if type(name) ~= "string" or name == "" then return false end
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then return false end
    
    local g = (getgenv and getgenv()) or _G

    local data = self:ExportConfig()
    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if not ok or type(json) ~= "string" then
        if not silent then self:Notify("CONFIG", "JSON encode failed", "error") end
        return false
    end
    local path = "DoD_UI_" .. name .. ".json"
    -- Mirror to memory too, then report honestly whether the file write worked.
    g.__DoDConfigs = g.__DoDConfigs or {}
    g.__DoDConfigs[name] = json
    local fileOk = false
    pcall(function()
        if writefile and type(writefile) == "function" then
            writefile(path, json)
            fileOk = true
        end
    end)
    g.DoD_LastConfig = name
    self._configsCache = nil
    if not silent then
        if fileOk then
            self:Notify("CONFIG", "Saved: " .. name, "success")
        else
            self:Notify("CONFIG", "Saved (memory only): " .. name, "warning")
        end
    end
    return true
end

function Library:LoadConfig(name, silent)
    if self:_isDead() then return end
    if type(name) ~= "string" or name == "" then return end
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then return end
    local path = "DoD_UI_" .. name .. ".json"
    local json = nil
    pcall(function()
        if isfile and type(isfile) == "function" and readfile and type(readfile) == "function" then
            if isfile(path) then json = readfile(path) end
        end
    end)
    if not json then
        local g = (getgenv and getgenv()) or _G
        if g.__DoDConfigs and g.__DoDConfigs[name] then
            json = g.__DoDConfigs[name]
        end
    end
    if type(json) ~= "string" then
        if not silent then self:Notify("CONFIG", "Not found: " .. name, "warning") end
        return false
    end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(json)
    end)
    if not ok or type(data) ~= "table" then
        if not silent then self:Notify("CONFIG", "Decode failed", "error") end
        return false
    end
    local imported = self:ImportConfig(data, silent)
    return imported == true
end

function Library:EnableAutoSave(name)
    if self:_isDead() then return end
    if type(name) ~= "string" or name == "" then return end
    self._STATE.ConfigAutoSave = { name = name }
    self:SaveConfig(name, true)
end

function Library:DisableAutoSave()
    if self:_isDead() then return end
    self._STATE.ConfigAutoSave = nil
end

function Library:Notify(title, text, notifyType)
    local STATE = self._STATE
    if STATE.Destroyed then return end
    title = tostring(title or "")
    text = tostring(text or "")
    notifyType = tostring(notifyType or "info")
    
    if STATE.NotifActive >= STATE.NotifMax then
        local queue = STATE.NotifQueue
        table.insert(queue, { title = title, text = text, nType = notifyType })
        -- When the backlog is full, drop informational toasts before errors, so
        -- the messages that actually matter survive a burst.
        while #queue > 10 do
            local dropIndex = 1
            for i, entry in ipairs(queue) do
                if entry.nType ~= "error" and entry.nType ~= "warning" then
                    dropIndex = i
                    break
                end
            end
            table.remove(queue, dropIndex)
        end
        return
    end
    STATE.NotifActive = STATE.NotifActive + 1
    self:PlaySound("Notify")

    task.spawn(function()
        local ok, err = pcall(function()
        if STATE.Destroyed or not self._UI.NotifGui or not self._UI.NotifGui.Parent then
            return
        end
        local palette = self._Colors or {}
        local accent = palette.Accent or Color3.fromRGB(180, 180, 195)
        
        local iconId = GetIcon("info")
        local color = accent
        
        if notifyType == "success" then
            color = Color3.fromRGB(52, 211, 153)
            iconId = GetIcon("check-circle")
        elseif notifyType == "error" then
            color = Color3.fromRGB(248, 113, 113)
            iconId = GetIcon("x-circle")
        elseif notifyType == "warning" then
            color = Color3.fromRGB(251, 191, 36)
            iconId = GetIcon("alert-triangle")
        end

        local nPos = self._NotifPosition or "TopRight"
        local spawnPos = UDim2.new(1, -295, 0, -70)
        if nPos == "TopLeft" then spawnPos = UDim2.new(0, -295, 0, 15)
        elseif nPos == "BottomLeft" then spawnPos = UDim2.new(0, -295, 1, -71)
        elseif nPos == "BottomRight" then spawnPos = UDim2.new(1, -295, 1, -71)
        end

        local frame = Instance.new("Frame", self._UI.NotifGui)
        frame.Size = UDim2.new(0, 280, 0, 56)
        frame.Position = spawnPos
        frame.BackgroundColor3 = palette.Bg2 or Color3.fromRGB(14, 14, 20)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.ClipsDescendants = true
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

        local frameStroke = Instance.new("UIStroke", frame)
        frameStroke.Color = color
        frameStroke.Thickness = 1
        frameStroke.Transparency = 0.4

        local icon = Instance.new("ImageLabel", frame)
        icon.Size = UDim2.fromOffset(16, 16)
        icon.Position = UDim2.new(0, 12, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = iconId
        icon.ImageColor3 = color

        local titleLabel = Instance.new("TextLabel", frame)
        titleLabel.Size = UDim2.new(1, -40, 0, 20)
        titleLabel.Position = UDim2.new(0, 36, 0, 7)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        titleLabel.TextColor3 = palette.Text or Color3.fromRGB(220, 220, 230)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local textLabel = Instance.new("TextLabel", frame)
        textLabel.Size = UDim2.new(1, -40, 0, 18)
        textLabel.Position = UDim2.new(0, 36, 0, 28)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = palette.TextDim or Color3.fromRGB(140, 140, 155)
        textLabel.Font = Enum.Font.GothamMedium
        textLabel.TextSize = 11
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.TextTruncate = Enum.TextTruncate.AtEnd

        local progressBar = Instance.new("Frame", frame)
        progressBar.Size = UDim2.new(1, -4, 0, 2)
        progressBar.Position = UDim2.new(0, 4, 1, -2)
        progressBar.BackgroundColor3 = color
        progressBar.BorderSizePixel = 0

        local accentBar = Instance.new("Frame", frame)
        accentBar.Name = "AccentBar"
        accentBar.Size = UDim2.new(0, 3, 1, -8)
        accentBar.Position = UDim2.new(0, 4, 0, 4)
        accentBar.BackgroundColor3 = color
        accentBar.BorderSizePixel = 0
        accentBar.ZIndex = 2
        Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

        STATE.notifParts[frame] = {
            stroke = frameStroke,
            accentBar = accentBar,
            progressBar = progressBar,
            titleLabel = titleLabel,
            textLabel = textLabel,
        }

        table.insert(STATE.activeNotifs, frame)
        self:_updateNotifPositions()
        TweenService:Create(frame, TweenInfo.new(0.25), {BackgroundTransparency = 0.1}):Play()

        TweenService:Create(
            progressBar,
            TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 0, 0, 2)}
        ):Play()

        task.wait(2.5)

        local index = table.find(STATE.activeNotifs, frame)
        if index then table.remove(STATE.activeNotifs, index) end
        if STATE.Destroyed or not frame.Parent then
            STATE.notifParts[frame] = nil
            if frame.Parent then frame:Destroy() end
            return
        end
        self:_updateNotifPositions()

        TweenService:Create(titleLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
        TweenService:Create(textLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
        TweenService:Create(icon, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
        TweenService:Create(frameStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()

        local exitX = UDim2.new(1, 15, 0, frame.Position.Y.Offset)
        if nPos == "TopLeft" or nPos == "BottomLeft" then
            exitX = UDim2.new(0, -300, 0, frame.Position.Y.Offset)
        end
        if nPos == "BottomLeft" or nPos == "BottomRight" then
            exitX = UDim2.new(exitX.X.Scale, exitX.X.Offset, 1, frame.Position.Y.Offset)
        end

        local out = TweenService:Create(
            frame,
            TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
            {Position = exitX, BackgroundTransparency = 1}
        )
        out:Play()
        -- Fixed wait instead of Completed:Wait(): a cancelled tween would suspend
        -- this coroutine forever, pinning the library and one notification slot.
        task.wait(0.35)
        STATE.notifParts[frame] = nil
        if frame.Parent then frame:Destroy() end
        end)
        if not ok then
            warn("[DoD UI] Notify failed: " .. tostring(err))
        end
        -- Exactly one slot is released here, on every exit path.
        STATE.NotifActive = math.max(0, STATE.NotifActive - 1)
        if not STATE.Destroyed then
            local nxt = table.remove(STATE.NotifQueue, 1)
            if nxt then self:Notify(nxt.title, nxt.text, nxt.nType) end
        end
    end)
end

function Library:ShowLoading(label)
    if self:_isDead() then return end
    local UI = self._UI
    if not UI.LoadingFrame or not UI.LoadingFrame.Parent then
        local frame = Instance.new("Frame", UI.MainContainer)
        frame.Name = "LoadingFrame"
        frame.Size = UDim2.fromOffset(220, 42)
        frame.Position = UDim2.new(1, -16, 1, -16)
        frame.AnchorPoint = Vector2.new(1, 1)
        frame.BackgroundColor3 = self._Colors.Bg2
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.ZIndex = 500
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", frame)
        stroke.Color = self._Colors.Accent
        stroke.Thickness = 1
        stroke.Transparency = 0.3
        stroke.ZIndex = 500
        local spinner = Instance.new("ImageLabel", frame)
        spinner.Name = "Spinner"
        spinner.Size = UDim2.fromOffset(20, 20)
        spinner.Position = UDim2.new(0, 10, 0.5, -10)
        spinner.BackgroundTransparency = 1
        spinner.Image = GetIcon("loader")
        spinner.ImageColor3 = self._Colors.Accent
        spinner.ZIndex = 501
        local lbl = Instance.new("TextLabel", frame)
        lbl.Name = "LoadingLabel"
        lbl.Size = UDim2.new(1, -42, 1, -6)
        lbl.Position = UDim2.new(0, 36, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(label or "Loading...")
        lbl.TextColor3 = self._Colors.Text
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.ZIndex = 501
        local bar = Instance.new("Frame", frame)
        bar.Name = "ProgressBar"
        bar.Size = UDim2.new(0, 0, 0, 2)
        bar.Position = UDim2.new(0, 4, 1, -3)
        bar.BackgroundColor3 = self._Colors.Accent
        bar.BorderSizePixel = 0
        bar.ZIndex = 501
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
        UI.LoadingFrame = frame
        UI.LoadingSpinner = spinner
        UI.LoadingLabel = lbl
        UI.LoadingBar = bar
        local angle = 0
        if self._loadingSpinConn then
            pcall(function() self._loadingSpinConn:Disconnect() end)
            self._loadingSpinConn = nil
        end
        self._loadingSpinConn = Fn.track(RunService.RenderStepped, function(dt)
            if SharedReduced.value then return end
            if not spinner or not spinner.Parent then
                if self._loadingSpinConn then
                    Fn.untrack(self._loadingSpinConn, self)
                    self._loadingSpinConn = nil
                end
                return
            end
            angle = (angle + dt * 360) % 360
            spinner.Rotation = angle
        end, self)
    else
        UI.LoadingLabel.Text = tostring(label or "Loading...")
        if UI.LoadingBar then UI.LoadingBar.Size = UDim2.new(0, 0, 0, 2) end
    end
end

function Library:SetProgress(value)
    if self:_isDead() then return end
    local bar = self._UI.LoadingBar
    if not bar or not bar.Parent then return end
    local v = math.clamp(tonumber(value) or 0, 0, 1)
    bar.Size = UDim2.new(v, 0, 0, 2)
end

function Library:HideLoading()
    if self:_isDead() then return end
    -- Stop the spinner before the early-out, otherwise a frame that was already
    -- unparented leaves the RenderStepped rotation running forever.
    if self._loadingSpinConn then
        pcall(function() Fn.untrack(self._loadingSpinConn, self) end)
        self._loadingSpinConn = nil
    end
    local frame = self._UI.LoadingFrame
    if not frame or not frame.Parent then return end
    local out = TweenService:Create(frame, TweenInfo.new(0.2), {BackgroundTransparency = 1})
    out:Play()
    out.Completed:Connect(function()
        if frame and frame.Parent then frame:Destroy() end
    end)
    self._UI.LoadingFrame = nil
    self._UI.LoadingSpinner = nil
    self._UI.LoadingLabel = nil
    self._UI.LoadingBar = nil
end


return true

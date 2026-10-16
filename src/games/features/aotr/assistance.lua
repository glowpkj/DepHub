-- Optional helpers adapted from aotr_corrigido_v3. Paths remain runtime assumptions.
local Feature = {}
function Feature.new(context)
    local self = {Jobs = {}, States = {}, Injuries = {}, Destroyed = false}
    local player = context.Player
    local function path(root, ...)
        for _, name in ipairs({...}) do root = root and root:FindFirstChild(name) end
        return root
    end
    local function report(name, message)
        self.States[name] = tostring(message)
        context.Warn(name .. ": " .. tostring(message))
    end
    local function stop(name)
        local job = self.Jobs[name]
        self.Jobs[name] = nil
        if job then
            job.Active = false
            if job.Connection then job.Connection:Disconnect() end
            if job.Thread then pcall(task.cancel, job.Thread) end
        end
    end
    local function restoreInjuries()
        for injury, entry in pairs(self.Injuries) do
            -- Do not put injuries from a previous character into the new character.
            if entry.Character == player.Character and entry.Parent.Parent then
                local ok, err = pcall(function() injury.Parent = entry.Parent end)
                if not ok then report("AntiInjury", err) end
            else pcall(function() injury:Destroy() end) end
        end
        self.Injuries = {}
    end
    local function invoke(...)
        local remote = path(game:GetService("ReplicatedStorage"), "Assets", "Remotes", "GET")
        if not remote or not remote:IsA("RemoteFunction") then error("Assets.Remotes.GET unavailable") end
        return remote:InvokeServer(...)
    end
    local function top()
        return path(player, "PlayerGui", "Interface", "HUD", "Main", "Top")
    end
    local function visible(gui)
        if not gui or not gui:IsA("GuiObject") then return false end
        local item = gui
        while item and item ~= player do
            if item:IsA("GuiObject") and not item.Visible then return false end
            if item:IsA("ScreenGui") and not item.Enabled then return false end
            item = item.Parent
        end
        return true
    end
    local ticks = {}
    function ticks.AutoBladeRefill(job)
        local character = player.Character
        local blade = path(character, "Rig_" .. player.Name, "LeftHand", "Blade_1")
        if not blade or not blade:IsA("BasePart") then return "waiting: Rig/LeftHand/Blade_1" end
        if blade.Transparency ~= 1 then job.Reloading = nil; return "blade equipped" end
        if character:GetAttribute("IFrames") ~= nil then return "waiting: IFrames" end
        local hud = top()
        local sets = path(hud and hud:FindFirstChild("Blade", true), "Sets")
        if not sets or not (sets:IsA("TextLabel") or sets:IsA("TextButton")) then return "waiting: Blade.Sets" end
        local available = tonumber(sets.Text:match("(%d+)%s*/"))
        if not available or available <= 0 then return "no blade sets / unreadable HUD" end
        if job.Character ~= character then job.Character = character; job.Reloading = nil end
        job.Reloading = job.Reloading or os.clock()
        if os.clock() - job.Reloading >= 30 then return "reload timeout; toggle off/on to retry" end
        invoke("Blades", "Reload")
        return "reload requested (unverified)"
    end
    function ticks.AntiInjury()
        local folder = path(player.Character, "Injuries")
        if not folder then return "waiting: Character.Injuries" end
        for _, injury in ipairs(folder:GetChildren()) do
            self.Injuries[injury] = {Parent = folder, Character = player.Character}
            injury.Parent = nil -- retained for restoration; never destroy current injuries
        end
        for injury, entry in pairs(self.Injuries) do
            if entry.Character ~= player.Character then
                pcall(function() injury:Destroy() end)
                self.Injuries[injury] = nil
            end
        end
        return "client injuries detached; server effect unverified"
    end
    function ticks.AutoGrabEscape(job)
        local buttons = path(player, "PlayerGui", "Interface", "Buttons")
        if not buttons then return "waiting: Interface.Buttons" end
        if job.Folder ~= buttons then
            if job.Connection then job.Connection:Disconnect() end
            job.Folder = buttons
            job.Connection = buttons.ChildAdded:Connect(function()
                if not job.Active or self.Destroyed then return end
                local ok, err = pcall(function()
                    local remote = path(game:GetService("ReplicatedStorage"), "Assets", "Remotes", "POST")
                    if not remote or not remote:IsA("RemoteEvent") then error("Assets.Remotes.POST unavailable") end
                    remote:FireServer("Attacks", "Slash_Escape")
                end)
                if not ok then report("AutoGrabEscape", err) end
            end)
        end
        return "listening: Buttons.ChildAdded (legacy trigger)"
    end
    function ticks.AutoRetry(job)
        local title = path(player, "PlayerGui", "Interface", "Rewards", "Main", "Info", "Main", "Buttons", "Retry", "Title")
        if not visible(title) or not (title:IsA("TextLabel") or title:IsA("TextButton")) then job.Requested = nil; return "waiting: visible Retry.Title" end
        if title.Text:find("STARTING", 1, true) or title.Text:find("(0/0)", 1, true) then job.Requested=nil; return "waiting: retry state" end
        if job.Requested == title then return "retry requested; waiting for next rewards screen" end
        invoke("Functions", "Retry", "Add")
        job.Requested = title
        return "retry requested (unverified)"
    end
    function self:SetToggle(name, enabled)
        if self.Destroyed then return false end
        if not ticks[name] and name ~= "AntiAFK" then return false end
        stop(name)
        if name == "AntiInjury" and not enabled then restoreInjuries() end
        self.States[name] = enabled and "starting" or "off"
        if not enabled then return true end
        local job = {Active = true}
        self.Jobs[name] = job
        if name == "AntiAFK" then
            job.Connection = player.Idled:Connect(function()
                if not job.Active or self.Destroyed then return end
                local ok, err = pcall(function()
                    local virtualUser = game:GetService("VirtualUser")
                    virtualUser:CaptureController()
                    virtualUser:ClickButton2(Vector2.new())
                end)
                if not ok then report(name, err) end
            end)
            self.States[name] = "listening: Idled"
        else
            job.Thread = task.spawn(function()
                while job.Active and not self.Destroyed do
                    local ok, status = pcall(ticks[name], job)
                    if not job.Active or self.Destroyed then return end
                    if ok then self.States[name] = status else report(name, status) end
                    task.wait(name == "AutoBladeRefill" and 1 or 0.5)
                end
            end)
        end
        return true
    end
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        for name in pairs(self.Jobs) do stop(name) end
        restoreInjuries()
    end
    return self
end
return Feature

local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Player: ESP, mobility (NoClip / Walk on Water / Speed / Jump), Haki keep-on, Anti-AFK.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local M = {}
M._esp = {}
M._espOn = false
M.config = {
    noclip = false, walkWater = false, speedOn = false, walkSpeed = 50, jumpOn = false, jumpPower = 120,
    ken = false, buso = false,
    antiAfk = true,
}
M._platform, M._hakiRunning = nil, false

local function hrp(ch) return ch and ch:FindFirstChild("HumanoidRootPart") end
local function myHrp() return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") end
local function myHum() return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") end

local function makeEsp(ch)
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 80, 80)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.6
    hl.Adornee = ch; hl.Parent = ch
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(120, 28); bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = ch:FindFirstChild("HumanoidRootPart") or ch; bb.Parent = ch
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1; lbl.Size = UDim2.fromScale(1, 1)
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11; lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextStrokeTransparency = 0.5; lbl.Parent = bb
    return { hl = hl, bb = bb, lbl = lbl, char = ch }
end

function M.others()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then t[#t + 1] = p end
    end
    return t
end

function M.setESP(on)
    M._espOn = on
    if not on then
        for _, e in pairs(M._esp) do pcall(function() e.hl:Destroy(); e.bb:Destroy() end) end
        M._esp = {}
    end
end

local function remotes() return RS:FindFirstChild("Remotes") end
function M.hakiLoop()
    if M._hakiRunning or not M._core then return end
    M._hakiRunning = true
    M._core.spawn(function()
        while M.config.ken or M.config.buso do
            local ch = LP.Character
            local r = remotes()
            if ch and r then
                local kenOn = LP:GetAttribute("KenActive") or ch:GetAttribute("KenActive")
                local busoOn = ch:GetAttribute("BusoEnabled") or LP:GetAttribute("BusoEnabled")
                if M.config.ken and not kenOn then
                    local ce = r:FindFirstChild("CommE")
                    if ce then pcall(function() ce:FireServer("Ken", true) end) end
                end
                if M.config.buso and not busoOn then
                    local cf = r:FindFirstChild("CommF_")
                    if cf then pcall(function() cf:InvokeServer("Buso") end) end
                end
            end
            task.wait(0.5)
        end
        M._hakiRunning = false
    end)
end
function M.setKen(on)
    M.config.ken = on
    if on then M.hakiLoop()
    else
        local r = remotes(); local ce = r and r:FindFirstChild("CommE")
        if ce and LP:GetAttribute("KenActive") then pcall(function() ce:FireServer("Ken", false) end) end
    end
end
function M.setBuso(on)
    M.config.buso = on
    if on then M.hakiLoop()
    else
        local ch = LP.Character; local r = remotes(); local cf = r and r:FindFirstChild("CommF_")
        if ch and cf and ch:GetAttribute("BusoEnabled") then pcall(function() cf:InvokeServer("Buso") end) end
    end
end

function M.setAntiAfk(on) M.config.antiAfk = on and true or false end

function M.stop()
    M.setESP(false)
    M.config.ken, M.config.buso = false, false
    if M._platform then M._platform:Destroy(); M._platform = nil end
    local h = myHum()
    if h then h.WalkSpeed = 16 end
end

function M.init(Core, UI)
    M._core = Core

    local VirtualUser = game:GetService("VirtualUser")
    Core.track(LP.Idled:Connect(function()
        if not M.config.antiAfk then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))

    local page = UI.page("Player")

    UI.toggle(page, "Player ESP", "Highlight players and show distance", false, function(s) M.setESP(s) end)

    UI.section(page, "MOBILITY")
    UI.toggle(page, "NoClip", "Walk through walls", false, function(s) M.config.noclip = s end)
    UI.toggle(page, "Walk on Water", "Invisible platform over water", false, function(s) M.config.walkWater = s end)
    UI.toggle(page, "Speed boost", "Faster walk speed", false, function(s) M.config.speedOn = s end)
    UI.slider(page, "Walk speed", "Speed value", 16, 300, M.config.walkSpeed, function(v) M.config.walkSpeed = v end)
    UI.toggle(page, "Super jump", "Higher jump", false, function(s) M.config.jumpOn = s end)
    UI.slider(page, "Jump power", "Jump value", 50, 500, M.config.jumpPower, function(v) M.config.jumpPower = v end)

    UI.section(page, "HAKI")
    UI.toggle(page, "Auto Ken", "Keep Observation Haki on (must be unlocked)", false, function(s) M.setKen(s) end)
    UI.toggle(page, "Auto Buso", "Keep Armament Haki on (must be unlocked)", false, function(s) M.setBuso(s) end)

    UI.section(page, "UTILITY")
    UI.toggle(page, "Anti-AFK", "Prevent the 20-min idle kick (on by default)", true, function(s) M.setAntiAfk(s) end)

    Core.track(RunService.Heartbeat:Connect(function()
        if not M._espOn then return end
        local mh = myHrp()
        for _, p in ipairs(M.others()) do
            local ch = p.Character
            if ch then
                local e = M._esp[p]
                if e and e.char ~= ch then pcall(function() e.hl:Destroy(); e.bb:Destroy() end); e, M._esp[p] = nil, nil end
                if not e then e = makeEsp(ch); M._esp[p] = e end
                local h = hrp(ch)
                local d = (h and mh) and math.floor((h.Position - mh.Position).Magnitude) or 0
                e.lbl.Text = p.Name .. "\n" .. d .. "m"
            end
        end
    end))

    Core.track(RunService.Stepped:Connect(function()
        if not M.config.noclip then return end
        local ch = LP.Character
        if ch then
            for _, part in ipairs(ch:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end))

    -- RenderStepped runs after the game's own controller, so our values win the frame.
    Core.track(RunService.RenderStepped:Connect(function()
        local h = myHum()
        if h then
            if M.config.speedOn then h.WalkSpeed = M.config.walkSpeed end
            if M.config.jumpOn then h.UseJumpPower = true; h.JumpPower = M.config.jumpPower end
        end
    end))

    Core.track(RunService.Heartbeat:Connect(function()
        local hp = myHrp()
        local h = myHum()
        -- Pause the platform while farming: Sea 3 submerged islands are underwater, and the
        -- platform would shove the character back up to the surface, away from the mobs.
        local farm = M._core and M._core.modules.farm
        local farming = farm and (farm._farmOn or farm._bossOn or farm._nearestOn)
        if M.config.walkWater and not farming and hp and h then
            local swimming = (h:GetState() == Enum.HumanoidStateType.Swimming)
            if swimming and not M._platform then
                M._platform = Instance.new("Part")
                M._platform.Size = Vector3.new(30, 1, 30); M._platform.Anchored = true
                M._platform.CanCollide = true; M._platform.Transparency = 1; M._platform.Parent = workspace
                M._waterY = hp.Position.Y - 1
            end
            if M._platform then
                M._platform.Position = Vector3.new(hp.Position.X, M._waterY, hp.Position.Z)
                if hp.Position.Y < M._waterY + 1 then
                    hp.CFrame = CFrame.new(hp.Position.X, M._waterY + 3, hp.Position.Z)
                end
            end
        elseif M._platform then
            M._platform:Destroy(); M._platform = nil
        end
    end))

    Core.register("player", M)
    return M
end

return M

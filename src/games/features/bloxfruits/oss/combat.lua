local dephub = (getgenv and getgenv() or _G).__DEPHUB_OSS_RUNTIME
local game = dephub.game
local task = dephub.task

-- Combat: auto-attack, kill aura, aimbot, bounty hunt.
-- Hits = RegisterAttack + RegisterHit, both need a server-validated hitId (see installCapture).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer

local M = {}
M.config = {
    range = 120, delay = 0.15,
    targetPlayers = true, playerRange = 60,
    fast = false,
    auraRange = 60, losCheck = true,
    aimSmooth = 0.15,
    clickInterval = 0.25,
    keys = { Z = true, X = true, C = false, V = false, F = false },
    followDist = 6, attack1v1 = false,
    spectate = false, aim = false,
}
M.lastHitId = nil
M._combo, M._hooked = 0, false
M._mobAuto, M._playerAuto, M._aura, M._autoClick, M._follow = false, false, false, false, false
M._wasSpectate = false

M.bounty = {
    noFriends = true, noCup = true,
    safePct = 20,
    invisKen = false,
    chatKill = false, chatMsg = "gg",
    maxTime = 20,
    team = "Both",
    method = "Nearest",
}
M._bountyOn, M._noStunOn = false, false
M._bountySkip = {}

local function net()
    local mods = RS:FindFirstChild("Modules")
    local n = mods and mods:FindFirstChild("Net")
    if not n then return end
    return n:FindFirstChild("RE/RegisterAttack"), n:FindFirstChild("RE/RegisterHit")
end
local function effDelay() return M.config.fast and 0.08 or M.config.delay end

function M.hrp() local ch = LP and LP.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end

local function isFishingRod(t)
    if not t then return false end
    local tip = t.ToolTip
    return (tip and (tostring(tip):find("Fishing") or tostring(tip):find("Rod"))) or t.Name:find("Rod") ~= nil
end
-- A fishing rod hijacks the RegisterAttack hook, so hits never land: unequip it before attacking.
local function ensureNotRod()
    local ch = LP.Character
    local eq = ch and ch:FindFirstChildOfClass("Tool")
    if eq and isFishingRod(eq) then
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
    end
end

local function losClear(fromPos, part, ignore)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = { LP.Character, ignore }
    return workspace:Raycast(fromPos, part.Position - fromPos, p) == nil
end

-- Steal a valid hitId from the game's own RegisterHit call. A forged id is rejected on fresh
-- accounts, so we hook __namecall and read the real one the client sends.
function M.installCapture()
    if M._hooked then return end
    if not (hookmetamethod and getnamecallmethod and checkcaller and newcclosure) then
        if M._core then M._core.warn("no hook API: hitId capture unavailable") end
        return
    end
    local _, RegisterHit = net()
    M._capturing = true
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if M._capturing and not checkcaller() and getnamecallmethod() == "FireServer" and self == RegisterHit then
            local a = table.pack(...)
            if a[4] ~= nil then M.lastHitId = a[4]
            elseif a.n == 1 and type(a[1]) == "string" then M.lastHitId = a[1] end
        end
        return old(self, ...)
    end))
    M._hooked = true
end

local function isRaidChip(t) return t.Name:find("Microchip") ~= nil end
local function reequipWeapon()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local tool = ch:FindFirstChildOfClass("Tool")
    if tool and (isFishingRod(tool) or isRaidChip(tool)) then tool = nil end
    if not tool then
        local bp = LP:FindFirstChild("Backpack")
        if bp then for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and not isFishingRod(t) and not isRaidChip(t) then tool = t; break end
        end end
    end
    if tool then
        pcall(function() hum:UnequipTools() end)
        task.wait(0.15)
        pcall(function() hum:EquipTool(tool) end)
    end
end
function M.setupHitId()
    M.installCapture()
    task.spawn(function()
        ensureNotRod()
        reequipWeapon()
        task.wait(0.5)
        if M.lastHitId then
            if M._core then M._core.info("hitId captured", tostring(M.lastHitId)) end
            return
        end
        local _, RegisterHit = net()
        if RegisterHit then
            local id = tostring(LP.UserId):sub(2, 4) .. tostring(coroutine.running()):sub(11, 15)
            pcall(function() RegisterHit:FireServer(id) end)
            M.lastHitId = id
            if M._core then M._core.warn("hitId fallback generated", tostring(id)) end
        end
    end)
end

function M.nearest(range)
    local hrp, folder = M.hrp(), workspace:FindFirstChild("Enemies")
    if not hrp or not folder then return end
    local best, bestD
    for _, e in ipairs(folder:GetChildren()) do
        local hum = e:FindFirstChildOfClass("Humanoid")
        local part = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
        if hum and hum.Health > 0 and part then
            local d = (part.Position - hrp.Position).Magnitude
            if d <= range and (not bestD or d < bestD) then best, bestD = e, d end
        end
    end
    return best
end

function M.nearestAny(range)
    local h = M.hrp(); if not h then return end
    local best, bestD
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") and d.Health > 0 then
            local model = d.Parent
            if model and model ~= LP.Character and not Players:GetPlayerFromCharacter(model) then
                local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if part then
                    local dd = (part.Position - h.Position).Magnitude
                    if dd <= (range or 1e9) and (not bestD or dd < bestD) then best, bestD = model, dd end
                end
            end
        end
    end
    return best
end

function M.nearestPlayer(range)
    local h = M.hrp()
    if not h then return end
    local best, bestD
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p ~= LP and p.Character
        local ph = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if ph and hum and hum.Health > 0 then
            local d = (ph.Position - h.Position).Magnitude
            if (not range or d <= range) and (not bestD or d < bestD) then best, bestD = ch, d end
        end
    end
    return best
end

function M.attackOnce(enemy)
    ensureNotRod()
    local RegisterAttack, RegisterHit = net()
    if not (RegisterAttack and RegisterHit and enemy) then return end
    local part = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
        or enemy:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    M._combo = (M._combo % 4) + 1
    RegisterAttack:FireServer(0.4, M._combo)
    RegisterHit:FireServer(part, {}, nil, M.lastHitId)   -- 4th arg = captured hitId; without it the hit is ignored
end

function M.attackMany(list)
    ensureNotRod()
    local RegisterAttack, RegisterHit = net()
    if not (RegisterAttack and RegisterHit) or #list == 0 then return end
    M._combo = (M._combo % 4) + 1
    RegisterAttack:FireServer(0.4, M._combo)
    for _, e in ipairs(list) do
        local part = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
        if part then RegisterHit:FireServer(part, {}, nil, M.lastHitId) end
    end
end

function M.playersInRange(range)
    local h, list = M.hrp(), {}
    if not h then return list end
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p ~= LP and p.Character
        local ph = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if ph and hum and hum.Health > 0 and (ph.Position - h.Position).Magnitude <= range then
            list[#list + 1] = ch
        end
    end
    return list
end
function M.attackPlayersInRange(range)
    for _, ch in ipairs(M.playersInRange(range)) do M.attackOnce(ch) end
end

function M.setMobAuto(on)
    M._mobAuto = on and true or false
    if M._mobAuto and M._core then
        M._core.spawn(function()
            while M._mobAuto do
                M.attackOnce(M.nearest(M.config.range))
                task.wait(effDelay())
            end
        end)
    end
end

function M.setPlayerAuto(on)
    M._playerAuto = on and true or false
    if M._playerAuto and M._core then
        M._core.spawn(function()
            while M._playerAuto do
                M.attackPlayersInRange(M.config.playerRange)
                task.wait(effDelay())
            end
        end)
    end
end

function M.setAura(on)
    M._aura = on and true or false
    if M._aura and M._core then
        M._core.spawn(function()
            while M._aura do
                local h, folder = M.hrp(), workspace:FindFirstChild("Enemies")
                if h and folder then
                    local list = {}
                    for _, e in ipairs(folder:GetChildren()) do
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        local part = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                        if hum and hum.Health > 0 and part and (part.Position - h.Position).Magnitude <= M.config.auraRange then
                            if not M.config.losCheck or losClear(h.Position, part, e) then list[#list + 1] = e end
                        end
                    end
                    M.attackMany(list)
                end
                if M.config.targetPlayers then M.attackPlayersInRange(M.config.auraRange) end
                task.wait(effDelay())
            end
        end)
    end
end

function M.pressKey(name)
    local kc = Enum.KeyCode[name]
    if not kc then return end
    pcall(function()
        VIM:SendKeyEvent(true, kc, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, kc, false, game)
    end)
end
function M.setAutoClick(on)
    M._autoClick = on and true or false
    if M._autoClick and M._core then
        M._core.spawn(function()
            while M._autoClick do
                for k, enabled in pairs(M.config.keys) do
                    if not M._autoClick then break end
                    if enabled then M.pressKey(k) end
                end
                task.wait(M.config.clickInterval)
            end
        end)
    end
end

function M.setFollow(on)
    M._follow = on and true or false
    if M._follow and M._core then
        M._core.spawn(function()
            while M._follow do
                local tp = M._core.modules.teleport
                local ch = M.nearestPlayer()
                local ph = ch and ch:FindFirstChild("HumanoidRootPart")
                if tp and ph then tp.go(ph.Position + ph.CFrame.LookVector * -M.config.followDist) end
                if M.config.attack1v1 and ch then M.attackOnce(ch) end
                task.wait(0.3)
            end
        end)
    end
end

local function myHealthPct()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth > 0 then return hum.Health / hum.MaxHealth * 100 end
    return 100
end
local function holdingCup(ch)
    for _, t in ipairs(ch:GetChildren()) do if t:IsA("Tool") and t.Name == "Cup" then return true end end
    return false
end
local function bountyValid(p)
    if p == LP then return false end
    local ch = p.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local ph = ch and ch:FindFirstChild("HumanoidRootPart")
    if not (hum and ph and hum.Health > 0) then return false end
    if M.bounty.noFriends then
        local ok, f = pcall(function() return LP:IsFriendsWith(p.UserId) end)
        if ok and f then return false end
    end
    if M.bounty.noCup and holdingCup(ch) then return false end
    if M.bounty.team ~= "Both" and p.Team and p.Team.Name:lower():find(M.bounty.team:lower()) == nil then return false end
    local sk = M._bountySkip[p.UserId]
    if sk and sk > os.clock() then return false end
    return true
end
local function pickBounty()
    local h = M.hrp(); if not h then return end
    local best, bestScore
    for _, p in ipairs(Players:GetPlayers()) do
        if bountyValid(p) then
            local ch = p.Character
            local ph, hum = ch:FindFirstChild("HumanoidRootPart"), ch:FindFirstChildOfClass("Humanoid")
            local score = (M.bounty.method == "Lowest HP") and hum.Health or (ph.Position - h.Position).Magnitude
            if not bestScore or score < bestScore then best, bestScore = p, score end
        end
    end
    return best
end
function M.chat(msg)
    pcall(function()
        local TCS = game:GetService("TextChatService")
        if TCS.ChatVersion == Enum.ChatVersion.TextChatService then
            TCS.TextChannels.RBXGeneral:SendAsync(msg)
        else
            RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
        end
    end)
end
function M.setNoStun(on)
    M._noStunOn = on and true or false
    if M._noStunOn and M._core then
        M._core.spawn(function()
            while M._noStunOn do
                local ch = LP.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if ch and hum then
                    if hum.PlatformStand then hum.PlatformStand = false end
                    for _, a in ipairs({ "Stun", "Stunned" }) do
                        if ch:GetAttribute(a) then ch:SetAttribute(a, false) end
                    end
                end
                task.wait(0.1)
            end
        end)
    end
end
function M.setBounty(on)
    M._bountyOn = on and true or false
    if not (M._bountyOn and M._core) then return end
    M._core.spawn(function()
        local tp = M._core.modules.teleport
        while M._bountyOn do
            if myHealthPct() < M.bounty.safePct then
                local h = M.hrp()
                if tp and h then tp.go(h.Position + Vector3.new(0, 220, 0)) end
                if M._ui then M._ui.notify("Safe zone: low HP, retreating") end
                task.wait(1.2)
            else
                local target = pickBounty()
                if not target then task.wait(0.5) else
                    local start = os.clock()
                    while M._bountyOn and (os.clock() - start) < M.bounty.maxTime do
                        if myHealthPct() < M.bounty.safePct then break end
                        local ch = target.Character
                        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                        local ph = ch and ch:FindFirstChild("HumanoidRootPart")
                        if not (ch and hum and ph and hum.Health > 0) then
                            if M.bounty.chatKill then M.chat(M.bounty.chatMsg) end
                            break
                        end
                        local off = M.config.followDist
                        local dest = ph.Position + ph.CFrame.LookVector * -off + Vector3.new(0, M.bounty.invisKen and 4 or 0, 0)
                        if tp then tp.go(dest) end
                        M.attackOnce(ch)
                        task.wait(effDelay())
                    end
                    if os.clock() - start >= M.bounty.maxTime then M._bountySkip[target.UserId] = os.clock() + 8 end
                end
            end
        end
    end)
end

function M.stop()
    M._mobAuto, M._playerAuto, M._aura, M._autoClick, M._follow, M._capturing = false, false, false, false, false, false
    M._bountyOn, M._noStunOn = false, false
    M.config.aim, M.config.spectate = false, false
    local cam = workspace.CurrentCamera
    local myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if cam and myHum then cam.CameraSubject = myHum end
end

function M.init(Core, UI)
    M._core = Core
    M.installCapture()

    Core.track(RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        if M.config.aim then
            local ch = M.nearestPlayer()
            local ph = ch and ch:FindFirstChild("HumanoidRootPart")
            if ph then
                cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, ph.Position), M.config.aimSmooth)
            end
        end
        if M.config.spectate then
            local ch = M.nearestPlayer()
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum; M._wasSpectate = true end
        elseif M._wasSpectate then
            local myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if myHum then cam.CameraSubject = myHum end
            M._wasSpectate = false
        end
    end))

    local page = UI.page("PVP")
    UI.toggle(page, "Auto attack players", "Attack the nearby players", false, function(s) M.setPlayerAuto(s) end)
    UI.slider(page, "Player range", "Player detection radius", 10, 200, M.config.playerRange, function(v) M.config.playerRange = v end)
    UI.toggle(page, "Fast attack", "Minimum delay between hits", M.config.fast, function(s) M.config.fast = s end)
    UI.toggle(page, "Attack players while farming", "Hit nearby players during auto-farm too", M.config.targetPlayers, function(s) M.config.targetPlayers = s end)

    UI.section(page, "KILL AURA")
    UI.toggle(page, "Kill aura", "Hit everything in range (mobs + players)", false, function(s) M.setAura(s) end)
    UI.slider(page, "Aura range", "Radius", 10, 200, M.config.auraRange, function(v) M.config.auraRange = v end)
    UI.toggle(page, "Line of sight", "Only hit visible targets", M.config.losCheck, function(s) M.config.losCheck = s end)

    UI.section(page, "AIMBOT")
    UI.toggle(page, "Aimbot", "Lock camera on the nearest player", false, function(s) M.config.aim = s end)
    UI.slider(page, "Smoothness", "Lower = smoother", 3, 100, math.floor(M.config.aimSmooth * 100), function(v) M.config.aimSmooth = v / 100 end)

    UI.section(page, "AUTO SKILLS")
    UI.toggle(page, "Auto skills", "Auto-press the skill keys", false, function(s) M.setAutoClick(s) end)
    for _, k in ipairs({ "Z", "X", "C", "V", "F" }) do
        UI.toggle(page, "Key " .. k, "Include " .. k .. " in the rotation", M.config.keys[k], function(s) M.config.keys[k] = s end)
    end
    UI.slider(page, "Skill interval (ms)", "Delay between key series", 100, 1000, math.floor(M.config.clickInterval * 1000), function(v) M.config.clickInterval = v / 1000 end)

    UI.section(page, "PLAYERS")
    UI.toggle(page, "Follow nearest", "Teleport onto the nearest player", false, function(s) M.setFollow(s) end)
    UI.toggle(page, "1v1 (attack target)", "Attack the followed player", false, function(s) M.config.attack1v1 = s end)
    UI.toggle(page, "Spectate nearest", "Camera on the nearest player", false, function(s) M.config.spectate = s end)
    UI.button(page, "Show captured hit id", "hitId from your last real M1", function()
        UI.notify(M.lastHitId and ("hitId: " .. tostring(M.lastHitId)) or "No hitId yet — do one real M1")
    end)

    UI.section(page, "AUTO BOUNTY V4")
    UI.toggle(page, "Auto Bounty", "Hunt players (fly to target, attack, guards)", false, function(s) M.setBounty(s) end)
    UI.dropdown(page, "Target team", "Which team to hunt", { "Both", "Pirates", "Marines" }, function(s) M.bounty.team = s end)
    UI.dropdown(page, "Farm method", "How to pick the target", { "Nearest", "Lowest HP" }, function(s) M.bounty.method = s end)
    UI.toggle(page, "Don't attack friends", "Skip your Roblox friends", M.bounty.noFriends, function(s) M.bounty.noFriends = s end)
    UI.toggle(page, "Don't attack Cup holders", "Skip players holding a Cup (truce)", M.bounty.noCup, function(s) M.bounty.noCup = s end)
    UI.toggle(page, "No stun", "Counter stun (PlatformStand / stun attributes)", false, function(s) M.setNoStun(s) end)
    UI.toggle(page, "Invisible from Ken", "Best-effort: strike from behind/above", M.bounty.invisKen, function(s) M.bounty.invisKen = s end)
    UI.toggle(page, "Chat after kill", "Send a message when a target dies", M.bounty.chatKill, function(s) M.bounty.chatKill = s end)
    UI.textbox(page, "Kill message (default: gg)", function(t) M.bounty.chatMsg = (t ~= "" and t) or "gg" end)
    UI.slider(page, "Safe zone HP %", "Retreat below this health", 0, 100, M.bounty.safePct, function(v) M.bounty.safePct = v end)
    UI.slider(page, "Max time on target (s)", "Switch after this many seconds", 5, 60, M.bounty.maxTime, function(v) M.bounty.maxTime = v end)

    Core.register("combat", M)
    return M
end

return M

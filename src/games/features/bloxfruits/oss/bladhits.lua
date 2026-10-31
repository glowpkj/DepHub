local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Blade Hits: auto-swing the equipped weapon at nearby enemies by firing the
-- game's own attack/hit remotes, the same pair combat.lua uses
-- (RE/RegisterAttack + RE/RegisterHit). It reaches enemies the normal swing
-- would miss and, unlike a tool:Activate() loop, it is driven by the server
-- remotes so it lands everywhere the enemy is.
--
-- The hit needs a server-validated hitId: a forged one is ignored, so this
-- reads the one the client already sent (see combat.lua's capture) and reuses
-- it. With no captured id yet it still fires (the game grants one on the first
-- real M1), matching the original behaviour.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

local M = {}
M.config = {
    range = 100,
    interval = 0.1,
    jitterPct = 0.25,   -- +/- on the interval, so the loop is not perfectly periodic
    enemiesFolder = true,
    charactersFolder = true,
    players = false,
    playerRange = 60,
}
M._on = false
M._thread = nil
M.hits = 0
M.lastHitId = nil

local function net()
    local mods = RS:FindFirstChild("Modules")
    local n = mods and mods:FindFirstChild("Net")
    if not n then return end
    return n:FindFirstChild("RE/RegisterAttack"), n:FindFirstChild("RE/RegisterHit")
end

function M.hrp()
    local ch = LP and LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function alive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

-- Collect every live enemy in range from the folders the game uses for mobs and
-- other characters; the nearest is fired first.
local function collectEnemies(range)
    local root = M.hrp()
    if not root then return {} end
    local list = {}
    local function scan(folder)
        if not folder then return end
        for _, enemy in ipairs(folder:GetChildren()) do
            if enemy ~= LP.Character then
                local humanoid = enemy:FindFirstChildOfClass("Humanoid")
                local part = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and part then
                    local distance = (part.Position - root.Position).Magnitude
                    if distance <= range then list[#list + 1] = {model = enemy, part = part, distance = distance} end
                end
            end
        end
    end
    if M.config.enemiesFolder then scan(Workspace:FindFirstChild("Enemies")) end
    if M.config.charactersFolder then scan(Workspace:FindFirstChild("Characters")) end
    if M.config.players then
        for _, p in ipairs(Players:GetPlayers()) do
            local ch = p ~= LP and p.Character
            local part = ch and ch:FindFirstChild("HumanoidRootPart")
            local humanoid = ch and ch:FindFirstChildOfClass("Humanoid")
            if part and humanoid and humanoid.Health > 0 then
                local distance = (part.Position - root.Position).Magnitude
                if distance <= M.config.playerRange then list[#list + 1] = {model = ch, part = part, distance = distance} end
            end
        end
    end
    table.sort(list, function(a, b) return a.distance < b.distance end)
    return list
end

-- Fire the attack/hit remotes at every target in range. The combo counter cycles
-- 1..4 so the animation keys alternate the way the game expects.
function M.swing()
    local attack, hit = net()
    if not (attack and hit) then return false end
    local targets = collectEnemies(M.config.range)
    if #targets == 0 then return false end
    M._combo = ((M._combo or 0) % 4) + 1
    pcall(function() attack:FireServer(0.4, M._combo) end)
    for _, target in ipairs(targets) do
        pcall(function() hit:FireServer(target.part, {}, nil, M.lastHitId) end)
    end
    M.hits = M.hits + 1
    return true
end

local function jitter(base, spread)
    return base * (1 + (math.random() * 2 - 1) * (spread or M.config.jitterPct))
end

function M.set(on)
    M._on = on and true or false
    if M._on then
        if M._thread then return end
        M._thread = M._core.spawn(function()
            while M._on do
                if alive(LP.Character) then pcall(M.swing) end
                task.wait(jitter(M.config.interval))
            end
            M._thread = nil
        end)
    elseif M._thread then
        pcall(task.cancel, M._thread)
        M._thread = nil
    end
end

function M.stop()
    M._on = false
    if M._thread then pcall(task.cancel, M._thread); M._thread = nil end
end

function M.init(Core, UI)
    M._core = Core
    -- Reuse the hitId combat already captured this session (the game's own M1),
    -- and follow every later one: the id is per swing, so a one-time snapshot
    -- would leave the loop sending a stale id after the first real hit.
    local combat = Core.modules and Core.modules.combat
    if combat then
        if combat.lastHitId then M.lastHitId = combat.lastHitId end
        combat._onHitId = M.syncHitId
    end

    local page = UI.page("PVP")
    UI.section(page, "BLADE HITS")
    UI.toggle(page, "Blade hits", "Auto-swing the weapon at every enemy in range (uses the game's attack remotes)", false, function(s)
        if s and combat and combat.lastHitId then M.lastHitId = combat.lastHitId end
        M.set(s)
    end)
    UI.slider(page, "Blade range", "Enemy detection radius", 10, 300, M.config.range, function(v) M.config.range = v end)
    UI.slider(page, "Blade interval (ms)", "Delay between swings", 30, 500, math.floor(M.config.interval * 1000), function(v) M.config.interval = v / 1000 end)
    UI.toggle(page, "Hit players too", "Include nearby players", false, function(s) M.config.players = s end)
    UI.toggle(page, "Enemies folder", "Scan Workspace.Enemies", M.config.enemiesFolder, function(s) M.config.enemiesFolder = s end)
    UI.toggle(page, "Characters folder", "Scan Workspace.Characters", M.config.charactersFolder, function(s) M.config.charactersFolder = s end)

    Core.register("bladhits", M)
    return M
end

-- Mirror the hitId combat just captured, so the next swing sends a live id.
function M.syncHitId(value)
    if value ~= nil then M.lastHitId = value end
end

return M

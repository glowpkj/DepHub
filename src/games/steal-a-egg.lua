local game, task, type, tostring, tonumber, pairs, ipairs, pcall, math, table = game, task, type, tostring, tonumber, pairs, ipairs, pcall, math, table
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_STEALANEGG"

local previous = env[STATE_KEY]
if type(previous) == "table" and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
end

-- Steal An Egg backend.
--
-- Two features, both ported from the Blox Fruits modules and only those:
--
--   * Walk speed -- a toggle + slider driven by a RenderStepped loop that
--     re-applies Humanoid.WalkSpeed every frame, so the game's controller cannot
--     overwrite it (RenderStepped runs after it and wins the frame).
--   * Teleport -- a CFrame tween fly, ported from the BF teleport module: it
--     tweens the HumanoidRootPart to the target at a constant speed, zeroes the
--     linear velocity during the tween and turns collision off so the character
--     glides instead of snagging, but it never Anchors the character (anchoring
--     makes both games reject every hit). Waypoints let the player save spots in
--     game, because the coordinates are not known ahead of time.
--
-- The teleport is a client-side CFrame move. It works in games that trust the
-- client for position, which Blox Fruits does. Whether Steal An Egg does as well
-- is a property of that game, not of this code: a server-side position check
-- would flag it no matter how the tween is shaped.

local State = {
    Version = "0.2.0",
    Destroyed = false,
    Started = false,
    Connections = {},
    Toggles = {
        Speed = false,
    },
    ToggleLabels = {
        Speed = "Speed boost",
    },
    Values = {
        WalkSpeed = 50,
        FlySpeed = 200,
    },
    Tween = nil,
    Waypoints = {},
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.StealAnEgg = State

local function myCharacter()
    return LocalPlayer.Character
end

local function myHumanoid()
    local character = myCharacter()
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function myRoot()
    local character = myCharacter()
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

-- ---------------------------------------------------------------------------
-- Walk speed (unchanged from v0.0.78)
-- ---------------------------------------------------------------------------
function State:SetSpeed(value)
    value = tonumber(value)
    if not value or value ~= value then return false end
    self.Values.WalkSpeed = math.clamp(math.floor(value), 16, 300)
    return true
end

-- ---------------------------------------------------------------------------
-- Teleport: CFrame tween fly ported from the Blox Fruits teleport module.
-- ---------------------------------------------------------------------------
function State:CancelFly()
    if self.Tween then pcall(function() self.Tween:Cancel() end); self.Tween = nil end
end

function State:Go(pos)
    if self.Destroyed or typeof(pos) ~= "Vector3" then return false end
    local root = myRoot()
    if not root then return false end
    local distance = (root.Position - pos).Magnitude
    local duration = math.clamp(distance / math.max(self.Values.FlySpeed, 1), 0.05, 90)
    self:CancelFly()
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    self.Tween = tween
    tween.Completed:Connect(function() if self.Tween == tween then self.Tween = nil end end)
    tween:Play()
    return true
end

function State:FlyToPosition()
    local root = myRoot()
    if not root then return nil end
    local p = root.Position
    return p
end

function State:SetFlySpeed(value)
    value = tonumber(value)
    if not value or value ~= value or value < 1 then return false end
    self.Values.FlySpeed = math.clamp(math.floor(value), 1, 100000)
    return true
end

-- ---------------------------------------------------------------------------
-- Waypoints: the map layout is not known ahead of time, so the player saves the
-- spots in game. Persisted through the executor file API when available; a
-- missing writefile/readfile degrades to in-memory only instead of erroring.
-- ---------------------------------------------------------------------------
local WAYPOINT_FILE = "DepHub_SAE_waypoints.json"

local function canPersist()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function encodeWaypoints(list)
    local lines = {}
    for _, w in ipairs(list) do
        lines[#lines + 1] = string.format("%s\t%.3f\t%.3f\t%.3f", w.name, w.pos.X, w.pos.Y, w.pos.Z)
    end
    return table.concat(lines, "\n")
end

local function decodeWaypoints(text)
    local list = {}
    for line in tostring(text):gmatch("[^\n]+") do
        local name, x, y, z = line:match("^(.-)\t([%-%d%.]+)\t([%-%d%.]+)\t([%-%d%.]+)$")
        if name and x and y and z then
            list[#list + 1] = {name = name, pos = Vector3.new(tonumber(x), tonumber(y), tonumber(z))}
        end
    end
    return list
end

function State:SaveWaypoints()
    if not canPersist() then return false end
    local ok = pcall(writefile, WAYPOINT_FILE, encodeWaypoints(self.Waypoints))
    return ok
end

function State:LoadWaypoints()
    if not canPersist() then return false end
    local has = pcall(isfile, WAYPOINT_FILE)
    if not (has and isfile(WAYPOINT_FILE)) then return false end
    local ok, text = pcall(readfile, WAYPOINT_FILE)
    if not ok or type(text) ~= "string" then return false end
    self.Waypoints = decodeWaypoints(text)
    return true
end

function State:AddWaypoint(name, pos)
    if self.Destroyed then return false end
    local root = myRoot()
    pos = pos or (root and root.Position)
    if not pos then return false end
    name = tostring(name or "")
    if name == "" then name = "WP " .. (#self.Waypoints + 1) end
    self.Waypoints[#self.Waypoints + 1] = {name = name, pos = pos}
    self:SaveWaypoints()
    return true
end

function State:RemoveWaypoint(name)
    if self.Destroyed then return false end
    for index, w in ipairs(self.Waypoints) do
        if w.name == name then
            table.remove(self.Waypoints, index)
            self:SaveWaypoints()
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Toggles + lifecycle
-- ---------------------------------------------------------------------------
function State:SetToggle(name, enabled)
    if self.Destroyed or type(name) ~= "string" then return false end
    if self.Toggles[name] == nil then return false end
    self.Toggles[name] = enabled == true
    -- Turning the boost off hands the value back to the game immediately, so the
    -- player is not stuck at the boosted speed until the next respawn.
    if name == "Speed" and not self.Toggles.Speed then
        local humanoid = myHumanoid()
        if humanoid then pcall(function() humanoid.WalkSpeed = 16 end) end
    end
    return true
end

function State:GetToggle(name)
    if self.Destroyed or type(name) ~= "string" then return false end
    return self.Toggles[name] == true
end

function State:Start()
    if self.Started or self.Destroyed then return false end
    self.Started = true

    -- Walk speed: re-apply every frame while the boost is on.
    self.Connections[#self.Connections + 1] = RunService.RenderStepped:Connect(function()
        if self.Destroyed or not self.Toggles.Speed then return end
        local humanoid = myHumanoid()
        if humanoid then humanoid.WalkSpeed = self.Values.WalkSpeed end
    end)

    -- During a fly: zero velocity + collision off, exactly like BF. Never Anchor
    -- the character -- anchoring makes both games reject every hit.
    self.Connections[#self.Connections + 1] = RunService.Heartbeat:Connect(function()
        if self.Destroyed or not self.Tween then return end
        local character = myCharacter()
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if root then root.AssemblyLinearVelocity = Vector3.zero end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end)

    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self:CancelFly()
    local humanoid = myHumanoid()
    if humanoid then pcall(function() humanoid.WalkSpeed = 16 end) end
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    if env[STATE_KEY] == self then env[STATE_KEY] = nil end
    if env.__DEPHUB and env.__DEPHUB.StealAnEgg == self then env.__DEPHUB.StealAnEgg = nil end
end

-- ---------------------------------------------------------------------------
-- Presentation: grouped by CATEGORY (finalidade), never a per-game tab. Speed
-- and teleport are both movement, so they live in the Movement category.
-- ---------------------------------------------------------------------------
do
    local UI = env.__DEPHUB and env.__DEPHUB.UI
    local Kit = env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        local speed = Kit.Section(Kit.Tab("Speed", "Movement"), "Movimento", "Left")
        if speed then
            speed:CreateToggle("Speed boost", State.Toggles.Speed, function(v) State:SetToggle("Speed", v) end)
            speed:CreateSlider("Walk speed", 16, 300, State.Values.WalkSpeed, function(v) State:SetSpeed(v) end)
        end

        local tpTab = Kit.Tab("Teleport", "Movement")
        local fly = Kit.Section(tpTab, "Voo", "Left")
        if fly then
            fly:CreateSlider("Velocidade do voo", 50, 1000, State.Values.FlySpeed, function(v) State:SetFlySpeed(v) end)
            fly:CreateButton("Notificar posicao atual", function()
                local p = State:FlyToPosition()
                if not p then UI:Notify("Teleport", "Sem personagem") return end
                UI:Notify("Posicao", string.format("X %.1f  Y %.1f  Z %.1f", p.X, p.Y, p.Z))
            end)
            fly:CreateButton("Salvar waypoint aqui", function()
                local p = State:FlyToPosition()
                if not p then UI:Notify("Teleport", "Sem personagem") return end
                State:AddWaypoint(nil, p)
                UI:Notify("Waypoint", "Salvo (total " .. tostring(#State.Waypoints) .. ")")
            end)
        end

        local wp = Kit.Section(tpTab, "Waypoints", "Right")
        if wp then
            for _, waypoint in ipairs(State.Waypoints) do
                wp:CreateButton("Ir: " .. waypoint.name, function() State:Go(waypoint.pos) end)
            end
            wp:CreateParagraph("Waypoints", "Nenhum salvo ainda. Use 'Salvar waypoint aqui' na coluna da esquerda enquanto estiver no lugar desejado.")
        end
    end
end

State:LoadWaypoints()
State:Start()

do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.RegisterModule) == "function" then
        Diag:RegisterModule("src/games/steal-a-egg.lua")
        Diag:Feature("StealAnEgg.Speed", function() return State.Toggles.Speed and ("ON " .. tostring(State.Values.WalkSpeed)) or "off" end)
        Diag:Feature("StealAnEgg.Waypoints", function() return tostring(#State.Waypoints) end)
        Diag:Watch("StealAnEgg voando", function() return State.Tween and "sim" or "nao" end)
        Diag:Command("sae", function()
            return "speed=" .. tostring(State.Toggles.Speed) ..
                " valor=" .. tostring(State.Values.WalkSpeed) ..
                " voo=" .. tostring(State.Tween ~= nil) ..
                " waypoints=" .. tostring(#State.Waypoints)
        end)
    end
end

env.SAE = State

return State

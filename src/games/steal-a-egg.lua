local game, task, type, tostring, tonumber, pairs, ipairs, pcall, math = game, task, type, tostring, tonumber, pairs, ipairs, pcall, math
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
-- Only the walk-speed feature, ported from the Blox Fruits player module: a
-- "Speed boost" toggle plus a "Walk speed" slider, and a RenderStepped loop that
-- re-applies the value every frame. The loop is the whole point -- the game's own
-- controller rewrites Humanoid.WalkSpeed each frame, so a one-shot write is
-- overwritten immediately. RenderStepped runs after the game's controller, so
-- re-setting there wins the frame and the speed actually sticks.

local State = {
    Version = "0.1.0",
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
    },
}

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.StealAnEgg = State

local function myHumanoid()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

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

function State:SetSpeed(value)
    value = tonumber(value)
    if not value or value ~= value then return false end
    self.Values.WalkSpeed = math.clamp(math.floor(value), 16, 300)
    return true
end

function State:Start()
    if self.Started or self.Destroyed then return false end
    self.Started = true
    local connection = RunService.RenderStepped:Connect(function()
        if self.Destroyed or not self.Toggles.Speed then return end
        local humanoid = myHumanoid()
        if humanoid then humanoid.WalkSpeed = self.Values.WalkSpeed end
    end)
    self.Connections[#self.Connections + 1] = connection
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
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
-- Presentation: the shared shell. Tabs and sections are the backend's job.
-- ---------------------------------------------------------------------------
do
    local UI = env.__DEPHUB and env.__DEPHUB.UI
    if type(UI) == "table" and type(UI.CreateTab) == "function" then
        local okTab, tab = pcall(function() return UI:CreateTab("Speed", "All") end)
        if okTab and tab then
            local okSection, section = pcall(function() return tab:CreateSection("Movimento", "Left", "Velocidade de caminhada") end)
            if okSection and section then
                section:CreateToggle("Speed boost", State.Toggles.Speed, function(v) State:SetToggle("Speed", v) end)
                section:CreateSlider("Walk speed", 16, 300, State.Values.WalkSpeed, function(v) State:SetSpeed(v) end)
            end
        end
    end
end

State:Start()

do
    local Diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.RegisterModule) == "function" then
        Diag:RegisterModule("src/games/steal-a-egg.lua")
        Diag:Feature("StealAnEgg.Speed", function() return State.Toggles.Speed and ("ON " .. tostring(State.Values.WalkSpeed)) or "off" end)
        Diag:Command("sae", function()
            return "speed=" .. tostring(State.Toggles.Speed) .. " valor=" .. tostring(State.Values.WalkSpeed)
        end)
    end
end

env.SAE = State

return State

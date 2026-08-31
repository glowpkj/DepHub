local game = game
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_TSB"
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION = "0.0.1"

local previous = type(env[STATE_KEY]) == "table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

local function compile(source)
    if type(loadstring) ~= "function" then
        return false, "loadstring indisponivel"
    end

    local ok, chunk, compileError = pcall(loadstring, source)
    if not ok or type(chunk) ~= "function" then
        return false, tostring(compileError or chunk)
    end

    return true, chunk
end

local function loadFeature(path, context)
    local okGet, source = pcall(function()
        return game:HttpGet(BASE_URL .. path)
    end)

    if not okGet or type(source) ~= "string" or #source == 0 then
        return false, tostring(source)
    end

    local okCompile, chunk = compile(source)
    if not okCompile then
        return false, chunk
    end

    local okRun, factory = pcall(chunk)
    if not okRun or type(factory) ~= "table" or type(factory.new) ~= "function" then
        return false, tostring(factory)
    end

    local okNew, feature = pcall(factory.new, context)
    if not okNew or type(feature) ~= "table" then
        return false, tostring(feature)
    end

    return true, feature
end

local State = {
    Started = false,
    Destroyed = false,
    Version = VERSION,
    Features = {},
    Toggles = {
        AutoBlock = false,
        M1AfterBlock = false,
        M1Catch = false
    },
    Values = {
        NormalRange = 12,
        SpecialRange = 50,
        SkillRange = 50,
        SkillHold = 1.2
    }
}

local context = {
    Players = Players,
    RunService = RunService,
    VirtualInputManager = VirtualInputManager,
    Workspace = Workspace,
    LocalPlayer = LocalPlayer,
    NormalRange = State.Values.NormalRange,
    SpecialRange = State.Values.SpecialRange,
    SkillRange = State.Values.SkillRange,
    SkillHold = State.Values.SkillHold,
    M1AfterBlock = State.Toggles.M1AfterBlock,
    M1Catch = State.Toggles.M1Catch
}

local okAutoBlock, AutoBlock = loadFeature(
    "src/games/features/tsb/autoblock.lua",
    context
)

if not okAutoBlock then
    return false
end

State.Features.AutoBlock = AutoBlock

env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.TSB = State

function State:SetAutoBlock(enabled)
    if self.Destroyed then return false end
    enabled = enabled == true

    if self.Toggles.AutoBlock == enabled then
        return true
    end

    local feature = self.Features.AutoBlock
    if not feature then return false end

    local ok = enabled and feature:Enable() or feature:Disable()
    if ok == false then return false end

    self.Toggles.AutoBlock = enabled
    return true
end

function State:SetM1AfterBlock(enabled)
    if self.Destroyed then return false end
    enabled = enabled == true
    local feature = self.Features.AutoBlock
    if not feature then return false end
    local ok = feature:SetM1AfterBlock(enabled)
    if ok == false then return false end
    self.Toggles.M1AfterBlock = enabled
    return true
end

function State:SetM1Catch(enabled)
    if self.Destroyed then return false end
    enabled = enabled == true
    local feature = self.Features.AutoBlock
    if not feature then return false end
    local ok = feature:SetM1Catch(enabled)
    if ok == false then return false end
    self.Toggles.M1Catch = enabled
    return true
end

function State:SetNormalRange(value)
    if self.Destroyed then return false end
    value = tonumber(value)
    if not value then return false end
    local feature = self.Features.AutoBlock
    if not feature or not feature:SetNormalRange(value) then return false end
    self.Values.NormalRange = feature.Config.NormalRange
    return true
end

function State:SetSpecialRange(value)
    if self.Destroyed then return false end
    value = tonumber(value)
    if not value then return false end
    local feature = self.Features.AutoBlock
    if not feature or not feature:SetSpecialRange(value) then return false end
    self.Values.SpecialRange = feature.Config.SpecialRange
    return true
end

function State:SetSkillRange(value)
    if self.Destroyed then return false end
    value = tonumber(value)
    if not value then return false end
    local feature = self.Features.AutoBlock
    if not feature or not feature:SetSkillRange(value) then return false end
    self.Values.SkillRange = feature.Config.SkillRange
    return true
end

function State:SetSkillHold(value)
    if self.Destroyed then return false end
    value = tonumber(value)
    if not value then return false end
    local feature = self.Features.AutoBlock
    if not feature or not feature:SetSkillHold(value) then return false end
    self.Values.SkillHold = feature.Config.SkillHold
    return true
end

function State:GetToggle(name)
    return self.Toggles[name] == true
end

function State:GetValue(name)
    return self.Values[name]
end

function State:GetAutoBlockConfig()
    local feature = self.Features.AutoBlock
    if not feature then return nil end
    return feature:GetConfig()
end

function State:Start()
    if self.Destroyed or self.Started then return false end
    self.Started = true
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    local feature = self.Features and self.Features.AutoBlock
    if feature and type(feature.Destroy) == "function" then
        pcall(feature.Destroy, feature)
    end

    self.Features = nil

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end

    if env.__DEPHUB and env.__DEPHUB.TSB == self then
        env.__DEPHUB.TSB = nil
    end
end

if not LocalPlayer then
    pcall(State.Destroy, State)
    return false
end

local okStart, started = pcall(State.Start, State)
if not okStart or not started then
    pcall(State.Destroy, State)
    return false
end

return State

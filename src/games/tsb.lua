local game = game
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local pairs = pairs

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local env = type(getgenv) == "function" and getgenv() or _G
local STATE_KEY = "__DEPHUB_TSB"
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION = "0.0.5"

local previous = type(env[STATE_KEY]) == "table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy) == "function" then
    pcall(previous.Destroy, previous)
end

if not LocalPlayer then
    return false
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

local function fetch(path)
    local ok, source = pcall(function()
        return game:HttpGet(BASE_URL .. path)
    end)

    if not ok or type(source) ~= "string" or #source == 0 then
        return false, tostring(source)
    end

    return true, source
end

local function loadModule(path)
    local okFetch, source = fetch(path)
    if not okFetch then return false, source end

    local okCompile, chunk = compile(source)
    if not okCompile then return false, chunk end

    local okRun, result = pcall(chunk)
    if not okRun then return false, tostring(result) end

    return true, result
end

local function loadFeature(path, context)
    local okModule, factory = loadModule(path)
    if not okModule then return false, factory end
    if type(factory) ~= "table" or type(factory.new) ~= "function" then
        return false, "factory invalida: " .. path
    end

    local okNew, feature = pcall(factory.new, context)
    if not okNew or type(feature) ~= "table" then
        return false, tostring(feature)
    end

    return true, feature
end

local okAnimations, AnimationData = loadModule("src/games/features/tsb/animations.lua")
if not okAnimations or type(AnimationData) ~= "table" then
    return false
end

if type(AnimationData.Groups) ~= "table" or type(AnimationData.SkillIds) ~= "table" then
    return false
end

local State = {
    Started = false,
    Destroyed = false,
    Version = VERSION,
    Features = {},
    AnimationData = AnimationData,
    Toggles = {
        AutoBlock = false,
        M1AfterBlock = false,
        M1Catch = false,
        DashBlock = false,
        SkillBlock = false,
        ShowDetectionBox = false,
        Debug = false
    },
    Values = {
        NormalRange = 12,
        SpecialRange = 50,
        SkillRange = 50,
        SkillHold = 1.2,
        DetectionBoxSize = 12,
        ScanHz = 30
    }
}

local context = {
    Players = Players,
    RunService = RunService,
    VirtualInputManager = VirtualInputManager,
    Workspace = Workspace,
    LocalPlayer = LocalPlayer,
    AnimationData = AnimationData,
    M1Block = State.Toggles.AutoBlock,
    M1AfterBlock = State.Toggles.M1AfterBlock,
    M1Catch = State.Toggles.M1Catch,
    DashBlock = State.Toggles.DashBlock,
    SkillBlock = State.Toggles.SkillBlock,
    ShowDetectionBox = State.Toggles.ShowDetectionBox,
    Debug = State.Toggles.Debug,
    NormalRange = State.Values.NormalRange,
    SpecialRange = State.Values.SpecialRange,
    SkillRange = State.Values.SkillRange,
    SkillHold = State.Values.SkillHold,
    DetectionBoxSize = State.Values.DetectionBoxSize,
    ScanHz = State.Values.ScanHz
}

local okAutoBlock, AutoBlock = loadFeature("src/games/features/tsb/autoblock.lua", context)
if not okAutoBlock then
    return false
end

State.Features.AutoBlock = AutoBlock
env[STATE_KEY] = State
env.__DEPHUB = env.__DEPHUB or {}
env.__DEPHUB.TSB = State

local function syncRuntime(self)
    if self.Destroyed then return false end

    local feature = self.Features and self.Features.AutoBlock
    if not feature then return false end

    local shouldRun = self.Toggles.AutoBlock
        or self.Toggles.DashBlock
        or self.Toggles.SkillBlock

    if shouldRun and not feature.Enabled then
        return feature:Enable() ~= false
    end

    if not shouldRun and feature.Enabled then
        return feature:Disable() ~= false
    end

    return true
end

local function setToggle(self, key, method, value, needsSync)
    if self.Destroyed then return false end

    local feature = self.Features and self.Features.AutoBlock
    if not feature or type(feature[method]) ~= "function" then return false end

    value = value == true
    local ok, result = pcall(feature[method], feature, value)
    if not ok or result == false then return false end

    self.Toggles[key] = value
    if needsSync then
        return syncRuntime(self)
    end
    return true
end

local function setValue(self, key, method, value)
    if self.Destroyed then return false end

    value = tonumber(value)
    if not value then return false end

    local feature = self.Features and self.Features.AutoBlock
    if not feature or type(feature[method]) ~= "function" then return false end

    local ok, result = pcall(feature[method], feature, value)
    if not ok or result == false then return false end

    local config = type(feature.GetConfig) == "function" and feature:GetConfig() or nil
    if type(config) == "table" and config[key] ~= nil then
        self.Values[key] = config[key]
    else
        self.Values[key] = value
    end

    return true
end

function State:SetAutoBlock(value)
    return setToggle(self, "AutoBlock", "SetM1Block", value, true)
end

function State:SetM1AfterBlock(value)
    return setToggle(self, "M1AfterBlock", "SetM1AfterBlock", value, false)
end

function State:SetM1Catch(value)
    return setToggle(self, "M1Catch", "SetM1Catch", value, false)
end

function State:SetDashBlock(value)
    return setToggle(self, "DashBlock", "SetDashBlock", value, true)
end

function State:SetSkillBlock(value)
    return setToggle(self, "SkillBlock", "SetSkillBlock", value, true)
end

function State:SetShowDetectionBox(value)
    return setToggle(self, "ShowDetectionBox", "SetShowDetectionBox", value, false)
end

function State:SetDebug(value)
    return setToggle(self, "Debug", "SetDebug", value, false)
end

function State:SetNormalRange(value)
    return setValue(self, "NormalRange", "SetNormalRange", value)
end

function State:SetSpecialRange(value)
    return setValue(self, "SpecialRange", "SetSpecialRange", value)
end

function State:SetSkillRange(value)
    return setValue(self, "SkillRange", "SetSkillRange", value)
end

function State:SetSkillHold(value)
    return setValue(self, "SkillHold", "SetSkillHold", value)
end

function State:SetDetectionBoxSize(value)
    return setValue(self, "DetectionBoxSize", "SetDetectionBoxSize", value)
end

function State:SetScanHz(value)
    return setValue(self, "ScanHz", "SetScanHz", value)
end

function State:ResetCombatState()
    if self.Destroyed then return false end
    local feature = self.Features and self.Features.AutoBlock
    if not feature or type(feature.ResetCombatState) ~= "function" then return false end
    local ok, result = pcall(feature.ResetCombatState, feature, "manual reset")
    return ok and result ~= false
end

function State:GetToggle(name)
    return self.Toggles[name] == true
end

function State:GetValue(name)
    return self.Values[name]
end

function State:GetAutoBlockConfig()
    local feature = self.Features and self.Features.AutoBlock
    if not feature or type(feature.GetConfig) ~= "function" then return nil end
    return feature:GetConfig()
end

function State:GetDebugInfo()
    local feature = self.Features and self.Features.AutoBlock
    if not feature or type(feature.GetDebugInfo) ~= "function" then return nil end
    return feature:GetDebugInfo()
end

function State:Start()
    if self.Destroyed or self.Started then return false end
    self.Started = true
    return syncRuntime(self)
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    local features = self.Features
    self.Features = nil

    if type(features) == "table" then
        for _, feature in pairs(features) do
            if type(feature) == "table" and type(feature.Destroy) == "function" then
                pcall(feature.Destroy, feature)
            end
        end
    end

    self.AnimationData = nil

    if env[STATE_KEY] == self then
        env[STATE_KEY] = nil
    end

    if env.__DEPHUB and env.__DEPHUB.TSB == self then
        env.__DEPHUB.TSB = nil
    end
end

local okStart, started = pcall(State.Start, State)
if not okStart or not started then
    pcall(State.Destroy, State)
    return false
end

return State

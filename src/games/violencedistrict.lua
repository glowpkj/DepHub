local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer

local env=type(getgenv)=="function" and getgenv() or _G
local STATE_KEY="__DEPHUB_VD"
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION="0.0.1"

local previous=type(env[STATE_KEY])=="table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy)=="function" then
    pcall(previous.Destroy,previous)
end

local function compile(source)
    if type(loadstring)~="function" then return false,"loadstring indisponivel" end
    local ok,chunk,err=pcall(loadstring,source)
    if not ok or type(chunk)~="function" then return false,tostring(err or chunk) end
    return true,chunk
end

local function loadFeature(path,context)
    local okGet,source=pcall(function()
        return game:HttpGet(BASE_URL..path)
    end)
    if not okGet or type(source)~="string" or #source==0 then return false,tostring(source) end
    local okCompile,chunk=compile(source)
    if not okCompile then return false,chunk end
    local okRun,factory=pcall(chunk)
    if not okRun or type(factory)~="table" or type(factory.new)~="function" then return false,tostring(factory) end
    local okNew,feature=pcall(factory.new,context)
    if not okNew or type(feature)~="table" then return false,tostring(feature) end
    return true,feature
end

local State={
    Started=false,
    Destroyed=false,
    Version=VERSION,
    Features={},
    Toggles={
        PlayerESP=false,
        AutoRepair=false,
        AutoSkillCheck=false,
        Debug=false
    },
    Values={
        RepairRange=14
    }
}

local context={
    Players=Players,
    RunService=RunService,
    ReplicatedStorage=ReplicatedStorage,
    Workspace=Workspace,
    LocalPlayer=LocalPlayer,
    RepairRange=State.Values.RepairRange,
    AutoRepair=false,
    AutoSkillCheck=false,
    Debug=false
}

local okESP,ESP=loadFeature("src/games/features/violencedistrict/esp.lua",context)
if not okESP then return false end
local okGenerator,Generator=loadFeature("src/games/features/violencedistrict/generator.lua",context)
if not okGenerator then
    pcall(ESP.Destroy,ESP)
    return false
end

State.Features.ESP=ESP
State.Features.Generator=Generator

env[STATE_KEY]=State
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.ViolenceDistrict=State

local function syncGenerator(self)
    local feature=self.Features.Generator
    if not feature then return false end
    local shouldRun=self.Toggles.AutoRepair or self.Toggles.AutoSkillCheck
    if shouldRun and not feature.Enabled then return feature:Enable()~=false end
    if not shouldRun and feature.Enabled then return feature:Disable()~=false end
    return true
end

function State:SetPlayerESP(value)
    if self.Destroyed then return false end
    value=value==true
    local feature=self.Features.ESP
    if not feature then return false end
    if self.Toggles.PlayerESP~=value then
        local ok=value and feature:Enable() or feature:Disable()
        if ok==false then return false end
    end
    self.Toggles.PlayerESP=value
    return true
end

function State:SetAutoRepair(value)
    if self.Destroyed then return false end
    value=value==true
    local feature=self.Features.Generator
    if not feature or feature:SetAutoRepair(value)==false then return false end
    self.Toggles.AutoRepair=value
    return syncGenerator(self)
end

function State:SetAutoSkillCheck(value)
    if self.Destroyed then return false end
    value=value==true
    local feature=self.Features.Generator
    if not feature or feature:SetAutoSkillCheck(value)==false then return false end
    self.Toggles.AutoSkillCheck=value
    return syncGenerator(self)
end

function State:SetDebug(value)
    if self.Destroyed then return false end
    value=value==true
    local esp=self.Features.ESP
    local generator=self.Features.Generator
    if esp then esp:SetDebug(value) end
    if generator then generator:SetDebug(value) end
    self.Toggles.Debug=value
    return true
end

function State:SetRepairRange(value)
    if self.Destroyed then return false end
    value=tonumber(value)
    if not value then return false end
    local feature=self.Features.Generator
    if not feature or feature:SetRepairRange(value)==false then return false end
    self.Values.RepairRange=feature.RepairRange
    return true
end

function State:GetToggle(name)
    return self.Toggles[name]==true
end

function State:GetValue(name)
    return self.Values[name]
end

function State:GetGeneratorDebugInfo()
    local feature=self.Features.Generator
    return feature and feature:GetDebugInfo() or nil
end

function State:Start()
    if self.Destroyed or self.Started then return false end
    self.Started=true
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    for _,feature in pairs(self.Features or {}) do
        if type(feature)=="table" and type(feature.Destroy)=="function" then
            pcall(feature.Destroy,feature)
        end
    end
    self.Features=nil
    if env[STATE_KEY]==self then env[STATE_KEY]=nil end
    if env.__DEPHUB and env.__DEPHUB.ViolenceDistrict==self then
        env.__DEPHUB.ViolenceDistrict=nil
    end
end

if not LocalPlayer then
    pcall(State.Destroy,State)
    return false
end

local okStart,started=pcall(State.Start,State)
if not okStart or not started then
    pcall(State.Destroy,State)
    return false
end

return State

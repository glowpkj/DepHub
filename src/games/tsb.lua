local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
local STATE_KEY="__DEPHUB_TSB"
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION="0.0.2"
local previous=type(env[STATE_KEY])=="table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end
local function compile(source)
    if type(loadstring)~="function" then return false,"loadstring indisponivel" end
    local ok,chunk,err=pcall(loadstring,source)
    if not ok or type(chunk)~="function" then return false,tostring(err or chunk) end
    return true,chunk
end
local function loadFeature(path,context)
    local okGet,source=pcall(function() return game:HttpGet(BASE_URL..path) end)
    if not okGet or type(source)~="string" or #source==0 then return false,tostring(source) end
    local okCompile,chunk=compile(source) if not okCompile then return false,chunk end
    local okRun,factory=pcall(chunk) if not okRun or type(factory)~="table" or type(factory.new)~="function" then return false,tostring(factory) end
    local okNew,feature=pcall(factory.new,context) if not okNew or type(feature)~="table" then return false,tostring(feature) end
    return true,feature
end
local State={Started=false,Destroyed=false,Version=VERSION,Features={},Toggles={AutoBlock=false,M1AfterBlock=false,M1Catch=false,ShowDetectionBox=false},Values={NormalRange=12,SpecialRange=50,SkillRange=50,SkillHold=1.2,DetectionBoxSize=12}}
local context={Players=Players,RunService=RunService,VirtualInputManager=VirtualInputManager,Workspace=Workspace,LocalPlayer=LocalPlayer,NormalRange=State.Values.NormalRange,SpecialRange=State.Values.SpecialRange,SkillRange=State.Values.SkillRange,SkillHold=State.Values.SkillHold,DetectionBoxSize=State.Values.DetectionBoxSize,M1AfterBlock=false,M1Catch=false,ShowDetectionBox=false}
local okAutoBlock,AutoBlock=loadFeature("src/games/features/tsb/autoblock.lua",context)
if not okAutoBlock then return false end
State.Features.AutoBlock=AutoBlock
env[STATE_KEY]=State env.__DEPHUB=env.__DEPHUB or {} env.__DEPHUB.TSB=State
function State:SetAutoBlock(v) if self.Destroyed then return false end v=v==true if self.Toggles.AutoBlock==v then return true end local f=self.Features.AutoBlock if not f then return false end local ok=v and f:Enable() or f:Disable() if ok==false then return false end self.Toggles.AutoBlock=v return true end
function State:SetM1AfterBlock(v) if self.Destroyed then return false end v=v==true local f=self.Features.AutoBlock if not f or f:SetM1AfterBlock(v)==false then return false end self.Toggles.M1AfterBlock=v return true end
function State:SetM1Catch(v) if self.Destroyed then return false end v=v==true local f=self.Features.AutoBlock if not f or f:SetM1Catch(v)==false then return false end self.Toggles.M1Catch=v return true end
function State:SetShowDetectionBox(v) if self.Destroyed then return false end v=v==true local f=self.Features.AutoBlock if not f or f:SetShowDetectionBox(v)==false then return false end self.Toggles.ShowDetectionBox=v return true end
local function setValue(self,key,method,value) if self.Destroyed then return false end value=tonumber(value) if not value then return false end local f=self.Features.AutoBlock if not f or f[method](f,value)==false then return false end self.Values[key]=f.Config[key] return true end
function State:SetNormalRange(v) return setValue(self,"NormalRange","SetNormalRange",v) end
function State:SetSpecialRange(v) return setValue(self,"SpecialRange","SetSpecialRange",v) end
function State:SetSkillRange(v) return setValue(self,"SkillRange","SetSkillRange",v) end
function State:SetSkillHold(v) return setValue(self,"SkillHold","SetSkillHold",v) end
function State:SetDetectionBoxSize(v) return setValue(self,"DetectionBoxSize","SetDetectionBoxSize",v) end
function State:GetToggle(name) return self.Toggles[name]==true end
function State:GetValue(name) return self.Values[name] end
function State:GetAutoBlockConfig() local f=self.Features.AutoBlock return f and f:GetConfig() or nil end
function State:Start() if self.Destroyed or self.Started then return false end self.Started=true return true end
function State:Destroy() if self.Destroyed then return end self.Destroyed=true local f=self.Features and self.Features.AutoBlock if f and type(f.Destroy)=="function" then pcall(f.Destroy,f) end self.Features=nil if env[STATE_KEY]==self then env[STATE_KEY]=nil end if env.__DEPHUB and env.__DEPHUB.TSB==self then env.__DEPHUB.TSB=nil end end
if not LocalPlayer then pcall(State.Destroy,State) return false end
local okStart,started=pcall(State.Start,State) if not okStart or not started then pcall(State.Destroy,State) return false end
return State

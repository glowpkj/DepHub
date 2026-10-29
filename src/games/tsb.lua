local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall
local pairs=pairs

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer

local env=type(getgenv)=="function" and getgenv() or _G
local STATE_KEY="__DEPHUB_TSB"
local BASE_URL=((type(getgenv)=="function" and getgenv() or _G).__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION="0.0.10"

local previous=type(env[STATE_KEY])=="table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end
if not LocalPlayer then return false end

local function compile(source)
    if type(loadstring)~="function" then return false,"loadstring indisponivel" end
    local ok,chunk,compileError=pcall(loadstring,source)
    if not ok or type(chunk)~="function" then return false,tostring(compileError or chunk) end
    return true,chunk
end
local function fetch(path)
    local cb=tostring((env.__DEPHUB or {}).SourceCacheBust or "")
    local ok,source=pcall(function() return game:HttpGet(BASE_URL..path..(cb~="" and ("?cb="..cb) or "")) end)
    if not ok or type(source)~="string" or #source==0 then return false,tostring(source) end
    return true,source
end
local function loadModule(path)
    local okFetch,source=fetch(path) if not okFetch then return false,source end
    local okCompile,chunk=compile(source) if not okCompile then return false,chunk end
    local okRun,result=pcall(chunk) if not okRun then return false,tostring(result) end
    return true,result
end
local function loadFeature(path,context)
    local okModule,factory=loadModule(path) if not okModule then return false,factory end
    if type(factory)~="table" or type(factory.new)~="function" then return false,"factory invalida: "..path end
    local okNew,feature=pcall(factory.new,context) if not okNew or type(feature)~="table" then return false,tostring(feature) end
    return true,feature
end

local okAnimations,AnimationData=loadModule("src/games/features/tsb/animations.lua")
if not okAnimations or type(AnimationData)~="table" then return false end
if type(AnimationData.Groups)~="table" or type(AnimationData.SkillIds)~="table" then return false end

local State={
    Started=false,Destroyed=false,Version=VERSION,Features={},AnimationData=AnimationData,
    Toggles={AutoBlock=false,M1AfterBlock=false,FaceAttacker=true,DashBlock=false,SkillBlock=false,FacingCheck=true,Prediction=true,UnknownLogger=false,ShowDetectionBox=false,Debug=false},
    Values={NormalRange=12,SpecialRange=50,SkillRange=50,SkillHold=1.2,DetectionBoxSize=12,ScanHz=45,FacingDot=-0.05,PredictionTime=0.12,PredictionExtra=3,CounterDelay=0.07}
}

local context={
    Players=Players,RunService=RunService,Workspace=Workspace,LocalPlayer=LocalPlayer,AnimationData=AnimationData,
    M1Block=State.Toggles.AutoBlock,M1AfterBlock=State.Toggles.M1AfterBlock,FaceAttacker=State.Toggles.FaceAttacker,
    DashBlock=State.Toggles.DashBlock,SkillBlock=State.Toggles.SkillBlock,FacingCheck=State.Toggles.FacingCheck,
    Prediction=State.Toggles.Prediction,UnknownLogger=State.Toggles.UnknownLogger,ShowDetectionBox=State.Toggles.ShowDetectionBox,Debug=State.Toggles.Debug,
    NormalRange=State.Values.NormalRange,SpecialRange=State.Values.SpecialRange,SkillRange=State.Values.SkillRange,SkillHold=State.Values.SkillHold,
    DetectionBoxSize=State.Values.DetectionBoxSize,ScanHz=State.Values.ScanHz,FacingDot=State.Values.FacingDot,
    PredictionTime=State.Values.PredictionTime,PredictionExtra=State.Values.PredictionExtra,CounterDelay=State.Values.CounterDelay
}

local okAutoBlock,AutoBlock=loadFeature("src/games/features/tsb/autoblock-v3.lua",context)
if not okAutoBlock then return false end
State.Features.AutoBlock=AutoBlock
env[STATE_KEY]=State
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.TSB=State

local function releaseCombatInputs()
    local character=LocalPlayer and LocalPlayer.Character
    local remote=character and character:FindFirstChild("Communicate")
    if not remote or not remote:IsA("RemoteEvent") then return false end
    pcall(remote.FireServer,remote,{Goal="KeyRelease",Key=Enum.KeyCode.F})
    pcall(remote.FireServer,remote,{Goal="LeftClickRelease",Mobile=true})
    return true
end
local function syncRuntime(self)
    if self.Destroyed then return false end
    local feature=self.Features and self.Features.AutoBlock if not feature then return false end
    local shouldRun=self.Toggles.AutoBlock or self.Toggles.DashBlock or self.Toggles.SkillBlock
    if shouldRun and not feature.Enabled then return feature:Enable()~=false end
    if not shouldRun and feature.Enabled then local ok=feature:Disable()~=false releaseCombatInputs() return ok end
    return true
end
local function setToggle(self,key,method,value,needsSync)
    if self.Destroyed then return false end
    local feature=self.Features and self.Features.AutoBlock
    if not feature or type(feature[method])~="function" then return false end
    value=value==true
    local ok,result=pcall(feature[method],feature,value) if not ok or result==false then return false end
    self.Toggles[key]=value if needsSync then return syncRuntime(self) end return true
end
local function setValue(self,key,method,value)
    if self.Destroyed then return false end value=tonumber(value) if not value then return false end
    local feature=self.Features and self.Features.AutoBlock
    if not feature or type(feature[method])~="function" then return false end
    local ok,result=pcall(feature[method],feature,value) if not ok or result==false then return false end
    local config=type(feature.GetConfig)=="function" and feature:GetConfig() or nil
    if type(config)=="table" and config[key]~=nil then self.Values[key]=config[key] else self.Values[key]=value end
    return true
end

function State:SetAutoBlock(value)
    if self.Destroyed then return false end
    value=value==true
    -- One master switch; manual attacks remain manual, never queued as counters.
    local feature=self.Features and self.Features.AutoBlock
    if not feature then return false end
    feature:SetM1AfterBlock(false)
    feature:SetM1Block(value) feature:SetDashBlock(value) feature:SetSkillBlock(value)
    self.Toggles.AutoBlock=value self.Toggles.DashBlock=value self.Toggles.SkillBlock=value self.Toggles.M1AfterBlock=false
    return syncRuntime(self)
end
function State:SetM1AfterBlock(value) return setToggle(self,"M1AfterBlock","SetM1AfterBlock",value,false) end
function State:SetFaceAttacker(value) return setToggle(self,"FaceAttacker","SetFaceAttacker",value,false) end
function State:SetDashBlock(value) return setToggle(self,"DashBlock","SetDashBlock",value,true) end
function State:SetSkillBlock(value) return setToggle(self,"SkillBlock","SetSkillBlock",value,true) end
function State:SetFacingCheck(value) return setToggle(self,"FacingCheck","SetFacingCheck",value,false) end
function State:SetPrediction(value) return setToggle(self,"Prediction","SetPrediction",value,false) end
function State:SetUnknownLogger(value) return setToggle(self,"UnknownLogger","SetUnknownLogger",value,false) end
function State:SetShowDetectionBox(value) return setToggle(self,"ShowDetectionBox","SetShowDetectionBox",value,false) end
function State:SetDebug(value) return setToggle(self,"Debug","SetDebug",value,false) end
function State:SetNormalRange(value) return setValue(self,"NormalRange","SetNormalRange",value) end
function State:SetSpecialRange(value) return setValue(self,"SpecialRange","SetSpecialRange",value) end
function State:SetSkillRange(value) return setValue(self,"SkillRange","SetSkillRange",value) end
function State:SetSkillHold(value) return setValue(self,"SkillHold","SetSkillHold",value) end
function State:SetDetectionBoxSize(value) return setValue(self,"DetectionBoxSize","SetDetectionBoxSize",value) end
function State:SetScanHz(value) return setValue(self,"ScanHz","SetScanHz",value) end
function State:SetFacingDot(value) return setValue(self,"FacingDot","SetFacingDot",value) end
function State:SetPredictionTime(value) return setValue(self,"PredictionTime","SetPredictionTime",value) end
function State:SetPredictionExtra(value) return setValue(self,"PredictionExtra","SetPredictionExtra",value) end
function State:SetCounterDelay(value) return setValue(self,"CounterDelay","SetCounterDelay",value) end

function State:ResetCombatState()
    if self.Destroyed then return false end
    local feature=self.Features and self.Features.AutoBlock
    if not feature or type(feature.ResetCombatState)~="function" then return false end
    local ok,result=pcall(feature.ResetCombatState,feature,"manual reset") return ok and result~=false
end
function State:GetToggle(name) return self.Toggles[name]==true end
function State:GetValue(name) return self.Values[name] end
function State:GetAutoBlockConfig()
    local feature=self.Features and self.Features.AutoBlock if not feature or type(feature.GetConfig)~="function" then return nil end return feature:GetConfig()
end
function State:GetDebugInfo()
    local feature=self.Features and self.Features.AutoBlock if not feature or type(feature.GetDebugInfo)~="function" then return nil end return feature:GetDebugInfo()
end
function State:Start() if self.Destroyed or self.Started then return false end self.Started=true return syncRuntime(self) end
function State:Destroy()
    if self.Destroyed then return end self.Destroyed=true releaseCombatInputs()
    local features=self.Features self.Features=nil
    if type(features)=="table" then for _,feature in pairs(features) do if type(feature)=="table" and type(feature.Destroy)=="function" then pcall(feature.Destroy,feature) end end end
    self.AnimationData=nil
    if env[STATE_KEY]==self then env[STATE_KEY]=nil end
    if env.__DEPHUB and env.__DEPHUB.TSB==self then env.__DEPHUB.TSB=nil end
end

local okStart,started=pcall(State.Start,State)
if not okStart or not started then pcall(State.Destroy,State) return false end

local UI = (env.__DEPHUB or {}).UI
if type(UI) == "table" and type(UI.CreateTab) == "function" then
    local tabs = {}
    local function section(tabName, sectionName, column)
        local tab = tabs[tabName]
        if not tab then
            tab = UI:CreateTab(tabName, "All")
            tabs[tabName] = tab
        end
        if not tab then return nil end
        return tab:CreateSection(sectionName, column or "Left")
    end
    local function notify(title, message)
        if type(UI.Notify) == "function" then UI:Notify(title, message) end
    end

    local autoblock = section("Autoblock", "Bloqueio", "Left")
    if autoblock then
        autoblock:CreateToggle("Auto block", State.Toggles.AutoBlock, function(v) State:SetAutoBlock(v) end)
        autoblock:CreateToggle("M1 após bloquear", State.Toggles.M1AfterBlock, function(v) State:SetM1AfterBlock(v) end)
        autoblock:CreateToggle("Encarar atacante", State.Toggles.FaceAttacker, function(v) State:SetFaceAttacker(v) end)
        autoblock:CreateToggle("Bloquear dash", State.Toggles.DashBlock, function(v) State:SetDashBlock(v) end)
        autoblock:CreateToggle("Bloquear skills", State.Toggles.SkillBlock, function(v) State:SetSkillBlock(v) end)
        autoblock:CreateToggle("Checar direção (facing)", State.Toggles.FacingCheck, function(v) State:SetFacingCheck(v) end)
        autoblock:CreateToggle("Previsão", State.Toggles.Prediction, function(v) State:SetPrediction(v) end)
    end

    local ranges = section("Ranges", "Alcance e tempo", "Left")
    if ranges then
        ranges:CreateSlider("Alcance normal", 0, 60, State.Values.NormalRange, function(v) State:SetNormalRange(v) end)
        ranges:CreateSlider("Alcance especial", 0, 120, State.Values.SpecialRange, function(v) State:SetSpecialRange(v) end)
        ranges:CreateSlider("Alcance de skill", 0, 120, State.Values.SkillRange, function(v) State:SetSkillRange(v) end)
        ranges:CreateSlider("Tempo de skill", 0, 5, State.Values.SkillHold, function(v) State:SetSkillHold(v) end)
        ranges:CreateSlider("Atraso do counter", 0, 1, State.Values.CounterDelay, function(v) State:SetCounterDelay(v) end)
    end

    local detection = section("Detection", "Detecção", "Left")
    if detection then
        detection:CreateSlider("Tamanho da caixa", 0, 40, State.Values.DetectionBoxSize, function(v) State:SetDetectionBoxSize(v) end)
        detection:CreateSlider("Scan (Hz)", 1, 120, State.Values.ScanHz, function(v) State:SetScanHz(v) end)
        detection:CreateSlider("Facing dot", -1, 1, State.Values.FacingDot, function(v) State:SetFacingDot(v) end)
        detection:CreateToggle("Mostrar caixa de detecção", State.Toggles.ShowDetectionBox, function(v) State:SetShowDetectionBox(v) end)
        detection:CreateToggle("Log de desconhecidos", State.Toggles.UnknownLogger, function(v) State:SetUnknownLogger(v) end)
    end

    local prediction = section("Prediction", "Previsão", "Left")
    if prediction then
        prediction:CreateSlider("Tempo de previsão", 0, 1, State.Values.PredictionTime, function(v) State:SetPredictionTime(v) end)
        prediction:CreateSlider("Extra de previsão", 0, 12, State.Values.PredictionExtra, function(v) State:SetPredictionExtra(v) end)
    end

    local debug = section("Debug", "Diagnóstico", "Left")
    if debug then
        local function statusText()
            local info = State:GetDebugInfo()
            return type(info) == "table" and tostring(info) or "Sem dados de debug."
        end
        debug:CreateParagraph("Estado", statusText())
        debug:CreateToggle("Debug", State.Toggles.Debug, function(v) State:SetDebug(v) end)
        debug:CreateButton("Resetar combate", function()
            local ok = State:ResetCombatState()
            notify("TSB", ok and "Estado de combate resetado." or "Não foi possível resetar.")
        end)
    end
end

-- Report this backend's own structure and live state into the shared Debug tab.
-- The block key is the "Communicate" RemoteEvent under the character and the
-- "Live" folder under Workspace -- both are what a TSB update would rename.
do
    local Diag=env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.Probe)=="function" then
        Diag:SetEnvironment({["TSB versao"]=VERSION})
        Diag:RegisterModule("features/tsb/animations.lua")
        Diag:RegisterModule("features/tsb/autoblock-v3.lua")
        Diag:Module("features/tsb/animations.lua",type(AnimationData)=="table",type(AnimationData)=="table" and "carregado" or "ausente")
        Diag:Module("features/tsb/autoblock-v3.lua",State.Features.AutoBlock~=nil,State.Features.AutoBlock and "carregado" or "ausente")
        Diag:Probe("Players.LocalPlayer",LocalPlayer~=nil,LocalPlayer and LocalPlayer.Name or "ausente")
        local character=LocalPlayer and LocalPlayer.Character
        local communicate=character and character:FindFirstChild("Communicate")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local humanoid=character and character:FindFirstChildWhichIsA("Humanoid")
        Diag:Probe("Character.Communicate",communicate and communicate:IsA("RemoteEvent") or false,
            communicate and communicate.ClassName or "ausente (bloqueio/counters falham)")
        Diag:Probe("Character.HumanoidRootPart",root~=nil,root and root.ClassName or "ausente")
        Diag:Probe("Character.Humanoid",humanoid~=nil,humanoid and humanoid.ClassName or "ausente")
        Diag:Probe("Workspace.Live",Workspace:FindFirstChild("Live")~=nil,
            Workspace:FindFirstChild("Live") and Workspace.Live.ClassName or "ausente (sem pasta Live, nenhum alvo fica pronto)")
        Diag:Probe("AnimationData.Groups",type(AnimationData.Groups)=="table","grupos de animacao")
        Diag:Probe("AnimationData.SkillIds",type(AnimationData.SkillIds)=="table","ids de skill")
        Diag:Feature("TSB.AutoBlock",function() return State.Toggles.AutoBlock and "ON" or "off" end)
        Diag:Feature("TSB.M1AfterBlock",function() return State.Toggles.M1AfterBlock and "ON" or "off" end)
        Diag:Feature("TSB.DashBlock",function() return State.Toggles.DashBlock and "ON" or "off" end)
        Diag:Feature("TSB.SkillBlock",function() return State.Toggles.SkillBlock and "ON" or "off" end)
        Diag:Feature("TSB.Estado",function()
            local info=State:GetDebugInfo()
            if type(info)~="table" then return "sem dados" end
            return "bloqueio="..tostring(info.BlockActive).." fonte="..tostring(info.BlockSource)
                .." alvos="..tostring(info.TrackedPlayers).." blocos="..tostring(info.Blocks)
        end)
        Diag:Feature("TSB.Remote",function()
            local info=State:GetDebugInfo()
            return type(info)=="table" and tostring(info.Remote) or "sem dados"
        end)
        Diag:Feature("TSB.Desconhecidos",function()
            local info=State:GetDebugInfo()
            if type(info)~="table" then return "0" end
            return tostring(info.UnknownAnimations).." animacoes nao mapeadas"
        end)
        Diag:Feature("TSB.LastError",function()
            local info=State:GetDebugInfo()
            return type(info)=="table" and tostring(info.LastError or "none") or "sem dados"
        end)
        if type(Diag.Watch)=="function" then
            Diag:Watch("TSB bloqueio ativo",function() local info=State:GetDebugInfo() return type(info)=="table" and tostring(info.BlockActive) or "?" end)
            Diag:Watch("TSB alvos",function() local info=State:GetDebugInfo() return type(info)=="table" and tostring(info.TrackedPlayers) or "?" end)
            Diag:Watch("TSB remote",function() local info=State:GetDebugInfo() return type(info)=="table" and tostring(info.Remote) or "?" end)
        end
        if type(Diag.Command)=="function" then
            Diag:Command("tsb",function()
                local info=State:GetDebugInfo()
                if type(info)~="table" then return "sem dados de debug" end
                return "bloqueio="..tostring(info.BlockActive).." fonte="..tostring(info.BlockSource)
                    .." alvos="..tostring(info.TrackedPlayers).." blocos="..tostring(info.Blocks)
                    .." releases="..tostring(info.Releases).." remote="..tostring(info.Remote)
                    .." desconhecidos="..tostring(info.UnknownAnimations)
            end)
            Diag:Command("tsb-autoblock",function(argument)
                local on=argument~="off"
                State:SetAutoBlock(on)
                return "AutoBlock="..tostring(on)
            end)
        end
        -- Sniff the character remote the block/counters fire through.
        if type(Diag.SniffRemote)=="function" and communicate then
            Diag:SniffRemote(communicate,"TSB.Communicate")
        end
    end
end

return State


local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall

local RunService=game:GetService("RunService")
local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local previous=env.__DEPHUB_TSB_FRONTEND
if type(previous)=="table" and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end
local Backend=env.__DEPHUB and env.__DEPHUB.TSB
if type(Backend)~="table" then return false end

local okSource,source=pcall(function() return game:HttpGet(BASE_URL.."library/compact.lua") end)
if not okSource or type(source)~="string" or #source==0 then return false end
local okCompile,chunk=pcall(loadstring,source)
if not okCompile or type(chunk)~="function" then return false end
local okLibrary,Library=pcall(chunk)
if not okLibrary or type(Library)~="table" or type(Library.new)~="function" then return false end

local UI=Library.new({Id="TSB",Title="DEPHUB",Subtitle="THE STRONGEST BATTLEGROUNDS",Accent=Color3.fromRGB(111,238,190),Width=292,Height=500,Open=true})
if type(UI)~="table" then return false end

UI:AddSection("COMBAT")
local autoBlock,autoSettings=UI:AddFeature("Auto Block",Backend:GetToggle("AutoBlock"),function(value) return Backend:SetAutoBlock(value) end)
UI:AddToggle("M1 After Block",Backend:GetToggle("M1AfterBlock"),function(value) return Backend:SetM1AfterBlock(value) end,autoSettings)
UI:AddToggle("Face Attacker",Backend:GetToggle("FaceAttacker"),function(value) return Backend:SetFaceAttacker(value) end,autoSettings)
UI:AddToggle("Facing Check",Backend:GetToggle("FacingCheck"),function(value) return Backend:SetFacingCheck(value) end,autoSettings)
UI:AddToggle("Prediction",Backend:GetToggle("Prediction"),function(value) return Backend:SetPrediction(value) end,autoSettings)
UI:AddToggle("Show Hitbox",Backend:GetToggle("ShowDetectionBox"),function(value) return Backend:SetShowDetectionBox(value) end,autoSettings)
UI:AddSlider("Hitbox Size",2,40,1,Backend:GetValue("DetectionBoxSize") or 12,function(value) return Backend:SetDetectionBoxSize(value) end,autoSettings)
UI:AddSlider("M1 Range",2,30,1,Backend:GetValue("NormalRange") or 12,function(value) return Backend:SetNormalRange(value) end,autoSettings)
UI:AddSlider("Prediction Time",0,0.35,0.01,Backend:GetValue("PredictionTime") or 0.12,function(value) return Backend:SetPredictionTime(value) end,autoSettings)
UI:AddSlider("Prediction Extra",0,8,0.5,Backend:GetValue("PredictionExtra") or 3,function(value) return Backend:SetPredictionExtra(value) end,autoSettings)
UI:AddSlider("Counter Delay",0.02,0.35,0.01,Backend:GetValue("CounterDelay") or 0.07,function(value) return Backend:SetCounterDelay(value) end,autoSettings)
UI:AddSlider("Scan Hz",10,60,5,Backend:GetValue("ScanHz") or 45,function(value) return Backend:SetScanHz(value) end,autoSettings)

local dash,dashSettings=UI:AddFeature("Dash Block",Backend:GetToggle("DashBlock"),function(value) return Backend:SetDashBlock(value) end)
UI:AddSlider("Dash Range",5,80,1,Backend:GetValue("SpecialRange") or 50,function(value) return Backend:SetSpecialRange(value) end,dashSettings)

local skill,skillSettings=UI:AddFeature("Skill Block",Backend:GetToggle("SkillBlock"),function(value) return Backend:SetSkillBlock(value) end)
UI:AddSlider("Skill Range",5,80,1,Backend:GetValue("SkillRange") or 50,function(value) return Backend:SetSkillRange(value) end,skillSettings)
UI:AddSlider("Skill Hold",0.1,2,0.1,Backend:GetValue("SkillHold") or 1.2,function(value) return Backend:SetSkillHold(value) end,skillSettings)

UI:AddSection("DIAGNOSTICS")
local debug,debugSettings=UI:AddFeature("Debug",Backend:GetToggle("Debug"),function(value) return Backend:SetDebug(value) end)
UI:AddToggle("Unknown Anim Logger",Backend:GetToggle("UnknownLogger"),function(value) return Backend:SetUnknownLogger(value) end,debugSettings)
UI:AddButton("RESET COMBAT STATE",function() local ok=Backend:ResetCombatState() return ok and "RESET DONE" or "RESET FAILED" end,debugSettings)
local Status=UI:AddStatus("LIVE STATUS",debugSettings,194)

local alive=true
local elapsed=0
local statusConnection
statusConnection=RunService.Heartbeat:Connect(function(dt)
    if not alive or UI.Destroyed or not debug:Get() then return end
    elapsed=elapsed+dt
    if elapsed<0.25 then return end
    elapsed=0
    local info=Backend:GetDebugInfo()
    if type(info)~="table" then Status:Set("backend unavailable") return end
    Status:Set(
        "runtime: "..tostring(info.Runtime)..
        "\ncharacter: "..tostring(info.Character).." | remote: "..tostring(info.Remote)..
        "\ntracked: "..tostring(info.TrackedPlayers or 0).." | block: "..tostring(info.BlockActive)..
        "\nsource: "..tostring(info.BlockSource or "none").." | total: "..tostring(info.Blocks or 0)..
        "\nplayer: "..tostring(info.LastPlayer or "none").." | dist: "..string.format("%.1f",tonumber(info.LastDistance) or 0)..
        "\npred dist: "..string.format("%.1f",tonumber(info.LastPredictedDistance) or 0).." | closing: "..string.format("%.1f",tonumber(info.LastClosingSpeed) or 0)..
        "\nfacing: "..string.format("%.2f",tonumber(info.LastFacing) or 0).." | rejected: "..tostring(info.FacingRejected or 0)..
        "\npred blocks: "..tostring(info.PredictionBlocks or 0).." | unknown: "..tostring(info.UnknownAnimations or 0)..
        "\ncounters: "..tostring(info.Counters or 0).." | pending: "..tostring(info.CounterPending or false)..
        "\nid: "..tostring(info.LastAnimation or "none").." | err: "..tostring(info.LastError or "none")
    )
end)

local baseDestroy=UI.Destroy
function UI:Destroy()
    if self.Destroyed then return end
    alive=false
    if statusConnection then pcall(statusConnection.Disconnect,statusConnection) statusConnection=nil end
    pcall(baseDestroy,self)
    if env.__DEPHUB_TSB_FRONTEND==self then env.__DEPHUB_TSB_FRONTEND=nil end
    if env.__DEPHUB and env.__DEPHUB.TSBUI==self then env.__DEPHUB.TSBUI=nil end
end

env.__DEPHUB_TSB_FRONTEND=UI
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.TSBUI=UI
return UI

local game=game
local type=type
local tostring=tostring
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

local UI=Library.new({
    Id="TSB",
    Title="DEPHUB",
    Subtitle="THE STRONGEST BATTLEGROUNDS",
    Accent=Color3.fromRGB(111,238,190),
    Width=292,
    Height=470,
    Open=true
})
if type(UI)~="table" then return false end

UI:AddSection("COMBAT")
local autoBlock,autoSettings=UI:AddFeature("Auto Block",Backend:GetToggle("AutoBlock"),function(v)
    return Backend:SetAutoBlock(v)
end)
UI:AddToggle("M1 After Block",Backend:GetToggle("M1AfterBlock"),function(v)
    return Backend:SetM1AfterBlock(v)
end,autoSettings)
UI:AddToggle("M1 Catch",Backend:GetToggle("M1Catch"),function(v)
    return Backend:SetM1Catch(v)
end,autoSettings)
UI:AddToggle("Show Hitbox",Backend:GetToggle("ShowDetectionBox"),function(v)
    return Backend:SetShowDetectionBox(v)
end,autoSettings)
UI:AddSlider("Hitbox Size",2,40,1,Backend:GetValue("DetectionBoxSize") or 12,function(v)
    return Backend:SetDetectionBoxSize(v)
end,autoSettings)
UI:AddSlider("M1 Range",2,30,1,Backend:GetValue("NormalRange") or 12,function(v)
    return Backend:SetNormalRange(v)
end,autoSettings)

local dash,dashSettings=UI:AddFeature("Dash Block",Backend:GetToggle("DashBlock"),function(v)
    return Backend:SetDashBlock(v)
end)
UI:AddSlider("Dash Range",5,80,1,Backend:GetValue("SpecialRange") or 50,function(v)
    return Backend:SetSpecialRange(v)
end,dashSettings)

local skill,skillSettings=UI:AddFeature("Skill Block",Backend:GetToggle("SkillBlock"),function(v)
    return Backend:SetSkillBlock(v)
end)
UI:AddSlider("Skill Range",5,80,1,Backend:GetValue("SkillRange") or 50,function(v)
    return Backend:SetSkillRange(v)
end,skillSettings)
UI:AddSlider("Skill Hold",0.1,2,0.1,Backend:GetValue("SkillHold") or 1.2,function(v)
    return Backend:SetSkillHold(v)
end,skillSettings)
UI:AddSlider("Scan Hz",10,60,5,Backend:GetValue("ScanHz") or 30,function(v)
    return Backend:SetScanHz(v)
end,skillSettings)

UI:AddSection("DIAGNOSTICS")
local debug,debugSettings=UI:AddFeature("Debug",Backend:GetToggle("Debug"),function(v)
    return Backend:SetDebug(v)
end)
UI:AddButton("RESET COMBAT STATE",function()
    local ok=Backend:ResetCombatState()
    return ok and "RESET DONE" or "RESET FAILED"
end,debugSettings)
local Status=UI:AddStatus("LIVE STATUS",debugSettings,142)

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

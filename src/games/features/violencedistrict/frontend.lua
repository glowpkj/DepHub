local env=type(getgenv)=="function" and getgenv() or _G
local Backend=(env.__DEPHUB or {}).ViolenceDistrict
if type(Backend)~="table" then return false end
local previous=env.__DEPHUB_VD_FRONTEND
if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous,true) end
local base=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local chunk,err=loadstring(game:HttpGet(base.."src/frontend/linoria.lua?ui=0.1.0"));assert(chunk,err)
local UI=chunk().new({Id="ViolenceDistrict",Title="DEPHUB",Subtitle="VIOLENCE DISTRICT",Backend=Backend})
UI:AddSection("Players")
UI:AddToggle("Player ESP",Backend:GetToggle("PlayerESP"),function(v) return Backend:SetPlayerESP(v) end)
UI:AddSection("Generator")
local _,repair=UI:AddFeature("Auto Repair",Backend:GetToggle("AutoRepair"),function(v) return Backend:SetAutoRepair(v) end)
UI:AddSlider("Repair Range",2,35,1,Backend:GetValue("RepairRange") or 14,function(v) return Backend:SetRepairRange(v) end,repair)
UI:AddToggle("Auto Skill Check",Backend:GetToggle("AutoSkillCheck"),function(v) return Backend:SetAutoSkillCheck(v) end)
UI:AddSection("Map")
local exit=UI:AddButton("TELEPORT EXIT LEVER",function() return Backend:TeleportToExitLever() end)
exit:SetVisible(false)
UI:AddSection("Diagnostics")
local debug=UI:AddToggle("Debug",Backend:GetToggle("Debug"),function(v) return Backend:SetDebug(v) end)
local status=UI:AddStatus("GENERATOR STATUS")
local elapsed=0
UI.Connections[#UI.Connections+1]=game:GetService("RunService").Heartbeat:Connect(function(dt)
    if UI.Destroyed then return end
    elapsed=elapsed+dt;if elapsed<0.5 then return end;elapsed=0
    local ok,info=pcall(Backend.GetExitLeverInfo,Backend)
    exit:SetVisible(ok and type(info)=="table" and info.Available==true)
    if not debug:Get() then return end
    local success,data=pcall(Backend.GetGeneratorDebugInfo,Backend)
    if not success or type(data)~="table" then status:Set("Error: backend unavailable");return end
    local lines={}
    for _,name in ipairs({"Runtime","Map","RepairRemote","SkillRemote","Generators","CurrentGenerator","CurrentPoint","NearestDistance","RepairActive","RepairCalls","RepairStops","SkillChecks","LastSkillIndex","ExitLever","LastAction","LastError"}) do
        lines[#lines+1]=name..": "..tostring(data[name])
    end
    status:Set(table.concat(lines,"\n"))
end)
local destroy=UI.Destroy
function UI:Destroy(preserveBackend)
    if self.Destroyed then return end
    destroy(self,preserveBackend)
    if env.__DEPHUB_VD_FRONTEND==self then env.__DEPHUB_VD_FRONTEND=nil end
    if env.__DEPHUB and env.__DEPHUB.ViolenceDistrictUI==self then env.__DEPHUB.ViolenceDistrictUI=nil end
end
env.__DEPHUB_VD_FRONTEND=UI;env.__DEPHUB.ViolenceDistrictUI=UI
return UI

-- AOT:R module: defensive client-side features. No external webhooks.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
local old=env.__DEPHUB_AOTR
if type(old)=="table" and type(old.Destroy)=="function" then pcall(old.Destroy,old) end
-- Humanised timing: vary the refresh interval so the loop is not perfectly periodic.
local function jitter(base, spread)
 spread = spread or 0.15
 return task.wait(base * (1 + (math.random() * 2 - 1) * spread))
end
local M={Version="0.2.0",Destroyed=false,Toggles={TitanESP=false,NapeVisible=false,NapeExtend=false,ErenExtend=false,AutoBladeRefill=false,AutoGrabEscape=false,AntiInjury=false,AutoRetry=false,AntiAFK=false,TitanRipper=false,SkillAutofarm=false,ClassicAutofarm=false,ClassicNoclip=true},Values={NapeMultiplier=1,TravelSpeed=1000},Connections={},Highlights={},LastError="none"}
local function warnError(message)
 local nextError=tostring(message)
 if M.LastError~=nextError then warn("[DepHub/AOTR] "..nextError) end
 M.LastError=nextError
end
local base=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
-- Prefer the bundle's resolver published on the shared environment. It is only
-- present in a bundled build; a source checkout resolves through the executor's
-- own HttpGet, so fall back to that. Either way the module is plain repo source,
-- not a remote blob fetched from a third party.
local function fetch(path)
 local cb=tostring((env.__DEPHUB or {}).SourceCacheBust or "")
 local url=base..path..(cb~="" and ("?cb="..cb) or "")
 local resolver=(type(env.__dephubHttpGet)=="function" and env.__dephubHttpGet)
  or (type(env.__DEPHUB_HTTP_GET)=="function" and env.__DEPHUB_HTTP_GET)
  or (type(_G.__dephubHttpGet)=="function" and _G.__dephubHttpGet)
  or (type(_G.__DEPHUB_HTTP_GET)=="function" and _G.__DEPHUB_HTTP_GET)
 if resolver then
  local ok,source=pcall(resolver,url)
  if ok and type(source)=="string" and #source>0 then return true,source end
 end
 local ok,source=pcall(function() return game:HttpGet(url) end)
 if ok and type(source)=="string" and #source>0 then return true,source end
 return false,tostring(source)
end
local function loadFeature(name)
 local okFetch,source=fetch("src/games/features/aotr/"..name..".lua")
 if not okFetch then return nil,tostring(source) end
 local chunk,err=loadstring(source)
 if not chunk then return nil,tostring(err) end
 local okRun,module=pcall(chunk)
 if not okRun or type(module)~="table" then return nil,tostring(module) end
 return module
end
local properties,propertiesError=loadFeature("properties")
if not properties then return false,warnError("properties: "..tostring(propertiesError)) end
M.Properties=properties.new(warnError)
local helpers,helpersError=loadFeature("assistance")
if helpers then M.Assistance=helpers.new({Player=player,Warn=warnError}) else warnError("Assistance unavailable: "..tostring(helpersError)) end
local targets,targetsError=loadFeature("targets")
local movement,movementError=loadFeature("movement")
local combat,combatError=loadFeature("combat")
if targets and movement and combat then
 M.Combat=combat.new({Player=player,Workspace=Workspace,ReplicatedStorage=game:GetService("ReplicatedStorage"),RunService=game:GetService("RunService"),TweenService=TweenService,Targets=targets,Movement=movement,Properties=M.Properties,Warn=warnError,Now=os.clock,
  CancelTeleport=function() M:CancelTeleport() end,
  FindRefill=function() return M:FindRefill() end,
  IsTeleporting=function() return M.TeleportTween and M.TeleportTween.PlaybackState==Enum.PlaybackState.Playing end})
else
 warnError("Combat unavailable: "..tostring(targetsError or movementError or combatError))
end
local function child(parent,name) return parent and parent:FindFirstChild(name) end
local function descendants(parent,name)
 if not parent then return nil end
 return parent:FindFirstChild(name,true)
end
local function character() return player and player.Character end
local function titanFolder() return child(Workspace,"Titans") end
local function titans()
 local result={}
 local folder=titanFolder()
 if folder then
  for _,model in ipairs(folder:GetChildren()) do
   if model:IsA("Model") and child(model,"Hitboxes") then result[#result+1]=model end
  end
 end
 return result
end
local function nape(model)
 return child(child(child(model,"Hitboxes"),"Hit"),"Nape")
end
-- Report this backend's own structure and live state into the shared Debug tab.
local Diag=env.__DEPHUB and env.__DEPHUB.Diagnostics
if Diag and type(Diag.Probe)=="function" then
 local assets=child(game:GetService("ReplicatedStorage"),"Assets")
 local remotes=child(assets,"Remotes")
 local getRemote=child(remotes,"GET")
 local postRemote=child(remotes,"POST")
 Diag:RegisterModule("features/aotr/properties.lua")
 Diag:RegisterModule("features/aotr/assistance.lua")
 Diag:RegisterModule("features/aotr/targets.lua")
 Diag:RegisterModule("features/aotr/movement.lua")
 Diag:RegisterModule("features/aotr/combat.lua")
 Diag:Module("features/aotr/properties.lua",properties~=nil,tostring(propertiesError or "ok"))
 Diag:Module("features/aotr/assistance.lua",helpers~=nil,tostring(helpersError or "ok"))
 Diag:Module("features/aotr/targets.lua",targets~=nil,tostring(targetsError or "ok"))
 Diag:Module("features/aotr/movement.lua",movement~=nil,tostring(movementError or "ok"))
 Diag:Module("features/aotr/combat.lua",combat~=nil,tostring(combatError or "ok"))
 Diag:Probe("Workspace.Titans",titanFolder()~=nil,titanFolder() and (#titans().." titans") or "absent")
 local napeFound=false
 for _,model in ipairs(titans()) do if nape(model) then napeFound=true break end end
 Diag:Probe("Hitboxes.Hit.Nape",napeFound,napeFound and "resolvable on a live titan" or "not found")
 Diag:Probe("Assets.Remotes.GET",getRemote and getRemote:IsA("RemoteFunction") or false,getRemote and getRemote.ClassName or "absent")
 Diag:Probe("Assets.Remotes.POST",postRemote and postRemote:IsA("RemoteEvent") or false,postRemote and postRemote.ClassName or "absent")
 Diag:Probe("HUD Hotbar",child(child(child(child(player,"PlayerGui"),"Interface"),"HUD"),"Main")~=nil,"HUD/Main")
 local refillFound=false
 for _,rootName in ipairs({"Unclimbable","Climbable"}) do
  local root=child(Workspace,rootName)
  if root then
   for _,item in ipairs(root:GetDescendants()) do
    if item.Name=="Refill" and item:IsA("BasePart") then
     local ancestor=item.Parent
     while ancestor and ancestor~=root do
      if ancestor.Name=="GasTanks" then refillFound=true break end
      ancestor=ancestor.Parent
     end
    end
    if refillFound then break end
   end
  end
 end
 Diag:Probe("GasTanks.Refill",refillFound,refillFound and "found" or "absent")
 Diag:Feature("AOTR.TitanESP",function() return M.Toggles.TitanESP and "ON" or "off" end)
 Diag:Feature("AOTR.TitanRipper",function() return M.Combat and tostring(M.Combat.States.Ripper or "Disabled") or "no module" end)
 Diag:Feature("AOTR.SkillAutofarm",function() return M.Combat and tostring(M.Combat.States.SkillAutofarm or "Disabled") or "no module" end)
 Diag:Feature("AOTR.ClassicAutofarm",function() return M.Combat and tostring(M.Combat.States.ClassicAutofarm or "Disabled") or "no module" end)
 Diag:Feature("AOTR.Assistance",function()
  if not M.Assistance then return "no module" end
  local parts={}
  for _,name in ipairs({"AutoBladeRefill","AutoGrabEscape","AntiInjury","AutoRetry","AntiAFK"}) do
   if M.Toggles[name] then parts[#parts+1]=name.."="..tostring(M.Assistance.States[name] or "?") end
  end
  return #parts>0 and table.concat(parts,"; ") or "all off"
 end)
 Diag:Feature("AOTR.TravelSpeed",function() return tostring(M.Values.TravelSpeed).." studs/s" end)
 Diag:Feature("AOTR.ShadowBan",function() return M.Combat and M.Combat.CheckResult or "no module" end)
 Diag:Feature("AOTR.LastError",function() return M.LastError end)
 -- Structure watch: entity/part changes become timestamped console events.
 Diag:Watch("Titans",function() return #titans() end)
 Diag:Watch("Nape vivo",function()
  for _,model in ipairs(titans()) do if nape(model) then return true end end
  return false
 end)
 Diag:Watch("Personagem",function() return character() and character().Name or "nil" end)
 Diag:Watch("Remotes",function()
  return tostring(getRemote~=nil).."/"..tostring(postRemote~=nil)
 end)
 -- Sniff the two legacy remotes the farm drives, so every GET/POST the hub
 -- sends shows up in the console with its arguments.
 if type(Diag.SniffRemote)=="function" then
  Diag:SniffRemote(getRemote,"AOTR.GET")
  Diag:SniffRemote(postRemote,"AOTR.POST")
 end
 -- Console commands this backend adds on top of the built-ins.
 if type(Diag.Command)=="function" then
  Diag:Command("aotr",function()
   local parts={"titans="..#titans()}
   parts[#parts+1]="nape="..tostring((function() for _,model in ipairs(titans()) do if nape(model) then return true end end return false end)())
   parts[#parts+1]="refill="..tostring(refillFound)
   parts[#parts+1]="speed="..tostring(M.Values.TravelSpeed)
   parts[#parts+1]="lastError="..tostring(M.LastError)
   return table.concat(parts," ")
  end)
  Diag:Command("aotr-titanesp",function(argument)
   local on=argument~="off"
   M:SetToggle("TitanESP",on)
   return "TitanESP="..tostring(on)
  end)
 end
end
function M:Refresh()
 if self.Destroyed then return end
 local visual,eren={},{}
 for _,model in ipairs(titans()) do
  local part=nape(model)
  if part and part:IsA("BasePart") then
   if self.Toggles.NapeVisible or self.Toggles.NapeExtend then
    visual[part]={}
    if self.Toggles.NapeVisible then visual[part].Transparency=0.65 end
    if self.Toggles.NapeExtend then visual[part].Size=self.Properties:Original(part,"Size")*(self.Values.NapeMultiplier or 1) end
   end
  end
  if model.Name=="Attack_Titan" and self.Toggles.ErenExtend then
   local target=targets and targets.Marker(model)
   if target then
    eren[target]={Size=Vector3.new(95,95,95),Transparency=0.94}
   end
  end
  local highlight=self.Highlights[model]
  if self.Toggles.TitanESP then
   if not highlight or not highlight.Parent then
    highlight=Instance.new("Highlight")
    highlight.Name="DepHub_TitanESP"
    highlight.Adornee=model
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency=0.7
    highlight.OutlineTransparency=0
    highlight.Parent=model
    self.Highlights[model]=highlight
   end
  elseif highlight then highlight:Destroy();self.Highlights[model]=nil end
 end
 self.Properties:Set("Visual",visual,10)
 self.Properties:Set("Eren",eren,20)
 for model,highlight in pairs(self.Highlights) do
  if model.Parent~=titanFolder() or not self.Toggles.TitanESP then
   pcall(function() highlight:Destroy() end);self.Highlights[model]=nil
  end
 end
end
function M:SetToggle(name,value)
 if self.Destroyed or self.Toggles[name]==nil then return false end
 value=value==true
 if self.Toggles[name]==value then return true end
 if name=="ClassicNoclip" then
  if not self.Combat then warnError("Combat dependencies unavailable");return false end
  local ok,result=pcall(self.Combat.SetNoclip,self.Combat,value)
  if not ok or result==false then warnError(result);return false end
 end
 if name=="TitanRipper" or name=="SkillAutofarm" or name=="ClassicAutofarm" then
  if not self.Combat then warnError("Combat dependencies unavailable");return false end
  local ok,result=pcall(self.Combat.SetToggle,self.Combat,name,value)
  if not ok or result==false then warnError(result);return false end
 end
 if name=="AutoBladeRefill" or name=="AutoGrabEscape" or name=="AntiInjury" or name=="AutoRetry" or name=="AntiAFK" then
  if not self.Assistance then warnError("Assistance module unavailable");return false end
  if not self.Assistance:SetToggle(name,value) then return false end
 end
 self.Toggles[name]=value==true
 local ok,err=pcall(function() self:Refresh() end)
 if not ok then warnError(err) end
 return true
end
function M:SetTravelSpeed(value)
 value=tonumber(value)
 if self.Destroyed or not value or value~=value or value<50 or value>2000 or not self.Combat then return false end
 if not self.Combat:SetMovementSpeed(value) then return false end
 self.Values.TravelSpeed=value
 return true
end
function M:CheckShadowBan()
 if self.Destroyed or not self.Combat then return false end
 return self.Combat:CheckShadowBan()
end
function M:GetToggle(name) return self.Toggles[name]==true end
function M:SetNapeMultiplier(value)
 value=tonumber(value)
 if self.Destroyed or not value or value~=value or value<0 or value>2 then return false end
 self.Values.NapeMultiplier=value
 local ok,err=pcall(self.Refresh,self);if not ok then warnError(err) end
 return ok
end
function M:FindRefill()
 for _,rootName in ipairs({"Unclimbable","Climbable"}) do
  local root=child(Workspace,rootName)
  if root then
   for _,item in ipairs(root:GetDescendants()) do
    if item.Name=="Refill" and item:IsA("BasePart") then
     local ancestor=item.Parent
     while ancestor and ancestor~=root do
      if ancestor.Name=="GasTanks" then return item end
      ancestor=ancestor.Parent
     end
    end
   end
  end
 end
 return nil
end
function M:TeleportToRefill()
 if self.Destroyed then return false end
 local root=child(character(),"HumanoidRootPart")
 local refill=self:FindRefill()
 if not root or not root:IsA("BasePart") or not refill then warnError("Root or GasTanks.Refill unavailable");return false end
 local humanoid=character() and character():FindFirstChildOfClass("Humanoid")
 if root.Anchored or not humanoid or humanoid.Health<=0 then warnError("Character unavailable for refill travel");return false end
 self:CancelTeleport()
 if self.Combat then self.Combat:PauseMovement() end
 local distance=(root.Position-refill.Position).Magnitude
 local tween=TweenService:Create(root,TweenInfo.new(math.max(0.03,distance/(self.Values.TravelSpeed or 1000)),Enum.EasingStyle.Linear),{CFrame=refill.CFrame+Vector3.new(0,3,0)})
 tween:Play()
 self.TeleportTween=tween
 return true
end
function M:CancelTeleport()
 if self.TeleportTween then self.TeleportTween:Cancel();self.TeleportTween=nil end
 return true
end
function M:GetStatus()
 local top=child(child(child(child(player,"PlayerGui"),"Interface"),"HUD"),"Main")
 top=child(top,"Top")
 local hotbar=child(child(top,"7"),"Hotbar")
 local assistance=""
 if self.Assistance then
  for _,name in ipairs({"AutoBladeRefill","AutoGrabEscape","AntiInjury","AutoRetry","AntiAFK"}) do
   if self.Toggles[name] then assistance=assistance.."\n"..name..": "..tostring(self.Assistance.States[name] or "starting") end
  end
 end
 if self.Combat then
  for _,name in ipairs({"TitanRipper","SkillAutofarm","ClassicAutofarm"}) do
   local key=name=="TitanRipper" and "Ripper" or name
   assistance=assistance.."\n"..name..": "..tostring(self.Combat.States[key] or "Disabled")
  end
  assistance=assistance.."\nShadowBan: "..self.Combat.CheckResult
 end
 return "AOTR "..self.Version.." | speed: "..self.Values.TravelSpeed.." studs/s | farm noclip: "..tostring(self.Toggles.ClassicNoclip).."\nPlaceId: "..tostring(game.PlaceId).." | GameId: "..tostring(game.GameId).."\ntitans: "..tostring(#titans())..
  "\nhotbar: "..(hotbar and "found" or "missing")..
  "\nrefill: "..(self:FindRefill() and "found" or "missing")..
  "\nblade hud: "..(descendants(top,"Blade") and "found" or "missing")..
  "\nlast error: "..self.LastError..assistance
end
function M:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true
 if self.RefreshTask then pcall(task.cancel,self.RefreshTask);self.RefreshTask=nil end
 self:CancelTeleport()
 if self.Assistance then self.Assistance:Destroy() end
 if self.Combat then self.Combat:Destroy() end
 for _,connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
 for _,highlight in pairs(self.Highlights) do pcall(function() highlight:Destroy() end) end
 if self.Properties then self.Properties:Destroy() end
 self.Highlights={}
 if env.__DEPHUB_AOTR==self then env.__DEPHUB_AOTR=nil end
 if env.__DEPHUB and env.__DEPHUB.AOTR==self then env.__DEPHUB.AOTR=nil end
end
-- Refresh on newly spawned titans without touching unrelated Highlight children.
M.Connections[#M.Connections+1]=player.CharacterRemoving:Connect(function() M:CancelTeleport() end)
M.RefreshTask=task.spawn(function()
 while not M.Destroyed do
  jitter(1)
  if M.Destroyed then return end
  local ok,err=pcall(function() M:Refresh() end)
  if not ok then warnError(err) end
 end
end)
env.__DEPHUB_AOTR=M
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.AOTR=M

local UI=(env.__DEPHUB or {}).UI
-- ---------------------------------------------------------------------------
-- Presentation: grouped by CATEGORY (finalidade), never by game name. This game
-- uses only the categories it actually has:
--   Visual   - what to see on the titans (ESP / nape markers)
--   Combat   - titan-farming automation
--   Movement - traversal and teleport helpers
--   Misc     - everything that keeps the run alive plus the diagnostics panel
-- The category -> tab -> section creation goes through the shared UI kit, so the
-- "column must be Left/Right" contract lives in one place.
-- ---------------------------------------------------------------------------
do
    local Kit=env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        local esp=Kit.Section(Kit.Tab("Titan ESP","Visual"),"Visuals","Left")
        if esp then
            -- ESP + its two nape switches share lines; the nape multiplier slider
            -- drives "Expand nape" so it keeps its own row.
            local espRow=Kit.Row(esp)
            if espRow then
                espRow:CreateToggle("Titan ESP",M.Toggles.TitanESP,function(v) M:SetToggle("TitanESP",v) end)
                espRow:CreateToggle("Show nape",M.Toggles.NapeVisible,function(v) M:SetToggle("NapeVisible",v) end)
            else
                esp:CreateToggle("Titan ESP",M.Toggles.TitanESP,function(v) M:SetToggle("TitanESP",v) end)
                esp:CreateToggle("Show nape",M.Toggles.NapeVisible,function(v) M:SetToggle("NapeVisible",v) end)
            end
            local espRow2=Kit.Row(esp)
            if espRow2 then
                espRow2:CreateToggle("Expand nape",M.Toggles.NapeExtend,function(v) M:SetToggle("NapeExtend",v) end)
                espRow2:CreateSlider("Nape multiplier",0,2,M.Values.NapeMultiplier,function(v) M:SetNapeMultiplier(v) end)
            else
                esp:CreateToggle("Expand nape",M.Toggles.NapeExtend,function(v) M:SetToggle("NapeExtend",v) end)
                esp:CreateSlider("Nape multiplier",0,2,M.Values.NapeMultiplier,function(v) M:SetNapeMultiplier(v) end)
            end
            esp:CreateToggle("Expand Attack Titan target",M.Toggles.ErenExtend,function(v) M:SetToggle("ErenExtend",v) end)
        end

        local combat=Kit.Section(Kit.Tab("Farm","Combat"),"Autofarm","Left")
        if combat then
            -- Autofarm switches are the same decision, so they pair on lines.
            local farmRow=Kit.Row(combat)
            if farmRow then
                farmRow:CreateToggle("Titan Ripper",M.Toggles.TitanRipper,function(v) M:SetToggle("TitanRipper",v) end)
                farmRow:CreateToggle("Skill autofarm",M.Toggles.SkillAutofarm,function(v) M:SetToggle("SkillAutofarm",v) end)
            else
                combat:CreateToggle("Titan Ripper",M.Toggles.TitanRipper,function(v) M:SetToggle("TitanRipper",v) end)
                combat:CreateToggle("Skill autofarm",M.Toggles.SkillAutofarm,function(v) M:SetToggle("SkillAutofarm",v) end)
            end
            combat:CreateToggle("Classic autofarm",M.Toggles.ClassicAutofarm,function(v) M:SetToggle("ClassicAutofarm",v) end)
        end

        local movement=Kit.Section(Kit.Tab("Movement","Movement"),"Movement","Left")
        if movement then
            -- Farm noclip + travel speed share a line; the two actions share one.
            local moveRow=Kit.Row(movement)
            if moveRow then
                moveRow:CreateToggle("Farm noclip",M.Toggles.ClassicNoclip,function(v) M:SetToggle("ClassicNoclip",v) end)
                moveRow:CreateSlider("Travel speed",50,2000,M.Values.TravelSpeed,function(v) M:SetTravelSpeed(v) end)
            else
                movement:CreateToggle("Farm noclip",M.Toggles.ClassicNoclip,function(v) M:SetToggle("ClassicNoclip",v) end)
                movement:CreateSlider("Travel speed",50,2000,M.Values.TravelSpeed,function(v) M:SetTravelSpeed(v) end)
            end
            local moveBtnRow=Kit.Row(movement)
            if moveBtnRow then
                moveBtnRow:CreateButton("Go to refill",function()
                    local ok=M:TeleportToRefill()
                    if UI and type(UI.Notify)=="function" then UI:Notify("AOT:R",ok and "Heading to refill." or "Refill not found.") end
                end)
                moveBtnRow:CreateButton("Cancel movement",function() M:CancelTeleport() end)
            else
                movement:CreateButton("Go to refill",function()
                    local ok=M:TeleportToRefill()
                    if UI and type(UI.Notify)=="function" then UI:Notify("AOT:R",ok and "Heading to refill." or "Refill not found.") end
                end)
                movement:CreateButton("Cancel movement",function() M:CancelTeleport() end)
            end
        end

        local assist=Kit.Section(Kit.Tab("Assistance","Misc"),"Automation","Left")
        if assist then
            -- Five safety switches, all the same decision; pair them on lines.
            local assistRow1=Kit.Row(assist)
            if assistRow1 then
                assistRow1:CreateToggle("Refill blades",M.Toggles.AutoBladeRefill,function(v) M:SetToggle("AutoBladeRefill",v) end)
                assistRow1:CreateToggle("Auto grab escape",M.Toggles.AutoGrabEscape,function(v) M:SetToggle("AutoGrabEscape",v) end)
            else
                assist:CreateToggle("Refill blades",M.Toggles.AutoBladeRefill,function(v) M:SetToggle("AutoBladeRefill",v) end)
                assist:CreateToggle("Auto grab escape",M.Toggles.AutoGrabEscape,function(v) M:SetToggle("AutoGrabEscape",v) end)
            end
            local assistRow2=Kit.Row(assist)
            if assistRow2 then
                assistRow2:CreateToggle("Anti-injury",M.Toggles.AntiInjury,function(v) M:SetToggle("AntiInjury",v) end)
                assistRow2:CreateToggle("Auto retry",M.Toggles.AutoRetry,function(v) M:SetToggle("AutoRetry",v) end)
            else
                assist:CreateToggle("Anti-injury",M.Toggles.AntiInjury,function(v) M:SetToggle("AntiInjury",v) end)
                assist:CreateToggle("Auto retry",M.Toggles.AutoRetry,function(v) M:SetToggle("AutoRetry",v) end)
            end
            assist:CreateToggle("Anti-AFK",M.Toggles.AntiAFK,function(v) M:SetToggle("AntiAFK",v) end)
        end

        local status=Kit.Section(Kit.Tab("Status","Misc"),"Diagnostics","Left")
        if status then
            status:CreateParagraph("Current state",M:GetStatus())
            status:CreateButton("Check ShadowBan",function()
                M:CheckShadowBan()
                if UI and type(UI.Notify)=="function" then UI:Notify("AOT:R","Diagnostics requested.") end
            end)
        end
    end
end
return M

-- AOT:R module: defensive client-side features. No external webhooks.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
local old=env.__DEPHUB_AOTR
if type(old)=="table" and type(old.Destroy)=="function" then pcall(old.Destroy,old) end
local M={Version="0.1.0",Destroyed=false,Toggles={TitanESP=false,NapeVisible=false,NapeExtend=false,ErenExtend=false,AutoBladeRefill=false,AutoGrabEscape=false,AntiInjury=false,AutoRetry=false,AntiAFK=false,TitanRipper=false,SkillAutofarm=false,ClassicAutofarm=false},Values={NapeMultiplier=1},Connections={},Highlights={},LastError="none"}
local function warnError(message)
 local nextError=tostring(message)
 if M.LastError~=nextError then warn("[DepHub/AOTR] "..nextError) end
 M.LastError=nextError
end
local base=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local function loadFeature(name)
 local ok,result=pcall(function()
  local source=game:HttpGet(base.."src/games/features/aotr/"..name..".lua?aotr="..M.Version)
  local chunk,err=loadstring(source);assert(chunk,err)
  local module=chunk();assert(type(module)=="table","Invalid module: "..name)
  return module
 end)
 if not ok then warnError(name..": "..tostring(result));return nil end
 return result
end
local properties=loadFeature("properties")
if not properties then return false end
M.Properties=properties.new(warnError)
local assistance=loadFeature("assistance")
if assistance then M.Assistance=assistance.new({Player=player,Warn=warnError}) end
local targets=loadFeature("targets")
local movement=loadFeature("movement")
local combat=loadFeature("combat")
if targets and movement and combat then
 M.Combat=combat.new({Player=player,Workspace=Workspace,ReplicatedStorage=game:GetService("ReplicatedStorage"),Targets=targets,Movement=movement,Properties=M.Properties,Warn=warnError,Now=os.clock,
  CancelTeleport=function() M:CancelTeleport() end,
  FindRefill=function() return M:FindRefill() end,
  IsTeleporting=function() return M.TeleportTween and M.TeleportTween.PlaybackState==Enum.PlaybackState.Playing end})
end
local function child(parent,name) return parent and parent:FindFirstChild(name) end
local function descendants(parent,name)
 if not parent then return nil end
 return parent:FindFirstChild(name,true)
end
local function character() return player and player.Character end
local function main() return child(character(),"Main") end
local function remote(name)
 local assets=child(game:GetService("ReplicatedStorage"),"Assets")
 return child(child(assets,"Remotes"),name)
end
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
 if name=="TitanRipper" or name=="SkillAutofarm" or name=="ClassicAutofarm" then
  if not self.Combat then warnError("Combat dependencies unavailable");return false end
  local ok,result=pcall(self.Combat.SetToggle,self.Combat,name,value)
  if not ok or result==false then warnError(result);return false end
 end
 if name=="AutoBladeRefill" or name=="AutoGrabEscape" or name=="AntiInjury" or name=="AutoRetry" or name=="AntiAFK" then
  if not self.Assistance then warnError("Assistance module unavailable");return false end
  local ok,result=pcall(self.Assistance.SetToggle,self.Assistance,name,value)
  if not ok or result==false then warnError(result);return false end
 end
 self.Toggles[name]=value==true
 local ok,err=pcall(function() self:Refresh() end)
 if not ok then warnError(err) end
 return true
end
function M:GetToggle(name) return self.Toggles[name]==true end
function M:CheckShadowBan()
 if self.Destroyed or not self.Combat then return false end
 return self.Combat:CheckShadowBan()
end
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
 self:CancelTeleport()
 local distance=(root.Position-refill.Position).Magnitude
 local tween=TweenService:Create(root,TweenInfo.new(math.max(0.1,distance/225),Enum.EasingStyle.Linear),{CFrame=refill.CFrame+Vector3.new(0,3,0)})
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
 return "AOTR "..self.Version.." | PlaceId: "..tostring(game.PlaceId).." | GameId: "..tostring(game.GameId).."\ntitans: "..tostring(#titans())..
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
 self.Properties:Destroy()
 self.Highlights={}
 if env.__DEPHUB_AOTR==self then env.__DEPHUB_AOTR=nil end
 if env.__DEPHUB and env.__DEPHUB.AOTR==self then env.__DEPHUB.AOTR=nil end
end
-- Refresh on newly spawned titans without touching unrelated Highlight children.
M.Connections[#M.Connections+1]=player.CharacterRemoving:Connect(function() M:CancelTeleport() end)
M.RefreshTask=task.spawn(function()
 while not M.Destroyed do
  task.wait(1)
  if M.Destroyed then return end
  local ok,err=pcall(function() M:Refresh() end)
  if not ok then warnError(err) end
 end
end)
env.__DEPHUB_AOTR=M
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.AOTR=M
return M

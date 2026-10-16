-- AOT:R module: defensive client-side features. No external webhooks.
local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
local old=env.__DEPHUB_AOTR
if type(old)=="table" and type(old.Destroy)=="function" then pcall(old.Destroy,old) end
local M={Destroyed=false,Toggles={TitanESP=false,NapeVisible=false,NapeExtend=false,ErenExtend=false,AutoBladeRefill=false,AutoGrabEscape=false,AntiInjury=false,AutoRetry=false,AntiAFK=false},Values={NapeMultiplier=1},Connections={},Originals={},Highlights={},LastError="none"}
local function warnError(message)
 local nextError=tostring(message)
 if M.LastError~=nextError then warn("[DepHub/AOTR] "..nextError) end
 M.LastError=nextError
end
local base=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local okHelpers,helpers=pcall(function()
 local source=game:HttpGet(base.."src/games/features/aotr/assistance.lua")
 local chunk,err=loadstring(source)
 assert(chunk,err)
 return chunk().new({Player=player,Warn=warnError})
end)
if okHelpers and type(helpers)=="table" then M.Assistance=helpers else warnError("Assistance unavailable: "..tostring(helpers)) end
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
local function remember(part)
 if not M.Originals[part] then
  M.Originals[part]={Size=part.Size,Transparency=part.Transparency}
 end
end
local function restore()
 for part,values in pairs(M.Originals) do
  if part and part.Parent then
   pcall(function() part.Size=values.Size;part.Transparency=values.Transparency end)
  end
 end
 M.Originals={}
end
function M:Refresh()
 if self.Destroyed then return end
 local desired={}
 for _,model in ipairs(titans()) do
  local part=nape(model)
  if part and part:IsA("BasePart") then
   if self.Toggles.NapeVisible or self.Toggles.NapeExtend then
    desired[part]=true
    remember(part)
    local original=self.Originals[part]
    part.Transparency=self.Toggles.NapeVisible and 0.65 or original.Transparency
    part.Size=self.Toggles.NapeExtend and original.Size*(self.Values.NapeMultiplier or 1) or original.Size
   elseif self.Originals[part] then
    local original=self.Originals[part]
    part.Size=original.Size;part.Transparency=original.Transparency
    self.Originals[part]=nil
   end
  end
  if model.Name=="Attack_Titan" and self.Toggles.ErenExtend then
   local marker=child(model,"Marker")
   local hit=child(child(model,"Hitboxes"),"Hit")
   local target=marker and (marker:IsA("Highlight") or marker:IsA("BillboardGui") or marker:IsA("SelectionBox")) and marker.Adornee
   if target and hit and target:IsA("BasePart") and target:IsDescendantOf(hit) then
    remember(target);desired[target]=true
    target.Size=Vector3.new(95,95,95);target.Transparency=0.94
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
 for part,original in pairs(self.Originals) do
  if not desired[part] then
   if part.Parent then
    local ok,err=pcall(function() part.Size=original.Size;part.Transparency=original.Transparency end)
    if not ok then warnError(err) end
   end
   self.Originals[part]=nil
  end
 end
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
 if name=="AutoBladeRefill" or name=="AutoGrabEscape" or name=="AntiInjury" or name=="AutoRetry" or name=="AntiAFK" then
  if not self.Assistance then warnError("Assistance module unavailable");return false end
  if not self.Assistance:SetToggle(name,value) then return false end
 end
 self.Toggles[name]=value==true
 local ok,err=pcall(function() self:Refresh() end)
 if not ok then warnError(err) end
 return true
end
function M:GetToggle(name) return self.Toggles[name]==true end
function M:SetNapeMultiplier(value)
 value=tonumber(value)
 if self.Destroyed or not value or value~=value or value<0 or value>2 then return false end
 self.Values.NapeMultiplier=value;self:Refresh();return true
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
 return "PlaceId: "..tostring(game.PlaceId).." | GameId: "..tostring(game.GameId).."\ntitans: "..tostring(#titans())..
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
 for _,connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
 for _,highlight in pairs(self.Highlights) do pcall(function() highlight:Destroy() end) end
 restore()
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

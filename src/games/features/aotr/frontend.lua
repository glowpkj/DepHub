local env=type(getgenv)=="function" and getgenv() or _G
local backend=env.__DEPHUB and env.__DEPHUB.AOTR
if type(backend)~="table" then return false end
local base=env.__DEPHUB.SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local ok,source=pcall(function() return game:HttpGet(base.."library/compact.lua") end)
if not ok then return false end
local compiled=loadstring(source)
if not compiled then return false end
local Library=compiled()
if type(Library)~="table" then return false end
local UI=Library.new({Id="AOTR",Title="DEPHUB",Subtitle="ATTACK ON TITAN: REVOLUTION",Accent=Color3.fromRGB(111,238,190),Width=310,Height=490,Open=true})
UI:AddSection("TITANS")
UI:AddToggle("Titan ESP",false,function(v) return backend:SetToggle("TitanESP",v) end)
UI:AddToggle("Nape Visible",false,function(v) return backend:SetToggle("NapeVisible",v) end)
local _,settings=UI:AddFeature("Nape Extend",false,function(v) return backend:SetToggle("NapeExtend",v) end)
UI:AddSlider("Nape Multiplier",0,2,0.1,1,function(v) return backend:SetNapeMultiplier(v) end,settings)
UI:AddSection("MOVEMENT")
UI:AddButton("TELEPORT TO REFILL",function() return backend:TeleportToRefill() and "TELEPORTING" or "REFILL NOT FOUND" end)
UI:AddSection("DIAGNOSTICS")
UI:AddButton("PRINT GAME STATUS",function() local s=backend:GetStatus();print("[DepHub/AOTR]\n"..s);return "STATUS PRINTED" end)
local status=UI:AddStatus("GAME STATUS",nil,130)
status:Set(backend:GetStatus())
local alive=true
task.spawn(function()
 while alive and not UI.Destroyed do
  task.wait(2)
  if alive and not UI.Destroyed then pcall(function() status:Set(backend:GetStatus()) end) end
 end
end)
local destroy=UI.Destroy
function UI:Destroy()
 if self.Destroyed then return end
 alive=false
 pcall(destroy,self)
 if env.__DEPHUB_AOTR_FRONTEND==self then env.__DEPHUB_AOTR_FRONTEND=nil end
end
env.__DEPHUB_AOTR_FRONTEND=UI
env.__DEPHUB.AOTRUI=UI
return UI

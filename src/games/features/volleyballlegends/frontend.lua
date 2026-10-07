local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local Backend=env.__DEPHUB and env.__DEPHUB.VolleyballLegends
if type(Backend)~="table" then return false end
local previous=env.__DEPHUB_VOLLEYBALL_FRONTEND
if type(previous)=="table" and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end
local chunk,err=loadstring(game:HttpGet(BASE_URL.."library/compact.lua")) assert(chunk,err)
local Library=chunk()
local UI=Library.new({Id="VolleyballLegends",Title="DEPHUB",Subtitle="VOLLEYBALL LEGENDS",Accent=Color3.fromRGB(255,195,65),Width=292,Height=240,Open=true})
UI:AddToggle("Ball ESP",Backend:GetToggle("BallESP"),function(value) return Backend:SetBallESP(value) end)
UI:AddToggle("Trajectory Predictor",Backend:GetToggle("TrajectoryPredictor"),function(value) return Backend:SetTrajectoryPredictor(value) end)
UI:AddToggle("Debug",Backend:GetToggle("Debug"),function(value) return Backend:SetDebug(value) end)
local baseDestroy=UI.Destroy
function UI:Destroy()
    if self.Destroyed then return end
    pcall(baseDestroy,self)
    if env.__DEPHUB_VOLLEYBALL_FRONTEND==self then env.__DEPHUB_VOLLEYBALL_FRONTEND=nil end
    if env.__DEPHUB and env.__DEPHUB.VolleyballLegendsUI==self then env.__DEPHUB.VolleyballLegendsUI=nil end
end
env.__DEPHUB_VOLLEYBALL_FRONTEND=UI env.__DEPHUB.VolleyballLegendsUI=UI
return UI

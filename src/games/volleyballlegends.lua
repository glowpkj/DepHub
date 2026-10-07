local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
if not player then return false end
local previous=env.__DEPHUB_VOLLEYBALL
if type(previous)=="table" and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end

local State={Version="0.0.1",Destroyed=false,Started=true,Features={},Connection=nil,Accumulator=0,DebugAccumulator=0,
    Toggles={BallESP=false,TrajectoryPredictor=false,Debug=false},LastError="none"}
local context={Players=Players,Workspace=Workspace,LocalPlayer=player}
local function cleanup()
    for _,feature in pairs(State.Features) do if type(feature.Destroy)=="function" then pcall(feature.Destroy,feature) end end
end
local function loadFeature(name)
    local source=game:HttpGet(BASE_URL.."src/games/features/volleyballlegends/"..name..".lua")
    local chunk,err=loadstring(source) assert(chunk,err)
    local factory=chunk() assert(type(factory)=="table" and type(factory.new)=="function","Invalid factory: "..name)
    local feature=factory.new(context)
    assert(type(feature)=="table" and type(feature.Destroy)=="function","Invalid feature: "..name)
    return feature
end
context.OnChanged=function(candidate)
    local esp=State.Features.BallESP local predictor=State.Features.TrajectoryPredictor
    if esp then esp:Clear() end
    if predictor then if candidate then predictor:Hide() else predictor:Clear() end end
    if State.Toggles.Debug then print("[DepHub Volleyball] ball="..(candidate and candidate.Object.Name or "none")) end
end
local ok,err=pcall(function()
    State.Features.Detector=loadFeature("ball-detector")
    State.Features.BallESP=loadFeature("ball-esp")
    State.Features.TrajectoryPredictor=loadFeature("trajectory")
end)
if not ok then cleanup(); warn("[DepHub Volleyball] "..tostring(err)); return false end

function State:_reference()
    local character=player.Character local root=character and character:FindFirstChild("HumanoidRootPart")
    local camera=Workspace.CurrentCamera
    return root and root.Position or camera and camera.CFrame.Position or nil
end
function State:_tick(dt)
    if self.Destroyed then return end
    self.Accumulator=self.Accumulator+dt
    if self.Accumulator<1/20 then return end
    local elapsed=self.Accumulator self.Accumulator=0
    local reference=self:_reference()
    local candidate=self.Features.Detector:Sample(elapsed,reference)
    if self.Toggles.BallESP then self.Features.BallESP:Update(candidate,reference) end
    if self.Toggles.TrajectoryPredictor then
        local exclusions=self.Features.Detector:GetExclusions()
        for _,other in ipairs(Players:GetPlayers()) do if other.Character then exclusions[#exclusions+1]=other.Character end end
        self.Features.TrajectoryPredictor:Update(candidate,exclusions)
    end
    if self.Toggles.Debug then
        self.DebugAccumulator=self.DebugAccumulator+elapsed
        if self.DebugAccumulator>=1 then
            self.DebugAccumulator=0
            local landing=self.Features.TrajectoryPredictor.Landing
            local signature=(candidate and candidate.Object.Name or "none")..":"..(landing and string.format("%.0f,%.0f,%.0f",landing.X,landing.Y,landing.Z) or "none")
            if signature~=self.LastDebugSignature then
                self.LastDebugSignature=signature
                print("[DepHub Volleyball] ball="..(candidate and candidate.Object.Name or "none").." part="..(candidate and candidate.Part:GetFullName() or "none")
                    .." speed="..string.format("%.1f",candidate and candidate.Velocity.Magnitude or 0).." landing="..(landing and tostring(landing) or "none"))
            end
        end
    end
end
function State:_sync()
    local needed=self.Toggles.BallESP or self.Toggles.TrajectoryPredictor
    if needed and not self.Connection then
        self.Features.Detector:Enable() self.Accumulator=0
        self.Connection=RunService.Heartbeat:Connect(function(dt)
            local success,message=pcall(self._tick,self,dt)
            if not success then
                self.Features.BallESP:Clear() self.Features.TrajectoryPredictor:Hide()
                if self.LastError~=tostring(message) and self.Toggles.Debug then warn("[DepHub Volleyball] "..tostring(message)) end
                self.LastError=tostring(message)
            else self.LastError="none" end
        end)
    elseif not needed then
        if self.Connection then self.Connection:Disconnect(); self.Connection=nil end
        self.Features.Detector:Disable() self.Accumulator=0
    end
    return true
end
function State:SetBallESP(value)
    if self.Destroyed then return false end self.Toggles.BallESP=value==true
    self.Features.BallESP:SetEnabled(value) return self:_sync()
end
function State:SetTrajectoryPredictor(value)
    if self.Destroyed then return false end self.Toggles.TrajectoryPredictor=value==true
    self.Features.TrajectoryPredictor:SetEnabled(value) return self:_sync()
end
function State:SetDebug(value)
    if self.Destroyed then return false end self.Toggles.Debug=value==true self.LastDebugSignature=nil self.DebugAccumulator=0 return true
end
function State:GetToggle(name) return self.Toggles[name]==true end
function State:GetDebugInfo()
    local detector=self.Features.Detector local candidate=detector.Active local landing=self.Features.TrajectoryPredictor.Landing
    local count=0 for _ in pairs(detector.Candidates) do count=count+1 end
    return {Running=self.Connection~=nil,Ball=candidate and candidate.Object.Name or "none",Part=candidate and candidate.Part:GetFullName() or "none",
        Candidates=count,Selection=detector.Reason,Speed=candidate and candidate.Velocity.Magnitude or 0,
        VelocitySource=candidate and candidate.VelocitySource or "none",Landing=landing and {X=landing.X,Y=landing.Y,Z=landing.Z} or false,LastError=self.LastError}
end
function State:Destroy()
    if self.Destroyed then return end self.Destroyed=true
    if self.Connection then self.Connection:Disconnect(); self.Connection=nil end
    cleanup()
    if env.__DEPHUB_VOLLEYBALL==self then env.__DEPHUB_VOLLEYBALL=nil end
    if env.__DEPHUB and env.__DEPHUB.VolleyballLegends==self then env.__DEPHUB.VolleyballLegends=nil end
end
env.__DEPHUB_VOLLEYBALL=State env.__DEPHUB=env.__DEPHUB or {} env.__DEPHUB.VolleyballLegends=State
return State

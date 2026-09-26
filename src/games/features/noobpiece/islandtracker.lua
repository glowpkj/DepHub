local Workspace=game:GetService("Workspace")

local IslandTracker={}
IslandTracker.__index=IslandTracker

local MARKER_NAME="DepHubIslandMarker"

local function disconnectAll(list)
    for _,connection in ipairs(list) do pcall(connection.Disconnect,connection) end
    table.clear(list)
end

function IslandTracker.new()
    return setmetatable({Records={},Connections={},Started=false},IslandTracker)
end

function IslandTracker:_bounds(model)
    local minX,minY,minZ=math.huge,math.huge,math.huge
    local maxX,maxY,maxZ=-math.huge,-math.huge,-math.huge
    local found=false
    for _,descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Name~=MARKER_NAME then
            local cf=descendant.CFrame
            local half=descendant.Size*0.5
            local radius=Vector3.new(
                math.abs(cf.RightVector.X)*half.X+math.abs(cf.UpVector.X)*half.Y+math.abs(cf.LookVector.X)*half.Z,
                math.abs(cf.RightVector.Y)*half.X+math.abs(cf.UpVector.Y)*half.Y+math.abs(cf.LookVector.Y)*half.Z,
                math.abs(cf.RightVector.Z)*half.X+math.abs(cf.UpVector.Z)*half.Y+math.abs(cf.LookVector.Z)*half.Z
            )
            local p=cf.Position
            minX=math.min(minX,p.X-radius.X)
            minY=math.min(minY,p.Y-radius.Y)
            minZ=math.min(minZ,p.Z-radius.Z)
            maxX=math.max(maxX,p.X+radius.X)
            maxY=math.max(maxY,p.Y+radius.Y)
            maxZ=math.max(maxZ,p.Z+radius.Z)
            found=true
        end
    end
    if not found then return nil end
    local min=Vector3.new(minX,minY,minZ)
    local max=Vector3.new(maxX,maxY,maxZ)
    return (min+max)*0.5,max-min
end

function IslandTracker:_setMarker(model,position,size)
    local marker=model:FindFirstChild(MARKER_NAME)
    if not marker or not marker:IsA("BasePart") then
        if marker then marker:Destroy() end
        marker=Instance.new("Part")
        marker.Name=MARKER_NAME
        marker.Anchored=true
        marker.CanCollide=false
        marker.CanTouch=false
        marker.CanQuery=false
        marker.CastShadow=false
        marker.Transparency=1
        marker.Size=Vector3.new(4,4,4)
        marker.Parent=model
    end
    marker.CFrame=CFrame.new(position)
    marker:SetAttribute("IslandName",model.Name)
    marker:SetAttribute("IslandSize",size)
    model:SetAttribute("DepHubIslandKnown",true)
    model:SetAttribute("DepHubIslandPosition",position)
end

function IslandTracker:_learn(model)
    local record=self.Records[model]
    if not record then return end
    local position,size=self:_bounds(model)
    if position then
        self:_setMarker(model,position,size)
        record.LastPosition=position
    elseif record.LastPosition then
        self:_setMarker(model,record.LastPosition,Vector3.zero)
    end
end

function IslandTracker:_schedule(model)
    local record=self.Records[model]
    if not record then return end
    record.Token+=1
    local token=record.Token
    task.delay(0.35,function()
        local current=self.Records[model]
        if current and current.Token==token then self:_learn(model) end
    end)
end

function IslandTracker:_track(model)
    if not model:IsA("Model") or self.Records[model] then return end
    local record={Connections={},Token=0,LastPosition=nil}
    self.Records[model]=record
    table.insert(record.Connections,model.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") and descendant.Name~=MARKER_NAME then self:_schedule(model) end
    end))
    table.insert(record.Connections,model.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("BasePart") and descendant.Name~=MARKER_NAME then self:_schedule(model) end
    end))
    self:_schedule(model)
end

function IslandTracker:_untrack(model)
    local record=self.Records[model]
    if not record then return end
    disconnectAll(record.Connections)
    self.Records[model]=nil
end

function IslandTracker:_bindFolder(folder)
    for _,model in ipairs(folder:GetChildren()) do self:_track(model) end
    table.insert(self.Connections,folder.ChildAdded:Connect(function(model) self:_track(model) end))
    table.insert(self.Connections,folder.ChildRemoved:Connect(function(model) self:_untrack(model) end))
end

function IslandTracker:Start()
    if self.Started then return end
    self.Started=true
    local folder=Workspace:FindFirstChild("Ilhas")
    if folder then self:_bindFolder(folder) end
    table.insert(self.Connections,Workspace.ChildAdded:Connect(function(child)
        if child.Name=="Ilhas" then self:_bindFolder(child) end
    end))
end

function IslandTracker:GetKnownIslands()
    local result={}
    for model,record in pairs(self.Records) do
        if model.Parent and record.LastPosition then table.insert(result,{Name=model.Name,Position=record.LastPosition,Model=model}) end
    end
    table.sort(result,function(a,b) return a.Name<b.Name end)
    return result
end

function IslandTracker:Destroy()
    if not self.Started then return end
    self.Started=false
    disconnectAll(self.Connections)
    local models={}
    for model in pairs(self.Records) do table.insert(models,model) end
    for _,model in ipairs(models) do
        local marker=model:FindFirstChild(MARKER_NAME)
        if marker then marker:Destroy() end
        self:_untrack(model)
    end
end

return IslandTracker

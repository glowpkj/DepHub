local Workspace=game:GetService("Workspace")

local IslandTracker={}
IslandTracker.__index=IslandTracker

local MARKER_FOLDER="DepHubIslandMarkers"

local function disconnectAll(list)
    for _,connection in ipairs(list) do
        pcall(connection.Disconnect,connection)
    end
    table.clear(list)
end

function IslandTracker.new(data,movement)
    return setmetatable({
        Data=data,
        Movement=movement,
        Records={},
        Known={},
        Markers={},
        Connections={},
        Started=false,
        ESPEnabled=false
    },IslandTracker)
end

function IslandTracker:_folder()
    local folder=Workspace:FindFirstChild(MARKER_FOLDER)

    if not folder then
        folder=Instance.new("Folder")
        folder.Name=MARKER_FOLDER
        folder.Parent=Workspace
    end

    return folder
end

function IslandTracker:_bounds(model)
    local minX,minY,minZ=math.huge,math.huge,math.huge
    local maxX,maxY,maxZ=-math.huge,-math.huge,-math.huge
    local found=false

    for _,descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
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

    if not found then
        return nil
    end

    local min=Vector3.new(minX,minY,minZ)
    local max=Vector3.new(maxX,maxY,maxZ)
    return (min+max)*0.5
end

function IslandTracker:_labelText(record)
    local text=string.upper(record.DisplayName or record.Name)

    if record.LevelMin and record.LevelMax then
        text=text..string.format("\nLV %d-%d",record.LevelMin,record.LevelMax)
    end

    return text
end

function IslandTracker:_refreshVisual(name)
    local marker=self.Markers[name]
    local record=self.Known[name]

    if not marker or not record then
        return
    end

    local gui=marker:FindFirstChild("DepHubIslandESP")

    if not self.ESPEnabled then
        if gui then gui:Destroy() end
        return
    end

    if not gui then
        gui=Instance.new("BillboardGui")
        gui.Name="DepHubIslandESP"
        gui.AlwaysOnTop=true
        gui.Size=UDim2.fromOffset(180,48)
        gui.StudsOffset=Vector3.new(0,5,0)
        gui.MaxDistance=10000
        gui.LightInfluence=0
        gui.Adornee=marker
        gui.Parent=marker

        local label=Instance.new("TextLabel")
        label.Name="Label"
        label.BackgroundTransparency=1
        label.Size=UDim2.fromScale(1,1)
        label.Font=Enum.Font.GothamBold
        label.TextColor3=Color3.new(1,1,1)
        label.TextStrokeColor3=Color3.new(0,0,0)
        label.TextStrokeTransparency=0.2
        label.TextSize=13
        label.Parent=gui
    end

    gui.Label.Text=self:_labelText(record)
end

function IslandTracker:_setMarker(name,cframe)
    local marker=self.Markers[name]

    if not marker or not marker.Parent then
        marker=Instance.new("Part")
        marker.Name="DepHubIslandMarker_"..name
        marker.Anchored=true
        marker.CanCollide=false
        marker.CanTouch=false
        marker.CanQuery=false
        marker.CastShadow=false
        marker.Transparency=1
        marker.Size=Vector3.new(4,4,4)
        marker.Parent=self:_folder()
        self.Markers[name]=marker
    end

    marker.CFrame=cframe
    marker:SetAttribute("IslandName",name)
    self:_refreshVisual(name)
end

function IslandTracker:_register(name,cframe,static)
    if type(name)~="string" or name=="" or typeof(cframe)~="CFrame" then
        return
    end

    local data=self.Data and self.Data.Get(name)
    local current=self.Known[name]

    if current and current.Static and not static then
        return
    end

    local record=current or {}
    record.Name=name
    record.DisplayName=data and data.DisplayName or name
    record.CFrame=cframe
    record.Position=cframe.Position
    record.LevelMin=data and data.LevelMin or record.LevelMin
    record.LevelMax=data and data.LevelMax or record.LevelMax
    record.Mirage=data and data.Mirage==true or false
    record.Static=static==true or record.Static==true
    self.Known[name]=record

    self:_setMarker(name,cframe)
end

function IslandTracker:_learn(model)
    local record=self.Records[model]
    if not record or not model.Parent then
        return
    end

    local position=self:_bounds(model)

    if position then
        record.LastPosition=position
        self:_register(model.Name,CFrame.new(position),false)
    end
end

function IslandTracker:_schedule(model)
    local record=self.Records[model]
    if not record then
        return
    end

    record.Token+=1
    local token=record.Token

    task.delay(0.35,function()
        local current=self.Records[model]

        if current and current.Token==token then
            self:_learn(model)
        end
    end)
end

function IslandTracker:_track(model)
    if not model:IsA("Model") or self.Records[model] then
        return
    end

    local record={Connections={},Token=0,LastPosition=nil}
    self.Records[model]=record

    record.Connections[#record.Connections+1]=model.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            self:_schedule(model)
        end
    end)

    record.Connections[#record.Connections+1]=model.DescendantRemoving:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            self:_schedule(model)
        end
    end)

    self:_schedule(model)
end

function IslandTracker:_untrack(model)
    local record=self.Records[model]

    if not record then
        return
    end

    disconnectAll(record.Connections)
    self.Records[model]=nil
end

function IslandTracker:_bindFolder(folder)
    for _,model in ipairs(folder:GetChildren()) do
        self:_track(model)
    end

    self.Connections[#self.Connections+1]=folder.ChildAdded:Connect(function(model)
        self:_track(model)
    end)

    self.Connections[#self.Connections+1]=folder.ChildRemoved:Connect(function(model)
        self:_untrack(model)
    end)
end

function IslandTracker:Start()
    if self.Started then
        return
    end

    self.Started=true

    if self.Data then
        for _,island in ipairs(self.Data.GetTeleportable()) do
            self:_register(island.Name,island.CFrame,true)
        end
    end

    local folder=Workspace:FindFirstChild("Ilhas")

    if folder then
        self:_bindFolder(folder)
    end

    self.Connections[#self.Connections+1]=Workspace.ChildAdded:Connect(function(child)
        if child.Name=="Ilhas" then
            self:_bindFolder(child)
        end
    end)
end

function IslandTracker:SetESPEnabled(enabled)
    self.ESPEnabled=enabled==true

    for name in pairs(self.Known) do
        self:_refreshVisual(name)
    end
end

function IslandTracker:GetTeleportNames()
    local result={}

    if not self.Data then
        return result
    end

    for _,island in ipairs(self.Data.GetTeleportable()) do
        result[#result+1]=island.Name
    end

    return result
end

function IslandTracker:Teleport(name,owner,priority)
    local record=self.Known[name]
    local cframe=record and record.CFrame

    if not cframe and self.Data then
        local data=self.Data.Get(name)
        cframe=data and data.CFrame
    end

    if not cframe or not self.Movement then
        return false
    end

    return self.Movement:FlyTo(cframe*CFrame.new(0,3,0),nil,owner or "IslandTeleport",priority)
end

function IslandTracker:GetKnownIslands()
    local result={}

    for _,record in pairs(self.Known) do
        result[#result+1]={
            Name=record.Name,
            Position=record.Position,
            CFrame=record.CFrame,
            LevelMin=record.LevelMin,
            LevelMax=record.LevelMax,
            Mirage=record.Mirage
        }
    end

    table.sort(result,function(a,b)
        local dataA=self.Data and self.Data.Get(a.Name)
        local dataB=self.Data and self.Data.Get(b.Name)
        local orderA=dataA and dataA.Order or math.huge
        local orderB=dataB and dataB.Order or math.huge

        if orderA~=orderB then
            return orderA<orderB
        end

        return a.Name<b.Name
    end)

    return result
end

function IslandTracker:Destroy()
    if not self.Started then
        return
    end

    self.Started=false
    disconnectAll(self.Connections)

    local models={}

    for model in pairs(self.Records) do
        models[#models+1]=model
    end

    for _,model in ipairs(models) do
        self:_untrack(model)
    end

    for _,marker in pairs(self.Markers) do
        if marker and marker.Parent then
            marker:Destroy()
        end
    end

    table.clear(self.Markers)
    table.clear(self.Known)

    local folder=Workspace:FindFirstChild(MARKER_FOLDER)

    if folder then
        folder:Destroy()
    end
end

return IslandTracker

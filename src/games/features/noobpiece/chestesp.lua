local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local ChestESP={}
ChestESP.__index=ChestESP

local function disconnectAll(list)
    for _,connection in ipairs(list) do pcall(connection.Disconnect,connection) end
    table.clear(list)
end

function ChestESP.new()
    return setmetatable({Enabled=false,Player=Players.LocalPlayer,Records={},Connections={},Accumulator=0},ChestESP)
end

function ChestESP:_root()
    local character=self.Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function ChestESP:_parts(model)
    return model:FindFirstChild("Part1",true),model:FindFirstChild("Part2",true)
end

function ChestESP:_spawned(model)
    local part1,part2=self:_parts(model)
    if not part1 or not part2 or not part1:IsA("BasePart") or not part2:IsA("BasePart") then return false end
    return part1.Transparency<0.99 or part2.Transparency<0.99
end

function ChestESP:_adornee(model)
    local part1,part2=self:_parts(model)
    if part1 and part1:IsA("BasePart") and part1.Transparency<0.99 then return part1 end
    if part2 and part2:IsA("BasePart") and part2.Transparency<0.99 then return part2 end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end

function ChestESP:_clearVisual(record)
    if record.Gui then record.Gui:Destroy() record.Gui=nil end
    if record.Highlight then record.Highlight:Destroy() record.Highlight=nil end
    record.Adornee=nil
    record.DistanceLabel=nil
end

function ChestESP:_buildPreview(viewport,model)
    local camera=Instance.new("Camera")
    camera.FieldOfView=35
    camera.Parent=viewport
    viewport.CurrentCamera=camera

    local world=Instance.new("WorldModel")
    world.Parent=viewport

    local oldArchivable=model.Archivable
    model.Archivable=true
    local ok,clone=pcall(function() return model:Clone() end)
    model.Archivable=oldArchivable
    if not ok or not clone then return end

    for _,descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA("LuaSourceContainer") or descendant:IsA("BillboardGui") or descendant:IsA("Highlight") then
            descendant:Destroy()
        elseif descendant:IsA("BasePart") then
            descendant.Anchored=true
            descendant.CanCollide=false
            descendant.CanTouch=false
            descendant.CanQuery=false
        end
    end

    clone.Parent=world
    pcall(function() clone:PivotTo(CFrame.new()) end)
    local okBounds,boundsCF,boundsSize=pcall(function()
        local cf,size=clone:GetBoundingBox()
        return cf,size
    end)
    if not okBounds then return end

    local radius=math.max(boundsSize.X,boundsSize.Y,boundsSize.Z)
    local cameraDistance=math.max(3,radius*2.15)
    local center=boundsCF.Position
    camera.CFrame=CFrame.lookAt(center+Vector3.new(cameraDistance*0.72,cameraDistance*0.42,cameraDistance),center)
end

function ChestESP:_createVisual(model,record)
    if record.Gui or not self.Enabled or not self:_spawned(model) then return end
    local adornee=self:_adornee(model)
    if not adornee then return end

    local highlight=Instance.new("Highlight")
    highlight.Name="DepHubChestESP"
    highlight.Adornee=model
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor=Color3.fromRGB(255,205,70)
    highlight.FillTransparency=0.5
    highlight.OutlineColor=Color3.fromRGB(255,240,175)
    highlight.OutlineTransparency=0.05
    highlight.Parent=model

    local gui=Instance.new("BillboardGui")
    gui.Name="DepHubChestLabel"
    gui.Adornee=adornee
    gui.AlwaysOnTop=true
    gui.Size=UDim2.fromOffset(270,78)
    gui.StudsOffset=Vector3.new(0,3.5,0)
    gui.MaxDistance=5000
    gui.LightInfluence=0
    gui.Parent=adornee

    local card=Instance.new("Frame")
    card.Name="Card"
    card.Size=UDim2.fromScale(1,1)
    card.BackgroundColor3=Color3.fromRGB(17,18,22)
    card.BackgroundTransparency=0.08
    card.BorderSizePixel=0
    card.Parent=gui
    local corner=Instance.new("UICorner")
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=card
    local stroke=Instance.new("UIStroke")
    stroke.Color=Color3.fromRGB(255,205,70)
    stroke.Transparency=0.25
    stroke.Thickness=1
    stroke.Parent=card

    local preview=Instance.new("ViewportFrame")
    preview.Name="ChestPreview"
    preview.Size=UDim2.fromOffset(64,64)
    preview.Position=UDim2.fromOffset(7,7)
    preview.BackgroundColor3=Color3.fromRGB(27,28,34)
    preview.BorderSizePixel=0
    preview.Ambient=Color3.fromRGB(210,210,210)
    preview.LightColor=Color3.new(1,1,1)
    preview.LightDirection=Vector3.new(-1,-1,-1)
    preview.Parent=card
    local previewCorner=Instance.new("UICorner")
    previewCorner.CornerRadius=UDim.new(0,8)
    previewCorner.Parent=preview
    local previewStroke=Instance.new("UIStroke")
    previewStroke.Color=Color3.fromRGB(255,205,70)
    previewStroke.Transparency=0.6
    previewStroke.Thickness=1
    previewStroke.Parent=preview
    self:_buildPreview(preview,model)

    local name=Instance.new("TextLabel")
    name.Name="ChestName"
    name.BackgroundTransparency=1
    name.Position=UDim2.fromOffset(82,8)
    name.Size=UDim2.new(1,-90,0,21)
    name.Font=Enum.Font.GothamBold
    name.Text="BAU"
    name.TextColor3=Color3.new(1,1,1)
    name.TextSize=15
    name.TextXAlignment=Enum.TextXAlignment.Left
    name.Parent=card

    local description=Instance.new("TextLabel")
    description.Name="Description"
    description.BackgroundTransparency=1
    description.Position=UDim2.fromOffset(82,30)
    description.Size=UDim2.new(1,-90,0,18)
    description.Font=Enum.Font.GothamMedium
    description.Text="BAU DISPONIVEL"
    description.TextColor3=Color3.fromRGB(210,210,215)
    description.TextSize=11
    description.TextXAlignment=Enum.TextXAlignment.Left
    description.Parent=card

    local distance=Instance.new("TextLabel")
    distance.Name="Distance"
    distance.BackgroundTransparency=1
    distance.Position=UDim2.fromOffset(82,51)
    distance.Size=UDim2.new(1,-90,0,18)
    distance.Font=Enum.Font.GothamBold
    distance.Text="DISTANCIA: --"
    distance.TextColor3=Color3.fromRGB(255,205,70)
    distance.TextSize=11
    distance.TextXAlignment=Enum.TextXAlignment.Left
    distance.Parent=card

    record.Highlight=highlight
    record.Gui=gui
    record.Adornee=adornee
    record.DistanceLabel=distance
end

function ChestESP:_refresh(model)
    local record=self.Records[model]
    if not record then return end
    disconnectAll(record.StateConnections)
    local part1,part2=self:_parts(model)
    for _,part in ipairs({part1,part2}) do
        if part and part:IsA("BasePart") then
            table.insert(record.StateConnections,part:GetPropertyChangedSignal("Transparency"):Connect(function()
                self:_refresh(model)
            end))
        end
    end
    if self:_spawned(model) then self:_createVisual(model,record) else self:_clearVisual(record) end
end

function ChestESP:_track(model)
    if not model:IsA("Model") or model.Name~="Bau" or self.Records[model] then return end
    local record={StateConnections={},ModelConnections={}}
    self.Records[model]=record
    table.insert(record.ModelConnections,model.DescendantAdded:Connect(function(descendant)
        if descendant.Name=="Part1" or descendant.Name=="Part2" then task.defer(function() self:_refresh(model) end) end
    end))
    table.insert(record.ModelConnections,model.DescendantRemoving:Connect(function(descendant)
        if descendant.Name=="Part1" or descendant.Name=="Part2" then task.defer(function() self:_refresh(model) end) end
    end))
    self:_refresh(model)
end

function ChestESP:_untrack(model)
    local record=self.Records[model]
    if not record then return end
    disconnectAll(record.StateConnections)
    disconnectAll(record.ModelConnections)
    self:_clearVisual(record)
    self.Records[model]=nil
end

function ChestESP:_bindFolder(folder)
    for _,model in ipairs(folder:GetChildren()) do self:_track(model) end
    table.insert(self.Connections,folder.ChildAdded:Connect(function(model) task.defer(function() self:_track(model) end) end))
    table.insert(self.Connections,folder.ChildRemoved:Connect(function(model) self:_untrack(model) end))
end

function ChestESP:SetEnabled(enabled)
    enabled=enabled==true
    if self.Enabled==enabled then return end
    self.Enabled=enabled
    if not enabled then
        disconnectAll(self.Connections)
        local models={}
        for model in pairs(self.Records) do table.insert(models,model) end
        for _,model in ipairs(models) do self:_untrack(model) end
        return
    end

    local folder=Workspace:FindFirstChild("Bau")
    if folder then self:_bindFolder(folder) end
    table.insert(self.Connections,Workspace.ChildAdded:Connect(function(child)
        if child.Name=="Bau" then self:_bindFolder(child) end
    end))
    table.insert(self.Connections,RunService.Heartbeat:Connect(function(dt)
        self.Accumulator+=dt
        if self.Accumulator<0.1 then return end
        self.Accumulator=0
        local root=self:_root()
        for model,record in pairs(self.Records) do
            if not model.Parent then
                self:_untrack(model)
            elseif record.Gui and (not self:_spawned(model) or not record.Adornee or not record.Adornee.Parent) then
                self:_refresh(model)
            elseif record.DistanceLabel and root and record.Adornee then
                record.DistanceLabel.Text=string.format("DISTANCIA: %d STUDS",math.floor((root.Position-record.Adornee.Position).Magnitude+0.5))
            elseif record.DistanceLabel then
                record.DistanceLabel.Text="DISTANCIA: --"
            end
        end
    end))
end

function ChestESP:Destroy()
    self:SetEnabled(false)
end

return ChestESP

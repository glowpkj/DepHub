local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local ChestESP={}
ChestESP.__index=ChestESP

local function disconnectAll(list)
    for _,connection in ipairs(list) do
        pcall(connection.Disconnect,connection)
    end
    table.clear(list)
end

function ChestESP.new()
    return setmetatable({
        Enabled=false,
        Player=Players.LocalPlayer,
        Records={},
        Connections={},
        BoundRoots={},
        Accumulator=0
    },ChestESP)
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

    if not part1 or not part2 or not part1:IsA("BasePart") or not part2:IsA("BasePart") then
        return false
    end

    return part1.Transparency<0.99 or part2.Transparency<0.99
end

function ChestESP:_adornee(model)
    local part1,part2=self:_parts(model)

    if part1 and part1:IsA("BasePart") and part1.Transparency<0.99 then
        return part1
    end

    if part2 and part2:IsA("BasePart") and part2.Transparency<0.99 then
        return part2
    end

    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end

function ChestESP:_isChest(model)
    if not model or not model:IsA("Model") then
        return false
    end

    if model.Name=="Bau" then
        return true
    end

    local part1,part2=self:_parts(model)
    return part1~=nil and part2~=nil
end

function ChestESP:_isMysterious(model)
    local current=model

    while current and current~=Workspace do
        if current.Name=="MysteriousIsland" and current.Parent==Workspace then
            return true
        end
        current=current.Parent
    end

    return false
end

function ChestESP:_clearVisual(record)
    if record.Gui then
        record.Gui:Destroy()
        record.Gui=nil
    end

    if record.Highlight then
        record.Highlight:Destroy()
        record.Highlight=nil
    end

    record.Adornee=nil
    record.DistanceLabel=nil
end

function ChestESP:_createVisual(model,record)
    if record.Gui or not self.Enabled or not self:_spawned(model) then
        return
    end

    local adornee=self:_adornee(model)

    if not adornee then
        return
    end

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
    gui.Size=UDim2.fromOffset(180,42)
    gui.StudsOffset=Vector3.new(0,3,0)
    gui.MaxDistance=10000
    gui.LightInfluence=0
    gui.Parent=adornee

    local label=Instance.new("TextLabel")
    label.Name="Label"
    label.BackgroundTransparency=1
    label.Size=UDim2.fromScale(1,1)
    label.Font=Enum.Font.GothamBold
    label.RichText=true
    label.TextColor3=Color3.new(1,1,1)
    label.TextStrokeColor3=Color3.new(0,0,0)
    label.TextStrokeTransparency=0.25
    label.TextSize=13
    label.Parent=gui

    record.Highlight=highlight
    record.Gui=gui
    record.Adornee=adornee
    record.DistanceLabel=label
    record.Mysterious=self:_isMysterious(model)
end

function ChestESP:_refresh(model)
    local record=self.Records[model]

    if not record then
        return
    end

    disconnectAll(record.StateConnections)

    local part1,part2=self:_parts(model)

    for _,part in ipairs({part1,part2}) do
        if part and part:IsA("BasePart") then
            record.StateConnections[#record.StateConnections+1]=part:GetPropertyChangedSignal("Transparency"):Connect(function()
                self:_refresh(model)
            end)
        end
    end

    if self:_spawned(model) then
        self:_createVisual(model,record)
    else
        self:_clearVisual(record)
    end
end

function ChestESP:_track(model)
    if not self:_isChest(model) or self.Records[model] then
        return
    end

    local record={StateConnections={},ModelConnections={}}
    self.Records[model]=record

    record.ModelConnections[#record.ModelConnections+1]=model.DescendantAdded:Connect(function(descendant)
        if descendant.Name=="Part1" or descendant.Name=="Part2" then
            task.defer(function()
                self:_refresh(model)
            end)
        end
    end)

    record.ModelConnections[#record.ModelConnections+1]=model.DescendantRemoving:Connect(function(descendant)
        if descendant.Name=="Part1" or descendant.Name=="Part2" then
            task.defer(function()
                self:_refresh(model)
            end)
        end
    end)

    self:_refresh(model)
end

function ChestESP:_untrack(model)
    local record=self.Records[model]

    if not record then
        return
    end

    disconnectAll(record.StateConnections)
    disconnectAll(record.ModelConnections)
    self:_clearVisual(record)
    self.Records[model]=nil
end

function ChestESP:_bindRoot(root)
    if not root or self.BoundRoots[root] then
        return
    end

    self.BoundRoots[root]=true

    if root:IsA("Model") then
        self:_track(root)
    end

    for _,object in ipairs(root:GetDescendants()) do
        if object:IsA("Model") then
            self:_track(object)
        end
    end

    self.Connections[#self.Connections+1]=root.DescendantAdded:Connect(function(object)
        if object:IsA("Model") then
            task.defer(function()
                self:_track(object)
            end)
        end
    end)

    self.Connections[#self.Connections+1]=root.DescendantRemoving:Connect(function(object)
        if object:IsA("Model") then
            self:_untrack(object)
        end
    end)
end

function ChestESP:_bindMysterious(island)
    if not island then
        return
    end

    local chestRoot=island:FindFirstChild("Bau")

    if chestRoot then
        self:_bindRoot(chestRoot)
    end

    self.Connections[#self.Connections+1]=island.ChildAdded:Connect(function(child)
        if child.Name=="Bau" then
            self:_bindRoot(child)
        end
    end)
end

function ChestESP:SetEnabled(enabled)
    enabled=enabled==true

    if self.Enabled==enabled then
        return
    end

    self.Enabled=enabled

    if not enabled then
        disconnectAll(self.Connections)
        table.clear(self.BoundRoots)

        local models={}

        for model in pairs(self.Records) do
            models[#models+1]=model
        end

        for _,model in ipairs(models) do
            self:_untrack(model)
        end

        return
    end

    local normal=Workspace:FindFirstChild("Bau")

    if normal then
        self:_bindRoot(normal)
    end

    self:_bindMysterious(Workspace:FindFirstChild("MysteriousIsland"))

    self.Connections[#self.Connections+1]=Workspace.ChildAdded:Connect(function(child)
        if child.Name=="Bau" then
            self:_bindRoot(child)
        elseif child.Name=="MysteriousIsland" then
            self:_bindMysterious(child)
        end
    end)

    self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
        self.Accumulator+=dt

        if self.Accumulator<0.1 then
            return
        end

        self.Accumulator=0
        local root=self:_root()

        for model,record in pairs(self.Records) do
            if not model.Parent then
                self:_untrack(model)
            elseif record.Gui and (not self:_spawned(model) or not record.Adornee or not record.Adornee.Parent) then
                self:_refresh(model)
            elseif record.DistanceLabel and root and record.Adornee then
                local title=record.Mysterious and "BAU | MYSTERIOUS" or "BAU"
                record.DistanceLabel.Text=string.format(
                    "<b>%s</b>\n<font color='#FFCD46'>%.2f STUDS</font>",
                    title,
                    (root.Position-record.Adornee.Position).Magnitude
                )
            elseif record.DistanceLabel then
                local title=record.Mysterious and "BAU | MYSTERIOUS" or "BAU"
                record.DistanceLabel.Text="<b>"..title.."</b>\n<font color='#FFCD46'>-- STUDS</font>"
            end
        end
    end)
end

function ChestESP:Destroy()
    self:SetEnabled(false)
end

return ChestESP

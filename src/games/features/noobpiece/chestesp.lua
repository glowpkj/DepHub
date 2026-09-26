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
    gui.Size=UDim2.fromOffset(150,42)
    gui.StudsOffset=Vector3.new(0,3,0)
    gui.MaxDistance=5000
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
    label.Text="<b>BAU</b>\n<font color=\"#FFCD46\">-- STUDS</font>"
    label.Parent=gui

    record.Highlight=highlight
    record.Gui=gui
    record.Adornee=adornee
    record.DistanceLabel=label
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
                record.DistanceLabel.Text=string.format("<b>BAU</b>"..string.char(10).."<font color='#FFCD46'>%.2f STUDS</font>",(root.Position-record.Adornee.Position).Magnitude)
            elseif record.DistanceLabel then
                record.DistanceLabel.Text="<b>BAU</b>"..string.char(10).."<font color='#FFCD46'>-- STUDS</font>"
            end
        end
    end))
end

function ChestESP:Destroy()
    self:SetEnabled(false)
end

return ChestESP

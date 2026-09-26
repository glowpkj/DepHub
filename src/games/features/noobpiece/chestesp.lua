local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local ChestESP={}
ChestESP.__index=ChestESP

function ChestESP.new()
    local self=setmetatable({},ChestESP)
    self.Enabled=false
    self.Items={}
    self.Connections={}
    self.Player=Players.LocalPlayer
    return self
end

function ChestESP:_root()
    local character=self.Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function ChestESP:_part(model)
    if not model or not model:IsA("Model") then return nil end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
end

function ChestESP:_remove(model)
    local item=self.Items[model]
    if not item then return end
    if item.Gui then item.Gui:Destroy() end
    if item.Highlight then item.Highlight:Destroy() end
    self.Items[model]=nil
end

function ChestESP:_add(model)
    if not self.Enabled or self.Items[model] or not model:IsA("Model") or model.Name~="Bau" then return end
    local part=self:_part(model)
    if not part then return end

    local highlight=Instance.new("Highlight")
    highlight.Name="DepHubChestESP"
    highlight.Adornee=model
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor=Color3.fromRGB(255,205,70)
    highlight.FillTransparency=0.72
    highlight.OutlineColor=Color3.fromRGB(255,240,175)
    highlight.OutlineTransparency=0.05
    highlight.Parent=model

    local gui=Instance.new("BillboardGui")
    gui.Name="DepHubChestLabel"
    gui.Adornee=part
    gui.AlwaysOnTop=true
    gui.Size=UDim2.fromOffset(150,42)
    gui.StudsOffset=Vector3.new(0,2.5,0)
    gui.MaxDistance=5000
    gui.Parent=part

    local label=Instance.new("TextLabel")
    label.Name="Label"
    label.BackgroundTransparency=1
    label.Size=UDim2.fromScale(1,1)
    label.Font=Enum.Font.GothamBold
    label.TextColor3=Color3.new(1,1,1)
    label.TextStrokeColor3=Color3.new(0,0,0)
    label.TextStrokeTransparency=0.35
    label.TextSize=13
    label.Text="BAU"
    label.Parent=gui

    self.Items[model]={Highlight=highlight,Gui=gui,Label=label,Part=part}
end

function ChestESP:_scan()
    local folder=Workspace:FindFirstChild("Bau")
    if not folder then return end
    for _,child in ipairs(folder:GetChildren()) do self:_add(child) end
end

function ChestESP:SetEnabled(enabled)
    enabled=enabled==true
    if self.Enabled==enabled then return end
    self.Enabled=enabled
    if enabled then
        self:_scan()
        local folder=Workspace:FindFirstChild("Bau")
        if folder then
            table.insert(self.Connections,folder.ChildAdded:Connect(function(child) task.defer(function() self:_add(child) end) end))
            table.insert(self.Connections,folder.ChildRemoved:Connect(function(child) self:_remove(child) end))
        end
        table.insert(self.Connections,Workspace.ChildAdded:Connect(function(child)
            if child.Name=="Bau" then task.defer(function()
                for _,item in ipairs(child:GetChildren()) do self:_add(item) end
            end) end
        end))
        table.insert(self.Connections,RunService.RenderStepped:Connect(function()
            local root=self:_root()
            for model,item in pairs(self.Items) do
                if not model.Parent or not item.Part.Parent then
                    self:_remove(model)
                elseif root then
                    item.Label.Text=string.format("BAU\n%d STUDS",math.floor((root.Position-item.Part.Position).Magnitude+0.5))
                else
                    item.Label.Text="BAU"
                end
            end
        end))
    else
        for _,connection in ipairs(self.Connections) do connection:Disconnect() end
        table.clear(self.Connections)
        for model in pairs(self.Items) do self:_remove(model) end
    end
end

function ChestESP:Destroy()
    self:SetEnabled(false)
end

return ChestESP

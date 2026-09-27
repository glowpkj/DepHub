local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local NpcESP={}
NpcESP.__index=NpcESP

function NpcESP.new()
    return setmetatable({
        Player=Players.LocalPlayer,
        Enabled=false,
        Connections={},
        Gui=nil,
        Highlight=nil,
        Adornee=nil,
        Accumulator=0
    },NpcESP)
end

function NpcESP:_root()
    local character=self.Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function NpcESP:_npc()
    local folder=Workspace:FindFirstChild("WanderingGacha")
    return folder and folder:FindFirstChild("WanderingGacha")
end

function NpcESP:_adornee(npc)
    if not npc then
        return nil
    end

    if npc:IsA("BasePart") then
        return npc
    end

    if npc:IsA("Model") then
        return npc.PrimaryPart
            or npc:FindFirstChild("HumanoidRootPart")
            or npc:FindFirstChildWhichIsA("BasePart",true)
    end

    return nil
end

function NpcESP:_clear()
    if self.Gui then
        self.Gui:Destroy()
        self.Gui=nil
    end

    if self.Highlight then
        self.Highlight:Destroy()
        self.Highlight=nil
    end

    self.Adornee=nil
end

function NpcESP:_refresh()
    if not self.Enabled then
        self:_clear()
        return
    end

    local npc=self:_npc()
    local adornee=self:_adornee(npc)

    if not npc or not adornee then
        self:_clear()
        return
    end

    if self.Adornee==adornee and self.Gui and self.Highlight then
        return
    end

    self:_clear()

    local highlight=Instance.new("Highlight")
    highlight.Name="DepHubGachaESP"
    highlight.Adornee=npc
    highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency=0.5
    highlight.OutlineTransparency=0.05
    highlight.Parent=npc

    local gui=Instance.new("BillboardGui")
    gui.Name="DepHubGachaLabel"
    gui.Adornee=adornee
    gui.AlwaysOnTop=true
    gui.Size=UDim2.fromOffset(190,42)
    gui.StudsOffset=Vector3.new(0,3,0)
    gui.MaxDistance=10000
    gui.LightInfluence=0
    gui.Parent=adornee

    local label=Instance.new("TextLabel")
    label.Name="Label"
    label.BackgroundTransparency=1
    label.Size=UDim2.fromScale(1,1)
    label.Font=Enum.Font.GothamBold
    label.TextColor3=Color3.new(1,1,1)
    label.TextStrokeColor3=Color3.new(0,0,0)
    label.TextStrokeTransparency=0.25
    label.TextSize=13
    label.Parent=gui

    self.Gui=gui
    self.Highlight=highlight
    self.Adornee=adornee
end

function NpcESP:SetEnabled(enabled)
    enabled=enabled==true

    if self.Enabled==enabled then
        return
    end

    self.Enabled=enabled

    if not enabled then
        for _,connection in ipairs(self.Connections) do
            pcall(connection.Disconnect,connection)
        end
        table.clear(self.Connections)
        self:_clear()
        return
    end

    self:_refresh()

    self.Connections[#self.Connections+1]=Workspace.ChildAdded:Connect(function(child)
        if child.Name=="WanderingGacha" then
            task.defer(function()
                self:_refresh()
            end)
        end
    end)

    self.Connections[#self.Connections+1]=Workspace.ChildRemoved:Connect(function(child)
        if child.Name=="WanderingGacha" then
            task.defer(function()
                self:_refresh()
            end)
        end
    end)

    self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
        self.Accumulator+=dt

        if self.Accumulator<0.1 then
            return
        end

        self.Accumulator=0
        self:_refresh()

        if self.Gui and self.Adornee then
            local root=self:_root()
            local distance=root and (root.Position-self.Adornee.Position).Magnitude
            self.Gui.Label.Text=distance
                and string.format("WANDERING GACHA\n%.2f STUDS",distance)
                or "WANDERING GACHA\n-- STUDS"
        end
    end)
end

function NpcESP:Destroy()
    self:SetEnabled(false)
end

return NpcESP

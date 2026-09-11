local game=game
local type=type
local pairs=pairs
local ipairs=ipairs

local Factory={}

function Factory.new(context)
    context=context or {}
    local Players=context.Players or game:GetService("Players")
    local RunService=context.RunService or game:GetService("RunService")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer
    local RoleTracker=context.RoleTracker

    local self={Enabled=false,Destroyed=false,Connections={},Records={},Accumulator=0}

    local COLORS={
        Murder=Color3.fromRGB(255,72,72),
        Sheriff=Color3.fromRGB(70,160,255)
    }

    function self:_remove(player)
        local record=self.Records[player]
        self.Records[player]=nil
        if record then
            if record.Highlight then pcall(record.Highlight.Destroy,record.Highlight) end
            if record.Billboard then pcall(record.Billboard.Destroy,record.Billboard) end
        end
    end

    function self:_render(player,role)
        if player==LocalPlayer then
            self:_remove(player)
            return
        end
        if role~="Murder" and role~="Sheriff" then
            self:_remove(player)
            return
        end
        local character=player.Character
        local head=character and character:FindFirstChild("Head")
        if not character or not head then
            self:_remove(player)
            return
        end

        local record=self.Records[player]
        if record and record.Character~=character then
            self:_remove(player)
            record=nil
        end
        if not record then
            local highlight=Instance.new("Highlight")
            highlight.Name="DepHubMM2Highlight"
            highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillTransparency=0.42
            highlight.OutlineTransparency=1
            highlight.Adornee=character
            highlight.Parent=character

            local billboard=Instance.new("BillboardGui")
            billboard.Name="DepHubMM2Role"
            billboard.Size=UDim2.fromOffset(180,34)
            billboard.StudsOffset=Vector3.new(0,2.8,0)
            billboard.AlwaysOnTop=true
            billboard.Adornee=head
            billboard.Parent=head

            local text=Instance.new("TextLabel")
            text.Name="Text"
            text.Size=UDim2.fromScale(1,1)
            text.BackgroundTransparency=1
            text.Font=Enum.Font.GothamBold
            text.TextSize=13
            text.TextStrokeTransparency=0.25
            text.Parent=billboard

            record={Character=character,Highlight=highlight,Billboard=billboard,Text=text}
            self.Records[player]=record
        end

        local color=COLORS[role]
        record.Highlight.FillColor=color
        record.Text.Text=role:upper().." | "..player.Name
        record.Text.TextColor3=color
    end

    function self:Refresh()
        if self.Destroyed or not self.Enabled or not RoleTracker then return end
        for _,player in ipairs(Players:GetPlayers()) do
            self:_render(player,RoleTracker:GetRole(player))
        end
        for player in pairs(self.Records) do
            if not player.Parent then self:_remove(player) end
        end
    end

    function self:Enable()
        if self.Destroyed then return false end
        if self.Enabled then return true end
        self.Enabled=true
        self.Connections[#self.Connections+1]=RunService.Heartbeat:Connect(function(dt)
            self.Accumulator=self.Accumulator+dt
            if self.Accumulator>=0.2 then
                self.Accumulator=0
                self:Refresh()
            end
        end)
        self:Refresh()
        return true
    end

    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false
        for i=#self.Connections,1,-1 do
            local c=self.Connections[i]
            self.Connections[i]=nil
            if c then pcall(c.Disconnect,c) end
        end
        for player in pairs(self.Records) do self:_remove(player) end
        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed=true
    end

    return self
end

return Factory

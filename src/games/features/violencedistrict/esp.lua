local game=game
local type=type
local pcall=pcall
local tostring=tostring

local Factory={}

function Factory.new(context)
    context=context or {}
    local Players=context.Players or game:GetService("Players")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer

    local self={
        Enabled=false,
        Destroyed=false,
        Connections={},
        PlayerConnections={},
        Visuals={},
        Debug=context.Debug==true
    }

    local function disconnect(connection)
        if connection then pcall(connection.Disconnect,connection) end
    end

    local function cleanList(list)
        if not list then return end
        for i=#list,1,-1 do
            local connection=list[i]
            list[i]=nil
            disconnect(connection)
        end
    end

    function self:_debug(message)
        if self.Debug then
            print("[DepHub VD ESP] "..tostring(message))
        end
    end

    function self:_roleColor(player)
        local team=player and player.Team
        local name=team and string.lower(team.Name) or ""
        if string.find(name,"killer",1,true) then
            return Color3.fromRGB(255,86,86)
        end
        if string.find(name,"surviv",1,true) then
            return Color3.fromRGB(92,194,255)
        end
        if string.find(name,"spect",1,true) then
            return Color3.fromRGB(180,184,190)
        end
        return Color3.fromRGB(114,236,190)
    end

    function self:_removeVisual(player)
        local visual=self.Visuals[player]
        if not visual then return end
        self.Visuals[player]=nil
        if visual.Highlight then pcall(visual.Highlight.Destroy,visual.Highlight) end
        if visual.Billboard then pcall(visual.Billboard.Destroy,visual.Billboard) end
    end

    function self:_applyColor(player)
        local visual=self.Visuals[player]
        if not visual then return end
        local color=self:_roleColor(player)
        if visual.Highlight then visual.Highlight.FillColor=color end
        if visual.Label then visual.Label.TextColor3=color end
    end

    function self:_attachCharacter(player,character)
        if self.Destroyed or not self.Enabled or player==LocalPlayer or not character then return end
        self:_removeVisual(player)

        local head=character:FindFirstChild("Head") or character:WaitForChild("Head",5)
        if self.Destroyed or not self.Enabled or not character.Parent then return end

        local highlight=Instance.new("Highlight")
        highlight.Name="DepHubVDHighlight"
        highlight.Adornee=character
        highlight.FillTransparency=0.48
        highlight.OutlineTransparency=1
        highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent=character

        local billboard=nil
        local label=nil
        if head then
            billboard=Instance.new("BillboardGui")
            billboard.Name="DepHubVDUsername"
            billboard.Adornee=head
            billboard.AlwaysOnTop=true
            billboard.LightInfluence=0
            billboard.MaxDistance=300
            billboard.Size=UDim2.fromOffset(180,28)
            billboard.StudsOffsetWorldSpace=Vector3.new(0,2.9,0)
            billboard.Parent=head

            label=Instance.new("TextLabel")
            label.Size=UDim2.fromScale(1,1)
            label.BackgroundTransparency=1
            label.BorderSizePixel=0
            label.Text=player.Name
            label.TextSize=13
            label.Font=Enum.Font.GothamMedium
            label.TextStrokeTransparency=1
            label.TextXAlignment=Enum.TextXAlignment.Center
            label.Parent=billboard
        end

        self.Visuals[player]={Highlight=highlight,Billboard=billboard,Label=label,Character=character}
        self:_applyColor(player)
        self:_debug("ESP criado para "..player.Name)
    end

    function self:_watchPlayer(player)
        if player==LocalPlayer or self.PlayerConnections[player] then return end
        local list={}
        self.PlayerConnections[player]=list
        list[#list+1]=player.CharacterAdded:Connect(function(character)
            task.defer(function()
                self:_attachCharacter(player,character)
            end)
        end)
        list[#list+1]=player:GetPropertyChangedSignal("Team"):Connect(function()
            self:_applyColor(player)
        end)
        if player.Character then
            task.defer(function()
                self:_attachCharacter(player,player.Character)
            end)
        end
    end

    function self:_unwatchPlayer(player)
        cleanList(self.PlayerConnections[player])
        self.PlayerConnections[player]=nil
        self:_removeVisual(player)
    end

    function self:SetDebug(value)
        self.Debug=value==true
        return true
    end

    function self:Enable()
        if self.Destroyed or self.Enabled then return false end
        self.Enabled=true
        self.Connections[#self.Connections+1]=Players.PlayerAdded:Connect(function(player)
            self:_watchPlayer(player)
        end)
        self.Connections[#self.Connections+1]=Players.PlayerRemoving:Connect(function(player)
            self:_unwatchPlayer(player)
        end)
        for _,player in ipairs(Players:GetPlayers()) do
            self:_watchPlayer(player)
        end
        return true
    end

    function self:Disable()
        if self.Destroyed then return false end
        self.Enabled=false
        cleanList(self.Connections)
        for player,list in pairs(self.PlayerConnections) do
            cleanList(list)
            self.PlayerConnections[player]=nil
        end
        for player in pairs(self.Visuals) do
            self:_removeVisual(player)
        end
        return true
    end

    function self:Destroy()
        if self.Destroyed then return end
        self:Disable()
        self.Destroyed=true
        self.Visuals=nil
        self.PlayerConnections=nil
    end

    return self
end

return Factory

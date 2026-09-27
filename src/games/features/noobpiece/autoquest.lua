local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local AutoQuest={}
AutoQuest.__index=AutoQuest

local MOVEMENT_OWNER="AutoQuest"
local MOVEMENT_PRIORITY=300

local function lower(value)
    return string.lower(tostring(value or ""))
end

function AutoQuest.new(movement,islandData,autoFarm)
    local events=ReplicatedStorage:WaitForChild("Events")

    local self=setmetatable({
        Player=Players.LocalPlayer,
        Movement=movement,
        IslandData=islandData,
        AutoFarm=autoFarm,
        NpcInteract=events:WaitForChild("NpcInteract"),
        OpenDialog=events:WaitForChild("OpenDialog"),
        DialogChoice=events:WaitForChild("DialogChoice"),
        QuestUpdate=events:WaitForChild("QuestUpdate"),
        Enabled=false,
        Token=0,
        SelectedEnemy="Noob",
        ActiveQuest=nil,
        Stage=nil,
        WaitingDialog=false,
        LastInteract=0,
        DialogMovement=nil,
        IgnoreHudUntil=0,
        Connections={}
    },AutoQuest)

    self.Connections[#self.Connections+1]=self.OpenDialog.OnClientEvent:Connect(function(data)
        self:_onDialog(data)
    end)

    self.Connections[#self.Connections+1]=self.QuestUpdate.OnClientEvent:Connect(function(data)
        self:_onQuestUpdate(data)
    end)

    self:_syncHud()
    return self
end

function AutoQuest:_character()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return character,humanoid,root
end

function AutoQuest:_syncHud()
    if os.clock()<self.IgnoreHudUntil then
        return
    end

    local playerGui=self.Player:FindFirstChild("PlayerGui")
    local hud=playerGui and playerGui:FindFirstChild("QuestHUD")
    local quest=hud and hud:FindFirstChild("Quest")

    if not quest or not quest.Visible then
        return
    end

    local header=quest:FindFirstChild("HeaderFrame")
    local background=quest:FindFirstChild("BackgroundFrame")
    local questLabel=header and header:FindFirstChild("QuestLabel")
    local counter=background and background:FindFirstChild("CounterLabel")
    local kills,required

    if counter and type(counter.Text)=="string" then
        kills,required=counter.Text:match("(%d+)%s*/%s*(%d+)")
        kills=tonumber(kills)
        required=tonumber(required)
    end

    self.ActiveQuest={
        QuestName=questLabel and questLabel.Text or nil,
        Kills=kills,
        Required=required,
        SeededFromHUD=true
    }
end

function AutoQuest:_onQuestUpdate(data)
    if typeof(data)~="table" then
        return
    end

    if data.Removed then
        if not self.ActiveQuest or not self.ActiveQuest.Id or self.ActiveQuest.Id==data.Id then
            self.ActiveQuest=nil
        end

        self.IgnoreHudUntil=os.clock()+0.6

        if self.Enabled then
            self.Stage=nil
            self.WaitingDialog=false
            self.Token+=1
            local token=self.Token
            task.delay(0.2,function()
                self:_run(token)
            end)
        end
        return
    end

    self.ActiveQuest=data
    self.Stage=nil
    self.WaitingDialog=false

    if self.AutoFarm then
        self.AutoFarm:SetPaused(self.Enabled and not self:_questMatches())
    end
end

function AutoQuest:_questInfo()
    if not self.IslandData then
        return nil
    end

    local island,enemy=self.IslandData.FindEnemy(self.SelectedEnemy)

    if not island or not enemy or type(enemy.QuestGiver)~="string" then
        return nil
    end

    return island,enemy
end

function AutoQuest:_questMatches()
    if not self.ActiveQuest then
        return false
    end

    local name=lower(self.ActiveQuest.QuestName)
    local selected=lower(self.SelectedEnemy)

    if name==selected then
        return true
    end

    local _,enemy=self:_questInfo()
    local expected=enemy and enemy.QuestId

    return expected~=nil and self.ActiveQuest.Id==expected
end

function AutoQuest:_findChoice(data,wanted)
    if typeof(data)~="table" or type(wanted)~="string" then
        return nil
    end

    for index,choice in ipairs(data.Choices or {}) do
        if lower(choice)==lower(wanted) then
            return index
        end
    end

    return nil
end

function AutoQuest:_captureDialogMovement()
    local _,humanoid=self:_character()

    if not humanoid then
        self.DialogMovement=nil
        return
    end

    local huds={}
    local playerGui=self.Player:FindFirstChild("PlayerGui")

    if playerGui then
        for _,name in ipairs({"StatsHUD","ButtonsHUD","CurrencyHUD","ProfileHUD"}) do
            local hud=playerGui:FindFirstChild(name)

            if hud then
                huds[hud]=hud.Enabled
            end
        end
    end

    self.DialogMovement={
        Humanoid=humanoid,
        WalkSpeed=humanoid.WalkSpeed,
        UseJumpPower=humanoid.UseJumpPower,
        JumpPower=humanoid.JumpPower,
        JumpHeight=humanoid.JumpHeight,
        Huds=huds
    }
end

function AutoQuest:_restoreDialog()
    task.defer(function()
        self.Player:SetAttribute("DialogOpen",false)

        local playerGui=self.Player:FindFirstChild("PlayerGui")
        local dialogs=playerGui and playerGui:FindFirstChild("DialogsHUD")

        if dialogs then
            for _,name in ipairs({"NPCDialog","QuestDialog","SelectedDialog"}) do
                local panel=dialogs:FindFirstChild(name)
                if panel then
                    panel.Visible=false
                end
            end
        end

        local state=self.DialogMovement
        local humanoid=state and state.Humanoid

        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed=state.WalkSpeed

            if state.UseJumpPower then
                humanoid.JumpPower=state.JumpPower
            else
                humanoid.JumpHeight=state.JumpHeight
            end
        end

        if state and state.Huds then
            for hud,wasEnabled in pairs(state.Huds) do
                if hud and hud.Parent then
                    hud.Enabled=wasEnabled
                end
            end
        end
    end)
end

function AutoQuest:_onDialog(data)
    if not self.Enabled or not self.WaitingDialog or typeof(data)~="table" then
        return
    end

    local _,enemy=self:_questInfo()

    if not enemy then
        return
    end

    local choice

    if self.Stage=="select" then
        choice=self:_findChoice(data,enemy.QuestChoice or enemy.Id)

        if not choice then
            self.WaitingDialog=false
            self.Stage=nil
            self:_restoreDialog()
            return
        end

        self.Stage="accept"
    elseif self.Stage=="accept" then
        choice=self:_findChoice(data,"Accept")

        if not choice then
            self.WaitingDialog=false
            self.Stage=nil
            self:_restoreDialog()
            return
        end

        self.Stage="quest"
        self.WaitingDialog=false
    else
        return
    end

    self.DialogChoice:FireServer(data.Token,choice)
    self:_restoreDialog()
end

function AutoQuest:_giver(enemy)
    local quests=Workspace:FindFirstChild("Quests")
    local questGiver=quests and quests:FindFirstChild("QuestGiver")
    local normal=questGiver and questGiver:FindFirstChild("Normal")

    return normal and normal:FindFirstChild(enemy.QuestGiver)
end

function AutoQuest:_npcRoot(npc)
    if not npc then
        return nil
    end

    if npc:IsA("BasePart") then
        return npc
    end

    if npc:IsA("Model") then
        return npc:FindFirstChild("Torso")
            or npc:FindFirstChild("UpperTorso")
            or npc:FindFirstChild("HumanoidRootPart")
            or npc.PrimaryPart
            or npc:FindFirstChildWhichIsA("BasePart",true)
    end

    return nil
end

function AutoQuest:_moveNear(root,target)
    local distance=(root.Position-target.Position).Magnitude

    if distance<=10 then
        return true
    end

    local position=target.Position-target.CFrame.LookVector*6
    local goal=CFrame.lookAt(
        position,
        Vector3.new(target.Position.X,position.Y,target.Position.Z)
    )

    return self.Movement:FlyTo(goal,nil,MOVEMENT_OWNER,MOVEMENT_PRIORITY)
end

function AutoQuest:_approachIsland(root,island)
    if not island or not island.CFrame then
        return false
    end

    local destination=island.CFrame*CFrame.new(0,3,0)

    if (root.Position-destination.Position).Magnitude<=100 then
        return false
    end

    return self.Movement:FlyTo(destination,nil,MOVEMENT_OWNER,MOVEMENT_PRIORITY)
end

function AutoQuest:_requestQuest(island,enemy,token)
    local _,_,root=self:_character()

    if not root then
        return false
    end

    local giver=self:_giver(enemy)

    if not giver then
        self:_approachIsland(root,island)
        task.wait(0.35)
        return false
    end

    local npcRoot=self:_npcRoot(giver)

    if not npcRoot then
        self:_approachIsland(root,island)
        task.wait(0.2)
        return false
    end

    if not self:_moveNear(root,npcRoot) then
        return false
    end

    if not self.Enabled or token~=self.Token then
        return false
    end

    local now=os.clock()

    if now-self.LastInteract<0.6 then
        task.wait(0.6-(now-self.LastInteract))
    end

    self:_captureDialogMovement()
    self.Stage="select"
    self.WaitingDialog=true
    self.LastInteract=os.clock()
    self.NpcInteract:FireServer(giver)
    return true
end

function AutoQuest:_run(token)
    while self.Enabled and token==self.Token do
        self:_syncHud()

        if self.ActiveQuest then
            if self.AutoFarm then
                self.AutoFarm:SetPaused(not self:_questMatches())
            end
            return
        end

        local island,enemy=self:_questInfo()

        if not island or not enemy then
            if self.AutoFarm then
                self.AutoFarm:SetPaused(false)
            end
            return
        end

        if self.AutoFarm then
            self.AutoFarm:SetPaused(true)
        end

        if not self.WaitingDialog then
            self:_requestQuest(island,enemy,token)
        end

        local deadline=os.clock()+4

        while self.Enabled and token==self.Token and not self.ActiveQuest and os.clock()<deadline do
            task.wait(0.1)
        end

        if self.ActiveQuest then
            if self.AutoFarm then
                self.AutoFarm:SetPaused(not self:_questMatches())
            end
            return
        end

        self.WaitingDialog=false
        self.Stage=nil
        task.wait(0.35)
    end
end

function AutoQuest:SetSelectedEnemy(name)
    if type(name)~="string" or name=="" then
        return false
    end

    self.SelectedEnemy=name

    if self.Enabled then
        self.Token+=1
        local token=self.Token
        task.spawn(function()
            self:_run(token)
        end)
    end

    return true
end

function AutoQuest:SetEnabled(enabled)
    enabled=enabled==true

    if self.Enabled==enabled then
        return
    end

    self.Enabled=enabled
    self.Token+=1
    self.WaitingDialog=false
    self.Stage=nil

    if not enabled then
        if self.Movement then
            self.Movement:CancelOwner(MOVEMENT_OWNER,true)
        end

        if self.AutoFarm then
            self.AutoFarm:SetPaused(false)
        end

        if self.Player:GetAttribute("DialogOpen") then
            self:_restoreDialog()
        end

        self.DialogMovement=nil
        return
    end

    self:_syncHud()
    local token=self.Token

    task.spawn(function()
        self:_run(token)
    end)
end

function AutoQuest:GetActiveQuest()
    return self.ActiveQuest
end

function AutoQuest:Destroy()
    self:SetEnabled(false)

    for _,connection in ipairs(self.Connections) do
        pcall(connection.Disconnect,connection)
    end

    table.clear(self.Connections)
end

return AutoQuest

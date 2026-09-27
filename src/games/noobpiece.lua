local Workspace=game:GetService("Workspace")
local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function loadFeature(path)
    local source=game:HttpGet(BASE_URL..path)
    local chunk=assert(loadstring(source))
    return chunk()
end

local Movement=loadFeature("src/core/tween-movement.lua")
local IslandData=loadFeature("src/games/features/noobpiece/islanddata.lua")
local ChestESP=loadFeature("src/games/features/noobpiece/chestesp.lua")
local IslandTracker=loadFeature("src/games/features/noobpiece/islandtracker.lua")
local AutoChest=loadFeature("src/games/features/noobpiece/autochest.lua")
local AutoAttack=loadFeature("src/games/features/noobpiece/autoattack.lua")
local AutoFarm=loadFeature("src/games/features/noobpiece/autofarm.lua")
local AutoTeam=loadFeature("src/games/features/noobpiece/autoteam.lua")
local WanderingGacha=loadFeature("src/games/features/noobpiece/wanderinggacha.lua")
local NpcESP=loadFeature("src/games/features/noobpiece/npcesp.lua")
local AutoQuest=loadFeature("src/games/features/noobpiece/autoquest.lua")

local backend={
    Version="0.0.14",
    Toggles={
        ChestESP=false,
        IslandESP=false,
        IslandTeleport=false,
        GachaESP=false,
        AutoQuest=false,
        AutoChest=false,
        AutoAttack=false,
        AutoFarm=false,
        AutoTeam=false,
        AutoFarmMobs=false
    },
    Values={
        AutoChestDelay=0.35,
        WeaponCategory="Fists",
        SelectedTeam="Noob",
        SelectedEnemy="Noob",
        SelectedIsland="HomeIsland"
    }
}

backend.Movement=Movement.new({
    Speed=45,
    MinDuration=0.05,
    MaxSegmentDuration=2.5,
    SegmentPause=0.5,
    UsePhysics=true
})

backend.ChestESP=ChestESP.new()
backend.IslandTracker=IslandTracker.new(IslandData,backend.Movement)
backend.AutoChest=AutoChest.new(backend.Movement)
backend.AutoAttack=AutoAttack.new()
backend.AutoFarm=AutoFarm.new(backend.Movement,backend.AutoAttack,IslandData)
backend.AutoTeam=AutoTeam.new()
backend.WanderingGacha=WanderingGacha.new(backend.Movement)
backend.NpcESP=NpcESP.new()
backend.AutoQuest=AutoQuest.new(backend.Movement,IslandData,backend.AutoFarm)

backend.AutoChest:SetDelay(backend.Values.AutoChestDelay)
backend.AutoFarm:SetWeaponCategory(backend.Values.WeaponCategory)
backend.AutoTeam:SetSelected(backend.Values.SelectedTeam)
backend.AutoFarm:SetSelectedEnemy(backend.Values.SelectedEnemy)
backend.AutoQuest:SetSelectedEnemy(backend.Values.SelectedEnemy)
backend.IslandTracker:Start()
backend.IslandAvailability=Instance.new("BindableEvent")
backend.MirageMarker=nil

function backend:_RefreshMirageESP()
    local available=Workspace:FindFirstChild("MysteriousIsland")~=nil

    if not self.Toggles.IslandESP or not available then
        if self.MirageMarker then
            self.MirageMarker:Destroy()
            self.MirageMarker=nil
        end
        return
    end

    local island=IslandData.Get("MysteriousIsland")

    if not island or not island.CFrame or self.MirageMarker then
        return
    end

    local part=Instance.new("Part")
    part.Name="DepHubMysteriousIslandMarker"
    part.Anchored=true
    part.CanCollide=false
    part.CanTouch=false
    part.CanQuery=false
    part.CastShadow=false
    part.Transparency=1
    part.Size=Vector3.new(4,4,4)
    part.CFrame=island.CFrame
    part.Parent=Workspace

    local gui=Instance.new("BillboardGui")
    gui.Name="DepHubMysteriousIslandESP"
    gui.Adornee=part
    gui.AlwaysOnTop=true
    gui.Size=UDim2.fromOffset(190,42)
    gui.StudsOffset=Vector3.new(0,5,0)
    gui.MaxDistance=10000
    gui.LightInfluence=0
    gui.Parent=part

    local label=Instance.new("TextLabel")
    label.BackgroundTransparency=1
    label.Size=UDim2.fromScale(1,1)
    label.Font=Enum.Font.GothamBold
    label.TextColor3=Color3.new(1,1,1)
    label.TextStrokeColor3=Color3.new(0,0,0)
    label.TextStrokeTransparency=0.2
    label.TextSize=13
    label.Text="MYSTERIOUS ISLAND"
    label.Parent=gui

    self.MirageMarker=part
end

backend.IslandWorkspaceConnection=Workspace.ChildAdded:Connect(function(child)
    if child.Name=="MysteriousIsland" then
        backend:_RefreshMirageESP()
        backend.IslandAvailability:Fire(backend:GetIslandNames())
    end
end)

backend.IslandWorkspaceRemovingConnection=Workspace.ChildRemoved:Connect(function(child)
    if child.Name=="MysteriousIsland" then
        backend:_RefreshMirageESP()

        if backend.Toggles.IslandTeleport and backend.Values.SelectedIsland=="MysteriousIsland" then
            backend:SetIslandTeleport(false)
        end

        backend.IslandAvailability:Fire(backend:GetIslandNames())
    end
end)

function backend:SetChestESP(enabled)
    enabled=enabled==true
    self.Toggles.ChestESP=enabled
    self.ChestESP:SetEnabled(enabled)
end

function backend:SetIslandESP(enabled)
    enabled=enabled==true
    self.Toggles.IslandESP=enabled
    self.IslandTracker:SetESPEnabled(enabled)
    self:_RefreshMirageESP()
end

function backend:SetSelectedIsland(name)
    if type(name)~="string" or name=="" then
        return false
    end

    self.Values.SelectedIsland=name

    if self.Toggles.IslandTeleport then
        self.Movement:Stop()
        task.spawn(function()
            self:TeleportIsland(name)
        end)
    end

    return true
end

function backend:ConnectIslandAvailabilityChanged(callback)
    return self.IslandAvailability.Event:Connect(callback)
end

function backend:GetIslandNames()
    local names=self.IslandTracker:GetTeleportNames()

    if Workspace:FindFirstChild("MysteriousIsland") and not table.find(names,"MysteriousIsland") then
        names[#names+1]="MysteriousIsland"
    end

    return names
end

function backend:TeleportIsland(name)
    name=name or self.Values.SelectedIsland

    if type(name)~="string" or name=="" then
        return false
    end

    if name=="MysteriousIsland" and not Workspace:FindFirstChild("MysteriousIsland") then
        return false
    end

    self.Values.SelectedIsland=name
    return self.IslandTracker:Teleport(name)
end

function backend:SetIslandTeleport(enabled)
    enabled=enabled==true
    self.Toggles.IslandTeleport=enabled

    if not enabled then
        self.Movement:Stop()
        return true
    end

    local name=self.Values.SelectedIsland

    if name=="MysteriousIsland" and not Workspace:FindFirstChild("MysteriousIsland") then
        self.Toggles.IslandTeleport=false
        return false
    end

    task.spawn(function()
        self:TeleportIsland(name)
    end)

    return true
end

function backend:SetAutoChest(enabled)
    enabled=enabled==true

    if enabled and self.Toggles.AutoFarm then
        self.Toggles.AutoFarm=false
        self.AutoFarm:SetEnabled(false)
    end

    self.Toggles.AutoChest=enabled
    self.AutoChest:SetEnabled(enabled)
end

function backend:SetAutoFarm(enabled)
    enabled=enabled==true

    if enabled and self.Toggles.AutoChest then
        self.Toggles.AutoChest=false
        self.AutoChest:SetEnabled(false)
    end

    self.Toggles.AutoFarm=enabled
    self.AutoFarm:SetEnabled(enabled)
end

function backend:SetSelectedEnemy(name)
    if self.AutoFarm:SetSelectedEnemy(name) then
        self.Values.SelectedEnemy=self.AutoFarm:GetSelectedEnemy()
        self.AutoQuest:SetSelectedEnemy(self.Values.SelectedEnemy)
        return true
    end

    return false
end

function backend:GetEnemyTypes()
    return self.AutoFarm:GetEnemyTypes()
end

function backend:GetSelectedEnemyOption()
    return self.AutoFarm:GetSelectedEnemyOption()
end

function backend:TeleportWanderingGacha()
    return self.WanderingGacha:Teleport()
end

function backend:SetGachaESP(enabled)
    enabled=enabled==true
    self.Toggles.GachaESP=enabled
    self.NpcESP:SetEnabled(enabled)
end

function backend:SetAutoQuest(enabled)
    enabled=enabled==true
    self.Toggles.AutoQuest=enabled
    self.AutoQuest:SetEnabled(enabled)
end

function backend:SetWeaponCategory(category)
    if self.AutoFarm:SetWeaponCategory(category) then
        self.Values.WeaponCategory=category
        return true
    end

    return false
end

function backend:SetSelectedTeam(name)
    if self.AutoTeam:SetSelected(name) then
        self.Values.SelectedTeam=name
        return true
    end

    return false
end

function backend:SetAutoTeam(enabled)
    enabled=enabled==true
    self.Toggles.AutoTeam=enabled
    self.AutoTeam:SetEnabled(enabled)
end

function backend:GetTeams()
    return self.AutoTeam:GetTeams()
end

function backend:SetAutoChestDelay(value)
    value=math.clamp(tonumber(value) or 0.35,0.1,2)
    self.Values.AutoChestDelay=value
    self.AutoChest:SetDelay(value)
end

function backend:SetAutoAttack(enabled)
    enabled=enabled==true
    self.Toggles.AutoAttack=enabled
    self.AutoAttack:SetEnabled(enabled)
end

function backend:GetToggle(name)
    return self.Toggles[name]
end

function backend:GetValue(name)
    return self.Values[name]
end

function backend:GetKnownIslands()
    return self.IslandTracker:GetKnownIslands()
end

function backend:Destroy()
    if self.IslandWorkspaceConnection then
        self.IslandWorkspaceConnection:Disconnect()
    end

    if self.IslandWorkspaceRemovingConnection then
        self.IslandWorkspaceRemovingConnection:Disconnect()
    end

    if self.MirageMarker then
        self.MirageMarker:Destroy()
        self.MirageMarker=nil
    end

    if self.IslandAvailability then
        self.IslandAvailability:Destroy()
    end

    self.AutoQuest:Destroy()
    self.NpcESP:Destroy()
    self.WanderingGacha:Destroy()
    self.AutoTeam:Destroy()
    self.AutoFarm:Destroy()
    self.AutoChest:Destroy()
    self.AutoAttack:Destroy()
    self.Movement:Destroy()
    self.ChestESP:Destroy()
    self.IslandTracker:Destroy()
end

env.__DEPHUB_NOOBPIECE=backend
return backend

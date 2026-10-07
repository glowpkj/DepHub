local Workspace=game:GetService("Workspace")
local env=type(getgenv)=="function" and getgenv() or _G
local previous=env.__DEPHUB_NOOBPIECE
if type(previous)=="table" and type(previous.Destroy)=="function" then previous:Destroy() end
local BASE_URL=((type(getgenv)=="function" and getgenv() or _G).__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function loadFeature(path)
    local source=game:HttpGet(BASE_URL..path)
    local chunk=assert(loadstring(source))
    return chunk()
end

local Movement=loadFeature("src/core/tween-movement.lua")
local MovementProfile=loadFeature("src/games/features/noobpiece/movementprofile.lua")
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
    Version="0.0.20",
    Destroyed=false,
    TeleportToken=0,
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

function backend:_RefreshMirageESP()
    if self.Destroyed then return end
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

function backend:SetChestESP(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true
    self.Toggles.ChestESP=enabled
    self.ChestESP:SetEnabled(enabled)
end

function backend:SetIslandESP(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true
    self.Toggles.IslandESP=enabled
    self.IslandTracker:SetESPEnabled(enabled)
    self:_RefreshMirageESP()
end

function backend:SetSelectedIsland(name)
    if self.Destroyed then return false end
    if type(name)~="string" or name=="" then
        return false
    end

    self.Values.SelectedIsland=name

    if self.Toggles.IslandTeleport then
        self.Movement:CancelOwner("IslandTeleport",true)
        self.TeleportToken+=1
        local token=self.TeleportToken
        task.spawn(function()
            if not self.Destroyed and self.Toggles.IslandTeleport and token==self.TeleportToken then self:TeleportIsland(name) end
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
    if self.Destroyed then return false end
    name=name or self.Values.SelectedIsland

    if type(name)~="string" or name=="" then
        return false
    end

    if name=="MysteriousIsland" and not Workspace:FindFirstChild("MysteriousIsland") then
        return false
    end

    self.Values.SelectedIsland=name
    return self.IslandTracker:Teleport(name,"IslandTeleport")
end

function backend:SetIslandTeleport(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true
    self.Toggles.IslandTeleport=enabled
    self.TeleportToken+=1

    if not enabled then
        self.Movement:CancelOwner("IslandTeleport",true)
        return true
    end

    local name=self.Values.SelectedIsland

    if name=="MysteriousIsland" and not Workspace:FindFirstChild("MysteriousIsland") then
        self.Toggles.IslandTeleport=false
        return false
    end

    local token=self.TeleportToken
    task.spawn(function()
        if not self.Destroyed and self.Toggles.IslandTeleport and token==self.TeleportToken then self:TeleportIsland(name) end
    end)

    return true
end

function backend:SetAutoChest(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true

    if enabled and self.Toggles.AutoFarm then
        self.Toggles.AutoFarm=false
        self.AutoFarm:SetEnabled(false)
    end

    self.Toggles.AutoChest=enabled
    self.AutoChest:SetEnabled(enabled)
end

function backend:SetAutoFarm(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true

    if enabled and self.Toggles.AutoChest then
        self.Toggles.AutoChest=false
        self.AutoChest:SetEnabled(false)
    end

    self.Toggles.AutoFarm=enabled
    self.AutoFarm:SetEnabled(enabled)
end

function backend:SetSelectedEnemy(name)
    if self.Destroyed then return false end
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
    if self.Destroyed then return false end
    return self.WanderingGacha:Teleport()
end

function backend:SetGachaESP(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true
    self.Toggles.GachaESP=enabled
    self.NpcESP:SetEnabled(enabled)
end

function backend:SetAutoQuest(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true
    self.Toggles.AutoQuest=enabled
    self.AutoQuest:SetEnabled(enabled)
end

function backend:SetWeaponCategory(category)
    if self.Destroyed then return false end
    if self.AutoFarm:SetWeaponCategory(category) then
        self.Values.WeaponCategory=category
        return true
    end

    return false
end

function backend:SetSelectedTeam(name)
    if self.Destroyed then return false end
    if self.AutoTeam:SetSelected(name) then
        self.Values.SelectedTeam=name
        return true
    end

    return false
end

function backend:SetAutoTeam(enabled)
    if self.Destroyed then return false end
    enabled=enabled==true
    self.Toggles.AutoTeam=enabled
    self.AutoTeam:SetEnabled(enabled)
end

function backend:GetTeams()
    return self.AutoTeam:GetTeams()
end

function backend:SetAutoChestDelay(value)
    if self.Destroyed then return false end
    value=math.clamp(tonumber(value) or 0.35,0.1,2)
    self.Values.AutoChestDelay=value
    self.AutoChest:SetDelay(value)
end

function backend:SetAutoAttack(enabled)
    if self.Destroyed then return false end
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
    if self.Destroyed then return end
    self.Destroyed=true
    self.TeleportToken+=1
    for _,name in ipairs({"IslandWorkspaceConnection","IslandWorkspaceRemovingConnection"}) do
        local connection=self[name]
        self[name]=nil
        if connection then connection:Disconnect() end
    end
    for _,name in ipairs({"MirageMarker","IslandAvailability","AutoQuest","NpcESP","WanderingGacha","AutoTeam","AutoFarm","AutoChest","AutoAttack","IslandTracker","ChestESP","Movement"}) do
        local resource=self[name]
        if resource and type(resource.Destroy)=="function" then
            local ok,reason=pcall(resource.Destroy,resource)
            if not ok then warn("[DepHub Noob Piece] cleanup "..name..": "..tostring(reason)) end
        elseif typeof(resource)=="Instance" then
            resource:Destroy()
        end
        self[name]=nil
    end
    if env.__DEPHUB_NOOBPIECE==self then env.__DEPHUB_NOOBPIECE=nil end
    if env.__DEPHUB and env.__DEPHUB.NoobPiece==self then env.__DEPHUB.NoobPiece=nil end
end

local ok,reason=pcall(function()
    backend.Movement=Movement.new(MovementProfile)

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

end)
if not ok then
    backend:Destroy()
    error("Noob Piece initialization failed: "..tostring(reason))
end
env.__DEPHUB_NOOBPIECE=backend
return backend

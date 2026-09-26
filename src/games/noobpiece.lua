local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function loadFeature(path)
    local source=game:HttpGet(BASE_URL..path)
    local chunk=assert(loadstring(source))
    return chunk()
end

local Movement=loadFeature("src/core/tween-movement.lua")
local ChestESP=loadFeature("src/games/features/noobpiece/chestesp.lua")
local IslandTracker=loadFeature("src/games/features/noobpiece/islandtracker.lua")
local AutoChest=loadFeature("src/games/features/noobpiece/autochest.lua")
local AutoAttack=loadFeature("src/games/features/noobpiece/autoattack.lua")
local AutoFarm=loadFeature("src/games/features/noobpiece/autofarm.lua")

local backend={
    Version="0.0.6",
    Toggles={
        ChestESP=false,
        AutoChest=false,
        AutoAttack=false,
        AutoAttackRange=true,
        AutoFarm=false
    },
    Values={
        AutoChestDelay=0.35,
        WeaponCategory="Fists"
    }
}

backend.Movement=Movement.new({
    Speed=45,
    MinDuration=0.05,
    UsePhysics=true
})

backend.ChestESP=ChestESP.new()
backend.IslandTracker=IslandTracker.new()
backend.AutoChest=AutoChest.new(backend.Movement)
backend.AutoAttack=AutoAttack.new()
backend.AutoFarm=AutoFarm.new(backend.Movement,backend.AutoAttack)

backend.AutoChest:SetDelay(backend.Values.AutoChestDelay)
backend.AutoAttack:SetRangeCheck(backend.Toggles.AutoAttackRange)
backend.AutoAttack:SetWeaponCategory(backend.Values.WeaponCategory)
backend.IslandTracker:Start()

function backend:SetChestESP(enabled)
    enabled=enabled==true
    self.Toggles.ChestESP=enabled
    self.ChestESP:SetEnabled(enabled)
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

function backend:SetWeaponCategory(category)
    if self.AutoAttack:SetWeaponCategory(category) then
        self.Values.WeaponCategory=category
        return true
    end
    return false
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

function backend:SetAutoAttackRange(enabled)
    enabled=enabled==true
    self.Toggles.AutoAttackRange=enabled
    self.AutoAttack:SetRangeCheck(enabled)
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
    self.AutoFarm:Destroy()
    self.AutoChest:Destroy()
    self.AutoAttack:Destroy()
    self.Movement:Destroy()
    self.ChestESP:Destroy()
    self.IslandTracker:Destroy()
end

env.__DEPHUB_NOOBPIECE=backend
return backend

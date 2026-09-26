local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function loadFeature(path)
    local source=game:HttpGet(BASE_URL..path)
    local chunk=assert(loadstring(source))
    return chunk()
end

local ChestESP=loadFeature("src/games/features/noobpiece/chestesp.lua")
local IslandTracker=loadFeature("src/games/features/noobpiece/islandtracker.lua")
local AutoChest=loadFeature("src/games/features/noobpiece/autochest.lua")

local backend={
    Version="0.0.3",
    Toggles={ChestESP=false,AutoChest=false},
    Values={AutoChestDelay=0.35}
}

backend.ChestESP=ChestESP.new()
backend.IslandTracker=IslandTracker.new()
backend.AutoChest=AutoChest.new()
backend.AutoChest:SetDelay(backend.Values.AutoChestDelay)
backend.IslandTracker:Start()

function backend:SetChestESP(enabled)
    enabled=enabled==true
    self.Toggles.ChestESP=enabled
    self.ChestESP:SetEnabled(enabled)
end

function backend:SetAutoChest(enabled)
    enabled=enabled==true
    self.Toggles.AutoChest=enabled
    self.AutoChest:SetEnabled(enabled)
end

function backend:SetAutoChestDelay(value)
    value=math.clamp(tonumber(value) or 0.35,0.1,2)
    self.Values.AutoChestDelay=value
    self.AutoChest:SetDelay(value)
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
    self.AutoChest:Destroy()
    self.ChestESP:Destroy()
    self.IslandTracker:Destroy()
end

env.__DEPHUB_NOOBPIECE=backend
return backend

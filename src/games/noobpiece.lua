local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function loadFeature(path)
    local source=game:HttpGet(BASE_URL..path)
    local chunk=assert(loadstring(source))
    return chunk()
end

local ChestESP=loadFeature("src/games/features/noobpiece/chestesp.lua")
local IslandTracker=loadFeature("src/games/features/noobpiece/islandtracker.lua")

local backend={Version="0.0.2",Toggles={ChestESP=false}}
backend.ChestESP=ChestESP.new()
backend.IslandTracker=IslandTracker.new()
backend.IslandTracker:Start()

function backend:SetChestESP(enabled)
    enabled=enabled==true
    self.Toggles.ChestESP=enabled
    self.ChestESP:SetEnabled(enabled)
end

function backend:GetToggle(name)
    return self.Toggles[name]
end

function backend:GetKnownIslands()
    return self.IslandTracker:GetKnownIslands()
end

function backend:Destroy()
    self.ChestESP:Destroy()
    self.IslandTracker:Destroy()
end

env.__DEPHUB_NOOBPIECE=backend
return backend

local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local function loadFeature(path)
    local source=game:HttpGet(BASE_URL..path)
    local chunk=assert(loadstring(source))
    return chunk()
end

local ChestESP=loadFeature("src/games/features/noobpiece/chestesp.lua")
local backend={Version="0.0.1",Toggles={ChestESP=false}}
backend.ChestESP=ChestESP.new()

function backend:SetChestESP(enabled)
    enabled=enabled==true
    self.Toggles.ChestESP=enabled
    self.ChestESP:SetEnabled(enabled)
end

function backend:GetToggle(name)
    return self.Toggles[name]
end

function backend:Destroy()
    self.ChestESP:Destroy()
end

env.__DEPHUB_NOOBPIECE=backend
return backend

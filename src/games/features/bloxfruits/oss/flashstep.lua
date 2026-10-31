local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Flashstep: keep the player's Flashstep cooldown at zero so the move is always
-- ready. The game stores the cooldown as a character attribute; setting it to 0
-- and re-applying whenever the game writes it back (AttributeChanged) keeps it
-- clear. It re-binds on respawn so the effect follows a new character.

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local M = {}
M._on = false
M._character = nil

function M._disconnect()
    if M._connections then
        for _, c in ipairs(M._connections) do pcall(function() c:Disconnect() end) end
    end
    M._connections = {}
    M._character = nil
end

local function apply(character)
    if not M._on or not character or not character.Parent then return end
    pcall(function()
        if character:GetAttribute("FlashstepCooldown") ~= 0 then
            character:SetAttribute("FlashstepCooldown", 0)
        end
    end)
end

function M._bind(character)
    M._disconnect()
    M._character = character
    if not character then return end
    M._connections = M._connections or {}
    apply(character)
    M._connections[#M._connections + 1] = character:GetAttributeChangedSignal("FlashstepCooldown"):Connect(function()
        apply(character)
    end)
end

function M.set(on)
    M._on = on and true or false
    if M._on then
        M._bind(LP.Character)
        if not M._respawn then
            M._respawn = LP.CharacterAdded:Connect(function(character)
                if M._on then M._bind(character) end
            end)
        end
    else
        M._disconnect()
        if M._respawn then pcall(M._respawn.Disconnect, M._respawn); M._respawn = nil end
    end
end

function M.stop()
    M._on = false
    M._disconnect()
    if M._respawn then pcall(M._respawn.Disconnect, M._respawn); M._respawn = nil end
end

function M.init(Core, UI)
    M._core = Core
    local page = UI.page("Player")
    UI.section(page, "MOVEMENT")
    UI.toggle(page, "Flashstep (no cooldown)", "Keep Flashstep always ready", false, function(s) M.set(s) end)

    Core.register("flashstep", M)
    return M
end

return M

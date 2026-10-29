-- Visual profile selection for the DepHub frontend.
--
-- This module is deliberately free of Roblox APIs so the mode/profile decision
-- can be unit-tested outside the game client. The loader asks it which visual
-- mode a backend belongs to, and the Demon UI wrapper asks it which categories
-- that mode is allowed to register. Because both sides read the same table, a
-- game can never register another game's categories by accident.

local Profile = {}

-- Mode -> category profile. Blox Fruits is the only mode with sea categories.
-- Every other mode falls back to the single "General" category, so MM2, AOT:R,
-- Noob Piece, RT3, TSB, Volleyball and Universal can never show sea tabs.
Profile.CATEGORIES = {
    BloxFruits = { "General", "Sea 1", "Sea 2", "Sea 3", "Sea 1/2", "Sea 2/3" }
}

Profile.DEFAULT_CATEGORIES = { "General" }

local function basename(path)
    return tostring(path or ""):match("([^/]+)$") or ""
end

-- Resolve the visual mode from the loader's target table. The loader already
-- knows the exact file it is about to load, so the mapping is explicit rather
-- than inferred from a tab name or control value.
function Profile.modeForTarget(target)
    if type(target) ~= "table" then
        return "Universal"
    end
    if target.Universal then
        return "Universal"
    end
    local name = basename(target.Core)
    if name == "bloxfruits.lua" then return "BloxFruits" end
    if name == "mm2.lua" then return "MM2" end
    if name == "aotr.lua" then return "AOTR" end
    if name == "noobpiece.lua" then return "NoobPiece" end
    if name == "rt3.lua" then return "RT3" end
    if name == "tsb.lua" then return "TSB" end
    if name == "volleyball42.lua" then return "Volleyball42" end
    if name == "universal.lua" then return "Universal" end
    return "Universal"
end

function Profile.categoriesFor(mode)
    local categories = Profile.CATEGORIES[mode]
    if categories then
        return categories
    end
    return Profile.DEFAULT_CATEGORIES
end

return Profile

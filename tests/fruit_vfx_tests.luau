do
    local Factory = modules.fruitvfx
    local function equalAttributes(object, expected)
        local actual = object:GetAttributes()
        for key, value in pairs(expected) do if actual[key] ~= value then return false end end
        for key, value in pairs(actual) do if expected[key] ~= value then return false end end
        return true
    end
    local function data()
        local root = Instance.new("Folder"); root.Name, root.Parent = "LightningFruitVFXColor", player
        local normal = Instance.new("Folder"); normal.Name, normal.Parent = "Default", root
        local shifted = Instance.new("Folder"); shifted.Name, shifted.Parent = "Shifted", root
        -- Deliberately different from the screenshot: an already equipped skin.
        for index = 1, 3 do normal:SetAttribute("Default_Color" .. index, Color3.fromRGB(11*index,22*index,33*index)) end
        normal:SetAttribute("SkinName", "Existing skin")
        shifted:SetAttribute("Shifted_Color1", Color3.fromRGB(6,7,8))
        shifted:SetAttribute("NotAColor", 42)
        normal.WriteCount, shifted.WriteCount = 0, 0
        return root, normal, shifted
    end

    local feature = Factory.new({LocalPlayer = player})
    check(#feature:GetFruits() == 1 and feature:GetFruits()[1] == "Rumble", "VFX registry exposes only supported Rumble")
    check(#feature:GetColors("Rumble") == 11 and #feature:GetColors("Unknown") == 0, "VFX palettes are fruit-specific with original option")
    check(not feature:Apply("Rumble", "Purple", "Default"), "missing fruit data returns an error without blocking initialization")
    local root, normal, shifted = data()
    local defaultOriginal, shiftedOriginal = normal:GetAttributes(), shifted:GetAttributes()
    normal.FailRead = true
    check(not feature:Apply("Rumble", "Purple", "Default") and normal.WriteCount == 0, "failed attribute read aborts before any mutation")
    normal.FailRead = false
    check(not feature:Apply("Rumble", "Invalid", "Default") and normal.WriteCount == 0, "invalid palette is rejected without writes")
    check(not feature:Apply("Unknown", "Purple", "Default"), "invalid fruit rejected")
    check(not feature:Apply("Rumble", "Purple", "Unknown"), "invalid form rejected")
    check(feature:Apply("Rumble", "Purple", "Default"), "apply Rumble palette to normal form")
    check(normal:GetAttribute("Default_Color1") == Color3.fromRGB(140,0,255), "user-provided Purple palette values preserved")
    check(normal.WriteCount == 3 and shifted.WriteCount == 0, "normal mode changes only existing Default slots")
    check(normal:GetAttribute("Default_Color4") == nil and normal:GetAttribute("SkinName") == "Existing skin", "Default count and unrelated attributes stay intact")
    local writes = normal.WriteCount
    check(feature:Apply("Rumble", "Purple", "Default") and normal.WriteCount == writes, "repeated same palette performs zero redundant writes")
    check(feature:Apply("Rumble", "Red", "Default") and feature:Restore("Rumble", "Default"), "switching palettes retains the first original snapshot")
    check(equalAttributes(normal, defaultOriginal), "restores actual equipped Default skin rather than hardcoded cyan")
    check(feature:Apply("Rumble", "Blue", "Shifted"), "apply seven slots to Shifted form")
    check(shifted:GetAttribute("Shifted_Color7") == Color3.fromRGB(20,90,220), "all seven supplied Shifted colors applied")
    check(feature:Restore("Rumble", "Shifted") and equalAttributes(shifted, shiftedOriginal), "restore removes slots that did not exist and restores preexisting slots")
    check(feature:Apply("Rumble", "Pink", "Both"), "both forms apply together")
    normal:SetAttribute("AddedByGame", true)
    check(feature:Restore("Rumble", "Both") and normal:GetAttribute("AddedByGame") == true, "restore preserves unrelated attributes added after snapshot")
    normal:SetAttribute("AddedByGame", nil)
    check(equalAttributes(normal, defaultOriginal) and equalAttributes(shifted, shiftedOriginal), "both forms restore exactly")

    shifted.FailKey = "Shifted_Color3"
    check(not feature:Apply("Rumble", "Orange", "Both"), "mid-transaction failure reports failure")
    check(equalAttributes(normal, defaultOriginal) and equalAttributes(shifted, shiftedOriginal), "failed apply rolls back writes across both folders")
    check(feature:Apply("Rumble", "Green", "Both"), "feature remains usable after failed transaction")
    local greenDefault, greenShifted = normal:GetAttributes(), shifted:GetAttributes()
    normal.FailKey = "Default_Color2"
    check(not feature:Restore("Rumble", "Both"), "restore failure is reported")
    check(equalAttributes(normal, greenDefault) and equalAttributes(shifted, greenShifted), "failed restore rolls back instead of leaving mixed palettes")
    check(feature:Restore("Rumble", "Both"), "restore can be retried successfully")
    check(equalAttributes(normal, defaultOriginal) and equalAttributes(shifted, shiftedOriginal), "retry restores complete original skin")

    check(feature:Apply("Rumble", "Red", "Default"), "apply before an external skin change")
    local external = Color3.fromRGB(9,8,7)
    normal:SetAttribute("Default_Color1", external)
    check(not feature:Apply("Rumble", "Blue", "Default"), "external changes stop repeated application instead of fighting game state")
    local ok, message, kind = feature:Restore("Rumble", "Default")
    check(ok and kind == "Warning" and normal:GetAttribute("Default_Color1") == external, "restore preserves external updates and reports partial ownership")
    check(feature:Apply("Rumble", "White", "Default") and feature:Restore("Rumble", "Default"), "next edit captures the updated skin afresh")
    check(normal:GetAttribute("Default_Color1") == external, "new skin is not overwritten with a stale snapshot")

    normal:SetAttribute("Default_Color4", Color3.fromRGB(3,4,5))
    local dynamicOriginal = normal:GetAttributes()
    check(feature:Apply("Rumble", "Yellow", "Default") and normal:GetAttribute("Default_Color4") == Color3.fromRGB(255,250,150), "Default slot count is discovered dynamically")
    check(feature:Restore("Rumble", "Default") and equalAttributes(normal, dynamicOriginal), "additional original color slots restore exactly")
    normal:SetAttribute("Default_Color9", Color3.fromRGB(1,2,3))
    writes = normal.WriteCount
    check(not feature:Apply("Rumble", "Yellow", "Default") and normal.WriteCount == writes, "unknown palette schema is rejected without guessing values")
    normal:SetAttribute("Default_Color9", nil)
    shifted:SetAttribute("Shifted_Color5", "Wrong type")
    writes = normal.WriteCount
    check(not feature:Apply("Rumble", "Purple", "Both") and normal.WriteCount == writes, "type errors on either form prevent all writes")
    shifted:SetAttribute("Shifted_Color5", nil)
    shifted.Parent = nil
    check(not feature:Apply("Rumble", "Purple", "Both") and normal.WriteCount == writes, "missing Shifted prevents partial both-form application")
    shifted.Parent = root
    check(feature:Apply("Rumble", "Black", "Both"), "last test palette before destroying data")
    root:Destroy()
    root, normal, shifted = data()
    normal:SetAttribute("Default_Color1", Color3.fromRGB(91,92,93))
    local replacementOriginal = normal:GetAttributes()
    check(feature:Apply("Rumble", "Cyan", "Default") and feature:Restore("Rumble", "Default"), "replaced instances use a fresh snapshot")
    check(equalAttributes(normal, replacementOriginal), "old instance snapshots never overwrite replacement instances")
    check(feature:Apply("Rumble", "Orange", "Both") and feature:Destroy(), "destroy restores owned edits")
    check(equalAttributes(normal, replacementOriginal), "destroy restores normal skin")
    check(not feature:Apply("Rumble", "Red", "Default"), "destroyed feature rejects new edits")
    root:Destroy()

    feature = Factory.new({LocalPlayer=player})
    root, normal, shifted = data()
    for index=1,3 do normal:SetAttribute("Default_Color" .. index, nil) end
    writes = normal.WriteCount
    check(not feature:Apply("Rumble", "Purple", "Default") and normal.WriteCount == writes, "empty Default has no fabricated original colors")
    feature:Destroy(); root:Destroy()

end

local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Events: raid automation + sea events (Sea 2 / Sea 3).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TPS = game:GetService("TeleportService")
local LP = Players.LocalPlayer

local M = {}
M.config = {
    element = "Flame",
    waveWait = 0.35,     -- seconds between attack passes while clearing a wave
    startWait = 2.5,     -- seconds to wait after pressing the raid start button
    chipWait = 1.5,      -- seconds to wait when the microchip is missing
}
M._raidOn, M._inRaid, M._clearing = false, false, false
M.raidLoc = {
    Sea2 = { tube = Vector3.new(-6546.1, 310.5, -4767.7), button = Vector3.new(-6530.7, 304.8, -4798.4) },
    Sea3 = { tube = Vector3.new(-5010.1, 315.0, -2816.5), button = Vector3.new(-5010.1, 315.0, -2816.5) },
}
function M.currentRaidLoc()
    local info = M._core and M._core.modules.info
    return M.raidLoc[(info and info.sea) or "Sea2"] or M.raidLoc.Sea2
end
M.elements = {
    "Flame", "Ice", "Quake", "Dark", "Light", "Sand", "Magma", "Rumble", "Buddha", "Paw",
    "Gravity", "Dough", "Shadow", "Venom", "Control", "Spirit", "Bomb", "Spike", "Blizzard", "Phoenix",
}

function M._status(_) end
local fireprompt = fireproximityprompt or function() end
local fireclick = fireclickdetector or function() end
local firetouch = firetouchinterest or function() end
local function commF() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("CommF_") end
local function spiritTree() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("SpiritTree") end
local function raidsEvent() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("Raids") end
local function hintRF()
    local mods = RS:FindFirstChild("Modules"); local n = mods and mods:FindFirstChild("Net")
    return n and n:FindFirstChild("RF/RequestNextRaidHint")
end
local function hrp() local ch = LP.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end

function M.raidHint()
    local rf = hintRF(); if not rf then return end
    local ok, res = pcall(function() return rf:InvokeServer() end)
    return ok and type(res) == "table" and res or nil
end
local function isChip(t)
    return t:IsA("Tool") and (t.Name:find("Microchip") or tostring(t:GetAttribute("OriginalName") or ""):find("Microchip"))
end
local function chipTool()
    for _, pool in ipairs({ LP.Character, LP:FindFirstChild("Backpack") }) do
        if pool then for _, t in ipairs(pool:GetChildren()) do if isChip(t) then return t end end end
    end
end
local function chipEquipped()
    local ch = LP.Character
    if ch then for _, t in ipairs(ch:GetChildren()) do if isChip(t) then return true end end end
    return false
end
local function equipChip()
    if chipEquipped() then return true end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local chip = chipTool()
    if not (hum and chip) then return false end
    for _ = 1, 4 do
        pcall(function() hum:EquipTool(chip) end)
        if not chipEquipped() then pcall(function() chip.Parent = ch end) end
        task.wait(0.15)
        if chipEquipped() then return true end
    end
    return chipEquipped()
end
local function firePromptsNear(pos, radius)
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local part = d.Parent
            local pp = part and part:IsA("BasePart") and part.Position
            if pp and (pp - pos).Magnitude <= (radius or 30) then pcall(fireprompt, d); n = n + 1 end
        end
    end
    return n
end
local function triggerAround(pos, radius)
    radius = radius or 30
    local h = hrp()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        local ok = false
        if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("TouchTransmitter") then
            local part = d:FindFirstAncestorWhichIsA("BasePart") or (d.Parent and d.Parent:IsA("BasePart") and d.Parent)
            if part and (part.Position - pos).Magnitude <= radius then ok = true
                if d:IsA("ProximityPrompt") then pcall(fireprompt, d)
                elseif d:IsA("ClickDetector") then pcall(fireclick, d)
                elseif d:IsA("TouchTransmitter") and h then
                    pcall(firetouch, part, h, 0); task.wait(0.05); pcall(firetouch, part, h, 1)
                end
                n = n + 1
            end
        end
    end
    return n
end
function M.raidCheck()
    local c = commF(); if not c then return end
    local ok, v = pcall(function() return c:InvokeServer("RaidsNpc", "Check") end)
    if M._core then M._core.info("RaidsNpc Check", "ok=" .. tostring(ok), tostring(v)) end
    return ok and v
end
function M.buyChip()
    local c = commF(); if not c then return end
    local ok, v = pcall(function() return c:InvokeServer("RaidsNpc", "Select", M.config.element) end)
    if M._core then M._core.info("RaidsNpc Select", M.config.element, "ok=" .. tostring(ok), tostring(v)) end
    return v
end

local function setClearing(on)
    if M._clearing == on then return end
    M._clearing = on
    local combat = M._core and M._core.modules.combat
    local farm = M._core and M._core.modules.farm
    if combat then combat.setAura(on) end
    if farm then farm.setNearestFarm(on) end
end

function M.setAutoRaid(on)
    M._raidOn = on and true or false
    if not M._raidOn then
        M._raidClearInit = false
        local combat = M._core and M._core.modules.combat
        if combat then combat.setAura(false) end
        setClearing(false); return
    end
    if not M._core then return end
    M._core.spawn(function()
        local tp = M._core.modules.teleport
        local function pause(key, fallback)
            task.wait(math.max(0, tonumber(M.config[key]) or fallback))
        end
        while M._raidOn do
            if M._inRaid then
                setClearing(false)
                local combat = M._core.modules.combat
                if not M._raidClearInit then
                    M._raidClearInit = true
                    if combat and combat.setupHitId then combat.setupHitId() end
                    if combat then combat.setAura(true) end
                end
                local target = combat and combat.nearestAny(1e9)
                if target and combat then
                    local part = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                    local h = hrp()
                    if part and h and (part.Position - h.Position).Magnitude > 60 and tp then
                        tp.go(part.Position + Vector3.new(0, 12, 0))
                    end
                    combat.attackOnce(target)
                    M._status("Raid: clearing")
                else
                    M._status("Raid: waiting for next wave")
                end
                pause("waveWait", 0.35)
            else
                setClearing(false)
                if not chipTool() then M.buyChip(); task.wait(0.8) end
                local eq = equipChip()
                if not eq then
                    M._status("Raid: no Microchip — buy/hold one")
                    if M._core then M._core.warn("auto raid: chip not equipped (found=" .. tostring(chipTool() ~= nil) .. ")") end
                    pause("chipWait", 1.5)
                else
                    local loc = M.currentRaidLoc()
                    if tp then tp.go(loc.tube + Vector3.new(0, 3, 0)) end
                    task.wait(1.6)
                    equipChip()
                    local n = triggerAround(loc.button, 60)
                    M._status(("Raid: pressing button... chip=%s fired=%d"):format(tostring(chipEquipped()), n))
                    if M._core then M._core.info("auto raid", "tube button", "chip=" .. tostring(chipEquipped()), "n=" .. n) end
                    pause("startWait", 2.5)
                end
            end
        end
    end)
    if M._core then M._core.info("auto raid", "ON " .. M.config.element) end
end

function M.teleportEvent()
    local st = spiritTree()
    if not st then if M._ui then M._ui.notify("Event remote missing") end return end
    local ok = pcall(function() return st:InvokeServer("TeleportToEvent") end)
    if M._ui then M._ui.notify(ok and "Teleporting to event..." or "No active event") end
end
function M.eliteHunter()
    local c = commF(); if not c then return end
    local ok, v = pcall(function() return c:InvokeServer("EliteHunter") end)
    if M._core then M._core.info("EliteHunter", "ok=" .. tostring(ok), tostring(v)) end
    if M._ui then M._ui.notify(ok and "Elite Hunter claimed" or "Elite Hunter error") end
end
function M.eliteProgress()
    local c = commF(); if not c then return end
    local ok, v = pcall(function() return c:InvokeServer("EliteHunter", "Progress") end)
    if M._ui then M._ui.notify(ok and ("Elite progress: " .. tostring(v)) or "Elite Hunter error") end
end
function M.leviathanGate()
    local c = commF(); if not c then return end
    local ok, v = pcall(function() return c:InvokeServer("OpenLeviathanGate") end)
    if M._core then M._core.info("OpenLeviathanGate", "ok=" .. tostring(ok), tostring(v)) end
    if M._ui then M._ui.notify(ok and v and "Leviathan gate opened" or "Leviathan unavailable") end
end
function M.serverHop()
    if M._ui then M._ui.notify("Server hopping...") end
    pcall(function() TPS:Teleport(game.PlaceId, LP) end)
end
function M.pullLevers()
    local h = hrp(); if not h then return end
    local n = firePromptsNear(h.Position, 60)
    if M._ui then M._ui.notify(n .. " prompt(s) fired nearby") end
end

function M.stop()
    M._raidOn, M._raidClearInit = false, false
    local combat = M._core and M._core.modules.combat
    if combat then combat.setAura(false) end
    setClearing(false)
end

function M.init(Core, UI)
    M._core, M._ui = Core, UI

    local ev = raidsEvent()
    if ev then
        Core.track(ev.OnClientEvent:Connect(function(kind)
            if kind == "StartTimer" then M._inRaid = true; M._raidClearInit = false; Core.info("raid started")
            elseif kind == "Finished" then
                M._inRaid, M._raidClearInit = false, false
                local combat = M._core and M._core.modules.combat
                if combat then combat.setAura(false) end
                setClearing(false); Core.info("raid finished")
            end
        end))
    end

    local page = UI.page("Raids/Events")
    if not page then return M end

    UI.section(page, "AUTO RAID")
    UI.dropdown(page, "Raid element", "Microchip element (your fruit to awaken)", M.elements, function(s) M.config.element = s end)
    UI.toggle(page, "Auto Raid", "Buy chip, start the raid, then clear all waves", false, function(s) M.setAutoRaid(s) end)
    -- These three paced the raid loop with hardcoded waits; they are the only
    -- knobs that actually change how the loop behaves, so they get controls.
    UI.slider(page, "Wave wait", "Seconds between attack passes while clearing", 0.1, 3, M.config.waveWait, function(v) M.config.waveWait = v end)
    UI.slider(page, "Start wait", "Seconds to wait after pressing the raid button", 0.5, 10, M.config.startWait, function(v) M.config.startWait = v end)
    UI.slider(page, "Chip wait", "Seconds to wait when the microchip is missing", 0.5, 10, M.config.chipWait, function(v) M.config.chipWait = v end)
    UI.button(page, "Check raid status", "Query the raid NPC", function() local v = M.raidCheck(); if M._ui then M._ui.notify("Raid check: " .. tostring(v)) end end)
    -- raidHint() queries the RequestNextRaidHint RemoteFunction; it was implemented
    -- but never exposed, so the next-raid hint was unreachable.
    UI.button(page, "Next raid hint", "Ask the server for the next raid's hint", function()
        local hint = M.raidHint()
        if not hint then if M._ui then M._ui.notify("No hint available") end return end
        local label = hint.Element or hint.element or hint.Next or tostring(hint)
        if M._ui then M._ui.notify("Next raid: " .. tostring(label)) end
        if M._core then M._core.info("raid hint", label) end
    end)
    local statFrame = UI.section(page, "Raid: idle")
    M._statusLbl = statFrame and statFrame:FindFirstChildWhichIsA("TextLabel")
    function M._status(t) if M._statusLbl then M._statusLbl.Text = t end end

    UI.section(page, "SEA EVENTS")
    UI.button(page, "Teleport to event", "Go to the active sea event", function() M.teleportEvent() end)
    UI.button(page, "Pull nearby levers / prompts", "Fire ProximityPrompts within 60 studs", function() M.pullLevers() end)
    UI.button(page, "Server hop", "Rejoin the game (find another server)", function() M.serverHop() end)
    if UI._controls["Raids/Events / Server hop"] then UI._controls["Raids/Events / Server hop"].sea = "All" end

    UI.section(page, "ELITE HUNTER")
    UI.button(page, "Claim Elite Hunter", "Trigger the elite hunter reward/quest", function() M.eliteHunter() end)
    if UI._controls["Raids/Events / Claim Elite Hunter"] then UI._controls["Raids/Events / Claim Elite Hunter"].sea = "Sea3" end
    UI.button(page, "Elite progress", "Show elite hunter progress", function() M.eliteProgress() end)
    if UI._controls["Raids/Events / Elite progress"] then UI._controls["Raids/Events / Elite progress"].sea = "Sea3" end

    UI.section(page, "LEVIATHAN")
    UI.button(page, "Open Leviathan gate", "Open the leviathan gate (if active)", function() M.leviathanGate() end)
    if UI._controls["Raids/Events / Open Leviathan gate"] then UI._controls["Raids/Events / Open Leviathan gate"].sea = "Sea3" end

    Core.register("events", M)
    return M
end

return M

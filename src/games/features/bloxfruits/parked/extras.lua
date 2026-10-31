local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Extras: Sea 3 misc (Race V4, Cake Prince, Rip Indra).
local RS = game:GetService("ReplicatedStorage")

local M = {}
M.config = { spawnWait = 0.5 }   -- seconds to wait after summoning before selecting the boss
local function commF() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("CommF_") end
local function call(action, ...)
    local c = commF(); if not c then return end
    local args = table.pack(...)
    local ok, res = pcall(function() return c:InvokeServer(action, table.unpack(args, 1, args.n)) end)
    if M._core then M._core.info("Extras", action, "ok=" .. tostring(ok), tostring(res)) end
    return ok, res
end

local function farmBoss(name)
    local farm = M._core and M._core.modules.farm
    if not farm then return false end
    for _, list in ipairs({ farm.bosses3 or {}, farm.bosses2 or {}, farm.bosses or {} }) do
        for _, b in ipairs(list) do
            if b.name == name then farm.selectedBoss = b; farm.setBossFarm(true); return true end
        end
    end
    return false
end

function M.init(Core, UI)
    M._core, M._ui = Core, UI
    local page = UI.page("Extras")
    if not page then return M end

    UI.section(page, "RACE V4")
    UI.button(page, "Check V4 progress", "Show your Race V4 progress", function()
        local ok, v = call("RaceV4Progress", "Check")
        UI.notify(ok and ("V4 progress: " .. tostring(v)) or "Race remote error")
    end)
    UI.button(page, "V4 trial teleport", "Teleport to your Race V4 trial", function() call("RaceV4Progress", "Teleport") end)
    UI.button(page, "Upgrade / Awaken race", "Buy the next race upgrade (V2/V3)", function()
        call("UpgradeRace", "Buy", 2); UI.notify("Race upgrade requested")
    end)
    UI.button(page, "Reroll race", "Reroll your race (needs a reroll item)", function()
        call("RerollRace"); UI.notify("Race reroll requested")
    end)

    UI.section(page, "SPECIAL BOSSES")
    UI.button(page, "Spawn Cake Prince", "Summon the Cake Prince boss", function()
        local ok = call("CakePrinceSpawner", true)
        UI.notify(ok and "Cake Prince summoned" or "Cake Prince error")
    end)
    local cakeToggle
    cakeToggle = UI.toggle(page, "Auto Cake Prince", "Summon Cake Prince then farm it", false, function(s)
        if s then
            call("CakePrinceSpawner", true)
            task.wait(math.max(0, tonumber(M.config.spawnWait) or 0.5))
            if not farmBoss("Cake Prince") then
                -- No boss to farm: say so and drop the switch instead of leaving
                -- it on while doing nothing.
                UI.notify("Cake Prince not in boss list")
                if cakeToggle then cakeToggle.Set(false) end
            end
        else
            local farm = Core.modules.farm; if farm then farm.setBossFarm(false) end
        end
    end)
    UI.button(page, "Talk to Indra", "Trigger rip_indra (raid boss)", function()
        call("IndraTalk"); UI.notify("Indra triggered")
    end)
    local indraToggle
    indraToggle = UI.toggle(page, "Auto Rip Indra", "Talk to Indra then farm rip_indra", false, function(s)
        if s then
            call("IndraTalk")
            task.wait(math.max(0, tonumber(M.config.spawnWait) or 0.5))
            if not farmBoss("rip_indra") then
                UI.notify("rip_indra not in boss list")
                if indraToggle then indraToggle.Set(false) end
            end
        else
            local farm = Core.modules.farm; if farm then farm.setBossFarm(false) end
        end
    end)
    UI.slider(page, "Summon wait", "Seconds to wait after summoning before farming", 0, 10, M.config.spawnWait, function(v) M.config.spawnWait = v end)

    Core.register("extras", M)
    return M
end

return M

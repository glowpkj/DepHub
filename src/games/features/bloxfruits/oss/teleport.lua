local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Teleport: CFrame-tween fly, island/boss lists per sea, waypoints, auto sea travel.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local M = {}
M.config = { speed = 200 }   -- studs/s; 200 suits the huge Sea 3 map. Drop to ~100 if anti-cheat kicks/loopbacks.
M._tween = nil
M.waypoints = {}

M.islands = {
    { name = "Middle Town",        pos = Vector3.new(-1193.9, 12, -549.8) },
    { name = "Pirate Starter",     pos = Vector3.new(1038, 15, 1550) },
    { name = "Marine Starter",     pos = Vector3.new(-2674.5, 32.1, 2187.0) },
    { name = "Jungle",             pos = Vector3.new(-1866.3, 29.9, 21.6) },
    { name = "Buggy Island",       pos = Vector3.new(-981.0, 30.4, 3966.8) },
    { name = "Desert Island",      pos = Vector3.new(999.9, 7.6, 4490.3) },
    { name = "Snow Island",        pos = Vector3.new(1519.5, 78.0, -1510.9) },
    { name = "Marineford",         pos = Vector3.new(-4763.7, 13.4, 4288.8) },
    { name = "Sky Islands",        pos = Vector3.new(-4973.7, 280.7, -1119.4) },
    { name = "Mob Island (Saber)", pos = Vector3.new(-1527.2, 34.1, -33.2) },
    { name = "Impel Down",         pos = Vector3.new(5278.6, 7.1, 391.6) },
    { name = "Colosseum",          pos = Vector3.new(-1973.1, 9.0, -2744.9) },
    { name = "Volcano",            pos = Vector3.new(-5623.8, 17.0, 8314.1) },
    { name = "Fishman Island",     pos = Vector3.new(3894.3, 4.0, -1915.2) },
    { name = "Upper Sky Islands",  pos = Vector3.new(-6040.2, 5468.0, 1734.2) },
    { name = "Water 7",            pos = Vector3.new(5430.4, 78.0, 3953.6) },
}
M.islands2 = {
    { name = "Kingdom of Rose",  pos = Vector3.new(-195.1, 155.3, 279.9) },
    { name = "Café",             pos = Vector3.new(-380.4, 72.8, 303.2) },
    { name = "Mansion",          pos = Vector3.new(-393.3, 367.3, 687.5) },
    { name = "Colosseum",        pos = Vector3.new(-1836.4, 72.8, 1360.2) },
    { name = "Swan's Room",      pos = Vector3.new(2293.7, 12.5, 663.1) },
    { name = "Factory",          pos = Vector3.new(431.0, 238.4, -433.2) },
    { name = "Green Zone",       pos = Vector3.new(-2340.8, 155.3, -3396.3) },
    { name = "Dark Arena",       pos = Vector3.new(3807.1, 11.8, -3452.2) },
    { name = "Graveyard Island", pos = Vector3.new(-5577.9, 87.6, -782.2) },
    { name = "Snow Mountain",    pos = Vector3.new(856.2, 50.3, -5278.3) },
    { name = "Hot and Cold",     pos = Vector3.new(-5734.3, 49.4, -5146.4) },
    { name = "Cursed Ship",      pos = Vector3.new(900.9, 144.0, 33072.6) },
    { name = "Ice Castle",       pos = Vector3.new(6062.3, 155.3, -6880.9) },
    { name = "Forgotten Island", pos = Vector3.new(-3194.2, 155.3, -10795.3) },
}
M.bosses2 = {
    { name = "Diamond", pos = Vector3.new(-1711.4, 206.0, -97.1) },
    { name = "Jeremy", pos = Vector3.new(2338.0, 451.4, 700.1) },
    { name = "Smoke Admiral", pos = Vector3.new(-4857.4, 233.7, -5583.2) },
    { name = "Awakened Ice Admiral", pos = Vector3.new(6551.8, 325.3, -6989.9) },
    { name = "rip_indra", pos = Vector3.new(-26952.3, 21.5, 329.4) },
}
M.islands3 = {
    { name = "Port Town",              pos = Vector3.new(-610.4, 57.8, 6436.3) },
    { name = "Dragon Dojo",            pos = Vector3.new(5704.4, 1168.1, 937.0) },
    { name = "Castle on the Sea",      pos = Vector3.new(-5436.6, 815.6, -2701.7) },
    { name = "Floating Turtle",        pos = Vector3.new(-12164.6, -548.9, -8454.9) },
    { name = "Friendly Arena",         pos = Vector3.new(5012.8, 72.8, -1570.6) },
    { name = "Great Tree",             pos = Vector3.new(3036.3, 815.6, -7149.9) },
    { name = "Haunted Castle",         pos = Vector3.new(-9530.6, -132.9, 5763.1) },
    { name = "Beautiful Pirate Domain",pos = Vector3.new(5366.6, 71.2, -225.9) },
    { name = "Mansion",                pos = Vector3.new(-12547.7, 290.1, -7487.1) },
    { name = "North Pole",             pos = Vector3.new(-1141.1, 57.8, -14480.7) },
    { name = "Sea of Treats",          pos = Vector3.new(-1505.3, 57.8, -10724.1) },
    { name = "Secret Temple",          pos = Vector3.new(5226.2, 63.5, 858.8) },
    { name = "Tiki Outpost",           pos = Vector3.new(-16641.5, 213.3, 435.4) },
    { name = "Heavenly Dimension",     pos = Vector3.new(-22709.6, 5259.0, 3886.6) },
    { name = "Hell Dimension",         pos = Vector3.new(-22737.6, 5120.0, 2234.6) },
}
M.bosses3 = {
    { name = "Kilo Admiral", pos = Vector3.new(2998.3, 508.8, -7344.3) },
    { name = "Captain Elephant", pos = Vector3.new(-13365.5, 321.2, -8485.0) },
    { name = "Longma", pos = Vector3.new(-10156.2, 337.8, -9445.9) },
    { name = "Cake Queen", pos = Vector3.new(-678.5, 381.9, -11114.3) },
    { name = "Cake Prince", pos = Vector3.new(-2089.9, 4536.9, -14800.0) },
}
M.bosses = {
    { name = "Chef", pos = Vector3.new(-1120.5, 54.7, 4121.2) },
    { name = "Yeti", pos = Vector3.new(1181.7, 104.0, -1616.9) },
    { name = "Mob Boss", pos = Vector3.new(-2880.7, 6.7, 5430.9) },
    { name = "Saber Expert", pos = Vector3.new(-1527.2, 34.1, -33.2) },
    { name = "Warden", pos = Vector3.new(5623.2, 1.4, 733.8) },
    { name = "Magma General", pos = Vector3.new(-5625.7, 55.4, 8623.0) },
    { name = "Fishman Lord", pos = Vector3.new(61352.9, 67.2, 1029.1) },
    { name = "Sky Warlord", pos = Vector3.new(-6271.6, 5472.8, 1887.8) },
    { name = "Cyborg", pos = Vector3.new(6252.4, 9.3, 4941.4) },
    { name = "Ice Admiral", pos = Vector3.new(1212.4, 20.4, -1429.6) },
}

function M.hrp() local ch = LP and LP.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end
function M.cancel() if M._tween then pcall(function() M._tween:Cancel() end); M._tween = nil end end

function M.go(pos)
    local hrp = M.hrp()
    if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    local t = math.clamp(dist / math.max(M.config.speed, 1), 0.05, 90)
    M.cancel()
    local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(pos) })
    M._tween = tw
    tw.Completed:Connect(function() if M._tween == tw then M._tween = nil end end)
    tw:Play()
    if M._core then M._core.info("fly ->", pos) end
    return tw
end

M.secondSea = { captain = Vector3.new(-1130.2, 9.2, 1714.9), level = 700 }

local function commF()
    local r = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    return r and r:FindFirstChild("CommF_")
end
local function playerLevel()
    local ok, lv = pcall(function() return LP.Data.Level.Value end)
    return (ok and lv) or 0
end

function M.setAutoSecondSea(on)
    M._seaOn = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        local function finish(msg)
            if msg and M._ui then M._ui.notify(msg) end
            M._seaOn = false
            if M._seaToggle and M._seaToggle.Get() then M._seaToggle.Set(false) end
        end
        local lv = playerLevel()
        if lv < M.secondSea.level then
            finish(("Auto Second Sea: requires level %d (you are %d)"):format(M.secondSea.level, lv))
            return
        end
        M.go(M.secondSea.captain + Vector3.new(0, 4, 0))
        for _ = 1, 80 do
            if not M._seaOn then return end
            local h = M.hrp()
            if h and (h.Position - M.secondSea.captain).Magnitude < 25 then break end
            task.wait(0.25)
        end
        local c = commF()
        if c then
            local ok, res = pcall(function() return c:InvokeServer("TravelDressrosa") end)
            if M._core then M._core.info("Auto Second Sea", "TravelDressrosa", "ok=" .. tostring(ok), tostring(res)) end
            finish("Traveling to the Second Sea...")
        else
            finish("Auto Second Sea: remote missing")
        end
    end)
end

M.thirdSea = { level = 1500 }
function M.setAutoThirdSea(on)
    M._sea3On = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        local function finish(msg)
            if msg and M._ui then M._ui.notify(msg) end
            M._sea3On = false
            if M._sea3Toggle and M._sea3Toggle.Get() then M._sea3Toggle.Set(false) end
        end
        local lv = playerLevel()
        if lv < M.thirdSea.level then
            finish(("Auto Third Sea: requires level %d (you are %d)"):format(M.thirdSea.level, lv))
            return
        end
        local c = commF()
        if c then
            local ok, res = pcall(function() return c:InvokeServer("TravelZou") end)
            if M._core then M._core.info("Auto Third Sea", "TravelZou", "ok=" .. tostring(ok), tostring(res)) end
            finish("Traveling to the Third Sea...")
        else
            finish("Auto Third Sea: remote missing")
        end
    end)
end

function M.stop() M.cancel(); M._seaOn, M._sea3On = false, false end

function M.init(Core, UI)
    M._core, M._ui = Core, UI

    -- During a tween: zero velocity + noclip. Never Anchor the char — BF then rejects every hit.
    Core.track(RunService.Heartbeat:Connect(function()
        if M._tween then
            local ch = LP.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
            if ch then
                for _, part in ipairs(ch:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end
    end))

    local page = UI.page("Teleport")

    UI.button(page, "Notify current position", "Show and log your coordinates", function()
        local hrp = M.hrp()
        if not hrp then UI.notify("No character"); return end
        local p = hrp.Position
        UI.notify(("X %.1f   Y %.1f   Z %.1f"):format(p.X, p.Y, p.Z))
        Core.info("pos", ("%.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z))
    end)

    UI.button(page, "Set Spawn Here", "Set your respawn point to this location", function()
        local c = commF()
        if not c then UI.notify("Remote missing"); return end
        local ok, res = pcall(function() return c:InvokeServer("SetSpawnPoint") end)
        local done = ok and res ~= 0 and res ~= nil
        UI.notify(done and "Spawn point set here" or "Set spawn failed (too far from a spawn?)")
        Core.info("SetSpawnPoint", "ok=" .. tostring(ok), tostring(res))
    end)

    local groups = {}
    local function goList(sea, section, label, hint, list)
        local g = groups[sea]; if not g then g = {}; groups[sea] = g end
        g[#g + 1] = UI.section(page, section)
        local names = {}
        for _, e in ipairs(list) do names[#names + 1] = e.name end
        local dd = UI.dropdown(page, label, hint, names, function(_) end)
        g[#g + 1] = dd.frame
        local btn = UI.button(page, "Go to " .. label:lower(), "Fly there", function()
            for _, e in ipairs(list) do if e.name == dd.Get() then M.go(e.pos + Vector3.new(0, 5, 0)); break end end
        end)
        g[#g + 1] = btn.Parent
    end

    goList("Sea1", "ISLANDS", "Island", "Fly to an island", M.islands)
    goList("Sea1", "BOSSES", "Boss", "Fly to a boss", M.bosses)
    goList("Sea2", "ISLANDS", "Island 2", "Fly to an island", M.islands2)
    goList("Sea2", "BOSSES", "Boss 2", "Fly to a boss", M.bosses2)
    goList("Sea3", "ISLANDS", "Island 3", "Fly to an island", M.islands3)
    goList("Sea3", "BOSSES", "Boss 3", "Fly to a boss", M.bosses3)

    UI.onSea(function(sea)
        for s, g in pairs(groups) do
            for _, fr in ipairs(g) do fr.Visible = (s == sea) end
        end
    end)

    UI.section(page, "WAYPOINTS")
    local function addBtn(w) UI.button(page, "Go: " .. w.name, "Saved waypoint", function() M.go(w.pos) end) end
    for _, w in ipairs(M.waypoints) do addBtn(w) end
    local nameBox = UI.textbox(page, "New waypoint name...")
    UI.button(page, "Save current position", "Store your position as a waypoint", function()
        local hrp = M.hrp()
        if not hrp then UI.notify("No character"); return end
        local name = (nameBox.Text ~= "" and nameBox.Text) or ("WP " .. (#M.waypoints + 1))
        local w = { name = name, pos = hrp.Position }
        M.waypoints[#M.waypoints + 1] = w
        addBtn(w); nameBox.Text = ""
        UI.notify("Saved: " .. name)
    end)

    local seaPage = UI.page("Sea")
    if seaPage then
        UI.section(seaPage, "SECOND SEA")
        M._seaToggle = UI.toggle(seaPage, "Auto Second Sea",
            "Fly to the Experienced Captain and sail to Sea 2 (requires Lv 700)", false,
            function(s) M.setAutoSecondSea(s) end)
        UI.button(seaPage, "Go to Experienced Captain", "Fly to the Sea 2 ferry NPC", function()
            M.go(M.secondSea.captain + Vector3.new(0, 4, 0))
        end)
        UI.section(seaPage, "THIRD SEA")
        M._sea3Toggle = UI.toggle(seaPage, "Auto Third Sea",
            "Sail from Sea 2 to Sea 3 via Mr. Captain (requires Lv 1500)", false,
            function(s) M.setAutoThirdSea(s) end)
    end

    Core.register("teleport", M)
    return M
end

return M

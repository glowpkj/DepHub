local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Fruits: devil-fruit finder/teleport + gacha rolls.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local M = {}
M.config = { chestCooldown = 3.5, randomCooldown = 90, storePoll = 3, storeHandPoll = 2 }
function M._setStatus(_) end
M.FRUITS = {
    "Barrier", "Blade", "Blizzard", "Bomb", "Buddha", "Chop", "Control", "Creation", "Dark",
    "Diamond", "Door", "Dough", "Dragon", "Eagle", "Falcon", "Flame", "Gas", "Ghost", "Gravity",
    "Ice", "Kilo", "Kitsune", "Leopard", "Light", "Lightning", "Love", "Magma", "Mammoth",
    "Mochi", "Pain", "Paw", "Phoenix", "Portal", "Quake", "Revive", "Rocket", "Rubber", "Rumble",
    "Sand", "Shadow", "Smoke", "Sound", "Spider", "Spike", "Spin", "Spirit", "Spring", "String",
    "T-Rex", "Venom", "Yeti",
}
M.selectedFruit = nil
M._fruitEsp, M._collect, M._snipe, M._store, M._random = false, false, false, false, false
M._chestOn, M._chestEspOn, M._chestEsp, M._collected, M._fruitEspMap = false, false, {}, {}, {}

local fireprompt = fireproximityprompt or function() end

local function hrp() local ch = LP.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end
local function teleport() return M._core and M._core.modules.teleport end
local function commF() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("CommF_") end

function M.getStock()
    local c = commF()
    if not c then return {} end
    local ok, map = pcall(function() return c:InvokeServer("GetFruits", false) end)
    return (ok and type(map) == "table") and map or {}
end

function M.fruitNames()
    local names = table.clone(M.FRUITS)
    table.sort(names)
    return names
end

function M.buy(name)
    local c = commF()
    if not (c and name) then return end
    local ok, res = pcall(function() return c:InvokeServer("PurchaseRawFruit", name, false) end)
    if M._core then M._core.info("PurchaseRawFruit", name, "ok=" .. tostring(ok), "res=" .. tostring(res)) end
    return res
end

function M.setSnipe(on)
    M._snipe = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        while M._snipe do
            if M.selectedFruit then
                for _, v in pairs(M.getStock()) do
                    if type(v) == "table" and v.OnSale and v.ColorName == M.selectedFruit then
                        M.buy(v.ColorName)
                        if M._ui then M._ui.notify("Sniped: " .. v.ColorName) end
                    end
                end
            end
            task.wait(M.config.storePoll)
        end
    end)
end

function M.storeHeld()
    local c = commF()
    if not c then return end
    local pools = {}
    if LP.Character then pools[#pools + 1] = LP.Character end
    local bp = LP:FindFirstChild("Backpack")
    if bp then pools[#pools + 1] = bp end
    for _, pool in ipairs(pools) do
        for _, t in ipairs(pool:GetChildren()) do
            if t:IsA("Tool") then
                local orig = t:GetAttribute("OriginalName")
                if orig and tostring(orig):find("-") then
                    pcall(function() c:InvokeServer("StoreFruit", orig, t) end)
                    if M._core then M._core.info("StoreFruit", orig) end
                end
            end
        end
    end
end

function M.setStore(on)
    M._store = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        while M._store do M.storeHeld(); task.wait(M.config.storeHandPoll) end
    end)
end

local function dealerName()
    local info = M._core and M._core.modules.info
    return (info and info.sea == "Sea2") and "AdvancedFruitDealer" or "FruitDealer"
end

function M.openDealer()
    local ok, err = pcall(function()
        require(RS.Controllers.UI.FruitShop):Open(dealerName())
    end)
    if not ok and M._core then M._core.warn("openDealer failed:", tostring(err)) end
    if not ok and M._ui then M._ui.notify("Dealer menu unavailable") end
end

function M.awakenAll()
    local c = commF()
    if not c then return end
    local bought = 0
    for _ = 1, 30 do
        local ok, v = pcall(function() return c:InvokeServer("Awakener", "Awaken") end)
        if ok and v == 1 then bought = bought + 1 else break end
        task.wait(0.25)
    end
    if M._ui then M._ui.notify(bought > 0 and ("Awakened " .. bought .. " ability(ies)") or "Nothing to awaken (need fragments / equipped fruit)") end
    if M._core then M._core.info("Awaken all", "count=" .. bought) end
end

function M.openAwakening()
    local c = commF()
    if c then pcall(function() c:InvokeServer("AwakeningChanger", "Check") end) end
    local ok = pcall(function() require(RS.Controllers.UI.Awakening):Open() end)
    if M._ui then M._ui.notify(ok and "Awakening menu opened" or "Awaken needs a raid (see logs)") end
    if M._core then M._core.info("Awakening", "open ok=" .. tostring(ok)) end
end

local function gachaRF()
    local mods = RS:FindFirstChild("Modules")
    local n = mods and mods:FindFirstChild("Net")
    return n and n:FindFirstChild("RF/GachaNetworkRF")
end

function M.rollGacha()
    local rf = gachaRF()
    if not rf then if M._core then M._core.warn("GachaNetworkRF not found") end return end
    local p = table.pack(pcall(function() return rf:InvokeServer({ Context = "Purchase", BoxName = "ZiolesGacha" }) end))
    if M._core then
        local parts = {}
        for i = 2, p.n do parts[#parts + 1] = tostring(p[i]) end
        M._core.info("Gacha result:", table.concat(parts, " | "))
    end
    return p
end

function M.setRandom(on)
    M._random = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        while M._random do
            local ok, p = pcall(M.rollGacha)
            if M._ui then M._ui.notify("Fruit gacha roll") end
            local cd = M.config.randomCooldown
            if ok and p then
                for i = 2, p.n do
                    if type(p[i]) == "number" and p[i] > 3 then cd = math.clamp(math.floor(p[i]), 30, 300); break end
                end
            end
            while M._random and cd > 0 do
                M._setStatus(("Gacha: next roll in %ds"):format(cd))
                task.wait(1); cd = cd - 1
            end
        end
        M._setStatus("Gacha: off")
    end)
end

local function fruitPart(f)
    return f:FindFirstChild("Handle") or f:FindFirstChildWhichIsA("BasePart")
end
function M.groundFruits()
    local t = {}
    for _, c in ipairs(workspace:GetChildren()) do
        if c:IsA("Tool") and (c:GetAttribute("OriginalName") or c.Name:find("-")) and fruitPart(c) then
            t[#t + 1] = c
        end
    end
    return t
end

function M.setFruitESP(on)
    M._fruitEsp = on
    if not on then
        for _, e in pairs(M._fruitEspMap) do pcall(function() e.hl:Destroy(); e.bb:Destroy() end) end
        M._fruitEspMap = {}
        return
    end
    if not M._core then return end
    M._core.spawn(function()
        while M._fruitEsp do
            local live, h = {}, hrp()
            for _, f in ipairs(M.groundFruits()) do
                local part = fruitPart(f)
                if part then
                    live[f] = true
                    local e = M._fruitEspMap[f]
                    if not e then
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Color3.fromRGB(120, 220, 255)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.Adornee = part; hl.Parent = part
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.fromOffset(150, 20); bb.StudsOffset = Vector3.new(0, 2.5, 0)
                        bb.AlwaysOnTop = true; bb.Adornee = part; bb.Parent = part
                        local lbl = Instance.new("TextLabel")
                        lbl.BackgroundTransparency = 1; lbl.Size = UDim2.fromScale(1, 1)
                        lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13
                        lbl.TextColor3 = Color3.fromRGB(120, 220, 255); lbl.TextStrokeTransparency = 0.4
                        lbl.Parent = bb
                        e = { hl = hl, bb = bb, lbl = lbl, part = part }
                        M._fruitEspMap[f] = e
                    end
                    local d = h and math.floor((part.Position - h.Position).Magnitude) or 0
                    e.lbl.Text = ("%s  %dm"):format(f.Name, d)
                end
            end
            for f, e in pairs(M._fruitEspMap) do
                if not live[f] then pcall(function() e.hl:Destroy(); e.bb:Destroy() end); M._fruitEspMap[f] = nil end
            end
            task.wait(0.5)
        end
    end)
end

function M.nearestGroundFruit(skip)
    local h = hrp()
    local best, bestPart, bestD
    for _, f in ipairs(M.groundFruits()) do
        local p = fruitPart(f)
        if p and not (skip and skip[f]) then
            local d = h and (p.Position - h.Position).Magnitude or 0
            if not bestD or d < bestD then best, bestPart, bestD = f, p, d end
        end
    end
    return best, bestPart
end

function M.collectNearestOnce()
    local tp = teleport()
    local f, part = M.nearestGroundFruit()
    if tp and part then
        tp.go(part.Position)
        if M._core then M._core.info("fruit collect", f.Name) end
        return true
    end
    return false
end

function M.setCollect(on)
    M._collect = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        while M._collect do
            local farm = M._core.modules.farm
            if farm and farm._farmOn then
                task.wait(0.5)
            elseif M.collectNearestOnce() then
                task.wait(0.5)
            else
                task.wait(0.8)
            end
        end
    end)
end

function M.chests()
    local t = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Model") and (d.Name:match("^Chest%d*$") or d.Name == "SilverChest") then
            local ok, piv = pcall(function() return d:GetPivot().Position end)
            if ok then t[#t + 1] = { model = d, pos = piv } end
        end
    end
    return t
end

function M.setChestFarm(on)
    M._chestOn, M._collected = on, {}
    if not (on and M._core) then return end
    M._core.spawn(function()
        while M._chestOn do
            local tp, h = teleport(), hrp()
            if not (tp and h) then task.wait(1) else
                local pending = {}
                for _, ch in ipairs(M.chests()) do if not M._collected[ch.model] then pending[#pending + 1] = ch end end
                if #pending == 0 then
                    if M._ui then M._ui.notify("No chest to collect") end
                    M._collected = {}; task.wait(3)
                else
                    table.sort(pending, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end)
                    local ch = pending[1]
                    local dist = (ch.pos - h.Position).Magnitude
                    tp.go(ch.pos + Vector3.new(0, 3, 0))
                    task.wait(math.clamp(dist / 100, 0.2, 8) + 0.3)
                    M._collected[ch.model] = true
                    if M._core then M._core.info("chest ->", ch.model.Name) end
                    task.wait(M.config.chestCooldown)
                end
            end
        end
    end)
end

function M.setChestESP(on)
    M._chestEspOn = on
    if not on then
        for _, hl in pairs(M._chestEsp) do pcall(function() hl:Destroy() end) end
        M._chestEsp = {}
        return
    end
    if not M._core then return end
    M._core.spawn(function()
        local first = true
        while M._chestEspOn do
            local list = M.chests()
            if first and M._ui then M._ui.notify(#list .. " chest(s) found"); first = false end
            for _, ch in ipairs(list) do
                if not M._chestEsp[ch.model] then
                    local hl = Instance.new("Highlight")
                    hl.FillColor = Color3.fromRGB(255, 210, 60)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.Adornee = ch.model; hl.Parent = ch.model
                    M._chestEsp[ch.model] = hl
                end
            end
            task.wait(2)
        end
    end)
end

function M.stop()
    M._fruitEsp, M._collect, M._snipe, M._store, M._random, M._chestOn = false, false, false, false, false, false
    M.setFruitESP(false); M.setChestESP(false)
end

function M.init(Core, UI)
    M._core, M._ui = Core, UI

    local fp = UI.page("Fruit")
    UI.toggle(fp, "Fruit ESP", "Highlight fruits on the ground", false, function(s) M.setFruitESP(s) end)
    UI.toggle(fp, "Grab Fruit", "Pick up the nearest ground fruit", false, function(s) M.setCollect(s) end)
    UI.toggle(fp, "Fruit Store", "Auto-store fruits in your bar", false, function(s) M.setStore(s) end)

    UI.section(fp, "DEALER")
    local names = M.fruitNames()
    if #names == 0 then names = { "(open dealer / retry)" } end
    UI.dropdown(fp, "Fruit", "Fruit to snipe in the store", names, function(sel) M.selectedFruit = sel end)
    UI.toggle(fp, "Fruit snipe", "Buy the selected fruit when on sale", false, function(s) M.setSnipe(s) end)
    UI.toggle(fp, "Auto Random Fruit", "Roll the fruit gacha (Zioles) on cooldown", false, function(s) M.setRandom(s) end)
    UI.button(fp, "Fruit stock", "Open the in-game dealer menu (sea-aware)", function() M.openDealer() end)
    UI.button(fp, "Awaken all abilities", "Buy every awakening for your held fruit (uses fragments)", function() M.awakenAll() end)
    if UI._controls["Fruit / Awaken all abilities"] then UI._controls["Fruit / Awaken all abilities"].sea = "Sea2,Sea3" end
    UI.button(fp, "Awaken menu", "Open the awakening menu (full awaken needs a raid)", function() M.openAwakening() end)
    if UI._controls["Fruit / Awaken menu"] then UI._controls["Fruit / Awaken menu"].sea = "Sea2,Sea3" end
    local gStat = UI.section(fp, "Gacha: off")
    local gLbl = gStat and gStat:FindFirstChildWhichIsA("TextLabel")
    function M._setStatus(t) if gLbl then gLbl.Text = t end end

    local mp = UI.page("Farm")
    UI.section(mp, "CHESTS")
    UI.toggle(mp, "Chest ESP", "Highlight chests on the map", false, function(s) M.setChestESP(s) end)
    UI.toggle(mp, "Auto collect chests", "Teleport chest to chest (nearest first)", false, function(s) M.setChestFarm(s) end)

    Core.register("fruits", M)
    return M
end

return M

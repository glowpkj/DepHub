local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Shop: per-sea dealers, auto-buy legendary swords (Rengoku/Oroshi/Shizu).
local RS = game:GetService("ReplicatedStorage")

local M = {}
local function commF() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("CommF_") end

function M.buy(action, arg)
    local c = commF()
    if not c then return end
    local ok, res = pcall(function()
        if arg ~= nil then return c:InvokeServer(action, arg) else return c:InvokeServer(action) end
    end)
    if M._core then M._core.info("Shop", action, tostring(arg), "ok=" .. tostring(ok), "res=" .. tostring(res)) end
    if M._ui then
        M._ui.notify(ok and ("Buy " .. tostring(arg or action) .. " (res " .. tostring(res) .. ")") or "Shop error")
    end
end

M.swords = {
    "Katana", "Cutlass", "Iron Mace", "Dual Katana", "Bisento", "Pipe",
    "Dual-Headed Blade", "Soul Cane", "Dark Dagger", "Twin Hooks", "Longsword",
}
M.guns = { "Slingshot", "Refined Slingshot", "Flintlock", "Musket", "Cannon" }
M.styles = {
    { "Black Leg", "BuyBlackLeg" }, { "Electro", "BuyElectro" },
    { "Fishman Karate", "BuyFishmanKarate" }, { "Superhuman", "BuySuperhuman" },
}
M.haki = { "Buso", "Ken", "Geppo", "Soru" }
M.items = { "Black Cape", "Swordsman Hat", "Tomoe Ring" }

M.sea2 = {
    swords = { "Triple Katana" },
    guns = { "Dual Flintlock", "Refined Slingshot" },
    styles = {
        { "Death Step", "BuyDeathStep" }, { "Sharkman Karate", "BuySharkmanKarate" },
        { "Electric Claw", "BuyElectricClaw" }, { "Superhuman", "BuySuperhuman" },
    },
    haki = {},
    items = { "Swan Glasses", "Ghoul Mask", "Musketeer Hat", "Zebra Cap", "Warrior Helmet", "Marine Cap", "Black Spikey Coat" },
}

M.legendary = { "Shark Saw", "Saddi", "Pole (1st Form)" }
M._legendaryWant = "Any"

M.sea3 = {
    swords = {},
    guns = {},
    styles = {
        { "Dragon Talon", "BuyDragonTalon" }, { "Godhuman", "BuyGodhuman" }, { "Sanguine Art", "BuySanguineArt" },
    },
    haki = {},
    items = { "Ghoul Mask", "Pale Scarf", "Dark Coat", "Holy Crown", "Warrior Helmet" },
}

function M.legendaryOnSale()
    local c = commF()
    if not c then return nil end
    local ok, name = pcall(function() return c:InvokeServer("LegendarySwordDealer", "1") end)
    return ok and name or nil
end
function M.buyLegendary()
    local c = commF()
    if not c then return end
    return select(2, pcall(function() return c:InvokeServer("LegendarySwordDealer", "2") end))
end

function M.setAutoLegendary(on)
    M._legendaryOn = on
    if not (on and M._core) then return end
    M._core.spawn(function()
        while M._legendaryOn do
            local name = M.legendaryOnSale()
            if name and (M._legendaryWant == "Any" or name == M._legendaryWant) then
                local res = M.buyLegendary()
                if M._core then M._core.info("LegendarySword", name, "res=" .. tostring(res)) end
                if res == 1 then
                    if M._ui then M._ui.notify("Bought legendary: " .. name) end
                elseif res == 2 then
                    if M._ui then M._ui.notify("Already own: " .. name) end
                    M._legendaryOn = false
                    if M._legendaryToggle then M._legendaryToggle.Set(false) end
                end
            end
            task.wait(4)
        end
    end)
end

M.iceCastle = Vector3.new(6062.3, 155.3, -6880.9)
M._rengokuOn = false

local function rengokuDetection()
    local chest = workspace:FindFirstChild("RengokuChest", true)
    if not chest then
        local ice = workspace:FindFirstChild("IceCastle", true) or workspace:FindFirstChild("Ice Castle", true)
        chest = ice and ice:FindFirstChild("RengokuChest", true)
    end
    if not chest then return nil end
    local det = chest:FindFirstChild("Detection", true)
    local part = det or (chest:IsA("BasePart") and chest) or chest:FindFirstChildWhichIsA("BasePart")
    return part
end

function M.setRengoku(on)
    M._rengokuOn = on and true or false
    if not (M._rengokuOn and M._core) then return end
    local c = commF()
    if not c then if M._ui then M._ui.notify("Remote missing") end return end
    M._core.spawn(function()
        local tp = M._core.modules.teleport
        while M._rengokuOn do
            local part = rengokuDetection()
            if part then
                if tp then tp.go(part.Position + Vector3.new(0, 2, 0)) end
                task.wait(0.8)
                local ok, res = pcall(function() return c:InvokeServer("OpenRengoku") end)
                if M._core then M._core.info("OpenRengoku", "ok=" .. tostring(ok), tostring(res)) end
                if ok and res then
                    if M._ui then M._ui.notify("Rengoku chest opened") end
                    M._rengokuOn = false
                    if M._rengokuToggle then M._rengokuToggle.Set(false) end
                    return
                end
            else
                if tp then tp.go(M.iceCastle + Vector3.new(0, 40, 0)) end
                if M._ui then M._ui.notify("Locating Rengoku chest...") end
            end
            task.wait(1.5)
        end
    end)
end

function M.init(Core, UI)
    M._core, M._ui = Core, UI

    local function buildShop(page, d)
        if #d.swords > 0 then
            UI.section(page, "SWORDS")
            for _, s in ipairs(d.swords) do UI.button(page, s, "Buy this sword", function() M.buy("BuyItem", s) end) end
        end
        if #d.guns > 0 then
            UI.section(page, "GUNS")
            for _, g in ipairs(d.guns) do UI.button(page, g, "Buy this gun", function() M.buy("BuyItem", g) end) end
        end
        if #d.styles > 0 then
            UI.section(page, "FIGHTING STYLES")
            for _, st in ipairs(d.styles) do UI.button(page, st[1], "Buy this style", function() M.buy(st[2], true) end) end
        end
        if #d.haki > 0 then
            UI.section(page, "HAKI & MOVEMENT")
            for _, h in ipairs(d.haki) do UI.button(page, h, "Buy " .. h, function() M.buy("BuyHaki", h) end) end
        end
        if #d.items > 0 then
            UI.section(page, "ACCESSORIES")
            for _, it in ipairs(d.items) do UI.button(page, it, "Buy this item", function() M.buy("BuyItem", it) end) end
        end
    end

    local function buildLegendary(page)
        UI.section(page, "LEGENDARY SWORD (random dealer)")
        local want = { "Any" }
        for _, s in ipairs(M.legendary) do want[#want + 1] = s end
        UI.dropdown(page, "Legendary target", "Which sword to buy (Any = whatever is on sale)", want, function(sel) M._legendaryWant = sel end)
        UI.button(page, "Buy now (if present)", "Buy the sword on sale right now", function()
            local name = M.legendaryOnSale()
            if not name then UI.notify("Legendary dealer not available"); return end
            if M._legendaryWant ~= "Any" and name ~= M._legendaryWant then UI.notify("On sale: " .. name .. " (not your target)"); return end
            local res = M.buyLegendary()
            UI.notify(res == 1 and ("Bought: " .. name) or res == 0 and "Not enough money" or res == 2 and "Already owned" or "Gone")
        end)
        M._legendaryToggle = UI.toggle(page, "Auto Buy Legendary Sword", "Poll the random dealer and buy when it appears", false, function(s) M.setAutoLegendary(s) end)
    end

    buildShop(UI.page("Shop"), { swords = M.swords, guns = M.guns, styles = M.styles, haki = M.haki, items = M.items })

    local shop2 = UI.page("Shop 2")
    if shop2 then
        buildShop(shop2, M.sea2)
        buildLegendary(shop2)
        UI.section(shop2, "SPECIAL SWORDS")
        M._rengokuToggle = UI.toggle(shop2, "Auto Rengoku", "Go to the Ice Castle chest and open it (auto-off when done)", false, function(s) M.setRengoku(s) end)
    end

    local shop3 = UI.page("Shop 3")
    if shop3 then
        buildShop(shop3, M.sea3)
        buildLegendary(shop3)
    end

    Core.register("shop", M)
    return M
end

return M

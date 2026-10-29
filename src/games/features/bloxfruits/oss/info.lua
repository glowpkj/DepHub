local dephub = (getgenv and getgenv() or _G).__DEPHUB_OSS_RUNTIME
local game = dephub.game
local task = dephub.task

-- Info: status tab (executor, sea, player, logs).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local M = {}
M.VERSION = "1.0.0"
M._start = os.clock()
M.sea = "Sea1"

local function dataVal(name)
    local ok, v = pcall(function() return LP.Data[name].Value end)
    return ok and v or nil
end

local function equipped(tip)
    for _, pool in ipairs({ LP.Character, LP:FindFirstChild("Backpack") }) do
        if pool then
            for _, t in ipairs(pool:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == tip then return t.Name end
            end
        end
    end
    return "-"
end

local function comma(n)
    if type(n) ~= "number" then return tostring(n) end
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function uptime()
    local s = math.floor(os.clock() - M._start)
    return ("%02d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
end

local function executorName()
    local ok, name, ver = pcall(function() return identifyexecutor() end)
    if ok and name then return (ver and ver ~= "") and (tostring(name) .. " " .. tostring(ver)) or tostring(name) end
    local ok2, n2 = pcall(function() return getexecutorname() end)
    if ok2 and n2 then return tostring(n2) end
    return "Unknown"
end

function M.init(Core, UI)
    M._core, M._ui = Core, UI
    local page = UI.page("Info")
    local v = {}

    UI.section(page, "SCRIPT")
    v.sea = UI.stat(page, "Sea")
    v.version = UI.stat(page, "Version")
    v.executor = UI.stat(page, "Executor")
    v.uptime = UI.stat(page, "Uptime")

    UI.section(page, "PLAYER")
    v.level = UI.stat(page, "Level")
    v.beli = UI.stat(page, "Beli")
    v.frag = UI.stat(page, "Fragments")
    v.race = UI.stat(page, "Race")

    UI.section(page, "LOADOUT")
    v.fruit = UI.stat(page, "Fruit")
    v.sword = UI.stat(page, "Sword")
    v.gun = UI.stat(page, "Gun")
    v.melee = UI.stat(page, "Melee")

    v.version.Text = M.VERSION
    v.executor.Text = executorName()

    Core.spawn(function()
        while true do
            local ok, sea = pcall(function() return require(RS.Util.Realm).getCurrentSeaAsync() end)
            if ok and sea then M.sea = sea; UI.setSea(sea) end
            v.sea.Text = M.sea
            v.uptime.Text = uptime()
            v.level.Text = tostring(dataVal("Level") or "?")
            v.beli.Text = comma(dataVal("Beli") or 0)
            v.frag.Text = comma(dataVal("Fragments") or 0)
            v.race.Text = tostring(dataVal("Race") or "?")
            v.fruit.Text = tostring(dataVal("DevilFruit") or "None")
            v.sword.Text = equipped("Sword")
            v.gun.Text = equipped("Gun")
            v.melee.Text = equipped("Melee")
            task.wait(2)
        end
    end)

    Core.register("info", M)
    return M
end

return M

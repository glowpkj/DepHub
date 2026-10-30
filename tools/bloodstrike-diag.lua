-- Cola isso no console do executor DEPOIS que o DepHub carregar.
-- Nao muda nada; so imprime o estado do backend Blood Strike.

local g = getgenv and getgenv() or _G
local out = {}

local function add(k, v) out[#out + 1] = tostring(k) .. ": " .. tostring(v) end

add("PlaceId", game.PlaceId)
add("GameId", game.GameId)
add("nome do jogo", game.Name)

-- O loader registrou o backend?
add("__DEPHUB existe", g.__DEPHUB ~= nil)
add("Mode", g.__DEPHUB and g.__DEPHUB.Mode or "nil")
add("BloodStrike (backend)", g.__DEPHUB and g.__DEPHUB.BloodStrike or "nil")
add("BS (alias)", g.BS or "nil")
add("__DEPHUB_BLOODSTRIKE", g.__DEPHUB_BLOODSTRIKE or "nil")

-- workspace.Characters existe? quantos filhos, de que tipo, com que nome?
local container = game:GetService("Workspace"):FindFirstChild("Characters")
add("workspace.Characters existe", container ~= nil)
if container then
    local kids = container:GetChildren()
    add("Characters: filhos", #kids)
    for i = 1, math.min(#kids, 12) do
        local c = kids[i]
        local head = c.FindFirstChild and (c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart"))
        local hum = c.FindFirstChildOfClass and c:FindFirstChildOfClass("Humanoid")
        add("  [" .. i .. "]", c.Name .. " | " .. tostring(c.ClassName) ..
            " | Head=" .. tostring(head ~= nil) ..
            " | Humanoid=" .. tostring(hum ~= nil))
    end
else
    -- Procura qualquer container parecido em Workspace pra eu achar o nome certo.
    add("--- procurando containers em Workspace ---", "")
    for _, c in ipairs(game:GetService("Workspace"):GetChildren()) do
        if c:IsA("Folder") or c:IsA("Model") then
            local n = #c:GetChildren()
            if n > 0 then add("  workspace." .. c.Name, c.ClassName .. " (" .. n .. " filhos)") end
        end
    end
end

-- O player tem Team?
local lp = game:GetService("Players").LocalPlayer
add("LocalPlayer.Team", lp and lp.Team and lp.Team.Name or "nil")
add("LocalPlayer.Character", lp and (lp.Character and lp.Character.Name or "nil") or "sem player")

-- A aba ESP foi criada na UI?
local ui = g.__DEPHUB and g.__DEPHUB.UI
if ui and ui.Tabs then
    local found = {}
    for _, t in pairs(ui.Tabs) do
        if t.Name == "ESP" then found[#found + 1] = tostring(t.Category) end
    end
    add("aba ESP registrada na UI", #found > 0 and table.concat(found, ",") or "NAO")
end

print("========== DEPHUB BLOOD STRIKE DIAG ==========")
print(table.concat(out, "\n"))
print("==============================================")
return out

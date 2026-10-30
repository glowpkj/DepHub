-- Roda ANTES de recarregar o DepHub. Limpa todo o estado/cache que o loader
-- guarda no executor, para garantir que a proxima execucao seja limpa.
local g = getgenv and getgenv() or _G
local keys = {
    "__DEPHUB_SOURCE_CACHE",
    "__DEPHUB_LOADER_EXECUTED",
    "__DEPHUB_LOADER_STATE",
    "__DEPHUB_SELF_UPDATE_ATTEMPT",
    "__DEPHUB_BLOODSTRIKE",
    "__DEPHUB_BLOXFRUITS_OSS",
}
for _, k in ipairs(keys) do g[k] = nil end

-- Destroy de runtime, se houver
if g.__DEPHUB then
    for _, name in ipairs({"BloodStrike", "BloxFruits", "BloxFruitsOSS", "Universal", "Backend"}) do
        local t = g.__DEPHUB[name]
        if type(t) == "table" and type(t.Destroy) == "function" then pcall(t.Destroy, t) end
    end
end
g.__DEPHUB = nil
g.BS = nil

-- Fecha qualquer GUI do DepHub que tenha ficado
local pg = game:GetService("CoreGui")
for _, child in ipairs(pg:GetChildren()) do
    if child.Name:lower():find("dephub") or child.Name:lower():find("dep hub") then
        pcall(function() child:Destroy() end)
    end
end
for _, child in ipairs(game:GetService("Players").LocalPlayer:GetChildren()) do
    if child.Name:lower():find("dephub") or child:IsA("ScreenGui") then
        pcall(function() child:Destroy() end)
    end
end

print("[DepHub] cache e estado limpos. Recarregue o DepHub agora (podem aparecer 2 paineis se um antigo ficou; o novo e' o certo).")

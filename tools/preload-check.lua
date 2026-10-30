-- Roda ANTES de carregar o DepHub. So testa o que o loader testa no inicio.
local BASE = "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local out = {}

local function add(k, v) out[#out+1] = tostring(k)..": "..tostring(v) end

add("executor", (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "?")

-- 1) httpGet do version.txt (o loader faz isso logo apos o GameId)
local ok, res = pcall(function()
    return game:HttpGet(BASE .. "src/version.txt?cb=" .. tostring(os.time()))
end)
add("version.txt ok", ok)
add("version.txt valor", ok and tostring(res):sub(1,64) or tostring(res))

-- 2) httpGet do proprio loader
local ok2, res2 = pcall(function()
    return game:HttpGet(BASE .. "DepHub.lua?cb=" .. tostring(os.time()))
end)
add("DepHub.lua ok", ok2)
add("DepHub.lua tamanho", ok2 and #tostring(res2) or tostring(res2))

-- 3) compile do loader baixado
if ok2 then
    local ok3, chunk, err = pcall(loadstring, res2)
    add("loader compila", ok3 and type(chunk) == "function")
    if not (ok3 and type(chunk) == "function") then add("erro compile", tostring(chunk or err)) end
end

-- 4) o backend novo existe no remoto?
local ok4, res4 = pcall(function()
    return game:HttpGet(BASE .. "src/games/bloodstrike.lua?cb=" .. tostring(os.time()))
end)
add("bloodstrike.lua baixa", ok4)
add("bloodstrike.lua tamanho", ok4 and #tostring(res4) or tostring(res4))

print("========== PRE-LOAD CHECK ==========")
print(table.concat(out, "\n"))
print("====================================")

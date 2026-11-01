--[[
  DepHub -- bootstrap com verificacao de saude (geral, todos os jogos).

  Cole ESTE script no executor, sempre. Ele:

    1. baixa e executa o DepHub.lua oficial (com fallback de host igual ao
       loader do proprio hub);
    2. espera o backend subir;
    3. imprime no console um resumo curto -- versao, host, executor, qual
       backend/modo carregou -- e todo erro de carga que o backend reportou.

  O console SEMPRE recebe o resumo, para qualquer jogo: e o mesmo bootstrap
  para Blox Fruits, MM2, TSB, Noon Piece, universal, etc. Se algo estiver
  errado, ele aponta o ingrediente que falhou em vez de deixar voce adivinhar.

  Quando o backend carregado for o Blox Fruits, ele confere tambem a lista de
  ILHAS do Travel (a que aparece vazia no painel) e diz quantas carregaram por
  mar -- a checagem extra so roda nesse jogo.

  Trocar de branch: passe a ref como primeiro argumento, ex.:
      loadstring(...)("dev")   -- ou edite a SOURCE_REF abaixo.
  O hub e carregado com a MESMA ref, entao bootstrap de dev carrega build de dev.
]]

local SOURCE_REF = tostring((...) or "main")

local HOSTS = {
    "https://raw.githubusercontent.com/glowpkj/DepHub/" .. SOURCE_REF .. "/",
    "https://github.com/glowpkj/DepHub/raw/" .. SOURCE_REF .. "/",
    "https://cdn.jsdelivr.net/gh/glowpkj/DepHub@" .. SOURCE_REF .. "/",
}

local function say(message) pcall(print, "[DepHub loader] " .. tostring(message)) end
local function loud(message) pcall(warn, "[DepHub loader] " .. tostring(message)) end

-- Um GET que tenta todas as APIs de HTTP que o executor costuma expor.
local function httpGet(url)
    local candidates = {}
    if type(request) == "function" then candidates[#candidates + 1] = request end
    if type(http_request) == "function" then candidates[#candidates + 1] = http_request end
    if type(syn) == "table" and type(syn.request) == "function" then candidates[#candidates + 1] = syn.request end
    for _, fn in ipairs(candidates) do
        local ok, res = pcall(fn, {Url = url, Method = "GET"})
        if ok and type(res) == "table" then
            local body = res.Body or res.body
            if type(body) == "string" and #body > 0 then return true, body end
        end
    end
    if type(HttpGet) == "function" then
        local ok, body = pcall(HttpGet, url)
        if ok and type(body) == "string" and #body > 0 then return true, body end
    end
    if type(game.HttpGet) == "function" then
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if ok and type(body) == "string" and #body > 0 then return true, body end
    end
    return false, "nenhuma API de HTTP respondeu"
end

-- Baixa o loader oficial do primeiro host que servir um DepHub.lua nao-vazio.
local function fetchLoader()
    local lastError = "?"
    -- token unico por run: fura cache de executor que serve URL fixa antiga.
    local token = tostring(os.time()) .. "." .. tostring(math.floor((os.clock() % 1) * 1e6))
    for _, base in ipairs(HOSTS) do
        local ok, body = httpGet(base .. "DepHub.lua?cb=" .. token)
        if ok then return true, body, base end
        lastError = tostring(body)
    end
    return false, lastError, nil
end

-- ---------------------------------------------------------------------------
-- Carga
-- ---------------------------------------------------------------------------
local okFetch, source, usedBase = fetchLoader()
if not okFetch then
    loud("nao consegui baixar o DepHub.lua: " .. tostring(source))
    return
end

if type(loadstring) ~= "function" then
    loud("este executor nao tem loadstring -- nao da pra carregar o hub.")
    return
end

local chunk, compileError = loadstring(source)
if not chunk then
    loud("o DepHub.lua baixado nao compilou: " .. tostring(compileError))
    return
end

say("executando o hub (ref " .. SOURCE_REF .. ")...")
local okRun, runResult = pcall(chunk, SOURCE_REF)
if not okRun then
    loud("o hub estourou ao executar: " .. tostring(runResult))
    return
end

-- ---------------------------------------------------------------------------
-- Espera o hub publicar o estado do loader (o backend monta em alguns frames).
-- ---------------------------------------------------------------------------
local function waitForHub(timeout)
    local deadline = os.clock() + (timeout or 15)
    while os.clock() < deadline do
        local env = type(getgenv) == "function" and getgenv() or _G
        local loaderState = env.__DEPHUB_LOADER_STATE
        -- "success" / "failed" / "unsupported": qualquer estado final serve.
        if type(loaderState) == "table" and loaderState.status ~= "running" then
            return env, loaderState
        end
        task.wait(0.2)
    end
    return (type(getgenv) == "function" and getgenv() or _G), nil
end

local env, loaderState = waitForHub(15)

-- ---------------------------------------------------------------------------
-- Resumo (geral -- vale para qualquer jogo)
-- ---------------------------------------------------------------------------
say("----- resumo -----")
say("versao: " .. tostring((loaderState and loaderState.Version) or "?")
    .. "   host: " .. tostring(usedBase or "?")
    .. "   ref: " .. SOURCE_REF)

local executor = "?"
pcall(function()
    if type(identifyexecutor) == "function" then executor = identifyexecutor()
    elseif type(getexecutorname) == "function" then executor = getexecutorname() end
end)
say("executor: " .. tostring(executor))

if type(loaderState) ~= "table" then
    loud("o hub nao publicou estado em 15s -- provavelmente travou na carga.")
    say("dica: veja as mensagens de warn acima, ou abra a aba Debug do painel.")
    return
end

say("status: " .. tostring(loaderState.status)
    .. "   backend: " .. tostring(env.__DEPHUB and env.__DEPHUB.Mode or "?"))

if loaderState.status == "failed" then
    loud("a carga FALHOU: " .. tostring(loaderState.error or "(sem motivo registrado)"))
elseif loaderState.status == "unsupported" then
    say("este jogo nao tem backend proprio e o universal esta desligado.")
end

-- ---------------------------------------------------------------------------
-- Checagem EXTRA do Blox Fruits: a lista de ilhas do Travel.
-- So roda quando o backend carregado e o Blox Fruits; para os outros jogos
-- o resumo acima ja e o suficiente.
-- ---------------------------------------------------------------------------
local function checkBloxFruits()
    local ok, state = pcall(function() return env.__DEPHUB_BLOXFRUITS end)
    if not ok or type(state) ~= "table" then return false end

    say("blox fruits: mar detectado: " .. tostring(state.Sea or "(nenhum)"))

    if state.Errors and #state.Errors > 0 then
        loud("erros de carga do backend:")
        for _, message in ipairs(state.Errors) do loud("  - " .. tostring(message)) end
    else
        say("blox fruits: erros de carga: nenhum")
    end

    local factory = state.Features and state.Features.islands
    if type(factory) ~= "table" or type(factory.IslandLabels) ~= "function" then
        loud("a feature de ILHAS nao carregou (islands.lua) -- o dropdown do Travel fica vazio.")
        return true
    end

    local okLabels, labels = pcall(function() return factory:IslandLabels(state.Sea) end)
    if not okLabels then
        loud("IslandLabels estourou: " .. tostring(labels))
    elseif type(labels) ~= "table" or #labels == 0 then
        loud("a lista de ilhas do mar atual veio VAZIA -- e por isso o dropdown mostra None.")
        if state.Sea == nil then
            loud("o mar detectado e nil (ReplicatedStorage.Util.Realm nao respondeu).")
        end
    else
        say(("ilhas no mar atual (%s): %d -- ex.: %s")
            :format(tostring(state.Sea), #labels, tostring(labels[1])))
    end

    -- Contagem por mar, do mesmo modulo, pra provar que os 3 mapas existem.
    local counts = {}
    for _, sea in ipairs({"Sea1", "Sea2", "Sea3"}) do
        local okCount, seaLabels = pcall(function() return factory:IslandLabels(sea) end)
        counts[#counts + 1] = sea .. "=" .. tostring(okCount and (#seaLabels) or "erro")
    end
    say("ilhas por mar: " .. table.concat(counts, "  "))
    return true
end

local checkedBloxFruits = false
pcall(function() checkedBloxFruits = checkBloxFruits() end)
if not checkedBloxFruits and loaderState.status == "success" then
    say("(jogo sem checagem extra -- resumo geral acima)")
end

say("------------------")

if loaderState.status == "success" then
    say("hub no ar. se um dropdown aparecer vazio, o detalhe esta nas linhas acima.")
else
    loud("a carga nao terminou bem -- mande este resumo pra quem mantem o hub.")
end

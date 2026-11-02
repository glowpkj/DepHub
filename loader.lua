--[[
  DepHub -- bootstrap com verificacao de saude (geral, todos os jogos).

  Cole ESTE script no executor, sempre. Ele:

    1. baixa o DepHub.lua oficial (com fallback de host igual ao loader do
       proprio hub);
    2. executa o DepHub.lua NA HORA -- sem esperar o jogo nem o personagem
       carregarem (o hub aparece no mesmo instante). A protecao contra uma
       feature agir antes do personagem existir fica DENTRO de cada feature,
       como guarda por frame -- o loader nao bloqueia;
    3. espera o backend publicar o estado;
    4. fica QUIETO no console num load saudavel: a unica linha e
       "DepHub v<versao>". Todo o detalhe (host, executor, backend, contagem de
       ilhas) fica na aba Debug do painel. Falhas reais continuam saindo por
       warn -- um run quebrado nunca fica silencioso.

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
local okFetch, source = fetchLoader()
if not okFetch then
    loud("nao consegui baixar o DepHub.lua: " .. tostring(source))
    return
end

if type(loadstring) ~= "function" then
    loud("este executor nao tem loadstring -- nao da pra carregar o hub.")
    return
end

-- ---------------------------------------------------------------------------
-- Carga IMEDIATA: o hub sobe na hora, sem esperar o jogo nem o personagem.
--
-- Antes daqui havia um `waitForLoad(45)` que segurava o hub por ate 45s (loop de
-- task.wait(0.1) olhando game:IsLoaded() e o nascimento do Character) e o usuario
-- reclamou: "demorou muito pra executar, deixa sem carregamento". O atraso era
-- todo dessa espera -- o download e a montagem sao instantaneos.
--
-- A protecao contra feature agir cedo demais NAO se perdeu: ela vive DENTRO das
-- features, como guarda por frame (cada uma so age quando o proprio personagem/
-- alvo existe). O loader nao bloqueia mais nada -- sobe e pronto.
-- ---------------------------------------------------------------------------
-- (silencioso: o hub imprime a linha de versao; nao anunciamos progresso.)

local chunk, compileError = loadstring(source)
if not chunk then
    loud("o DepHub.lua baixado nao compilou: " .. tostring(compileError))
    return
end

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
-- Silencio no caminho feliz. O proprio hub imprime a unica linha que o
-- jogador ve ("DepHub v<versao>"). Aqui so reportamos PROBLEMA: se o backend
-- nao publicou estado, se a carga falhou, ou se a checagem extra do Blox Fruits
-- achou a lista de ilhas vazia. Todo o detalhe (host, executor, backend,
-- contagem por mar) fica na aba Debug do painel.
-- ---------------------------------------------------------------------------
if type(loaderState) ~= "table" then
    loud("o hub nao publicou estado em 15s -- provavelmente travou na carga.")
    loud("dica: abra a aba Debug do painel para ver o detalhe.")
    return
end

if loaderState.status == "failed" then
    loud("a carga FALHOU: " .. tostring(loaderState.error or "(sem motivo registrado)"))
elseif loaderState.status == "unsupported" then
    loud("este jogo nao tem backend proprio e o universal esta desligado.")
end

-- Checagem EXTRA do Blox Fruits: a lista de ilhas do Travel. So roda nesse
-- backend; se ela vier vazia, e o dropdown do Travel mostrando None -- avisa.
do
    local ok, state = pcall(function() return env.__DEPHUB_BLOXFRUITS end)
    if ok and type(state) == "table" then
        if state.Errors and #state.Errors > 0 then
            for _, message in ipairs(state.Errors) do loud("erro de carga do backend: " .. tostring(message)) end
        end

        local factory = state.Features and state.Features.islands
        if type(factory) ~= "table" or type(factory.IslandLabels) ~= "function" then
            loud("a feature de ILHAS nao carregou (islands.lua) -- o dropdown do Travel fica vazio.")
        else
            local okLabels, labels = pcall(function() return factory:IslandLabels(state.Sea) end)
            if not okLabels then
                loud("IslandLabels estourou: " .. tostring(labels))
            elseif type(labels) ~= "table" or #labels == 0 then
                loud("a lista de ilhas do mar atual veio VAZIA -- e por isso o dropdown mostra None.")
                if state.Sea == nil then
                    loud("o mar detectado e nil (ReplicatedStorage.Util.Realm nao respondeu).")
                end
            end
        end
    end
end

-- Caminho feliz: NADA aqui. O hub ja imprimiu "DepHub v<versao>"; o loader so
-- fala quando ha problema. Assim o console tem uma linha so num load saudavel.
if loaderState.status ~= "success" then
    loud("a carga nao terminou bem -- mande este aviso pra quem mantem o hub.")
end

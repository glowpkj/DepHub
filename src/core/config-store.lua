-- Config store compartilhado do DepHub.
--
-- Esta e a PECA UNICA de persistencia de config do hub. Antes cada backend
-- tinha sua propria copia do mesmo mecanismo (achar a API de arquivo do
-- executor, serializar um JSON raso, gravar, ler de volta, cair pra memoria
-- quando nao ha disco) -- e cada copia errava num lugar diferente. Aqui fica
-- UMA implementacao, e os backends so dizem o NOME DO ARQUIVO e, para cada
-- controle, a chave e como reaplicar o valor.
--
-- Como um backend adota (o "caminho pronto"):
--
--   local ok, factory = loadFactory("src/core/config-store.lua")   -- ou o fetch
--   local store = factory.new({ file = "DepHub_MeuJogo_config.json" })
--   store:Register("velocidade", function(v) self:SetSpeed(v) end, sliderHandle)
--   store:Save()                    -- grava o que esta no store
--   store:Prime()                   -- enche o store com o arquivo, SEM aplicar
--   ...monta o painel com store:Get("chave") nos controles...
--   store:Apply()                   -- reaplica TUDO (mesmo caminho do clique)
--
-- O ponto central: `Apply` reusa a MESMA funcao que o callback do controle usa,
-- entao um valor salvo LIGA a feature de verdade -- nao so pinta o controle.
-- Esse era o bug "o toggle ta ativo mas o efeito nao aparece".
--
-- Sem API de arquivo (writefile/readfile/isfile) a config vive so na sessao, sem
-- erro -- e o Save diz o MOTIVO real da falha em vez de um "so na memoria".

local type = type
local tostring = tostring
local table = table
local pcall = pcall
local pairs = pairs
local ipairs = ipairs

local env = type(getgenv) == "function" and getgenv() or _G

-- Os nomes livres capturados no load. Guardar agora evita a resolucao depender
-- de _G/getfenv depois; o getter ainda tenta env/getgenv() como fallback (alguns
-- executores so publicam la).
local fileWrite = writefile
local fileRead = readfile
local fileIsFile = isfile

-- A API de arquivo do executor. Os nomes livres sao o caminho normal; env
-- (getgenv/_G) e o fallback de quem so publica la. Sem os TRES nao ha disco.
local function resolveFileApi()
    local write = type(fileWrite) == "function" and fileWrite or env.writefile
    local read = type(fileRead) == "function" and fileRead or env.readfile
    local isf = type(fileIsFile) == "function" and fileIsFile or env.isfile
    if type(write) ~= "function" or type(read) ~= "function" or type(isf) ~= "function" then return nil end
    return { write = write, read = read, isfile = isf }
end

-- Serializa uma tabela plana (string/number/boolean + array de string) pro nosso
-- JSON. E um subconjunto JSON de proposito: o repo nao tem um codec JSON no
-- cliente, e o que uma config guarda e so escalares + listas de string.
local function encodeValue(value)
    local valueType = type(value)
    if valueType == "string" then
        return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "table" then
        local parts = {}
        for _, item in ipairs(value) do parts[#parts + 1] = encodeValue(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    return "null"
end

-- Le um objeto JSON raso (so escalares + arrays de string). Um parser minimo e
-- tolerante: o que nao casar e simplesmente ignorado.
local function decodeConfig(text)
    local out = {}
    if type(text) ~= "string" then return out end
    for key, raw in text:gmatch('"([^"]+)":%s*([^,}]+)') do
        raw = raw:gsub("%s+$", "")
        local str = raw:match('^"(.*)"$')
        if str then
            out[key] = str:gsub('\\"', '"'):gsub("\\\\", "\\")
        elseif raw == "true" then
            out[key] = true
        elseif raw == "false" then
            out[key] = false
        elseif raw:match("^%-?%d+%.?%d*$") then
            out[key] = tonumber(raw)
        elseif raw:match("^%[") then
            local list = {}
            local arrayText = text:match('"' .. key .. '":%s*(%b[])')
            if arrayText then
                for item in arrayText:gmatch('"(.-)"') do list[#list + 1] = item end
            end
            out[key] = list
        end
    end
    return out
end

local Store = {}
Store.__index = Store

-- opts.file        -- o nome do arquivo no executor (obrigatorio).
-- opts.decoder     -- (opcional) decodificador proprio; default o JSON raso acima.
function Store.new(opts)
    opts = opts or {}
    return setmetatable({
        file = opts.file,
        decoder = opts.decoder,
        Values = {},        -- o que o painel/escreveu: chave -> valor
        Entries = {},       -- { {key, apply, handle}, ... } na ordem de registro
        Saved = nil,        -- o snapshot em memoria (fallback sem disco)
        LastError = nil,
    }, Store)
end

function Store:FileApi()
    return resolveFileApi()
end

function Store:CanPersist()
    return self:FileApi() ~= nil
end

function Store:Get(key)
    return self.Values[key]
end

function Store:Set(key, value)
    self.Values[key] = value
end

-- Registra como uma chave volta ao vivo: a funcao de aplicar (MESMO corpo do
-- callback do controle) e, opcionalmente, o handle -- pro Load tambem mexer no
-- que esta na tela. Devolve a funcao apply (comodo pro chamador).
function Store:Register(key, apply, handle)
    self.Entries[#self.Entries + 1] = { key = key, apply = apply, handle = handle }
    return apply
end

function Store:Encode()
    local parts = {}
    local keys = {}
    for key in pairs(self.Values) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = '"' .. key .. '":' .. encodeValue(self.Values[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Grava as configs atuais. Devolve true se gravou em disco, false se so deu pra
-- guardar em memoria. O snapshot e uma COPIA (nao um alias): mexer no painel
-- depois de salvar nao reescreve o que foi salvo.
function Store:Save()
    local snapshot = {}
    for key, value in pairs(self.Values) do
        if type(value) == "table" then
            local copy = {}
            for index, item in ipairs(value) do copy[index] = item end
            snapshot[key] = copy
        else
            snapshot[key] = value
        end
    end
    self.Saved = snapshot
    local api = self:FileApi()
    if not api then
        self.LastError = "executor sem API de arquivo (writefile/readfile/isfile)"
        return false
    end
    local text = self:Encode()
    -- writefile pode lancar (pcall) OU devolver false explicito sem lancar; os
    -- dois sao falha. O terceiro argumento de pcall (a mensagem) entra no motivo.
    local ok, wrote = pcall(api.write, self.file, text)
    if not ok or wrote == false then
        self.LastError = ok and "writefile devolveu false" or "writefile recusou a gravacao"
        return false
    end
    -- Confirma lendo de volta E comparando BYTE a BYTE com o que foi escrito.
    -- Nao basta o arquivo "voltar com algo": um arquivo antigo, parcial ou de
    -- outro conteudo passaria. So e gravacao ok quando o que voltou e exatamente
    -- o texto que mandamos -- senao o Save diria "ok" e o proximo start abriria
    -- outra coisa (o "nao salva" que o usuario viu).
    local readOk, back = pcall(api.read, self.file)
    if not readOk or type(back) ~= "string" then
        self.LastError = "o arquivo nao voltou depois de gravar"
        return false
    end
    if back ~= text then
        self.LastError = "o arquivo nao voltou igual ao que foi gravado"
        return false
    end
    self.LastError = nil
    return true
end

-- Le as configs do disco (ou da memoria) e devolve a tabela, sem aplicar nada.
-- Devolve nil quando nao ha arquivo nem config guardada.
function Store:Read()
    local api = self:FileApi()
    if not api then return self.Saved end
    -- isfile pode lancar, devolver false ou devolver nil. Uma unica chamada,
    -- com o retorno E o ok do pcall guardados -- a versao anterior chamava
    -- isfile duas vezes e a segunda ficava FORA do pcall (um executor que lanca
    -- na segunda derrubava o Load inteiro).
    local ok, exists = pcall(api.isfile, self.file)
    if not ok then
        self.LastError = "isfile recusou"
        return self.Saved
    end
    if exists ~= true then return self.Saved end
    local readOk, text = pcall(api.read, self.file)
    if not readOk or type(text) ~= "string" then return nil end
    local parsed = (self.decoder or decodeConfig)(text)
    self.Saved = parsed
    return parsed
end

-- Le do disco so pra encher os Values, sem aplicar (o Apply precisa dos
-- handles, que so existem depois do painel montar). Chamado ANTES de montar o
-- painel, pra cada controle ja nascer no valor salvo. Devolve a tabela lida.
function Store:Prime()
    local config = self:Read()
    if type(config) == "table" then
        for key, value in pairs(config) do self.Values[key] = value end
    end
    return config
end

-- Aplica uma config (a do Read/Prime) ao estado e a UI: percorre a lista que o
-- painel registrou e chama a MESMA operacao de cada callback. Sem essa lista, so
-- os valores digitados na sessao teriam efeito -- o que veio do arquivo precisa
-- re-disparar cada setter.
--
-- Devolve uma tabela { applied = {...}, failed = {...}, count = n }. `applied` e
-- `failed` sao arrays de chaves: uma chave so entra em `applied` quando a
-- aplicacao realmente rodou sem erro. Um pcall que retorna false OU lanca erro
-- entra em `failed` com o motivo -- antes o codigo descartava o resultado e
-- contava como aplicado de qualquer jeito (o painel dizia "Loaded N settings"
-- mesmo quando uma feature tinha recusado).
--
-- O EFEITO ACONTECE UMA VEZ SO. O SetValue da RedzLib dispara o callback do
-- controle quando o valor muda; chamar `apply` E `SetValue` rodava o efeito duas
-- vezes. Aqui: se o controle vai mesmo mudar, so o SetValue roda (o callback
-- dele e o efeito); se o controle ja esta no valor, o SetValue nao dispararia
-- nada, entao o `apply` roda direto. Nunca os dois.
function Store:Apply(config)
    config = config or self.Saved
    local result = { applied = {}, failed = {}, count = 0 }
    if type(config) ~= "table" then return result end
    for _, entry in ipairs(self.Entries) do
        local value = config[entry.key]
        if value ~= nil then
            local handle = entry.handle
            local handleCanDrive = handle ~= nil
                and (type(handle.SetValue) == "function" or type(handle.Set) == "function")
            local willChange = handleCanDrive and (handle.Value ~= value)

            local ok, applied
            if willChange then
                -- O SetValue move o controle E dispara o callback (o efeito).
                local setter = type(handle.SetValue) == "function" and handle.SetValue or handle.Set
                ok, applied = pcall(setter, handle, value)
            else
                -- Sem handle, ou controle ja no valor: aplica o efeito direto.
                ok, applied = pcall(entry.apply, value)
                -- Move o controle (se houver) sem re-disparar: quando o valor ja
                -- bate, o SetValue da RedzLib nao faz nada, mas garante que a UI
                -- fique coerente em handles de outro tipo.
                if ok and handleCanDrive then
                    local setter = type(handle.SetValue) == "function" and handle.SetValue or handle.Set
                    pcall(setter, handle, value)
                end
            end

            if ok and applied ~= false then
                self.Values[entry.key] = value
                result.applied[#result.applied + 1] = entry.key
                result.count = result.count + 1
            else
                self.LastError = ("apply falhou em '%s'"):format(tostring(entry.key))
                result.failed[#result.failed + 1] = entry.key
            end
        end
    end
    return result
end

-- Le e aplica num passo: e o que um botao "Load" chama.
function Store:Load()
    local config = self:Read()
    return self:Apply(config)
end

return { new = function(opts) return Store.new(opts) end, Store = Store }

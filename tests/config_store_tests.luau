-- ConfigStore: os tres bugs P0 de persistencia, exercitados direto contra o
-- modulo real (nao via backend, pra isolar o store). O harness da um filesystem
-- em memoria (writefile/readfile/isfile em ctx.Env), entao cada cenario de falha
-- (isfile que lanca, writefile que devolve false, read-back diferente) e montado
-- mutando ctx.Env ANTES do load -- a API e capturada como global livre no load.

-- isfile: UMA chamada, sob pcall, e o retorno de verdade usado. A versao antiga
-- chamava isfile duas vezes e a segunda ficava FORA do pcall: um executor que
-- lancasse na segunda derrubava o Load inteiro (e o arquivo nem era lido).
do
    local ctx = sandbox()
    local factory = ctx:Run("src/core/config-store.lua")
    local file = "DepHub_cfg_isfile.json"

    -- Arquivo presente no disco em memoria: o store tem que LER (exists == true).
    ctx.Env.writefile(file, '{"range":640}')
    local store = factory.new({ file = file })
    local config = store:Read()
    check(type(config) == "table" and config.range == 640, "Read le o arquivo quando isfile devolve true")

    -- isfile que LANCA: nao pode propagar o erro; cai no fallback em memoria.
    local ctx2 = sandbox()
    local calls = 0
    ctx2.Env.isfile = function() calls = calls + 1; error("isfile morreu") end
    ctx2.Env.writefile(file, '{"speed":4}')
    local factory2 = ctx2:Run("src/core/config-store.lua")
    local store2 = factory2.new({ file = file })
    store2.Saved = { speed = 9 }
    local ok, result = pcall(function() return store2:Read() end)
    check(ok, "Read com isfile que lanca nao propaga o erro")
    check(calls == 1, "Read chama isfile UMA vez, mesmo quando ela lanca")
    check(type(result) == "table" and result.speed == 9, "isfile que falha cai no snapshot em memoria")
    check(store2.LastError == "isfile recusou", "isfile que falha registra o motivo em LastError")

    -- isfile devolve false/nil: nao le, cai no fallback (sem tocar no disco).
    local store3 = factory.new({ file = "DepHub_cfg_ausente.json" })
    store3.Saved = { range = 111 }
    check(store3:Read().range == 111, "isfile false usa o fallback em memoria")
end

-- Save: writefile pode lancar OU devolver false explicito; e o read-back tem que
-- ser comparado BYTE a BYTE com o que foi escrito, nao so "voltou algo". Cada
-- cenario de falha usa um sandbox NOVO: a API de arquivo e capturada como global
-- livre no load do modulo, entao tem que estar no lugar antes do load.
do
    -- Caminho feliz: grava, le de volta igual, devolve true.
    local ctx = sandbox()
    local factory = ctx:Run("src/core/config-store.lua")
    local store = factory.new({ file = "DepHub_cfg_save.json" })
    store:Set("range", 640)
    store:Set("fruitTrace", true)
    check(store:Save() == true, "Save devolve true quando o arquivo grava e volta igual")

    -- writefile devolve false SEM lancar: e falha mesmo assim.
    local ctxFalse = sandbox()
    local blockedName = "DepHub_cfg_blocked.json"
    ctxFalse.Env.writefile = function(name, data)
        if name == blockedName then return false end
        ctxFalse.Files[name] = tostring(data)
    end
    local factoryFalse = ctxFalse:Run("src/core/config-store.lua")
    local store2 = factoryFalse.new({ file = blockedName })
    store2:Set("range", 1)
    check(store2:Save() == false, "writefile que devolve false sem lancar conta como falha")
    check(store2.LastError == "writefile devolveu false", "o motivo distingue o retorno false do erro")

    -- writefile que LANCA: capturado, motivo claro.
    local ctxBoom = sandbox()
    local boomName = "DepHub_cfg_boom.json"
    ctxBoom.Env.writefile = function(name, data)
        if name == boomName then error("disco cheio") end
        ctxBoom.Files[name] = tostring(data)
    end
    local factoryBoom = ctxBoom:Run("src/core/config-store.lua")
    local store3 = factoryBoom.new({ file = boomName })
    store3:Set("range", 2)
    check(store3:Save() == false, "writefile que lanca nao derruba o Save")
    check(store3.LastError == "writefile recusou a gravacao", "writefile que lanca explica o motivo")

    -- read-back DIFERENTE do escrito (arquivo trocado por outro conteudo no meio):
    -- o Save nao pode dizer "ok".
    local ctxSwap = sandbox()
    local swappedName = "DepHub_cfg_swapped.json"
    ctxSwap.Env.readfile = function(name)
        if name == swappedName then return '{"range":999}' end
        return ctxSwap.Files[name]
    end
    local factorySwap = ctxSwap:Run("src/core/config-store.lua")
    local writeStore = factorySwap.new({ file = swappedName })
    writeStore:Set("range", 3)
    check(writeStore:Save() == false, "read-back diferente do escrito e falha")
    check(writeStore.LastError == "o arquivo nao voltou igual ao que foi gravado", "o mismatch explica o motivo")
end

-- Apply: reporta falha REAL (callback que lanca ou devolve false nao conta como
-- aplicado) e dispara o efeito UMA vez so (o duplo disparo via SetValue).
do
    local ctx = sandbox()
    local factory = ctx:Run("src/core/config-store.lua")
    local store = factory.new({ file = "DepHub_cfg_apply.json" })

    -- Handle de toggle que imita a RedzLib: SetValue dispara o callback quando o
    -- valor muda (WHEN_VALUE_CHANGED). Conta cada disparo.
    local function makeToggleHandle()
        local handle = { Value = false }
        function handle:SetValue(value)
            if self.Value ~= value then
                self.Value = value
                self.Callback(value)
            end
        end
        return handle
    end

    -- Efeito de cada chave conta quantas vezes rodou. O handle de "on" esta
    -- DESLIGADO, entao o SetValue vai mudar e disparar o callback -- que e o
    -- proprio apply. Esperamos UMA execucao (antes eram duas: apply + SetValue).
    local runs = 0
    local handle = makeToggleHandle()
    local function applyOn(value) runs = runs + 1 end
    handle.Callback = applyOn
    store:Register("on", applyOn, handle)
    local result = store:Apply({ on = true })
    check(runs == 1, "Apply dispara o efeito UMA vez quando o controle muda")
    check(result.count == 1 and result.applied[1] == "on", "a chave entra em applied")
    check(handle.Value == true, "o controle foi movido pro valor salvo")

    -- Controle JA no valor: o SetValue da RedzLib nao dispararia nada, entao o
    -- apply roda direto. Ainda exatamente UMA execucao (nao zero).
    runs = 0
    local result2 = store:Apply({ on = true })
    check(runs == 1, "Apply dispara o efeito UMA vez quando o controle ja esta no valor")
    check(result2.count == 1, "a chave continua contada como aplicada")

    -- Callback que LANCA: nao conta como aplicado, entra em failed.
    local store2 = factory.new({ file = "DepHub_cfg_apply2.json" })
    store2:Register("bad", function() error("recusou") end)
    local failedResult = store2:Apply({ bad = true })
    check(failedResult.count == 0 and failedResult.failed[1] == "bad", "callback que lanca entra em failed, nao em applied")
    check(store2.Values.bad == nil, "chave que falhou nao e escrita nos Values")

    -- Callback que devolve FALSE: tambem falha (antes contava como aplicado).
    local store3 = factory.new({ file = "DepHub_cfg_apply3.json" })
    store3:Register("nope", function() return false end)
    local falseResult = store3:Apply({ nope = true })
    check(falseResult.count == 0 and falseResult.failed[1] == "nope", "callback que devolve false conta como falha")

    -- Mix: uma chave boa e uma ruim -- o resultado separa as duas.
    local store4 = factory.new({ file = "DepHub_cfg_apply4.json" })
    store4:Register("good", function() return true end)
    store4:Register("bad", function() return false end)
    local mixed = store4:Apply({ good = 1, bad = 2 })
    check(mixed.count == 1 and mixed.applied[1] == "good", "o resultado separa a chave boa")
    check(#mixed.failed == 1 and mixed.failed[1] == "bad", "o resultado lista a chave ruim")
end

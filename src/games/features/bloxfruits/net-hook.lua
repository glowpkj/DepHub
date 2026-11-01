local game = game
local type = type
local pcall = pcall
local tostring = tostring
local unpack = unpack or table.unpack

-- Net hook -- UM gancho de __namecall compartilhado pelas features de combate.
--
-- O problema que isto resolve: cada feature que precisa ver os remotes de saida
-- do jogo (o silent aim reescrevendo a posicao; a blade hit querendo um hitId
-- valido) acabava instalando o PROPRIO gancho de __namecall. Dois ganchos
-- empilhados na mesma metatable sao duas superficies pro anti-cheat e uma ordem
-- de chamada fragil (quem instalou por ultimo envolve o primeiro). Aqui existe
-- UM gancho so, com varios assinantes: quem instala primeiro e quem instala por
-- ultimo usam a mesma camada, e ela e removida quando o ULTIMO assinante sai
-- (ref-count).
--
-- O gancho faz o trabalho que e de TODOS: detecta Fire/Invoke de remote e captura
-- o hitId do RegisterHit do jogo (o 4. argumento do FireServer) num campo
-- compartilhado. Cada assinante recebe uma callback pra fazer o que e SUA
-- responsabilidade (ex.: reescrever a posicao, forjar um hit) -- e pode reescrever
-- os args ou deixar passar.
--
-- Sem getrawmetatable/newcclosure (executor que nao expoe) o Add recusa e devolve
-- false -- quem chama decide o que fazer (o silent aim recusa o Enable, a blade
-- hit segue sem captura automatica).

local Hook = {}

local mt = nil                 -- a metatable do game (so depois do install)
local original = nil           -- o __namecall original, pra restaurar
local installed = nil          -- a closure QUE INSTALAMOS (pra saber se ainda e a nossa)
local wasReadonly = false
local active = false
local subscribers = {}          -- lista ordenada de {id = n, fn = function}
local nextId = 0

-- O hitId mais recente visto no RegisterHit do jogo (o 4. argumento). Compartilhado
-- entre as features: a blade hit le daqui em vez de esperar alguem chamar SetHitId.
Hook.LastHitId = nil
-- O remote RegisterHit resolvido (pra saber quando um FireServer e o RegisterHit).
Hook.RegisterHit = nil
-- O remote RegisterAttack resolvido.
Hook.RegisterAttack = nil

-- Resolve os remotes de ataque no mesmo caminho do jogo (Modules.Net, com
-- fallback pro Net solto). Devolve true se achou pelo menos o RegisterHit.
function Hook:Resolve()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    local net = (modules and modules:FindFirstChild("Net")) or ReplicatedStorage:FindFirstChild("Net")
    if not net then return false end
    local hit = net:FindFirstChild("RE/RegisterHit")
    if hit then
        Hook.RegisterHit = hit
        Hook.RegisterAttack = net:FindFirstChild("RE/RegisterAttack")
        return true
    end
    return false
end

-- Ha um gancho instalado agora?
function Hook:IsInstalled()
    return active
end

-- A closure que instalamos (os testes de cleanup olham isso). nil se nao ha gancho.
function Hook:Installed()
    return installed
end

-- O __namecall original guardado (pra restaurar).
function Hook:Original()
    return original
end

-- O corpo do gancho: captura o hitId (trabalho comum) e delega a reescrita pros
-- assinantes. Sem pcall em volta (mudaria o caminho da chamada do executor); a
-- delegacao usa pcall por assinante pra um erro deles nao derrubar a chamada.
local function hookBody(...)
    local method = getnamecallmethod()
    local args = { ... }

    local isFire = tostring(method) == "FireServer"
    local isInvoke = tostring(method) == "InvokeServer"

    if isFire or isInvoke then
        local arg1Str = tostring(args[1])
        local isRemote = (arg1Str == "RemoteEvent" or arg1Str == "RemoteFunction")

        if isRemote then
            -- Captura do hitId (trabalho COMUM). O __namecall recebe o proprio
            -- remote como 1. vararg, entao os argumentos reais comecam em args[2]:
            -- o RegisterHit do jogo manda (part, {}, nil, hitId) -> args[2..5], e
            -- o hitId e args[5]. Fica aqui, entao qualquer feature le sem gancho
            -- proprio.
            if Hook.RegisterHit ~= nil and args[1] == Hook.RegisterHit then
                if args[5] ~= nil then Hook.LastHitId = args[5] end
            end

            -- Delega a reescrita pros assinantes, na ordem de inscricao. Cada um
            -- recebe `args` e pode mexer na tabela (a chamada original e feita uma
            -- vez, no fim, com o que sair daqui).
            local snapshot = subscribers
            for i = 1, #snapshot do
                local entry = snapshot[i]
                if entry and type(entry.fn) == "function" then
                    pcall(entry.fn, args)
                end
            end
        end
    end

    return original(unpack(args))
end

-- Instala o gancho, se ainda nao estiver instalado. Devolve true se ha um gancho
-- ativo ao final (instalado agora ou ja antes).
function Hook:_Install()
    if active then return true end
    if type(getrawmetatable) ~= "function" or type(newcclosure) ~= "function" then
        return false
    end
    local metatable = getrawmetatable(game)
    if not metatable then return false end
    local previous = metatable.__namecall
    if type(previous) ~= "function" then return false end

    mt = metatable
    original = previous
    wasReadonly = false
    if type(isreadonly) == "function" then
        wasReadonly = pcall(isreadonly, metatable) and isreadonly(metatable) == true
    end
    if type(setreadonly) == "function" then pcall(setreadonly, metatable, false) end

    mt.__namecall = newcclosure(hookBody)
    installed = mt.__namecall
    active = true
    return true
end

-- Tira o gancho. So restaura o __namecall original se o valor ATUAL ainda for o
-- nosso gancho -- se outro script instalou uma camada depois, a dele fica (apagar
-- aqui destruiria a de outro). Devolve true se removeu.
function Hook:_Uninstall()
    if not active then return false end
    local ourClosure = installed
    active = false
    local metatable, previous = mt, original
    installed, mt, original = nil, nil, nil
    if metatable and previous then
        local restoreReadonly = wasReadonly
        pcall(function()
            if type(setreadonly) == "function" then pcall(setreadonly, metatable, false) end
            -- So restaura se o atual ainda for o NOSSO gancho. Guardamos a
            -- reference ANTES de zerar `installed`, entao a comparacao e honesta.
            if ourClosure == nil or metatable.__namecall == ourClosure then
                metatable.__namecall = previous
            end
            if restoreReadonly and type(setreadonly) == "function" then
                pcall(setreadonly, metatable, true)
            end
        end)
    end
    wasReadonly = false
    return true
end

-- Inscreve um assinante. Instala o gancho se for o primeiro; devolve um id pra
-- cancelar depois, ou nil se nao deu pra instalar.
function Hook:Add(fn)
    if type(fn) ~= "function" then return nil end
    if not self:_Install() then return nil end
    nextId = nextId + 1
    subscribers[#subscribers + 1] = { id = nextId, fn = fn }
    return nextId
end

-- Cancela um assinante pelo id. Quando o ULTIMO sai, o gancho e removido (ref-
-- count): nao fica uma camada pendurada na metatable sem ninguem usando.
function Hook:Remove(id)
    if id == nil then return false end
    for i = #subscribers, 1, -1 do
        if subscribers[i].id == id then
            table.remove(subscribers, i)
            break
        end
    end
    if #subscribers == 0 then self:_Uninstall() end
    return true
end

-- Quantos assinantes ha agora (o ref-count observavel).
function Hook:Count()
    return #subscribers
end

-- O singleton: e UM gancho no processo, entao "instanciar" devolve sempre a
-- mesma tabela. Isto deixa o carregador de infra (que chama factory.new) tratar
-- o net-hook como as outras pecas compartilhadas, sem caso especial.
function Hook.new()
    return Hook
end

return Hook

-- Volleyball 4.2 - PlayerAction / animacoes. Mapa dos remotes e animacoes que o
-- jogo usa para cada acao de quadra, levantado a partir do script local do
-- proprio jogo. Este modulo NAO liga nada sozinho: so publica as acoes para as
-- automacoes do backend (spawn da bola, set, spike, block, bump, dive, serve)
-- usarem o caminho REAL do jogo -- FireServer no PlayerAction e LoadAnimation no
-- Animator -- em vez de fingir o movimento.
--
-- Contrato do jogo (por observacao, pode mudar em patches):
--   PlayerAction = ReplicatedStorage.Remotes.PlayerAction  (RemoteEvent)
--   Animations   = ReplicatedStorage.Assets.Animations
--   PlayerData_m = require(ReplicatedStorage.PlayerData)   (indice das animacoes
--                  equipadas pelo jogador em PlayerData_m.Animations)
--
-- Nomes exatos dos argumentos passados ao FireServer:
--   Set frontal  -> "Setting"
--   Set de costas-> "Backsetting"
--   Spike        -> "Spiking"
--   Block        -> "Blocking"
--   SpawnBall    -> "SpawnBall", "Spawn"
--   Serve        -> "SpawnBall", "Serve"  e depois "Serving"
-- Bump e Dive NAO firem remote: so tocam a animacao (recepcao/mergulho).
--
-- Direcao do set: frontal = animacao Set[.Set][Front]; costas = [Back]. A tabela
-- de indice real vem de PlayerData.Animations.Set (o jogador pode estar com um
-- pack diferente), entao o modulo le esse indice em runtime em vez de fixar um
-- numero -- e cai no indice 1 se nao achar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = {}

Actions.RemotePath = {"Remotes", "PlayerAction"}
Actions.AnimationsPath = {"Assets", "Animations"}
Actions.PlayerDataPath = "PlayerData"
Actions.ServeHitDelay = 1.2 -- segundos entre "SpawnBall/Serve" e "Serving" (igual ao script do jogo)

-- resolve lazily, sem WaitForChild bloqueante (regra do repo)
local function childPath(root, path)
    local node = root
    for _, name in ipairs(path) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

function Actions.GetRemote()
    return childPath(ReplicatedStorage, Actions.RemotePath)
end

function Actions.GetAnimations()
    return childPath(ReplicatedStorage, Actions.AnimationsPath)
end

-- require do PlayerData protegido: em alguns lugares ele nao esta carregado
-- ainda e um erro derrubaria o backend inteiro.
function Actions.GetPlayerData()
    local module = ReplicatedStorage:FindFirstChild(Actions.PlayerDataPath)
    if not module then return nil end
    local ok, data = pcall(require, module)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

function Actions.GetAnimator()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- Le o indice de animacao do jogador; sem PlayerData cai no indice default.
local function animationIndex(data, kind, fallback)
    local animations = data and data.Animations
    local value = animations and animations[kind]
    if type(value) == "number" or type(value) == "string" then return value end
    return fallback
end

-- Navega Animations.<kind>.<index>[.<dir>] com os fallbacks documentados.
local function resolveAnimation(kind, dir, indexFallback)
    local animations = Actions.GetAnimations()
    if not animations then return nil end
    local node = animations:FindFirstChild(kind)
    if not node then return nil end

    local index = animationIndex(Actions.GetPlayerData(), kind, indexFallback)
    local indexed = node:FindFirstChild(tostring(index))
    local target = indexed or node

    if dir then
        return target:FindFirstChild(dir) or target
    end
    return target
end

local function fire(actor, ...)
    local remote = Actions.GetRemote()
    if not remote then return false, "PlayerAction remote ausente" end
    local ok, err = pcall(remote.FireServer, remote, ...)
    if not ok then return false, tostring(err) end
    local log = actor and actor.Log
    if log then log.Actions = log.Actions + 1 end
    return true
end

-- Toca uma animacao no Animator. Devolve a track (ou nil se nao achou/animator
-- ausente). Nao e fatal: a acao remota ainda dispara sem a animacao.
local function play(actor, kind, dir, indexFallback)
    local animator = Actions.GetAnimator()
    if not animator then return nil end
    local animation = resolveAnimation(kind, dir, indexFallback)
    if not animation then return nil end
    local ok, track = pcall(animator.LoadAnimation, animator, animation)
    if not ok or not track then return nil end
    pcall(track.Play, track)
    actor.Playing = track
    actor.LastAnimation = kind
    return track
end

-- === ACOES === (espelham exatamente as funcoes do script do jogo)

-- Set frontal (bloqueio de frente) ou de costas. frontal=true -> Front/Setting.
function Actions.Set(actor, frontal)
    local isFront = frontal ~= false
    play(actor, "Set", isFront and "Front" or "Back", 1)
    return fire(actor, isFront and "Setting" or "Backsetting")
end

function Actions.Spike(actor)
    play(actor, "Spike", "Spike", 1)
    return fire(actor, "Spiking")
end

function Actions.Block(actor)
    play(actor, "Block", nil, 1)
    return fire(actor, "Blocking")
end

-- Bump (recepcao): so animacao, sem remote.
function Actions.Bump(actor)
    play(actor, "Receive", nil, 1)
    return true
end

-- Dive (mergulho): so animacao, sem remote.
function Actions.Dive(actor)
    play(actor, "Dive", nil, 1)
    return true
end

function Actions.SpawnBall(actor)
    return fire(actor, "SpawnBall", "Spawn")
end

-- Serve: spawna a bola de saque, espera o delay do jogo e fire "Serving" com a
-- animacao de hit. Assincrono por causa do wait, por isso roda em task.spawn e
-- guarda a task no ator para o Destroy poder cancelar.
function Actions.Serve(actor)
    local started, err = fire(actor, "SpawnBall", "Serve")
    if not started then return false, err end
    actor.Serving = true
    actor.ServeTask = task.spawn(function()
        task.wait(Actions.ServeHitDelay)
        if actor.Destroyed or not actor.Serving then return end
        play(actor, "Serve", "Hit", 1)
        fire(actor, "Serving")
    end)
    return true
end

function Actions.Cancel(actor)
    actor.Serving = false
    if actor.ServeTask then
        pcall(task.cancel, actor.ServeTask)
        actor.ServeTask = nil
    end
end

-- Diagnostico: o que existe de fato no jogo, para o Debug tab. Nao muda estado.
function Actions.Inspect()
    local data = Actions.GetPlayerData()
    return {
        Remote = Actions.GetRemote() ~= nil,
        Animations = Actions.GetAnimations() ~= nil,
        PlayerData = data ~= nil,
        Animator = Actions.GetAnimator() ~= nil,
        SetIndex = animationIndex(data, "Set", 1),
    }
end

return Actions

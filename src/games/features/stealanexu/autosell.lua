-- Steal An Exu -- Auto Sell All (vende TODOS os Exus de uma vez).
--
-- O jogo expoe um botao "Vender Todos" na propria GUI:
--
--     game.Players.LocalPlayer.PlayerGui.Menus["Vender Todos"].Button
--
-- Clicar nele vende os Exus do jogador. O botao e' um GuiButton de verdade, entao
-- o jeito de acionar e' o mesmo de um clique: disparar a ativacao do GuiButton
-- (gui:Activate()) ou, se o executor tiver, o click virtual no objeto.
--
-- E' uma ACAO de passada unica (botao no painel), nao um loop: chama uma vez e
-- pronto. Se o jogo so vender um Exu por clique, a gente repete ate o botao
-- parar de mudar / um teto de tentativas, pra garantir "todos".
--
-- API: AutoSell.new(ctx) -> obj com Sell() / StartSell() / Destroy() e o campo
--      LastCounts.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local table = table
local select = select

-- Caminho da GUI de venda, a partir do PlayerGui do LocalPlayer:
--   PlayerGui.Menus["Vender Todos"].Button
local SELL_FOLDER = "Menus"
local SELL_BUTTON_NAME = "Vender Todos"

-- Quanto esperar entre duas tentativas de venda (o servidor processa e atualiza a
-- lista). Mesmo tempo pedido pelo usuario no roubo: 0.3.
local SELL_INTERVAL = 0.3

-- Teto de cliques numa passada. O botao "Vender Todos" em geral vende tudo de
-- uma vez (1 clique); o teto so existe pra o caso do jogo vender um-por-um.
local MAX_SELLS = 30

local AutoSell = {}
AutoSell.__index = AutoSell

-- --- Debug ----------------------------------------------------------------

AutoSell.DebugEnabled = true
local DEBUG_TAG = "[StealAnExu]"
local env = type(getgenv) == "function" and getgenv() or _G

local function debugLog(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = DEBUG_TAG .. " Sell: " .. table.concat(parts, " ")
    self.DebugLog = self.DebugLog or {}
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 200 then table.remove(self.DebugLog, 1) end
    if AutoSell.DebugEnabled then
        print(message)
        local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
        if type(diag) == "table" and type(diag.Note) == "function" then
            pcall(diag.Note, diag, message)
        end
    end
end

-- --- Construtor -----------------------------------------------------------

function AutoSell.new(ctx)
    local self = setmetatable({}, AutoSell)
    self.Ctx = ctx or {}
    self.LastError = nil
    self.Destroyed = false
    self.Thread = nil
    self.DebugLog = {}
    self.LastCounts = nil
    return self
end

function AutoSell:Logs()
    return self.DebugLog or {}
end

-- --- O alvo (o botao da GUI) ----------------------------------------------

-- O GuiButton "Vender Todos" do jogador, ou nil + motivo. Varre o caso comum
-- (Menus.<nome>.Button) e tambem aceita o botao direto em Menus, caso o jogo
-- mude a estrutura.
function AutoSell:Button()
    local player = game:GetService("Players").LocalPlayer
    if not player then return nil, "sem LocalPlayer" end

    -- Caminho real (o que o usuario mostrou): player.PlayerGui.
    local gui = player.PlayerGui
    if not gui then
        -- Fallback: procura o PlayerGui entre os filhos do jogador.
        local found = player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
        gui = found
    end
    if not gui then return nil, "sem PlayerGui" end

    local folder = gui:FindFirstChild(SELL_FOLDER)
    local node = folder and folder:FindFirstChild(SELL_BUTTON_NAME)
    -- Caminho esperado: Menus["Vender Todos"].Button (um GuiButton).
    local button = node and node:FindFirstChild("Button")
    if button then return button end
    -- Fallbacks: o proprio node ja sendo o botao, ou o botao solto.
    if node and (node:IsA("GuiButton") or type(node.Activate) == "function") then return node end
    local loose = gui:FindFirstChild("Vender Todos", true)
    if loose then
        local inner = loose:FindFirstChild("Button")
        if inner then return inner end
        if loose:IsA("GuiButton") then return loose end
    end
    return nil, "botao 'Vender Todos' nao encontrado no PlayerGui"
end

-- Um clique no botao da GUI. Prefere o click virtual do executor (age como um
-- clique real no GuiButton); senao usa o :Activate() do GuiButton, que e' o
-- caminho oficial pra acionar sem mouse.
function AutoSell:Click(button)
    if not button then return false end

    -- 1) clique virtual no objeto, se o executor expuser (mesmo efeito do mouse).
    local virtual = type(firesignal) == "function" and button.MouseButton1Click
    if virtual then
        local ok = pcall(firesignal, button.MouseButton1Click)
        if ok then return true end
    end

    -- 2) caminho oficial do GuiButton.
    if type(button.Activate) == "function" then
        local ok = pcall(function() button:Activate() end)
        if ok then return true end
    end

    -- 3) ultimo caso: um objeto com :Click() (alguns jogos custom).
    if type(button.Click) == "function" then
        local ok = pcall(function() button:Click() end)
        if ok then return true end
    end
    return false
end

-- --- A venda --------------------------------------------------------------

-- Uma passada: clica "Vender Todos" algumas vezes (com respiro), no caso do jogo
-- vender um por um; para quando o botao sumir/ficar inativo ou bater o teto.
function AutoSell:Sell()
    if self.Destroyed then return false, 0 end

    local button, reason = self:Button()
    if not button then
        self.LastError = reason
        debugLog(self, "ABORTA:", tostring(reason))
        return false, 0
    end

    debugLog(self, "vendendo via", button:GetFullName())
    local sold = 0
    for attempt = 1, MAX_SELLS do
        local current, currentReason = self:Button()
        if not current then
            -- O botao sumiu (o menu fechou porque nao tem mais nada a vender).
            debugLog(self, "menu fechou apos", sold, "clique(s) (", tostring(currentReason), ")")
            break
        end
        local ok = self:Click(current)
        if not ok then
            self.LastError = "falha ao clicar em Vender Todos"
            debugLog(self, "clique falhou em", current:GetFullName())
            break
        end
        sold = sold + 1
        task.wait(SELL_INTERVAL)
    end

    self.LastCounts = {sold = sold}
    debugLog(self, "=== fim da venda: ", sold, "clique(s) ===")
    return sold > 0, sold
end

-- O botao do painel chama isto: sobe a venda numa thread propria pra nao travar o
-- clique. Uma passada por vez.
function AutoSell:StartSell()
    if self.Destroyed then
        debugLog(self, "venda ignorada: feature destruida")
        return false
    end
    if self.Thread then
        debugLog(self, "venda ignorada: ja tem uma passada rodando")
        return false
    end
    debugLog(self, "venda iniciada (botao)")
    self.Thread = task.spawn(function()
        local ok, err = pcall(function() return self:Sell() end)
        if not ok then
            self.LastError = tostring(err)
            debugLog(self, "VENDA ERRO:", tostring(err))
        end
        self.Thread = nil
        debugLog(self, "venda terminada")
    end)
    return true
end

function AutoSell:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    if self.Thread then
        pcall(task.cancel, self.Thread)
        self.Thread = nil
    end
    self.DebugLog = {}
end

-- Devolve a fabrica.
return AutoSell

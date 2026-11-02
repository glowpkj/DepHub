-- Steal An Exu -- Auto Sell toggle.
-- Teleporta uma vez para workspace.Map.Plaza.Part e permanece nessa area.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local table = table
local select = select

local SELL_INTERVAL = 1
local RETRY_INTERVAL = 1
local TELEPORT_HEIGHT = 3

local AutoSell = {}
AutoSell.__index = AutoSell
AutoSell.DebugEnabled = true

local DEBUG_TAG = "[StealAnExu]"
local env = type(getgenv) == "function" and getgenv() or _G

local function debugLog(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = DEBUG_TAG .. " Sell: " .. table.concat(parts, " ")
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

function AutoSell.new(ctx)
    return setmetatable({
        Ctx = ctx or {},
        Enabled = false,
        Destroyed = false,
        Thread = nil,
        RunId = 0,
        DebugLog = {},
        LastError = nil,
        ClickCount = 0,
        AtPlaza = false,
    }, AutoSell)
end

function AutoSell:IsEnabled()
    return self.Enabled == true
end

function AutoSell:Logs()
    return self.DebugLog
end

function AutoSell:Button()
    local player = game:GetService("Players").LocalPlayer
    if not player then return nil, "sem LocalPlayer" end

    local playerGui = player.PlayerGui or player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
    if not playerGui then return nil, "sem PlayerGui" end

    local menus = playerGui:FindFirstChild("Menus")
    local sellPanel = menus and menus:FindFirstChild("Vender Todos")
    if not sellPanel then return nil, 'Menus["Vender Todos"] nao encontrado' end

    local button = sellPanel:FindFirstChild("Button")
    if not button then return nil, 'Vender Todos.Button nao encontrado' end

    local face = button:FindFirstChild("Face")
    if not face then return nil, 'Vender Todos.Button.Face nao encontrado' end

    if face:IsA("GuiButton") then return face end
    if button:IsA("GuiButton") then return button end

    local nested = face:FindFirstChildWhichIsA("GuiButton", true)
    if nested then return nested end

    return nil, "Face e Button nao sao GuiButton"
end

function AutoSell:Click(button)
    if not button then return false, "botao ausente" end
    if not button:IsA("GuiButton") then return false, "alvo nao e GuiButton" end

    if type(firesignal) == "function" then
        local okSignal, signal = pcall(function()
            return button.MouseButton1Click
        end)
        if okSignal and signal then
            local okFire = pcall(firesignal, signal)
            if okFire then return true end
        end

        local okActivated, activated = pcall(function()
            return button.Activated
        end)
        if okActivated and activated then
            local okFire = pcall(firesignal, activated)
            if okFire then return true end
        end
    end

    local okActivate = pcall(function()
        button:Activate()
    end)
    if okActivate then return true end

    return false, "nao foi possivel acionar o GuiButton"
end

function AutoSell:_plazaPart()
    local workspace = game:GetService("Workspace")
    local map = workspace:FindFirstChild("Map")
    local plaza = map and map:FindFirstChild("Plaza")
    local part = plaza and plaza:FindFirstChild("Part")
    if not part then return nil, "workspace.Map.Plaza.Part nao encontrado" end
    return part
end

function AutoSell:_teleport()
    local part, reason = self:_plazaPart()
    if not part then return false, reason end

    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false, "HumanoidRootPart nao encontrado" end

    local height = TELEPORT_HEIGHT
    pcall(function()
        height = (part.Size.Y / 2) + TELEPORT_HEIGHT
    end)

    local ok, err = pcall(function()
        root.CFrame = CFrame.new(part.Position + Vector3.new(0, height, 0))
    end)
    if not ok then return false, tostring(err) end

    self.AtPlaza = true
    debugLog(self, "teleportado para", part:GetFullName(), "- permanecendo na area")
    return true
end

function AutoSell:MoveToPlaza()
    local ctx = self.Ctx
    local acquired = false
    if type(ctx.AcquireMovement) == "function" then
        local ok, result = pcall(ctx.AcquireMovement, self)
        if not ok or result ~= true then
            return false, "movimento ocupado por outra feature"
        end
        acquired = true
    end

    local ok, result, reason = pcall(function()
        local moved, moveError = self:_teleport()
        return moved, moveError
    end)

    if acquired and type(ctx.ReleaseMovement) == "function" then
        pcall(ctx.ReleaseMovement, self)
    end

    if not ok then return false, tostring(result) end
    return result == true, reason
end

function AutoSell:_loop(runId)
    debugLog(self, "Auto Sell: ON")

    while self.Enabled and not self.Destroyed and self.RunId == runId and not self.AtPlaza do
        local moved, reason = self:MoveToPlaza()
        if moved then
            task.wait(0.25)
            break
        end

        self.LastError = reason
        debugLog(self, "aguardando Plaza:", tostring(reason))
        task.wait(reason == "movimento ocupado por outra feature" and 0.05 or RETRY_INTERVAL)
    end

    while self.Enabled and not self.Destroyed and self.RunId == runId and self.AtPlaza do
        local button, reason = self:Button()
        if button then
            local ok, clickError = self:Click(button)
            if ok then
                self.ClickCount = self.ClickCount + 1
                debugLog(self, "clique enviado via", button:GetFullName(), "(total:", self.ClickCount .. ")")
            else
                self.LastError = clickError
                debugLog(self, "falha no clique:", tostring(clickError))
            end
            task.wait(SELL_INTERVAL)
        else
            self.LastError = reason
            debugLog(self, "aguardando botao:", tostring(reason))
            task.wait(2)
        end
    end

    if self.RunId == runId then
        self.Thread = nil
        debugLog(self, "Auto Sell: loop parado")
    end
end

function AutoSell:SetEnabled(enabled)
    if self.Destroyed then return false end
    enabled = enabled == true
    if enabled == self.Enabled then return true end

    self.Enabled = enabled
    self.RunId = self.RunId + 1
    local runId = self.RunId

    if enabled then
        self.ClickCount = 0
        self.AtPlaza = false
        self.LastError = nil
        self.Thread = task.spawn(function()
            local ok, err = pcall(function()
                self:_loop(runId)
            end)
            if self.RunId == runId then
                self.Thread = nil
                if not ok then
                    self.Enabled = false
                    self.LastError = tostring(err)
                    debugLog(self, "ERRO:", tostring(err))
                end
            end
        end)
    else
        debugLog(self, "Auto Sell: desligado pelo toggle")
    end

    return true
end

function AutoSell:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    self.RunId = self.RunId + 1
    self.DebugLog = {}
end

return AutoSell

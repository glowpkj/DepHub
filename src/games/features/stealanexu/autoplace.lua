-- Steal An Exu -- Auto Place Exu.
-- Coloca apenas Tools cujo terreiro de origem esteja selecionado.

local game = game
local task = task
local type = type
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local table = table
local math = math

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G

local SPACING = 8
local PLACE_DELAY = 0.3
local SCAN_DELAY = 0.6

local AutoPlace = {}
AutoPlace.__index = AutoPlace

local function log(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = "[StealAnExu] Auto Place: " .. table.concat(parts, " ")
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 100 then table.remove(self.DebugLog, 1) end
    print(message)
    local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if type(diag) == "table" and type(diag.Note) == "function" then
        pcall(diag.Note, diag, message)
    end
end

local function selectedSet(names)
    local result = {}
    for _, name in ipairs(type(names) == "table" and names or {}) do
        result[tostring(name)] = true
    end
    return result
end

local function attribute(instance, names)
    if not instance then return nil end
    for _, name in ipairs(names) do
        local ok, value = pcall(function() return instance:GetAttribute(name) end)
        if ok and value ~= nil then return value end
    end
    return nil
end

function AutoPlace.new(ctx, options)
    options = options or {}
    return setmetatable({
        Ctx = ctx or {},
        Enabled = false,
        Destroyed = false,
        Thread = nil,
        RunId = 0,
        Terreiros = selectedSet(options.terreiros),
        Placed = {},
        NextSlot = 0,
        LastError = nil,
        LastStatus = "idle",
        DebugLog = {},
        ConfigModule = options.config,
        Remote = options.remote,
        Config = nil,
        Pen = nil,
    }, AutoPlace)
end

function AutoPlace:IsEnabled()
    return self.Enabled == true
end

function AutoPlace:Logs()
    return self.DebugLog
end

function AutoPlace:SetTerreiros(names)
    if type(names) ~= "table" then return false end
    local available = {}
    local list = type(self.Ctx.Terreiros) == "function" and self.Ctx.Terreiros() or {}
    for _, name in ipairs(list) do available[tostring(name)] = true end

    local selected = {}
    for _, name in ipairs(names) do
        name = tostring(name)
        if available[name] then selected[name] = true end
    end

    self.Terreiros = selected
    self.LastStatus = "selection updated"
    return true
end

function AutoPlace:SelectedTerreiros()
    local result = {}
    local list = type(self.Ctx.Terreiros) == "function" and self.Ctx.Terreiros() or {}
    for _, name in ipairs(list) do
        if self.Terreiros[name] then result[#result + 1] = name end
    end
    return result
end

function AutoPlace:_gameConfig()
    if type(self.ConfigModule) == "table" then return self.ConfigModule end

    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local module = shared and shared:FindFirstChild("Config")
    if not module then return nil, "ReplicatedStorage.Shared.Config nao encontrado" end

    local ok, result = pcall(require, module)
    if not ok or type(result) ~= "table" then
        return nil, "nao foi possivel carregar Shared.Config: " .. tostring(result)
    end

    self.ConfigModule = result
    return result
end

function AutoPlace:_pen()
    local pen = type(self.Ctx.MyPen) == "function" and self.Ctx.MyPen() or nil
    if not pen then
        local penName = LocalPlayer and LocalPlayer:GetAttribute("PenName")
        local map = game:GetService("Workspace"):FindFirstChild("Map")
        local pens = map and map:FindFirstChild("Pens")
        pen = pens and penName and pens:FindFirstChild(tostring(penName))
    end
    if not pen then return nil, "base do jogador nao encontrada" end
    return pen
end

function AutoPlace:_setup()
    local configModule, configError = self:_gameConfig()
    if not configModule then return nil, configError end

    local pen, penError = self:_pen()
    if not pen then return nil, penError end

    local index = pen:GetAttribute("Index")
    local penConfig = configModule.Pens and (configModule.Pens[index] or configModule.Pens[tostring(index)] or configModule.Pens[tonumber(index)])
    local penSize = tonumber(configModule.PEN_SIZE)
    if type(penConfig) ~= "table" or not penSize or not tonumber(penConfig.X) or not tonumber(penConfig.Z) then
        return nil, "config da base invalida (Pens[Index]/PEN_SIZE)"
    end

    local remote = self.Remote
    if not remote then
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        remote = remotes and remotes:FindFirstChild("PlaceExu")
    end
    if not remote or type(remote.FireServer) ~= "function" then
        return nil, "ReplicatedStorage.Remotes.PlaceExu nao encontrado"
    end

    self.Pen = pen
    self.Config = {X = tonumber(penConfig.X), Z = tonumber(penConfig.Z), Half = penSize / 2 - 3}
    self.Remote = remote
    return true
end

function AutoPlace:_inventoryTools()
    local result = {}
    local seen = {}
    local backpack = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack"))
    local character = LocalPlayer and LocalPlayer.Character

    local function collect(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") then
                local id = attribute(child, {"ExuId"})
                if id ~= nil then
                    local key = tostring(id)
                    if not seen[key] then
                        seen[key] = true
                        result[#result + 1] = {tool = child, id = id, key = key}
                    end
                end
            end
        end
    end

    collect(backpack)
    collect(character)
    return result
end

function AutoPlace:_sourceTerreiro(tool, id)
    local sourceMap = env.__DEPHUB_STEALANEXU_EXU_SOURCES
    if type(sourceMap) == "table" and sourceMap[tostring(id)] then
        return tostring(sourceMap[tostring(id)])
    end

    local value = attribute(tool, {"Terreiro", "TerreiroName", "SourceTerreiro", "OriginTerreiro"})
    if value ~= nil then return tostring(value) end

    return nil
end

function AutoPlace:_nextPosition()
    if not self.Config then return nil, "config da base nao carregada" end

    local half = self.Config.Half
    local cols = math.floor((half * 2) / SPACING)
    if cols < 1 then return nil, "area da base pequena demais para a grade" end

    local capacity = cols * cols
    if self.NextSlot >= capacity then return nil, "grade da base cheia" end

    local col = self.NextSlot % cols
    local row = math.floor(self.NextSlot / cols)
    local position = Vector3.new(
        self.Config.X - half + SPACING / 2 + col * SPACING,
        0.3,
        self.Config.Z - half + SPACING / 2 + row * SPACING
    )
    self.NextSlot += 1
    return position
end

function AutoPlace:PlaceOnce()
    if self.Destroyed then return 0, "feature destruida" end

    local selectedCount = 0
    for _ in pairs(self.Terreiros) do selectedCount += 1 end
    if selectedCount == 0 then
        self.LastError = "nenhum Terreiro selecionado para colocar"
        return 0, self.LastError
    end

    local ready, setupError = self:_setup()
    if not ready then
        self.LastError = setupError
        return 0, setupError
    end

    local placedNow = 0
    local tools = self:_inventoryTools()
    for _, entry in ipairs(tools) do
        if self.Destroyed or (self.Enabled == false and self.Thread ~= nil) then break end
        if not self.Placed[entry.key] then
            local source = self:_sourceTerreiro(entry.tool, entry.id)
            if source and self.Terreiros[source] then
                local position, positionError = self:_nextPosition()
                if not position then
                    self.LastError = positionError
                    break
                end

                local ok, err = pcall(function()
                    self.Remote:FireServer(entry.id, position)
                end)
                if ok then
                    self.Placed[entry.key] = true
                    placedNow += 1
                    log(self, "pedido enviado:", entry.key, "origem:", source, "slot:", self.NextSlot)
                    task.wait(PLACE_DELAY)
                else
                    self.LastError = tostring(err)
                    log(self, "falha ao colocar", entry.key, self.LastError)
                end
            end
        end
    end

    if placedNow > 0 then
        self.LastError = nil
        self.LastStatus = "placed " .. tostring(placedNow)
    elseif #tools == 0 then
        self.LastStatus = "waiting for Exu tools"
    else
        self.LastStatus = "no matching selected tools"
    end

    return placedNow
end

function AutoPlace:_loop(runId)
    log(self, "monitor iniciado.")
    while self.Enabled and not self.Destroyed and self.RunId == runId do
        local ok, err = pcall(function() self:PlaceOnce() end)
        if not ok then
            self.LastError = tostring(err)
            log(self, "erro no ciclo:", self.LastError)
        end
        task.wait(SCAN_DELAY)
    end

    if self.RunId == runId then self.Thread = nil end
end

function AutoPlace:SetEnabled(enabled)
    if self.Destroyed then return false end
    enabled = enabled == true
    if enabled == self.Enabled then return true end

    self.Enabled = enabled
    self.RunId += 1
    local runId = self.RunId

    if enabled then
        self.LastError = nil
        self.LastStatus = "monitoring"
        self.Thread = task.spawn(function()
            local ok, err = pcall(function() self:_loop(runId) end)
            if not ok and self.RunId == runId then
                self.Enabled = false
                self.Thread = nil
                self.LastError = tostring(err)
                self.LastStatus = "error"
                log(self, "loop interrompido:", self.LastError)
            end
        end)
    else
        self.LastStatus = "idle"
        log(self, "desligado.")
    end

    return true
end

function AutoPlace:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    self.RunId += 1
    self.DebugLog = {}
end

return AutoPlace

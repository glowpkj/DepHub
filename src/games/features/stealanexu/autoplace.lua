local game = game
local task = task
local type = type
local typeof = typeof or function(value) return type(value) end
local tostring = tostring
local tonumber = tonumber
local pcall = pcall
local table = table
local math = math
local select = select
local pairs = pairs
local ipairs = ipairs
local os = os

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local env = type(getgenv) == "function" and getgenv() or _G

local SPACING = 8
local PLACE_DELAY = 0.3
local SCAN_DELAY = 0.6
local DEBUG_INTERVAL = 5
local CONFIRM_TIMEOUT = 8

local AutoPlace = {}
AutoPlace.__index = AutoPlace

local function log(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = "[StealAnExu] Auto Place: " .. table.concat(parts, " ")
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 250 then table.remove(self.DebugLog, 1) end
    print(message)
    local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
    if type(diag) == "table" and type(diag.Note) == "function" then
        pcall(diag.Note, diag, message)
    end
end

local function listToText(values)
    if type(values) ~= "table" or #values == 0 then return "[]" end
    return "[" .. table.concat(values, ", ") .. "]"
end

local function selectedSet(names)
    local result = {}
    for _, name in ipairs(type(names) == "table" and names or {}) do
        result[tostring(name)] = true
    end
    return result
end

local function sortedSet(set)
    local result = {}
    for name, enabled in pairs(type(set) == "table" and set or {}) do
        if enabled then result[#result + 1] = tostring(name) end
    end
    table.sort(result)
    return result
end

local function attribute(instance, names)
    if not instance then return nil end
    for _, name in ipairs(names) do
        local ok, value = pcall(function() return instance:GetAttribute(name) end)
        if ok and value ~= nil then return value, name end
    end
    return nil
end

local function instanceName(instance)
    if not instance then return "nil" end
    local ok, value = pcall(function() return instance:GetFullName() end)
    if ok and value then return value end
    local okName, name = pcall(function() return instance.Name end)
    return okName and tostring(name) or tostring(instance)
end

local function penCoordinates(value, depth)
    if value == nil or (depth or 0) > 3 then return nil, nil, "nil" end
    local valueType = typeof(value)

    if valueType == "Vector3" then
        return tonumber(value.X), tonumber(value.Z), valueType
    elseif valueType == "Vector2" then
        return tonumber(value.X), tonumber(value.Y), valueType
    elseif valueType == "CFrame" then
        local position = value.Position
        return tonumber(position.X), tonumber(position.Z), valueType
    end

    if type(value) == "table" then
        local nested = value.Position or value.position or value.CFrame or value.cframe
            or value.Center or value.center or value.Origin or value.origin
        if nested ~= nil then
            local x, z, nestedType = penCoordinates(nested, (depth or 0) + 1)
            if x ~= nil and z ~= nil then
                return x, z, valueType .. "." .. nestedType
            end
        end

        local x = tonumber(value.X or value.x or value[1])
        local z = tonumber(value.Z or value.z or value[3])
        if z == nil then z = tonumber(value.Y or value.y or value[2]) end
        return x, z, valueType
    end

    return nil, nil, valueType
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
        Sent = {},
        NextSlot = 0,
        LastError = nil,
        LastStatus = "idle",
        LastSetupError = nil,
        LastDiagnosticAt = 0,
        LastDiagnosticSignature = nil,
        LastInventoryStats = {},
        ScanCount = 0,
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
    if type(names) ~= "table" then
        log(self, "selecao invalida; esperado array, recebido", type(names))
        return false
    end

    local available = {}
    local list = type(self.Ctx.Terreiros) == "function" and self.Ctx.Terreiros() or {}
    for _, name in ipairs(list) do available[tostring(name)] = true end

    local selected = {}
    local rejected = {}
    for _, name in ipairs(names) do
        name = tostring(name)
        if available[name] then
            selected[name] = true
        else
            rejected[#rejected + 1] = name
        end
    end

    self.Terreiros = selected
    self.LastStatus = "selection updated"
    self.LastDiagnosticSignature = nil
    log(self, "terreiros selecionados:", listToText(sortedSet(selected)))
    if #rejected > 0 then
        log(self, "opcoes ignoradas porque nao existem no mapa:", listToText(rejected))
    end
    if #sortedSet(selected) == 0 then
        log(self, "ATENCAO: nenhum Terreiro valido selecionado; nada sera colocado.")
    end
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
    if type(self.ConfigModule) == "table" then
        return self.ConfigModule
    end

    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if not shared then
        return nil, "ReplicatedStorage.Shared nao encontrado"
    end

    local module = shared:FindFirstChild("Config")
    if not module then
        return nil, "ReplicatedStorage.Shared.Config nao encontrado"
    end

    local ok, result = pcall(require, module)
    if not ok then
        return nil, "require(Shared.Config) falhou: " .. tostring(result)
    end
    if type(result) ~= "table" then
        return nil, "Shared.Config retornou " .. type(result) .. ", esperado table"
    end

    self.ConfigModule = result
    local penCount = 0
    for _ in pairs(type(result.Pens) == "table" and result.Pens or {}) do penCount += 1 end
    log(self, "Shared.Config carregado; PEN_SIZE =", result.PEN_SIZE, "| Pens =", penCount)
    return result
end

function AutoPlace:_pen()
    if type(self.Ctx.MyPen) == "function" then
        local ok, pen, reason = pcall(self.Ctx.MyPen)
        if ok and pen then
            return pen, "Owner"
        end
        if not ok then
            log(self, "Ctx.MyPen falhou:", tostring(pen))
        elseif reason then
            log(self, "Ctx.MyPen:", tostring(reason))
        end
    end

    local penName = attribute(LocalPlayer, {"PenName"})
    local map = Workspace:FindFirstChild("Map")
    local pens = map and map:FindFirstChild("Pens")
    if not pens then
        return nil, "workspace.Map.Pens nao encontrado"
    end
    if penName == nil then
        return nil, "LocalPlayer sem atributo PenName e busca por Owner nao encontrou base"
    end

    local pen = pens:FindFirstChild(tostring(penName))
    if not pen then
        return nil, "base PenName='" .. tostring(penName) .. "' nao encontrada em workspace.Map.Pens"
    end
    return pen, "PenName"
end

function AutoPlace:_setup()
    local configModule, configError = self:_gameConfig()
    if not configModule then return nil, configError end

    if type(configModule.Pens) ~= "table" then
        return nil, "Shared.Config.Pens nao e uma tabela"
    end

    local pen, penSource = self:_pen()
    if not pen then return nil, penSource end

    local index = attribute(pen, {"Index"})
    if index == nil then
        return nil, "base " .. instanceName(pen) .. " nao possui atributo Index"
    end

    local penConfig = configModule.Pens[index]
        or configModule.Pens[tostring(index)]
        or configModule.Pens[tonumber(index)]
    if penConfig == nil then
        local available = {}
        for key in pairs(configModule.Pens) do available[#available + 1] = tostring(key) end
        table.sort(available)
        return nil, "Pens[" .. tostring(index) .. "] nao existe em Shared.Config.Pens; indices: " .. listToText(available)
    end

    local penSize = tonumber(configModule.PEN_SIZE)
    local x, z, penFormat = penCoordinates(penConfig)
    if not penSize or x == nil or z == nil then
        return nil, "config da base invalida: PEN_SIZE=" .. tostring(configModule.PEN_SIZE)
            .. " formato=" .. tostring(penFormat) .. " X=" .. tostring(x) .. " Z=" .. tostring(z)
    end

    local remote = self.Remote
    if not remote then
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if not remotes then return nil, "ReplicatedStorage.Remotes nao encontrado" end
        remote = remotes:FindFirstChild("PlaceExu")
    end
    if not remote then return nil, "ReplicatedStorage.Remotes.PlaceExu nao encontrado" end

    local fireTypeOk, fireType = pcall(function() return type(remote.FireServer) end)
    if not fireTypeOk or fireType ~= "function" then
        return nil, "PlaceExu existe, mas FireServer nao e function (tipo " .. tostring(fireType) .. ")"
    end

    self.Pen = pen
    self.Config = {X = x, Z = z, Half = penSize / 2 - 3, PenSize = penSize, Index = index, Format = penFormat}
    self.Remote = remote

    local signature = table.concat({
        instanceName(pen), tostring(index), tostring(x), tostring(z),
        tostring(penSize), instanceName(remote)
    }, "|")
    if signature ~= self.LastSetupError then
        log(self, "setup OK; base =", instanceName(pen), "| origem =", penSource,
            "| Index =", index, "| centro =", x .. "," .. z, "| formato =", penFormat, "| PEN_SIZE =", penSize,
            "| remote =", instanceName(remote))
        self.LastSetupError = signature
    end
    return true
end

function AutoPlace:_inventoryTools()
    local result = {}
    local seen = {}
    local stats = {
        backpackFound = false,
        characterFound = false,
        totalTools = 0,
        exuTools = 0,
        missingExuId = 0,
        duplicateIds = 0,
        backpackExus = 0,
        characterExus = 0,
        names = {},
    }

    local backpack = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack"))
    local character = LocalPlayer and LocalPlayer.Character
    stats.backpackFound = backpack ~= nil
    stats.characterFound = character ~= nil

    local function collect(container, containerName)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") then
                stats.totalTools += 1
                local id = attribute(child, {"ExuId"})
                if id == nil then
                    stats.missingExuId += 1
                    if #stats.names < 12 then
                        stats.names[#stats.names + 1] = child.Name .. "(sem ExuId)"
                    end
                else
                    stats.exuTools += 1
                    if containerName == "Backpack" then
                        stats.backpackExus += 1
                    else
                        stats.characterExus += 1
                    end
                    local key = tostring(id)
                    if not seen[key] then
                        seen[key] = true
                        result[#result + 1] = {
                            tool = child,
                            id = id,
                            key = key,
                            container = containerName,
                        }
                        if #stats.names < 12 then
                            stats.names[#stats.names + 1] = child.Name .. "(ExuId=" .. key .. ")"
                        end
                    else
                        stats.duplicateIds += 1
                    end
                end
            end
        end
    end

    collect(backpack, "Backpack")
    collect(character, "Character")
    stats.uniqueExuIds = #result
    self.LastInventoryStats = stats
    return result
end

function AutoPlace:_sourceTerreiro(tool, id)
    local sourceMap = env.__DEPHUB_STEALANEXU_EXU_SOURCES
    if type(sourceMap) == "table" and sourceMap[tostring(id)] then
        return tostring(sourceMap[tostring(id)]), "sourceMap"
    end

    local value, attributeName = attribute(tool, {"Terreiro", "TerreiroName", "SourceTerreiro", "OriginTerreiro"})
    if value ~= nil then
        local name = tostring(value)
        local numeric = tonumber(name)
        if numeric then name = "Terreiro" .. tostring(math.floor(numeric)) end
        return name, attributeName
    end

    local index, indexAttribute = attribute(tool, {"TerreiroId", "TerreiroIndex", "OriginTerreiroId"})
    if index ~= nil then
        local numeric = tonumber(index)
        if numeric then return "Terreiro" .. tostring(math.floor(numeric)), indexAttribute end
        return tostring(index), indexAttribute
    end

    return nil, "origem-nao-mapeada"
end

function AutoPlace:_nextPosition()
    if not self.Config then return nil, "config da base nao carregada" end

    local half = self.Config.Half
    local cols = math.floor((half * 2) / SPACING)
    if cols < 1 then return nil, "area da base pequena demais para a grade" end

    local capacity = cols * cols
    if self.NextSlot >= capacity then
        return nil, "grade da base cheia (" .. tostring(capacity) .. " slots)"
    end

    local slot = self.NextSlot
    local col = slot % cols
    local row = math.floor(slot / cols)
    local position = Vector3.new(
        self.Config.X - half + SPACING / 2 + col * SPACING,
        0.3,
        self.Config.Z - half + SPACING / 2 + row * SPACING
    )
    return position, slot + 1, slot, capacity, cols
end

function AutoPlace:PendingCount()
    local count = 0
    local tools = self:_inventoryTools()
    self:_reconcileSent(tools)
    for _, entry in ipairs(tools) do
        if not self.Placed[entry.key] then
            local source = self:_sourceTerreiro(entry.tool, entry.id)
            if source == nil or self.Terreiros[source] then count += 1 end
        end
    end
    return count
end

function AutoPlace:Diagnose()
    local selected = sortedSet(self.Terreiros)
    local tools = self:_inventoryTools()
    local setup, setupReason = self:_setup()
    local mapped, unmatched, unselected = {}, {}, {}
    for _, entry in ipairs(tools) do
        local source, sourceKind = self:_sourceTerreiro(entry.tool, entry.id)
        local detail = entry.key .. "@" .. entry.container .. "->" .. tostring(source or "SEM ORIGEM")
            .. "(" .. tostring(sourceKind) .. ")"
        if not source then
            unmatched[#unmatched + 1] = detail
        elseif self.Terreiros[source] then
            mapped[#mapped + 1] = detail
        else
            unselected[#unselected + 1] = detail
        end
    end

    log(self, "========== DIAGNOSTICO ==========")
    log(self, "enabled =", self.Enabled, "| status =", self.LastStatus)
    log(self, "selecionados =", listToText(selected))
    log(self, "Setup =", setup and "OK" or "FALHOU", "| motivo =", setupReason or "nenhum")
    if self.Pen then
        log(self, "base =", instanceName(self.Pen), "| Index =", self.Config and self.Config.Index,
            "| centro =", self.Config and (tostring(self.Config.X) .. "," .. tostring(self.Config.Z)),
            "| formato =", self.Config and self.Config.Format)
    end
    if self.Remote then log(self, "remote =", instanceName(self.Remote)) end
    log(self, "Backpack =", self.LastInventoryStats.backpackFound,
        "| Character =", self.LastInventoryStats.characterFound,
        "| Tools =", self.LastInventoryStats.totalTools,
        "| Tools com ExuId =", self.LastInventoryStats.exuTools,
        "| IDs unicos =", self.LastInventoryStats.uniqueExuIds,
        "| sem ExuId =", self.LastInventoryStats.missingExuId,
        "| duplicados =", self.LastInventoryStats.duplicateIds)
    log(self, "inventario =", listToText(self.LastInventoryStats.names))
    log(self, "origem selecionada =", #mapped, listToText(mapped))
    log(self, "origem sem mapeamento =", #unmatched, listToText(unmatched))
    log(self, "origem em outro Terreiro =", #unselected, listToText(unselected))
    local sourceMap = env.__DEPHUB_STEALANEXU_EXU_SOURCES
    local sourceMapCount = 0
    for _ in pairs(type(sourceMap) == "table" and sourceMap or {}) do sourceMapCount += 1 end
    log(self, "sourceMap na memoria =", sourceMapCount)
    log(self, "pedidos enviados aguardando resultado =", (function()
        local count = 0
        for _ in pairs(self.Sent) do count += 1 end
        return count
    end)())
    log(self, "proximo slot =", self.NextSlot)
    log(self, "=================================")

    if not setup then
        self.LastError = setupReason
        self.LastStatus = "setup error"
    elseif #tools == 0 then
        self.LastError = nil
        self.LastStatus = "waiting for Exu tools"
    elseif #mapped == 0 then
        self.LastError = nil
        self.LastStatus = "no selected Exu source matched"
    else
        self.LastError = nil
        self.LastStatus = "ready"
    end

    return {
        setup = setup == true,
        setupError = setupReason,
        selected = selected,
        tools = tools,
        mapped = mapped,
        unmatched = unmatched,
        unselected = unselected,
        stats = self.LastInventoryStats,
    }
end

function AutoPlace:_reconcileSent(tools)
    local present = {}
    for _, entry in ipairs(tools) do present[entry.key] = entry end

    for key, info in pairs(self.Sent) do
        if not present[key] then
            self.Sent[key] = nil
            self.Placed[key] = true
            log(self, "confirmacao observada: Tool", key, "saiu do inventario apos PlaceExu.")
        elseif os.clock() - info.sentAt >= CONFIRM_TIMEOUT and not info.timeoutLogged then
            info.timeoutLogged = true
            log(self, "ATENCAO: Tool", key, "continua no inventario", CONFIRM_TIMEOUT,
                "s apos FireServer; o cliente enviou o pedido, mas o servidor ainda nao confirmou removendo a Tool.")
        end
    end
end

function AutoPlace:PlaceOnce()
    if self.Destroyed then return 0, "feature destruida" end

    if type(self.Ctx.IsAutoSellEnabled) == "function" then
        local ok, enabled = pcall(self.Ctx.IsAutoSellEnabled)
        if ok and enabled == true then
            self.LastStatus = "paused for Auto Sell"
            return 0, self.LastStatus
        end
    end

    local selected = sortedSet(self.Terreiros)
    if #selected == 0 then
        self.LastError = "nenhum Terreiro selecionado para colocar"
        self.LastStatus = "selection empty"
        local signature = self.LastStatus
        if signature ~= self.LastDiagnosticSignature then
            log(self, self.LastError)
            self.LastDiagnosticSignature = signature
        end
        return 0, self.LastError
    end

    local tools = self:_inventoryTools()
    self:_reconcileSent(tools)

    local ready, setupError = self:_setup()
    if not ready then
        self.LastError = setupError
        self.LastStatus = "setup error"
        local signature = "setup|" .. tostring(setupError)
        if signature ~= self.LastDiagnosticSignature then
            log(self, "SETUP FALHOU:", setupError,
                "| selecao =", listToText(selected),
                "| Tools com ExuId =", self.LastInventoryStats.uniqueExuIds,
                "| Tools sem ExuId =", self.LastInventoryStats.missingExuId)
            self.LastDiagnosticSignature = signature
        end
        return 0, setupError
    end

    local mapped = {}
    local unmatched = {}
    local unselected = {}
    for _, entry in ipairs(tools) do
        if not self.Placed[entry.key] and not self.Sent[entry.key] then
            local source, sourceKind = self:_sourceTerreiro(entry.tool, entry.id)
            if source and self.Terreiros[source] then
                mapped[#mapped + 1] = {entry = entry, source = source, sourceKind = sourceKind}
            elseif source then
                unselected[#unselected + 1] = entry.key .. "->" .. source
            else
                unmatched[#unmatched + 1] = entry.key .. "->sem origem"
            end
        end
    end

    local signature = table.concat({
        table.concat(selected, ","),
        tostring(self.LastInventoryStats.uniqueExuIds),
        tostring(self.LastInventoryStats.missingExuId),
        tostring(#mapped),
        tostring(#unmatched),
        tostring(#unselected),
        tostring(self.NextSlot),
        tostring(self.LastStatus),
    }, "|")
    if signature ~= self.LastDiagnosticSignature or os.clock() - self.LastDiagnosticAt >= DEBUG_INTERVAL then
        log(self, "scan", self.ScanCount + 1,
            "| selecionados =", listToText(selected),
            "| Backpack ExuId =", self.LastInventoryStats.backpackExus,
            "| Character ExuId =", self.LastInventoryStats.characterExus,
            "| unicos =", self.LastInventoryStats.uniqueExuIds,
            "| sem ExuId =", self.LastInventoryStats.missingExuId,
            "| correspondentes =", #mapped,
            "| sem origem =", #unmatched,
            "| outro Terreiro =", #unselected,
            "| enviados aguardando resposta =", (function()
                local count = 0
                for _ in pairs(self.Sent) do count += 1 end
                return count
            end)())
        if #unmatched > 0 then log(self, "Tools ignoradas sem origem:", listToText(unmatched)) end
        if #unselected > 0 then log(self, "Tools de terreiros nao selecionados:", listToText(unselected)) end
        self.LastDiagnosticSignature = signature
        self.LastDiagnosticAt = os.clock()
    end

    if #tools == 0 then
        self.LastError = nil
        self.LastStatus = "waiting for Exu tools"
        return 0, self.LastStatus
    end

    if #mapped == 0 then
        self.LastError = nil
        self.LastStatus = #unmatched > 0 and "missing source mapping" or "no matching selected tools"
        return 0, self.LastStatus
    end

    local sentNow = 0
    for _, item in ipairs(mapped) do
        if self.Destroyed or (self.Enabled == false and self.Thread ~= nil) then break end

        local entry = item.entry
        local position, nextSlot, slot, capacity, cols = self:_nextPosition()
        if not position then
            self.LastError = nextSlot
            self.LastStatus = "grid error"
            log(self, "NAO FOI POSSIVEL CALCULAR SLOT:", nextSlot)
            break
        end

        log(self, "enviando PlaceExu:",
            "ExuId =", entry.key,
            "| Tool =", instanceName(entry.tool),
            "| origem =", item.source,
            "| detectada por =", item.sourceKind,
            "| slot =", slot + 1, "/", capacity,
            "| grade =", cols .. "x" .. cols,
            "| posicao =", tostring(position))

        local ok, err = pcall(function()
            self.Remote:FireServer(entry.id, position)
        end)

        if ok then
            self.NextSlot = nextSlot
            self.Sent[entry.key] = {
                id = entry.id,
                source = item.source,
                tool = entry.tool,
                position = position,
                sentAt = os.clock(),
                timeoutLogged = false,
            }
            sentNow += 1
            log(self, "FireServer executado sem erro local para", entry.key,
                "| slot reservado =", self.NextSlot,
                "| aguardando confirmacao do servidor.")
            task.wait(PLACE_DELAY)
        else
            self.LastError = tostring(err)
            self.LastStatus = "remote error"
            log(self, "ERRO ao chamar PlaceExu:", entry.key, tostring(err))
        end
    end

    if sentNow > 0 then
        self.LastError = nil
        self.LastStatus = "requests sent; awaiting server"
    elseif #mapped > 0 then
        self.LastStatus = "waiting to submit"
    end

    return sentNow
end

function AutoPlace:_loop(runId)
    log(self, "monitor iniciado.",
        "| intervalo =", SCAN_DELAY,
        "| selecao =", listToText(sortedSet(self.Terreiros)))
    self:Diagnose()

    while self.Enabled and not self.Destroyed and self.RunId == runId do
        self.ScanCount += 1
        local ok, result, reason = pcall(function() return self:PlaceOnce() end)
        if not ok then
            self.LastError = tostring(result)
            self.LastStatus = "error"
            log(self, "erro no ciclo", self.ScanCount .. ":", self.LastError)
        elseif type(reason) == "string" and reason ~= "" and self.LastStatus ~= "paused for Auto Sell" then
            if self.LastError ~= reason then
                log(self, "ciclo sem envio:", tostring(reason))
            end
        end
        task.wait(SCAN_DELAY)
    end

    if self.RunId == runId then
        self.Thread = nil
        log(self, "monitor parado.")
    end
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
        self.LastDiagnosticSignature = nil
        log(self, "ON.",
            "| selecao =", listToText(sortedSet(self.Terreiros)),
            "| sourceMap =", type(env.__DEPHUB_STEALANEXU_EXU_SOURCES))
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
        log(self, "OFF.")
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

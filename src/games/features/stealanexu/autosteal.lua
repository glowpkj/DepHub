-- Steal An Exu -- Auto Steal Exu.
-- Varredura continua com pausa entre ciclos, prompts atualizados e movimento coordenado.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local table = table
local math = math
local os = os

local SETTLE_WAIT = 0.15
local POST_WAIT = 0.1
local TARGET_GAP = 0.08
local SCAN_WAIT = 0.25
local EMPTY_WAIT = 0.6
local CHARACTER_WAIT = 0.5
local MOVEMENT_WAIT = 0.05
local SOURCE_CONFIRM_WAIT = 0.18
local TARGET_CACHE_TTL = 0.65

local AutoSteal = {}
AutoSteal.__index = AutoSteal
AutoSteal.DebugEnabled = true

local DEBUG_TAG = "[StealAnExu]"
local env = type(getgenv) == "function" and getgenv() or _G

local function debugLog(self, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local message = DEBUG_TAG .. " Steal: " .. table.concat(parts, " ")
    self.DebugLog[#self.DebugLog + 1] = message
    if #self.DebugLog > 200 then table.remove(self.DebugLog, 1) end
    if AutoSteal.DebugEnabled then
        print(message)
        local diag = env.__DEPHUB and env.__DEPHUB.Diagnostics
        if type(diag) == "table" and type(diag.Note) == "function" then
            pcall(diag.Note, diag, message)
        end
    end
end

function AutoSteal.new(ctx, options)
    options = options or {}
    local selected = {}
    for _, name in ipairs(type(options.terreiros) == "table" and options.terreiros or {}) do
        selected[tostring(name)] = true
    end
    return setmetatable({
        Ctx = ctx or {},
        Enabled = false,
        Thread = nil,
        LastError = nil,
        Destroyed = false,
        DebugLog = {},
        LastTargetCount = nil,
        SelectedOnly = options.selectedOnly ~= false,
        Terreiros = selected,
        TargetCache = nil,
        TargetCacheAt = 0,
        TargetCacheKey = nil,
        SourceTrackQueue = {},
        SourceTrackWorker = false,
    }, AutoSteal)
end

function AutoSteal:Logs()
    return self.DebugLog
end

function AutoSteal:IsEnabled()
    return self.Enabled == true
end

function AutoSteal:_root()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function instancePosition(instance)
    if not instance then return nil end

    if instance:IsA("BasePart") then
        return instance.Position
    end

    if instance:IsA("Model") then
        if instance.PrimaryPart then return instance.PrimaryPart.Position end
        local ok, pivot = pcall(function() return instance:GetPivot() end)
        if ok and pivot then return pivot.Position end
    end

    local ok, position = pcall(function() return instance.Position end)
    return ok and position or nil
end

local function readExuId(instance)
    if not instance then return nil end
    local ok, value = pcall(function() return instance:GetAttribute("ExuId") end)
    if ok and value ~= nil then return value end
    local okChildren, descendants = pcall(function() return instance:GetDescendants() end)
    if okChildren then
        for _, descendant in ipairs(descendants) do
            local okId, childId = pcall(function() return descendant:GetAttribute("ExuId") end)
            if okId and childId ~= nil then return childId end
        end
    end
    return nil
end

local function collectRuntimeTargets(runtime)
    local targets = {}
    local seen = {}

    for _, model in ipairs(runtime:GetChildren()) do
        local ref = model:FindFirstChild("Root")
        if not ref then
            local ok, nested = pcall(function()
                return model:FindFirstChild("Root", true)
            end)
            if ok then ref = nested end
        end

        local prompt = ref and ref:FindFirstChild("ProximityPrompt")
        if ref and not prompt then
            local ok, nested = pcall(function()
                return ref:FindFirstChildWhichIsA("ProximityPrompt", true)
            end)
            if ok then prompt = nested end
        end

        local position = instancePosition(ref)
        if prompt and ref and position and not seen[prompt] then
            seen[prompt] = true
            targets[#targets + 1] = {
                prompt = prompt,
                ref = ref,
                model = model,
                runtime = runtime,
                position = position,
                exuId = readExuId(model),
            }
        end
    end

    return targets
end

local function numberedNameSort(a, b)
    local aNumber = tonumber(a.Name:match("(%d+)$")) or math.huge
    local bNumber = tonumber(b.Name:match("(%d+)$")) or math.huge
    if aNumber == bNumber then return a.Name < b.Name end
    return aNumber < bNumber
end

local function explicitTerreiro(instance)
    if not instance then return nil end
    for _, attributeName in ipairs({
        "Terreiro", "TerreiroName", "SourceTerreiro", "OriginTerreiro",
        "TerreiroId", "TerreiroIndex", "OriginTerreiroId",
    }) do
        local ok, value = pcall(function() return instance:GetAttribute(attributeName) end)
        if ok and value ~= nil then
            local name = tostring(value)
            local numeric = tonumber(name)
            if numeric then return "Terreiro" .. tostring(math.floor(numeric)) end
            if name:match("^%d+$") then return "Terreiro" .. name end
            return name
        end
    end
    return nil
end

function AutoSteal.terreiros()
    local workspace = game:GetService("Workspace")
    local map = workspace:FindFirstChild("Map")
    local folder = map and map:FindFirstChild("Terreiros")
    local result = {}

    if folder then
        for _, terreiro in ipairs(folder:GetChildren()) do
            if terreiro:FindFirstChild("Nests") then
                result[#result + 1] = terreiro.Name
            end
        end
    end

    table.sort(result, function(a, b)
        local aNumber = tonumber(a:match("(%d+)$")) or math.huge
        local bNumber = tonumber(b:match("(%d+)$")) or math.huge
        if aNumber == bNumber then return a < b end
        return aNumber < bNumber
    end)

    if #result == 0 then
        for index = 1, 9 do
            result[#result + 1] = "Terreiro" .. index
        end
    end

    return result
end

function AutoSteal:_selectedTargets(runtime)
    local workspace = game:GetService("Workspace")
    local map = workspace:FindFirstChild("Map")
    local terreirosFolder = map and map:FindFirstChild("Terreiros")
    if not terreirosFolder then
        return {}, "workspace.Map.Terreiros nao encontrado"
    end

    local selectedCount = 0
    local selectedNestCount = 0
    for terreiroName in pairs(self.Terreiros) do
        selectedCount += 1
        local selectedFolder = terreirosFolder:FindFirstChild(terreiroName)
        local selectedNests = selectedFolder and selectedFolder:FindFirstChild("Nests")
        if not selectedNests then
            return {}, "Nests do " .. tostring(terreiroName) .. " ainda nao carregaram"
        end
        selectedNestCount += #selectedNests:GetChildren()
    end
    if selectedCount == 0 then return {}, "nenhum Terreiro selecionado" end
    if selectedNestCount == 0 then return {}, "nenhum Nest disponivel nos terreiros selecionados" end

    local nests = {}
    for _, terreiro in ipairs(terreirosFolder:GetChildren()) do
        local nestsFolder = terreiro:FindFirstChild("Nests")
        if nestsFolder then
            for _, nest in ipairs(nestsFolder:GetChildren()) do
                local position = instancePosition(nest)
                if position then
                    nests[#nests + 1] = {
                        instance = nest,
                        position = position,
                        terreiroName = terreiro.Name,
                    }
                end
            end
        end
    end

    table.sort(nests, function(a, b)
        local aNumber = tonumber(a.terreiroName:match("(%d+)$")) or math.huge
        local bNumber = tonumber(b.terreiroName:match("(%d+)$")) or math.huge
        if aNumber ~= bNumber then return aNumber < bNumber end
        if a.terreiroName ~= b.terreiroName then return a.terreiroName < b.terreiroName end
        return numberedNameSort(a.instance, b.instance)
    end)

    local runtimeTargets = collectRuntimeTargets(runtime)
    if #runtimeTargets == 0 then
        return {}, nil
    end

    local targets = {}
    for _, target in ipairs(runtimeTargets) do
        local terreiroName = explicitTerreiro(target.model) or explicitTerreiro(target.ref)
        if terreiroName and not terreirosFolder:FindFirstChild(terreiroName) then
            terreiroName = nil
        end
        local nearestNest = nil
        local nearestDistance = math.huge

        if not terreiroName then
            for _, nest in ipairs(nests) do
                local delta = target.position - nest.position
                local distance = delta.Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestNest = nest
                end
            end
            terreiroName = nearestNest and nearestNest.terreiroName or nil
        end

        if terreiroName and self.Terreiros[terreiroName] then
            target.terreiroName = terreiroName
            target.nestName = nearestNest and nearestNest.instance.Name or nil
            targets[#targets + 1] = target
        end
    end

    return targets
end

function AutoSteal:_targets()
    local workspace = game:GetService("Workspace")
    local runtime = workspace:FindFirstChild("Runtime")
    if not runtime then
        self.TargetCache = nil
        return nil, "workspace.Runtime nao encontrado"
    end

    if self.SelectedOnly then
        local now = os.clock()
        local selectionKey = self:SelectionKey()
        local cached = self.TargetCache
        if cached and self.TargetCacheKey == selectionKey and now - self.TargetCacheAt < TARGET_CACHE_TTL then
            local stillAlive = true
            for _, target in ipairs(cached) do
                if not self:_alive(target) then
                    stillAlive = false
                    break
                end
            end
            if stillAlive then return cached end
            self.TargetCache = nil
        end

        local targets, reason = self:_selectedTargets(runtime)
        if targets then
            self.TargetCache = targets
            self.TargetCacheAt = now
            self.TargetCacheKey = selectionKey
        else
            self.TargetCache = nil
        end
        return targets, reason
    end

    return collectRuntimeTargets(runtime)
end

function AutoSteal:_alive(target)
    return target ~= nil
        and target.prompt ~= nil and target.prompt.Parent ~= nil
        and target.ref ~= nil and target.ref.Parent ~= nil
        and target.model ~= nil and target.model.Parent == target.runtime
end

function AutoSteal:_acquireMovement()
    local acquire = self.Ctx and self.Ctx.AcquireMovement
    if type(acquire) ~= "function" then return true, false end

    while not self.Destroyed do
        local ok, acquired = pcall(acquire, self)
        if ok and acquired == true then return true, true end
        if not self.Enabled then return false, false end
        task.wait(MOVEMENT_WAIT)
    end

    return false, false
end

function AutoSteal:_releaseMovement(acquired)
    if not acquired then return end
    local release = self.Ctx and self.Ctx.ReleaseMovement
    if type(release) == "function" then
        pcall(release, self)
    end
end

function AutoSteal:_queueSourceTrack(before, terreiroName)
    if not terreiroName or type(self.Ctx.InventoryExuIds) ~= "function"
        or type(self.Ctx.TrackNewExuSources) ~= "function"
    then
        return false
    end

    self.SourceTrackQueue[#self.SourceTrackQueue + 1] = {
        before = before or {},
        terreiroName = terreiroName,
        queuedAt = os.clock(),
    }

    if self.SourceTrackWorker then return true end
    self.SourceTrackWorker = true

    task.spawn(function()
        while not self.Destroyed and #self.SourceTrackQueue > 0 do
            local item = table.remove(self.SourceTrackQueue, 1)
            local deadline = os.clock() + 2.5
            local tracked = 0

            repeat
                task.wait(0.2)
                if self.Destroyed then break end

                local okIds, after = pcall(self.Ctx.InventoryExuIds)
                if okIds and type(after) == "table" then
                    local okTrack, added = pcall(
                        self.Ctx.TrackNewExuSources,
                        item.before,
                        after,
                        item.terreiroName
                    )
                    if okTrack then tracked += tonumber(added) or 0 end
                end

                if tracked > 0 then
                    local persist = self.Ctx.PersistExuSources
                    if type(persist) == "function" then
                        local okSave, saved = pcall(persist)
                        if not okSave or saved == false then
                            debugLog(self, "origem mapeada em background, mas falhou ao salvar.")
                        end
                    end
                    debugLog(self, tracked, "Tool(s) vinculada(s) em background ao", item.terreiroName)
                    break
                end
            until os.clock() >= deadline

            if tracked == 0 and not self.Destroyed then
                debugLog(self, "nenhum novo ExuId apareceu para", item.terreiroName,
                    "dentro da janela de confirmacao; roubo continuou sem esperar.")
            end
        end

        self.SourceTrackWorker = false
    end)

    return true
end

function AutoSteal:_step(target, root, originalPos)
    if not self:_alive(target) then return false end

    local acquiredOk, acquired = self:_acquireMovement()
    if not acquiredOk then return false end

    local returnCFrame = originalPos or root.CFrame
    local resolveReturn = self.Ctx and self.Ctx.StealReturnCFrame
    if type(resolveReturn) == "function" then
        local ok, destination = pcall(resolveReturn)
        if ok and destination then returnCFrame = destination end
    end

    local before = {}
    local getExuIds = self.Ctx and self.Ctx.InventoryExuIds
    if target.terreiroName and target.exuId == nil and type(getExuIds) == "function" then
        local ok, ids = pcall(getExuIds)
        if ok and type(ids) == "table" then before = ids end
    end

    local prompt = target.prompt
    local ref = target.ref

    local ok, err = pcall(function()
        pcall(function() prompt.MaxActivationDistance = 1000 end)
        pcall(function() prompt.HoldDuration = 0 end)
        pcall(function() prompt.RequiresLineOfSight = false end)

        if not self:_alive(target) then return end

        root.CFrame = CFrame.new(ref.Position + Vector3.new(0, 3, 0))
        task.wait(SETTLE_WAIT)

        if not self.Destroyed and (self.Enabled or originalPos ~= nil) and self:_alive(target) then
            prompt:InputHoldBegin()
            prompt:InputHoldEnd()

            if target.terreiroName then
                if target.exuId ~= nil and type(self.Ctx.TrackExuSource) == "function" then
                    local okTrack, changed = pcall(self.Ctx.TrackExuSource, target.exuId, target.terreiroName)
                    if okTrack and changed and type(self.Ctx.PersistExuSources) == "function" then
                        task.spawn(function()
                            task.wait(0.1)
                            pcall(self.Ctx.PersistExuSources)
                        end)
                    end
                else
                    self:_queueSourceTrack(before, target.terreiroName)
                end
            end
        end
    end)

    pcall(function()
        if root and root.Parent then root.CFrame = returnCFrame end
    end)
    self:_releaseMovement(acquired)

    if not ok then
        self.LastError = tostring(err)
        debugLog(self, "falha no prompt:", tostring(err))
    end

    task.wait(POST_WAIT)
    return ok
end

function AutoSteal:_loop()
    debugLog(self, "loop iniciado")
    while self.Enabled and not self.Destroyed do
        local root = self:_root()

        if not root then
            self.LastError = "sem personagem"
            task.wait(CHARACTER_WAIT)
        else
            local targets, reason = self:_targets()

            if not targets then
                self.LastError = reason
                if self.LastTargetCount ~= nil then
                    debugLog(self, "Runtime indisponivel; aguardando")
                    self.LastTargetCount = nil
                end
                task.wait(EMPTY_WAIT)
            elseif #targets == 0 then
                self.LastError = "Nenhum ProximityPrompt encontrado"
                if self.LastTargetCount ~= 0 then
                    debugLog(self, "nenhum Exu; aguardando spawn")
                    self.LastTargetCount = 0
                end
                task.wait(EMPTY_WAIT)
            else
                self.LastError = nil
                self.LastTargetCount = #targets

                for _, target in ipairs(targets) do
                    if not self.Enabled or self.Destroyed then break end
                    if self:_alive(target) then
                        self:_step(target, root)
                        task.wait(TARGET_GAP)
                    end
                end

                task.wait(SCAN_WAIT)
            end
        end
    end

    self.Thread = nil
    debugLog(self, "loop parado")
end

function AutoSteal:SetEnabled(on)
    on = on == true
    if self.Destroyed then return false end
    if on == self.Enabled then return true end

    self.Enabled = on
    if on then
        self.LastError = nil
        self.LastTargetCount = nil
        debugLog(self, "ON")
        self.Thread = task.spawn(function()
            local ok, err = pcall(function()
                self:_loop()
            end)
            if not ok then
                self.LastError = tostring(err)
                self.Enabled = false
                self.Thread = nil
                debugLog(self, "ERRO no loop:", tostring(err))
            end
        end)
    else
        debugLog(self, "OFF")
    end

    return true
end

function AutoSteal:SetTerreiros(names)
    if type(names) ~= "table" then return false end
    local available = {}
    for _, name in ipairs(AutoSteal.terreiros()) do available[name] = true end
    local selected = {}
    for _, name in ipairs(names) do
        name = tostring(name)
        if available[name] then selected[name] = true end
    end
    self.Terreiros = selected
    self.LastTargetCount = nil
    self.TargetCache = nil
    self.TargetCacheKey = nil
    return true
end

function AutoSteal:SetTerreiro(name)
    return self:SetTerreiros({name})
end

function AutoSteal:SelectedTerreiros()
    local result = {}
    for _, name in ipairs(AutoSteal.terreiros()) do
        if self.Terreiros[name] then result[#result + 1] = name end
    end
    return result
end

function AutoSteal:SelectionKey()
    return table.concat(self:SelectedTerreiros(), "|")
end

function AutoSteal:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    self.DebugLog = {}
end

return AutoSteal

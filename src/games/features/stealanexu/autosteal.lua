-- Steal An Exu -- Auto Steal Exu.
-- Varredura continua com pausa entre ciclos, prompts atualizados e movimento coordenado.

local game = game
local task = task
local type = type
local pcall = pcall
local tostring = tostring
local table = table
local math = math

local SETTLE_WAIT = 0.15
local POST_WAIT = 0.1
local TARGET_GAP = 0.08
local SCAN_WAIT = 0.25
local EMPTY_WAIT = 0.6
local CHARACTER_WAIT = 0.5
local MOVEMENT_WAIT = 0.05

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
    return setmetatable({
        Ctx = ctx or {},
        Enabled = false,
        Thread = nil,
        LastError = nil,
        Destroyed = false,
        DebugLog = {},
        LastTargetCount = nil,
        SelectedOnly = options.selectedOnly == true,
        Terreiro = options.terreiro or "Terreiro1",
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
    local terreiros = map and map:FindFirstChild("Terreiros")
    local terreiro = terreiros and terreiros:FindFirstChild(self.Terreiro)
    local nestsFolder = terreiro and terreiro:FindFirstChild("Nests")

    if not nestsFolder then
        return {}, "Terreiro nao encontrado: " .. tostring(self.Terreiro)
    end

    local nests = {}
    for _, nest in ipairs(nestsFolder:GetChildren()) do
        local position = instancePosition(nest)
        if position then
            nests[#nests + 1] = {instance = nest, position = position}
        end
    end
    table.sort(nests, function(a, b) return numberedNameSort(a.instance, b.instance) end)

    local runtimeTargets = collectRuntimeTargets(runtime)
    if #nests == 0 or #runtimeTargets == 0 then
        return {}, nil
    end

    -- Associa cada Nest ao Exu mais proximo sem reutilizar o mesmo Exu duas vezes.
    -- A ordenacao global por distancia evita que o primeiro Nest "roube" um Exu
    -- que esta muito mais perto do Nest seguinte.
    local pairsByDistance = {}
    for nestIndex, nest in ipairs(nests) do
        for targetIndex, target in ipairs(runtimeTargets) do
            local delta = target.position - nest.position
            pairsByDistance[#pairsByDistance + 1] = {
                nestIndex = nestIndex,
                targetIndex = targetIndex,
                distance = delta.Magnitude,
            }
        end
    end

    table.sort(pairsByDistance, function(a, b)
        if a.distance == b.distance then
            if a.nestIndex == b.nestIndex then return a.targetIndex < b.targetIndex end
            return a.nestIndex < b.nestIndex
        end
        return a.distance < b.distance
    end)

    local usedNests = {}
    local usedTargets = {}
    local assigned = {}

    for _, pair in ipairs(pairsByDistance) do
        if not usedNests[pair.nestIndex] and not usedTargets[pair.targetIndex] then
            usedNests[pair.nestIndex] = true
            usedTargets[pair.targetIndex] = true
            assigned[pair.nestIndex] = runtimeTargets[pair.targetIndex]
        end
    end

    local targets = {}
    for nestIndex, nest in ipairs(nests) do
        local target = assigned[nestIndex]
        if target then
            target.nestName = nest.instance.Name
            targets[#targets + 1] = target
        end
    end

    return targets
end

function AutoSteal:_targets()
    local workspace = game:GetService("Workspace")
    local runtime = workspace:FindFirstChild("Runtime")
    if not runtime then
        return nil, "workspace.Runtime nao encontrado"
    end

    if self.SelectedOnly then
        return self:_selectedTargets(runtime)
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

function AutoSteal:_step(target, root, originalPos)
    if not self:_alive(target) then return false end

    local acquiredOk, acquired = self:_acquireMovement()
    if not acquiredOk then return false end

    local returnCFrame = originalPos or root.CFrame
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

function AutoSteal:SetTerreiro(name)
    if type(name) ~= "string" or name == "" then return false end
    self.Terreiro = name
    self.LastTargetCount = nil
    return true
end

function AutoSteal:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false
    self.DebugLog = {}
end

return AutoSteal

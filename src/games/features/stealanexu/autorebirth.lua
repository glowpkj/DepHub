-- Steal An Exu -- Auto Rebirth.
-- Monitora Cash e Rebirths e invoca o remote quando o custo atual e atingido.

local game = game
local task = task
local type = type
local tostring = tostring
local pcall = pcall

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local CHECK_INTERVAL = 0.5

local AutoRebirth = {}
AutoRebirth.__index = AutoRebirth

function AutoRebirth.new()
    local self = setmetatable({}, AutoRebirth)
    self.Enabled = false
    self.Destroyed = false
    self.Thread = nil
    self.LastError = nil
    self.LastRebirth = nil
    self.Remote = nil
    self.Config = nil
    return self
end

function AutoRebirth:IsEnabled()
    return self.Enabled == true
end

function AutoRebirth:_setup()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotes then return false, "Remotes nao encontrado" end

    local rewards = remotes:WaitForChild("Rewards", 10)
    if not rewards then return false, "Remote Rewards nao encontrado" end
    if not rewards:IsA("RemoteFunction") then
        return false, "Rewards nao e RemoteFunction"
    end

    local shared = ReplicatedStorage:WaitForChild("Shared", 10)
    if not shared then return false, "Shared nao encontrado" end

    local configModule = shared:WaitForChild("Config", 10)
    if not configModule then return false, "Config nao encontrado" end

    local ok, config = pcall(require, configModule)
    if not ok or type(config) ~= "table" or type(config.rebirthCost) ~= "function" then
        return false, "Config.rebirthCost indisponivel: " .. tostring(config)
    end

    self.Remote = rewards
    self.Config = config
    return true
end

function AutoRebirth:_loop()
    local setupOk, setupError = self:_setup()
    if not setupOk then
        self.LastError = setupError
        warn("[StealAnExu] Auto Rebirth: " .. tostring(setupError))
        self.Enabled = false
        self.Thread = nil
        return
    end

    while self.Enabled and not self.Destroyed do
        local cash = LocalPlayer:GetAttribute("Cash") or 0
        local rebirths = LocalPlayer:GetAttribute("Rebirths") or 0
        local costOk, cost = pcall(self.Config.rebirthCost, rebirths)

        if costOk and type(cost) == "number" and cash >= cost then
            local invokeOk, success, message = pcall(function()
                return self.Remote:InvokeServer("rebirth")
            end)

            if invokeOk and success then
                self.LastRebirth = rebirths + 1
                print(("[StealAnExu] Rebirth #%d feito! (custou $%s)"):format(
                    rebirths + 1,
                    tostring(self.Config.format and self.Config.format(cost) or cost)
                ))
            elseif not invokeOk then
                self.LastError = tostring(success)
                warn("[StealAnExu] Auto Rebirth: " .. tostring(success))
            else
                self.LastError = tostring(message)
                warn("[StealAnExu] Auto Rebirth falhou: " .. tostring(message))
            end
        elseif not costOk then
            self.LastError = tostring(cost)
            warn("[StealAnExu] Auto Rebirth: erro calculando custo: " .. tostring(cost))
            task.wait(1)
        end

        task.wait(CHECK_INTERVAL)
    end

    self.Thread = nil
end

function AutoRebirth:SetEnabled(on)
    on = on == true
    if self.Destroyed then return false end
    if on == self.Enabled then return true end

    self.Enabled = on
    if on then
        self.Thread = task.spawn(function()
            local ok, err = pcall(function()
                self:_loop()
            end)
            if not ok then
                self.LastError = tostring(err)
                self.Enabled = false
                self.Thread = nil
                warn("[StealAnExu] Auto Rebirth erro: " .. tostring(err))
            end
        end)
    end

    return true
end

function AutoRebirth:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    self.Enabled = false

    if self.Thread then
        pcall(task.cancel, self.Thread)
        self.Thread = nil
    end

    self.Remote = nil
    self.Config = nil
end

return AutoRebirth

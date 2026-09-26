local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local AutoAttack={}
AutoAttack.__index=AutoAttack

function AutoAttack.new()
    return setmetatable({
        Player=Players.LocalPlayer,
        Remote=ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlayerAttack"),
        Enabled=false,
        FarmEnabled=false,
        FarmReady=false,
        Interval=0.05,
        ActivateInterval=0.1,
        Token=0
    },AutoAttack)
end

function AutoAttack:_character()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")

    if not character or not humanoid or humanoid.Health<=0 then
        return nil
    end

    return character
end

function AutoAttack:_argument(tool)
    if tool and tool:GetAttribute("StatCategory")=="Fists" then
        return "0"
    end
    return ""
end

function AutoAttack:_run(token)
    local lastActivate=0

    while (self.Enabled or self.FarmEnabled) and token==self.Token do
        if self.Enabled or self.FarmReady then
            local character=self:_character()
            local tool=character and character:FindFirstChildOfClass("Tool")

            if tool then
                local now=os.clock()

                if now-lastActivate>=self.ActivateInterval then
                    lastActivate=now
                    pcall(tool.Activate,tool)
                end

                pcall(self.Remote.FireServer,self.Remote,self:_argument(tool))
            end
        end

        task.wait(self.Interval)
    end
end

function AutoAttack:_refresh()
    self.Token+=1

    if self.Enabled or self.FarmEnabled then
        local token=self.Token
        task.spawn(function()
            self:_run(token)
        end)
    end
end

function AutoAttack:SetEnabled(enabled)
    enabled=enabled==true
    if self.Enabled==enabled then return end

    self.Enabled=enabled
    self:_refresh()
end

function AutoAttack:SetFarmEnabled(enabled)
    enabled=enabled==true
    if self.FarmEnabled==enabled then return end

    self.FarmEnabled=enabled

    if not enabled then
        self.FarmReady=false
    end

    self:_refresh()
end

function AutoAttack:SetFarmReady(ready)
    self.FarmReady=self.FarmEnabled and ready==true
end

function AutoAttack:Destroy()
    self.Enabled=false
    self.FarmEnabled=false
    self.FarmReady=false
    self:_refresh()
end

return AutoAttack

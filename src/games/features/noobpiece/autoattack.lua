local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local AutoAttack={}
AutoAttack.__index=AutoAttack

function AutoAttack.new()
    local self=setmetatable({
        Player=Players.LocalPlayer,
        Remote=ReplicatedStorage:WaitForChild("Events"):WaitForChild("PlayerAttack"),
        Enabled=false,
        FarmEnabled=false,
        Token=0
    },AutoAttack)

    return self
end

function AutoAttack:_character()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or humanoid.Health<=0 or not root then
        return nil
    end

    return character,root
end

function AutoAttack:_argument(tool)
    if tool and tool:GetAttribute("StatCategory")=="Fists" then
        return "0"
    end
    return ""
end

function AutoAttack:_run(token)
    while (self.Enabled or self.FarmEnabled) and token==self.Token do
        local character=self:_character()

        if character then
            local tool=character:FindFirstChildOfClass("Tool")
            if tool then
                pcall(tool.Activate,tool)
                self.Remote:FireServer(self:_argument(tool))
            end
        end

        task.wait()
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
    self:_refresh()
end

function AutoAttack:Destroy()
    self.Enabled=false
    self.FarmEnabled=false
    self:_refresh()

end

return AutoAttack

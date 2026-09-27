local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")

local WanderingGacha={}
WanderingGacha.__index=WanderingGacha

local MOVEMENT_OWNER="WanderingGacha"

function WanderingGacha.new(movement)
    return setmetatable({
        Player=Players.LocalPlayer,
        Movement=movement,
        Offset=4
    },WanderingGacha)
end

function WanderingGacha:_root(model)
    if not model then return nil end

    if model:IsA("BasePart") then
        return model
    end

    if model:IsA("Model") then
        return model.PrimaryPart
            or model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChildWhichIsA("BasePart",true)
    end

    return nil
end

function WanderingGacha:GetNpc()
    local folder=Workspace:FindFirstChild("WanderingGacha")
    if not folder then return nil end
    return folder:FindFirstChild("WanderingGacha")
end

function WanderingGacha:Teleport()
    local npc=self:GetNpc()
    local root=self:_root(npc)
    if not root or not self.Movement then
        return false
    end

    local position=root.Position-root.CFrame.LookVector*self.Offset
    local goal=CFrame.lookAt(
        position,
        Vector3.new(root.Position.X,position.Y,root.Position.Z)
    )

    return self.Movement:FlyTo(goal,nil,MOVEMENT_OWNER)
end

function WanderingGacha:Destroy()
end

return WanderingGacha

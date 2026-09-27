local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")

local AutoChest={}
AutoChest.__index=AutoChest

local MOVEMENT_OWNER="AutoChest"

function AutoChest.new(movement)
    return setmetatable({
        Player=Players.LocalPlayer,
        Movement=movement,
        Enabled=false,
        Token=0,
        Delay=0.35,
        Height=2.5,
        LastTarget=nil
    },AutoChest)
end

function AutoChest:_character()
    local character=self.Player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not character or not humanoid or humanoid.Health<=0 or not root then return nil end
    return character,root
end

function AutoChest:_parts(model)
    return model:FindFirstChild("Part1",true),model:FindFirstChild("Part2",true)
end

function AutoChest:_targetPart(model)
    local part1,part2=self:_parts(model)
    if part1 and part1:IsA("BasePart") and part1.Transparency<0.99 then return part1 end
    if part2 and part2:IsA("BasePart") and part2.Transparency<0.99 then return part2 end
    return nil
end

function AutoChest:_spawned(model)
    return self:_targetPart(model)~=nil
end

function AutoChest:_nearest(root)
    local folder=Workspace:FindFirstChild("Bau")
    if not folder then return nil,nil end

    local bestModel,bestPart,bestDistance

    for _,model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and model.Name=="Bau" then
            local part=self:_targetPart(model)

            if part then
                local distance=(root.Position-part.Position).Magnitude

                if not bestDistance or distance<bestDistance then
                    bestModel,bestPart,bestDistance=model,part,distance
                end
            end
        end
    end

    return bestModel,bestPart
end

function AutoChest:_targetCFrame(part)
    local position=part.Position+Vector3.new(0,self.Height,0)
    local look=part.CFrame.LookVector
    local flatLook=Vector3.new(look.X,0,look.Z)

    if flatLook.Magnitude<0.01 then
        flatLook=Vector3.new(0,0,-1)
    end

    return CFrame.lookAt(position,position+flatLook.Unit)
end

function AutoChest:_move(part)
    if not self.Movement then
        return false
    end

    return self.Movement:FlyTo(self:_targetCFrame(part),nil,MOVEMENT_OWNER)
end

function AutoChest:_touch(root,part)
    if type(firetouchinterest)~="function" then return end

    pcall(firetouchinterest,root,part,0)
    task.wait(0.04)
    pcall(firetouchinterest,root,part,1)
end

function AutoChest:_run(token)
    while self.Enabled and token==self.Token do
        local _,root=self:_character()

        if not root then
            task.wait(0.4)
            continue
        end

        local model,part=self:_nearest(root)

        if not model or not part then
            self.LastTarget=nil
            task.wait(0.25)
            continue
        end

        self.LastTarget=model

        local moved=self:_move(part)
        if not self.Enabled or token~=self.Token then
            break
        end

        if moved then
            local _,newRoot=self:_character()

            if newRoot and part.Parent and self:_spawned(model) then
                self:_touch(newRoot,part)
            end
        end

        local started=os.clock()

        while self.Enabled and token==self.Token and model.Parent and self:_spawned(model) and os.clock()-started<1.25 do
            task.wait(0.08)
        end

        task.wait(self.Delay)
    end
end

function AutoChest:SetDelay(value)
    self.Delay=math.clamp(tonumber(value) or 0.35,0.1,2)
end

function AutoChest:SetEnabled(enabled)
    enabled=enabled==true
    if self.Enabled==enabled then return end

    self.Enabled=enabled
    self.Token+=1

    if enabled then
        local token=self.Token
        task.spawn(function()
            self:_run(token)
        end)
    else
        self.LastTarget=nil

        if self.Movement then
            self.Movement:CancelOwner(MOVEMENT_OWNER,true)
        end
    end
end

function AutoChest:Destroy()
    self:SetEnabled(false)
end

return AutoChest

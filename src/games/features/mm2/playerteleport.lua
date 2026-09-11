local game=game
local type=type
local ipairs=ipairs

local Factory={}

function Factory.new(context)
    context=context or {}
    local Players=context.Players or game:GetService("Players")
    local LocalPlayer=context.LocalPlayer or Players.LocalPlayer
    local RoundTracker=context.RoundTracker

    local self={
        Destroyed=false,
        Index=0,
        LastTarget=nil,
        DebugInfo={Teleports=0,LastTarget="none",AliveTargets=0,LastError="none"}
    }

    function self:_root(player)
        local character=player and player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local root=character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health<=0 or not root then return nil end
        return root
    end

    function self:GetAliveTargets()
        local targets={}
        if RoundTracker and type(RoundTracker.GetAliveRoundPlayers)=="function" then
            targets=RoundTracker:GetAliveRoundPlayers()
        else
            for _,player in ipairs(Players:GetPlayers()) do
                if player~=LocalPlayer and self:_root(player) then targets[#targets+1]=player end
            end
            table.sort(targets,function(a,b) return string.lower(a.Name)<string.lower(b.Name) end)
        end
        self.DebugInfo.AliveTargets=#targets
        return targets
    end

    function self:TeleportNext()
        if self.Destroyed then return false,"destroyed" end
        local localRoot=self:_root(LocalPlayer)
        if not localRoot then return false,"local player unavailable" end

        local targets=self:GetAliveTargets()
        if #targets==0 then
            self.Index=0
            self.LastTarget=nil
            self.DebugInfo.LastTarget="none"
            return false,"NO ALIVE PLAYERS"
        end

        self.Index=self.Index+1
        if self.Index>#targets then self.Index=1 end
        local target=targets[self.Index]
        local targetRoot=self:_root(target)
        if not targetRoot then
            return false,"TARGET LOST"
        end

        local ok,err=pcall(function()
            localRoot.CFrame=targetRoot.CFrame*CFrame.new(0,0,4)
        end)
        if not ok then
            self.DebugInfo.LastError=tostring(err)
            return false,"TELEPORT FAILED"
        end

        self.LastTarget=target
        self.DebugInfo.Teleports=self.DebugInfo.Teleports+1
        self.DebugInfo.LastTarget=target.Name
        self.DebugInfo.LastError="none"
        return true,target.Name
    end

    function self:GetDebugInfo()
        local out={}
        for k,v in pairs(self.DebugInfo) do out[k]=v end
        return out
    end

    function self:Destroy()
        self.Destroyed=true
        self.LastTarget=nil
    end

    return self
end

return Factory

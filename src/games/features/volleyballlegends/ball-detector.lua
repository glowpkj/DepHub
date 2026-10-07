local Factory={}
local function disconnectAll(list)
    for i=#list,1,-1 do local c=list[i]; list[i]=nil; c:Disconnect() end
end
local function isBall(object) return object.Name:sub(1,12)=="CLIENT_BALL_" end

function Factory.new(context)
    local Workspace=context.Workspace
    local self={Enabled=false,Destroyed=false,Connections={},Candidates={},Active=nil,OnChanged=context.OnChanged,Sequence=0,Reason="disabled"}
    function self:_setActive(candidate)
        if self.Active==candidate then return end
        self.Active=candidate
        if self.OnChanged then self.OnChanged(candidate) end
    end
    function self:_resolve(candidate)
        if not self.Enabled or self.Candidates[candidate.Object]~=candidate then return end
        local part,count=nil,0
        for _,object in ipairs(candidate.Object:GetDescendants()) do
            if object.Name=="Cube.001" and object:IsA("BasePart") then part=object; count=count+1 end
        end
        -- Ambiguous duplicate parts are not silently selected.
        if count~=1 then part=nil end
        if candidate.Part~=part then
            if self.Active==candidate then self:_setActive(nil) end
            candidate.Part=part candidate.LastPosition=nil candidate.Velocity=nil
        end
    end
    function self:_register(object)
        if not self.Enabled or not isBall(object) or self.Candidates[object] then return end
        self.Sequence=self.Sequence+1
        local candidate={Object=object,Connections={},Order=self.Sequence}
        self.Candidates[object]=candidate
        local pending=false
        local function schedule()
            if pending then return end pending=true
            task.defer(function() pending=false; self:_resolve(candidate) end)
        end
        candidate.Connections[1]=object.DescendantAdded:Connect(schedule)
        candidate.Connections[2]=object.DescendantRemoving:Connect(function(removed)
            if candidate.Part and (candidate.Part==removed or candidate.Part:IsDescendantOf(removed)) then
                candidate.Part=nil candidate.LastPosition=nil
                if self.Active==candidate then self:_setActive(nil) end
            end
            schedule()
        end)
        self:_resolve(candidate)
    end
    function self:_remove(object)
        local candidate=self.Candidates[object] if not candidate then return end
        self.Candidates[object]=nil disconnectAll(candidate.Connections)
        if self.Active==candidate then self:_setActive(nil) end
    end
    function self:Enable()
        if self.Destroyed then return false end if self.Enabled then return true end
        self.Enabled=true self.Reason="waiting for ball"
        self.Connections[1]=Workspace.ChildAdded:Connect(function(object) self:_register(object) end)
        self.Connections[2]=Workspace.ChildRemoved:Connect(function(object) self:_remove(object) end)
        for _,object in ipairs(Workspace:GetChildren()) do self:_register(object) end
        return true
    end
    function self:Sample(dt,reference)
        if not self.Enabled then return nil end
        local best=nil local valid=0
        for _,candidate in pairs(self.Candidates) do
            local part=candidate.Part
            if candidate.Object.Parent==Workspace and part and part.Parent and part:IsDescendantOf(candidate.Object) then
                valid=valid+1
                local position=part.Position
                local reported=part.AssemblyLinearVelocity
                local measured=candidate.LastPosition and dt>0 and (position-candidate.LastPosition)/dt or nil
                -- CLIENT_BALL may be moved by CFrame while anchored: physics velocity can be zero.
                local useMeasured=measured and (part.Anchored or reported.Magnitude<0.5)
                candidate.Velocity=useMeasured and measured or reported
                candidate.VelocitySource=useMeasured and "position samples" or "AssemblyLinearVelocity"
                candidate.LastPosition=position candidate.Moving=candidate.Velocity.Magnitude>=0.5
                candidate.Distance=reference and (position-reference).Magnitude or math.huge
                if not best or (candidate.Moving and not best.Moving)
                    or (candidate.Moving==best.Moving and (candidate.Distance<best.Distance
                    or (candidate.Distance==best.Distance and (candidate.Object.Name<best.Object.Name
                    or (candidate.Object.Name==best.Object.Name and candidate.Order<best.Order))))) then best=candidate end
            end
        end
        if not reference and valid>1 then best=nil self.Reason="multiple balls without player/camera reference"
        else
            -- Keep the current ball unless a same-class candidate is at least 15% closer.
            local current=self.Active
            if best and current and current.Part and current.Part.Parent and current.Object.Parent==Workspace
                and current.Moving==best.Moving and current.Distance<=best.Distance*1.15 then best=current end
            self.Reason=best and (best.Moving and "nearest moving ball" or "nearest stationary ball") or "waiting for Cube.001"
        end
        self:_setActive(best)
        return best
    end
    function self:GetExclusions()
        local list={} for object in pairs(self.Candidates) do list[#list+1]=object end return list
    end
    function self:Disable()
        if not self.Enabled then return true end
        self.Enabled=false disconnectAll(self.Connections)
        local objects={} for object in pairs(self.Candidates) do objects[#objects+1]=object end
        for _,object in ipairs(objects) do self:_remove(object) end
        self:_setActive(nil) self.Reason="disabled" return true
    end
    function self:Destroy() if self.Destroyed then return end self:Disable(); self.Destroyed=true self.OnChanged=nil end
    return self
end
return Factory

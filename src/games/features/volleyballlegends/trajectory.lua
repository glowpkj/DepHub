local Factory={}
function Factory.new(context)
    local Workspace=context.Workspace
    local self={Enabled=false,Destroyed=false,Folder=nil,Dots={},Marker=nil,Landing=nil,Impact=nil,Visible=false,
        Horizon=2,Steps=40,Params=RaycastParams.new()}
    self.Params.FilterType=Enum.RaycastFilterType.Exclude
    self.Params.IgnoreWater=true self.Params.RespectCanCollide=true
    function self:FuturePosition(position,velocity,time)
        return position+velocity*time+Vector3.new(0,-Workspace.Gravity,0)*(0.5*time*time)
    end
    function self:_createPart(name,size)
        local part=Instance.new("Part") part.Name=name part.Size=size part.Anchored=true
        part.CanCollide=false part.CanTouch=false part.CanQuery=false part.CastShadow=false
        part.Material=Enum.Material.Neon part.Color=Color3.fromRGB(255,195,65)
        part.Transparency=1 part.Parent=self.Folder return part
    end
    function self:_createVisuals()
        if self.Folder then return end
        self.Folder=Instance.new("Folder") self.Folder.Name="DepHubVolleyballTrajectory" self.Folder.Parent=Workspace
        for i=1,self.Steps do
            local dot=self:_createPart("Point"..i,Vector3.new(0.24,0.24,0.24)) dot.Shape=Enum.PartType.Ball self.Dots[i]=dot
        end
        self.Marker=self:_createPart("Landing",Vector3.new(0.06,2.5,2.5)) self.Marker.Shape=Enum.PartType.Cylinder
    end
    function self:Hide()
        if not self.Visible then return end
        self.Visible=false
        for _,dot in ipairs(self.Dots) do dot.Transparency=1 end
        if self.Marker then self.Marker.Transparency=1 end self.Landing=nil self.Impact=nil
    end
    function self:Clear()
        if self.Folder then self.Folder:Destroy() end self.Folder=nil self.Dots={} self.Marker=nil self.Landing=nil self.Impact=nil self.Visible=false
        self.Params.FilterDescendantsInstances={}
    end
    function self:SetEnabled(value)
        if self.Destroyed then return false end self.Enabled=value==true
        if not self.Enabled then self:Clear() end return true
    end
    function self:Update(candidate,excluded)
        local part=candidate and candidate.Part local velocity=candidate and candidate.Velocity
        if not self.Enabled or not part or not part.Parent or not velocity or velocity.Magnitude<0.5 then self:Hide() return end
        self:_createVisuals()
        self.Visible=true
        local filters=table.clone(excluded or {}) filters[#filters+1]=self.Folder
        -- Include every known client ball and all player characters in the caller's exclusions.
        filters[#filters+1]=candidate.Object self.Params.FilterDescendantsInstances=filters
        local position=part.Position local previous=position local hitIndex=nil
        self.Landing=nil self.Impact=nil self.Marker.Transparency=1
        for i=1,self.Steps do
            local nextPosition=self:FuturePosition(position,velocity,i*self.Horizon/self.Steps)
            local delta=nextPosition-previous
            local hit=delta.Magnitude>0.001 and Workspace:Raycast(previous,delta,self.Params) or nil
            local dot=self.Dots[i] dot.Position=hit and hit.Position or nextPosition dot.Transparency=0.15
            if hit then
                self.Impact=hit.Position hitIndex=i
                -- An upward-facing surface reached while descending is a possible floor.
                -- Walls/net collisions terminate the curve without a fake ground marker.
                if delta.Y<0 and hit.Normal.Y>=0.7 then
                    self.Landing=hit.Position
                    local normal=hit.Normal
                    local tangent=normal:Cross(Vector3.new(0,0,1))
                    if tangent.Magnitude<0.001 then tangent=normal:Cross(Vector3.new(1,0,0)) end tangent=tangent.Unit
                    self.Marker.CFrame=CFrame.fromMatrix(hit.Position+normal*0.04,normal,tangent,normal:Cross(tangent))
                    self.Marker.Transparency=0.3
                end
                break
            end
            previous=nextPosition
        end
        if hitIndex then for i=hitIndex+1,self.Steps do self.Dots[i].Transparency=1 end end
    end
    function self:Destroy() if self.Destroyed then return end self.Enabled=false self:Clear(); self.Destroyed=true end
    return self
end
return Factory

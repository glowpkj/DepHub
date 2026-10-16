-- Legacy remote contracts are unverified. States describe local work, never kills.
local Module={}
function Module.new(ctx)
    local path=ctx.Targets.Path
    local self={Jobs={},States={},Enabled={},Destroyed=false,CheckBusy=false,CheckResult="Disabled: not requested"}
    local effects,tracks={},{}
    local priorCharacterEffects={}
    local mover=ctx.Movement.new(ctx)
    self.Movement=mover
    function self:SetMovementSpeed(value) return mover:SetSpeed(value) end
    function self:SetNoclip(value) return mover:SetNoclip(value) end
    function self:PauseMovement() mover:Stop() end
    local ripperCharacter=nil
    local function state(name,value) self.States[name]=value end
    local function invoke(...)
        local remote=path(ctx.ReplicatedStorage,"Assets","Remotes","GET")
        if not remote or not remote:IsA("RemoteFunction") then error("Assets.Remotes.GET unavailable") end
        return remote:InvokeServer(...)
    end
    local function post(...)
        local remote=path(ctx.ReplicatedStorage,"Assets","Remotes","POST")
        if not remote or not remote:IsA("RemoteEvent") then error("Assets.Remotes.POST unavailable") end
        remote:FireServer(...)
    end
    local function restoreTracks()
        for track,speed in pairs(tracks) do pcall(function() track:AdjustSpeed(speed) end) end
        tracks={}
    end
    local function clearRipper()
        ctx.Properties:Clear("Ripper");restoreTracks();effects={}
    end
    local function stop(name)
        local job=self.Jobs[name];self.Jobs[name]=nil
        if job then job.Active=false;if job.Thread then pcall(task.cancel,job.Thread) end end
        if name=="Ripper" then clearRipper() end
        if name=="ClassicAutofarm" then mover:Stop() end
    end
    local function worker(name,tick,interval)
        if self.Jobs[name] then return end
        local job={Active=true,Character=ctx.Player.Character}
        self.Jobs[name]=job
        job.Thread=task.spawn(function()
            while job.Active and not self.Destroyed do
                local ok,result=pcall(tick,job)
                if not job.Active or self.Destroyed then return end
                if ok then state(name,result or "Running")
                else
                    state(name,"Error: "..tostring(result));ctx.Warn(name..": "..tostring(result))
                    if name=="Ripper" then clearRipper() end
                    if name=="ClassicAutofarm" then mover:Stop() end
                end
                task.wait(interval)
            end
        end)
    end
    local function ripperTick()
        local character=ctx.Player.Character
        if character~=ripperCharacter then clearRipper();ripperCharacter=character end
        if not ctx.Targets.Alive(character) then clearRipper();return "Waiting: alive character" end
        local now=ctx.Now()
        local selected=nil
        for _,part in ipairs(ctx.Workspace:GetChildren()) do
            if not priorCharacterEffects[part] and part:IsA("BasePart") and (part.Name==ctx.Player.Name.."_Steel" or part.Name==ctx.Player.Name.."_Thrust" or part.Name==ctx.Player.Name.."_RIP") then
                if not effects[part] then effects[part]=now+2 end
                if effects[part]>now and not selected then selected=part end
            end
        end
        for part in pairs(effects) do if not part.Parent then effects[part]=nil end end
        for part in pairs(priorCharacterEffects) do if not part.Parent then priorCharacterEffects[part]=nil end end
        if not selected then ctx.Properties:Clear("Ripper");restoreTracks();return "Waiting: own Steel / Thrust / RIP effect" end
        local desired={[selected]={Size=Vector3.new(125,125,125)}}
        local restorers={}
        local folder=path(ctx.Workspace,"Titans")
        local count=0
        for _,model in ipairs(folder and folder:GetChildren() or {}) do
            if model:IsA("Model") and model.Name~="Attack_Titan" then
                local nape=path(model,"Hitboxes","Hit","Nape")
                local head=path(model,"Fake","Head")
                if nape and nape:IsA("BasePart") and head and head:IsA("BasePart") then
                    -- Capture a head-relative transform once, not a guessed world position.
                    local original=ctx.Properties:Original(nape,"CFrame")
                    local offset=head.CFrame:ToObjectSpace(original)
                    restorers[nape]={CFrame=function() if head.Parent then return head.CFrame*offset end end}
                    desired[nape]={CFrame=selected.CFrame,Size=Vector3.new(150,150,150),Transparency=1}
                    count=count+1
                end
            end
        end
        ctx.Properties:Set("Ripper",desired,30,restorers)
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                if tracks[track]==nil then tracks[track]=track.Speed end
                track:AdjustSpeed(0)
            end
        end
        return "Running: local effect, "..count.." napes (server unconfirmed)"
    end
    local function updateRipper()
        if self.Enabled.TitanRipper or self.Enabled.SkillAutofarm then worker("Ripper",ripperTick,0.1)
        else stop("Ripper");state("Ripper","Disabled") end
    end
    -- Names, icon IDs and delays originate in the supplied script; unknown slots are skipped.
    -- Icon-to-ID associations follow the three legacy skill names/sequence;
    -- unlike explicit SkillId attributes, these associations still need live validation.
    local sequence={{"108","15216496277",0.1},{"14","15215073606",2.5},{"23","15215081865",0.1},{"14","15215073606",0.5}}
    local function hotbar()
        return path(ctx.Player,"PlayerGui","Interface","HUD","Main","Top","7","Hotbar")
    end
    local function equipped(id,icon)
        local bar=hotbar()
        for _,slot in ipairs(bar and bar:GetChildren() or {}) do
            if slot.Name:find("Skill",1,true) then
                local image=path(slot,"Inner","Icon")
                local matches=slot:GetAttribute("SkillId")==id or tostring(slot:GetAttribute("SkillId") or "")==id
                if icon and image and (image:IsA("ImageLabel") or image:IsA("ImageButton")) then matches=matches or image.Image:match("(%d+)$")==icon end
                if matches then
                    local cooldown=path(slot,"Cooldown")
                    if not cooldown or not cooldown:IsA("GuiObject") then return false,"missing Cooldown" end
                    return not cooldown.Visible,cooldown.Visible and "cooldown" or "ready"
                end
            end
        end
        return false,"equipment not identified"
    end
    local function skillTick(job)
        if job.Character~=ctx.Player.Character then job.Character=ctx.Player.Character;job.Step=1;job.NextAt=0 end
        local root=ctx.Targets.Alive(job.Character)
        if not root then return "Waiting: alive character" end
        if root.Anchored or job.Character:GetAttribute("IFrames")==true then return "Waiting: character unavailable / IFrames" end
        if not ctx.Targets.Select(ctx.Workspace,root) then return "Waiting: live target" end
        if ctx.Now()<(job.NextAt or 0) then return "Waiting: sequence delay" end
        local index=job.Step or 1
        local step=sequence[index]
        local ready,reason=equipped(step[1],step[2])
        job.Step=index%#sequence+1
        job.NextAt=ctx.Now()+step[3]
        if not ready then return "Waiting: skill "..step[1].." / "..reason end
        state("SkillAutofarm","Running: requesting skill "..step[1].." (server unconfirmed)")
        invoke("S_Skills","Usage",step[1])
        return "Running: skill "..step[1].." requested (server unconfirmed)"
    end
    local function classicTick(job)
        if job.Character~=ctx.Player.Character then mover:Stop();job.Character=ctx.Player.Character;job.NextAttack=0;job.Target=nil end
        local root=ctx.Targets.Alive(job.Character)
        if not root then mover:Stop();return "Waiting: alive character" end
        if root.Anchored or job.Character:GetAttribute("IFrames")==true then mover:Stop();return "Waiting: character unavailable / IFrames" end
        if ctx.IsTeleporting() then mover:Stop();return "Waiting: refill teleport" end
        local blade=path(job.Character,"Rig_"..ctx.Player.Name,"LeftHand","Blade_1")
        if not blade or not blade:IsA("BasePart") then mover:Stop();return "Waiting: blade reference" end
        if blade.Transparency==1 then
            local top=path(ctx.Player,"PlayerGui","Interface","HUD","Main","Top")
            local sets=path(top and top:FindFirstChild("Blade",true),"Sets")
            local available=sets and (sets:IsA("TextLabel") or sets:IsA("TextButton")) and tonumber(sets.Text:match("(%d+)%s*/"))
            if available~=0 then mover:Stop();return "Waiting: blade reload / enable Blade Refill" end
            local refill=ctx.FindRefill()
            if not refill then mover:Stop();return "Waiting: GasTanks.Refill" end
            mover:Move(root,refill,3)
            if (root.Position-refill.Position).Magnitude>20 then return "Running: approaching refill" end
            if ctx.Now()<(job.NextRefill or 0) then return "Waiting: refill response / HUD confirmation" end
            job.NextRefill=ctx.Now()+5
            state("ClassicAutofarm","Running: requesting full reload (server unconfirmed)")
            invoke("Blades","Full_Reload","Left",refill)
            if not job.Active or self.Destroyed or job.Character~=ctx.Player.Character then return "Waiting: character changed" end
            invoke("Blades","Full_Reload","Right",refill)
            return "Waiting: full reload requested / HUD confirmation"
        end
        local target=job.Target
        local folder=path(ctx.Workspace,"Titans")
        local humanoid=target and target.Model:FindFirstChildOfClass("Humanoid")
        if target and (not target.Part.Parent or target.Model.Parent~=folder or not humanoid or humanoid.Health<=0
            or (target.Boss and ctx.Targets.Marker(target.Model)~=target.Part)) then target=nil end
        local distance
        if not target then target,distance=ctx.Targets.Select(ctx.Workspace,root) end
        job.Target=target
        if not target then mover:Stop();return distance end
        mover:Move(root,target.Part,target.Boss and 195 or 75,target.Model)
        -- Recheck the live target/root immediately before sending an attack.
        if not target.Part.Parent or not target.Model.Parent then mover:Stop();return "Waiting: target removed" end
        distance=(root.Position-target.Part.Position).Magnitude
        if ctx.Now()<(job.NextAttack or 0) then return "Running: moving toward "..target.Model.Name end
        if distance>(target.Boss and 250 or 175) then return "Running: approaching target" end
        job.NextAttack=ctx.Now()+1
        post("Attacks","Slash",true)
        if not job.Active or self.Destroyed or job.Character~=ctx.Player.Character then return "Waiting: character changed" end
        state("ClassicAutofarm","Running: registering local target (server unconfirmed)")
        -- Preserve the reference contract without inventing random hit speed/damage.
        invoke("Hitboxes","Register",target.Part,root.AssemblyLinearVelocity.Magnitude,0)
        return "Running: attack requested (server unconfirmed)"
    end
    function self:SetToggle(name,enabled)
        if self.Destroyed or (name~="TitanRipper" and name~="SkillAutofarm" and name~="ClassicAutofarm") then return false end
        enabled=enabled==true
        if self.Enabled[name]==enabled then return true end
        self.Enabled[name]=enabled
        state(name,enabled and "Waiting: starting" or "Disabled")
        if name=="SkillAutofarm" then
            if enabled then worker(name,skillTick,0.2) else stop(name) end
        elseif name=="ClassicAutofarm" then
            if enabled then ctx.CancelTeleport();worker(name,classicTick,0.15) else stop(name) end
        end
        updateRipper()
        return true
    end
    function self:CheckShadowBan()
        if self.Destroyed or self.CheckBusy then return false end
        if self.CheckWatchdog then pcall(task.cancel,self.CheckWatchdog);self.CheckWatchdog=nil end
        self.CheckToken=(self.CheckToken or 0)+1
        local token=self.CheckToken
        self.CheckBusy=true;self.CheckResult="Running: requesting account diagnostic"
        self.CheckThread=task.spawn(function()
            local ok,data=pcall(invoke,"Data","Get")
            if self.Destroyed or token~=self.CheckToken then return end
            self.CheckBusy=false;self.CheckThread=nil
            if self.CheckWatchdog then pcall(task.cancel,self.CheckWatchdog);self.CheckWatchdog=nil end
            -- No reliable schema was supplied. Inspect types, never infer a ban verdict.
            if not ok then self.CheckResult="Error: "..tostring(data);ctx.Warn(self.CheckResult)
            elseif type(data)~="table" then self.CheckResult="Waiting: inconclusive / response is "..type(data)
            else
                local count=0
                for key in pairs(data) do if type(key)=="string" and key:lower():find("blacklist",1,true) then count=count+1 end end
                self.CheckResult="Waiting: inconclusive / "..count.." blacklist-like fields; schema unverified"
            end
        end)
        if self.CheckBusy then self.CheckWatchdog=task.spawn(function()
            task.wait(15)
            if self.Destroyed or token~=self.CheckToken or not self.CheckBusy then return end
            self.CheckToken=self.CheckToken+1
            if self.CheckThread then pcall(task.cancel,self.CheckThread);self.CheckThread=nil end
            self.CheckBusy=false
            self.CheckResult="Error: diagnostic timeout; result inconclusive"
            ctx.Warn(self.CheckResult)
        end) end
        return true
    end
    self.Respawn=ctx.Player.CharacterRemoving:Connect(function()
        for part in pairs(effects) do priorCharacterEffects[part]=true end
        mover:Stop();clearRipper()
        -- Cancel in-flight workers on character removal, without changing user's toggles.
        for _,name in ipairs({"Ripper","SkillAutofarm","ClassicAutofarm"}) do stop(name) end
        for name,enabled in pairs(self.Enabled) do if enabled then state(name,"Waiting: respawn") end end
    end)
    self.CharacterAdded=ctx.Player.CharacterAdded:Connect(function()
        if self.Destroyed then return end
        if self.Enabled.SkillAutofarm then worker("SkillAutofarm",skillTick,0.2) end
        if self.Enabled.ClassicAutofarm then worker("ClassicAutofarm",classicTick,0.15) end
        updateRipper()
    end)
    function self:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        self.Respawn:Disconnect();self.CharacterAdded:Disconnect()
        for _,name in ipairs({"Ripper","SkillAutofarm","ClassicAutofarm"}) do stop(name) end
        if self.CheckThread then pcall(task.cancel,self.CheckThread) end
        if self.CheckWatchdog then pcall(task.cancel,self.CheckWatchdog) end
        self.CheckBusy=false;mover:Destroy()
    end
    return self
end
return Module

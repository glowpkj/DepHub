-- Deterministic scheduler and API doubles. No Roblox runtime validation.
local cf={}
local cfMeta={}
function cf.new(position) return setmetatable({Position=position},cfMeta) end
function cfMeta.__mul(a,b) return cf.new(a.Position+b.Position) end
function cfMeta.__index(a,key)
    if key=="ToObjectSpace" then return function(_,b) return cf.new(b.Position-a.Position) end end
end
local function aotrContext()
    local ctx=sandbox()
    ctx.Time=0;ctx.Fibers={};ctx.Cancelled=0
    ctx.Env.Vector3=vectors;ctx.Env.CFrame=cf
    ctx.Env.os={clock=function() return ctx.Time end}
    ctx.Env.task.spawn=function(fn,...)
        local fiber={Thread=coroutine.create(fn),Args={...},Due=ctx.Time}
        ctx.Fibers[#ctx.Fibers+1]=fiber
        return fiber.Thread
    end
    ctx.Env.task.wait=function(seconds) return coroutine.yield(seconds or 0) end
    ctx.Env.task.cancel=function(thread)
        ctx.Cancelled+=1
        if coroutine.status(thread)~="dead" then coroutine.close(thread) end
    end
    function ctx:Step(dt)
        self.Time+=dt or 0
        for _,fiber in ipairs(table.clone(self.Fibers)) do
            if coroutine.status(fiber.Thread)~="dead" and fiber.Due<=self.Time then
                local ok,delay=coroutine.resume(fiber.Thread,unpack(fiber.Args))
                fiber.Args={}
                assert(ok,delay)
                fiber.Due=self.Time+(tonumber(delay) or 0)
            end
        end
    end
    ctx.Services.TweenService={}
    ctx.Player.Name="Tester";ctx.Player.Idled=signal()
    function ctx:Object(class,name,parent)
        local item=Instance.new(class);item.Name=name;item.Parent=parent;return item
    end
    function ctx:Character()
        local char=self:Object("Model","Character",self.Player)
        local root=self:Object("Part","HumanoidRootPart",char)
        root.Position=vectors.new(0,0,0);root.CFrame=cf.new(root.Position)
        root.AssemblyLinearVelocity=vectors.new(4,0,0);root.AssemblyAngularVelocity=vectors.new(0,2,0)
        local hum=self:Object("Humanoid","Humanoid",char);hum.Health=100
        local rig=self:Object("Model","Rig_Tester",char)
        local blade=self:Object("Part","Blade_1",self:Object("Folder","LeftHand",rig));blade.Transparency=0
        self.Player.Character=char
        return char,root,hum,blade
    end
    function ctx:Titan(name,pos)
        local folder=self.Services.Workspace:FindFirstChild("Titans") or self:Object("Folder","Titans",self.Services.Workspace)
        local model=self:Object("Model",name,folder)
        local hum=self:Object("Humanoid","Humanoid",model);hum.Health=100
        local hit=self:Object("Folder","Hit",self:Object("Folder","Hitboxes",model))
        local nape=self:Object("Part","Nape",hit);nape.Position=pos;nape.CFrame=cf.new(pos)
        nape.Size=vectors.new(15,9,11);nape.Transparency=1
        local head=self:Object("Part","Head",self:Object("Model","Fake",model));head.Position=pos;head.CFrame=cf.new(pos)
        return model,nape,head,hum
    end
    ctx.Calls={}
    local assets=ctx:Object("Folder","Assets",ctx.Services.ReplicatedStorage)
    local remotes=ctx:Object("Folder","Remotes",assets)
    ctx.Get=ctx:Object("RemoteFunction","GET",remotes)
    ctx.Post=ctx:Object("RemoteEvent","POST",remotes)
    function ctx.Get:InvokeServer(...)
        local args={...};ctx.Calls[#ctx.Calls+1]=args
        if args[1]=="Data" then if ctx.Hang then coroutine.yield(100) end;return ctx.Data end
        if ctx.RemoteError then error("mock remote failure") end
        return nil
    end
    function ctx.Post:FireServer(...) ctx.Calls[#ctx.Calls+1]={...} end
    for _,name in ipairs({"properties","targets","movement","combat","assistance"}) do
        local p="src/games/features/aotr/"..name..".lua";ctx.Responses[p]=sources[p]
    end
    function ctx:Backend() return self:Run("src/games/aotr.lua") end
    return ctx
end

do
    local ctx=aotrContext();local char,root=ctx:Character()
    local near,nape,head=ctx:Titan("Near",vectors.new(10,0,0))
    local _,_,_,dead=ctx:Titan("Dead",vectors.new(1,0,0));dead.Health=0
    ctx:Titan("Far",vectors.new(80,0,0))
    local targets=ctx:Run("src/games/features/aotr/targets.lua")
    local selection=targets.Select(ctx.Services.Workspace,root)
    check(selection.Model==near,"AOTR nearest target ignores dead titans")
    local boss,bossNape=ctx:Titan("Attack_Titan",vectors.new(2,0,0))
    selection=targets.Select(ctx.Services.Workspace,root)
    check(selection.Model==near,"AOTR boss without marker is not attacked")
    local marker=ctx:Object("BillboardGui","Marker",boss);marker.Adornee=nape
    check(targets.Marker(boss)==nil,"AOTR boss marker cannot target unrelated models")
    marker.Adornee=bossNape
    check(targets.Select(ctx.Services.Workspace,root).Model==boss,"AOTR uses validated live boss weakpoint")
    local backend=ctx:Backend()
    check(next(backend.Combat.Enabled)==nil and #ctx.Calls==0,"AOTR combat and account queries never auto-start")
    backend:SetToggle("NapeExtend",true);backend:SetNapeMultiplier(2)
    local effect=ctx:Object("Part","Tester_Steel",ctx.Services.Workspace)
    effect.Size=vectors.new(5,5,5);effect.CFrame=cf.new(vectors.new(50,0,0))
    local track={Speed=0.7,AdjustSpeed=function(self,s) self.Speed=s end}
    local hum=char:FindFirstChildOfClass("Humanoid")
    local animator=ctx:Object("Animator","Animator",hum)
    animator.GetPlayingAnimationTracks=function() return {track} end
    check(backend:SetToggle("TitanRipper",true),"AOTR Ripper enables")
    local job=backend.Combat.Jobs.Ripper
    backend:SetToggle("TitanRipper",true)
    check(backend.Combat.Jobs.Ripper==job,"AOTR Ripper enable is idempotent")
    ctx:Step(0)
    check(nape.Size.X==150 and effect.Size.X==125 and track.Speed==0,"AOTR Ripper applies effect and freezes owned animation state")
    backend:Refresh()
    check(nape.Size.X==150,"AOTR visual refresh cannot overwrite Ripper")
    head.CFrame=cf.new(vectors.new(30,0,0))
    backend:SetToggle("TitanRipper",false)
    check(nape.CFrame.Position.X==30 and nape.Size.X==30 and effect.Size.X==5 and track.Speed==0.7,"AOTR Ripper restores moving-head offset, active extension, effect and exact animation speed")
    backend:SetToggle("NapeExtend",false)
    check(nape.Size.X==15,"AOTR property layers finally restore base dimensions")
    backend:SetToggle("TitanRipper",true);ctx:Step(0.1)
    ctx.Player.CharacterRemoving:Fire(char)
    check(next(backend.Combat.Jobs)==nil and effect.Size.X==5,"AOTR respawn cancels Ripper work and restores effects")
    ctx:Character();ctx.Player.CharacterAdded:Fire(ctx.Player.Character)
    check(backend.Combat.Jobs.Ripper~=nil,"AOTR explicitly enabled Ripper resumes with new character")
    backend:Destroy()
    check(not backend.Combat.Respawn.Connected and next(backend.Properties.Records)==nil,"AOTR unload releases listeners and property records")
end

do
    local ctx=aotrContext();local char,root,hum=ctx:Character()
    ctx:Titan("Titan",vectors.new(10,0,0))
    local oldBV=ctx:Object("BodyVelocity","BV",root);oldBV.MaxForce=vectors.new(9,9,9)
    local map=ctx:Object("Folder","Climbable",ctx.Services.Workspace)
    local wall=ctx:Object("Part","Wall",map);wall.CanCollide=true
    local backend=ctx:Backend()
    backend:SetToggle("ClassicAutofarm",true);ctx:Step(0)
    check(root:FindFirstChild("DepHub_AOTR_FarmPosition")~=nil,"AOTR classic farm creates its own mover")
    check(#ctx.Calls==2 and ctx.Calls[1][1]=="Attacks" and ctx.Calls[2][2]=="Register","AOTR classic farm uses observed attack contract")
    local prior=#ctx.Calls
    backend:SetToggle("ClassicAutofarm",false);ctx:Step(2)
    check(#ctx.Calls==prior and root:FindFirstChild("DepHub_AOTR_FarmPosition")==nil,"AOTR classic disable cancels sends and removes movers")
    check(root.AssemblyLinearVelocity.X==4,"AOTR classic cleanup restores captured local velocity")
    check(oldBV.Parent==root and oldBV.MaxForce.X==9 and wall.Parent==map and wall.CanCollide,"AOTR classic farm preserves game movers, map and collisions")
    backend:SetToggle("ClassicAutofarm",true);ctx:Step(0)
    hum.Health=0;ctx:Step(0.2)
    check(root:FindFirstChild("DepHub_AOTR_FarmPosition")==nil,"AOTR death stops movement before respawn")
    ctx.Player.CharacterRemoving:Fire(char)
    local newChar,newRoot=ctx:Character();ctx.Player.CharacterAdded:Fire(newChar);ctx:Step(0)
    check(newRoot:FindFirstChild("DepHub_AOTR_FarmPosition")~=nil and root:FindFirstChild("DepHub_AOTR_FarmPosition")==nil,"AOTR classic resumes on new root without stale mover")
    backend:Destroy();ctx:Step(2)
    check(newRoot:FindFirstChild("DepHub_AOTR_FarmPosition")==nil,"AOTR unload removes new-character mover")
end

do
    local ctx=aotrContext();local _,root=ctx:Character();ctx:Titan("Titan",vectors.new(10,0,0));ctx.RemoteError=true
    local backend=ctx:Backend();backend:SetToggle("ClassicAutofarm",true);ctx:Step(0)
    check(backend.Combat.States.ClassicAutofarm:find("Error:",1,true)==1 and root:FindFirstChild("DepHub_AOTR_FarmPosition")==nil,"AOTR remote failure restores movement and reports Error")
    check(not backend.Destroyed and backend:SetToggle("NapeVisible",true),"AOTR isolated combat error preserves the hub")
    backend:Destroy()
end

do
    local ctx=aotrContext();ctx:Character();ctx:Titan("Titan",vectors.new(10,0,0))
    local gui=ctx:Object("Folder","PlayerGui",ctx.Player)
    local top=gui
    for _,name in ipairs({"Interface","HUD","Main","Top","7","Hotbar"}) do top=ctx:Object("Folder",name,top) end
    local slot=ctx:Object("Folder","Skill_1",top);slot:SetAttribute("SkillId","108")
    local cooldown=ctx:Object("TextLabel","Cooldown",slot);cooldown.Visible=true
    -- Supply GuiObject inheritance only for these test objects.
    local old=methods.IsA
    function methods:IsA(class) return class=="GuiObject" and self.ClassName=="TextLabel" or old(self,class) end
    local backend=ctx:Backend()
    backend:SetToggle("SkillAutofarm",true);local job=backend.Combat.Jobs.SkillAutofarm
    backend:SetToggle("SkillAutofarm",true);ctx:Step(0)
    check(job==backend.Combat.Jobs.SkillAutofarm and #ctx.Calls==0,"AOTR skill farm gates cooldown and avoids duplicate worker")
    cooldown.Visible=false;ctx:Step(0.2);ctx:Step(3);ctx:Step(0.2);ctx:Step(0.6);ctx:Step(0.2)
    check(#ctx.Calls==1 and ctx.Calls[1][3]=="108","AOTR skill sequence skips unidentified equipment and sends only ready known skill")
    backend:SetToggle("TitanRipper",true);backend:SetToggle("SkillAutofarm",false)
    check(backend.Combat.Jobs.Ripper~=nil,"AOTR disabling skill farm preserves separately enabled Ripper")
    backend:SetToggle("TitanRipper",false)
    check(backend.Combat.Jobs.Ripper==nil,"AOTR shared Ripper stops after last owner releases")
    local prior=#ctx.Calls;ctx:Step(5)
    check(#ctx.Calls==prior,"AOTR disabled skill sequence cannot resume after delay")
    backend:Destroy();methods.IsA=old
end

do
    local ctx=aotrContext();local char=ctx:Character();local backend=ctx:Backend()
    backend:SetToggle("AutoGrabEscape",true);ctx:Step(0)
    check(#ctx.Calls==0,"AOTR escape does not fire without explicit indicator")
    local gui=ctx:Object("Folder","PlayerGui",ctx.Player)
    local buttons=ctx:Object("Folder","Buttons",ctx:Object("Folder","Interface",gui));ctx:Object("TextLabel","Unrelated",buttons)
    ctx:Step(0.6)
    check(#ctx.Calls==0,"AOTR unrelated GUI changes never trigger grab escape")
    char:SetAttribute("Grabbed",true);ctx:Step(0.6);ctx:Step(0.6)
    check(#ctx.Calls==1 and ctx.Calls[1][2]=="Slash_Escape","AOTR one escape request per explicit grab episode")
    char:SetAttribute("Grabbed",false);ctx:Step(0.6);char:SetAttribute("Grabbed",true);ctx:Step(0.6)
    check(#ctx.Calls==2,"AOTR new grab episode can request escape")
    local folder=ctx:Object("Folder","Injuries",char);local injury=ctx:Object("Folder","Arm",folder)
    backend:SetToggle("AntiInjury",true);ctx:Step(0)
    check(injury.Parent==nil,"AOTR detaches local injury without destruction")
    ctx.Player.CharacterRemoving:Fire(char)
    check(injury.Parent==folder,"AOTR respawn restores recoverable injuries to old folder")
    local newChar=ctx:Character();ctx.Player.CharacterAdded:Fire(newChar);ctx:Step(0)
    check(injury.Parent==folder and #ctx.Calls==2,"AOTR new character cannot inherit injuries or stale grab state")
    backend:Destroy();ctx:Step(1)
    check(next(backend.Assistance.Jobs)==nil and not backend.Assistance.Added.Connected,"AOTR assistance unload removes workers and respawn hooks")
end

do
    local ctx=aotrContext();local backend=ctx:Backend()
    for _,data in ipairs({{Is_Blacklisted=true},{strange_blacklist=false,[1]=true},"unknown"}) do
        ctx.Data=data;check(backend:CheckShadowBan(),"AOTR explicit diagnostic starts asynchronously")
        check(not backend:CheckShadowBan(),"AOTR concurrent diagnostic is rejected")
        ctx:Step(0)
        check(backend.Combat.CheckResult:find("inconclusive",1,true)~=nil,"AOTR blacklist field names never yield a ban verdict")
    end
    ctx.Hang=true;backend:CheckShadowBan();ctx:Step(0);ctx:Step(16)
    check(not backend.Combat.CheckBusy and backend.Combat.CheckResult:find("timeout",1,true)~=nil,"AOTR hung diagnostic times out without blocking UI")
    ctx.Hang=false;ctx.Data=nil;check(backend:CheckShadowBan(),"AOTR diagnostic retry allowed after timeout");ctx:Step(0)
    check(backend.Combat.CheckResult:find("inconclusive",1,true)~=nil,"AOTR nil response is inconclusive")
    backend:SetToggle("ClassicAutofarm",true);ctx:Step(0)
    check(backend.Combat.States.ClassicAutofarm:find("Waiting",1,true)==1,"AOTR missing character becomes Waiting")
    backend:Destroy();check(not backend:CheckShadowBan(),"AOTR destroyed diagnostic cannot restart")
end

do
    local ctx=aotrContext();local char,root,_,blade=ctx:Character()
    local gui=ctx:Object("Folder","PlayerGui",ctx.Player)
    local interface=ctx:Object("Folder","Interface",gui)
    local top=interface
    for _,name in ipairs({"HUD","Main","Top"}) do top=ctx:Object("Folder",name,top) end
    local sets=ctx:Object("TextLabel","Sets",ctx:Object("Folder","Blade",top));sets.Text="2 / 3"
    local oldFind=methods.FindFirstChild
    function methods:FindFirstChild(name,recursive)
        local item=oldFind(self,name)
        if item or not recursive then return item end
        for _,child in ipairs(self:GetDescendants()) do if child.Name==name then return child end end
    end
    local oldIsA=methods.IsA
    function methods:IsA(class) return class=="GuiObject" and self.ClassName=="TextLabel" or oldIsA(self,class) end
    local backend=ctx:Backend();blade.Transparency=1
    backend:SetToggle("AutoBladeRefill",true);ctx:Step(0)
    check(#ctx.Calls==1 and ctx.Calls[1][2]=="Reload" and sets.Text=="2 / 3","AOTR reload uses stock without falsifying HUD")
    backend:SetToggle("AutoBladeRefill",false);ctx:Step(2)
    check(#ctx.Calls==1,"AOTR disabled blade reload cannot send")
    local gas=ctx:Object("Folder","GasTanks",ctx:Object("Folder","Unclimbable",ctx.Services.Workspace))
    local refill=ctx:Object("Part","Refill",gas);refill.Position=vectors.new(0,0,0)
    sets.Text="0 / 3"
    backend:SetToggle("ClassicAutofarm",true);ctx:Step(0)
    check(#ctx.Calls==3 and ctx.Calls[2][2]=="Full_Reload" and ctx.Calls[3][3]=="Right","AOTR classic farm refills both blades near validated refill")
    ctx:Step(1)
    check(#ctx.Calls==3 and sets.Text=="0 / 3","AOTR full reload waits for HUD and throttles requests")
    backend:SetToggle("ClassicAutofarm",false)
    local rewards=ctx:Object("TextLabel","Rewards",interface);rewards.Visible=true
    local parent=rewards
    for _,name in ipairs({"Main","Info","Main","Buttons","Retry"}) do parent=ctx:Object("Folder",name,parent) end
    local title=ctx:Object("TextLabel","Title",parent);title.Text="RETRY (1/4)";title.Visible=true
    backend:SetToggle("AutoRetry",true);ctx:Step(0)
    local count=#ctx.Calls;ctx:Step(0.6)
    check(count==4 and #ctx.Calls==count,"AOTR retry votes once per visible reward episode")
    rewards.Visible=false;ctx:Step(0.6);rewards.Visible=true;ctx:Step(0.6)
    check(#ctx.Calls==count+1,"AOTR retry resets when rewards actually hide")
    backend:SetToggle("AntiAFK",true)
    local first=ctx.Player.Idled.connections[#ctx.Player.Idled.connections]
    ctx.Player.CharacterRemoving:Fire(char)
    check(not first.Connected,"AOTR respawn releases old idle handler")
    local nextChar=ctx:Character();ctx.Player.CharacterAdded:Fire(nextChar)
    local last=ctx.Player.Idled.connections[#ctx.Player.Idled.connections]
    check(last~=first and last.Connected,"AOTR explicitly enabled idle handler rebinds once")
    local replacement=ctx:Backend()
    check(backend.Destroyed and not last.Connected and next(replacement.Combat.Enabled)==nil,"AOTR backend restart destroys previous workers and starts with all combat off")
    replacement:Destroy()
    methods.FindFirstChild=oldFind;methods.IsA=oldIsA
end

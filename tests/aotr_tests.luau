-- Behavioral checks with API doubles; no claim of in-game functionality.
do
    for _,ids in ipairs({{13379208636,2},{999,4658598196}}) do
        local ctx=sandbox(ids[1],ids[2])
        ctx.Responses["src/version.txt"]="0.0.37"
        ctx:Provide("src/games/aotr.lua",{Destroyed=false})
        check(ctx:Run("DepHub.lua")==true,"AOTR routes without game.Name")
        check(ctx.State.__DEPHUB.AOTR~=nil and ctx.State.__DEPHUB.BloxFruits==nil,"AOTR route preserves backend identity")
        check(ctx.State.__DEPHUB.Mode=="aotr" and ctx.State.__DEPHUB.Backend==ctx.State.__DEPHUB.AOTR,"AOTR route exposes its backend and label")
    end
    local ctx=sandbox()
    ctx.Services.TweenService={}
    ctx.Player.Name="Tester"
    ctx.Player.Idled=signal()
    ctx.Responses["src/games/features/aotr/assistance.lua"]=sources["src/games/features/aotr/assistance.lua"]
    local function object(class,name,parent)
        local item=Instance.new(class);item.Name=name;item.Parent=parent;return item
    end
    local folder=object("Folder","Titans",ctx.Services.Workspace)
    local model=object("Model","Titan",folder)
    local hit=object("Folder","Hit",object("Folder","Hitboxes",model))
    local nape=object("Part","Nape",hit)
    nape.Size=Vector3.new(15,9,11);nape.Transparency=1
    object("Highlight","Unrelated",folder)
    local backend=ctx:Run("src/games/aotr.lua")
    check(backend:SetToggle("NapeVisible",true) and nape.Transparency==0.65,"AOTR ignores Highlight siblings")
    backend:SetNapeMultiplier(2);backend:SetToggle("NapeExtend",true)
    check(nape.Size.X==30,"AOTR extends from captured dimensions")
    backend:SetToggle("NapeVisible",false)
    check(nape.Size.X==30 and nape.Transparency==1,"AOTR toggles restore independently")
    check(not backend:SetNapeMultiplier(0/0) and not backend:SetNapeMultiplier(3),"AOTR rejects NaN and invalid multipliers")
    backend:SetToggle("NapeExtend",false)
    check(nape.Size.X==15,"AOTR restores original dimensions")
    backend:SetToggle("TitanESP",true);backend:SetToggle("TitanESP",true)
    check(#model:GetChildren()==2,"AOTR repeated enable does not duplicate ESP")
    backend:SetToggle("TitanESP",false)
    check(folder:FindFirstChild("Unrelated")~=nil,"AOTR preserves unrelated highlights")
    local boss=object("Model","Attack_Titan",folder)
    local bossHit=object("Folder","Hit",object("Folder","Hitboxes",boss))
    local weakpoint=object("Part","LeftLeg",bossHit);weakpoint.Size=Vector3.new(10,20,10);weakpoint.Transparency=1
    local marker=object("BillboardGui","Marker",boss);marker.Adornee=weakpoint
    backend:SetToggle("ErenExtend",true)
    check(weakpoint.Size.X==95,"AOTR extends validated marker target")
    marker.Adornee=nape;backend:Refresh()
    check(weakpoint.Size.X==10,"AOTR restores previous marker target and rejects another titan")
    backend:SetToggle("AntiAFK",true)
    local idle=ctx.Player.Idled.connections[1]
    backend:SetToggle("AntiAFK",false)
    check(not idle.Connected,"AOTR disconnects its own idle handler")
    local character=object("Model","Character",ctx.Player);ctx.Player.Character=character
    local injuries=object("Folder","Injuries",character)
    local injury=object("Folder","Arm",injuries)
    backend:SetToggle("AntiInjury",true)
    local call=ctx.Spawned[#ctx.Spawned]
    ctx.Env.task.wait=function() coroutine.yield() end
    local thread=coroutine.create(call.Fn)
    check(coroutine.resume(thread),"AOTR injury worker starts")
    check(injury.Parent==nil,"AOTR injury is retained outside folder")
    backend:SetToggle("AntiInjury",false)
    check(injury.Parent==injuries,"AOTR restores detached injury on disable")
    backend:Destroy();backend:Destroy()
    check(ctx.State.__DEPHUB.AOTR==nil and not backend:SetToggle("AntiAFK",true),"AOTR destroy clears runtime and rejects enable")
    check(not backend:SetNapeMultiplier(1) and not backend:TeleportToRefill(),"AOTR destroyed backend rejects mutation")
end

-- Combat integration: the restored combat module is wired through the backend's
-- own toggle contract, so the combat toggles must route to the module rather
-- than being stored as inert booleans on the backend.
do
    local ctx=sandbox()
    ctx.Services.TweenService={Create=function(_,_,_,_)
        return {Play=function() end,Cancel=function() end,Completed={Connect=function() return {Disconnect=function() end} end}}
    end}
    ctx.Player.Name="Tester"
    local function object(class,name,parent)
        local item=Instance.new(class);item.Name=name;item.Parent=parent;return item
    end
    -- Remote contract: Assets.Remotes.GET (RemoteFunction) and POST (RemoteEvent).
    local assets=object("Folder","Assets",ctx.Services.ReplicatedStorage)
    local remotes=object("Folder","Remotes",assets)
    local get=object("RemoteFunction","GET",remotes)
    local post=object("RemoteEvent","POST",remotes)
    -- A live titan with a resolvable nape.
    local folder=object("Folder","Titans",ctx.Services.Workspace)
    local model=object("Model","Titan",folder)
    local humanoid=object("Humanoid","Humanoid",model);humanoid.Health=100
    local hit=object("Folder","Hit",object("Folder","Hitboxes",model))
    local nape=object("Part","Nape",hit);nape.Size=Vector3.new(15,9,11);nape.Transparency=1
    -- Local character with a rooted humanoid.
    local character=object("Model","Character",ctx.Player);ctx.Player.Character=character
    local charHumanoid=object("Humanoid","Humanoid",character);charHumanoid.Health=100
    local root=object("Part","HumanoidRootPart",character)
    local backend=ctx:Run("src/games/aotr.lua")
    check(backend.Combat~=nil,"AOTR loads the combat module when its dependencies resolve")
    check(backend:SetToggle("ClassicAutofarm",true),"AOTR routes the ClassicAutofarm toggle to the combat module")
    check(backend.Toggles.ClassicAutofarm==true,"AOTR records the routed combat toggle state")
    check(backend:SetToggle("ClassicAutofarm",false),"AOTR disables the ClassicAutofarm toggle")
    check(backend:SetToggle("SkillAutofarm",true) and backend:SetToggle("SkillAutofarm",false),"AOTR routes the SkillAutofarm toggle")
    check(backend:SetToggle("ClassicNoclip",false) and backend:SetToggle("ClassicNoclip",true),"AOTR routes the farm noclip toggle to the movement module")
    check(backend:SetTravelSpeed(1500) and backend.Values.TravelSpeed==1500,"AOTR applies travel speed through the combat module")
    check(not backend:SetTravelSpeed(10) and not backend:SetTravelSpeed(9000),"AOTR rejects out-of-range travel speed")
    check(backend:CheckShadowBan()==true,"AOTR exposes the combat diagnostic through CheckShadowBan")
    check(not backend:SetToggle("NotAFeature",true),"AOTR rejects unknown toggles")
    backend:Destroy()
    check(ctx.State.__DEPHUB.AOTR==nil,"AOTR combat teardown releases the backend")
end

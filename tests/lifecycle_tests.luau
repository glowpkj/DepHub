do
    local ctx=sandbox()
    ctx.Responses["src/version.txt"]="0.0.29"
    local backend={Destroyed=false,Destroy=function(self) self.Destroyed=true end}
    local frontend={Destroyed=false,Destroy=function(self) self.Destroyed=true end}
    ctx:Provide("src/games/universal.lua",backend)
    ctx:Provide("library/init.lua",{new=function() frontend.Destroyed=false; backend.Destroyed=false; return frontend end})
    local updaterCreations=0
    ctx:Provide("src/core/updater.lua",{new=function() updaterCreations+=1; return {Start=function() end} end})
    check(ctx:Run("DepHub.lua")==true,"initial loader session starts")
    local requests=#ctx.Requests
    check(ctx:Run("DepHub.lua")==true and #ctx.Requests==requests,"healthy session is reused")
    frontend.Destroyed=true
    check(ctx:Run("DepHub.lua")==true and #ctx.Requests>requests,"destroyed frontend forces rebuild")
    ctx:FlushDeferred()
    check(updaterCreations==1,"superseded session cannot create a stale updater")
end

do
    local ctx=sandbox()
    local Updater=ctx:Run("src/core/updater.lua")
    local updater=Updater.new()
    updater:Start(); updater:Start()
    check(#ctx.Spawned==1,"repeated updater start creates one polling worker")
    function updater:FetchVersion() self:Destroy(); return true,{Version="v2",Commit="b"} end
    updater:Check()
    check(updater.PendingUpdate==nil and updater.CurrentVersion==nil,"HTTP completion after destroy cannot restore updater state")
end

do
    local ctx=sandbox()
    local universal=ctx:Run("src/games/universal.lua")
    local sends=0
    function universal:SendChat() sends+=1 end
    universal:SetChatLoop(true)
    local oldWorker=ctx.Spawned[#ctx.Spawned]
    universal:SetChatLoop(false)
    universal:SetChatLoop(true)
    oldWorker.Fn()
    check(sends==0,"chat worker from an earlier toggle cannot resume after re-enable")
    universal:Destroy()
    ctx.Spawned[#ctx.Spawned].Fn()
    check(sends==0,"destroyed Universal cannot send from a queued chat worker")
end

do
    local ctx=sandbox()
    local factory=ctx:Run("src/games/features/mm2/roletracker.lua")
    local tracker=factory.new()
    tracker.Enabled=true
    local player=Instance.new("Player")
    player.CharacterAdded,player.CharacterRemoving,player.ChildAdded,player.ChildRemoved=signal(),signal(),signal(),signal()
    tracker:_watchPlayer(player)
    local old=Instance.new("Model")
    old.ChildAdded,old.ChildRemoved=signal(),signal()
    player.Character=old
    player.CharacterAdded:Fire(old)
    local oldConnections=table.clone(tracker.PlayerConnections[player].CharacterConnections)
    local new=Instance.new("Model")
    new.ChildAdded,new.ChildRemoved=signal(),signal()
    player.Character=new
    player.CharacterAdded:Fire(new)
    for _,connection in ipairs(oldConnections) do check(not connection.Connected,"MM2 disconnects old character listeners on respawn") end
    local backpack=Instance.new("Backpack")
    backpack.ChildAdded,backpack.ChildRemoved=signal(),signal()
    player.ChildAdded:Fire(backpack)
    local backpackConnections=table.clone(tracker.PlayerConnections[player].BackpackConnections)
    player.ChildRemoved:Fire(backpack)
    for _,connection in ipairs(backpackConnections) do check(not connection.Connected,"MM2 disconnects replaced backpack listeners") end
    local binding=tracker.PlayerConnections[player]
    local playerConnections=table.clone(binding.Connections)
    tracker:_unwatchPlayer(player)
    for _,connection in ipairs(playerConnections) do check(not connection.Connected,"MM2 releases player listeners on leave") end
    tracker:Destroy()
    ctx:FlushDeferred()
end

do
    local ctx=sandbox()
    local factory=ctx:Run("src/games/features/tsb/autoblock-v3.lua")
    local feature=factory.new({AnimationData={}})
    feature.Enabled=true
    local player=Instance.new("Player")
    player.CharacterAdded,player.CharacterRemoving=signal(),signal()
    feature:_bindPlayer(player)
    local character=Instance.new("Model")
    character.DescendantAdded,character.DescendantRemoving=signal(),signal()
    player.Character=character
    player.CharacterAdded:Fire(character)
    check(feature.PlayerBindings[player].Tracker==nil,"TSB waits through missing streamed components without polling")
    local humanoid=Instance.new("Humanoid"); humanoid.Health=100; humanoid.Parent=character
    local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Parent=character
    local animator=Instance.new("Animator"); animator.AnimationPlayed=signal(); animator.Parent=humanoid
    function animator:GetPlayingAnimationTracks() return {} end
    character.DescendantAdded:Fire(animator)
    ctx:FlushDeferred()
    local first=feature.PlayerBindings[player].Tracker
    check(first~=nil and first.Root==root,"TSB binds late streamed root and animator")
    root.Parent=nil
    character.DescendantRemoving:Fire(root)
    ctx:FlushDeferred()
    check(first.Destroyed and feature.PlayerBindings[player].Tracker==nil,"TSB cleans tracker when root streams out")
    root.Parent=character
    character.DescendantAdded:Fire(root)
    ctx:FlushDeferred()
    check(feature.PlayerBindings[player].Tracker~=nil,"TSB rebinds streamed root without CharacterAdded")
    feature:_unbindAllPlayers()
    feature.Enabled=false
    feature:Destroy()
    check(next(feature.Connections)==nil,"TSB tracker teardown leaves no global connections")
end

do
    local ctx=sandbox()
    ctx.Services.Workspace.ChildAdded,ctx.Services.Workspace.ChildRemoved=signal(),signal()
    local created={}
    local function factory(name,fail)
        return {new=function()
            if fail then error("missing Events/SelectTeam") end
            local object={Destroyed=false,DestroyCount=0}
            function object:Destroy() self.Destroyed=true; self.DestroyCount+=1 end
            function object:SetDelay() end
            function object:SetWeaponCategory() end
            function object:SetSelected() end
            function object:SetSelectedEnemy() end
            function object:Start() end
            function object:CancelOwner() end
            function object:Teleport() self.Teleports=(self.Teleports or 0)+1; return true end
            created[name]=object
            return object
        end}
    end
    ctx:Provide("src/core/tween-movement.lua",factory("Movement"))
    ctx:Provide("src/games/features/noobpiece/movementprofile.lua",{})
    ctx:Provide("src/games/features/noobpiece/islanddata.lua",{})
    for _,name in ipairs({"chestesp","islandtracker","autochest","autoattack","autofarm","autoteam","wanderinggacha","npcesp","autoquest"}) do
        ctx:Provide("src/games/features/noobpiece/"..name..".lua",factory(name,name=="autoteam"))
    end
    local ok,reason=pcall(ctx.Run,ctx,"src/games/noobpiece.lua")
    check(not ok and tostring(reason):find("Events/SelectTeam",1,true)~=nil,"Noob Piece reports failed dependency")
    for name,object in pairs(created) do check(object.Destroyed and object.DestroyCount==1,"Noob Piece rolls back resource "..name) end
    check(ctx.State.__DEPHUB_NOOBPIECE==nil,"failed Noob Piece does not publish a backend")
    ctx:Provide("src/games/features/noobpiece/autoteam.lua",factory("autoteam"))
    local backend=ctx:Run("src/games/noobpiece.lua")
    check(type(backend)=="table" and not backend.Destroyed,"Noob Piece succeeds when dependencies are available")
    backend:SetIslandTeleport(true)
    local teleportWorker=ctx.Spawned[#ctx.Spawned]
    backend:SetIslandTeleport(false)
    teleportWorker.Fn()
    check(not created.islandtracker.Teleports,"cancelled island teleport cannot start movement")
    backend:Destroy(); backend:Destroy()
    for name,object in pairs(created) do check(object.DestroyCount==1,"successful Noob Piece has idempotent cleanup for "..name) end
    check(ctx.State.__DEPHUB_NOOBPIECE==nil,"Noob Piece destruction releases published handle")
end

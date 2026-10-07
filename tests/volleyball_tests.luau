local vectors={}
local vectorMeta={}
function vectors.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
function vectorMeta.__add(a,b) return vectors.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vectorMeta.__sub(a,b) return vectors.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function vectorMeta.__mul(a,b) return vectors.new(a.X*b,a.Y*b,a.Z*b) end
function vectorMeta.__div(a,b) return a*(1/b) end
function vectorMeta.__index(a,key)
    if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
    if key=="Unit" then return a/a.Magnitude end return vectors[key]
end
function vectors:Cross(b) return vectors.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
local function volleySandbox()
    local ctx=sandbox()
    ctx.Env.Vector3=vectors
    ctx.Env.UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end}
    ctx.Env.CFrame={fromMatrix=function(position,...) return {Position=position,Axes={...}} end}
    ctx.Env.RaycastParams={new=function() return {} end}
    ctx.Services.Workspace.ChildAdded,ctx.Services.Workspace.ChildRemoved=signal(),signal()
    ctx.Services.Workspace.Gravity=196.2
    ctx.Created=0
    ctx.Env.Instance={new=function(class) ctx.Created+=1; return Instance.new(class) end}
    function ctx.Services.Workspace:Raycast() return nil end
    return ctx
end
local function ball(ctx,name,position,velocity)
    local object=Instance.new("Model") object.Name=name object.DescendantAdded,object.DescendantRemoving=signal(),signal()
    object.Parent=ctx.Services.Workspace
    local part=Instance.new("MeshPart") part.Name="Cube.001" part.Position=position part.AssemblyLinearVelocity=velocity part.Anchored=false part.Parent=object
    return object,part
end
do
    local ctx=sandbox()
    ctx.State.__DEPHUB_SOURCE_REF="stale-ref"
    ctx.Responses["src/version.txt"]="0.0.31"
    ctx:Provide("src/games/universal.lua",{})
    ctx:Provide("library/init.lua",{new=function() return {} end})
    check(assert(ctx.Env.loadstring(sources["DepHub.lua"]))("main")==true,"DepHub one-line loader accepts source revision as a chunk argument")
    check(ctx.State.__DEPHUB.SourceBaseURL=="https://raw.githubusercontent.com/glowpkj/DepHub/main/" and ctx.State.__DEPHUB_SOURCE_REF=="stale-ref","DepHub explicit loader revision overrides stale global without mutating it")
end
do
    local ctx=volleySandbox()
    local v=vectors.new
    local first,part=ball(ctx,"CLIENT_BALL_72746008800",v(5,5,0),v(10,0,0))
    local other,otherPart=ball(ctx,"CLIENT_BALL_72746008832",v(2,5,0),v(0,0,0))
    local factory=ctx:Run("src/games/features/volleyballlegends/ball-detector.lua")
    local switches=0
    local detector=factory.new({Workspace=ctx.Services.Workspace,OnChanged=function() switches+=1 end})
    check(detector:Enable(),"Volleyball detector enables")
    local selected=detector:Sample(0.05,v(0,0,0))
    check(selected.Object==first and selected.Part==part,"Volleyball dynamically chooses moving ball instead of nearer stationary ball")
    local nameBefore=selected.Object.Name
    part.Position=v(7,5,0) part.Anchored=true part.AssemblyLinearVelocity=v(0,0,0)
    selected=detector:Sample(0.05,v(0,0,0))
    check(math.abs(selected.Velocity.X-40)<0.001 and selected.VelocitySource=="position samples","Volleyball measures velocity of anchored client ball")
    part.Anchored=false part.AssemblyLinearVelocity=v(40,0,0)
    otherPart.AssemblyLinearVelocity=v(8,0,0) otherPart.Position=v(6.9,5,0)
    check(detector:Sample(0.05,v(0,0,0)).Object==first,"Volleyball hysteresis avoids switching for tiny distance changes")
    otherPart.Position=v(1,5,0)
    check(detector:Sample(0.05,v(0,0,0)).Object==other,"Volleyball switches to significantly closer moving ball")
    other.Parent=nil ctx.Services.Workspace.ChildRemoved:Fire(other)
    check(detector.Active==nil,"Volleyball immediately clears removed active ball")
    check(detector:Sample(0.05,v(0,0,0)).Object==first,"Volleyball recovers remaining ball after removal")
    part.Parent=nil first.DescendantRemoving:Fire(part) ctx:FlushDeferred()
    check(detector:Sample(0.05,v(0,0,0))==nil,"Volleyball ignores missing streamed Cube.001")
    local invalid=Instance.new("Folder") invalid.Name="Cube.001" invalid.Parent=first first.DescendantAdded:Fire(invalid) ctx:FlushDeferred()
    check(detector.Candidates[first].Part==nil,"Volleyball rejects non-BasePart named Cube.001")
    part.Parent=first first.DescendantAdded:Fire(part) ctx:FlushDeferred()
    check(detector:Sample(0.05,v(0,0,0)).Part==part,"Volleyball rebinds late streamed Cube.001")
    local duplicate=Instance.new("Part") duplicate.Name="Cube.001" duplicate.Parent=first first.DescendantAdded:Fire(duplicate) ctx:FlushDeferred()
    check(detector:Sample(0.05,v(0,0,0))==nil,"Volleyball refuses ambiguous duplicate Cube.001 parts")
    duplicate.Parent=nil first.DescendantRemoving:Fire(duplicate) ctx:FlushDeferred()
    local recreated,newPart=ball(ctx,"CLIENT_BALL_99999999999",v(1,2,0),v(4,0,0))
    ctx.Services.Workspace.ChildAdded:Fire(recreated)
    check(detector:Sample(0.05,v(0,0,0)).Part==newPart,"Volleyball detects replacement CLIENT_BALL with a new dynamic suffix")
    check(detector:Sample(0.05,nil)==nil,"Volleyball does not guess between multiple balls without a reference")
    detector:Sample(0.05,v(0,0,0))
    local globalConnections=table.clone(detector.Connections)
    local partConnections=table.clone(detector.Candidates[recreated].Connections)
    detector:Disable()
    check(next(detector.Candidates)==nil and detector.Active==nil,"Volleyball detector releases candidates when both features are off")
    for _,c in ipairs(globalConnections) do check(not c.Connected,"Volleyball detector disconnects workspace events") end
    for _,c in ipairs(partConnections) do check(not c.Connected,"Volleyball detector disconnects ball events") end
    detector:Enable(); check(detector:Sample(0.05,v(0,0,0)).Part==newPart,"Volleyball detector can re-enable")
    detector:Destroy(); ctx:FlushDeferred()
    check(detector.Destroyed and not detector.Enabled,"Volleyball delayed events cannot revive destroyed detector")
end
do
    local ctx=volleySandbox() local v=vectors.new
    local object,part=ball(ctx,"CLIENT_BALL_1",v(0,10,0),v(10,0,0))
    local candidate={Object=object,Part=part,Velocity=part.AssemblyLinearVelocity}
    local esp=ctx:Run("src/games/features/volleyballlegends/ball-esp.lua").new({Workspace=ctx.Services.Workspace})
    esp:SetEnabled(true) esp:Update(candidate,v(0,0,0))
    check(esp.Highlight.Adornee==part and esp.Billboard.Adornee==part,"Volleyball ESP follows actual Cube.001")
    local highlight=esp.Highlight local billboard=esp.Billboard local allocated=ctx.Created
    esp:Update(candidate,v(0,0,0))
    check(ctx.Created==allocated and esp.Highlight==highlight,"Volleyball ESP reuses visuals each update")
    check(esp.Label.Text:find("10 studs",1,true)~=nil,"Volleyball ESP shows player distance")
    esp:SetEnabled(false)
    check(highlight.Parent==nil and billboard.Parent==nil and esp.Part==nil,"Volleyball ESP OFF removes all owned visuals")
    local predictor=ctx:Run("src/games/features/volleyballlegends/trajectory.lua").new({Workspace=ctx.Services.Workspace})
    local future=predictor:FuturePosition(v(0,10,0),v(10,20,0),0.5)
    check(math.abs(future.X-5)<0.001 and math.abs(future.Y+4.525)<0.001,"Volleyball projectile includes gravity and vertical velocity")
    predictor:SetEnabled(true)
    local character=Instance.new("Model")
    local casts=0
    function ctx.Services.Workspace:Raycast(origin,direction,params)
        casts+=1
        if origin.Y>=0 and origin.Y+direction.Y<=0 then
            local fraction=-origin.Y/direction.Y
            return {Position=origin+direction*fraction,Normal=v(0,1,0)}
        end
        return nil
    end
    predictor:Update(candidate,{object,character})
    check(predictor.Landing~=nil and math.abs(predictor.Landing.Y)<0.001,"Volleyball raycasts locate descending floor crossing")
    check(predictor.Marker.Transparency<1,"Volleyball landing marker appears on valid floor")
    check(table.find(predictor.Params.FilterDescendantsInstances,object) and table.find(predictor.Params.FilterDescendantsInstances,character)
        and table.find(predictor.Params.FilterDescendantsInstances,predictor.Folder),"Volleyball raycasts exclude balls characters and visualization")
    check(not predictor.Dots[1].CanQuery and not predictor.Marker.CanCollide,"Volleyball visuals cannot participate in collisions")
    allocated=ctx.Created local folder=predictor.Folder
    predictor:Update(candidate,{object,character})
    check(ctx.Created==allocated and predictor.Folder==folder,"Volleyball predictor allocates no new Parts during subsequent frames")
    function ctx.Services.Workspace:Raycast(origin,direction) return {Position=origin+direction*0.5,Normal=v(1,0,0)} end
    predictor:Update(candidate,{object})
    check(predictor.Impact~=nil and predictor.Landing==nil and predictor.Marker.Transparency==1,"Volleyball wall/net impact stops curve without false landing")
    check(predictor.Dots[2].Transparency==1,"Volleyball hides curve points after first collision")
    candidate.Velocity=v(0,0,0) casts=0
    function ctx.Services.Workspace:Raycast() casts+=1; return nil end
    predictor:Update(candidate,{object})
    check(casts==0 and predictor.Dots[1].Transparency==1,"Volleyball stationary ball skips prediction and hides curve")
    candidate.Velocity=v(10,0,0) predictor:Update(candidate,{object})
    check(predictor.Landing==nil and predictor.Dots[40].Transparency<1,"Volleyball no impact within horizon does not invent landing point")
    predictor:SetEnabled(false)
    check(folder.Parent==nil and #predictor.Dots==0 and predictor.Marker==nil,"Volleyball predictor OFF removes pooled visuals")
    predictor:Destroy(); esp:Destroy()
end
do
    local ctx=volleySandbox() local v=vectors.new
    for _,name in ipairs({"ball-detector","ball-esp","trajectory"}) do
        local path="src/games/features/volleyballlegends/"..name..".lua" ctx.Responses[path]=sources[path]
    end
    local backend=ctx:Run("src/games/volleyballlegends.lua")
    check(backend.Connection==nil and not backend.Toggles.BallESP and not backend.Toggles.TrajectoryPredictor,"Volleyball features start OFF with no frame worker")
    local object,part=ball(ctx,"CLIENT_BALL_42",v(0,10,0),v(10,0,0))
    local character=Instance.new("Model") local root=Instance.new("Part") root.Name="HumanoidRootPart" root.Position=v(0,0,0) root.Parent=character ctx.Player.Character=character
    backend:SetBallESP(true)
    local worker=backend.Connection
    backend:SetTrajectoryPredictor(true)
    check(backend.Connection==worker,"Volleyball features share one Heartbeat worker")
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    check(backend.Features.BallESP.Part==part and backend.Features.TrajectoryPredictor.Folder~=nil,"Volleyball actual backend runs both visuals")
    backend:SetBallESP(false)
    check(backend.Connection==worker and backend.Features.Detector.Enabled and backend.Features.BallESP.Highlight==nil,"Volleyball turning ESP off keeps predictor active")
    backend:SetTrajectoryPredictor(false)
    check(not worker.Connected and backend.Connection==nil and not backend.Features.Detector.Enabled,"Volleyball both OFF removes worker and detector subscriptions")
    backend:SetDebug(true)
    check(backend.Connection==nil,"Volleyball debug alone cannot start frame calculations")
    backend:SetTrajectoryPredictor(true) backend:SetBallESP(true)
    ctx.Services.RunService.Heartbeat:Fire(0.05)
    check(backend:GetDebugInfo().Ball==object.Name and backend:GetDebugInfo().Speed==10,"Volleyball diagnostics expose selected ball and velocity")
    object.Parent=nil ctx.Services.Workspace.ChildRemoved:Fire(object)
    check(backend.Features.TrajectoryPredictor.Folder==nil and backend.Features.BallESP.Highlight==nil,"Volleyball removed ball immediately cleans its visual objects")
    local ui={Destroyed=false,Toggles={}}
    function ui:AddToggle(name,initial,fn) self.Toggles[#self.Toggles+1]={Name=name,Initial=initial,Fn=fn} end
    function ui:Destroy() self.Destroyed=true end
    ctx:Provide("library/compact.lua",{new=function() return ui end})
    check(ctx:Run("src/games/features/volleyballlegends/frontend.lua")==ui and #ui.Toggles==3,"Volleyball frontend uses shared UI for two visual toggles and debug")
    ui:Destroy()
    check(ctx.State.__DEPHUB_VOLLEYBALL_FRONTEND==nil,"Volleyball UI teardown clears its global handle")
    backend:Destroy(); backend:Destroy()
    check(ctx.State.__DEPHUB.VolleyballLegends==nil and backend.Connection==nil,"Volleyball destruction is idempotent and clears backend handles")
end
do
    local ctx=volleySandbox()
    local detector={DestroyCount=0}
    function detector:Destroy() self.DestroyCount+=1 end
    ctx:Provide("src/games/features/volleyballlegends/ball-detector.lua",{new=function() return detector end})
    ctx:Provide("src/games/features/volleyballlegends/ball-esp.lua",{new=function() error("simulated ESP factory failure") end})
    check(ctx:Run("src/games/volleyballlegends.lua")==false and detector.DestroyCount==1,"Volleyball factory failure rolls back previously created resources")
    check(ctx.State.__DEPHUB_VOLLEYBALL==nil,"Volleyball failed startup cannot publish backend")
end
do
    for _,route in ipairs({{73956553001240,1},{1,6931042565}}) do
        local ctx=sandbox(route[1],route[2])
        ctx.Responses["src/version.txt"]="0.0.31"
        local backend={Destroyed=false,Destroy=function(self) self.Destroyed=true end}
        local ui={Destroyed=false,Destroy=function(self) self.Destroyed=true end}
        ctx:Provide("src/games/volleyballlegends.lua",backend)
        ctx:Provide("src/games/features/volleyballlegends/frontend.lua",ui)
        check(ctx:Run("DepHub.lua")==true,"Volleyball routes through existing loader by PlaceId or GameId")
        check(ctx.State.__DEPHUB.VolleyballLegends==backend and ctx.State.__DEPHUB.BloxFruits==nil,"Volleyball loader uses its own backend slot")
        local requests=#ctx.Requests ctx:Run("DepHub.lua")
        check(#ctx.Requests==requests,"Volleyball healthy loader reexecution does not duplicate modules")
        ui.Destroyed=true ctx:Run("DepHub.lua")
        check(backend.Destroyed,"Volleyball loader cleans old backend when UI is destroyed")
    end
end

-- Actual defense methods with fake threat geometry; real game timing is not emulated.
do
    local ctx=sandbox()
    local actions={}
    function actions:BindActionAtPriority(name,fn,_,priority,input)
        self.Name=name self.Handler=fn self.Priority=priority self.Input=input
    end
    function actions:UnbindAction(name) check(name==self.Name,"TSB unbinds its own input action"); self.Handler=nil end
    ctx.Services.ContextActionService=actions
    Enum.ContextActionPriority.High={Value=3000}
    local factory=ctx:Run("src/games/features/tsb/autoblock-v3.lua")
    local id=10469493270
    local feature=factory.new({AnimationData={Groups={{Normal={id}}}},M1Block=true,FaceAttacker=false})
    feature.Enabled=true
    function feature:_localAlive() return true end
    function feature:_localRoot() return {} end
    function feature:_trackerReady(tracker) return not tracker.Destroyed end
    local boxRequired
    function feature:_threatMetrics(tracker,_,_,requireBox)
        boxRequired=requireBox
        return {Pass=tracker.InRange,Distance=10}
    end
    local sent={}
    function feature:_communicate(goal) sent[#sent+1]=goal; return true end
    local a={InRange=true,M1ing=true,ActiveIds={}}
    local b={InRange=true,M1ing=false,ActiveIds={[id]=1}}
    feature.PlayerBindings={[{Name="A"}]={Tracker=a},[{Name="B"}]={Tracker=b}}
    feature.Mouse1Down=true
    feature:_spatialTick()
    check(feature.BlockActive,"TSB starts defense despite held mouse attack")
    check(sent[1]=="LeftClickRelease" and sent[2]=="KeyPress","TSB releases held M1 before block")
    check(boxRequired==false,"TSB uses configured M1 range without an extra half-size box")
    feature:_cancelAutomationForLocalAttack("test click")
    check(feature.BlockActive,"TSB manual click cannot cancel defense")
    feature.BlockUntil=0
    feature:_spatialTick()
    check(feature.BlockActive and feature.BlockUntil>0,"TSB renews defense without attacker leaving range")
    check(feature:_bindInputGuard(),"TSB binds defense input guard")
    check(actions.Input==Enum.UserInputType.MouseButton1 and actions.Priority>3000,"TSB guard precedes normal combat actions")
    check(actions.Handler(nil,Enum.UserInputState.Begin)==Enum.ContextActionResult.Sink,"TSB sinks attacks while threatened")
    a.M1ing=false feature.BlockUntil=0 feature:_spatialTick()
    check(feature.BlockActive,"TSB keeps defense for another attacker")
    b.ActiveIds={} feature.BlockUntil=0 feature:_spatialTick()
    check(not feature.BlockActive and sent[#sent]=="KeyRelease","TSB releases when all recognized threats end")
    check(actions.Handler(nil,Enum.UserInputState.Begin)==Enum.ContextActionResult.Pass,"TSB passes manual attacks after danger ends")
    check(not feature.CounterPending and feature.DebugInfo.Counters==0,"TSB never auto-attacks in master mode")
    a.M1ing=true a.InRange=false feature:_spatialTick()
    check(not feature.BlockActive,"TSB ignores attacks outside the configured range")
    a.InRange=true feature:_spatialTick() a.Destroyed=true feature.BlockUntil=0 feature:_spatialTick()
    check(not feature.BlockActive,"TSB releases removed attacker")
    feature:_unbindInputGuard()
    check(not actions.Handler and not feature.InputGuardBound,"TSB input teardown restores ordinary input")
    feature.Enabled=false feature:Destroy()
end

do
    local ctx=sandbox()
    local feature={Enabled=false}
    function feature:Enable() self.Enabled=true return true end
    function feature:Disable() self.Enabled=false return true end
    function feature:Destroy() self.Enabled=false end
    function feature:SetM1Block(value) self.M1=value end
    function feature:SetDashBlock(value) self.Dash=value end
    function feature:SetSkillBlock(value) self.Skill=value end
    function feature:SetM1AfterBlock(value) self.Counter=value end
    ctx:Provide("src/games/features/tsb/animations.lua",{Groups={},SkillIds={}})
    ctx:Provide("src/games/features/tsb/autoblock-v3.lua",{new=function() return feature end})
    local backend=ctx:Run("src/games/tsb.lua")
    local ui={Destroyed=false,Toggles={}}
    function ui:AddToggle(name,value,callback) self.Toggles[#self.Toggles+1]={Name=name,Value=value,Callback=callback} end
    function ui:Destroy() self.Destroyed=true end
    ctx:Provide("library/compact.lua",{new=function() return ui end})
    check(ctx:Run("src/games/features/tsb/frontend.lua")==ui and #ui.Toggles==1,"TSB frontend exposes exactly one toggle and no extra controls")
    check(ui.Toggles[1].Name=="Auto Block","TSB single toggle is Auto Block")
    check(ui.Toggles[1].Callback(true) and feature.Enabled and feature.M1 and feature.Dash and feature.Skill,"TSB single toggle enables all existing block detectors")
    check(feature.Counter==false,"TSB master switch disables automatic counter attacks")
    check(ui.Toggles[1].Callback(false) and not feature.Enabled and not feature.M1 and not feature.Dash and not feature.Skill,"TSB single toggle disables all detectors")
    ui:Destroy()
    check(ctx.State.__DEPHUB_TSB_FRONTEND==nil and ctx.State.__DEPHUB.TSBUI==nil,"TSB simplified UI preserves cleanup")
    backend:Destroy()
end

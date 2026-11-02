-- Steal An Exu is a skeleton: it has no features yet. It must still load clean
-- (which is the whole point while the script is being written), be routed from
-- its own place/universe ids instead of the universal fallback, publish its
-- state, and tear down with nothing left behind.
do
    -- Routing: the loader must pick this backend from the place id (and from the
    -- universe id), not fall back to the universal backend.
    local ctx = sandbox(103076400317371, 10771168447)
    ctx.Responses["src/version.txt"] = "0.0.1"
    ctx:Provide("src/games/steal-an-exu.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Steal An Exu routes from its place id")
    check(ctx.State.__DEPHUB.StealAnExu ~= nil, "Steal An Exu route exposes its backend")
    check(ctx.State.__DEPHUB.Universal == nil, "Steal An Exu does not fall back to the universal backend")
    check(ctx.State.__DEPHUB.BloxFruits == nil and ctx.State.__DEPHUB.Volleyball42 == nil,
        "Steal An Exu route does not leak another backend")
    check(ctx.State.__DEPHUB.Mode == "steal-an-exu", "Steal An Exu route names its backend")
end

-- Routing by universe id too, the way the loader matches game ids.
do
    local ctx = sandbox(999, 10771168447)
    ctx.Responses["src/version.txt"] = "0.0.1"
    ctx:Provide("src/games/steal-an-exu.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Steal An Exu routes from its universe id")
    check(ctx.State.__DEPHUB.StealAnExu ~= nil, "universe id exposes the Steal An Exu backend")
end

-- The entry itself: loads clean, has no features, exposes the contract the
-- future panel will drive, and destroys without residue.
do
    local ctx = sandbox(103076400317371, 10771168447)
    local ui = ctx:MountUI()

    local backend = ctx:Run("src/games/steal-an-exu.lua")
    check(type(backend) == "table" and backend.Destroyed == false, "Steal An Exu entry returns a live backend")
    check(backend.Started == true, "the backend starts itself")
    check(type(backend.Features) == "table" and next(backend.Features) == nil, "there are no features yet")
    check(ctx.State.__DEPHUB.StealAnExu == backend, "the backend publishes itself")

    -- The contract is defined even though there is nothing to drive: an unknown
    -- feature is refused instead of creating phantom state.
    check(backend:SetFeature("nope", true) == false, "an unknown feature is refused")
    check(backend:IsEnabled("nope") == false, "an unknown feature reads as disabled")
    check(backend:SetFeature(123, true) == false, "a non-string feature name is refused")

    -- No UI is registered while the features are being written.
    local controls = ui.Library._Controls or {}
    check(#controls == 0, "the skeleton registers no panel controls")

    backend:Destroy()
    backend:Destroy()
    check(backend.Destroyed == true, "destroy marks the backend destroyed")
    check(ctx.State.__DEPHUB.StealAnExu == nil, "destroy clears the published state")
    check(backend:SetFeature("nope", true) == false, "a destroyed backend refuses toggles")
end

-- A registered feature is driven by name, and destroyed with the backend.
do
    local ctx = sandbox(103076400317371, 10771168447)
    ctx:MountUI()
    local backend = ctx:Run("src/games/steal-an-exu.lua")

    local live = {Enabled = false, Destroyed = false}
    function live.SetEnabled(self, on) self.Enabled = on == true; return true end
    function live.IsEnabled(self) return self.Enabled == true end
    function live.Destroy(self) self.Destroyed = true end
    backend.Features.demo = live

    check(backend:SetFeature("demo", true) == true and backend:IsEnabled("demo") == true,
        "a registered feature turns on by name")
    check(backend:SetFeature("demo", false) == true and backend:IsEnabled("demo") == false,
        "and turns off by name")

    backend:Destroy()
    check(live.Destroyed == true, "destroy tears down every registered feature")
end

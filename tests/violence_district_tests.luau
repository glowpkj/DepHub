-- [CURE] Violence District backend: the ESP resolves players by their role Team,
-- auto repair fires the generator RepairEvent at the nearest GeneratorPointN,
-- the skill-check assist fires SkillCheckResultEvent on a Skillcheck-gen object,
-- and auto parry fires the dagger parry remote on a known parryable animation.
-- Behavioral checks with API doubles; no claim of in-game functionality.
do
    -- Routing: the loader must pick this backend from the place id and the
    -- universe id, and keep it distinct from the other games.
    local ctx = sandbox(93978595733734, 93978595733734)
    ctx.Responses["src/version.txt"] = "0.0.96"
    ctx:Provide("src/games/violence-district.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Violence District routes from its place id")
    check(ctx.State.__DEPHUB.ViolenceDistrict ~= nil, "Violence District route exposes its backend")
    check(ctx.State.__DEPHUB.BloodStrike == nil and ctx.State.__DEPHUB.Volleyball42 == nil,
        "Violence District route does not leak another backend")
    check(ctx.State.__DEPHUB.Mode == "violence-district", "Violence District route names its backend")
end

do
    local ctx = sandbox(6739698191, 6739698191)
    ctx.Responses["src/version.txt"] = "0.0.96"
    ctx:Provide("src/games/violence-district.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Violence District routes from its universe id")
    check(ctx.State.__DEPHUB.ViolenceDistrict ~= nil, "universe id route exposes the backend")
end

do
    local ctx = sandbox(93978595733734, 93978595733734)
    ctx:MountUI()
    local function object(class, name, parent)
        local item = Instance.new(class); item.Name = name; item.Parent = parent; return item
    end
    local function player(name, team)
        local p = Instance.new("Player"); p.Name = name; p.Team = team
        p.CharacterAdded, p.CharacterRemoving = signal(), signal()
        return p
    end

    -- Remotes the backend resolves at load, so the features wire up live.
    local remotes = object("Folder", "Remotes", ctx.Services.ReplicatedStorage)
    local genRemotes = object("Folder", "Generator", remotes)
    local repairRemote = object("RemoteEvent", "RepairEvent", genRemotes)
    local skillRemote = object("RemoteEvent", "SkillCheckResultEvent", genRemotes)
    local items = object("Folder", "Items", remotes)
    local daggerFolder = object("Folder", "Parrying Dagger", items)
    local parryRemote = object("RemoteEvent", "parry", daggerFolder)

    local killerTeam = object("Team", "Killer", ctx.Services.Teams)
    local survivorTeam = object("Team", "Survivors", ctx.Services.Teams)

    -- Local player: a survivor with a character (humanoid + root) and a Head so
    -- the killer's ESP has a billboard adornee.
    ctx.Player.Team = survivorTeam
    local localChar = object("Model", "LocalCharacter", ctx.Services.Workspace)
    local localRoot = object("Part", "HumanoidRootPart", localChar); localRoot.Position = Vector3.new(0, 0, 0)
    local localHead = object("Part", "Head", localChar)
    object("Humanoid", "Humanoid", localChar)
    ctx.Player.Character = localChar

    -- A killer near the local player, with a character and an Animator.
    local killer = player("KillerPlayer", killerTeam)
    local killerChar = object("Model", "KillerCharacter", ctx.Services.Workspace)
    local killerRoot = object("Part", "HumanoidRootPart", killerChar); killerRoot.Position = Vector3.new(10, 0, 0)
    local killerHead = object("Part", "Head", killerChar)
    local killerHumanoid = object("Humanoid", "Humanoid", killerChar)
    local killerAnimator = object("Animator", "Animator", killerHumanoid)
    killerAnimator.AnimationPlayed = {Connect = function(_, fn) killerAnimator._play = fn; return {Disconnect = function() end} end}
    killer.Character = killerChar

    -- A survivor far away.
    local survivor = player("SurvivorPlayer", survivorTeam)
    local survivorChar = object("Model", "SurvivorCharacter", ctx.Services.Workspace)
    local survivorRoot = object("Part", "HumanoidRootPart", survivorChar); survivorRoot.Position = Vector3.new(40, 0, 0)
    object("Part", "Head", survivorChar)
    object("Humanoid", "Humanoid", survivorChar)
    survivor.Character = survivorChar

    ctx.Services.Players.GetPlayers = function() return {ctx.Player, killer, survivor} end
    ctx.Services.Players.GetPlayerFromCharacter = function(_, character)
        if character == localChar then return ctx.Player end
        if character == killerChar then return killer end
        if character == survivorChar then return survivor end
        return nil
    end

    -- A map with generators built from GeneratorPointN parts.
    local map = object("Folder", "Map", ctx.Services.Workspace)
    local genModel = object("Model", "Generator1", map)
    local genPoint = object("Part", "GeneratorPoint1", genModel); genPoint.Position = Vector3.new(10, 0, 0)

    local backend = ctx:Run("src/games/violence-district.lua")
    -- Resolve the deferred remote lookup and killer watch before driving events.
    ctx:FlushDeferred()
    check(type(backend) == "table" and backend.Destroyed == false, "Violence District entry returns a live backend")
    check(backend.Toggles.ESP == false, "ESP starts off")
    check(next(backend.ESPObjects) == nil, "ESP stays empty while disabled")

    -- ESP on: killer and survivor are tagged by role, the local player is not.
    backend:SetESP(true)
    check(backend.ESPObjects[killerChar] ~= nil, "ESP tags the killer")
    check(backend.ESPObjects[survivorChar] ~= nil, "ESP tags the survivor")
    check(backend.ESPObjects[localChar] == nil, "ESP never tags the local player")

    local killerRecord = backend.ESPObjects[killerChar]
    check(killerRecord.Role == "Killer", "the killer record carries the killer role")
    check(killerRecord.Highlight ~= nil, "chams are built by default")
    check(killerRecord.Label.Text:find("KILLER", 1, true) ~= nil, "the killer label names the role")
    check(killerRecord.Label.Text:find("10", 1, true) ~= nil, "the label shows the distance")

    -- Turning the killer toggle off drops the killer but keeps the survivor.
    backend:SetToggle("ESPKiller", false)
    check(backend.ESPObjects[killerChar] == nil, "disabling the killer toggle untags the killer")
    check(backend.ESPObjects[survivorChar] ~= nil, "the survivor survives an unrelated toggle")
    backend:SetToggle("ESPKiller", true)

    -- Chams off disables the highlight only; the billboard stays.
    backend:SetToggle("Chams", false)
    local survivorRecord = backend.ESPObjects[survivorChar]
    check(survivorRecord ~= nil and survivorRecord.Highlight.Enabled == false and survivorRecord.Billboard ~= nil,
        "chams toggle disables the highlight only")
    backend:SetToggle("Chams", true)

    -- Range: the survivor at 40 studs is out of a 20-stud range.
    backend:SetValue("Range", 20)
    backend:Refresh()
    check(backend.ESPObjects[survivorChar] == nil, "range hides a distant player")
    check(backend.ESPObjects[killerChar] ~= nil, "range keeps a near target")
    check(backend:SetValue("Range", "x") == false, "range rejects a non-numeric value")
    backend:SetValue("Range", 2000)
    backend:Refresh()

    -- Auto repair: fires RepairEvent(point, true) at the nearest generator.
    local repairCalls = {}
    repairRemote.FireServer = function(_, ...) repairCalls[#repairCalls + 1] = {...} end
    backend:SetToggle("AutoRepair", true)
    ctx.Services.RunService.Heartbeat:Fire(0.016)
    check(#repairCalls == 1 and repairCalls[1][1] == genPoint and repairCalls[1][2] == true,
        "auto repair fires RepairEvent at the generator point")

    -- Moving the point out of range stops the repair with a false fire.
    genPoint.Position = Vector3.new(500, 0, 0)
    ctx.Services.RunService.Heartbeat:Fire(0.016)
    local stopped = repairCalls[#repairCalls]
    check(stopped[1] == genPoint and stopped[2] == false, "auto repair sends the stop signal out of range")
    genPoint.Position = Vector3.new(10, 0, 0)

    -- Disabling auto repair also stops an active repair.
    backend:SetToggle("AutoRepair", false)
    check(backend.RepairActive == false, "disabling auto repair clears the active repair")

    -- Skill check: a Skillcheck-gen object on the character fires the success
    -- result remote for the generator being repaired.
    local skillCalls = {}
    skillRemote.FireServer = function(_, ...) skillCalls[#skillCalls + 1] = {...} end
    backend:SetToggle("AutoRepair", true)
    ctx.Services.RunService.Heartbeat:Fire(0.016) -- starts the repair, remembers the generator
    backend:SetToggle("AutoSkillCheck", true)
    local skillTag = object("Part", "Skillcheck-gen", localChar)
    ctx.Services.RunService.Heartbeat:Fire(0.016) -- runs the queued skill-check call
    check(#skillCalls == 1 and skillCalls[1][1] == "success" and skillCalls[1][3] == genModel and skillCalls[1][4] == genPoint,
        "the skill-check assist sends success with the generator and point")
    skillTag:Destroy()
    backend:SetToggle("AutoRepair", false)

    -- Auto parry: a known parryable animation fired by the killer in range fires
    -- the dagger remote, and the cooldown blocks an immediate second fire.
    local parryCount = 0
    parryRemote.FireServer = function() parryCount = parryCount + 1 end
    local backpack = object("Backpack", "Backpack", ctx.Player)
    ctx.Player.Backpack = backpack
    object("Tool", "Parrying Dagger", backpack)
    local humanoidEquip = localChar:FindFirstChildOfClass("Humanoid")
    humanoidEquip.EquipTool = function(_, tool) tool.Parent = localChar end
    backend:SetToggle("AutoParry", true)
    backend:SetValue("ParryCooldown", 5)

    killerAnimator._play({Animation = {AnimationId = "rbxassetid://78935059863801"}})
    check(parryCount == 1, "auto parry fires the dagger remote on a known parryable animation in range")
    check(localChar:FindFirstChild("Parrying Dagger") ~= nil, "auto equip moves the dagger into the character")

    killerAnimator._play({Animation = {AnimationId = "rbxassetid://78935059863801"}})
    check(parryCount == 1, "the parry cooldown blocks an immediate second fire")

    -- An unknown animation (a charge/hold tell) does not trigger a parry.
    parryCount = 0
    backend:SetValue("ParryCooldown", 0)
    killerAnimator._play({Animation = {AnimationId = "rbxassetid://122812055447896"}})
    check(parryCount == 0, "auto parry ignores a non-parryable animation")

    -- Out of range: a known animation far away does not fire either.
    killerRoot.Position = Vector3.new(500, 0, 0)
    killerAnimator._play({Animation = {AnimationId = "rbxassetid://78935059863801"}})
    check(parryCount == 0, "auto parry ignores a parryable animation out of range")

    -- Destroy clears everything and releases the runtime.
    backend:Destroy()
    backend:Destroy()
    check(next(backend.ESPObjects) == nil, "destroy clears the ESP records")
    check(backend.Destroyed == true and backend:SetToggle("ESP", true) == false, "destroyed backend rejects toggles")
    check(ctx.State.__DEPHUB.ViolenceDistrict == nil, "destroy releases the published runtime")
end

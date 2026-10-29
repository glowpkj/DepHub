-- Blood Strike: the ESP resolves fighters from workspace.Characters (Models named
-- after their owner) and falls back to the standard Players surface, with a team
-- check. Behavioral checks with API doubles; no claim of in-game functionality.
do
    -- Routing: the loader must pick this backend from the place id and keep it
    -- distinct from the other games.
    local ctx = sandbox(114234929420007, 114234929420007)
    ctx.Responses["src/version.txt"] = "0.0.76"
    ctx:Provide("src/games/bloodstrike.lua", {Destroyed = false})
    check(ctx:Run("DepHub.lua") == true, "Blood Strike routes from its place id")
    check(ctx.State.__DEPHUB.BloodStrike ~= nil, "Blood Strike route exposes its backend")
    check(ctx.State.__DEPHUB.BloxFruits == nil and ctx.State.__DEPHUB.Volleyball42 == nil, "Blood Strike route does not leak another backend")
    check(ctx.State.__DEPHUB.Mode == "bloodstrike", "Blood Strike route names its backend")
end

do
    local ctx = sandbox(114234929420007, 114234929420007)
    ctx:MountUI()
    local function object(class, name, parent)
        local item = Instance.new(class); item.Name = name; item.Parent = parent; return item
    end
    -- The game's fighter container. Children are Models named after their owner.
    local characters = object("Folder", "Characters", ctx.Services.Workspace)
    -- Local player with a character and a team.
    local localTeam = object("Team", "Red", ctx.Services.Teams)
    ctx.Player.Team = localTeam
    local localChar = object("Model", ctx.Player.Name, characters)
    local localRoot = object("Part", "HumanoidRootPart", localChar); localRoot.Position = Vector3.new(0, 0, 0)
    object("Humanoid", "Humanoid", localChar)
    object("Part", "Head", localChar)
    ctx.Player.Character = localChar
    -- An enemy (no team) near the local player.
    local enemy = Instance.new("Player"); enemy.Name = "Enemy"
    local enemyChar = object("Model", "Enemy", characters)
    local enemyRoot = object("Part", "HumanoidRootPart", enemyChar); enemyRoot.Position = Vector3.new(30, 0, 0)
    local enemyHumanoid = object("Humanoid", "Humanoid", enemyChar); enemyHumanoid.Health = 75
    object("Part", "Head", enemyChar)
    enemy.Character = enemyChar
    -- A teammate far away.
    local mate = Instance.new("Player"); mate.Name = "Mate"; mate.Team = localTeam
    local mateChar = object("Model", "Mate", characters)
    local mateRoot = object("Part", "HumanoidRootPart", mateChar); mateRoot.Position = Vector3.new(0, 0, 400)
    object("Humanoid", "Humanoid", mateChar)
    object("Part", "Head", mateChar)
    mate.Character = mateChar
    ctx.Services.Players.GetPlayers = function() return {ctx.Player, enemy, mate} end
    ctx.Services.Players.GetPlayerFromCharacter = function(_, character)
        if character == localChar then return ctx.Player end
        if character == enemyChar then return enemy end
        if character == mateChar then return mate end
        return nil
    end

    local backend = ctx:Run("src/games/bloodstrike.lua")
    check(type(backend) == "table" and backend.Destroyed == false, "Blood Strike entry returns a live backend")

    -- ESP off: nothing is created.
    backend:SetESP(false)
    check(next(backend.ESPObjects) == nil, "ESP stays empty while disabled")

    -- ESP on with team check: the enemy is tagged, the teammate is not.
    backend:SetESP(true)
    check(backend.ESPObjects[enemyChar] ~= nil, "ESP tags an enemy character")
    check(backend.ESPObjects[mateChar] == nil, "team check skips the teammate")
    local record = backend.ESPObjects[enemyChar]
    check(record.Billboard ~= nil and record.Label ~= nil, "ESP builds a billboard and label")
    check(record.Highlight ~= nil, "ESP builds chams by default")
    check(record.Label.Text:find("Enemy", 1, true) ~= nil, "ESP label shows the name")
    check(record.Label.Text:find("30", 1, true) ~= nil, "ESP label shows the distance")
    check(record.Label.Text:find("HP", 1, true) == nil, "health is off by default")

    -- Health toggle repaints on the next refresh.
    backend:SetToggle("ESPHealth", true)
    backend:Refresh()
    check(backend.ESPObjects[enemyChar].Label.Text:find("75 HP", 1, true) ~= nil, "health toggle adds HP to the label")

    -- Team check off: the teammate becomes visible too.
    backend:SetToggle("TeamCheck", false)
    check(backend.ESPObjects[mateChar] ~= nil, "disabling team check tags the teammate")

    -- Range: the teammate at 400 studs is out of a 100-stud range.
    backend:SetToggle("TeamCheck", true)
    backend:SetRange(100)
    backend:Refresh()
    check(backend.ESPObjects[mateChar] == nil, "range hides a distant fighter")
    check(backend.ESPObjects[enemyChar] ~= nil, "range keeps a near fighter")
    check(backend:SetRange(0) == false and backend:SetRange("x") == false, "range rejects invalid values")

    -- Chams off removes only the highlight, keeping the billboard.
    backend:SetToggle("Chams", false)
    local afterChams = backend.ESPObjects[enemyChar]
    check(afterChams ~= nil and afterChams.Highlight == nil and afterChams.Billboard ~= nil, "chams toggle drops the highlight only")

    -- A character leaving the container is cleaned up on the next refresh.
    enemyChar.Parent = nil
    backend:Refresh()
    check(backend.ESPObjects[enemyChar] == nil, "ESP drops a fighter that left the container")

    -- Fallback path: with no Characters container the ESP uses Players.
    characters.Parent = nil
    local fallbackEnemy = object("Model", "FallbackEnemy", nil)
    local fbRoot = object("Part", "HumanoidRootPart", fallbackEnemy); fbRoot.Position = Vector3.new(10, 0, 0)
    object("Humanoid", "Humanoid", fallbackEnemy)
    local fbPlayer = Instance.new("Player"); fbPlayer.Name = "FallbackEnemy"; fbPlayer.Character = fallbackEnemy
    ctx.Services.Players.GetPlayers = function() return {ctx.Player, fbPlayer} end
    backend:SetToggle("TeamCheck", true)
    backend:SetToggle("Chams", true)
    backend:Refresh()
    check(backend.ESPObjects[fallbackEnemy] ~= nil, "ESP falls back to the Players surface")

    -- Destroy clears the ESP and releases the runtime.
    backend:Destroy()
    backend:Destroy()
    check(next(backend.ESPObjects) == nil, "destroy clears the ESP records")
    check(backend.Destroyed == true and backend:SetToggle("ESP", true) == false, "destroyed backend rejects toggles")
    check(ctx.State.__DEPHUB.BloodStrike == nil, "destroy releases the published runtime")
end

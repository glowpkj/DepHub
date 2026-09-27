local IslandData={}

local islands={
    {
        Name="HomeIsland",
        DisplayName="HomeIsland",
        Order=1,
        CFrame=CFrame.new(
            -1690.98621,10.2895718,-69.7156982,
            -0.5592103,0,0.829025805,
            0,1,0,
            -0.829025805,0,-0.5592103
        ),
        LevelMin=1,
        LevelMax=30,
        WorkspacePath={"Ilhas","HomeIsland"},
        EnemyFolder="HomeIsland",
        Enemies={
            {Id="Noob",Order=1,QuestGiver="QuestGiver1",QuestChoice="Noob",QuestId="QuestGiver1_1",QuestMinLevel=1,QuestMaxLevel=15},
            {Id="Bacon",Order=2,QuestGiver="QuestGiver1",QuestChoice="Bacon",QuestId="QuestGiver1_2",QuestMinLevel=15,QuestMaxLevel=30},
            {Id="Mega Noob",Boss=true,Order=3}
        }
    },
    {
        Name="CentralIsland",
        DisplayName="CentralIsland",
        Order=2,
        CFrame=CFrame.new(
            6.64712143,42.4040222,35.0391083,
            0,0,-1,
            0,1,0,
            1,0,0
        ),
        WorkspacePath={"Ilhas","CentralIsland"},
        EnemyFolder="CentralIsland",
        Enemies={}
    },
    {
        Name="ForestIsland",
        DisplayName="ForestIsland",
        Order=3,
        CFrame=CFrame.new(703.284973,8.0722971,1853.84863),
        LevelMin=30,
        LevelMax=100,
        WorkspacePath={"Ilhas","ForestIsland"},
        EnemyFolder="ForestIsland",
        Enemies={
            {Id="Monkey",Order=1},
            {Id="Hunter",Order=2},
            {Id="Gorilla",Boss=true,Order=3}
        }
    },
    {
        Name="DesertIsland",
        DisplayName="DesertIsland",
        Order=4,
        WorkspacePath={"Ilhas","DesertIsland"},
        EnemyFolder="DesertIsland",
        Enemies={
            {Id="Bandit",Order=1},
            {Id="Mummy",Order=2},
            {Id="Pharaoh",Boss=true,Order=3}
        }
    },
    {
        Name="SnowIsland",
        DisplayName="SnowIsland",
        Order=5,
        WorkspacePath={"Ilhas","SnowIsland"},
        EnemyFolder="SnowIsland",
        Enemies={
            {Id="SnowMan",Order=1},
            {Id="GingerBread",Order=2},
            {Id="Abominable Snowman",Boss=true,Order=3}
        }
    },
    {
        Name="CastleIsland",
        DisplayName="CastleIsland",
        Order=6,
        WorkspacePath={"Ilhas","CastleIsland"},
        EnemyFolder="CastleIsland",
        Enemies={
            {Id="Blue Knight",Order=1},
            {Id="Red Knight",Order=2},
            {Id="King",Boss=true,Order=3}
        }
    },
    {
        Name="GiantIsland",
        DisplayName="GiantIsland",
        Order=7,
        WorkspacePath={"Ilhas","GiantIsland"},
        EnemyFolder="GiantIsland",
        Enemies={
            {Id="Bacon Wizard",Order=1},
            {Id="Chef",Order=2},
            {Id="Student",Order=3},
            {Id="Wizard",Boss=true,Order=4}
        }
    },
    {
        Name="MysteriousIsland",
        DisplayName="MysteriousIsland",
        Order=8,
        CFrame=CFrame.new(
            -434.964844,13.6790476,2161.72119,
            1,0,0,
            0,1,0,
            0,0,1
        ),
        Mirage=true,
        WorkspacePath={"MysteriousIsland"},
        ChestPath={"MysteriousIsland","Bau"},
        NPCs={
            {
                Name="ShikaiZangetsu",
                Path={"MysteriousIsland","ShikaiZangetsu"},
                Quest=true,
                Note="Possible sword-related quest"
            }
        },
        Enemies={}
    }
}

local byName={}

for _,island in ipairs(islands) do
    byName[island.Name]=island
end

function IslandData.GetAll()
    return islands
end

function IslandData.Get(name)
    return byName[name]
end

function IslandData.GetTeleportable()
    local result={}

    for _,island in ipairs(islands) do
        if island.CFrame then
            result[#result+1]=island
        end
    end

    return result
end

function IslandData.FindEnemy(id)
    for _,island in ipairs(islands) do
        for _,enemy in ipairs(island.Enemies or {}) do
            if enemy.Id==id then
                return island,enemy
            end
        end
    end

    return nil
end

return IslandData

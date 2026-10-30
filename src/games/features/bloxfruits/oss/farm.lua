local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Farm: level auto-farm. Flies to the quest mob's spawn (not just the nearest enemy) and
-- attacks through Combat. Mob/quest lists are per-sea (currentList picks by the detected sea).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local M = {}
M.config = {
    questInterval = 5, attackInterval = 0.2, heightOffset = 12,
    hoverRange = 250,
    bring = false,
    equip = false, equipType = "Melee",
    stat = "Melee", statAmount = 1,
}
M._mobName = nil
M._anchor, M._collecting = nil, false
M._fruitSkip = setmetatable({}, { __mode = "k" })
M._fruitTries = setmetatable({}, { __mode = "k" })
M._decollided = setmetatable({}, { __mode = "k" })
M.stats = { "Melee", "Defense", "Sword", "Gun", "Blox Fruit" }

M.sea1 = {
    { id = "BanditQuest1",  tier = 1, level = 1,   mob = "Bandit",              label = "Bandit (Lv 1)" },
    { id = "JungleQuest",   tier = 1, level = 10,  mob = "Monkey",              label = "Monkey (Lv 10)" },
    { id = "JungleQuest",   tier = 2, level = 15,  mob = "Gorilla",             label = "Gorilla (Lv 15)" },
    { id = "BuggyQuest1",   tier = 1, level = 30,  mob = "Pirate",              label = "Pirate (Lv 30)" },
    { id = "BuggyQuest1",   tier = 2, level = 40,  mob = "Brute",               label = "Brute (Lv 40)" },
    { id = "DesertQuest",   tier = 1, level = 60,  mob = "Desert Bandit",       label = "Desert Bandit (Lv 60)" },
    { id = "DesertQuest",   tier = 2, level = 75,  mob = "Desert Officer",      label = "Desert Officer (Lv 75)" },
    { id = "SnowQuest",     tier = 1, level = 90,  mob = "Snow Bandit",         label = "Snow Bandit (Lv 90)" },
    { id = "SnowQuest",     tier = 2, level = 100, mob = "Snowman",             label = "Snowman (Lv 100)" },
    { id = "MarineQuest2",  tier = 1, level = 120, mob = "Chief Petty Officer", label = "Chief Petty Officer (Lv 120)" },
    { id = "MarineQuest2",  tier = 2, level = 130, mob = "Vice Admiral",        label = "Vice Admiral (Lv 130)" },
    { id = "SkyQuest",      tier = 1, level = 150, mob = "Sky Bandit",          label = "Sky Bandit (Lv 150)" },
    { id = "SkyQuest",      tier = 2, level = 175, mob = "Dark Master",         label = "Dark Master (Lv 175)" },
    { id = "PrisonerQuest", tier = 1, level = 190, mob = "Prisoner",            label = "Prisoner (Lv 190)" },
    { id = "PrisonerQuest", tier = 2, level = 210, mob = "Dangerous Prisoner",  label = "Dangerous Prisoner (Lv 210)" },
    { id = "ColosseumQuest",tier = 1, level = 250, mob = "Toga Warrior",        label = "Toga Warrior (Lv 250)" },
    { id = "ColosseumQuest",tier = 2, level = 275, mob = "Gladiator",           label = "Gladiator (Lv 275)" },
    { id = "MagmaQuest",    tier = 1, level = 300, mob = "Military Soldier",    label = "Military Soldier (Lv 300)" },
    { id = "MagmaQuest",    tier = 2, level = 325, mob = "Military Spy",        label = "Military Spy (Lv 325)" },
    { id = "FishmanQuest",  tier = 1, level = 375, mob = "Fishman Warrior",     label = "Fishman Warrior (Lv 375)" },
    { id = "FishmanQuest",  tier = 2, level = 400, mob = "Fishman Commando",    label = "Fishman Commando (Lv 400)" },
    { id = "SkyExp1Quest",  tier = 1, level = 450, mob = "God's Guard",         label = "God's Guard (Lv 450)" },
    { id = "SkyExp1Quest",  tier = 2, level = 475, mob = "Shanda",             label = "Shanda (Lv 475)" },
    { id = "SkyExp2Quest",  tier = 1, level = 525, mob = "Royal Squad",        label = "Royal Squad (Lv 525)" },
    { id = "SkyExp2Quest",  tier = 2, level = 550, mob = "Royal Soldier",      label = "Royal Soldier (Lv 550)" },
    { id = "FountainQuest", tier = 1, level = 625, mob = "Galley Pirate",      label = "Galley Pirate (Lv 625)" },
    { id = "FountainQuest", tier = 2, level = 650, mob = "Galley Captain",     label = "Galley Captain (Lv 650)" },
}
M.sea2 = {
    { id = "Area1Quest",       tier = 1, level = 700,  mob = "Raider",             label = "Raider (Lv 700)" },
    { id = "Area1Quest",       tier = 2, level = 725,  mob = "Mercenary",          label = "Mercenary (Lv 725)" },
    { id = "Area2Quest",       tier = 1, level = 775,  mob = "Swan Pirate",        label = "Swan Pirate (Lv 775)" },
    { id = "Area2Quest",       tier = 2, level = 800,  mob = "Factory Staff",      label = "Factory Staff (Lv 800)" },
    { id = "MarineQuest3",     tier = 1, level = 875,  mob = "Marine Lieutenant",  label = "Marine Lieutenant (Lv 875)" },
    { id = "MarineQuest3",     tier = 2, level = 900,  mob = "Marine Captain",     label = "Marine Captain (Lv 900)" },
    { id = "ZombieQuest",      tier = 1, level = 950,  mob = "Zombie",             label = "Zombie (Lv 950)" },
    { id = "ZombieQuest",      tier = 2, level = 975,  mob = "Vampire",            label = "Vampire (Lv 975)" },
    { id = "SnowMountainQuest",tier = 1, level = 1000, mob = "Snow Trooper",       label = "Snow Trooper (Lv 1000)" },
    { id = "SnowMountainQuest",tier = 2, level = 1050, mob = "Winter Warrior",     label = "Winter Warrior (Lv 1050)" },
    { id = "IceSideQuest",     tier = 1, level = 1100, mob = "Lab Subordinate",    label = "Lab Subordinate (Lv 1100)" },
    { id = "IceSideQuest",     tier = 2, level = 1125, mob = "Horned Warrior",     label = "Horned Warrior (Lv 1125)" },
    { id = "FireSideQuest",    tier = 1, level = 1175, mob = "Magma Ninja",        label = "Magma Ninja (Lv 1175)" },
    { id = "FireSideQuest",    tier = 2, level = 1200, mob = "Lava Pirate",        label = "Lava Pirate (Lv 1200)" },
    { id = "ShipQuest1",       tier = 1, level = 1250, mob = "Ship Deckhand",      label = "Ship Deckhand (Lv 1250)" },
    { id = "ShipQuest1",       tier = 2, level = 1275, mob = "Ship Engineer",      label = "Ship Engineer (Lv 1275)" },
    { id = "ShipQuest2",       tier = 1, level = 1300, mob = "Ship Steward",       label = "Ship Steward (Lv 1300)" },
    { id = "ShipQuest2",       tier = 2, level = 1325, mob = "Ship Officer",       label = "Ship Officer (Lv 1325)" },
    { id = "FrostQuest",       tier = 1, level = 1350, mob = "Arctic Warrior",     label = "Arctic Warrior (Lv 1350)" },
    { id = "FrostQuest",       tier = 2, level = 1375, mob = "Snow Lurker",        label = "Snow Lurker (Lv 1375)" },
    { id = "ForgottenQuest",   tier = 1, level = 1425, mob = "Sea Soldier",        label = "Sea Soldier (Lv 1425)" },
    { id = "ForgottenQuest",   tier = 2, level = 1450, mob = "Water Fighter",      label = "Water Fighter (Lv 1450)" },
    { id = "BartiloQuest",     tier = 1, level = 775,  mob = "Swan Pirate",        kills = 50, label = "Bartilo Quest (50 Swan Pirates)" },
}
M.sea3 = {
    { id = "PiratePortQuest",    tier = 1, level = 1500, mob = "Pirate Millionaire",    label = "Pirate Millionaire (Lv 1500)" },
    { id = "PiratePortQuest",    tier = 2, level = 1525, mob = "Pistol Billionaire",    label = "Pistol Billionaire (Lv 1525)" },
    { id = "DragonCrewQuest",    tier = 1, level = 1575, mob = "Dragon Crew Warrior",   label = "Dragon Crew Warrior (Lv 1575)" },
    { id = "VenomCrewQuest",     tier = 4, level = 1700, mob = "Marine Commodore",      label = "Marine Commodore (Lv 1700)" },
    { id = "VenomCrewQuest",     tier = 5, level = 1725, mob = "Marine Rear Admiral",   label = "Marine Rear Admiral (Lv 1725)" },
    { id = "VenomCrewQuest",     tier = 7, level = 1775, mob = "Fishman Raider",        label = "Fishman Raider (Lv 1775)" },
    { id = "VenomCrewQuest",     tier = 8, level = 1800, mob = "Fishman Captain",       label = "Fishman Captain (Lv 1800)" },
    { id = "VenomCrewQuest",     tier = 9, level = 1825, mob = "Forest Pirate",         label = "Forest Pirate (Lv 1825)" },
    { id = "VenomCrewQuest",     tier = 10, level = 1850, mob = "Mythological Pirate",  label = "Mythological Pirate (Lv 1850)" },
    { id = "VenomCrewQuest",     tier = 12, level = 1900, mob = "Jungle Pirate",        label = "Jungle Pirate (Lv 1900)" },
    { id = "VenomCrewQuest",     tier = 13, level = 1925, mob = "Musketeer Pirate",     label = "Musketeer Pirate (Lv 1925)" },
    { id = "HauntedQuest1",      tier = 1, level = 1975, mob = "Reborn Skeleton",       label = "Reborn Skeleton (Lv 1975)" },
    { id = "HauntedQuest1",      tier = 2, level = 2000, mob = "Living Zombie",         label = "Living Zombie (Lv 2000)" },
    { id = "HauntedQuest2",      tier = 2, level = 2050, mob = "Posessed Mummy",        label = "Posessed Mummy (Lv 2050)" },
    { id = "NutsIslandQuest",    tier = 1, level = 2075, mob = "Peanut Scout",          label = "Peanut Scout (Lv 2075)" },
    { id = "NutsIslandQuest",    tier = 2, level = 2100, mob = "Peanut President",      label = "Peanut President (Lv 2100)" },
    { id = "IceCreamIslandQuest",tier = 1, level = 2125, mob = "Ice Cream Chef",        label = "Ice Cream Chef (Lv 2125)" },
    { id = "IceCreamIslandQuest",tier = 2, level = 2150, mob = "Ice Cream Commander",   label = "Ice Cream Commander (Lv 2150)" },
    { id = "CakeQuest2",         tier = 1, level = 2250, mob = "Baking Staff",          label = "Baking Staff (Lv 2250)" },
    { id = "CakeQuest2",         tier = 2, level = 2275, mob = "Head Baker",            label = "Head Baker (Lv 2275)" },
    { id = "ChocQuest1",         tier = 1, level = 2300, mob = "Cocoa Warrior",         label = "Cocoa Warrior (Lv 2300)" },
    { id = "ChocQuest1",         tier = 2, level = 2325, mob = "Chocolate Bar Battler", label = "Chocolate Bar Battler (Lv 2325)" },
    { id = "ChocQuest2",         tier = 1, level = 2350, mob = "Sweet Thief",           label = "Sweet Thief (Lv 2350)" },
    { id = "ChocQuest2",         tier = 2, level = 2375, mob = "Candy Rebel",           label = "Candy Rebel (Lv 2375)" },
    { id = "CandyQuest1",        tier = 1, level = 2400, mob = "Candy Pirate",          label = "Candy Pirate (Lv 2400)" },
    { id = "CandyQuest1",        tier = 2, level = 2425, mob = "Snow Demon",            label = "Snow Demon (Lv 2425)" },
    { id = "TikiQuest1",         tier = 1, level = 2450, mob = "Isle Outlaw",           label = "Isle Outlaw (Lv 2450)" },
    { id = "TikiQuest1",         tier = 2, level = 2475, mob = "Island Boy",            label = "Island Boy (Lv 2475)" },
    { id = "TikiQuest2",         tier = 1, level = 2500, mob = "Sun-kissed Warrior",    label = "Sun-kissed Warrior (Lv 2500)" },
    { id = "TikiQuest2",         tier = 2, level = 2525, mob = "Isle Champion",         label = "Isle Champion (Lv 2525)" },
    { id = "TikiQuest3",         tier = 1, level = 2550, mob = "Serpent Hunter",        label = "Serpent Hunter (Lv 2550)" },
    { id = "TikiQuest3",         tier = 2, level = 2575, mob = "Skull Slayer",          label = "Skull Slayer (Lv 2575)" },
    { id = "SubmergedQuest1",    tier = 1, level = 2600, mob = "Reef Bandit",           label = "Reef Bandit (Lv 2600)" },
    { id = "SubmergedQuest1",    tier = 2, level = 2625, mob = "Coral Pirate",          label = "Coral Pirate (Lv 2625)" },
    { id = "SubmergedQuest2",    tier = 1, level = 2650, mob = "Sea Chanter",           label = "Sea Chanter (Lv 2650)" },
    { id = "SubmergedQuest2",    tier = 2, level = 2675, mob = "Ocean Prophet",         label = "Ocean Prophet (Lv 2675)" },
    { id = "SubmergedQuest3",    tier = 2, level = 2700, mob = "Grand Devotee",         label = "Grand Devotee (Lv 2700)" },
}
M.spawns = {
    ["Monkey"] = Vector3.new(-1866.3, 29.9, 21.6),
    ["Gorilla"] = Vector3.new(-1266.6, 14.5, -462.0),
    ["Pirate"] = Vector3.new(-981.0, 30.4, 3966.8),
    ["Brute"] = Vector3.new(-1085.9, 28.1, 4342.7),
    ["Desert Bandit"] = Vector3.new(999.9, 7.6, 4490.3),
    ["Desert Officer"] = Vector3.new(1523.8, 15.3, 4095.4),
    ["Snow Bandit"] = Vector3.new(1519.5, 78.0, -1510.9),
    ["Snowman"] = Vector3.new(1121.5, 98.2, -1669.0),
    ["Chief Petty Officer"] = Vector3.new(-4763.7, 13.4, 4288.8),
    ["Sky Bandit"] = Vector3.new(-4973.7, 280.7, -1119.4),
    ["Dark Master"] = Vector3.new(-5283.2, 505.1, -221.0),
    ["Prisoner"] = Vector3.new(5278.6, 7.1, 391.6),
    ["Dangerous Prisoner"] = Vector3.new(5058.3, 9.1, 900.9),
    ["Toga Warrior"] = Vector3.new(-1973.1, 9.0, -2744.9),
    ["Gladiator"] = Vector3.new(-1161.9, 11.6, -3097.2),
    ["Military Soldier"] = Vector3.new(-5623.8, 17.0, 8314.1),
    ["Military Spy"] = Vector3.new(-5952.5, 76.9, 8742.4),
    ["Fishman Warrior"] = Vector3.new(60736.8, 23.8, 1396.3),
    ["Fishman Commando"] = Vector3.new(61808.1, 24.6, 1328.6),
    ["God's Guard"] = Vector3.new(-4082.9, 1087.3, -414.1),
    ["Shanda"] = Vector3.new(-6040.2, 5468.0, 1734.2),
    ["Royal Squad"] = Vector3.new(-6706.9, 5551.4, 1155.4),
    ["Royal Soldier"] = Vector3.new(-7138.5, 5541.1, 1050.8),
    ["Galley Pirate"] = Vector3.new(5430.4, 78.0, 3953.6),
    ["Galley Captain"] = Vector3.new(5409.5, 77.7, 4687.0),
    ["Raider"] = Vector3.new(-612.4, 40.0, 2557.4),
    ["Mercenary"] = Vector3.new(-1135.9, 72.9, 1248.3),
    ["Swan Pirate"] = Vector3.new(1067.0, 72.8, 1080.9),
    ["Factory Staff"] = Vector3.new(386.1, 72.8, 91.8),
    ["Marine Lieutenant"] = Vector3.new(-2583.9, 71.0, -3039.6),
    ["Marine Captain"] = Vector3.new(-2103.9, 73.0, -3259.3),
    ["Zombie"] = Vector3.new(-5615.0, 49.3, -938.5),
    ["Vampire"] = Vector3.new(-6132.4, 9.0, -1466.2),
    ["Snow Trooper"] = Vector3.new(484.3, 400.8, -5472.4),
    ["Winter Warrior"] = Vector3.new(1226.3, 428.8, -5216.0),
    ["Lab Subordinate"] = Vector3.new(-5998.3, 90.0, -4386.5),
    ["Horned Warrior"] = Vector3.new(-6540.0, 29.2, -5718.0),
    ["Magma Ninja"] = Vector3.new(-5711.4, 47.4, -5658.5),
    ["Lava Pirate"] = Vector3.new(-5111.3, 32.2, -5115.9),
    ["Ship Deckhand"] = Vector3.new(1157.3, 125.6, 32930.1),
    ["Ship Engineer"] = Vector3.new(834.8, 43.7, 32720.9),
    ["Ship Steward"] = Vector3.new(801.4, 125.8, 33505.2),
    ["Ship Officer"] = Vector3.new(694.5, 179.9, 33112.6),
    ["Arctic Warrior"] = Vector3.new(6271.3, 27.6, -6151.5),
    ["Snow Lurker"] = Vector3.new(5524.2, 27.6, -6583.8),
    ["Sea Soldier"] = Vector3.new(-2550.9, 28.5, -9840.0),
    ["Water Fighter"] = Vector3.new(-3331.7, 239.1, -10553.4),
    ["Pirate Millionaire"] = Vector3.new(-232.9, 57.0, 5757.8),
    ["Pistol Billionaire"] = Vector3.new(-54.8, 83.8, 5947.8),
    ["Dragon Crew Warrior"] = Vector3.new(7217.8, 56.6, -680.8),
    ["Marine Commodore"] = Vector3.new(2577.3, 75.6, -7739.9),
    ["Marine Rear Admiral"] = Vector3.new(3920.1, 146.2, -7175.2),
    ["Fishman Raider"] = Vector3.new(-10223.1, 332.6, -8482.5),
    ["Fishman Captain"] = Vector3.new(-10736.7, 331.8, -8807.6),
    ["Forest Pirate"] = Vector3.new(-13105.5, 332.2, -7705.8),
    ["Mythological Pirate"] = Vector3.new(-13221.0, 519.1, -6689.0),
    ["Jungle Pirate"] = Vector3.new(-12321.3, 331.4, -10669.3),
    ["Musketeer Pirate"] = Vector3.new(-13556.1, 391.4, -9735.9),
    ["Reborn Skeleton"] = Vector3.new(-8710.1, 141.0, 6112.9),
    ["Living Zombie"] = Vector3.new(-10170.9, 141.2, 6159.6),
    ["Posessed Mummy"] = Vector3.new(-9399.6, 12.2, 6118.8),
    ["Peanut Scout"] = Vector3.new(-1924.0, 37.3, -10199.7),
    ["Peanut President"] = Vector3.new(-1993.4, 37.2, -10682.9),
    ["Ice Cream Chef"] = Vector3.new(-502.4, 64.6, -10873.8),
    ["Ice Cream Commander"] = Vector3.new(-366.8, 64.7, -11094.4),
    ["Baking Staff"] = Vector3.new(-1774.1, 34.7, -12850.5),
    ["Head Baker"] = Vector3.new(-2389.2, 51.0, -13018.3),
    ["Cocoa Warrior"] = Vector3.new(-128.7, 26.2, -12249.8),
    ["Chocolate Bar Battler"] = Vector3.new(598.8, 25.6, -12395.1),
    ["Sweet Thief"] = Vector3.new(-77.6, 25.6, -12765.6),
    ["Candy Rebel"] = Vector3.new(166.8, 25.6, -13035.3),
    ["Candy Pirate"] = Vector3.new(-1226.8, 36.3, -14777.6),
    ["Snow Demon"] = Vector3.new(-936.2, 14.0, -14552.5),
    ["Isle Outlaw"] = Vector3.new(-16351.8, 23.5, -282.5),
    ["Island Boy"] = Vector3.new(-16736.2, 22.2, -131.7),
    ["Sun-kissed Warrior"] = Vector3.new(-16413.5, 56.7, 1054.4),
    ["Isle Champion"] = Vector3.new(-16735.7, 23.3, 1110.6),
    ["Serpent Hunter"] = Vector3.new(-16536.0, 106.9, 1347.1),
    ["Skull Slayer"] = Vector3.new(-16829.4, 193.2, 1753.4),
    ["Reef Bandit"] = Vector3.new(10899.9, -2145.2, 9279.3),
    ["Coral Pirate"] = Vector3.new(10703.7, -2087.3, 9255.4),
    ["Sea Chanter"] = Vector3.new(10680.1, -2056.7, 9933.9),
    ["Ocean Prophet"] = Vector3.new(11129.8, -2007.8, 10051.5),
    ["Grand Devotee"] = Vector3.new(9559.2, -1994.4, 9798.7),
}
M.kills = {
    Bandit = 5, Monkey = 6, Gorilla = 8, Pirate = 8, Brute = 8,
    ["Desert Bandit"] = 8, ["Desert Officer"] = 6, ["Snow Bandit"] = 7, Snowman = 8,
    ["Chief Petty Officer"] = 8, ["Vice Admiral"] = 1, ["Sky Bandit"] = 7, ["Dark Master"] = 8,
    Prisoner = 8, ["Dangerous Prisoner"] = 8, ["Toga Warrior"] = 7, Gladiator = 8,
    ["Military Soldier"] = 7, ["Military Spy"] = 8, ["Fishman Warrior"] = 8, ["Fishman Commando"] = 7,
    Shanda = 9, ["Royal Squad"] = 8, ["Royal Soldier"] = 8, ["Galley Pirate"] = 8, ["Galley Captain"] = 9,
    Raider = 8, Mercenary = 8, ["Swan Pirate"] = 8, ["Factory Staff"] = 8,
    ["Marine Lieutenant"] = 8, ["Marine Captain"] = 9, Zombie = 8, Vampire = 8,
    ["Snow Trooper"] = 8, ["Winter Warrior"] = 9, ["Lab Subordinate"] = 8, ["Horned Warrior"] = 9,
    ["Magma Ninja"] = 8, ["Lava Pirate"] = 8, ["Ship Deckhand"] = 8, ["Ship Engineer"] = 8,
    ["Ship Steward"] = 8, ["Ship Officer"] = 8, ["Arctic Warrior"] = 8, ["Snow Lurker"] = 8,
    ["Sea Soldier"] = 8, ["Water Fighter"] = 8,
    ["Pirate Millionaire"] = 8, ["Pistol Billionaire"] = 8, ["Dragon Crew Warrior"] = 8,
    ["Marine Commodore"] = 8, ["Marine Rear Admiral"] = 8, ["Fishman Raider"] = 8, ["Fishman Captain"] = 8,
    ["Forest Pirate"] = 8, ["Mythological Pirate"] = 8, ["Jungle Pirate"] = 8, ["Musketeer Pirate"] = 8,
    ["Reborn Skeleton"] = 8, ["Living Zombie"] = 8, ["Posessed Mummy"] = 8, ["Peanut Scout"] = 8,
    ["Peanut President"] = 8, ["Ice Cream Chef"] = 8, ["Ice Cream Commander"] = 8, ["Baking Staff"] = 8,
    ["Head Baker"] = 8, ["Cocoa Warrior"] = 8, ["Chocolate Bar Battler"] = 8, ["Sweet Thief"] = 8,
    ["Candy Rebel"] = 8, ["Candy Pirate"] = 8, ["Snow Demon"] = 8, ["Isle Outlaw"] = 8, ["Island Boy"] = 8,
    ["Sun-kissed Warrior"] = 8, ["Isle Champion"] = 8, ["Serpent Hunter"] = 8, ["Skull Slayer"] = 8,
    ["Reef Bandit"] = 8, ["Coral Pirate"] = 8, ["Sea Chanter"] = 8, ["Ocean Prophet"] = 8, ["Grand Devotee"] = 8,
}

M.bosses = {
    { name = "Chef", level = 55, pos = Vector3.new(-1120.5, 54.7, 4121.2) },
    { name = "Yeti", level = 110, pos = Vector3.new(1181.7, 104.0, -1616.9) },
    { name = "Mob Boss", level = 120, pos = Vector3.new(-2880.7, 6.7, 5430.9) },
    { name = "Saber Expert", level = 200, pos = Vector3.new(-1527.2, 34.1, -33.2) },
    { name = "Warden", level = 230, pos = Vector3.new(5623.2, 1.4, 733.8) },
    { name = "Magma General", level = 350, pos = Vector3.new(-5625.7, 55.4, 8623.0) },
    { name = "Fishman Lord", level = 425, pos = Vector3.new(61352.9, 67.2, 1029.1) },
    { name = "Sky Warlord", level = 500, pos = Vector3.new(-6271.6, 5472.8, 1887.8) },
    { name = "Cyborg", level = 675, pos = Vector3.new(6252.4, 9.3, 4941.4) },
    { name = "Ice Admiral", level = 700, pos = Vector3.new(1212.4, 20.4, -1429.6) },
}
M.bosses2 = {
    { name = "Diamond", level = 750, pos = Vector3.new(-1711.4, 206.0, -97.1) },
    { name = "Jeremy", level = 850, pos = Vector3.new(2338.0, 451.4, 700.1) },
    { name = "Smoke Admiral", level = 1150, pos = Vector3.new(-4857.4, 233.7, -5583.2) },
    { name = "Awakened Ice Admiral", level = 1400, pos = Vector3.new(6551.8, 325.3, -6989.9) },
    { name = "rip_indra", level = 1500, pos = Vector3.new(-26952.3, 21.5, 329.4) },
}
M.bosses3 = {
    { name = "Kilo Admiral", level = 1750, pos = Vector3.new(2998.3, 508.8, -7344.3) },
    { name = "Captain Elephant", level = 1875, pos = Vector3.new(-13365.5, 321.2, -8485.0) },
    { name = "Longma", level = 2000, pos = Vector3.new(-10156.2, 337.8, -9445.9) },
    { name = "Cake Queen", level = 2175, pos = Vector3.new(-678.5, 381.9, -11114.3) },
    { name = "Cake Prince", level = 2200, pos = Vector3.new(-2089.9, 4536.9, -14800.0) },
}
M.sea3materials = {
    { mat = "Fish Tail",       mob = "Fishman Raider" },
    { mat = "Mystic Droplet",  mob = "Ocean Prophet" },
    { mat = "Ectoplasm",       mob = "Reborn Skeleton" },
    { mat = "Dragon Scale",    mob = "Dragon Crew Warrior" },
    { mat = "Gunpowder",       mob = "Pirate Millionaire" },
}
M.sea2materials = {
    { mat = "Scrap Metal",    mob = "Factory Staff" },
    { mat = "Vampire Fang",   mob = "Vampire" },
    { mat = "Magma Ore",      mob = "Magma Ninja" },
    { mat = "Conjured Cocoa", mob = "Ship Deckhand" },
    { mat = "Mystic Droplet", mob = "Water Fighter" },
}
M.selectedBoss = nil
M.selected = nil
M._statAuto, M._farmOn, M._bossOn, M._nearestOn, M._warn = false, false, false, false, 0
M._curKey, M._target = nil, nil
M._killCount, M._killReq, M._prevAlive = 0, 8, nil

local function commF() local r = RS:FindFirstChild("Remotes"); return r and r:FindFirstChild("CommF_") end
local function hrp() local ch = LP.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end

function M.playerLevel()
    local ok, lv = pcall(function() return LP.Data.Level.Value end)
    return (ok and lv) or 1
end

function M.currentList()
    local info = M._core and M._core.modules.info
    local sea = info and info.sea
    if sea == "Sea3" then return M.sea3 end
    if sea == "Sea2" then return M.sea2 end
    return M.sea1
end

function M.bestForLevel()
    local list = M.currentList()
    local lv, best = M.playerLevel(), list[1]
    for _, q in ipairs(list) do if q.level <= lv then best = q else break end end
    return best
end

function M.aliveMobs(name)
    local folder, list = workspace:FindFirstChild("Enemies"), {}
    if folder then
        for _, e in ipairs(folder:GetChildren()) do
            if e.Name:lower() == name:lower() then
                local hum = e:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then list[#list + 1] = e end
            end
        end
    end
    return list
end

function M.nearestMob(name)
    local h, folder = hrp(), workspace:FindFirstChild("Enemies")
    if not h or not folder then return end
    local best, bestD
    for _, e in ipairs(folder:GetChildren()) do
        if e.Name:lower() == name:lower() then
            local hum = e:FindFirstChildOfClass("Humanoid")
            local part = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
            if hum and hum.Health > 0 and part then
                local d = (part.Position - h.Position).Magnitude
                if not bestD or d < bestD then best, bestD = e, d end
            end
        end
    end
    return best
end

function M.warnEnemies(want)
    if os.clock() - M._warn < 4 then return end
    M._warn = os.clock()
    local folder, seen, list = workspace:FindFirstChild("Enemies"), {}, {}
    if folder then for _, e in ipairs(folder:GetChildren()) do if not seen[e.Name] then seen[e.Name] = true; list[#list + 1] = e.Name end end end
    if M._core then M._core.warn("no '" .. want .. "' nearby; enemies:", table.concat(list, ", ")) end
end

local function isKind(t, kind)
    if kind == "Fruit" then
        local o = t:GetAttribute("OriginalName")
        return (o and tostring(o):find("-") ~= nil) or t.ToolTip == "Blox Fruit"
    end
    return t.ToolTip == kind
end
function M.equipWeapon(kind)
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (ch and hum) then return end
    local eq = ch:FindFirstChildOfClass("Tool")
    if eq and isKind(eq, kind) then return end
    for _, pool in ipairs({ ch, LP:FindFirstChild("Backpack") }) do
        if pool then
            for _, t in ipairs(pool:GetChildren()) do
                if t:IsA("Tool") and isKind(t, kind) then hum:EquipTool(t); return end
            end
        end
    end
end

function M.startQuest()
    local c = commF()
    if not c then return end
    local q = M.selected or M.bestForLevel()
    pcall(function() return c:InvokeServer("StartQuest", q.id, q.tier) end)
    if M._core then M._core.info("StartQuest", q.id, q.tier, q.label) end
end

function M.addPoint(stat, amount)
    local c = commF()
    if not c then return end
    stat, amount = stat or M.config.stat, amount or M.config.statAmount
    pcall(function() return c:InvokeServer("AddPoint", stat, amount) end)
    if M._core then M._core.info("AddPoint", stat, amount) end
end

local function loop(flag, fn, interval)
    if not M._core then return end
    M._core.spawn(function() while M[flag] do fn(); task.wait(interval) end end)
end

function M.setStatAuto(on) M._statAuto = on; if on then loop("_statAuto", function() M.addPoint() end, 1) end end

function M._farmStep(combat, teleport)
    local q = M.selected or M.bestForLevel()
    M._mobName = q.mob
    local key = q.id .. "#" .. q.tier

    local fr = M._core.modules.fruits
    local ffruit, fpart = nil, nil
    if fr and fr._collect then ffruit, fpart = fr.nearestGroundFruit(M._fruitSkip) end
    if ffruit and fpart and teleport then
        M._collecting = true
        teleport.go(fpart.Position)
        M._fruitTries[ffruit] = (M._fruitTries[ffruit] or 0) + 1
        if M._fruitTries[ffruit] > 5 then M._fruitSkip[ffruit] = true end
        task.wait(0.5)
        return
    end
    M._collecting = false

    local list = M.aliveMobs(q.mob)
    local curr = {}
    for _, e in ipairs(list) do curr[e] = true end
    if M._prevAlive then
        for e in pairs(M._prevAlive) do if not curr[e] then M._killCount = M._killCount + 1 end end
    end
    M._prevAlive = curr
    if key ~= M._curKey then
        M._curKey, M._target, M._anchor = key, nil, nil
        M._killCount, M._killReq, M._prevAlive = 0, (q.kills or M.kills[q.mob] or 8), nil
        M.startQuest()
    elseif M._killCount >= M._killReq then
        M._killCount = 0
        M.startQuest()
    end

    local target = M.nearestMob(q.mob)
    if target and teleport and combat then
        if target ~= M._target then M._target = target end
        local part = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
        local h = hrp()
        if M.config.bring then
            if not M._anchor and part and h then
                if (part.Position - h.Position).Magnitude > M.config.hoverRange then
                    teleport.go(part.Position + Vector3.new(0, M.config.heightOffset, 0))
                else
                    M._anchor = part.Position
                    if teleport then teleport.cancel() end
                end
            end
        elseif part and h and (part.Position - h.Position).Magnitude > M.config.hoverRange then
            teleport.go(part.Position + Vector3.new(0, M.config.heightOffset, 0))
        end
        if M.config.equip then M.equipWeapon(M.config.equipType) end
        if M.config.bring then
            for _, e in ipairs(list) do combat.attackOnce(e) end
        else
            combat.attackOnce(target)
        end
        if combat.config.targetPlayers then combat.attackPlayersInRange(combat.config.playerRange) end
        task.wait(M.config.attackInterval)
    elseif M.config.bring and M._anchor then
        task.wait(1)
    else
        local sp, h = M.spawns[q.mob], hrp()
        if sp and teleport and h then
            local dist = (h.Position - sp).Magnitude
            if dist > 150 then
                teleport.go(sp + Vector3.new(0, M.config.heightOffset, 0))
                -- wait the actual fly time (distance / speed) + buffer, so we attack only once arrived
                task.wait(math.clamp(dist / ((teleport.config and teleport.config.speed) or 100), 0.3, 90) + 0.4)
            else
                task.wait(1.2)
            end
        else
            M.warnEnemies(q.mob)
            task.wait(M.config.attackInterval)
        end
    end
end

-- _farmGen versions the loop: a restart bumps the gen so any stale loop exits on its next check.
function M._runFarmLoop()
    local gen = M._farmGen
    M._core.spawn(function()
        local combat, teleport = M._core.modules.combat, M._core.modules.teleport
        if combat and combat.setupHitId then combat.setupHitId() end   -- re-equip weapon -> register a valid hitId
        while M._farmOn and M._farmGen == gen do
            M._lastTick = os.clock()
            local ok, err = pcall(M._farmStep, combat, teleport)
            if not ok and M._core then M._core.warn("farm step:", tostring(err)); task.wait(0.3) end
        end
    end)
end

function M.startWatchdog()
    if M._watchdogOn then return end
    M._watchdogOn = true
    M._core.spawn(function()
        while M._farmOn do
            if M._lastTick and (os.clock() - M._lastTick) > 4 then
                if M._core then M._core.warn("farm watchdog: restarting loop") end
                M._farmGen = (M._farmGen or 0) + 1
                M._lastTick = os.clock()
                M._runFarmLoop()
            end
            task.wait(2)
        end
        M._watchdogOn = false
    end)
end

function M.setFarm(on)
    M._farmOn = on
    if on then M._bossOn, M._nearestOn = false, false end
    if not M._core then return end
    M._curKey, M._target, M._collecting, M._anchor = nil, nil, false, nil
    M._killCount, M._killReq, M._prevAlive = 0, 8, nil
    M._fruitSkip = setmetatable({}, { __mode = "k" })
    M._fruitTries = setmetatable({}, { __mode = "k" })
    M._decollided = setmetatable({}, { __mode = "k" })
    if on and not M.selected and M._ui then M._ui.notify("Auto quest: " .. M.bestForLevel().label) end
    if on then
        M._farmGen = (M._farmGen or 0) + 1
        M._lastTick = os.clock()
        M._runFarmLoop()
        M.startWatchdog()
    end
    M._core.info("level farm", on and "ON" or "OFF")
end

function M.setNearestFarm(on)
    M._nearestOn = on
    if on then M._farmOn, M._bossOn = false, false end
    if not (on and M._core) then return end
    M._mobName, M._anchor, M._target = nil, nil, nil
    M._core.spawn(function()
        local combat, teleport = M._core.modules.combat, M._core.modules.teleport
        if combat and combat.setupHitId then combat.setupHitId() end
        while M._nearestOn do
            local target = combat and combat.nearest(1e9)
            if target and teleport and combat then
                M._target = target
                local part = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                local h = hrp()
                if part and h and (part.Position - h.Position).Magnitude > M.config.hoverRange then
                    teleport.go(part.Position + Vector3.new(0, M.config.heightOffset, 0))
                end
                if M.config.equip then M.equipWeapon(M.config.equipType) end
                combat.attackOnce(target)
                if combat.config.targetPlayers then combat.attackPlayersInRange(combat.config.playerRange) end
            else
                M._target = nil
            end
            task.wait(M.config.attackInterval)
        end
    end)
    M._core.info("nearest farm", on and "ON" or "OFF")
end

function M.setBossFarm(on)
    M._bossOn = on
    if on then M._farmOn, M._nearestOn = false, false end
    if not (on and M._core) then return end
    M._target = nil
    M._core.spawn(function()
        local combat, teleport = M._core.modules.combat, M._core.modules.teleport
        if combat and combat.setupHitId then combat.setupHitId() end
        while M._bossOn do
            local b = M.selectedBoss
            if not b then task.wait(1) else
                local target = M.nearestMob(b.name)
                if target then
                    M._target = target
                    local part = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                    local h = hrp()
                    if part and h and teleport and (part.Position - h.Position).Magnitude > M.config.hoverRange then
                        teleport.go(part.Position + Vector3.new(0, M.config.heightOffset, 0))
                    end
                    if M.config.equip then M.equipWeapon(M.config.equipType) end
                    if combat then
                        combat.attackOnce(target)
                        if combat.config.targetPlayers then combat.attackPlayersInRange(combat.config.playerRange) end
                    end
                    task.wait(M.config.attackInterval)
                else
                    M._target = nil
                    if teleport and b.pos then teleport.go(b.pos + Vector3.new(0, M.config.heightOffset, 0)) end
                    task.wait(2)
                end
            end
        end
    end)
    M._core.info("boss farm", on and ("ON " .. (M.selectedBoss and M.selectedBoss.name or "")) or "OFF")
end

local function entryByMob(list, mob)
    for _, q in ipairs(list) do if q.mob == mob then return q end end
end

function M.setMaterialFarm(on)
    if on then
        local list = M.currentList()
        local src = M._matMob or (list[1] and list[1].mob)
        local q = src and entryByMob(list, src)
        if not q then if M._ui then M._ui.notify("Pick a material first") end return end
        M.selected, M._curKey = q, nil
        if M._ui then M._ui.notify("Material farm: " .. src) end
    end
    M.setFarm(on)
end

function M.setAutoNextIsland(on)
    if on then M.selected, M._curKey = nil, nil end
    M.setFarm(on)
end

function M.stop()
    M._statAuto, M._farmOn, M._bossOn, M._nearestOn = false, false, false, false
    local h = hrp()
    if h and h.Anchored then h.Anchored = false end
end

function M.init(Core, UI)
    M._core, M._ui = Core, UI

    Core.track(RunService.RenderStepped:Connect(function()
        if not (M._farmOn or M._bossOn or M._nearestOn) then return end
        local h = hrp()
        if not h then return end
        if h.Anchored then h.Anchored = false end
        h.AssemblyLinearVelocity = Vector3.zero
        if M._collecting then return end

        if M.config.bring and M._anchor then
            h.CFrame = CFrame.new(M._anchor + Vector3.new(0, M.config.heightOffset, 0))
            h.AssemblyLinearVelocity = Vector3.zero
            if M._mobName then
                local folder = workspace:FindFirstChild("Enemies")
                if folder then
                    for _, e in ipairs(folder:GetChildren()) do
                        if e.Name:lower() == M._mobName:lower() then
                            local hum = e:FindFirstChildOfClass("Humanoid")
                            local ep = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                            if hum and hum.Health > 0 and ep then
                                if not M._decollided[e] then
                                    for _, bp in ipairs(e:GetDescendants()) do
                                        if bp:IsA("BasePart") then bp.CanCollide = false end
                                    end
                                    M._decollided[e] = true
                                end
                                ep.CFrame = CFrame.new(M._anchor)
                                ep.AssemblyLinearVelocity = Vector3.zero
                            end
                        end
                    end
                end
            end
        else
            local t = M._target
            local part = t and (t:FindFirstChild("HumanoidRootPart") or t.PrimaryPart)
            if part and (part.Position - h.Position).Magnitude < M.config.hoverRange then
                h.CFrame = CFrame.new(part.Position + Vector3.new(0, M.config.heightOffset, 0))
                h.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end))

    local combat = Core.modules.combat

    local function buildFarm(page, mobs, bosses, saber, materials)
        UI.toggle(page, "Auto level farm", "Quest + move to quest mob + attack", false, function(s) M.setFarm(s) end)
        UI.toggle(page, "Farm Nearest", "Farm the nearest mob (any type, no quest)", false, function(s) M.setNearestFarm(s) end)
        if materials then
            UI.toggle(page, "Auto Next Island", "Auto-progress: farm the mob matching your level", false, function(s) M.setAutoNextIsland(s) end)
        end
        local labels = { "Auto (by level)" }
        for _, q in ipairs(mobs) do labels[#labels + 1] = q.label end
        UI.dropdown(page, "Quest", "Target mob (Auto = by your level)", labels, function(sel)
            if sel == "Auto (by level)" then M.selected = nil
            else for _, q in ipairs(mobs) do if q.label == sel then M.selected = q; break end end end
            M._curKey = nil
        end)
        UI.slider(page, "Height offset", "Studs above the mob", 0, 40, M.config.heightOffset, function(v) M.config.heightOffset = v end)
        -- "Approach distance" is hoverRange: the loop only flies to the mob when it
        -- is farther than this, otherwise it attacks in place. Larger = lazier
        -- movement (fewer trips, wider leash); smaller = hugs the target.
        UI.slider(page, "Approach distance", "Fly to the mob only when farther than this", 30, 600, M.config.hoverRange, function(v) M.config.hoverRange = v end)
        UI.toggle(page, "Bring mob", "Stack mobs on one spot under you", false, function(s) M.config.bring = s end)

        UI.toggle(page, "Auto attack (mobs)", "Attack the nearest mob (standalone)", false, function(s)
            if combat then combat.setMobAuto(s) end
        end)
        UI.slider(page, "Attack range", "Mob detection radius", 1, 300, combat and combat.config.range or 120, function(v)
            if combat then combat.config.range = v end
        end)
        -- attackInterval drives every wait between attacks in the farm loops.
        UI.slider(page, "Attack interval", "Seconds between attacks (lower = faster)", 0.05, 2, M.config.attackInterval, function(v) M.config.attackInterval = v end)

        UI.dropdown(page, "Auto equip", "Weapon to equip while farming", { "Melee", "Sword", "Gun", "Fruit" }, function(s) M.config.equipType = s end)
        UI.toggle(page, "Auto equip on", "Equip the chosen weapon to farm with", false, function(s) M.config.equip = s end)

        UI.section(page, "BOSS")
        local bl = {}
        for _, b in ipairs(bosses) do bl[#bl + 1] = ("%s (Lv %d)"):format(b.name, b.level) end
        UI.dropdown(page, "Boss", "Boss to farm (long respawn)", bl, function(sel)
            for _, b in ipairs(bosses) do if ("%s (Lv %d)"):format(b.name, b.level) == sel then M.selectedBoss = b; break end end
        end)
        UI.toggle(page, "Farm Boss", "Go to the boss and kill it on respawn", false, function(s) M.setBossFarm(s) end)
        if saber then
            UI.toggle(page, "Auto Saber", "Farm the Saber Expert to unlock the Saber", false, function(s)
                if s then for _, b in ipairs(bosses) do if b.name == "Saber Expert" then M.selectedBoss = b; break end end end
                M.setBossFarm(s)
            end)
        end

        if materials then
            UI.section(page, "MATERIALS")
            local mlabels = {}
            for _, m in ipairs(materials) do mlabels[#mlabels + 1] = m.mat .. "  (" .. m.mob .. ")" end
            UI.dropdown(page, "Material", "Material to farm (its source mob)", mlabels, function(sel)
                for _, m in ipairs(materials) do if (m.mat .. "  (" .. m.mob .. ")") == sel then M._matMob = m.mob; break end end
            end)
            UI.toggle(page, "Material Farm", "Farm the source mob of the selected material", false, function(s) M.setMaterialFarm(s) end)
        end

        UI.section(page, "STATS")
        UI.dropdown(page, "Stat", "Stat to level up", M.stats, function(s) M.config.stat = s end)
        UI.slider(page, "Amount", "Points per add", 1, 100, M.config.statAmount, function(v) M.config.statAmount = v end)
        UI.toggle(page, "Auto add points", "Spend points continuously", false, function(s) M.setStatAuto(s) end)
    end

    buildFarm(UI.page("Farm"), M.sea1, M.bosses, true, nil)
    buildFarm(UI.page("Farm 2"), M.sea2, M.bosses2, false, M.sea2materials)
    buildFarm(UI.page("Farm 3"), M.sea3, M.bosses3, false, M.sea3materials)

    Core.register("farm", M)
    return M
end

return M

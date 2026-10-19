-- Blox Fruits quest/mob reference data.
--
-- Pure data: level band -> monster name + a spawn CFrame used as a teleport
-- anchor. Extracted from commonly distributed 2025 quest tables. This is a
-- FALLBACK source only; the live monster folder (Workspace.Enemies) is always
-- preferred, and the active quest is queried from the game. If the game shifts
-- monster spawns these coordinates drift, which is why they are data and not
-- logic. All coordinates are World 1 unless the band belongs to World 2/3.

local Quests = {}

-- Each world is a list of {min, max, monster, spawn = {x, y, z}}.
Quests.Worlds = {
    [1] = {
        {1, 9, "Bandit", {1045.96, 27.00, 1560.82}},
        {10, 14, "Monkey", {-1448.51, 67.85, 11.46}},
        {15, 29, "Gorilla", {-1129.88, 40.46, -525.42}},
        {30, 39, "Pirate", {-1103.51, 13.75, 3896.09}},
        {40, 59, "Brute", {-1140.08, 14.80, 4322.92}},
        {60, 74, "Desert Bandit", {924.79, 6.44, 4481.58}},
        {75, 89, "Desert Officer", {1608.28, 8.61, 4371.00}},
        {90, 99, "Snow Bandit", {1354.34, 87.27, -1393.94}},
        {100, 119, "Snowman", {1201.64, 144.57, -1550.06}},
        {120, 149, "Chief Petty Officer", {-4881.23, 22.65, 4273.75}},
        {150, 174, "Sky Bandit", {-4953.20, 295.74, -2899.22}},
        {175, 189, "Dark Master", {-5259.84, 391.39, -2229.03}},
        {190, 209, "Prisoner", {5098.97, -0.32, 474.23}},
        {210, 249, "Dangerous Prisoner", {5654.56, 15.63, 866.29}},
        {250, 274, "Toga Warrior", {-1820.21, 51.68, -2740.66}},
        {275, 299, "Gladiator", {-1292.83, 56.38, -3339.03}},
        {300, 324, "Military Soldier", {-5411.16, 11.08, 8454.29}},
        {325, 374, "Military Spy", {-5802.86, 86.26, 8828.85}},
        {375, 399, "Fishman Warrior", {60878.30, 18.48, 1543.75}},
        {400, 449, "Fishman Commando", {61922.63, 18.48, 1493.93}},
        {450, 474, "God's Guard", {-4710.04, 845.27, -1927.30}},
        {475, 524, "Shanda", {-7678.48, 5566.40, -497.21}},
        {525, 549, "Royal Squad", {-7624.25, 5658.13, -1467.35}},
        {550, 624, "Royal Soldier", {-7836.75, 5645.66, -1790.62}},
        {625, 649, "Galley Pirate", {5551.02, 78.90, 3930.41}},
        {650, 699, "Galley Captain", {5441.95, 42.50, 4950.09}},
    },
    [2] = {
        {700, 724, "Raider", {-728.32, 52.77, 2345.77}},
        {725, 774, "Mercenary", {-1004.32, 80.15, 1424.61}},
        {775, 799, "Swan Pirate", {1068.66, 137.61, 1322.10}},
        {800, 874, "Factory Staff", {73.07, 81.86, -27.47}},
        {875, 899, "Marine Lieutenant", {-2821.37, 75.89, -3070.08}},
        {900, 949, "Marine Captain", {-1861.23, 80.17, -3254.69}},
        {950, 974, "Zombie", {-5657.77, 78.96, -928.68}},
        {975, 999, "Vampire", {-6037.66, 32.18, -1340.65}},
        {1000, 1049, "Snow Trooper", {549.14, 427.38, -5563.69}},
        {1050, 1099, "Winter Warrior", {1142.74, 475.63, -5199.41}},
        {1100, 1124, "Lab Subordinate", {-5707.47, 15.95, -4513.39}},
        {1125, 1174, "Horned Warrior", {-6341.36, 15.95, -5723.16}},
        {1175, 1199, "Magma Ninja", {-5449.67, 76.65, -5808.20}},
        {1200, 1249, "Lava Pirate", {-5213.33, 49.73, -4701.45}},
        {1250, 1274, "Ship Deckhand", {1212.01, 150.79, 33059.24}},
        {1275, 1299, "Ship Engineer", {919.47, 43.54, 32779.96}},
        {1300, 1324, "Ship Steward", {919.43, 129.55, 33436.03}},
        {1325, 1349, "Ship Officer", {1036.01, 181.43, 33315.72}},
        {1350, 1374, "Arctic Warrior", {5966.24, 62.97, -6179.38}},
        {1375, 1424, "Snow Lurker", {5407.07, 69.19, -6880.88}},
        {1425, 1449, "Sea Soldier", {-3028.22, 64.67, -9775.42}},
        {1450, 1499, "Water Fighter", {-3352.90, 285.01, -10534.84}},
    },
    [3] = {
        {1500, 1524, "Pirate Millionaire", {-245.99, 47.30, 5584.10}},
        {1525, 1574, "Pistol Billionaire", {-187.33, 86.23, 6013.51}},
        {1575, 1599, "Dragon Crew Warrior", {6141.14, 51.35, -1340.73}},
        {1600, 1624, "Dragon Crew Archer", {6616.41, 441.76, 446.04}},
        {1625, 1649, "Female Islander", {4685.25, 735.80, 815.34}},
        {1650, 1699, "Giant Islander", {4729.09, 590.43, -36.97}},
        {1700, 1724, "Marine Commodore", {2286.00, 73.13, -7159.80}},
        {1725, 1774, "Marine Rear Admiral", {3656.77, 160.52, -7001.59}},
        {1775, 1799, "Fishman Raider", {-10407.52, 331.76, -8368.51}},
        {1800, 1824, "Fishman Captain", {-10994.70, 352.38, -9002.11}},
        {1825, 1849, "Forest Pirate", {-13274.47, 332.37, -7769.58}},
        {1850, 1899, "Mythological Pirate", {-13680.60, 501.08, -6991.18}},
        {1900, 1924, "Jungle Pirate", {-12256.16, 331.73, -10485.83}},
        {1925, 1974, "Musketeer Pirate", {-13457.90, 391.54, -9859.17}},
        {1975, 1999, "Reborn Skeleton", {-8763.72, 165.72, 6159.86}},
        {2000, 2024, "Living Zombie", {-10144.13, 138.62, 5838.08}},
        {2025, 2049, "Demonic Soul", {-9505.87, 172.10, 6158.99}},
        {2050, 2074, "Posessed Mummy", {-9582.02, 6.25, 6205.47}},
        {2075, 2099, "Peanut Scout", {-2143.24, 47.72, -10029.99}},
        {2100, 2124, "Peanut President", {-1859.35, 38.10, -10422.42}},
        {2125, 2149, "Ice Cream Chef", {-872.24, 65.81, -10919.95}},
        {2150, 2199, "Ice Cream Commander", {-558.06, 112.04, -11290.77}},
        {2200, 2224, "Cookie Crafter", {-2374.13, 37.79, -12125.30}},
        {2225, 2249, "Cake Guard", {-1598.30, 43.77, -12244.58}},
        {2250, 2274, "Baking Staff", {-1887.80, 77.61, -12998.35}},
        {2275, 2299, "Head Baker", {-2216.18, 82.88, -12869.29}},
        {2300, 2324, "Cocoa Warrior", {-21.55, 80.57, -12352.38}},
        {2325, 2349, "Chocolate Bar Battler", {582.59, 77.18, -12463.16}},
        {2350, 2374, "Sweet Thief", {165.18, 76.05, -12600.83}},
        {2375, 2399, "Candy Rebel", {134.86, 77.24, -12876.54}},
        {2400, 2424, "Candy Pirate", {-1310.50, 26.01, -14562.40}},
        {2425, 2449, "Snow Demon", {-880.20, 71.24, -14538.60}},
        {2450, 2474, "Isle Outlaw", {-16442.81, 116.13, -264.46}},
        {2475, 2524, "Island Boy", {-16901.26, 84.06, -192.88}},
        {2525, 2549, "Isle Champion", {-16641.67, 235.78, 1031.28}},
        {2550, 2574, "Serpent Hunter", {-16587.89, 154.21, 1533.40}},
        {2575, 9999, "Skull Slayer", {-16885.20, 114.12, 1627.94}},
    },
}

-- PlaceId -> world number.
Quests.PlaceWorld = {
    [2753915549] = 1,
    [4442272183] = 2,
    [7449423635] = 3,
}

function Quests.WorldFor(placeId)
    return Quests.PlaceWorld[tonumber(placeId)]
end

function Quests.For(placeId, level)
    local world = Quests.WorldFor(placeId)
    if not world then return nil end
    local band = tonumber(level)
    if not band then return nil end
    for _, entry in ipairs(Quests.Worlds[world]) do
        if band >= entry[1] and band <= entry[2] then
            return entry[3], entry[4], world
        end
    end
    return nil
end

-- Rarity groups for the fruit store/ESP filter. Names match the in-game tool
-- names ("<Fruit> Fruit"). Data only, taken from public 2025 fruit lists.
Quests.FruitRarity = {
    Common = {"Rocket", "Spin", "Chop", "Spring", "Bomb", "Smoke", "Spike", "Flame", "Falcon", "Ice"},
    Uncommon = {"Sand", "Dark", "Diamond", "Light", "Rubber", "Barrier", "Ghost", "Magma", "Quake", "Buddha"},
    Rare = {"Love", "Spider", "Sound", "Phoenix", "Portal", "Rumble", "Pain", "Blizzard", "Gravity", "Mammoth"},
    Legendary = {"T-Rex", "Dough", "Shadow", "Venom", "Control", "Spirit", "Dragon", "Leopard", "Kitsune"},
    Mythical = {"Yeti", "Gas", "Ice Dragon", "East Dragon", "West Dragon", "Kitsune"},
}

function Quests.RarityOf(fruitName)
    if type(fruitName) ~= "string" then return nil end
    local base = fruitName:gsub(" Fruit$", "")
    for rarity, list in pairs(Quests.FruitRarity) do
        for _, name in ipairs(list) do
            if name == base then return rarity end
        end
    end
    return nil
end

return Quests

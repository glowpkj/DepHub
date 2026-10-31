local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall
local pairs=pairs

local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
local STATE_KEY="__DEPHUB_MM2"
local BASE_URL=((type(getgenv)=="function" and getgenv() or _G).__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local VERSION="0.0.5"

local previous=type(env[STATE_KEY])=="table" and env[STATE_KEY] or nil
if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end

local function loadFeature(path,context)
    local cb=tostring((env.__DEPHUB or {}).SourceCacheBust or "")
    local okGet,source=pcall(function() return game:HttpGet(BASE_URL..path..(cb~="" and ("?cb="..cb) or "")) end)
    if not okGet or type(source)~="string" or #source==0 then return false,tostring(source) end
    local okCompile,chunk,err=pcall(loadstring,source)
    if not okCompile or type(chunk)~="function" then return false,tostring(err or chunk) end
    local okRun,factory=pcall(chunk)
    if not okRun or type(factory)~="table" or type(factory.new)~="function" then return false,tostring(factory) end
    local okNew,feature=pcall(factory.new,context)
    if not okNew or type(feature)~="table" then return false,tostring(feature) end
    return true,feature
end

local base={Players=Players,Workspace=Workspace,LocalPlayer=LocalPlayer}
local okRole,RoleTracker=loadFeature("src/games/features/mm2/roletracker.lua",base)
if not okRole then return false end
base.RoleTracker=RoleTracker
local okRound,RoundTracker=loadFeature("src/games/features/mm2/roundtracker.lua",base)
if not okRound then pcall(RoleTracker.Destroy,RoleTracker) return false end
base.RoundTracker=RoundTracker
local okESP,ESP=loadFeature("src/games/features/mm2/esp.lua",base)
if not okESP then pcall(RoleTracker.Destroy,RoleTracker) pcall(RoundTracker.Destroy,RoundTracker) return false end
local okCoin,CoinFarm=loadFeature("src/games/features/mm2/coinfarm.lua",base)
if not okCoin then pcall(RoleTracker.Destroy,RoleTracker) pcall(RoundTracker.Destroy,RoundTracker) pcall(ESP.Destroy,ESP) return false end
local okTeleport,PlayerTeleport=loadFeature("src/games/features/mm2/playerteleport.lua",base)
if not okTeleport then pcall(RoleTracker.Destroy,RoleTracker) pcall(RoundTracker.Destroy,RoundTracker) pcall(ESP.Destroy,ESP) pcall(CoinFarm.Destroy,CoinFarm) return false end
local okGun,GunDrop=loadFeature("src/games/features/mm2/gundrop.lua",base)
if not okGun then pcall(RoleTracker.Destroy,RoleTracker) pcall(RoundTracker.Destroy,RoundTracker) pcall(ESP.Destroy,ESP) pcall(CoinFarm.Destroy,CoinFarm) pcall(PlayerTeleport.Destroy,PlayerTeleport) return false end

local State={
    Version=VERSION,
    Started=false,
    Destroyed=false,
    Features={RoleTracker=RoleTracker,RoundTracker=RoundTracker,ESP=ESP,CoinFarm=CoinFarm,PlayerTeleport=PlayerTeleport,GunDrop=GunDrop},
    Toggles={RoleESP=false,AutoCoins=false,GunDropESP=false,AutoGetGun=false},
    Values={CoinSafeDistance=18,CoinDelay=0.05,GunSafeDistance=22,GunPickupHold=0.16}
}

env[STATE_KEY]=State
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.MM2=State

function State:SetRoleESP(v)
    v=v==true
    self.Toggles.RoleESP=v
    return (v and ESP:Enable() or ESP:Disable())~=false
end

function State:SetAutoCoins(v)
    v=v==true
    self.Toggles.AutoCoins=v
    return (v and CoinFarm:Enable() or CoinFarm:Disable())~=false
end

function State:SetCoinSafeDistance(v)
    v=tonumber(v)
    if not v then return false end
    if not CoinFarm:SetSafeDistance(v) then return false end
    self.Values.CoinSafeDistance=CoinFarm.SafeDistance
    return true
end

function State:SetCoinDelay(v)
    v=tonumber(v)
    if not v then return false end
    if not CoinFarm:SetDelay(v) then return false end
    self.Values.CoinDelay=CoinFarm.Delay
    return true
end

function State:SetGunDropESP(v)
    v=v==true
    if GunDrop:SetESP(v)==false then return false end
    self.Toggles.GunDropESP=v
    return true
end

function State:SetAutoGetGun(v)
    v=v==true
    if GunDrop:SetAutoPickup(v)==false then return false end
    self.Toggles.AutoGetGun=v
    return true
end

function State:SetGunSafeDistance(v)
    v=tonumber(v)
    if not v or GunDrop:SetSafeDistance(v)==false then return false end
    self.Values.GunSafeDistance=GunDrop.SafeDistance
    return true
end

function State:SetGunPickupHold(v)
    v=tonumber(v)
    if not v or GunDrop:SetPickupHold(v)==false then return false end
    self.Values.GunPickupHold=GunDrop.PickupHold
    return true
end

function State:TeleportNextAlivePlayer()
    if self.Destroyed then return false,"destroyed" end
    return PlayerTeleport:TeleportNext()
end

function State:GetAlivePlayers() return PlayerTeleport:GetAliveTargets() end
function State:GetGunDrop() return RoleTracker:GetGunDrop() end
function State:GetToggle(name) return self.Toggles[name]==true end
function State:GetValue(name) return self.Values[name] end
function State:GetMurder() return RoleTracker:GetMurder() end
function State:GetSheriff() return RoleTracker:GetSheriff() end
function State:IsRoundActive() return RoundTracker:IsRoundActive() end
function State:GetDebugInfo()
    return {
        Role=RoleTracker:GetDebugInfo(),
        Round=RoundTracker:GetDebugInfo(),
        Coin=CoinFarm:GetDebugInfo(),
        Teleport=PlayerTeleport:GetDebugInfo(),
        Gun=GunDrop:GetDebugInfo()
    }
end

function State:Start()
    if self.Destroyed or self.Started then return false end
    self.Started=true
    RoleTracker:Enable()
    RoundTracker:Enable()
    self.RoundConnection=RoundTracker:OnChanged(function(active)
        if not active then RoleTracker:ResetRound() end
    end)
    return true
end

function State:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    if self.RoundConnection then pcall(self.RoundConnection.Disconnect,self.RoundConnection) self.RoundConnection=nil end
    for _,feature in pairs(self.Features or {}) do
        if type(feature)=="table" and type(feature.Destroy)=="function" then pcall(feature.Destroy,feature) end
    end
    self.Features=nil
    if env[STATE_KEY]==self then env[STATE_KEY]=nil end
    if env.__DEPHUB and env.__DEPHUB.MM2==self then env.__DEPHUB.MM2=nil end
end

if not LocalPlayer then return false end
if not State:Start() then State:Destroy() return false end

local UI=env.__DEPHUB and env.__DEPHUB.UI
do
    local Kit=env.__DEPHUB and env.__DEPHUB.UIKit
    if Kit then
        -- Roles are pure information on screen -> Visual.
        local roles=Kit.Section(Kit.Tab("Roles","Visual"),"Role ESP","Left")
        if roles then
            roles:CreateToggle("Show Murder and Sheriff",false,function(value)
                State:SetRoleESP(value)
            end)
            roles:CreateParagraph("Identification","Highlights the Murder in red and the Sheriff in blue.")
        end

        -- Coin collection is a farm loop -> Farm.
        local coins=Kit.Section(Kit.Tab("Coin Farm","Farm"),"Collect coins","Left")
        if coins then
            -- Auto collect + the distance it keeps share a line; the interval is
            -- its own row.
            local coinRow=Kit.Row(coins)
            if coinRow then
                coinRow:CreateToggle("Auto collect",false,function(value)
                    State:SetAutoCoins(value)
                end)
                coinRow:CreateSlider("Safe distance",0,80,State.Values.CoinSafeDistance,function(value)
                    State:SetCoinSafeDistance(value)
                end)
            else
                coins:CreateToggle("Auto collect",false,function(value)
                    State:SetAutoCoins(value)
                end)
                coins:CreateSlider("Safe distance",0,80,State.Values.CoinSafeDistance,function(value)
                    State:SetCoinSafeDistance(value)
                end)
            end
            coins:CreateSlider("Interval (seconds)",0.02,0.3,State.Values.CoinDelay,function(value)
                State:SetCoinDelay(value)
            end)
        end

        -- Gun drop is a farm action with a visual ESP bit -> Farm.
        local gun=Kit.Section(Kit.Tab("Gun Drop","Farm"),"Dropped gun","Left")
        if gun then
            -- The two gun switches share a line, then the two value sliders, which
            -- pair with the feature each drives.
            local gunRow=Kit.Row(gun)
            if gunRow then
                gunRow:CreateToggle("Gun ESP",false,function(value)
                    State:SetGunDropESP(value)
                end)
                gunRow:CreateToggle("Auto pickup gun",false,function(value)
                    State:SetAutoGetGun(value)
                end)
            else
                gun:CreateToggle("Gun ESP",false,function(value)
                    State:SetGunDropESP(value)
                end)
                gun:CreateToggle("Auto pickup gun",false,function(value)
                    State:SetAutoGetGun(value)
                end)
            end
            local gunSliderRow=Kit.Row(gun)
            if gunSliderRow then
                gunSliderRow:CreateSlider("Safe distance from Murder",5,80,State.Values.GunSafeDistance,function(value)
                    State:SetGunSafeDistance(value)
                end)
                gunSliderRow:CreateSlider("Pickup hold time",0.05,0.5,State.Values.GunPickupHold,function(value)
                    State:SetGunPickupHold(value)
                end)
            else
                gun:CreateSlider("Safe distance from Murder",5,80,State.Values.GunSafeDistance,function(value)
                    State:SetGunSafeDistance(value)
                end)
                gun:CreateSlider("Pickup hold time",0.05,0.5,State.Values.GunPickupHold,function(value)
                    State:SetGunPickupHold(value)
                end)
            end
        end

        -- Teleport-to-player is a movement/player action -> Movement.
        local players=Kit.Section(Kit.Tab("Players","Movement"),"Alive players","Left")
        if players then
            players:CreateButton("Teleport to next alive player",function()
                local ok,name=State:TeleportNextAlivePlayer()
                if type(UI.Notify)=="function" then
                    UI:Notify("MM2",ok and ("Teleported to "..tostring(name)) or tostring(name or "Could not teleport"),ok and "success" or "warning")
                end
            end)
            players:CreateParagraph("Status","Teleport cycles through the round's alive players.")
        end
    end
end

-- Report this backend's own structure and live state into the shared Debug tab.
-- Every probe names the exact instance a feature reads, so a game update that
-- renames or removes one shows up as [FALHA] at the point of failure.
do
    local Diag=env.__DEPHUB and env.__DEPHUB.Diagnostics
    if Diag and type(Diag.Probe)=="function" then
        Diag:SetEnvironment({["MM2 version"]=VERSION})
        for _,name in ipairs({"roletracker","roundtracker","esp","coinfarm","playerteleport","gundrop"}) do
            Diag:RegisterModule("features/mm2/"..name..".lua")
        end
        Diag:Module("features/mm2/roletracker.lua",RoleTracker~=nil,"loaded")
        Diag:Module("features/mm2/roundtracker.lua",RoundTracker~=nil,"loaded")
        Diag:Module("features/mm2/esp.lua",ESP~=nil,"loaded")
        Diag:Module("features/mm2/coinfarm.lua",CoinFarm~=nil,"loaded")
        Diag:Module("features/mm2/playerteleport.lua",PlayerTeleport~=nil,"loaded")
        Diag:Module("features/mm2/gundrop.lua",GunDrop~=nil,"loaded")
        -- Structure probes: the named objects the trackers resolve. A rename of
        -- any of these is exactly what silently kills a feature after an update.
        Diag:Probe("Players.LocalPlayer",LocalPlayer~=nil,LocalPlayer and LocalPlayer.Name or "absent")
        Diag:Probe("Workspace.RegularLobby",Workspace:FindFirstChild("RegularLobby")~=nil,
            Workspace:FindFirstChild("RegularLobby") and Workspace.RegularLobby.ClassName or "absent")
        local hasKnife,hasGun,hasDrop,hasCoins=false,false,false,false
        for _,object in ipairs(Workspace:GetDescendants()) do
            if object.Name=="GunDrop" then hasDrop=true end
            if object.Name=="CoinContainer" then hasCoins=true end
        end
        for _,player in ipairs(Players:GetPlayers()) do
            local character=player.Character
            local backpack=player:FindFirstChildOfClass("Backpack")
            if character and character:FindFirstChild("Knife",true) then hasKnife=true end
            if character and character:FindFirstChild("Gun",true) then hasGun=true end
            if backpack and backpack:FindFirstChild("Gun") then hasGun=true end
        end
        Diag:Probe("Tool.Knife",hasKnife,hasKnife and "seen on a player" or "not seen (no murder this round?)")
        Diag:Probe("Tool.Gun",hasGun,hasGun and "seen on a player" or "not seen (no sheriff this round?)")
        Diag:Probe("Workspace.GunDrop",hasDrop,hasDrop and "found" or "no active drop")
        Diag:Probe("Workspace.CoinContainer",hasCoins,hasCoins and "found" or "no container")
        -- Live feature state, read from the tracker debug tables the backend keeps.
        Diag:Feature("MM2.RoleESP",function() return State.Toggles.RoleESP and "ON" or "off" end)
        Diag:Feature("MM2.AutoCoins",function() return State.Toggles.AutoCoins and "ON" or "off" end)
        Diag:Feature("MM2.GunDropESP",function() return State.Toggles.GunDropESP and "ON" or "off" end)
        Diag:Feature("MM2.AutoGetGun",function() return State.Toggles.AutoGetGun and "ON" or "off" end)
        Diag:Feature("MM2.Roles",function()
            local info=RoleTracker:GetDebugInfo()
            return "murder="..tostring(info.Murder).." sheriff="..tostring(info.Sheriff).." scans="..tostring(info.Scans)
        end)
        Diag:Feature("MM2.Round",function()
            local info=RoundTracker:GetDebugInfo()
            return "active="..tostring(info.RoundActive).." alive="..tostring(info.AliveRoundPlayers).." lobby="..tostring(info.PlayersInLobby)
        end)
        Diag:Feature("MM2.CoinFarm",function()
            local info=CoinFarm:GetDebugInfo()
            return "coins="..tostring(info.Coins).." teleports="..tostring(info.Teleports).." paused="..tostring(info.Paused)
        end)
        Diag:Feature("MM2.GunDrop",function()
            local info=GunDrop:GetDebugInfo()
            return "drop="..tostring(info.GunDrop).." dist="..tostring(info.MurderDistance).." safe="..tostring(info.Safe)
        end)
        Diag:Feature("MM2.LastError",function()
            local parts={}
            for _,info in ipairs({RoleTracker:GetDebugInfo(),RoundTracker:GetDebugInfo(),CoinFarm:GetDebugInfo(),PlayerTeleport:GetDebugInfo(),GunDrop:GetDebugInfo()}) do
                if info.LastError and info.LastError~="none" then parts[#parts+1]=tostring(info.LastError) end
            end
            return #parts>0 and table.concat(parts," | ") or "none"
        end)
        if type(Diag.Watch)=="function" then
            Diag:Watch("MM2 murder",function() local info=RoleTracker:GetDebugInfo() return tostring(info.Murder) end)
            Diag:Watch("MM2 round active",function() return tostring(RoundTracker:GetDebugInfo().RoundActive) end)
            Diag:Watch("MM2 coins",function() return tostring(CoinFarm:GetDebugInfo().Coins) end)
            Diag:Watch("MM2 gun drop",function() return tostring(GunDrop:GetDebugInfo().GunDrop) end)
        end
        if type(Diag.Command)=="function" then
            Diag:Command("mm2",function()
                local role=RoleTracker:GetDebugInfo()
                local round=RoundTracker:GetDebugInfo()
                local coin=CoinFarm:GetDebugInfo()
                local gun=GunDrop:GetDebugInfo()
                return "murder="..tostring(role.Murder).." sheriff="..tostring(role.Sheriff)
                    .." roundActive="..tostring(round.RoundActive).." alive="..tostring(round.AliveRoundPlayers)
                    .." coins="..tostring(coin.Coins).." drop="..tostring(gun.GunDrop)
            end)
            Diag:Command("mm2-roleesp",function(argument)
                local on=argument~="off"
                State:SetRoleESP(on)
                return "RoleESP="..tostring(on)
            end)
        end
    end
end

return State


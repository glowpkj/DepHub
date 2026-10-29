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
    local okGet,source=pcall(function() return game:HttpGet(BASE_URL..path) end)
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
if type(UI)=="table" and type(UI.CreateTab)=="function" then
    local function createSection(tabName,sectionName,column)
        local tab=UI:CreateTab(tabName,"All")
        if not tab then return nil end
        return tab:CreateSection(sectionName,column)
    end

    local roles=createSection("Roles","Role ESP","Left")
    if roles then
        roles:CreateToggle("Mostrar Murder e Sheriff",false,function(value)
            State:SetRoleESP(value)
        end)
        roles:CreateParagraph("Identificação","Destaca o Murder em vermelho e o Sheriff em azul.")
    end

    local coins=createSection("Coin Farm","Coletar moedas","Left")
    if coins then
        coins:CreateToggle("Coleta automática",false,function(value)
            State:SetAutoCoins(value)
        end)
        coins:CreateSlider("Distância de segurança",0,80,State.Values.CoinSafeDistance,function(value)
            State:SetCoinSafeDistance(value)
        end)
        coins:CreateSlider("Intervalo (segundos)",0.02,0.3,State.Values.CoinDelay,function(value)
            State:SetCoinDelay(value)
        end)
    end

    local gun=createSection("Gun Drop","Pistola caída","Left")
    if gun then
        gun:CreateToggle("ESP da pistola",false,function(value)
            State:SetGunDropESP(value)
        end)
        gun:CreateToggle("Pegar pistola automaticamente",false,function(value)
            State:SetAutoGetGun(value)
        end)
        gun:CreateSlider("Distância segura do Murder",5,80,State.Values.GunSafeDistance,function(value)
            State:SetGunSafeDistance(value)
        end)
        gun:CreateSlider("Tempo de coleta",0.05,0.5,State.Values.GunPickupHold,function(value)
            State:SetGunPickupHold(value)
        end)
    end

    local players=createSection("Players","Jogadores vivos","Left")
    if players then
        players:CreateButton("Teleportar para próximo jogador vivo",function()
            local ok,name=State:TeleportNextAlivePlayer()
            if type(UI.Notify)=="function" then
                UI:Notify("MM2",ok and ("Teleportado para "..tostring(name)) or tostring(name or "Não foi possível teleportar"),ok and "success" or "warning")
            end
        end)
        players:CreateParagraph("Status","O teleporte percorre os jogadores vivos da rodada.")
    end
end

return State


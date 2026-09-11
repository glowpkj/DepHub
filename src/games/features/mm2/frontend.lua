local game=game
local type=type
local tostring=tostring
local pcall=pcall

local RunService=game:GetService("RunService")
local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local previous=env.__DEPHUB_MM2_FRONTEND
if type(previous)=="table" and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end

local Backend=env.__DEPHUB and env.__DEPHUB.MM2
if type(Backend)~="table" then return false end

local okSource,source=pcall(function() return game:HttpGet(BASE_URL.."library/compact.lua") end)
if not okSource or type(source)~="string" or #source==0 then return false end
local okCompile,chunk=pcall(loadstring,source)
if not okCompile or type(chunk)~="function" then return false end
local okLibrary,Library=pcall(chunk)
if not okLibrary or type(Library)~="table" or type(Library.new)~="function" then return false end

local UI=Library.new({
    Id="MM2",
    Title="DEPHUB",
    Subtitle="MURDER MYSTERY 2",
    Accent=Color3.fromRGB(111,238,190),
    Width=290,
    Height=430,
    Open=true
})
if type(UI)~="table" then return false end

UI:AddSection("ROLES")
UI:AddToggle("Role ESP",Backend:GetToggle("RoleESP"),function(v)
    return Backend:SetRoleESP(v)
end)

UI:AddSection("FARM")
local autoCoins,coinSettings=UI:AddFeature("Auto Coins",Backend:GetToggle("AutoCoins"),function(v)
    return Backend:SetAutoCoins(v)
end)
UI:AddSlider("Coin Delay",0.02,0.20,0.01,Backend:GetValue("CoinDelay") or 0.05,function(v)
    return Backend:SetCoinDelay(v)
end,coinSettings)
UI:AddSlider("Murder Safe Distance",0,60,1,Backend:GetValue("CoinSafeDistance") or 18,function(v)
    return Backend:SetCoinSafeDistance(v)
end,coinSettings)

UI:AddSection("PLAYERS")
UI:AddButton("TELEPORT NEXT ALIVE",function()
    local ok,name=Backend:TeleportNextAlivePlayer()
    if ok then return "TO: "..tostring(name) end
    return tostring(name or "NO TARGET")
end)

UI:AddSection("STATUS")
local Status=UI:AddStatus("LIVE STATUS",nil,124)
local alive=true
local elapsed=0
local statusConnection
statusConnection=RunService.Heartbeat:Connect(function(dt)
    if not alive or UI.Destroyed then return end
    elapsed=elapsed+dt
    if elapsed<0.25 then return end
    elapsed=0
    local info=Backend:GetDebugInfo()
    local murder=Backend:GetMurder()
    local sheriff=Backend:GetSheriff()
    local coin=info and info.Coin or {}
    local round=info and info.Round or {}
    local teleport=info and info.Teleport or {}
    Status:Set(
        "round: "..(Backend:IsRoundActive() and "active" or "lobby")..
        "\nmurder: "..(murder and murder.Name or "none")..
        "\nsheriff: "..(sheriff and sheriff.Name or "none")..
        "\nalive targets: "..tostring(round.AliveRoundPlayers or 0)..
        "\ncoins: "..tostring(coin.Coins or 0).." | farm tp: "..tostring(coin.Teleports or 0)..
        "\nlast player: "..tostring(teleport.LastTarget or "none")
    )
end)

local baseDestroy=UI.Destroy
function UI:Destroy()
    if self.Destroyed then return end
    alive=false
    if statusConnection then pcall(statusConnection.Disconnect,statusConnection) statusConnection=nil end
    pcall(baseDestroy,self)
    if env.__DEPHUB_MM2_FRONTEND==self then env.__DEPHUB_MM2_FRONTEND=nil end
    if env.__DEPHUB and env.__DEPHUB.MM2UI==self then env.__DEPHUB.MM2UI=nil end
end

env.__DEPHUB_MM2_FRONTEND=UI
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.MM2UI=UI
return UI

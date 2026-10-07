local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall

local env=type(getgenv)=="function" and getgenv() or _G
local BASE_URL=((type(getgenv)=="function" and getgenv() or _G).__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"

local previous=env.__DEPHUB_TSB_FRONTEND
if type(previous)=="table" and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end
local Backend=env.__DEPHUB and env.__DEPHUB.TSB
if type(Backend)~="table" then return false end

local okSource,source=pcall(function() return game:HttpGet(BASE_URL.."library/compact.lua") end)
if not okSource or type(source)~="string" or #source==0 then return false end
local okCompile,chunk=pcall(loadstring,source)
if not okCompile or type(chunk)~="function" then return false end
local okLibrary,Library=pcall(chunk)
if not okLibrary or type(Library)~="table" or type(Library.new)~="function" then return false end

local UI=Library.new({Id="TSB",Title="DEPHUB",Subtitle="THE STRONGEST BATTLEGROUNDS",Accent=Color3.fromRGB(111,238,190),Width=292,Height=180,Open=true})
if type(UI)~="table" then return false end

UI:AddToggle("Auto Block",Backend:GetToggle("AutoBlock"),function(value) return Backend:SetAutoBlock(value) end)

local baseDestroy=UI.Destroy
function UI:Destroy()
    if self.Destroyed then return end
    pcall(baseDestroy,self)
    if env.__DEPHUB_TSB_FRONTEND==self then env.__DEPHUB_TSB_FRONTEND=nil end
    if env.__DEPHUB and env.__DEPHUB.TSBUI==self then env.__DEPHUB.TSBUI=nil end
end

env.__DEPHUB_TSB_FRONTEND=UI
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.TSBUI=UI
return UI


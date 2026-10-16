local env=type(getgenv)=="function" and getgenv() or _G
local base=(env.__DEPHUB or {}).SourceBaseURL or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local function load(path)
    local chunk,err=loadstring(game:HttpGet(base..path.."?ui=0.1.0"));assert(chunk,err)
    return chunk()
end
local Adapter=load("src/frontend/linoria.lua")
local Main={}
function Main.new(options)
    local mode=options.Mode or "Universal"
    local paths={Universal="universal",BloxFruits="bloxfruits",RT3="rt3",NoobPiece="noobpiece"}
    assert(paths[mode],"Unknown frontend mode: "..tostring(mode))
    local window=Adapter.new(options)
    local ok,err=pcall(function()
        local common=load("src/frontend/games/common.lua")
        load("src/frontend/games/"..paths[mode]..".lua").mount(window,options.Backend,common)
        common.mount(window,options.Backend,env)
        window:OpenPage(window.FirstPage)
    end)
    if not ok then window:Destroy();error(err) end
    env.__DEPHUB_FRONTEND=window
    env.__DEPHUB=env.__DEPHUB or {};env.__DEPHUB.Frontend=window
    return window
end
return Main

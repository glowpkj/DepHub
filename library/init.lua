local environment = type(getgenv)=="function" and getgenv() or _G
local BASE_URL="https://raw.githubusercontent.com/glowpkj/DepHub/main/"
local cache=environment.__DEPHUB_LIBRARY_CACHE
if type(cache)~="table" then cache={}; environment.__DEPHUB_LIBRARY_CACHE=cache end
local requestNonce=tostring(math.floor(os.clock()*1000000))

local function loadModule(path)
    if cache[path]~=nil then return cache[path] end
    local okSource,source=pcall(function() return game:HttpGet(BASE_URL..path.."?library="..requestNonce) end)
    if not okSource or type(source)~="string" or source=="" then error("Falha baixando "..path..": "..tostring(source)) end
    if type(loadstring)~="function" then error("loadstring indisponível") end
    local okCompile,chunk,compileError=pcall(loadstring,source)
    if not okCompile or type(chunk)~="function" then error("Falha compilando "..path..": "..tostring(compileError or chunk)) end
    local okRun,module=pcall(chunk)
    if not okRun then error("Falha executando "..path..": "..tostring(module)) end
    cache[path]=module
    return module
end

local Theme=loadModule("library/theme.lua")
local Utils=loadModule("library/utils.lua")
local Components=loadModule("library/components.lua")
local Window=loadModule("library/window.lua")
local Common=loadModule("library/content/common.lua")
local contents={
    Universal="library/content/universal.lua",
    BloxFruits="library/content/bloxfruits.lua",
    RT3="library/content/rt3.lua"
}

local Library={Theme=Theme,Version="1.0.0"}

function Library.new(options)
    options=options or {}
    local previous=environment.__DEPHUB_FRONTEND
    if type(previous)=="table" and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end
    environment.__DEPHUB_FRONTEND=nil
    local mode=options.Mode or "Universal"
    local contentPath=contents[mode]
    if not contentPath then error("Modo de conteúdo inválido: "..tostring(mode)) end
    local window=Window.new({Theme=Theme,Utils=Utils,Components=Components},{
        Title=options.Title or "DEPHUB",Subtitle=options.Subtitle or mode,Backend=options.Backend,Environment=environment
    })
    local ok,reason=pcall(function()
        loadModule(contentPath).mount(window,options.Backend,Common)
        Common.mount(window,options.Backend,environment)
    end)
    if not ok then window:Destroy(); error(reason) end
    environment.__DEPHUB_FRONTEND=window
    environment.__DEPHUB=environment.__DEPHUB or {}
    environment.__DEPHUB.Frontend=window
    return window
end

function Library.clearCache()
    environment.__DEPHUB_LIBRARY_CACHE={}
    cache=environment.__DEPHUB_LIBRARY_CACHE
end

return Library

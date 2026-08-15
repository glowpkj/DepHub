local game = game
local type = type
local tostring = tostring
local pcall = pcall
local math_floor = math.floor

local env = type(getgenv) == "function" and getgenv() or _G
local compiler = loadstring
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/src/ui/"
local MODULES = {
    "utils",
    "responsive",
    "watchdog",
    "components",
    "window"
}

if type(compiler) ~= "function" then
    return nil
end

local function fetch(name)
    local url = BASE_URL .. name .. ".lua"
    local cacheBust = "?dephubui=" .. tostring(math_floor(os.clock() * 1000000))
    local ok, result = pcall(function()
        return game:HttpGet(url .. cacheBust)
    end)

    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end

    return false, ok and "Resposta HTTP vazia" or tostring(result)
end

local function compile(source, name)
    local transformed = source:gsub("require%(script%.Parent%.([%w_]+)%)", '__DEPHUB_UI_MODULES["%1"]')
    local ok, chunk, err = pcall(compiler, transformed)

    if not ok or type(chunk) ~= "function" then
        return false, err or chunk or ("Falha compilando " .. name)
    end

    return true, chunk
end

local previousModules = env.__DEPHUB_UI_MODULES
env.__DEPHUB_UI_MODULES = {}

local function restore()
    env.__DEPHUB_UI_MODULES = previousModules
end

for _, name in ipairs(MODULES) do
    local okFetch, source = fetch(name)
    if not okFetch then
        restore()
        return nil
    end

    local okCompile, chunk = compile(source, name)
    if not okCompile then
        restore()
        return nil
    end

    local okRun, result = pcall(chunk)
    if not okRun then
        restore()
        return nil
    end

    env.__DEPHUB_UI_MODULES[name] = result
end

local Library = env.__DEPHUB_UI_MODULES.window
local Loading = env.__DEPHUB_UI_LOADING

if type(Loading) ~= "table" then
    local okFetch, source = fetch("loading")
    if okFetch then
        local okCompile, chunk = compile(source, "loading")
        if okCompile then
            local okRun, result = pcall(chunk)
            if okRun then
                Loading = result
            end
        end
    end
end

restore()

env.__DEPHUB_UI_LOADING = Loading

if type(Library) ~= "table" or type(Library.new) ~= "function" then
    return nil
end

if type(Loading) == "table" then
    Library.Loading = Loading
end

return Library

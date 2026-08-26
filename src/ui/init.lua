local game = game
local task = task
local type = type
local tostring = tostring
local pcall = pcall
local math_floor = math.floor
local UDim2_new = UDim2.new

local env = type(getgenv) == "function" and getgenv() or _G
local compiler = loadstring
local BASE_URL = "https://raw.githubusercontent.com/glowpkj/DepHub/main/src/ui/"
local MODULES = {"utils", "responsive", "watchdog", "components", "window", "controller"}

if type(compiler) ~= "function" then
    return nil
end

local function fetch(name)
    local url = BASE_URL .. name .. ".lua"
    local ok, result = pcall(function()
        return game:HttpGet(url)
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
local Controller = env.__DEPHUB_UI_MODULES.controller
local Loading = env.__DEPHUB_UI_LOADING
restore()
env.__DEPHUB_UI_LOADING = Loading

if type(Library) ~= "table" or type(Library.new) ~= "function" then
    return nil
end

local originalNew = Library.new
Library.new = function(...)
    local window = originalNew(...)
    if type(Controller) == "table" and type(Controller.Enhance) == "function" then
        window = Controller.Enhance(window) or window
    end
    if type(window) == "table" then
        window.SetOpen = function(self, shouldOpen)
            if self.Destroyed or not self.Window then return end
            local visible = shouldOpen == true
            self.IsHidden = not visible
            self.Window.Visible = visible
            if self.ToggleButton then
                self.ToggleButton.Visible = true
                if not visible then
                    self.LastOpenSize = self.Window.Size
                end
            end
        end
        if window.ToggleButton then
            window.ToggleButton.Position = UDim2_new(0, 50, 0, 50)
        end
    end
    return window
end

if type(Loading) == "table" then
    Library.Loading = Loading
end

return Library

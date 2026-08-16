local HttpService = game:GetService("HttpService")

local Feature = {}
Feature.__index = Feature

local function funcs()
    return {
        read = type(readfile) == "function" and readfile or nil,
        write = type(writefile) == "function" and writefile or nil,
        exists = type(isfile) == "function" and isfile or nil
    }
end

function Feature.new(context)
    local self = setmetatable({}, Feature)
    self.Context = context
    self.Enabled = true
    self.Data = {}
    self.FileName = "DepHub_BloxFruits_" .. tostring(game.PlaceId) .. ".json"
    self.MemoryKey = "__DEPHUB_BLOXFRUITS_CONFIG"
    return self
end

function Feature:Load(defaults)
    self.Data = {}
    for key, value in pairs(defaults or {}) do
        self.Data[key] = value
    end
    local f = funcs()
    local env = type(getgenv) == "function" and getgenv() or _G
    local loaded
    if f.read and f.exists then
        local okExists, exists = pcall(f.exists, self.FileName)
        if okExists and exists then
            local okRead, source = pcall(f.read, self.FileName)
            if okRead and type(source) == "string" and source ~= "" then
                local okDecode, data = pcall(HttpService.JSONDecode, HttpService, source)
                if okDecode and type(data) == "table" then loaded = data end
            end
        end
    end
    if not loaded and type(env[self.MemoryKey]) == "table" then loaded = env[self.MemoryKey] end
    if type(loaded) == "table" then
        for key, value in pairs(loaded) do self.Data[key] = value end
    end
    env[self.MemoryKey] = self.Data
    return self.Data
end

function Feature:Get(key, fallback)
    local value = self.Data[key]
    if value == nil then return fallback end
    return value
end

function Feature:Set(key, value, save)
    self.Data[key] = value
    local env = type(getgenv) == "function" and getgenv() or _G
    env[self.MemoryKey] = self.Data
    if save ~= false then self:Save() end
    return true
end

function Feature:Update(values, save)
    for key, value in pairs(values or {}) do self.Data[key] = value end
    local env = type(getgenv) == "function" and getgenv() or _G
    env[self.MemoryKey] = self.Data
    if save ~= false then self:Save() end
    return true
end

function Feature:Save()
    local f = funcs()
    if not f.write then return false end
    local okEncode, source = pcall(HttpService.JSONEncode, HttpService, self.Data)
    if not okEncode or type(source) ~= "string" then return false end
    return pcall(f.write, self.FileName, source)
end

function Feature:Enable() return true end
function Feature:Disable() return true end
function Feature:IsEnabled() return true end
function Feature:Destroy()
    self:Save()
    self.Context = nil
end

return Feature

local dephub
do
    local function pick(t) return type(t) == "table" and t.__DEPHUB_OSS_RUNTIME or nil end
    dephub = (type(getgenv) == "function" and pick(select(2, pcall(getgenv)))) or pick(shared) or pick(_G)
    if not dephub then error("DepHub OSS runtime missing: __DEPHUB_OSS_RUNTIME was not published", 0) end
end
local game = dephub.game
local task = dephub.task

-- Core: config, in-memory logs, and lifecycle (connections/threads/modules) cleaned up on unload.
local Core = {}
Core.config = {}
Core.logs = {}
Core._conns = {}
Core._threads = {}
Core._cleanups = {}
Core.modules = {}

local LOG_CAP = 2000
local spawn = (task and task.spawn) or function(f, ...) return coroutine.wrap(f)(...) end
local cancel = task and task.cancel

Core.config = {
    prefix = "[BF]",
    verbose = true,
    logToFile = false,
}
function Core.configure(overrides)
    for k, v in pairs(overrides or {}) do Core.config[k] = v end
    return Core.config
end

function Core.log(level, ...)
    local n = select("#", ...)
    local parts = table.create and table.create(n) or {}
    for i = 1, n do parts[i] = tostring((select(i, ...))) end
    local msg = table.concat(parts, " ")
    local now = (os.clock and os.clock()) or 0
    Core.logs[#Core.logs + 1] = { t = now, level = level, msg = msg }
    if #Core.logs > LOG_CAP then table.remove(Core.logs, 1) end
    if Core.config.verbose then print(("%s %s: %s"):format(Core.config.prefix, level, msg)) end
    if Core.config.logToFile and writefile and appendfile then
        pcall(appendfile, "bf_script.log", ("%.2f %s %s\n"):format(now, level, msg))
    end
    return msg
end
function Core.info(...) return Core.log("INFO", ...) end
function Core.warn(...) return Core.log("WARN", ...) end
function Core.dumpLogs()
    local out = {}
    for i, e in ipairs(Core.logs) do out[i] = ("%.2f %s %s"):format(e.t, e.level, e.msg) end
    return table.concat(out, "\n")
end

function Core.track(conn)
    Core._conns[#Core._conns + 1] = conn
    return conn
end
function Core.spawn(fn, ...)
    local th = spawn(fn, ...)
    Core._threads[#Core._threads + 1] = th
    return th
end
function Core.onCleanup(fn)
    Core._cleanups[#Core._cleanups + 1] = fn
end
function Core.register(name, mod)
    Core.modules[name] = mod
    return mod
end

local HttpService = game:GetService("HttpService")
-- Config lives under a DepHub-owned prefix so it never collides with a
-- standalone copy of the open-source script running in the same executor.
local FILE_PREFIX = "DepHub_BF_"
local CONFIG_FILE = FILE_PREFIX .. "config.json"
function Core.gatherConfig()
    local t = {}
    local ui = Core.modules.ui
    if ui and ui._controls then
        for key, c in pairs(ui._controls) do
            local ok, v = pcall(c.get)
            if ok and v ~= nil then t[key] = v end
        end
    end
    return t
end
function Core.applyConfig(data)
    local ui = Core.modules.ui
    if not (ui and ui._controls) then return end
    for key, v in pairs(data or {}) do
        local c = ui._controls[key]
        if c then pcall(c.set, v) end
    end
end
function Core.saveConfig(file)
    if not writefile then return false, "no writefile" end
    local ok, s = pcall(function() return HttpService:JSONEncode(Core.gatherConfig()) end)
    if not ok then return false, "encode failed" end
    local wok = pcall(writefile, file or CONFIG_FILE, s)
    return wok
end
function Core.loadConfig(file)
    file = file or CONFIG_FILE
    if not (isfile and readfile) then return false, "no readfile" end
    local ok = pcall(isfile, file)
    if not (ok and isfile(file)) then return false, "no file" end
    local rok, data = pcall(function() return HttpService:JSONDecode(readfile(file)) end)
    if rok and type(data) == "table" then Core.applyConfig(data); return true end
    return false, "decode failed"
end

local LAST_FILE = FILE_PREFIX .. "lastcfg.txt"
local function cfgFile(name) return FILE_PREFIX .. "cfg_" .. name .. ".json" end
local function cfgName(file)
    local match = tostring(file):match(FILE_PREFIX .. "cfg_(.+)%.json$")
    if match then return match end
    -- Adopt configs written by an earlier DepHub revision that used the bare
    -- "BF_cfg_<name>.json" name, so an existing user keeps their settings.
    return tostring(file):match("BF_cfg_(.+)%.json$")
end
function Core.listConfigs()
    local names = {}
    if not listfiles then return names end
    local ok, files = pcall(listfiles, "")
    if not ok or not files then ok, files = pcall(listfiles, ".") end
    if files then
        for _, f in ipairs(files) do
            local n = cfgName(f)
            if n then names[#names + 1] = n end
        end
    end
    return names
end
function Core.saveNamedConfig(name)
    if not writefile or not name or name == "" then return false end
    local ok, s = pcall(function() return HttpService:JSONEncode(Core.gatherConfig()) end)
    if not ok then return false end
    local wok = pcall(writefile, cfgFile(name), s)
    if wok then pcall(writefile, LAST_FILE, name) end
    return wok
end
function Core.loadNamedConfig(name)
    if not name or name == "" or not (isfile and readfile) then return false end
    local candidates = {cfgFile(name), "BF_cfg_" .. name .. ".json"}
    for _, f in ipairs(candidates) do
        if pcall(isfile, f) and isfile(f) then
            local rok, data = pcall(function() return HttpService:JSONDecode(readfile(f)) end)
            if rok and type(data) == "table" then
                Core.applyConfig(data)
                if writefile then pcall(writefile, LAST_FILE, name) end
                return true
            end
        end
    end
    return false
end
function Core.loadLastConfig()
    if not (isfile and readfile) then return false end
    if not (pcall(isfile, LAST_FILE) and isfile(LAST_FILE)) then return false end
    local ok, name = pcall(readfile, LAST_FILE)
    if ok and name and name ~= "" then return Core.loadNamedConfig(name) end
    return false
end

-- Delete a named config. delfile is executor-provided, so guard it like the other
-- file APIs. The last-config pointer is cleared when it named this file. A
-- missing file reports false rather than pretending it deleted something.
function Core.deleteNamedConfig(name)
    if not name or name == "" or not delfile then return false end
    if isfile then
        local exists = pcall(isfile, cfgFile(name)) and isfile(cfgFile(name))
        if not exists then return false end
    end
    local ok = pcall(delfile, cfgFile(name))
    if ok and writefile and isfile and pcall(isfile, LAST_FILE) and isfile(LAST_FILE) then
        local rok, last = pcall(readfile, LAST_FILE)
        if rok and last == name then pcall(writefile, LAST_FILE, "") end
    end
    return ok
end

-- Rename a config: read its data, write it under the new name, then drop the old
-- file. Returns false if the source is missing or the target already exists.
function Core.renameNamedConfig(from, to)
    if not (from and to and from ~= "" and to ~= "" and from ~= to) then return false end
    if not (isfile and readfile and writefile and delfile) then return false end
    if pcall(isfile, cfgFile(to)) and isfile(cfgFile(to)) then return false, "exists" end
    if not (pcall(isfile, cfgFile(from)) and isfile(cfgFile(from))) then return false, "missing" end
    local rok, s = pcall(readfile, cfgFile(from))
    if not rok or type(s) ~= "string" then return false, "read" end
    local wok = pcall(writefile, cfgFile(to), s)
    if not wok then return false, "write" end
    pcall(delfile, cfgFile(from))
    return true
end

-- Reset every control back to the default it registered with. The ui model keeps
-- the default on each _defs entry, so this restores the same values a fresh
-- session starts from without needing a hardcoded table.
function Core.resetToDefaults()
    local ui = Core.modules.ui
    if not (ui and ui._defs and ui._controls) then return false end
    for _, definition in ipairs(ui._defs) do
        local control = ui._controls[definition.key]
        if control and definition.default ~= nil then pcall(control.set, definition.default) end
    end
    return true
end

-- Which module a control belongs to, by the page it was registered on. Pages map
-- to modules one-to-one for the Blox Fruits backend, which is what "reset just
-- this module" needs.
local PAGE_MODULE = {
    ["PVP"] = "combat", ["Farm"] = "farm", ["Farm 2"] = "farm", ["Farm 3"] = "farm",
    ["Player"] = "player", ["Fruit"] = "fruits", ["Shop"] = "shop", ["Shop 2"] = "shop",
    ["Shop 3"] = "shop", ["Raids/Events"] = "events", ["Extras"] = "extras",
    ["Teleport"] = "teleport", ["Sea"] = "teleport",
}
function Core.moduleForPage(page) return PAGE_MODULE[tostring(page)] end

-- Reset only the controls registered for one module, leaving every other module's
-- settings untouched. Returns the number of controls reset.
function Core.resetModule(moduleName)
    local ui = Core.modules.ui
    if not (ui and ui._defs and ui._controls) or not moduleName then return 0 end
    local count = 0
    for _, definition in ipairs(ui._defs) do
        if Core.moduleForPage(definition.page) == moduleName then
            local control = ui._controls[definition.key]
            if control and definition.default ~= nil then
                pcall(control.set, definition.default)
                count = count + 1
            end
        end
    end
    return count
end

function Core.unload()
    for _, m in pairs(Core.modules) do
        if type(m) == "table" and type(m.stop) == "function" then pcall(m.stop) end
    end
    for _, fn in ipairs(Core._cleanups) do pcall(fn) end
    for _, c in ipairs(Core._conns) do pcall(function() c:Disconnect() end) end
    for _, th in ipairs(Core._threads) do if cancel then pcall(cancel, th) end end
    Core._conns, Core._threads, Core._cleanups, Core.modules = {}, {}, {}, {}
    Core.info("unloaded")
end

function Core.selfTest()
    Core.configure({ verbose = false })
    assert(Core.config.verbose == false, "configure override")
    Core.info("hello", 42)
    assert(Core.logs[#Core.logs].msg == "hello 42", "log join")
    local closed = 0
    Core.track({ Disconnect = function() closed = closed + 1 end })
    Core.onCleanup(function() closed = closed + 1 end)
    local ran = false
    Core.register("t", { stop = function() ran = true end })
    Core.unload()
    assert(ran, "module.stop called")
    assert(closed == 2, "conn + cleanup fired")
    assert(next(Core.modules) == nil and #Core._conns == 0, "state cleared")
    Core.configure({ verbose = true })
    print("core.selfTest OK")
    return true
end

return Core

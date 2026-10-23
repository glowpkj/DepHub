// Runs the published bundle against a GUI-capable double and reports what
// actually mounted.
//
//   node tests/run_loader_probe.js <luau.exe> [bundlePath]
//
// The bundle is what the game executes, so this probe runs that file (not the
// loose sources) with a __dephubHttpGet resolver serving the repo from disk
// instead of the network. It answers "did the intro and the panel mount, and
// is the panel visible" without a Roblox client.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const luau = process.argv[2] || "luau";
const root = path.join(__dirname, "..");
const bundlePath = process.argv[3] || path.join(root, "dist", "DepHub.lua");

const bundle = fs.readFileSync(bundlePath, "utf8").replace(/^\uFEFF/, "");

// Every file the resolver may be asked for, keyed by repo-relative path.
const sources = {};
function walk(dir, rel) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        const relPath = rel ? rel + "/" + entry.name : entry.name;
        if (entry.isDirectory()) walk(full, relPath);
        else if (entry.name.endsWith(".lua") || entry.name.endsWith(".txt")) {
            sources[relPath] = fs.readFileSync(full, "utf8");
        }
    }
}
walk(path.join(root, "src"), "src");

function quote(text) {
    let level = 0;
    for (;;) {
        const eq = "=".repeat(level);
        if (!text.includes("]" + eq + "]")) return "[" + eq + "[" + text + "]" + eq + "]";
        level += 1;
    }
}
const table =
    "local BUNDLE_SOURCE = " + quote(bundle) + "\n\n" +
    "local SOURCES = {\n" +
    Object.entries(sources).map(([k, v]) => `  [${JSON.stringify(k)}] = ${quote(v)},`).join("\n") +
    "\n}\n";

// The probe body. It builds a GUI double, runs the bundle, then walks what the
// bundle left behind. Kept as one string so the harness stays readable.
const probe = `
local checks, fails = 0, 0
local function ok(cond, msg)
    checks += 1
    if not cond then fails += 1; print("FAIL: " .. tostring(msg)) end
end

-- ---------------------------------------------------------------------------
-- GUI double
-- ---------------------------------------------------------------------------
local signal = function()
    local e = {handlers = {}}
    function e:Connect(fn) local c = {Connected = true, fn = fn}; self.handlers[#self.handlers+1] = c; return c end
    function e:Once(fn) return self:Connect(fn) end
    function e:Disconnect() self.Connected = false end
    function e:Fire(...) for _, c in ipairs(self.handlers) do if c.Connected then c.fn(...) end end end
    return e
end
local AUTO = {
    MouseButton1Click=true,MouseButton1Down=true,MouseButton1Up=true,MouseButton2Click=true,
    MouseEnter=true,MouseLeave=true,InputBegan=true,InputEnded=true,InputChanged=true,
    Focused=true,FocusLost=true,Activated=true,ChildAdded=true,ChildRemoved=true,Changed=true,
    AncestryChanged=true,CharacterAdded=true,CharacterRemoving=true,PlayerAdded=true,
    PlayerRemoving=true,Completed=true,Destroying=true,Touched=true,Triggered=true,
}
local CLASS_PARENTS = {
    Frame="GuiObject",TextLabel="GuiObject",TextButton="GuiObject",ImageLabel="GuiObject",
    ImageButton="GuiObject",ScrollingFrame="GuiObject",ViewportFrame="GuiObject",TextBox="GuiObject",
    GuiObject="GuiBase2d",ScreenGui="LayerCollector",
}
local meta = {}
meta.__index = function(self, key)
    local m = meta[key]; if m then return m end
    local props = rawget(self, "_props")
    if props[key] ~= nil then return props[key] end
    if AUTO[key] then local e = signal(); props[key] = e; return e end
    return nil
end
meta.__newindex = function(self, key, value)
    if key == "Parent" then
        local props = rawget(self, "_props"); local old = props.Parent
        if old then local sib = rawget(old, "_children"); for i = #sib, 1, -1 do if sib[i] == self then table.remove(sib, i) end end end
        props.Parent = value
        if value then local sib = rawget(value, "_children"); sib[#sib+1] = self end
        return
    end
    rawget(self, "_props")[key] = value
end
function meta:GetChildren() return table.clone(rawget(self, "_children")) end
function meta:FindFirstChild(n) for _, c in ipairs(rawget(self, "_children")) do if c.Name == n then return c end end return nil end
function meta:FindFirstChildOfClass(c) for _, x in ipairs(rawget(self, "_children")) do if x.ClassName == c then return x end end return nil end
function meta:FindFirstAncestorOfClass() return nil end
function meta:FindFirstChildWhichIsA() return nil end
function meta:IsA(class)
    local cur = self.ClassName
    while cur do if cur == class then return true end cur = CLASS_PARENTS[cur] end
    return false
end
function meta:WaitForChild() return self end
function meta:GetDescendants() local o = {} for _, c in ipairs(rawget(self, "_children")) do o[#o+1]=c; for _,d in ipairs(c:GetDescendants()) do o[#o+1]=d end end return o end
function meta:ClearAllChildren() for _, c in ipairs(rawget(self, "_children")) do c.Parent = nil end end
function meta:Destroy() self:ClearAllChildren(); self.Parent = nil; rawget(self,"_props").Destroyed = true end
function meta:GetPropertyChangedSignal() return signal() end
function meta:Clone() return Instance.new(self.ClassName) end
function meta:SetAttribute(n,v) rawget(self,"_attrs")[n]=v end
function meta:GetAttribute(n) return rawget(self,"_attrs")[n] end
function meta:IsDescendantOf() return true end
function meta:GetFullName() return self.Name end
function meta:GetValueString() return "0" end

local Instance = {}
function Instance.new(c) return setmetatable({_props={ClassName=c,Name=c,Parent=nil},_children={},_attrs={}}, meta) end

local Enum = setmetatable({}, {__index=function(t,k)
    local v = setmetatable({}, {__index=function(s,n) rawset(s,n,n); return n end})
    rawset(t,k,v); return v
end})

local UIS = {InputBegan=signal(), InputChanged=signal(), InputEnded=signal(),
    GetFocusedTextBox=function() return nil end, IsKeyDown=function() return false end}

local playerGui = Instance.new("PlayerGui")
local player = Instance.new("Player")
player.Name = "T"
player.CharacterAdded = signal(); player.CharacterRemoving = signal()
player.FindFirstChildOfClass = function(self, c) if c == "PlayerGui" then return playerGui end return nil end
player.WaitForChild = function(self, n) return playerGui end
player.GetMouse = function() return Instance.new("Mouse") end

local players = {LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal()}
function players:GetPlayers() return {player} end
function players:GetPlayerFromCharacter() return nil end

local tweenService
local probeTaskRef
tweenService = {
    Create = function(_, inst, info, props)
        local t = {Completed = signal(), _inst = inst, _props = props or {}}
        function t:Play()
            for k, v in pairs(self._props) do pcall(function() inst[k] = v end) end
            if self.Completed and probeTaskRef then
                probeTaskRef.defer(function() if self.Completed then self.Completed:Fire() end end)
            end
        end
        function t:Cancel() end
        function t:Pause() end
        return t
    end,
}

local coreGuiService = Instance.new("CoreGui")
coreGuiService.Name = "CoreGui"

local services = {
    Players = players,
    UserInputService = UIS,
    TweenService = tweenService,
    RunService = {Heartbeat=signal(), RenderStepped=signal(), Stepped=signal(),
        IsStudio=function() return false end, IsClient=function() return true end,
        IsServer=function() return false end},
}
local game = {PlaceId=2753915549, GameId=2753915549, Name="Blox Fruits",
    JobId="probe", Loaded = signal(), IsLoaded = function() return true end,
    GetService=function(self, name)
        if name == "CoreGui" then return coreGuiService end
        if services[name] then return services[name] end
        local made = Instance.new(name); services[name] = made; return made
    end}

-- The resolver reads SOURCES by repo-relative path.
local function resolver(url)    local rel = tostring(url):match("^.-main/(.+)$") or tostring(url)
    rel = rel:gsub("%?.*$", "")
    local src = SOURCES[rel]
    if type(src) ~= "string" then error("not bundled: " .. rel) end
    return src
end

-- A real scheduler: defer/spawn run now, delay waits. The probe can then walk
-- the whole intro timeline by advancing the clock.
local probeTask = (function()
    local queue = {}
    local clock = 0
    local spin = 0
    local t = {}
    function t.spawn(fn, ...)
        local args = table.pack(...)
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok and not tostring(err):find("spin guard") then
            print("  [spawn error] " .. tostring(err))
        end
    end
    function t.defer(fn) t.spawn(fn) end
    function t.delay(seconds, fn)
        -- A delay far in the future (a poll loop's next tick) is kept but will
        -- not fire inside the probe's advance window.
        local handle = {at = clock + (seconds or 0), fn = fn}
        if (seconds or 0) > 60 then handle.dormant = true end
        queue[#queue + 1] = handle
        return handle
    end
    function t.wait(seconds)
        clock = clock + (seconds or 0)
        -- A polling loop would spin here because wait cannot yield across the
        -- C boundary. Count the spins and abort the loop after a burst so the
        -- probe stays finite.
        spin = spin + 1
        if spin > 10000 then error("task.wait spin guard", 2) end
    end
    function t.cancel(handle)
        for i = #queue, 1, -1 do if queue[i] == handle then table.remove(queue, i) end end
    end
    -- Advance the clock and fire everything due, in order. Work scheduled during
    -- the drain is picked up on the next pass.
    function t.__advance(seconds)
        clock = clock + (seconds or 0)
        spin = 0
        local guard = 0
        local queued = #queue
        while true do
            guard = guard + 1
            if guard > 200 then break end
            local nextHandle, nextIndex = nil, nil
            for i, h in ipairs(queue) do
                if not h.dormant and h.at <= clock
                    and (not nextHandle or h.at < nextHandle.at) then
                    nextHandle, nextIndex = h, i
                end
            end
            if not nextHandle then break end
            table.remove(queue, nextIndex)
            pcall(nextHandle.fn)
        end
        return queued
    end
    function t.__now() return clock end
    return t
end)()
probeTaskRef = probeTask

local state = {}
local env
-- Modules the bundle compiles must see the same globals an executor provides,
-- so the bundle's loadstring is wrapped to setfenv.
local function envLoadstring(source, chunkname)
    local fn, err = loadstring(source, chunkname)
    if not fn then return fn, err end
    local okSet = pcall(setfenv, fn, env)
    if not okSet then print("  [envLoadstring] setfenv FAILED for " .. tostring(chunkname)) end
    return fn
end

env = setmetatable({
    game = game, Instance = Instance, Enum = Enum, signal = signal,
    getgenv = function() return state end, getrenv = function() return state end,
    typeof = typeof, print = print, warn = warn, error = error, pcall = pcall,
    tostring = tostring, tonumber = tonumber, type = type, pairs = pairs, ipairs = ipairs,
    task = probeTask,
    os = {time=function() return 0 end, clock=function() return 0 end, date=function() return {} end},
    Color3 = {fromRGB=function(r,g,b) return {r=r,g=g,b=b} end, fromHSV=function() return {r=1,g=1,b=1} end,
              new=function(r,g,b) return {r=r,g=g,b=b} end},
    ColorSequence = {new=function(a,b) return {a=a,b=b} end},
    ColorSequenceKeypoint = {new=function(t,c) return {time=t,color=c} end},
    NumberSequence = {new=function(a,b) return {a=a,b=b} end},
    NumberSequenceKeypoint = {new=function(t,v) return {time=t,value=v} end},
    UDim = {new=function(s,o) return {Scale=s,Offset=o} end},
    UDim2 = {new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end,
        fromScale=function(x,y) return {X={Scale=x,Offset=0},Y={Scale=y,Offset=0}} end,
        fromOffset=function(x,y) return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}} end},
    Vector2 = {new=function(x,y) return {X=x,Y=y} end, zero={X=0,Y=0}},
    Vector3 = {new=function(x,y,z) return {X=x,Y=y,Z=z} end, zero={X=0,Y=0,Z=0}},
    Rect = {new=function() return {} end},
    TweenInfo = {new=function(...) return {...} end},
    CFrame = {new=function() return {} end},
    Font = {new=function() return {} end},
    loadstring = envLoadstring,
    __dephubHttpGet = resolver,
}, {__index = _G})
env._G = env
state.__dephubHttpGet = resolver
state.__DEPHUB_BUNDLED_SOURCES = SOURCES

-- ---------------------------------------------------------------------------
-- Run the bundle
-- ---------------------------------------------------------------------------
local chunk, compileErr = loadstring(BUNDLE_SOURCE, "@DepHub.bundle.lua")
if not chunk then
    print("FATAL: bundle did not compile: " .. tostring(compileErr))
    print(string.format("probe checks: 1 run, 1 failed"))
    return
end
setfenv(chunk, env)
local okRun, runErr = pcall(chunk)
print("bundle ran: " .. tostring(okRun) .. (okRun and "" or (" (" .. tostring(runErr) .. ")")))

local DEP = state.__DEPHUB or env.__DEPHUB
ok(DEP ~= nil, "bundle published __DEPHUB")

-- ---------------------------------------------------------------------------
-- Inspect
-- ---------------------------------------------------------------------------
local function findGui(parent, needle, exclude)
    if not parent then return nil end
    for _, child in ipairs(parent:GetChildren()) do
        if child.ClassName == "ScreenGui" and child ~= exclude
            and string.find(string.lower(child.Name), needle, 1, true) then
            return child
        end
    end
    return nil
end

local introGui = findGui(coreGuiService, "intro") or findGui(playerGui, "intro")
ok(introGui ~= nil, "intro ScreenGui mounted")
if introGui then
    print("  intro gui: " .. introGui.Name .. " in " .. tostring(introGui.Parent and introGui.Parent.ClassName))
    local stage = introGui:FindFirstChild("Stage")
    if stage then
        print("  intro stage children = " .. #stage:GetChildren())
        local shell = stage:FindFirstChild("Shell")
        ok(shell ~= nil, "intro shell exists")
        if shell then
            print("  shell size = " .. shell.Size.X.Offset .. "x" .. shell.Size.Y.Offset)
            local brand = shell:FindFirstChild("Brand")
            ok(brand ~= nil, "intro brand exists")
            if brand then
                local markHolder = brand:FindFirstChild("MarkHolder")
                local nameLabel = brand:FindFirstChild("Name")
                ok(markHolder ~= nil, "intro mark exists")
                ok(nameLabel ~= nil, "intro name exists")
                if markHolder then
                    print("  mark size = " .. markHolder.Size.X.Offset .. "x" .. markHolder.Size.Y.Offset
                        .. " rotation = " .. tostring(markHolder.Rotation))
                end
                if nameLabel then
                    print("  name text = '" .. tostring(nameLabel.Text) .. "'")
                end
            end
            local line = shell:FindFirstChild("Line")
            ok(line ~= nil, "intro divider line exists")
        end
    else
        ok(false, "intro stage exists")
    end
end

local dephubGui = findGui(coreGuiService, "dephub", introGui) or findGui(playerGui, "dephub", introGui)
ok(dephubGui ~= nil, "panel ScreenGui mounted")

-- Capture the pre-handoff state: the loader mounts the panel hidden and plays
-- the intro over it, so before any clock advance the panel must be down while
-- the intro sits at its opening 62x62 monogram. Assert on this snapshot, then
-- advance the clock so the reveal phase runs and the panel comes up.
local bootShell = introGui and introGui:FindFirstChild("Stage")
bootShell = bootShell and bootShell:FindFirstChild("Shell")
local bootVisible = dephubGui and dephubGui:FindFirstChild("Root") and dephubGui:FindFirstChild("Root").Visible

if bootShell then
    ok(bootShell.Size.X.Offset == 62 and bootShell.Size.Y.Offset == 62,
        "intro mounts at its starting 62x62 monogram")
end
ok(bootVisible == false, "panel starts hidden for the intro to reveal")

if dephubGui then
    print("  panel gui: " .. dephubGui.Name .. " in " .. tostring(dephubGui.Parent and dephubGui.Parent.ClassName))
    local kids = {}
    for _, c in ipairs(dephubGui:GetChildren()) do kids[#kids+1] = c.ClassName .. ":" .. c.Name end
    print("  panel children: " .. table.concat(kids, ", "))
end

-- Run the intro's whole timeline; its "revealed" phase calls OnReveal, which
-- is what unhides the panel.
if probeTask and probeTask.__advance then probeTask.__advance(4.0) end

if dephubGui then
    local root = dephubGui:FindFirstChild("Root")
    ok(root ~= nil, "panel window frame exists")
    if root then
        print("  panel window visible = " .. tostring(root.Visible)
            .. " size = " .. root.Size.X.Offset .. "x" .. root.Size.Y.Offset)
        ok(root.Visible == true, "panel is visible after the intro handoff")
    end
end

if DEP then
    local keys = {}
    for k in pairs(DEP) do keys[#keys+1] = tostring(k) end
    table.sort(keys)
    print("  __DEPHUB keys: " .. table.concat(keys, ", "))
end

-- The intro's phase timeline is asserted by tests/intro_probe.js, which drives
-- a virtual clock through every phase. Above we confirmed the two facts that
-- belong to the loader: the intro mounts at its opening monogram over a hidden
-- panel, and once the intro's reveal phase runs the panel is up.
print(string.format("probe checks: %d run, %d failed", checks, fails))
`;

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "dephub-loader-probe-"));
const file = path.join(tempDir, "probe.luau");
fs.writeFileSync(file, table + probe);
try {
    console.log(execFileSync(luau, [file], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }));
} catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);
    process.exit(1);
} finally {
    try { fs.rmSync(tempDir, { recursive: true, force: true }); } catch {}
}

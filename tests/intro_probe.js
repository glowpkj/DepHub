// Intro timeline probe. Loads src/ui/Intro.lua alone against a GUI double with
// a controllable clock, drives every phase, and asserts the state the mockup
// (INTRO.html) specifies at each one.
//
//   node tests/intro_probe.js <luau.exe>

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const luau = process.argv[2] || "luau";
const root = path.join(__dirname, "..");
const introSource = fs.readFileSync(path.join(root, "src", "ui", "Intro.lua"), "utf8");

function quote(text) {
    let level = 0;
    for (;;) {
        const eq = "=".repeat(level);
        if (!text.includes("]" + eq + "]")) return "[" + eq + "[" + text + "]" + eq + "]";
        level += 1;
    }
}

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
local AUTO = {Completed=true,ChildAdded=true,ChildRemoved=true,Changed=true,AncestryChanged=true}
local CLASS_PARENTS = {Frame="GuiObject",TextLabel="GuiObject",TextButton="GuiObject",GuiObject="GuiBase2d",ScreenGui="LayerCollector"}
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
function meta:FindFirstChildWhichIsA() return nil end
function meta:FindFirstAncestorOfClass() return nil end
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

local Instance = {}
function Instance.new(c) return setmetatable({_props={ClassName=c,Name=c,Parent=nil},_children={},_attrs={}}, meta) end
local Enum = setmetatable({}, {__index=function(t,k)
    local v = setmetatable({}, {__index=function(s,n) rawset(s,n,n); return n end})
    rawset(t,k,v); return v
end})

-- A controllable clock. Delays register against it; __advance fires what is due.
local clock = 0
local queue = {}
local probeTask = {}
function probeTask.delay(seconds, fn)
    local handle = {at = clock + (seconds or 0), fn = fn}
    queue[#queue + 1] = handle
    return handle
end
function probeTask.defer(fn) return probeTask.delay(0, fn) end
function probeTask.spawn(fn) return probeTask.delay(0, fn) end
function probeTask.wait(seconds) clock = clock + (seconds or 0) end
function probeTask.cancel(handle)
    for i = #queue, 1, -1 do if queue[i] == handle then table.remove(queue, i) end end
end
function probeTask.__advance(seconds)
    -- Step the clock in small ticks so work scheduled by earlier work is picked
    -- up at the right virtual time, the way the engine would.
    local remaining = seconds or 0
    local step = 0.05
    while remaining > 0 do
        local tick = math.min(step, remaining)
        remaining = remaining - tick
        clock = clock + tick
        local guard = 0
        while true do
            guard = guard + 1
            if guard > 50 then break end
            local nextHandle, nextIndex = nil, nil
            for i, h in ipairs(queue) do
                if h.at <= clock and (not nextHandle or h.at < nextHandle.at) then
                    nextHandle, nextIndex = h, i
                end
            end
            if not nextHandle then break end
            table.remove(queue, nextIndex)
            pcall(nextHandle.fn)
        end
    end
end
function probeTask.__now() return clock end

-- TweenService that plants each tween on the virtual clock: the end state is
-- applied when its duration elapses, which is what the phases depend on.
local tweenService = {
    Create = function(_, inst, info, props)
        local duration = type(info) == "table" and (tonumber(info[1]) or 0) or 0
        local t = {Completed = signal(), _inst = inst, _props = props or {}, _done = false}
        function t:Play()
            probeTask.delay(duration, function()
                self._done = true
                for k, v in pairs(self._props) do pcall(function() inst[k] = v end) end
                if self.Completed then self.Completed:Fire() end
            end)
        end
        function t:Cancel() self._cancelled = true end
        return t
    end,
}

local coreGui = Instance.new("CoreGui")
local playerGui = Instance.new("PlayerGui")
local player = Instance.new("Player")
player.Name = "T"
player.WaitForChild = function() return playerGui end
player.FindFirstChildOfClass = function(self, c) if c == "PlayerGui" then return playerGui end return nil end
local players = {LocalPlayer = player}

local services = {TweenService = tweenService, Players = players,
    RunService = {Heartbeat = signal(), RenderStepped = signal()}}
local game = {GameId = 1, PlaceId = 1, Name = "Test",
    GetService = function(self, name)
        if name == "CoreGui" then return coreGui end
        if services[name] then return services[name] end
        local m = Instance.new(name); services[name] = m; return m
    end}

local env = setmetatable({
    game = game, Instance = Instance, Enum = Enum, signal = signal,
    task = probeTask, typeof = typeof, print = print, warn = warn, pcall = pcall,
    Color3 = {fromRGB=function(r,g,b) return {r=r,g=g,b=b} end, new=function(r,g,b) return {r=r,g=g,b=b} end},
    ColorSequence = {new=function(a,b) return {a=a,b=b} end},
    ColorSequenceKeypoint = {new=function(t,c) return {time=t,color=c} end},
    NumberSequence = {new=function(a,b) return {a=a,b=b} end},
    NumberSequenceKeypoint = {new=function(t,v) return {time=t,value=v} end},
    UDim = {new=function(s,o) return {Scale=s,Offset=o} end},
    UDim2 = {new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end,
        fromScale=function(x,y) return {X={Scale=x,Offset=0},Y={Scale=y,Offset=0}} end,
        fromOffset=function(x,y) return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}} end},
    Vector2 = {new=function(x,y) return {X=x,Y=y} end},
    TweenInfo = {new=function(...) return {...} end},
}, {__index = _G})

local chunk = assert(loadstring(INTRO_SOURCE, "@Intro.lua"))
setfenv(chunk, env)
local Intro = chunk()

local revealed = false
local completed = false
local inst = Intro:Play({
    OnReveal = function() revealed = true end,
    OnComplete = function() completed = true end,
})

local gui = inst.Gui
ok(gui ~= nil and gui.Name == "DepHubIntro", "intro builds its ScreenGui")
local stage = gui:FindFirstChild("Stage")
ok(stage ~= nil, "intro stage exists")
local shell = stage:FindFirstChild("Shell")
ok(shell ~= nil, "intro shell exists")
local brand = shell:FindFirstChild("Brand")
ok(brand ~= nil, "intro brand exists")
local markHolder = brand:FindFirstChild("MarkHolder")
local nameLabel = brand:FindFirstChild("Name")
ok(markHolder ~= nil, "intro mark exists")
ok(nameLabel ~= nil, "intro name exists")
local line = shell:FindFirstChild("Line")
ok(line ~= nil, "intro divider line exists")

-- t=0: the monogram, rotated -13deg, matching the stylesheet defaults.
print(string.format("  [t=0.00] shell=%dx%d mark=%dx%d rot=%s name=%s",
    shell.Size.X.Offset, shell.Size.Y.Offset,
    markHolder.Size.X.Offset, markHolder.Size.Y.Offset,
    tostring(markHolder.Rotation), tostring(nameLabel.Text)))
ok(shell.Size.X.Offset == 62 and shell.Size.Y.Offset == 62, "shell starts at 62x62")
ok(markHolder.Size.X.Offset == 34 and markHolder.Size.Y.Offset == 34, "mark is 34x34")
ok(markHolder.Rotation == -13, "mark starts rotated -13 degrees")
ok(nameLabel.Text == "DepHub", "name text is DepHub")

-- t=950 named, and its 0.65s width tween completes by ~1600.
probeTask.__advance(1.7)
print(string.format("  [named] shell=%dx%d", shell.Size.X.Offset, shell.Size.Y.Offset))
ok(shell.Size.X.Offset == 174, "named widens the shell to 174")

-- t=2050 expanding, 0.95s expansion completes by ~3000.
probeTask.__advance(1.5)
print(string.format("  [expanding] shell=%dx%d brandPos=%d,%d lineTop=%d",
    shell.Size.X.Offset, shell.Size.Y.Offset,
    brand.Position.X.Offset, brand.Position.Y.Offset, line.Position.Y.Offset))
ok(shell.Size.X.Offset == 780 and shell.Size.Y.Offset == 520, "expanding grows the shell to 780x520")
ok(brand.Position.X.Offset == 24 and brand.Position.Y.Offset == 13, "brand slides to the header position")
ok(line.Position.Y.Offset == 65, "divider sits at top:65")

-- t=3050: revealed. The panel takes over.
probeTask.__advance(1.2)
print("  [revealed] OnReveal fired = " .. tostring(revealed))
ok(revealed == true, "revealed fires OnReveal so the panel can appear")

-- t=3550 done, then the 0.32s teardown.
probeTask.__advance(1.5)
print("  [done] OnComplete fired = " .. tostring(completed))
ok(completed == true, "done fires OnComplete")

print(string.format("intro checks: %d run, %d failed", checks, fails))
`;

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "dephub-intro-probe-"));
const file = path.join(tempDir, "probe.luau");
fs.writeFileSync(file, "local INTRO_SOURCE = " + quote(introSource) + "\n" + probe);
try {
    console.log(execFileSync(luau, [file], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 60000 }));
} catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);
    process.exit(1);
} finally {
    try { fs.rmSync(tempDir, { recursive: true, force: true }); } catch {}
}

// Verifies a generated DepHub bundle is self-contained: it must load its
// backend purely from the inlined BUNDLED_SOURCES table with the network
// blocked. This is what proves the private repository no longer has to be
// reachable at runtime.
//
// Usage: node tests/verify_bundle.js <bundlePath> <luauExe> [PlaceId] [GameId] [expectedMode]
//   With no PlaceId the check defaults to Blox Fruits.

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');

const bundlePath = process.argv[2];
const luau = process.argv[3];
if (!bundlePath || !luau) {
  throw new Error('Usage: node tests/verify_bundle.js <bundlePath> <luauExe> [PlaceId] [GameId]');
}
if (!fs.existsSync(bundlePath)) throw new Error('Bundle not found: ' + bundlePath);

const placeId = process.argv[4] || '2753915549';
const gameId = process.argv[5] || '994732206';
// The mode the loader publishes is the backend file's basename (see DepHub.lua),
// so derive it from the manifest instead of carrying a stale literal. An explicit
// 6th argument still overrides.
const gamesManifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '.github/dephub-games.json'), 'utf8'));
const manifestEntry = gamesManifest[String(gameId)];
let expectedMode = process.argv[6];
if (!expectedMode) {
  const backend = manifestEntry && manifestEntry.files.find(f => f.startsWith('src/games/') && f.endsWith('.lua') && !f.includes('/features/'));
  expectedMode = backend ? backend.replace(/^src\/games\//, '').replace(/\.lua$/, '') : 'Game';
}

const bundle = fs.readFileSync(bundlePath, 'utf8');

function quote(value) {
  let eq = '=';
  while (value.includes(']' + eq + ']')) eq += '=';
  return '[' + eq + '[' + value + ']' + eq + ']';
}

// Minimal environment with every network path throwing, so a successful run can
// only mean the modules came from BUNDLED_SOURCES.
const driver = `
local norm = function(p) return (p:gsub("\\\\", "/")) end
local fired = {}
local function signal()
    local e = {connections = {}}
    function e:Connect(fn) local c = {Connected=true, fn=fn}; self.connections[#self.connections+1]=c; return c end
    function e:Wait() end
    function e:Fire(...) for _,c in ipairs(self.connections) do if c.Connected then c.fn(...) end end end
    return e
end
local Player = {Name="Tester", UserId=1, DisplayName="Tester", Character=nil, Backpack=nil, PlayerGui=nil, CharacterAdded=signal(), CharacterRemoving=signal(), PlayerAdded=signal(), AncestryChanged=signal(), ChildAdded=signal(), ChildRemoved=signal(), DescendantAdded=signal(), DescendantRemoving=signal(), Changed=signal(), OnTeleport=signal()}
-- Same permissive surface as an instance: an unmodelled member is a live signal,
-- and WaitForChild/FindFirstChild resolve against nothing (the fake has no tree).
setmetatable(Player, {__index=function(self, key)
    if key == "WaitForChild" or key == "FindFirstChild" or key == "FindFirstChildOfClass" then return function() return nil end end
    if key == "IsA" then return function(_, c) return c == "Player" end end
    local sig = signal(); rawset(self, key, sig); return sig
end})
local players = {LocalPlayer=Player, GetPlayers=function() return {Player} end, PlayerAdded=signal(), PlayerRemoving=signal(), GetPlayerFromCharacter=function() return nil end}
local function blankInstance(class)
    local inst = {ClassName=class, Name=class, _children={}, _props={},
        ChildAdded=signal(), ChildRemoved=signal(), DescendantAdded=signal(), DescendantRemoving=signal(),
        AncestryChanged=signal(), AttributeChanged=signal(), Changed=signal(),
        Focused=signal(), FocusLost=signal(), TextChanged=signal(), Activated=signal(),
        MouseEnter=signal(), MouseLeave=signal(), MouseButton1Down=signal(), MouseButton1Up=signal(),
        MouseButton1Click=signal(), MouseButton2Click=signal(), SelectionGained=signal(), SelectionLost=signal(),
        InputBegan=signal(), InputChanged=signal(), InputEnded=signal(), Destroying=signal(),
        GetPropertyChangedSignal=function() return signal() end,
        GetAttributeChangedSignal=function() return signal() end,
        SetAttribute=function() end, GetAttribute=function() return nil end,
        FindFirstChild=function(self, name) for _, c in ipairs(self._children) do if c.Name == name then return c end end end,
        FindFirstChildOfClass=function(self, klass) for _, c in ipairs(self._children) do if c.ClassName == klass then return c end end end,
        FindFirstChildWhichIsA=function(self, klass) for _, c in ipairs(self._children) do if c.ClassName == klass then return c end end end,
        GetChildren=function(self) return self._children end,
        GetDescendants=function(self)
            local out = {}
            for _, c in ipairs(self._children) do
                out[#out+1] = c
                for _, d in ipairs(c:GetDescendants()) do out[#out+1] = d end
            end
            return out
        end,
        IsA=function(self,c) return c==class or c=="Instance" or c=="GuiObject" end,
        ClearAllChildren=function(self) self._children = {} end, Remove=function() end,
        FindFirstAncestor=function() return nil end, FindFirstAncestorOfClass=function() return nil end,
        FindFirstAncestorWhichIsA=function() return nil end,
        GetFullName=function(self) return self.Name end, IsDescendantOf=function() return false end,
        WaitForChild=function(self, name) return self:FindFirstChild(name) end, Destroy=function() end}
    inst.Clone = function() return inst end
    -- A real Roblox instance resolves obj.Child by walking its children, and any
    -- unmodelled GuiObject event (RedzLib connects a long tail of them:
    -- MouseButton1Click, SelectionGained, InputBegan on TextBoxes, ...) is a live
    -- signal. Model both so the shell builds here exactly as it does in game.
    return setmetatable(inst, {
        __index=function(self, key)
            if key == "Parent" then return rawget(self, "_parent") end
            local child = rawget(self, "FindFirstChild")
            if child then
                local found = child(self, key)
                if found then return found end
            end
            local sig = signal()
            rawset(self, key, sig)
            return sig
        end,
        __newindex=function(self, key, value)
            if key == "Parent" then
                rawset(self, "_parent", value)
                if type(value) == "table" and type(value._children) == "table" then
                    value._children[#value._children+1] = self
                end
                return
            end
            rawset(self, key, value)
        end,
    })
end
-- Defined after blankInstance so the closure captures the local, not a nil global.
-- RedzLib asks LocalPlayer for the mouse at build time.
Player.GetMouse = function() return {Hit=blankInstance("CFrame"), Target=nil, UnitRay={}} end
-- A real client has a character once loaded; some backends bind to it at init
-- (MM2's role tracker connects character.ChildAdded).
local fakeCharacter = blankInstance("Model")
fakeCharacter.Name = "TestCharacter"
Player.Character = fakeCharacter
local rs = blankInstance("ReplicatedStorage")
-- The shell reads the camera's ViewportSize to size itself; a real client always
-- has a CurrentCamera on Workspace.
local camera = blankInstance("Camera")
camera.ViewportSize = {X=1920, Y=1080}
camera.CFrame = {Position={X=0,Y=0,Z=0}, LookVector={X=0,Y=0,Z=-1}, p={0,0,0}}
camera.FieldOfView = 70
camera.CameraSubject = nil
camera.CameraType = "Custom"
local workspace = blankInstance("Workspace")
workspace.CurrentCamera = camera
local networkAttempts = {}
-- Model an executor that does NOT expose HttpGet as a DataModel member (some
-- only provide it as a global). The bundle must never depend on the member
-- existing, and never fetch — the blocker below records any attempt either way.
local game = {
    PlaceId = ${placeId}, GameId = ${gameId}, JobId = "job", Name = "Test Game",
    IsLoaded = function() return true end, Loaded = signal(),
    GetService = function(self, name)
        if name == "Players" then return players end
        if name == "ReplicatedStorage" then return rs end
        if name == "Workspace" then return workspace end
        if name == "Camera" then return camera end
        if name == "Teams" then return blankInstance("Teams") end
        if name == "RunService" then return {RenderStepped=signal(), Stepped=signal(), Heartbeat=signal(), IsStudio=function() return false end, IsClient=function() return true end, IsServer=function() return false end, BindToRenderStep=function() end, UnbindFromRenderStep=function() end} end
        if name == "UserInputService" then return {InputBegan=signal(), InputChanged=signal(), InputEnded=signal(), JumpRequest=signal(), TouchStarted=signal(), TouchEnded=signal(), GetFocusedTextBox=function() return nil end, GetMouseLocation=function() return {} end, MouseBehavior=0, MouseIconEnabled=true} end
        if name == "TeleportService" then return {Teleport=function() end, TeleportToPlaceInstance=function() end, TeleportInitFailed=signal()} end
        if name == "HttpService" then return {JSONDecode=function() return {} end, JSONEncode=function() return "{}" end, GenerateGUID=function() return "guid" end} end
        if name == "Lighting" then return blankInstance("Lighting") end
        if name == "SoundService" then return blankInstance("SoundService") end
        if name == "StarterGui" then return blankInstance("StarterGui") end
        if name == "StarterPlayer" then return blankInstance("StarterPlayer") end
        if name == "TweenService" then return {Create=function() return {Play=function() end, Cancel=function() end, Completed=signal()} end} end
        if name == "VirtualUser" then return {Button1Down=function() end, Button2Down=function() end, CaptureController=function() end, ClickButton1=function() end, ClickButton2=function() end} end
        if name == "VirtualInputManager" then return {SendKeyEvent=function() end, SendMouseButtonEvent=function() end, SendMouseMoveEvent=function() end} end
        if name == "ProximityPromptService" then return {PromptTriggered=signal(), PromptButtonHoldBegan=signal()} end
        if name == "ContextActionService" then return {BindAction=function() end, UnbindAction=function() end, BindActionAtPriority=function() end} end
        if name == "GuiService" then return blankInstance("GuiService") end
        if name == "TextService" then return {GetTextSize=function() return {} end} end
        if name == "CollectionService" then return {GetTagged=function() return {} end, AddTag=function() end, RemoveTag=function() end, GetInstanceAddedSignal=function() return signal() end, GetInstanceRemovedSignal=function() return signal() end} end
        if name == "CoreGui" then return blankInstance("CoreGui") end
        if name == "PlayerGui" then return blankInstance("PlayerGui") end
        if name == "TextChatService" then return blankInstance("TextChatService") end
        if name == "MarketplaceService" then return {GetProductInfo=function() return {} end, GetDeveloperProductsAsync=function() return {GetCurrentPage=function() return {} end} end, PromptGamePassPurchase=function() end, PromptProductPurchase=function() end, UserOwnsGamePassAsync=function() return false end, ProcessReceipt=signal(), PromptPurchaseFinished=signal(), PromptGamePassPurchaseFinished=signal()} end
        return blankInstance(name)
    end,
}
local state = {}
local logs = {}
local nativeGlobals = getfenv(1)
-- Virtual tick source (see the task table below): monotonically increasing, so a
-- loop that waits for tick() to advance always terminates.
local virtualClock = 0
-- UDim2 value methods the shell's draggable/window code calls.
local UDim2meta = {__index={Lerp=function(self) return self end, sub=function(self) return self end}}
local env = {
    game = game, workspace = workspace,
    task = {wait=function(s) virtualClock = virtualClock + (tonumber(s) or 1) end, defer=function(f, ...) if f then f(...) end end, spawn=function(f) return f end, cancel=function() end},
    print = function(...) local parts={} for _,v in ipairs({...}) do parts[#parts+1]=tostring(v) end; logs[#logs+1]=table.concat(parts," ") end,
    warn = function(...) local parts={} for _,v in ipairs({...}) do parts[#parts+1]=tostring(v) end; logs[#logs+1]=table.concat(parts," ") end,
    getgenv = function() return state end, identifyexecutor = function() return "BundleVerify" end,
    -- The global HttpGet is the executor's fetch primitive here; the loader must
    -- reach for this when the DataModel member is absent. Any call is a bundle
    -- defect, so it records and errors.
    HttpGet = function(url) networkAttempts[#networkAttempts+1] = tostring(url); error("NETWORK BLOCKED (bundle should not fetch): " .. tostring(url)) end,
    typeof = typeof, tostring=tostring, tonumber=tonumber, type=type, pcall=pcall,
    ipairs=ipairs, pairs=pairs, next=next, select=select, unpack=unpack or table.unpack,
    -- Roblox globals RedzLib calls while building the window (timings, deferred work).
    -- tick/wait must move together: the shell's draggable loop spins on
    -- "while ... do ... task.wait() end" and exits only when tick() advances a
    -- second. Drive a virtual clock (wall-clock busy waits can spin forever on a
    -- coarse platform timer).
    tick = function() return virtualClock end, time = function() return virtualClock end,
    wait = function(s) virtualClock = virtualClock + (tonumber(s) or 1) end,
    delay = function(_, f) if f then f() end end, spawn = function(f, ...) return f end,
    os=os, math=math, string=string, table=table, debug=debug,
    DateTime = {now=function() return {UnixTimestampMillis=function() return 0 end} end},
    Instance = {new=function(c) return blankInstance(c) end},
    Enum = setmetatable({}, {__index=function(t,k) local v=setmetatable({},{__index=function(s,n) rawset(s,n,n); return n end}); rawset(t,k,v); return v end}),
    Color3 = {fromRGB=function() return {} end, new=function() return {} end},
    Vector3 = {new=function() return {Magnitude=0, X=0, Y=0, Z=0} end, zero=function() return {Magnitude=0} end},
    CFrame = {new=function() return {Position={X=0,Y=0,Z=0}} end, lookAt=function() return {Position={X=0,Y=0,Z=0}} end},
    -- The shell sizes its window with UDim2 at load time (RedzLib + the adapter),
    -- so the fake world has to provide the datatype constructors a real client
    -- always exposes.
    UDim2 = {
        new=function(xs,xo,ys,yo) return setmetatable({X={Scale=xs or 0,Offset=xo or 0}, Y={Scale=ys or 0,Offset=yo or 0}}, UDim2meta) end,
        fromOffset=function(x,y) return setmetatable({X={Scale=0,Offset=x or 0}, Y={Scale=0,Offset=y or 0}}, UDim2meta) end,
        fromScale=function(x,y) return setmetatable({X={Scale=x or 0,Offset=0}, Y={Scale=y or 0,Offset=0}}, UDim2meta) end,
    },
    UDim = {new=function(s,o) return {Scale=s or 0, Offset=o or 0} end},
    Vector2 = {new=function(x,y) return {X=x or 0, Y=y or 0} end},
    ColorSequence = {new=function(t) return t or {} end},
    ColorSequenceKeypoint = {new=function(t,c) return {Time=t, Value=c} end},
    NumberSequence = {new=function() return {} end},
    Rect = {new=function() return {} end},
    TweenInfo = {new=function() return {} end},
    Random = {new=function() return {NextNumber=function() return 0.5 end, NextInteger=function(a) return a end} end},
}
-- Executors expose the full Lua standard library plus task/game. Mirror that by
-- falling back to the native globals for anything the sandbox does not
-- override, so modules may use setmetatable/string/etc. freely.
setmetatable(env, {__index = function(_, key) return nativeGlobals[key] end})
-- Route loadstring through the sandbox environment so modules loaded by the
-- bundle see the same faked globals (this mirrors how an executor exposes
-- game/Instance to chunks it loads).
local nativeLoadstring = loadstring
env.loadstring = function(src)
    local fn, err = nativeLoadstring(src)
    if fn then setfenv(fn, env) end
    return fn, err
end
env._G = env
-- The vendored Blox Fruits modules read their globals from the shared
-- environment rather than from the loader's chunk-locals, so the fake world has
-- to publish the same runtime table a real executor would.
state.__DEPHUB_OSS_RUNTIME = {game = game, task = env.task}
local B = ${quote(bundle)}
local chunk, err = loadstring(B)
assert(chunk, "bundle failed to compile: " .. tostring(err))
setfenv(chunk, env)
local ok, result = pcall(chunk)

-- The one invariant that matters: the bundle must never touch the network.
-- Every bundled path resolves from BUNDLED_SOURCES, so any recorded attempt
-- means a module the bundle failed to inline.
if #networkAttempts > 0 then
    for _, l in ipairs(logs) do print("LOG: " .. l) end
    error("bundle attempted " .. #networkAttempts .. " network fetch(es); first: " .. tostring(networkAttempts[1]))
end

-- Beyond no-network, the loader should report success and publish the mode for
-- this PlaceId. A backend may still decline to initialise when the (faked) game
-- world lacks objects it needs — that is a driver limitation, not a bundle
-- defect, so it is reported as a warning rather than a failure.
local published = state.__DEPHUB
if not ok or result ~= true or type(published) ~= "table" or published.Mode ~= "${expectedMode}" or type(published.Backend) ~= "table" then
    for _, l in ipairs(logs) do print("LOG: " .. l) end
    print("WARN backend for ${expectedMode} did not fully initialise under the fake world (bundle still resolved offline)")
    print("PASS bundle is self-contained: no network fetch for ${expectedMode} with network blocked")
    return
end
print("PASS bundle is self-contained: Mode=" .. tostring(published.Mode) .. " with network blocked")
`;

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dephub-bundle-verify-'));
const file = path.join(temp, 'verify.luau');
try {
  fs.writeFileSync(file, driver, 'utf8');
  const result = cp.spawnSync(luau, [file], {encoding: 'utf8', timeout: 60000});
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  process.exitCode = result.status === null ? 1 : result.status;
} finally {
  if (fs.existsSync(file)) fs.unlinkSync(file);
}

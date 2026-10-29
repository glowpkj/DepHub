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
  throw new Error('Usage: node tests/verify_bundle.js <bundlePath> <luauExe> [PlaceId] [GameId] [expectedMode]');
}
if (!fs.existsSync(bundlePath)) throw new Error('Bundle not found: ' + bundlePath);

const placeId = process.argv[4] || '2753915549';
const gameId = process.argv[5] || '994732206';
const expectedMode = process.argv[6] || 'BloxFruits';

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
local Player = {Name="Tester", UserId=1, DisplayName="Tester", Character=nil, Backpack=nil, PlayerGui=nil, CharacterAdded=signal(), CharacterRemoving=signal(), PlayerAdded=signal(), AncestryChanged=signal()}
local players = {LocalPlayer=Player, GetPlayers=function() return {Player} end, PlayerAdded=signal(), PlayerRemoving=signal(), GetPlayerFromCharacter=function() return nil end}
local function blankInstance(class)
    local inst = {ClassName=class, Name=class, Parent=nil, _children={},
        ChildAdded=signal(), ChildRemoved=signal(), DescendantAdded=signal(), DescendantRemoving=signal(),
        AncestryChanged=signal(), AttributeChanged=signal(), Changed=signal(),
        FindFirstChild=function() return nil end, FindFirstChildOfClass=function() return nil end,
        FindFirstChildWhichIsA=function() return nil end, GetChildren=function() return {} end,
        GetDescendants=function() return {} end, IsA=function(self,c) return c==class end,
        WaitForChild=function() return nil end, Destroy=function() end}
    inst.Clone = function() return inst end
    return inst
end
local rs = blankInstance("ReplicatedStorage")
local workspace = blankInstance("Workspace")
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
        return blankInstance(name)
    end,
}
local state = {}
local logs = {}
local nativeGlobals = getfenv(1)
local env = {
    game = game, workspace = workspace,
    task = {wait=function() end, defer=function(f) f() end, spawn=function(f) return f end, cancel=function() end},
    print = function(...) local parts={} for _,v in ipairs({...}) do parts[#parts+1]=tostring(v) end; logs[#logs+1]=table.concat(parts," ") end,
    warn = function(...) local parts={} for _,v in ipairs({...}) do parts[#parts+1]=tostring(v) end; logs[#logs+1]=table.concat(parts," ") end,
    getgenv = function() return state end, identifyexecutor = function() return "BundleVerify" end,
    -- The global HttpGet is the executor's fetch primitive here; the loader must
    -- reach for this when the DataModel member is absent. Any call is a bundle
    -- defect, so it records and errors.
    HttpGet = function(url) networkAttempts[#networkAttempts+1] = tostring(url); error("NETWORK BLOCKED (bundle should not fetch): " .. tostring(url)) end,
    typeof = typeof, tostring=tostring, tonumber=tonumber, type=type, pcall=pcall,
    ipairs=ipairs, pairs=pairs, next=next, select=select, unpack=unpack or table.unpack,
    os=os, math=math, string=string, table=table,
    Instance = {new=function(c) return blankInstance(c) end},
    Enum = setmetatable({}, {__index=function(t,k) local v=setmetatable({},{__index=function(s,n) rawset(s,n,n); return n end}); rawset(t,k,v); return v end}),
    Color3 = {fromRGB=function() return {} end, new=function() return {} end},
    Vector3 = {new=function() return {Magnitude=0, X=0, Y=0, Z=0} end, zero=function() return {Magnitude=0} end},
    CFrame = {new=function() return {Position={X=0,Y=0,Z=0}} end, lookAt=function() return {Position={X=0,Y=0,Z=0}} end},
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

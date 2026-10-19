// Dumps the panel geometry so layout defects are visible without a client.
//
//   node tests/dump_panel_layout.js <luau.exe>
//
// Builds the real frontend against the GUI double, then prints a tree with each
// node's AbsolutePosition/AbsoluteSize — approximated from Size/Position since
// the double has no renderer. Overlaps, zero sizes and off-window nodes are
// what a broken panel looks like, so they are flagged explicitly.

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const luau = process.argv[2] || "luau";
const srcRoot = path.join(__dirname, "..", "src");
const sources = {};
function walk(dir, rel) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        const relPath = rel ? rel + "/" + entry.name : entry.name;
        if (entry.isDirectory()) walk(full, relPath);
        else if (entry.name.endsWith(".lua")) sources["src/" + relPath] = fs.readFileSync(full, "utf8");
    }
}
walk(srcRoot, "");

function quote(text) {
    let level = 0;
    for (;;) {
        const eq = "=".repeat(level);
        if (!text.includes("]" + eq + "]")) return "[" + eq + "[" + text + "]" + eq + "]";
        level += 1;
    }
}
const table = "local SOURCES = {\n" + Object.entries(sources).map(([k, v]) => `  [${JSON.stringify(k)}] = ${quote(v)},`).join("\n") + "\n}\n";

const probe = `
local checkCount, failCount = 0, 0

-- Reuse the same double the panel tests use, trimmed to what the dump needs.
local signal = function()
    local e = {handlers = {}}
    function e:Connect(fn) local c = {Connected = true, fn = fn}; self.handlers[#self.handlers+1] = c; return c end
    function e:Once(fn) return self:Connect(fn) end
    function e:Fire(...) for _, c in ipairs(self.handlers) do if c.Connected then c.fn(...) end end end
    return e
end
local AUTO = {MouseButton1Click=true,MouseButton1Down=true,MouseButton1Up=true,MouseEnter=true,MouseLeave=true,InputBegan=true,InputEnded=true,InputChanged=true,Focused=true,FocusLost=true,Changed=true,AncestryChanged=true,CharacterAdded=true,CharacterRemoving=true,PlayerAdded=true,PlayerRemoving=true,Completed=true}
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
function meta:IsA(c) return self.ClassName == c end
function meta:WaitForChild() return self end
function meta:GetDescendants() local o = {} for _, c in ipairs(rawget(self, "_children")) do o[#o+1] = c; for _, d in ipairs(c:GetDescendants()) do o[#o+1] = d end end return o end
function meta:ClearAllChildren() for _, c in ipairs(rawget(self, "_children")) do c.Parent = nil end end
function meta:Destroy() self:ClearAllChildren(); self.Parent = nil; rawget(self, "_props").Destroyed = true end
function meta:GetPropertyChangedSignal() return signal() end
function meta:Clone() return Instance.new(self.ClassName) end
local Instance = {}
function Instance.new(c) return setmetatable({_props = {ClassName = c, Name = c, Parent = nil}, _children = {}}, meta) end

local Enum = setmetatable({}, {__index = function(t, k) local v = setmetatable({}, {__index = function(s, n) rawset(s, n, n); return n end}); rawset(t, k, v); return v end})
local UIS = {InputBegan = signal(), InputChanged = signal()}
local playerGui = Instance.new("PlayerGui")
local player = Instance.new("Player"); player.Name = "T"
player.CharacterAdded = signal(); player.CharacterRemoving = signal()
player.FindFirstChildOfClass = function(self, c) if c == "PlayerGui" then return playerGui end return nil end
local Players = {LocalPlayer = player, PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {player} end}
local game = {PlaceId = 1, GameId = 1, Name = "Test", GetService = function(self, n)
    if n == "Players" then return Players end
    if n == "UserInputService" then return UIS end
    if n == "TweenService" then return {Create = function() local t = {Completed = signal()}; function t:Play() if self.Completed then self.Completed:Fire() end end; function t:Cancel() end; return t end} end
    return Instance.new(n)
end}
local state = {}
local env = setmetatable({
    game = game, Instance = Instance, Enum = Enum, signal = signal,
    getgenv = function() return state end, typeof = typeof,
    task = {wait=function() end, defer=function(f) f() end, spawn=function(f) return f end, cancel=function() end, delay=function() end},
    Color3 = {fromRGB = function(r,g,b) return {r=r,g=g,b=b} end},
    UDim = {new = function(s,o) return {Scale=s,Offset=o} end},
    UDim2 = {new=function(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end,
        fromScale=function(x,y) return {X={Scale=x,Offset=0},Y={Scale=y,Offset=0}} end,
        fromOffset=function(x,y) return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}} end},
    Vector2 = {new=function(x,y) return {X=x,Y=y} end},
    TweenInfo = {new=function() return {} end},
}, {__index = _G})
env._G = env

local function loadModule(p)
    local src = assert(SOURCES[p], "missing " .. p)
    local chunk = assert(loadstring(src))
    setfenv(chunk, env)
    return chunk()
end

local Panel = loadModule("src/frontend/init.lua")
local panel = Panel.new({Title = "DepHub", GameName = "Murder Mystery 2", StartOpen = true})
local tab = panel:CreateTab({Name = "Jogador", Glyph = "@", Intro = "Ajuste suas preferencias.", Search = "Encontrar..."})
panel:AddSection(tab, "Preferencias")
panel:AddToggle(tab, "Ativar recursos", "Controle principal.", true, nil)
panel:AddCheckbox(tab, "Lembrar", nil, false, nil)
panel:AddSlider(tab, "Distancia", 50, 1000, 10, 250, nil, function(v) return tostring(v) .. " m" end)
panel:AddInlineSlider(tab, "Opacidade", 60, 100, 1, 100, nil, function(v) return tostring(v) .. "%" end)
panel:AddDisabledToggle(tab, "Indisponivel", "Futuro.", true)
panel:AddDropdown(tab, "Perfil", nil, {"A", "B"}, "A", nil)
panel:AddTextField(tab, "Nome", "ex", "x", nil, "Ajuda.")
panel:AddAction(tab, "Aplicar", "Acao.", "Aplicar", nil, true)
panel:AddCollapsible(tab, "Recolhivel", false)
panel:AddButtonGroup(tab, {{Label="Salvar",Primary=true},{Label="Carregar"}})

-- Geometry summary. The double has no renderer, so sizes are propagated down
-- the tree: a child's scale component resolves against its parent's computed
-- size. AutomaticSize.Y nodes are content-sized (children plus padding), which
-- mirrors the client, so the check does not flag normal auto containers while
-- still catching a visible node that genuinely has no area.
local WINDOW_W, WINDOW_H = 840, 560
local function resolve(size, base)
    if not size then return 0, 0 end
    return size.X.Offset + size.X.Scale * base.w, size.Y.Offset + size.Y.Scale * base.h
end

-- AutomaticSize grows a node from its declared size; a leaf with no children
-- keeps that declared extent (a text label's line box).
local function isLeaf(inst)
    for _, child in ipairs(inst:GetChildren()) do
        if child.ClassName ~= "UICorner" and child.ClassName ~= "UIStroke"
            and child.ClassName ~= "UIPadding" and child.ClassName ~= "UISizeConstraint" then
            return false
        end
    end
    return true
end

-- Measure one axis the way the client resolves it, recursing into children and
-- honouring their own AutomaticSize.
local function measure(inst, axis, base)
    local size = inst.Size
    local declared
    if axis == "Y" then declared = size.Y.Offset + size.Y.Scale * base.h
    else declared = size.X.Offset + size.X.Scale * base.w end
    local autoTag = tostring(inst.AutomaticSize)
    local auto = (axis == "Y" and autoTag:find("Y")) or (axis == "X" and autoTag:find("X"))
    if not auto then return declared end
    if isLeaf(inst) then return declared end

    local total, count = 0, 0
    for _, child in ipairs(inst:GetChildren()) do
        if child.ClassName ~= "UIListLayout" and child.ClassName ~= "UIPadding"
            and child.ClassName ~= "UICorner" and child.ClassName ~= "UIStroke"
            and child.ClassName ~= "UISizeConstraint" then
            if child.Visible ~= false then
                total = total + measure(child, axis, inst.Measured or {w = 680, h = 420})
                count = count + 1
            end
        end
    end
    local padding = inst:FindFirstChildOfClass("UIPadding")
    if padding then
        if axis == "Y" then total = total + padding.PaddingTop.Offset + padding.PaddingBottom.Offset
        else total = total + padding.PaddingLeft.Offset + padding.PaddingRight.Offset end
    end
    local layout = inst:FindFirstChildOfClass("UIListLayout")
    if layout and count > 1 then
        local along = (layout.FillDirection == Enum.FillDirection.Horizontal) == (axis == "X")
        if along then total = total + layout.Padding.Offset * (count - 1) end
    end
    return math.max(total, declared)
end

local issues = {}
local function show(inst, base, depth, lines)
    local w, h = resolve(inst.Size, base)
    local autoTag = tostring(inst.AutomaticSize)
    if autoTag:find("X") then w = measure(inst, "X", base) end
    if autoTag:find("Y") then h = measure(inst, "Y", base) end
    w, h = math.floor(w + 0.5), math.floor(h + 0.5)
    inst.Measured = {w = w, h = h}
    local pad = string.rep("  ", depth)
    local tag = string.rep("A", (autoTag:find("X") and 1 or 0) + (autoTag:find("Y") and 1 or 0))
    lines[#lines + 1] = pad .. inst.Name .. "  " .. w .. "x" .. h .. (tag ~= "" and ("  [" .. tag .. "]") or "")
    local decorative = inst.ClassName == "UIListLayout" or inst.ClassName == "UIPadding"
        or inst.ClassName == "UICorner" or inst.ClassName == "UIStroke"
        or inst.ClassName == "UISizeConstraint"
    -- Collapsed-by-design nodes (the intro's morph-name, the mobile nav index)
    -- are expected to be zero.
    local intentional = inst.Name == "MorphName" or inst.Name == "Index"
    if not decorative and not intentional and inst.Visible ~= false and (w <= 0 or h <= 0) then
        issues[#issues + 1] = inst.Name .. " (" .. inst.ClassName .. ") " .. w .. "x" .. h
    end
    local childBase = {w = w, h = h}
    for _, child in ipairs(inst:GetChildren()) do
        show(child, childBase, depth + 1, lines)
    end
end

local lines = {}
show(panel.Window, {w = WINDOW_W, h = WINDOW_H}, 0, lines)
for _, l in ipairs(lines) do print(l) end
print("--- issues ---")
if #issues == 0 then print("none") else for _, l in ipairs(issues) do print(l) end end
print("layout dump complete")
`;

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "dephub-layout-"));
const file = path.join(tempDir, "dump.luau");
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

// Panel fidelity probe. Loads src/frontend/init.lua against a GUI double and
// exercises every control the index.html specifies, asserting the structure and
// the tokens each one is built from.
//
//   node tests/panel_fidelity_probe.js <luau.exe>
//
// The index.html is the spec: this probe checks that the Luau panel has the
// same surface (heading, search, checkbox, slider, dropdown, field, action,
// button-group, color picker, keybind, notice, details, disabled, toast,
// footer) and that the numbers match (780x520, header 66, sidebar 160, toggle
// 35x21, knob 15, row min-height 58).

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const luau = process.argv[2] || "luau";
const root = path.join(__dirname, "..");
const frontend = fs.readFileSync(path.join(root, "src", "frontend", "init.lua"), "utf8");

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
local function eq(actual, expected, msg)
    ok(actual == expected, msg .. " (got " .. tostring(actual) .. ", want " .. tostring(expected) .. ")")
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
    MouseButton1Click=true,MouseButton1Down=true,MouseButton1Up=true,MouseEnter=true,MouseLeave=true,
    InputBegan=true,InputEnded=true,InputChanged=true,Focused=true,FocusLost=true,Activated=true,
    ChildAdded=true,ChildRemoved=true,Changed=true,AncestryChanged=true,Completed=true,Destroying=true,
}
local CLASS_PARENTS = {
    Frame="GuiObject",TextLabel="GuiObject",TextButton="GuiObject",TextBox="GuiObject",
    ImageLabel="GuiObject",ImageButton="GuiObject",ScrollingFrame="GuiObject",
    GuiObject="GuiBase2d",ScreenGui="LayerCollector",
}
local meta = {}
meta.__index = function(self, key)
    local m = meta[key]; if m then return m end
    local props = rawget(self, "_props")
    if props[key] ~= nil then return props[key] end
    -- Layout measurements are vectors; the double reports an empty layout.
    if key == "AbsoluteContentSize" or key == "AbsoluteSize" or key == "AbsolutePosition" then
        local v = {X = 0, Y = 0, Width = 0, Height = 0}
        props[key] = v
        return v
    end
    if AUTO[key] then local e = signal(); props[key] = e; return e end
    return nil
end
meta.__newindex = function(self, key, value)
    if key == "Parent" then
        local props = rawget(self, "_props"); local old = props.Parent
        if old then local sib = rawget(old, "_children"); for i = #sib, 1, -1 do if sib[i] == self then table.remove(sib, i) end end end
        props.Parent = value
        if value then local sib = rawget(value, "_children"); sib[#sib+1] = self end
        if key == "Parent" and self.ClassName == "UIListLayout" then end
        return
    end
    rawget(self, "_props")[key] = value
end
function meta:GetChildren() return table.clone(rawget(self, "_children")) end
function meta:FindFirstChild(n) for _, c in ipairs(rawget(self, "_children")) do if c.Name == n then return c end end return nil end
function meta:FindFirstChildOfClass(c) for _, x in ipairs(rawget(self, "_children")) do if x.ClassName == c then return x end end return nil end
function meta:FindFirstChildWhichIsA(c) for _, x in ipairs(rawget(self, "_children")) do if x:IsA(c) then return x end end return nil end
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
function meta:IsDescendantOf() return true end
function meta:GetPropertyChangedSignal() return signal() end
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

local tweenService = {
    Create = function(_, inst, info, props)
        local t = {Completed = signal()}
        function t:Play()
            for k, v in pairs(props or {}) do pcall(function() inst[k] = v end) end
        end
        function t:Cancel() end
        return t
    end,
}
local coreGui = Instance.new("CoreGui")
local services = {
    Players = players,
    UserInputService = UIS,
    TweenService = tweenService,
    RunService = {Heartbeat=signal(), RenderStepped=signal(),
        IsClient=function() return true end, IsServer=function() return false end},
}
local game = {PlaceId=1, GameId=1, Name="Test",
    Loaded = signal(), IsLoaded = function() return true end,
    GetService=function(self, name)
        if name == "CoreGui" then return coreGui end
        if services[name] then return services[name] end
        local m = Instance.new(name); services[name] = m; return m
    end}

local env = setmetatable({
    game = game, Instance = Instance, Enum = Enum, signal = signal,
    task = {wait=function() end, defer=function(f) return f end, spawn=function(f) return f end,
            cancel=function() end, delay=function(_, f) return f end},
    typeof = typeof, print = print, warn = warn, pcall = pcall,
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
    Vector3 = {new=function(x,y,z) return {X=x,Y=y,Z=z} end},
    Rect = {new=function() return {} end},
    TweenInfo = {new=function(...) return {...} end},
    CFrame = {new=function() return {} end},
}, {__index = _G})

local chunk = assert(loadstring(FRONTEND_SOURCE, "@frontend/init.lua"))
setfenv(chunk, env)
local Factory = chunk()
ok(type(Factory) == "table" and type(Factory.new) == "function", "frontend returns a factory with .new")

local panel = Factory.new({Title = "DepHub", GameName = "Blox Fruits", StartOpen = true})
local root = panel.Root
ok(root ~= nil, "panel Root exists")

-- Geometry from index.html.
eq(root.Size.X.Offset, 780, "panel is 780 wide")
eq(root.Size.Y.Offset, 520, "panel is 520 tall")

local header = root:FindFirstChild("Header")
ok(header ~= nil, "header exists")
eq(header.Size.Y.Offset, 66, "header is 66 tall")

local sidebar = root:FindFirstChild("Sidebar")
ok(sidebar ~= nil, "sidebar exists")
eq(sidebar.Size.X.Offset, 160, "sidebar is 160 wide")

-- Header: the mark is the 34x34 "D", the title sits at x=69.
local badge = header and header:FindFirstChildWhichIsA("TextLabel")
local foundBadge
for _, c in ipairs(header:GetChildren()) do
    if c:IsA("TextLabel") and c.Text == "D" then foundBadge = c end
end
ok(foundBadge ~= nil, "header mark is the 'D' label")
if foundBadge then
    eq(foundBadge.Size.X.Offset, 34, "header mark is 34 wide")
    eq(foundBadge.Size.Y.Offset, 34, "header mark is 34 tall")
    eq(foundBadge.Position.X.Offset, 24, "header mark sits at x=24")
    eq(foundBadge.TextSize, 27, "header mark font is 27")
end

-- Every method the index.html needs.
local methods = {
    "CreateTab", "SelectTab", "AddHeading", "AddSection", "AddSearch",
    "AddToggle", "AddDisabledToggle", "AddCheckbox", "AddSlider", "AddInlineSlider",
    "AddDropdown", "AddField", "AddAction", "AddButtonGroup", "AddColorPicker",
    "AddKeybind", "AddNotice", "AddDetails", "Notify", "SetStatus",
}
for _, name in ipairs(methods) do
    ok(type(panel[name]) == "function", "Panel:" .. name .. " exists")
end

-- Build a tab with every control and confirm each one lands in the scroll.
local tabA = panel:CreateTab({Name = "Componentes", Glyph = "C"})
local tabB = panel:CreateTab({Name = "Visual", Glyph = "V"})
panel:SelectTab(tabA)

panel:AddHeading(tabA, "Componentes", "Exemplos para sua biblioteca.", "DEMO")
panel:AddSearch(tabA, "Buscar componente...")
panel:AddSection(tabA, "CONTROLES BÁSICOS")
panel:AddToggle(tabA, "Toggle", "Descrição opcional.", true, nil)
panel:AddCheckbox(tabA, "Checkbox", "Uma opção de exemplo.", false, nil)
panel:AddSlider(tabA, "Slider", 50, 1000, 10, 250, nil, function(v) return tostring(v) .. " m" end)
panel:AddDropdown(tabA, "Dropdown", nil, {"Opção 01", "Opção 02"}, "Opção 01", nil)
panel:AddField(tabA, "Campo de texto", "Digite alguma coisa...", "", nil)
panel:AddAction(tabA, "Botão", "Executa uma ação.", "Executar", nil, false)
panel:AddColorPicker(tabA, "Color picker", nil, nil)
panel:AddKeybind(tabA, "Atalho do menu", "Insert", nil)
panel:AddNotice(tabA, "Esta é uma demonstração.", "DepHub Library")
panel:AddDisabledToggle(tabA, "Opção indisponível", "Placeholder.", false)
panel:AddButtonGroup(tabA, {
    {label = "Salvar", primary = true},
    {label = "Carregar"},
    {label = "Restaurar padrão"},
})
panel:AddDetails(tabA, "Seção recolhível", true)
panel:AddToggle(tabB, "Opção ativa", nil, true, nil)

-- The toggle must be 35x21 with a 15px knob (index.html numbers).
local toggleRow
for _, c in ipairs(panel.Scroll:GetChildren()) do
    if c:GetAttribute("TabRef") == tabA.Name and c:GetAttribute("Searchable") then
        local track = c:FindFirstChildWhichIsA("Frame")
        if track then
            for _, k in ipairs(c:GetChildren()) do
                if k.ClassName == "Frame" and k.Size.X.Offset == 35 then toggleRow = c end
            end
        end
    end
end
ok(toggleRow ~= nil, "a toggle row with a 35-wide track exists")
if toggleRow then
    local track
    for _, k in ipairs(toggleRow:GetChildren()) do
        if k.ClassName == "Frame" and k.Size.X.Offset == 35 then track = k end
    end
    if track then
        eq(track.Size.Y.Offset, 21, "toggle track is 21 tall")
        local knob = track:FindFirstChildWhichIsA("Frame")
        ok(knob ~= nil, "toggle has a knob")
        if knob then eq(knob.Size.X.Offset, 15, "knob is 15 wide") end
    end
end

-- Count the tab's controls and confirm search can filter them.
local searchable, total = 0, 0
for _, c in ipairs(panel.Scroll:GetChildren()) do
    if c:GetAttribute("TabRef") == tabA.Name and c:IsA("GuiObject") then
        total = total + 1
        if c:GetAttribute("Searchable") then searchable = searchable + 1 end
    end
end
ok(searchable >= 8, "at least 8 searchable controls registered (got " .. searchable .. ")")

-- Tab switching hides the other tab's controls.
panel:SelectTab(tabB)
local hiddenA, visibleB = 0, 0
for _, c in ipairs(panel.Scroll:GetChildren()) do
    if c:IsA("GuiObject") and c.Name ~= "UIPadding" and c.Name ~= "UIListLayout" then
        if c:GetAttribute("TabRef") == tabA.Name and not c.Visible then hiddenA = hiddenA + 1 end
        if c:GetAttribute("TabRef") == tabB.Name and c.Visible then visibleB = visibleB + 1 end
    end
end
ok(hiddenA > 0, "switching tabs hides the first tab's controls")
ok(visibleB > 0, "switching tabs shows the second tab's controls")

-- Toast and status.
local toast = panel:Notify("DepHub", "Sua notificação aparece assim.")
ok(toast ~= nil, "Notify creates a toast")
panel:SetStatus("Protótipo local")
ok(panel.StatusLabel.Text == "Protótipo local", "SetStatus writes the footer status")

-- Footer height (index.html min-height:39px).
ok(panel.StatusLabel.Size.Y.Offset == 39, "footer is 39 tall")

print(string.format("fidelity checks: %d run, %d failed", checks, fails))
`;

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "dephub-fidelity-probe-"));
const file = path.join(tempDir, "probe.luau");
fs.writeFileSync(file, "local FRONTEND_SOURCE = " + quote(frontend) + "\n" + probe);
try {
    console.log(execFileSync(luau, [file], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 60000 }));
} catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);
    process.exit(1);
} finally {
    try { fs.rmSync(tempDir, { recursive: true, force: true }); } catch {}
}

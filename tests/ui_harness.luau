-- Behavioral tests only: this is not a Roblox rendering/physics emulator.
local passed = 0
local function check(condition, message)
    assert(condition, message)
    passed += 1
    print("PASS " .. message)
end
local function signal()
    local event = {connections = {}}
    function event:Connect(fn)
        local connection = {Connected = true, fn = fn}
        function connection:Disconnect() self.Connected = false end
        self.connections[#self.connections + 1] = connection
        return connection
    end
    function event:Fire(...)
        local current = table.clone(self.connections)
        for _, connection in ipairs(current) do if connection.Connected then connection.fn(...) end end
    end
    return event
end
local Enum = setmetatable({}, {__index = function(t, category)
    local values = setmetatable({}, {__index = function(sub, key) local value = {Name = key}; rawset(sub, key, value); return value end})
    rawset(t, category, values); return values
end})
local Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local UDim = {new = function(scale, offset) return {Scale = scale, Offset = offset} end}
local UDim2 = {}
function UDim2.new(x, ox, y, oy) return {X = UDim.new(x, ox), Y = UDim.new(y, oy)} end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local Color3 = {}
local colorMeta = {__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end}
function Color3.new(r, g, b) return setmetatable({R = r, G = g, B = b, __color = true}, colorMeta) end
function Color3.fromRGB(r, g, b) return Color3.new(r/255, g/255, b/255) end
local builtinTypeof = typeof
local function typeof(value) return type(value) == "table" and value.__color and "Color3" or builtinTypeof(value) end
local TweenInfo = {new = function(...) return {} end}
local task = {spawn = function(fn, ...) return fn(...) end, defer = function(fn, ...) return fn(...) end, delay = function() end}
local events = {InputBegan=true,InputChanged=true,InputEnded=true,MouseEnter=true,MouseLeave=true,MouseButton1Click=true,FocusLost=true,Changed=true}
local guiClasses = {Frame=true,ScrollingFrame=true,TextLabel=true,TextButton=true,TextBox=true,ImageLabel=true}
local methods = {}
local instanceMeta = {}
function instanceMeta:__index(key)
    if methods[key] then return methods[key] end
    if key == "AbsoluteSize" then return self._props.TestSize or Vector2.new(410, 62) end
    if key == "AbsolutePosition" then return Vector2.new(0, 0) end
    if events[key] then
        if not self._signals[key] then self._signals[key] = signal() end
        return self._signals[key]
    end
    return self._props[key]
end
function instanceMeta:__newindex(key, value)
    if key == "Parent" then
        local old = self._props.Parent
        if old then local index = table.find(old._children, self); if index then table.remove(old._children, index) end end
        self._props.Parent = value
        if value then value._children[#value._children + 1] = self end
    else
        local old = self._props[key]
        self._props[key] = value
        if old ~= value and self._signals[key] then self._signals[key]:Fire() end
    end
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
    local output = {}
    for _, child in ipairs(self._children) do output[#output+1] = child; for _, sub in ipairs(child:GetDescendants()) do output[#output+1] = sub end end
    return output
end
function methods:IsA(class) return class == self.ClassName or (class == "GuiObject" and guiClasses[self.ClassName] == true) end
function methods:FindFirstChild(name) for _, child in ipairs(self._children) do if child.Name == name then return child end end end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing child " .. name) end
function methods:FindFirstChildOfClass(class) for _, child in ipairs(self._children) do if child:IsA(class) then return child end end end
function methods:GetPropertyChangedSignal(key) if not self._signals[key] then self._signals[key] = signal() end; return self._signals[key] end
function methods:IsDescendantOf(ancestor)
    local parent = self.Parent
    while parent do if parent == ancestor then return true end; parent = parent.Parent end
    return false
end
function methods:GetAttributes() if self.FailRead then error("Simulated read failure") end; return table.clone(self._attributes) end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:SetAttribute(key, value)
    if self.FailKey == key then self.FailKey = nil; error("Simulated attribute failure") end
    self._attributes[key] = value
    self.WriteCount = (self.WriteCount or 0) + 1
end
function methods:Destroy()
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    for _, event in pairs(self._signals) do for _, connection in ipairs(event.connections) do connection:Disconnect() end end
    self.Parent = nil
end
local Instance = {}
function Instance.new(class)
    return setmetatable({_props={ClassName=class, Name=class, Visible=true, Size=UDim2.fromOffset(0,0), Position=UDim2.fromOffset(0,0)},_children={},_signals={},_attributes={}}, instanceMeta)
end
local player = Instance.new("Player")
player.Name, player.DisplayName = "Tester", "Tester"
local playerGui = Instance.new("PlayerGui"); playerGui.Name, playerGui.Parent = "PlayerGui", player
local camera = Instance.new("Camera"); camera.ViewportSize = Vector2.new(1440,900)
local workspace = Instance.new("Workspace"); workspace.CurrentCamera = camera
local input = Instance.new("UserInputService")
local services = {Players={LocalPlayer=player}, UserInputService=input, RunService={}, TweenService={}}
function services.TweenService:Create(object, info, props)
    return {Play=function() for key,value in pairs(props) do object[key]=value end end}
end
local game = {GetService=function(_, name) return assert(services[name], name) end}
-- INSERT_MODULES
-- INSERT_FRUIT_VFX_TESTS

local library = modules.window
local window = library.new("DepHub", "Universal", "")
check(window.CurrentTab == "Dashboard", "dashboard created and selected")
check(window.TabContainer.Name == "CategoryRail", "horizontal category rail replaces sidebar")
check(not window.Sidebar, "legacy sidebar is absent")
check(window.Window.Size.X.Offset == 1040, "desktop window has maximum width")
local tab = window:CreateTab("Movimento", nil, "Motion tools")
local calls = 0
local toggle = tab:CreateToggle("WalkSpeed", "Speed control", false, function(v) calls += 1 end)
local slider = tab:CreateSlider("Speed value", "Set speed", 16, 250, 20, function() end)
local dropdown = tab:CreateDropdown("Target", "Choose target", {"Head","Root"}, "Head", function() end)
local inputBox = tab:CreateInput("Message", "Text", "Type", function() end)
local picker = tab:CreateColorPicker("ESP color", "Custom RGB", Color3.fromRGB(210,43,67), function() end)
tab:CreateKeybind("Key", "Set key", Enum.KeyCode.RightControl, function() end)
tab:CreateButton("Run", function() end)
tab:CreateDivider("Tools")
tab:CreateLabel("All ready")
tab:CreateCard("Info", "Information", 80)
check(toggle.Frame.Parent == tab.LeftColumn and slider.Frame.Parent == tab.RightColumn, "desktop distributes controls into two columns")
toggle:SetValue(true)
check(toggle:GetValue() and calls == 1, "toggle callback and state")
toggle:SetValue(false, true)
check(not toggle:GetValue() and calls == 1, "toggle silent update")
slider:SetValue(900)
check(slider:GetValue() == 250, "slider clamps maximum")
slider:SetValue(2)
check(slider:GetValue() == 16, "slider clamps minimum")
dropdown:SetValue("Root")
check(dropdown:GetValue() == "Root", "dropdown setter")
inputBox:SetValue("Hello")
check(inputBox:GetValue() == "Hello", "input setter")
picker:SetValue(Color3.fromRGB(12,34,56))
check(math.abs(picker:GetValue().G - 34/255) < 0.001, "color picker supports arbitrary RGB, not just presets")
window.DashboardStats.Ping:SetColor(Color3.fromRGB(0,255,0))
check(window.DashboardStats.Ping.Label.TextColor3.G == 1, "RT3 SetColor API preserved")
window:SelectTab("Movimento")
check(tab.Page.Visible and not window.DashboardTab.Page.Visible, "tab navigation toggles correct page")
window.SearchBox.Text = "walkspeed"
check(toggle.Frame.Visible and not slider.Frame.Visible, "search filters actual controls")
window.SearchBox.Text = "unknown-feature"
check(window.EmptySearch.Visible, "search empty state")
window.SearchBox.Text = ""
check(slider.Frame.Visible and not window.EmptySearch.Visible, "clearing search restores controls")
camera.ViewportSize = Vector2.new(390,844)
check(window.Compact and window.Window.Size.X.Offset == 366, "phone viewport fits without desktop minimum")
for _, record in ipairs(tab.Records) do check(record.Object.Parent == tab.LeftColumn, "phone control retains order in one column " .. record.Order) end
check(not tab.RightColumn.Visible, "second column hidden on phone")
check(window.SearchHolder.Size.X.Scale == 1, "mobile search moves into full-width row")
camera.ViewportSize = Vector2.new(1440,900)
check(not window.Compact and tab.RightColumn.Visible, "desktop layout restores after rotation")
window:SetOpen(false)
check(not window.Window.Visible and window.ToggleButton.Visible, "minimize shows reopen control")
window.ToggleButton.MouseButton1Click:Fire()
check(window.Window.Visible and not window.ToggleButton.Visible, "reopen control works")
window:SetReleases({{Version="0.0.3", Date="2026-08-30", Changes={"New interface"}}})
check(window.DashboardStats.Version:GetValue() == "0.0.3", "release dashboard API")
local oldCamera = camera
local grouped = window:CreateTab("Visual", nil, "Grouped controls")
local esp = grouped:CreateSection("Player ESP")
local ambient = grouped:CreateSection("Ambiente")
local nameToggle = esp:CreateToggle("Nomes", "Mostrar jogadores", true, function() end)
local hpToggle = esp:CreateToggle("Vida", "Mostrar vida", true, function() end)
ambient:CreateToggle("Fullbright", "Clarear mapa", false, function() end)
check(nameToggle.Frame.Parent == hpToggle.Frame.Parent, "related controls stay together inside sections")
check(esp.Frame.Parent ~= ambient.Frame.Parent, "desktop places groups in distinct columns")
window:SelectTab("Visual")
window.SearchBox.Text = "nomes"
check(nameToggle.Frame.Visible and not hpToggle.Frame.Visible and not ambient.Frame.Visible, "search filters individual controls within sections")
window.SearchBox.Text = ""
check(hpToggle.Frame.Visible and ambient.Frame.Visible, "search restores all section controls")
camera.ViewportSize = Vector2.new(390,844)
check(esp.Frame.Parent == ambient.Frame.Parent, "phone stacks complete sections in order")
inputBox.Frame.TestSize = Vector2.new(280,62)
inputBox.Frame:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(inputBox.Frame.Size.Y.Offset == 102, "narrow input control reflows below its label")
dropdown.Frame.TestSize = Vector2.new(280,62)
dropdown.Frame:GetPropertyChangedSignal("AbsoluteSize"):Fire()
local dropdownButton = dropdown.Frame:FindFirstChildOfClass("TextButton")
dropdownButton.MouseButton1Click:Fire()
check(dropdown.Frame.Size.Y.Offset > 102, "dropdown expands inside layout without overlay clipping")
dropdown:SetValue("Head")
check(dropdown.Frame.Size.Y.Offset == 102, "dropdown collapse respects narrow layout")
local colorButton = picker.Frame:FindFirstChildOfClass("TextButton")
colorButton.MouseButton1Click:Fire()
check(picker.Frame.Size.Y.Offset == 126, "RGB editor expands the color card")
camera = Instance.new("Camera"); camera.ViewportSize = Vector2.new(600,800)
workspace.CurrentCamera = camera
check(window.Compact, "camera replacement rebinds responsive listener")
local external = table.clone(window.Connections)
window:Destroy()
check(window.Destroyed and window.ScreenGui == nil, "destroy removes UI")
for _, connection in ipairs(external) do assert(not connection.Connected, "connection leak") end
check(true, "all tracked connections disconnected")
-- INSERT_GAME_SMOKES
print("UI TESTS COMPLETE: " .. passed .. " checks passed")

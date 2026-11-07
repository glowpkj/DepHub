-- DepHub UI library (RedzLib v2.0.1, vendored).
--
-- This is the single UI library every backend in DepHub renders through. It is
-- kept in-tree (not fetched at runtime) so editing this file edits the UI.
--
-- It was originally shipped minified, with single-letter top-level names and no
-- comments. The minified body is preserved exactly (it is load-bearing and has
-- been proven to render identically), but the file-wide top-level symbols have
-- been renamed to meaningful names and the file is split into labelled sections
-- so it can be read and maintained. Everything below the "SECTION" banners is
-- the original logic, untouched except for those renames.
--
-- Public API (the part DepHub consumes):
--   local lib = Library                     -- this module's export
--   local win = lib:MakeWindow({Title=, SubTitle=, ScriptFolder=})
--   local tab = win:MakeTab({Title=, Icon=})   -- Icon is an icon NAME resolved
--                                              --   through GetIconByName (see
--                                              --   src/redz-icons.lua) or a raw
--                                              --   asset id; an unknown name (or
--                                              --   an emoji) leaves the tab with
--                                              --   no icon
--   -- The window's starting size is read from lib.Default.UISize (a UDim2) at
--   -- MakeWindow time; MakeWindow itself takes no Size option.
--   tab:AddSection(title)                   -- visual header (string only)
--   tab:AddToggle/Slider/Button/TextBox/Dropdown/Paragraph/Keybind/...
--   win:Notify({Title=, Content=, Icon=, Duration=})
--   win:Dialog({Title=, Content=, Options={...}})
--   win:SelectTab(n|tab) / win:GetTabByTitle(t) / win:Minimize() / win:Dialog()
--   tab:Select() / tab:SetVisible(bool) / tab:Destroy()
--   lib:GetIconByName(name) / lib:SetTheme(name) / lib:SetUIScale(scale)
--
-- The adapter that maps this API onto DepHub's own shell contract lives in
-- src/core/ui-adapter.lua; backends never call RedzLib directly.

-- ===========================================================================
-- SECTION: Executor shims and services
-- Safe wrappers for the executor-only globals (some executers lack them) and
-- the handful of Roblox services the library talks to. `Services` resolves and
-- caches each service lazily through cloneref so the library never holds a
-- second, unclonable reference to a service.
-- ===========================================================================

local clonerefShim = cloneref or (function(...) return ... end)

local deleteFolderSafe = delfolder or deletefolder
local deleteFileSafe = delfile or deletefile
local makeFolderSafe = makefolder
local writeFileSafe = writefile
local readFileSafe = readfile

local Services = setmetatable({}, {
__index = function(g,h)
rawset(g,h,clonerefShim(game:GetService(h)))
return rawget(g,h)
end
})

local UserInputService = Services.UserInputService
local GuiService = Services.GuiService
local TweenService = Services.TweenService
local HttpService = Services.HttpService
local RunService = Services.RunService
local PlayersService = Services.Players

local GuiParent = (gethui or function() return Services.CoreGui end)()

-- ===========================================================================
-- SECTION: Built-in themes
-- The theme tables (colours, fonts, icons per theme name). `Themes` is the
-- registry the rest of the library reads and `SetTheme` switches between them.
-- ===========================================================================

local Themes={
Darker={
Colors={
Background=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(25,25,25)),
ColorSequenceKeypoint.new(0.50,Color3.fromRGB(32.5,32.5,32.5)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(25,25,25))
},
Primary=Color3.fromRGB(88,101,242),
OnPrimary=Color3.fromRGB(61,67,135),
ScrollBar=Color3.fromRGB(1,76,105),
Stroke=Color3.fromRGB(45,45,45),

Error=Color3.fromRGB(255,102,102),
Icons=Color3.fromRGB(232,233,235),

JoinButton=Color3.fromRGB(37,128,69),
Link=Color3.fromRGB(40,150,255),

Dialog={
Background=Color3.fromRGB(28,28,28)
},
Buttons={
Holding=Color3.fromRGB(34,34,34),
Default=Color3.fromRGB(28,28,30)
},
Border={
Holding=Color3.fromRGB(60,60,60),
Default=Color3.fromRGB(38,38,38),
},
Text={
Default=Color3.fromRGB(255,255,255),
Dark=Color3.fromRGB(200,200,200),
Darker=Color3.fromRGB(175,175,175),
},
Slider={
SliderBar=Color3.fromRGB(1,76,105),
SliderNumber=Color3.fromRGB(232,233,235),
},
Dropdown={
Holder=Color3.fromRGB(30,30,30),
}
},
Icons={
Error="rbxassetid://10709752996",
Button="rbxassetid://10709791437",
Close="rbxassetid://10747384394",
TextBox="rbxassetid://15637081879",
Search="rbxassetid://10734943674",
Keybind="rbxassetid://10734982144",
Dropdown={
Open="rbxassetid://10709791523",
Close="rbxassetid://10709790948"
}
},
Font={
Normal=Enum.Font.BuilderSans,
Medium=Enum.Font.BuilderSansMedium,
Bold=Enum.Font.BuilderSansBold,
ExtraBold=Enum.Font.BuilderSansExtraBold,
SliderValue=Enum.Font.FredokaOne
},
BackgroundTransparency=0.03
}
}

local LightTheme=table.clone(Themes.Darker)
LightTheme.Colors=table.clone(Themes.Darker.Colors)
LightTheme.Colors.Text=table.clone(Themes.Darker.Colors.Text)
LightTheme.Colors.Buttons=table.clone(Themes.Darker.Colors.Buttons)
LightTheme.Colors.Border=table.clone(Themes.Darker.Colors.Border)
LightTheme.Colors.Dialog=table.clone(Themes.Darker.Colors.Dialog)
LightTheme.Colors.Slider=table.clone(Themes.Darker.Colors.Slider)
LightTheme.Colors.Dropdown=table.clone(Themes.Darker.Colors.Dropdown)
LightTheme.Colors.Background=ColorSequence.new{
ColorSequenceKeypoint.new(0,Color3.fromRGB(248,248,250)),
ColorSequenceKeypoint.new(0.5,Color3.fromRGB(238,239,243)),
ColorSequenceKeypoint.new(1,Color3.fromRGB(248,248,250))
}
LightTheme.Colors.Stroke=Color3.fromRGB(205,207,214)
LightTheme.Colors.OnPrimary=Color3.fromRGB(65,74,160)
LightTheme.Colors.ScrollBar=Color3.fromRGB(130,137,158)
LightTheme.Colors.Icons=Color3.fromRGB(65,68,78)
LightTheme.Colors.Text.Default=Color3.fromRGB(35,36,42)
LightTheme.Colors.Text.Dark=Color3.fromRGB(75,77,86)
LightTheme.Colors.Text.Darker=Color3.fromRGB(105,108,118)
LightTheme.Colors.Buttons.Default=Color3.fromRGB(231,232,237)
LightTheme.Colors.Buttons.Holding=Color3.fromRGB(218,220,228)
LightTheme.Colors.Border.Default=Color3.fromRGB(210,212,219)
LightTheme.Colors.Border.Holding=Color3.fromRGB(185,188,198)
LightTheme.Colors.Dialog.Background=Color3.fromRGB(250,250,252)
LightTheme.Colors.Slider.SliderBar=LightTheme.Colors.Primary
LightTheme.Colors.Dropdown.Holder=Color3.fromRGB(244,245,248)
Themes.Light=LightTheme

for Library,ViewportSize in Themes do
ViewportSize.Name=Library
table.freeze(ViewportSize)
end


-- ===========================================================================
-- SECTION: Library identity and defaults
-- The module table itself (Information/Defaults/Themes/Connections/Options/Tabs)
-- and the aliases the rest of the file uses.
-- ===========================================================================
local Library={
ReducedMotion=false,
Information={
Version="v2.0.1",
GitHubOwner="tlredz"
},
Default={
Theme="Darker",
UISize=UDim2.fromOffset(900,500),
TabSize=160
},

Themes=Themes,
CurrentTheme=Themes.Darker,

Connections={},
Options={},
Tabs={}
}

Library.Info=Library.Information
Library.Save=Library.Default


-- ===========================================================================
-- SECTION: Small utilities
-- Signal connection helper, theme path reader, theme value/collection appliers,
-- and the wrapped file writer used to persist flags.
-- ===========================================================================
-- DepHub: a escala da UI e fixa em 1:1. As dimensoes em pixels permanecem
-- iguais entre resolucoes, sem encolher em telas menores ou crescer em telas maiores.
-- Pixel sizing is independent of the camera viewport.
local u=function(signal,callback,method,scope)
local connection=signal[method or "Connect"](signal,callback)
table.insert(Library.Connections,connection)
if scope and typeof(scope)=="Instance" then
local cleanup
cleanup=scope.Destroying:Connect(function()
if connection.Connected then connection:Disconnect() end
for index=#Library.Connections,1,-1 do
if Library.Connections[index]==connection or Library.Connections[index]==cleanup then
 table.remove(Library.Connections,index)
end
end
end)
table.insert(Library.Connections,cleanup)
end
return connection
end


local v={}
v.__index=v local w=function(

w, x)
for y in x:gmatch"[^%.]+"do
w=w[y]
end

return w end local x=function(


x, y, z, A)
if not A then
A=Library.CurrentTheme
end

x[y]=w(A,if type(z)=="function"then z()else z)end local y=function(


y, z, A)
for B,C in A do
x(z,B,C,y)
end end local z=function(


z, A)
if makeFolderSafe then
local B=z:split"/"
B[#B]=nil

local C=table.concat(B,"/")

if C~=""and(isfolder==nil or not isfolder(C))then
makeFolderSafe(C)
end
end

writeFileSafe(z,A)end


local A=false


-- ===========================================================================
-- SECTION: Constants
-- Scale bounds and shared control constants.
-- ===========================================================================
local B={
MAX_SCALE=1.6,
MIN_SCALE=0.6,

TEXTBOX={
PLACEHOLDER_TEXT="Input"
}
}

function v:add(C,D)
self.Descendants[D]=C

if self.IS_RENDERING then
y(Library.CurrentTheme,C,D)
end
end

function v:remove(instance)
if typeof(instance)=="Instance" then
self.Descendants[instance]=nil
for _,descendant in ipairs(instance:GetDescendants()) do
self.Descendants[descendant]=nil
end
end
end

function v:update()
if self.IS_RENDERING and not self.UPDATED_OBJECTS then
local C=Library.CurrentTheme
self.UPDATED_OBJECTS=true

for InstanceFactory,createInstance in self.Descendants do
local F=typeof(createInstance)
if F=="table"then createInstance:update()continue end

y(C,createInstance,InstanceFactory)
end
end
end

function v:destroy()
local C=self.Parent and table.find(self.Parent.Descendants,self)

if C then
table.remove(self.Parent.Descendants,C)
end

table.clear(self.Descendants)
setmetatable(self,nil)
end

function v:changeRendering(C)
if self.IS_RENDERING~=C then
self.IS_RENDERING=C
self.UPDATED_OBJECTS=false
end
end

function v:new()
local C=setmetatable({
IS_RENDERING=true,
UPDATED_OBJECTS=false,
Descendants={},
Parent=self.Descendants~=nil and self or nil
},v)

if self.Descendants then
table.insert(self.Descendants,C)
end

return C
end

local C=v:new()


-- ===========================================================================
-- SECTION: Instance factory
-- createInstance builds a Roblox instance and applies a declarative table of
-- properties/elements/theme tags/children; InstanceFactory holds the element
-- templates and value setters it uses.
-- ===========================================================================
local InstanceFactory,createInstance={}do
local F={}

local G={}do
G.ElementsTable={
Corner=function(H)
return createInstance("UICorner",{
CornerRadius=H or UDim.new(0,8)
})
end,
Stroke=function(H,I)
return createInstance("UIStroke",{
Color=H or Color3.fromRGB(60,60,60),
Thickness=I or 1
})
end,
Image=function(H)
return createInstance("ImageLabel",{
Image=H or"",
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1)
})
end,
Button=function()
return createInstance("TextButton",{
Text="",
Size=UDim2.fromScale(1,1),
AutoButtonColor=false
})
end,
Padding=function(H,I,J,K)
return createInstance("UIPadding",{
PaddingLeft=H or UDim.new(0,10),
PaddingRight=I or UDim.new(0,10),
PaddingTop=J or UDim.new(0,10),
PaddingBottom=K or UDim.new(0,10)
})
end,
ListLayout=function(H)
return createInstance("UIListLayout",{
Padding=H or UDim.new(0,5)
})
end,
Text=function(H)
return createInstance("TextLabel",{
BackgroundTransparency=1,
Text=H or""
})
end,
Gradient=function(H)
return createInstance("UIGradient",{
Color=H
})
end
}

function G:Create(H,I,...)
local J=self.ElementsTable[I]

if J then
local K=J(...)
K.Parent=H
return K
end
end
end

local H={}

function H:Childs(I)
for J=1,#I do
I[J].Parent=self
end
end

function H:Elements(I)
for J,K in pairs(I)do
if type(K)=="table"then
InstanceFactory.SetProperties(G:Create(self,J),K)
else
G:Create(self,J,K)
end
end
end

function H:ThemeTag(I)
local J=I.OBJECTS
I.OBJECTS=nil
return(J or C):add(self,I)
end

function InstanceFactory:SetProperties(I)
for J,K in pairs(I)do
if H[J]then
H[J](self,K)
else
self[J]=K
end
end
end

function InstanceFactory:SetValues(...)
local I=self

for J,K in{...}do
local L=typeof(K)

if L=="table"then
InstanceFactory.SetProperties(I,K)
else
I[if L=="string"then"Name"else"Parent"]=K
end
end

return I
end

local I

function InstanceFactory:Draggable(frame,scaleObject,lerpFactor,clampPosition)
local activeInput=nil
local startPointer=nil
local startPosition=nil
local latestPointer=nil
local renderConnection=nil
local moved=false
local smoothing=lerpFactor or 0.28

local latestTarget=nil
local function pointerPosition(input)
local inset=GuiService:GetGuiInset()
if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseMovement then
return UserInputService:GetMouseLocation()-inset
end
return input.Position-inset
end

local function stopDrag()
if not activeInput then return end
activeInput=nil
startPointer=nil
startPosition=nil
latestPointer=nil
if latestTarget and frame.Parent then frame.Position=latestTarget end
latestTarget=nil
if renderConnection then
renderConnection:Disconnect()
renderConnection=nil
end
A=false
end

u(frame.InputBegan,function(input)
if A or activeInput then return end
if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
activeInput=input
startPointer=pointerPosition(input)
latestPointer=startPointer
startPosition=frame.Position
moved=false
A=true
renderConnection=RunService.RenderStepped:Connect(function(deltaTime)
if not activeInput or not frame.Parent then
stopDrag()
return
end
local delta=latestPointer-startPointer
if math.abs(delta.X)>4 or math.abs(delta.Y)>4 then
moved=true
frame:SetAttribute("DragMoved",true)
end
local factor=1-math.pow(1-math.clamp(smoothing,0,1),math.max(deltaTime,0)*60)
local target
if clampPosition then
target=clampPosition(
startPosition.X.Scale,startPosition.X.Offset+delta.X/math.max(scaleObject.Scale,0.001),
startPosition.Y.Scale,startPosition.Y.Offset+delta.Y/math.max(scaleObject.Scale,0.001)
)
else
local viewport=I.AbsoluteSize
local size=frame.AbsoluteSize
local anchorPosition=frame.AbsolutePosition+Vector2.new(size.X*frame.AnchorPoint.X,size.Y*frame.AnchorPoint.Y)
local targetAnchor=anchorPosition+delta
local minX=size.X*frame.AnchorPoint.X
local minY=size.Y*frame.AnchorPoint.Y
local maxX=math.max(minX,viewport.X-size.X*(1-frame.AnchorPoint.X))
local maxY=math.max(minY,viewport.Y-size.Y*(1-frame.AnchorPoint.Y))
target=UDim2.fromOffset(math.clamp(targetAnchor.X,minX,maxX),math.clamp(targetAnchor.Y,minY,maxY))
end
latestTarget=target
frame.Position=frame.Position:Lerp(target,factor)
end)
end,nil,frame)

u(UserInputService.InputChanged,function(input)
if not activeInput then return end
if activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement then
latestPointer=pointerPosition(input)
elseif activeInput.UserInputType==Enum.UserInputType.Touch and input.UserInputType==Enum.UserInputType.Touch then
latestPointer=input.Position
end
end,nil,frame)

u(UserInputService.InputEnded,function(input)
if not activeInput then return end
if activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1 then
stopDrag()
elseif activeInput.UserInputType==Enum.UserInputType.Touch and input.UserInputType==Enum.UserInputType.Touch then
stopDrag()
end
end,nil,frame)
end

function InstanceFactory.new(J,...)
return InstanceFactory.SetValues(Instance.new(J),...)
end

createInstance=InstanceFactory.new
end local F=function(

F)
if F==nil then
return{}
end

if type(F)~="function"and type(F)~="table"then
error(`Failed to get Callback: 'function', or 'table' expected, got {typeof(F)}`,2)
end

if type(F)~="function"then
local G=F[1]
local H=F[2]

F=function(I)
G[H]=I
end
end

return table.pack(F)end local G=function(


G, ...)
for H=1,#G do
local callback=G[H]
task.spawn(function(...)
local ok,err=pcall(callback,...)
if not ok then warn("DepHub callback error: "..tostring(err)) end
end,...)
end end


local H="redz-library-v5"
local I=GuiParent:FindFirstChild(H)

if not I then
I=createInstance("ScreenGui",H,GuiParent,{
IgnoreGuiInset=true
})
end local ReducedMotion=false
local J=function(

J, K, L, M, ...)
if ReducedMotion then M=0 end
local N=TweenInfo.new(M,Enum.EasingStyle.Quint,...)

return TweenService:Create(J,N,{
[K]=L
})end local K=function(


K)
local L={}
for M=1,#K do
rawset(L,K[M],true)
end
return L end


local L=K(string.split"\n\t,_:;()[]#&=!. \"'*^<>$")local M=function(

M)
return string.gsub(M:lower(),".",function(N)
return L[N]and""or N
end)end local N=function(


N)
local O,P,Q=tostring(N),"",0

for R=#O,1,-1 do
P=O:sub(R,R)..P
Q+=1

if R>1 and Q%3==0 then
P=","..P
end
end

return P end local O=function(


O)
local P="rbxassetid://"
return O:sub(1,#P)==P end local P=function(


P)
return P end local Q=function(


Q)
local R=math.floor(Q/60)
local S=math.floor(Q/60/60)
Q=math.floor((Q-(R*60))*10)/10
R=R-(S*60)

if S>0 then
return`{S}h {R}m {math.floor(Q)}s`
elseif R>0 then
return`{R}m {math.floor(Q)}s`
else
return tostring(Q)
end end



-- ===========================================================================
-- SECTION: Internal registries
-- Per-window state: the tab registry, per-tab control lists, tab transitions and
-- containers, and the Window/Tab/Option prototype tables the library exposes.
-- ===========================================================================
local R={}do
local S={}
local T={}
local U={}
local V={}

local W
local X
local Y
local Z
local _
local aa
local ab
local ac
local ad
local ae

local af=""
local activeNotifications={}
local notificationHistory={}

local ag={SelectedTab=1,Minimized=false}
ag.__index=ag

local ah={}
ah.__index=ah

local ai={}
ai.__index=ai

local aj={}
aj.__index=aj

local ak={}do local al=function()

local al={}
al.__index=function(am,an)
return al[an]or rawget(ai,an)
end

return al end


local am=al()
ak.TextBox=am

local an=al()
ak.Toggle=an

local ao=al()
ak.Slider=ao

local ap=al()
ak.Dropdown=ap

local aq=al()
ak.Keybind=aq
local colorPickerPrototype=al()
ak.ColorPicker=colorPickerPrototype

local ar=al()
ak.Dialog=ar local as=function()


Z.Closed=true
Z.Closing=false
setmetatable(Z,nil)

Z=nil
aa.Parent=nil end local at=function()



if Z~=nil then
Z:Close()
end end


function ar:NewOption(au)
local av=au[1]or au.Name or au.Title
local aw=F(au[2]or au.Callback)

table.insert(aw,at)

assert(type(av)=="string",`"Dialog.NewOption.Name". 'string' expected, got {typeof(av)}`)

local ax=createInstance("TextButton",{
AutoButtonColor=false,
Size=UDim2.fromScale(0.2,1),
BackgroundTransparency=1,
TextSize=10,
Text=av,
Elements={
Corner=UDim.new(1,0)
},
ThemeTag={
OBJECTS=self.ThemeGroup,
BackgroundColor3="Colors.Buttons.Default",
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})

local ay=J(ax,"BackgroundTransparency",0,0.3)
local az=J(ax,"BackgroundTransparency",1,0.3)

u(ax.MouseLeave,function()az:Play()end,nil,ax)
u(ax.MouseEnter,function()ay:Play()end,nil,ax)
u(ax.Activated,function()G(aw)end,nil,ax)

ax.Parent=aa.Template.Options
end

function ar:Close(au)
if self.Closed or self.Closing or Z~=self then
return nil
end

self.Closing=true
local fadeDuration=ReducedMotion and 0 or 0.16
local fadeTweens={}
local backdropTween=J(aa,"BackgroundTransparency",1,fadeDuration)
local bodyTween=J(self.TEMPLATE,"BackgroundTransparency",1,fadeDuration)
table.insert(fadeTweens,backdropTween)
table.insert(fadeTweens,bodyTween)
for _,object in ipairs(self.TEMPLATE:GetDescendants()) do
if object:IsA("GuiObject") then
local tween=J(object,"BackgroundTransparency",1,fadeDuration)
table.insert(fadeTweens,tween)
end
if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
local tween=J(object,"TextTransparency",1,fadeDuration)
table.insert(fadeTweens,tween)
end
if object:IsA("ImageLabel") or object:IsA("ImageButton") then
local tween=J(object,"ImageTransparency",1,fadeDuration)
table.insert(fadeTweens,tween)
end
if object:IsA("UIStroke") then
local tween=J(object,"Transparency",1,fadeDuration)
table.insert(fadeTweens,tween)
end
end
for _,tween in ipairs(fadeTweens) do tween:Play() end
local sizeTween=J(self.TEMPLATE,"Size",self.NEW_SIZE,0.1)
sizeTween:Play()
if au then
sizeTween.Completed:Wait()
task.wait(fadeDuration)
if self.ThemeGroup then self.ThemeGroup:destroy() self.ThemeGroup=nil end
as()
else
u(sizeTween.Completed,function()
task.wait(fadeDuration)
if self.ThemeGroup then self.ThemeGroup:destroy() self.ThemeGroup=nil end
as()
end,nil,self.TEMPLATE)
end
end

function ar.new(au,av)
return setmetatable({
TITLE_LABEL=av,
DESCRIPTION_LABEL=au,
Content=au.Text,
Title=av.Text,

Closed=false,
Closing=false,
Kind="Dialog"
},ar)
end

function ap:SetValue(value)
if type(value)=="table" then
for _,option in ipairs(self.DROPDOWN_OPTIONS) do
self.SELECT_DROPDOWN_OPTION(option.Name,false)
end
for name,selected in pairs(value) do
self.SELECT_DROPDOWN_OPTION(name,selected==true)
end
elseif type(value)=="string" or type(value)=="number" then
self.SELECT_DROPDOWN_OPTION(tostring(value),true)
else
error(`"Dropdown.SetValue". 'string', 'number', or 'table' expected, got {typeof(value)}`,2)
end
return self
end

function ap:SetEnabled(au)
if type(au)=="boolean" then
self.Enabled=au
if self.DESTROY_ELEMENT then self.DESTROY_ELEMENT.Active=au end
return self
end
assert(type(au)=="table",`"Dropdown.SetEnabled[param 1]". 'boolean' or 'table' expected, got {typeof(au)}`)
assert(type(self.SET_ENABLED_OPTIONS)=="function",`"Dropdown.SetEnabled". option registry is unavailable`)
self.SET_ENABLED_OPTIONS(au)
return self
end

function ap:Clear()
self.CLEAR_DROPDOWN()
end

function ap:NewOptions(...)
self:Clear()
self:Add(...)
end

function ap:GetOptionsCount()
return#self.DROPDOWN_OPTIONS
end

function ap:Remove(...)
local au={...}
assert(#au>0,"'Dropdown.Remove' requires one or more options.")

for av,aw in au do
self.REMOVE_DROPDOWN_OPTION(aw)
end
end

function ap:Add(...)
local au={...}
assert(#au>0,"'Dropdown.Add' requires one or more options.")

for av,aw in au do
self.ADD_DROPDOWN_OPTION(aw)
end
end

function ap.new(au,av,aw,ax,ay)
return setmetatable({
CALLBACKS=ay,

DESTROY_ELEMENT=av,
VISIBLE_ELEMENT=av,

TITLE_LABEL=aw,
DESCRIPTION_LABEL=ax,
Description=ax.Text,
Title=aw.Text,

Parent=au,
Kind="Dropdown"
},ap)
end

function ao:SetValue(au)
assert(type(au)=="number",`"Slider.SetValue". 'number' expected, got {typeof(au)}`)

if self.Value~=au then
self.WHEN_VALUE_CHANGED(au)
end
end

function ao.new(au,av,aw,ax,ay)
return setmetatable({
CALLBACKS=ay,

DESTROY_ELEMENT=av,
VISIBLE_ELEMENT=av,

TITLE_LABEL=aw,
DESCRIPTION_LABEL=ax,
Description=ax.Text,
Title=aw.Text,

Parent=au,
Kind="Slider"
},ao)
end

function an:SetValue(au)
assert(type(au)=="boolean",`"Toggle.SetValue". 'boolean' expected, got {typeof(au)}`)

if self.Value~=au then
self.Value=au
self.WHEN_VALUE_CHANGED(au)
end
end

function an.new(au,av,aw,ax,ay,az)
return setmetatable({
CALLBACKS=az,
WHEN_VALUE_CHANGED=ay,

DESTROY_ELEMENT=av,
VISIBLE_ELEMENT=av,

TITLE_LABEL=aw,
DESCRIPTION_LABEL=ax,
Description=ax.Text,
Title=aw.Text,

Parent=au,
Kind="Toggle"
},an)
end

function am:SetText(au)
assert(type(au)=="string",`"TextBox.SetText". 'string' expected, got {typeof(au)}`)

self.TEXTBOX.Text=au
return self
end

function am:SetPlaceholder(au)
assert(type(au)=="string",`"TextBox.SetPlaceholder". 'string' expected, got {typeof(au)}`)

self.TEXTBOX.PlaceholderText=au
return self
end

function am:CaptureFocus()
self.TEXTBOX:CaptureFocus()
return self
end

function am:Clear()
self.TEXTBOX.Text=""
return self
end

function am:SetTextFilter(au)
if au~=nil then
assert(type(au)=="function",`"TextBox.SetTextFilter[param 1]". 'function', or 'nil' expected, got {typeof(au)}`)
end

self.TEXTBOX_TEXT_FILTER=au
return self
end

function am.new(au,av,aw,ax,ay,az)
return setmetatable({
Title=av.Text,
Description=aw.Text,
DESCRIPTION_LABEL=aw,
TITLE_LABEL=av,

CALLBACKS=az,
DESTROY_ELEMENT=ax,
VISIBLE_ELEMENT=ax,

TEXTBOX=ay,
BUTTON=ax,

Parent=au,
Kind="TextBox"
},am)
end

am.Set=am.SetText
an.Set=an.SetValue
ao.Set=ao.SetValue
end
-- Build one tab button: the clickable row (TextButton), its title label, the
-- selection marker frame, the content container, and the icon. The icon is an
-- ImageLabel showing the resolved asset id (or nothing when there is no icon).
local al=function(

al, am, an)
local ao=createInstance("TextButton","Button",an,{
Size=UDim2.new(1,0,0,24),
AutoButtonColor=false,
BackgroundTransparency=1,
Text="",
Elements={
Corner=UDim.new(0,6)
},
ThemeTag={
BackgroundColor3="Colors.Buttons.Default"
},
Childs={
createInstance("TextLabel","Title",{
BackgroundTransparency=1,
Font=Enum.Font.GothamMedium,
Text=am.Title,
TextSize=10,
TextXAlignment=Enum.TextXAlignment.Left,
TextTransparency=0.3,
TextTruncate=Enum.TextTruncate.AtEnd,
ThemeTag={
TextColor3="Colors.Text.Default"
}
})
}
})

local ap=createInstance("Frame",ao,{
Position=UDim2.new(0,1,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
Size=UDim2.fromOffset(4,4),
BackgroundTransparency=1,
ThemeTag={
BackgroundColor3="Colors.Primary"
},
Elements={
Corner=UDim.new(0.5,0)
}
})

local aq=createInstance("ScrollingFrame","Container",{
Size=UDim2.new(1,0,1,0),
Position=UDim2.new(0,0,1),
AnchorPoint=Vector2.new(0,1),
ScrollBarThickness=UserInputService.TouchEnabled and 5 or 1.5,
BackgroundTransparency=1,
ScrollBarImageTransparency=0.2,
AutomaticCanvasSize=Enum.AutomaticSize.Y,
ScrollingDirection=Enum.ScrollingDirection.Y,
BorderSizePixel=0,
CanvasSize=UDim2.new(),
ThemeTag={
ScrollBarImageColor3="Colors.ScrollBar"
},
Elements={
Padding={
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingTop=UDim.new(0,10),
PaddingBottom=UDim.new(0,10)
},
ListLayout={
Padding=UDim.new(0,5)
}
}
})

-- DepHub: icone da aba. Agora so existe o caminho de ImageLabel: o Icon ja vem
-- do MakeTab resolvido pelo catalogo da propria biblioteca (asset id ou nil). Um
-- Icon nil (nome desconhecido / sem icone) simplesmente nao desenha nada e a aba
-- fica sem icone -- era o pedido ("se nao tiver, deixa sem"). O caminho de emoji
-- (TextLabel) foi removido: nao se usa mais emoji nos icones.
local ar=createInstance("ImageLabel",ao,{
Position=UDim2.new(0,8,0.5),
Size=UDim2.new(0,13,0,13),
AnchorPoint=Vector2.new(0,0.5),
BackgroundTransparency=1,
ImageTransparency=0.3,
Image=am.Icon or""
})
local as=function()
local as=string.sub(ar.Image,1,13)=="rbxassetid://"
local at=ao.Title
ar.Visible=as
at.Size=UDim2.new(1,as and-25 or-15,1)
at.Position=UDim2.fromOffset(as and 25 or 15)end

u(ar:GetPropertyChangedSignal"Image",as,nil,ao)
u(ao.MouseEnter,function()
if not al.Selected then
J(ao,"BackgroundTransparency",0.92,0.12):Play()
J(ao,"BackgroundColor3",w(Library.CurrentTheme,"Colors.Buttons.Holding"),0.12):Play()
end
end,nil,ao)
u(ao.MouseLeave,function()
if not al.Selected then
J(ao,"BackgroundTransparency",1,0.12):Play()
J(ao,"BackgroundColor3",w(Library.CurrentTheme,"Colors.Buttons.Default"),0.12):Play()
end
end,nil,ao)
u(ao.MouseButton1Down,function()
J(ao,"BackgroundTransparency",0.88,0.06):Play()
end,nil,ao)
u(ao.MouseButton1Up,function()
J(ao,"BackgroundTransparency",al.Selected and 0.85 or 0.92,0.08):Play()
end,nil,ao)
as()

return ao,aq,ap,ar end local am=function(


am, an, ao, ap, kind)
local aq=createInstance("TextLabel",{
TextXAlignment=Enum.TextXAlignment.Left,
TextTruncate=Enum.TextTruncate.AtEnd,
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.new(1,-20),
Position=UDim2.fromScale(0,0.5),
AnchorPoint=Vector2.new(0,0.5),
BackgroundTransparency=1,
TextSize=11,
ThemeTag={
OBJECTS=C,
TextColor3="Colors.Text.Default",
Font="Font.Medium"
}
})

local ar=V[am]
local as=T[am].Container

local at=createInstance("TextLabel",{
TextXAlignment=Enum.TextXAlignment.Left,
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.new(1,-20),
Position=UDim2.new(0,12,0,15),
BackgroundTransparency=1,
TextWrapped=true,
TextSize=9,
RichText=true,
ThemeTag={
OBJECTS=ar,
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})

local au={OBJECTS=ar}
if kind~="Paragraph" then
au.BackgroundColor3="Colors.Buttons.Default"
end

local av=createInstance("TextButton","Option",{
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.new(1,0,0,25),
AutoButtonColor=false,
Active=kind~="Paragraph",
BackgroundTransparency=kind=="Paragraph" and 1 or 0,
Text="",
ThemeTag=au,
Elements={
Corner=UDim.new(0,6)
},
Childs={
createInstance("Frame","Holder",{
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
Size=ap,
Elements={
ListLayout={
SortOrder=Enum.SortOrder.LayoutOrder,
VerticalAlignment=Enum.VerticalAlignment.Center,
Padding=UDim.new(0,2)
},
Padding={
PaddingBottom=UDim.new(0,5),
PaddingTop=UDim.new(0,5)
}
},
Childs={aq,at}
})
}
})

if am._CurrentSection then
local section=am._CurrentSection
section.Items[#section.Items+1]=av
if section.Collapsed then av.Visible=false end
end

local aw=av.Holder local ax=function(

ax, ay)
if ay then
if _ then
local az=w(Library.CurrentTheme,"Colors.Buttons.Default")
_.Theme.BackgroundColor3="Colors.Buttons.Default"
J(_.Button,"BackgroundColor3",az,0.2):Play()
end

_={
Button=av,
Theme=au
}
end

au.BackgroundColor3=ax
J(av,"BackgroundColor3",w(Library.CurrentTheme,ax),0.2):Play()end


if kind~="Paragraph" then
u(av.MouseLeave,function()ax("Colors.Buttons.Default",false)end,nil,av)
u(av.MouseEnter,function()ax("Colors.Buttons.Holding",true)end,nil,av)
end

u(at:GetPropertyChangedSignal"Text",function()
local ay=#at.Text>0

if at.Visible~=ay then
local az=ay and 0 or 0.5
at.Visible=ay
aw.Position=UDim2.fromScale(0,az)
aw.AnchorPoint=Vector2.new(0,az)
end
end,nil,av)

aq.Text=an
at.Text=ao or""

av.Parent=as

return av,aq,at end local an=function(


an, ao)
if type(ao)~="table"then
error(`"Tab.Add{an}[Configs]". 'table' expected, got {typeof(ao)}`,2)
end

local ap=ao[1]or ao.Name or ao.Title
local aq=ao.Desc or ao.Description

assert(type(ap)=="string",`"Tab.Add{an}.Title". 'string' expected, got {typeof(ap)}`)

if aq~=nil and type(aq)~="string"then
error(`"Tab.Add{an}.Description". 'string', or 'nil' expected, got {typeof(aq)}`,2)
end

return ap,aq or""end local ao=function(


ao, ap)
if ap~=nil and type(ap)~="string"then
error(`"Tab.Add{ao}.Flag". 'nil', or 'string' expected, got {typeof(ap)}`)
end

return ap end local ap=function()



local ap=160

local aq={
Corner=UDim.new(0,6),
Stroke={
ThemeTag={
Color="Colors.Stroke"
}
},
Gradient={
Rotation=45,
ThemeTag={
Color="Colors.Background"
}
}
}

-- DepHub: o popup do dropdown e um singleton reaproveitado por TODOS os
-- dropdowns. O pai original aqui era o global `OutBox`, que o refactor deixou
-- sem binding (== nil) -- por SetValues, um argumento posicional nil vira
-- `Parent=nil`, entao o popup nascia solto com o frame "Dropdown" preso no
-- Position/Size literais (fromOffset(50,50) / fromOffset(160,100)). Sem dono
-- ele nao renderiza, mas assim que algo o parenta (ar.Parent=Y) ele aparece
-- exatamente nesse canto fixo, por cima do conteudo -- o "box escuro com a
-- lupa" que o usuario reportou. O overlay real da biblioteca e o local `aa`
-- (OutBox de notificacao, tela cheia e ja escalado); usar ele como pai base
-- mantem o popup dentro do overlay correto e fora do fluxo de conteudo.
local ar=createInstance("TextButton",aa,{
ZIndex=1000,
Size=UDim2.fromScale(1,1),
BackgroundTransparency=1,
Active=true,
Text=""
})
-- DepHub: nasce sempre fechado -- so aparece quando um dropdown e aberto de
-- verdade (aT faz ar.Parent=Y).
ar.Visible=false

local as=createInstance("Frame","Dropdown",ar,{
ZIndex=1001,
Size=UDim2.fromOffset(ap,100),
Position=UDim2.fromOffset(50,50),
Elements=aq,
Active=true,
ThemeTag={
BackgroundTransparency="BackgroundTransparency"
}
})

local at=createInstance("TextButton","Search",as,{
ZIndex=1002,
Position=UDim2.new(1,5,0,5),
Size=UDim2.new(0,25,0,25),
AutomaticSize=Enum.AutomaticSize.X,
Active=true,
Elements=aq,
Text="",
ThemeTag={
BackgroundTransparency="BackgroundTransparency"
},
Childs={
createInstance("UIPadding",{
PaddingLeft=UDim.new(0,5),
PaddingRight=UDim.new(0,5),
PaddingBottom=UDim.new(0,5),
PaddingTop=UDim.new(0,5)
}),
createInstance("UIListLayout",{
Padding=UDim.new(0,5),
FillDirection=Enum.FillDirection.Horizontal
}),
createInstance("TextBox","SearchBox",{
Size=UDim2.fromScale(0,1),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
Visible=false,
PlaceholderText="Search...",
ClearTextOnFocus=false,
Text="",
Elements={
Corner=UDim.new(0,6)
},
ThemeTag={
BackgroundColor3="Colors.Stroke",
TextColor3="Colors.Text.Default",
Font="Font.ExtraBold"
}
}),
createInstance("ImageLabel","SearchIcon",{
Size=UDim2.fromScale(1,1),
SizeConstraint=Enum.SizeConstraint.RelativeYY,
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=1,
ThemeTag={
BackgroundColor3="Colors.Stroke",
ImageColor3="Colors.Icons",
Image="Icons.Search"
}
})
}
})

local au=createInstance("ScrollingFrame",as,{
ZIndex=1002,
Size=UDim2.new(1,-6,1,-6),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
ScrollBarThickness=UserInputService.TouchEnabled and 6 or 3,
BackgroundTransparency=1,
BorderSizePixel=0,
CanvasSize=UDim2.new(),
ScrollingDirection=Enum.ScrollingDirection.Y,
AutomaticCanvasSize=Enum.AutomaticSize.Y,
Active=true,
ThemeTag={
OBJECTS=C,
ScrollBarImageColor3="Colors.ScrollBar"
},
Elements={
Padding={
PaddingLeft=UDim.new(0,8),
PaddingRight=UDim.new(0,8),
PaddingTop=UDim.new(0,5),
PaddingBottom=UDim.new(0,5)
},
ListLayout={
Padding=UDim.new(0,4)
}
}
})

local av=at.SearchIcon
local aw=at.SearchBox

local ax=130

local ay=J(as,"Size",UDim2.fromOffset(ap,0),0.2)
local az=J(aw,"Size",UDim2.new(0,ax-30,1,0),0.3)
local aA=J(aw,"Size",UDim2.new(0,0,1,0),0.2)

local aB={}
local dropdownThemeGroup=nil
local aC=false
local aD=false
local aE
local aF
local aG
local aH
local aI

local aJ=0
local SEARCH_RESULT_COUNT=0

local aK=25
local aL=(aK*12)+10
local aM=5 local aN=function(

aN)
-- Altura do popup, em pixels de tela crus (o popup vive fora do UIScale do
-- painel; dividir por `ad.Scale` aqui encolhia a lista e podia zerar a altura).
local aO=I.AbsoluteSize.Y
return math.min((aK*math.max(aN,0.5))+10,aL,aO/1.75)end local aO=function()



local aO=as.AbsolutePosition
local aP=as.AbsoluteSize

local mousePosition=UserInputService:GetMouseLocation()-GuiService:GetGuiInset()
local aQ=Vector2.new(mousePosition.X,mousePosition.Y)

local aR=aQ.X>=aO.X and aQ.X<=(aO.X+aP.X)
local aS=aQ.Y>=aO.Y and aQ.Y<=(aO.Y+aP.Y)

return aR and aS end local aP=function(


aP, aQ)
-- DepHub: o popup e parentado na pasta `Dropdowns`, que e filha do ScreenGui --
-- FORA do UIScale que envolve o painel. Toda a conta aqui tem que ser em
-- coordenada de TELA crua (AbsolutePosition/AbsoluteSize ja vem em pixels de
-- tela). A versao original dividia tudo por `ad.Scale` como se o popup vivesse
-- dentro do conteudo escalado: com a escala de ~1.2 o popup caia em
-- `campo.X / 1.2` -- ~193 px a esquerda do campo num campo em X=1157 -- e a
-- altura ia para o eixo errado. O popup abria "deslocado / fora do lugar" (e
-- sob o scissor do painel, invisivel). Aqui nao ha mais divisao por escala.
local aR=aI.AbsolutePosition
local aS=aI.AbsoluteSize
local aT=I.AbsoluteSize
local aV=aN(aP)

local aW=aT.X
local aX=aT.Y
local aY=aR.X
local aZ=aR.Y
local a_=aS.X
local a0=aS.Y

local a1=aZ+(a0/2)
local a2=a1-(aV/2)

local a3=aM
local a4=aX-aV-aM

local a5=math.clamp(a2,a3,a4)

local a6=Vector2.new(0,0)

if a5>(aX*0.7)then
a6=Vector2.new(0,1)
a5=math.min(a1+(aV/2),aX-aM)
end

local a7=math.clamp(
aY,
aM,
aW-as.Size.X.Offset-(aM*2)-at.AbsoluteSize.X
)

return Vector2.new(a7,a5),a6 end local aQ=function(...)



local aQ,aR=aP(...)

as.AnchorPoint=aR
as.Position=UDim2.fromOffset(aQ.X,aQ.Y)end local aR=function()



if not aD then return end

aD=false

aw.Text=""
aA:Play()
aA.Completed:Wait()
aw.Visible=false end local aS=function()



if aD then return end

aD=true

aw.Visible=true
az:Play()

aw:CaptureFocus()

local aS=as.AbsoluteSize
local aT=I.AbsoluteSize
local aV=as.AnchorPoint

-- Coordenadas cruas de tela (o popup vive fora do UIScale do painel): a
-- largura do campo de busca ja esta em pixels reais, sem multiplicar por escala.
local aW=ax

local aX=as.AbsolutePosition.X

local aY=aX+aS.X+5+aW

if aY>aT.X-(aM)then
local aZ=(aT.X-aS.X-aW-5-(aM))

aZ=math.max(aZ,aM)

J(as,"Position",UDim2.fromOffset(aZ,as.Position.Y.Offset),0.3):Play()
end end local aT=function(


aT)
if not aC then
aE=aT
ar.Parent=Y
-- DepHub: abre de fato -- Visible e controlado aqui e no close (aU), nao pelo
-- pai, para o singleton nunca ficar visivel fora de um open real.
ar.Visible=true
return true
end end local aU=function()



if aC then return end

if aE then
aE()
aE=nil
end

task.spawn(aR)
aC=true
ay:Play()
ay.Completed:Wait()
ar.Parent=nil
-- DepHub: fecha de fato -- esconde junto com o desparent, senao o Visible=true
-- do open ficaria grudado e o box reapareceria no proximo parent.
ar.Visible=false
aC=false end local aV=function()



if aw:IsFocused()then
aJ=os.clock()
return nil
end

if(os.clock()-aJ)>=0.3 and not aO()then
aU()
end end local aW=function()



for aW,aX in aB do
aW.Parent=nil
aB[aW]=nil
end end local aX=function(


aX, aY)
aX.Selected=aY

if aX.Instance then
local aZ=aX.Instance
local a_=aZ.TextLabel
local a0=aZ.Frame

local a1=aY and 0 or(aH and 0.8 or 1)
local a2=aY and 0 or 0.4
local a3=UDim2.fromOffset(4,aY and 14 or 4)

if aZ.Parent then
J(a0,"BackgroundTransparency",a1,0.35):Play()
J(a_,"TextTransparency",a2,0.35):Play()
J(a0,"Size",a3,0.35):Play()
else
a_.TextTransparency=a2
a0.BackgroundTransparency=a1
a0.Size=a3
end
end end local aY=function(


aY)
if aw.Visible==false or not aY then
local aZ=aG and#aG or 0
as.Size=UDim2.fromOffset(ap,aN(aZ))
return nil
end

if aY then
local aZ=aY.Instance
local a_=M(aw.Text)
aZ.Visible=#a_==0 or aY.SearchText:find(a_,1,true)~=nil

if aZ.Visible~=false then
SEARCH_RESULT_COUNT+=1
as.Size=UDim2.fromOffset(ap,aN(SEARCH_RESULT_COUNT))
end
end end local aZ=function(


aZ, a_, a0, a1)
local a2=true

if a_=="+"or a_=="-"then
a2=aZ.Selected==(a_=="+")
a0=a0:sub(2,-1)
end

return a2 and a1:find(a0,1,true)~=nil end local a_=function(


a_, a0)
local a1=createInstance("TextButton",{
ZIndex=1003,
Size=UDim2.new(1,0,0,21),
AutoButtonColor=false,
Text="",
Elements={
Corner=UDim.new(0,4)
},
ThemeTag={
OBJECTS=dropdownThemeGroup,
BackgroundColor3="Colors.Buttons.Default"
},
Childs={
createInstance("Frame",{
ZIndex=1004,
Position=UDim2.new(0,1,0.5),
Size=UDim2.new(0,4,0,4),
BackgroundTransparency=1,
AnchorPoint=Vector2.new(0,0.5),
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag={
OBJECTS=dropdownThemeGroup,
BackgroundColor3="Colors.Primary"
}
}),
createInstance("TextLabel",{
ZIndex=1004,
Size=UDim2.fromScale(1,1),
Position=UDim2.fromOffset(10,0),
TextXAlignment=Enum.TextXAlignment.Left,
BackgroundTransparency=1,
TextTransparency=0.4,
Text=a_.DisplayName,
TextSize=9,
ThemeTag={
OBJECTS=dropdownThemeGroup,
Font="Font.Bold",
TextColor3="Colors.Text.Default"
}
})
}
})

u(a1.Activated,function()
if a_.Enabled==false then return end
if ar.Parent then
aF(a_)
end
end,nil,a1)

a_.SearchText=M(a_.DisplayName)
a_.Instance=a1
a1.Active=a_.Enabled~=false
if a_.Enabled==false then
 a1.BackgroundTransparency=0.45
 local optionLabel=a1:FindFirstChildOfClass("TextLabel")
 if optionLabel then optionLabel.TextTransparency=0.7 end
end

if a0 then
local a3=aw.Text

if#a3>0 then
local a4=string.sub(a3,1,1)
local a5=M(aw.Text)
a1.Visible=aZ(a_,a4,a5,a_.SearchText)
end

a1.Parent=au
aY(a_)
end

aX(a_,a_.Selected)end local a0=function(


a0)
aW()
aG=a0

for a1=1,#a0 do
local a2=a0[a1]
local a3=a2.Instance

if a3==nil then
a_(a2)
a3=a2.Instance
end

a3.Parent=au
aB[a3]=true
end

aQ(#a0)
J(as,"Size",UDim2.fromOffset(ap,aN(#a0)),0.3):Play()end local a1=function()



local a1=aw.Text
local a2=string.sub(a1,1,1)
local a3=M(a1)
local a4=#a3==0
local a5=0

for a6=1,#aG do
local a7=aG[a6]
local a8=a4 or aZ(a7,a2,a3,a7.SearchText)
a7.Instance.Visible=a8

if a8 then
a5+=1
end
end

SEARCH_RESULT_COUNT=a5
as.Size=UDim2.fromOffset(ap,aN(a5))end


u(ab:GetPropertyChangedSignal"Visible",aV,nil,ar)
u(ab:GetPropertyChangedSignal"Size",aV,nil,ar)
u(ar.MouseButton1Down,aV,nil,ar)
u(ar.Activated,aV,nil,ar)

u(at.Activated,aS,nil,at)
u(aw:GetPropertyChangedSignal"Text",a1,nil,aw)

return table.freeze{
CreateOptionTemplate=a_,
SetOptionValue=aX,
CloseDropdown=aU,
OpenDropdown=aT,
SetOptions=a0,
Clear=aW,
SetOnClicked=function(...)
aF=...
end,
SetMultiSelect=function(...)
aH=...
end,
SetHolder=function(...)
aI=...
end,
SetThemeGroup=function(group)
if dropdownThemeGroup~=group then
if aG then
for _,option in ipairs(aG) do
if option.Instance then
if dropdownThemeGroup then dropdownThemeGroup:remove(option.Instance) end
pcall(option.Instance.Destroy,option.Instance)
option.Instance=nil
end
end
end
for instance in pairs(aB) do pcall(instance.Destroy,instance) end
table.clear(aB)
dropdownThemeGroup=group
end
end
}end


local aq

local ar={"W","A","S","D","Tab","Slash","Backspace","Escape","Unknown"}
local as={"MouseButton1","MouseButton2","MouseButton3"}

local at=K({"number","string","nil","boolean","table"},true)local au=function(

au)
if aq==nil then
aq=K(Enum.KeyCode:GetEnumItems())
end

return typeof(au)=="EnumItem"and aq[au]end

function ak.Keybind:SetKeyCode(keyCode)
assert(au(keyCode),`"Keybind.SetKeyCode". 'KeyCode' expected, got {typeof(keyCode)}`)
self.KeyCode=keyCode
if self.KEY_BUTTON then self.KEY_BUTTON.Text=keyCode.Name end
if self.Flag then ae[self.Flag]=keyCode.Name end
return self
end

function ak.Keybind:SetEnabled(enabled)
assert(type(enabled)=="boolean",`"Keybind.SetEnabled". 'boolean' expected, got {typeof(enabled)}`)
self.Enabled=enabled
if not enabled and self.Capturing then self.Capturing=false if self.KEY_BUTTON then self.KEY_BUTTON.Text=self.KeyCode.Name end end
if self.KEY_BUTTON then self.KEY_BUTTON.Active=enabled end
return self
end

function ak.ColorPicker:SetColor(color)
assert(typeof(color)=="Color3",`"ColorPicker.SetColor". 'Color3' expected, got {typeof(color)}`)
self.Value=color
local hex=string.format("%02X%02X%02X",math.round(color.R*255),math.round(color.G*255),math.round(color.B*255))
if self.COLOR_INPUT then self.COLOR_INPUT.Text="#"..hex end
if self.COLOR_SWATCH then self.COLOR_SWATCH.BackgroundColor3=color end
if self.Flag then ae[self.Flag]=hex end
G(self.CALLBACKS,color)
return self
end

function ak.ColorPicker:SetEnabled(enabled)
assert(type(enabled)=="boolean",`"ColorPicker.SetEnabled". 'boolean' expected, got {typeof(enabled)}`)
self.Enabled=enabled
if self.COLOR_INPUT then self.COLOR_INPUT.TextEditable=enabled self.COLOR_INPUT.Active=enabled end
return self
end


function ah:GetNoSelfCall(av)
assert(type(av)=="string",`"Tab.GetNoSelfCall". 'string' expected, got {typeof(av)}`)
local aw=self[av]
assert(type(aw)=="function",`"Tab.GetNoSelfCall". '{aw}' is not a 'function'-{av}`)

return function(...)
return aw(self,...)
end
end


-- ===========================================================================
-- SECTION: Tab options
-- AddSection / AddToggle / AddButton / AddTextBox / AddSlider / AddParagraph /
-- AddDropdown / AddKeybind / AddColorPicker / AddDiscordInvite and the option
-- prototype methods (SetValue / Set / AddCallback / Destroy / ...).
-- ===========================================================================
function ah:AddSection(av,options)
if type(av)=="table" then
options=av
av=options.Title or options.Name or ""
end
assert(av==nil or type(av)=="string",`"Tab.AddSection[param 1]". 'string', or 'nil' expected, got {typeof(av)}`)
assert(options==nil or type(options)=="table" or type(options)=="boolean",`"Tab.AddSection[param 2]". 'table', 'boolean', or 'nil' expected, got {typeof(options)}`)
av=av or ""
local collapsible=options==true or (type(options)=="table" and options.Collapsible==true)
local group=V[self]
local header=createInstance("TextButton","Option",T[self].Container,{
Size=UDim2.new(1,0,0,24),
BackgroundTransparency=1,
AutoButtonColor=false,
Active=collapsible,
Text="",
Elements={Corner=UDim.new(0,5)}
})
local titleLabel=createInstance("TextLabel","Title",header,{
TextXAlignment=Enum.TextXAlignment.Left,
TextTruncate=Enum.TextTruncate.AtEnd,
Size=UDim2.new(1,-28,1,0),
Position=UDim2.fromOffset(5,0),
BackgroundTransparency=1,
TextSize=15,
Text=av,
ThemeTag={OBJECTS=group,TextColor3="Colors.Text.Default",Font="Font.Bold"}
})
local indicator
if collapsible then
indicator=createInstance("TextLabel","Indicator",header,{
Size=UDim2.fromOffset(20,20),
Position=UDim2.new(1,-5,0.5,0),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
Text="−",
TextSize=15,
ThemeTag={OBJECTS=group,TextColor3="Colors.Text.Darker",Font="Font.Bold"}
})
end
local section={Items={},Collapsed=false,Collapsible=collapsible,Header=header,Indicator=indicator,Title=av}
if collapsible then
self._CurrentSection=section
self._Sections=self._Sections or {}
self._Sections[#self._Sections+1]=section
else
self._CurrentSection=nil
end
local handle=setmetatable({
Title=av,
DESTROY_ELEMENT=header,
VISIBLE_ELEMENT=header,
TITLE_LABEL=titleLabel,
Section=section,
Kind="Section",
Parent=self
},ai)
function handle:SetCollapsed(collapsed)
assert(type(collapsed)=="boolean",`"Section.SetCollapsed". 'boolean' expected, got {typeof(collapsed)}`)
assert(section.Collapsible,`"Section.SetCollapsed". this section is not collapsible`)
section.Collapsed=collapsed
for index=#section.Items,1,-1 do
local item=section.Items[index]
if item and item.Parent then
item.Visible=not collapsed
else
table.remove(section.Items,index)
end
end
if section.Indicator then section.Indicator.Text=collapsed and "+" or "−" end
return self
end
if collapsible then
u(header.Activated,function()
handle:SetCollapsed(not section.Collapsed)
end,nil,header)
u(header.MouseEnter,function() header.BackgroundTransparency=0.9 end,nil,header)
u(header.MouseLeave,function() header.BackgroundTransparency=1 end,nil,header)
end
return handle
end

function ah:AddToggle(av)
local aw,ax=an("Toggle",av)
local ay=ao("Toggle",av[4]or av.Flag)

local az=av[2]or av.Default or false
local aA=F(av[3]or av.Callback)

if type(az)~="boolean"then
error(`"Tab.AddToggle.Default". 'boolean' expected, got {typeof(az)}`,2)
end

if ay~=nil and type(ae[ay])=="number"then
az=ae[ay]==0
end

local aB=V[self]
local aC,aD,aE=am(self,aw,ax,UDim2.new(1,-38,0,0))

local aF=createInstance("Frame",aC,{
Size=UDim2.new(0,35,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag={
OBJECTS=aB,
BackgroundColor3="Colors.Stroke"
}
})

local aG=createInstance("Frame",aF,{
BackgroundTransparency=1,
Size=UDim2.new(0.8,0,0.8,0),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5)
})

local aH={
OBJECTS=aB,
BackgroundColor3="Colors.OnPrimary"
}

local aI=createInstance("Frame",aG,{
Size=UDim2.new(0,12,0,12),
Position=UDim2.new(0,0,0.5),
AnchorPoint=Vector2.new(0,0.5),
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag=aH
})

local aJ=os.clock()
local aK=0.2
local aL={}local aM=function(

aM)
aL={}
for aN=1,#aM do
aM[aN]:Play()
aL[aN]=aM[aN]
end end local aN=function()



for aN=#aL,1,-1 do
local aO=aL[aN]
if aO.PlaybackState==Enum.PlaybackState.Playing then
aO:Cancel()
end
aL[aN]=nil
end end local aO=function(


aO)
if ay~=nil then ae[ay]=aO and 0 or 1 end
G(aA,aO)

local aP=UDim2.new(aO and 1 or 0,0,0.5,0)
local aQ=Vector2.new(aO and 1 or 0,0.5)
local aR=aO and"Colors.Primary"or"Colors.Stroke"
local aS=w(Library.CurrentTheme,aO and"Colors.Text.Default"or"Colors.OnPrimary")

aH.BackgroundColor3=aR

if self.Selected and(os.clock()-aJ)>=aK then
aM{
J(aI,"Position",aP,0.25),
J(aI,"AnchorPoint",aQ,0.25),
J(aI,"BackgroundColor3",aS,0.25)
}
else
aN()
aI.Position=aP
aI.AnchorPoint=aQ
aI.BackgroundColor3=aS
end

aJ=os.clock()end


local aP=ak.Toggle.new(self,aC,aD,aE,aO,aA)
aP.Flag=ay
if ay then Library.Options[ay]=aP end
aP:SetValue(az)

local aQ=0

u(aC.Activated,function()
aQ=os.clock()
aP:SetValue(not aP.Value)
end,nil,aC)

return aP
end

function ah:AddButton(av)
local aw,ax=an("Button",av)
local ay=F(av[2]or av.Callback)
local az=av.Debounce or av.Cooldown

local aA=V[self]
local aB,aC,aD=am(self,aw,ax,UDim2.new(1,-20,0,0))

local aE=createInstance("ImageLabel",aB,{
Size=UDim2.new(0,14,0,14),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
ThemeTag={
OBJECTS=aA,
Image="Icons.Button"
}
})

local aF=0

u(aB.Activated,function()
if aB:GetAttribute("Loading") then return end
if az~=nil and(os.clock()-aF)<0 then return end

if az~=nil then
aF=os.clock()+az
end

G(ay)
end,nil,aB)

local buttonHandle=setmetatable({
CALLBACKS=ay,
DESTROY_ELEMENT=aB,
VISIBLE_ELEMENT=aB,
TITLE_LABEL=aC,
DESCRIPTION_LABEL=aD,

Title=aw,
Description=ax,

Parent=self,
Kind="Button",
LoadingIcon=aE
},ai)
return buttonHandle
end

function ah:AddTextBox(av)
local aw,ax=an("TextBox",av)
local ay=ao("TextBox",av[4]or av.Flag)

local az=av[2]or av.Default
local aA=F(av[3]or av.Callback)

local aB=av.Placeholder or av.PlaceholderText
local aC=av.ClearOnFocus or av.ClearTextOnFocus

if az~=nil and type(az)~="string"then
error(`"Tab.AddTextBox.Default". 'string', or 'nil' expected, got {typeof(az)}`,2)
end

if ay and type(ae[ay])=="string"then
az=ae[ay]
end

local aD=V[self]
local aE,aF,aG=am(self,aw,ax,UDim2.new(1,-150,0,0))

local aH=createInstance("Frame",aE,{
Size=UDim2.new(0,150,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Stroke"
},
Elements={
Corner=UDim.new(0,4)
}
})

local aI=createInstance("TextBox",aH,{
Size=UDim2.new(0.85,0,0.85,0),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
BackgroundTransparency=1,
TextScaled=false,
TextSize=10,
TextTruncate=Enum.TextTruncate.AtEnd,
Active=true,
Text="",
PlaceholderText=B.TEXTBOX.PLACEHOLDER_TEXT,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aJ={
OBJECTS=aD,
Image="Icons.TextBox",
ImageColor3="Colors.Icons"
}

local aK=createInstance("ImageLabel",aH,{
Size=UDim2.new(0,12,0,12),
Position=UDim2.new(0,-5,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
ThemeTag=aJ
})

if az~=nil then
aI.Text=az
end

if aC~=nil then
aI.ClearTextOnFocus=aC
end

if aB~=nil then
aI.PlaceholderText=aB
end

local errorStroke=createInstance("UIStroke",aH,{
Color=w(Library.CurrentTheme,"Colors.Error"),
Transparency=1,
Thickness=1.2
})
local aL=ak.TextBox.new(self,aF,aG,aE,aI,aA)
aL.Flag=ay
if ay then Library.Options[ay]=aL end
aL.ERROR_STROKE=errorStroke
local aM=function(

aM)
aJ.ImageColor3=aM
J(aK,"ImageColor3",w(Library.CurrentTheme,aM),0.5):Play()end


if ay~=nil then
u(aI:GetPropertyChangedSignal"Text",function()
ae[ay]=aI.Text
end,nil,aI)
end

u(aI.Focused,function()
aM"Colors.Primary"
end,nil,aI)

u(aI.FocusLost,function()
aM"Colors.Icons"
local aN=aL.TEXTBOX_TEXT_FILTER

if aN then
local aO=aN(aI.Text)
if type(aO)=="string"then
aI.Text=aO
end
end

G(aA,aI.Text)
end,nil,aI)

u(aE.Activated,function()
aI:CaptureFocus()
end,nil,aE)

return aL
end

function ah:AddSlider(av)
local aw,ax=an("Slider",av)
local ay=ao("Slider",av[7]or av.Flag)

local az=av[2]or av.Min
local aA=av[3]or av.Max
local aB=av[4]or av.Increment
local aC=av[5]or av.Default
local aD=F(av[6]or av.Callback)

if aB~=nil and type(aB)~="number"then
error(`"Tab.AddSlider.Increment". 'number', or 'nil' expected, got {typeof(aB)}`,2)
end

if aC~=nil and type(aC)~="number"then
error(`"Tab.AddSlider.Default". 'number', or 'nil' expected, got {typeof(aC)}`,2)
end

assert(type(az)=="number",`"Tab.AddSlider.Min", 'number' expected, got {typeof(az)}`)
assert(type(aA)=="number",`"Tab.AddSlider.Max", 'number' expected, got {typeof(aA)}`)
assert(aA>az,`"Tab.AddSlider". Max must be greater than Min`)
assert(aB==nil or aB>0,`"Tab.AddSlider.Increment". must be greater than zero`)

local aE=V[self]
local aF=T[self].Container

local aG,aH,aI=am(self,aw,ax,UDim2.new(0.55,0,0,0))

if aC==nil then
aC=az
end

if aB==nil then
aB=1
end

if ay~=nil and type(ae[ay])=="number"then
aC=ae[ay]
end

local aJ=createInstance("TextButton",aG,{
Size=UDim2.new(0.45,0,1,0),
Position=UDim2.new(1,0,0,0),
AnchorPoint=Vector2.new(1,0),
AutoButtonColor=false,
BackgroundTransparency=1,
Text=""
})

local aK=createInstance("Frame",aJ,{
Size=UDim2.new(1,-20,0,6),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
ThemeTag={
OBJECTS=aE,
BackgroundColor3="Colors.Stroke"
},
Elements={
Corner=UDim.new(0.5,0)
}
})

local aL=createInstance("Frame",aK,{
Size=UDim2.fromScale(0,1),
BorderSizePixel=0,
ThemeTag={
OBJECTS=aE,
BackgroundColor3="Colors.Primary"
},
Elements={
Corner=UDim.new(0.5,0)
}
})

local aM=createInstance("Frame",aK,{
Size=UDim2.new(0,6,0,12),
BackgroundColor3=Color3.fromRGB(220,220,220),
Position=UDim2.fromScale(0,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=0.2,
Elements={
Corner=UDim.new(0,6)
}
})

local aN=createInstance("TextLabel",aJ,{
Size=UDim2.new(0,50,0,14),
AnchorPoint=Vector2.new(1,0.5),
Position=UDim2.new(0,-1,0.5,0),
BackgroundTransparency=1,
TextSize=12,
TextXAlignment=Enum.TextXAlignment.Right,
ThemeTag={
OBJECTS=aE,
TextColor3="Colors.Text.Default",
Font="Font.SliderValue"
}
})

local aP=ak.Slider.new(self,aG,aH,aI,aD)
aP.Flag=ay
if ay then Library.Options[ay]=aP end

aP.Min=az
aP.Max=aA
aP.Increment=aB
aP.INPUT_BUTTON=aJ local aQ=function(

aQ)
return(aQ-az)/(aA-az)end local aR=function(


aR)
return(aR*(aA-az))+az end local aS=function(


aS)
local steps=math.floor(((aS-az)/aB)+0.5)
return math.floor((az+steps*aB)*1000000+0.5)/1000000 end local aT=function(


aT, aU)
if aT==aP.Value then return end

if ay~=nil then
ae[ay]=aT
end

task.defer(G,aD,aT)
aP.Value=aT

local aV=UDim2.fromScale(aU,0.5)
local aW=UDim2.fromScale(aU,1)

aN.Text=tostring(math.floor(aT*1000)/1000)

aM.Position=aV
aL.Size=aW
end local aU=function(


aU)
local aV=math.clamp(aS(aU),az,aA)
aT(aV,aQ(aV))end


aP.WHEN_VALUE_CHANGED=aU local aV=function(position,trackPosition,trackSize)
local alpha=math.clamp((position.X-trackPosition.X)/math.max(trackSize.X,1),0,1)
local rawValue=aR(alpha)
local rounded=math.clamp(aS(rawValue),az,aA)
aT(rounded,aQ(rounded))
end


local activeInput=nil
local changedConnection=nil
local endedConnection=nil

local function updateSlider(position)
local trackPosition=aK.AbsolutePosition
local trackSize=aK.AbsoluteSize
aV(position,trackPosition,trackSize)
end

local function disconnectDragInput()
if changedConnection then changedConnection:Disconnect() changedConnection=nil end
if endedConnection then endedConnection:Disconnect() endedConnection=nil end
end

local function finishDrag()
if not activeInput then return end
activeInput=nil
A=false
disconnectDragInput()
J(aM,"BackgroundTransparency",0.2,0.15):Play()
aF.ScrollingEnabled=true
end

local function connectDragInput()
changedConnection=UserInputService.InputChanged:Connect(function(input)
if not activeInput then return end
if activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement then
updateSlider(UserInputService:GetMouseLocation()-GuiService:GetGuiInset())
elseif activeInput.UserInputType==Enum.UserInputType.Touch and input.UserInputType==Enum.UserInputType.Touch then
updateSlider(input.Position-GuiService:GetGuiInset())
end
end)
endedConnection=UserInputService.InputEnded:Connect(function(input)
if not activeInput then return end
if activeInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1 then
finishDrag()
elseif activeInput.UserInputType==Enum.UserInputType.Touch and input.UserInputType==Enum.UserInputType.Touch then
finishDrag()
end
end)
end

u(aJ.InputBegan,function(input)
if A~=false then return end
if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
activeInput=input
A=true
connectDragInput()
J(aM,"BackgroundTransparency",0,0.15):Play()
aF.ScrollingEnabled=false
updateSlider(input.Position-GuiService:GetGuiInset())
end,nil,aJ)

u(aJ.Destroying,function()
finishDrag()
end,nil,aG)

local originalDestroy=ai.Destroy
aP.Destroy=function(option)
finishDrag()
return originalDestroy(option)
end

aU(aC)
return aP
end

function ah:AddDiscordInvite(av)
local aw,ax=an("DiscordInvite",av)
local ay=av.Icon or av.Image or av.Logo
local az=av.Banner or av.BannerColor
local aA=av.Online or av.MembersOnline
local aB=av.Members or av.TotalMembers
local aC=av.Invite or av.Link

assert(type(aC)=="string",`"Tab.AddDiscordInvite.Invite". 'string' expected, got {typeof(aC)}`)

if az~=nil and typeof(az)~="Color3"and type(az)~="string"then
error(`"Tab.AddDiscordInvite.Banner". 'nil', 'Color3', or 'string' expected, got {typeof(az)}`,2)
end

if aA~=nil and type(aA)~="number"then
error(`"Tab.AddDiscordInvite.Online". 'number' expected, got {typeof(aA)}`,2)
end

if aB~=nil and type(aB)~="number"then
error(`"Tab.AddDiscordInvite.Members". 'nil', or 'number' expected, got {typeof(aB)}`,2)
end

if I.ZIndexBehavior~=Enum.ZIndexBehavior.Sibling then
I.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
end

local aD=V[self]
local aE=T[self].Container

local aF=createInstance("Frame","Option",aE,{
BackgroundTransparency=1,
Size=UDim2.new(1,0,0,148)
})
if self._CurrentSection then
self._CurrentSection.Items[#self._CurrentSection.Items+1]=aF
if self._CurrentSection.Collapsed then aF.Visible=false end
end

local aG=createInstance("CanvasGroup",aF,{
Size=UDim2.new(0,178,1,-15),
Position=UDim2.new(0,5,1,0),
AnchorPoint=Vector2.new(0,1),
ClipsDescendants=true,
Elements={
Corner=UDim.new(0,9),
Stroke={
ThemeTag={
Color="Colors.Border.Default"
}
}
},
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Buttons.Default"
}
})

local aH=createInstance("ImageLabel",aG,{
BackgroundColor3=Color3.new(1,1,1),
Size=UDim2.fromScale(1,0.28),
BackgroundTransparency=1
})

local aI=createInstance("TextLabel",aF,{
Position=UDim2.fromOffset(5,0),
Size=UDim2.new(1,0,0,15),
TextColor3=Color3.fromRGB(40,150,255),
TextXAlignment=Enum.TextXAlignment.Left,
BackgroundTransparency=1,
TextSize=9,
Text=aC,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Link",
Font="Font.Medium"
}
})

local aJ=createInstance("ImageLabel",aG,{
Size=UDim2.fromOffset(33,33),
Position=UDim2.new(0,10,0.28,0),
AnchorPoint=Vector2.new(0,0.5),
Image=ay,
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Buttons.Default"
},
Elements={
Corner=UDim.new(0,8),
Stroke={
Thickness=2.2,
ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
ThemeTag={
OBJECTS=aD,
Color="Colors.Buttons.Default"
}
}
}
})

local aK=createInstance("TextLabel",aG,{
Size=UDim2.new(1,-10,0,10),
Position=UDim2.new(0,10,0.44,0),
TextXAlignment=Enum.TextXAlignment.Left,
BackgroundTransparency=1,
TextSize=11,
Text=aw,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aL

if aA or aB then
aL=createInstance("Frame",aG,{
Size=UDim2.new(1,-10,0,9),
Position=UDim2.new(0,0,0.52,0),
BackgroundTransparency=1,
Elements={
Padding={
PaddingLeft=UDim.new(0,7),
PaddingRight=UDim.new(0,10)
},
ListLayout={
HorizontalAlignment=Enum.HorizontalAlignment.Left,
VerticalAlignment=Enum.VerticalAlignment.Center,
FillDirection=Enum.FillDirection.Horizontal,
Padding=UDim.new(0,4),
}
}
})local aM=function(

aM, aN)
return createInstance("Frame",aL,{
Size=UDim2.fromScale(0,1),
AutomaticSize=Enum.AutomaticSize.X,
BackgroundTransparency=1,
Childs={
createInstance("Frame",{
Size=UDim2.fromOffset(3,3),
Position=UDim2.new(0,5,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
BackgroundColor3=aM,
Elements={
Corner=UDim.new(1,0)
}
}),
createInstance("TextLabel",{
Size=UDim2.new(0,0,1,0),
Position=UDim2.new(0,12,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
AutomaticSize=Enum.AutomaticSize.X,
BackgroundTransparency=1,
TextSize=8,
Text=aN,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Darker",
Font="Font.Normal"
}
})
}
})end


if aA~=nil then
aM(Color3.fromRGB(67,181,129),N(aA).." Online")
end
if aB~=nil then
aM(Color3.fromRGB(86,101,105),N(aB).." Members")
end
end

local aM=createInstance("TextLabel",aG,{
Size=UDim2.new(1,-50,0,8),
Position=UDim2.new(0,10,aL and 0.6 or 0.56,0),
TextXAlignment=Enum.TextXAlignment.Left,
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
TextSize=8,
Text=ax or"",
TextWrapped=true,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Darker",
Font="Font.Medium"
}
})

local aN=createInstance("Frame",aG,{
Size=UDim2.new(1,0,0.28,0),
Position=UDim2.fromScale(0,1),
AnchorPoint=Vector2.new(0,1),
BorderSizePixel=0,
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Buttons.Default"
}
})

if#aM.Text>0 then
aN.Size=UDim2.new(1,0,0.42,0)

createInstance("UIGradient",aN,{
Rotation=-90,
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.00,0.00),
NumberSequenceKeypoint.new(0.60,0.00),
NumberSequenceKeypoint.new(1.00,1.00)
}
})
end

local aO=createInstance("TextButton",aN,{
Position=UDim2.new(0.5,0,1,-9),
Size=UDim2.new(1,-18,0,18),
AnchorPoint=Vector2.new(0.5,1),
Text="Go to Server",
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.JoinButton",
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aP=0

u(aO.Activated,function()
if(os.clock()-aP)<0 then return end

aP=os.clock()+5
local aQ=aO.Text
aO.Text="Copied to Clipboard!"
if type(setclipboard)=="function" then
setclipboard(aC)
else
warn("DepHub: clipboard is unavailable in this executor")
end
task.wait(4)
if aO.Parent then aO.Text=aQ end
end,nil,aO)

if type(az)=="string"then
aH.ScaleType=Enum.ScaleType.Crop
aH.Image=az
elseif typeof(az)=="Color3"then
aH.BackgroundTransparency=0
createInstance("UIGradient",aH,{
Rotation=-15,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,az),
ColorSequenceKeypoint.new(1,az:Lerp(Color3.new(1,1,1),0.2))
}
})
end

return setmetatable({
DESTROY_ELEMENT=aF,
VISIBLE_ELEMENT=aF,

Title=aw,
Description=ax,
DESCRIPTION_LABEL=aM,
TITLE_LABEL=aK,

Kind="DiscordInvite",
Parent=self
},ai)
end

function ah:AddKeybind(av)
local title,description=an("Keybind",av)
local flag=ao("Keybind",av[4]or av.Flag)
local default=av[2]or av.KeyCode or av.Default or Enum.KeyCode.Unknown
local callbacks=F(av[3]or av.Callback)
if type(default)=="string" then default=Enum.KeyCode[default] end
if not au(default) then error(`"Tab.AddKeybind.KeyCode". 'KeyCode' expected, got {typeof(default)}`,2) end
if flag and type(ae[flag])=="string" and Enum.KeyCode[ae[flag]] then default=Enum.KeyCode[ae[flag]] end
local group=V[self]
local row,titleLabel,descriptionLabel=am(self,title,description,UDim2.new(1,-105,0,0))
local keyButton=createInstance("TextButton",row,{
Size=UDim2.fromOffset(92,22),
Position=UDim2.new(1,-10,0.5,0),
AnchorPoint=Vector2.new(1,0.5),
AutoButtonColor=false,
Text=default.Name,
TextSize=10,
TextTruncate=Enum.TextTruncate.AtEnd,
ThemeTag={OBJECTS=group,BackgroundColor3="Colors.Stroke",TextColor3="Colors.Text.Default",Font="Font.Bold"},
Elements={Corner=UDim.new(0,5)}
})
local handle=setmetatable({
CALLBACKS=callbacks,
DESTROY_ELEMENT=row,
VISIBLE_ELEMENT=row,
TITLE_LABEL=titleLabel,
DESCRIPTION_LABEL=descriptionLabel,
KEY_BUTTON=keyButton,
KeyCode=default,
Flag=flag,
Enabled=true,
Title=title,
Description=description,
Parent=self,
Kind="Keybind"
},ak.Keybind)
if flag then ae[flag]=default.Name Library.Options[flag]=handle end
u(keyButton.Activated,function()
if handle.Enabled==false then return end
handle.Capturing=true
keyButton.Text="Press a key..."
end,nil,keyButton)
u(UserInputService.InputBegan,function(input,processed)
if input.UserInputType~=Enum.UserInputType.Keyboard then return end
if handle.Capturing then
if input.KeyCode==Enum.KeyCode.Escape then
handle.Capturing=false
keyButton.Text=handle.KeyCode.Name
return
end
handle:SetKeyCode(input.KeyCode)
handle.Capturing=false
return
end
if processed or handle.Enabled==false then return end
if UserInputService:GetFocusedTextBox() then return end
if input.KeyCode==handle.KeyCode and handle.KeyCode~=Enum.KeyCode.Unknown then G(callbacks) end
end,nil,keyButton)
return handle
end

function ah:AddColorPicker(av)
local title,description=an("ColorPicker",av)
local flag=ao("ColorPicker",av[4]or av.Flag)
local default=av[2]or av.Default or Color3.new(1,1,1)
local callbacks=F(av[3]or av.Callback)
if type(default)=="string" then
local hex=default:gsub("^#","")
if #hex==6 and tonumber(hex,16) then
default=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
else
default=Color3.new(1,1,1)
end
end
if flag and type(ae[flag])=="string" then
local hex=ae[flag]:gsub("^#","")
if #hex==6 and tonumber(hex,16) then
default=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
end
assert(typeof(default)=="Color3",`"Tab.AddColorPicker.Default". 'Color3' or hex string expected, got {typeof(default)}`,2)
local group=V[self]
local row,titleLabel,descriptionLabel=am(self,title,description,UDim2.new(1,-125,0,0))
local swatch=createInstance("Frame",row,{
Size=UDim2.fromOffset(22,22),
Position=UDim2.new(1,-10,0.5,0),
AnchorPoint=Vector2.new(1,0.5),
BackgroundColor3=default,
Elements={Corner=UDim.new(0,5),Stroke={Color=w(Library.CurrentTheme,"Colors.Stroke")}}
})
local input=createInstance("TextBox",row,{
Size=UDim2.fromOffset(82,22),
Position=UDim2.new(1,-39,0.5,0),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
Text="#"..string.format("%02X%02X%02X",math.round(default.R*255),math.round(default.G*255),math.round(default.B*255)),
PlaceholderText="#RRGGBB",
TextSize=10,
ClearTextOnFocus=false,
TextColor3=w(Library.CurrentTheme,"Colors.Text.Default")
})
local handle=setmetatable({
CALLBACKS=callbacks,
DESTROY_ELEMENT=row,
VISIBLE_ELEMENT=row,
TITLE_LABEL=titleLabel,
DESCRIPTION_LABEL=descriptionLabel,
COLOR_INPUT=input,
COLOR_SWATCH=swatch,
Value=default,
Flag=flag,
Title=title,
Description=description,
Parent=self,
Kind="ColorPicker"
},ak.ColorPicker)
if flag then ae[flag]=input.Text:gsub("^#","") Library.Options[flag]=handle end
u(input.FocusLost,function()
local hex=input.Text:gsub("^#","")
if #hex~=6 or not tonumber(hex,16) then
handle.HasError=true
input.Text="#"..string.format("%02X%02X%02X",math.round(handle.Value.R*255),math.round(handle.Value.G*255),math.round(handle.Value.B*255))
return
end
handle.HasError=false
handle:SetColor(Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16)))
end,nil,input)
return handle
end

function ah:AddLabel(text)
assert(type(text)=="string",`"Tab.AddLabel". 'string' expected, got {typeof(text)}`,2)
return self:AddParagraph(text,"")
end

function ah:AddDivider()
local group=V[self]
local line=createInstance("Frame",T[self].Container,{
Size=UDim2.new(1,-4,0,1),
BorderSizePixel=0,
BackgroundColor3=w(Library.CurrentTheme,"Colors.Stroke")
})
group:add(line,{BackgroundColor3="Colors.Stroke"})
if self._CurrentSection then
self._CurrentSection.Items[#self._CurrentSection.Items+1]=line
if self._CurrentSection.Collapsed then line.Visible=false end
end
return setmetatable({
DESTROY_ELEMENT=line,
VISIBLE_ELEMENT=line,
Parent=self,
Kind="Divider"
},ai)
end

function ah:AddProgressBar(av)
local title,description=an("ProgressBar",av)
local group=V[self]
local row,titleLabel,descriptionLabel=am(self,title,description,UDim2.new(1,0,0,0))
local track=createInstance("Frame",row,{
Size=UDim2.new(1,-20,0,5),
Position=UDim2.new(0,10,1,-8),
AnchorPoint=Vector2.new(0,1),
BackgroundColor3=w(Library.CurrentTheme,"Colors.Stroke"),
ThemeTag={OBJECTS=group,BackgroundColor3="Colors.Stroke"},
Elements={Corner=UDim.new(0.5,0)}
})
local fill=createInstance("Frame",track,{
Size=UDim2.fromScale(0,1),
BackgroundColor3=w(Library.CurrentTheme,"Colors.Primary"),
ThemeTag={OBJECTS=group,BackgroundColor3="Colors.Primary"},
Elements={Corner=UDim.new(0.5,0)}
})
local handle=setmetatable({
DESTROY_ELEMENT=row,
VISIBLE_ELEMENT=row,
TITLE_LABEL=titleLabel,
DESCRIPTION_LABEL=descriptionLabel,
FILL=fill,
TRACK=track,
Value=0,
Parent=self,
Kind="ProgressBar"
},ai)
function handle:SetValue(value)
assert(type(value)=="number",`"ProgressBar.SetValue". 'number' expected, got {typeof(value)}`,2)
self.Value=math.clamp(value,0,100)
self.FILL.Size=UDim2.fromScale(self.Value/100,1)
return self
end
handle.Set=handle.SetValue
local originalDestroy=ai.Destroy
handle.Destroy=function(option)
group:remove(fill)
group:remove(track)
return originalDestroy(option)
end
return handle
end

function ah:AddParagraph(av,aw)
assert(type(av)=="string",`"Tab.AddParagraph[param 1]". 'string' expected, got {typeof(av)}`)

if aw~=nil and type(aw)~="string"then
error(`"Tab.AddParagraph[param 2]". 'string', or 'nil' expected, got {typeof(aw)}`,2)
end

local ax=V[self]
local ay,az,aA=am(self,av,aw,UDim2.new(1,0,0,0),"Paragraph")

return setmetatable({
DESTROY_ELEMENT=ay,
VISIBLE_ELEMENT=ay,
TITLE_LABEL=az,
DESCRIPTION_LABEL=aA,

Title=av,
Description=aw,

Parent=self,
Kind="Paragraph"
},ai)
end

function ah:AddDropdown(av)
local aw,ax=an("Dropdown",av)
local ay=ao("Dropdown",av[5]or av.Flag)

local az=av[2]or av.Options
local aA=av[3]or av.Default
local aB=F(av[4]or av.Callback)
local aC=av.MultiSelect

if aA~=nil and type(aA)~="table"and type(aA)~="string"then
error(`"Tab.AddDropdown.Default". 'string', 'table', or 'nil' expected, got {typeof(aA)}`,2)
end

if az~=nil and type(az)~="table"then
error(`"Tab.AddDropdown.Options". 'table', or 'nil' expected, got {typeof(az)}`,2)
end

if aC~=nil and type(aC)~="boolean"then
error(`"Tab.AddDropdown.MultiSelect". 'boolean', or 'nil' expected, got {typeof(aC)}`,2)
end

if ay and type(ae[ay])==(aC and"table"or"string")then
aA=ae[ay]
end

local aD=V[self]
local aE,aF,aG=am(self,aw,ax,UDim2.new(1,-150,0,0))

local aH=createInstance("Frame",aE,{
Size=UDim2.new(0,150,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
Elements={
Corner=UDim.new(0,4)
},
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Stroke"
}
})

local aI=createInstance("TextLabel",aH,{
Size=UDim2.new(0.85,0,0.85,0),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
BackgroundTransparency=1,
TextScaled=false,
TextSize=10,
TextTruncate=Enum.TextTruncate.AtEnd,
Text="...",
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aJ={
OBJECTS=aD,
Image="Icons.Dropdown.Open",
ImageColor3="Colors.Icons"
}

local aK=createInstance("ImageLabel",aH,{
Size=UDim2.new(0,15,0,15),
Position=UDim2.new(0,-5,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
ThemeTag=aJ
})

local aL=ak.Dropdown.new(self,aE,aF,aG,aB)
aL.Flag=ay
if ay then Library.Options[ay]=aL end

local aM
local aN=false
local aO=false

local aP={}
local aQ={}
local aR={}
local aS={}

aL.DROPDOWN_OPTIONS=aR
aL.Opened=aO local aT=function(

aT, aU)
aJ.ImageColor3=aT
aJ.Image=aU

J(aK,"ImageColor3",w(Library.CurrentTheme,aT),0.35):Play()
aK.Image=w(Library.CurrentTheme,aU)end local aU=function(


aU)
aO=aU
aL.Opened=aU

local aV=aU and"Colors.Primary"or"Colors.Icons"
local aW=aU and"Icons.Dropdown.Close"or"Icons.Dropdown.Open"
aT(aV,aW)end local aV=function()



aU(false)end local aW=function()



local aW={}
for aX,aY in aQ do
if not aY then continue end
aW[#aW+1]=aX
end
return aW end local aX=function(


aX)
local aY=type(aX)=="table"and table.concat(aX,", ")or(aX or"")

if#aY>=100 then
aY=aY:sub(1,97).."..."
end

aI.Text=#aY~=0 and aY or"..."end local aY=function()



aN=false

local aY=aC and aW()or aM and aM.Name
G(aB,aC and aQ or aY)
aX(aY)

if ay~=nil then
ae[ay]=aY
end end local aZ=function()



if not aN then
aN=true
task.delay(0.1,aY)
end end local a_=function(


a_)
if aC then
local a0=not a_.Selected
X.SetOptionValue(a_,a0)
aQ[a_.Name]=a0
else
if aM==a_ then
return nil
elseif aM~=nil then
X.SetOptionValue(aM,false)
end

aM=a_
X.SetOptionValue(a_,true)
end

aZ()end local a0=function(


a0)
a0=tostring(a0)
if aS[a0]then return end

local a1={
Name=a0,
DisplayName=a0,
Selected=false
}

if aC and aQ[a0]==nil then
aQ[a0]=false
end

aS[a0]=a1
aR[#aR+1]=a1
return a1 end local a1=function(


a1)
if aO==a1 then return end

if not X then
X=ap()
end

if a1 then
if not X.OpenDropdown(aV)then return end

X.SetThemeGroup(aD)
X.SetHolder(aH)
X.SetMultiSelect(aC)
X.SetOnClicked(a_)
X.SetOptions(aR)
else
X.CloseDropdown()
end

aU(a1)end local a2=function(


a2, a3)
if a3 and type(a2)=="boolean"then
return a2==true and aR[a3]
end

return if type(a2)=="number"then aR[a2]else aS[tostring(a2)]end local a3=function(


a3)
a3.Selected=true

if aC then
aQ[a3.Name]=true
else
aM=a3
end end local a4=function(...)



local a4=a2(...)

if a4 then
a3(a4)
elseif aC and type(...)=="string"then
aP[select(1,...)]=true
end end local a5=function()



if not aA then return end

for a5=1,(aC and#aA or 1)do
a4(aA[a5],a5)
end end local a6=function(


a6)
local a7=table.find(aR,a6)

if a7 then
table.remove(aR,a7)
end

if a6.Instance then
aD:remove(a6.Instance)
a6.Instance:Destroy()
a6.Instance=nil
end

aS[a6.Name]=nil end local a7=function(


a7)
if aC then
local a8=a7.Name
return(aQ[a8]or aP[a8])==true
else
return aM and aM.Name==a7.Name
end end


aL.SET_ENABLED_OPTIONS=function(enabledOptions)
for name,option in pairs(aS) do
local enabled=enabledOptions[name]
if enabled==nil then enabled=true end
option.Enabled=enabled==true
if option.Instance then
option.Instance.Active=option.Enabled
option.Instance.BackgroundTransparency=option.Enabled and 0 or 0.45
local optionLabel=option.Instance:FindFirstChildOfClass("TextLabel")
if optionLabel then optionLabel.TextTransparency=option.Enabled and 0.4 or 0.7 end
end
end
end

aL.ADD_DROPDOWN_OPTION=function(a8)
if type(a8)=="table"then
for a9=1,#a8 do
aL:Add(a8[a9])
end

return nil
end

local a9=a0(a8)

if a9 then
if a9.Enabled==nil then a9.Enabled=true end
if aL.Opened then
X.CreateOptionTemplate(a9,true)
end

if a7(a9)then
a3(a9)

if a9.Instance then
X.SetOptionValue(a9,a9.Selected)
end
end

aZ()
end
end

-- DepHub: selecao programatica. O handle so tinha Clear/Add, e o Add NAO marca
-- a opcao -- a lib so a marca pelo caminho do CLIQUE (a_). O adapter restaurando
-- uma config (Clear + Add) nao conseguia re-selecionar nada: marcava tudo como
-- nao-escolhido e o campo ficava vazio (ou com sobra da selecao anterior). Este
-- Select reproduz exatamente a logica do clique para marcar/desmarcar.
aL.SELECT_DROPDOWN_OPTION=function(a8,a9)
local a0_=aS[tostring(a8)]
if not a0_ or a0_.Enabled==false then return false end

if aC then
local want=(a9~=false)
a0_.Selected=want
aQ[a0_.Name]=want
if a0_.Instance then X.SetOptionValue(a0_,want) end
elseif a9~=false then
a3(a0_)
if a0_.Instance then X.SetOptionValue(a0_,true) end
end

aZ()
return true
end

-- Alias publico usado pelo adapter (nome curto, igual ao do clique/experiencia).
aL.Select=function(self,a8,a9) return self.SELECT_DROPDOWN_OPTION(a8,a9) end

aL.REMOVE_DROPDOWN_OPTION=function(a8)
local a9=aS[tostring(a8)]
if a9 then
a6(a9)
end
end

aL.CLEAR_DROPDOWN=function()
for a8=#aR,1,-1 do
local a9=aR[a8]
if a9.Instance then
aD:remove(a9.Instance)
a9.Instance:Destroy()
a9.Instance=nil
end

-- DepHub: limpar tambem a SELECAO da opcao removida. O conjunto da selecao
-- multipla (aQ) e o pendente (aP) nao eram zerados aqui: depois de um Clear, a
-- selecao antiga sobrevivia ("Alpha" continuava marcada) e o proximo Add checava
-- contra ela -- reaplicar uma config sobre um dropdown ja usado deixava a sobra
-- da selecao anterior no campo em vez da nova. Era o "as listas de fruta / as
-- exception keys nao mostram o que eu escolhi".
aQ[a9.Name]=nil
aP[a9.Name]=nil
aS[a9.Name]=nil
aR[a8]=nil
end

if aL.Opened then
X.Clear()
end

-- Re-renderiza o campo/label com o conjunto agora vazio.
aZ()
end

do
if az then
for a8=1,#az do
a0(az[a8])
end
end

if type(aA)=="table"then
a5()
elseif type(aA)=="string"or type(aA)=="number"then
local a8=a2(aA)

if a8 then
a3(a8)
end
end

if aC then
local a8=aW()
task.defer(G,aB,aQ)
aX(a8)
else
local a8=aM
local a9=a8 and a8.Name or""
task.defer(G,aB,a9)
aX(a9)
end
end

u(aE.Activated,function()
a1(not aO)
end,nil,aE)

return aL
end


-- ===========================================================================
-- SECTION: Tab methods
-- Destroy / SetVisible / Select.
-- ===========================================================================
function ah:Destroy()
assert(type(self)=="table"and self.IS_A_TAB,`"Tab.Destroy". {tostring(self)} is not a tab`)
if self.IS_DESTROYED then return end
local av=table.find(S,self)
assert(av,`"Tab.Destroy". failed to destroy '{self.Title}'`)
local wasSelected=ac==self
self.IS_DESTROYED=true

if wasSelected and X then
pcall(X.CloseDropdown)
end

for aw,ax in T[self] or {} do
if typeof(ax)=="Instance" then
pcall(ax.Destroy,ax)
end
end

local themeGroup=V[self]
if themeGroup then
pcall(themeGroup.destroy,themeGroup)
end

for flag,option in pairs(Library.Options) do
if option.Parent==self then Library.Options[flag]=nil end
end
self._CurrentSection=nil
self._Sections=nil
T[self]=nil
U[self]=nil
V[self]=nil
table.remove(S,av)

if wasSelected then
ac=nil
local nextTab=S[math.min(av,#S)]
if nextTab then
nextTab:Select()
end
end

setmetatable(self,nil)
end

function ah:SetVisible(av)
assert(type(av)=="boolean",`"Tab.SetVisible[param 1]". 'boolean' extected, got {typeof(av)}`)

for aw,ax in T[self]do
ax.Visible=av
end
end

function ah:Select()
if ac==self then
return nil
end

-- DepHub: o popup de dropdown e um singleton (X) compartilhado por todos os
-- dropdowns de todas as abas. Se uma aba for trocada com o popup aberto, ele
-- continuaria parentado em Y (a pasta Dropdowns) e apareceria preso no canto
-- fixo por cima da outra aba. Fechar na troca de aba garante que o proximo
-- dropdown sempre reabra do zero, reposicionado pelo holder dele.
if ac and X then
X.CloseDropdown()
end

if ac then
U[ac].Unselect()
end

ac=self
U[ac].Select()
end

function ai:SetTitle(av)
assert(type(av)=="string",`"Option.SetTitle". 'string' expected, got {typeof(av)}`)
assert(self.TITLE_LABEL,`"Option.SetTitle". cannot change this option name {self.KIND}:{self.Title}`)

self.TITLE_LABEL.Text=av
self.Title=av
return self
end

function ai:SetDescription(av)
assert(av==nil or type(av)=="string",`"Option.SetDescription". 'string', or 'nil' expected, got {typeof(av)}`)
assert(self.DESCRIPTION_LABEL,`"Option.SetDescription". cannot change this option description {self.KIND}:{self.Title}`)

self.DESCRIPTION_LABEL.Text=av
self.Description=av
return self
end

function ai:SetVisible(av)
assert(typeof(self.VISIBLE_ELEMENT)=="Instance",`"Option.SetVisible". cannot change this option visibility {self.KIND}:{self.Title}`)
assert(type(av)=="boolean",`"Option.SetVisible". 'boolean' expected, got {typeof(av)}`)
self.VISIBLE_ELEMENT.Visible=av
return self
end

function ai:SetEnabled(av)
assert(type(av)=="boolean",`"Option.SetEnabled". 'boolean' expected, got {typeof(av)}`)
self.Enabled=av
local element=self.DESTROY_ELEMENT
if typeof(element)=="Instance" and element:IsA("GuiButton") then
 element.Active=av and not self.Loading
 element.AutoButtonColor=false
end
if self.TEXTBOX then self.TEXTBOX.TextEditable=av self.TEXTBOX.Active=av end
if self.COLOR_INPUT then self.COLOR_INPUT.TextEditable=av self.COLOR_INPUT.Active=av end
if self.KEY_BUTTON then self.KEY_BUTTON.Active=av end
if self.INPUT_BUTTON then self.INPUT_BUTTON.Active=av end
return self
end

function ai:SetLoading(loading)
assert(type(loading)=="boolean",`"Option.SetLoading". 'boolean' expected, got {typeof(loading)}`)
assert(self.Kind=="Button",`"Option.SetLoading" is only available for Button options`)
self.Loading=loading
local element=self.DESTROY_ELEMENT
if typeof(element)=="Instance" then element:SetAttribute("Loading",loading) element.Active=not loading and self.Enabled~=false end
if self.LoadingTween then self.LoadingTween:Cancel() self.LoadingTween=nil end
if self.LoadingIcon then
if loading and not ReducedMotion then
self.LoadingTween=TweenService:Create(self.LoadingIcon,TweenInfo.new(0.8,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Rotation=360})
self.LoadingTween:Play()
else
self.LoadingIcon.Rotation=0
end
end
return self
end

function ai:SetError(hasError)
assert(type(hasError)=="boolean",`"Option.SetError". 'boolean' expected, got {typeof(hasError)}`)
if self.ERROR_STROKE then
self.ERROR_STROKE.Color=w(Library.CurrentTheme,"Colors.Error")
self.ERROR_STROKE.Transparency=hasError and 0 or 1
end
self.HasError=hasError
return self
end

function ai:SetTooltip(text)
assert(text==nil or type(text)=="string",`"Option.SetTooltip". 'string', or 'nil' expected, got {typeof(text)}`)
if self.TOOLTIP then self.TOOLTIP:Destroy() self.TOOLTIP=nil end
if not text or text=="" then return self end
local target=self.VISIBLE_ELEMENT or self.DESTROY_ELEMENT
if typeof(target)~="Instance" then return self end
local tooltip=createInstance("TextLabel",I,{
Visible=false,
ZIndex=2000,
AutomaticSize=Enum.AutomaticSize.XY,
Size=UDim2.fromOffset(0,0),
BackgroundColor3=Color3.fromRGB(20,20,20),
TextColor3=Color3.new(1,1,1),
TextSize=11,
TextWrapped=true,
Text=text,
Position=UDim2.fromOffset(0,0),
Elements={Corner=UDim.new(0,5),Padding={PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)}}
})
self.TOOLTIP=tooltip
u(target.MouseEnter,function() tooltip.Visible=true end,nil,target)
u(target.MouseLeave,function() tooltip.Visible=false end,nil,target)
u(target.Destroying,function() if tooltip.Parent then tooltip:Destroy() end end,nil,I)
u(UserInputService.InputChanged,function(input)
if tooltip.Visible and input.UserInputType==Enum.UserInputType.MouseMovement then
local position=UserInputService:GetMouseLocation()-GuiService:GetGuiInset()
tooltip.Position=UDim2.fromOffset(position.X+12,position.Y+12)
end
end,nil,target)
return self
end

function ai:Destroy()
assert(typeof(self.DESTROY_ELEMENT)=="Instance",`"Option.Destroy". cannot destroy this option {self.KIND}:{self.Title}`)
if self.LoadingTween then self.LoadingTween:Cancel() self.LoadingTween=nil end
if self.TOOLTIP then self.TOOLTIP:Destroy() self.TOOLTIP=nil end
local parentGroup=self.Parent and V[self.Parent]
if parentGroup and type(parentGroup.remove)=="function" then
parentGroup:remove(self.DESTROY_ELEMENT)
end
if self.Flag and Library.Options[self.Flag]==self then Library.Options[self.Flag]=nil end
self.DESTROY_ELEMENT:Destroy()
setmetatable(self,nil)

self.Destroyed=true
end

function ai:AddCallback(av)
assert(self.CALLBACKS,"\"Option.AddCallback\". cannot add callback to this option.")
assert(type(av)=="function",`"Option.AddCallback[param 1]". 'function' expected, got {typeof(av)}`)

table.insert(self.CALLBACKS,av)
return self
end

ai.NewCallback=ai.AddCallback
ai.SetContent=ai.SetDescription
ai.SetDesc=ai.SetDescription

function aj:CreateMobileMinimizer(av)
local aw=createInstance("ImageButton",I,{
Size=UDim2.fromOffset(35,35),
Position=UDim2.fromScale(0.17,0.28),
AnchorPoint=Vector2.new(0.5,0.5),
AutoButtonColor=false,
ThemeTag={
BackgroundColor3="Colors.Buttons.Default"
}
})

u(aw.Activated,function()
if aw:GetAttribute("DragMoved") then
aw:SetAttribute("DragMoved",false)
return
end
ag:Minimize()
end,nil,aw)

av.Elements={}

if av.Corner then
av.Elements.Corner=av.Corner
av.Corner=nil
end

if av.Stroke then
av.Elements.Stroke=av.Stroke
av.Stroke=nil
end

InstanceFactory.Draggable(aw,ad,0.5)
InstanceFactory.SetProperties(aw,av)

return aw
end

function aj:SetKeyCode(av)
assert(au(av),`"Minimizer.SetKeyCode[param 1]". 'KeyCode' expected, got {typeof(av)}`)

self.KeyCode=av
end


-- ===========================================================================
-- SECTION: Window methods
-- SelectTab / Minimize / MakeTab / StartWindow / MinimizeButton / SetTitle /
-- flags (DeleteFlags / SetFlag / GetFlag / ReadFile / WriteFile) / Dialog /
-- Notify / NewNotifyGroup / GetTabByTitle.
-- ===========================================================================
function ag:SelectTab(av)
local aw=type(av)=="number"and S[av]

if type(av)=="table"and av.IS_A_TAB then
aw=av
end

if aw then
aw:Select()
elseif not aw then
assert(type(av)=="number",`"Window.SelectTab" number or tab expected, got {typeof(av)}`)
assert(av>0,`"Window.SelectTab" the number must be greater than 0, value: {av}`)
assert(av==math.floor(av),`"Winow.SelectTab" floor number expected, got {av}`)

self.SelectedTab=av
end
end

function ag:Minimize()
ab.Visible=not ab.Visible
end

function ag:MakeTab(av)
local aw=av[1]or av.Name or av.Title
local ax=av[2]or av.Icon or av.Image

assert(type(aw)=="string",`"Tab.Title" 'string' expected, got {typeof(aw)}`)
assert(ax==nil or type(ax)=="string",`"Tab.Icon" 'string' expected, got {typeof(ax)}`)

-- DepHub: o icone da aba e resolvido pelo catalogo da PROPRIA biblioteca. Um
-- nome (ex.: "rocket", "sword", "cherry") vira o asset id real do redz; um
-- asset id cru passa direto; um nome que nao existe no catalogo vira nil -- e a
-- aba aparece SEM icone, que e o pedido ("se nao tiver, deixa sem"). Emoji nao
-- tem tratamento especial: nao e um nome do catalogo nem um asset id, entao
-- simplesmente nao resolve e a aba fica sem icone.
local ay=setmetatable({
Selected=self.SelectedTab==#S+1,
Icon=type(ax)=="string"and#ax>0 and Library:GetIconByName(ax) or nil,
Title=aw,

Parent=self,
IS_A_TAB=true
},ah)

local az=self:GetElements()
local aA=az.TabsContainer
local aB=az.ContainerHolder

local aC,aD,aE=al(self,ay,aA)

local aF=J(aD,"Size",UDim2.new(1,0,1,0),0.3)
local aG=UDim2.new(1,0,1,150)

local aH=0.45

local aI={
J(aE,"BackgroundTransparency",0,aH),
J(aE,"Size",UDim2.fromOffset(4,13),aH)
}

local aJ={
J(aE,"BackgroundTransparency",1,aH),
J(aE,"Size",UDim2.fromOffset(4,4),aH)
}

local aK=C:new()
V[ay]=aK local activeTabTweens={}
local aL=function(tweens)
for _,tween in ipairs(activeTabTweens) do
if tween.PlaybackState==Enum.PlaybackState.Playing then tween:Cancel() end
end
table.clear(activeTabTweens)
for index=1,#tweens do
local tween=tweens[index]
activeTabTweens[#activeTabTweens+1]=tween
tween:Play()
end
end local aM=function()



aL(aI)
ay.Selected=true
J(aC,"BackgroundColor3",w(Library.CurrentTheme,"Colors.Primary"),aH):Play()
J(aC,"BackgroundTransparency",0.85,aH):Play()
local titleLabel=aC:FindFirstChild("Title")
local iconImage=aC:FindFirstChild("ImageLabel")
if titleLabel then J(titleLabel,"TextTransparency",0,aH):Play() end
if iconImage then J(iconImage,"ImageTransparency",0,aH):Play() end
aK:changeRendering(true)
aK:update()
aD.Parent=aB
aD.Size=aG
aF:Play()end local aN=function()



aL(aJ)
ay.Selected=false
J(aC,"BackgroundTransparency",1,aH):Play()
local titleLabel=aC:FindFirstChild("Title")
local iconImage=aC:FindFirstChild("ImageLabel")
if titleLabel then J(titleLabel,"TextTransparency",0.3,aH):Play() end
if iconImage then J(iconImage,"ImageTransparency",0.3,aH):Play() end
aD.Parent=nil
aK:changeRendering(false)end


U[ay]=table.freeze{
Unselect=aN,
Select=aM
}

T[ay]=table.freeze{
SelectTabButton=aC,
Container=aD
}

table.insert(S,ay)

u(aC.Activated,function()
ay:Select()
end,nil,aC)

if ay.Selected then
ay:Select()
end

return ay
end

function ag:StartWindow(av)
local aw=av.MinimizeButton
local ax=av.MainFrame
local ay=av.Resizers
local az=av.TopBar

local aA=av.SubTitle
local aB=av.Title

Y=av.Dropdowns
ab=av.MainFrame
ad=av.UIScale
ae=av.Flags

local aC=ax.Size
local aD=0

function ag:MinimizeButton()
if(os.clock()-aD)<0 then
return false
end

if self.Minimized then
aw.Image="rbxassetid://10734896206"
J(ax,"Size",aC,0.25):Play()
else
aC=ax.Size
aw.Image="rbxassetid://10734924532"
J(ax,"Size",UDim2.fromOffset(ax.Size.X.Offset,az.Size.Y.Offset),0.25):Play()
end

for aE,aF in ay do
aF.Visible=self.Minimized
end

self.Minimized=not self.Minimized
aD=os.clock()+0.5

return true
end

function ag:GetTitle()
return aB.Text
end

function ag:GetSubTitle()
return aA.Text
end

function ag:SetTitle(aE)
assert(type(aE)=="string",`"Window.SetTitle". 'string' expected, got {typeof(aE)}`)
assert(#aE>0,"\"Window.SetTitle\". the new 'Title' is too short.")

aB.Text=aE
end

function ag:SetSubTitle(aE)
assert(type(aE)=="string",`"Window.SetSubTitle". 'string' expected, got {typeof(aE)}`)
assert(#aE>0,"\"Window.SetSubTitle\". the new 'SubTitle' is too short.")

aA.Text=aE
end

W=createInstance("Frame",I,{
Size=UDim2.new(0,280,1,0),
Position=UDim2.fromScale(1,0),
AnchorPoint=Vector2.new(1,0),
BackgroundTransparency=1,
Elements={
Padding={
PaddingBottom=UDim.new(0,20)
},
ListLayout={
HorizontalAlignment=Enum.HorizontalAlignment.Center,
VerticalAlignment=Enum.VerticalAlignment.Bottom,
SortOrder=Enum.SortOrder.LayoutOrder,
Padding=UDim.new(0,20)
}
}
})

aa=createInstance("TextButton","OutBox",{
Size=UDim2.fromScale(1,1),
BackgroundTransparency=0.3,
AutoButtonColor=false,
Text="",
ThemeTag={
BackgroundColor3="Colors.Buttons.Default"
},
Childs={
ax:FindFirstChildOfClass"UICorner":Clone(),
createInstance("Frame","Template",{
Size=UDim2.new(0.35,60,0.20,80),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
Active=true,
Elements={
Corner=UDim.new(0,6),
Gradient={
Rotation=45,
ThemeTag={
Color="Colors.Background"
}
}
},
Childs={
createInstance("TextLabel","Title",{
Size=UDim2.new(1,-20,0,20),
TextTruncate=Enum.TextTruncate.AtEnd,
TextSize=15,
Position=UDim2.new(0.5,0,0,28),
AnchorPoint=Vector2.new(0.5,0),
BackgroundTransparency=1,
ThemeTag={
Font="Font.ExtraBold",
TextColor3="Colors.Text.Default"
}
}),
createInstance("TextLabel","Description",{
Position=UDim2.new(0.5,0,0,46),
Size=UDim2.new(1,-20,0,0),
AnchorPoint=Vector2.new(0.5,0),
TextWrapped=true,
TextSize=11,
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
ThemeTag={
TextColor3="Colors.Text.Darker",
Font="Font.Medium"
}
}),
createInstance("Frame","Options",{
Size=UDim2.new(1,-20,0.15,18),
Position=UDim2.new(0.5,0,1,-10),
AnchorPoint=Vector2.new(0.5,1),
BackgroundTransparency=1,
Elements={
Padding={
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingBottom=UDim.new(0,30),
PaddingTop=UDim.new(0,30)
},
ListLayout={
HorizontalAlignment=Enum.HorizontalAlignment.Right,
VerticalAlignment=Enum.VerticalAlignment.Center,
FillDirection=Enum.FillDirection.Horizontal
}
}
})
}
})
}
})

aa.Template:SetAttribute("OriginalSize",aa.Template.Size)

u(aa.Activated,function()
if Z~=nil and not Z.Closing and not Z.Closed then
Z:Close()
end
end,nil,aa)

ag.StartWindow=nil
end

function ag:SaveProfile(name)
assert(type(name)=="string" and name:match("^[%w_-]+$"),`"Window.SaveProfile". profile name must contain only letters, numbers, '_' or '-'`)
local ok,encoded=pcall(HttpService.JSONEncode,HttpService,ae)
if not ok then return false end
return self:WriteFile("profile_"..name..".json",encoded)
end

function ag:LoadProfile(name)
assert(type(name)=="string" and name:match("^[%w_-]+$"),`"Window.LoadProfile". profile name must contain only letters, numbers, '_' or '-'`)
local content=self:ReadFile("profile_"..name..".json")
if type(content)~="string" then return false end
local ok,profile=pcall(HttpService.JSONDecode,HttpService,content)
if not ok or type(profile)~="table" then return false end
for flag,value in pairs(profile) do
if at[typeof(value)] then
 ae[flag]=value
 local option=Library.Options[flag]
 if option and option.Parent and not option.Destroyed then
  if option.Kind=="Toggle" and type(value)=="number" then pcall(option.SetValue,option,value==0)
  elseif option.Kind=="Slider" and type(value)=="number" then pcall(option.SetValue,option,value)
  elseif option.Kind=="TextBox" and type(value)=="string" then pcall(option.SetText,option,value)
  elseif option.Kind=="Dropdown" then pcall(option.SetValue,option,value)
  elseif option.Kind=="Keybind" and type(value)=="string" and Enum.KeyCode[value] then pcall(option.SetKeyCode,option,Enum.KeyCode[value])
  elseif option.Kind=="ColorPicker" and type(value)=="string" then
   local hex=value:gsub("^#","")
   if #hex==6 and tonumber(hex,16) then pcall(option.SetColor,option,Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))) end
  end
 end
end
end
return true
end

function ag:DeleteProfile(name)
assert(type(name)=="string" and name:match("^[%w_-]+$"),`"Window.DeleteProfile". profile name must contain only letters, numbers, '_' or '-'`)
return self:WriteFile("profile_"..name..".json",nil)
end

function ag:DeleteFlags()
return ae()
end

function ag:SetFlag(av,aw)
assert(type(av)=="string",`"Window.SetFlag[param 1]". 'string' expected, got {typeof(av)}`)

if at[typeof(aw)]~=true then
local ax={}

for ay,az in at do
table.insert(ax,ay)
end

return error(`"Window.SetFlag[param 2]". '{table.concat(ax,"', '")}' expected, got {typeof(aw)}`,2)
end

ae[av]=aw
end

function ag:GetFlag(av)
return ae[av]
end

function ag:ReadFile(av)
assert(type(av)=="string",`"Window.ReadFile[param 1]". 'string' expected, got {typeof(av)}`)
local path=self.ScriptFolder and (`{self.ScriptFolder}/{av}`) or av
if not readFileSafe then return nil end
if isfile then
local ok,exists=pcall(isfile,path)
if not ok or not exists then return nil end
end
local ok,result=pcall(readFileSafe,path)
if ok then return result end
return nil
end

function ag:WriteFile(av,aw)
assert(type(av)=="string",`"Window.WriteFile[param 1]". 'string' expected, got {typeof(av)}`)
if aw~=nil and type(aw)~="string"then
error(`"Window.WriteFile[param 2]". 'string', or 'nil' expected, got {typeof(aw)}`,2)
end
local path=self.ScriptFolder and (`{self.ScriptFolder}/{av}`) or av
if aw==nil then
if deleteFileSafe then
if isfile then
local ok,exists=pcall(isfile,path)
if not ok or not exists then return false end
end
local ok=pcall(deleteFileSafe,path)
return ok
end
else
if writeFileSafe then
z(path,aw)
return true
end
end
return false
end

function ag:NewMinimizer(av)
local aw=type(av)=="table"and(av[1]or av.KeyCode)or av

if not au(aw)then
error(`"Window.NewMinimizer.KeyCode". 'KeyCode' expected, got {typeof(aw)}`,2)
end

local ax=setmetatable({
KeyCode=aw
},aj)

u(UserInputService.InputBegan,function(ay,az)
-- Ignora entrada ja processada (digitacao no chat/TextBox): sem isso a tecla
-- de abrir/fechar dispara enquanto o usuario escreve. Somente teclado.
if az or ay.UserInputType~=Enum.UserInputType.Keyboard then return end
if ay.KeyCode==ax.KeyCode then
ag:Minimize()
end
end,nil,I)

return ax
end

function ag:Dialog(av)
if self.Minimized then
while not self:MinimizeButton()do task.wait()end
end

if Z then
Z:Close(true)
end

local aw=av.Title or av.Name
local ax=av.Content or av.Description
local ay=av.Options

assert(type(aw)=="string",`"Window.Dialog.Title". 'string' expected, got {typeof(aw)}`)
assert(type(ax)=="string",`"Window.Dialog.Content". 'string' expected, got {typeof(ax)}`)
assert(type(ay)=="table",`"Window.Dialog.Options". 'table' expected, got {typeof(ay)}`)
assert(#ay>0,"\"Window.Dialog.Options\". requires one or more options.")local az=function()


local az=aa.Template
local aA=az.Description
local aB=az.Title

local aC=az:GetAttribute"OriginalSize"
local aD=UDim2.new(aC.X.Scale*1.2,aC.X.Offset,aC.Y.Scale*1.2,aC.Y.Offset)

az.Size=aD
aa.Parent=ab
aA.Text=ax
aB.Text=aw

J(az,"Size",aC,0.3):Play()

local aE=ak.Dialog.new(aA,aB)
aE.ThemeGroup=C:new()
aE.NEW_SIZE=aD
aE.TEMPLATE=az
if aa:GetAttribute("DepHubOriginalBackgroundTransparency")==nil then
 aa:SetAttribute("DepHubOriginalBackgroundTransparency",aa.BackgroundTransparency)
end
aa.BackgroundTransparency=aa:GetAttribute("DepHubOriginalBackgroundTransparency")
for _,object in ipairs(az:GetDescendants()) do
if object:IsA("GuiObject") then
if object:GetAttribute("DepHubOriginalBackgroundTransparency")==nil then
object:SetAttribute("DepHubOriginalBackgroundTransparency",object.BackgroundTransparency)
end
object.BackgroundTransparency=object:GetAttribute("DepHubOriginalBackgroundTransparency")
end
if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
if object:GetAttribute("DepHubOriginalTextTransparency")==nil then
object:SetAttribute("DepHubOriginalTextTransparency",object.TextTransparency)
end
object.TextTransparency=object:GetAttribute("DepHubOriginalTextTransparency")
end
if object:IsA("ImageLabel") or object:IsA("ImageButton") then
if object:GetAttribute("DepHubOriginalImageTransparency")==nil then
object:SetAttribute("DepHubOriginalImageTransparency",object.ImageTransparency)
end
object.ImageTransparency=object:GetAttribute("DepHubOriginalImageTransparency")
end
if object:IsA("UIStroke") then
if object:GetAttribute("DepHubOriginalStrokeTransparency")==nil then
object:SetAttribute("DepHubOriginalStrokeTransparency",object.Transparency)
end
object.Transparency=object:GetAttribute("DepHubOriginalStrokeTransparency")
end
end
az.BackgroundTransparency=0

for aF,aG in az.Options:GetChildren()do
if aG:IsA"GuiObject"then
aG:Destroy()
end
end

for aF=#ay,1,-1 do
aE:NewOption(ay[aF])
end

return aE end


Z=az()
return Z
end

function ag:SetNotifyDefaultIcon(av)
assert(type(av)=="string",`"Window.SetNotifyDefaultIcon[param 1]". 'string' expected, got {typeof(av)}`)

af=av
end

function ag:GetNotificationHistory()
local history={}
for index,entry in ipairs(notificationHistory) do history[index]=table.clone(entry) end
return history
end

function ag:ClearNotificationHistory()
table.clear(notificationHistory)
end

function ag:Notify(av)
if type(av)~="table"then
av={}
end

local aw=av[1]or av.Name or av.Title
local ax=av[2]or av.Content
local ay=av[3]or av.Icon or av.Image
local az=av[4]or av.Duration or av.Countdown or av.Time

if self.NOTIFICATION_GROUP then
if az==nil then az=self.Duration end
if ax==nil then ax=self.Content end
if aw==nil then aw=self.Title end
if ay==nil then ay=self.Icon end
end

assert(type(aw)=="string",`"Window.Notify.Title". 'string' expected, got {typeof(aw)}`)
assert(type(ax)=="string",`"Window.Notify.Content". 'string' expected, got {typeof(ax)}`)
assert(ay==nil or type(ay)=="string",`"Window.Notify.Icon". 'nil' or 'string' expected, got {typeof(ay)}`)

if az~=nil and type(az)~="number"then
error(`"Window.Notify.Time". 'number', or 'nil' expected, got {typeof(az)}`,2)
elseif az==nil then
az=5
end

notificationHistory[#notificationHistory+1]={Title=aw,Content=ax,Icon=ay,Duration=az,Timestamp=os.clock()}
if #notificationHistory>100 then table.remove(notificationHistory,1) end
local notificationThemeGroup=C:new()
local aA=createInstance("Frame","Notification",W,{
Size=UDim2.new(0.85,0,0,60),
BackgroundTransparency=1,
AutomaticSize=Enum.AutomaticSize.Y
})

local aB=createInstance("TextButton",aA,{
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.fromScale(1,1),
AutoButtonColor=false,
Text="",
ThemeTag={
OBJECTS=notificationThemeGroup,
BackgroundTransparency="BackgroundTransparency"
},
Elements={
Corner=UDim.new(0,9),
Gradient={
Rotation=45,
ThemeTag={
OBJECTS=notificationThemeGroup,
Color="Colors.Background"
}
}
}
})

local aC=createInstance("UIScale",aA)

local aD=createInstance("Frame","Holder",aB,{
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
Elements={
ListLayout={
SortOrder=Enum.SortOrder.LayoutOrder,
VerticalAlignment=Enum.VerticalAlignment.Center,
Padding=UDim.new(0,4)
},
Padding={
PaddingBottom=UDim.new(0,8),
PaddingTop=UDim.new(0,8),
PaddingLeft=UDim.new(0,40)
}
}
})

local aE=createInstance("TextLabel",aD,{
Size=UDim2.new(1,0,0,20),
TextTruncate=Enum.TextTruncate.AtEnd,
TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Bottom,
BackgroundTransparency=1,
TextSize=14,
ThemeTag={
OBJECTS=notificationThemeGroup,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aF=createInstance("TextLabel",aD,{
Size=UDim2.new(1,0,0,20),
TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Top,
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
TextWrapped=true,
TextSize=12,
ThemeTag={
OBJECTS=notificationThemeGroup,
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})

local aG=createInstance("ImageLabel",aB,{
Size=UDim2.fromOffset(24,24),
Position=UDim2.new(0,8,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
BackgroundTransparency=1,
ThemeTag={
OBJECTS=notificationThemeGroup,
ImageColor3="Colors.Icons"
}
})

local aH=createInstance("TextLabel",aB,{
Size=UDim2.new(0,40,0,16),
Position=UDim2.new(1,-10,0,8),
AnchorPoint=Vector2.new(1,0),
BackgroundTransparency=1,
TextSize=10,
ThemeTag={
OBJECTS=notificationThemeGroup,
TextColor3="Colors.Text.Darker",
Font="Font.Normal"
}
})

local aI=false

local aJ=J(aC,"Scale",0.97,0.12)
local aK=J(aC,"Scale",1.00,0.35)

local progressTrack=createInstance("Frame","ProgressTrack",aB,{
Size=UDim2.new(1,-16,0,2),
Position=UDim2.new(0,8,1,-4),
AnchorPoint=Vector2.new(0,1),
BorderSizePixel=0,
BackgroundColor3=w(Library.CurrentTheme,"Colors.Stroke"),
ThemeTag={OBJECTS=notificationThemeGroup,BackgroundColor3="Colors.Stroke"}
})
local progressFill=createInstance("Frame","Progress",progressTrack,{
Size=UDim2.fromScale(1,1),
BorderSizePixel=0,
BackgroundColor3=w(Library.CurrentTheme,"Colors.Primary"),
ThemeTag={OBJECTS=notificationThemeGroup,BackgroundColor3="Colors.Primary"}
})

local aL=setmetatable({
TITLE_LABEL=aE,
DESCRIPTION_LABEL=aF,
VISIBLE_ELEMENT=aA,
DESTROY_ELEMENT=aA,
NOTIFICATION=aB,

Kind="Notification",
Closed=false,
Parent=self
},ai)

function aL:Close()
if self.Closed==true then return end
self.Closed=true
local exitTween=J(aB,"Position",UDim2.fromScale(1.15,0),0.22)
local scaleTween=J(aC,"Scale",0.94,0.22)
exitTween:Play()
scaleTween:Play()
exitTween.Completed:Wait()
if aA.Parent then aA:Destroy() end
if notificationThemeGroup then notificationThemeGroup:destroy() notificationThemeGroup=nil end
for index=#activeNotifications,1,-1 do
if activeNotifications[index]==self then table.remove(activeNotifications,index) end
end
self.Destroyed=true
setmetatable(self,nil)
end local aM=function()


local resolvedIcon=Library:GetIconByName(ay or af)
if O(resolvedIcon) then
aG.Image=resolvedIcon
aG.Visible=true
else
aG.Image=""
aG.Visible=false
aD.UIPadding.PaddingLeft=UDim.new(0,15)
end

aB.Position=UDim2.fromScale(3,0)
J(aB,"Position",UDim2.fromScale(0,0),0.35):Play()

aE.Text=aw
aF.Text=ax

local aM=aB.MouseLeave
local totalDuration=math.max(az,0.1)
local lastCountdown=nil
while az>0 and not aL.Closed do
local countdown=math.ceil(az*10)/10
if countdown~=lastCountdown then
aH.Text=Q(countdown)
lastCountdown=countdown
end
progressFill.Size=UDim2.new(math.clamp(az/totalDuration,0,1),0,1,0)
az-=task.wait(0.05)
end

aL:Close()end


u(aB.MouseButton1Down,function()aJ:Play()aI=true end,nil,aA)
u(aB.MouseLeave,function()aK:Play()aI=false end,nil,aA)

activeNotifications[#activeNotifications+1]=aL
while #activeNotifications>4 do
local oldest=activeNotifications[1]
if oldest and not oldest.Closed then
oldest:Close()
else
table.remove(activeNotifications,1)
end
end

task.defer(aM)

return aL
end

function ag:NewNotifyGroup(av)
local aw=av[1]or av.Name or av.Title
local ax=av[2]or av.Content
local ay=av[3]or av.Icon or av.Image
local az=av[4]or av.Duration or av.Countdown or av.Time

if aw~=nil and type(aw)~="string"then
error(`"Window.NewNotifyGroup.Title". 'string', or 'nil' expected, got {typeof(aw)}`,2)
end

if ax~=nil and type(ax)~="string"then
error(`"Window.NewNotifyGroup.Content". 'string', or 'nil' expected, got {typeof(ax)}`,2)
end

if ay~=nil and type(ay)~="string"then
error(`"Window.NewNotifyGroup.Icon". 'string', or 'nil' expected, got {typeof(ay)}`,2)
end

if az~=nil and type(az)~="number"then
error(`"Window.NewNotifyGroup.Time". 'number', or 'nil' expected, got {typeof(az)}`,2)
end

return{
NOTIFICATION_GROUP=true,
Notify=ag.Notify,

Duration=az,
Content=ax,
Title=aw,
Icon=ay,
}
end

function ag:GetTabByTitle(av)
assert(type(av)=="string",`"Window.GetTabByTitle[param 1]". 'string' expected, got {typeof(av)}`)

for aw=1,#S do
if S[aw].Title==av then
return S[aw]
end
end
end

ag.NewNotificationGroup=ag.NewNotifyGroup
ag.SetDefaultNotifyIcon=ag.SetNotifyDefaultIcon
ag.GetTabByName=ag.GetTabByTitle
ag.Notificafion=ag.Notify

R.Window=ag
end local aa=function(

aa, ab)
local ac=ab.Size.Y.Offset
local ad=UDim2.new(0,aa.TabSize or Library.Default.TabSize,1,-ac)
local ae=UDim2.new(1,-ad.X.Offset,1,-ac)

local af=createInstance("ScrollingFrame","TabsScroll",{
AutomaticCanvasSize=Enum.AutomaticSize.Y,
ScrollingDirection=Enum.ScrollingDirection.Y,
Position=UDim2.new(0,0,1,0),
AnchorPoint=Vector2.new(0,1),
ScrollBarThickness=UserInputService.TouchEnabled and 5 or 2.2,
BackgroundTransparency=1,
ScrollBarImageTransparency=0.2,
CanvasSize=UDim2.new(),
BorderSizePixel=0,
Size=ad,
ThemeTag={
ScrollBarImageColor3="Colors.ScrollBar"
},
Elements={
Padding={
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingTop=UDim.new(0,10),
PaddingBottom=UDim.new(0,10)
},
ListLayout={
Padding=UDim.new(0,5)
}
}
})

local ag=createInstance("Frame","Containers",{
Size=ae,
AnchorPoint=Vector2.new(1,1),
Position=UDim2.new(1,0,1,0),
BackgroundTransparency=1,
ClipsDescendants=true
})

return af,ag end



-- ===========================================================================
-- SECTION: Module-level API
-- GetIconByName / IsValidTheme / GetThemes / GetTheme / SetTheme / SetUIScale /
-- GetMaxScale / GetMinScale / GetCurrentTheme / Destroy / MakeWindow.
-- ===========================================================================
function Library:GetIconByName(ab)
if ab==nil then return end
assert(ab,`"Library.GetIconByName". 'string' expected, got {typeof(ab)}`)

if O(ab)or#ab==0 then
return ab
end

local ac=M(ab)

if self.Icons[ac]then
return"rbxassetid://"..self.Icons[ac]
end

for ad,ae in self.Icons do
if ad:find(ac,1,true)then
return"rbxassetid://"..ae
end
end
end

function Library:IsValidTheme(ab)
assert(type(ab)=="string",`"Library.IsValidTheme". string extected, got {typeof(ab)}`)

return self.Themes[ab]~=nil
end

function Library:GetThemes()
local ab={}
for ac,ad in self.Themes do
table.insert(ab,ac)
end
return ab
end

function Library:GetTheme(ab)
assert(ab==nil or type(ab)=="string",`"Library.GetTheme". 'string' expected, got {typeof(ab)}`)

if ab==nil then
return self.CurrentTheme
end

local ac=self.Themes[ab]
assert(ac~=nil,`"Library.GetTheme". theme not found: {ab}`)
return ac
end

function Library:SetTheme(ab)
assert(type(ab)=="string",`"Library.SetTheme". string extected, got {typeof(ab)}`)
local ac=self.Themes[ab]
assert(ac,`"Library.SetTheme". theme not found: {ab}`)

self.CurrentTheme=ac
if self.WindowSettings then self.WindowSettings.SelectedTheme=ac.Name end
local function resetThemeGroups(group)
if not group then return end
group.UPDATED_OBJECTS=false
for _,child in pairs(group.Descendants or {}) do
if type(child)=="table" and child.Descendants then
resetThemeGroups(child)
end
end
end
resetThemeGroups(C)
C:update()
end

function Library:SetReducedMotion(enabled)
assert(type(enabled)=="boolean",`"Library.SetReducedMotion". 'boolean' expected, got {typeof(enabled)}`)
ReducedMotion=enabled
self.ReducedMotion=enabled
return self
end

function Library:SetAccent(color)
assert(typeof(color)=="Color3",`"Library.SetAccent". 'Color3' expected, got {typeof(color)}`)
local theme=self.CurrentTheme or self.Themes[self.Default.Theme]
assert(theme and theme.Colors,`"Library.SetAccent". current theme is unavailable`)
theme.Colors.Primary=color
theme.Colors.Slider.SliderBar=color
theme.Colors.OnPrimary=color:Lerp(theme.Colors.Text.Default,0.55)
self.CurrentTheme=theme
if self.LOADED_UI_LIBRARY then
self:SetTheme(theme.Name)
end
return self
end

function Library:SetUIScale(ab)
local ac=B.MIN_SCALE
local ad=B.MAX_SCALE

assert(type(ab)=="number",`"Library.SetUIScale". 'number' expected, got {typeof(ab)}`)
assert(ab>=ac and ab<=ad,`"Library.SetUIScale". Min Scale: {ac}, Max Scale: {ad}`)

I.Scale.Scale=P(ab)
end

function Library:GetMaxScale()
return B.MAX_SCALE
end

function Library:GetMinScale()
return B.MIN_SCALE
end

function Library:GetCurrentTheme()
if not self.LOADED_UI_LIBRARY then
return error("failed to get current theme: UI is not loaded",2)
end
return self.CurrentTheme
end

function Library:Destroy()
for _,connection in ipairs(self.Connections) do
pcall(function() connection:Disconnect() end)
end
table.clear(self.Connections)
table.clear(self.Options)

if I and I:GetAttribute"UID"==self.SCREENGUI_UID then
pcall(I.Destroy,I)
end
end

function Library:MakeWindow(ab)
if self.LOADED_UI_LIBRARY then
return error("you can create only 1 Window",2)
end

local ac=math.random()
I:SetAttribute("UID",ac)
self.SCREENGUI_UID=ac
I:ClearAllChildren()

local camera=Services.Workspace.CurrentCamera
local viewportSize=camera and camera.ViewportSize or I.AbsoluteSize
local responsiveScale=math.min(1,viewportSize.X/900,viewportSize.Y/500)
local ad=createInstance("UIScale","Scale",I,{
Scale=P(math.max(0.3,responsiveScale))
})
local function updateResponsiveScale()
local currentCamera=Services.Workspace.CurrentCamera
if not currentCamera then return end
local size=currentCamera.ViewportSize
local scale=math.min(1,size.X/900,size.Y/500)
ad.Scale=math.max(0.3,scale)
end
if camera then
u(camera:GetPropertyChangedSignal("ViewportSize"),updateResponsiveScale,nil,I)
end
u(Services.Workspace:GetPropertyChangedSignal("CurrentCamera"),function()
local currentCamera=Services.Workspace.CurrentCamera
if currentCamera then
u(currentCamera:GetPropertyChangedSignal("ViewportSize"),updateResponsiveScale,nil,I)
updateResponsiveScale()
end
end,nil,I)

local ae={
Title=ab[1]or ab.Name or ab.Title,
SubTitle=ab[2]or ab.SubName or ab.SubTitle,
ScriptFolder=ab[3]or ab.ScriptFolder or ab.FolderName
}

assert(type(ae.Title)=="string",`"Window.Title". 'string' expected, got {typeof(ae.Title)}`)
assert(type(ae.SubTitle)=="string",`"Window.SubTitle". 'string' expected, got {typeof(ae.SubTitle)}`)

if ae.ScriptFolder~=nil and type(ae.ScriptFolder)~="string"then
return error(`"Window.ScriptFolder". 'string', or nil expected, got {typeof(ae.ScriptFolder)}`,2)
end

if ae.ScriptFolder~=nil and string.find(ae.ScriptFolder,"/")then
return error("\"Window.ScriptFolder\" is not valid, unexpected char \"/\"",2)
end

local af=(function()
local af=ae.ScriptFolder
local ag=false

local ah,ai=pcall(function()
return af and HttpService:JSONDecode(readFileSafe(`{af}/LibrarySettings.json`))
end)

if type(ai)~="table"then
ai={}
end local aj=function()


ag=false

return pcall(function()
return z(`{af}/LibrarySettings.json`,HttpService:JSONEncode(ai))
end)end local ak=function(


ak, al, am)
rawset(ai,al,am)

if af and not ag then
ag=true
task.delay(0.5,aj)
end end


return setmetatable({},{
__newindex=ak,
__index=ai
})
end)()

local ag=(function()
local ag=ae.ScriptFolder
local ah=false

local ai,aj=pcall(function()
return ag and HttpService:JSONDecode(readFileSafe(`{ag}/ScriptFlags.json`))
end)

if type(aj)~="table"then
aj={}
end local ak=function()


ah=false

return pcall(function()
z(`{ag}/ScriptFlags.json`,HttpService:JSONEncode(aj))
end)end local al=function(


al, am, an)
rawset(aj,am,an)

if ag and not ah then
ah=true
task.delay(0.5,ak)
end end local am=function()



table.clear(aj)
return pcall(function()
return ag and deleteFileSafe(`{ag}/ScriptFlags.json`)
end)end


return setmetatable({},{
__newindex=al,
__call=am,
__index=aj
})
end)()

self.ThemesObjects=C
self.WindowSettings=af
self.Flags=ag

-- DepHub: a biblioteca e VENDORED no repo e nao pode ir a rede em runtime (o
-- bundle tem que ser self-contained). O redz original cai para um HttpGet no
-- GitHub quando nao acha o Icons.lua local; aqui esse fallback foi trocado por
-- uma tabela local no proprio repo. Sem ela o GetIconByName simplesmente nao
-- acha o nome e o controle sai sem icone -- que e o comportamento degradado que
-- o proprio redz ja tinha.
-- DepHub: o catalogo de icones e VENDORED no repo (src/core/redz-icons.lua) --
-- e o arquivo Icons.lua real que o redz publicava (818 nomes -> asset ids). O
-- redz original tentava loadstring({ScriptFolder}/Icons.lua) e caia para uma
-- tabela minuscula de 4 nomes; por isso qualquer outro icone saia vazio e a
-- shell forcava emoji. Aqui o catalogo completo entra primeiro, via o mesmo
-- caminho que o loader usa para os modulos, e o fallback de 4 nomes so existe
-- para o caso extremo de o catalogo nao carregar.
--
-- Os valores guardados sao ids SEM o prefixo rbxassetid:// -- o GetIconByName
-- (abaixo) e quem acrescenta o prefixo. Guardar o valor ja com prefixo faria
-- o id sair com dois "rbxassetid://" e o icone nao carregaria.
self.Icons=(function()
local ah=ae.ScriptFolder

-- 1) Catalogo real vendorado no repo (nomes -> "rbxassetid://id"). Normaliza
--    para guardar o valor sem prefixo, que e o formato que o GetIconByName usa.
--    Resolve o arquivo pelo mesmo caminho que o loader usa para os modulos: o
--    httpGet publicado (no bundle ele serve de BUNDLED_SOURCES, sem rede) ou,
--    sem ele, game:HttpGet da SourceBaseURL (execucao normal pela rede).
--
--    O resolver publicado devolve APENAS o corpo (uma string), enquanto o
--    httpGet interno do loader devolve (ok, corpo). Os dois formatos sao
--    aceitos aqui, e o caminho de rede so roda quando nao ha resolver nenhum --
--    assim o bundle nunca toca a rede (o verify_bundle falha se tocar).
local ao,ap=pcall(function()
    local base=(getgenv and getgenv().__DEPHUB and getgenv().__DEPHUB.SourceBaseURL)
        or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"
    local url=base.."src/core/redz-icons.lua"
    -- Aceita as duas formas: (corpo) e (ok, corpo). O resolver do bundle devolve
    -- so o corpo; o httpGet do loader devolve (ok, corpo). Se o corpo vier vazio
    -- a tentativa inteira e descartada.
    local function tryFetch(fn,arg)
        if type(fn)~="function"then return nil end
        local a,b=pcall(fn,arg)
        if not a then return nil end
        if type(a)=="string"and#a>0 and a~=true then return a end
        if type(b)=="string"and#b>0 then return b end
        return nil
    end
    local get=__dephubHttpGet or __DEPHUB_HTTP_GET
    local source=tryFetch(get,url) or tryFetch(get,"src/core/redz-icons.lua")
    if not source then return nil end
    local chunk=loadstring(source)
    if type(chunk)~="function"then return nil end
    return chunk()
end)
if ao and type(ap)=="table"then
    local normalized={}
    for name,value in pairs(ap)do
        if type(value)=="string"then
            normalized[name]=(value:gsub("^rbxassetid://",""))
        end
    end
    if next(normalized)~=nil then return normalized end
end

-- 2) Compatibilidade: o Icons.lua local do redz, se existir ao lado do script.
local ai,aj=pcall(function()
    return loadstring(readFileSafe(`{ah}/Icons.lua`))()
end)
if ai and type(aj)=="table"then
    local normalized={}
    for name,value in pairs(aj)do
        if type(value)=="string"then normalized[name]=(value:gsub("^rbxassetid://","")) end
    end
    return normalized
end

-- 3) Fallback minimo: os quatro nomes que a shell sempre teve. Valores SEM
--    prefixo (o GetIconByName acrescenta).
return{
layers="6031091004",
swords="6549167889",
cherry="6766380907",
map="6031280882",
}
end)()

if type(af.SelectedTheme)=="string"and self:IsValidTheme(af.SelectedTheme)then
self:SetTheme(af.SelectedTheme)
else
self:SetTheme(self.Default.Theme)
end

self.LOADED_UI_LIBRARY=true

local ah=self.Default.UISize

if af and type(af.UISize)=="table"then
local ak,al=unpack(af.UISize)

if type(ak)=="number"and type(al)=="number"then
local am=I.AbsoluteSize
ak=math.clamp(ak,850,1000)
al=math.clamp(al,480,500)
ah=UDim2.fromOffset(ak,al)
end
end

local ak=createInstance("Frame","Window",I,{
Position=UDim2.new(0.5,-ah.X.Offset/2,0.5,-ah.Y.Offset/2),
Active=true,
Size=ah,
ThemeTag={
BackgroundTransparency="BackgroundTransparency"
},
Elements={
Corner=UDim.new(0,8),
Gradient={
Rotation=45,
ThemeTag={
Color="Colors.Background"
}
}
}
})

u(ak.Destroying,function()
self:Destroy()
end,nil,I)

u(I:GetAttributeChangedSignal"UID",function()
self:Destroy()
ak:Destroy()
end,nil,I)

InstanceFactory.Draggable(ak,ad,0.5)

local al=createInstance("Folder","Components",ak)
local am=createInstance("Folder","Dropdowns",I)

local an=createInstance("Frame","TopBar",al,{
Size=UDim2.new(1,0,0,28),
BackgroundTransparency=1
})

local ao=createInstance("TextLabel","Title",an,{
TextXAlignment=Enum.TextXAlignment.Left,
AutomaticSize=Enum.AutomaticSize.XY,
Position=UDim2.new(0,15,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
Text=ae.Title,
TextSize=12,
BackgroundTransparency=1,
ThemeTag={
TextColor3="Colors.Text.Default",
Font="Font.Bold"
},
Childs={
createInstance("TextLabel","SubTitle",{
Size=UDim2.fromScale(0,1),
AutomaticSize="X",
AnchorPoint=Vector2.new(0,1),
Position=UDim2.new(1,5,0.9),
Text=ae.SubTitle,
BackgroundTransparency=1,
TextXAlignment="Left",
TextYAlignment="Bottom",
TextSize=9,
ThemeTag={
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})
}
})

local ap=createInstance("Folder","Buttons",an,{
Childs={
createInstance("ImageButton","Close",{
Size=UDim2.new(0,18,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
BackgroundColor3=Color3.fromRGB(255,35,35),
AutoButtonColor=false,
ThemeTag={
Image="Icons.Close"
},
Elements={
Corner=UDim.new(0.2,0)
}
}),
createInstance("ImageButton","Minimize",{
Size=UDim2.new(0,18,0,18),
Position=UDim2.new(1,-35,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
BackgroundColor3=Color3.new(1,1,1),
Image="rbxassetid://10734896206",
AutoButtonColor=false,
Elements={
Corner=UDim.new(0.2,0)
}
})
}
})

local aq=ap.Minimize
local ar=ap.Close

local as=setmetatable(ae,{
__index=R.Window
})

local at,au=aa(af,an)

at.Parent=al
au.Parent=al

local av=table.freeze{
ContainerHolder=au,
TabsContainer=at,
Components=al,
Dropdowns=am,
MainFrame=ak
}

function as:GetElements()
return av
end

local aw=createInstance("Frame","ControlWindowSize",ak,{
Size=UDim2.new(0,35,0,35),
Position=ak.Size,
AnchorPoint=Vector2.new(0.8,0.8),
BackgroundTransparency=1,
Active=true,
Elements={
Corner=UDim.new(0,6)
},
ThemeTag={
BackgroundColor3="Colors.OnPrimary"
}
})

local ax=createInstance("Frame","ControlTabsSize",ak,{
Size=UDim2.new(0,16,0.75,-30),
Position=UDim2.new(0,at.Size.X.Offset,0.5,15),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=1,
Active=true,
Elements={
Corner=UDim.new(0,6)
},
ThemeTag={
BackgroundColor3="Colors.OnPrimary"
}
})local ay=function(

ay)
local az=ay:GetAttribute"Resizing"
ay:SetAttribute("Resizing",os.clock())

if az and(os.clock()-az)<=0.1 then
return nil
end

J(ay,"BackgroundTransparency",0.5,0.3):Play()
while os.clock()-ay:GetAttribute"Resizing"<=0.1 do task.wait()end
J(ay,"BackgroundTransparency",1,0.4):Play()end


u(aw:GetPropertyChangedSignal"Position",function()
ay(aw)
local az=aw.Position
ak.Size=az
af.UISize={az.X.Offset,az.Y.Offset}
end,nil,aw)

u(ax:GetPropertyChangedSignal"Position",function()
ay(ax)
local az=ax.Position
at.Size=UDim2.new(0,az.X.Offset,1,-an.Size.Y.Offset)
au.Size=UDim2.new(1,-at.Size.X.Offset,1,-an.Size.Y.Offset)
af.TabSize=az.X.Offset
end,nil,ax)

InstanceFactory.Draggable(aw,ad,0.68,function(az,aA,aB,aC)
return UDim2.fromOffset(math.clamp(aA,850,1000),math.clamp(aC,480,500))
end)

InstanceFactory.Draggable(ax,ad,0.68,function(aA,aB)
return UDim2.new(0,math.clamp(aB,135,210),0.5,15)
end)

local aA={
Title="Close Window?",
Content="You Want Close UI?",
Options={
{
Title="Yes",
Callback=function()self:Destroy()end
},
{
Title="No"
}
}
}

u(aq.MouseEnter,function()aq.BackgroundTransparency=0.65 end,nil,aq)
u(aq.MouseLeave,function()aq.BackgroundTransparency=1.00 end,nil,aq)

u(ar.MouseEnter,function()ar.BackgroundTransparency=0.65 end,nil,ar)
u(ar.MouseLeave,function()ar.BackgroundTransparency=1.00 end,nil,ar)

as.SetUIScale=self.SetUIScale
as.SUBTITLE_LABEL=ao.SubTitle
as.TITLE_LABEL=ao

local aB=as:StartWindow{
Resizers={aw,ax},
MinimizeButton=aq,
Dropdowns=am,
MainFrame=ak,
TopBar=an,

SubTitle=ao.SubTitle,
Title=ao,

UIScale=ad,
Flags=ag
}

u(aq.Activated,function()
as:MinimizeButton()
end,nil,aq)

u(ar.Activated,function()
as:Dialog(aA)
end,nil,ar)

return as
end

return Library

local passed=0
local function check(value,message) assert(value,message);passed+=1 end
local function signal()
    local event={connections={}}
    function event:Connect(fn) local connection={Connected=true,fn=fn};function connection:Disconnect()self.Connected=false end;self.connections[#self.connections+1]=connection;return connection end
    function event:Fire(...) for _,connection in ipairs(table.clone(self.connections))do if connection.Connected then connection.fn(...)end end end
    return event
end
local Enum=setmetatable({}, {__index=function(t,category)local values=setmetatable({}, {__index=function(s,key)local value={Name=key,__enum=true};rawset(s,key,value);return value end});rawset(t,category,values);return values end})
local vectorMeta={}
vectorMeta.__sub=function(a,b)return setmetatable({X=a.X-b.X,Y=a.Y-b.Y},vectorMeta)end
vectorMeta.__index=function(self,key)if key=="Magnitude"then return math.sqrt(self.X*self.X+self.Y*self.Y)end end
local Vector2={new=function(x,y)return setmetatable({X=x,Y=y},vectorMeta)end}
local UDim={new=function(scale,offset)return{Scale=scale,Offset=offset}end}
local UDim2={}
function UDim2.new(x,ox,y,oy)return{X=UDim.new(x,ox),Y=UDim.new(y,oy)}end
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local Color3={};local colorMeta={__eq=function(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end}
function Color3.new(r,g,b)return setmetatable({R=r,G=g,B=b,__color=true},colorMeta)end
function Color3.fromRGB(r,g,b)return Color3.new(r/255,g/255,b/255)end
local originalTypeof=typeof
local function typeof(value)if type(value)=="table"and value.__color then return"Color3"elseif type(value)=="table"and value.__enum then return"EnumItem"end;return originalTypeof(value)end
local TweenInfo={new=function()return{}end}
local task={spawn=function(fn,...)return fn(...)end,defer=function(fn,...)return fn(...)end,delay=function()end,cancel=function()end,wait=function()end}
local events={InputBegan=true,InputChanged=true,InputEnded=true,MouseEnter=true,MouseLeave=true,MouseButton1Click=true,FocusLost=true,AncestryChanged=true,Changed=true,OnTeleport=true}
local gui={Frame=true,ScrollingFrame=true,TextLabel=true,TextButton=true,TextBox=true}
local methods,meta={},{}
function meta:__index(key)
    if methods[key]then return methods[key]end
    if key=="AbsoluteSize"then return self._props.TestSize or Vector2.new(410,62)end
    if key=="AbsolutePosition"then return self._props.TestPosition or Vector2.new(0,0)end
    if events[key]then self._signals[key]=self._signals[key]or signal();return self._signals[key]end
    return self._props[key]
end
function meta:__newindex(key,value)
    if key=="Parent"then local old=self._props.Parent;if old then local index=table.find(old._children,self);if index then table.remove(old._children,index)end end;self._props.Parent=value;if value then value._children[#value._children+1]=self end
    else local old=self._props[key];self._props[key]=value;if old~=value and self._signals[key]then self._signals[key]:Fire()end end
end
function methods:GetChildren()return table.clone(self._children)end
function methods:GetDescendants()local result={};for _,child in ipairs(self._children)do result[#result+1]=child;for _,sub in ipairs(child:GetDescendants())do result[#result+1]=sub end end;return result end
function methods:IsA(class)return self.ClassName==class or(class=="GuiObject"and gui[self.ClassName])end
function methods:FindFirstChild(name)for _,child in ipairs(self._children)do if child.Name==name then return child end end end
function methods:FindFirstChildOfClass(class)for _,child in ipairs(self._children)do if child:IsA(class)then return child end end end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),"Missing "..name)end
function methods:GetPropertyChangedSignal(key)self._signals[key]=self._signals[key]or signal();return self._signals[key]end
function methods:Destroy()for _,child in ipairs(self:GetChildren())do child:Destroy()end;for _,event in pairs(self._signals)do for _,connection in ipairs(event.connections)do connection:Disconnect()end end;self.Parent=nil end
local Instance={}
function Instance.new(class)return setmetatable({_props={ClassName=class,Name=class,Visible=true,Size=UDim2.fromOffset(0,0),Position=UDim2.fromOffset(0,0),Text=""},_children={},_signals={}},meta)end
local player=Instance.new("Player");player.Name,player.CameraMaxZoomDistance="Tester",128
local playerGui=Instance.new("PlayerGui");playerGui.Name,playerGui.Parent="PlayerGui",player
local camera=Instance.new("Camera");camera.ViewportSize=Vector2.new(1440,900)
local workspace=Instance.new("Workspace");workspace.CurrentCamera,workspace.DistributedGameTime=camera,125
local input=Instance.new("UserInputService")
local players={LocalPlayer=player,PlayerAdded=signal()}
local tween={}
function tween:Create(object,_,properties)local completed=signal();return{Completed=completed,Play=function()for key,value in pairs(properties)do object[key]=value end;completed:Fire()end,Cancel=function()end}end
local services={Players=players,Workspace=workspace,UserInputService=input,TweenService=tween}
local state={}
local game={JobId="job-test"}
function game:GetService(name)return assert(services[name],name)end
-- INSERT_SOURCES
function game:HttpGet(url)local path=url:gsub("^https://raw.githubusercontent.com/glowpkj/DepHub/main/",""):gsub("%?.*$","");return assert(sources[path],path)end
local sandbox=setmetatable({game=game,workspace=workspace,Instance=Instance,Enum=Enum,Vector2=Vector2,UDim=UDim,UDim2=UDim2,Color3=Color3,TweenInfo=TweenInfo,task=task,typeof=typeof,getgenv=function()return state end},{__index=getfenv(0)})
function sandbox.loadstring(source)local fn,err=loadstring(source);if fn then setfenv(fn,sandbox)end;return fn,err end
local init=assert(sandbox.loadstring(sources["library/init.lua"]));local Library=init()

local universal={Values={WalkSpeed=16,JumpPower=50,FlySpeed=70,ESPRange=2000,ESPTextSize=14,ESPColor=Color3.fromRGB(90,170,255),AimbotFOV=180,AimPart="Head",ChatMessage="Hi",ChatInterval=5},Toggles={WalkSpeed=false,Jump=false,Fly=false,Noclip=false,ESP=false,ESPNames=true,ESPHealth=true,ESPDistance=true,Chams=true,TeamColors=true,TeamCheck=false,Fullbright=false,InfiniteZoom=false,Aimbot=false,ChatLoop=false}}
for _,name in ipairs({"ApplyMovement","SetWalkSpeedEnabled","SetJumpEnabled","SetFly","SetNoclip","CreateTeleportTool","SetESP","SetFullbright","SetInfiniteZoom","SetChatLoop","Rejoin","ServerHop","RunDex"})do universal[name]=function()end end
function universal:SendChat()return true end
local window=Library.new({Mode="Universal",Backend=universal,Subtitle="UNIVERSAL"})
check(window.ScreenGui.Parent==playerGui and window.CurrentPage=="HOME","library creates and opens its window")
for _,name in ipairs({"MAIN","VISUAL","AIM","CHAT","SERVER","CONFIG"})do check(window.Pages[name]~=nil,"Universal content mounts "..name)end
check(#window.Responsive>20,"real Universal controls are registered")
local custom=window:CreateTab("TEST","TEST");local section=window:CreateSection(custom,"COMPONENTS")
local calls=0;local toggle=window:CreateToggle(section,{Title="Toggle",Default=false,Callback=function()calls+=1 end});toggle:SetValue(true);check(toggle:GetValue()and calls==1,"toggle setter and callback")
toggle:SetValue(false,true);check(calls==1,"toggle silent setter")
local slider=window:CreateSlider(section,{Title="Slider",Min=10,Max=20,Default=15,Callback=function()end});slider:SetValue(99,true);check(slider:GetValue()==20,"slider clamps values")
local dropdown=window:CreateDropdown(section,{Title="Dropdown",Values={"A","B"},Default="A",Callback=function()end});check(dropdown:SetValue("B",true)and dropdown:GetValue()=="B","dropdown selects valid value")
dropdown:SetValues({"X","Y","Z"},"Y",true);check(#dropdown:GetValues()==3 and dropdown:GetValue()=="Y","dropdown rebuilds dependent values")
dropdown.Button.MouseButton1Click:Fire();check(dropdown.Menu.Visible and dropdown.Instance.Size.Y.Offset>70,"dropdown expands inside layout")
local box=window:CreateInput(section,{Title="Input",Default="A",Callback=function()end});box:SetValue("B",true);check(box:GetValue()=="B","input setter")
local colorCalls=0;local color=window:CreateColor(section,{Title="Color",Default=Color3.fromRGB(1,2,3),Callback=function()colorCalls+=1 end});color.Boxes[1].Text="12";color.Boxes[2].Text="34";color.Boxes[3].Text="56";color.Button.MouseButton1Click:Fire();check(math.abs(color:GetValue().G-34/255)<0.001 and colorCalls==1,"RGB color editor applies arbitrary color")
window:OpenPage("TEST");check(custom.Instance.Visible and not window.Pages.HOME.Instance.Visible,"tab navigation switches pages")
camera.ViewportSize=Vector2.new(390,844);check(window.Compact and window.MainFrame.Size.X.Offset==370,"phone viewport enables compact layout")
check(box.Instance.Size.Y.Offset==112 and box.Box.Size.X.Scale==1,"compact input reflows below label")
window:SetOpen(false);window.ToggleButton.MouseButton1Click:Fire();check(window:IsOpen(),"floating button reopens window")
input.InputBegan:Fire({KeyCode=Enum.KeyCode.RightControl,UserInputType=Enum.UserInputType.Keyboard},false);check(not window:IsOpen(),"configured keyboard shortcut toggles window");window:SetOpen(true)
window.ToggleButton.TestSize=Vector2.new(56,56)
window.ToggleButton.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(20,20)})
input.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement,Position=Vector2.new(100,90)})
input.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1,Position=Vector2.new(100,90)})
check(window.ToggleButton.Position.X.Offset>=8 and window.SuppressToggleClick,"floating button drags without toggling window")
window:SafeCall(function()error("expected")end);check(#window.Notifications:GetChildren()>1,"callback errors become notifications")

local old=window
local fruitVFX={GetFruits=function()return{"Rumble"}end,GetColors=function()return{"Original","Roxo"}end,Apply=function()return true,"Applied"end,Restore=function()return true,"Restored"end}
local blox={Features={FruitVFX=fruitVFX},Toggles={},Values={}}
function blox:GetDashLength()return 1 end;function blox:GetToggle()return false end;function blox:SetToggle()return true end;function blox:SetDashLength()return true end;function blox:GetPreferredTeam()return"Pirates"end;function blox:SetPreferredTeam()return true end;function blox:SaveConfig()return true end
window=Library.new({Mode="BloxFruits",Backend=blox,Subtitle="BLOX FRUITS"})
check(old.Destroyed and window.Pages.MAIN and window.Pages.VISUAL and window.Pages.CONFIG,"Blox Fruits replaces previous window and mounts content")
local runtime={Features={},GetSnapshot=function()return{Health="Healthy",Dashboard={Ping=20,FPS=60,ScriptVersion="1"}}end}
for _,name in ipairs({"AutoFarm","InstantCook","AutoDrop","AutoFarmFriends"})do runtime.Features[name]={Enabled=false,Toggle=function()end}end
old=window;window=Library.new({Mode="RT3",Backend=runtime,Subtitle="RT3"})
check(old.Destroyed and window.Pages.MAIN and window.Pages.STATUS and window.Pages.CONFIG,"RT3 replaces previous window and mounts content")
local connections=table.clone(window.Connections);window:Destroy();check(window.Destroyed and window.ScreenGui==nil and state.__DEPHUB_FRONTEND==nil,"destroy releases UI and global handle")
for _,connection in ipairs(connections)do check(not connection.Connected,"destroy disconnects tracked listener")end
print(string.format("PASS %d library checks",passed))

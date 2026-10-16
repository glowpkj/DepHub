local passed=0
local function check(value,message) assert(value,message);passed+=1 end
local function signal()
    local event={connections={}}
    function event:Connect(fn) local connection={Connected=true,fn=fn};function connection:Disconnect()self.Connected=false end;self.connections[#self.connections+1]=connection;return connection end
    function event:Fire(...) for _,connection in ipairs(table.clone(self.connections))do if connection.Connected then connection.fn(...)end end end
    function event:Once(fn)
        local connection
        connection=self:Connect(function(...) connection:Disconnect(); fn(...) end)
        return connection
    end
    return event
end
local Enum=setmetatable({}, {__index=function(t,category)local values=setmetatable({}, {__index=function(s,key)local value={Name=key,__enum=true};rawset(s,key,value);return value end});rawset(t,category,values);return values end})
local vectorMeta={}
vectorMeta.__add=function(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y},vectorMeta)end
vectorMeta.__div=function(a,b)return setmetatable({X=a.X/b,Y=a.Y/b},vectorMeta)end
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
local queued={}
local task={spawn=function(fn,...) local thread=type(fn)=="thread" and fn or coroutine.create(fn);queued[#queued+1]=thread;return thread end,defer=function(fn,...)return fn(...)end,delay=function()end,cancel=function(thread) if type(thread)=="thread" and coroutine.status(thread)~="dead" then coroutine.close(thread) end end,wait=function()coroutine.yield()end}
local events={InputBegan=true,InputChanged=true,InputEnded=true,MouseEnter=true,MouseLeave=true,MouseButton1Click=true,FocusLost=true,AncestryChanged=true,Changed=true,OnTeleport=true,DescendantRemoving=true,Destroying=true}
local gui={Frame=true,ScrollingFrame=true,TextLabel=true,TextButton=true,TextBox=true}
local methods,meta={},{}
function meta:__index(key)
    if methods[key]then return methods[key]end
    if key=="AbsoluteSize"then return self._props.TestSize or Vector2.new(410,62)end
    if key=="AbsoluteContentSize"then return Vector2.new(200,400)end
    if key=="AbsolutePosition"then return self._props.TestPosition or Vector2.new(0,0)end
    if events[key]then self._signals[key]=self._signals[key]or signal();return self._signals[key]end
    if self._props[key]~=nil then return self._props[key] end
    for _,child in ipairs(self._children)do if child.Name==key then return child end end
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
function methods:TweenSize(value)self.Size=value end
function methods:TweenPosition(value)self.Position=value end
function methods:Clone()
    local props=table.clone(self._props);props.Parent=nil
    local result=setmetatable({_props=props,_children={},_signals={}},meta)
    for _,child in ipairs(self:GetChildren())do local cloned=child:Clone();cloned.Parent=result end
    return result
end
function methods:Destroy()if self._signals.Destroying then self._signals.Destroying:Fire()end;for _,child in ipairs(self:GetChildren())do child:Destroy()end;for _,event in pairs(self._signals)do for _,connection in ipairs(event.connections)do connection:Disconnect()end end;self.Parent=nil end
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
local core=Instance.new("CoreGui")
local run={RenderStepped=signal(),Heartbeat=signal()}
function run.RenderStepped:Wait()coroutine.yield()end
function player:GetMouse()return {X=0,Y=0,Icon=""}end
function input:IsMouseButtonPressed()return false end
function input:IsKeyDown()return false end
local textService={GetTextSize=function(_,text,size) return Vector2.new(#text*(size or 14)/2,20) end}
local services={Players=players,Workspace=workspace,UserInputService=input,TweenService=tween,CoreGui=core,RunService=run,TextService=textService}
local state={}
local game={JobId="job-test"}
function game:GetService(name)return assert(services[name],name)end
-- INSERT_SOURCES
function game:HttpGet(url)local path=url:gsub("^https://raw.githubusercontent.com/glowpkj/DepHub/main/",""):gsub("%?.*$","");return assert(sources[path],path)end
function Color3.toHSV(c)
    local max,min=math.max(c.R,c.G,c.B),math.min(c.R,c.G,c.B);local diff=max-min;local hue=0
    if diff>0 then if max==c.R then hue=((c.G-c.B)/diff)%6 elseif max==c.G then hue=(c.B-c.R)/diff+2 else hue=(c.R-c.G)/diff+4 end;hue=hue/6 end
    return hue,max==0 and 0 or diff/max,max
end
function Color3.fromHSV(h,s,v)
    local k=h*6;local i=math.floor(k);local f=k-i;local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    local values={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}};local rgb=values[i%6+1];return Color3.new(unpack(rgb))
end
colorMeta.__index={ToHex=function(c)return string.format("%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end}
local sequence={new=function(...)return {...}end}
local logs={}
local sandbox=setmetatable({ColorSequence=sequence,ColorSequenceKeypoint=sequence,NumberSequence=sequence,NumberSequenceKeypoint=sequence,print=function()end,warn=function(message)logs[#logs+1]=message end,game=game,workspace=workspace,Instance=Instance,Enum=Enum,Vector2=Vector2,UDim=UDim,UDim2=UDim2,Color3=Color3,TweenInfo=TweenInfo,task=task,typeof=typeof,getgenv=function()return state end},{__index=getfenv(0)})
function sandbox.loadstring(source)local fn,err=loadstring(source);if fn then setfenv(fn,sandbox)end;return fn,err end
local function module(path)return assert(sandbox.loadstring(sources[path]))()end
local Adapter=module("src/frontend/linoria.lua")
local Main=module("src/frontend/main.lua")
local mountCalls=0
local universal={Values={WalkSpeed=16,JumpPower=50,FlySpeed=70,ESPRange=2000,ESPTextSize=14,ESPColor=Color3.fromRGB(90,170,255),AimbotFOV=180,AimPart="Head",ChatMessage="Hi",ChatInterval=5},Toggles={WalkSpeed=false,Jump=false,Fly=false,Noclip=false,ESP=false,ESPNames=true,ESPHealth=true,ESPDistance=true,Chams=true,TeamColors=true,TeamCheck=false,Fullbright=false,InfiniteZoom=false,Aimbot=false,ChatLoop=false}}
for _,name in ipairs({"ApplyMovement","SetWalkSpeedEnabled","SetJumpEnabled","SetFly","SetNoclip","CreateTeleportTool","SetESP","SetFullbright","SetInfiniteZoom","SetChatLoop","Rejoin","ServerHop","RunDex"})do universal[name]=function()mountCalls+=1 end end
function universal:SendChat()mountCalls+=1;return true end
function universal:Destroy()self.Destroyed=true end
local window=Main.new({Mode="Universal",Backend=universal,Title="DEPHUB",Subtitle="UNIVERSAL"})
check(window.Library.ScreenGui.Parent==playerGui and window:IsOpen(),"actual Linoria mounts visible under PlayerGui")
check(mountCalls==0,"registering OnChanged does not start backend actions")
for _,name in ipairs({"MAIN","VISUAL","AIM","CHAT","SERVER","CONFIG"})do check(window.Pages[name]~=nil,"Universal preserves tab "..name)end
check(window.Library.CreateWindow~=nil and sources["library/compact.lua"]==nil,"Linoria is the only renderer")
local section=window:CreateSection(window:CreateTab("TEST","Test"),"Controls")
local calls=0
local toggle=window:CreateToggle(section,{Title="Toggle",Default=false,Callback=function()calls+=1 end})
check(calls==0,"native initial callback is suppressed")
toggle:SetValue(true);check(calls==1 and toggle:GetValue(),"native toggle reaches backend once")
toggle:SetValue(false,true);check(calls==1 and not toggle:GetValue(),"silent toggle updates native UI without callback")
local rejected=window:CreateToggle(section,{Title="Rejected",Default=false,Callback=function()return false end})
check(not rejected:SetValue(true) and rejected:GetValue()==false,"backend rejection rolls native toggle back")
local failed=window:CreateToggle(section,{Title="Failed",Default=false,Callback=function()error("expected failure")end})
check(not failed:SetValue(true) and not failed:GetValue() and not window.Destroyed,"callback exception does not destroy UI")
local slider=window:CreateSlider(section,{Title="Slider",Min=0,Max=2,Default=1,Step=0.1,Callback=function()calls+=1 end})
slider:SetValue(9,true);check(slider:GetValue()==2 and calls==1,"native slider clamps and respects silent updates")
check(not slider:SetValue(0/0) and not slider:SetValue(math.huge),"slider rejects NaN and infinity")
local dropdown=window:CreateDropdown(section,{Title="Dropdown",Values={"A","B"},Default="A",Callback=function()calls+=1 end})
check(dropdown:GetValue()=="A","native dropdown selects default by index")
dropdown:SetValue("B");check(dropdown:GetValue()=="B" and calls==2,"native dropdown invokes updated callback once")
dropdown:SetValues({"X","Y"},"Y",true)
check(dropdown:GetValue()=="Y" and #dropdown:GetValues()==2 and calls==2,"dependent dropdown rebuild is silent and preserves selected value")
check(not dropdown:SetValue("missing"),"dropdown rejects missing values")
local inputControl=window:CreateInput(section,{Title="Input",Default="old",Callback=function(value)check(value=="new","input callback observes new value")end})
inputControl:SetValue("new");check(inputControl:GetValue()=="new","native input uses corrected value ordering")
local colors=0
local color=window:CreateColor(section,{Title="Color",Default=Color3.fromRGB(1,2,3),Callback=function()colors+=1 end})
color:SetValue(Color3.fromRGB(12,34,56));check(colors==1 and math.abs(color:GetValue().G-34/255)<0.001,"native color picker calls once with updated RGB")
local status=window:AddStatus("STATUS");status:Set("line one\nline two\nline three")
check(status.Raw.TextLabel.Text:find("line three",1,true)~=nil and status.Raw.TextLabel.Size.Y.Offset>=45,"status uses multiline native Linoria label")
window:SetOpen(false);check(not window:IsOpen(),"window hides through native holder")
window:SetOpen(true);check(window:IsOpen(),"window reopens through native holder")
local menuKey
for _,option in pairs(window.Library.Options)do if option.Type=="KeyPicker"then menuKey=option;break end end
check(menuKey~=nil,"menu uses native Linoria key picker")
menuKey:DoClick();check(not window:IsOpen(),"native menu key action hides window")
menuKey:DoClick();check(window:IsOpen(),"native menu key action reopens window")
local conns=table.clone(window.Library.Connections)
local threads={};for thread in pairs(window.Library.Threads)do threads[#threads+1]=thread end
window:Destroy();window:Destroy()
check(window.Destroyed and universal.Destroyed and state.__DEPHUB_LINORIA==nil,"unload is idempotent and destroys backend")
check(window.Library.ScreenGui.Parent==nil and next(window.Library.Registry)==nil,"unload removes Linoria gui and registry")
for _,connection in ipairs(conns)do check(not connection.Connected,"unload disconnects Linoria-owned subscription")end
for _,thread in ipairs(threads)do check(coroutine.status(thread)=="dead","unload cancels queued native tasks")end
check(not toggle:SetValue(true) and not status:Set("late"),"late updates after unload are rejected")

local fruitVFX={GetFruits=function()return{"Rumble","Dough"}end,GetColors=function(_,fruit)return fruit=="Rumble" and {"Original","Roxo"}or{"Original","Azul"}end,Apply=function()return true,"requested"end,Restore=function()return true,"restored"end}
local blox={Features={FruitVFX=fruitVFX},Toggles={},Values={}}
function blox:GetDashLength()return 1 end;function blox:GetToggle()return false end;function blox:SetToggle()return true end;function blox:SetDashLength()return true end;function blox:GetPreferredTeam()return"Pirates"end;function blox:SetPreferredTeam()return true end;function blox:SaveConfig()return true end
window=Main.new({Mode="BloxFruits",Backend=blox})
check(window.Pages.MAIN and window.Pages.VISUAL and window.Pages.CONFIG,"Blox Fruits mounts on Linoria")
window.Controls["FRUTA COMPATÍVEL"]:SetValue("Dough")
check(window.Controls["COR / SKIN"]:GetValues()[2]=="Azul","Blox Fruits keeps dependent fruit/color controls")
window:Destroy()
local runtime={Features={},GetSnapshot=function()return{Health="Healthy",Dashboard={Ping=20,FPS=60,ScriptVersion="1"}}end}
for _,name in ipairs({"AutoFarm","InstantCook","AutoDrop","AutoFarmFriends"})do runtime.Features[name]={Enabled=false,Toggle=function()mountCalls+=1 end}end
window=Main.new({Mode="RT3",Backend=runtime})
check(window.Pages.MAIN and window.Pages.STATUS and window.Pages.CONFIG,"RT3 preserves automation and status controls on Linoria")
window:Destroy()
local noob={}
for _,name in ipairs({"GetIslandNames","GetEnemyTypes","GetTeams"})do noob[name]=function()return{"A","B"}end end
noob.GetToggle=function()return false end
noob.GetValue=function(_,name)if name=="AutoChestDelay"then return .2 elseif name=="WeaponCategory"then return"Fists"else return"A"end end
noob.GetSelectedEnemyOption=function()return"A"end
noob.SetSelectedIsland=function()end
noob.ConnectIslandAvailabilityChanged=function(self,fn)self.Listener=fn;self.Event=signal();self.Connection=self.Event:Connect(fn);return self.Connection end
window=Main.new({Mode="NoobPiece",Backend=noob})
check(window.Pages.ESP and window.Pages.FARM and window.Pages.CONFIG,"Noob Piece preserves game tabs on Linoria")
noob.Listener({"B"});check(window.Controls.ILHA:GetValue()=="B","Noob Piece updates island dropdown from backend signal")
window:Destroy()
check(not noob.Connection.Connected,"frontend unload disconnects dynamic backend island listener")

for _,gameCase in ipairs({{"tsb","TSB","__DEPHUB_TSB_FRONTEND"},{"volleyballlegends","VolleyballLegends","__DEPHUB_VOLLEYBALL_FRONTEND"},{"mm2","MM2","__DEPHUB_MM2_FRONTEND"},{"violencedistrict","ViolenceDistrict","__DEPHUB_VD_FRONTEND"},{"aotr","AOTR","__DEPHUB_AOTR_FRONTEND"}})do
    local backend={Values={NapeMultiplier=1},Destroyed=false}
    backend.GetToggle=function()return false end
    backend.GetValue=function()return nil end
    backend.GetStatus=function()return"Waiting: test"end
    backend.Destroy=function(self)self.Destroyed=true end
    state.__DEPHUB=state.__DEPHUB or {};state.__DEPHUB[gameCase[2]]=backend
    local mounted=module("src/games/features/"..gameCase[1].."/frontend.lua")
    check(type(mounted)=="table" and mounted.Library~=nil and mounted:IsOpen(),gameCase[2].." mounts actual Linoria frontend")
    check(not backend.Destroyed,gameCase[2].." mounting does not destroy active backend")
    local native=mounted.Library
    native:Unload()
    check(mounted.Destroyed and backend.Destroyed and state[gameCase[3]]==nil,gameCase[2].." native unload cleans backend and global handles")
end

local saved={external=true};state.Options=saved
window=Adapter.new({Id="Reload",Title="DEPHUB"})
local old=window
window=Adapter.new({Id="Reload",Title="DEPHUB"})
check(old.Destroyed and old.Library.Unloaded,"reloading replaces previous native Linoria session")
window.Library.ScreenGui:Destroy()
check(window.Destroyed and state.Options==saved,"external GUI destruction triggers cleanup and restores prior globals")
print(string.format("PASS %d Linoria integration checks",passed))

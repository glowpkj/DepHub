local game=game
local type=type
local tostring=tostring
local tonumber=tonumber
local pcall=pcall
local math_floor=math.floor
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local LocalPlayer=Players.LocalPlayer
local PlayerGui=LocalPlayer:WaitForChild("PlayerGui")
local env=type(getgenv)=="function" and getgenv() or _G
local Previous=env.__DEPHUB_TSB_FRONTEND
if type(Previous)=="table" and type(Previous.Destroy)=="function" then pcall(Previous.Destroy,Previous) end
local oldGui=PlayerGui:FindFirstChild("dephubTSB") if oldGui then pcall(oldGui.Destroy,oldGui) end
local Backend=env.__DEPHUB and env.__DEPHUB.TSB or nil if type(Backend)~="table" then return false end
local UI={Destroyed=false,Open=false,Connections={},Controls={}}
local Colors={Header=Color3.fromRGB(20,22,24),Body=Color3.fromRGB(16,18,20),Control=Color3.fromRGB(28,31,33),ControlHover=Color3.fromRGB(34,38,40),Sub=Color3.fromRGB(23,26,28),Border=Color3.fromRGB(48,52,55),Text=Color3.fromRGB(255,255,255),Muted=Color3.fromRGB(170,176,180),Accent=Color3.fromRGB(114,236,190),Off=Color3.fromRGB(58,62,65),Track=Color3.fromRGB(47,52,55),Danger=Color3.fromRGB(255,85,85)}
local Width,HeaderHeight,BodyHeight,RowHeight=252,36,455,34
local function track(c) UI.Connections[#UI.Connections+1]=c return c end
local function disconnectAll(list) for i=#list,1,-1 do local c=list[i] list[i]=nil if c then pcall(c.Disconnect,c) end end end
local function corner(o,r) local v=Instance.new("UICorner") v.CornerRadius=UDim.new(0,r) v.Parent=o end
local function stroke(o) local v=Instance.new("UIStroke") v.Thickness=1 v.Color=Colors.Border v.Transparency=.15 v.Parent=o end
local Gui=Instance.new("ScreenGui") Gui.Name="dephubTSB" Gui.ResetOnSpawn=false Gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling Gui.Parent=PlayerGui
local Root=Instance.new("Frame") Root.Size=UDim2.fromOffset(Width,HeaderHeight) Root.Position=UDim2.new(.5,-Width/2,.26,0) Root.BackgroundTransparency=1 Root.Parent=Gui
local Header=Instance.new("Frame") Header.Size=UDim2.new(1,0,0,HeaderHeight) Header.BackgroundColor3=Colors.Header Header.BorderSizePixel=0 Header.Active=true Header.Parent=Root corner(Header,7) stroke(Header)
local Accent=Instance.new("Frame") Accent.Size=UDim2.fromOffset(3,18) Accent.Position=UDim2.new(0,8,.5,-9) Accent.BackgroundColor3=Colors.Accent Accent.BorderSizePixel=0 Accent.Parent=Header corner(Accent,2)
local Title=Instance.new("TextLabel") Title.Size=UDim2.new(1,-82,1,0) Title.Position=UDim2.fromOffset(19,0) Title.BackgroundTransparency=1 Title.Text="DepHub TSB" Title.TextColor3=Colors.Text Title.TextSize=14 Title.Font=Enum.Font.GothamMedium Title.TextXAlignment=Enum.TextXAlignment.Left Title.Parent=Header
local OpenButton=Instance.new("TextButton") OpenButton.Size=UDim2.fromOffset(58,24) OpenButton.Position=UDim2.new(1,-64,.5,-12) OpenButton.BackgroundColor3=Colors.Control OpenButton.BorderSizePixel=0 OpenButton.AutoButtonColor=false OpenButton.Text="OPEN" OpenButton.TextColor3=Colors.Text OpenButton.TextSize=11 OpenButton.Font=Enum.Font.GothamMedium OpenButton.Parent=Header corner(OpenButton,5)
local Body=Instance.new("Frame") Body.Size=UDim2.new(1,0,0,0) Body.Position=UDim2.new(0,0,0,HeaderHeight+4) Body.BackgroundColor3=Colors.Body Body.BorderSizePixel=0 Body.ClipsDescendants=true Body.Visible=false Body.Parent=Root corner(Body,7) stroke(Body)
local Content=Instance.new("ScrollingFrame") Content.Size=UDim2.new(1,-12,1,-12) Content.Position=UDim2.fromOffset(6,6) Content.BackgroundTransparency=1 Content.BorderSizePixel=0 Content.ScrollBarThickness=2 Content.ScrollBarImageColor3=Colors.Accent Content.AutomaticCanvasSize=Enum.AutomaticSize.Y Content.CanvasSize=UDim2.fromOffset(0,0) Content.Parent=Body
local Layout=Instance.new("UIListLayout") Layout.Padding=UDim.new(0,6) Layout.SortOrder=Enum.SortOrder.LayoutOrder Layout.Parent=Content
local function addSection(text) local l=Instance.new("TextLabel") l.Size=UDim2.new(1,0,0,20) l.BackgroundTransparency=1 l.Text=text l.TextColor3=Colors.Muted l.TextSize=11 l.Font=Enum.Font.GothamMedium l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=Content return l end
local function makeToggle(parent,text,default,callback,sub)
 local state=default==true
 local row=Instance.new("TextButton") row.Size=UDim2.new(1,0,0,RowHeight) row.BackgroundColor3=sub and Colors.Sub or Colors.Control row.BorderSizePixel=0 row.AutoButtonColor=false row.Text="" row.Parent=parent corner(row,5)
 local label=Instance.new("TextLabel") label.Size=UDim2.new(1,-55,1,0) label.Position=UDim2.fromOffset(10,0) label.BackgroundTransparency=1 label.Text=text label.TextColor3=Colors.Text label.TextSize=12 label.Font=Enum.Font.Gotham label.TextXAlignment=Enum.TextXAlignment.Left label.Parent=row
 local sw=Instance.new("Frame") sw.Size=UDim2.fromOffset(34,18) sw.Position=UDim2.new(1,-44,.5,-9) sw.BorderSizePixel=0 sw.Parent=row corner(sw,9)
 local dot=Instance.new("Frame") dot.Size=UDim2.fromOffset(12,12) dot.BackgroundColor3=Colors.Text dot.BorderSizePixel=0 dot.Parent=sw corner(dot,6)
 local function render(instant) local c=state and Colors.Accent or Colors.Off local p=state and UDim2.new(1,-15,0,3) or UDim2.fromOffset(3,3) if instant then sw.BackgroundColor3=c dot.Position=p else TweenService:Create(sw,TweenInfo.new(.12,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=c}):Play() TweenService:Create(dot,TweenInfo.new(.12,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=p}):Play() end end
 local control={}
 function control:Set(v,fire) state=v==true render(false) if fire~=false and type(callback)=="function" then task.spawn(callback,state) end if self.OnChanged then self.OnChanged(state) end end
 function control:Get() return state end
 track(row.MouseButton1Click:Connect(function() control:Set(not state) end))
 track(row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(.08),{BackgroundColor3=sub and Color3.fromRGB(29,33,35) or Colors.ControlHover}):Play() end))
 track(row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(.08),{BackgroundColor3=sub and Colors.Sub or Colors.Control}):Play() end))
 render(true) UI.Controls[text]=control return control,row
end
local function roundStep(value,step) return math_floor(value/step+.5)*step end
local function addSlider(parent,text,min,max,step,default,callback)
 local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,52) row.BackgroundColor3=Colors.Sub row.BorderSizePixel=0 row.Parent=parent corner(row,5)
 local label=Instance.new("TextLabel") label.Size=UDim2.new(1,-62,0,22) label.Position=UDim2.fromOffset(10,3) label.BackgroundTransparency=1 label.Text=text label.TextColor3=Colors.Text label.TextSize=11 label.Font=Enum.Font.Gotham label.TextXAlignment=Enum.TextXAlignment.Left label.Parent=row
 local valueLabel=Instance.new("TextLabel") valueLabel.Size=UDim2.fromOffset(46,22) valueLabel.Position=UDim2.new(1,-54,0,3) valueLabel.BackgroundTransparency=1 valueLabel.TextColor3=Colors.Accent valueLabel.TextSize=11 valueLabel.Font=Enum.Font.GothamMedium valueLabel.TextXAlignment=Enum.TextXAlignment.Right valueLabel.Parent=row
 local bar=Instance.new("Frame") bar.Size=UDim2.new(1,-20,0,6) bar.Position=UDim2.fromOffset(10,35) bar.BackgroundColor3=Colors.Track bar.BorderSizePixel=0 bar.Active=true bar.Parent=row corner(bar,3)
 local fill=Instance.new("Frame") fill.Size=UDim2.new(0,0,1,0) fill.BackgroundColor3=Colors.Accent fill.BorderSizePixel=0 fill.Parent=bar corner(fill,3)
 local knob=Instance.new("Frame") knob.Size=UDim2.fromOffset(12,12) knob.AnchorPoint=Vector2.new(.5,.5) knob.Position=UDim2.new(0,0,.5,0) knob.BackgroundColor3=Colors.Text knob.BorderSizePixel=0 knob.Parent=bar corner(knob,6)
 local value=math.clamp(tonumber(default) or min,min,max) local dragging=false
 local function format(v) if step<1 then return string.format("%.1f",v) end return tostring(math_floor(v+.5)) end
 local function render() local a=(value-min)/(max-min) fill.Size=UDim2.new(a,0,1,0) knob.Position=UDim2.new(a,0,.5,0) valueLabel.Text=format(value) end
 local function setFromX(x,fire) local width=bar.AbsoluteSize.X if width<=0 then return end local a=math.clamp((x-bar.AbsolutePosition.X)/width,0,1) local new=math.clamp(roundStep(min+(max-min)*a,step),min,max) if new==value then return end local old=value value=new if fire~=false and type(callback)=="function" then local ok=callback(value) if ok==false then value=old end end render() end
 track(bar.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true setFromX(input.Position.X,true) end end))
 track(UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then setFromX(input.Position.X,true) end end))
 track(UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
 local control={} function control:Set(v,fire) v=tonumber(v) if not v then return false end local old=value value=math.clamp(roundStep(v,step),min,max) if fire~=false and type(callback)=="function" then local ok=callback(value) if ok==false then value=old render() return false end end render() return true end function control:Get() return value end
 render() UI.Controls[text]=control return control,row
end
local function addFeature(text,default,callback)
 local group=Instance.new("Frame") group.Size=UDim2.new(1,0,0,0) group.AutomaticSize=Enum.AutomaticSize.Y group.BackgroundTransparency=1 group.Parent=Content
 local gl=Instance.new("UIListLayout") gl.Padding=UDim.new(0,5) gl.SortOrder=Enum.SortOrder.LayoutOrder gl.Parent=group
 local control=makeToggle(group,text,default,callback,false)
 local settings=Instance.new("Frame") settings.Size=UDim2.new(1,0,0,0) settings.BackgroundTransparency=1 settings.ClipsDescendants=true settings.Parent=group
 local inner=Instance.new("Frame") inner.Size=UDim2.new(1,-8,0,0) inner.Position=UDim2.fromOffset(8,0) inner.AutomaticSize=Enum.AutomaticSize.Y inner.BackgroundTransparency=1 inner.Parent=settings
 local il=Instance.new("UIListLayout") il.Padding=UDim.new(0,5) il.SortOrder=Enum.SortOrder.LayoutOrder il.Parent=inner
 local currentTween=nil
 local function targetHeight() return il.AbsoluteContentSize.Y end
 local function animate(open,instant)
  if currentTween then pcall(currentTween.Cancel,currentTween) currentTween=nil end
  local target=open and targetHeight() or 0
  if instant then settings.Size=UDim2.new(1,0,0,target) return end
  currentTween=TweenService:Create(settings,TweenInfo.new(.2,Enum.EasingStyle.Quart,open and Enum.EasingDirection.Out or Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,target)}) currentTween:Play()
 end
 control.OnChanged=function(open) task.defer(function() if not UI.Destroyed then animate(open,false) end end) end
 track(il:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() if control:Get() then settings.Size=UDim2.new(1,0,0,targetHeight()) end end))
 task.defer(function() if not UI.Destroyed then animate(control:Get(),true) end end)
 return control,inner
end
local function addStatusCard(parent)
 local card=Instance.new("Frame") card.Size=UDim2.new(1,0,0,132) card.BackgroundColor3=Colors.Sub card.BorderSizePixel=0 card.Parent=parent corner(card,5)
 local title=Instance.new("TextLabel") title.Size=UDim2.new(1,-20,0,22) title.Position=UDim2.fromOffset(10,5) title.BackgroundTransparency=1 title.Text="Live Status" title.TextColor3=Colors.Text title.TextSize=11 title.Font=Enum.Font.GothamMedium title.TextXAlignment=Enum.TextXAlignment.Left title.Parent=card
 local body=Instance.new("TextLabel") body.Size=UDim2.new(1,-20,1,-32) body.Position=UDim2.fromOffset(10,27) body.BackgroundTransparency=1 body.Text="runtime: idle" body.TextColor3=Colors.Muted body.TextSize=10 body.Font=Enum.Font.Code body.TextXAlignment=Enum.TextXAlignment.Left body.TextYAlignment=Enum.TextYAlignment.Top body.TextWrapped=true body.Parent=card
 return body
end
addSection("Combat")
local m1,m1Settings=addFeature("Auto Block",Backend:GetToggle("AutoBlock"),function(v) Backend:SetAutoBlock(v) end)
makeToggle(m1Settings,"M1 After Block",Backend:GetToggle("M1AfterBlock"),function(v) Backend:SetM1AfterBlock(v) end,true)
makeToggle(m1Settings,"M1 Catch",Backend:GetToggle("M1Catch"),function(v) Backend:SetM1Catch(v) end,true)
makeToggle(m1Settings,"Show Hitbox",Backend:GetToggle("ShowDetectionBox"),function(v) Backend:SetShowDetectionBox(v) end,true)
addSlider(m1Settings,"Hitbox Size",2,40,1,Backend:GetValue("DetectionBoxSize") or 12,function(v) return Backend:SetDetectionBoxSize(v) end)
addSlider(m1Settings,"M1 Range",2,30,1,Backend:GetValue("NormalRange") or 12,function(v) return Backend:SetNormalRange(v) end)
local dash,dashSettings=addFeature("Dash Block",Backend:GetToggle("DashBlock"),function(v) Backend:SetDashBlock(v) end)
addSlider(dashSettings,"Dash Range",5,80,1,Backend:GetValue("SpecialRange") or 50,function(v) return Backend:SetSpecialRange(v) end)
local skill,skillSettings=addFeature("Skill Block",Backend:GetToggle("SkillBlock"),function(v) Backend:SetSkillBlock(v) end)
addSlider(skillSettings,"Skill Range",5,80,1,Backend:GetValue("SkillRange") or 50,function(v) return Backend:SetSkillRange(v) end)
addSlider(skillSettings,"Skill Hold",.1,2,.1,Backend:GetValue("SkillHold") or 1.2,function(v) return Backend:SetSkillHold(v) end)
addSection("Diagnostics")
local debugFeature,debugSettings=addFeature("Debug",Backend:GetToggle("Debug"),function(v) Backend:SetDebug(v) end)
local DebugText=addStatusCard(debugSettings)
local debugElapsed=0
track(RunService.Heartbeat:Connect(function(dt)
 if UI.Destroyed or not debugFeature:Get() then return end
 debugElapsed=debugElapsed+dt if debugElapsed<.25 then return end debugElapsed=0
 local info=Backend:GetDebugInfo() if type(info)~="table" then DebugText.Text="backend unavailable" DebugText.TextColor3=Colors.Danger return end
 DebugText.TextColor3=info.LastError and info.LastError~="none" and Colors.Danger or Colors.Muted
 DebugText.Text="runtime: "..tostring(info.Runtime).."\ncharacter: "..tostring(info.Character).." | remote: "..tostring(info.Remote).."\nlive: "..tostring(info.Live).." | block: "..tostring(info.BlockActive).." | total: "..tostring(info.Blocks).."\nlast: "..tostring(info.LastEvent).."\nplayer: "..tostring(info.LastPlayer).." | id: "..tostring(info.LastAnimation).." | dist: "..string.format("%.1f",tonumber(info.LastDistance) or 0).."\nerror: "..tostring(info.LastError)
end))
local currentTween
function UI:SetOpen(state) if self.Destroyed then return end state=state==true if self.Open==state then return end self.Open=state if currentTween then pcall(currentTween.Cancel,currentTween) end if state then Body.Visible=true OpenButton.Text="CLOSE" currentTween=TweenService:Create(Body,TweenInfo.new(.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,BodyHeight)}) currentTween:Play() else OpenButton.Text="OPEN" currentTween=TweenService:Create(Body,TweenInfo.new(.14,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,0)}) local t=currentTween t:Play() task.spawn(function() t.Completed:Wait() if not UI.Destroyed and not UI.Open and currentTween==t then Body.Visible=false end end) end end
track(OpenButton.MouseButton1Click:Connect(function() UI:SetOpen(not UI.Open) end))
local dragging,dragInput,dragStart,startPosition=false,nil,nil,nil
track(Header.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end local p=input.Position local bp,bs=OpenButton.AbsolutePosition,OpenButton.AbsoluteSize if p.X>=bp.X and p.X<=bp.X+bs.X and p.Y>=bp.Y and p.Y<=bp.Y+bs.Y then return end dragging=true dragStart=input.Position startPosition=Root.Position local changed changed=input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false if changed then changed:Disconnect() end end end) end))
track(Header.InputChanged:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end end))
track(UserInputService.InputChanged:Connect(function(input) if not dragging or input~=dragInput then return end local d=input.Position-dragStart Root.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,startPosition.Y.Scale,startPosition.Y.Offset+d.Y) end))
function UI:Destroy() if self.Destroyed then return end self.Destroyed=true if currentTween then pcall(currentTween.Cancel,currentTween) end disconnectAll(self.Connections) self.Controls={} if Gui then pcall(Gui.Destroy,Gui) end if env.__DEPHUB_TSB_FRONTEND==self then env.__DEPHUB_TSB_FRONTEND=nil end if env.__DEPHUB and env.__DEPHUB.TSBUI==self then env.__DEPHUB.TSBUI=nil end end
env.__DEPHUB_TSB_FRONTEND=UI env.__DEPHUB=env.__DEPHUB or {} env.__DEPHUB.TSBUI=UI
return UI

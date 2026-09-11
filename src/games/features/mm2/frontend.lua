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
local Previous=env.__DEPHUB_MM2_FRONTEND
if type(Previous)=="table" and type(Previous.Destroy)=="function" then pcall(Previous.Destroy,Previous) end

local Backend=env.__DEPHUB and env.__DEPHUB.MM2
if type(Backend)~="table" then return false end

local UI={Destroyed=false,Open=false,Connections={},Controls={}}
local Colors={Header=Color3.fromRGB(20,22,24),Body=Color3.fromRGB(16,18,20),Control=Color3.fromRGB(28,31,33),Sub=Color3.fromRGB(23,26,28),Text=Color3.fromRGB(255,255,255),Muted=Color3.fromRGB(170,176,180),Accent=Color3.fromRGB(114,236,190),Off=Color3.fromRGB(58,62,65),Track=Color3.fromRGB(47,52,55),Red=Color3.fromRGB(255,76,76),Blue=Color3.fromRGB(70,160,255)}
local function track(c) UI.Connections[#UI.Connections+1]=c return c end
local function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r) c.Parent=o end
local function disconnectAll() for i=#UI.Connections,1,-1 do local c=UI.Connections[i] UI.Connections[i]=nil if c then pcall(c.Disconnect,c) end end end
local function parentGui() if type(gethui)=="function" then local ok,v=pcall(gethui) if ok and v then return v end end return PlayerGui end

local old=PlayerGui:FindFirstChild("dephubMM2") if old then pcall(old.Destroy,old) end
local Gui=Instance.new("ScreenGui")
Gui.Name="dephubMM2" Gui.ResetOnSpawn=false Gui.DisplayOrder=2147483647 Gui.ZIndexBehavior=Enum.ZIndexBehavior.Global Gui.Parent=parentGui()
local Root=Instance.new("Frame") Root.Size=UDim2.fromOffset(270,36) Root.Position=UDim2.new(.5,-135,.22,0) Root.BackgroundTransparency=1 Root.Parent=Gui
local Header=Instance.new("Frame") Header.Size=UDim2.fromScale(1,1) Header.BackgroundColor3=Colors.Header Header.BorderSizePixel=0 Header.Active=true Header.Parent=Root corner(Header,7)
local Title=Instance.new("TextLabel") Title.Size=UDim2.new(1,-72,1,0) Title.Position=UDim2.fromOffset(12,0) Title.BackgroundTransparency=1 Title.Text="DEPHUB MM2" Title.TextColor3=Colors.Text Title.Font=Enum.Font.GothamBold Title.TextSize=13 Title.TextXAlignment=Enum.TextXAlignment.Left Title.Parent=Header
local Open=Instance.new("TextButton") Open.Size=UDim2.fromOffset(58,24) Open.Position=UDim2.new(1,-64,.5,-12) Open.BackgroundColor3=Colors.Control Open.Text="OPEN" Open.TextColor3=Colors.Text Open.TextSize=11 Open.Font=Enum.Font.GothamMedium Open.BorderSizePixel=0 Open.Parent=Header corner(Open,5)
local Body=Instance.new("Frame") Body.Size=UDim2.new(1,0,0,0) Body.Position=UDim2.new(0,0,0,40) Body.BackgroundColor3=Colors.Body Body.BorderSizePixel=0 Body.ClipsDescendants=true Body.Visible=false Body.Parent=Root corner(Body,7)
local Content=Instance.new("ScrollingFrame") Content.Size=UDim2.new(1,-12,1,-12) Content.Position=UDim2.fromOffset(6,6) Content.BackgroundTransparency=1 Content.BorderSizePixel=0 Content.ScrollBarThickness=2 Content.ScrollBarImageColor3=Colors.Accent Content.AutomaticCanvasSize=Enum.AutomaticSize.Y Content.CanvasSize=UDim2.fromOffset(0,0) Content.Parent=Body
local Layout=Instance.new("UIListLayout") Layout.Padding=UDim.new(0,6) Layout.Parent=Content

local function section(text)
    local l=Instance.new("TextLabel") l.Size=UDim2.new(1,0,0,18) l.BackgroundTransparency=1 l.Text=text l.TextColor3=Colors.Muted l.TextSize=10 l.Font=Enum.Font.GothamMedium l.TextXAlignment=Enum.TextXAlignment.Left l.Parent=Content
end

local function toggle(text,default,callback)
    local state=default==true
    local row=Instance.new("TextButton") row.Size=UDim2.new(1,0,0,34) row.BackgroundColor3=Colors.Control row.BorderSizePixel=0 row.Text="" row.Parent=Content corner(row,5)
    local label=Instance.new("TextLabel") label.Size=UDim2.new(1,-54,1,0) label.Position=UDim2.fromOffset(10,0) label.BackgroundTransparency=1 label.Text=text label.TextColor3=Colors.Text label.TextSize=12 label.Font=Enum.Font.Gotham label.TextXAlignment=Enum.TextXAlignment.Left label.Parent=row
    local sw=Instance.new("Frame") sw.Size=UDim2.fromOffset(34,18) sw.Position=UDim2.new(1,-44,.5,-9) sw.BorderSizePixel=0 sw.Parent=row corner(sw,9)
    local dot=Instance.new("Frame") dot.Size=UDim2.fromOffset(12,12) dot.BackgroundColor3=Colors.Text dot.BorderSizePixel=0 dot.Parent=sw corner(dot,6)
    local function render() sw.BackgroundColor3=state and Colors.Accent or Colors.Off dot.Position=state and UDim2.new(1,-15,0,3) or UDim2.fromOffset(3,3) end
    track(row.MouseButton1Click:Connect(function()
        local nextState=not state
        local ok,result=pcall(callback,nextState)
        if ok and result~=false then state=nextState end
        render()
    end))
    render()
    UI.Controls[text]={Get=function() return state end,Set=function(_,v) state=v==true render() end}
end

local function slider(text,min,max,step,default,callback)
    local value=math.clamp(tonumber(default) or min,min,max)
    local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,50) row.BackgroundColor3=Colors.Sub row.BorderSizePixel=0 row.Parent=Content corner(row,5)
    local label=Instance.new("TextLabel") label.Size=UDim2.new(1,-60,0,22) label.Position=UDim2.fromOffset(10,3) label.BackgroundTransparency=1 label.Text=text label.TextColor3=Colors.Text label.TextSize=11 label.Font=Enum.Font.Gotham label.TextXAlignment=Enum.TextXAlignment.Left label.Parent=row
    local val=Instance.new("TextLabel") val.Size=UDim2.fromOffset(48,22) val.Position=UDim2.new(1,-56,0,3) val.BackgroundTransparency=1 val.TextColor3=Colors.Accent val.TextSize=11 val.Font=Enum.Font.GothamMedium val.TextXAlignment=Enum.TextXAlignment.Right val.Parent=row
    local bar=Instance.new("Frame") bar.Size=UDim2.new(1,-20,0,6) bar.Position=UDim2.fromOffset(10,34) bar.BackgroundColor3=Colors.Track bar.BorderSizePixel=0 bar.Active=true bar.Parent=row corner(bar,3)
    local fill=Instance.new("Frame") fill.BackgroundColor3=Colors.Accent fill.BorderSizePixel=0 fill.Parent=bar corner(fill,3)
    local dragging=false
    local function render() local a=(value-min)/(max-min) fill.Size=UDim2.new(a,0,1,0) val.Text=step<1 and string.format("%.1f",value) or tostring(math_floor(value+.5)) end
    local function setX(x)
        local w=bar.AbsoluteSize.X if w<=0 then return end
        local a=math.clamp((x-bar.AbsolutePosition.X)/w,0,1)
        local nextValue=math.clamp(math_floor(((min+(max-min)*a)/step)+.5)*step,min,max)
        local ok,result=pcall(callback,nextValue)
        if ok and result~=false then value=nextValue end
        render()
    end
    track(bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true setX(i.Position.X) end end))
    track(UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setX(i.Position.X) end end))
    track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
    render()
end

section("ROLES")
toggle("Role ESP",Backend:GetToggle("RoleESP"),function(v) return Backend:SetRoleESP(v) end)
section("FARM")
toggle("Auto Coins",Backend:GetToggle("AutoCoins"),function(v) return Backend:SetAutoCoins(v) end)
slider("Murder Safe Distance",0,60,1,Backend:GetValue("CoinSafeDistance") or 18,function(v) return Backend:SetCoinSafeDistance(v) end)
section("SAFETY")
toggle("Murder Evade",Backend:GetToggle("MurderEvade"),function(v) return Backend:SetMurderEvade(v) end)
toggle("Show Danger Box",Backend:GetToggle("ShowDangerBox"),function(v) return Backend:SetShowDangerBox(v) end)
slider("Danger Box Size",4,50,1,Backend:GetValue("DangerSize") or 18,function(v) return Backend:SetDangerSize(v) end)
slider("Escape Height",8,80,1,Backend:GetValue("EscapeHeight") or 32,function(v) return Backend:SetEscapeHeight(v) end)
section("STATUS")
local Status=Instance.new("TextLabel") Status.Size=UDim2.new(1,0,0,86) Status.BackgroundColor3=Colors.Sub Status.BorderSizePixel=0 Status.TextColor3=Colors.Muted Status.TextSize=10 Status.Font=Enum.Font.Code Status.TextXAlignment=Enum.TextXAlignment.Left Status.TextYAlignment=Enum.TextYAlignment.Top Status.TextWrapped=true Status.Parent=Content corner(Status,5)
local statusElapsed=0
track(RunService.Heartbeat:Connect(function(dt)
    statusElapsed=statusElapsed+dt if statusElapsed<.3 then return end statusElapsed=0
    local info=Backend:GetDebugInfo()
    local murder=Backend:GetMurder() local sheriff=Backend:GetSheriff()
    Status.Text=" round: "..(Backend:IsRoundActive() and "active" or "lobby").."\n murder: "..(murder and murder.Name or "none").."\n sheriff: "..(sheriff and sheriff.Name or "none").."\n coins: "..tostring(info.Coin and info.Coin.Coins or 0).." | teleports: "..tostring(info.Coin and info.Coin.Teleports or 0).."\n evade: "..tostring(info.Evade and info.Evade.Evading or false).." | attacks: "..tostring(info.Evade and info.Evade.Attacks or 0)
end))

local tween
local function setOpen(state)
    UI.Open=state==true
    if tween then pcall(tween.Cancel,tween) end
    if UI.Open then Body.Visible=true Open.Text="CLOSE" tween=TweenService:Create(Body,TweenInfo.new(.16,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,430)})
    else Open.Text="OPEN" tween=TweenService:Create(Body,TweenInfo.new(.13,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,0)}) end
    tween:Play()
    if not UI.Open then task.spawn(function() local t=tween t.Completed:Wait() if not UI.Destroyed and not UI.Open and tween==t then Body.Visible=false end end) end
end
track(Open.MouseButton1Click:Connect(function() setOpen(not UI.Open) end))

local dragging,dragStart,startPos=false,nil,nil
track(Header.InputBegan:Connect(function(i)
    if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end
    if i.Position.X>=Open.AbsolutePosition.X then return end
    dragging=true dragStart=i.Position startPos=Root.Position
end))
track(UserInputService.InputChanged:Connect(function(i)
    if not dragging or (i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch) then return end
    local d=i.Position-dragStart Root.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
end))
track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end))

function UI:Destroy()
    if self.Destroyed then return end self.Destroyed=true disconnectAll() if Gui then pcall(Gui.Destroy,Gui) end
    if env.__DEPHUB_MM2_FRONTEND==self then env.__DEPHUB_MM2_FRONTEND=nil end
    if env.__DEPHUB and env.__DEPHUB.MM2UI==self then env.__DEPHUB.MM2UI=nil end
end

env.__DEPHUB_MM2_FRONTEND=UI env.__DEPHUB=env.__DEPHUB or {} env.__DEPHUB.MM2UI=UI
return UI

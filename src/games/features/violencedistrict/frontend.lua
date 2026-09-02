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

local function resolveUIParent()
    if type(gethui)=="function" then
        local ok,result=pcall(gethui)
        if ok and typeof(result)=="Instance" then
            return result
        end
    end
    return PlayerGui
end

local UIParent=resolveUIParent()

local previous=env.__DEPHUB_VD_FRONTEND
if type(previous)=="table" and type(previous.Destroy)=="function" then
    pcall(previous.Destroy,previous)
end

for _,parent in ipairs({PlayerGui,UIParent}) do
    if parent then
        local old=parent:FindFirstChild("dephubViolenceDistrict")
        if old then pcall(old.Destroy,old) end
    end
end

local Backend=env.__DEPHUB and env.__DEPHUB.ViolenceDistrict or nil
if type(Backend)~="table" then return false end

local UI={
    Destroyed=false,
    Open=false,
    Connections={},
    Controls={}
}

local Colors={
    Header=Color3.fromRGB(18,20,22),
    Body=Color3.fromRGB(14,16,18),
    Control=Color3.fromRGB(26,29,31),
    Hover=Color3.fromRGB(32,36,39),
    Sub=Color3.fromRGB(21,24,26),
    Border=Color3.fromRGB(46,50,53),
    Text=Color3.fromRGB(247,248,249),
    Muted=Color3.fromRGB(156,162,167),
    Accent=Color3.fromRGB(113,231,190),
    Off=Color3.fromRGB(57,61,64),
    Track=Color3.fromRGB(43,47,50),
    Danger=Color3.fromRGB(255,95,95)
}

local Width=264
local HeaderHeight=36
local BodyHeight=470
local RowHeight=34

local function track(connection)
    UI.Connections[#UI.Connections+1]=connection
    return connection
end

local function disconnectAll(list)
    for i=#list,1,-1 do
        local connection=list[i]
        list[i]=nil
        if connection then pcall(connection.Disconnect,connection) end
    end
end

local function corner(object,radius)
    local value=Instance.new("UICorner")
    value.CornerRadius=UDim.new(0,radius)
    value.Parent=object
end

local function stroke(object)
    local value=Instance.new("UIStroke")
    value.Thickness=1
    value.Color=Colors.Border
    value.Transparency=0.2
    value.Parent=object
end

local Gui=Instance.new("ScreenGui")
Gui.Name="dephubViolenceDistrict"
Gui.ResetOnSpawn=false
Gui.IgnoreGuiInset=false
Gui.Enabled=true
Gui.DisplayOrder=2147483647
Gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
pcall(function() Gui.OnTopOfCoreBlur=true end)
Gui.Parent=UIParent

track(Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if not UI.Destroyed and Gui.Parent and not Gui.Enabled then
        Gui.Enabled=true
    end
end))

track(Gui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
    if not UI.Destroyed and Gui.Parent and Gui.DisplayOrder~=2147483647 then
        Gui.DisplayOrder=2147483647
    end
end))

local Root=Instance.new("Frame")
Root.Name="Root"
Root.Size=UDim2.fromOffset(Width,HeaderHeight)
Root.Position=UDim2.new(0.5,-Width/2,0.24,0)
Root.BackgroundTransparency=1
Root.Parent=Gui

local Header=Instance.new("Frame")
Header.Name="Header"
Header.Size=UDim2.new(1,0,0,HeaderHeight)
Header.BackgroundColor3=Colors.Header
Header.BorderSizePixel=0
Header.Active=true
Header.Parent=Root
corner(Header,7)
stroke(Header)

local Accent=Instance.new("Frame")
Accent.Size=UDim2.fromOffset(3,18)
Accent.Position=UDim2.new(0,8,0.5,-9)
Accent.BackgroundColor3=Colors.Accent
Accent.BorderSizePixel=0
Accent.Parent=Header
corner(Accent,2)

local Title=Instance.new("TextLabel")
Title.Size=UDim2.new(1,-82,1,0)
Title.Position=UDim2.fromOffset(19,0)
Title.BackgroundTransparency=1
Title.Text="DepHub Violence District"
Title.TextColor3=Colors.Text
Title.TextSize=13
Title.Font=Enum.Font.GothamMedium
Title.TextXAlignment=Enum.TextXAlignment.Left
Title.Parent=Header

local OpenButton=Instance.new("TextButton")
OpenButton.Size=UDim2.fromOffset(58,24)
OpenButton.Position=UDim2.new(1,-64,0.5,-12)
OpenButton.BackgroundColor3=Colors.Control
OpenButton.BorderSizePixel=0
OpenButton.AutoButtonColor=false
OpenButton.Text="OPEN"
OpenButton.TextColor3=Colors.Text
OpenButton.TextSize=11
OpenButton.Font=Enum.Font.GothamMedium
OpenButton.Parent=Header
corner(OpenButton,5)

local Body=Instance.new("Frame")
Body.Size=UDim2.new(1,0,0,0)
Body.Position=UDim2.new(0,0,0,HeaderHeight+4)
Body.BackgroundColor3=Colors.Body
Body.BorderSizePixel=0
Body.ClipsDescendants=true
Body.Visible=false
Body.Parent=Root
corner(Body,7)
stroke(Body)

local Content=Instance.new("ScrollingFrame")
Content.Size=UDim2.new(1,-12,1,-12)
Content.Position=UDim2.fromOffset(6,6)
Content.BackgroundTransparency=1
Content.BorderSizePixel=0
Content.ScrollBarThickness=2
Content.ScrollBarImageColor3=Colors.Accent
Content.AutomaticCanvasSize=Enum.AutomaticSize.Y
Content.CanvasSize=UDim2.fromOffset(0,0)
Content.Parent=Body

local Layout=Instance.new("UIListLayout")
Layout.Padding=UDim.new(0,6)
Layout.SortOrder=Enum.SortOrder.LayoutOrder
Layout.Parent=Content

local function addSection(text)
    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,0,0,20)
    label.BackgroundTransparency=1
    label.Text=text
    label.TextColor3=Colors.Muted
    label.TextSize=11
    label.Font=Enum.Font.GothamMedium
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.Parent=Content
    return label
end

local function makeToggle(parent,text,default,callback,sub)
    local state=default==true

    local row=Instance.new("TextButton")
    row.Size=UDim2.new(1,0,0,RowHeight)
    row.BackgroundColor3=sub and Colors.Sub or Colors.Control
    row.BorderSizePixel=0
    row.AutoButtonColor=false
    row.Text=""
    row.Parent=parent
    corner(row,5)

    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,-55,1,0)
    label.Position=UDim2.fromOffset(10,0)
    label.BackgroundTransparency=1
    label.Text=text
    label.TextColor3=Colors.Text
    label.TextSize=12
    label.Font=Enum.Font.Gotham
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.Parent=row

    local switch=Instance.new("Frame")
    switch.Size=UDim2.fromOffset(34,18)
    switch.Position=UDim2.new(1,-44,0.5,-9)
    switch.BorderSizePixel=0
    switch.Parent=row
    corner(switch,9)

    local dot=Instance.new("Frame")
    dot.Size=UDim2.fromOffset(12,12)
    dot.BackgroundColor3=Colors.Text
    dot.BorderSizePixel=0
    dot.Parent=switch
    corner(dot,6)

    local function render(instant)
        local switchColor=state and Colors.Accent or Colors.Off
        local position=state and UDim2.new(1,-15,0,3) or UDim2.fromOffset(3,3)

        if instant then
            switch.BackgroundColor3=switchColor
            dot.Position=position
            return
        end

        TweenService:Create(switch,TweenInfo.new(0.12,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
            BackgroundColor3=switchColor
        }):Play()

        TweenService:Create(dot,TweenInfo.new(0.12,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
            Position=position
        }):Play()
    end

    local control={}

    function control:Set(value,fire)
        state=value==true
        render(false)

        if fire~=false and type(callback)=="function" then
            task.spawn(callback,state)
        end

        if self.OnChanged then
            self.OnChanged(state)
        end
    end

    function control:Get()
        return state
    end

    track(row.MouseButton1Click:Connect(function()
        control:Set(not state)
    end))

    track(row.MouseEnter:Connect(function()
        TweenService:Create(row,TweenInfo.new(0.08),{
            BackgroundColor3=sub and Color3.fromRGB(27,31,33) or Colors.Hover
        }):Play()
    end))

    track(row.MouseLeave:Connect(function()
        TweenService:Create(row,TweenInfo.new(0.08),{
            BackgroundColor3=sub and Colors.Sub or Colors.Control
        }):Play()
    end))

    render(true)
    UI.Controls[text]=control
    return control,row
end

local function roundStep(value,step)
    return math_floor(value/step+0.5)*step
end

local function addSlider(parent,text,min,max,step,default,callback)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,52)
    row.BackgroundColor3=Colors.Sub
    row.BorderSizePixel=0
    row.Parent=parent
    corner(row,5)

    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,-62,0,22)
    label.Position=UDim2.fromOffset(10,3)
    label.BackgroundTransparency=1
    label.Text=text
    label.TextColor3=Colors.Text
    label.TextSize=11
    label.Font=Enum.Font.Gotham
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.Parent=row

    local valueLabel=Instance.new("TextLabel")
    valueLabel.Size=UDim2.fromOffset(46,22)
    valueLabel.Position=UDim2.new(1,-54,0,3)
    valueLabel.BackgroundTransparency=1
    valueLabel.TextColor3=Colors.Accent
    valueLabel.TextSize=11
    valueLabel.Font=Enum.Font.GothamMedium
    valueLabel.TextXAlignment=Enum.TextXAlignment.Right
    valueLabel.Parent=row

    local bar=Instance.new("Frame")
    bar.Size=UDim2.new(1,-20,0,6)
    bar.Position=UDim2.fromOffset(10,35)
    bar.BackgroundColor3=Colors.Track
    bar.BorderSizePixel=0
    bar.Active=true
    bar.Parent=row
    corner(bar,3)

    local fill=Instance.new("Frame")
    fill.Size=UDim2.new(0,0,1,0)
    fill.BackgroundColor3=Colors.Accent
    fill.BorderSizePixel=0
    fill.Parent=bar
    corner(fill,3)

    local knob=Instance.new("Frame")
    knob.Size=UDim2.fromOffset(12,12)
    knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.BackgroundColor3=Colors.Text
    knob.BorderSizePixel=0
    knob.Parent=bar
    corner(knob,6)

    local value=math.clamp(tonumber(default) or min,min,max)
    local dragging=false

    local function render()
        local alpha=(value-min)/(max-min)
        fill.Size=UDim2.new(alpha,0,1,0)
        knob.Position=UDim2.new(alpha,0,0.5,0)
        valueLabel.Text=step<1 and string.format("%.1f",value) or tostring(math_floor(value+0.5))
    end

    local function setFromX(x,fire)
        local width=bar.AbsoluteSize.X
        if width<=0 then return end

        local alpha=math.clamp((x-bar.AbsolutePosition.X)/width,0,1)
        local newValue=math.clamp(roundStep(min+(max-min)*alpha,step),min,max)

        if newValue==value then return end

        local oldValue=value
        value=newValue

        if fire~=false and type(callback)=="function" then
            local ok=callback(value)
            if ok==false then value=oldValue end
        end

        render()
    end

    track(bar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            setFromX(input.Position.X,true)
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            setFromX(input.Position.X,true)
        end
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end))

    render()
    UI.Controls[text]={Get=function() return value end}
    return row
end

local function addFeature(text,default,callback)
    local group=Instance.new("Frame")
    group.Size=UDim2.new(1,0,0,0)
    group.AutomaticSize=Enum.AutomaticSize.Y
    group.BackgroundTransparency=1
    group.Parent=Content

    local groupLayout=Instance.new("UIListLayout")
    groupLayout.Padding=UDim.new(0,5)
    groupLayout.SortOrder=Enum.SortOrder.LayoutOrder
    groupLayout.Parent=group

    local control=makeToggle(group,text,default,callback,false)

    local settings=Instance.new("Frame")
    settings.Size=UDim2.new(1,0,0,0)
    settings.BackgroundTransparency=1
    settings.ClipsDescendants=true
    settings.Parent=group

    local inner=Instance.new("Frame")
    inner.Size=UDim2.new(1,-8,0,0)
    inner.Position=UDim2.fromOffset(8,0)
    inner.AutomaticSize=Enum.AutomaticSize.Y
    inner.BackgroundTransparency=1
    inner.Parent=settings

    local innerLayout=Instance.new("UIListLayout")
    innerLayout.Padding=UDim.new(0,5)
    innerLayout.SortOrder=Enum.SortOrder.LayoutOrder
    innerLayout.Parent=inner

    local activeTween=nil

    local function targetHeight()
        return innerLayout.AbsoluteContentSize.Y
    end

    local function animate(open,instant)
        if activeTween then
            pcall(activeTween.Cancel,activeTween)
            activeTween=nil
        end

        local target=open and targetHeight() or 0

        if instant then
            settings.Size=UDim2.new(1,0,0,target)
            return
        end

        activeTween=TweenService:Create(
            settings,
            TweenInfo.new(0.2,Enum.EasingStyle.Quart,open and Enum.EasingDirection.Out or Enum.EasingDirection.In),
            {Size=UDim2.new(1,0,0,target)}
        )
        activeTween:Play()
    end

    control.OnChanged=function(open)
        task.defer(function()
            if not UI.Destroyed then
                animate(open,false)
            end
        end)
    end

    track(innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if control:Get() then
            settings.Size=UDim2.new(1,0,0,targetHeight())
        end
    end))

    task.defer(function()
        if not UI.Destroyed then
            animate(control:Get(),true)
        end
    end)

    return control,inner
end

local function addAction(parent,text,callback)
    local button=Instance.new("TextButton")
    button.Size=UDim2.new(1,0,0,38)
    button.BackgroundColor3=Colors.Control
    button.BorderSizePixel=0
    button.AutoButtonColor=false
    button.Text=text
    button.TextColor3=Colors.Text
    button.TextSize=12
    button.Font=Enum.Font.GothamMedium
    button.Parent=parent
    corner(button,5)

    track(button.MouseEnter:Connect(function()
        TweenService:Create(button,TweenInfo.new(0.08),{
            BackgroundColor3=Colors.Hover
        }):Play()
    end))

    track(button.MouseLeave:Connect(function()
        TweenService:Create(button,TweenInfo.new(0.08),{
            BackgroundColor3=Colors.Control
        }):Play()
    end))

    track(button.MouseButton1Click:Connect(function()
        if type(callback)=="function" then
            task.spawn(callback)
        end
    end))

    return button
end

local function addStatusCard(parent)
    local card=Instance.new("Frame")
    card.Size=UDim2.new(1,0,0,176)
    card.BackgroundColor3=Colors.Sub
    card.BorderSizePixel=0
    card.Parent=parent
    corner(card,5)

    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,-20,1,-16)
    label.Position=UDim2.fromOffset(10,8)
    label.BackgroundTransparency=1
    label.Text="runtime: idle"
    label.TextColor3=Colors.Muted
    label.TextSize=10
    label.Font=Enum.Font.Code
    label.TextXAlignment=Enum.TextXAlignment.Left
    label.TextYAlignment=Enum.TextYAlignment.Top
    label.TextWrapped=true
    label.Parent=card

    return label
end

addSection("Players")

makeToggle(Content,"Player ESP",Backend:GetToggle("PlayerESP"),function(value)
    Backend:SetPlayerESP(value)
end,false)

addSection("Generator")

local autoRepair,autoRepairSettings=addFeature("Auto Repair",Backend:GetToggle("AutoRepair"),function(value)
    Backend:SetAutoRepair(value)
end)

addSlider(autoRepairSettings,"Repair Range",2,35,1,Backend:GetValue("RepairRange") or 14,function(value)
    return Backend:SetRepairRange(value)
end)

makeToggle(Content,"Auto Skill Check",Backend:GetToggle("AutoSkillCheck"),function(value)
    Backend:SetAutoSkillCheck(value)
end,false)

addSection("Map")

local ExitLeverButton=addAction(Content,"TELEPORT EXIT LEVER",function()
    Backend:TeleportToExitLever()
end)
ExitLeverButton.Visible=false

addSection("Diagnostics")

local debugFeature,debugSettings=addFeature("Debug",Backend:GetToggle("Debug"),function(value)
    Backend:SetDebug(value)
end)

local DebugText=addStatusCard(debugSettings)

local debugElapsed=0
local mapElapsed=0

track(RunService.Heartbeat:Connect(function(dt)
    if UI.Destroyed then return end

    mapElapsed=mapElapsed+dt
    if mapElapsed>=0.45 then
        mapElapsed=0
        local ok,info=pcall(Backend.GetExitLeverInfo,Backend)
        ExitLeverButton.Visible=ok and type(info)=="table" and info.Available==true
    end

    if not debugFeature:Get() then return end

    debugElapsed=debugElapsed+dt
    if debugElapsed<0.25 then return end
    debugElapsed=0

    local info=Backend:GetGeneratorDebugInfo()
    if type(info)~="table" then
        DebugText.Text="backend unavailable"
        DebugText.TextColor3=Colors.Danger
        return
    end

    DebugText.TextColor3=info.LastError and info.LastError~="none" and Colors.Danger or Colors.Muted
    DebugText.Text=
        "runtime: "..tostring(info.Runtime)..
        "\nmap: "..tostring(info.Map)..
        "\nrepair: "..tostring(info.RepairRemote).." | skill: "..tostring(info.SkillRemote)..
        "\ngenerators: "..tostring(info.Generators)..
        "\ncurrent: "..tostring(info.CurrentGenerator).." / "..tostring(info.CurrentPoint)..
        "\ndistance: "..string.format("%.1f",tonumber(info.NearestDistance) or 0)..
        " | active: "..tostring(info.RepairActive)..
        "\nrepair calls: "..tostring(info.RepairCalls).." | stops: "..tostring(info.RepairStops)..
        "\nskill checks: "..tostring(info.SkillChecks).." | index: "..tostring(info.LastSkillIndex)..
        "\nexit: "..tostring(info.ExitLever)..
        "\nlast: "..tostring(info.LastAction)..
        "\nerror: "..tostring(info.LastError)
end))

local currentTween=nil

function UI:SetOpen(state)
    if self.Destroyed then return end

    state=state==true
    if self.Open==state then return end

    self.Open=state

    if currentTween then
        pcall(currentTween.Cancel,currentTween)
        currentTween=nil
    end

    if state then
        Body.Visible=true
        OpenButton.Text="CLOSE"
        currentTween=TweenService:Create(
            Body,
            TweenInfo.new(0.16,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
            {Size=UDim2.new(1,0,0,BodyHeight)}
        )
        currentTween:Play()
        return
    end

    OpenButton.Text="OPEN"
    currentTween=TweenService:Create(
        Body,
        TweenInfo.new(0.13,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
        {Size=UDim2.new(1,0,0,0)}
    )

    local tween=currentTween
    tween:Play()

    task.spawn(function()
        tween.Completed:Wait()
        if not UI.Destroyed and not UI.Open and currentTween==tween then
            Body.Visible=false
        end
    end)
end

track(OpenButton.MouseButton1Click:Connect(function()
    UI:SetOpen(not UI.Open)
end))

track(OpenButton.MouseEnter:Connect(function()
    TweenService:Create(OpenButton,TweenInfo.new(0.08),{
        BackgroundColor3=Colors.Hover
    }):Play()
end))

track(OpenButton.MouseLeave:Connect(function()
    TweenService:Create(OpenButton,TweenInfo.new(0.08),{
        BackgroundColor3=Colors.Control
    }):Play()
end))

local dragging=false
local dragInput=nil
local dragStart=nil
local startPosition=nil

track(Header.InputBegan:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then
        return
    end

    local point=input.Position
    local buttonPosition=OpenButton.AbsolutePosition
    local buttonSize=OpenButton.AbsoluteSize

    if point.X>=buttonPosition.X and point.X<=buttonPosition.X+buttonSize.X
        and point.Y>=buttonPosition.Y and point.Y<=buttonPosition.Y+buttonSize.Y then
        return
    end

    dragging=true
    dragStart=input.Position
    startPosition=Root.Position

    local changed
    changed=input.Changed:Connect(function()
        if input.UserInputState==Enum.UserInputState.End then
            dragging=false
            if changed then
                changed:Disconnect()
                changed=nil
            end
        end
    end)
end))

track(Header.InputChanged:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then
        dragInput=input
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if not dragging or input~=dragInput then return end

    local delta=input.Position-dragStart

    Root.Position=UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset+delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset+delta.Y
    )
end))

function UI:Destroy()
    if self.Destroyed then return end

    self.Destroyed=true

    if currentTween then
        pcall(currentTween.Cancel,currentTween)
        currentTween=nil
    end

    disconnectAll(self.Connections)
    self.Controls={}

    if Gui then
        pcall(Gui.Destroy,Gui)
    end

    if env.__DEPHUB_VD_FRONTEND==self then
        env.__DEPHUB_VD_FRONTEND=nil
    end

    if env.__DEPHUB and env.__DEPHUB.ViolenceDistrictUI==self then
        env.__DEPHUB.ViolenceDistrictUI=nil
    end
end

env.__DEPHUB_VD_FRONTEND=UI
env.__DEPHUB=env.__DEPHUB or {}
env.__DEPHUB.ViolenceDistrictUI=UI

return UI

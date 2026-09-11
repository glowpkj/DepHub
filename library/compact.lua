local game=game
local type=type
local tonumber=tonumber
local tostring=tostring
local pcall=pcall
local math_floor=math.floor

local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local LocalPlayer=Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui=LocalPlayer:WaitForChild("PlayerGui")
local env=type(getgenv)=="function" and getgenv() or _G

local Library={Version="1.0.0"}
local Windows={}

local function disconnectAll(list)
    for i=#list,1,-1 do
        local c=list[i]
        list[i]=nil
        if c then pcall(c.Disconnect,c) end
    end
end

local function round(object,radius)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,radius or 5)
    c.Parent=object
    return c
end

local function stroke(object,color,transparency)
    local s=Instance.new("UIStroke")
    s.Thickness=1
    s.Color=color
    s.Transparency=transparency or 0
    s.Parent=object
    return s
end

local function safeCall(callback,...)
    if type(callback)~="function" then return true end
    local ok,result=pcall(callback,...)
    if not ok then return false,result end
    if result==false then return false,"rejected" end
    return true,result
end

local function parentGui(gui)
    local parent=PlayerGui
    if type(gethui)=="function" then
        local ok,result=pcall(gethui)
        if ok and result then parent=result end
    end
    gui.Parent=parent
end

function Library.new(options)
    options=options or {}
    local id=tostring(options.Id or options.Title or "DepHubCompact"):gsub("%W","")
    if id=="" then id="DepHubCompact" end

    local previous=Windows[id]
    if previous and type(previous.Destroy)=="function" then pcall(previous.Destroy,previous) end

    local accent=options.Accent or Color3.fromRGB(105,232,188)
    local bg=Color3.fromRGB(12,14,16)
    local headerColor=Color3.fromRGB(17,19,22)
    local cardColor=Color3.fromRGB(22,25,28)
    local cardHover=Color3.fromRGB(27,31,35)
    local nestedColor=Color3.fromRGB(18,21,24)
    local lineColor=Color3.fromRGB(45,50,55)
    local white=Color3.fromRGB(255,255,255)

    local window={Destroyed=false,Open=options.Open~=false,Connections={},Controls={},Id=id}

    local Gui=Instance.new("ScreenGui")
    Gui.Name="dephubCompact_"..id
    Gui.ResetOnSpawn=false
    Gui.IgnoreGuiInset=false
    Gui.DisplayOrder=2147483647
    Gui.ZIndexBehavior=Enum.ZIndexBehavior.Global
    pcall(function() Gui.OnTopOfCoreBlur=true end)
    parentGui(Gui)

    local width=tonumber(options.Width) or 286
    local bodyHeight=tonumber(options.Height) or 470
    local headerHeight=42

    local Root=Instance.new("Frame")
    Root.Size=UDim2.fromOffset(width,headerHeight)
    Root.Position=options.Position or UDim2.new(.5,-width/2,.22,0)
    Root.BackgroundTransparency=1
    Root.Parent=Gui

    local Scale=Instance.new("UIScale")
    Scale.Scale=1
    Scale.Parent=Root

    local Header=Instance.new("Frame")
    Header.Size=UDim2.new(1,0,0,headerHeight)
    Header.BackgroundColor3=headerColor
    Header.BorderSizePixel=0
    Header.Active=true
    Header.Parent=Root
    round(Header,6)
    stroke(Header,lineColor,.2)

    local Accent=Instance.new("Frame")
    Accent.Size=UDim2.fromOffset(3,24)
    Accent.Position=UDim2.new(0,9,.5,-12)
    Accent.BackgroundColor3=accent
    Accent.BorderSizePixel=0
    Accent.Parent=Header
    round(Accent,2)

    local Title=Instance.new("TextLabel")
    Title.Size=UDim2.new(1,-88,0,22)
    Title.Position=UDim2.fromOffset(20,4)
    Title.BackgroundTransparency=1
    Title.Text=tostring(options.Title or "DEPHUB")
    Title.TextColor3=white
    Title.TextTransparency=0
    Title.TextSize=13
    Title.Font=Enum.Font.GothamBold
    Title.TextXAlignment=Enum.TextXAlignment.Left
    Title.Parent=Header

    local Subtitle=Instance.new("TextLabel")
    Subtitle.Size=UDim2.new(1,-88,0,14)
    Subtitle.Position=UDim2.fromOffset(20,23)
    Subtitle.BackgroundTransparency=1
    Subtitle.Text=string.upper(tostring(options.Subtitle or "RUNTIME"))
    Subtitle.TextColor3=white
    Subtitle.TextTransparency=.38
    Subtitle.TextSize=9
    Subtitle.Font=Enum.Font.GothamMedium
    Subtitle.TextXAlignment=Enum.TextXAlignment.Left
    Subtitle.Parent=Header

    local OpenButton=Instance.new("TextButton")
    OpenButton.Size=UDim2.fromOffset(54,25)
    OpenButton.Position=UDim2.new(1,-63,.5,-12)
    OpenButton.BackgroundColor3=cardColor
    OpenButton.BorderSizePixel=0
    OpenButton.AutoButtonColor=false
    OpenButton.Text="CLOSE"
    OpenButton.TextColor3=white
    OpenButton.TextSize=9
    OpenButton.Font=Enum.Font.GothamBold
    OpenButton.Parent=Header
    round(OpenButton,5)
    stroke(OpenButton,lineColor,.35)

    local Body=Instance.new("Frame")
    Body.Size=UDim2.new(1,0,0,bodyHeight)
    Body.Position=UDim2.new(0,0,0,headerHeight+5)
    Body.BackgroundColor3=bg
    Body.BorderSizePixel=0
    Body.ClipsDescendants=true
    Body.Parent=Root
    round(Body,6)
    stroke(Body,lineColor,.18)

    local Content=Instance.new("ScrollingFrame")
    Content.Size=UDim2.new(1,-14,1,-14)
    Content.Position=UDim2.fromOffset(7,7)
    Content.BackgroundTransparency=1
    Content.BorderSizePixel=0
    Content.ScrollBarThickness=2
    Content.ScrollBarImageColor3=accent
    Content.AutomaticCanvasSize=Enum.AutomaticSize.Y
    Content.CanvasSize=UDim2.fromOffset(0,0)
    Content.ScrollingDirection=Enum.ScrollingDirection.Y
    Content.Parent=Body

    local Layout=Instance.new("UIListLayout")
    Layout.Padding=UDim.new(0,6)
    Layout.SortOrder=Enum.SortOrder.LayoutOrder
    Layout.Parent=Content

    local function track(c)
        window.Connections[#window.Connections+1]=c
        return c
    end

    local function updateScale()
        local camera=Workspace.CurrentCamera
        local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
        local x=(viewport.X-22)/width
        local y=(viewport.Y-70)/(bodyHeight+headerHeight+5)
        Scale.Scale=math.clamp(math.min(1,x,y),.72,1)
    end

    updateScale()
    if Workspace.CurrentCamera then
        track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
    end
    track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        task.defer(updateScale)
    end))

    local function makeLabel(parent,text,size,height,transparency)
        local label=Instance.new("TextLabel")
        label.Size=UDim2.new(1,0,0,height or 18)
        label.BackgroundTransparency=1
        label.Text=tostring(text or "")
        label.TextColor3=white
        label.TextTransparency=transparency or 0
        label.TextSize=size or 10
        label.Font=Enum.Font.GothamMedium
        label.TextXAlignment=Enum.TextXAlignment.Left
        label.Parent=parent
        return label
    end

    function window:AddSection(text)
        local holder=Instance.new("Frame")
        holder.Size=UDim2.new(1,0,0,24)
        holder.BackgroundTransparency=1
        holder.Parent=Content
        local label=makeLabel(holder,string.upper(text),9,24,.3)
        label.Position=UDim2.fromOffset(4,0)
        return holder
    end

    local function makeToggle(parent,text,default,callback,nested)
        local state=default==true
        local row=Instance.new("TextButton")
        row.Size=UDim2.new(1,0,0,36)
        row.BackgroundColor3=nested and nestedColor or cardColor
        row.BorderSizePixel=0
        row.AutoButtonColor=false
        row.Text=""
        row.Parent=parent
        round(row,5)
        stroke(row,lineColor,.55)

        local label=makeLabel(row,text,11,36,0)
        label.Size=UDim2.new(1,-58,1,0)
        label.Position=UDim2.fromOffset(10,0)

        local sw=Instance.new("Frame")
        sw.Size=UDim2.fromOffset(34,18)
        sw.Position=UDim2.new(1,-44,.5,-9)
        sw.BorderSizePixel=0
        sw.Parent=row
        round(sw,9)

        local dot=Instance.new("Frame")
        dot.Size=UDim2.fromOffset(12,12)
        dot.BackgroundColor3=white
        dot.BorderSizePixel=0
        dot.Parent=sw
        round(dot,6)

        local control={}
        local function render(instant)
            local color=state and accent or Color3.fromRGB(52,57,62)
            local pos=state and UDim2.new(1,-15,0,3) or UDim2.fromOffset(3,3)
            if instant then
                sw.BackgroundColor3=color
                dot.Position=pos
            else
                TweenService:Create(sw,TweenInfo.new(.13,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundColor3=color}):Play()
                TweenService:Create(dot,TweenInfo.new(.13,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=pos}):Play()
            end
        end
        function control:Set(value,fire)
            local nextState=value==true
            if fire~=false then
                local ok=safeCall(callback,nextState)
                if not ok then return false end
            end
            state=nextState
            render(false)
            if type(self.OnChanged)=="function" then pcall(self.OnChanged,state) end
            return true
        end
        function control:Get() return state end
        track(row.MouseButton1Click:Connect(function() control:Set(not state,true) end))
        track(row.MouseEnter:Connect(function() TweenService:Create(row,TweenInfo.new(.08),{BackgroundColor3=cardHover}):Play() end))
        track(row.MouseLeave:Connect(function() TweenService:Create(row,TweenInfo.new(.08),{BackgroundColor3=nested and nestedColor or cardColor}):Play() end))
        render(true)
        window.Controls[text]=control
        return control,row
    end

    function window:AddToggle(text,default,callback,parent)
        local target=parent or Content
        return makeToggle(target,text,default,callback,parent~=nil)
    end

    function window:AddFeature(text,default,callback)
        local group=Instance.new("Frame")
        group.Size=UDim2.new(1,0,0,0)
        group.AutomaticSize=Enum.AutomaticSize.Y
        group.BackgroundTransparency=1
        group.Parent=Content
        local gl=Instance.new("UIListLayout")
        gl.Padding=UDim.new(0,5)
        gl.Parent=group

        local toggle=makeToggle(group,text,default,callback,false)
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
        local il=Instance.new("UIListLayout")
        il.Padding=UDim.new(0,5)
        il.Parent=inner

        local currentTween
        local function resize(open,instant)
            if currentTween then pcall(currentTween.Cancel,currentTween) end
            local height=open and il.AbsoluteContentSize.Y or 0
            if instant then settings.Size=UDim2.new(1,0,0,height) return end
            currentTween=TweenService:Create(settings,TweenInfo.new(.18,Enum.EasingStyle.Quart,open and Enum.EasingDirection.Out or Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,height)})
            currentTween:Play()
        end
        toggle.OnChanged=function(open) task.defer(function() if not window.Destroyed then resize(open,false) end end) end
        track(il:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() if toggle:Get() then resize(true,true) end end))
        task.defer(function() if not window.Destroyed then resize(toggle:Get(),true) end end)
        return toggle,inner
    end

    function window:AddSlider(text,min,max,step,default,callback,parent)
        local target=parent or Content
        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,54)
        row.BackgroundColor3=parent and nestedColor or cardColor
        row.BorderSizePixel=0
        row.Parent=target
        round(row,5)
        stroke(row,lineColor,.55)

        local label=makeLabel(row,text,10,22,0)
        label.Size=UDim2.new(1,-64,0,22)
        label.Position=UDim2.fromOffset(10,4)
        local valueLabel=makeLabel(row,"",10,22,0)
        valueLabel.Size=UDim2.fromOffset(50,22)
        valueLabel.Position=UDim2.new(1,-60,0,4)
        valueLabel.TextXAlignment=Enum.TextXAlignment.Right
        valueLabel.TextColor3=accent

        min=tonumber(min) or 0
        max=tonumber(max) or 100
        step=tonumber(step) or 1
        local value=math.clamp(tonumber(default) or min,min,max)
        local dragging=false

        local bar=Instance.new("Frame")
        bar.Size=UDim2.new(1,-20,0,5)
        bar.Position=UDim2.fromOffset(10,38)
        bar.BackgroundColor3=Color3.fromRGB(46,51,56)
        bar.BorderSizePixel=0
        bar.Active=true
        bar.Parent=row
        round(bar,3)
        local fill=Instance.new("Frame")
        fill.Size=UDim2.new(0,0,1,0)
        fill.BackgroundColor3=accent
        fill.BorderSizePixel=0
        fill.Parent=bar
        round(fill,3)
        local knob=Instance.new("Frame")
        knob.Size=UDim2.fromOffset(11,11)
        knob.AnchorPoint=Vector2.new(.5,.5)
        knob.BackgroundColor3=white
        knob.BorderSizePixel=0
        knob.Parent=bar
        round(knob,6)

        local function formatted(v)
            if step<1 then return string.format("%.2f",v):gsub("0+$",""):gsub("%.$","") end
            return tostring(math_floor(v+.5))
        end
        local function render()
            local a=max==min and 0 or (value-min)/(max-min)
            fill.Size=UDim2.new(a,0,1,0)
            knob.Position=UDim2.new(a,0,.5,0)
            valueLabel.Text=formatted(value)
        end
        local function setValue(nextValue,fire)
            nextValue=math.clamp(math_floor(((nextValue-min)/step)+.5)*step+min,min,max)
            if nextValue==value then return true end
            if fire~=false then
                local ok=safeCall(callback,nextValue)
                if not ok then return false end
            end
            value=nextValue
            render()
            return true
        end
        local function setX(x)
            local widthPx=bar.AbsoluteSize.X
            if widthPx<=0 then return end
            local a=math.clamp((x-bar.AbsolutePosition.X)/widthPx,0,1)
            setValue(min+(max-min)*a,true)
        end
        track(bar.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true setX(input.Position.X) end
        end))
        track(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then setX(input.Position.X) end
        end))
        track(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end))
        local control={Set=function(_,v,fire) return setValue(tonumber(v) or value,fire) end,Get=function() return value end}
        render()
        window.Controls[text]=control
        return control,row
    end

    function window:AddButton(text,callback,parent)
        local target=parent or Content
        local button=Instance.new("TextButton")
        button.Size=UDim2.new(1,0,0,36)
        button.BackgroundColor3=parent and nestedColor or cardColor
        button.BorderSizePixel=0
        button.AutoButtonColor=false
        button.Text=tostring(text)
        button.TextColor3=white
        button.TextSize=10
        button.Font=Enum.Font.GothamBold
        button.Parent=target
        round(button,5)
        stroke(button,lineColor,.55)
        track(button.MouseEnter:Connect(function() TweenService:Create(button,TweenInfo.new(.08),{BackgroundColor3=cardHover}):Play() end))
        track(button.MouseLeave:Connect(function() TweenService:Create(button,TweenInfo.new(.08),{BackgroundColor3=parent and nestedColor or cardColor}):Play() end))
        track(button.MouseButton1Click:Connect(function()
            local original=button.Text
            button.Text="..."
            local ok,result=safeCall(callback)
            if type(result)=="string" and result~="" then button.Text=result else button.Text=ok and original or "FAILED" end
            task.delay(.7,function() if button.Parent and not window.Destroyed then button.Text=original end end)
        end))
        local control={SetText=function(_,value) if button.Parent then button.Text=tostring(value) end end}
        window.Controls[text]=control
        return control,button
    end

    function window:AddStatus(title,parent,height)
        local target=parent or Content
        local card=Instance.new("Frame")
        card.Size=UDim2.new(1,0,0,height or 118)
        card.BackgroundColor3=parent and nestedColor or cardColor
        card.BorderSizePixel=0
        card.Parent=target
        round(card,5)
        stroke(card,lineColor,.55)
        local caption=makeLabel(card,title or "STATUS",9,20,.25)
        caption.Position=UDim2.fromOffset(10,5)
        local body=makeLabel(card,"",9,(height or 118)-30,.18)
        body.Size=UDim2.new(1,-20,1,-30)
        body.Position=UDim2.fromOffset(10,27)
        body.Font=Enum.Font.Code
        body.TextYAlignment=Enum.TextYAlignment.Top
        body.TextWrapped=true
        local control={Set=function(_,text) if body.Parent then body.Text=tostring(text or "") end end,Label=body}
        return control,card
    end

    local currentTween
    function window:SetOpen(state)
        if self.Destroyed then return false end
        state=state==true
        self.Open=state
        if currentTween then pcall(currentTween.Cancel,currentTween) end
        if state then
            Body.Visible=true
            OpenButton.Text="CLOSE"
            currentTween=TweenService:Create(Body,TweenInfo.new(.18,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=UDim2.new(1,0,0,bodyHeight)})
            currentTween:Play()
        else
            OpenButton.Text="OPEN"
            currentTween=TweenService:Create(Body,TweenInfo.new(.14,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Size=UDim2.new(1,0,0,0)})
            local tween=currentTween
            tween:Play()
            task.spawn(function()
                tween.Completed:Wait()
                if not self.Destroyed and not self.Open and currentTween==tween then Body.Visible=false end
            end)
        end
        return true
    end

    track(OpenButton.MouseButton1Click:Connect(function() window:SetOpen(not window.Open) end))

    local dragging=false
    local dragInput
    local dragStart
    local startPosition
    track(Header.InputBegan:Connect(function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local p=input.Position
        local bp,bs=OpenButton.AbsolutePosition,OpenButton.AbsoluteSize
        if p.X>=bp.X and p.X<=bp.X+bs.X and p.Y>=bp.Y and p.Y<=bp.Y+bs.Y then return end
        dragging=true
        dragStart=input.Position
        startPosition=Root.Position
        local changed
        changed=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if changed then changed:Disconnect() end
            end
        end)
    end))
    track(Header.InputChanged:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then dragInput=input end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging or input~=dragInput then return end
        local delta=input.Position-dragStart
        Root.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
    end))

    track(UserInputService.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.KeyCode==(options.ToggleKey or Enum.KeyCode.RightShift) then window:SetOpen(not window.Open) end
    end))

    function window:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        if currentTween then pcall(currentTween.Cancel,currentTween) end
        disconnectAll(self.Connections)
        self.Controls={}
        if Gui then pcall(Gui.Destroy,Gui) end
        if Windows[id]==self then Windows[id]=nil end
    end

    if not window.Open then
        Body.Size=UDim2.new(1,0,0,0)
        Body.Visible=false
        OpenButton.Text="OPEN"
    end

    Windows[id]=window
    return window
end

function Library.DestroyAll()
    local list={}
    for _,window in pairs(Windows) do list[#list+1]=window end
    for _,window in ipairs(list) do pcall(window.Destroy,window) end
end

return Library

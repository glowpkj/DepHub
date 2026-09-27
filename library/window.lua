local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")

local Window={}
Window.__index=Window

local function disconnect(connection)
    if connection then pcall(connection.Disconnect,connection) end
end

local function newFrame(name,parent,size,position,color)
    local frame=Instance.new("Frame")
    frame.Name=name
    frame.Size=size
    frame.Position=position or UDim2.fromOffset(0,0)
    frame.BackgroundColor3=color
    frame.BorderSizePixel=0
    frame.Parent=parent
    return frame
end

function Window.new(dependencies,options)
    options=options or {}
    local self=setmetatable({
        Theme=dependencies.Theme,
        Destroyed=false,
        Open=true,
        Compact=false,
        CurrentPage=nil,
        Pages={},
        Tabs={},
        Connections={},
        Tweens={},
        Responsive={},
        ToggleKey=Enum.KeyCode.RightControl,
        Title=options.Title or "DEPHUB",
        Subtitle=options.Subtitle or "UNIVERSAL",
        Backend=options.Backend,
        Environment=options.Environment,
        Generation=0,
        OpenVersion=0,
        SearchOriginals={}
    },Window)
    self.Utils=dependencies.Utils.new(self,self.Theme)
    self.Components=dependencies.Components.new(self,self.Utils,self.Theme)
    self:_build()
    self:CreateTab("HOME","HOME",true)
    self:_buildHome()
    self:OpenPage("HOME")
    self:_bind()
    self:_updateResponsive(true)
    return self
end

function Window:_build()
    self.LocalPlayer=Players.LocalPlayer or Players.PlayerAdded:Wait()
    self.PlayerGui=self.LocalPlayer:FindFirstChildOfClass("PlayerGui") or self.LocalPlayer:WaitForChild("PlayerGui",30)
    assert(self.PlayerGui,"PlayerGui unavailable")

    for _,child in ipairs(self.PlayerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name=="DepHubLibrary" then
            child:Destroy()
        end
    end

    local screen=Instance.new("ScreenGui")
    screen.Name="DepHubLibrary"
    screen.ResetOnSpawn=false
    screen.IgnoreGuiInset=true
    screen.DisplayOrder=999999
    screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screen.Parent=self.PlayerGui
    self.ScreenGui=screen

    local main=newFrame("MainFrame",screen,UDim2.fromOffset(740,474),UDim2.fromScale(0.5,0.5),self.Theme.Background)
    main.AnchorPoint=Vector2.new(0.5,0.5)
    main.Active=true
    main.ClipsDescendants=false
    self.Utils:Corner(main,UDim.new(0,11))
    self.Utils:Stroke(main,self.Theme.Border,0.05,1)
    self.MainFrame=main

    local scale=Instance.new("UIScale")
    scale.Scale=1
    scale.Parent=main
    self.MainScale=scale

    local body=newFrame("WindowContent",main,UDim2.fromScale(1,1),nil,self.Theme.Background)
    body.ClipsDescendants=true
    self.Utils:Corner(body,UDim.new(0,11))

    local sidebar=newFrame("Sidebar",body,UDim2.fromOffset(182,474),nil,self.Theme.Sidebar)
    self.Sidebar=sidebar
    local divider=newFrame("Divider",sidebar,UDim2.new(0,1,1,0),UDim2.new(1,-1,0,0),self.Theme.Border)
    divider.BackgroundTransparency=0.1

    self.Brand=self.Utils:Text(sidebar,self.Title,UDim2.new(1,-34,0,33),UDim2.fromOffset(20,22),23,Enum.Font.GothamBlack,self.Theme.White)
    self.Brand.TextTruncate=Enum.TextTruncate.AtEnd
    local accent=newFrame("BrandAccent",sidebar,UDim2.fromOffset(25,2),UDim2.fromOffset(20,69),self.Theme.Accent)
    self.SubtitleLabel=self.Utils:Text(sidebar,string.upper(self.Subtitle),UDim2.new(1,-64,0,18),UDim2.fromOffset(54,61),10,Enum.Font.GothamBold,self.Theme.White)

    self.NavigationLabel=self.Utils:Text(sidebar,"NAVEGAÇÃO",UDim2.new(1,-36,0,18),UDim2.fromOffset(20,107),10,Enum.Font.GothamBold,self.Theme.White)

    local homeHolder=newFrame("FixedHome",sidebar,UDim2.new(1,-24,0,45),UDim2.fromOffset(12,133),self.Theme.Sidebar)
    homeHolder.BackgroundTransparency=1
    self.HomeHolder=homeHolder

    local tabs=Instance.new("ScrollingFrame")
    tabs.Name="Tabs"
    tabs.Size=UDim2.new(1,-24,1,-243)
    tabs.Position=UDim2.fromOffset(12,188)
    tabs.BackgroundTransparency=1
    tabs.BorderSizePixel=0
    tabs.CanvasSize=UDim2.fromOffset(0,0)
    tabs.AutomaticCanvasSize=Enum.AutomaticSize.Y
    tabs.ScrollBarThickness=0
    tabs.Parent=sidebar
    local tabLayout=Instance.new("UIListLayout")
    tabLayout.Padding=UDim.new(0,3)
    tabLayout.SortOrder=Enum.SortOrder.LayoutOrder
    tabLayout.Parent=tabs
    self.TabsHolder=tabs

    local sidebarFooter=newFrame("SidebarFooter",sidebar,UDim2.new(1,-40,0,1),UDim2.new(0,20,1,-48),self.Theme.Border)
    self.ShortcutLabel=self.Utils:Text(sidebar,"RIGHT CTRL  /  MENU",UDim2.new(1,-40,0,24),UDim2.new(0,20,1,-40),10,Enum.Font.GothamMedium,self.Theme.White)

    local content=newFrame("Content",body,UDim2.new(1,-182,1,0),UDim2.fromOffset(182,0),self.Theme.Background)
    content.ClipsDescendants=true
    self.Content=content

    local header=newFrame("Header",content,UDim2.new(1,0,0,64),nil,self.Theme.Background)
    self.Header=header
    self.HeaderTitle=self.Utils:Text(header,"HOME",UDim2.new(1,-250,0,32),UDim2.fromOffset(23,17),19,Enum.Font.GothamBold,self.Theme.White)
    local headerDivider=newFrame("HeaderDivider",header,UDim2.new(1,-42,0,1),UDim2.new(0,21,1,-1),self.Theme.Border)
    headerDivider.BackgroundTransparency=0.2

    local search=Instance.new("TextBox")
    search.Name="FeatureSearch"
    search.Size=UDim2.fromOffset(196,33)
    search.Position=UDim2.new(1,-218,0,15)
    search.BackgroundColor3=self.Theme.Input
    search.BorderSizePixel=0
    search.Text=""
    search.PlaceholderText="BUSCAR RECURSOS"
    search.TextColor3=self.Theme.White
    search.PlaceholderColor3=self.Theme.White
    search.TextTransparency=0
    search.PlaceholderColor3=self.Theme.White
    search.Font=Enum.Font.GothamMedium
    search.TextSize=12
    search.ClearTextOnFocus=false
    search.TextXAlignment=Enum.TextXAlignment.Left
    search.Visible=false
    search.Parent=header
    self.Utils:Corner(search,UDim.new(0,5))
    self.Utils:Stroke(search,self.Theme.Border,0.1,1)
    local searchPadding=Instance.new("UIPadding")
    searchPadding.PaddingLeft=UDim.new(0,11)
    searchPadding.PaddingRight=UDim.new(0,9)
    searchPadding.Parent=search
    self.SearchBox=search

    local pages=newFrame("Pages",content,UDim2.new(1,0,1,-64),UDim2.fromOffset(0,64),self.Theme.Background)
    pages.BackgroundTransparency=1
    pages.ClipsDescendants=true
    self.PagesContainer=pages

    local drag=Instance.new("TextButton")
    drag.Name="DragHandle"
    drag.Size=UDim2.new(0,12,1,-30)
    drag.Position=UDim2.fromOffset(0,15)
    drag.BackgroundTransparency=1
    drag.BorderSizePixel=0
    drag.Text=""
    drag.AutoButtonColor=false
    drag.Active=true
    drag.ZIndex=10
    drag.Parent=main
    self.DragHitbox=drag
    local line=newFrame("DragLine",drag,UDim2.fromOffset(2,72),UDim2.new(0,4,0.5,-36),self.Theme.White)
    line.BackgroundTransparency=0.6
    line.ZIndex=11
    self.Utils:Corner(line,UDim.new(1,0))
    self.DragLine=line

    local toggle=Instance.new("TextButton")
    toggle.Name="DepHubToggle"
    toggle.Size=UDim2.fromOffset(52,52)
    toggle.Position=UDim2.fromOffset(18,18)
    toggle.BackgroundColor3=self.Theme.Sidebar
    toggle.BorderSizePixel=0
    toggle.Text="D"
    toggle.TextColor3=self.Theme.White
    toggle.TextSize=23
    toggle.Font=Enum.Font.GothamBlack
    toggle.AutoButtonColor=false
    toggle.Parent=screen
    self.Utils:Corner(toggle,UDim.new(1,0))
    self.ToggleStroke=self.Utils:Stroke(toggle,self.Theme.Accent,0.05,1.5)
    self.ToggleButton=toggle

    local notifications=Instance.new("Frame")
    notifications.Name="Notifications"
    notifications.Size=UDim2.fromOffset(288,420)
    notifications.Position=UDim2.new(1,-14,0,14)
    notifications.AnchorPoint=Vector2.new(1,0)
    notifications.BackgroundTransparency=1
    notifications.Parent=screen
    local notificationLayout=Instance.new("UIListLayout")
    notificationLayout.Padding=UDim.new(0,8)
    notificationLayout.HorizontalAlignment=Enum.HorizontalAlignment.Right
    notificationLayout.SortOrder=Enum.SortOrder.LayoutOrder
    notificationLayout.Parent=notifications
    self.Notifications=notifications
end

function Window:_newPage(name)
    local pageFrame=Instance.new("ScrollingFrame")
    pageFrame.Name=name
    pageFrame.Size=UDim2.fromScale(1,1)
    pageFrame.BackgroundTransparency=1
    pageFrame.BorderSizePixel=0
    pageFrame.CanvasSize=UDim2.fromOffset(0,0)
    pageFrame.AutomaticCanvasSize=Enum.AutomaticSize.Y
    pageFrame.ScrollBarThickness=2
    pageFrame.ScrollBarImageColor3=self.Theme.Accent
    pageFrame.Visible=false
    pageFrame.Parent=self.PagesContainer
    local padding=Instance.new("UIPadding")
    padding.PaddingLeft=UDim.new(0,22)
    padding.PaddingRight=UDim.new(0,22)
    padding.PaddingTop=UDim.new(0,15)
    padding.PaddingBottom=UDim.new(0,28)
    padding.Parent=pageFrame
    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,15)
    layout.SortOrder=Enum.SortOrder.LayoutOrder
    layout.Parent=pageFrame
    local page={Name=name,Instance=pageFrame,Padding=padding,NextOrder=1,Destroyed=false}
    function page:Add(object)
        if self.Destroyed or not object then return end
        object.LayoutOrder=self.NextOrder
        self.NextOrder+=1
        object.Parent=pageFrame
    end
    function page:Destroy()
        if self.Destroyed then return end
        self.Destroyed=true
        pageFrame:Destroy()
        self.Instance=nil
    end
    return page
end

function Window:CreateTab(name,label,fixed)
    name=string.upper(tostring(name))
    label=string.upper(tostring(label or name))
    if self.Pages[name] then return self.Pages[name] end
    local page=self:_newPage(name)
    self.Pages[name]=page

    local button=Instance.new("TextButton")
    button.Name=name
    button.Size=UDim2.new(1,0,0,43)
    button.BackgroundTransparency=1
    button.BorderSizePixel=0
    button.Text=""
    button.AutoButtonColor=false
    button.LayoutOrder=#self.Tabs+1
    button.Parent=fixed and self.HomeHolder or self.TabsHolder
    local marker=newFrame("SelectedLine",button,UDim2.fromOffset(2,21),UDim2.new(0,2,0.5,-10),self.Theme.Accent)
    marker.Visible=false
    local labelText=self.Utils:Text(button,label,UDim2.new(1,-24,1,0),UDim2.fromOffset(15,0),13,Enum.Font.GothamBold,self.Theme.White)
    local record={Name=name,Label=label,Button=button,Text=labelText,Marker=marker,Page=page}
    self.Tabs[#self.Tabs+1]=record
    self.Utils:Track(button.MouseEnter:Connect(function()
        if self.CurrentPage~=name then
            marker.Visible=true
            marker.BackgroundTransparency=0.55
        end
    end))
    self.Utils:Track(button.MouseLeave:Connect(function()
        if self.CurrentPage~=name then marker.Visible=false end
    end))
    self.Utils:Track(button.MouseButton1Click:Connect(function()
        self:OpenPage(name)
    end))
    return page
end

function Window:_clearSearch()
    for instance,visible in pairs(self.SearchOriginals) do
        if instance and instance.Parent then instance.Visible=visible end
    end
    table.clear(self.SearchOriginals)
end

function Window:_applySearch()
    self:_clearSearch()
    if not self.SearchBox or self.CurrentPage=="HOME" then return end
    local query=string.lower(self.SearchBox.Text):match("^%s*(.-)%s*$")
    if query=="" then return end
    local page=self.Pages[self.CurrentPage]
    if not page then return end

    local function matches(object)
        for _,descendant in ipairs(object:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                if string.find(string.lower(descendant.Text),query,1,true) then return true end
            end
        end
        return false
    end

    for _,section in ipairs(page.Instance:GetChildren()) do
        if section:IsA("Frame") and section.Name:sub(1,8)=="Section_" and section.Visible then
            local header=section:FindFirstChildOfClass("TextLabel")
            local all=header and string.find(string.lower(header.Text),query,1,true)~=nil
            local any=false
            for _,control in ipairs(section:GetChildren()) do
                if control:IsA("Frame") and control.Visible then
                    local visible=all or matches(control)
                    self.SearchOriginals[control]=control.Visible
                    control.Visible=visible
                    any=any or visible
                end
            end
            self.SearchOriginals[section]=section.Visible
            section.Visible=any
        end
    end
end

function Window:OpenPage(name)
    if self.Destroyed then return false end
    name=string.upper(tostring(name))
    if not self.Pages[name] then return false end
    if self.CurrentPage==name then return true end

    self:_clearSearch()
    if self.SearchBox then self.SearchBox.Text="" end
    self.CurrentPage=name
    self.HeaderTitle.Text=name

    for pageName,page in pairs(self.Pages) do
        page.Instance.Visible=pageName==name
    end

    local page=self.Pages[name].Instance
    page.Position=UDim2.fromOffset(9,0)
    self.Utils:Tween("page",page,0.18,{Position=UDim2.fromOffset(0,0)})

    for _,tab in ipairs(self.Tabs) do
        local selected=tab.Name==name
        tab.Marker.Visible=selected
        tab.Marker.BackgroundTransparency=0
        tab.Text.Text=selected and ("[  "..tab.Label.."  ]") or tab.Label
        tab.Text.TextColor3=self.Theme.White
        tab.Button.BackgroundTransparency=1
    end

    if self.SearchBox then self.SearchBox.Visible=not self.Compact and name~="HOME" end
    return true
end

function Window:GetPage(name) return self.Pages[string.upper(tostring(name))] end
function Window:CreateSection(page,title) return self.Components:CreateSection(page,title) end
function Window:CreateLabel(section,options) return self.Components:CreateLabel(section,options) end
function Window:CreateButton(section,options) return self.Components:CreateButton(section,options) end
function Window:CreateToggle(section,options) return self.Components:CreateToggle(section,options) end
function Window:CreateSlider(section,options) return self.Components:CreateSlider(section,options) end
function Window:CreateDropdown(section,options) return self.Components:CreateDropdown(section,options) end
function Window:CreateInput(section,options) return self.Components:CreateInput(section,options) end
function Window:CreateKeybind(section,options) return self.Components:CreateKeybind(section,options) end
function Window:CreateColor(section,options) return self.Components:CreateColor(section,options) end

function Window:_buildHome()
    local page=self.Pages.HOME
    local title=self.Utils:Text(page.Instance,"BEM-VINDO AO DEPHUB",UDim2.new(1,0,0,42),nil,23,Enum.Font.GothamBold,self.Theme.White)
    page:Add(title)
    self.WelcomeTitle=title
    local description=self.Utils:Text(page.Instance,"SELECIONE UMA ABA PARA COMEÇAR.",UDim2.new(1,0,0,25),nil,12,Enum.Font.GothamMedium,self.Theme.White)
    page:Add(description)
    local section=self:CreateSection(page,"SESSÃO ATUAL")
    local job=game.JobId~="" and game.JobId or "UNAVAILABLE"
    self:CreateLabel(section,{Title="JOGO",Text=self.Subtitle})
    self:CreateLabel(section,{Title="JOB ID",Text=job})
    self.UptimeLabel=self:CreateLabel(section,{Title="UPTIME",Text=self.Utils:FormatDuration(Workspace.DistributedGameTime)})
end

function Window:SafeCall(callback,...)
    if type(callback)~="function" then return true end
    local ok,result=pcall(callback,...)
    if not ok then self:Notify("ERRO",tostring(result),4,"Error") end
    return ok,result
end

function Window:Notify(title,message,duration,kind)
    if self.Destroyed then return end
    local colors={Success=self.Theme.Success,Warning=self.Theme.Warning,Error=self.Theme.Error,Info=self.Theme.Accent}
    local color=colors[kind or "Info"] or self.Theme.Accent
    local card=newFrame("Notification",self.Notifications,UDim2.new(1,0,0,68),nil,self.Theme.SurfaceElevated)
    self.Utils:Corner(card,UDim.new(0,6))
    self.Utils:Stroke(card,self.Theme.Border,0.1,1)
    newFrame("Accent",card,UDim2.fromOffset(3,46),UDim2.fromOffset(0,11),color)
    self.Utils:Text(card,string.upper(tostring(title or "DEPHUB")),UDim2.new(1,-28,0,24),UDim2.fromOffset(14,7),12,Enum.Font.GothamBold,self.Theme.White)
    self.Utils:Text(card,tostring(message or ""),UDim2.new(1,-28,0,29),UDim2.fromOffset(14,31),11,Enum.Font.Gotham,self.Theme.White)
    task.delay(tonumber(duration) or 3,function()
        if card and card.Parent then card:Destroy() end
    end)
end

function Window:RegisterResponsive(object)
    self.Responsive[#self.Responsive+1]=object
end

function Window:SetToggleKey(key)
    if typeof(key)~="EnumItem" then return end
    self.ToggleKey=key
    if self.ShortcutLabel then self.ShortcutLabel.Text=string.upper(key.Name).."  /  MENU" end
end

function Window:SetOpen(state,instant)
    if self.Destroyed then return end
    local nextOpen=state==true
    if nextOpen==self.Open and not instant then return end
    self.Open=nextOpen
    self.OpenVersion+=1
    local version=self.OpenVersion

    if nextOpen then
        self.MainFrame.Visible=true
        if instant then
            self.MainScale.Scale=1
        else
            self.MainScale.Scale=math.min(self.MainScale.Scale,0.96)
            self.Utils:Tween("window",self.MainScale,0.19,{Scale=1})
        end
    else
        if instant then
            self.MainFrame.Visible=false
        else
            local tween=self.Utils:Tween("window",self.MainScale,0.16,{Scale=0.96})
            tween.Completed:Once(function(stateValue)
                if stateValue==Enum.PlaybackState.Completed and version==self.OpenVersion and not self.Open and not self.Destroyed then
                    self.MainFrame.Visible=false
                end
            end)
        end
    end
end

function Window:IsOpen() return self.Open end
function Window:Toggle() self:SetOpen(not self.Open) end

function Window:_clampWindowPosition()
    local viewport=self.Utils:Viewport()
    local size=self.MainFrame.AbsoluteSize
    local center=self.MainFrame.AbsolutePosition+size/2
    local halfX=size.X/2
    local halfY=size.Y/2
    local x=math.clamp(center.X,halfX+4,math.max(halfX+4,viewport.X-halfX-4))
    local y=math.clamp(center.Y,halfY+4,math.max(halfY+4,viewport.Y-halfY-4))
    self.MainFrame.Position=UDim2.fromOffset(x,y)
end

function Window:_updateResponsive(force)
    if self.Destroyed then return end
    local viewport=self.Utils:Viewport()
    local width=math.min(740,math.max(200,viewport.X-20))
    local height=math.min(474,math.max(230,viewport.Y-20))
    local compact=width<625
    self.MainFrame.Size=UDim2.fromOffset(width,height)
    local side=compact and math.clamp(math.floor(width*0.31),98,146) or 182
    self.Sidebar.Size=UDim2.fromOffset(side,height)
    self.Content.Position=UDim2.fromOffset(side,0)
    self.Content.Size=UDim2.new(1,-side,1,0)
    self.Brand.TextSize=compact and 17 or 23
    self.SubtitleLabel.Visible=not compact
    self.NavigationLabel.TextSize=compact and 9 or 10
    self.HeaderTitle.TextSize=compact and 16 or 19
    self.HeaderTitle.Size=UDim2.new(1,compact and -26 or -250,0,32)
    self.SearchBox.Visible=not compact and self.CurrentPage~="HOME"
    self.TabsHolder.Size=UDim2.new(1,-24,1,-243)

    for _,page in pairs(self.Pages) do
        page.Padding.PaddingLeft=UDim.new(0,compact and 12 or 22)
        page.Padding.PaddingRight=UDim.new(0,compact and 12 or 22)
        page.Padding.PaddingTop=UDim.new(0,compact and 12 or 15)
    end

    if force or compact~=self.Compact then
        self.Compact=compact
        for _,item in ipairs(self.Responsive) do
            if item and not item.Destroyed then item:Reflow(compact) end
        end
    end
    self:_clampWindowPosition()
end

function Window:_bind()
    local dragging,dragInput,dragStart,origin=false,nil,nil,nil
    self.Utils:Track(self.DragHitbox.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            dragInput=input
            dragStart=input.Position
            origin=self.MainFrame.AbsolutePosition+self.MainFrame.AbsoluteSize/2
        end
    end))
    self.Utils:Track(UserInputService.InputChanged:Connect(function(input)
        if not dragging or (input.UserInputType~=Enum.UserInputType.MouseMovement and input~=dragInput) then return end
        local delta=input.Position-dragStart
        local viewport=self.Utils:Viewport()
        local size=self.MainFrame.AbsoluteSize
        local halfX,halfY=size.X/2,size.Y/2
        local x=math.clamp(origin.X+delta.X,halfX+4,math.max(halfX+4,viewport.X-halfX-4))
        local y=math.clamp(origin.Y+delta.Y,halfY+4,math.max(halfY+4,viewport.Y-halfY-4))
        self.MainFrame.Position=UDim2.fromOffset(x,y)
    end))
    self.Utils:Track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input==dragInput then
            dragging=false
            dragInput=nil
        end
    end))

    local toggleDragging,toggleInput,toggleStart,toggleOrigin,toggleMoved=false,nil,nil,nil,false
    self.Utils:Track(self.ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            toggleDragging,toggleInput,toggleStart,toggleOrigin,toggleMoved=true,input,input.Position,self.ToggleButton.Position,false
        end
    end))
    self.Utils:Track(UserInputService.InputChanged:Connect(function(input)
        if not toggleDragging or (input.UserInputType~=Enum.UserInputType.MouseMovement and input~=toggleInput) then return end
        local delta=input.Position-toggleStart
        if delta.Magnitude>=6 then toggleMoved=true end
        local viewport=self.Utils:Viewport()
        local x=math.clamp(toggleOrigin.X.Offset+delta.X,8,math.max(8,viewport.X-self.ToggleButton.AbsoluteSize.X-8))
        local y=math.clamp(toggleOrigin.Y.Offset+delta.Y,8,math.max(8,viewport.Y-self.ToggleButton.AbsoluteSize.Y-8))
        self.ToggleButton.Position=UDim2.fromOffset(x,y)
    end))
    self.Utils:Track(UserInputService.InputEnded:Connect(function(input)
        if not toggleDragging or (input.UserInputType~=Enum.UserInputType.MouseButton1 and input~=toggleInput) then return end
        toggleDragging,toggleInput=false,nil
        if toggleMoved then
            self.SuppressToggleClick=true
            task.delay(0.12,function()
                if not self.Destroyed then self.SuppressToggleClick=false end
            end)
        end
    end))
    self.Utils:Track(self.ToggleButton.MouseButton1Click:Connect(function()
        if not self.SuppressToggleClick then self:Toggle() end
    end))
    self.Utils:Track(self.ToggleButton.MouseEnter:Connect(function()
        self.ToggleButton.BackgroundColor3=self.Theme.SurfaceHover
    end))
    self.Utils:Track(self.ToggleButton.MouseLeave:Connect(function()
        self.ToggleButton.BackgroundColor3=self.Theme.Sidebar
    end))
    self.Utils:Track(UserInputService.InputBegan:Connect(function(input,processed)
        if not processed and input.KeyCode==self.ToggleKey then self:Toggle() end
    end))
    self.Utils:Track(self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self:_applySearch()
    end))

    self.Utils:Track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        self:_bindCamera()
    end))
    self:_bindCamera()
    self.Utils:Track(self.LocalPlayer.OnTeleport:Connect(function()
        self:Destroy()
    end))
    self.Utils:Track(self.PlayerGui.AncestryChanged:Connect(function(_,parent)
        if parent==nil then self:Destroy() end
    end))

    self.Generation+=1
    local generation=self.Generation
    local function uptime()
        if self.Destroyed or generation~=self.Generation then return end
        if self.UptimeLabel then self.UptimeLabel:SetText(self.Utils:FormatDuration(Workspace.DistributedGameTime)) end
        task.delay(1,uptime)
    end
    uptime()
end

function Window:_bindCamera()
    disconnect(self.CameraConnection)
    self.CameraConnection=nil
    local camera=Workspace.CurrentCamera
    if camera then
        self.CameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            self:_updateResponsive()
        end)
    end
    self:_updateResponsive(true)
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true
    self.Generation+=1
    self.OpenVersion+=1
    disconnect(self.CameraConnection)
    self:_clearSearch()
    for _,tween in pairs(self.Tweens) do pcall(tween.Cancel,tween) end
    for _,connection in ipairs(self.Connections) do disconnect(connection) end
    self.Connections,self.Tweens,self.Responsive={},{},{}
    if self.ScreenGui then self.ScreenGui:Destroy() end
    self.ScreenGui,self.MainFrame=nil,nil
    self.Pages,self.Tabs={},{}
    if self.Environment and self.Environment.__DEPHUB_FRONTEND==self then self.Environment.__DEPHUB_FRONTEND=nil end
    local state=self.Environment and self.Environment.__DEPHUB
    if state and state.Frontend==self then state.Frontend=nil end
end

return Window

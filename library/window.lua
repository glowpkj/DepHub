local Window = {}
Window.__index = Window

local function disconnect(connection)
    if connection then pcall(connection.Disconnect, connection) end
end

function Window.new(dependencies, options)
    options = options or {}
    local self = setmetatable({
        Theme = dependencies.Theme,
        Destroyed = false,
        Open = true,
        Compact = false,
        CurrentPage = nil,
        Pages = {},
        Tabs = {},
        Connections = {},
        Tweens = {},
        Responsive = {},
        ToggleKey = Enum.KeyCode.RightControl,
        Title = options.Title or "DEPHUB",
        Subtitle = options.Subtitle or "UNIVERSAL",
        Backend = options.Backend,
        Environment = options.Environment,
        Generation = 0
    }, Window)
    self.Utils = dependencies.Utils.new(self, self.Theme)
    self.Components = dependencies.Components.new(self, self.Utils, self.Theme)
    self:_build(options)
    self:_bind()
    self:CreateTab("HOME", "HOME", true)
    self:_buildHome()
    self:OpenPage("HOME")
    self:_updateResponsive(true)
    return self
end

function Window:_build(options)
    local players = game:GetService("Players")
    self.LocalPlayer = players.LocalPlayer or players.PlayerAdded:Wait()
    self.PlayerGui = self.LocalPlayer:FindFirstChildOfClass("PlayerGui") or self.LocalPlayer:WaitForChild("PlayerGui", 30)
    assert(self.PlayerGui, "PlayerGui unavailable")
    for _, child in ipairs(self.PlayerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == "DepHubLibrary" then child:Destroy() end
    end

    local screen = Instance.new("ScreenGui")
    screen.Name, screen.ResetOnSpawn, screen.IgnoreGuiInset, screen.DisplayOrder = "DepHubLibrary", false, true, 999999
    screen.ZIndexBehavior, screen.Parent = Enum.ZIndexBehavior.Global, self.PlayerGui
    self.ScreenGui = screen

    local main = Instance.new("Frame")
    main.Name, main.Size, main.Position, main.AnchorPoint = "MainFrame", UDim2.fromOffset(760, 480), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
    main.BackgroundColor3, main.BorderSizePixel, main.Active, main.ClipsDescendants = self.Theme.Background, 0, true, false
    main.Parent = screen; self.Utils:Corner(main, UDim.new(0, 15)); self.Utils:Stroke(main, self.Theme.Border, 0.15, 1)
    self.MainFrame = main

    local contentWindow = Instance.new("Frame")
    contentWindow.Name, contentWindow.Size, contentWindow.BackgroundColor3, contentWindow.BorderSizePixel, contentWindow.ClipsDescendants = "WindowContent", UDim2.fromScale(1, 1), self.Theme.Background, 0, true
    contentWindow.Parent = main; self.Utils:Corner(contentWindow, UDim.new(0, 15))

    local sidebar = Instance.new("Frame")
    sidebar.Name, sidebar.Size, sidebar.BackgroundColor3, sidebar.BorderSizePixel = "Sidebar", UDim2.fromOffset(184, 480), self.Theme.Sidebar, 0
    sidebar.Parent = contentWindow; self.Sidebar = sidebar
    local divider = Instance.new("Frame")
    divider.Size, divider.Position, divider.BackgroundColor3, divider.BorderSizePixel, divider.Parent = UDim2.new(0,1,1,0), UDim2.new(1,-1,0,0), self.Theme.Border, 0, sidebar
    self.Brand = self.Utils:Text(sidebar, self.Title, UDim2.new(1,-36,0,36), UDim2.fromOffset(18,26), 22, Enum.Font.GothamBold)
    local subtitle = self.Utils:Text(sidebar, string.upper(self.Subtitle), UDim2.new(1,-36,0,20), UDim2.fromOffset(18,61), 10, Enum.Font.GothamBold, self.Theme.Accent)
    self.SubtitleLabel = subtitle

    local homeHolder = Instance.new("Frame")
    homeHolder.Name, homeHolder.Size, homeHolder.Position, homeHolder.BackgroundTransparency = "FixedHome", UDim2.new(1,-24,0,52), UDim2.fromOffset(12,96), 1
    homeHolder.Parent = sidebar; self.HomeHolder = homeHolder
    local tabs = Instance.new("ScrollingFrame")
    tabs.Name, tabs.Size, tabs.Position, tabs.BackgroundTransparency, tabs.BorderSizePixel = "Tabs", UDim2.new(1,-24,1,-172), UDim2.fromOffset(12,160), 1, 0
    tabs.CanvasSize, tabs.AutomaticCanvasSize, tabs.ScrollBarThickness, tabs.Parent = UDim2.fromOffset(0,0), Enum.AutomaticSize.Y, 0, sidebar
    local tabLayout = Instance.new("UIListLayout"); tabLayout.Padding, tabLayout.SortOrder, tabLayout.Parent = UDim.new(0,7), Enum.SortOrder.LayoutOrder, tabs
    self.TabsHolder = tabs

    local content = Instance.new("Frame")
    content.Name, content.Size, content.Position, content.BackgroundColor3, content.BorderSizePixel, content.ClipsDescendants = "Content", UDim2.new(1,-184,1,0), UDim2.fromOffset(184,0), self.Theme.Background, 0, true
    content.Parent = contentWindow; self.Content = content
    local pages = Instance.new("Frame")
    pages.Name, pages.Size, pages.BackgroundTransparency, pages.Parent = "Pages", UDim2.fromScale(1,1), 1, content
    self.PagesContainer = pages

    local drag = Instance.new("TextButton")
    drag.Name, drag.Size, drag.Position, drag.AnchorPoint, drag.BackgroundTransparency, drag.Text, drag.AutoButtonColor = "DragHandle", UDim2.fromOffset(300,34), UDim2.new(0.5,0,0,0), Vector2.new(0.5,0), 1, "", false
    drag.Parent = main; self.DragHitbox = drag
    local line = Instance.new("Frame")
    line.Size, line.Position, line.AnchorPoint, line.BackgroundColor3, line.BackgroundTransparency, line.BorderSizePixel = UDim2.fromOffset(145,4), UDim2.new(0.5,0,0,10), Vector2.new(0.5,0), self.Theme.White, 0.78, 0
    line.Parent = drag; self.Utils:Corner(line, UDim.new(1,0)); self.DragLine = line

    local toggle = Instance.new("TextButton")
    toggle.Name, toggle.Size, toggle.Position, toggle.BackgroundColor3, toggle.BorderSizePixel, toggle.Text, toggle.AutoButtonColor = "DepHubToggle", UDim2.fromOffset(56,56), UDim2.fromOffset(18,18), self.Theme.Sidebar, 0, "D", false
    toggle.TextColor3, toggle.Font, toggle.TextSize, toggle.Parent = self.Theme.Accent, Enum.Font.GothamBold, 23, screen
    self.Utils:Corner(toggle, UDim.new(1,0)); self.ToggleStroke = self.Utils:Stroke(toggle,self.Theme.Border,0.05,1)
    self.ToggleButton = toggle

    local notifications = Instance.new("Frame")
    notifications.Name, notifications.Size, notifications.Position, notifications.AnchorPoint, notifications.BackgroundTransparency = "Notifications", UDim2.fromOffset(280,420), UDim2.new(1,-14,0,14), Vector2.new(1,0), 1
    notifications.Parent = screen
    local notificationLayout = Instance.new("UIListLayout"); notificationLayout.Padding, notificationLayout.HorizontalAlignment, notificationLayout.SortOrder, notificationLayout.Parent = UDim.new(0,8), Enum.HorizontalAlignment.Right, Enum.SortOrder.LayoutOrder, notifications
    self.Notifications = notifications
end

function Window:_newPage(name)
    local pageFrame = Instance.new("ScrollingFrame")
    pageFrame.Name, pageFrame.Size, pageFrame.BackgroundTransparency, pageFrame.BorderSizePixel = name, UDim2.fromScale(1,1), 1, 0
    pageFrame.CanvasSize, pageFrame.AutomaticCanvasSize, pageFrame.ScrollBarThickness, pageFrame.ScrollBarImageColor3, pageFrame.Visible = UDim2.fromOffset(0,0), Enum.AutomaticSize.Y, 2, self.Theme.Accent, false
    pageFrame.Parent = self.PagesContainer
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom, padding.Parent = UDim.new(0,28), UDim.new(0,28), UDim.new(0,38), UDim.new(0,28), pageFrame
    local layout = Instance.new("UIListLayout"); layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0,12), Enum.SortOrder.LayoutOrder, pageFrame
    local page = {Name=name, Instance=pageFrame, Padding=padding, NextOrder=1, Destroyed=false}
    function page:Add(object) if not self.Destroyed and object then object.LayoutOrder=self.NextOrder; self.NextOrder+=1; object.Parent=pageFrame end end
    function page:Destroy() if self.Destroyed then return end; self.Destroyed=true; pageFrame:Destroy(); self.Instance=nil end
    return page
end

function Window:CreateTab(name, label, fixed)
    name, label = string.upper(tostring(name)), string.upper(tostring(label or name))
    if self.Pages[name] then return self.Pages[name] end
    local page = self:_newPage(name); self.Pages[name] = page
    local button = Instance.new("TextButton")
    button.Name, button.Size, button.BackgroundColor3, button.BorderSizePixel, button.Text, button.AutoButtonColor = name, UDim2.new(1,0,0,50), self.Theme.Sidebar, 0, "", false
    button.LayoutOrder, button.Parent = #self.Tabs+1, fixed and self.HomeHolder or self.TabsHolder
    local text = self.Utils:Text(button,label,UDim2.new(1,-24,1,0),UDim2.fromOffset(12,0),14,Enum.Font.GothamBold)
    local record={Name=name,Label=label,Button=button,Text=text,Page=page}; self.Tabs[#self.Tabs+1]=record
    self.Utils:Track(button.MouseEnter:Connect(function() if self.CurrentPage~=name then button.BackgroundColor3=self.Theme.SidebarHover end end))
    self.Utils:Track(button.MouseLeave:Connect(function() if self.CurrentPage~=name then button.BackgroundColor3=self.Theme.Sidebar end end))
    self.Utils:Track(button.MouseButton1Click:Connect(function() self:OpenPage(name) end))
    return page
end

function Window:OpenPage(name)
    if self.Destroyed then return false end
    name=string.upper(tostring(name)); if not self.Pages[name] then return false end
    self.CurrentPage=name
    for pageName,page in pairs(self.Pages) do page.Instance.Visible=pageName==name end
    for _,tab in ipairs(self.Tabs) do
        local selected=tab.Name==name
        tab.Button.BackgroundColor3=selected and self.Theme.SidebarSelected or self.Theme.Sidebar
        tab.Text.Text=selected and "[ "..tab.Label.." ]" or tab.Label
        tab.Text.TextColor3=selected and self.Theme.Accent or self.Theme.White
    end
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
    local title=self.Utils:Text(page.Instance,"BEM-VINDO AO DEPHUB",UDim2.new(1,0,0,40),nil,25,Enum.Font.GothamBold); page:Add(title); self.WelcomeTitle=title
    local description=self.Utils:Text(page.Instance,"SELECIONE UMA ABA PARA ACESSAR OS RECURSOS.",UDim2.new(1,0,0,24),nil,11,Enum.Font.GothamMedium,self.Theme.Text); page:Add(description)
    local section=self:CreateSection(page,"SESSÃO ATUAL")
    local job=game.JobId~="" and game.JobId or "UNAVAILABLE"
    self:CreateLabel(section,{Title="JOGO",Text=self.Subtitle,Color=self.Theme.Accent})
    self:CreateLabel(section,{Title="JOB ID",Text=job})
    self.UptimeLabel=self:CreateLabel(section,{Title="UPTIME",Text=self.Utils:FormatDuration(workspace.DistributedGameTime),Color=self.Theme.Success})
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
    local card=Instance.new("Frame")
    card.Size,card.BackgroundColor3,card.BorderSizePixel,card.Parent=UDim2.new(1,0,0,70),self.Theme.SurfaceElevated,0,self.Notifications
    self.Utils:Corner(card,UDim.new(0,8)); self.Utils:Stroke(card,colors[kind or "Info"] or self.Theme.Accent,0.15,1)
    self.Utils:Text(card,string.upper(tostring(title or "DEPHUB")),UDim2.new(1,-24,0,24),UDim2.fromOffset(12,7),12,Enum.Font.GothamBold,colors[kind or "Info"] or self.Theme.Accent)
    self.Utils:Text(card,tostring(message or ""),UDim2.new(1,-24,0,27),UDim2.fromOffset(12,31),11,Enum.Font.Gotham,self.Theme.Text)
    task.delay(tonumber(duration) or 3,function() if card and card.Parent then card:Destroy() end end)
end

function Window:RegisterResponsive(object) self.Responsive[#self.Responsive+1]=object end
function Window:SetToggleKey(key) if typeof(key)=="EnumItem" then self.ToggleKey=key end end
function Window:SetOpen(state) self.Open=state==true; if self.MainFrame then self.MainFrame.Visible=self.Open end end
function Window:IsOpen() return self.Open end
function Window:Toggle() self:SetOpen(not self.Open) end

function Window:_updateResponsive(force)
    if self.Destroyed then return end
    local viewport=self.Utils:Viewport(); local width=math.min(760,math.max(300,viewport.X-20)); local height=math.min(480,math.max(260,viewport.Y-20))
    local compact=width<=570
    self.MainFrame.Size=UDim2.fromOffset(width,height)
    local side=compact and math.max(104,math.floor(width*0.29)) or 184
    self.Sidebar.Size=UDim2.fromOffset(side,height); self.Content.Position=UDim2.fromOffset(side,0); self.Content.Size=UDim2.new(1,-side,1,0)
    for _,page in pairs(self.Pages) do
        if page.Padding then
            page.Padding.PaddingLeft=UDim.new(0,compact and 10 or 28)
            page.Padding.PaddingRight=UDim.new(0,compact and 10 or 28)
            page.Padding.PaddingTop=UDim.new(0,compact and 30 or 38)
        end
    end
    self.Brand.TextSize=compact and 17 or 22; self.SubtitleLabel.Visible=not compact
    if force or compact~=self.Compact then self.Compact=compact; for _,item in ipairs(self.Responsive) do if item and not item.Destroyed then item:Reflow(compact) end end end
    local maxX=math.max(0,viewport.X-width); local maxY=math.max(0,viewport.Y-height)
    local center=self.MainFrame.AbsolutePosition
    if center.X<0 or center.Y<0 then self.MainFrame.Position=UDim2.fromScale(0.5,0.5) end
end

function Window:_bind()
    local input=game:GetService("UserInputService"); local dragging,dragInput,start,origin=false,nil,nil,nil
    self.Utils:Track(self.DragHitbox.InputBegan:Connect(function(value)
        if value.UserInputType==Enum.UserInputType.MouseButton1 or value.UserInputType==Enum.UserInputType.Touch then dragging=true;dragInput=value;start=value.Position;origin=self.MainFrame.Position end
    end))
    self.Utils:Track(input.InputChanged:Connect(function(value)
        if dragging and (value.UserInputType==Enum.UserInputType.MouseMovement or value==dragInput) then local delta=value.Position-start; self.MainFrame.Position=UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y) end
    end))
    self.Utils:Track(input.InputEnded:Connect(function(value)
        if value.UserInputType==Enum.UserInputType.MouseButton1 or value==dragInput then dragging=false;dragInput=nil end
    end))
    local toggleDragging,toggleInput,toggleStart,toggleOrigin,toggleMoved=false,nil,nil,nil,false
    self.Utils:Track(self.ToggleButton.InputBegan:Connect(function(value)
        if value.UserInputType==Enum.UserInputType.MouseButton1 or value.UserInputType==Enum.UserInputType.Touch then
            toggleDragging,toggleInput,toggleStart,toggleOrigin,toggleMoved=true,value,value.Position,self.ToggleButton.Position,false
        end
    end))
    self.Utils:Track(input.InputChanged:Connect(function(value)
        if not toggleDragging or (value.UserInputType~=Enum.UserInputType.MouseMovement and value~=toggleInput) then return end
        local delta=value.Position-toggleStart; if delta.Magnitude>=6 then toggleMoved=true end
        local viewport=self.Utils:Viewport()
        local x=math.clamp(toggleOrigin.X.Offset+delta.X,8,math.max(8,viewport.X-self.ToggleButton.AbsoluteSize.X-8))
        local y=math.clamp(toggleOrigin.Y.Offset+delta.Y,8,math.max(8,viewport.Y-self.ToggleButton.AbsoluteSize.Y-8))
        self.ToggleButton.Position=UDim2.fromOffset(x,y)
    end))
    self.Utils:Track(input.InputEnded:Connect(function(value)
        if not toggleDragging or (value.UserInputType~=Enum.UserInputType.MouseButton1 and value~=toggleInput) then return end
        toggleDragging,toggleInput=false,nil
        if toggleMoved then self.SuppressToggleClick=true; task.delay(0.1,function() self.SuppressToggleClick=false end) end
    end))
    self.Utils:Track(self.ToggleButton.MouseButton1Click:Connect(function() if not self.SuppressToggleClick then self:Toggle() end end))
    self.Utils:Track(self.ToggleButton.MouseEnter:Connect(function() self.ToggleButton.BackgroundColor3=self.Theme.SurfaceHover;self.ToggleStroke.Color=self.Theme.Accent end))
    self.Utils:Track(self.ToggleButton.MouseLeave:Connect(function() self.ToggleButton.BackgroundColor3=self.Theme.Sidebar;self.ToggleStroke.Color=self.Theme.Border end))
    self.Utils:Track(input.InputBegan:Connect(function(value,processed) if not processed and value.KeyCode==self.ToggleKey then self:Toggle() end end))
    local workspaceService=game:GetService("Workspace")
    self.Utils:Track(workspaceService:GetPropertyChangedSignal("CurrentCamera"):Connect(function() self:_bindCamera() end))
    self:_bindCamera()
    self.Utils:Track(self.LocalPlayer.OnTeleport:Connect(function() self:Destroy() end))
    self.Utils:Track(self.PlayerGui.AncestryChanged:Connect(function(_,parent) if parent==nil then self:Destroy() end end))
    self.Generation+=1; local generation=self.Generation
    local function uptime()
        if self.Destroyed or generation~=self.Generation then return end
        if self.UptimeLabel then self.UptimeLabel:SetText(self.Utils:FormatDuration(workspace.DistributedGameTime)) end
        task.delay(1,uptime)
    end
    uptime()
end

function Window:_bindCamera()
    disconnect(self.CameraConnection); self.CameraConnection=nil
    local camera=workspace.CurrentCamera
    if camera then self.CameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:_updateResponsive() end); self.Utils:Track(self.CameraConnection) end
    self:_updateResponsive(true)
end

function Window:Destroy()
    if self.Destroyed then return end
    self.Destroyed=true; self.Generation+=1
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

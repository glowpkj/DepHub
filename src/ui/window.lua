local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Library = {}
Library.__index = Library

local Utils = require(script.Parent.utils)
local Responsive = require(script.Parent.responsive)
local Watchdog = require(script.Parent.watchdog)
local Components = require(script.Parent.components)

Components.Register(Tab)

local Colors = Utils.Colors
local Tween = Utils.Tween
local ApplyCorner = Utils.ApplyCorner
local ApplyStroke = Utils.ApplyStroke
local ApplyConstraint = Utils.ApplyConstraint
local CreateLogo = Utils.CreateLogo
local MakeDraggable = Utils.MakeDraggable
local GetInputPosition = Utils.GetInputPosition
local IsPrimaryInput = Utils.IsPrimaryInput
local UserInputService = Utils.UserInputService
local LocalPlayer = Utils.LocalPlayer
local PlayerGui = Utils.PlayerGui
local Camera = Utils.Camera
local EasingQuint = Utils.EasingQuint
local EasingQuad = Utils.EasingQuad
local DirectionOut = Utils.DirectionOut
local DirectionIn = Utils.DirectionIn

local CreateText = Responsive.CreateText
local ComputeScaleFactor = Responsive.ComputeScaleFactor
local RefreshAllTexts = Responsive.RefreshAllTexts

local Instance_new = Instance.new
local UDim2_new = UDim2.new
local UDim2_fromOffset = UDim2.fromOffset
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local ColorSequence_new = ColorSequence.new
local ColorSequenceKeypoint_new = ColorSequenceKeypoint.new
local NumberSequence_new = NumberSequence.new
local NumberSequenceKeypoint_new = NumberSequenceKeypoint.new
local math_clamp = math.clamp
local string_upper = string.upper

function Window:SetOpen(ShouldOpen)
	local Self = self

	if Self.ToggleButton then
		Self.ToggleButton.Visible = true
	end

	if ShouldOpen then
		if not Self.Window or Self.IsHidden == false then
			return
		end

		Self.IsHidden = false
		Self.Window.Visible = true

		local ReopenSize = Self.Window.Size
		Self.Window.Size = UDim2_fromOffset(0, 0)

		Tween(Self.Window, 0.32, EasingQuint, DirectionOut, {
			Size = ReopenSize
		})

		task.delay(0.1, function()
			if Self.Window and Self.Window.AbsoluteSize.X > 0 then
				RefreshAllTexts(ComputeScaleFactor(Self.Window.AbsoluteSize.X))
			end
		end)
	else
		Self.IsHidden = true

		local ClosingSize = Self.Window.Size
		Self.LastOpenSize = ClosingSize

		local ClosingTween = Tween(Self.Window, 0.22, EasingQuint, DirectionIn, {
			Size = UDim2_fromOffset(0, 0)
		})

		ClosingTween.Completed:Connect(function()
			Self.Window.Visible = false
			Self.Window.Size = ClosingSize
		end)
	end
end

function Window:Notify(Title, Text, Duration, NotifyType)
	local Self = self
	Duration = Duration or 4

	local TypeColors = {
		Info = Colors.Accent,
		Success = Colors.Success,
		Warning = Colors.Warning,
		Error = Colors.Error
	}

	local StripColor = TypeColors[NotifyType or "Info"] or Colors.Accent

	Self.NotifyCount = Self.NotifyCount + 1
	local Order = Self.NotifyCount

	local Toast = Instance_new("Frame")
	Toast.Size = UDim2_new(1, 0, 0, 64)
	Toast.BackgroundColor3 = Colors.Card
	Toast.BorderSizePixel = 0
	Toast.ClipsDescendants = true
	Toast.LayoutOrder = Order
	Toast.Position = UDim2_new(1.4, 0, 0, 0)
	Toast.Parent = Self.NotificationContainer

	ApplyCorner(Toast, 9)
	ApplyStroke(Toast, Colors.Border, 1, 0.3)

	local Strip = Instance_new("Frame")
	Strip.Size = UDim2_new(0, 3, 1, -16)
	Strip.Position = UDim2_new(0, 8, 0.5, 0)
	Strip.AnchorPoint = Vector2_new(0, 0.5)
	Strip.BackgroundColor3 = StripColor
	Strip.BorderSizePixel = 0
	Strip.Parent = Toast
	ApplyCorner(Strip, 100)

	CreateText(
		Toast,
		Title or "",
		UDim2_new(1, -32, 0, 20),
		UDim2_new(0, 20, 0, 10),
		13,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Toast,
		Text or "",
		UDim2_new(1, -32, 0, 32),
		UDim2_new(0, 20, 0, 30),
		11,
		Colors.Gray,
		Enum.Font.Gotham
	)

	Tween(Toast, 0.32, EasingQuint, DirectionOut, {
		Position = UDim2_new(0, 0, 0, 0)
	})

	task.delay(Duration, function()
		if Toast and Toast.Parent then
			local OutTween = Tween(Toast, 0.28, EasingQuint, DirectionIn, {
				Position = UDim2_new(1.4, 0, 0, 0)
			})

			OutTween.Completed:Connect(function()
				Toast:Destroy()
			end)
		end
	end)

	return Toast
end

function Window:CreateTab(TabName, IconId, Description)
	local Self = self

	if TabName ~= "Dashboard" and not Self.DashboardCreated then
		Self:CreateDashboard()
	end

	if not Self.Rebuilding then
		Self.TabDefinitions[#Self.TabDefinitions + 1] = {
			Name = TabName,
			IconId = IconId,
			Description = Description
		}
	end

	local NewTab = setmetatable({}, Tab)

	NewTab.Name = TabName
	NewTab.WindowRef = Self
	NewTab.Elements = {}
	NewTab.IconId = IconId
	NewTab.Description = Description

	local Order = #Self.Tabs + 1

	local Page = Instance_new("ScrollingFrame")
	Page.Name = TabName .. "Page"
	Page.Size = UDim2_new(1, 0, 1, 0)
	Page.BackgroundTransparency = 1
	Page.BorderSizePixel = 0
	Page.ScrollBarThickness = 2
	Page.ScrollBarImageColor3 = Colors.BorderLight
	Page.CanvasSize = UDim2_new(0, 0, 0, 0)
	Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Page.Visible = false
	Page.Parent = Self.Content
	NewTab.Page = Page

	local Padding = Instance_new("UIPadding")
	Padding.PaddingLeft = UDim_new(0, 22)
	Padding.PaddingRight = UDim_new(0, 22)
	Padding.PaddingTop = UDim_new(0, 22)
	Padding.PaddingBottom = UDim_new(0, 22)
	Padding.Parent = Page

	local Layout = Instance_new("UIListLayout")
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Padding = UDim_new(0, 10)
	Layout.Parent = Page

	local TitleLabel = CreateText(
		Page,
		TabName,
		UDim2_new(1, 0, 0, 32),
		UDim2_new(0, 0, 0, 0),
		24,
		Colors.White,
		Enum.Font.GothamBold
	)
	TitleLabel.LayoutOrder = 1
	NewTab.TitleLabel = TitleLabel

	local DescriptionLabel = CreateText(
		Page,
		Description or "",
		UDim2_new(1, 0, 0, 25),
		UDim2_new(0, 0, 0, 0),
		12,
		Colors.Gray,
		Enum.Font.Gotham
	)
	DescriptionLabel.LayoutOrder = 2
	NewTab.DescriptionLabel = DescriptionLabel
	NewTab.NextOrder = 3

	local Button = Instance_new("TextButton")
	Button.Name = TabName .. "Tab"
	Button.Size = UDim2_new(1, 0, 0, 39)
	Button.BackgroundTransparency = 1
	Button.BackgroundColor3 = Colors.Active
	Button.BorderSizePixel = 0
	Button.Text = ""
	Button.AutoButtonColor = false
	Button.LayoutOrder = Order
	Button.Parent = Self.TabContainer

	ApplyCorner(Button, 8)

	local Indicator = Instance_new("Frame")
	Indicator.Size = UDim2_fromOffset(3, 19)
	Indicator.Position = UDim2_new(0, 0, 0.5, 0)
	Indicator.AnchorPoint = Vector2_new(0, 0.5)
	Indicator.BackgroundColor3 = Colors.White
	Indicator.BackgroundTransparency = 1
	Indicator.BorderSizePixel = 0
	Indicator.Parent = Button
	ApplyCorner(Indicator, 100)

	local IconLabel
	local LabelOffset = 15

	if IconId then
		IconLabel = Instance_new("ImageLabel")
		IconLabel.Size = UDim2_fromOffset(16, 16)
		IconLabel.Position = UDim2_new(0, 14, 0.5, 0)
		IconLabel.AnchorPoint = Vector2_new(0, 0.5)
		IconLabel.BackgroundTransparency = 1
		IconLabel.Image = IconId
		IconLabel.ImageColor3 = Colors.Gray
		IconLabel.ScaleType = Enum.ScaleType.Fit
		IconLabel.Parent = Button
		LabelOffset = 38
	end

	local Label = CreateText(
		Button,
		string_upper(TabName),
		UDim2_new(1, -LabelOffset - 10, 1, 0),
		UDim2_new(0, LabelOffset, 0, 0),
		11,
		Colors.Gray,
		Enum.Font.GothamBold
	)

	NewTab.Button = Button
	NewTab.Label = Label
	NewTab.Indicator = Indicator
	NewTab.IconLabel = IconLabel

	Self.TabButtons[TabName] = NewTab
	Self.Tabs[#Self.Tabs + 1] = NewTab

	Button.MouseEnter:Connect(function()
		if Self.CurrentTab ~= TabName then
			Tween(Button, 0.16, EasingQuint, DirectionOut, {
				BackgroundTransparency = 0.65
			})

			Tween(Label, 0.16, EasingQuint, DirectionOut, {
				TextColor3 = Colors.Light
			})

			if IconLabel then
				Tween(IconLabel, 0.16, EasingQuint, DirectionOut, {
					ImageColor3 = Colors.Light
				})
			end
		end
	end)

	Button.MouseLeave:Connect(function()
		if Self.CurrentTab ~= TabName then
			Tween(Button, 0.16, EasingQuint, DirectionOut, {
				BackgroundTransparency = 1
			})

			Tween(Label, 0.16, EasingQuint, DirectionOut, {
				TextColor3 = Colors.Gray
			})

			if IconLabel then
				Tween(IconLabel, 0.16, EasingQuint, DirectionOut, {
					ImageColor3 = Colors.Gray
				})
			end
		end
	end)

	Button.MouseButton1Down:Connect(function()
		Tween(Button, 0.08, EasingQuad, DirectionOut, {
			BackgroundColor3 = Colors.ActiveHover
		})
	end)

	Button.MouseButton1Click:Connect(function()
		Self:SelectTab(TabName)
	end)

	if Order == 1 and not Self.Rebuilding then
		task.defer(function()
			Self:SelectTab(TabName)
		end)
	end

	return NewTab
end

function Window:SelectTab(TabName)
	local Self = self

	if Self.Switching or Self.CurrentTab == TabName then
		return
	end

	local TargetTab = Self.TabButtons[TabName]
	if not TargetTab then
		return
	end

	Self.Switching = true

	local OldTabName = Self.CurrentTab
	local OldTab = OldTabName and Self.TabButtons[OldTabName]
	local NewPage = TargetTab.Page

	if OldTab then
		local OldPage = OldTab.Page
		local OldTween = Tween(OldPage, 0.14, EasingQuint, DirectionIn, {
			Position = UDim2_new(0, -18, 0, 0)
		})

		OldTween.Completed:Wait()
		OldPage.Visible = false
		OldPage.Position = UDim2_new(0, 0, 0, 0)
	end

	NewPage.Position = UDim2_new(0, 18, 0, 0)
	NewPage.Visible = true

	Tween(NewPage, 0.28, EasingQuint, DirectionOut, {
		Position = UDim2_new(0, 0, 0, 0)
	})

	for _, TabData in Self.Tabs do
		local Active = TabData.Name == TabName

		Tween(TabData.Button, 0.18, EasingQuint, DirectionOut, {
			BackgroundTransparency = Active and 0 or 1
		})

		Tween(TabData.Label, 0.18, EasingQuint, DirectionOut, {
			TextColor3 = Active and Colors.White or Colors.Gray
		})

		Tween(TabData.Indicator, 0.18, EasingQuint, DirectionOut, {
			BackgroundTransparency = Active and 0 or 1
		})

		if TabData.IconLabel then
			Tween(TabData.IconLabel, 0.18, EasingQuint, DirectionOut, {
				ImageColor3 = Active and Colors.White or Colors.Gray
			})
		end
	end

	Self.CurrentTab = TabName
	Self.CurrentTabName = TabName

	task.wait(0.12)

	Self.Switching = false
end

function Window:CreateDashboard(WelcomeTitle, WelcomeText)
	local Self = self

	if Self.DashboardCreated and Self.DashboardTab then
		return Self.DashboardTab
	end

	Self.DashboardCreated = true

	local DashTab = Self:CreateTab("Dashboard", nil, WelcomeText or "Bem-vindo de volta.")
	Self.DashboardTab = DashTab

	if WelcomeTitle then
		DashTab.TitleLabel.Text = WelcomeTitle
	end

	local Grid = DashTab:CreateStatGrid()
	local StatPlayer = Grid:CreateStat("JOGADOR", "@" .. LocalPlayer.Name)
	local StatStatus = Grid:CreateStat("STATUS", "ONLINE")
	local StatVersion = Grid:CreateStat("VERSÃO", "--")
	local StatPing = Grid:CreateStat("PING", "--")

	Self.DashboardStats = {
		Player = StatPlayer,
		Status = StatStatus,
		Version = StatVersion,
		Ping = StatPing
	}

	DashTab:CreateDivider("ÚLTIMAS ATUALIZAÇÕES")

	local ReleasesHolder = Instance_new("Frame")
	ReleasesHolder.Name = "ReleasesHolder"
	ReleasesHolder.Size = UDim2_new(1, 0, 0, 0)
	ReleasesHolder.AutomaticSize = Enum.AutomaticSize.Y
	ReleasesHolder.BackgroundTransparency = 1
	ReleasesHolder.LayoutOrder = DashTab.NextOrder
	ReleasesHolder.Parent = DashTab.Page
	DashTab.NextOrder = DashTab.NextOrder + 1

	local ReleasesLayout = Instance_new("UIListLayout")
	ReleasesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ReleasesLayout.Padding = UDim_new(0, 10)
	ReleasesLayout.Parent = ReleasesHolder

	local EmptyLabel = CreateText(
		ReleasesHolder,
		"Nenhuma atualização publicada ainda.",
		UDim2_new(1, 0, 0, 20),
		UDim2_new(0, 0, 0, 0),
		11,
		Colors.DarkGray,
		Enum.Font.Gotham
	)
	EmptyLabel.LayoutOrder = 1

	Self.ReleasesHolder = ReleasesHolder
	Self.ReleasesEmptyLabel = EmptyLabel

	return DashTab
end

function Window:SetReleases(Changelog)
	local Self = self

	if not Self.DashboardCreated then
		Self:CreateDashboard()
	end

	local Holder = Self.ReleasesHolder
	if not Holder then
		return
	end

	for _, Child in Holder:GetChildren() do
		if not Child:IsA("UIListLayout") then
			Child:Destroy()
		end
	end

	if not Changelog or #Changelog == 0 then
		local EmptyLabel = CreateText(
			Holder,
			"Nenhuma atualização publicada ainda.",
			UDim2_new(1, 0, 0, 20),
			UDim2_new(0, 0, 0, 0),
			11,
			Colors.DarkGray,
			Enum.Font.Gotham
		)
		EmptyLabel.LayoutOrder = 1
		return
	end

	if Self.DashboardStats and Self.DashboardStats.Version and Changelog[1] then
		Self.DashboardStats.Version:SetValue(Changelog[1].Version or "--")
	end

	for Index, Entry in Changelog do
		local Card = Instance_new("Frame")
		Card.Size = UDim2_new(1, 0, 0, 0)
		Card.AutomaticSize = Enum.AutomaticSize.Y
		Card.BackgroundColor3 = Colors.Card
		Card.BorderSizePixel = 0
		Card.LayoutOrder = Index
		Card.Parent = Holder

		ApplyCorner(Card, 9)
		ApplyStroke(Card, Colors.Border, 1, 0.35)

		local Accent = Instance_new("Frame")
		Accent.Size = UDim2_fromOffset(2, 22)
		Accent.Position = UDim2_new(0, 0, 0, 14)
		Accent.BackgroundColor3 = Colors.Accent
		Accent.BackgroundTransparency = 0.35
		Accent.BorderSizePixel = 0
		Accent.Parent = Card
		ApplyCorner(Accent, 100)

		local HeaderText = CreateText(
			Card,
			(Entry.Version or "") .. "   •   " .. (Entry.Date or ""),
			UDim2_new(1, -28, 0, 22),
			UDim2_new(0, 14, 0, 10),
			14,
			Colors.White,
			Enum.Font.GothamBold
		)

		local ChangesHolder = Instance_new("Frame")
		ChangesHolder.Size = UDim2_new(1, -28, 0, 0)
		ChangesHolder.AutomaticSize = Enum.AutomaticSize.Y
		ChangesHolder.Position = UDim2_new(0, 14, 0, 36)
		ChangesHolder.BackgroundTransparency = 1
		ChangesHolder.Parent = Card

		local ChangesLayout = Instance_new("UIListLayout")
		ChangesLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ChangesLayout.Padding = UDim_new(0, 2)
		ChangesLayout.Parent = ChangesHolder

		local BottomPadding = Instance_new("Frame")
		BottomPadding.Size = UDim2_new(1, 0, 0, 12)
		BottomPadding.BackgroundTransparency = 1
		BottomPadding.LayoutOrder = 999
		BottomPadding.Parent = Card

		if Entry.Changes then
			for LineIndex, Line in Entry.Changes do
				local LineLabel = CreateText(
					ChangesHolder,
					"•  " .. tostring(Line),
					UDim2_new(1, 0, 0, 16),
					UDim2_new(0, 0, 0, 0),
					12,
					Colors.Gray,
					Enum.Font.Gotham
				)
				LineLabel.LayoutOrder = LineIndex
			end
		end
	end
end

function Window:Destroy()
	local Self = self

	Watchdog.Stop(Self)

	for _, Connection in Self.Connections do
		if Connection and Connection.Disconnect then
			Connection:Disconnect()
		end
	end

	Self.Connections = {}

	if Self.Window then
		local ClosingTween = Tween(Self.Window, 0.22, EasingQuint, DirectionIn, {
			Size = UDim2_fromOffset(0, 0)
		})

		ClosingTween.Completed:Connect(function()
			if Self.ScreenGui then
				Self.ScreenGui:Destroy()
				Self.ScreenGui = nil
			end
		end)
	elseif Self.ScreenGui then
		Self.ScreenGui:Destroy()
		Self.ScreenGui = nil
	end
end

function Library.new(HubName, Subtitle, LogoId)
	local Self = setmetatable({}, Window)

	Self.Connections = {}
	Self.Tabs = {}
	Self.TabButtons = {}
	Self.TabDefinitions = {}
	Self.CurrentTab = nil
	Self.CurrentTabName = nil
	Self.Switching = false
	Self.IsHidden = false
	Self.DashboardCreated = false
	Self.NotifyCount = 0
	Self.LogoId = LogoId or Utils.DefaultLogoId
	Self.HubName = HubName
	Self.Subtitle = Subtitle

	Self.Destroyed = false
	Self.WatchdogRunning = false
	Self.Rebuilding = false

	local function BuildCoreUI()
		if Self.ScreenGui then
			Self.ScreenGui:Destroy()
			Self.ScreenGui = nil
		end

		local ScreenGui = Instance_new("ScreenGui")
		ScreenGui.Name = "DepHubLibraryGui"
		ScreenGui.ResetOnSpawn = false
		ScreenGui.IgnoreGuiInset = true
		ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		ScreenGui.DisplayOrder = 999
		ScreenGui.Parent = PlayerGui
		Self.ScreenGui = ScreenGui

		local MainWindow = Instance_new("Frame")
		MainWindow.Name = "Window"
		MainWindow.Size = UDim2_new(0.68, 0, 0.72, 0)
		MainWindow.Position = UDim2_new(0.5, 0, 0.5, 0)
		MainWindow.AnchorPoint = Vector2_new(0.5, 0.5)
		MainWindow.BackgroundColor3 = Colors.Background
		MainWindow.BorderSizePixel = 0
		MainWindow.ClipsDescendants = true
		MainWindow.Parent = ScreenGui
		Self.Window = MainWindow

		ApplyConstraint(MainWindow, Vector2_new(500, 320), Vector2_new(1800, 1200))
		ApplyCorner(MainWindow, 10)
		ApplyStroke(MainWindow, Colors.Border, 1, 0.15)

		local Sheen = Instance_new("Frame")
		Sheen.BackgroundColor3 = Colors.White
		Sheen.BackgroundTransparency = 1
		Sheen.BorderSizePixel = 0
		Sheen.Size = UDim2_new(1, 0, 0, 140)
		Sheen.ZIndex = 0
		Sheen.Parent = MainWindow

		local SheenGradient = Instance_new("UIGradient")
		SheenGradient.Rotation = 90
		SheenGradient.Color = ColorSequence_new(Colors.White)
		SheenGradient.Transparency = NumberSequence_new({
			NumberSequenceKeypoint_new(0, 0.94),
			NumberSequenceKeypoint_new(1, 1)
		})
		SheenGradient.Parent = Sheen

		local TitleBar = Instance_new("Frame")
		TitleBar.Name = "TitleBar"
		TitleBar.Size = UDim2_new(1, 0, 0, 44)
		TitleBar.BackgroundColor3 = Colors.Black
		TitleBar.BorderSizePixel = 0
		TitleBar.Parent = MainWindow
		Self.TitleBar = TitleBar

		local TitleLine = Instance_new("Frame")
		TitleLine.Size = UDim2_new(1, 0, 0, 1)
		TitleLine.Position = UDim2_new(0, 0, 1, -1)
		TitleLine.BackgroundColor3 = Colors.Border
		TitleLine.BorderSizePixel = 0
		TitleLine.Parent = TitleBar

		CreateLogo(TitleBar, Self.LogoId, UDim2_fromOffset(24, 24), UDim2_new(0, 14, 0.5, 0), Vector2_new(0, 0.5))

		local TitleLabel = CreateText(
			TitleBar,
			string_upper(Self.HubName or "HUB"),
			UDim2_new(0, 160, 1, 0),
			UDim2_new(0, 48, 0, 0),
			14,
			Colors.White,
			Enum.Font.GothamBold
		)

		local SubtitleLabel = CreateText(
			TitleBar,
			string_upper(Self.Subtitle or "GAME SYSTEM"),
			UDim2_new(0, 160, 1, 0),
			UDim2_new(0, 118, 0, 0),
			10,
			Colors.DarkGray,
			Enum.Font.GothamMedium
		)

		local Sidebar = Instance_new("Frame")
		Sidebar.Name = "Sidebar"
		Sidebar.Size = UDim2_new(0.22, 0, 1, -44)
		Sidebar.Position = UDim2_new(0, 0, 0, 44)
		Sidebar.BackgroundColor3 = Colors.Sidebar
		Sidebar.BorderSizePixel = 0
		Sidebar.Parent = MainWindow
		Self.Sidebar = Sidebar

		local SidebarSizeConstraint = Instance_new("UISizeConstraint")
		SidebarSizeConstraint.MinSize = Vector2_new(140, 0)
		SidebarSizeConstraint.MaxSize = Vector2_new(220, math.huge)
		SidebarSizeConstraint.Parent = Sidebar

		local function RecalculateResponsiveLayout()
			local Width = MainWindow.AbsoluteSize.X
			if Width <= 0 then
				return
			end
			RefreshAllTexts(ComputeScaleFactor(Width))
		end

		Self.Connections[#Self.Connections + 1] = MainWindow:GetPropertyChangedSignal("AbsoluteSize"):Connect(RecalculateResponsiveLayout)

		CreateLogo(Sidebar, Self.LogoId, UDim2_fromOffset(44, 44), UDim2_new(0.5, 0, 0, 22), Vector2_new(0.5, 0))

		local Brand = CreateText(
			Sidebar,
			string_upper(Self.HubName or "HUB"),
			UDim2_new(1, -30, 0, 22),
			UDim2_new(0, 15, 0, 70),
			16,
			Colors.White,
			Enum.Font.GothamBold,
			Enum.TextXAlignment.Center
		)

		local BrandSubtitle = CreateText(
			Sidebar,
			string_upper(Self.Subtitle or "GAME SYSTEM"),
			UDim2_new(1, -30, 0, 16),
			UDim2_new(0, 15, 0, 91),
			10,
			Colors.DarkGray,
			Enum.Font.GothamMedium,
			Enum.TextXAlignment.Center
		)

		local NavigationTitle = CreateText(
			Sidebar,
			"NAVIGATION",
			UDim2_new(1, -28, 0, 18),
			UDim2_new(0, 14, 0, 124),
			10,
			Colors.DarkGray,
			Enum.Font.GothamBold
		)

		local TabContainer = Instance_new("ScrollingFrame")
		TabContainer.Name = "Navigation"
		TabContainer.Size = UDim2_new(1, -24, 1, -206)
		TabContainer.Position = UDim2_new(0, 12, 0, 148)
		TabContainer.BackgroundTransparency = 1
		TabContainer.BorderSizePixel = 0
		TabContainer.ScrollBarThickness = 2
		TabContainer.ScrollBarImageColor3 = Colors.BorderLight
		TabContainer.CanvasSize = UDim2_new(0, 0, 0, 0)
		TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
		TabContainer.Parent = Sidebar
		Self.TabContainer = TabContainer

		local TabLayout = Instance_new("UIListLayout")
		TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		TabLayout.Padding = UDim_new(0, 5)
		TabLayout.Parent = TabContainer

		local UserBox = Instance_new("Frame")
		UserBox.Size = UDim2_new(1, -24, 0, 42)
		UserBox.Position = UDim2_new(0, 12, 1, -54)
		UserBox.BackgroundColor3 = Colors.Card
		UserBox.BorderSizePixel = 0
		UserBox.Parent = Sidebar

		ApplyCorner(UserBox, 8)
		ApplyStroke(UserBox, Colors.Border, 1, 0.35)

		local UserStatus = Instance_new("Frame")
		UserStatus.Size = UDim2_fromOffset(7, 7)
		UserStatus.Position = UDim2_new(0, 11, 0.5, 0)
		UserStatus.AnchorPoint = Vector2_new(0, 0.5)
		UserStatus.BackgroundColor3 = Colors.Success
		UserStatus.BorderSizePixel = 0
		UserStatus.Parent = UserBox
		ApplyCorner(UserStatus, 100)

		local UserName = CreateText(
			UserBox,
			"@" .. LocalPlayer.Name,
			UDim2_new(1, -32, 1, 0),
			UDim2_new(0, 27, 0, 0),
			12,
			Colors.Gray,
			Enum.Font.GothamMedium
		)

		local Content = Instance_new("Frame")
		Content.Name = "Content"
		Content.Size = UDim2_new(0.78, 0, 1, -44)
		Content.Position = UDim2_new(0.22, 0, 0, 44)
		Content.BackgroundColor3 = Colors.Background
		Content.BorderSizePixel = 0
		Content.ClipsDescendants = true
		Content.Parent = MainWindow
		Self.Content = Content

		Self.Connections[#Self.Connections + 1] = Sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			Content.Size = UDim2_new(1, -Sidebar.AbsoluteSize.X, 1, -44)
			Content.Position = UDim2_new(0, Sidebar.AbsoluteSize.X, 0, 44)
		end)

		local NotificationContainer = Instance_new("Frame")
		NotificationContainer.Name = "Notifications"
		NotificationContainer.Size = UDim2_new(0, 300, 1, -40)
		NotificationContainer.Position = UDim2_new(1, -320, 0, 20)
		NotificationContainer.BackgroundTransparency = 1
		NotificationContainer.ZIndex = 100
		NotificationContainer.Parent = ScreenGui
		Self.NotificationContainer = NotificationContainer

		local NotifyConstraint = Instance_new("UISizeConstraint")
		NotifyConstraint.MinSize = Vector2_new(240, 0)
		NotifyConstraint.MaxSize = Vector2_new(340, math.huge)
		NotifyConstraint.Parent = NotificationContainer

		local NotifyLayout = Instance_new("UIListLayout")
		NotifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
		NotifyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		NotifyLayout.Padding = UDim_new(0, 8)
		NotifyLayout.Parent = NotificationContainer

		local DragConnections = MakeDraggable(TitleBar, MainWindow)
		for _, Connection in DragConnections do
			Self.Connections[#Self.Connections + 1] = Connection
		end

		local function CreateResizeHandle(Size, Position, Anchor, Axis)
			local Handle = Instance_new("TextButton")
			Handle.Size = Size
			Handle.Position = Position
			Handle.AnchorPoint = Anchor
			Handle.BackgroundTransparency = 1
			Handle.Text = ""
			Handle.AutoButtonColor = false
			Handle.ZIndex = 50
			Handle.Parent = MainWindow

			local Resizing = false
			local ResizeStart
			local ResizeStartSize

			Handle.InputBegan:Connect(function(Input)
				if IsPrimaryInput(Input) then
					Resizing = true
					ResizeStart = GetInputPosition(Input)
					ResizeStartSize = MainWindow.AbsoluteSize

					local ChangedConnection
					ChangedConnection = Input.Changed:Connect(function()
						if Input.UserInputState == Enum.UserInputState.End then
							Resizing = false
							if ChangedConnection then
								ChangedConnection:Disconnect()
							end
						end
					end)
				end
			end)

			Self.Connections[#Self.Connections + 1] = UserInputService.InputChanged:Connect(function(Input)
				if not Resizing then
					return
				end

				if Input.UserInputType ~= Enum.UserInputType.MouseMovement
					and Input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end

				local Delta = GetInputPosition(Input) - ResizeStart
				local Width = ResizeStartSize.X
				local Height = ResizeStartSize.Y

				if Axis == "Right" or Axis == "Corner" then
					Width = ResizeStartSize.X + Delta.X
				end

				if Axis == "Bottom" or Axis == "Corner" then
					Height = ResizeStartSize.Y + Delta.Y
				end

				local ViewportSize = Camera.ViewportSize
				Width = math_clamp(Width, 500, ViewportSize.X)
				Height = math_clamp(Height, 320, ViewportSize.Y)

				MainWindow.Size = UDim2_fromOffset(Width, Height)
			end)

			return Handle
		end

		CreateResizeHandle(UDim2_fromOffset(8, 120), UDim2_new(1, -4, 0.5, 0), Vector2_new(0.5, 0.5), "Right")
		CreateResizeHandle(UDim2_new(1, -120, 0, 8), UDim2_new(0.5, 0, 1, -4), Vector2_new(0.5, 0.5), "Bottom")
		CreateResizeHandle(UDim2_fromOffset(18, 18), UDim2_new(1, -4, 1, -4), Vector2_new(0.5, 0.5), "Corner")

		local ToggleButton = Instance_new("TextButton")
		ToggleButton.Name = "DepHubToggle"
		ToggleButton.Size = UDim2_fromOffset(56, 56)
		ToggleButton.Position = UDim2_new(0, 16, 1, -80)
		ToggleButton.AnchorPoint = Vector2_new(0, 1)
		ToggleButton.BackgroundColor3 = Colors.Black
		ToggleButton.BorderSizePixel = 0
		ToggleButton.AutoButtonColor = false
		ToggleButton.Text = ""
		ToggleButton.Visible = true
		ToggleButton.ZIndex = 200
		ToggleButton.Parent = ScreenGui
		Self.ToggleButton = ToggleButton

		ApplyCorner(ToggleButton, 100)
		local ToggleButtonStroke = ApplyStroke(ToggleButton, Colors.Border, 1, 0.15)

		CreateLogo(ToggleButton, Self.LogoId, UDim2_fromOffset(28, 28), UDim2_new(0.5, 0, 0.5, 0), Vector2_new(0.5, 0.5))

		ToggleButton.MouseEnter:Connect(function()
			Tween(ToggleButton, 0.16, EasingQuint, DirectionOut, {
				BackgroundColor3 = Colors.Active
			})
		end)

		ToggleButton.MouseLeave:Connect(function()
			Tween(ToggleButton, 0.16, EasingQuint, DirectionOut, {
				BackgroundColor3 = Colors.Black
			})
		end)

		local ToggleDragConnections = MakeDraggable(ToggleButton, ToggleButton)
		for _, Connection in ToggleDragConnections do
			Self.Connections[#Self.Connections + 1] = Connection
		end

		local ToggleDragDistance = 0
		local ToggleDragStartPosition = nil

		ToggleButton.InputBegan:Connect(function(Input)
			if IsPrimaryInput(Input) then
				ToggleDragStartPosition = GetInputPosition(Input)
				ToggleDragDistance = 0
			end
		end)

		Self.Connections[#Self.Connections + 1] = UserInputService.InputChanged:Connect(function(Input)
			if ToggleDragStartPosition and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
				local Current = GetInputPosition(Input)
				ToggleDragDistance = (Current - ToggleDragStartPosition).Magnitude
			end
		end)

		ToggleButton.MouseButton1Click:Connect(function()
			if ToggleDragDistance < 6 then
				Self:SetOpen(Self.IsHidden)
			end
		end)

		local OriginalSize = MainWindow.Size
		local ViewportWidth = Camera.ViewportSize.X
		local EstimatedWindowWidth = math_clamp(ViewportWidth * OriginalSize.X.Scale, 500, 1800)
		RefreshAllTexts(ComputeScaleFactor(EstimatedWindowWidth))

		MainWindow.Size = UDim2_fromOffset(0, 0)

		local OpenTween = Tween(MainWindow, 0.5, EasingQuint, DirectionOut, {
			Size = OriginalSize
		})

		OpenTween.Completed:Connect(function()
			if MainWindow.AbsoluteSize.X > 0 then
				RefreshAllTexts(ComputeScaleFactor(MainWindow.AbsoluteSize.X))
			end
		end)
	end

	BuildCoreUI()
	Watchdog.Start(Self, BuildCoreUI)

	Library.__index = Window
	_G.DepHubLib = Library

	return Self
end

return Library

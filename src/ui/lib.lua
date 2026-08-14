local Players_GetService = game.GetService
local Players = Players_GetService(game, "Players")
local TweenService = Players_GetService(game, "TweenService")
local UserInputService = Players_GetService(game, "UserInputService")
local RunService = Players_GetService(game, "RunService")

local Instance_new = Instance.new
local UDim2_new = UDim2.new
local UDim2_fromOffset = UDim2.fromOffset
local UDim2_fromScale = UDim2.fromScale
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local Color3_fromRGB = Color3.fromRGB
local ColorSequence_new = ColorSequence.new
local ColorSequenceKeypoint_new = ColorSequenceKeypoint.new
local NumberSequence_new = NumberSequence.new
local NumberSequenceKeypoint_new = NumberSequenceKeypoint.new
local TweenInfo_new = TweenInfo.new
local math_clamp = math.clamp
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local string_upper = string.upper
local table_insert = table.insert

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local DefaultLogoId = "rbxassetid://79507712997362"

local Colors = {
	Black = Color3_fromRGB(0, 0, 0),
	Background = Color3_fromRGB(5, 5, 5),
	Sidebar = Color3_fromRGB(8, 8, 8),
	Surface = Color3_fromRGB(12, 12, 12),
	Card = Color3_fromRGB(16, 16, 16),
	CardHover = Color3_fromRGB(23, 23, 23),
	Active = Color3_fromRGB(30, 30, 30),
	ActiveHover = Color3_fromRGB(38, 38, 38),
	Border = Color3_fromRGB(35, 35, 35),
	BorderLight = Color3_fromRGB(48, 48, 48),
	White = Color3_fromRGB(255, 255, 255),
	Light = Color3_fromRGB(200, 200, 200),
	Gray = Color3_fromRGB(140, 140, 140),
	DarkGray = Color3_fromRGB(90, 90, 90),
	ToggleOff = Color3_fromRGB(38, 38, 38),
	ToggleOn = Color3_fromRGB(220, 220, 220),
	ToggleKnob = Color3_fromRGB(255, 255, 255),
	Accent = Color3_fromRGB(90, 140, 255),
	Success = Color3_fromRGB(80, 200, 120),
	Warning = Color3_fromRGB(230, 180, 60),
	Error = Color3_fromRGB(230, 80, 80)
}

local EasingQuint = Enum.EasingStyle.Quint
local EasingQuad = Enum.EasingStyle.Quad
local EasingBack = Enum.EasingStyle.Back
local DirectionOut = Enum.EasingDirection.Out
local DirectionIn = Enum.EasingDirection.In

local function Tween(Instance, Duration, Style, Direction, Properties)
	local Info = TweenInfo_new(Duration, Style or EasingQuint, Direction or DirectionOut)
	local Playing = TweenService:Create(Instance, Info, Properties)
	Playing:Play()
	return Playing
end

local function ApplyCorner(Instance, Radius)
	local Corner = Instance_new("UICorner")
	Corner.CornerRadius = UDim_new(0, Radius or 8)
	Corner.Parent = Instance
	return Corner
end

local function ApplyStroke(Instance, Color, Thickness, Transparency)
	local Stroke = Instance_new("UIStroke")
	Stroke.Color = Color or Colors.Border
	Stroke.Thickness = Thickness or 1
	Stroke.Transparency = Transparency or 0.35
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Parent = Instance
	return Stroke
end

local function ApplyConstraint(Instance, MinSize, MaxSize)
	local Constraint = Instance_new("UISizeConstraint")
	Constraint.MinSize = MinSize or Vector2_new(0, 0)
	Constraint.MaxSize = MaxSize or Vector2_new(math.huge, math.huge)
	Constraint.Parent = Instance
	return Constraint
end

local ReferenceWidth = 900
local RegisteredTexts = {}
local ActiveScaleFactor = 1

local function ComputeScaleFactor(WindowWidth)
	local Factor = WindowWidth / ReferenceWidth
	return math_clamp(Factor, 0.72, 1.35)
end

local function ApplyTextScale(Entry, Factor)
	local Label = Entry.Label
	if not Label or not Label.Parent then
		return
	end

	local Scaled = math_floor((Entry.BaseSize * Factor) + 0.5)
	Scaled = math_clamp(Scaled, Entry.MinSize, Entry.MaxSize)
	Label.TextSize = Scaled
end

local function RefreshAllTexts(Factor)
	ActiveScaleFactor = Factor

	local Alive = {}
	for _, Entry in RegisteredTexts do
		if Entry.Label and Entry.Label.Parent then
			ApplyTextScale(Entry, Factor)
			Alive[#Alive + 1] = Entry
		end
	end
	RegisteredTexts = Alive
end

local function CreateText(Parent, Text, Size, Position, TextSize, TextColor, Font, XAlign)
	local Label = Instance_new("TextLabel")
	Label.Size = Size
	Label.Position = Position
	Label.BackgroundTransparency = 1
	Label.Text = Text
	Label.TextColor3 = TextColor
	Label.Font = Font or Enum.Font.Gotham
	Label.TextSize = TextSize
	Label.TextWrapped = true
	Label.TextXAlignment = XAlign or Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Parent = Parent

	local Entry = {
		Label = Label,
		BaseSize = TextSize,
		MinSize = math_max(6, math_floor(TextSize * 0.72)),
		MaxSize = math_floor(TextSize * 1.35) + 1
	}

	RegisteredTexts[#RegisteredTexts + 1] = Entry
	ApplyTextScale(Entry, ActiveScaleFactor)

	return Label
end

local function GetInputPosition(Input)
	return Input.Position
end

local function IsPrimaryInput(Input)
	return Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.Touch
end

local function CreateLogo(Parent, LogoId, Size, Position, Anchor, FallbackColor)
	local Logo = Instance_new("ImageLabel")
	Logo.Size = Size
	Logo.Position = Position
	Logo.AnchorPoint = Anchor or Vector2_new(0, 0)
	Logo.BackgroundTransparency = 1
	Logo.Image = LogoId or DefaultLogoId
	Logo.ScaleType = Enum.ScaleType.Fit
	Logo.Parent = Parent
	return Logo
end

local function MakeDraggable(DragHandle, TargetFrame, OnDragStart, OnDragEnd)
	local Dragging = false
	local DragStart
	local StartPosition
	local Connections = {}

	local InputBeganConnection = DragHandle.InputBegan:Connect(function(Input)
		if not IsPrimaryInput(Input) then
			return
		end

		Dragging = true
		DragStart = GetInputPosition(Input)
		StartPosition = TargetFrame.Position

		if OnDragStart then
			OnDragStart()
		end

		local ChangedConnection
		ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Dragging = false
				if OnDragEnd then
					OnDragEnd()
				end
				if ChangedConnection then
					ChangedConnection:Disconnect()
				end
			end
		end)
	end)

	local InputChangedConnection = UserInputService.InputChanged:Connect(function(Input)
		if not Dragging then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseMovement
			and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local CurrentPosition = GetInputPosition(Input)
		local Delta = CurrentPosition - DragStart

		TargetFrame.Position = UDim2_new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + Delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y
		)
	end)

	table_insert(Connections, InputBeganConnection)
	table_insert(Connections, InputChangedConnection)

	return Connections
end

local Library = {}
Library.__index = Library

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

function Library.new(HubName, Subtitle, LogoId)
	local Self = setmetatable({}, Window)

	Self.Connections = {}
	Self.Tabs = {}
	Self.TabButtons = {}
	Self.CurrentTab = nil
	Self.Switching = false
	Self.Maximized = false
	Self.Minimized = false
	Self.IsHidden = false
	Self.DashboardCreated = false
	Self.NotifyCount = 0
	Self.LogoId = LogoId or DefaultLogoId

	local ExistingGui = PlayerGui:FindFirstChild("DepHubLibraryGui")
	if ExistingGui then
		ExistingGui:Destroy()
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
	MainWindow.Size = UDim2_new(0.47, 0, 0.62, 0)
	MainWindow.Position = UDim2_new(0.5, 0, 0.5, 0)
	MainWindow.AnchorPoint = Vector2_new(0.5, 0.5)
	MainWindow.BackgroundColor3 = Colors.Background
	MainWindow.BorderSizePixel = 0
	MainWindow.ClipsDescendants = true
	MainWindow.Parent = ScreenGui
	Self.Window = MainWindow

	ApplyConstraint(MainWindow, Vector2_new(340, 260), Vector2_new(1400, 900))
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
		string_upper(HubName or "HUB"),
		UDim2_new(0, 160, 1, 0),
		UDim2_new(0, 48, 0, 0),
		12,
		Colors.White,
		Enum.Font.GothamBold
	)

	local SubtitleLabel = CreateText(
		TitleBar,
		string_upper(Subtitle or "GAME SYSTEM"),
		UDim2_new(0, 160, 1, 0),
		UDim2_new(0, 118, 0, 0),
		8,
		Colors.DarkGray,
		Enum.Font.GothamMedium
	)

	local WindowControls = Instance_new("Frame")
	WindowControls.Size = UDim2_new(0, 120, 1, 0)
	WindowControls.Position = UDim2_new(1, -120, 0, 0)
	WindowControls.BackgroundTransparency = 1
	WindowControls.Parent = TitleBar

	local ControlLayout = Instance_new("UIListLayout")
	ControlLayout.FillDirection = Enum.FillDirection.Horizontal
	ControlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ControlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ControlLayout.Padding = UDim_new(0, 2)
	ControlLayout.Parent = WindowControls

	local function CreateWindowButton(Name, Text)
		local Button = Instance_new("TextButton")
		Button.Name = Name
		Button.Size = UDim2_fromOffset(40, 34)
		Button.BackgroundTransparency = 1
		Button.BackgroundColor3 = Colors.Card
		Button.BorderSizePixel = 0
		Button.Text = Text
		Button.TextColor3 = Colors.Gray
		Button.Font = Enum.Font.Gotham
		Button.TextSize = 14
		Button.AutoButtonColor = false
		Button.Parent = WindowControls

		ApplyCorner(Button, 6)

		Button.MouseEnter:Connect(function()
			Tween(Button, 0.16, EasingQuint, DirectionOut, {
				BackgroundTransparency = 0,
				TextColor3 = Colors.White
			})
		end)

		Button.MouseLeave:Connect(function()
			Tween(Button, 0.16, EasingQuint, DirectionOut, {
				BackgroundTransparency = 1,
				TextColor3 = Colors.Gray
			})
		end)

		Button.MouseButton1Down:Connect(function()
			Tween(Button, 0.08, EasingQuad, DirectionOut, {
				BackgroundColor3 = Colors.ActiveHover
			})
		end)

		Button.MouseButton1Up:Connect(function()
			Tween(Button, 0.12, EasingQuad, DirectionOut, {
				BackgroundColor3 = Colors.Card
			})
		end)

		return Button
	end

	local MinimizeButton = CreateWindowButton("Minimize", "—")
	local MaximizeButton = CreateWindowButton("Maximize", "□")
	local CloseButton = CreateWindowButton("Close", "×")

	local Sidebar = Instance_new("Frame")
	Sidebar.Name = "Sidebar"
	Sidebar.Size = UDim2_new(0.24, 0, 1, -44)
	Sidebar.Position = UDim2_new(0, 0, 0, 44)
	Sidebar.BackgroundColor3 = Colors.Sidebar
	Sidebar.BorderSizePixel = 0
	Sidebar.Parent = MainWindow
	Self.Sidebar = Sidebar

	local SidebarSizeConstraint = Instance_new("UISizeConstraint")
	SidebarSizeConstraint.MinSize = Vector2_new(150, 0)
	SidebarSizeConstraint.MaxSize = Vector2_new(240, math.huge)
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
		string_upper(HubName or "HUB"),
		UDim2_new(1, -30, 0, 22),
		UDim2_new(0, 15, 0, 70),
		14,
		Colors.White,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Center
	)

	local BrandSubtitle = CreateText(
		Sidebar,
		string_upper(Subtitle or "GAME SYSTEM"),
		UDim2_new(1, -30, 0, 16),
		UDim2_new(0, 15, 0, 91),
		8,
		Colors.DarkGray,
		Enum.Font.GothamMedium,
		Enum.TextXAlignment.Center
	)

	local NavigationTitle = CreateText(
		Sidebar,
		"NAVIGATION",
		UDim2_new(1, -28, 0, 18),
		UDim2_new(0, 14, 0, 124),
		8,
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
		10,
		Colors.Gray,
		Enum.Font.GothamMedium
	)

	local Content = Instance_new("Frame")
	Content.Name = "Content"
	Content.Size = UDim2_new(0.76, 0, 1, -44)
	Content.Position = UDim2_new(0.24, 0, 0, 44)
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

	local SavedSize = MainWindow.Size
	local SavedPosition = MainWindow.Position

	MaximizeButton.MouseButton1Click:Connect(function()
		if Self.Minimized then
			return
		end

		if not Self.Maximized then
			SavedSize = MainWindow.Size
			SavedPosition = MainWindow.Position
			Self.Maximized = true

			Tween(MainWindow, 0.28, EasingQuint, DirectionOut, {
				Size = UDim2_new(0.92, 0, 0.88, 0),
				Position = UDim2_new(0.5, 0, 0.5, 0)
			})

			MaximizeButton.Text = "❐"
		else
			Self.Maximized = false

			Tween(MainWindow, 0.28, EasingQuint, DirectionOut, {
				Size = SavedSize,
				Position = SavedPosition
			})

			MaximizeButton.Text = "□"
		end
	end)

	MinimizeButton.MouseButton1Click:Connect(function()
		if not Self.Minimized then
			SavedSize = MainWindow.Size
			Self.Minimized = true

			Tween(MainWindow, 0.25, EasingQuint, DirectionOut, {
				Size = UDim2_fromOffset(360, 44)
			})

			task.delay(0.1, function()
				if Self.Minimized then
					Sidebar.Visible = false
					Content.Visible = false
				end
			end)
		else
			Self.Minimized = false

			Sidebar.Visible = true
			Content.Visible = true

			Tween(MainWindow, 0.25, EasingQuint, DirectionOut, {
				Size = SavedSize
			})
		end
	end)

	CloseButton.MouseButton1Click:Connect(function()
		Self:SetOpen(false)
	end)

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
			if Self.Maximized or Self.Minimized then
				return
			end

			if not IsPrimaryInput(Input) then
				return
			end

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
			Width = math_clamp(Width, 340, ViewportSize.X)
			Height = math_clamp(Height, 260, ViewportSize.Y)

			MainWindow.Size = UDim2_fromOffset(Width, Height)
		end)

		return Handle
	end

	CreateResizeHandle(UDim2_fromOffset(8, 120), UDim2_new(1, -4, 0.5, 0), Vector2_new(0.5, 0.5), "Right")
	CreateResizeHandle(UDim2_new(1, -120, 0, 8), UDim2_new(0.5, 0, 1, -4), Vector2_new(0.5, 0.5), "Bottom")
	CreateResizeHandle(UDim2_fromOffset(18, 18), UDim2_new(1, -4, 1, -4), Vector2_new(0.5, 0.5), "Corner")

	local ToggleButton = Instance_new("TextButton")
	ToggleButton.Name = "DepHubToggle"
	ToggleButton.Size = UDim2_fromOffset(52, 52)
	ToggleButton.Position = UDim2_new(0, 24, 0, 24)
	ToggleButton.AnchorPoint = Vector2_new(0, 0)
	ToggleButton.BackgroundColor3 = Colors.Black
	ToggleButton.BorderSizePixel = 0
	ToggleButton.AutoButtonColor = false
	ToggleButton.Text = ""
	ToggleButton.Visible = false
	ToggleButton.ZIndex = 200
	ToggleButton.Parent = ScreenGui
	Self.ToggleButton = ToggleButton

	ApplyCorner(ToggleButton, 100)
	local ToggleButtonStroke = ApplyStroke(ToggleButton, Colors.Border, 1, 0.15)

	CreateLogo(ToggleButton, Self.LogoId, UDim2_fromOffset(26, 26), UDim2_new(0.5, 0, 0.5, 0), Vector2_new(0.5, 0.5))

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
			Self:SetOpen(true)
		end
	end)

	local OriginalSize = MainWindow.Size
	MainWindow.Size = UDim2_fromOffset(0, 0)

	local ViewportWidth = Camera.ViewportSize.X
	local EstimatedWindowWidth = math_clamp(ViewportWidth * OriginalSize.X.Scale, 340, 1400)
	RefreshAllTexts(ComputeScaleFactor(EstimatedWindowWidth))

	local OpenTween = Tween(MainWindow, 0.5, EasingQuint, DirectionOut, {
		Size = OriginalSize
	})

	OpenTween.Completed:Connect(function()
		if MainWindow.AbsoluteSize.X > 0 then
			RefreshAllTexts(ComputeScaleFactor(MainWindow.AbsoluteSize.X))
		end
	end)

	return Self
end

function Window:SetOpen(ShouldOpen)
	local Self = self

	if ShouldOpen then
		if not Self.Window or Self.IsHidden == false then
			return
		end

		Self.IsHidden = false
		Self.Window.Visible = true

		Tween(Self.ToggleButton, 0.18, EasingQuint, DirectionIn, {
			Size = UDim2_fromOffset(0, 0)
		}).Completed:Connect(function()
			Self.ToggleButton.Visible = false
		end)

		local ReopenSize = Self.Window.Size
		Self.Window.Size = UDim2_fromOffset(0, 0)

		Tween(Self.Window, 0.32, EasingQuint, DirectionOut, {
			Size = ReopenSize
		})
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

		Self.ToggleButton.Visible = true
		Self.ToggleButton.Size = UDim2_fromOffset(0, 0)

		Tween(Self.ToggleButton, 0.24, EasingBack, DirectionOut, {
			Size = UDim2_fromOffset(52, 52)
		})
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
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Toast,
		Text or "",
		UDim2_new(1, -32, 0, 32),
		UDim2_new(0, 20, 0, 30),
		9,
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

	local NewTab = setmetatable({}, Tab)

	NewTab.Name = TabName
	NewTab.WindowRef = Self
	NewTab.Elements = {}

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
		22,
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
		10,
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
		9,
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

	if Order == 1 then
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
		9,
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
			9,
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
			12,
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
					10,
					Colors.Gray,
					Enum.Font.Gotham
				)
				LineLabel.LayoutOrder = LineIndex
			end
		end
	end
end

function Tab:CreateCard(TitleText, Description, Height)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local CardHeight = Height or 76

	local Card = Instance_new("Frame")
	Card.Size = UDim2_new(1, 0, 0, CardHeight)
	Card.BackgroundColor3 = Colors.Card
	Card.BorderSizePixel = 0
	Card.LayoutOrder = Order
	Card.Parent = Self.Page

	ApplyCorner(Card, 9)
	ApplyStroke(Card, Colors.Border, 1, 0.35)

	local Accent = Instance_new("Frame")
	Accent.Size = UDim2_fromOffset(2, 22)
	Accent.Position = UDim2_new(0, 0, 0.5, 0)
	Accent.AnchorPoint = Vector2_new(0, 0.5)
	Accent.BackgroundColor3 = Colors.White
	Accent.BackgroundTransparency = 0.9
	Accent.BorderSizePixel = 0
	Accent.Parent = Card
	ApplyCorner(Accent, 100)

	CreateText(
		Card,
		TitleText,
		UDim2_new(1, -28, 0, 22),
		UDim2_new(0, 14, 0, 10),
		12,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Card,
		Description,
		UDim2_new(1, -28, 0, math_max(18, CardHeight - 47)),
		UDim2_new(0, 14, 0, 37),
		10,
		Colors.Gray,
		Enum.Font.Gotham
	)

	Card.MouseEnter:Connect(function()
		Tween(Card, 0.18, EasingQuint, DirectionOut, {
			BackgroundColor3 = Colors.CardHover
		})

		Tween(Accent, 0.18, EasingQuint, DirectionOut, {
			BackgroundTransparency = 0.35
		})
	end)

	Card.MouseLeave:Connect(function()
		Tween(Card, 0.18, EasingQuint, DirectionOut, {
			BackgroundColor3 = Colors.Card
		})

		Tween(Accent, 0.18, EasingQuint, DirectionOut, {
			BackgroundTransparency = 0.9
		})
	end)

	Self.Elements[#Self.Elements + 1] = Card

	return Card
end

function Tab:CreateDivider(Text)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, 26)
	Frame.BackgroundTransparency = 1
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	local Line = Instance_new("Frame")
	Line.Size = UDim2_new(1, 0, 0, 1)
	Line.Position = UDim2_new(0, 0, 1, -1)
	Line.BackgroundColor3 = Colors.Border
	Line.BorderSizePixel = 0
	Line.Parent = Frame

	if Text and Text ~= "" then
		CreateText(
			Frame,
			string_upper(Text),
			UDim2_new(1, 0, 0, 16),
			UDim2_new(0, 0, 0, 0),
			8,
			Colors.DarkGray,
			Enum.Font.GothamBold
		)
	end

	Self.Elements[#Self.Elements + 1] = Frame

	return Frame
end

function Tab:CreateLabel(Text)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Label = CreateText(
		Self.Page,
		Text,
		UDim2_new(1, 0, 0, 18),
		UDim2_new(0, 0, 0, 0),
		10,
		Colors.Gray,
		Enum.Font.Gotham
	)
	Label.LayoutOrder = Order

	Self.Elements[#Self.Elements + 1] = Label

	return Label
end

function Tab:CreateStatGrid()
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Grid = Instance_new("Frame")
	Grid.Size = UDim2_new(1, 0, 0, 166)
	Grid.BackgroundTransparency = 1
	Grid.LayoutOrder = Order
	Grid.Parent = Self.Page

	local GridLayout = Instance_new("UIGridLayout")
	GridLayout.CellSize = UDim2_new(0.5, -5, 0, 78)
	GridLayout.CellPadding = UDim2_new(0, 10, 0, 10)
	GridLayout.Parent = Grid

	Self.Elements[#Self.Elements + 1] = Grid

	local GridObject = {}
	GridObject.Frame = Grid
	GridObject.NextOrder = 1

	function GridObject:CreateStat(TitleText, ValueText)
		local StatOrder = self.NextOrder
		self.NextOrder = self.NextOrder + 1

		local Card = Instance_new("Frame")
		Card.BackgroundColor3 = Colors.Card
		Card.BorderSizePixel = 0
		Card.LayoutOrder = StatOrder
		Card.Parent = Grid

		ApplyCorner(Card, 9)
		ApplyStroke(Card, Colors.Border, 1, 0.35)

		local TitleLabel = CreateText(
			Card,
			TitleText,
			UDim2_new(1, -20, 0, 17),
			UDim2_new(0, 10, 0, 8),
			8,
			Colors.DarkGray,
			Enum.Font.GothamBold
		)

		local ValueLabel = CreateText(
			Card,
			ValueText,
			UDim2_new(1, -20, 0, 28),
			UDim2_new(0, 10, 0, 31),
			15,
			Colors.White,
			Enum.Font.GothamBold
		)

		Card.MouseEnter:Connect(function()
			Tween(Card, 0.16, EasingQuint, DirectionOut, {
				BackgroundColor3 = Colors.CardHover
			})
		end)

		Card.MouseLeave:Connect(function()
			Tween(Card, 0.16, EasingQuint, DirectionOut, {
				BackgroundColor3 = Colors.Card
			})
		end)

		local StatObject = {}
		StatObject.Card = Card

		function StatObject:SetValue(NewValue)
			ValueLabel.Text = NewValue
		end

		function StatObject:SetTitle(NewTitle)
			TitleLabel.Text = NewTitle
		end

		return StatObject
	end

	return GridObject
end

function Tab:CreateToggle(TitleText, Description, Default, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, 68)
	Frame.BackgroundColor3 = Colors.Card
	Frame.BorderSizePixel = 0
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	ApplyCorner(Frame, 9)
	ApplyStroke(Frame, Colors.Border, 1, 0.35)

	local ToggleButton = Instance_new("TextButton")
	ToggleButton.BackgroundTransparency = 1
	ToggleButton.Text = ""
	ToggleButton.Size = UDim2_new(1, 0, 1, 0)
	ToggleButton.AutoButtonColor = false
	ToggleButton.ZIndex = 2
	ToggleButton.Parent = Frame

	local TextArea = Instance_new("Frame")
	TextArea.Size = UDim2_new(1, -80, 1, 0)
	TextArea.BackgroundTransparency = 1
	TextArea.Parent = Frame

	CreateText(
		TextArea,
		TitleText,
		UDim2_new(1, -10, 0, 21),
		UDim2_new(0, 13, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		TextArea,
		Description,
		UDim2_new(1, -10, 0, 20),
		UDim2_new(0, 13, 0, 32),
		9,
		Colors.Gray,
		Enum.Font.Gotham
	)

	local ToggleTrack = Instance_new("Frame")
	ToggleTrack.Name = "Toggle"
	ToggleTrack.Size = UDim2_fromOffset(48, 26)
	ToggleTrack.Position = UDim2_new(1, -61, 0.5, 0)
	ToggleTrack.AnchorPoint = Vector2_new(0, 0.5)
	ToggleTrack.BackgroundColor3 = Default and Colors.ToggleOn or Colors.ToggleOff
	ToggleTrack.BorderSizePixel = 0
	ToggleTrack.Parent = Frame

	ApplyCorner(ToggleTrack, 100)

	local ToggleStroke = ApplyStroke(ToggleTrack, Default and Colors.Light or Colors.BorderLight, 1, 0.2)

	local KnobShadow = Instance_new("Frame")
	KnobShadow.Size = UDim2_fromOffset(20, 20)
	KnobShadow.Position = Default and UDim2_new(1, -23, 0.5, 0) or UDim2_new(0, 3, 0.5, 0)
	KnobShadow.AnchorPoint = Vector2_new(0, 0.5)
	KnobShadow.BackgroundColor3 = Colors.Black
	KnobShadow.BackgroundTransparency = 0.45
	KnobShadow.BorderSizePixel = 0
	KnobShadow.ZIndex = 2
	KnobShadow.Parent = ToggleTrack
	ApplyCorner(KnobShadow, 100)

	local Knob = Instance_new("Frame")
	Knob.Size = UDim2_fromOffset(18, 18)
	Knob.Position = Default and UDim2_new(1, -22, 0.5, 0) or UDim2_new(0, 4, 0.5, 0)
	Knob.AnchorPoint = Vector2_new(0, 0.5)
	Knob.BackgroundColor3 = Colors.ToggleKnob
	Knob.BorderSizePixel = 0
	Knob.ZIndex = 3
	Knob.Parent = ToggleTrack
	ApplyCorner(Knob, 100)

	local Enabled = Default
	local Hovering = false

	local ToggleObject = {}

	local function UpdateToggle(Animate)
		local Duration = Animate and 0.22 or 0

		Tween(ToggleTrack, Duration, EasingQuint, DirectionOut, {
			BackgroundColor3 = Enabled and Colors.ToggleOn or Colors.ToggleOff
		})

		Tween(Knob, Duration, EasingBack, DirectionOut, {
			Position = Enabled and UDim2_new(1, -22, 0.5, 0) or UDim2_new(0, 4, 0.5, 0)
		})

		Tween(KnobShadow, Duration, EasingBack, DirectionOut, {
			Position = Enabled and UDim2_new(1, -23, 0.5, 0) or UDim2_new(0, 3, 0.5, 0)
		})

		Tween(ToggleStroke, Duration, EasingQuad, DirectionOut, {
			Color = Enabled and Colors.Light or Colors.BorderLight
		})
	end

	ToggleButton.MouseEnter:Connect(function()
		Hovering = true

		Tween(ToggleTrack, 0.16, EasingQuint, DirectionOut, {
			Size = UDim2_fromOffset(51, 28)
		})
	end)

	ToggleButton.MouseLeave:Connect(function()
		Hovering = false

		Tween(ToggleTrack, 0.16, EasingQuint, DirectionOut, {
			Size = UDim2_fromOffset(48, 26)
		})
	end)

	ToggleButton.MouseButton1Down:Connect(function()
		Tween(ToggleTrack, 0.08, EasingQuad, DirectionOut, {
			Size = UDim2_fromOffset(45, 24)
		})
	end)

	ToggleButton.MouseButton1Up:Connect(function()
		Tween(ToggleTrack, 0.12, EasingBack, DirectionOut, {
			Size = Hovering and UDim2_fromOffset(51, 28) or UDim2_fromOffset(48, 26)
		})
	end)

	ToggleButton.MouseButton1Click:Connect(function()
		Enabled = not Enabled
		UpdateToggle(true)

		if Callback then
			task.spawn(Callback, Enabled)
		end
	end)

	function ToggleObject:SetValue(NewValue)
		Enabled = NewValue
		UpdateToggle(true)
	end

	function ToggleObject:GetValue()
		return Enabled
	end

	ToggleObject.Frame = Frame

	Self.Elements[#Self.Elements + 1] = Frame

	return ToggleObject
end

function Tab:CreateButton(Text, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local ButtonInstance = Instance_new("TextButton")
	ButtonInstance.Size = UDim2_new(1, 0, 0, 42)
	ButtonInstance.BackgroundColor3 = Colors.Card
	ButtonInstance.BorderSizePixel = 0
	ButtonInstance.Text = ""
	ButtonInstance.AutoButtonColor = false
	ButtonInstance.LayoutOrder = Order
	ButtonInstance.Parent = Self.Page

	ApplyCorner(ButtonInstance, 8)
	ApplyStroke(ButtonInstance, Colors.Border, 1, 0.25)

	local Label = CreateText(
		ButtonInstance,
		Text,
		UDim2_new(1, -40, 1, 0),
		UDim2_new(0, 16, 0, 0),
		9,
		Colors.Gray,
		Enum.Font.GothamBold
	)

	local Arrow = CreateText(
		ButtonInstance,
		"→",
		UDim2_fromOffset(20, 20),
		UDim2_new(1, -30, 0.5, 0),
		14,
		Colors.DarkGray,
		Enum.Font.Gotham
	)
	Arrow.AnchorPoint = Vector2_new(0, 0.5)

	ButtonInstance.MouseEnter:Connect(function()
		Tween(ButtonInstance, 0.17, EasingQuint, DirectionOut, {
			BackgroundColor3 = Colors.CardHover
		})

		Tween(Label, 0.17, EasingQuint, DirectionOut, {
			TextColor3 = Colors.White
		})

		Tween(Arrow, 0.2, EasingBack, DirectionOut, {
			TextColor3 = Colors.White,
			Position = UDim2_new(1, -25, 0.5, 0)
		})
	end)

	ButtonInstance.MouseLeave:Connect(function()
		Tween(ButtonInstance, 0.17, EasingQuint, DirectionOut, {
			BackgroundColor3 = Colors.Card
		})

		Tween(Label, 0.17, EasingQuint, DirectionOut, {
			TextColor3 = Colors.Gray
		})

		Tween(Arrow, 0.2, EasingQuint, DirectionOut, {
			TextColor3 = Colors.DarkGray,
			Position = UDim2_new(1, -30, 0.5, 0)
		})
	end)

	ButtonInstance.MouseButton1Down:Connect(function()
		Tween(ButtonInstance, 0.08, EasingQuad, DirectionOut, {
			BackgroundColor3 = Colors.Active
		})
	end)

	ButtonInstance.MouseButton1Up:Connect(function()
		Tween(ButtonInstance, 0.12, EasingQuad, DirectionOut, {
			BackgroundColor3 = Colors.CardHover
		})
	end)

	ButtonInstance.MouseButton1Click:Connect(function()
		if Callback then
			task.spawn(Callback)
		end
	end)

	Self.Elements[#Self.Elements + 1] = ButtonInstance

	return ButtonInstance
end

local function BuildSliderRow(Parent, LabelText, Min, Max, Default, Callback)
	local Row = Instance_new("Frame")
	Row.Size = UDim2_new(1, 0, 0, 40)
	Row.BackgroundTransparency = 1
	Row.Parent = Parent

	CreateText(
		Row,
		LabelText,
		UDim2_new(0, 60, 0, 16),
		UDim2_new(0, 0, 0, 0),
		9,
		Colors.Gray,
		Enum.Font.GothamMedium
	)

	local ValueLabel = CreateText(
		Row,
		tostring(Default),
		UDim2_new(0, 40, 0, 16),
		UDim2_new(1, -40, 0, 0),
		9,
		Colors.White,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)

	local Track = Instance_new("Frame")
	Track.Size = UDim2_new(1, 0, 0, 5)
	Track.Position = UDim2_new(0, 0, 0, 24)
	Track.BackgroundColor3 = Colors.ToggleOff
	Track.BorderSizePixel = 0
	Track.Parent = Row
	ApplyCorner(Track, 100)

	local Fill = Instance_new("Frame")
	Fill.Size = UDim2_new(0, 0, 1, 0)
	Fill.BackgroundColor3 = Colors.White
	Fill.BorderSizePixel = 0
	Fill.Parent = Track
	ApplyCorner(Fill, 100)

	local Grabber = Instance_new("Frame")
	Grabber.Size = UDim2_fromOffset(12, 12)
	Grabber.AnchorPoint = Vector2_new(0.5, 0.5)
	Grabber.Position = UDim2_new(0, 0, 0.5, 0)
	Grabber.BackgroundColor3 = Colors.White
	Grabber.BorderSizePixel = 0
	Grabber.ZIndex = 2
	Grabber.Parent = Track
	ApplyCorner(Grabber, 100)

	local SliderInput = Instance_new("TextButton")
	SliderInput.Size = UDim2_new(1, 0, 1, 20)
	SliderInput.Position = UDim2_new(0, 0, 0.5, 0)
	SliderInput.AnchorPoint = Vector2_new(0, 0.5)
	SliderInput.BackgroundTransparency = 1
	SliderInput.Text = ""
	SliderInput.AutoButtonColor = false
	SliderInput.Parent = Track

	local CurrentValue = Default
	local Dragging = false

	local function SetFromRatio(Ratio)
		Ratio = math_clamp(Ratio, 0, 1)
		local Value = Min + (Max - Min) * Ratio
		Value = math_floor(Value + 0.5)
		CurrentValue = Value
		ValueLabel.Text = tostring(Value)

		Fill.Size = UDim2_new(Ratio, 0, 1, 0)
		Grabber.Position = UDim2_new(Ratio, 0, 0.5, 0)

		if Callback then
			task.spawn(Callback, Value)
		end
	end

	local function InitialRatio()
		return (Default - Min) / math_max(1, (Max - Min))
	end

	Fill.Size = UDim2_new(InitialRatio(), 0, 1, 0)
	Grabber.Position = UDim2_new(InitialRatio(), 0, 0.5, 0)

	SliderInput.InputBegan:Connect(function(Input)
		if not IsPrimaryInput(Input) then
			return
		end

		Dragging = true

		local RelativeX = GetInputPosition(Input).X - Track.AbsolutePosition.X
		SetFromRatio(RelativeX / Track.AbsoluteSize.X)

		local ChangedConnection
		ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Dragging = false
				if ChangedConnection then
					ChangedConnection:Disconnect()
				end
			end
		end)
	end)

	UserInputService.InputChanged:Connect(function(Input)
		if not Dragging then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseMovement
			and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local RelativeX = GetInputPosition(Input).X - Track.AbsolutePosition.X
		SetFromRatio(RelativeX / Track.AbsoluteSize.X)
	end)

	local RowObject = {}
	RowObject.Row = Row

	function RowObject:SetValue(NewValue)
		local Ratio = (NewValue - Min) / math_max(1, (Max - Min))
		SetFromRatio(Ratio)
	end

	function RowObject:GetValue()
		return CurrentValue
	end

	return RowObject
end

function Tab:CreateSlider(TitleText, Description, MinValue, MaxValue, Default, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, 74)
	Frame.BackgroundColor3 = Colors.Card
	Frame.BorderSizePixel = 0
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	ApplyCorner(Frame, 9)
	ApplyStroke(Frame, Colors.Border, 1, 0.35)

	CreateText(
		Frame,
		TitleText,
		UDim2_new(1, -100, 0, 21),
		UDim2_new(0, 14, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Frame,
		Description,
		UDim2_new(1, -100, 0, 18),
		UDim2_new(0, 14, 0, 30),
		9,
		Colors.Gray,
		Enum.Font.Gotham
	)

	local ValueLabel = CreateText(
		Frame,
		tostring(Default),
		UDim2_new(0, 60, 0, 21),
		UDim2_new(1, -74, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)

	local Track = Instance_new("Frame")
	Track.Size = UDim2_new(1, -28, 0, 6)
	Track.Position = UDim2_new(0, 14, 1, -18)
	Track.BackgroundColor3 = Colors.ToggleOff
	Track.BorderSizePixel = 0
	Track.Parent = Frame
	ApplyCorner(Track, 100)

	local Fill = Instance_new("Frame")
	Fill.Size = UDim2_new(0, 0, 1, 0)
	Fill.BackgroundColor3 = Colors.White
	Fill.BorderSizePixel = 0
	Fill.Parent = Track
	ApplyCorner(Fill, 100)

	local Grabber = Instance_new("Frame")
	Grabber.Size = UDim2_fromOffset(14, 14)
	Grabber.AnchorPoint = Vector2_new(0.5, 0.5)
	Grabber.Position = UDim2_new(0, 0, 0.5, 0)
	Grabber.BackgroundColor3 = Colors.White
	Grabber.BorderSizePixel = 0
	Grabber.ZIndex = 2
	Grabber.Parent = Track
	ApplyCorner(Grabber, 100)

	local SliderInput = Instance_new("TextButton")
	SliderInput.Size = UDim2_new(1, 0, 1, 20)
	SliderInput.Position = UDim2_new(0, 0, 0.5, 0)
	SliderInput.AnchorPoint = Vector2_new(0, 0.5)
	SliderInput.BackgroundTransparency = 1
	SliderInput.Text = ""
	SliderInput.AutoButtonColor = false
	SliderInput.Parent = Track

	local CurrentValue = Default
	local Dragging = false

	local function SetFromRatio(Ratio)
		Ratio = math_clamp(Ratio, 0, 1)
		local Value = MinValue + (MaxValue - MinValue) * Ratio
		Value = math_floor(Value + 0.5)
		CurrentValue = Value
		ValueLabel.Text = tostring(Value)

		Fill.Size = UDim2_new(Ratio, 0, 1, 0)
		Grabber.Position = UDim2_new(Ratio, 0, 0.5, 0)

		if Callback then
			task.spawn(Callback, Value)
		end
	end

	local function InitialRatio()
		return (Default - MinValue) / math_max(1, (MaxValue - MinValue))
	end

	Fill.Size = UDim2_new(InitialRatio(), 0, 1, 0)
	Grabber.Position = UDim2_new(InitialRatio(), 0, 0.5, 0)

	SliderInput.InputBegan:Connect(function(Input)
		if not IsPrimaryInput(Input) then
			return
		end

		Dragging = true

		local RelativeX = GetInputPosition(Input).X - Track.AbsolutePosition.X
		SetFromRatio(RelativeX / Track.AbsoluteSize.X)

		local ChangedConnection
		ChangedConnection = Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Dragging = false
				if ChangedConnection then
					ChangedConnection:Disconnect()
				end
			end
		end)
	end)

	UserInputService.InputChanged:Connect(function(Input)
		if not Dragging then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.MouseMovement
			and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local RelativeX = GetInputPosition(Input).X - Track.AbsolutePosition.X
		SetFromRatio(RelativeX / Track.AbsoluteSize.X)
	end)

	local SliderObject = {}
	SliderObject.Frame = Frame

	function SliderObject:SetValue(NewValue)
		local Ratio = (NewValue - MinValue) / math_max(1, (MaxValue - MinValue))
		SetFromRatio(Ratio)
	end

	function SliderObject:GetValue()
		return CurrentValue
	end

	Self.Elements[#Self.Elements + 1] = Frame

	return SliderObject
end

function Tab:CreateDropdown(TitleText, Description, Options, Default, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local CollapsedHeight = 68
	local OptionHeight = 30
	local ExpandedHeight = CollapsedHeight + (#Options * OptionHeight) + 10

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, CollapsedHeight)
	Frame.BackgroundColor3 = Colors.Card
	Frame.BorderSizePixel = 0
	Frame.ClipsDescendants = true
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	ApplyCorner(Frame, 9)
	ApplyStroke(Frame, Colors.Border, 1, 0.35)

	local HeaderButton = Instance_new("TextButton")
	HeaderButton.Size = UDim2_new(1, 0, 0, CollapsedHeight)
	HeaderButton.BackgroundTransparency = 1
	HeaderButton.Text = ""
	HeaderButton.AutoButtonColor = false
	HeaderButton.ZIndex = 2
	HeaderButton.Parent = Frame

	CreateText(
		Frame,
		TitleText,
		UDim2_new(1, -140, 0, 21),
		UDim2_new(0, 14, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Frame,
		Description,
		UDim2_new(1, -140, 0, 18),
		UDim2_new(0, 14, 0, 30),
		9,
		Colors.Gray,
		Enum.Font.Gotham
	)

	local ValueBox = Instance_new("Frame")
	ValueBox.Size = UDim2_new(0, 108, 0, 30)
	ValueBox.Position = UDim2_new(1, -122, 0, 19)
	ValueBox.BackgroundColor3 = Colors.Surface
	ValueBox.BorderSizePixel = 0
	ValueBox.Parent = Frame
	ApplyCorner(ValueBox, 7)
	ApplyStroke(ValueBox, Colors.Border, 1, 0.3)

	local ValueLabel = CreateText(
		ValueBox,
		tostring(Default or "Selecione"),
		UDim2_new(1, -30, 1, 0),
		UDim2_new(0, 10, 0, 0),
		9,
		Colors.White,
		Enum.Font.GothamBold
	)

	local Chevron = CreateText(
		ValueBox,
		"▼",
		UDim2_fromOffset(20, 30),
		UDim2_new(1, -22, 0, 0),
		8,
		Colors.DarkGray,
		Enum.Font.Gotham,
		Enum.TextXAlignment.Center
	)

	local OptionsHolder = Instance_new("Frame")
	OptionsHolder.Size = UDim2_new(1, -20, 0, #Options * OptionHeight)
	OptionsHolder.Position = UDim2_new(0, 10, 0, CollapsedHeight)
	OptionsHolder.BackgroundTransparency = 1
	OptionsHolder.Parent = Frame

	local OptionsLayout = Instance_new("UIListLayout")
	OptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	OptionsLayout.Parent = OptionsHolder

	local CurrentValue = Default
	local Expanded = false

	local DropdownObject = {}

	local function Collapse()
		Expanded = false

		Tween(Frame, 0.22, EasingQuint, DirectionOut, {
			Size = UDim2_new(1, 0, 0, CollapsedHeight)
		})

		Tween(Chevron, 0.22, EasingQuint, DirectionOut, {
			Rotation = 0
		})
	end

	local function Expand()
		Expanded = true

		Tween(Frame, 0.22, EasingQuint, DirectionOut, {
			Size = UDim2_new(1, 0, 0, ExpandedHeight)
		})

		Tween(Chevron, 0.22, EasingQuint, DirectionOut, {
			Rotation = 180
		})
	end

	for Index, OptionText in Options do
		local OptionButton = Instance_new("TextButton")
		OptionButton.Size = UDim2_new(1, 0, 0, OptionHeight)
		OptionButton.BackgroundTransparency = 1
		OptionButton.Text = ""
		OptionButton.AutoButtonColor = false
		OptionButton.LayoutOrder = Index
		OptionButton.Parent = OptionsHolder

		local OptionLabel = CreateText(
			OptionButton,
			tostring(OptionText),
			UDim2_new(1, -20, 1, 0),
			UDim2_new(0, 10, 0, 0),
			9,
			(OptionText == Default) and Colors.White or Colors.Gray,
			Enum.Font.GothamMedium
		)

		OptionButton.MouseEnter:Connect(function()
			Tween(OptionLabel, 0.14, EasingQuint, DirectionOut, {
				TextColor3 = Colors.White
			})
		end)

		OptionButton.MouseLeave:Connect(function()
			if OptionText ~= CurrentValue then
				Tween(OptionLabel, 0.14, EasingQuint, DirectionOut, {
					TextColor3 = Colors.Gray
				})
			end
		end)

		OptionButton.MouseButton1Click:Connect(function()
			CurrentValue = OptionText
			ValueLabel.Text = tostring(OptionText)
			Collapse()

			if Callback then
				task.spawn(Callback, OptionText)
			end
		end)
	end

	HeaderButton.MouseButton1Click:Connect(function()
		if Expanded then
			Collapse()
		else
			Expand()
		end
	end)

	function DropdownObject:SetValue(NewValue)
		CurrentValue = NewValue
		ValueLabel.Text = tostring(NewValue)
	end

	function DropdownObject:GetValue()
		return CurrentValue
	end

	DropdownObject.Frame = Frame

	Self.Elements[#Self.Elements + 1] = Frame

	return DropdownObject
end

function Tab:CreateInput(TitleText, Description, PlaceholderText, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, 68)
	Frame.BackgroundColor3 = Colors.Card
	Frame.BorderSizePixel = 0
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	ApplyCorner(Frame, 9)
	ApplyStroke(Frame, Colors.Border, 1, 0.35)

	CreateText(
		Frame,
		TitleText,
		UDim2_new(1, -160, 0, 21),
		UDim2_new(0, 14, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Frame,
		Description,
		UDim2_new(1, -160, 0, 18),
		UDim2_new(0, 14, 0, 30),
		9,
		Colors.Gray,
		Enum.Font.Gotham
	)

	local InputBox = Instance_new("Frame")
	InputBox.Size = UDim2_new(0, 140, 0, 32)
	InputBox.Position = UDim2_new(1, -154, 0.5, 0)
	InputBox.AnchorPoint = Vector2_new(0, 0.5)
	InputBox.BackgroundColor3 = Colors.Surface
	InputBox.BorderSizePixel = 0
	InputBox.Parent = Frame
	ApplyCorner(InputBox, 7)
	local InputStroke = ApplyStroke(InputBox, Colors.Border, 1, 0.3)

	local TextBox = Instance_new("TextBox")
	TextBox.Size = UDim2_new(1, -18, 1, 0)
	TextBox.Position = UDim2_new(0, 9, 0, 0)
	TextBox.BackgroundTransparency = 1
	TextBox.Text = ""
	TextBox.PlaceholderText = PlaceholderText or ""
	TextBox.PlaceholderColor3 = Colors.DarkGray
	TextBox.TextColor3 = Colors.White
	TextBox.Font = Enum.Font.GothamMedium
	TextBox.TextSize = 10
	TextBox.ClearTextOnFocus = false
	TextBox.TextXAlignment = Enum.TextXAlignment.Left
	TextBox.Parent = InputBox

	TextBox.Focused:Connect(function()
		Tween(InputStroke, 0.16, EasingQuint, DirectionOut, {
			Color = Colors.Accent,
			Transparency = 0
		})
	end)

	TextBox.FocusLost:Connect(function(EnterPressed)
		Tween(InputStroke, 0.16, EasingQuint, DirectionOut, {
			Color = Colors.Border,
			Transparency = 0.3
		})

		if Callback then
			task.spawn(Callback, TextBox.Text, EnterPressed)
		end
	end)

	local InputObject = {}
	InputObject.Frame = Frame

	function InputObject:SetValue(NewValue)
		TextBox.Text = NewValue
	end

	function InputObject:GetValue()
		return TextBox.Text
	end

	Self.Elements[#Self.Elements + 1] = Frame

	return InputObject
end

function Tab:CreateKeybind(TitleText, Description, DefaultKey, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, 68)
	Frame.BackgroundColor3 = Colors.Card
	Frame.BorderSizePixel = 0
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	ApplyCorner(Frame, 9)
	ApplyStroke(Frame, Colors.Border, 1, 0.35)

	CreateText(
		Frame,
		TitleText,
		UDim2_new(1, -110, 0, 21),
		UDim2_new(0, 14, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Frame,
		Description,
		UDim2_new(1, -110, 0, 18),
		UDim2_new(0, 14, 0, 30),
		9,
		Colors.Gray,
		Enum.Font.Gotham
	)

	local KeyButton = Instance_new("TextButton")
	KeyButton.Size = UDim2_new(0, 90, 0, 32)
	KeyButton.Position = UDim2_new(1, -104, 0.5, 0)
	KeyButton.AnchorPoint = Vector2_new(0, 0.5)
	KeyButton.BackgroundColor3 = Colors.Surface
	KeyButton.BorderSizePixel = 0
	KeyButton.AutoButtonColor = false
	KeyButton.Text = DefaultKey and DefaultKey.Name or "NONE"
	KeyButton.TextColor3 = Colors.White
	KeyButton.Font = Enum.Font.GothamBold
	KeyButton.TextSize = 9
	KeyButton.Parent = Frame
	ApplyCorner(KeyButton, 7)
	local KeyStroke = ApplyStroke(KeyButton, Colors.Border, 1, 0.3)

	local CurrentKey = DefaultKey
	local Listening = false

	local KeybindObject = {}

	KeyButton.MouseButton1Click:Connect(function()
		Listening = true
		KeyButton.Text = "..."

		Tween(KeyStroke, 0.16, EasingQuint, DirectionOut, {
			Color = Colors.Accent,
			Transparency = 0
		})
	end)

	Self.Elements[#Self.Elements + 1] = Frame

	Self.WindowRef.Connections[#Self.WindowRef.Connections + 1] = UserInputService.InputBegan:Connect(function(Input)
		if not Listening then
			return
		end

		if Input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end

		Listening = false

		Tween(KeyStroke, 0.16, EasingQuint, DirectionOut, {
			Color = Colors.Border,
			Transparency = 0.3
		})

		if Input.KeyCode == Enum.KeyCode.Escape then
			KeyButton.Text = CurrentKey and CurrentKey.Name or "NONE"
			return
		end

		CurrentKey = Input.KeyCode
		KeyButton.Text = CurrentKey.Name

		if Callback then
			task.spawn(Callback, CurrentKey)
		end
	end)

	function KeybindObject:SetValue(NewKey)
		CurrentKey = NewKey
		KeyButton.Text = NewKey and NewKey.Name or "NONE"
	end

	function KeybindObject:GetValue()
		return CurrentKey
	end

	KeybindObject.Frame = Frame

	return KeybindObject
end

function Tab:CreateColorPicker(TitleText, Description, DefaultColor, Callback)
	local Self = self
	local Order = Self.NextOrder
	Self.NextOrder = Self.NextOrder + 1

	local CollapsedHeight = 68
	local ExpandedHeight = 210

	local Frame = Instance_new("Frame")
	Frame.Size = UDim2_new(1, 0, 0, CollapsedHeight)
	Frame.BackgroundColor3 = Colors.Card
	Frame.BorderSizePixel = 0
	Frame.ClipsDescendants = true
	Frame.LayoutOrder = Order
	Frame.Parent = Self.Page

	ApplyCorner(Frame, 9)
	ApplyStroke(Frame, Colors.Border, 1, 0.35)

	local HeaderButton = Instance_new("TextButton")
	HeaderButton.Size = UDim2_new(1, 0, 0, CollapsedHeight)
	HeaderButton.BackgroundTransparency = 1
	HeaderButton.Text = ""
	HeaderButton.AutoButtonColor = false
	HeaderButton.ZIndex = 2
	HeaderButton.Parent = Frame

	CreateText(
		Frame,
		TitleText,
		UDim2_new(1, -90, 0, 21),
		UDim2_new(0, 14, 0, 9),
		11,
		Colors.White,
		Enum.Font.GothamBold
	)

	CreateText(
		Frame,
		Description,
		UDim2_new(1, -90, 0, 18),
		UDim2_new(0, 14, 0, 30),
		9,
		Colors.Gray,
		Enum.Font.Gotham
	)

	local StartColor = DefaultColor or Colors.White

	local Swatch = Instance_new("Frame")
	Swatch.Size = UDim2_fromOffset(30, 30)
	Swatch.Position = UDim2_new(1, -44, 0, 19)
	Swatch.BackgroundColor3 = StartColor
	Swatch.BorderSizePixel = 0
	Swatch.Parent = Frame
	ApplyCorner(Swatch, 7)
	ApplyStroke(Swatch, Colors.Border, 1, 0.2)

	local SlidersHolder = Instance_new("Frame")
	SlidersHolder.Size = UDim2_new(1, -28, 0, 130)
	SlidersHolder.Position = UDim2_new(0, 14, 0, CollapsedHeight + 4)
	SlidersHolder.BackgroundTransparency = 1
	SlidersHolder.Parent = Frame

	local SlidersLayout = Instance_new("UIListLayout")
	SlidersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	SlidersLayout.Padding = UDim_new(0, 6)
	SlidersLayout.Parent = SlidersHolder

	local Expanded = false

	local function UpdateSwatch(R, G, B)
		Swatch.BackgroundColor3 = Color3_fromRGB(R, G, B)
	end

	local CurrentColor = StartColor

	local RedSlider = BuildSliderRow(SlidersHolder, "R", 0, 255, math_floor(StartColor.R * 255), function(Value)
		CurrentColor = Color3_fromRGB(Value, math_floor(CurrentColor.G * 255), math_floor(CurrentColor.B * 255))
		UpdateSwatch(Value, math_floor(CurrentColor.G * 255), math_floor(CurrentColor.B * 255))
		if Callback then
			task.spawn(Callback, CurrentColor)
		end
	end)

	local GreenSlider = BuildSliderRow(SlidersHolder, "G", 0, 255, math_floor(StartColor.G * 255), function(Value)
		CurrentColor = Color3_fromRGB(math_floor(CurrentColor.R * 255), Value, math_floor(CurrentColor.B * 255))
		UpdateSwatch(math_floor(CurrentColor.R * 255), Value, math_floor(CurrentColor.B * 255))
		if Callback then
			task.spawn(Callback, CurrentColor)
		end
	end)

	local BlueSlider = BuildSliderRow(SlidersHolder, "B", 0, 255, math_floor(StartColor.B * 255), function(Value)
		CurrentColor = Color3_fromRGB(math_floor(CurrentColor.R * 255), math_floor(CurrentColor.G * 255), Value)
		UpdateSwatch(math_floor(CurrentColor.R * 255), math_floor(CurrentColor.G * 255), Value)
		if Callback then
			task.spawn(Callback, CurrentColor)
		end
	end)

	HeaderButton.MouseButton1Click:Connect(function()
		Expanded = not Expanded

		Tween(Frame, 0.24, EasingQuint, DirectionOut, {
			Size = UDim2_new(1, 0, 0, Expanded and ExpandedHeight or CollapsedHeight)
		})
	end)

	local ColorPickerObject = {}
	ColorPickerObject.Frame = Frame

	function ColorPickerObject:SetValue(NewColor)
		CurrentColor = NewColor
		UpdateSwatch(math_floor(NewColor.R * 255), math_floor(NewColor.G * 255), math_floor(NewColor.B * 255))
		RedSlider:SetValue(math_floor(NewColor.R * 255))
		GreenSlider:SetValue(math_floor(NewColor.G * 255))
		BlueSlider:SetValue(math_floor(NewColor.B * 255))
	end

	function ColorPickerObject:GetValue()
		return CurrentColor
	end

	Self.Elements[#Self.Elements + 1] = Frame

	return ColorPickerObject
end

function Window:Destroy()
	local Self = self

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
			end
		end)
	elseif Self.ScreenGui then
		Self.ScreenGui:Destroy()
	end
end

Library.new = Window.new
Library.__index = Window

_G.DepHubLib = Library
return Library

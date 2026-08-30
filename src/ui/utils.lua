local Utils = {}

local Players_GetService = game.GetService
local Players = Players_GetService(game, "Players")
local TweenService = Players_GetService(game, "TweenService")
local UserInputService = Players_GetService(game, "UserInputService")
local RunService = Players_GetService(game, "RunService")

local Instance_new = Instance.new
local UDim2_new = UDim2.new
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local Color3_fromRGB = Color3.fromRGB
local TweenInfo_new = TweenInfo.new
local table_insert = table.insert

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local DefaultLogoId = "rbxassetid://79507712997362"

local Colors = {
	Black = Color3_fromRGB(0, 0, 0),
	Background = Color3_fromRGB(15, 14, 18),
	Sidebar = Color3_fromRGB(20, 18, 23),
	Surface = Color3_fromRGB(25, 23, 29),
	Card = Color3_fromRGB(29, 27, 33),
	CardHover = Color3_fromRGB(36, 32, 40),
	Active = Color3_fromRGB(50, 25, 31),
	ActiveHover = Color3_fromRGB(67, 29, 37),
	Border = Color3_fromRGB(53, 47, 58),
	BorderLight = Color3_fromRGB(72, 62, 76),
	White = Color3_fromRGB(248, 245, 247),
	Light = Color3_fromRGB(222, 215, 220),
	Gray = Color3_fromRGB(161, 151, 158),
	DarkGray = Color3_fromRGB(103, 94, 101),
	ToggleOff = Color3_fromRGB(57, 51, 60),
	ToggleOn = Color3_fromRGB(210, 43, 67),
	ToggleKnob = Color3_fromRGB(255, 255, 255),
	Accent = Color3_fromRGB(210, 43, 67),
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

Utils.Players = Players
Utils.TweenService = TweenService
Utils.UserInputService = UserInputService
Utils.RunService = RunService
Utils.LocalPlayer = LocalPlayer
Utils.PlayerGui = PlayerGui
Utils.Camera = Camera
Utils.DefaultLogoId = DefaultLogoId
Utils.Colors = Colors
Utils.EasingQuint = EasingQuint
Utils.EasingQuad = EasingQuad
Utils.EasingBack = EasingBack
Utils.DirectionOut = DirectionOut
Utils.DirectionIn = DirectionIn
Utils.Tween = Tween
Utils.ApplyCorner = ApplyCorner
Utils.ApplyStroke = ApplyStroke
Utils.ApplyConstraint = ApplyConstraint
Utils.GetInputPosition = GetInputPosition
Utils.IsPrimaryInput = IsPrimaryInput
Utils.CreateLogo = CreateLogo
Utils.MakeDraggable = MakeDraggable

return Utils

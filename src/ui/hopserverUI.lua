local Players_GetService = game.GetService
local Players = Players_GetService(game, "Players")
local TweenService = Players_GetService(game, "TweenService")
local StarterGui = Players_GetService(game, "StarterGui")

local Instance_new = Instance.new
local UDim2_new = UDim2.new
local UDim2_fromOffset = UDim2.fromOffset
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local Color3_fromRGB = Color3.fromRGB
local TweenInfo_new = TweenInfo.new
local math_clamp = math.clamp
local math_max = math.max

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BackgroundImageId = "rbxassetid://123302057053749"
local LoadingIconId = "rbxassetid://79507712997362"

local Colors = {
	Black = Color3_fromRGB(0, 0, 0),
	Background = Color3_fromRGB(5, 5, 5),
	Card = Color3_fromRGB(16, 16, 16),
	CardHover = Color3_fromRGB(23, 23, 23),
	Border = Color3_fromRGB(35, 35, 35),
	White = Color3_fromRGB(255, 255, 255),
	Gray = Color3_fromRGB(140, 140, 140),
	DarkGray = Color3_fromRGB(90, 90, 90),
	Accent = Color3_fromRGB(90, 140, 255),
	Error = Color3_fromRGB(230, 80, 80)
}

local EasingQuint = Enum.EasingStyle.Quint
local EasingQuad = Enum.EasingStyle.Quad
local EasingSine = Enum.EasingStyle.Sine
local DirectionOut = Enum.EasingDirection.Out
local DirectionIn = Enum.EasingDirection.In
local DirectionInOut = Enum.EasingDirection.InOut

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

local ReferenceWidth = 900

local function ComputeScaleFactor(Width)
	return math_clamp(Width / ReferenceWidth, 0.75, 1.4)
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
	Label.TextXAlignment = XAlign or Enum.TextXAlignment.Center
	Label.TextYAlignment = Enum.TextYAlignment.Center
	Label.Parent = Parent
	Label:SetAttribute("BaseTextSize", TextSize)
	return Label
end

local CoreGuiTypes = {
	Enum.CoreGuiType.All
}

local function SetNativeUIEnabled(Enabled)
	for _, GuiType in CoreGuiTypes do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(GuiType, Enabled)
		end)
	end
end

local ServerHopOverlay = {}
ServerHopOverlay.__index = ServerHopOverlay

function ServerHopOverlay.new(Options)
	Options = Options or {}

	local Self = setmetatable({}, ServerHopOverlay)

	Self.Cancelled = false
	Self.Destroyed = false
	Self.Connections = {}
	Self.OnCancel = Options.OnCancel

	local ExistingGui = PlayerGui:FindFirstChild("DepHubServerHopOverlay")
	if ExistingGui then
		ExistingGui:Destroy()
	end

	local ScreenGui = Instance_new("ScreenGui")
	ScreenGui.Name = "DepHubServerHopOverlay"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.DisplayOrder = 10000
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui
	Self.ScreenGui = ScreenGui

	local Backdrop = Instance_new("Frame")
	Backdrop.Name = "Backdrop"
	Backdrop.Size = UDim2_new(1, 0, 1, 0)
	Backdrop.Position = UDim2_new(0, 0, 0, 0)
	Backdrop.BackgroundColor3 = Colors.Black
	Backdrop.BackgroundTransparency = 1
	Backdrop.BorderSizePixel = 0
	Backdrop.ClipsDescendants = true
	Backdrop.ZIndex = 1
	Backdrop.Parent = ScreenGui
	Self.Backdrop = Backdrop

	local BackgroundImage = Instance_new("ImageLabel")
	BackgroundImage.Name = "BackgroundImage"
	BackgroundImage.Size = UDim2_new(1, 0, 1, 0)
	BackgroundImage.Position = UDim2_new(0.5, 0, 0.5, 0)
	BackgroundImage.AnchorPoint = Vector2_new(0.5, 0.5)
	BackgroundImage.BackgroundTransparency = 1
	BackgroundImage.Image = BackgroundImageId
	BackgroundImage.ScaleType = Enum.ScaleType.Crop
	BackgroundImage.ImageTransparency = 1
	BackgroundImage.ZIndex = 1
	BackgroundImage.Parent = Backdrop
	Self.BackgroundImage = BackgroundImage

	local Tint = Instance_new("Frame")
	Tint.Name = "Tint"
	Tint.Size = UDim2_new(1, 0, 1, 0)
	Tint.BackgroundColor3 = Colors.Black
	Tint.BackgroundTransparency = 1
	Tint.BorderSizePixel = 0
	Tint.ZIndex = 2
	Tint.Parent = Backdrop
	Self.Tint = Tint

	local BlockInput = Instance_new("TextButton")
	BlockInput.Name = "InputBlocker"
	BlockInput.Size = UDim2_new(1, 0, 1, 0)
	BlockInput.BackgroundTransparency = 1
	BlockInput.Text = ""
	BlockInput.AutoButtonColor = false
	BlockInput.Modal = true
	BlockInput.ZIndex = 3
	BlockInput.Parent = Backdrop

	local ContentHolder = Instance_new("Frame")
	ContentHolder.Name = "Content"
	ContentHolder.Size = UDim2_fromOffset(420, 260)
	ContentHolder.Position = UDim2_new(0.5, 0, 0.5, 0)
	ContentHolder.AnchorPoint = Vector2_new(0.5, 0.5)
	ContentHolder.BackgroundTransparency = 1
	ContentHolder.ZIndex = 4
	ContentHolder.Parent = Backdrop
	Self.ContentHolder = ContentHolder

	local SizeConstraint = Instance_new("UISizeConstraint")
	SizeConstraint.MinSize = Vector2_new(280, 220)
	SizeConstraint.MaxSize = Vector2_new(520, 320)
	SizeConstraint.Parent = ContentHolder

	local LoadingIcon = Instance_new("ImageLabel")
	LoadingIcon.Name = "LoadingIcon"
	LoadingIcon.Size = UDim2_fromOffset(64, 64)
	LoadingIcon.Position = UDim2_new(0.5, 0, 0, 6)
	LoadingIcon.AnchorPoint = Vector2_new(0.5, 0)
	LoadingIcon.BackgroundTransparency = 1
	LoadingIcon.Image = LoadingIconId
	LoadingIcon.ScaleType = Enum.ScaleType.Fit
	LoadingIcon.ImageTransparency = 1
	LoadingIcon.ZIndex = 4
	LoadingIcon.Parent = ContentHolder
	LoadingIcon:SetAttribute("BaseSize", 64)
	Self.LoadingIcon = LoadingIcon

	local TitleLabel = CreateText(
		ContentHolder,
		Options.Title or "Trocando de Servidor",
		UDim2_new(1, 0, 0, 30),
		UDim2_new(0.5, 0, 0, 86),
		20,
		Colors.White,
		Enum.Font.GothamBold
	)
	TitleLabel.AnchorPoint = Vector2_new(0.5, 0)
	TitleLabel.ZIndex = 4

	local TextLabel = CreateText(
		ContentHolder,
		Options.Text or "Aguarde enquanto localizamos um novo servidor para você.",
		UDim2_new(1, -20, 0, 44),
		UDim2_new(0.5, 0, 0, 124),
		12,
		Colors.Gray,
		Enum.Font.Gotham
	)
	TextLabel.AnchorPoint = Vector2_new(0.5, 0)
	TextLabel.ZIndex = 4
	Self.TextLabel = TextLabel
	Self.TitleLabel = TitleLabel

	local CancelButton = Instance_new("TextButton")
	CancelButton.Name = "CancelButton"
	CancelButton.Size = UDim2_fromOffset(160, 40)
	CancelButton.Position = UDim2_new(0.5, 0, 0, 194)
	CancelButton.AnchorPoint = Vector2_new(0.5, 0)
	CancelButton.BackgroundColor3 = Colors.Card
	CancelButton.BorderSizePixel = 0
	CancelButton.AutoButtonColor = false
	CancelButton.Text = ""
	CancelButton.ZIndex = 4
	CancelButton.Parent = ContentHolder

	ApplyCorner(CancelButton, 9)
	local CancelStroke = ApplyStroke(CancelButton, Colors.Border, 1, 0.3)

	local CancelLabel = CreateText(
		CancelButton,
		"CANCELAR",
		UDim2_new(1, 0, 1, 0),
		UDim2_new(0, 0, 0, 0),
		11,
		Colors.Gray,
		Enum.Font.GothamBold
	)
	CancelLabel.ZIndex = 4
	Self.CancelButton = CancelButton
	Self.CancelLabel = CancelLabel

	CancelButton.MouseEnter:Connect(function()
		Tween(CancelButton, 0.16, EasingQuint, DirectionOut, {
			BackgroundColor3 = Colors.CardHover
		})
		Tween(CancelStroke, 0.16, EasingQuint, DirectionOut, {
			Color = Colors.Error,
			Transparency = 0.1
		})
		Tween(CancelLabel, 0.16, EasingQuint, DirectionOut, {
			TextColor3 = Colors.White
		})
	end)

	CancelButton.MouseLeave:Connect(function()
		Tween(CancelButton, 0.16, EasingQuint, DirectionOut, {
			BackgroundColor3 = Colors.Card
		})
		Tween(CancelStroke, 0.16, EasingQuint, DirectionOut, {
			Color = Colors.Border,
			Transparency = 0.3
		})
		Tween(CancelLabel, 0.16, EasingQuint, DirectionOut, {
			TextColor3 = Colors.Gray
		})
	end)

	CancelButton.MouseButton1Click:Connect(function()
		Self:Cancel()
	end)

	local function RefreshScale()
		local ViewportWidth = Backdrop.AbsoluteSize.X
		if ViewportWidth <= 0 then
			return
		end

		local Factor = ComputeScaleFactor(ViewportWidth)

		TitleLabel.TextSize = math_max(14, TitleLabel:GetAttribute("BaseTextSize") * Factor)
		TextLabel.TextSize = math_max(9, TextLabel:GetAttribute("BaseTextSize") * Factor)
		CancelLabel.TextSize = math_max(8, CancelLabel:GetAttribute("BaseTextSize") * Factor)

		local IconSize = math_max(40, LoadingIcon:GetAttribute("BaseSize") * Factor)
		LoadingIcon.Size = UDim2_fromOffset(IconSize, IconSize)
	end

	Self.Connections[#Self.Connections + 1] = Backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(RefreshScale)
	RefreshScale()

	local BobTween

	local function StartBobbing()
		BobTween = Tween(LoadingIcon, 1.1, EasingSine, DirectionInOut, {
			Position = UDim2_new(0.5, 0, 0, 22)
		})
	end

	StartBobbing()

	local BobbingActive = true

	task.spawn(function()
		while BobbingActive do
			if BobTween then
				BobTween.Completed:Wait()
			end

			if not BobbingActive then
				break
			end

			local GoingUp = LoadingIcon.Position.Y.Offset > 15

			BobTween = Tween(LoadingIcon, 1.1, EasingSine, DirectionInOut, {
				Position = GoingUp and UDim2_new(0.5, 0, 0, 6) or UDim2_new(0.5, 0, 0, 22)
			})
		end
	end)

	Self.StopAnimation = function()
		BobbingActive = false
		if BobTween then
			BobTween:Cancel()
		end
	end

	SetNativeUIEnabled(false)

	Tween(Backdrop, 0.32, EasingQuint, DirectionOut, {
		BackgroundTransparency = 0
	})

	Tween(BackgroundImage, 0.32, EasingQuint, DirectionOut, {
		ImageTransparency = 0
	})

	Tween(Tint, 0.32, EasingQuint, DirectionOut, {
		BackgroundTransparency = 0.45
	})

	Tween(LoadingIcon, 0.32, EasingQuint, DirectionOut, {
		ImageTransparency = 0
	})

	ContentHolder.Position = UDim2_new(0.5, 0, 0.56, 0)
	Tween(ContentHolder, 0.36, EasingQuint, DirectionOut, {
		Position = UDim2_new(0.5, 0, 0.5, 0)
	})

	return Self
end

function ServerHopOverlay:UpdateText(NewText)
	if self.Destroyed then
		return
	end

	if self.TextLabel then
		self.TextLabel.Text = NewText
	end
end

function ServerHopOverlay:UpdateTitle(NewTitle)
	if self.Destroyed then
		return
	end

	if self.TitleLabel then
		self.TitleLabel.Text = NewTitle
	end
end

function ServerHopOverlay:Cancel()
	local Self = self

	if Self.Destroyed or Self.Cancelled then
		return
	end

	Self.Cancelled = true

	if Self.OnCancel then
		task.spawn(Self.OnCancel)
	end

	Self:Destroy()
end

function ServerHopOverlay:Destroy()
	local Self = self

	if Self.Destroyed then
		return
	end

	Self.Destroyed = true

	if Self.StopAnimation then
		Self.StopAnimation()
	end

	for _, Connection in Self.Connections do
		if Connection and Connection.Disconnect then
			Connection:Disconnect()
		end
	end

	Self.Connections = {}

	SetNativeUIEnabled(true)

	if Self.Backdrop then
		Tween(Self.Backdrop, 0.24, EasingQuint, DirectionIn, {
			BackgroundTransparency = 1
		})
	end

	if Self.BackgroundImage then
		Tween(Self.BackgroundImage, 0.24, EasingQuint, DirectionIn, {
			ImageTransparency = 1
		})
	end

	if Self.Tint then
		Tween(Self.Tint, 0.24, EasingQuint, DirectionIn, {
			BackgroundTransparency = 1
		})
	end

	if Self.LoadingIcon then
		Tween(Self.LoadingIcon, 0.2, EasingQuint, DirectionIn, {
			ImageTransparency = 1
		})
	end

	if Self.ContentHolder then
		Tween(Self.ContentHolder, 0.24, EasingQuint, DirectionIn, {
			Position = UDim2_new(0.5, 0, 0.44, 0)
		})
	end

	task.delay(0.26, function()
		if Self.ScreenGui then
			Self.ScreenGui:Destroy()
		end
	end)
end

return ServerHopOverlay

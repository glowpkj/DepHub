local Components = {}

local Utils = require(script.Parent.utils)
local Responsive = require(script.Parent.responsive)

local Colors = Utils.Colors
local Tween = Utils.Tween
local ApplyCorner = Utils.ApplyCorner
local ApplyStroke = Utils.ApplyStroke
local GetInputPosition = Utils.GetInputPosition
local IsPrimaryInput = Utils.IsPrimaryInput
local UserInputService = Utils.UserInputService
local EasingQuint = Utils.EasingQuint
local EasingQuad = Utils.EasingQuad
local EasingBack = Utils.EasingBack
local DirectionOut = Utils.DirectionOut
local DirectionIn = Utils.DirectionIn
local CreateText = Responsive.CreateText

local Instance_new = Instance.new
local UDim2_new = UDim2.new
local UDim2_fromOffset = UDim2.fromOffset
local UDim_new = UDim.new
local Vector2_new = Vector2.new
local Color3_fromRGB = Color3.fromRGB
local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max
local string_upper = string.upper

function Components.Register(Tab)
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
			14,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			Card,
			Description,
			UDim2_new(1, -28, 0, math_max(18, CardHeight - 47)),
			UDim2_new(0, 14, 0, 37),
			12,
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
				10,
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
			12,
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
				10,
				Colors.DarkGray,
				Enum.Font.GothamBold
			)

			local ValueLabel = CreateText(
				Card,
				ValueText,
				UDim2_new(1, -20, 0, 28),
				UDim2_new(0, 10, 0, 31),
				17,
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
			13,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			TextArea,
			Description,
			UDim2_new(1, -10, 0, 20),
			UDim2_new(0, 13, 0, 32),
			11,
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
			11,
			Colors.Gray,
			Enum.Font.GothamBold
		)

		local Arrow = CreateText(
			ButtonInstance,
			"→",
			UDim2_fromOffset(20, 20),
			UDim2_new(1, -30, 0.5, 0),
			16,
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
			11,
			Colors.Gray,
			Enum.Font.GothamMedium
		)

		local ValueLabel = CreateText(
			Row,
			tostring(Default),
			UDim2_new(0, 40, 0, 16),
			UDim2_new(1, -40, 0, 0),
			11,
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
			13,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			Frame,
			Description,
			UDim2_new(1, -100, 0, 18),
			UDim2_new(0, 14, 0, 30),
			11,
			Colors.Gray,
			Enum.Font.Gotham
		)

		local ValueLabel = CreateText(
			Frame,
			tostring(Default),
			UDim2_new(0, 60, 0, 21),
			UDim2_new(1, -74, 0, 9),
			13,
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
			13,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			Frame,
			Description,
			UDim2_new(1, -140, 0, 18),
			UDim2_new(0, 14, 0, 30),
			11,
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
			11,
			Colors.White,
			Enum.Font.GothamBold
		)

		local Chevron = CreateText(
			ValueBox,
			"▼",
			UDim2_fromOffset(20, 30),
			UDim2_new(1, -22, 0, 0),
			10,
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
				11,
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
			13,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			Frame,
			Description,
			UDim2_new(1, -160, 0, 18),
			UDim2_new(0, 14, 0, 30),
			11,
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
		TextBox.TextSize = 12
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
			13,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			Frame,
			Description,
			UDim2_new(1, -110, 0, 18),
			UDim2_new(0, 14, 0, 30),
			11,
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
		KeyButton.TextSize = 11
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
			13,
			Colors.White,
			Enum.Font.GothamBold
		)

		CreateText(
			Frame,
			Description,
			UDim2_new(1, -90, 0, 18),
			UDim2_new(0, 14, 0, 30),
			11,
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
end

return Components

local Responsive = {}

local Instance_new = Instance.new
local math_clamp = math.clamp
local math_floor = math.floor
local math_max = math.max

local ReferenceWidth = 1100
local RegisteredTexts = {}
local ActiveScaleFactor = 1

local function ComputeScaleFactor(WindowWidth)
	local Factor = WindowWidth / ReferenceWidth
	return math_clamp(Factor, 0.85, 1.5)
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
		MinSize = math_max(8, math_floor(TextSize * 0.8)),
		MaxSize = math_floor(TextSize * 1.5) + 2
	}

	RegisteredTexts[#RegisteredTexts + 1] = Entry
	ApplyTextScale(Entry, ActiveScaleFactor)

	return Label
end

Responsive.ComputeScaleFactor = ComputeScaleFactor
Responsive.RefreshAllTexts = RefreshAllTexts
Responsive.CreateText = CreateText

return Responsive

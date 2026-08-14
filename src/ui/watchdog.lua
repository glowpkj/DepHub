local Watchdog = {}

local UDim2_new = UDim2.new
local Vector2_new = Vector2.new

local function EnsureVisibility(Self)
	if Self.Destroyed then return end

	if Self.ScreenGui then
		if not Self.ScreenGui.Enabled then Self.ScreenGui.Enabled = true end
		if Self.ScreenGui.DisplayOrder ~= 999 then Self.ScreenGui.DisplayOrder = 999 end
	end

	if Self.ToggleButton then
		if not Self.ToggleButton.Visible then Self.ToggleButton.Visible = true end
		if Self.ToggleButton.Position ~= UDim2_new(0, 16, 1, -80) then Self.ToggleButton.Position = UDim2_new(0, 16, 1, -80) end
		if Self.ToggleButton.AnchorPoint ~= Vector2_new(0, 1) then Self.ToggleButton.AnchorPoint = Vector2_new(0, 1) end
	end

	if Self.Window then
		if Self.IsHidden then
			if Self.Window.Visible then Self.Window.Visible = false end
		else
			if not Self.Window.Visible then Self.Window.Visible = true end
		end
	end
end

local function RebuildCoreUI(Self, BuildCoreUI)
	if Self.Destroyed then return end

	Self.Rebuilding = true
	BuildCoreUI()

	local oldDefinitions = Self.TabDefinitions
	Self.Tabs = {}
	Self.TabButtons = {}
	Self.TabDefinitions = {}
	Self.CurrentTab = nil
	Self.CurrentTabName = nil
	Self.DashboardCreated = false
	Self.DashboardTab = nil
	Self.DashboardStats = nil
	Self.ReleasesHolder = nil
	Self.ReleasesEmptyLabel = nil

	for _, def in ipairs(oldDefinitions) do
		Self:CreateTab(def.Name, def.IconId, def.Description)
	end

	Self.Rebuilding = false

	if Self.CurrentTabName then
		Self:SelectTab(Self.CurrentTabName)
	end

	EnsureVisibility(Self)
end

local function Start(Self, BuildCoreUI)
	if Self.WatchdogRunning then return end
	Self.WatchdogRunning = true

	task.spawn(function()
		while not Self.Destroyed do
			task.wait(0.5)
			if Self.Destroyed then break end

			EnsureVisibility(Self)

			if not Self.ScreenGui or not Self.ScreenGui.Parent then
				if not Self.Destroyed then
					RebuildCoreUI(Self, BuildCoreUI)
				end
			end
		end
	end)
end

local function Stop(Self)
	Self.Destroyed = true
	Self.WatchdogRunning = false
end

Watchdog.EnsureVisibility = EnsureVisibility
Watchdog.RebuildCoreUI = RebuildCoreUI
Watchdog.Start = Start
Watchdog.Stop = Stop

return Watchdog

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local AntiAFK = {
    Enabled = false,
    Connection = nil
}

function AntiAFK.Start()
    if AntiAFK.Enabled then return end
    AntiAFK.Enabled = true

    if AntiAFK.Connection then
        pcall(function()
            AntiAFK.Connection:Disconnect()
        end)
    end

    AntiAFK.Connection = Players.LocalPlayer.Idled:Connect(function()
        if not AntiAFK.Enabled then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
end

function AntiAFK.Stop()
    AntiAFK.Enabled = false
    if AntiAFK.Connection then
        pcall(function()
            AntiAFK.Connection:Disconnect()
        end)
        AntiAFK.Connection = nil
    end
end

function AntiAFK.Toggle(state)
    if state then
        AntiAFK.Start()
    else
        AntiAFK.Stop()
    end
end

AntiAFK.Set = AntiAFK.Toggle

return AntiAFK

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/refs/heads/main/lib.lua"))()
local AutoFarm = loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/refs/heads/main/autofarm.lua"))()

local Window = Library.new("DEP HUB", "AUTOFARM SYSTEM")

local MainTab = Window:CreateTab("AUTOFARM", nil, "Controle do sistema de autofarm remoto")

local autofarmToggle = MainTab:CreateToggle(
    "AutoFarm Remoto",
    "Ativa/desativa o sistema de autofarm",
    false,
    function(state)
        if state then
            AutoFarm:Start()
            Window:Notify("AutoFarm", "Sistema ativado com sucesso!", 3, "Success")
        else
            AutoFarm:Stop()
            Window:Notify("AutoFarm", "Sistema desativado!", 3, "Info")
        end
    end
)

MainTab:CreateDivider("STATUS DO SISTEMA")

local statusLabel = MainTab:CreateLabel("Status: Aguardando ativação...")

MainTab:CreateDivider("INFORMAÇÕES")

MainTab:CreateLabel("Jogador: " .. game.Players.LocalPlayer.Name)
MainTab:CreateLabel("Place ID: " .. game.PlaceId)
MainTab:CreateLabel("Game ID: " .. game.GameId)

local function updateStatus()
    if AutoFarm.Enabled then
        statusLabel.Text = "Status: ATIVADO - Monitorando interações"
    else
        statusLabel.Text = "Status: DESATIVADO"
    end
end

local heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function()
    if autofarmToggle:GetValue() ~= AutoFarm.Enabled then
        autofarmToggle:SetValue(AutoFarm.Enabled)
    end
    updateStatus()
end)

Window.Connections[#Window.Connections + 1] = heartbeatConnection

Window:Notify("DEP HUB", "Sistema carregado com sucesso!", 4, "Success")

task.spawn(function()
    while Window and Window.Window and Window.Window.Parent do
        task.wait(1)
        if AutoFarm.Enabled then
        end
    end
end)

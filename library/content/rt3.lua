local Content = {}

function Content.mount(window, runtime)
    local main=window:CreateTab("MAIN","MAIN")
    local automation=window:CreateSection(main,"AUTOMAÇÕES DO RESTAURANTE")
    local labels={AutoFarm={"AUTO FARM GERAL","ATENDIMENTO E GERENCIAMENTO AUTOMÁTICO"},InstantCook={"COZIMENTO INSTANTÂNEO","AUTOMATIZA AS TAREFAS DE COZINHA"},AutoDrop={"AUTO DROP","COLETA OS DROPS DISPONÍVEIS"},AutoFarmFriends={"AUTO FARM FRIENDS","AUTOMATIZA TYCOONS DE AMIGOS"}}
    for _, name in ipairs({"AutoFarm","InstantCook","AutoDrop","AutoFarmFriends"}) do
        local feature=runtime.Features and runtime.Features[name]; local text=labels[name]
        if feature then
            window:CreateToggle(automation,{Title=text[1],Description=text[2],Default=feature.Enabled==true,Callback=function(value)
                local handler=feature.Toggle or feature.Set; if type(handler)=="function" then handler(value) end
            end})
        end
    end
    local status=window:CreateTab("STATUS","STATUS")
    local telemetry=window:CreateSection(status,"TELEMETRIA")
    local snapshot=runtime:GetSnapshot(); local dashboard=snapshot.Dashboard or {}
    window:CreateLabel(telemetry,{Title="SAÚDE",Text=tostring(snapshot.Health or "UNKNOWN")})
    window:CreateLabel(telemetry,{Title="PING",Text=dashboard.Ping and tostring(math.floor(dashboard.Ping+0.5)).." MS" or "--"})
    window:CreateLabel(telemetry,{Title="FPS",Text=tostring(dashboard.FPS or "--")})
    window:CreateLabel(telemetry,{Title="VERSÃO",Text=tostring(dashboard.ScriptVersion or "--")})
end

return Content

local Content = {}

function Content.mount(window, backend, common)
    local main = window:CreateTab("MAIN", "MAIN")
    local movement = window:CreateSection(main, "MOVIMENTO")
    window:CreateSlider(movement,{Title="WALKSPEED",Description="VELOCIDADE DO PERSONAGEM",Min=16,Max=250,Default=backend.Values.WalkSpeed,Callback=function(value) backend.Values.WalkSpeed=value; backend:ApplyMovement() end})
    window:CreateToggle(movement,{Title="ATIVAR WALKSPEED",Description="MANTÉM A VELOCIDADE CONFIGURADA",Default=backend.Toggles.WalkSpeed,Callback=function(value) backend:SetWalkSpeedEnabled(value) end})
    window:CreateSlider(movement,{Title="JUMP POWER",Description="FORÇA DO SALTO",Min=50,Max=250,Default=backend.Values.JumpPower,Callback=function(value) backend.Values.JumpPower=value; backend:ApplyMovement() end})
    window:CreateToggle(movement,{Title="ATIVAR JUMP",Description="MANTÉM O SALTO CONFIGURADO",Default=backend.Toggles.Jump,Callback=function(value) backend:SetJumpEnabled(value) end})
    local flight = window:CreateSection(main,"VOO E COLISÃO")
    window:CreateSlider(flight,{Title="FLY SPEED",Description="VELOCIDADE DO VOO",Min=20,Max=250,Default=backend.Values.FlySpeed,Callback=function(value) backend.Values.FlySpeed=value end})
    window:CreateToggle(flight,{Title="FLY",Description="WASD, ESPAÇO E CTRL",Default=backend.Toggles.Fly,Callback=function(value) backend:SetFly(value) end})
    window:CreateToggle(flight,{Title="NO CLIP",Description="DESATIVA A COLISÃO DO PERSONAGEM",Default=backend.Toggles.Noclip,Callback=function(value) backend:SetNoclip(value) end})
    window:CreateButton(flight,{Title="ADICIONAR CLICK TELEPORT",Callback=function() backend:CreateTeleportTool() end})

    local visual = window:CreateTab("VISUAL","VISUAL")
    local esp = window:CreateSection(visual,"PLAYER ESP")
    window:CreateToggle(esp,{Title="PLAYER ESP",Description="EXIBE INFORMAÇÕES DOS JOGADORES",Default=backend.Toggles.ESP,Callback=function(value) backend:SetESP(value) end})
    for _, item in ipairs({
        {"NOMES","ESPNames","MOSTRA O NOME"},{"VIDA","ESPHealth","MOSTRA A VIDA"},{"DISTÂNCIA","ESPDistance","MOSTRA A DISTÂNCIA"},
        {"CHAMS","Chams","DESTAQUE ATRAVÉS DE PAREDES"},{"CORES DOS TIMES","TeamColors","USA A COR DE CADA TIME"},{"TEAM CHECK","TeamCheck","IGNORA O MESMO TIME"}
    }) do window:CreateToggle(esp,{Title=item[1],Description=item[3],Default=backend.Toggles[item[2]],Callback=function(value) backend.Toggles[item[2]]=value end}) end
    window:CreateSlider(esp,{Title="ALCANCE DO ESP",Description="DISTÂNCIA MÁXIMA EM STUDS",Min=100,Max=10000,Default=backend.Values.ESPRange,Callback=function(value) backend.Values.ESPRange=value end})
    window:CreateSlider(esp,{Title="TAMANHO DO TEXTO",Description="TAMANHO DAS INFORMAÇÕES",Min=10,Max=30,Default=backend.Values.ESPTextSize,Callback=function(value) backend.Values.ESPTextSize=value end})
    window:CreateColor(esp,{Title="COR DO ESP",Description="USADA SEM CORES DOS TIMES",Default=backend.Values.ESPColor,Callback=function(value) backend.Values.ESPColor=value end})
    local environment = window:CreateSection(visual,"AMBIENTE")
    window:CreateToggle(environment,{Title="FULLBRIGHT",Description="CLAREIA O MAPA E REMOVE NEBLINA",Default=backend.Toggles.Fullbright,Callback=function(value) backend:SetFullbright(value) end})
    window:CreateToggle(environment,{Title="INFINITE ZOOM",Description="AMPLIA O LIMITE DA CÂMERA",Default=backend.Toggles.InfiniteZoom,Callback=function(value) backend:SetInfiniteZoom(value) end})

    local aim = window:CreateTab("AIM","AIM")
    local aimSection=window:CreateSection(aim,"CONTROLE DA MIRA")
    window:CreateToggle(aimSection,{Title="AIMBOT",Description="SEGURE O BOTÃO DIREITO PARA MIRAR",Default=backend.Toggles.Aimbot,Callback=function(value) backend.Toggles.Aimbot=value end})
    window:CreateSlider(aimSection,{Title="FOV",Description="RAIO DE CAPTURA EM PIXELS",Min=30,Max=600,Default=backend.Values.AimbotFOV,Callback=function(value) backend.Values.AimbotFOV=value end})
    window:CreateDropdown(aimSection,{Title="PARTE DO CORPO",Description="PONTO USADO PELA MIRA",Values={"Head","HumanoidRootPart","UpperTorso"},Default=backend.Values.AimPart,Callback=function(value) backend.Values.AimPart=value end})

    local chat=window:CreateTab("CHAT","CHAT")
    local messages=window:CreateSection(chat,"MENSAGENS")
    window:CreateInput(messages,{Title="MENSAGEM",Description="TEXTO ENVIADO AO CHAT",Default=backend.Values.ChatMessage,Placeholder="DIGITE A MENSAGEM",Callback=function(value) backend.Values.ChatMessage=value end})
    window:CreateSlider(messages,{Title="INTERVALO",Description="SEGUNDOS ENTRE MENSAGENS",Min=3,Max=60,Default=backend.Values.ChatInterval,Callback=function(value) backend.Values.ChatInterval=value end})
    window:CreateButton(messages,{Title="ENVIAR UMA VEZ",Callback=function() common.notifyResult(window,backend:SendChat(),"Mensagem enviada.") end})
    window:CreateToggle(messages,{Title="ENVIO AUTOMÁTICO",Description="REPITE NO INTERVALO CONFIGURADO",Default=backend.Toggles.ChatLoop,Callback=function(value) backend:SetChatLoop(value) end})

    local server=window:CreateTab("SERVER","SERVER")
    local connection=window:CreateSection(server,"CONEXÃO")
    window:CreateButton(connection,{Title="REJOIN",Callback=function() backend:Rejoin() end})
    window:CreateButton(connection,{Title="SERVER HOP",Callback=function() backend:ServerHop() end})
    local developer=window:CreateSection(server,"DESENVOLVEDOR")
    window:CreateButton(developer,{Title="DEX EXPLORER",Callback=function() backend:RunDex() end})
end

return Content

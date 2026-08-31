local Content = {}

local function result(window, ok, message, kind)
    window:Notify(ok and "SUCESSO" or "ERRO", message or "Operação concluída.", 5, kind or (ok and "Success" or "Error"))
end

function Content.mount(window, backend)
    local main=window:CreateTab("MAIN","MAIN")
    local movement=window:CreateSection(main,"MOVIMENTO")
    window:CreateSlider(movement,{Title="DASH LENGTH",Description="COMPRIMENTO DO DASH",Min=1,Max=100,Default=backend:GetDashLength(),Callback=function(value) backend:SetDashLength(value) end})
    for _, item in ipairs({
        {"DASH CUSTOMIZER","DashCustomizer","ATIVA O DASH CONFIGURADO"},{"FLASHSTEP NO COOLDOWN","FlashstepNoCooldown","REMOVE O COOLDOWN QUANDO SUPORTADO"},
        {"WATER WALKING","WaterWalking","PERMITE CAMINHAR SOBRE A ÁGUA"},{"UNBREAKABLE ALL","UnbreakableAll","APLICA DURABILIDADE ENQUANTO ATIVO"}
    }) do window:CreateToggle(movement,{Title=item[1],Description=item[3],Default=backend:GetToggle(item[2]),Callback=function(value) backend:SetToggle(item[2],value) end}) end
    local team=window:CreateSection(main,"EQUIPE")
    window:CreateToggle(team,{Title="AUTO JOIN TEAM",Description="ENTRA NO TIME CONFIGURADO",Default=backend:GetToggle("AutoJoinTeam"),Callback=function(value) backend:SetToggle("AutoJoinTeam",value) end})
    window:CreateDropdown(team,{Title="TIME PREFERIDO",Description="TIME USADO PELO AUTO JOIN",Values={"Pirates","Marines"},Default=backend:GetPreferredTeam(),Callback=function(value) backend:SetPreferredTeam(value) end})

    local visual=window:CreateTab("VISUAL","VISUAL")
    local esp=window:CreateSection(visual,"ESP")
    window:CreateToggle(esp,{Title="PLAYER ESP",Description="INFORMAÇÕES DOS JOGADORES",Default=backend:GetToggle("PlayerESP"),Callback=function(value) backend:SetToggle("PlayerESP",value) end})
    window:CreateToggle(esp,{Title="FRUIT ESP",Description="FRUTAS DETECTADAS NO MAPA",Default=backend:GetToggle("FruitESP"),Callback=function(value) backend:SetToggle("FruitESP",value) end})

    local vfx=backend.Features and backend.Features.FruitVFX
    if vfx then
        local skins=window:CreateSection(visual,"SKINS / CORES DAS FRUTAS")
        local fruits=vfx:GetFruits(); local selectedFruit=fruits[1]; local selectedColor; local selectedForm="Normal (Default)"
        local colorControl
        window:CreateDropdown(skins,{Title="FRUTA COMPATÍVEL",Description="FRUTAS CADASTRADAS NO CÓDIGO",Values=fruits,Default=selectedFruit,Callback=function(value)
            selectedFruit=value; local colors=vfx:GetColors(value); selectedColor=colors[1]; colorControl:SetValues(colors,selectedColor,true)
        end})
        local colors=selectedFruit and vfx:GetColors(selectedFruit) or {}; selectedColor=colors[1]
        colorControl=window:CreateDropdown(skins,{Title="COR / SKIN",Description="PALETA DA FRUTA SELECIONADA",Values=colors,Default=selectedColor,Callback=function(value) selectedColor=value end})
        window:CreateDropdown(skins,{Title="FORMA",Description="NORMAL, TRANSFORMADA OU AMBAS",Values={"Normal (Default)","Transformada (Shifted)","Ambas"},Default=selectedForm,Callback=function(value) selectedForm=value end})
        window:CreateButton(skins,{Title="APLICAR COR SELECIONADA",Callback=function() result(window,vfx:Apply(selectedFruit,selectedColor,selectedForm)) end})
        window:CreateButton(skins,{Title="RESTAURAR SKIN ANTERIOR",Callback=function() result(window,vfx:Restore(selectedFruit,"Both")) end})
        window:CreateLabel(skins,{Title="ORIGINAL",Text="RESTAURA AS CORES CAPTURADAS ANTES DA PRIMEIRA ALTERAÇÃO."})
    end
end

return Content

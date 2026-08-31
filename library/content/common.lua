local Common = {}

local function notifyResult(window, ok, message, kind)
    window:Notify(ok and "SUCESSO" or "ERRO", message or (ok and "Operação concluída." or "Operação recusada."), 4, kind or (ok and "Success" or "Error"))
end

function Common.mount(window, backend, environment)
    local page = window:CreateTab("CONFIG", "CONFIG")
    local interface = window:CreateSection(page, "INTERFACE")
    window:CreateKeybind(interface, {
        Title="ABRIR / FECHAR", Description="TECLA GLOBAL DA JANELA", Default=Enum.KeyCode.RightControl,
        Callback=function(key) window:SetToggleKey(key); window:Notify("INTERFACE","Atalho atualizado para "..key.Name..".",3,"Success") end
    })
    window:CreateButton(interface, {Title="ESCONDER INTERFACE", Callback=function() window:SetOpen(false) end})

    local configuration = window:CreateSection(page, "CONFIGURAÇÃO")
    if backend and type(backend.SaveConfig)=="function" then
        window:CreateButton(configuration, {Title="SALVAR CONFIGURAÇÃO", Callback=function()
            local ok, result = pcall(backend.SaveConfig, backend)
            notifyResult(window, ok and result ~= false, ok and (result == false and "Não foi possível salvar." or "Configuração salva.") or tostring(result))
        end})
    else
        window:CreateLabel(configuration, {Title="PERSISTÊNCIA", Text="ESTE MÓDULO NÃO POSSUI CONFIGURAÇÃO SALVA."})
    end

    local updates = window:CreateSection(page, "ATUALIZAÇÕES")
    window:CreateButton(updates, {Title="APLICAR ATUALIZAÇÃO PENDENTE", Callback=function()
        local updater = environment.__DEPHUB and environment.__DEPHUB.Updater
        if not updater or not updater.PendingUpdate then return notifyResult(window, false, "Nenhuma atualização pendente.") end
        notifyResult(window, updater:ApplyPending(), "Atualização solicitada.")
    end})
    window:CreateButton(updates, {Title="CANCELAR ATUALIZAÇÃO PENDENTE", Callback=function()
        local updater = environment.__DEPHUB and environment.__DEPHUB.Updater
        if not updater or not updater.PendingUpdate then return notifyResult(window, false, "Nenhuma atualização pendente.") end
        updater:Cancel(); notifyResult(window, true, "Atualização pendente cancelada.")
    end})
end

Common.notifyResult = notifyResult
return Common

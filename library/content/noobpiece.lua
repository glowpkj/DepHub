local Content={}

function Content.mount(window,backend)
    local page=window:CreateTab("ESP","ESP")
    local section=window:CreateSection(page,"BAUS")
    window:CreateToggle(section,{
        Title="ESP DE BAU",
        Description="MOSTRA APENAS BAUS SPAWNADOS, COM PREVIEW E DISTANCIA.",
        Default=backend:GetToggle("ChestESP"),
        Callback=function(enabled) backend:SetChestESP(enabled) end
    })

    local farm=window:CreateSection(page,"AUTO BAU")
    window:CreateToggle(farm,{
        Title="AUTO BAU",
        Description="TELEPORTA PARA BAUS SPAWNADOS E CARREGADOS NO CLIENTE.",
        Default=backend:GetToggle("AutoChest"),
        Callback=function(enabled) backend:SetAutoChest(enabled) end
    })
    window:CreateSlider(farm,{
        Title="INTERVALO",
        Description="TEMPO ENTRE TENTATIVAS DE BAU.",
        Min=0.1,
        Max=2,
        Default=backend:GetValue("AutoChestDelay"),
        Callback=function(value) backend:SetAutoChestDelay(value) end
    })

    window:OpenPage("ESP")
end

return Content

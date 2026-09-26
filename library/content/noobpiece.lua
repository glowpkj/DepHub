local Content={}

function Content.mount(window,backend)
    local espPage=window:CreateTab("ESP","ESP")
    local chestEsp=window:CreateSection(espPage,"BAUS")

    window:CreateToggle(chestEsp,{
        Title="ESP DE BAU",
        Description="MOSTRA APENAS BAUS SPAWNADOS COM NOME E DISTANCIA.",
        Default=backend:GetToggle("ChestESP"),
        Callback=function(enabled) backend:SetChestESP(enabled) end
    })

    local chestFarm=window:CreateSection(espPage,"AUTO BAU")

    window:CreateToggle(chestFarm,{
        Title="AUTO BAU",
        Description="VAI ATE BAUS SPAWNADOS USANDO MOVIMENTO TWEEN.",
        Default=backend:GetToggle("AutoChest"),
        Callback=function(enabled) backend:SetAutoChest(enabled) end
    })

    window:CreateSlider(chestFarm,{
        Title="INTERVALO",
        Description="TEMPO ENTRE TENTATIVAS DE BAU.",
        Min=0.1,
        Max=2,
        Default=backend:GetValue("AutoChestDelay"),
        Callback=function(value) backend:SetAutoChestDelay(value) end
    })

    local farmPage=window:CreateTab("FARM","FARM")
    local combat=window:CreateSection(farmPage,"COMBATE")

    window:CreateToggle(combat,{
        Title="AUTO ATTACK",
        Description="ATACA AUTOMATICAMENTE SEM PRECISAR CLICAR.",
        Default=backend:GetToggle("AutoAttack"),
        Callback=function(enabled) backend:SetAutoAttack(enabled) end
    })

    window:CreateToggle(combat,{
        Title="CHECK RANGE",
        Description="SO ATACA QUANDO EXISTE UM INIMIGO DENTRO DO RANGE DA TOOL.",
        Default=backend:GetToggle("AutoAttackRange"),
        Callback=function(enabled) backend:SetAutoAttackRange(enabled) end
    })

    window:OpenPage("ESP")
end

return Content

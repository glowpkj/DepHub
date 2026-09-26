local Content={}

function Content.mount(window,backend)
    local autoChestToggle
    local autoFarmToggle

    local espPage=window:CreateTab("ESP","ESP")
    local chestEsp=window:CreateSection(espPage,"BAUS")

    window:CreateToggle(chestEsp,{
        Title="ESP DE BAU",
        Description="MOSTRA APENAS BAUS SPAWNADOS COM NOME E DISTANCIA.",
        Default=backend:GetToggle("ChestESP"),
        Callback=function(enabled) backend:SetChestESP(enabled) end
    })

    local chestFarm=window:CreateSection(espPage,"AUTO BAU")

    autoChestToggle=window:CreateToggle(chestFarm,{
        Title="AUTO BAU",
        Description="VAI ATE BAUS SPAWNADOS USANDO MOVIMENTO TWEEN.",
        Default=backend:GetToggle("AutoChest"),
        Callback=function(enabled)
            backend:SetAutoChest(enabled)
            if enabled and autoFarmToggle then
                autoFarmToggle:SetValue(false,true)
            end
        end
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
    local autoFarm=window:CreateSection(farmPage,"AUTO FARM")

    autoFarmToggle=window:CreateToggle(autoFarm,{
        Title="AUTO FARM NOOB",
        Description="VAI ATE O NOOB E FICA NA BORDA DO RANGE DA ARMA.",
        Default=backend:GetToggle("AutoFarm"),
        Callback=function(enabled)
            backend:SetAutoFarm(enabled)
            if enabled and autoChestToggle then
                autoChestToggle:SetValue(false,true)
            end
        end
    })

    window:CreateDropdown(autoFarm,{
        Title="ARMA",
        Description="ESCOLHE ENTRE ESTILO DE LUTA E ESPADA.",
        Values={"Fists","Sword"},
        Default=backend:GetValue("WeaponCategory"),
        Callback=function(value) backend:SetWeaponCategory(value) end
    })

    local combat=window:CreateSection(farmPage,"COMBATE")

    window:CreateToggle(combat,{
        Title="AUTO ATTACK",
        Description="ATACA AUTOMATICAMENTE COM A TOOL E O REMOTE.",
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

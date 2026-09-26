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
        Title="AUTO FARM MOBS",
        Description="VAI ATE O MOB SELECIONADO E FICA ATRAS DELE NA BORDA DO RANGE.",
        Default=backend:GetToggle("AutoFarm"),
        Callback=function(enabled)
            backend:SetAutoFarm(enabled)
            if enabled and autoChestToggle then
                autoChestToggle:SetValue(false,true)
            end
        end
    })

    local enemyDropdown=window:CreateDropdown(autoFarm,{
        Title="INIMIGO",
        Description="SELECIONA O TIPO DE MOB PELO NPC ID.",
        Values=backend:GetEnemyTypes(),
        Default=backend:GetValue("SelectedEnemy"),
        Callback=function(value) backend:SetSelectedEnemy(value) end
    })

    window:CreateButton(autoFarm,{
        Title="ATUALIZAR INIMIGOS",
        Description="RELE TODOS OS MOBS E BOSSES DAS ILHAS CARREGADAS.",
        Callback=function()
            local values=backend:GetEnemyTypes()
            local selected=backend:GetValue("SelectedEnemy")

            if not table.find(values,selected) then
                selected=values[1]
                if selected then
                    backend:SetSelectedEnemy(selected)
                end
            end

            enemyDropdown:SetValues(values,selected,true)
        end
    })

    window:CreateDropdown(autoFarm,{
        Title="ARMA",
        Description="ESCOLHE ENTRE ESTILO DE LUTA E ESPADA.",
        Values={"Fists","Sword"},
        Default=backend:GetValue("WeaponCategory"),
        Callback=function(value) backend:SetWeaponCategory(value) end
    })

    local utility=window:CreateSection(farmPage,"NPCS")

    window:CreateButton(utility,{
        Title="WANDERING GACHA",
        Description="TELEPORTA ATE O NPC DE GIRAR FRUTA SE ELE ESTIVER NO MAPA.",
        Callback=function() backend:TeleportWanderingGacha() end
    })

    local team=window:CreateSection(farmPage,"TIME")

    window:CreateDropdown(team,{
        Title="TIME",
        Description="ESCOLHE O TIME USADO PELO AUTO TEAM.",
        Values=backend:GetTeams(),
        Default=backend:GetValue("SelectedTeam"),
        Callback=function(value) backend:SetSelectedTeam(value) end
    })

    window:CreateToggle(team,{
        Title="AUTO TEAM",
        Description="ENTRA AUTOMATICAMENTE NO TIME SELECIONADO.",
        Default=backend:GetToggle("AutoTeam"),
        Callback=function(enabled) backend:SetAutoTeam(enabled) end
    })

    local combat=window:CreateSection(farmPage,"COMBATE")

    window:CreateToggle(combat,{
        Title="AUTO ATTACK",
        Description="ATACA SEMPRE COM A TOOL EQUIPADA E O REMOTE.",
        Default=backend:GetToggle("AutoAttack"),
        Callback=function(enabled) backend:SetAutoAttack(enabled) end
    })


    window:OpenPage("ESP")
end

return Content

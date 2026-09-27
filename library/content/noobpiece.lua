local Content={}

function Content.mount(window,backend)
    local autoChestToggle
    local autoFarmToggle
    local islandTeleportToggle

    local espPage=window:CreateTab("ESP","ESP")
    local chestEsp=window:CreateSection(espPage,"BAUS")

    window:CreateToggle(chestEsp,{
        Title="ESP DE BAU",
        Description="MOSTRA BAUS SPAWNADOS, INCLUINDO OS DA MYSTERIOUS ISLAND.",
        Default=backend:GetToggle("ChestESP"),
        Callback=function(enabled)
            backend:SetChestESP(enabled)
        end
    })

    local islands=window:CreateSection(espPage,"ILHAS")

    window:CreateToggle(islands,{
        Title="ESP ILHAS",
        Description="MOSTRA MARCADORES DAS ILHAS MAPEADAS MESMO QUANDO O MAPA DELAS NAO ESTA CARREGADO.",
        Default=backend:GetToggle("IslandESP"),
        Callback=function(enabled)
            backend:SetIslandESP(enabled)
        end
    })

    local islandDropdown=window:CreateDropdown(islands,{
        Title="ILHA",
        Description="SELECIONA UMA ILHA COM CFRAME JA MAPEADO. A MYSTERIOUS SO APARECE ENQUANTO EXISTIR.",
        Values=backend:GetIslandNames(),
        Default=backend:GetValue("SelectedIsland"),
        Callback=function(value)
            backend:SetSelectedIsland(value)
        end
    })

    islandTeleportToggle=window:CreateToggle(islands,{
        Title="TELEPORTAR ILHA",
        Description="ATIVA O MOVIMENTO ATE A ILHA SELECIONADA. DESATIVE PARA INTERROMPER.",
        Default=backend:GetToggle("IslandTeleport"),
        Callback=function(enabled)
            if not backend:SetIslandTeleport(enabled) and enabled then
                islandTeleportToggle:SetValue(false,true)
            end
        end
    })

    backend:ConnectIslandAvailabilityChanged(function(values)
        local selected=backend:GetValue("SelectedIsland")

        if not table.find(values,selected) then
            if islandTeleportToggle then
                islandTeleportToggle:SetValue(false,true)
            end

            selected=values[1]

            if selected then
                backend:SetSelectedIsland(selected)
            end
        end

        islandDropdown:SetValues(values,selected,true)
    end)

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
        Callback=function(value)
            backend:SetAutoChestDelay(value)
        end
    })

    local farmPage=window:CreateTab("FARM","FARM")
    local autoFarm=window:CreateSection(farmPage,"AUTO FARM")

    window:CreateToggle(autoFarm,{
        Title="AUTO QUEST",
        Description="PEGA E RENOVA AUTOMATICAMENTE A MISSAO DO INIMIGO SELECIONADO QUANDO ELA ESTA MAPEADA.",
        Default=backend:GetToggle("AutoQuest"),
        Callback=function(enabled)
            backend:SetAutoQuest(enabled)
        end
    })

    autoFarmToggle=window:CreateToggle(autoFarm,{
        Title="AUTO FARM MOBS",
        Description="VAI PRIMEIRO A ILHA MAPEADA, ESPERA O NPC CARREGAR E DEPOIS FARMA ATRAS DELE.",
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
        Description="LISTA MOBS E BOSSES POR ILHA E USA O LEVEL DO NPC QUANDO ELE ESTA DISPONIVEL.",
        Values=backend:GetEnemyTypes(),
        Default=backend:GetSelectedEnemyOption(),
        Callback=function(value)
            backend:SetSelectedEnemy(value)
        end
    })

    window:CreateButton(autoFarm,{
        Title="ATUALIZAR INIMIGOS",
        Description="RELE OS ATRIBUTOS DOS NPCS CARREGADOS E ATUALIZA LEVEL, ILHA E BOSS.",
        Callback=function()
            local values=backend:GetEnemyTypes()
            local selected=backend:GetSelectedEnemyOption()

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
        Callback=function(value)
            backend:SetWeaponCategory(value)
        end
    })

    local utility=window:CreateSection(farmPage,"NPCS")

    window:CreateToggle(utility,{
        Title="ESP WANDERING GACHA",
        Description="MOSTRA O NPC DE GACHA E A DISTANCIA QUANDO ELE EXISTIR.",
        Default=backend:GetToggle("GachaESP"),
        Callback=function(enabled)
            backend:SetGachaESP(enabled)
        end
    })

    window:CreateButton(utility,{
        Title="WANDERING GACHA",
        Description="TELEPORTA ATE O NPC DE GIRAR FRUTA SE ELE ESTIVER NO MAPA.",
        Callback=function()
            backend:TeleportWanderingGacha()
        end
    })

    local team=window:CreateSection(farmPage,"TIME")

    window:CreateDropdown(team,{
        Title="TIME",
        Description="ESCOLHE O TIME USADO PELO AUTO TEAM.",
        Values=backend:GetTeams(),
        Default=backend:GetValue("SelectedTeam"),
        Callback=function(value)
            backend:SetSelectedTeam(value)
        end
    })

    window:CreateToggle(team,{
        Title="AUTO TEAM",
        Description="ENTRA AUTOMATICAMENTE NO TIME SELECIONADO.",
        Default=backend:GetToggle("AutoTeam"),
        Callback=function(enabled)
            backend:SetAutoTeam(enabled)
        end
    })

    local combat=window:CreateSection(farmPage,"COMBATE")

    window:CreateToggle(combat,{
        Title="AUTO ATTACK",
        Description="ATACA SEMPRE COM A TOOL EQUIPADA E O REMOTE.",
        Default=backend:GetToggle("AutoAttack"),
        Callback=function(enabled)
            backend:SetAutoAttack(enabled)
        end
    })

    window:OpenPage("ESP")
end

return Content

local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/tbao143/Library-ui/refs/heads/main/Redzhubui"))()

local Window = redzlib:MakeWindow({
    Title = "DepHub | Redz UI Preview",
    SubTitle = "Comparação visual da biblioteca",
    LoadText = "Carregando interface...",
    Flags = "DepHub_RedzPreview"
})

Window:AddMinimizeButton({
    Button = {
        Image = "rbxassetid://178993746",
        BackgroundTransparency = 0
    },
    Corner = {
        CornerRadius = UDim.new(35, 1)
    }
})

local Main = Window:MakeTab({
    Title = "Principal",
    Icon = "home"
})

Main:AddSection({"Componentes"})

Main:AddParagraph({
    "DepHub V2",
    "Prévia usando a biblioteca Redz original para comparar visual, espaçamento e comportamento."
})

Main:AddButton({
    Name = "Botão de teste",
    Callback = function()
        print("Redz UI: botão clicado")
    end
})

Main:AddToggle({
    Name = "Toggle de teste",
    Description = "Ative ou desative para testar o componente.",
    Default = false,
    Callback = function(value)
        print("Toggle:", value)
    end
})

Main:AddSlider({
    Name = "Slider de teste",
    Min = 0,
    Max = 100,
    Default = 35,
    Increment = 1,
    ValueName = "%",
    Callback = function(value)
        print("Slider:", value)
    end
})

Main:AddDropdown({
    Name = "Dropdown de teste",
    Options = {"Opção A", "Opção B", "Opção C"},
    Default = "Opção A",
    Callback = function(value)
        print("Dropdown:", value)
    end
})

local Second = Window:MakeTab({
    Title = "Configurações",
    Icon = "settings"
})

Second:AddSection({"Sobre a prévia"})
Second:AddParagraph({
    "Biblioteca",
    "Esta tela usa a Redz UI diretamente. Ela não substitui nem altera a DepHubV2Lib."
})

Second:AddButton({
    Name = "Imprimir informações",
    Callback = function()
        print("DepHub Redz preview carregada")
    end
})

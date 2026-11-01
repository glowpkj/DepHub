local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/glowpkj/DepHub/main/src/dephubv2lib.lua"))()

local Window = Library:CreateWindow({
    Title = "DepHub",
    Subtitle = "V2 Library Showcase",
    Width = 700,
    Height = 460
})

local Home = Window:CreateTab({Name = "Home", Icon = "⌂"})
local General = Home:CreateSection("General")

General:CreateParagraph({
    Title = "DepHub V2",
    Content = "Standalone UI library loaded directly by executor."
})

General:CreateToggle({
    Name = "Example toggle",
    Default = false,
    Callback = function(value)
        print("Toggle:", value)
    end
})

General:CreateSlider({
    Name = "Example slider",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(value)
        print("Slider:", value)
    end
})

General:CreateDropdown({
    Name = "Example dropdown",
    Options = {"Option A", "Option B", "Option C"},
    Default = "Option A",
    Callback = function(value)
        print("Dropdown:", value)
    end
})

General:CreateInput({
    Name = "Example input",
    Placeholder = "Type something...",
    Callback = function(value, enterPressed)
        print("Input:", value, enterPressed)
    end
})

General:CreateButton({
    Name = "Test notification",
    Callback = function()
        Window:Notify({
            Title = "DepHub V2",
            Content = "Library loaded successfully.",
            Duration = 3
        })
    end
})

local Other = Window:CreateTab({Name = "Other", Icon = "⚙"})
local Info = Other:CreateSection("Controls")

Info:CreateButton({
    Name = "Destroy UI",
    Callback = function()
        Window:Destroy()
    end
})

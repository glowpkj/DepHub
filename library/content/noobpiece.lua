local Content={}

function Content.mount(window,backend)
    local page=window:CreateTab("ESP","ESP")
    local section=window:CreateSection(page,"BAUS")
    window:CreateToggle(section,{
        Title="ESP DE BAU",
        Description="MOSTRA TODOS OS BAUS DO MAPA E A DISTANCIA.",
        Default=backend:GetToggle("ChestESP"),
        Callback=function(enabled) backend:SetChestESP(enabled) end
    })
    window:OpenPage("ESP")
end

return Content

local game = game
local type = type
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local sort = table.sort

local TempUI = {}

local function pretty(name)
    return tostring(name):gsub("(%l)(%u)", "%1 %2")
end

local function setterCandidates(name)
    return {"Set" .. name, "Set" .. name .. "Enabled"}
end

local function applyToggle(backend, name, value)
    if type(backend.SetToggle) == "function" then
        local ok, result = pcall(backend.SetToggle, backend, name, value)
        if ok then return result ~= false end
    end
    for _, setter in ipairs(setterCandidates(name)) do
        if type(backend[setter]) == "function" then
            local ok, result = pcall(backend[setter], backend, value)
            if ok then return result ~= false end
        end
    end
    if type(backend.Toggles) == "table" then
        backend.Toggles[name] = value
        return true
    end
    return false
end

local function readToggle(backend, name)
    if type(backend.GetToggle) == "function" then
        local ok, value = pcall(backend.GetToggle, backend, name)
        if ok then return value == true end
    end
    return type(backend.Toggles) == "table" and backend.Toggles[name] == true
end

function TempUI.Mount(env)
    if type(env) ~= "table" or type(env.__DEPHUB) ~= "table" then return nil end
    local contract = env.__DEPHUB
    local backend = contract.Backend
    local library = contract.UILibrary
    if type(backend) ~= "table" or type(library) ~= "table" or type(library.new) ~= "function" then return nil end

    local window = library.new({
        Name = "DepHub",
        GuiName = "DepHub",
        FooterLeft = "DepHub  ·  v" .. tostring(contract.Version or "?"),
        Size = UDim2.fromOffset(820, 540)
    })
    contract.UI = window

    local tab = window:CreateTab("Home")
    local resources = tab:CreateSection("Recursos")

    local function addToggle(name, initial, callback)
        resources:CreateToggle(backend.ToggleLabels and backend.ToggleLabels[name] or pretty(name), initial, function(value)
            local result = callback(value)
            if result == false then
                window:Notify("DepHub", "Nao foi possivel alterar " .. pretty(name), 3)
                return
            end
            window.Flags[name] = value
        end)
    end

    if type(backend.Features) == "table" then
        local names = {}
        for name in pairs(backend.Features) do names[#names + 1] = name end
        sort(names)
        for _, name in ipairs(names) do
            local feature = backend.Features[name]
            if type(feature) == "table" then
                addToggle(name, feature.Enabled == true, function(value)
                    local fn = feature.Toggle or feature.Set
                    if type(fn) ~= "function" then return false end
                    local ok, result = pcall(fn, feature, value)
                    return ok and result ~= false
                end)
            end
        end
    elseif type(backend.Toggles) == "table" then
        local names = {}
        for name in pairs(backend.Toggles) do names[#names + 1] = name end
        sort(names)
        for _, name in ipairs(names) do
            addToggle(name, readToggle(backend, name), function(value)
                return applyToggle(backend, name, value)
            end)
        end
    else
        resources:CreateLabel("Nenhum recurso publicado por este jogo.")
    end

    if type(backend.Modes) == "table" and type(backend.SetMode) == "function" then
        local modeSection = tab:CreateSection("Modo")
        modeSection:CreateDropdown("Modo de previsao", backend.Modes, backend.Mode or backend.Modes[1], function(value)
            local ok, result = pcall(backend.SetMode, backend, value)
            if not ok or result == false then
                window:Notify("DepHub", "Falha ao selecionar o modo", 3)
                return
            end
            window:Notify("DepHub", "Modo " .. tostring(value) .. " selecionado", 2)
        end)
        modeSection:CreateLabel("Future esta reservado e ainda nao possui recursos.")
    end

    local session = tab:CreateSection("Sessao")
    if type(backend.Rejoin) == "function" then
        session:CreateButton("Reentrar", function()
            local ok, err = pcall(backend.Rejoin, backend)
            if not ok then window:Notify("DepHub", tostring(err), 4) end
        end)
    end
    if type(backend.ServerHop) == "function" then
        session:CreateButton("Trocar servidor", function()
            local ok, err = pcall(backend.ServerHop, backend)
            if not ok then window:Notify("DepHub", tostring(err), 4) end
        end)
    end
    session:CreateLabel("Insert abre ou minimiza a interface.")

    local handle = {Destroyed = false, Library = window}
    function handle:Show()
        if self.Library and self.Library.SetVisible then self.Library.SetVisible(true) end
    end
    function handle:Hide()
        if self.Library and self.Library.SetVisible then self.Library.SetVisible(false) end
    end
    function handle:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self.Library then self.Library:Destroy() end
        if contract.UI == self.Library then contract.UI = nil end
    end
    return handle
end

return TempUI

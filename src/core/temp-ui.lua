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

local function call(target, method, ...)
    if type(target) ~= "table" or type(target[method]) ~= "function" then return false end
    local ok, result = pcall(target[method], target, ...)
    return ok and result ~= false, result
end

local function readControl(control, fallback)
    if type(control) == "table" and type(control.get) == "function" then
        local ok, value = pcall(control.get)
        if ok and value ~= nil then return value end
    end
    return fallback
end

local function applyControl(backend, key, value)
    if type(backend.SetControl) == "function" then
        local ok, result = pcall(backend.SetControl, backend, key, value)
        return ok and result ~= false
    end
    return false
end

local function seaAllowed(seaRule, currentSea)
    if type(seaRule) ~= "string" or seaRule == "" then return true end
    for sea in string.gmatch(seaRule, "[^,]+") do
        if sea == currentSea then return true end
    end
    return false
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

    local renderedTabs = {}
    local pageSea = {}
    local controlRows = {}
    local statusRows = {}
    local infoTab
    local infoSection

    local function makeTab(pageName, seaRule)
        if renderedTabs[pageName] then return renderedTabs[pageName] end
        local tab = window:CreateTab(pageName)
        local section = tab:CreateSection(pageName)
        renderedTabs[pageName] = {Tab = tab, Section = section}
        pageSea[pageName] = seaRule
        return renderedTabs[pageName]
    end

    local function createControl(entry)
        local pageName = tostring(entry.page or "Home")
        local group = makeTab(pageName, entry.sea)
        local section = group.Section
        local title = tostring(entry.title or entry.key or "Control")
        local key = tostring(entry.key or (pageName .. " / " .. title))
        local initial = readControl(entry, entry.default)
        local item
        local lastAcceptedValue = initial
        local reverting = false
        local callback = function(value)
            if reverting then
                reverting = false
                return
            end
            if not applyControl(backend, key, value) then
                window:Notify("DepHub", "Nao foi possivel alterar " .. title, 3)
                if item and type(item.Set) == "function" then
                    reverting = true
                    pcall(item.Set, item, lastAcceptedValue)
                end
                window.Flags[key] = lastAcceptedValue
                return
            end
            lastAcceptedValue = value
            window.Flags[key] = value
        end
        if entry.kind == "toggle" then
            item = section:CreateToggle(title, initial == true, callback)
        elseif entry.kind == "slider" then
            item = section:CreateSlider(title, entry.min or 0, entry.max or 100, tonumber(initial) or entry.default or entry.min or 0, callback)
        elseif entry.kind == "dropdown" then
            local options = type(entry.options) == "table" and entry.options or {}
            item = section:CreateDropdown(title, options, initial, callback)
        elseif entry.kind == "textbox" or entry.kind == "input" then
            item = section:CreateInput(title, title, tostring(initial or ""), callback)
        elseif entry.kind == "button" then
            item = section:CreateButton(title, function()
                local ok = applyControl(backend, key, true)
                if not ok then window:Notify("DepHub", "Falha ao executar " .. title, 3) end
            end)
        elseif entry.kind == "stat" then
            item = section:CreateParagraph(title .. ": " .. tostring(initial or "-"))
        else
            item = section:CreateParagraph(title .. " (tipo nao suportado: " .. tostring(entry.kind) .. ")")
        end
        if type(item) == "table" then item.FlagName = key end
        controlRows[key] = {Entry = entry, Item = item, Page = pageName}
        window.Flags[key] = initial
    end

    local controls
    if type(backend.ListControls) == "function" then
        local ok, result = pcall(backend.ListControls, backend)
        if ok and type(result) == "table" then controls = result end
    end

    if type(controls) == "table" and #controls > 0 then
        for _, entry in ipairs(controls) do
            if type(entry) == "table" then createControl(entry) end
        end
    else
        local tab = window:CreateTab("Home")
        local resources = tab:CreateSection("Recursos")
        if type(backend.Features) == "table" then
            local names = {}
            for name in pairs(backend.Features) do names[#names + 1] = name end
            sort(names)
            for _, name in ipairs(names) do
                local feature = backend.Features[name]
                if type(feature) == "table" then
                    resources:CreateToggle(name, feature.Enabled == true, function(value)
                        local fn = feature.Toggle or feature.Set
                        if type(fn) ~= "function" then return end
                        local ok, result = pcall(fn, feature, value)
                        if not ok or result == false then window:Notify("DepHub", "Falha ao alterar " .. name, 3) end
                    end)
                end
            end
        elseif type(backend.Toggles) == "table" then
            local names = {}
            for name in pairs(backend.Toggles) do names[#names + 1] = name end
            sort(names)
            for _, name in ipairs(names) do
                resources:CreateToggle(backend.ToggleLabels and backend.ToggleLabels[name] or pretty(name), backend.Toggles[name] == true, function(value)
                    local ok = call(backend, "SetToggle", name, value)
                    if not ok then window:Notify("DepHub", "Falha ao alterar " .. name, 3) end
                end)
            end
        else
            resources:CreateLabel("Nenhum recurso publicado por este jogo.")
        end
        if type(backend.Modes) == "table" and type(backend.SetMode) == "function" then
            local modeSection = tab:CreateSection("Modo")
            modeSection:CreateDropdown("Modo", backend.Modes, backend.Mode or backend.Modes[1], function(value)
                local ok, result = pcall(backend.SetMode, backend, value)
                if not ok or result == false then window:Notify("DepHub", "Falha ao selecionar o modo", 3) end
            end)
        end
        local session = tab:CreateSection("Sessao")
        if type(backend.Rejoin) == "function" then session:CreateButton("Reentrar", function() pcall(backend.Rejoin, backend) end) end
        if type(backend.ServerHop) == "function" then session:CreateButton("Trocar servidor", function() pcall(backend.ServerHop, backend) end) end
        session:CreateLabel("Ctrl esquerdo/direito abre ou minimiza a interface.")
    end

    infoTab = renderedTabs.Info and renderedTabs.Info.Tab or window:CreateTab("Info")
    infoSection = renderedTabs.Info and renderedTabs.Info.Section or infoTab:CreateSection("Status")
    local statsParagraph = infoSection:CreateParagraph("Aguardando estatisticas...")
    local notificationSection = infoTab:CreateSection("Notificacoes")
    local notificationParagraph = notificationSection:CreateParagraph("Nenhuma notificacao.")
    local logParagraph = nil
    local logsTab = renderedTabs.Logs and renderedTabs.Logs.Tab or window:CreateTab("Logs")
    local logsSection = renderedTabs.Logs and renderedTabs.Logs.Section or logsTab:CreateSection("Saida")
    logParagraph = logsSection:CreateParagraph("Aguardando logs...")

    local currentSea = "Sea1"
    local function updateSea()
        if type(backend.GetStatus) == "function" then
            local ok, status = pcall(backend.GetStatus, backend)
            if ok and type(status) == "table" then currentSea = status.Sea or currentSea end
        end
        if type(backend.SetSea) == "function" then pcall(backend.SetSea, backend, currentSea) end
        for name, group in pairs(renderedTabs) do
            local allowed = seaAllowed(pageSea[name], currentSea)
            if group.Tab.SetVisible then
                pcall(group.Tab.SetVisible, group.Tab, allowed)
            elseif group.Tab.Page then
                group.Tab.Page.Visible = allowed
                group.Tab.NavButton.Visible = allowed
                group.Tab.TabButton.Visible = allowed
            end
        end
    end
    updateSea()

    local function renderStats()
        local chunks = {}
        local stats = backend.Stats
        if type(stats) == "table" then
            for key, value in pairs(stats) do chunks[#chunks + 1] = tostring(key) .. ": " .. tostring(value) end
            sort(chunks)
        end
        if #chunks == 0 and type(backend.GetStatus) == "function" then
            local ok, status = pcall(backend.GetStatus, backend)
            if ok and type(status) == "table" then
                chunks = {
                    "Version: " .. tostring(status.Version or "?"),
                    "Sea: " .. tostring(status.Sea or "?"),
                    "Controls: " .. tostring(status.Controls or 0),
                    "Modules: " .. tostring((function() local n = 0; for _ in pairs(status.Modules or {}) do n = n + 1 end; return n end)()),
                    "Restored config: " .. tostring(status.RestoredConfig == true),
                    "Errors: " .. tostring(status.Errors and #status.Errors or 0)
                }
            end
        end
        statsParagraph:SetText(#chunks > 0 and table.concat(chunks, "\n") or "Sem estatisticas publicadas.")
    end

    local lastNotificationCount, lastLogCount = -1, -1
    local running = true
    task.spawn(function()
        while running and not window.Destroyed do
            updateSea()
            renderStats()
            local notifications = backend.Notifications
            if type(notifications) == "table" then
                if #notifications ~= lastNotificationCount then
                    if #notifications > lastNotificationCount and #notifications > 0 then
                        window:Notify("DepHub", tostring(notifications[#notifications]), 3)
                    end
                    lastNotificationCount = #notifications
                    local first = math.max(1, #notifications - 9)
                    local lines = {}
                    for i = first, #notifications do lines[#lines + 1] = tostring(notifications[i]) end
                    notificationParagraph:SetText(#lines > 0 and table.concat(lines, "\n") or "Nenhuma notificacao.")
                end
            end
            local core = backend.Core
            local logs = core and core.logs
            if type(logs) == "table" and #logs ~= lastLogCount then
                lastLogCount = #logs
                local first = math.max(1, #logs - 9)
                local lines = {}
                for i = first, #logs do
                    local entry = logs[i]
                    lines[#lines + 1] = tostring(entry.level or "LOG") .. ": " .. tostring(entry.msg or entry)
                end
                logParagraph:SetText(#lines > 0 and table.concat(lines, "\n") or "Sem logs.")
            end
            task.wait(1)
        end
    end)

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
        running = false
        if self.Library then self.Library:Destroy() end
        if contract.UI == self.Library then contract.UI = nil end
    end
    return handle
end

return TempUI

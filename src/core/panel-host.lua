-- DepHub panel host.
--
-- Bridges the presentation-only panel library (src/frontend/init.lua) to a
-- backend published on getgenv().__DEPHUB.Backend. The panel knows nothing about
-- features; the backends know nothing about UI. This file owns the map between
-- them: for each mode it declares the tabs, the controls in each tab, how to
-- read the current value, and how to apply a change.
--
-- Backends differ in shape, so binding goes through small adapters:
--   * toggle-style backends (Blox Fruits, TSB, MM2, NoobPiece, AOTR) expose
--     State:SetToggle(name, enabled) / State:GetToggle(name).
--   * the universal backend exposes one setter per feature
--     (SetFly, SetNoclip, ...), so those controls carry an explicit apply().
--
-- Loaded as a plain chunk by the bundle, so it builds its own Panel by pulling
-- the frontend factory from the loader-provided module table.

local PanelHost = {}

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function isCallable(value)
    if type(value) == "function" then return true end
    if type(value) == "table" and type(value.__call) == "function" then return true end
    return false
end

local function call(fn, ...)
    if not isCallable(fn) then return false, "not callable" end
    local ok, result = pcall(fn, ...)
    return ok, result
end

-- A control descriptor is one of:
--   {Type="toggle",   Name=..., Title=..., Help=..., Get=fn, Set=fn}
--   {Type="slider",   Name=..., Title=..., Min=, Max=, Step=, Get=fn, Set=fn}
--   {Type="dropdown", Name=..., Title=..., Options={...}, Get=fn, Set=fn}
--   {Type="action",   Name=..., Title=..., Button=..., Run=fn, Primary=bool}
--   {Type="notice",   Name=..., Title=, Text=...}
--   {Type="section",  Label=...}
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Per-mode specs. Each entry returns a list of tabs:
--   { {Name="Jogador", Glyph="◫", Controls={ ... }}, ... }
-- The functions receive the backend so Get/Set/Apply close over it.
-- ---------------------------------------------------------------------------

local function genericToggleGet(backend, name)
    return function()
        if type(backend.GetToggle) == "function" then
            local ok, value = call(backend.GetToggle, backend, name)
            if ok then return value == true end
        end
        if type(backend.Toggles) == "table" then return backend.Toggles[name] == true end
        return false
    end
end

local function genericToggleSet(backend, name)
    return function(value)
        if type(backend.SetToggle) == "function" then
            local ok = call(backend.SetToggle, backend, name, value)
            if ok then return end
        end
        if type(backend.Toggles) == "table" then backend.Toggles[name] = value == true end
    end
end

local function toggle(b, name, title, help)
    return {Type = "toggle", Name = name, Title = title, Help = help,
        Get = genericToggleGet(b, name), Set = genericToggleSet(b, name)}
end

-- Build a toggle whose value is stored on a boolean table field and applied by
-- an explicit setter (the universal backend's shape).
local function customToggle(b, name, title, help, field, setter)
    return {Type = "toggle", Name = name, Title = title, Help = help,
        Get = function()
            local store = b.Toggles
            if type(store) == "table" then return store[field] == true end
            return false
        end,
        Set = function(value)
            if type(b.Toggles) == "table" then b.Toggles[field] = value == true end
            if type(b[setter]) == "function" then call(b[setter], b, value == true) end
        end}
end

local function buildBloxFruits(b)
    return {
        {Name = "Jogador", Glyph = "◫", Controls = {
            toggle(b, "PlayerESP", "ESP de jogadores", "Realça outros jogadores pelo corpo."),
            toggle(b, "FruitESP", "ESP de frutas", "Marca frutas próximas com um realce."),
            toggle(b, "AutoFarm", "Autofarm", "Segue a quest ativa e ataca o alvo automaticamente."),
            toggle(b, "BladeHits", "Blade Hits", "Ataque por remote com cadência limitada."),
            toggle(b, "AutoJoinTeam", "Entrar em time", "Entra no time preferido ao spawnar."),
        }},
        {Name = "Movimento", Glyph = "◎", Controls = {
            toggle(b, "DashCustomizer", "Dash personalizado", "Ajusta a distância do dash."),
            toggle(b, "FlashstepNoCooldown", "Flashstep sem cooldown", "Ignora o cooldown do dash."),
            toggle(b, "WaterWalking", "Andar na água", "Permite caminhar sobre a água."),
            {Type = "slider", Name = "DashLength", Title = "Distância do dash", Min = 1, Max = 10, Step = 1,
                Get = function()
                    if type(b.Values) == "table" and type(b.Values.DashLength) == "number" then return b.Values.DashLength end
                    return 1
                end,
                Set = function(value)
                    if type(b.Values) == "table" then b.Values.DashLength = value end
                    if type(b.SetDashLength) == "function" then call(b.SetDashLength, b, value) end
                end},
        }},
        {Name = "Universo", Glyph = "☷", Controls = {
            toggle(b, "UnbreakableAll", "Unbreakable em todos", "Aplica a proteção de quebra a todos."),
            {Type = "action", Name = "ServerHop", Title = "Trocar de servidor", Button = "Trocar", Run = function()
                if type(b.ServerHop) == "function" then call(b.ServerHop, b) end
            end},
            {Type = "notice", Text = "<b>Autofarm</b><br>Ativa com Blade Hits já habilitado ou ele se arma sozinho."},
        }},
    }
end

local function buildUniversal(b)
    return {
        {Name = "Jogador", Glyph = "◫", Controls = {
            customToggle(b, "WalkSpeed", "Velocidade", "Aumenta a velocidade de caminhada.", "WalkSpeed", "SetWalkSpeedEnabled"),
            customToggle(b, "Jump", "Pulo alto", "Aumenta a força do pulo.", "Jump", "SetJumpEnabled"),
            customToggle(b, "Fly", "Voar", "Voo simples com controles de WASD.", "Fly", "SetFly"),
            customToggle(b, "Noclip", "Noclip", "Atravessa paredes.", "Noclip", "SetNoclip"),
            customToggle(b, "InfiniteJump", "Pulo infinito", "Permite pular sem tocar o chão.", "InfiniteJump", "SetInfiniteJump"),
            customToggle(b, "BunnyHop", "Bunny hop", "Pulo automático ao correr.", "BunnyHop", "SetBunnyHop"),
            customToggle(b, "AntiFling", "Anti-fling", "Impede que jogadores te arremessem.", "AntiFling", "SetAntiFling"),
            customToggle(b, "AntiVoid", "Anti-void", "Resgata você antes de cair no vazio.", "AntiVoid", "SetAntiVoid"),
        }},
        {Name = "Visual", Glyph = "◎", Controls = {
            customToggle(b, "ESP", "ESP", "Caixas em volta dos jogadores.", "ESP", "SetESP"),
            customToggle(b, "Chams", "Chams", "Realce colorido por time.", "Chams", nil),
            customToggle(b, "Fullbright", "Fullbright", "Ilumina o mapa inteiro.", "Fullbright", "SetFullbright"),
            customToggle(b, "InfiniteZoom", "Zoom infinito", "Remove o limite de zoom.", "InfiniteZoom", "SetInfiniteZoom"),
            customToggle(b, "Tracers", "Tracers", "Linhas até os jogadores.", "Tracers", "SetTracers"),
        }},
        {Name = "Combate", Glyph = "✧", Controls = {
            customToggle(b, "Aimbot", "Aimbot", "Mira suave (LERP) no alvo mais próximo.", "Aimbot", nil),
            customToggle(b, "SilentAim", "Silent aim", "Redireciona o tiro sem mover a câmera.", "SilentAim", "SetSilentAim"),
            customToggle(b, "TeamCheck", "Checar time", "Ignora aliados.", "TeamCheck", nil),
            customToggle(b, "TeamColors", "Cores por time", "Usa a cor do time no realce.", "TeamColors", nil),
        }},
        {Name = "Diversos", Glyph = "☷", Controls = {
            customToggle(b, "ChatLoop", "Chat loop", "Repete uma mensagem no chat.", "ChatLoop", "SetChatLoop"),
            {Type = "action", Name = "ServerHop", Title = "Trocar de servidor", Button = "Trocar", Run = function()
                if type(b.ServerHop) == "function" then call(b.ServerHop, b) end
            end},
            {Type = "action", Name = "Rejoin", Title = "Reentrar", Button = "Reentrar", Run = function()
                if type(b.Rejoin) == "function" then call(b.Rejoin, b) end
            end},
        }},
    }
end

-- Generic fallback for the toggle-style backends that do not need bespoke tabs:
-- list whatever State.Toggles declares.
local function buildGeneric(b)
    local known = {
        PlayerESP = {"ESP de jogadores", "Realça outros jogadores."},
        FruitESP = {"ESP de frutas", "Marca frutas próximas."},
        AutoFarm = {"Autofarm", "Automação principal do jogo."},
        BladeHits = {"Blade Hits", "Ataque por remote."},
        RoleESP = {"ESP de papéis", "Realça papéis do round (MM2)."},
        GunESP = {"ESP de armas", "Marca armas no chão."},
        CoinFarm = {"Farm de moedas", "Coleta moedas automaticamente."},
        PlayerTeleport = {"Teleporte", "Teleporta até jogadores."},
    }
    local controls = {}
    if type(b.Toggles) == "table" then
        for name in pairs(b.Toggles) do
            local meta = known[name]
            controls[#controls + 1] = toggle(b, name, meta and meta[1] or name, meta and meta[2] or nil)
        end
        table.sort(controls, function(a, c) return tostring(a.Title) < tostring(c.Title) end)
    end
    if #controls == 0 then
        controls[#controls + 1] = {Type = "notice", Text = "Nenhum recurso publicado por este backend."}
    end
    return {
        {Name = "Recursos", Glyph = "◫", Controls = controls},
    }
end

local SPECS = {
    BloxFruits = buildBloxFruits,
    Universal = buildUniversal,
}

-- ---------------------------------------------------------------------------
-- Host
-- ---------------------------------------------------------------------------

function PanelHost.Mount(env, PanelFactory)
    if type(env) ~= "table" then return nil, "no environment" end
    if type(PanelFactory) ~= "table" or type(PanelFactory.new) ~= "function" then
        return nil, "panel factory unavailable"
    end

    local contract = env.__DEPHUB
    if type(contract) ~= "table" then return nil, "__DEPHUB not published" end

    local backend = contract.Backend
    local mode = tostring(contract.Mode or "")
    if type(backend) ~= "table" then
        -- No backend (unknown game without fallback). Still show a stub panel so
        -- the user sees the interface exists, with an explanatory notice.
        local panel = PanelFactory.new({Title = "DepHub", GameName = game.Name, StartOpen = false})
        local tab = panel:CreateTab("Estado", "!")
        panel:AddNotice(tab, "Nenhum backend ativo para este jogo. Modo: " .. mode)
        env.__DEPHUB.Frontend = panel
        return panel
    end

    local GameName = game.Name
    local panel = PanelFactory.new({
        Title = "DepHub",
        GameName = (GameName ~= "" and GameName) or mode,
        StartOpen = false,
    })

    local build = SPECS[mode] or buildGeneric
    local ok, tabs = pcall(build, backend)
    if not ok or type(tabs) ~= "table" then
        tabs = buildGeneric(backend)
    end

    for _, tabSpec in ipairs(tabs) do
        local tab = panel:CreateTab(tabSpec.Name, tabSpec.Glyph)
        for _, control in ipairs(tabSpec.Controls or {}) do
            local kind = control.Type
            if kind == "toggle" then
                local value = false
                local okGet, current = call(control.Get)
                if okGet then value = current == true end
                panel:AddToggle(tab, control.Title, control.Help, value, function(next)
                    local okSet, result = call(control.Set, next)
                    if not okSet then
                        panel:Notify("Falha ao aplicar", tostring(control.Title) .. ": " .. tostring(result), true)
                        return
                    end
                end)
            elseif kind == "slider" then
                local value = control.Min or 0
                local okGet, current = call(control.Get)
                if okGet and type(current) == "number" then value = current end
                panel:AddSlider(tab, control.Title, control.Help, control.Min, control.Max, control.Step, value,
                    function(next)
                        call(control.Set, next)
                    end)
            elseif kind == "dropdown" then
                local value = nil
                local okGet, current = call(control.Get)
                if okGet then value = current end
                panel:AddDropdown(tab, control.Title, control.Help, control.Options, value, function(next)
                    call(control.Set, next)
                end)
            elseif kind == "action" then
                panel:AddAction(tab, control.Title, control.Help, control.Button, function()
                    local okRun, err = call(control.Run)
                    if not okRun then
                        panel:Notify("Ação falhou", tostring(control.Title) .. ": " .. tostring(err), true)
                    else
                        panel:Notify(tostring(control.Title), "Executado.")
                    end
                end, control.Primary)
            elseif kind == "notice" then
                panel:AddNotice(tab, control.Text, control.Title)
            elseif kind == "section" then
                panel:AddSection(tab, control.Label)
            end
        end
    end

    panel:SetStatus("Modo " .. mode .. " · v" .. tostring(contract.Version or "?"))
    contract.Frontend = panel
    return panel
end

return PanelHost

-- Diagnostics module: a collector plus a shared Debug tab. Exercised directly
-- through its public API with API doubles; no claim of in-game functionality.
do
    local ctx = sandbox()
    local Diag = ctx:Run("src/core/diagnostics.lua")

    local diag = Diag.new()
    diag:SetEnvironment({Executor = "Tester", Version = "1.2.3", PlaceId = "1"})
    diag:RegisterModule("um")
    diag:Module("um", true, "ok")
    diag:Module("dois", false, "explodiu")
    diag:Probe("Workspace.Titans", true, "3 titans")
    diag:Probe("Assets.Remotes.GET", false, "ausente")
    diag:Feature("Feature.A", function() return "rodando" end)
    diag:Feature("Feature.B", function() error("leitura falhou") end)
    diag:Note("linha livre")
    diag:Log("loader", "iniciando")

    local report = diag:Report()
    check(report:find("Executor: Tester", 1, true) ~= nil, "diagnostics report includes environment")
    check(report:find("[OK] um: ok", 1, true) ~= nil, "diagnostics report marks a healthy module")
    check(report:find("[FALHA] dois: explodiu", 1, true) ~= nil, "diagnostics report marks a failed module")
    check(report:find("[OK] Workspace.Titans: 3 titans", 1, true) ~= nil, "diagnostics report includes a passing probe")
    check(report:find("[FALHA] Assets.Remotes.GET: ausente", 1, true) ~= nil, "diagnostics report includes a failing probe")
    check(report:find("Feature.A: rodando", 1, true) ~= nil, "diagnostics report reads a live feature")
    check(report:find("Feature.B: ERRO DE LEITURA", 1, true) ~= nil, "diagnostics report contains a throwing feature instead of failing")
    check(report:find("linha livre", 1, true) ~= nil and report:find("[loader] iniciando", 1, true) ~= nil, "diagnostics report includes notes and log lines")

    local summary = diag:Summary()
    check(summary:find("1 falha", 1, true) ~= nil, "diagnostics summary counts failures")

    -- A throw inside a deferred feature reader must never take the report down.
    diag:Feature("Feature.C", function() return nil + 1 end)
    check(type(diag:Report()) == "string", "diagnostics always returns a report string")

    -- Copy prefers the executor clipboard and still prints.
    local copiedText = nil
    ctx.State.setclipboard = function(text) copiedText = text end
    local copied, text = diag:Copy()
    check(copied and copiedText == text, "diagnostics copies the full report to the clipboard")
    ctx.State.setclipboard = nil

    diag:Destroy()
end

-- The loader installs the shared Debug tab for every game, and the AOT:R
-- backend reports its own structure into it.
do
    local ctx = sandbox(4658598196, 4658598196)
    ctx.Responses["src/version.txt"] = "0.0.3"
    ctx:MountUI()
    check(ctx:Run("DepHub.lua") == true, "loader succeeds with the diagnostics collector")
    check(ctx.State.__DEPHUB.Diagnostics ~= nil, "loader publishes the diagnostics collector")
    check(ctx.State.__DEPHUB.Diagnostics.Installed, "loader installs the Debug tab")

    local ui = ctx.State.__DEPHUB.UI
    local names = {}
    for _, tab in ipairs(ui.Library._Tabs) do names[#names + 1] = tab.Name end
    local found = false
    for _, name in ipairs(names) do if name == "Debug" then found = true end end
    check(found, "shared Debug tab is registered")

    local report = ctx.State.__DEPHUB.Diagnostics:Report()
    check(report:find("Ambiente", 1, true) ~= nil, "Debug report has an environment section")
    check(report:find("AOTR.TitanRipper", 1, true) ~= nil, "AOT:R backend reports its combat features into Debug")
    check(report:find("Workspace.Titans", 1, true) ~= nil, "AOT:R backend reports its structure probes into Debug")
end

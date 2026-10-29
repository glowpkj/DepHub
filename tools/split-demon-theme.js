// Codemod: split src/core/ui/demon-theme.luau into an orchestrator + parts.
//
// The moved sections keep byte-identical bodies; only the "envelope" changes:
//   * each part is wrapped with a binding header that re-creates the shared
//     locals from the injected `__CTX`, and ends with `return true`;
//   * the shared _ReducedMotion flag becomes ctx.SharedReduced.value at its
//     8 read/write sites (the only edit inside moved code);
//   * cross-section symbols defined in a part (SubTabModule, WEATHER_PRESETS,
//     randomFloat) are published back onto __CTX by that part.
//
// Run from the repo root: node tools/split-demon-theme.js
// Writes src/core/ui/theme/*.luau and replaces src/core/ui/demon-theme.luau.

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const SRC = path.join(ROOT, 'src/core/ui/demon-theme.luau');
const OUTDIR = path.join(ROOT, 'src/core/ui/theme');

const raw = fs.readFileSync(SRC, 'utf8');
const EOL = raw.includes('\r\n') ? '\r\n' : '\n';
const lines = raw.split(/\r?\n/); // 0-based; line N is lines[N-1]

const slice = (a, b) => lines.slice(a - 1, b); // 1-based inclusive

// ---- section ranges (1-based inclusive), from the file's own banners ----
const CORE = [1, 177];           // header + Library/_IconCache/helpers/TweenService/services
const SHARED = [178, 303];       // Fn + D shells
const EXPORT = [12976, lines.length];

const PARTS = [
  { file: 'data.luau', range: [304, 641], title: 'THEMES + WEATHER PRESETS (D.* tables, WEATHER_PRESETS, randomFloat)',
    publish: ['WEATHER_PRESETS', 'randomFloat'] },
  { file: 'sub-tabs.luau', range: [642, 872], title: 'SUB-TAB MODULE',
    publish: ['SubTabModule', 'SUBTAB_DEFAULT_THEME'] },
  { file: 'constructor.luau', range: [873, 1217], title: 'LIBRARY CONSTRUCTOR' },
  { file: 'theme-apply.luau', range: [1218, 1778], title: 'THEME APPLY (perf tier, density, acrylic, reduced motion)' },
  { file: 'notifications.luau', range: [1779, 2488], title: 'NOTIFICATIONS + config save/load/import/export' },
  { file: 'window.luau', range: [2489, 5701], title: 'WINDOW CHROME (main GUI, title bar, category bar, search bar, content area)' },
  { file: 'extras.luau', range: [5702, 6504], title: 'FOCUS OVERLAY + WEATHER ENGINE + MOBILE TOGGLE + DRAG LOGIC' },
  { file: 'public-api.luau', range: [6505, 8621], title: 'PUBLIC API (CreateCategory/Tab/Section and label helpers)' },
  { file: 'controls.luau', range: [8622, 12105], title: 'CONTROLS (toggle, slider, dropdown, button, textbox, keybind, ...)' },
  { file: 'lifecycle.luau', range: [12106, 12975], title: 'WINDOW TOGGLE / MINIMIZE / DESTROY' },
];

// Shared core symbols every part may reference; bound from __CTX at part top.
const BINDINGS = [
  'Library', 'D', 'Fn', 'GetIcon', 'getCam', 'GetGuiParent', 'findInGuiParents',
  'GuiParent', 'TweenService', 'GuiSound', 'Players', 'RunService',
  'MarketplaceService', 'Stats', 'UserInputService', 'CoreGui', 'Lighting',
  'SoundService', 'LocalPlayer', 'IconsV2',
];
// Cross-section symbols bound from __CTX and (for the part that owns them)
// published back. A part that declares one of these itself must NOT bind it,
// or the local declaration is shadowed by a dead binding.
const CROSS = ['WEATHER_PRESETS', 'randomFloat', 'SubTabModule', 'SUBTAB_DEFAULT_THEME'];

function declaresSymbol(bodyLines, name) {
  const re = new RegExp('^\\s*local\\s+(function\\s+)?' + name + '\\b');
  return bodyLines.some((l) => re.test(l));
}

function bindLines(partBody) {
  const out = ['local SharedReduced = __CTX.SharedReduced'];
  for (const name of BINDINGS) out.push('local ' + name + ' = __CTX.' + name);
  for (const name of CROSS) {
    if (declaresSymbol(partBody, name)) continue; // this part owns it; publishes it instead
    out.push('local ' + name + ' = __CTX.' + name);
  }
  return out;
}

// Replace the shared _ReducedMotion flag with ctx.SharedReduced.value, verbatim
// everywhere else. Every standalone token is rewritten, both reads (`if x`,
// `RHS of an assignment`) and writes (`x = ...`).
function rewriteSharedReduced(bodyLines) {
  return bodyLines.map((line) => line.replace(/\b_ReducedMotion\b/g, 'SharedReduced.value'));
}

function buildPart(part) {
  const [a, b] = part.range;
  const body = rewriteSharedReduced(slice(a, b));
  const head = [
    '--[[',
    '  ' + part.title,
    '',
    '  Split out of src/core/ui/demon-theme.luau (original lines ' + a + '-' + b + ').',
    '  The body below is the original section, unchanged except for the shared',
    '  reduced-motion flag (ctx.SharedReduced.value). The orchestrator loads this',
    '  part with a shared context; it adds methods to the one Library table.',
    ']]',
    'local __CTX = ...',
    ...bindLines(body),
    '',
  ];
  const tail = [];
  for (const name of part.publish || []) tail.push('__CTX.' + name + ' = ' + name);
  tail.push('return true');
  return head.concat(body, '', tail).join(EOL) + EOL;
}

// ---- orchestrator ----
function buildOrchestrator() {
  const core = slice(CORE[0], CORE[1]);
  const shared = slice(SHARED[0], SHARED[1]);
  const exportSec = slice(EXPORT[0], EXPORT[1]);

  // In core, `local _ReducedMotion = false` becomes the shared table so the
  // TweenService wrapper (and every part) reads the same flag.
  const coreFixed = core.map((line) =>
    line.replace(/^(\s*)local _ReducedMotion\s*=\s*false\s*$/,
      '$1local SharedReduced = { value = false }'));
  const coreFinal = rewriteSharedReduced(coreFixed);
  const sharedFinal = rewriteSharedReduced(shared);

  const partFiles = PARTS.map((p) => 'src/core/ui/theme/' + p.file);

  return [
    ...coreFinal,
    ...sharedFinal,
    '',
    '-- =========================================================',
    '-- PART LOADER',
    '-- =========================================================',
    '-- The theme is split into ordered parts under src/core/ui/theme/. Each part',
    '-- receives this shared context and adds methods to the one Library table.',
    '-- Parts load with the same resolver the rest of the repo uses (the bundled',
    '-- source table in a build, game:HttpGet in an executor), in the exact order',
    '-- the sections appeared in the original file so every cross-reference',
    '-- resolves when its part runs.',
    'local THEME_PARTS = {',
    ...partFiles.map((f) => '    ' + JSON.stringify(f) + ','),
    '}',
    '',
    'local function resolvePartSource(relPath)',
    '    local env = (type(getgenv) == "function" and getgenv()) or _G',
    '    local resolver = (type(env.__dephubHttpGet) == "function" and env.__dephubHttpGet)',
    '        or (type(env.__DEPHUB_HTTP_GET) == "function" and env.__DEPHUB_HTTP_GET)',
    '        or (type(_G.__dephubHttpGet) == "function" and _G.__dephubHttpGet)',
    '        or (type(_G.__DEPHUB_HTTP_GET) == "function" and _G.__DEPHUB_HTTP_GET)',
    '    local base = (env.__DEPHUB and env.__DEPHUB.SourceBaseURL) or "https://raw.githubusercontent.com/glowpkj/DepHub/main/"',
    '    local token = (env.__DEPHUB and env.__DEPHUB.SourceCacheBust) or ""',
    '    local suffix = token ~= "" and ("?cb=" .. tostring(token)) or ""',
    '    if resolver then',
    '        local ok, source = pcall(resolver, base .. relPath .. suffix)',
    '        if ok and type(source) == "string" and #source > 0 then return source end',
    '    end',
    '    local ok, source = pcall(function() return game:HttpGet(base .. relPath .. suffix) end)',
    '    if ok and type(source) == "string" and #source > 0 then return source end',
    '    return nil',
    'end',
    '',
    'local ctx = {',
    '    Library = Library,',
    '    D = D,',
    '    Fn = Fn,',
    '    GetIcon = GetIcon,',
    '    getCam = getCam,',
    '    GetGuiParent = GetGuiParent,',
    '    findInGuiParents = findInGuiParents,',
    '    GuiParent = GuiParent,',
    '    TweenService = TweenService,',
    '    GuiSound = GuiSound,',
    '    Players = Players,',
    '    RunService = RunService,',
    '    MarketplaceService = MarketplaceService,',
    '    Stats = Stats,',
    '    UserInputService = UserInputService,',
    '    CoreGui = CoreGui,',
    '    Lighting = Lighting,',
    '    SoundService = SoundService,',
    '    LocalPlayer = LocalPlayer,',
    '    IconsV2 = IconsV2,',
    '    SharedReduced = SharedReduced,',
    '}',
    '',
    'local function loadThemeParts()',
    '    -- Parts run in the same environment this chunk runs in (the executor\'s',
    '    -- globals: game, Enum, Instance, ...). loadstring may hand back a chunk with',
    '    -- a different env on some executors, so set it explicitly when the executor',
    '    -- exposes setfenv/getfenv.',
    '    local currentEnv = (type(getfenv) == "function") and getfenv(0) or nil',
    '    for _, relPath in ipairs(THEME_PARTS) do',
    '        local source = resolvePartSource(relPath)',
    '        if type(source) ~= "string" or #source == 0 then',
    '            error("[DoD UI] theme part unavailable: " .. tostring(relPath))',
    '        end',
    '        local chunk, compileError = loadstring(source)',
    '        if not chunk then',
    '            error("[DoD UI] theme part failed to compile: " .. tostring(relPath) .. ": " .. tostring(compileError))',
    '        end',
    '        if currentEnv and type(setfenv) == "function" then',
    '            pcall(setfenv, chunk, currentEnv)',
    '        end',
    '        local ok, err = pcall(chunk, ctx)',
    '        if not ok then',
    '            error("[DoD UI] theme part failed: " .. tostring(relPath) .. ": " .. tostring(err))',
    '        end',
    '    end',
    'end',
    '',
    'loadThemeParts()',
    '',
    ...exportSec,
  ].join(EOL) + EOL;
}

fs.mkdirSync(OUTDIR, { recursive: true });
for (const part of PARTS) {
  const dest = path.join(OUTDIR, part.file);
  fs.writeFileSync(dest, buildPart(part));
  console.log('wrote', path.relative(ROOT, dest), '(' + (part.range[1] - part.range[0] + 1) + ' body lines)');
}
fs.writeFileSync(SRC, buildOrchestrator());
console.log('rewrote', path.relative(ROOT, SRC), '(orchestrator)');

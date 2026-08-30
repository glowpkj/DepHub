// Runs the actual UI modules against an isolated Roblox API double using Luau CLI.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const luau = process.argv[2];
if (!luau) throw new Error('Usage: node tests/run_ui_tests.js /path/to/luau');
const sources = {};
for (const name of ['utils', 'components', 'window']) {
  sources[name] = fs.readFileSync(path.join(root, 'src/ui', name + '.lua'), 'utf8')
    .replace(/require\(script\.Parent\.(\w+)\)/g, 'modules.$1');
}
sources.fruitvfx = fs.readFileSync(path.join(root, 'src/games/features/bloxfruits/fruitvfx.lua'), 'utf8');
const modules = 'local modules = {}\n' + Object.entries(sources)
  .map(([name, source]) => `modules.${name} = (function()\n${source}\nend)()`).join('\n');
const smoke = ['bloxfruits', 'universal'].map(name => {
  const source = fs.readFileSync(path.join(root, 'src/games', name + '.lua'), 'utf8');
  const start = source.indexOf('function State:CreateUI()');
  const end = source.indexOf('\nfunction State:Destroy()', start);
  if (start < 0 || end < 0) throw new Error('Could not isolate UI constructor for ' + name);
  return `do
    local env = {__DEPHUB = {}}
    local State = {Version="0.0.3", Values={DashLength=1, ESPColor=Color3.fromRGB(90,170,255), ChatMessage="Hello"}}
    State.Features = {FruitVFX = modules.fruitvfx.new({LocalPlayer = player})}
    function State:GetToggle() return false end
    function State:_startPingMonitor(stat) stat:SetValue("24 ms") end
    local function loadUILibrary() return true, modules.window end
    local function loadUI() return modules.window end
    ${source.slice(start, end)}
    check(State:CreateUI(), "${name}: actual UI constructor integrates with rebuilt API")
    check(#State.UI.Tabs >= 5, "${name}: all feature categories registered")
    State.Features.FruitVFX:Destroy()
    State.UI:Destroy()
  end`;
}).join('\n');
const harness = fs.readFileSync(path.join(__dirname, 'ui_harness.luau'), 'utf8')
  .replace('-- INSERT_MODULES', modules).replace('-- INSERT_GAME_SMOKES', smoke)
  .replace('-- INSERT_FRUIT_VFX_TESTS', fs.readFileSync(path.join(__dirname, 'fruit_vfx_tests.luau'), 'utf8'));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dephub-ui-test-'));
const file = path.join(temp, 'test.luau');
fs.writeFileSync(file, harness);
try {
  const result = cp.spawnSync(luau, [file], {encoding: 'utf8'});
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  process.exitCode = result.status || 0;
} finally {
  fs.unlinkSync(file);
  fs.rmdirSync(temp);
}

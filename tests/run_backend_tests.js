// Executes repository sources with isolated Roblox API doubles; no network or game access.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const luau = process.argv[2];
if (!luau) throw new Error('Usage: node tests/run_backend_tests.js /path/to/luau');
const files = ['src/games/aotr.lua', 'src/games/features/aotr/assistance.lua', 'DepHub.lua', 'src/games/bloxfruits.lua', 'src/games/universal.lua',
  'src/games/rt3.lua', 'src/core/runtime.lua', 'src/core/updater.lua', 'src/core/scheduler.lua', 'src/core/health-monitor.lua',
  'src/games/features/bloxfruits/fruitvfx.lua', 'src/games/noobpiece.lua',
  'src/games/features/bloxfruits/bladhits.lua', 'src/games/features/bloxfruits/autofarm.lua', 'src/games/features/bloxfruits/quests.lua',
  'src/games/features/mm2/roletracker.lua', 'src/games/features/tsb/autoblock-v3.lua',
  'src/games/tsb.lua'];
const manifestConfig = JSON.parse(fs.readFileSync(path.join(root, '.github/dephub-games.json'), 'utf8'));
for (const game of Object.values(manifestConfig)) {
  for (const file of game.files) {
    if (file.startsWith('src/ui/') || !fs.existsSync(path.join(root, file))) {
      throw new Error('Invalid tracked manifest file: ' + file);
    }
  }
}
function quote(value) {
  let eq = '=';
  while (value.includes(']' + eq + ']')) eq += '=';
  return '[' + eq + '[' + value + ']' + eq + ']';
}
function luaFiles(dir) {
  return fs.readdirSync(dir, {withFileTypes: true}).flatMap(entry => {
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? luaFiles(file) : file.endsWith('.lua') ? [file] : [];
  });
}
// Fail on dangling dependencies on retired frontend/library code. The UI lives
// in src/frontend and src/core/panel-host.lua by design, so the "no UI here"
// check is scoped to game backends; the retired markers are still banned
// everywhere (loader included).
if (fs.existsSync(path.join(root, 'library'))) {
  throw new Error('Retired library directory still exists');
}
// src/ui is the presentation layer (the intro animation). It must not be
// depended on by game backends; that is enforced by the src/games scan below.
const allowedUi = new Set(['Intro.lua', 'DepHubUI.lua']);
if (fs.existsSync(path.join(root, 'src/ui'))) {
  for (const entry of fs.readdirSync(path.join(root, 'src/ui'), {withFileTypes: true})) {
    if (!entry.isDirectory() && entry.name.endsWith('.lua') && !allowedUi.has(entry.name)) {
      throw new Error('Unexpected module in src/ui: ' + entry.name);
    }
  }
}
for (const file of [path.join(root, 'DepHub.lua'), ...luaFiles(path.join(root, 'src'))]) {
  const source = fs.readFileSync(file, 'utf8');
  if (/CreateUI|MountUI|CreatePrompt|library\/|frontend\.lua|Library\.new|dephubCompact|dephubViolenceDistrict/.test(source)) {
    throw new Error('Retired frontend/library dependency remains in ' + file);
  }
}
for (const file of luaFiles(path.join(root, 'src/games'))) {
  const source = fs.readFileSync(file, 'utf8');
  if (/CreateTab|CreateSection/.test(source)) {
    throw new Error('Game backend must not build UI: ' + file);
  }
}
const sources = 'local sources = {\n' + files.map(file =>
  `[ ${quote(file)} ] = ${quote(fs.readFileSync(path.join(root, file), 'utf8'))},`).join('\n') + '\n}';
const harness = fs.readFileSync(path.join(__dirname, 'backend_harness.luau'), 'utf8')
  .replace('-- INSERT_SOURCES', () => sources)
  .replace('-- INSERT_FRUIT_VFX_TESTS', () => fs.readFileSync(path.join(__dirname, 'fruit_vfx_tests.luau'), 'utf8'))
  .replace('-- INSERT_LIFECYCLE_TESTS', () => fs.readFileSync(path.join(__dirname, 'lifecycle_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'tsb_combat_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'aotr_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'core_tests.luau'), 'utf8'))
  .replace('-- INSERT_HEADLESS_TESTS', () => fs.readFileSync(path.join(__dirname, 'headless_tests.luau'), 'utf8'));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dephub-backend-test-'));
const file = path.join(temp, 'test.luau');
try {
  fs.writeFileSync(file, harness);
  const result = cp.spawnSync(luau, [file], {encoding: 'utf8', timeout: 30000});
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  process.exitCode = result.status === null ? 1 : result.status;
} finally {
  if (fs.existsSync(file)) fs.unlinkSync(file);
  fs.rmdirSync(temp);
}

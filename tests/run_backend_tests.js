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
  'src/core/demon-ui.lua',
  'src/games/noobpiece.lua',
  'src/games/features/mm2/roletracker.lua', 'src/games/features/tsb/autoblock-v3.lua',
  'src/games/tsb.lua', 'src/games/volleyball42.lua'];
const manifestConfig = JSON.parse(fs.readFileSync(path.join(root, '.github/dephub-games.json'), 'utf8'));
// Every module a game entry ships (vendored or feature) has to be available to
// the harness, so the test list can never drift from what the game ships.
for (const game of Object.values(manifestConfig)) {
  for (const file of game.files) {
    if ((file.endsWith('.lua') || file.endsWith('.luau')) && !file.includes('demon-theme') && !files.includes(file)) files.push(file);
  }
}
// The theme is split into ordered parts under src/core/ui/theme/. The orchestrator
// (demon-theme.luau) fetches each part through the same resolver the rest of the
// repo uses, so every part has to be available to the harness the same way.
const themeDir = path.join(root, 'src/core/ui/theme');
if (fs.existsSync(themeDir)) {
  for (const name of fs.readdirSync(themeDir).sort()) {
    if (name.endsWith('.luau') || name.endsWith('.lua')) {
      const rel = 'src/core/ui/theme/' + name;
      if (!files.includes(rel)) files.push(rel);
    }
  }
}
for (const game of Object.values(manifestConfig)) {
  for (const file of game.files) {
    if (file.startsWith('src/ui/') || file.startsWith('src/frontend/') || file.endsWith('/frontend.lua')) {
      throw new Error('Removed frontend file tracked in manifest: ' + file);
    }
    if (!fs.existsSync(path.join(root, file))) {
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
// Fail on dangling dependencies on retired frontend/library code. The frontend
// has been removed entirely, so no presentation module may come back.
if (fs.existsSync(path.join(root, 'library'))) {
  throw new Error('Retired library directory still exists');
}
for (const removed of ['src/ui', 'src/frontend', 'src/core/panel-host.lua', 'src/core/theme.lua', 'src/core/ui-guard.lua']) {
  if (fs.existsSync(path.join(root, removed))) {
    throw new Error('Removed frontend code still exists: ' + removed);
  }
}
for (const file of [path.join(root, 'DepHub.lua'), ...luaFiles(path.join(root, 'src'))]) {
  const source = fs.readFileSync(file, 'utf8');
  if (/CreateUI|MountUI|CreatePrompt|library\/|frontend\.lua|Library\.new|dephubCompact|dephubViolenceDistrict/.test(source)) {
    throw new Error('Retired frontend/library dependency remains in ' + file);
  }
}
// Game backends now own their presentation through the Demon UI wrapper, so
// they are expected to build tabs and sections. Only the retired frontend /
// library markers must stay gone.
for (const file of luaFiles(path.join(root, 'src/games'))) {
  const source = fs.readFileSync(file, 'utf8');
  if (/CreateUI|MountUI|CreatePrompt|library\/|frontend\.lua|Library\.new|dephubCompact|dephubViolenceDistrict/.test(source)) {
    throw new Error('Retired frontend/library dependency remains in ' + file);
  }
}
const sources = 'local sources = {\n' + files.map(file =>
  `[ ${quote(file)} ] = ${quote(fs.readFileSync(path.join(root, file), 'utf8'))},`).join('\n') + '\n}';
const harness = fs.readFileSync(path.join(__dirname, 'backend_harness.luau'), 'utf8')
  .replace('-- INSERT_SOURCES', () => sources)
  .replace('-- INSERT_BLOXF_OSS_TESTS', () => fs.readFileSync(path.join(__dirname, 'bloxfruits_oss_tests.luau'), 'utf8'))
  .replace('-- INSERT_THEME_SOURCE', () => {
    const theme = fs.readFileSync(path.join(root, 'src/core/ui/demon-theme.luau'), 'utf8');
    const partsDir = path.join(root, 'src/core/ui/theme');
    const entries = fs.existsSync(partsDir)
      ? fs.readdirSync(partsDir).sort().filter((n) => n.endsWith('.luau') || n.endsWith('.lua'))
      : [];
    const partsLua = entries
      .map((n) => `[ ${quote('src/core/ui/theme/' + n)} ] = ${quote(fs.readFileSync(path.join(partsDir, n), 'utf8'))},`)
      .join('\n');
    return 'local _THEME_SOURCE = ' + quote(theme) + '\n'
      + 'local _THEME_PARTS = {\n' + partsLua + '\n}';
  })
  .replace('-- INSERT_THEME_TESTS', () => fs.readFileSync(path.join(__dirname, 'theme_render_tests.luau'), 'utf8'))
  .replace('-- INSERT_LIFECYCLE_TESTS', () => fs.readFileSync(path.join(__dirname, 'lifecycle_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'tsb_combat_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'aotr_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'diagnostics_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'debug_backend_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'core_tests.luau'), 'utf8') + '\n' + fs.readFileSync(path.join(__dirname, 'ui_isolation_tests.luau'), 'utf8'))
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



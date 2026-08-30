// Executes repository sources with isolated Roblox API doubles; no network or game access.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const luau = process.argv[2];
if (!luau) throw new Error('Usage: node tests/run_backend_tests.js /path/to/luau');
const files = ['DepHub.lua', 'src/games/bloxfruits.lua', 'src/games/universal.lua',
  'src/games/rt3.lua', 'src/core/runtime.lua', 'src/core/updater.lua',
  'src/games/features/bloxfruits/fruitvfx.lua'];
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
// Fail on dangling frontend dependencies, even in modules not run by smoke tests.
if (fs.existsSync(path.join(root, 'src/ui')) && fs.readdirSync(path.join(root, 'src/ui')).length) {
  throw new Error('Legacy UI directory still contains files');
}
for (const file of [path.join(root, 'DepHub.lua'), ...luaFiles(path.join(root, 'src'))]) {
  const source = fs.readFileSync(file, 'utf8');
  if (/src\/ui\/|CreateUI|MountUI|CreateTab|CreateSection|CreatePrompt|Instance\.new\(["'](?:ScreenGui|TextButton|TextBox|Frame)["']\)/.test(source)) {
    throw new Error('Frontend code remains in ' + file);
  }
}
const sources = 'local sources = {\n' + files.map(file =>
  `[ ${quote(file)} ] = ${quote(fs.readFileSync(path.join(root, file), 'utf8'))},`).join('\n') + '\n}';
const harness = fs.readFileSync(path.join(__dirname, 'backend_harness.luau'), 'utf8')
  .replace('-- INSERT_SOURCES', () => sources)
  .replace('-- INSERT_FRUIT_VFX_TESTS', () => fs.readFileSync(path.join(__dirname, 'fruit_vfx_tests.luau'), 'utf8'))
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

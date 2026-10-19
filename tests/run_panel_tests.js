// Runs tests/panel_tests.luau with the real frontend and host sources injected.
// These are structural and wiring checks against a GUI-capable Roblox double —
// not a renderer — so they catch regressions in the object graph and the
// control callbacks without a live client.
//
// Usage: node tests/run_panel_tests.js /path/to/luau

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');

const root = path.resolve(__dirname, '..');
const luau = process.argv[2];
if (!luau) throw new Error('Usage: node tests/run_panel_tests.js /path/to/luau');

const modulePaths = [
  'src/frontend/init.lua',
  'src/core/panel-host.lua',
  'src/core/theme.lua',
];

function quote(value) {
  let eq = '=';
  while (value.includes(']' + eq + ']')) eq += '=';
  return '[' + eq + '[' + value + ']' + eq + ']';
}

const sources = 'local SOURCES = {\n' + modulePaths.map(p =>
  `[ ${quote(p)} ] = ${quote(fs.readFileSync(path.join(root, p), 'utf8'))},`
).join('\n') + '\n}\n';

const test = fs.readFileSync(path.join(__dirname, 'panel_tests.luau'), 'utf8');
const driver = sources + '\n' + test;

const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dephub-panel-test-'));
const file = path.join(temp, 'test.luau');
try {
  fs.writeFileSync(file, driver, 'utf8');
  const result = cp.spawnSync(luau, [file], {encoding: 'utf8', timeout: 30000});
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) throw result.error;
  process.exitCode = result.status === null ? 1 : result.status;
} finally {
  if (fs.existsSync(file)) fs.unlinkSync(file);
}

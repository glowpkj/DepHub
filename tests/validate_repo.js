const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

function fail(message) {
  throw new Error(message);
}

function read(relative) {
  return fs.readFileSync(path.join(root, relative), 'utf8');
}

function exists(relative) {
  return fs.existsSync(path.join(root, relative));
}

const version = read('src/version.txt').trim();
if (!/^\d+\.\d+\.\d+$/.test(version)) {
  fail('Invalid src/version.txt: ' + version);
}

const loader = read('DepHub.lua');
const loaderVersion = loader.match(/local\s+VERSION\s*=\s*["']([^"']+)["']/);
if (!loaderVersion) {
  fail('DepHub.lua VERSION constant was not found');
}
if (loaderVersion[1] !== version) {
  fail(`Loader version ${loaderVersion[1]} does not match src/version.txt ${version}`);
}

const manifestConfig = JSON.parse(read('.github/dephub-games.json'));
const requiredCommon = ['DepHub.lua', 'src/version.txt', 'src/core/ui-guard.lua'];

for (const [gameId, game] of Object.entries(manifestConfig)) {
  if (!game || typeof game.name !== 'string' || !Array.isArray(game.files)) {
    fail('Invalid game manifest entry: ' + gameId);
  }

  const seen = new Set();
  for (const file of game.files) {
    if (typeof file !== 'string' || !file) {
      fail(`Invalid tracked path in ${gameId}`);
    }
    if (seen.has(file)) {
      fail(`Duplicate tracked path in ${gameId}: ${file}`);
    }
    seen.add(file);
    if (!exists(file)) {
      fail(`Missing tracked file for ${gameId}: ${file}`);
    }
  }

  for (const required of requiredCommon) {
    if (!seen.has(required)) {
      fail(`Game ${gameId} is missing required tracked file: ${required}`);
    }
  }

  const updateFile = `src/games/updates/${gameId}.txt`;
  if (!seen.has(updateFile) || !exists(updateFile)) {
    fail(`Game ${gameId} is missing its update marker: ${updateFile}`);
  }
}

const tsbId = '3808081382';
const tsb = manifestConfig[tsbId];
if (!tsb) {
  fail('TSB manifest entry is missing');
}

const tsbFiles = new Set(tsb.files);
for (const required of ['src/core/updater.lua', 'src/games/tsb.lua']) {
  if (!tsbFiles.has(required)) {
    fail('TSB manifest is missing: ' + required);
  }
}

const tsbFeatureDir = path.join(root, 'src/games/features/tsb');
for (const entry of fs.readdirSync(tsbFeatureDir, {withFileTypes: true})) {
  if (!entry.isFile() || !entry.name.endsWith('.lua')) continue;
  const relative = `src/games/features/tsb/${entry.name}`;
  if (!tsbFiles.has(relative)) {
    fail('TSB feature is not tracked by the manifest: ' + relative);
  }
}

const legacyUi = path.join(root, 'src/ui');
if (fs.existsSync(legacyUi) && fs.readdirSync(legacyUi).length > 0) {
  fail('Legacy src/ui directory must stay empty');
}

console.log(`DepHub repository validation passed for v${version}`);

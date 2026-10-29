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
const requiredCommon = ['DepHub.lua', 'src/version.txt'];

for (const [gameId, game] of Object.entries(manifestConfig)) {
  if (!game || typeof game.name !== 'string' || !Array.isArray(game.files)) {
    fail('Invalid game manifest entry: ' + gameId);
  }

  const seen = new Set();
  for (const file of game.files) {
    if (typeof file !== 'string' || !file) fail(`Invalid tracked path in ${gameId}`);
    if (seen.has(file)) fail(`Duplicate tracked path in ${gameId}: ${file}`);
    seen.add(file);
    if (!exists(file)) fail(`Missing tracked file for ${gameId}: ${file}`);
    if (file.startsWith('library/')) fail(`Retired library path is still tracked in ${gameId}: ${file}`);
    if (file.endsWith('/frontend.lua') || file.startsWith('src/ui/') || file.startsWith('src/frontend/')) {
      fail(`Removed frontend is still tracked in ${gameId}: ${file}`);
    }
  }

  for (const required of requiredCommon) {
    if (!seen.has(required)) fail(`Game ${gameId} is missing required tracked file: ${required}`);
  }

  const updateFile = `src/games/updates/${gameId}.txt`;
  if (!seen.has(updateFile) || !exists(updateFile)) fail(`Game ${gameId} is missing its update marker: ${updateFile}`);
}

// Every backend feature module must be tracked so the updater can hash it.
function validateFeatureDirectory(gameId, directory) {
  const game = manifestConfig[gameId];
  if (!game) fail(`Manifest entry is missing: ${gameId}`);
  const files = new Set(game.files);
  const absolute = path.join(root, directory);
  if (!fs.existsSync(absolute)) return;
  for (const entry of fs.readdirSync(absolute, {withFileTypes: true})) {
    if (!entry.isFile() || !entry.name.endsWith('.lua')) continue;
    const relative = `${directory}/${entry.name}`;
    if (!files.has(relative)) fail(`${game.name} feature is not tracked by the manifest: ${relative}`);
  }
}

validateFeatureDirectory('994732206', 'src/games/features/bloxfruits');
validateFeatureDirectory('85211729168715', 'src/games/features/bloxfruits');
validateFeatureDirectory('119048529960596', 'src/games/features/restauranttycoon3');
validateFeatureDirectory('84822469255086', 'src/games/features/noobpiece');
validateFeatureDirectory('3808081382', 'src/games/features/tsb');
validateFeatureDirectory('66654135', 'src/games/features/mm2');
validateFeatureDirectory('4658598196', 'src/games/features/aotr');

if (!loader.includes('["142823291"]') || !loader.includes('["66654135"]') || !loader.includes('src/games/mm2.lua')) {
  fail('MM2 loader routing is incomplete');
}
if (loader.includes('volleyball') || loader.includes('Volleyball') || loader.includes('6931042565')) {
  fail('Removed Volleyball Legends routing remains in the loader');
}
if (loader.includes('violencedistrict') || loader.includes('ViolenceDistrict') || loader.includes('6739698191')) {
  fail('Removed Violence District routing remains in the loader');
}
// The loader must not pull in the retired third-party library or the removed
// in-repo frontend. The retired markers below are banned outright.
if (/library\/|frontend\.lua|Library\.new|dephubCompact|dephubViolenceDistrict/.test(loader)) {
  fail('Loader still references a retired frontend/library');
}

for (const retired of ['src/games/volleyballlegends.lua', 'src/games/violencedistrict.lua']) {
  if (exists(retired)) fail('Retired backend still exists: ' + retired);
}
for (const retired of ['src/games/features/volleyballlegends', 'src/games/features/violencedistrict', 'library']) {
  if (exists(retired)) fail('Retired directory still exists: ' + retired);
}

// Game backends must stay presentation-free: they may not build UI. The
// frontend has been removed entirely, so only src/games is checked here.
const xmlUi = /CreateTab|CreateSection|CreateToggle\b|Library\.new|dephubCompact|dephubViolenceDistrict|library\//;
function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith('.lua')) {
      const source = fs.readFileSync(file, 'utf8');
      if (xmlUi.test(source)) {
        fail('Backend still depends on a retired frontend/library: ' + path.relative(root, file));
      }
    }
  }
}
walk(path.join(root, 'src/games'));

for (const removed of ['src/ui', 'src/frontend', 'src/core/panel-host.lua', 'src/core/theme.lua', 'src/core/ui-guard.lua']) {
  if (exists(removed)) fail('Removed frontend code still exists: ' + removed);
}

console.log(`DepHub repository validation passed for v${version}`);

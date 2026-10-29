#requires -Version 5.1
<#
    DepHub publish.ps1

    One-button build-and-push for the DepHub repository.

    What it does, in order:
      1. Locates Git and the Luau CLI (portable copies under C:\Users\<you>\tools,
         then PATH, then a portable download into tools/).
      2. Runs the full local gate: repo validation, backend/headless tests,
         and a bytecode compile of every source file.
      3. Regenerates src/update-manifest.json with the same hash algorithm the
         CI workflow uses, so the two never disagree.
      4. Commits every change and pushes to origin/<branch>.

    Credentials: authentication uses Git Credential Manager and your GitHub
    account. The first HTTPS push opens a browser window to sign in; the
    credential is stored (DPAPI-encrypted) and every later push is automatic.
    A token in the environment variable DEPHUB_GIT_TOKEN or in a gitignored
    .publish-token file is still honoured for headless runs. The token is only
    used for that one push and is never written into the repo.

    Usage:
      powershell -ExecutionPolicy Bypass -File publish.ps1
      powershell -ExecutionPolicy Bypass -File publish.ps1 -Message "feat: add blox fruits autofarm"
      powershell -ExecutionPolicy Bypass -File publish.ps1 -NoPush      # build + commit only
      powershell -ExecutionPolicy Bypass -File publish.ps1 -DryRun      # gate only, no commit

    Or just double-click publish.bat.
#>
param(
    [string]$Message = "",
    [string]$Branch = "main",
    [switch]$NoPush,
    [switch]$DryRun,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

function Write-Step([string]$Text) { Write-Host ""; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "    OK  $Text" -ForegroundColor Green }
function Write-Warn2([string]$Text){ Write-Host "    !!  $Text" -ForegroundColor Yellow }
function Fail([string]$Text)       { Write-Host ""; Write-Host "FAILED: $Text" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------------------
# Tool discovery
# ---------------------------------------------------------------------------
function Resolve-Tool {
    param([string[]]$Candidates, [string]$Name)
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
    }
    return $null
}

$userTools = Join-Path $env:USERPROFILE 'tools'
$gitCandidates = @(
    (Join-Path $userTools 'mingit\cmd\git.exe'),
    (Join-Path $RepoRoot 'tools\mingit\cmd\git.exe'),
    (Join-Path ${env:ProgramFiles} 'Git\cmd\git.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
)
$luauCandidates = @(
    (Join-Path $userTools 'luau-win\luau-compile.exe'),
    (Join-Path $RepoRoot 'tools\luau-win\luau-compile.exe'),
    (Join-Path $env:TEMP 'luau-win\luau-compile.exe')
)

Write-Step 'Locating tools'
$GitExe = Resolve-Tool -Candidates $gitCandidates -Name 'git'
if (-not $GitExe) {
    $onPath = Get-Command git -ErrorAction SilentlyContinue
    if ($onPath) { $GitExe = $onPath.Source }
}
if (-not $GitExe) { Fail "Git not found. Install it or place a portable copy at $userTools\mingit." }
Write-Ok "git      $GitExe"

$CompileExe = Resolve-Tool -Candidates $luauCandidates -Name 'luau-compile'
$LuauExe = $null
if ($CompileExe) { $LuauExe = Join-Path (Split-Path -Parent $CompileExe) 'luau.exe' }
$NodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $NodeExe) { Fail 'Node.js not found on PATH (required by the test runner).' }
Write-Ok "node     $NodeExe"
if ($CompileExe) { Write-Ok "luau     $CompileExe" } else { Write-Warn2 'luau-compile not found - compile step will be skipped.' }

# ---------------------------------------------------------------------------
# Gate
# ---------------------------------------------------------------------------
if (-not $SkipTests) {
    Write-Step 'Validating repository'
    & $NodeExe tests/validate_repo.js
    if ($LASTEXITCODE -ne 0) { Fail 'validate_repo.js reported problems.' }
    Write-Ok 'validate_repo passed'

    if ($LuauExe) {
        Write-Step 'Running backend and headless tests'
        & $NodeExe tests/run_backend_tests.js $LuauExe
        if ($LASTEXITCODE -ne 0) { Fail 'backend/headless tests failed.' }
        Write-Ok 'backend tests passed'
    } else {
        Write-Warn2 'luau.exe not found - skipping behavioral tests.'
    }

    if ($CompileExe) {
        Write-Step 'Compiling all Luau sources'
        $sources = @()
        foreach ($dir in @('src', 'diagnostics')) {
            if (Test-Path $dir) {
                $sources += Get-ChildItem -Recurse -File -Path $dir -Include *.lua | ForEach-Object { $_.FullName }
            }
        }
        & $CompileExe --null DepHub.lua @sources
        if ($LASTEXITCODE -ne 0) { Fail 'luau-compile reported a syntax error.' }
        Write-Ok "compiled $($sources.Count) files"
    }
} else {
    Write-Warn2 'Skipping tests (-SkipTests).'
}

# ---------------------------------------------------------------------------
# Manifest regeneration (must match the CI algorithm)
# ---------------------------------------------------------------------------
Write-Step 'Regenerating src/update-manifest.json'
$manifestScript = @'
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = process.argv[2];
if (!root || !fs.existsSync(root)) { console.error('bad repo root: ' + root); process.exit(1); }
const config = JSON.parse(fs.readFileSync(path.join(root, '.github/dephub-games.json'), 'utf8'));
const version = fs.readFileSync(path.join(root, 'src/version.txt'), 'utf8').trim();
const games = {};
for (const [placeId, game] of Object.entries(config)) {
  const digest = crypto.createHash('sha256');
  for (const p of game.files) {
    const full = path.join(root, p);
    if (!fs.existsSync(full)) throw new Error('Missing tracked file: ' + p);
    const data = fs.readFileSync(full);
    digest.update(Buffer.from(p, 'utf8'));
    digest.update(Buffer.from([0]));
    digest.update(data);
    digest.update(Buffer.from([0]));
  }
  games[placeId] = { name: game.name, version: digest.digest('hex'), commit: 'local', files: game.files };
}
const manifest = { schema: 2, generatedAt: new Date().toISOString(), commit: 'local', version, games, recentUpdates: [] };
fs.writeFileSync(path.join(root, 'src/update-manifest.json'), JSON.stringify(manifest, null, 2) + '\n', 'utf8');
console.log('manifest written:', Object.keys(games).length, 'games, version ' + version);
'@
$tmpManifest = Join-Path $env:TEMP ('dephub_manifest_' + [guid]::NewGuid().ToString('N') + '.js')
Set-Content -Path $tmpManifest -Value $manifestScript -Encoding UTF8
try {
    & $NodeExe $tmpManifest $RepoRoot
    if ($LASTEXITCODE -ne 0) { Fail 'manifest generation failed.' }
} finally {
    Remove-Item $tmpManifest -ErrorAction SilentlyContinue
}
Write-Ok 'manifest regenerated'

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run complete - nothing committed or pushed." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------
Write-Step 'Staging and committing'
& $GitExe add -A
if ($LASTEXITCODE -ne 0) { Fail 'git add failed.' }

& $GitExe diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Warn2 'No changes to commit.'
} else {
    if (-not $Message) {
        $Message = 'chore: update DepHub build'
    }
    & $GitExe -c user.name='DepHub Publish' -c user.email='publish@localhost' commit -m $Message
    if ($LASTEXITCODE -ne 0) { Fail 'git commit failed.' }
    Write-Ok "committed: $Message"
}

if ($NoPush) {
    Write-Host ""
    Write-Host "Committed locally (-NoPush). Push skipped." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------
Write-Step 'Pushing to origin'

$Remote = (& $GitExe remote get-url origin).Trim()
if (-not $Remote) { Fail 'No origin remote configured.' }

# Authentication is handled by Git Credential Manager: the first HTTPS push
# opens a browser window to sign in to GitHub, and the credential is stored
# (DPAPI-encrypted) for every push after that. A token in DEPHUB_GIT_TOKEN or
# .publish-token is still honoured if present, for headless use.
$Token = $env:DEPHUB_GIT_TOKEN
$tokenFile = Join-Path $RepoRoot '.publish-token'
if (-not $Token -and (Test-Path $tokenFile)) {
    $Token = (Get-Content $tokenFile -Raw).Trim()
}

if ($Token -and $Remote -match '^https://') {
    $hostPart = ($Remote -replace '^https://', '') -replace '^[^@]*@', ''
    & $GitExe -c credential.helper= push "https://x-access-token:$Token@$hostPart" "HEAD:$Branch"
    $pushExit = $LASTEXITCODE
    & $GitExe remote set-url origin $Remote | Out-Null
    if ($pushExit -ne 0) { Fail 'git push failed (check the token scope and branch protection).' }
} else {
    # Normal authenticated push. GCM will prompt the first time.
    Write-Host "    (if this is the first push, a browser window will open to sign in to GitHub)" -ForegroundColor DarkGray
    & $GitExe push origin "HEAD:$Branch"
    if ($LASTEXITCODE -ne 0) { Fail 'git push failed. If the login window was cancelled, run the script again.' }
}

Write-Host ""
Write-Host "Published to $Branch." -ForegroundColor Green
Write-Host "GitHub Actions will validate and refresh the manifest on its own." -ForegroundColor DarkGray

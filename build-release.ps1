#requires -Version 5.1
<#
    DepHub build-release.ps1

    Production-packaging step. Turns this private repository into the single
    artifact a user actually runs.

    Model: the repository stays private; the code is never served at runtime.
    This script inlines every module into one Lua chunk (tools/bundle.js), runs
    the full local gate so a broken build can never ship, optionally passes the
    chunk through an obfuscator, and writes a ready-to-host release plus a tiny
    public loader into dist/.

    What it does, in order:
      1. Locates Node.js, the Luau CLI and (optionally) the obfuscator.
      2. Runs the gate: repo validation, backend/headless tests, bundle smoke
         test (all seven routes must load with the network blocked), and a
         bytecode compile of the bundle.
      3. Bundles every module into dist/DepHub.bundle.lua.
      4. Optionally obfuscates the bundle (see -Obfuscator below).
      5. Writes the public loader dist/loader.lua pointing at your fixed URL.

    Obfuscation:
      The bundle is plain Luau by default. Pass -Obfuscator external and a
      command to run it through any obfuscator that reads stdin and writes
      stdout. The command receives the bundle on stdin; its stdout becomes the
      released artifact. Examples:

        powershell -File build-release.ps1 -Obfuscator external `
            -ExternalCommand "luraph-cli --preset max"

        powershell -File build-release.ps1 -Obfuscator external `
            -ExternalCommand "prometheus-cli"

      Obfuscation is the only step that keeps the source unreadable once the
      artifact is public; without it the bundle is trivially readable and the
      private repository is exposed in effect. Ship without it only for local
      testing.

    Usage:
      powershell -ExecutionPolicy Bypass -File build-release.ps1
      powershell -ExecutionPolicy Bypass -File build-release.ps1 -HostURL "https://cdn.example.com/v1/DepHub.lua"
      powershell -ExecutionPolicy Bypass -File build-release.ps1 -Obfuscator external -ExternalCommand "luraph-cli --preset max"
      powershell -ExecutionPolicy Bypass -File build-release.ps1 -SkipTests   # fast local iteration

    Or double-click build-release.bat.
#>
param(
    [string]$OutDir = "dist",
    [string]$HostURL = "",
    [ValidateSet("none", "external")]
    [string]$Obfuscator = "none",
    [string]$ExternalCommand = "",
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
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
    }
    return $null
}

$userTools = Join-Path $env:USERPROFILE 'tools'
$luauCandidates = @(
    (Join-Path $userTools 'luau-win\luau-compile.exe'),
    (Join-Path $RepoRoot 'tools\luau-win\luau-compile.exe'),
    (Join-Path $env:TEMP 'luau-win\luau-compile.exe')
)

Write-Step 'Locating tools'
$NodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $NodeExe) { Fail 'Node.js not found on PATH (required by the bundler and tests).' }
Write-Ok "node     $NodeExe"

$CompileExe = Resolve-Tool -Candidates $luauCandidates
$LuauExe = $null
if ($CompileExe) { $LuauExe = Join-Path (Split-Path -Parent $CompileExe) 'luau.exe' }
if ($CompileExe) { Write-Ok "luau     $CompileExe" } else { Write-Warn2 'luau-compile not found - some gate steps will be skipped.' }

if ($Obfuscator -eq 'external' -and -not $ExternalCommand) {
    Fail '-Obfuscator external requires -ExternalCommand.'
}

$distPath = Join-Path $RepoRoot $OutDir
$bundlePath = Join-Path $distPath 'DepHub.bundle.lua'
$releasePath = Join-Path $distPath 'DepHub.lua'
$loaderPath = Join-Path $distPath 'loader.lua'

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
} else {
    Write-Warn2 'Skipping tests (-SkipTests).'
}

# ---------------------------------------------------------------------------
# Bundle
# ---------------------------------------------------------------------------
Write-Step 'Bundling all modules'
New-Item -ItemType Directory -Force -Path $distPath | Out-Null
& $NodeExe tools/bundle.js $RepoRoot $bundlePath
if ($LASTEXITCODE -ne 0) { Fail 'bundling failed.' }
$bundleSize = (Get-Item $bundlePath).Length
Write-Ok ("bundle written: {0:N1} KB" -f ($bundleSize / 1KB))

if ($CompileExe) {
    Write-Step 'Compiling the bundle'
    & $CompileExe --null $bundlePath
    if ($LASTEXITCODE -ne 0) { Fail 'the bundle does not compile.' }
    Write-Ok 'bundle compiles'
}

if (-not $SkipTests -and $LuauExe) {
    Write-Step 'Verifying the bundle is self-contained (network blocked)'
    $routes = @(
        @('2753915549',    '994732206',   'BloxFruits'),
        @('13379208636',   '4658598196',  'AOTR'),
        @('10449761463',   '0',           'TSB'),
        @('142823291',     '0',           'MM2'),
        @('84822469255086','0',           'NoobPiece'),
        @('119048529960596','0',          'RT3'),
        @('12345',         '999',         'Universal')
    )
    foreach ($route in $routes) {
        & $NodeExe tests/verify_bundle.js $bundlePath $LuauExe $route[0] $route[1] $route[2]
        if ($LASTEXITCODE -ne 0) { Fail ("bundle verification failed for " + $route[2]) }
    }
    Write-Ok 'every route resolves offline with zero network fetches'
}

# ---------------------------------------------------------------------------
# Release artifact
# ---------------------------------------------------------------------------
$artifactPath = $bundlePath
if ($Obfuscator -eq 'external') {
    Write-Step "Obfuscating with: $ExternalCommand"
    $obfuscated = Join-Path $distPath 'DepHub.obfuscated.lua'
    # Stream the bundle through the obfuscator with a temporary .cmd file so
    # bytes are preserved exactly: no PowerShell pipeline, no text encoding, no
    # BOM, and no nested-quote mangling of the obfuscator command line.
    $runner = Join-Path $env:TEMP ('dephub_obf_' + [guid]::NewGuid().ToString('N') + '.cmd')
    $runnerBody = @(
        '@echo off',
        ('type "' + $bundlePath + '" | ' + $ExternalCommand + ' > "' + $obfuscated + '"')
    ) -join "`r`n"
    Set-Content -Path $runner -Value $runnerBody -Encoding ASCII
    try {
        & $runner
        if ($LASTEXITCODE -ne 0) { Fail 'the obfuscator command failed.' }
    } finally {
        Remove-Item $runner -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $obfuscated) -or (Get-Item $obfuscated).Length -eq 0) {
        Fail 'the obfuscator produced no output.'
    }
    $artifactPath = $obfuscated
    $obfSize = (Get-Item $obfuscated).Length
    Write-Ok ("obfuscated artifact: {0:N1} KB" -f ($obfSize / 1KB))
} else {
    Write-Warn2 'No obfuscation. The released artifact is readable source.'
    Write-Warn2 'Host it behind a private URL or add -Obfuscator external before shipping.'
}

Copy-Item -Force $artifactPath $releasePath

if (-not $HostURL) {
    $HostURL = 'https://raw.githubusercontent.com/glowpkj/DepHub-releases/main/DepHub.lua'
    Write-Warn2 "No -HostURL given; the loader will default to $HostURL"
}

# ---------------------------------------------------------------------------
# Public loader: the only thing a user runs
# ---------------------------------------------------------------------------
Write-Step 'Writing the public loader'
$loader = @"
-- DepHub loader. Fetches and runs the DepHub bundle from a fixed URL.
-- Update the URL here if you move the hosted artifact.
local DEPHUB_URL = "$HostURL"
local source = game:HttpGet(DEPHUB_URL .. (DEPHUB_URL:find("?") and "&" or "?") .. "t=" .. tostring(math.floor(os.clock() * 1000000)))
if type(source) ~= "string" or #source == 0 then
    error("DepHub: failed to download the bundle from " .. DEPHUB_URL)
end
local chunk, err = loadstring(source)
if not chunk then error("DepHub: bundle failed to compile: " .. tostring(err)) end
return chunk()
"@
Set-Content -Path $loaderPath -Value $loader -Encoding ASCII
Write-Ok "loader written: $loaderPath"

Write-Host ""
Write-Host "Release complete: $distPath" -ForegroundColor Green
Write-Host "  DepHub.lua   the artifact to host at the loader URL" -ForegroundColor DarkGray
Write-Host "  loader.lua   the one-liner users run" -ForegroundColor DarkGray
Write-Host "  DepHub.bundle.lua  the readable bundle (keep private)" -ForegroundColor DarkGray
if ($Obfuscator -eq 'none') {
    Write-Host "  NOTE: not obfuscated - re-run with -Obfuscator external before a public release." -ForegroundColor Yellow
}

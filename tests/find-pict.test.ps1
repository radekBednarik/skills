# Tests for skills/pict-pairwise-testing/scripts/find-pict.ps1
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests\find-pict.test.ps1 -RealPict C:\path\to\pict.exe
#
# -RealPict is required: Windows cannot run a shell-script stand-in, so the
# positive cases need a real pict.exe. Nothing is installed or modified; the
# cache dir and PATH are redirected to temporary values per case.

param([Parameter(Mandatory = $true)][string]$RealPict)

$script = Join-Path $PSScriptRoot '..\skills\pict-pairwise-testing\scripts\find-pict.ps1'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("find-pict-test-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$script:pass = 0
$script:fail = 0
$psExe = (Get-Process -Id $PID).Path

function Invoke-Case([string]$Name, [int]$WantExit, [string[]]$WantLines,
                     [string]$PathValue, [string]$PictBin, [string]$LocalAppData) {
    $saved = @{ PATH = $env:PATH; PICT_BIN = $env:PICT_BIN; LOCALAPPDATA = $env:LOCALAPPDATA }
    try {
        $env:PATH = $PathValue
        $env:PICT_BIN = $PictBin
        $env:LOCALAPPDATA = $LocalAppData
        $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $script 2>&1 | ForEach-Object { "$_" }
        $gotExit = $LASTEXITCODE
    } finally {
        $env:PATH = $saved.PATH
        $env:PICT_BIN = $saved.PICT_BIN
        $env:LOCALAPPDATA = $saved.LOCALAPPDATA
    }
    $ok = ($gotExit -eq $WantExit)
    foreach ($line in $WantLines) {
        if ($out -notcontains $line) { $ok = $false }
    }
    if ($ok) {
        $script:pass++
        Write-Output "ok   - $Name"
    } else {
        $script:fail++
        Write-Output "FAIL - $Name (exit $gotExit, wanted $WantExit)"
        Write-Output ("       wanted lines: " + ($WantLines -join ' ; '))
        $out | ForEach-Object { Write-Output "       | $_" }
    }
}

try {
    $emptyCache = Join-Path $work 'empty'
    New-Item -ItemType Directory -Path $emptyCache | Out-Null
    $noPict = Join-Path $env:SystemRoot 'System32'

    # A bin dir and a cache dir that each hold a copy of the real binary.
    $binDir = Join-Path $work 'bin'
    $cacheRoot = Join-Path $work 'cache'
    $cacheDir = Join-Path $cacheRoot 'pict-skill'
    New-Item -ItemType Directory -Path $binDir, $cacheDir | Out-Null
    Copy-Item -LiteralPath $RealPict -Destination (Join-Path $binDir 'pict.exe')
    Copy-Item -LiteralPath $RealPict -Destination (Join-Path $cacheDir 'pict.exe')

    # A different program that happens to be called pict.
    $impostorDir = Join-Path $work 'impostor'
    New-Item -ItemType Directory -Path $impostorDir | Out-Null
    Set-Content -LiteralPath (Join-Path $impostorDir 'pict.cmd') -Value "@echo pict 1.0 - picture converter"

    Invoke-Case 'nothing found reports missing' 1 `
        @('status=missing', "cache_dir=$(Join-Path $emptyCache 'pict-skill')") `
        $noPict '' $emptyCache

    Invoke-Case 'PICT_BIN is used' 0 `
        @('status=found', "path=$RealPict", 'source=PICT_BIN', 'flags=o d a n e r c s') `
        $noPict $RealPict $emptyCache

    Invoke-Case 'pict on PATH is found' 0 `
        @('status=found', "path=$(Join-Path $binDir 'pict.exe')", 'source=PATH') `
        "$binDir;$noPict" '' $emptyCache

    Invoke-Case 'cache dir is found' 0 `
        @('status=found', "path=$(Join-Path $cacheDir 'pict.exe')", 'source=cache') `
        $noPict '' $cacheRoot

    Invoke-Case 'PICT_BIN wins over PATH and cache' 0 @('source=PICT_BIN') `
        "$binDir;$noPict" $RealPict $cacheRoot

    Invoke-Case 'PATH wins over cache' 0 @('source=PATH') `
        "$binDir;$noPict" '' $cacheRoot

    $missing = Join-Path $work 'does-not-exist.exe'
    Invoke-Case 'bad PICT_BIN falls through with a note' 0 `
        @('source=PATH', "note=PICT_BIN is set to '$missing' but that is not a working PICT executable") `
        "$binDir;$noPict" $missing $emptyCache

    Invoke-Case 'unrelated program named pict is rejected' 1 @('status=missing') `
        "$impostorDir;$noPict" '' $emptyCache

    Invoke-Case 'impostor on PATH still allows cache hit' 0 @('source=cache') `
        "$impostorDir;$noPict" '' $cacheRoot
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ''
Write-Output "$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0

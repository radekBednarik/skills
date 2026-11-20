# find-pict.ps1 - locate the PICT executable and report which options it supports.
#
# Read-only and offline: this script does not download, install, build or
# write anything. It only checks a few locations and runs a candidate once
# with no arguments to read its usage text.
#
# Search order:
#   1. $env:PICT_BIN        (explicit path chosen by the user)
#   2. pict                 (on PATH)
#   3. the skill cache dir  (%LOCALAPPDATA%\pict-skill)
#
# Output: key=value lines on stdout.
# Exit:   0 when a working PICT was found, 1 otherwise.

$ErrorActionPreference = 'Continue'

if ($env:LOCALAPPDATA) {
    $cacheDir = Join-Path $env:LOCALAPPDATA 'pict-skill'
} elseif ($env:XDG_CACHE_HOME) {
    $cacheDir = Join-Path $env:XDG_CACHE_HOME 'pict-skill'
} else {
    $cacheDir = Join-Path (Join-Path $HOME '.cache') 'pict-skill'
}

# Returns the usage text when $Candidate identifies itself as PICT, else $null.
function Get-PictUsage([string]$Candidate) {
    if (-not $Candidate) { return $null }
    if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { return $null }
    try {
        $text = (& $Candidate 2>&1 | Out-String)
    } catch {
        return $null
    }
    if ($text -match 'Pairwise Independent Combinatorial') { return $text }
    return $null
}

function Write-Found([string]$Path, [string]$Source, [string]$Usage) {
    # Option letters come from usage lines such as " /o:N|max - Order of ...".
    $flags = @()
    foreach ($line in ($Usage -split "`r?`n")) {
        if ($line -match '^\s*/([A-Za-z])') { $flags += $Matches[1] }
    }
    Write-Output 'status=found'
    Write-Output "path=$Path"
    Write-Output "source=$Source"
    Write-Output ("flags=" + ($flags -join ' '))
    exit 0
}

if ($env:PICT_BIN) {
    $usage = Get-PictUsage $env:PICT_BIN
    if ($usage) { Write-Found $env:PICT_BIN 'PICT_BIN' $usage }
    Write-Output "note=PICT_BIN is set to '$($env:PICT_BIN)' but that is not a working PICT executable"
}

$onPath = Get-Command pict -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($onPath) {
    $usage = Get-PictUsage $onPath.Source
    if ($usage) { Write-Found $onPath.Source 'PATH' $usage }
    Write-Output "note=found '$($onPath.Source)' on PATH but it does not identify itself as PICT"
}

foreach ($name in @('pict.exe', 'pict')) {
    $candidate = Join-Path $cacheDir $name
    $usage = Get-PictUsage $candidate
    if ($usage) { Write-Found $candidate 'cache' $usage }
}

Write-Output 'status=missing'
Write-Output "cache_dir=$cacheDir"
Write-Output ("os=" + [System.Environment]::OSVersion.Platform)
exit 1

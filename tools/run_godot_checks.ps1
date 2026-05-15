param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

function Find-Godot {
    param([string]$Candidate)

    if ($Candidate -ne "" -and (Test-Path $Candidate)) {
        return (Resolve-Path $Candidate).Path
    }

    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command -ne $null) {
        return $command.Source
    }

    $commonPaths = @(
        "$env:ProgramFiles\Godot\Godot_v4.6-stable_win64.exe",
        "$env:ProgramFiles\Godot\Godot_v4.5-stable_win64.exe",
        "$env:ProgramFiles\Godot\Godot.exe",
        "${env:ProgramFiles(x86)}\Godot\Godot.exe"
    )

    foreach ($path in $commonPaths) {
        if ($path -ne "" -and (Test-Path $path)) {
            return (Resolve-Path $path).Path
        }
    }

    return ""
}

$godot = Find-Godot $GodotBin

if ($godot -eq "") {
    Write-Host "Godot CLI was not found. Set GODOT_BIN to the full Godot executable path, then rerun this script."
    exit 1
}

Push-Location $RepoRoot

Write-Host "[check] Godot project parse"
& $godot --headless --path $RepoRoot --quit
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    exit $LASTEXITCODE
}

Write-Host "[check] Godot restaurant smoke"
& $godot --headless --path $RepoRoot --script res://tools/restaurant_smoke_test.gd
$exitCode = $LASTEXITCODE

Pop-Location
exit $exitCode

param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$failed = $false

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host "[check] $Name"
    try {
        $global:LASTEXITCODE = 0
        & $Command
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "exit code $LASTEXITCODE"
        }
        Write-Host "[ok] $Name"
    } catch {
        Write-Host "[fail] $Name"
        Write-Host $_
        $script:failed = $true
    }
}

Push-Location $RepoRoot

$assignPattern = ':' + '='

Invoke-Check "no Godot typed-assignment shorthand" {
    & rg -n $assignPattern .
    if ($LASTEXITCODE -eq 1) {
        $global:LASTEXITCODE = 0
    }
}

Invoke-Check "git whitespace diff check" {
    & git diff --check
}

Invoke-Check "TODO contains only pending work" {
    $todoPath = Join-Path $RepoRoot "TODO.md"
    $todoText = [System.IO.File]::ReadAllText($todoPath, [System.Text.Encoding]::UTF8)
    $blockedTerms = @(
        ([string][char]0x9AD8 + [string][char]0x4F18 + [string][char]0x5148 + [string][char]0x7EA7 + [string][char]0x7EF4 + [string][char]0x62A4),
        ([string][char]0x672C + [string][char]0x8F6E + [string][char]0x5DF2 + [string][char]0x5904 + [string][char]0x7406),
        ([string][char]0x5DF2 + [string][char]0x5B8C + [string][char]0x6210 + [string][char]0x62C6 + [string][char]0x5206)
    )

    foreach ($term in $blockedTerms) {
        if ($todoText.Contains($term)) {
            throw "TODO.md still contains completed-work wording."
        }
    }
}

Pop-Location

if ($failed) {
    exit 1
}

exit 0

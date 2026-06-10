param(
    [string]$Alias = "cal-diy-dev",
    [string]$DevHub = "devOrg"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
Set-Location $repoRoot

function Resolve-DevHub {
    param([string]$Preferred)
    $list = sf org list --json | ConvertFrom-Json
    $hub = $list.result.devHubs | Where-Object { $_.alias -eq $Preferred -and $_.connectedStatus -eq "Connected" }
    if ($hub) { return $Preferred }
    $connected = $list.result.devHubs | Where-Object { $_.connectedStatus -eq "Connected" } | Select-Object -First 1
    if (-not $connected) { throw "No connected Dev Hub found. Run sf org login web --set-default-dev-hub" }
    return $connected.alias
}

function Resolve-Alias {
    param([string]$Preferred, [string]$Fallback)
    $list = sf org list --json | ConvertFrom-Json
    $existing = @($list.result.scratchOrgs) + @($list.result.nonScratchOrgs) | Where-Object { $_.alias -eq $Preferred }
    if ($existing -and $existing.status -ne "Deleted") {
        Write-Host "Alias $Preferred exists; deleting scratch org..."
        sf org delete scratch -o $Preferred -p 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Could not delete $Preferred; using $Fallback"
            return $Fallback
        }
    }
    return $Preferred
}

$DevHub = Resolve-DevHub -Preferred $DevHub
$Alias = Resolve-Alias -Preferred $Alias -Fallback "cal-diy-scratch"

Write-Host "Creating scratch org: $Alias (Dev Hub: $DevHub)"
$def = Get-Content config/project-scratch-def.json -Raw | ConvertFrom-Json
if ($def.PSObject.Properties.Name -contains "durationDays") {
    $def.PSObject.Properties.Remove("durationDays")
}
$tmpDef = Join-Path $env:TEMP "cal-diy-scratch-def.json"
$def | ConvertTo-Json -Depth 10 | Set-Content $tmpDef
sf org create scratch -f $tmpDef -a $Alias -v $DevHub -y 30
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying force-app with RunLocalTests..."
sf project deploy start --source-dir force-app --target-org $Alias --test-level RunLocalTests
if ($LASTEXITCODE -ne 0) {
    Write-Host "Deploy failed; retrying with NoTestRun then running tests..."
    sf project deploy start --source-dir force-app --target-org $Alias --test-level NoTestRun --ignore-conflicts
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    sf apex run test --target-org $Alias --test-level RunLocalTests --result-format human --wait 30
}

sf org assign permset --name Scheduling_Host --target-org $Alias
sf org assign permset --name Scheduling_Admin --target-org $Alias
sf config set target-org $Alias
sf org open --target-org $Alias

Write-Host "`n--- Org summary ---"
sf org display --target-org $Alias

[CmdletBinding()]
param([string]$EnvironmentFile = ".env")

. "$PSScriptRoot\Common.ps1"
Import-DotEnv -Path $EnvironmentFile
$workspaceId = Get-RequiredEnvironmentValue "FABRIC_WORKSPACE_ID"

$expected = @(
    @{ displayName = "MedallionLakehouse"; type = "Lakehouse" },
    @{ displayName = "TransformMedallion"; type = "Notebook" },
    @{ displayName = "Motorola Sales Certified"; type = "SemanticModel" },
    @{ displayName = "Motorola Sales Overview"; type = "Report" },
    @{ displayName = "Motorola Sales Agent"; type = "DataAgent" }
)
$missing = @()
foreach ($descriptor in $expected) {
    $item = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $descriptor.displayName -Type $descriptor.type
    if ($null -eq $item) {
        $missing += "$($descriptor.type): $($descriptor.displayName)"
    }
    else {
        Write-Host "FOUND $($descriptor.type): $($item.displayName) [$($item.id)]"
    }
}
if ($missing.Count -gt 0) {
    throw "Deployment is incomplete. Missing: $($missing -join ', ')"
}
Write-Host "Item-level verification passed. Complete the UI evidence checklist in docs\runbook.md."

[CmdletBinding()]
param([string]$EnvironmentFile = ".env")

. "$PSScriptRoot\Common.ps1"
Import-DotEnv -Path $EnvironmentFile
& "$PSScriptRoot\preflight.ps1" -EnvironmentFile $EnvironmentFile -RequireDeploymentTools

$workspaceId = Get-RequiredEnvironmentValue "FABRIC_WORKSPACE_ID"
$statePath = ".fabric-deploy-state.json"
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "Deployment state is missing. Run deploy.ps1 first."
}
$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
if ($state.createdResourceTag -ne "moto-fabric-poc" -or $state.workspaceId -ne $workspaceId) {
    throw "Deployment state does not belong to this POC and workspace."
}

$displayName = "SalesOntology"
$existing = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $displayName -Type "Ontology"
if ($null -ne $existing -and -not (Test-StateOwnsItem -State $state -Item $existing)) {
    throw "Refusing to update pre-existing Ontology '$displayName'."
}

$deploymentExitCode = 0
try {
    & (Get-PocPython) "$PSScriptRoot\deploy_items.py" `
        --workspace-id $workspaceId `
        --repository-directory "fabric" `
        --environment "POC" `
        --item-types Ontology
    $deploymentExitCode = $LASTEXITCODE
}
finally {
    $deployed = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $displayName -Type "Ontology"
    if ($null -ne $deployed) {
        Add-OwnedItemToState -State $state -Item $deployed
        Save-PocDeploymentState -State $state -Path $statePath
    }
}
if ($deploymentExitCode -ne 0) {
    throw "Ontology deployment failed. Any created item ID was checkpointed for safe teardown."
}
if ($null -eq $deployed) {
    throw "Deployed ontology could not be resolved."
}

Write-Host "Ontology deployed: $($deployed.displayName) [$($deployed.id)]"
Write-Host "Complete the semantic-model binding with the Ontology Agent prompts in docs\ontology-runbook.md."

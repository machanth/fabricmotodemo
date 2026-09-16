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
$lakehouse = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "MedallionLakehouse" -Type "Lakehouse"
if ($null -eq $lakehouse) {
    throw "MedallionLakehouse does not exist. Run deploy.ps1 first."
}

$details = Invoke-FabricApi -Method GET -Path "/workspaces/$workspaceId/lakehouses/$($lakehouse.id)"
$sqlEndpoint = $details.properties.sqlEndpointProperties
if ($null -eq $sqlEndpoint -or [string]::IsNullOrWhiteSpace($sqlEndpoint.connectionString)) {
    throw "Lakehouse SQL analytics endpoint is not ready."
}

$stagingRoot = Join-Path "dist" "fabric"
if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -Recurse -Force -LiteralPath $stagingRoot
}
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
Copy-Item -Recurse -Force "fabric\*" $stagingRoot

$modelFile = Join-Path $stagingRoot "Motorola Sales Certified.SemanticModel\definition\expressions.tmdl"
$content = Get-Content -Raw -LiteralPath $modelFile
$content = $content.Replace("{{LAKEHOUSE_SQL_ENDPOINT}}", $sqlEndpoint.connectionString)
$content = $content.Replace("{{LAKEHOUSE_SQL_DATABASE}}", $sqlEndpoint.id)
[System.IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath $modelFile),
    $content,
    (New-Object System.Text.UTF8Encoding($false))
)

$modelDescriptors = @(
    @{ displayName = "Motorola Sales Certified"; type = "SemanticModel" },
    @{ displayName = "Motorola Sales Overview"; type = "Report" }
)
foreach ($descriptor in $modelDescriptors) {
    $existing = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $descriptor.displayName -Type $descriptor.type
    if ($null -ne $existing -and -not (Test-StateOwnsItem -State $state -Item $existing)) {
        throw "Refusing to update pre-existing $($descriptor.type) '$($descriptor.displayName)'."
    }
}

$deploymentExitCode = 0
try {
    & (Get-PocPython) "$PSScriptRoot\deploy_items.py" `
        --workspace-id $workspaceId `
        --repository-directory $stagingRoot `
        --environment "POC" `
        --item-types SemanticModel Report
    $deploymentExitCode = $LASTEXITCODE
}
finally {
    foreach ($descriptor in $modelDescriptors) {
        $deployed = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $descriptor.displayName -Type $descriptor.type
        if ($null -ne $deployed) {
            Add-OwnedItemToState -State $state -Item $deployed
        }
    }
    Save-PocDeploymentState -State $state -Path $statePath
}
if ($deploymentExitCode -ne 0) {
    throw "Semantic model/report deployment failed. Created item IDs were checkpointed for teardown."
}

$semanticModel = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "Motorola Sales Certified" -Type "SemanticModel"
if ($null -eq $semanticModel) {
    throw "Deployed semantic model was not found."
}
$agentSource = Join-Path $stagingRoot "Motorola Sales Agent.DataAgent\Files\Config\draft\semantic_model-Motorola Sales Certified\datasource.json"
$agentContent = Get-Content -Raw -LiteralPath $agentSource
$agentContent = $agentContent.Replace("00000000-0000-0000-0000-000000000000", $workspaceId)
$agentDefinition = $agentContent | ConvertFrom-Json
$agentDefinition.artifactId = $semanticModel.id
[System.IO.File]::WriteAllText(
    (Resolve-Path -LiteralPath $agentSource),
    ($agentDefinition | ConvertTo-Json -Depth 30),
    (New-Object System.Text.UTF8Encoding($false))
)

$existingAgent = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "Motorola Sales Agent" -Type "DataAgent"
if ($null -ne $existingAgent -and -not (Test-StateOwnsItem -State $state -Item $existingAgent)) {
    throw "Refusing to update pre-existing DataAgent 'Motorola Sales Agent'."
}
$agentExitCode = 0
try {
    & (Get-PocPython) "$PSScriptRoot\deploy_items.py" `
        --workspace-id $workspaceId `
        --repository-directory $stagingRoot `
        --environment "POC" `
        --item-types DataAgent
    $agentExitCode = $LASTEXITCODE
}
finally {
    $deployedAgent = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "Motorola Sales Agent" -Type "DataAgent"
    if ($null -ne $deployedAgent) {
        Add-OwnedItemToState -State $state -Item $deployedAgent
    }
    Save-PocDeploymentState -State $state -Path $statePath
}
if ($agentExitCode -ne 0) {
    throw "Data agent draft deployment failed. Created item IDs were checkpointed for teardown."
}

foreach ($descriptor in @(
    @{ displayName = "Motorola Sales Certified"; type = "SemanticModel" },
    @{ displayName = "Motorola Sales Overview"; type = "Report" },
    @{ displayName = "Motorola Sales Agent"; type = "DataAgent" }
)) {
    $item = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $descriptor.displayName -Type $descriptor.type
    if ($null -eq $item) {
        throw "Deployed item was not found: $($descriptor.displayName)"
    }
    Add-OwnedItemToState -State $state -Item $item
}
Save-PocDeploymentState -State $state -Path $statePath
Write-Host "Semantic model, thin report, and data-agent draft deployed."

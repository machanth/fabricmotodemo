[CmdletBinding()]
param(
    [string]$EnvironmentFile = ".env",
    [switch]$SkipWarehouseUpload,
    [switch]$SkipShortcut,
    [switch]$SkipNotebookRun
)

. "$PSScriptRoot\Common.ps1"
Import-DotEnv -Path $EnvironmentFile
& "$PSScriptRoot\preflight.ps1" -EnvironmentFile $EnvironmentFile -RequireDeploymentTools

$workspaceId = Get-RequiredEnvironmentValue "FABRIC_WORKSPACE_ID"
$statePath = ".fabric-deploy-state.json"
if (Test-Path -LiteralPath $statePath) {
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    if ($state.createdResourceTag -ne "moto-fabric-poc" -or $state.workspaceId -ne $workspaceId) {
        throw "Existing deployment state does not belong to this POC and workspace."
    }
}
else {
    $state = New-PocDeploymentState -WorkspaceId $workspaceId
    Save-PocDeploymentState -State $state -Path $statePath
}

$environmentName = [Environment]::GetEnvironmentVariable("FABRIC_DEPLOY_ENVIRONMENT")
if ([string]::IsNullOrWhiteSpace($environmentName)) {
    $environmentName = "POC"
}

$coreDescriptors = @(
    @{ displayName = "MedallionLakehouse"; type = "Lakehouse" },
    @{ displayName = "TransformMedallion"; type = "Notebook" }
)
foreach ($descriptor in $coreDescriptors) {
    $existing = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $descriptor.displayName -Type $descriptor.type
    if ($null -ne $existing -and -not (Test-StateOwnsItem -State $state -Item $existing)) {
        throw "Refusing to update pre-existing $($descriptor.type) '$($descriptor.displayName)'."
    }
}

Write-Host "Deploying lakehouse and notebook metadata..."
$deploymentExitCode = 0
try {
    & python "$PSScriptRoot\deploy_items.py" `
        --workspace-id $workspaceId `
        --repository-directory "fabric" `
        --environment $environmentName `
        --item-types Lakehouse Notebook
    $deploymentExitCode = $LASTEXITCODE
}
finally {
    foreach ($descriptor in $coreDescriptors) {
        $deployed = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName $descriptor.displayName -Type $descriptor.type
        if ($null -ne $deployed) {
            Add-OwnedItemToState -State $state -Item $deployed
        }
    }
    Save-PocDeploymentState -State $state -Path $statePath
}
if ($deploymentExitCode -ne 0) {
    throw "Core Fabric item deployment failed. Created item IDs were checkpointed for teardown."
}

$lakehouse = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "MedallionLakehouse" -Type "Lakehouse"
$notebook = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "TransformMedallion" -Type "Notebook"
if ($null -eq $lakehouse -or $null -eq $notebook) {
    throw "Deployed lakehouse or notebook could not be resolved."
}

if (-not $SkipWarehouseUpload) {
    if (-not (Get-Command azcopy -ErrorAction SilentlyContinue)) {
        throw "AzCopy is required to upload warehouse-domain files. Install AzCopy or rerun with -SkipWarehouseUpload after uploading sample-data\warehouse manually."
    }
    [Environment]::SetEnvironmentVariable("AZCOPY_AUTO_LOGIN_TYPE", "AZCLI", "Process")
    $destination = "https://onelake.dfs.fabric.microsoft.com/$workspaceId/$($lakehouse.id)/Files/landing/warehouse"
    & azcopy copy "sample-data\warehouse\*" $destination --recursive=false
    if ($LASTEXITCODE -ne 0) {
        throw "Warehouse-domain source upload failed."
    }
}

if (-not $SkipShortcut) {
    $sourceType = Get-RequiredEnvironmentValue "SHORTCUT_SOURCE_TYPE"
    $connectionId = Get-RequiredEnvironmentValue "SHORTCUT_CONNECTION_ID"
    $location = Get-RequiredEnvironmentValue "SHORTCUT_LOCATION"
    $subpath = Get-RequiredEnvironmentValue "SHORTCUT_SUBPATH"
    switch ($sourceType) {
        "AdlsGen2" {
            $target = @{ adlsGen2 = @{
                location = $location
                subpath = $subpath
                connectionId = $connectionId
            } }
        }
        "AmazonS3" {
            $target = @{ amazonS3 = @{
                location = $location
                subpath = $subpath
                connectionId = $connectionId
            } }
        }
        default {
            throw "SHORTCUT_SOURCE_TYPE must be AdlsGen2 or AmazonS3."
        }
    }
    $shortcutBody = @{
        path = "Files/landing/customer-domain"
        name = "external-customers"
        target = $target
    }
    $ownedShortcut = $null -ne $state.shortcut -and
        $state.shortcut.lakehouseId -eq $lakehouse.id -and
        $state.shortcut.path -eq "Files/landing/customer-domain" -and
        $state.shortcut.name -eq "external-customers"
    if (-not $ownedShortcut) {
        try {
            $null = Invoke-FabricApi -Method GET -Path "/workspaces/$workspaceId/items/$($lakehouse.id)/shortcuts/Files/landing/customer-domain/external-customers"
            throw "Refusing to overwrite pre-existing shortcut 'Files/landing/customer-domain/external-customers'."
        }
        catch {
            if (-not (Test-FabricNotFound -ErrorRecord $_)) {
                throw
            }
        }
    }
    $shortcutPath = "/workspaces/$workspaceId/items/$($lakehouse.id)/shortcuts?shortcutConflictPolicy=CreateOrOverwrite"
    $null = Invoke-FabricApi -Method POST -Path $shortcutPath -Body $shortcutBody
    $state.shortcut = @{
        lakehouseId = $lakehouse.id
        path = "Files/landing/customer-domain"
        name = "external-customers"
    }
    Save-PocDeploymentState -State $state -Path $statePath
    Write-Host "Created or updated external customer-domain shortcut."
}

if (-not $SkipNotebookRun) {
    $jobPath = "/workspaces/$workspaceId/items/$($notebook.id)/jobs/instances?jobType=RunNotebook"
    $null = Invoke-FabricApi -Method POST -Path $jobPath -Body @{}
    Write-Host "Submitted the medallion notebook. Run verify-deployment.ps1 after it completes."
    Write-Host "The semantic model and report are intentionally not deployed until gold tables exist."
}

Save-PocDeploymentState -State $state -Path $statePath

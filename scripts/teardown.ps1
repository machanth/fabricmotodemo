[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param([string]$StatePath = ".fabric-deploy-state.json")

. "$PSScriptRoot\Common.ps1"
if (-not (Test-Path -LiteralPath $StatePath)) {
    throw "No deployment state exists. Teardown refuses to infer resources by name."
}
$state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
if ($state.createdResourceTag -ne "moto-fabric-poc") {
    throw "State file is not owned by this POC."
}

if ($null -ne $state.shortcut) {
    $shortcutPath = "/workspaces/$($state.workspaceId)/items/$($state.shortcut.lakehouseId)/shortcuts/$($state.shortcut.path)/$($state.shortcut.name)"
    if ($PSCmdlet.ShouldProcess($shortcutPath, "Delete POC shortcut")) {
        try {
            $null = Invoke-FabricApi -Method DELETE -Path $shortcutPath
        }
        catch {
            if (-not (Test-FabricNotFound -ErrorRecord $_)) {
                throw
            }
        }
        $state.shortcut = $null
        Save-PocDeploymentState -State $state -Path $StatePath
    }
}

$items = @($state.items)
[array]::Reverse($items)
foreach ($item in $items) {
    try {
        $live = Invoke-FabricApi -Method GET -Path "/workspaces/$($state.workspaceId)/items/$($item.id)"
    }
    catch {
        if (Test-FabricNotFound -ErrorRecord $_) {
            $state.items = @($state.items | Where-Object { $_.id -ne $item.id })
            Save-PocDeploymentState -State $state -Path $StatePath
            continue
        }
        throw
    }
    if ($live.displayName -ne $item.displayName -or $live.type -ne $item.type) {
        throw "Refusing to delete changed resource $($item.id)."
    }
    if ($PSCmdlet.ShouldProcess("$($item.type) '$($item.displayName)'", "Delete POC-created item")) {
        try {
            $null = Invoke-FabricApi -Method DELETE -Path "/workspaces/$($state.workspaceId)/items/$($item.id)"
        }
        catch {
            if (-not (Test-FabricNotFound -ErrorRecord $_)) {
                throw
            }
        }
        $state.items = @($state.items | Where-Object { $_.id -ne $item.id })
        Save-PocDeploymentState -State $state -Path $StatePath
    }
}
if (-not $WhatIfPreference -and $null -eq $state.shortcut -and @($state.items).Count -eq 0) {
    Remove-Item -LiteralPath $StatePath
}
Write-Host "POC items removed. Workspace, capacity, external storage, and cloud connections were preserved."

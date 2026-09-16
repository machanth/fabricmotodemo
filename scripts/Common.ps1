Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Import-DotEnv {
    param([string]$Path = ".env")
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) {
            continue
        }
        $parts = $trimmed.Split("=", 2)
        if ($parts.Count -ne 2) {
            throw "Invalid .env line: $line"
        }
        [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
    }
}

function Get-RequiredEnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match "^0{8}-0{4}-0{4}-0{4}-0{12}$") {
        throw "Set $Name to a non-placeholder value in .env or the process environment."
    }
    return $value
}

function Get-FabricToken {
    $token = & az account get-access-token --resource "https://api.fabric.microsoft.com" --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "Unable to acquire a Fabric token. Run 'az login' with an authorized identity."
    }
    return $token.Trim()
}

function Invoke-FabricApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("GET", "POST", "DELETE")][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )
    $headers = @{ Authorization = "Bearer $(Get-FabricToken)" }
    $uri = if ($Path.StartsWith("https://")) { $Path } else { "https://api.fabric.microsoft.com/v1$Path" }
    if ($PSBoundParameters.ContainsKey("Body")) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers `
            -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 20)
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Test-FabricNotFound {
    param([Parameter(Mandatory = $true)]$ErrorRecord)
    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $false
    }
    return [int]$response.StatusCode -eq 404
}

function Get-WorkspaceItem {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspaceId,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$Type
    )
    $path = "/workspaces/$WorkspaceId/items?type=$Type"
    $matches = @()
    do {
        $response = Invoke-FabricApi -Method GET -Path $path
        $matches += @($response.value | Where-Object { $_.displayName -eq $DisplayName })
        $continuationProperty = $response.PSObject.Properties["continuationUri"]
        $path = if ($null -eq $continuationProperty) { $null } else { $continuationProperty.Value }
    } while (-not [string]::IsNullOrWhiteSpace($path))
    if ($matches.Count -gt 1) {
        throw "More than one $Type item is named '$DisplayName'."
    }
    if ($matches.Count -eq 0) {
        return $null
    }
    return $matches[0]
}

function New-PocDeploymentState {
    param([Parameter(Mandatory = $true)][string]$WorkspaceId)
    return @{
        workspaceId = $WorkspaceId
        createdResourceTag = "moto-fabric-poc"
        items = @()
        shortcut = $null
    }
}

function Save-PocDeploymentState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [string]$Path = ".fabric-deploy-state.json"
    )
    $temporaryPath = "$Path.tmp"
    $State | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 -LiteralPath $temporaryPath
    Move-Item -Force -LiteralPath $temporaryPath -Destination $Path
}

function Add-OwnedItemToState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)]$Item
    )
    $items = @($State.items | Where-Object { $_.id -ne $Item.id })
    $items += @{ id = $Item.id; displayName = $Item.displayName; type = $Item.type }
    $State.items = $items
}

function Test-StateOwnsItem {
    param(
        [Parameter(Mandatory = $true)]$State,
        $Item
    )
    if ($null -eq $Item) {
        return $false
    }
    return @($State.items | Where-Object { $_.id -eq $Item.id }).Count -eq 1
}

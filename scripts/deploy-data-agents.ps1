[CmdletBinding()]
param([string]$EnvironmentFile = ".env")

. "$PSScriptRoot\Common.ps1"
Import-DotEnv -Path $EnvironmentFile

$workspaceId = Get-RequiredEnvironmentValue "FABRIC_WORKSPACE_ID"
$statePath = ".fabric-deploy-state.json"
if (-not (Test-Path -LiteralPath $statePath)) {
    throw "Deployment state is missing. Run deploy.ps1 first."
}
$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
if ($state.createdResourceTag -ne "moto-fabric-poc" -or $state.workspaceId -ne $workspaceId) {
    throw "Deployment state does not belong to this POC and workspace."
}

function Get-ConfiguredItem {
    param(
        [Parameter(Mandatory = $true)][string]$EnvironmentName,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string[]]$DisplayNames
    )
    $configuredId = [Environment]::GetEnvironmentVariable($EnvironmentName, "Process")
    if (-not [string]::IsNullOrWhiteSpace($configuredId) -and
        $configuredId -notmatch "^0{8}-0{4}-0{4}-0{4}-0{12}$") {
        return @($state.items | Where-Object {
            $_.type -eq $Type -and $_.id -eq $configuredId
        }) | Select-Object -First 1
    }
    return @($state.items | Where-Object {
        $_.type -eq $Type -and $_.displayName -in $DisplayNames
    }) | Select-Object -First 1
}

$semanticModel = Get-ConfiguredItem `
    -EnvironmentName "FABRIC_SEMANTIC_MODEL_ID" `
    -Type "SemanticModel" `
    -DisplayNames @("Sales Certified")
$semanticAgent = Get-ConfiguredItem `
    -EnvironmentName "FABRIC_SEMANTIC_AGENT_ID" `
    -Type "DataAgent" `
    -DisplayNames @("Sales Agent")
$ontology = Get-ConfiguredItem `
    -EnvironmentName "FABRIC_ONTOLOGY_ID" `
    -Type "Ontology" `
    -DisplayNames @("SalesOntology")
$ontologyAgent = Get-ConfiguredItem `
    -EnvironmentName "FABRIC_ONTOLOGY_AGENT_ID" `
    -Type "DataAgent" `
    -DisplayNames @("Ontology Agent")

foreach ($required in @(
    @{ name = "Sales Certified semantic model"; value = $semanticModel },
    @{ name = "Sales Agent"; value = $semanticAgent },
    @{ name = "SalesOntology"; value = $ontology },
    @{ name = "Ontology Agent"; value = $ontologyAgent }
)) {
    if ($null -eq $required.value) {
        throw "$($required.name) isn't recorded as POC-owned in $statePath."
    }
}

$token = Get-FabricToken
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

function Invoke-DataAgentRequest {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("GET", "POST")][string]$Method,
        [Parameter(Mandatory = $true)][string]$Uri,
        [object]$Body
    )
    $arguments = @{
        Method = $Method
        Uri = $Uri
        Headers = $headers
        SkipHttpErrorCheck = $true
    }
    if ($PSBoundParameters.ContainsKey("Body")) {
        $arguments.ContentType = "application/json"
        $arguments.Body = $Body | ConvertTo-Json -Depth 50 -Compress
    }
    $response = Invoke-WebRequest @arguments
    $content = if ([string]::IsNullOrWhiteSpace($response.Content)) {
        $null
    }
    else {
        $response.Content | ConvertFrom-Json
    }
    return [pscustomobject]@{
        StatusCode = [int]$response.StatusCode
        Headers = $response.Headers
        Content = $content
    }
}

function Wait-DataAgentOperation {
    param([Parameter(Mandatory = $true)]$Response)
    if ($Response.StatusCode -ne 202) {
        return $Response
    }
    $location = [string]$Response.Headers.Location
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Seconds 2
        $operation = Invoke-DataAgentRequest -Method GET -Uri $location
        if ($operation.Content.status -eq "Succeeded") {
            return Invoke-DataAgentRequest -Method GET -Uri "$location/result"
        }
        if ($operation.Content.status -eq "Failed") {
            throw "Fabric operation failed: $($operation.Content | ConvertTo-Json -Depth 20 -Compress)"
        }
    }
    throw "Fabric operation did not finish within 120 seconds."
}

function Get-DefinitionParts {
    param(
        [Parameter(Mandatory = $true)][string]$DefinitionRoot,
        [Parameter(Mandatory = $true)][ValidateSet("semantic_model", "ontology")][string]$SourceType
    )
    return @(Get-ChildItem -LiteralPath (Join-Path $DefinitionRoot "Files") -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = [IO.Path]::GetRelativePath($DefinitionRoot, $_.FullName).Replace("\", "/")
            $bytes = [IO.File]::ReadAllBytes($_.FullName)
            if ($_.Name -eq "datasource.json") {
                $source = [Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
                if ($source.type -eq $SourceType) {
                    $source.workspaceId = $workspaceId
                    if ($SourceType -eq "semantic_model") {
                        $source.artifactId = $semanticModel.id
                        $source.displayName = "Sales Certified"
                    }
                    else {
                        $source.artifactId = $ontology.id
                        $source.displayName = "SalesOntology"
                    }
                    $bytes = [Text.Encoding]::UTF8.GetBytes(
                        ($source | ConvertTo-Json -Depth 50 -Compress)
                    )
                }
            }
            @{
                path = $relativePath
                payload = [Convert]::ToBase64String($bytes)
                payloadType = "InlineBase64"
            }
        })
}

function Update-And-VerifyDataAgent {
    param(
        [Parameter(Mandatory = $true)]$Agent,
        [Parameter(Mandatory = $true)][string]$DefinitionRoot,
        [Parameter(Mandatory = $true)][ValidateSet("semantic_model", "ontology")][string]$SourceType,
        [Parameter(Mandatory = $true)][string]$ExpectedArtifactId
    )
    $baseUri = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/dataAgents/$($Agent.id)"
    $parts = Get-DefinitionParts -DefinitionRoot $DefinitionRoot -SourceType $SourceType
    $update = Invoke-DataAgentRequest -Method POST -Uri "$baseUri/updateDefinition" -Body @{
        definition = @{ parts = $parts }
    }
    if ($update.StatusCode -notin 200, 202) {
        throw "DataAgent update failed with HTTP $($update.StatusCode): $($update.Content | ConvertTo-Json -Depth 20 -Compress)"
    }
    $updateStatus = $update.StatusCode
    $null = Wait-DataAgentOperation -Response $update

    $readback = Invoke-DataAgentRequest -Method GET -Uri $baseUri
    if ($readback.StatusCode -ne 200) {
        throw "DataAgent readback failed with HTTP $($readback.StatusCode)."
    }
    $definition = Wait-DataAgentOperation -Response (
        Invoke-DataAgentRequest -Method POST -Uri "$baseUri/getDefinition" -Body @{}
    )
    if ($definition.StatusCode -ne 200) {
        throw "DataAgent definition readback failed with HTTP $($definition.StatusCode)."
    }
    $sourcePart = @($definition.Content.definition.parts | Where-Object {
        $_.path -like "*/datasource.json"
    }) | ForEach-Object {
        [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.payload)) |
            ConvertFrom-Json
    } | Where-Object { $_.type -eq $SourceType } | Select-Object -First 1
    if ($null -eq $sourcePart -or $sourcePart.artifactId -ne $ExpectedArtifactId) {
        throw "DataAgent source verification failed for $($readback.Content.displayName)."
    }
    Write-Host "$($readback.Content.displayName): update HTTP $updateStatus; item readback HTTP $($readback.StatusCode); getDefinition HTTP $($definition.StatusCode); ID $($readback.Content.id); source $SourceType -> $($sourcePart.artifactId)"
}

Update-And-VerifyDataAgent `
    -Agent $semanticAgent `
    -DefinitionRoot "fabric\Sales Agent.DataAgent" `
    -SourceType "semantic_model" `
    -ExpectedArtifactId $semanticModel.id

Update-And-VerifyDataAgent `
    -Agent $ontologyAgent `
    -DefinitionRoot "fabric\Ontology Agent.DataAgent" `
    -SourceType "ontology" `
    -ExpectedArtifactId $ontology.id

$token = $null
Write-Host "Both DataAgent draft definitions deployed idempotently and verified. Publish remains a Fabric UI step."

[CmdletBinding()]
param(
    [string]$EnvironmentFile = ".env",
    [ValidateRange(1, 20)][int]$Iterations = 3,
    [ValidateRange(0, 300)][int]$DelaySeconds = 30
)

. "$PSScriptRoot\Common.ps1"
Import-DotEnv -Path $EnvironmentFile
$workspaceId = Get-RequiredEnvironmentValue "FABRIC_WORKSPACE_ID"
$notebook = Get-WorkspaceItem -WorkspaceId $workspaceId -DisplayName "TransformMedallion" -Type "Notebook"
if ($null -eq $notebook) {
    throw "TransformMedallion is not deployed."
}

New-Item -ItemType Directory -Path "dist" -Force | Out-Null
$runId = [guid]::NewGuid().ToString()
$records = @()
for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
    $submitted = (Get-Date).ToUniversalTime()
    $path = "/workspaces/$workspaceId/items/$($notebook.id)/jobs/instances?jobType=RunNotebook"
    $response = Invoke-FabricApi -Method POST -Path $path -Body @{}
    $records += [pscustomobject]@{
        POC_RunId = $runId
        Iteration = $iteration
        SubmittedUtc = $submitted.ToString("o")
        WorkspaceId = $workspaceId
        ItemId = $notebook.id
        ItemName = $notebook.displayName
        Operation = "RunNotebook"
        FabricJobInstanceId = $response.id
    }
    if ($iteration -lt $Iterations -and $DelaySeconds -gt 0) {
        Start-Sleep -Seconds $DelaySeconds
    }
}
$path = "dist\capacity-demo-$runId.csv"
$records | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $path
Write-Host "Submitted $Iterations attributable notebook operations. Evidence log: $path"
Write-Host "Wait at least 15 minutes, then follow the Capacity Metrics steps in docs\runbook.md."

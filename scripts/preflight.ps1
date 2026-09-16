[CmdletBinding()]
param(
    [string]$EnvironmentFile = ".env",
    [switch]$RequireDeploymentTools
)

. "$PSScriptRoot\Common.ps1"
Import-DotEnv -Path $EnvironmentFile

$requiredFiles = @(
    "config\poc.template.json",
    "fabric\MedallionLakehouse.Lakehouse\.platform",
    "fabric\TransformMedallion.Notebook\notebook-content.py",
    "fabric\Motorola Sales Certified.SemanticModel\definition.pbism",
    "fabric\Motorola Sales Overview.Report\definition.pbir",
    "fabric\Motorola Sales Agent.DataAgent\Files\Config\data_agent.json",
    "ai\data-agent-config.json"
)
foreach ($path in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required artifact is missing: $path"
    }
}

$jsonFiles = Get-ChildItem -Recurse -File -Include *.json
foreach ($file in $jsonFiles) {
    try {
        $null = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON: $($file.FullName): $($_.Exception.Message)"
    }
}

if ($RequireDeploymentTools) {
    $null = Get-RequiredEnvironmentValue "FABRIC_WORKSPACE_ID"
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is required. Install it and run 'az login'."
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "Python 3 is required."
    }
    & python -c "import azure.identity, fabric_cicd"
    if ($LASTEXITCODE -ne 0) {
        throw "Install official deployment dependencies: python -m pip install -r requirements-deploy.txt"
    }
    $null = Get-FabricToken
}

Write-Host "Preflight passed ($($jsonFiles.Count) JSON files validated)."

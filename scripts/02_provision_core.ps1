<#
.SYNOPSIS
    AI-103 Katas — step 2: create the Foundry resource, project, and model deployments.

.DESCRIPTION
    Creates BILLABLE resources. Reads settings from ../.env (written by
    01_connect_azure.ps1). Safe to re-run — every step is idempotent.

    Creates:
      * resource group
      * Azure AI Foundry resource (Cognitive Services kind=AIServices, S0)
      * a Foundry project
      * model deployments: gpt-4o-mini, gpt-4o, text-embedding-3-small, o4-mini
        (DataZoneStandard by default, so inference stays in the EU data zone)
      * Log Analytics workspace + Application Insights
      * RBAC: grants you Azure AI User + Cognitive Services OpenAI User

    Image and video models (gpt-image-1, sora-2) are NOT deployed here — unit 03.1
    has you create them on demand so they are not billing in the background.

.EXAMPLE
    pwsh scripts/02_provision_core.ps1
    pwsh scripts/02_provision_core.ps1 -DeploymentSku GlobalStandard
#>
[CmdletBinding()]
param(
    [switch] $SkipModels,

    # DataZoneStandard  - EU/US data-zone residency (default, matches the EU region)
    # Standard          - stays in this single region; tighter capacity
    # GlobalStandard    - worldwide routing, cheapest, NO residency guarantee
    [ValidateSet('DataZoneStandard', 'Standard', 'GlobalStandard')]
    [string] $DeploymentSku = 'DataZoneStandard'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [!]  $m" -ForegroundColor Yellow }

# --- load .env -------------------------------------------------------------
$envPath = Join-Path $root '.env'
if (-not (Test-Path $envPath)) { throw "No .env found. Run scripts/01_connect_azure.ps1 first." }

$cfg = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)$') { $cfg[$Matches[1]] = $Matches[2].Trim() }
}

$sub      = $cfg['AZURE_SUBSCRIPTION_ID']
$rg       = $cfg['AZURE_RESOURCE_GROUP']
$loc      = $cfg['AZURE_LOCATION']
$foundry  = $cfg['AZURE_AI_FOUNDRY_RESOURCE']
$project  = $cfg['AZURE_AI_PROJECT_NAME']
$laName   = $cfg['AZURE_LOG_ANALYTICS_WORKSPACE']

az account set --subscription $sub

Write-Host ''
Write-Warn 'This creates billable Azure resources. Rough cost if left running: <$1/day idle,'
Write-Warn 'plus per-token model charges. Run scripts/teardown.ps1 when you finish the course.'
$go = Read-Host 'Proceed? [y/N]'
if ($go -notmatch '^[Yy]') { Write-Host 'Aborted.'; exit 0 }

# --- resource group --------------------------------------------------------
Write-Step "Resource group $rg"
az group create --name $rg --location $loc --tags course=ai103 --output none
Write-Ok $rg

# --- Foundry resource ------------------------------------------------------
Write-Step "Foundry resource $foundry"
$exists = az cognitiveservices account show --name $foundry --resource-group $rg --output json 2>$null
if (-not $exists) {
    az cognitiveservices account create `
        --name $foundry --resource-group $rg --location $loc `
        --kind AIServices --sku S0 `
        --custom-domain $foundry `
        --assign-identity `
        --yes --output none
}
Write-Ok "$foundry (kind=AIServices, sku=S0)"

$foundryId = az cognitiveservices account show --name $foundry --resource-group $rg --query id --output tsv

# --- Foundry project -------------------------------------------------------
Write-Step "Foundry project $project"
# Projects are a sub-resource of the AIServices account. The CLI extension may not
# expose them yet, so use the REST API through `az rest`.
$apiVersion = '2025-06-01'
$projectUri = "https://management.azure.com$foundryId/projects/$project`?api-version=$apiVersion"

$projExists = az rest --method get --uri $projectUri --output json 2>$null
if (-not $projExists) {
    $body = @{ location = $loc; identity = @{ type = 'SystemAssigned' }; properties = @{
        displayName = 'AI-103 Katas'; description = 'Lab project for the AI-103 course' } } | ConvertTo-Json -Depth 5
    $tmp = New-TemporaryFile
    $body | Set-Content $tmp -Encoding utf8
    az rest --method put --uri $projectUri --body "@$tmp" --output none
    Remove-Item $tmp -Force
}
Write-Ok $project

# --- model deployments -----------------------------------------------------
if (-not $SkipModels) {
    Write-Step 'Model deployments'

    # Deployment SKU and data residency:
    #   Standard          - inference stays in THIS region
    #   DataZoneStandard  - stays within the EU (or US) data zone   <-- course default
    #   GlobalStandard    - routed worldwide, cheapest + highest throughput,
    #                       NO residency guarantee
    # The course defaults to an EU region, so DataZoneStandard is the consistent
    # choice: EU residency without the capacity limits of single-region Standard.
    # Override with -DeploymentSku GlobalStandard if you do not need residency and
    # want the cheapest per-token price. Unit 01.2 covers the trade-off.
    $sku = $DeploymentSku
    Write-Host "  SKU: $sku" -ForegroundColor Yellow
    if ($sku -eq 'GlobalStandard') {
        Write-Warn 'GlobalStandard routes inference worldwide - no data-residency guarantee.'
    }

    # capacity = thousands of tokens per minute. Keep small; raise in unit 01.3.
    $deployments = @(
        @{ name = $cfg['MODEL_MINI'];      model = 'gpt-4o-mini';            format = 'OpenAI'; sku = $sku; capacity = 30 },
        @{ name = $cfg['MODEL_CHAT'];      model = 'gpt-4o';                 format = 'OpenAI'; sku = $sku; capacity = 20 },
        @{ name = $cfg['MODEL_EMBEDDING']; model = 'text-embedding-3-small'; format = 'OpenAI'; sku = $sku; capacity = 30 },
        @{ name = $cfg['MODEL_REASONING']; model = 'o4-mini';                format = 'OpenAI'; sku = $sku; capacity = 20 }
    )

    # `az cognitiveservices account deployment create` REQUIRES --model-version.
    # Resolve the newest version each model actually offers in THIS region, rather
    # than hardcoding versions that drift (and differ per region).
    Write-Host "  Reading the $loc model catalog ..."
    $catalog = az cognitiveservices model list --location $loc --output json 2>$null | ConvertFrom-Json

    foreach ($d in $deployments) {
        $have = az cognitiveservices account deployment show `
                    --name $foundry --resource-group $rg --deployment-name $d.name --output json 2>$null
        if ($have) { Write-Ok "$($d.name) (already deployed)"; continue }

        # newest version of this model that supports the requested SKU here
        $entry = $catalog |
            Where-Object { $_.model.name -eq $d.model -and ($_.model.skus.name -contains $d.sku) } |
            Sort-Object { $_.model.version } | Select-Object -Last 1

        if (-not $entry) {
            Write-Warn "$($d.model) is not offered with SKU $($d.sku) in $loc - skipping."
            Write-Warn 'Re-run with -DeploymentSku GlobalStandard, or pick another region.'
            continue
        }
        $version = $entry.model.version

        Write-Host "  Deploying $($d.name)  ($($d.model) v$version) ..."
        az cognitiveservices account deployment create `
            --name $foundry --resource-group $rg `
            --deployment-name $d.name `
            --model-name $d.model --model-version $version `
            --model-format $d.format `
            --sku-name $d.sku --sku-capacity $d.capacity `
            --output none
        # az CLI signals failure via exit code, NOT a thrown exception - try/catch
        # here would silently report success. Always test $LASTEXITCODE.
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$($d.name)  [$($d.sku), v$version]"
        } else {
            Write-Warn "$($d.name) failed (exit $LASTEXITCODE)."
            Write-Warn 'If the SKU is unavailable here, retry with -DeploymentSku GlobalStandard.'
            Write-Warn 'Quota issues are covered in unit 01.3.'
        }
    }
}

# --- observability ---------------------------------------------------------
Write-Step 'Log Analytics + Application Insights'

$laId = az monitor log-analytics workspace show --resource-group $rg --workspace-name $laName --query id --output tsv 2>$null
if (-not $laId) {
    az monitor log-analytics workspace create --resource-group $rg --workspace-name $laName --location $loc --output none
    $laId = az monitor log-analytics workspace show --resource-group $rg --workspace-name $laName --query id --output tsv
}
Write-Ok $laName

$aiName = 'ai103-appinsights'
$aiConn = az monitor app-insights component show --app $aiName --resource-group $rg --query connectionString --output tsv 2>$null
if (-not $aiConn) {
    az extension add --name application-insights --only-show-errors 2>$null | Out-Null
    az monitor app-insights component create --app $aiName --resource-group $rg --location $loc `
        --workspace $laId --application-type web --output none
    $aiConn = az monitor app-insights component show --app $aiName --resource-group $rg --query connectionString --output tsv
}
Write-Ok $aiName

# --- RBAC ------------------------------------------------------------------
Write-Step 'Role assignments'

$me = az ad signed-in-user show --query id --output tsv 2>$null
if ($me) {
    foreach ($role in @('Azure AI User', 'Cognitive Services OpenAI User', 'Cognitive Services User')) {
        try {
            az role assignment create --assignee-object-id $me --assignee-principal-type User `
                --role $role --scope $foundryId --output none 2>$null
            Write-Ok "$role -> you"
        } catch {
            Write-Warn "Could not assign '$role'. You may already have it, or you lack User Access Administrator."
        }
    }
} else {
    Write-Warn 'Skipping RBAC — could not resolve your directory object id.'
}

# --- update .env -----------------------------------------------------------
Write-Step 'Updating .env'
$content = Get-Content $envPath -Raw
$content = $content -replace 'APPLICATIONINSIGHTS_CONNECTION_STRING=.*', "APPLICATIONINSIGHTS_CONNECTION_STRING=$aiConn"
$content | Set-Content $envPath -Encoding utf8 -NoNewline
Write-Ok 'APPLICATIONINSIGHTS_CONNECTION_STRING'

Write-Host ''
Write-Host 'Core provisioning complete.' -ForegroundColor Green
Write-Host "  Portal: https://ai.azure.com  ->  project '$project'"
Write-Host ''
Write-Host 'Next: pwsh scripts/03_provision_labs.ps1' -ForegroundColor Cyan

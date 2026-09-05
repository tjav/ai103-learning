<#
.SYNOPSIS
    AI-103 Katas — step 3: create the supporting lab resources.

.DESCRIPTION
    Creates BILLABLE resources used by the retrieval, vision, and speech units:
      * Azure AI Search (Basic tier — semantic ranker requires Basic or higher)
      * Storage account + blob containers for documents and generated media
      * a budget with an email alert
      * RBAC so Search, Foundry, and Storage can talk to each other via managed
        identity (keyless)

    Azure AI Search Basic is the single most expensive item in this course
    (~$75/month if left running). Delete it with scripts/teardown.ps1 when done,
    or pass -SkipSearch and use the free tier note in unit 05.1.

.EXAMPLE
    pwsh scripts/03_provision_labs.ps1
    pwsh scripts/03_provision_labs.ps1 -SearchSku free
#>
[CmdletBinding()]
param(
    [ValidateSet('free', 'basic', 'standard')]
    [string] $SearchSku = 'basic',
    [switch] $SkipSearch,
    [decimal] $BudgetAmount = 50
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [!]  $m" -ForegroundColor Yellow }

$envPath = Join-Path $root '.env'
if (-not (Test-Path $envPath)) { throw 'No .env found. Run scripts/01_connect_azure.ps1 first.' }

$cfg = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)$') { $cfg[$Matches[1]] = $Matches[2].Trim() }
}

$sub     = $cfg['AZURE_SUBSCRIPTION_ID']
$rg      = $cfg['AZURE_RESOURCE_GROUP']
$loc     = $cfg['AZURE_LOCATION']
$foundry = $cfg['AZURE_AI_FOUNDRY_RESOURCE']
$search  = $cfg['AZURE_SEARCH_SERVICE']
$storage = $cfg['AZURE_STORAGE_ACCOUNT']
$email   = $cfg['AZURE_BUDGET_ALERT_EMAIL']

az account set --subscription $sub

Write-Host ''
if ($SearchSku -eq 'basic' -and -not $SkipSearch) {
    Write-Warn 'Azure AI Search Basic bills ~$0.10/hour (~$75/month) whether or not you query it.'
    Write-Warn 'The free tier works for most of unit 05.1 but has no semantic ranker and one index only.'
}
$go = Read-Host 'Proceed? [y/N]'
if ($go -notmatch '^[Yy]') { Write-Host 'Aborted.'; exit 0 }

# --- storage ---------------------------------------------------------------
Write-Step "Storage account $storage"
$stExists = az storage account show --name $storage --resource-group $rg --output json 2>$null
if (-not $stExists) {
    az storage account create --name $storage --resource-group $rg --location $loc `
        --sku Standard_LRS --kind StorageV2 `
        --allow-blob-public-access false `
        --min-tls-version TLS1_2 `
        --output none
}
Write-Ok $storage

$storageId = az storage account show --name $storage --resource-group $rg --query id --output tsv
$me = az ad signed-in-user show --query id --output tsv 2>$null

# Grant yourself data-plane access so the notebooks can upload without keys.
if ($me) {
    try {
        az role assignment create --assignee-object-id $me --assignee-principal-type User `
            --role 'Storage Blob Data Contributor' --scope $storageId --output none 2>$null
        Write-Ok 'Storage Blob Data Contributor -> you'
    } catch { Write-Warn 'Could not assign Storage Blob Data Contributor (may already exist).' }
}

Write-Host '  Waiting 20s for the role assignment to propagate...'
Start-Sleep -Seconds 20

foreach ($container in @($cfg['AZURE_STORAGE_CONTAINER'], 'ai103-media', 'ai103-audio')) {
    try {
        az storage container create --name $container --account-name $storage `
            --auth-mode login --output none 2>$null
        Write-Ok "container: $container"
    } catch { Write-Warn "container '$container' — $($_.Exception.Message)" }
}

# --- Azure AI Search -------------------------------------------------------
if (-not $SkipSearch) {
    Write-Step "Azure AI Search $search ($SearchSku)"
    $srExists = az search service show --name $search --resource-group $rg --output json 2>$null
    if (-not $srExists) {
        az search service create --name $search --resource-group $rg --location $loc `
            --sku $SearchSku --partition-count 1 --replica-count 1 `
            --identity-type SystemAssigned `
            --auth-options aadOrApiKey --aad-auth-failure-mode http401WithBearerChallenge `
            --output none
    }
    Write-Ok $search

    $searchId = az search service show --name $search --resource-group $rg --query id --output tsv
    $searchMi = az search service show --name $search --resource-group $rg --query identity.principalId --output tsv

    if ($me) {
        foreach ($role in @('Search Service Contributor', 'Search Index Data Contributor')) {
            try {
                az role assignment create --assignee-object-id $me --assignee-principal-type User `
                    --role $role --scope $searchId --output none 2>$null
                Write-Ok "$role -> you"
            } catch { Write-Warn "Could not assign '$role'." }
        }
    }

    # Search's managed identity needs to read blobs (indexer) and call the
    # embedding model (integrated vectorization).
    if ($searchMi) {
        $foundryId = az cognitiveservices account show --name $foundry --resource-group $rg --query id --output tsv
        foreach ($pair in @(
            @{ role = 'Storage Blob Data Reader';       scope = $storageId },
            @{ role = 'Cognitive Services OpenAI User'; scope = $foundryId }
        )) {
            try {
                az role assignment create --assignee-object-id $searchMi --assignee-principal-type ServicePrincipal `
                    --role $pair.role --scope $pair.scope --output none 2>$null
                Write-Ok "$($pair.role) -> Search managed identity"
            } catch { Write-Warn "Could not assign '$($pair.role)' to the Search identity." }
        }
    }
} else {
    Write-Warn 'Skipping Azure AI Search. Unit 05.1 will not run until you create it.'
}

# --- Speech key ------------------------------------------------------------
# The Speech SDK still needs a key for some scenarios in unit 04.2.
Write-Step 'Speech key'
$speechKey = az cognitiveservices account keys list --name $foundry --resource-group $rg --query key1 --output tsv 2>$null
if ($speechKey) {
    $content = Get-Content $envPath -Raw
    $content = $content -replace 'AZURE_SPEECH_KEY=.*', "AZURE_SPEECH_KEY=$speechKey"
    $content | Set-Content $envPath -Encoding utf8 -NoNewline
    Write-Ok 'AZURE_SPEECH_KEY written to .env'
    Write-Warn 'This is the only key in the course. Unit 01.3 explains how to go fully keyless.'
}

# --- budget ----------------------------------------------------------------
Write-Step "Budget alert (\$$BudgetAmount)"
if (-not $email) {
    Write-Warn 'No AZURE_BUDGET_ALERT_EMAIL in .env — skipping. Create the budget by hand in 00_setup.'
} else {
    $budgetName = $cfg['AZURE_BUDGET_NAME']
    $start = (Get-Date -Day 1).ToString('yyyy-MM-01')
    $end   = (Get-Date -Day 1).AddYears(1).ToString('yyyy-MM-01')
    $uri = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Consumption/budgets/$budgetName`?api-version=2023-05-01"

    $body = @{
        properties = @{
            category      = 'Cost'
            amount        = $BudgetAmount
            timeGrain     = 'Monthly'
            timePeriod    = @{ startDate = $start; endDate = $end }
            notifications = @{
                Actual50  = @{ enabled = $true; operator = 'GreaterThan'; threshold = 50;  contactEmails = @($email); thresholdType = 'Actual' }
                Actual90  = @{ enabled = $true; operator = 'GreaterThan'; threshold = 90;  contactEmails = @($email); thresholdType = 'Actual' }
                Forecast100 = @{ enabled = $true; operator = 'GreaterThan'; threshold = 100; contactEmails = @($email); thresholdType = 'Forecasted' }
            }
        }
    } | ConvertTo-Json -Depth 8

    $tmp = New-TemporaryFile
    $body | Set-Content $tmp -Encoding utf8
    try {
        az rest --method put --uri $uri --body "@$tmp" --output none
        Write-Ok "Budget '$budgetName' — alerts at 50%, 90% actual and 100% forecast to $email"
    } catch {
        Write-Warn "Budget creation failed: $($_.Exception.Message)"
        Write-Warn 'Create it by hand — 00_setup/README.md has the portal steps.'
    }
    Remove-Item $tmp -Force
}

Write-Host ''
Write-Host 'Lab provisioning complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next: python scripts/verify_environment.py' -ForegroundColor Cyan

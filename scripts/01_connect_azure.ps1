<#
.SYNOPSIS
    AI-103 Katas — step 1: connect your Azure tenant and write .env

.DESCRIPTION
    Signs you in, lets you pick a tenant and subscription, checks the region
    supports the services this course needs, registers the required resource
    providers, and writes ai103-learning/.env.

    This script does NOT create any billable resource. Run 02_provision_core.ps1
    next.

.EXAMPLE
    pwsh scripts/01_connect_azure.ps1
    pwsh scripts/01_connect_azure.ps1 -Location swedencentral -ResourceGroup rg-ai103
#>
[CmdletBinding()]
param(
    [string] $Location      = 'swedencentral',
    [string] $ResourceGroup = 'rg-ai103-lab',
    [string] $ProjectName   = 'ai103-project',
    [string] $SubscriptionId
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $root '.env'

function Write-Step { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [!]  $m" -ForegroundColor Yellow }

# --------------------------------------------------------------------------
Write-Step 'Checking prerequisites'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI not found. Install from https://aka.ms/installazurecli then re-run.'
}
$azVersion = (az version --output json | ConvertFrom-Json).'azure-cli'
Write-Ok "Azure CLI $azVersion"
if ([version]$azVersion -lt [version]'2.60.0') {
    Write-Warn 'Azure CLI 2.60+ recommended. Run: az upgrade'
}

# --------------------------------------------------------------------------
Write-Step 'Signing in'

# `az account show` reads a cached profile and succeeds even when the refresh token
# has expired, so it is not proof that you can actually call Azure. Ask for a real
# token instead and re-login if that fails.
$account = az account show --output json 2>$null | ConvertFrom-Json
if ($account) {
    az account get-access-token --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn 'Your cached credential has expired (conditional access re-authentication).'
        $account = $null
    }
}
if (-not $account) {
    Write-Host '  Opening browser for sign-in...'
    az login --output none
    $account = az account show --output json | ConvertFrom-Json
}
Write-Ok "Signed in as $($account.user.name)"

# --------------------------------------------------------------------------
Write-Step 'Choosing a subscription'

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
} else {
    $subs = az account list --all --query "[?state=='Enabled']" --output json | ConvertFrom-Json
    if ($subs.Count -eq 0) { throw 'No enabled subscriptions found on this account.' }

    if ($subs.Count -eq 1) {
        $chosen = $subs[0]
    } else {
        Write-Host ''
        for ($i = 0; $i -lt $subs.Count; $i++) {
            $marker = if ($subs[$i].id -eq $account.id) { '*' } else { ' ' }
            Write-Host ("  [{0}]{1} {2}  ({3})" -f $i, $marker, $subs[$i].name, $subs[$i].id)
        }
        Write-Host ''
        do {
            $sel = Read-Host "Select a subscription [0-$($subs.Count - 1)]"
        } until ($sel -match '^\d+$' -and [int]$sel -lt $subs.Count)
        $chosen = $subs[[int]$sel]
    }
    az account set --subscription $chosen.id
    $SubscriptionId = $chosen.id
}

$account = az account show --output json | ConvertFrom-Json
$SubscriptionId = $account.id
$TenantId       = $account.tenantId
Write-Ok "Subscription: $($account.name)"
Write-Ok "Tenant:       $TenantId"

# --------------------------------------------------------------------------
Write-Step 'Checking your permissions'

$signedInId = az ad signed-in-user show --query id --output tsv 2>$null
if ($signedInId) {
    $roles = az role assignment list --assignee $signedInId `
                --scope "/subscriptions/$SubscriptionId" `
                --include-inherited --query "[].roleDefinitionName" --output json 2>$null | ConvertFrom-Json
    $roleList = ($roles -join ', ')
    Write-Ok "Roles on this subscription: $roleList"

    $canWrite  = $roles -contains 'Owner' -or $roles -contains 'Contributor'
    $canAssign = $roles -contains 'Owner' -or $roles -contains 'User Access Administrator'

    if (-not $canWrite)  { Write-Warn 'You need Owner or Contributor to create the lab resources.' }
    if (-not $canAssign) { Write-Warn 'You need Owner or User Access Administrator to complete the RBAC labs in unit 01.3.' }
} else {
    Write-Warn 'Could not read your directory object (common with guest accounts). Skipping the role check.'
}

# --------------------------------------------------------------------------
Write-Step "Validating region '$Location'"

$regionOk = az account list-locations --query "[?name=='$Location'].name" --output tsv
if (-not $regionOk) { throw "'$Location' is not a valid Azure region for this subscription." }

# The models this course deploys, and the SKU each lab expects.
$requiredModels = @(
    @{ name = 'gpt-4o';                 note = 'chat + vision (units 02.x, 03.2)' },
    @{ name = 'gpt-4o-mini';            note = 'cheap chat (most labs)' },
    @{ name = 'text-embedding-3-small'; note = 'vector search (units 02.2, 05.1)' },
    @{ name = 'o4-mini';                note = 'reasoning (unit 02.5)' },
    @{ name = 'gpt-image-1';            note = 'image generation + editing (unit 03.1)' },
    @{ name = 'sora-2';                 note = 'video generation (unit 03.1)' }
)

Write-Host '  Querying model availability (this takes a moment)...'
$available = az cognitiveservices model list --location $Location --output json 2>$null | ConvertFrom-Json
$availableNames = @($available | ForEach-Object { $_.model.name } | Sort-Object -Unique)

$missing = @()
foreach ($m in $requiredModels) {
    if ($availableNames -contains $m.name) {
        Write-Ok "$($m.name) — $($m.note)"
    } else {
        Write-Warn "$($m.name) NOT available in $Location — $($m.note)"
        $missing += $m.name
    }
}

if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Warn "$($missing.Count) model(s) unavailable in '$Location'."
    Write-Host '  EU regions with the broadest coverage: swedencentral (all course models),'
    Write-Host '  then polandcentral. Non-EU fallback: eastus2, westus3.'
    Write-Host '  You can continue — the affected unit READMEs explain the alternatives.'
    $go = Read-Host '  Continue with this region anyway? [y/N]'
    if ($go -notmatch '^[Yy]') { throw 'Aborted. Re-run with -Location <region>.' }
}

# --------------------------------------------------------------------------
Write-Step 'Registering resource providers'

$providers = @(
    'Microsoft.CognitiveServices',   # Foundry / AI Services
    'Microsoft.Search',              # Azure AI Search
    'Microsoft.Storage',             # blobs for RAG + generated media
    'Microsoft.OperationalInsights', # Log Analytics
    'Microsoft.Insights',            # Application Insights
    'Microsoft.KeyVault',
    'Microsoft.Consumption'          # budgets
)
foreach ($p in $providers) {
    $state = az provider show --namespace $p --query registrationState --output tsv 2>$null
    if ($state -ne 'Registered') {
        Write-Host "  Registering $p ..."
        az provider register --namespace $p --output none
    }
    Write-Ok "$p"
}
Write-Warn 'Registration can take a few minutes to finish in the background. That is fine.'

# --------------------------------------------------------------------------
Write-Step 'Writing .env'

# Names must be globally unique; derive a stable suffix from the subscription id.
$suffix = ($SubscriptionId -replace '[^0-9a-f]', '').Substring(0, 6)
$foundryResource = "ai103foundry$suffix"
$searchService   = "ai103search$suffix"
$storageAccount  = "ai103stor$suffix"

$projectEndpoint   = "https://$foundryResource.services.ai.azure.com/api/projects/$ProjectName"
$inferenceEndpoint = "https://$foundryResource.services.ai.azure.com"

if (Test-Path $envPath) {
    $backup = "$envPath.bak"
    Copy-Item $envPath $backup -Force
    Write-Warn "Existing .env backed up to $(Split-Path -Leaf $backup)"
}

$budgetEmail = if ($account.user.name -match '@') { $account.user.name } else { '' }

@"
# Generated by scripts/01_connect_azure.ps1 on $(Get-Date -Format 'u')
# Do not commit this file.

# --- Subscription / tenant ---
AZURE_TENANT_ID=$TenantId
AZURE_SUBSCRIPTION_ID=$SubscriptionId
AZURE_RESOURCE_GROUP=$ResourceGroup
AZURE_LOCATION=$Location

# --- Foundry ---
AZURE_AI_FOUNDRY_RESOURCE=$foundryResource
AZURE_AI_PROJECT_NAME=$ProjectName
AZURE_AI_PROJECT_ENDPOINT=$projectEndpoint
AZURE_AI_INFERENCE_ENDPOINT=$inferenceEndpoint
AZURE_OPENAI_ENDPOINT=$inferenceEndpoint
AZURE_OPENAI_API_VERSION=2025-04-01-preview

# --- Model deployment names ---
MODEL_CHAT=gpt-4o
MODEL_MINI=gpt-4o-mini
MODEL_REASONING=o4-mini
MODEL_EMBEDDING=text-embedding-3-small
MODEL_IMAGE=gpt-image-1
MODEL_VIDEO=sora-2

# --- Azure AI Search ---
AZURE_SEARCH_SERVICE=$searchService
AZURE_SEARCH_ENDPOINT=https://$searchService.search.windows.net
AZURE_SEARCH_INDEX=ai103-index

# --- Storage ---
AZURE_STORAGE_ACCOUNT=$storageAccount
AZURE_STORAGE_BLOB_ENDPOINT=https://$storageAccount.blob.core.windows.net
AZURE_STORAGE_CONTAINER=ai103-docs

# --- Foundry Tools (share the AI Services endpoint) ---
AZURE_LANGUAGE_ENDPOINT=$inferenceEndpoint
AZURE_CONTENT_UNDERSTANDING_ENDPOINT=$inferenceEndpoint
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT=$inferenceEndpoint
AZURE_CONTENT_SAFETY_ENDPOINT=$inferenceEndpoint
AZURE_TRANSLATOR_ENDPOINT=https://api.cognitive.microsofttranslator.com
AZURE_TRANSLATOR_REGION=$Location
AZURE_SPEECH_REGION=$Location
AZURE_SPEECH_KEY=

# --- Observability ---
APPLICATIONINSIGHTS_CONNECTION_STRING=
AZURE_LOG_ANALYTICS_WORKSPACE=ai103-logs

# --- Cost guard ---
AZURE_BUDGET_NAME=ai103-budget
AZURE_BUDGET_AMOUNT=50
AZURE_BUDGET_ALERT_EMAIL=$budgetEmail
"@ | Set-Content -Path $envPath -Encoding utf8

Write-Ok ".env written to $envPath"

# --------------------------------------------------------------------------
Write-Host ''
Write-Host 'Connected.' -ForegroundColor Green
Write-Host ''
Write-Host '  Subscription : ' -NoNewline; Write-Host $account.name
Write-Host '  Region       : ' -NoNewline; Write-Host $Location
Write-Host '  Resource grp : ' -NoNewline; Write-Host $ResourceGroup  -NoNewline; Write-Host '  (not created yet)'
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  Portal path  -> open 00_setup/README.md and create the project by hand (recommended)'
Write-Host '  Script path  -> pwsh scripts/02_provision_core.ps1'
Write-Host ''

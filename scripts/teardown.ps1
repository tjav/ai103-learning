<#
.SYNOPSIS
    AI-103 Katas — delete everything this course created.

.DESCRIPTION
    Deletes the lab resource group and purges the soft-deleted Foundry account.

    Purging matters: Cognitive Services accounts are soft-deleted for 48 hours,
    and the name stays reserved. If you re-run the provisioning scripts without
    purging, creation fails with "the account name is already in use".

.EXAMPLE
    pwsh scripts/teardown.ps1
    pwsh scripts/teardown.ps1 -Force -NoWait
#>
[CmdletBinding()]
param(
    [switch] $Force,
    [switch] $NoWait,
    [switch] $KeepResourceGroup
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Write-Step { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [!]  $m" -ForegroundColor Yellow }

$envPath = Join-Path $root '.env'
if (-not (Test-Path $envPath)) { throw 'No .env found — nothing to tear down (or you moved it).' }

$cfg = @{}
Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.*)$') { $cfg[$Matches[1]] = $Matches[2].Trim() }
}

$sub     = $cfg['AZURE_SUBSCRIPTION_ID']
$rg      = $cfg['AZURE_RESOURCE_GROUP']
$loc     = $cfg['AZURE_LOCATION']
$foundry = $cfg['AZURE_AI_FOUNDRY_RESOURCE']

az account set --subscription $sub
$subName = az account show --query name --output tsv

# --- show what will die ----------------------------------------------------
Write-Step "Resources in $rg"

$exists = az group exists --name $rg --output tsv
if ($exists -ne 'true') {
    Write-Warn "Resource group '$rg' does not exist."
} else {
    az resource list --resource-group $rg --query "[].{Name:name, Type:type}" --output table
}

Write-Host ''
Write-Host "  Subscription   : $subName" -ForegroundColor Yellow
Write-Host "  Resource group : $rg"       -ForegroundColor Yellow
Write-Host ''
Write-Warn 'This is irreversible. All lab data, indexes, agents, and deployments will be lost.'

if (-not $Force) {
    $confirm = Read-Host "Type the resource group name to confirm deletion"
    if ($confirm -ne $rg) { Write-Host 'Aborted.'; exit 0 }
}

# --- delete ----------------------------------------------------------------
if (-not $KeepResourceGroup -and $exists -eq 'true') {
    Write-Step "Deleting resource group $rg"
    if ($NoWait) {
        az group delete --name $rg --yes --no-wait --output none
        Write-Ok 'Delete started in the background.'
        Write-Warn 'Run this script again later (or purge by hand) to release the Foundry name.'
        exit 0
    }
    Write-Host '  This usually takes 5-15 minutes...'
    az group delete --name $rg --yes --output none
    Write-Ok "$rg deleted"
}

# --- purge the soft-deleted Cognitive Services account ---------------------
Write-Step 'Purging soft-deleted Foundry account'

$deleted = az cognitiveservices account list-deleted --output json 2>$null | ConvertFrom-Json
$target = $deleted | Where-Object { $_.name -eq $foundry }

if ($target) {
    try {
        az cognitiveservices account purge --name $foundry --resource-group $rg --location $loc --output none
        Write-Ok "$foundry purged — the name is free again"
    } catch {
        Write-Warn "Purge failed: $($_.Exception.Message)"
        Write-Warn "Purge by hand: az cognitiveservices account purge -n $foundry -g $rg -l $loc"
    }
} else {
    Write-Ok 'Nothing to purge.'
}

# --- local cleanup ---------------------------------------------------------
Write-Step 'Local files'
Write-Warn "Your .env still points at deleted resources. Delete it, or re-run"
Write-Warn 'scripts/01_connect_azure.ps1 if you want to start the course again.'

Write-Host ''
Write-Host 'Teardown complete. Check the Cost Analysis blade tomorrow to confirm spend stopped.' -ForegroundColor Green

# 99 — Tear down your lab

**Do this the moment you stop using the environment.** Most of what this course
creates is consumption-priced and costs nothing while idle — but not all of it, and
the exceptions are the expensive ones.

**Time:** 10–20 minutes, mostly waiting.

---

## What actually bills while you are not looking

| Resource | Idle cost | Notes |
|---|---|---|
| **Provisioned (PTU) deployment** | **High, per hour** | If you created one in 01.2, delete it *now* |
| **Fine-tuned model deployment** | **Per hour while deployed** | Bills even with zero calls |
| **Azure AI Search** (Basic / Standard) | **Per hour** | Free tier is free, but you may have moved off it |
| Storage account | Small, per GB | Blobs, indexed documents, generated media |
| Application Insights / Log Analytics | Per GB ingested + retention | Traces from 02.5 add up |
| Foundry resource + standard deployments | **Zero when idle** | Token-priced only |
| Content Safety, Language, Translator, Speech | **Zero when idle** | Consumption-priced |
| Agents, threads, vector stores | Storage-priced, small | File Search vector stores do bill |

The three lines in bold are the ones that turn a forgotten lab into a real bill.

---

## The fast path

```powershell
cd ai103-learning
pwsh scripts/teardown.ps1
```

The script:

1. Reads `.env` and switches to the right subscription.
2. **Lists every resource** in the group and shows you the subscription name.
3. Asks you to type the resource group name to confirm.
4. Deletes the resource group.
5. **Purges the soft-deleted Foundry account** — see below, this step matters.
6. Reminds you that `.env` now points at nothing.

Options:

```powershell
pwsh scripts/teardown.ps1 -Force              # skip the confirmation prompt
pwsh scripts/teardown.ps1 -NoWait             # start the delete and return immediately
pwsh scripts/teardown.ps1 -KeepResourceGroup  # purge only; leave the RG in place
```

If you use `-NoWait`, **run the script again later**. The purge in step 5 cannot run
until the delete finishes.

---

## Why purging matters

Cognitive Services accounts — which is what a Foundry resource is — are
**soft-deleted for 48 hours**, and the name stays reserved for the whole window.
Delete the resource group without purging and re-running `02_provision_core.ps1`
fails with *"the account name is already in use"* on a name that appears nowhere in
the portal.

Check and purge by hand:

```powershell
az cognitiveservices account list-deleted -o table

az cognitiveservices account purge `
    --name  $env:AZURE_AI_FOUNDRY_RESOURCE `
    --resource-group $env:AZURE_RESOURCE_GROUP `
    --location $env:AZURE_LOCATION
```

The same soft-delete behaviour applies to Key Vault if you created one.

---

## Portal path

If you would rather see it happen:

1. **portal.azure.com** → **Resource groups** → `rg-ai103-lab`.
2. Click **Delete resource group**, type the name, confirm.
3. Then **Azure AI Foundry** (or Cognitive Services) → **Manage deleted
   resources** → select your resource → **Purge**.
4. **Cost Management + Billing** → **Cost analysis** → scope to the subscription,
   group by **Resource group**, and confirm `rg-ai103-lab` stops accruing tomorrow.

Costs lag by up to 24 hours, so today's graph will still show yesterday's spend.
That is not a failed teardown.

---

## Keeping the lab, cutting the cost

Want to come back next week without paying for the gap? Delete only the hourly
things and leave the rest:

```powershell
# 1. Any provisioned or fine-tuned deployment (the real money)
az cognitiveservices account deployment list `
    -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
    --query "[].{name:name, sku:sku.name, capacity:sku.capacity}" -o table

az cognitiveservices account deployment delete `
    -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
    --deployment-name <name>

# 2. Azure AI Search, if you are not on the free tier
az search service show -n $env:AZURE_SEARCH_SERVICE -g $env:AZURE_RESOURCE_GROUP `
    --query "sku.name" -o tsv
az search service delete -n $env:AZURE_SEARCH_SERVICE -g $env:AZURE_RESOURCE_GROUP --yes

# 3. Trim Log Analytics retention
az monitor log-analytics workspace update `
    -n $env:AZURE_LOG_ANALYTICS_WORKSPACE -g $env:AZURE_RESOURCE_GROUP `
    --retention-time 30
```

Standard token-priced deployments, the Foundry resource itself, and every
consumption-priced Foundry Tool can stay. They cost nothing until you call them.

Re-run `scripts/03_provision_labs.ps1` when you come back to recreate Search and
friends.

---

## Verify it is really gone

```powershell
# Should print false
az group exists --name $env:AZURE_RESOURCE_GROUP

# Should be empty
az cognitiveservices account list-deleted -o table

# Nothing left anywhere carrying the course tag
az resource list --tag project=ai103 -o table
```

Then remove the local artefacts:

```powershell
Remove-Item ai103-learning/.env
Get-ChildItem ai103-learning -Recurse -Directory -Filter lab_output | Remove-Item -Recurse -Force
```

Your progress in `ai103-learning.json`, the notebooks, and the quizzes all stay —
none of that depends on Azure.

---

## Starting over

```powershell
pwsh scripts/01_connect_azure.ps1
pwsh scripts/02_provision_core.ps1
pwsh scripts/03_provision_labs.ps1
python scripts/verify_environment.py
```

If `02_` fails on a name collision, the purge did not happen. Go back to
[Why purging matters](#why-purging-matters).

---

## Before you close the course

- [ ] Resource group deleted, Foundry account purged
- [ ] Budget alert from `00_setup` reviewed — it will now report near-zero
- [ ] [90 — Study guide summary](../90_summary/README.md) read end to end
- [ ] [91 — Cheat sheet](../91_cheatsheet/CHEATSHEET.md) printed
- [ ] Practice assessment taken on
      [AI Skills Navigator](https://aiskillsnavigator.microsoft.com/)
- [ ] Exam booked

Good luck.

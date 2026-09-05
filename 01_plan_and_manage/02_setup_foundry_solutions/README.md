# 02 — Set up AI solutions in Foundry

**Time:** 90–120 minutes · **Cost:** a few cents — the lab creates one
`GlobalStandard` deployment and one agent, both consumption-priced, and deletes
both. Nothing here bills by the hour **unless you deploy the provisioned example**,
which this unit deliberately never does.

Unit 01.1 chose the services. This unit builds the thing that holds them: the
resource topology, the deployments, the identity model, and the pipeline that
reproduces all of it from a repository instead of from somebody's memory of which
buttons they clicked.

By the end you will have:

- [ ] A topology you can draw from memory: subscription → resource group → Foundry resource → project → deployment
- [ ] A defensible answer to "which deployment type" for any scenario the exam throws at you
- [ ] A model deployment created, resized in place, and deleted from code
- [ ] An agent deployed from a version-controlled JSON definition
- [ ] A Bicep template that provisions the resource, project, and deployments
- [ ] An `azure.yaml` with a `postprovision` hook that creates the data-plane objects Bicep cannot
- [ ] A GitHub Actions workflow using OIDC federated credentials, a `what-if` diff, and an evaluation gate before production

---

## Concepts

### 1. Design Azure infrastructure for AI apps and agent-based solutions

#### The object model, and where each decision lives

```
Azure subscription                     ← quota lives here (per region, per model family)
└── Resource group  rg-ai103-lab       ← lifecycle and RBAC boundary; teardown unit
    ├── Azure AI Foundry resource      ← Microsoft.CognitiveServices/accounts, kind=AIServices
    │   │                                identity · networking · keys · custom subdomain
    │   ├── Project  ai103-project     ← Microsoft.CognitiveServices/accounts/projects
    │   │                                agents · indexes · evaluations · connections · traces
    │   └── Deployments                ← accounts/deployments — name, model, version, SKU, capacity
    ├── Azure AI Search                ← hourly billed. A connection, not a child
    ├── Storage account                ← documents, images, evaluation datasets
    ├── Key Vault                      ← third-party secrets only; Azure-to-Azure should be keyless
    ├── Application Insights           ← traces, token analytics (unit 01.3 / 02.5)
    └── Log Analytics workspace        ← diagnostic settings sink
```

The single most useful sentence about this diagram: **everything above the project
line is control plane (ARM), everything inside the project is data plane (service
endpoints).** That one distinction explains why Bicep cannot create an agent, why a
Contributor service principal gets a 403 halfway through your pipeline, and why
`azd` needs a `postprovision` hook. It is also, in one form or another, three or
four questions on the exam.

| Plane | Reached via | Created by | Typical role |
|---|---|---|---|
| **Control** | `management.azure.com` | ARM / Bicep / `az` / `azure-mgmt-*` | Cognitive Services Contributor |
| **Data** | `<resource>.services.ai.azure.com` | SDK / REST / portal / a deploy script | Foundry User (was *Azure AI User*), Cognitive Services OpenAI User |

#### How many resources, how many projects?

| Situation | Shape | Why |
|---|---|---|
| One team, one product | One resource, one project per environment | Simplest thing that gives you dev/prod isolation |
| Several teams sharing a subscription | One resource, one project per team | Projects isolate agents, indexes, connections, and traces |
| Teams that must not see each other's data or spend | **Separate resources**, ideally separate resource groups | RBAC and diagnostic settings live on the resource, not the project |
| A model is unavailable in your primary region | A second Foundry resource in another region, connected to the project | Model availability is per region and does not follow your resource |
| You have exhausted quota in a region | Same — a second resource in a second region | Quota is per subscription **per region** |
| Users in another geography complain about latency | Same, plus routing in front | |

> **Exam note.** Adding a region solves *availability, quota, and latency*. It does
> **not** solve *RBAC isolation* — a second region widens the surface you have to
> secure. Isolation is a separate project or a separate resource.

#### Environments

Use **separate resource groups per environment**, not separate resource groups per
component. `rg-ai103-dev`, `rg-ai103-prod`. It gives you one place to delete, one
scope for RBAC, one scope for budgets, and one scope for policy. The alternative —
one resource group with `-dev` and `-prod` suffixes on every resource — makes every
one of those four things harder and buys nothing.

#### Networking and identity, in the shape they appear in a template

Four account properties carry most of the security posture. Unit 01.3 configures
them properly; know what they mean before you get there.

| Property | Effect | Exam angle |
|---|---|---|
| `customSubDomainName` | Gives the account a unique hostname | **Required for Entra ID token auth**, and **cannot be added after creation** |
| `disableLocalAuth: true` | Rejects API keys entirely | This is what actually enforces "keyless credentials" — not your client code |
| `publicNetworkAccess: 'Disabled'` | Only private endpoints reach the account | Combine with a private endpoint + private DNS zone, or nothing can call it |
| `networkAcls.ipRules` | Firewall allow-list | The narrow escape hatch for an operator when public access is `Enabled` but restricted |
| `identity.type: 'SystemAssigned'` | Gives the account a principal | How the account reads your Storage container without a connection string |

> **Exam note.** "Owner" does not defeat a network block. Authorisation and
> reachability are different axes; a question that offers a role assignment as the
> fix for a `publicNetworkAccess: Disabled` problem is testing exactly that.

---

### 2. Choose appropriate deployment options

#### First fork: serverless API vs managed compute

Before you pick a SKU, pick a hosting model. The catalogue offers both and they
bill on completely different axes.

| | **Serverless API** (standard / global / data-zone / provisioned) | **Managed compute** |
|---|---|---|
| What it is | Microsoft-hosted endpoint, you call a deployment name | The model running on VMs in your workspace |
| Billing | Per token (or per hour for PTU) | **Per VM-hour, always on** |
| Scales to zero | Yes, for the pay-per-token types | **No** |
| Models | Azure OpenAI + partner models offered as a service | Almost anything in the catalogue, including open-weights |
| Network | Public endpoint or private endpoint on the resource | Inside your VNet |
| Custom code | No | Yes — custom scoring script, custom container |
| Project type | Foundry project | **Hub-based project** |

> **Exam note.** The reason *not* to use managed compute in dev is not capability,
> it is that it bills per VM-hour and does not scale to zero. An idle dev endpoint
> costs the same as a busy one. This is the single most reliable "forgotten
> resource" invoice in Azure AI.

#### Second fork: which serverless deployment type

| Type | SKU name | Data residency | Billing | Latency / throughput | Choose when |
|---|---|---|---|---|---|
| **Standard** | `Standard` | Processed **only in the resource's region** | Per token | Best-effort; lowest quota | Residency is a hard requirement and one region's capacity is enough |
| **Global Standard** | `GlobalStandard` | Routed to **any** region with capacity | Per token | Best availability, highest quota | The default. Best choice unless residency says otherwise |
| **Data Zone Standard** | `DataZoneStandard` | Within a **geography** (EU or US) | Per token | Between the two above | Regional compliance *and* more capacity than one region supplies |
| **Provisioned (PTU)** | `ProvisionedManaged` / `GlobalProvisionedManaged` / `DataZoneProvisionedManaged` | Per the variant | **Per hour, from creation** | Reserved throughput, predictable latency | Sustained high volume with a latency SLO |
| **Batch** | `GlobalBatch` / `DataZoneBatch` | Per the variant | ~50% of the per-token price | Async, 24-hour completion target | Bulk offline work with no interactive user |

Reading the table the way the exam asks you to:

- The word **"residency"**, "must not leave the EU", "sovereignty" → `Standard`
  if one region suffices, `DataZoneStandard` if it does not. Never `Global*`.
- The words **"predictable latency"**, "guaranteed throughput", "no 429s under
  load" → provisioned. Accept the hourly bill; that is the trade.
- The words **"overnight"**, "nightly classification of 2 million records",
  "cost is the priority, latency is not" → batch.
- Anything else → `GlobalStandard`.

> **Exam note.** Three details get tested independently of the table. (1) Quota is
> a **per-subscription, per-region, per-model-family ceiling in TPM**, not a
> reservation — holding it costs nothing but denies it to your colleagues.
> (2) Exceeding quota fails at **deployment time with a 400 `InsufficientQuota`**;
> exceeding your deployment's rate at runtime returns **429 with `Retry-After`**.
> Different failures, different fixes. (3) Provisioned capacity is measured in
> **PTUs with a minimum purchase**, so "just try provisioned in dev" is a
> four-figure mistake.

#### Third fork: version upgrade policy

| `versionUpgradeOption` | Behaviour | Use when |
|---|---|---|
| `OnceNewDefaultVersionAvailable` | Moves as soon as Azure changes the default | Dev, and prod that is covered by a regression evaluation |
| `OnceCurrentVersionExpired` | Holds the pinned version until Azure retires it, then moves | **The production default.** Stability without falling off a cliff |
| `NoAutoUpgrade` | Never moves | Short-term pinning during an investigation |

> **Exam note.** `NoAutoUpgrade` is the trap. Model versions are retired on a
> **published schedule**, so pinning does not buy permanent stability — it converts
> a gradual quality risk into a sudden outage at a date Microsoft chose. The
> production stance is `OnceCurrentVersionExpired` **plus a regression evaluation
> in the pipeline**.

---

### 3. Configure model and agent deployments

#### The deployment name is the contract

Callers pass a **deployment name**, never a model name:

```python
chat_client().chat.completions.create(model="gpt-4o-mini", ...)   # deployment name
```

Behind that name, the model, version, SKU, capacity, and content filter are all
implementation detail you can change without touching a single caller. That
decoupling is what makes canary and blue/green model rollouts possible: deploy the
new version under a second name, move a fraction of traffic, swap, delete.

Capacity is a **mutable property**. Reducing a deployment's TPM is a PATCH — same
name, same endpoint, no downtime. Deleting and recreating is the wrong answer and
is offered as a distractor constantly.

Everything a model deployment carries:

| Setting | Notes |
|---|---|
| Deployment name | The contract. Choose it deliberately |
| Model + format + version | `format` is `OpenAI` for Azure OpenAI models |
| SKU name + capacity | Capacity is thousands of TPM for the `*Standard` SKUs, PTUs for provisioned |
| `versionUpgradeOption` | See above |
| `raiPolicyName` | The content filter. Per deployment, not per resource |
| `dynamicThrottlingEnabled` | Lets Azure borrow idle capacity across the account under burst |

#### Agents are data-plane objects, and that changes how you deploy them

Bicep **cannot create an agent**. Nor a search index, nor an evaluation, nor a
project connection's data. Those exist only behind the project endpoint. So an
agent deployment is a two-phase thing:

```
phase 1  ARM/Bicep      resource, project, model deployments, RBAC, networking
phase 2  deploy script  agents, indexes, connections tested, evaluations run
```

The pattern to remember, and the one the lab builds:

1. The agent's configuration is **data** — a JSON file in the repository, reviewed
   in a pull request like any other change.
2. A generic, idempotent script applies it after provisioning. Only the JSON
   differs between environments.
3. Idempotency keys on the agent **id**, persisted in durable state — *not* on the
   name. Agent names are display labels and Foundry will happily hold three agents
   called `support-agent`. Name-matching survives until the first partial failure,
   after which your "update" silently edits an arbitrary one of them.

```jsonc
// agents/support-agent.json — diffable, reviewable, promotable
{
  "name": "support-agent",
  "model": "gpt-4o-mini",          // a DEPLOYMENT name, not a model name
  "instructions": "You answer questions about order status. Refuse anything else.",
  "temperature": 0.2,
  "tools": [],
  "tool_resources": {}
}
```

What an agent deployment actually needs configured, beyond the JSON:

| Concern | Where it is set | Note |
|---|---|---|
| Which model | `model` in the definition | A deployment name in *that* project |
| Tool permissions | `tools` + `tool_resources` | Least privilege: an agent cannot misuse a tool it does not have |
| Knowledge | A project **connection** (Search, Storage) referenced by a tool | The connection is ARM; the tool wiring is data plane |
| Content filter | The `raiPolicyName` on the underlying model deployment | Agents inherit the deployment's filter |
| Identity to the outside world | The project's managed identity | Not the caller's identity — this trips people up in unit 01.3 |

---

### 4. Integrate Foundry projects with CI/CD pipelines

#### What goes in the repository

```
infra/
  main.bicep              resource, project, deployments, diagnostics, RBAC
  main.parameters.json    per-environment values
agents/
  support-agent.json      the agent definition, reviewed in PRs
evals/
  regression.jsonl        the dataset the promotion gate runs against
scripts/
  deploy_agents.py        idempotent data-plane apply
azure.yaml                azd: services + hooks
.github/workflows/
  deploy.yml              OIDC login → what-if → provision → data plane → evaluate
```

#### The Bicep

This is a real template. It provisions the account with keyless auth enforced, a
project, and two deployments — and it contains the one non-obvious thing that
catches everybody, which is the `dependsOn` between the two deployments.

```bicep
targetScope = 'resourceGroup'

@description('Short environment name. Drives SKU choices.')
@allowed(['dev', 'test', 'prod'])
param environmentName string = 'dev'

@description('Globally unique name for the Foundry (AIServices) account.')
param foundryName string

param projectName string = 'ai103-project'
param location string = resourceGroup().location

// Production gets more headroom. Note that this stays on a per-token SKU:
// switching prod to ProvisionedManaged here would start an hourly bill the
// moment somebody ran the pipeline. See the exam note below.
var chatCapacity = environmentName == 'prod' ? 50 : 10

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    // Required for Microsoft Entra ID token auth. CANNOT be changed later.
    customSubDomainName: foundryName
    // This is what actually enforces keyless access. Client code choosing not
    // to use a key is not enforcement.
    disableLocalAuth: true
    publicNetworkAccess: environmentName == 'prod' ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: environmentName == 'prod' ? 'Deny' : 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: projectName
    description: 'AI-103 katas project'
  }
}

resource chat 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: 'gpt-4o-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: chatCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

resource embedding 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: 'text-embedding-3-small'
  sku: {
    name: 'Standard'
    capacity: 30
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
  }
  // NOT optional. Azure rejects concurrent create/update operations against
  // deployments on the same account, and Bicep parallelises independent
  // resources by default. Without this the second deployment fails
  // intermittently with a conflict — the classic "works on the retry" bug.
  dependsOn: [ chat ]
}

output foundryEndpoint string = foundry.properties.endpoint
output projectEndpoint string = 'https://${foundryName}.services.ai.azure.com/api/projects/${projectName}'
output foundryPrincipalId string = foundry.identity.principalId
```

> **Exam note.** Serialising deployments with `dependsOn` is a genuine platform
> constraint, not a style preference. An ARM deployment that creates two model
> deployments on one account and "fails intermittently" has exactly one right
> answer, and it is this.

> **Exam note.** A `param environmentName` that selects `ProvisionedManaged` for
> prod is a legitimate pattern and a loaded gun. One mistyped parameter provisions
> reserved capacity that bills from creation whether or not a token flows. Contain
> it the way you contain any destructive parameter: a GitHub Environment with
> required reviewers on the prod job, a mandatory `what-if` diff in the pull
> request, and an Azure Policy denying `ProvisionedManaged` outside the production
> resource group.

#### The `azd` layer

`azd` is not required — `az deployment group create` plus a Python script is a
complete pipeline. What `azd` adds is an environment abstraction and, critically,
**hooks**, which is where the data plane gets handled.

```yaml
# azure.yaml
name: ai103-solution
metadata:
  template: ai103-katas@1.0.0

infra:
  provider: bicep
  path: infra
  module: main

services:
  api:
    project: ./src/api
    language: python
    host: containerapp

hooks:
  postprovision:
    # Runs AFTER ARM finishes — the first moment the project endpoint exists.
    # This is where agents, indexes, and connections get created.
    posix:
      shell: sh
      run: python scripts/deploy_agents.py --definition agents/support-agent.json
    windows:
      shell: pwsh
      run: python scripts/deploy_agents.py --definition agents/support-agent.json
```

`azd up` = `provision` (ARM) + `deploy` (your app code) + hooks in between.
`azd env set` / `azd env get-values` carry the outputs of the Bicep — endpoints,
deployment names — into the hook and into your app's environment without you
copying strings around.

> **Exam note.** `postprovision` exists precisely because ARM cannot create
> data-plane artefacts. If a question asks what a `postprovision` hook is for in a
> Foundry solution, the answer is "creating agents, indexes, and other objects
> behind the project endpoint" — not building images (that is `services`) and not
> `what-if` (that runs before provisioning).

#### Identity for the pipeline: OIDC federated credentials

Do not put a client secret in GitHub. A federated credential lets GitHub's OIDC
token be exchanged for an Azure token, so there is no secret to rotate or leak.

```powershell
$APP = az ad app create --display-name "gh-ai103-deploy" --query appId -o tsv
az ad sp create --id $APP
$SP  = az ad sp show --id $APP --query id -o tsv
$RG  = az group show -n rg-ai103-prod --query id -o tsv

# Control plane: create and update deployments
az role assignment create --assignee-object-id $SP --assignee-principal-type ServicePrincipal `
    --role "Cognitive Services Contributor" --scope $RG

# Data plane: create agents, run evaluations. Contributor does NOT cover this.
az role assignment create --assignee-object-id $SP --assignee-principal-type ServicePrincipal `
    --role "Azure AI User" --scope $RG

# One federated credential PER SUBJECT. These are different subjects and you
# usually need more than one.
az ad app federated-credential create --id $APP --parameters '{
  "name": "gh-main-branch",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:my-org/ai103-solution:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id $APP --parameters '{
  "name": "gh-env-prod",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:my-org/ai103-solution:environment:prod",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

| Job trigger | Subject string |
|---|---|
| Push to a branch | `repo:<org>/<repo>:ref:refs/heads/main` |
| Tag | `repo:<org>/<repo>:ref:refs/tags/v1.0.0` |
| Pull request | `repo:<org>/<repo>:pull_request` |
| Job bound to a GitHub Environment | `repo:<org>/<repo>:environment:prod` |

> **Exam note.** `AADSTS700213: No matching federated identity record found` means
> the **subject did not match** — almost always because the job runs under
> `environment: prod` while the credential was registered for a branch ref. A
> missing `permissions: id-token: write` produces a *different* failure: no token
> is requested at all. Learn to tell those two apart.

#### The workflow

```yaml
# .github/workflows/deploy.yml
name: deploy-foundry

on:
  push:
    branches: [main]
  pull_request:

permissions:
  id-token: write      # required to request the OIDC token
  contents: read

env:
  AZURE_RESOURCE_GROUP: rg-ai103-prod
  FOUNDRY_NAME: ai103foundryprod

jobs:
  # ---------------------------------------------------------------------
  # Every pull request gets a rendered diff of what ARM would change.
  # No approvals, no writes.
  # ---------------------------------------------------------------------
  what-if:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Preview infrastructure changes
        run: |
          az deployment group what-if \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --template-file infra/main.bicep \
            --parameters environmentName=prod foundryName="$FOUNDRY_NAME" \
            --result-format FullResourcePayloads

  # ---------------------------------------------------------------------
  # Provision, then the data plane, then prove quality before promoting.
  # `environment: prod` gates on required reviewers AND selects the
  # federated credential whose subject is repo:...:environment:prod.
  # ---------------------------------------------------------------------
  deploy:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # 1 — control plane
      - name: Provision infrastructure
        id: infra
        run: |
          az deployment group create \
            --resource-group "$AZURE_RESOURCE_GROUP" \
            --template-file infra/main.bicep \
            --parameters environmentName=prod foundryName="$FOUNDRY_NAME" \
            --query properties.outputs -o json > outputs.json
          echo "project_endpoint=$(jq -r .projectEndpoint.value outputs.json)" >> "$GITHUB_OUTPUT"

      - run: pip install -r requirements.txt

      # 2 — data plane. Fails with 403 if the SP lacks Azure AI User.
      - name: Apply agent definitions
        env:
          AZURE_AI_PROJECT_ENDPOINT: ${{ steps.infra.outputs.project_endpoint }}
        run: python scripts/deploy_agents.py --definition agents/support-agent.json

      # 3 — the gate. A model-version move or a prompt edit that regresses
      #     groundedness must not reach users just because ARM succeeded.
      - name: Evaluation gate
        env:
          AZURE_AI_PROJECT_ENDPOINT: ${{ steps.infra.outputs.project_endpoint }}
        run: |
          python scripts/run_evaluation.py \
            --dataset evals/regression.jsonl \
            --evaluators groundedness relevance fluency \
            --min-score 4.0 \
            --output eval-results.json

      - name: Publish evaluation results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: evaluation-results
          path: eval-results.json
```

The evaluation gate is the part people leave out and the part that matters. ARM
succeeding tells you the deployment exists. It tells you nothing about whether the
new model version, the edited system prompt, or the re-chunked index still answers
correctly. `run_evaluation.py` exits non-zero below the threshold, and the job
fails. Unit 02.1 builds the evaluator side of this properly with
`azure-ai-evaluation`.

| Stage | Plane | Fails with | Usual cause |
|---|---|---|---|
| `azure/login` | — | `AADSTS700213` | Federated credential subject mismatch |
| `az deployment group create` | Control | `InsufficientQuota` (400) | Capacity request exceeds the regional pool |
| `az deployment group create` | Control | Conflict on the second deployment | Missing `dependsOn` |
| `deploy_agents.py` | Data | `403 PermissionDenied` | SP has Contributor but no data-plane role |
| `run_evaluation.py` | Data | Non-zero exit | The actual point of the gate |

---

## Portal walkthrough

You will do all of this from code in the lab. Walk it once in the portal anyway —
the exam's screenshots come from here, and the field names map one-to-one onto the
Bicep above.

### A. Add a deployment and read every field

1. **https://ai.azure.com** → your project → **Models + endpoints**
   (older portals: **Deployments**).
2. **+ Deploy model** → **Deploy base model** → search `gpt-4o-mini` → **Confirm**.
3. Select **Customize** — the default pane hides the settings the exam asks about.

   | Field | Value | Maps to |
   |---|---|---|
   | Deployment name | `ai103-canary` | the resource `name` |
   | Deployment type | **Global Standard** | `sku.name = GlobalStandard` |
   | Model version | leave the default | `properties.model.version` |
   | Tokens per Minute Rate Limit | `5K` | `sku.capacity = 5` (thousands of TPM) |
   | Content filter | **DefaultV2** | `properties.raiPolicyName` |
   | Enable dynamic quota | On | `dynamicThrottlingEnabled` |

4. Note the **quota remaining** figure that updates as you drag the TPM slider.
   That is the subscription's regional pool for this model family, and it is shared
   with every other deployment and every other team.
5. **Deploy**. Open the deployment and find **Edit** — change the TPM to `2K` and
   save. The endpoint and name do not change. That is the in-place PATCH, and it
   is the correct answer to "reduce capacity without breaking callers".
6. **Management center** → **Quota** shows the same pool per region and model
   family, with a **Request quota** link.

### B. Create an agent, then find its definition

1. Left nav → **Agents** → **+ New agent**.
2. Fill in:

   | Field | Value |
   |---|---|
   | Agent name | `ai103-lab-agent` |
   | Deployment | `gpt-4o-mini` — note this lists **deployment names** |
   | Instructions | `You explain Azure AI Foundry deployment types. Answer in at most three sentences. Refuse anything else.` |
   | Temperature | `0.2` |
   | Knowledge / Actions | leave empty |

3. Test it in the pane on the right, then ask it for a poem and watch the refusal.
4. Now look for an **Export** or **View code** option. There is a code view for
   *calling* the agent, but the agent's own definition is not something the portal
   hands you as a promotable artefact. That is the whole argument for keeping the
   definition in the repository and treating the portal as a debugger, not a source
   of truth.

### C. Look at where a pipeline identity gets its roles

1. **portal.azure.com** → the Foundry resource → **Access control (IAM)** →
   **Role assignments**.
2. Filter the role list for "Cognitive Services" and for "Azure AI". Notice there
   are two families: control-plane roles that let you *create* things, and
   data-plane roles that let you *use* them.
3. **Azure AI User** (formerly *Azure AI Developer*; surfaced in newer portals as
   **Foundry User**) is the one a pipeline needs for the agent step. Contributor
   alone gives a 403 there. The role names were renamed recently; the IDs and
   permissions did not change.

<details>
<summary>Script and CLI alternative</summary>

```powershell
# --- control plane: create a deployment ---------------------------------
az cognitiveservices account deployment create `
  -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
  --deployment-name ai103-canary `
  --model-name gpt-4o-mini --model-version 2024-07-18 --model-format OpenAI `
  --sku-name GlobalStandard --sku-capacity 5

# --- resize in place: same command, different capacity, no downtime -----
az cognitiveservices account deployment create `
  -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
  --deployment-name ai103-canary `
  --model-name gpt-4o-mini --model-version 2024-07-18 --model-format OpenAI `
  --sku-name GlobalStandard --sku-capacity 2

# --- what the pipeline runs, in order -----------------------------------
az deployment group what-if -g $env:AZURE_RESOURCE_GROUP `
  --template-file infra/main.bicep --parameters environmentName=dev
az deployment group create  -g $env:AZURE_RESOURCE_GROUP `
  --template-file infra/main.bicep --parameters environmentName=dev
python scripts/deploy_agents.py --definition agents/support-agent.json

# --- or the whole thing through azd -------------------------------------
azd env new dev
azd up --environment dev          # provision + postprovision hook + deploy

# --- cleanup ------------------------------------------------------------
az cognitiveservices account deployment delete `
  -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
  --deployment-name ai103-canary
```

</details>

---

## Lab

[lab.ipynb](lab.ipynb) does all of the above from the SDK: reads the account's
topology and security posture, creates a deployment through ARM, resizes it in
place, prints the quota pool it drew from, deploys an agent from a JSON definition
with an idempotent apply, inspects the role assignments a pipeline identity needs,
and deletes everything it made.

---

## Troubleshooting

**`InsufficientQuota` — "This operation requires 30000 TPM, but only 10000 TPM is available"**
Deployment-time 400, not a runtime 429. Lower `sku.capacity`, delete a deployment
you are not using, choose a different region, or request an increase at
**Management center → Quota**. Remember quota is per subscription **per region per
model family**.

**Second model deployment fails with a conflict, then succeeds on re-run**
Azure serialises create/update on deployments belonging to one account, and Bicep
parallelises by default. Add `dependsOn` between them. "Increase the timeout" is
the distractor.

**`AADSTS700213: No matching federated identity record found in the tenant`**
The OIDC subject the job presented does not match any registered credential. Print
it: `echo "repo:${{ github.repository }}:environment:${{ github.environment }}"`.
Jobs with `environment:` produce an environment subject, not a branch subject —
register both.

**`azure/login@v2` fails with "Unable to get ACTIONS_ID_TOKEN_REQUEST_URL"**
`permissions: id-token: write` is missing from the workflow or the job. Different
symptom, different cause from the one above.

**Provisioning succeeds, then the agent step returns `403 PermissionDenied`**
Control-plane role, no data-plane role. Assign **Azure AI User** (Foundry User) to
the pipeline's service principal on the Foundry resource, and wait — RBAC
propagation takes up to five minutes and pipelines are faster than that.

**`401` from the SDK even though `az login` works and you have a role**
The account has no `customSubDomainName`, so Entra ID token auth is not available.
It cannot be added after creation. Recreate the account.

**Calls fail after setting `publicNetworkAccess: 'Disabled'`**
Working as configured. Reach it from inside the VNet that holds the private
endpoint, or re-enable public access with a narrow `networkAcls.ipRules` allow-list
for the operator. Re-enabling key auth fixes nothing — that is authentication, not
reachability.

**The deploy script created a second agent instead of updating the first**
It matched on `name`. Names are not unique in Foundry. Key on the agent `id` and
persist it in durable state — a Storage blob or the `azd` environment, not the
runner's filesystem.

**`azd up` provisions but the `postprovision` hook is skipped on Windows**
`hooks` needs both a `posix` and a `windows` entry (or a single `run` with a shell
available on both). A missing platform key is silently ignored.

---

## Check yourself

[quiz.md](quiz.md) — 14 questions on deployment types, capacity changes, control
plane vs data plane, federated credentials, and promotion gates.

## Next

[01.3 — Manage, monitor, and secure AI systems](../03_manage_monitor_secure/README.md)

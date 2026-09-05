# 00 — Setup: connect your Azure tenant

**Time:** 30–45 minutes · **Cost:** a few cents, plus whatever you leave running

Nothing in this course is simulated. You will create real Azure resources, deploy
real models, and pay real (small) amounts of money. This unit gets you connected
and — just as importantly — puts a cost guard in place before you start spending.

By the end you will have:

- [ ] Signed in and selected a subscription
- [ ] A resource group holding everything the course creates
- [ ] An Azure AI Foundry resource and a project
- [ ] Two model deployments you can call
- [ ] A budget alert
- [ ] A green run of `verify_environment.py`

---

## What you are actually creating

Before clicking, understand the shape of it. Foundry has three nested concepts and
the exam tests whether you can tell them apart:

```
Azure subscription
└── Resource group  (rg-ai103-lab)
    └── Azure AI Foundry resource        ← an Azure resource of type
        │                                  Microsoft.CognitiveServices/accounts
        │                                  with kind = AIServices
        │                                  This is where RBAC, networking,
        │                                  quota, and billing live.
        ├── Project  (ai103-project)     ← the work container: agents, indexes,
        │                                  evaluations, connections, traces
        └── Deployments (gpt-4o-mini …)  ← named endpoints for specific models
```

Three ideas worth fixing in your head now:

| Term | What it is | Why it matters on the exam |
|---|---|---|
| **Foundry resource** | The Azure resource. Owns identity, keys, quota, private endpoints. | Security and quota questions target this level. |
| **Project** | A workspace inside the resource. Agents, indexes, evaluations, connections. | Apps connect to a *project endpoint*, not a model endpoint. |
| **Deployment** | A named instance of a model with its own SKU and capacity. | You call the **deployment name**, never the model name. Getting this wrong is a classic exam trap. |

There are two project types. **Foundry projects** (the default now) live directly
on the AIServices resource and are what the Agent Service, Content Understanding,
and the newer tooling expect. **Hub-based projects** are the older shape, backed by
an Azure AI hub plus a storage account and key vault, and they are what you need for
managed compute and prompt flow. This course uses a **Foundry project**.

---

## Step 1 — Sign in and choose a subscription

```powershell
cd ai103-learning

python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
pip install -r requirements-eval.txt   # evaluators; see the ARM64 note in that file

pwsh scripts/01_connect_azure.ps1
```

The script signs you in, lists your subscriptions, checks the region has the models
this course needs, registers resource providers, and writes `.env`. It creates
**nothing billable**.

### Permissions you need

| Role | Scope | Needed for |
|---|---|---|
| **Contributor** | subscription or resource group | Creating every lab resource |
| **User Access Administrator** | same scope | The RBAC labs in unit 01.3 — you will assign roles to managed identities |

Owner covers both. If you only have Contributor, everything works except the
role-assignment exercises; those units say so where relevant.

> **Guest accounts and multiple tenants.** If `az login` lands you in the wrong
> directory, use `az login --tenant <tenant-id>`. `.env` records the tenant so the
> notebooks stay consistent.

---

## Where to open the portal

Every portal walkthrough in this course works **inside the Discovery app / VS Code**
— you do not need to switch to an external browser.

Verified working in the integrated browser:

| Portal | URL | Status |
|---|---|---|
| Azure portal | https://portal.azure.com | Works, full sign-in and SSO |
| Microsoft Foundry | https://ai.azure.com | Works |
| Language Studio | https://language.cognitive.azure.com | Works |
| Content Safety Studio | https://contentsafety.cognitive.azure.com | Works |

Two ways to open one:

- **Ask the agent** — "open the Azure portal" — and it opens in a pane beside your
  notebook. This is the smoothest option, because the agent can then read the page
  and help you find a blade.
- **Ctrl/Cmd-click any portal link** in these READMEs.

> **Why an embedded `<iframe>` will not work.** If you try to build your own
> dashboard that frames the Azure portal, it will fail: `portal.azure.com` sends
> `Content-Security-Policy: frame-ancestors 'self'`, so browsers refuse to render it
> inside another page. The integrated browser works because it opens a **real
> top-level page**, not a frame. Worth knowing — the same header is why you cannot
> iframe most Microsoft sign-in surfaces, and it comes up in clickjacking questions.

If a portal blade misbehaves in the integrated browser, open the same URL in your
system browser; nothing in this course depends on which one you use.

### Guided walkthroughs: `/portal-walkthrough`

Every unit with a portal exercise can be run as a **guided session**. In chat, type:

```
/portal-walkthrough 00
```

— or any unit number (`01.3`, `02.3`, `05.1`…), or nothing to pick from a list.

The agent opens the right portal, then walks you through the exercise **one step at
a time**: it names the exact blade and field, uses your real resource names from
`.env`, waits for you, reads the page to check you landed where you should, and adds
the exam note for each step. At the end it verifies what you built with the Azure
CLI — proving the resource exists, not just that a page rendered.

**You do the clicking.** That is deliberate: the exam shows portal screenshots, and
recognition only comes from doing it yourself. If you would rather watch, say
"demo mode" and the agent drives while narrating each step.

It also watches cost — it stops and confirms before anything that bills per hour
(provisioned deployments, AI Search Basic, fine-tuned model deployments).

---

## Step 2 — Create the Foundry resource and project (portal)

Do this by hand. The portal is what the exam shows you, and clicking through it
once is worth more than reading about it three times.

1. Go to **https://ai.azure.com** and sign in.
2. Confirm the tenant in the top-right matches `AZURE_TENANT_ID` in your `.env`.
3. Select **+ Create new** → **Azure AI Foundry resource**.
4. Fill in:

   | Field | Value |
   |---|---|
   | Project name | `ai103-project` |
   | Foundry resource | the `AZURE_AI_FOUNDRY_RESOURCE` value from your `.env` |
   | Subscription | the one you selected in step 1 |
   | Resource group | `rg-ai103-lab` — **Create new** |
   | Region | `swedencentral` (or whatever `01_connect_azure.ps1` settled on) |

5. Expand **Advanced options** and look, even though you will not change anything:
   - **Connect Azure AI Search** — leave empty. Unit 05.1 connects one deliberately
     so you see what the connection actually does.
   - **Network access** — leave public. Unit 01.3 covers private endpoints.
6. **Create**. Provisioning takes 1–3 minutes.

You land on the project overview. Note two values near the top:

- **Azure AI Foundry project endpoint** — `https://<resource>.services.ai.azure.com/api/projects/ai103-project`
- **Azure OpenAI endpoint** — `https://<resource>.services.ai.azure.com`

Both are already in your `.env`. Compare them to confirm the names match; if they
do not, edit `.env` to match the portal.

<details>
<summary>Script alternative (if the portal is blocked or you want to skip ahead)</summary>

```powershell
pwsh scripts/02_provision_core.ps1
```

Creates the resource group, Foundry resource, project, four model deployments,
Log Analytics, Application Insights, and your role assignments. Come back and read
the portal steps anyway — the exam asks about them.
</details>

---

## Step 3 — Deploy your first model

1. In the left nav, choose **Model catalog**.
2. Search for **gpt-4o-mini**. Select it, then **Use this model**.
3. In the deployment dialog:

   | Field | Value | Why |
   |---|---|---|
   | Deployment name | `gpt-4o-mini` | Match the model name so `.env` stays simple. Deployment names are what your code calls. |
   | Deployment type | **Global Standard** | Pay-per-token, routed to global capacity, highest available quota. |
   | Tokens per minute rate limit | `30K` | Plenty for the labs. Quota is a shared subscription pool. |
   | Content filter | **DefaultV2** | Unit 01.4 builds a custom one. |
   | Model version | leave default, auto-update on | |

4. **Deploy**, then repeat for **text-embedding-3-small** (deployment type
   **Standard**, 30K TPM). Units 02.2 and 05.1 need it.

### Deployment types — know this table cold

| Type | Data residency | Billing | Use when |
|---|---|---|---|
| **Standard** | Your region only | Per token | Data residency requirements |
| **Global Standard** | Routed anywhere Microsoft has capacity | Per token | Default choice — best availability and quota |
| **Data Zone Standard** | Within a geography (EU / US) | Per token | Regional compliance without single-region limits |
| **Provisioned (PTU)** | Reserved capacity | Per hour | Predictable high throughput, latency guarantees |
| **Batch** | Async, 24-hour window | ~50% cheaper per token | Bulk offline jobs |

Unit 01.2 goes deeper. For now: **Global Standard for chat, Standard for
embeddings, and never leave a provisioned deployment running by accident.**

### Test it in the playground

**Playgrounds** → **Chat** → pick `gpt-4o-mini` → ask it anything. If it answers,
your resource, deployment, and permissions all work. If you get a 401 or 403, jump
to Troubleshooting below.

---

## Step 4 — Set a budget alert

Do not skip this. Azure AI Search and provisioned deployments bill by the hour
regardless of use, and it is genuinely easy to forget a resource for a month.

1. **https://portal.azure.com** → your subscription → **Cost Management** → **Budgets**.
2. **+ Add**.
3. Scope: filter to resource group `rg-ai103-lab`.
4. Name `ai103-budget`, reset period **Monthly**, amount **50** (or your comfort level).
5. Alert conditions:

   | Type | Threshold | Meaning |
   |---|---|---|
   | Actual | 50% | Early warning |
   | Actual | 90% | Act now |
   | Forecasted | 100% | Azure predicts you will blow the budget |

6. Add your email address. **Create**.

Budget alerts are informational — Azure will **not** stop your resources. The only
real cost control is [99_teardown](../99_teardown/README.md).

<details>
<summary>Script alternative</summary>

```powershell
pwsh scripts/03_provision_labs.ps1
```

Also creates Storage, Azure AI Search, and the cross-service role assignments.
</details>

---

## Step 5 — Verify

```powershell
python scripts/verify_environment.py
```

It checks your Python version and packages, `.env`, credential, project
connectivity, model deployments, a live chat completion, and Search/Storage
access. Every check prints why it matters and how to fix it.

Then open [lab.ipynb](lab.ipynb) and run it top to bottom. It walks the same ground
in code: connect, list deployments, call a model, inspect token usage, and see the
difference between the project endpoint and the inference endpoint.

---

## Troubleshooting

**`401 Unauthorized` / `403 Forbidden` when calling a model**
RBAC has not propagated, or you lack the role. Wait five minutes, then:

```powershell
$me = az ad signed-in-user show --query id -o tsv
$id = az cognitiveservices account show -n <resource> -g rg-ai103-lab --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
    --role "Cognitive Services OpenAI User" --scope $id
```

**`DefaultAzureCredential failed to retrieve a token`**
Run `az login --tenant <tenant-id>`. In VS Code, also sign in to the Azure account
extension — `DefaultAzureCredential` tries several sources and the error lists each.

**`Deployment failed: insufficient quota`**
Quota is per subscription, per region, per model family, and a new subscription may
have zero for some models. **https://ai.azure.com** → **Management center** →
**Quota** shows what you have. Lower the TPM, or request an increase (unit 01.3).

**`The account name is already in use`**
A previous Foundry resource is soft-deleted. Purge it:

```powershell
az cognitiveservices account purge -n <name> -g rg-ai103-lab -l swedencentral
```

**Model not available in my region**
`01_connect_azure.ps1` warns about this. The course defaults to an **EU** region;
`swedencentral` is the only EU region serving every model the course uses. Other EU
regions run everything except unit 03.1's image and video models. You can deploy an
extra Foundry resource in a second
region and connect it to the same project — unit 01.2 shows how.

---

## Check yourself

[quiz.md](quiz.md) — 12 questions on the Foundry object model, deployment types,
and keyless authentication.

## Next

[01.1 — Choose the appropriate Foundry services for generative AI and agents](../01_plan_and_manage/01_choose_services_and_models/README.md)

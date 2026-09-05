# 01.3 — Manage, monitor, and secure AI systems

**Time:** 90 minutes · **Cost:** under $1. Log Analytics ingestion is charged per
GB but the lab generates kilobytes. **Azure AI Search bills hourly** — if you
provisioned one in unit 00, it is already costing you.

This is the widest unit in the domain: quota and cost, model monitoring, retrieval
monitoring, and security. It is also the one with the most memorisable facts —
role names, log table names, metric names — so read the tables twice.

By the end you will have:

- [ ] Read quota and usage programmatically and calculated your headroom
- [ ] Handled a real 429 with correct backoff
- [ ] Enabled diagnostic settings and run KQL against `AzureDiagnostics`
- [ ] Measured a grounding-quality signal and a drift signal
- [ ] Checked search index health and relevance
- [ ] Audited RBAC on the Foundry resource and understood every role in the table
- [ ] Understood exactly what `disableLocalAuth` and private endpoints change

---

## Concepts

### 1. Quota, scaling, rate limits, cost

**Quota is not the same as a rate limit, and neither is cost.**

| Term | Scope | Unit | What exceeding it does |
|---|---|---|---|
| **Quota** | Subscription + region + model family | TPM (thousands of tokens/minute) | Deployment *creation* fails with `InsufficientQuota` (400) |
| **Rate limit** | One deployment | TPM and RPM, derived from capacity | Requests fail at runtime with `429` and a `Retry-After` header |
| **Cost** | Per token consumed (or per hour for PTU/managed compute) | USD | Nothing — Azure bills you |

Azure derives RPM from TPM at roughly **6 RPM per 1,000 TPM** for most models. A
30K TPM deployment therefore gives about 180 requests per minute regardless of how
short those requests are — which is why chatty, tiny-prompt workloads hit RPM
limits long before TPM.

**Handling 429 correctly.** The response carries `Retry-After` in seconds. Honour
it. Exponential backoff *without* jitter causes retry storms where every client
retries at the same instant.

| Lever | Effect | Cost |
|---|---|---|
| Raise deployment capacity | More TPM and RPM | Consumes shared quota |
| Enable **dynamic quota** | Azure lends spare capacity opportunistically | Free, but not guaranteed |
| Add a second deployment in another region and load-balance | Multiplies throughput, adds failover | Complexity |
| Move to **Provisioned (PTU)** | Guaranteed throughput and latency | Hourly, expensive |
| Move to **Batch** | Removes the workload from the real-time pool entirely | ~50% cheaper |

**Where the cost actually is.** Reading a per-model cost breakdown surprises most
teams:

- **Prompt tokens dominate in RAG.** Ten retrieved chunks at 600 tokens is 6,000
  prompt tokens before the user has said anything.
- **Agent threads grow.** Each turn resends the whole thread — cost is quadratic
  in conversation length.
- **Reasoning tokens are invisible but billed.** See unit 01.1.
- **Idle resources.** Azure AI Search, PTU, and managed compute bill whether or not
  you call them.

> **Exam note.** A budget alert **notifies**; it never stops anything. If a scenario
> requires spend to actually halt, the answer is an action group triggering
> automation (Logic App, Function, runbook) — the budget alone is not enough.

### 2. Monitoring models: performance, drift, safety, grounding

Four distinct signals, four different places to get them.

| Signal | Source | Key names |
|---|---|---|
| **Performance** | Azure Monitor **metrics** on the account | `ProcessedPromptTokens`, `GeneratedTokens`, `TokenTransaction`, `AzureOpenAIRequests`, `Ratelimit` |
| **Latency + traces** | Application Insights via OpenTelemetry | `gen_ai.*` span attributes, dependency duration |
| **Safety events** | Content filter annotations on the response; diagnostic logs | `finish_reason = "content_filter"`, `prompt_filter_results` |
| **Grounding quality** | `azure-ai-evaluation` run on sampled traffic | `groundedness`, `relevance`, `retrieval` |

**Diagnostic settings** are the prerequisite for all KQL work. On the Foundry
resource → **Monitoring** → **Diagnostic settings** → **+ Add**, send these
categories to a Log Analytics workspace:

| Category | Table | Contains |
|---|---|---|
| `Audit` | `AzureDiagnostics` | Who did what on the resource |
| `RequestResponse` | `AzureDiagnostics` | Per-request metadata: operation, duration, result code |
| `AzureOpenAIRequestUsage` | `AzureDiagnostics` | Token usage per request (**charged to export**) |
| `Trace` | `AzureDiagnostics` | Service-side traces |
| `AllMetrics` | `AzureMetrics` | The metric names above |

> **Exam note.** Everything lands in the generic **`AzureDiagnostics`** table, not
> a dedicated `AzureOpenAI…` table. Expect a 1–2 hour delay before data appears
> after you enable the setting.

Useful queries:

```kusto
// Throttling: are you hitting the deployment rate limit?
AzureDiagnostics
| where Category == "RequestResponse" and ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| where TimeGenerated > ago(24h)
| summarize
    calls = count(),
    throttled = countif(resultSignature_d == 429),
    server_errors = countif(resultSignature_d >= 500)
  by bin(TimeGenerated, 1h)
| extend throttle_rate = todouble(throttled) / calls
| order by TimeGenerated desc
```

```kusto
// Latency distribution by operation — p50 vs p95 is the number that matters
AzureDiagnostics
| where Category == "RequestResponse" and isnotempty(DurationMs)
| where TimeGenerated > ago(24h)
| summarize p50 = percentile(DurationMs, 50),
            p95 = percentile(DurationMs, 95),
            p99 = percentile(DurationMs, 99),
            n = count()
  by OperationName
| order by p95 desc
```

```kusto
// Token burn by deployment — the cost driver
AzureDiagnostics
| where Category == "AzureOpenAIRequestUsage"
| where TimeGenerated > ago(7d)
| extend props = parse_json(properties_s)
| extend deployment = tostring(props.modelDeploymentName)
| summarize prompt = sum(toint(props.promptTokens)),
            completion = sum(toint(props.generatedTokens))
  by deployment, bin(TimeGenerated, 1d)
| extend total = prompt + completion
| order by TimeGenerated desc
```

```kusto
// Safety events surfaced by your own application telemetry
AppTraces
| where TimeGenerated > ago(7d)
| where Message has "content_filter"
| summarize events = count() by bin(TimeGenerated, 1h)
| render timechart
```

**Drift** has three meanings on this exam, and you must separate them:

| Kind | What changed | How you detect it |
|---|---|---|
| **Model drift** | Azure auto-upgraded the model version | Compare `model` in responses over time; pin versions; run a regression eval |
| **Data drift** | Input distribution moved (new products, new phrasing) | Track input embeddings' distance from a baseline centroid; track topic mix |
| **Quality drift** | Same inputs, worse outputs | Scheduled evaluation on a fixed golden set — the only reliable detector |

> **Exam note.** The correct answer to "how do you detect quality regression after
> a model version change" is **a scheduled evaluation against a fixed golden
> dataset**, not user complaints, not metric dashboards, not token counts.

### 3. Monitoring ingestion, index health, and relevance

RAG fails at retrieval far more often than at generation, and the failures are
silent — the model produces a confident answer from the wrong chunks.

| Layer | What to watch | Where |
|---|---|---|
| **Ingestion** | Indexer success rate, per-document errors and warnings, items processed, skillset failures | `SearchClient` indexer status; `AzureDiagnostics` where `OperationName == "Indexers.Status"` |
| **Index health** | Document count vs source count, storage size, vector index size vs quota | `get_service_statistics()`, `get_index_statistics()` |
| **Query health** | Query latency, throttled queries, queries per second | Azure Monitor metrics `SearchLatency`, `SearchQueriesPerSecond`, `ThrottledSearchQueriesPercentage` |
| **Relevance** | Zero-result rate, click/thumbs signals, evaluator scores | Your telemetry + `RetrievalEvaluator`, `DocumentRetrievalEvaluator` |

```kusto
// Search operations: errors and slow queries
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SEARCH"
| where TimeGenerated > ago(24h)
| summarize n = count(),
            failures = countif(resultSignature_d >= 400),
            p95_ms = percentile(DurationMs, 95)
  by OperationName
| order by failures desc
```

Four ingestion-quality checks worth automating:

1. **Document count reconciliation** — blobs in the container vs documents in the
   index. A gap means silent indexer failures.
2. **Empty-vector detection** — documents whose embedding field is null mean the
   embedding skill failed and those documents are invisible to vector search.
3. **Chunk-size distribution** — a long tail of 4,000-token chunks means your
   splitter is not splitting.
4. **Zero-result query rate** — a rising rate is the earliest warning that
   ingestion or relevance has broken.

> **Exam note.** A search index that reports Succeeded and returns results can
> still be broken. The specific failure mode to remember is a **partially failed
> skillset**: documents are indexed, their vector fields are empty, keyword search
> works, vector search silently returns nothing relevant.

### 4. Security

Four bullets, one coherent posture.

#### Managed identity

| Type | Lifecycle | Use when |
|---|---|---|
| **System-assigned** | Created and deleted with the resource | One resource, one identity — the default |
| **User-assigned** | Independent resource, attachable to many | Several resources need the same permissions, or you must grant access before the consumer exists |

The Foundry resource's identity is what reaches Azure AI Search and Storage. The
project has its own identity too. Both need role assignments on the *target*.

#### Keyless credentials

Three layers, and the exam tests that you know all three are needed:

1. **Client side** — `DefaultAzureCredential`: `az login` locally, managed identity
   in Azure, no code change between them.
2. **Resource side** — `disableLocalAuth: true` makes API keys stop working.
   Without this, keys still work even if your code has stopped using them.
3. **Prerequisite** — a **custom subdomain** on the account. Entra ID token auth
   requires it and it cannot be added after creation.

#### Private networking

| Control | What it does |
|---|---|
| **Private endpoint** | A private IP for the service in your VNet; DNS resolves the public FQDN to it via a private DNS zone |
| `publicNetworkAccess: 'Disabled'` | Refuses all internet traffic. Combine with a private endpoint or nothing can reach it |
| `networkAcls` IP rules | A firewall allow-list. Weaker than a private endpoint but far simpler |
| **Service tags** | Used in NSG rules, `CognitiveServicesManagement` for control-plane traffic |

Private endpoints you typically need for a full RAG solution: the Foundry account,
Azure AI Search, the Storage account (blob **and** file sub-resources), and Key
Vault. Each needs a private DNS zone —
`privatelink.cognitiveservices.azure.com`, `privatelink.search.windows.net`,
`privatelink.blob.core.windows.net`.

> **Exam note.** Disabling public access without creating a private endpoint and a
> private DNS zone is the standard broken configuration. Symptom: the name resolves
> to a public IP and the connection is refused.

#### RBAC — the table to memorise

Foundry's roles were **recently renamed**. The exam and the portal may show either
name; the role IDs and permissions are unchanged.

| Current name | Former name | Grants | Assign to |
|---|---|---|---|
| **Foundry User** | *Azure AI User* | Data-plane development: build agents, run evaluations, upload files, call endpoints | Developers, project managed identities, CI/CD |
| **Foundry Project Manager** | *Azure AI Project Manager* | Foundry User plus project management, publishing agents, and assigning Foundry User to others | Team leads |
| **Foundry Account Owner** | *Azure AI Account Owner* | Create accounts and projects, manage models; **no data actions** | Platform team |
| **Foundry Owner** | *Azure AI Owner* | Everything, control and data plane | Break-glass; the only built-in role that can fine-tune *and* deploy the result |
| **Foundry Agent Consumer** | — | Call agent endpoints only | Applications that invoke but never modify agents |

Alongside those, the Cognitive Services and Search roles:

| Role | Grants | Assign to |
|---|---|---|
| **Cognitive Services OpenAI User** | Inference calls with Entra ID; view deployments | Apps that only call models |
| **Cognitive Services OpenAI Contributor** | Above plus create/edit deployments and fine-tunes | Deployment automation |
| **Cognitive Services Contributor** | Create resources, read keys, create custom content filters | Platform team |
| **Cognitive Services User** | Read and list keys; call Foundry Tools | Legacy / Tools-only apps |
| **Cognitive Services Usages Reader** | Read quota | FinOps, dashboards |
| **Search Index Data Reader** | Query an index | The Foundry resource identity; RAG apps |
| **Search Index Data Contributor** | Read and write documents | Ingestion pipelines |
| **Search Service Contributor** | Manage indexes, indexers, skillsets, data sources | Ingestion setup; the Foundry identity for "on your data" |
| **Storage Blob Data Reader / Contributor** | Read / write blobs | Search identity (reader), ingestion (contributor) |

The cross-service assignments a working RAG solution needs — a favourite exam
table:

| Role | Assigned to | On |
|---|---|---|
| Search Index Data Reader | Foundry account identity | Azure AI Search |
| Search Service Contributor | Foundry account identity | Azure AI Search |
| Storage Blob Data Reader | Search service identity | Storage account |
| Cognitive Services OpenAI Contributor | Search service identity | Foundry account (for integrated vectorization) |
| Cognitive Services OpenAI User | Application identity | Foundry account |

> **Exam note.** `Owner` and `Contributor` at subscription scope are inherited and
> take priority, which is why "I'm Owner and still get 403" happens: Owner grants
> control-plane rights and the *ability to grant* data-plane roles, but for some
> Foundry data actions you still need the explicit data-plane role assigned.

---

## Portal walkthrough

### A. Enable diagnostics

1. **https://portal.azure.com** → your Foundry resource → **Monitoring** →
   **Diagnostic settings** → **+ Add diagnostic setting**.
2. Name `ai103-diagnostics`.
3. Tick **Audit Logs**, **Request and Response Logs**, **Azure OpenAI Request
   Usage**, **Trace Logs**, and **AllMetrics**.
4. Destination: **Send to Log Analytics workspace** → the workspace from unit 00.
5. **Save**. Allow up to two hours before queries return rows.

### B. Read quota

**https://ai.azure.com** → **Management center** → **Quota**. Filter to your
region. For each model family note **Used / Limit**. **Request quota** opens the
increase form — note it asks for a business justification and a target TPM.

### C. Turn on keyless enforcement

1. Azure portal → Foundry resource → **Resource Management** → **Identity**.
   Confirm **System assigned** is **On**.
2. **Resource Management** → **Keys and Endpoint**. Note the two keys exist.
3. **Networking** → **Firewalls and virtual networks**. Leave public for now; the
   lab shows what changes when you do not.
4. To disable keys, set `disableLocalAuth` — there is no portal toggle on all
   surfaces, so use the CLI:

   ```powershell
   az resource update `
       --ids $(az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP --query id -o tsv) `
       --set properties.disableLocalAuth=true
   ```

   Verify by trying a key — it will now return 401.

### D. Assign a role

1. Foundry resource → **Access control (IAM)** → **+ Add** → **Add role assignment**.
2. **Role** tab → search **Foundry User** (or *Azure AI User* if the rename has not
   reached your tenant).
3. **Members** → **Managed identity** → select your project's identity.
4. **Review + assign**. Propagation takes up to 5 minutes.

<details>
<summary>CLI alternative</summary>

```powershell
$acct = az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP --query id -o tsv
$me   = az ad signed-in-user show --query id -o tsv

# Data-plane developer access
az role assignment create --assignee-object-id $me --assignee-principal-type User `
    --role "Cognitive Services OpenAI User" --scope $acct

# Let the Foundry identity read the search index
$mi     = az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP --query identity.principalId -o tsv
$search = az search service show -n $env:AZURE_SEARCH_SERVICE -g $env:AZURE_RESOURCE_GROUP --query id -o tsv
az role assignment create --assignee-object-id $mi --assignee-principal-type ServicePrincipal `
    --role "Search Index Data Reader" --scope $search

# Private endpoint + lock the front door
az network private-endpoint create -g $env:AZURE_RESOURCE_GROUP -n pe-foundry `
    --vnet-name vnet-ai103 --subnet snet-pe `
    --private-connection-resource-id $acct --group-id account --connection-name foundry-conn

az resource update --ids $acct --set properties.publicNetworkAccess=Disabled
```
</details>

---

## Troubleshooting

**`429 Too Many Requests`, `Retry-After: 12`**
Deployment rate limit, not quota. Honour `Retry-After`, add jitter, and consider
dynamic quota or a second region. Raising capacity fixes it only if quota remains.

**`InsufficientQuota` when creating a deployment**
Different problem, same root cause of confusion. This is the subscription ceiling.
Delete unused deployments or request an increase.

**KQL returns no rows**
Three causes, in order of likelihood: diagnostic settings were enabled less than
two hours ago; you queried the wrong table (it is `AzureDiagnostics`, not a
per-service table); or the query scope is set to a single resource — open Log
Analytics from **Azure Monitor**, not from the resource blade.

**`403` after assigning the correct role**
Wait five minutes. If it persists, check the **scope** — a role on the resource
group does not always behave identically to one on the resource, and subscription
`Owner`/`Contributor` inherit and can mask what you intended.

**`401` after setting `disableLocalAuth=true`**
Working as designed — something is still sending a key. Find it: any
`api_key=`/`Ocp-Apim-Subscription-Key` in code, a connection configured with key
auth, or a Search data source using a key.

**Private endpoint created but calls still fail**
Almost always DNS. Confirm a private DNS zone
(`privatelink.cognitiveservices.azure.com`) exists, is linked to the VNet, and has
an A record for your account. `nslookup <account>.services.ai.azure.com` from
inside the VNet must return a private IP.

**Search index returns nothing for vector queries but keyword works**
The embedding skill failed for those documents; their vector fields are null.
Check indexer execution history for warnings — a *partially* successful run still
reports Success.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on quota, monitoring, index health, and security.

## Next

[01.4 — Implement responsible AI across generative AI and agentic systems](../04_responsible_ai/README.md)

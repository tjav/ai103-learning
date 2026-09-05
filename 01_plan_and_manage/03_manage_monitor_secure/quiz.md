# 01.3 — Manage, monitor, and secure: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** Your application receives `429 Too Many Requests` with a `Retry-After: 8`
header. What is the correct immediate handling?

- A. Retry immediately with a different deployment
- B. Sleep for the `Retry-After` value plus jitter, then retry
- C. Request a quota increase before retrying
- D. Fall back to an API key

---

**2.** Which two statements distinguish quota from a rate limit? Choose two.

- A. Quota failures occur when creating a deployment; rate limits occur at request time
- B. Quota is per deployment; rate limits are per subscription
- C. Quota exhaustion returns 400 `InsufficientQuota`; rate limiting returns 429
- D. Both return 429 with different error codes

---

**3.** A team's chat deployment has 30K TPM. Their workload is thousands of very
short requests per minute and they are throttled while using only 10% of their
token budget. What is happening?

- A. The content filter is rejecting requests
- B. They are hitting the derived RPM limit, roughly 6 RPM per 1,000 TPM
- C. Their quota was reduced by another team
- D. Global Standard routing is adding latency

---

**4.** You enabled diagnostic settings on your Foundry resource an hour ago, but
your KQL query returns no rows. Which is the **least** likely cause?

- A. Log data can take up to two hours to appear
- B. You queried a table named `AzureOpenAILogs` which does not exist
- C. The query scope is limited to a single resource
- D. The Foundry resource has no managed identity

---

**5.** Which log category must be enabled to analyse per-request token consumption
in Log Analytics?

- A. `Audit`
- B. `RequestResponse`
- C. `AzureOpenAIRequestUsage`
- D. `Trace`

---

**6.** After Azure auto-upgraded your model version, users report worse answers,
though inputs have not changed. Which detection method would have caught this?

- A. Embedding-distance drift detection on inputs
- B. A scheduled evaluation against a fixed golden dataset
- C. Monitoring `ProcessedPromptTokens`
- D. A budget alert

---

**7.** Your search indexer reports `Success`, keyword search works, but vector
search returns irrelevant results. What is the most likely cause?

- A. The semantic ranker is disabled
- B. The embedding skill failed for some documents, leaving null vector fields
- C. The index has too few documents
- D. The query is using the wrong API version

---

**8.** Which two are required to authenticate to a Foundry resource with Microsoft
Entra ID? Choose two.

- A. A custom subdomain on the account
- B. `publicNetworkAccess` set to `Enabled`
- C. A data-plane role such as *Cognitive Services OpenAI User*
- D. `disableLocalAuth` set to `true`

---

**9.** What is the practical effect of setting `disableLocalAuth: true`?

- A. Developers can no longer deploy models
- B. API key authentication is rejected; only Entra ID tokens work
- C. The account's keys are deleted permanently
- D. Public network access is disabled

---

**10.** A RAG application's web app identity must query the index but never modify
it. Which role, at which scope?

- A. Search Service Contributor on the search service
- B. Search Index Data Contributor on the search service
- C. Search Index Data Reader on the search service or index
- D. Reader on the resource group

---

**11.** Which role should you assign to a developer who needs to build agents and
run evaluations but must not create Azure resources?

- A. Contributor
- B. Foundry User (formerly Azure AI User)
- C. Foundry Account Owner
- D. Cognitive Services Contributor

---

**12.** You set `publicNetworkAccess: 'Disabled'` and created a private endpoint,
but calls from inside the VNet still fail with a connection timeout. What is the
most likely missing piece?

- A. A network security group rule allowing port 443
- B. A private DNS zone linked to the VNet with an A record for the account
- C. A managed identity on the calling VM
- D. `disableLocalAuth` set to `false`

---

**13.** A budget alert fires at 100% of a $500 monthly budget. What happens to your
model deployments?

- A. They are throttled to zero TPM
- B. They are deleted
- C. Nothing — budget alerts only notify
- D. They fall back to Batch pricing

---

**14.** Which is **not** a recognised meaning of "drift" in this domain?

- A. The model version changed underneath the deployment
- B. The distribution of user inputs moved away from the baseline
- C. Output quality degraded on unchanged inputs
- D. Deployment capacity was reduced by an administrator

---

**15.** For "Azure OpenAI On Your Data" style integrated retrieval, which role must
be assigned to the **Foundry account's managed identity** on the Azure AI Search
service so it can query the index?

- A. Search Index Data Contributor
- B. Search Index Data Reader
- C. Storage Blob Data Reader
- D. Cognitive Services OpenAI User

---
---

## Answers

**1 — B.** The service tells you when capacity frees up; honour it. Jitter matters
because synchronised clients on identical backoff curves recreate the burst that
caused the throttle. A can work as a deliberate multi-region strategy but is not
the *immediate* handling and often just moves the problem. C addresses deployment
creation, a different failure. D is unrelated — throttling is about capacity, not
authentication.

**2 — A and C.** Quota is a subscription + region + model-family ceiling enforced
when you *create or resize* a deployment, returning 400 `InsufficientQuota`. Rate
limits are per deployment, enforced per request, returning 429. B inverts the
scopes. D is simply wrong about the quota status code.

**3 — B.** Azure derives an RPM limit from TPM at roughly 6 RPM per 1,000 TPM, so
30K TPM caps you near 180 requests per minute no matter how small each request is.
Chatty workloads with tiny prompts always hit RPM first. A returns 400 with a
`content_filter` code, not 429. C would show in the quota blade. D affects latency,
not throttling.

**4 — D.** Diagnostic logging routes through the diagnostic setting, not the
resource's managed identity, so a missing identity has no bearing. A is the most
common cause. B is the classic mistake — everything lands in `AzureDiagnostics`.
C bites when you open Logs from the resource blade rather than from Azure Monitor.

**5 — C.** `AzureOpenAIRequestUsage` carries per-request prompt and generated token
counts. Note it is the one category that costs money to export. `RequestResponse`
gives operation, duration, and result code but not token counts; `Audit` covers
management actions; `Trace` covers service-side traces.

**6 — B.** Only a fixed golden dataset scored on a schedule isolates *quality*
change from input change, because the inputs are held constant by construction.
A detects input drift, which by definition did not occur here. C measures volume,
not quality. D measures money.

**7 — B.** A partially failed skillset still reports the run as successful: the
documents index, but their vector fields are null, so they are invisible to vector
search while remaining findable by keyword. Check the indexer execution history for
warnings, not just the status. A would degrade ranking but not produce irrelevant
results. C and D would break keyword search too.

**8 — A and C.** A custom subdomain is a hard prerequisite for token auth and
cannot be added after creation; a data-plane role is required because control-plane
roles grant no inference access. B is false — Entra ID auth works over private
endpoints. D enforces keyless but is not required *for* Entra ID to work.

**9 — B.** It rejects key-based authentication at the resource, which is what
actually makes a deployment keyless — using `DefaultAzureCredential` in your code
does not stop anyone else using a key. The keys still exist (C is wrong) and
networking is untouched (D is wrong).

**10 — C.** Least privilege: query without write. Note the scope can be the service
or an individual index, and index scope is tighter. A grants management of indexes
and indexers. B grants document writes the app must not have. D is a control-plane
role granting no data access at all.

**11 — B.** Foundry User (formerly *Azure AI User*) is the data-plane developer
role: build agents, run evaluations, upload files, call endpoints, with no ability
to create Azure resources. A and D are control-plane roles — and Contributor
notably does *not* grant the data actions. C creates accounts and projects but has
no data actions, which is the mirror-image mistake.

**12 — B.** Without a linked private DNS zone
(`privatelink.cognitiveservices.azure.com`) holding an A record, the public FQDN
still resolves to a public IP that is now refusing traffic. This is the single most
common private-endpoint failure. A is rarely the cause since private endpoint
traffic is typically permitted by default. C and D are authentication concerns, and
you would see 401/403 rather than a timeout.

**13 — C.** Azure budgets are notification-only. To actually stop spending you must
wire the alert to an action group that triggers automation. This is deliberately
tested because assuming budgets enforce a cap is a costly misunderstanding.

**14 — D.** A capacity change is an administrative action with an audit trail, not
drift. A (model drift), B (data drift), and C (quality drift) are the three
recognised kinds, and separating them is the point of the question.

**15 — B.** The Foundry account identity queries the index, so it needs *Search
Index Data Reader*. It typically also needs *Search Service Contributor* to read
the index schema for field mapping — but for the query itself, Data Reader is the
answer. A grants unnecessary write access. C is the role the **Search** identity
needs on **Storage**. D is what the **application** needs on **Foundry** — a
different direction entirely.

---

## Lab exercise solutions

**1. Separate the two failures.**

| | Rate limit | Quota |
|---|---|---|
| Status | `429` | `400` |
| Code | `429` / `RateLimitReached` | `InsufficientQuota` |
| Headers | `Retry-After` (seconds) | none |
| When | Every request, at runtime | Deployment create or resize |
| Fix in code | Backoff and retry | Nothing — it is a provisioning failure |

They must be handled differently because a 429 is **transient and retryable** —
the same request will succeed shortly — while `InsufficientQuota` is **permanent
until a human acts**. Retrying a quota failure burns time and achieves nothing, and
worse, treating a 429 as fatal turns a momentary capacity blip into a user-visible
outage. The general rule: retry on 429 and 5xx, fail fast on 4xx.

**2. Write a cost query.**

```kusto
let rate_in  = dynamic({"gpt-4o-mini": 0.15, "gpt-4o": 2.50, "o4-mini": 1.10});
let rate_out = dynamic({"gpt-4o-mini": 0.60, "gpt-4o": 10.00, "o4-mini": 4.40});
AzureDiagnostics
| where Category == "AzureOpenAIRequestUsage" and TimeGenerated > ago(7d)
| extend props = parse_json(properties_s)
| extend deployment = tostring(props.modelDeploymentName),
         p = toint(props.promptTokens),
         c = toint(props.generatedTokens)
| summarize prompt = sum(p), completion = sum(c) by deployment, day = bin(TimeGenerated, 1d)
| extend usd = round(prompt / 1000000.0 * todouble(rate_in[deployment])
                   + completion / 1000000.0 * todouble(rate_out[deployment]), 4)
| order by day desc, usd desc
```

The usual surprise is that the embedding deployment or a "cheap" mini deployment
tops the list, because volume beats unit price. The second surprise is the
prompt/completion ratio in a RAG workload — often 20:1 — which tells you that
tuning retrieval (fewer, better chunks) saves more money than switching models.

**3. Make drift detection stateful.**

```python
import json, pathlib
STATE = pathlib.Path("drift_baseline.json")

if STATE.exists():
    saved = json.loads(STATE.read_text())
    centroid, threshold = saved["centroid"], saved["threshold"]
else:
    base_vecs = embed(BASELINE)
    centroid = [sum(col) / len(col) for col in zip(*base_vecs)]
    threshold = max(1 - cosine(v, centroid) for v in base_vecs)
    STATE.write_text(json.dumps({
        "centroid": centroid,
        "threshold": threshold,
        "embedding_model": cfg["MODEL_EMBEDDING"],
        "created": dt.datetime.now(dt.timezone.utc).isoformat(),
        "n": len(BASELINE),
    }))
```

You must also store **which embedding model produced the centroid**, because
vectors from different models are not comparable — re-baseline whenever the
embedding deployment changes, or your drift metric becomes noise. Store the sample
size and creation date too, since a centroid built from five queries is not a
distribution.

Re-baseline on a deliberate schedule (say monthly) *or* when drift is investigated
and judged legitimate — for example a new product launched and the new questions
are ones you now want to serve. Never re-baseline automatically on drift, or the
detector silently accepts whatever happens and stops detecting anything.

**4. Least-privilege matrix.**

| Principal | Role | Scope | Why |
|---|---|---|---|
| Web app managed identity | Cognitive Services OpenAI User | Foundry account | Call the model |
| Web app managed identity | Search Index Data Reader | Search index | Query for grounding |
| Foundry account identity | Search Index Data Reader | Search service | Integrated retrieval queries |
| Foundry account identity | Search Service Contributor | Search service | Read index schema for field mapping |
| Search service identity | Storage Blob Data Reader | Storage account | Indexer reads source documents |
| Search service identity | Cognitive Services OpenAI Contributor | Foundry account | Integrated vectorization calls the embedding model |
| Ingestion pipeline identity | Search Index Data Contributor | Search index | Push documents |
| Developer | Foundry User | Foundry account | Build agents, run evaluations |

The app identity must not hold `Search Index Data Contributor` because a
compromised or buggy application could then **poison the grounding corpus** —
injecting documents that the model will subsequently treat as authoritative truth
and cite. That is a content-integrity attack with no obvious symptom, and it is far
more damaging than a read-only compromise. Separating read from write across
identities means a single compromise cannot both read the corpus and rewrite it.

**5. Reason about locking the door.** Everything breaks immediately: your
notebooks, the Foundry portal playground, the CI/CD pipeline running on
GitHub-hosted runners, and any connected Search "on your data" traffic that
traverses the public endpoint. The failures present as connection timeouts, not
403s, which sends people hunting through RBAC for an hour.

To restore it:

1. Create a VNet and a subnet for private endpoints
   (`privateEndpointNetworkPolicies: Disabled`).
2. Create a private endpoint on the Foundry account with `groupId = account`.
3. Create the private DNS zone `privatelink.cognitiveservices.azure.com`, link it
   to the VNet, and confirm the A record was written.
4. Repeat 2–3 for Search (`privatelink.search.windows.net`) and Storage
   (`privatelink.blob.core.windows.net`, plus the `file` sub-resource).
5. Move your compute inside the VNet — Container Apps with VNet integration, or a
   jump host — and use a self-hosted or VNet-integrated CI/CD runner.
6. For occasional operator access, add specific IPs to `networkAcls.ipRules`
   rather than re-enabling public access wholesale.

The order matters: create the private endpoint and DNS **before** disabling public
access, or you lock yourself out of the resource you need to fix it.

# 00 — Setup: quiz

12 questions. Answers at the bottom. Aim for 10+ before moving on.

---

**1.** You have an Azure AI Foundry resource named `contosoai` and a project named
`support-bot`. An application needs to create and run an agent. Which endpoint
should it connect to?

- A. `https://contosoai.services.ai.azure.com`
- B. `https://contosoai.openai.azure.com`
- C. `https://contosoai.services.ai.azure.com/api/projects/support-bot`
- D. `https://management.azure.com/.../accounts/contosoai`

---

**2.** You deploy the model `gpt-4o` with the deployment name `prod-chat`. What
value goes in the `model` parameter of a chat completions call?

- A. `gpt-4o`
- B. `prod-chat`
- C. `gpt-4o/prod-chat`
- D. The full deployment resource ID

---

**3.** A customer requires that prompts and completions never leave the European
Union, but they also want more capacity than a single region provides. Which
deployment type fits?

- A. Standard
- B. Global Standard
- C. Data Zone Standard
- D. Provisioned Throughput (PTU)

---

**4.** Which statement about Azure AI Foundry **quota** is correct?

- A. Quota is allocated per deployment and cannot be moved.
- B. Quota is a per-subscription, per-region, per-model-family pool shared across deployments.
- C. Quota is unlimited on pay-as-you-go subscriptions.
- D. Quota is set at the resource group level.

---

**5.** Your app runs locally during development and on an Azure Container App in
production. You want the same authentication code in both. What should you use?

- A. An API key stored in `.env` locally and in App Settings in production
- B. A service principal with a client secret in both environments
- C. `DefaultAzureCredential` — Azure CLI locally, managed identity in production
- D. A shared access signature

---

**6.** After deploying a model you call it and receive **403 Forbidden**. The
deployment shows as Succeeded in the portal. What is the most likely cause?

- A. The model version is deprecated
- B. Your identity lacks a data-plane role such as *Cognitive Services OpenAI User*
- C. The quota is set to zero
- D. The content filter blocked the request

---

**7.** Which two are true of a **Foundry project** (as opposed to a hub-based
project)? Choose two.

- A. It is created directly on the AIServices resource
- B. It requires a separate Azure Storage account and Key Vault
- C. It is the project type used by the Foundry Agent Service
- D. It is required for managed compute and prompt flow

---

**8.** You want a bulk job that classifies 200,000 archived support tickets
overnight, at the lowest possible cost. Which deployment type?

- A. Global Standard
- B. Provisioned Throughput
- C. Batch
- D. Data Zone Standard

---

**9.** What does a **connection** in a Foundry project do?

- A. Opens a private endpoint to a virtual network
- B. Stores the endpoint and authentication for an external resource so tools and agents can use it
- C. Links two projects so they share deployments
- D. Configures the content filter

---

**10.** You delete the resource group containing your Foundry resource, then try to
recreate it with the same name and get *"the account name is already in use."* Why?

- A. The name is reserved globally by another customer
- B. Cognitive Services accounts are soft-deleted and must be purged
- C. DNS propagation has not completed
- D. The resource group deletion has not finished

---

**11.** Which token counts are billed for a reasoning model such as `o4-mini`?

- A. Prompt tokens only
- B. Prompt and visible completion tokens only
- C. Prompt tokens, visible completion tokens, and hidden reasoning tokens
- D. A flat fee per request

---

**12.** You set a budget of $50 with an alert at 100% actual spend. Spend reaches
$50. What happens?

- A. Azure stops the resources in scope
- B. Model deployments are throttled to zero
- C. You receive an email; nothing is stopped
- D. The subscription is disabled

---
---

## Answers

**1 — C.** Agents, evaluations, indexes, and connections all belong to the project,
so the client needs the *project endpoint* (`/api/projects/<name>`). A is the
inference endpoint, used for direct chat and embedding calls. D is the management
plane, used for creating and configuring the resource itself.

**2 — B.** You always call the **deployment name**. The model name only appears when
you create the deployment. This decoupling lets you swap the underlying model
without changing application code — and it is a favourite exam trap.

**3 — C.** Data Zone Standard keeps processing inside a geography (EU or US) while
pooling capacity across the regions in it. Standard (A) is single-region and gives
up the extra capacity; Global Standard (B) may process anywhere in the world and
breaks the residency requirement; PTU (D) is about throughput guarantees, not
residency.

**4 — B.** Quota is a shared pool scoped to subscription + region + model family,
measured in tokens per minute (TPM). Deployments draw from that pool, so a large
deployment can starve others. You can reduce one deployment's TPM to free capacity
for another, or request an increase.

**5 — C.** `DefaultAzureCredential` tries credential sources in order and uses the
first that works — your `az login` locally, the managed identity in Azure. Same
code, no secrets. A and B both require managing secrets; D does not apply to
Foundry.

**6 — B.** A successful deployment plus 403 means authorization, not availability.
Foundry data-plane calls need an RBAC role on the resource: *Cognitive Services
OpenAI User* (inference) or *Azure AI User* (project operations). Control-plane
roles like Contributor do **not** grant data-plane access. Zero quota (C) returns
429; a content filter block (D) returns 400 with a `content_filter` reason.

**7 — A and C.** Foundry projects sit directly on the AIServices resource and are
what the Agent Service, Content Understanding, and current tooling expect. B and D
describe hub-based projects, which add a hub with its own storage and key vault and
remain necessary for managed compute and prompt flow.

**8 — C.** Batch deployments process asynchronously within a 24-hour window for
roughly half the per-token price. There is no latency requirement here, so paying
for Global Standard or reserving PTU capacity would be wasteful.

**9 — B.** A connection is stored endpoint + auth metadata for an external resource
(Azure AI Search, Storage, another AI Services resource, an API). Agents and tools
reference the connection by name instead of handling credentials. Connections can
be project-scoped or shared across the resource.

**10 — B.** Cognitive Services accounts are soft-deleted for 48 hours and the name
stays reserved. Purge it:
`az cognitiveservices account purge -n <name> -g <rg> -l <region>`. The teardown
script does this automatically.

**11 — C.** Reasoning models generate internal reasoning tokens that you are billed
for but never see. They appear in `usage.completion_tokens_details.reasoning_tokens`
and can dwarf the visible output — which is why unit 02.5 has you measure them
before choosing a reasoning model.

**12 — C.** Azure budgets are **notification only**. They do not stop, throttle, or
delete anything. Automated action requires wiring the budget alert to an action
group that runs a runbook or Function. The reliable control is deleting the
resource group.

---

## Lab exercise solutions

**1. Temperature.** At `temperature=0.0` the three responses are near-identical —
decoding is effectively greedy. At `1.5` they diverge sharply and quality degrades:
odd word choices, sometimes incoherence. Use low temperature for extraction,
classification, and anything you will parse; higher for creative drafting. Note that
reasoning models such as `o4-mini` ignore `temperature` entirely.

**2. Bad deployment name.** You get **404 Not Found** with a
`DeploymentNotFound` code. Contrast with **401** (no valid token — you are not
authenticated) and **403** (valid token, insufficient RBAC — you are authenticated
but not authorized). Distinguishing 404 / 401 / 403 quickly is a practical
troubleshooting skill the exam probes.

**3. SKU and capacity.**

```python
d = project.deployments.get(cfg["MODEL_MINI"])
print(d.name, d.model_name, d.model_version)
print(getattr(d, "sku", None))  # name = GlobalStandard, capacity = 30 (thousand TPM)
```

The capacity number is the same TPM value shown under **Management center →
Quota** in the portal. Raising it here consumes more of the shared subscription
pool.

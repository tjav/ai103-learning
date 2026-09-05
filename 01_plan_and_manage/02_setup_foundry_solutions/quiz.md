# 01.2 — Set up AI solutions in Foundry: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** A European bank requires that no prompt or completion is processed outside
the EU, and needs more capacity than a single region can supply. Which deployment
type?

- A. Global Standard
- B. Standard
- C. Data Zone Standard
- D. Global Provisioned Managed

---

**2.** Your chat deployment is consuming most of the subscription's `gpt-4o` TPM
quota and starving a second team. You must reduce it with no downtime for existing
callers. What do you do?

- A. Delete the deployment and recreate it with lower capacity
- B. Update the deployment's SKU capacity in place
- C. Change the deployment type to Batch
- D. Request a quota decrease from Azure support

---

**3.** Which two artefacts **cannot** be created by a Bicep template? Choose two.

- A. A model deployment
- B. An agent
- C. A project connection
- D. An Azure AI Search index definition

---

**4.** Your GitHub Actions workflow uses `azure/login@v2` with no client secret but
fails with `AADSTS700213: No matching federated identity record found`. Which is
the most likely cause?

- A. `permissions: id-token: write` is missing from the workflow
- B. The federated credential's subject does not match the job's actual subject
- C. The service principal has no Contributor role
- D. The subscription ID secret is wrong

---

**5.** An ARM deployment that creates two model deployments on the same account
fails intermittently. What is the fix?

- A. Increase the deployment timeout
- B. Add `dependsOn` so the deployments are serialised
- C. Move each deployment to its own resource group
- D. Switch both to `Standard` SKU

---

**6.** What does `disableLocalAuth: true` on a Foundry account do?

- A. Disables anonymous access to the public endpoint
- B. Rejects API key authentication, forcing Microsoft Entra ID
- C. Prevents local developers from deploying models
- D. Turns off the local Foundry emulator

---

**7.** Which is the strongest reason **not** to use managed compute for a model in
a development environment?

- A. Managed compute does not support Microsoft Entra ID
- B. It bills per VM-hour and does not scale to zero
- C. It cannot be created from Bicep
- D. Content filters cannot be applied

---

**8.** Which two are required for Microsoft Entra ID token authentication against a
Foundry resource? Choose two.

- A. A custom subdomain on the account
- B. A Key Vault storing the account key
- C. A data-plane role assignment such as *Cognitive Services OpenAI User*
- D. Public network access enabled

---

**9.** Your pipeline provisions infrastructure successfully with a Contributor
service principal, but the next step — creating an agent — returns 403. Why?

- A. The agent name is already taken
- B. Contributor is a control-plane role and grants no data-plane access
- C. The project endpoint is wrong
- D. Agents require a Provisioned deployment

---

**10.** In the `azure.yaml` for an `azd` project, what is a `postprovision` hook
typically used for in a Foundry solution?

- A. Building the container image
- B. Creating data-plane artefacts such as agents and indexes
- C. Running `az deployment group what-if`
- D. Assigning subscription-scope RBAC

---

**11.** Which statement about `versionUpgradeOption` is correct?

- A. `NoAutoUpgrade` guarantees the deployment keeps working indefinitely
- B. `OnceCurrentVersionExpired` upgrades only when the pinned version retires
- C. `OnceNewDefaultVersionAvailable` never changes the model version
- D. The setting can only be configured through the portal

---

**12.** A team wants an agent's configuration to be reviewable in pull requests and
identical across dev and prod. What is the correct pattern?

- A. Create the agent in the portal and export it after each change
- B. Store the agent definition as JSON in the repo and apply it with an idempotent
  deploy script after provisioning
- C. Encode the agent instructions in the Bicep template as a parameter
- D. Copy the agent between projects using the portal's duplicate function

---

**13.** Which is **not** a valid reason to deploy a second Foundry resource in a
different region and connect it to the same project?

- A. A model you need is unavailable in the primary region
- B. You have exhausted quota in the primary region
- C. You need to isolate two teams' RBAC from each other
- D. You need lower latency for users in another geography

---

**14.** Your production Bicep sets `publicNetworkAccess: 'Disabled'`. After
deployment, calls from a developer laptop fail. Which two are valid ways to
restore access for an approved operator? Choose two.

- A. Add the operator's IP to the account's `networkAcls.ipRules`
- B. Assign the operator the Owner role
- C. Connect from a VM inside the VNet that holds the private endpoint
- D. Set `disableLocalAuth: false` and use an API key

---
---

## Answers

**1 — C.** Data Zone Standard confines processing to a geography (EU or US) while
pooling capacity across all regions in it — precisely "residency plus more capacity
than one region." A breaks residency by routing globally. B satisfies residency but
gives up the extra capacity, which is the second half of the requirement. D is
about guaranteed throughput and, in its Global variant, also routes globally.

**2 — B.** Deployment capacity is a mutable property; a PATCH updates it with no
change to the name or endpoint and no interruption. A causes an outage for every
caller during the gap and is the trap answer. C changes the billing and latency
model entirely and would break synchronous callers. D misunderstands quota —
quota is a subscription-level ceiling you request *increases* to, not something
attached to one deployment.

**3 — B and D.** Agents and search index definitions are data-plane objects created
through service endpoints, not ARM. That is exactly why an `azd` project needs a
`postprovision` hook. A and C are both genuine ARM resource types
(`accounts/deployments` and `accounts/connections`).

**4 — B.** The error is specifically about subject matching. A job running under
`environment: prod` has subject `repo:<org>/<repo>:environment:prod`, while a push
to main has `repo:<org>/<repo>:ref:refs/heads/main` — different records, and you
usually need both. A produces a different error (no token is requested at all). C
would surface as a 403 later, after login succeeds. D produces a subscription-not-found
error.

**5 — B.** Azure rejects concurrent create/update operations against deployments on
the same Cognitive Services account. Bicep parallelises independent resources by
default, so you must introduce an explicit dependency to serialise them. A does not
address a conflict error. C is not possible — deployments are children of the
account. D changes nothing about concurrency.

**6 — B.** `disableLocalAuth` removes key-based authentication entirely, so every
caller must present an Entra ID token. It is the enforcement mechanism behind the
"keyless credentials" objective — without it, keys still work even if your code
does not use them. A describes network controls; C and D are invented.

**7 — B.** Managed compute is a dedicated always-on endpoint, so an idle dev
deployment costs the same as a busy one — the classic forgotten-resource invoice.
A, C, and D are all false: managed compute supports Entra ID, is deployable from
IaC, and can have content safety applied.

**8 — A and C.** A custom subdomain is a hard prerequisite for token auth (and
cannot be added after the account is created), and you need a data-plane role
because control-plane roles like Contributor grant no inference access. B is the
opposite of keyless. D is irrelevant — Entra ID auth works fine over a private
endpoint.

**9 — B.** Azure separates control-plane actions (create the deployment) from
data-plane actions (create an agent, run an evaluation, call a model). Contributor
covers only the former. The pipeline identity additionally needs **Foundry User**
(formerly *Azure AI User*) on the Foundry resource. Note the roles were recently
renamed; the IDs and permissions are unchanged.

**10 — B.** `postprovision` runs after ARM has created the infrastructure, which is
the only point at which the project endpoint exists and data-plane artefacts can be
created. A is handled by the `services` section. C belongs before provisioning. D
is control-plane work that belongs in the template.

**11 — B.** `OnceCurrentVersionExpired` holds the pinned version until Azure
retires it, then moves — the usual production choice, paired with a regression
evaluation. A is the trap: pinned versions eventually retire and the deployment
stops working, so `NoAutoUpgrade` is a stability choice with an expiry date, not a
permanent guarantee. C inverts the meaning. D is false — it is settable via ARM,
CLI, and SDK.

**12 — B.** Configuration as version-controlled data plus an idempotent apply step
gives you review, diffing, and reproducibility, and it is the pattern the
`postprovision` hook exists to support. A inverts the source of truth. C is
impossible — Bicep cannot create agents. D does not survive review or promotion.

**13 — C.** RBAC isolation is achieved with separate projects or separate resource
groups, not by adding a region — and a second region actually widens the surface
you must secure. A, B, and D are the three legitimate drivers: model availability,
quota exhaustion, and user latency are all per-region facts.

**14 — A and C.** With public access disabled, you either come from inside the
network (private endpoint reachable from the VNet) or you re-open a narrow hole in
the account firewall for a specific IP. B confuses authorisation with network
reachability — Owner still cannot reach a network-blocked endpoint. D is worse than
wrong: re-enabling key auth neither restores connectivity nor is it acceptable
practice.

---

## Lab exercise solutions

**1. Prove the deployment-name contract.** Callers change nothing. The deployment
name is the contract; the model, version, SKU, capacity, and content filter behind
it are all implementation detail. That decoupling is what makes canary and
blue/green model rollouts possible: deploy the new version under a second name,
shift a fraction of traffic, then swap.

`NoAutoUpgrade` is not automatically safe because model versions are **retired on a
published schedule**. Pinning means the deployment eventually stops working — at a
time chosen by Microsoft, not you. The production stance is
`OnceCurrentVersionExpired` (so you never fall off a cliff) combined with a
regression evaluation in the pipeline (so you find out if the new version broke
your prompts). Pinning without a monitoring plan converts a gradual quality risk
into a sudden outage risk.

**2. Find the quota ceiling.**

```python
for u in arm.usages.list(location=cfg["AZURE_LOCATION"]):
    if u.name and "gpt-4o-mini" in u.name.value.lower():
        print(f"{u.name.value}: used {u.current_value} of {u.limit}")

# Then attempt to exceed it:
arm.deployments.begin_create_or_update(RG, ACCOUNT, "too-big", {
    "sku": {"name": "GlobalStandard", "capacity": 100000},
    "properties": {"model": {"format": "OpenAI", "name": "gpt-4o-mini", "version": model_version}},
}).result()
```

You get `InsufficientQuota` with a message naming the requested capacity, the
available capacity, and the quota family. Two things to note for the exam: the
error is a **400 at deployment time**, not a runtime 429, and quota is a *ceiling*
rather than a reservation — holding 30K TPM costs nothing but denies it to others.
Runtime throttling produces `429 Too Many Requests` with a `Retry-After` header,
which is a different failure entirely.

**3. Write the promotion parameter.**

```bicep
@allowed(['dev', 'test', 'prod'])
param environmentName string

var chatSku = environmentName == 'prod'
  ? { name: 'ProvisionedManaged', capacity: 50 }
  : { name: 'GlobalStandard', capacity: 10 }

resource chat 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: 'gpt-4o-mini'
  sku: chatSku
  properties: { model: { format: 'OpenAI', name: 'gpt-4o-mini', version: '2024-07-18' } }
}
```

It is dangerous because a single mistyped parameter provisions hourly-billed
reserved capacity — PTU has a substantial minimum and bills from creation whether
or not a single token flows. Mitigate it the way you would any destructive
parameter: restrict who can run the prod pipeline via a GitHub Environment with
required reviewers, require a `what-if` diff in the pull request, and set an Azure
Policy denying `ProvisionedManaged` SKUs outside the production resource group.

**4. Make the deploy script idempotent — properly.** Agent names are display
labels, not unique keys — Foundry will happily hold three agents called
`support-agent`. Name-matching works until the first partial failure (the create
succeeds, the pipeline times out, the re-run creates a second one), after which
`next(...)` returns an arbitrary member of a growing set and your "update" silently
edits the wrong object.

The fix is to key on the agent **id**, which is stable and unique, and persist it
outside the script:

```python
STATE = pathlib.Path("agents/.state.json")
state = json.loads(STATE.read_text()) if STATE.exists() else {}

agent_id = state.get(LAB_AGENT)
if agent_id:
    agent = agents.update_agent(agent_id=agent_id, **AGENT_DEFINITION)
else:
    agent = agents.create_agent(**AGENT_DEFINITION)
    state[LAB_AGENT] = agent.id
    STATE.write_text(json.dumps(state, indent=2))
```

In a real pipeline the state belongs somewhere shared and durable — a Storage blob
or the `azd` environment — rather than the runner's ephemeral filesystem, for the
same reason Terraform keeps remote state.

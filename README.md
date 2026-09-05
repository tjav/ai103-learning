# AI-103 Katas — Developing AI Apps and Agents on Azure

A hands-on, self-paced course for **Microsoft Certified: Azure AI Apps and Agents
Developer Associate** (Exam **AI-103**), modelled on the Quantum Katas: short
lessons, real labs, and a quiz after every unit.

Every bullet of the [AI-103 study guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/ai-103)
(skills measured as of **16 April 2026**) is mapped to a unit in
[course.json](course.json).

---

## ⚠️ This course spends real money

Labs run against **your own Azure subscription**. Expect roughly **$5–$25** for the
whole course if you follow the teardown guidance, and considerably more if you
leave resources running (Azure AI Search Basic and provisioned model deployments
bill per hour, not per request).

Non-negotiables:

1. `00_setup` creates a **budget alert** — do not skip it.
2. Everything lands in one resource group (`rg-ai103-lab` by default) so
   [99_teardown](99_teardown/README.md) can delete it in a single command.
3. Run the teardown when you finish, even if you plan to return tomorrow.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Azure subscription | Owner or Contributor **+ User Access Administrator** on a subscription. Role assignments are part of the labs. |
| Python | 3.10 – 3.12 |
| Azure CLI | 2.60 or later — `az version` |
| PowerShell | 7+ (`pwsh`) for the setup scripts |
| VS Code / Discovery | With the Python and Jupyter extensions |
| Python skill | The exam assumes you can read and write Python. This course does not teach Python. |

A **Free Trial** subscription will not work for the whole course — several model
SKUs and Azure AI Search are unavailable on free tiers.

---

## Course map

| # | Unit | Study-guide domain | Weight |
|---|---|---|---|
| 00 | [Setup — connect your Azure tenant](00_setup/README.md) | — | — |
| 01.1 | [Choose services and models](01_plan_and_manage/01_choose_services_and_models/README.md) | Plan and manage | 25–30% |
| 01.2 | [Set up AI solutions in Foundry](01_plan_and_manage/02_setup_foundry_solutions/README.md) | Plan and manage | |
| 01.3 | [Manage, monitor, and secure](01_plan_and_manage/03_manage_monitor_secure/README.md) | Plan and manage | |
| 01.4 | [Responsible AI](01_plan_and_manage/04_responsible_ai/README.md) | Plan and manage | |
| 02.1 | [Generative applications](02_genai_and_agents/01_generative_apps/README.md) | GenAI and agents | 30–35% |
| 02.2 | [RAG and grounding](02_genai_and_agents/02_rag_grounding/README.md) | GenAI and agents | |
| 02.3 | [Build agents](02_genai_and_agents/03_build_agents/README.md) | GenAI and agents | |
| 02.4 | [Multi-agent and approvals](02_genai_and_agents/04_multi_agent_and_approvals/README.md) | GenAI and agents | |
| 02.5 | [Optimize and observe](02_genai_and_agents/05_optimize_and_observe/README.md) | GenAI and agents | |
| 03.1 | [Image and video generation](03_computer_vision/01_image_and_video_generation/README.md) | Computer vision | 10–15% |
| 03.2 | [Multimodal understanding](03_computer_vision/02_multimodal_understanding/README.md) | Computer vision | |
| 03.3 | [Responsible AI for multimodal](03_computer_vision/03_responsible_ai_multimodal/README.md) | Computer vision | |
| 04.1 | [Language model text analysis](04_text_analysis/01_language_model_text_analysis/README.md) | Text analysis | 10–15% |
| 04.2 | [Speech solutions](04_text_analysis/02_speech_solutions/README.md) | Text analysis | |
| 05.1 | [Retrieval and grounding pipelines](05_information_extraction/01_retrieval_and_grounding/README.md) | Information extraction | 10–15% |
| 05.2 | [Document extraction](05_information_extraction/02_document_extraction/README.md) | Information extraction | |
| 90 | [Full study-guide summary](90_summary/README.md) — every objective, condensed | — | — |
| 91 | [Cheatsheet (3 pages)](91_cheatsheet/CHEATSHEET.md) | — | — |
| 99 | [Teardown](99_teardown/README.md) | — | — |

Each unit folder contains:

- `README.md` — theory plus a click-by-click **Azure portal** walkthrough
- `lab.ipynb` — the same thing in Python, so you learn both the portal and the SDK
- `quiz.md` — exam-style questions with an answer key at the bottom

---

## Getting started

```powershell
cd ai103-learning

# 1. Python environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Units 01.4, 02.1, 02.2 and 02.4 also need the evaluation SDK.
# On Windows ARM64 read the notes at the top of this file first.
pip install -r requirements-eval.txt

# 2. Connect your Azure tenant and pick a subscription
pwsh scripts/01_connect_azure.ps1

# 3. Create the shared lab resources
pwsh scripts/02_provision_core.ps1     # Foundry resource, project, model deployments
pwsh scripts/03_provision_labs.ps1     # Search, Storage, Speech, Translator, Content Understanding

# 4. Confirm everything is reachable
python scripts/verify_environment.py
```

Then open [00_setup/README.md](00_setup/README.md) and work forward.

Script `01_connect_azure.ps1` writes a `.env` file (git-ignored) with every
endpoint and resource name the notebooks need. See [.env.example](.env.example)
for the full list of variables.

> **Portal-first, script-fallback.** The exam tests the portal experience, so each
> unit walks you through the portal by hand. The provisioning scripts exist so you
> are never blocked, and so teardown is reliable. If you would rather click
> everything yourself, run only `01_connect_azure.ps1` and follow `00_setup`.

> **The portal opens inside this app.** `portal.azure.com`, `ai.azure.com`, and the
> studio sites all work in the integrated browser — just ask the agent to "open the
> Azure portal", or Ctrl/Cmd-click any portal link. Details in
> [00_setup](00_setup/README.md#where-to-open-the-portal).

> **Want a guided portal exercise?** Type **`/portal-walkthrough 02.3`** in chat
> (any unit number). The agent opens the right portal beside your editor and walks
> you through the clicks one step at a time, verifying as you go — **you** click,
> it guides. Add "demo mode" if you would rather watch it drive.

---

## Region — EU by default

Default: **`swedencentral`**.

This course defaults to an **EU region** so lab data stays in the European Union.
Sweden Central is the EU region with the broadest coverage of what the course
needs — Foundry Agent Service, GPT-family and reasoning models, image **and** video
generation, Content Understanding, and the Azure AI Search semantic ranker.

Verified EU coverage of the six models the course deploys:

| Region | Coverage | Missing |
|---|---|---|
| **`swedencentral`** | **6/6** | — |
| `polandcentral` | 5/6 | `sora-2` (video, unit 03.1) |
| `westeurope`, `northeurope`, `francecentral`, `germanywestcentral`, `switzerlandnorth`, `italynorth`, `norwayeast`, `spaincentral` | 4/6 | `gpt-image-1`, `sora-2` (unit 03.1) |

So any EU region runs roughly 90% of the course; only **unit 03.1 (image and video
generation)** is affected elsewhere, and that unit explains how to deploy those two
models into a second region and connect to it — which is itself an exam objective.

Pick a different region with:

```powershell
pwsh scripts/01_connect_azure.ps1 -Location westeurope
```

`01_connect_azure.ps1` queries **live** model availability in whatever region you
choose and warns you before anything is provisioned. Regional availability changes
monthly, so trust that output over any table — including this one.

> **Data residency on the exam.** Region choice is not just a lab detail.
> `Standard` keeps inference in the region, `DataZoneStandard` keeps it within the
> EU or US data zone, and `GlobalStandard` routes worldwide for the best price and
> throughput with **no residency guarantee**. If a question mentions EU data
> residency, `GlobalStandard` is wrong. Unit 01.2 covers this in full.

---

## Progress tracking

Progress lives in [`../ai103-learning.json`](../ai103-learning.json), using the same
schema as `qdk-learning.json`:

```json
{
  "version": 1,
  "position":    { "courseId": "ai103", "unitId": "...", "activityId": "..." },
  "completions": { "ai103__<unit>__<unit>__<activity>": { "completedAt": "<ISO 8601>" } },
  "startedAt":   "<ISO 8601>"
}
```

Mark an activity done by adding its key to `completions`, or ask the agent:
*"mark 01_choose_services_and_models complete"*.

---

## Exam facts

| | |
|---|---|
| Exam | AI-103, *Developing AI Apps and Agents on Azure* |
| Duration | 120 minutes, proctored, may include interactive labs |
| Passing score | 700 / 1000 |
| Price | $165 USD (varies by country) |
| Languages | English, Chinese (Simplified/Traditional), French, German, Italian, Japanese, Korean, Portuguese (BR), Spanish |
| Renewal | Free online assessment, annually |

Official practice assessment: [AI Skills Navigator](https://aiskillsnavigator.microsoft.com/credentials/cert-3fb198f57997226a824aa5f52a1a22af9a4597941b2288ed39371c7a9e6bd7c9) ·
[Exam sandbox](https://go.microsoft.com/fwlink/?linkid=2226877)

---

## Disclaimer

This is unofficial study material. Azure AI services change quickly — where this
course and [Microsoft Learn](https://learn.microsoft.com/azure/ai-foundry/) disagree,
Microsoft Learn wins. Content authored against the study guide dated 16 April 2026.

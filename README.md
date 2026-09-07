# AI-103 — Developing AI Apps and Agents on Azure

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

### Optional Learning extension workflow

This **public AI-103 course repository** stays separate from the
[Cert Learner extension repository](https://github.com/tjav/cert-learner).
The workflow below describes **v0.2.0**, available from the extension's
[GitHub Releases](https://github.com/tjav/cert-learner/releases).
Both repositories can be read without private-repository access.

1. Download the Cert Learner VSIX and verify its published SHA-256 checksum,
  then use **Extensions: Install from VSIX...** in VS Code / Discovery. Reload
  if prompted. The course remains usable without the extension.
2. Open this local course folder; its root [course.json](course.json) is discovered
  automatically. For another location, choose **Learning: Add Course → Local folder**
  and select the **course folder containing the manifest**, not the manifest file.
  To obtain a new copy, choose **GitHub repository** instead (details below). In
  **Learning**, read **Course overview** or choose a unit and activity; use
  **Learning: Resume Course** to return later. If these commands are unavailable,
  use the file-based course workflow below until a compatible build is installed.
3. Expand a unit for its activities followed by **Lab** and **Quiz** children.
  These open the same resources as the lesson panel's **Open lab / Open quiz**
  buttons, without changing the current activity, resume position, or progress.
  They are resources, not additional tracked activities. For a lab, select
  your intended Python environment with the notebook's **Select Kernel** control.
  Run only the cells you have reviewed. **Never Run All blindly: final cleanup
  cells can delete resources.**
4. Use **Mark complete** for your own learning record and **Reset progress** to
  reset that unit's record, not its files; review the scope before confirming.
  AI-103 completion is
  **manual and self-reported, not verified competence or an exam score**. There
  are no automated cloud checks in this manifest.
5. Optionally use Copilot **@certlearning** for an explanation or hint, if that
  participant is available in your installed build. This is a **read-only tutor
  without browser/file tools**, not the general Agent workflow. Copilot is not required.
6. **Portal walkthrough** and **Revert unit** appear alongside **Explain** / **Hint**
  in **Activity tools**. The equivalent commands are **Learning: Portal Walkthrough**
  (`certLearner.portalWalkthrough`) and **Learning: Revert Unit** (`certLearner.revertUnit`).
  They require a trusted workspace and the corresponding existing fixed prompt:
  [.github/prompts/portal-walkthrough.prompt.md](.github/prompts/portal-walkthrough.prompt.md)
  or [.github/prompts/revert-unit.prompt.md](.github/prompts/revert-unit.prompt.md).
  Missing/invalid prompts disable the corresponding panel button; commands also
  validate availability. Choose **Prepare draft** in the explicit modal, then
  **select general Agent mode, review, and submit the draft yourself**. Use general
  Agent mode, not `@certlearning`, for browser/file tools. If chat cannot open,
  **Copy draft** offers the same request without running it.

**GitHub add:** enter `https://github.com/tjav/ai103-learning` (optional `.git`),
choose an existing local **parent folder**, then review and confirm the exact new
repository-named child destination. Only HTTPS repository-root URLs and the default
branch are supported, not SSH, tree/blob, branch/subfolder links, or URL parameters.
Installed Git, workspace trust, and network access are required. Any existing
destination is refused, **even an empty folder**. This public course does not
require GitHub authentication to clone. For other, private course repositories,
sign in separately with Git/Git Credential Manager first; previously configured
trusted credential helpers supply private access noninteractively.
**Never paste credentials or tokens into the input.**
The clone skips hooks and submodules, then checks out with isolated Git configuration
to suppress filters; no course checks, notebook cells, requirements installation,
or provisioning runs. Trusted authentication helpers may run, so this is **not a
whole-process sandbox**. Failed/canceled clones retain any created folder, possibly
partial, without registration. Missing/invalid root [course.json](course.json)
also leaves the clone unregistered; use **Add Course → Local folder** on a valid
course subfolder if applicable. There is no automatic course update/sync.

**Practice grading:** **Quiz** reads the existing unit Markdown using the strict
[authoring grammar](AUTHORING.md#quiz-compatibility-in-cert-learner-v020); originals
remain readable and unchanged. Single-answer radio clicks immediately show
**Correct / Incorrect**, the correct option, and the authored explanation. For
multiple answers, select exactly the displayed count of checkboxes and choose
**Check answer**: the selected set must match every correct option, in any order.
Each correct first submission earns one point; incorrect answers earn zero, with
no partial credit or repeat-click points. **Previous / Next** review and advance;
**Finish quiz / Summary** shows results, and **Restart / Retry quiz** clears that
attempt after confirmation when answers exist. Unsupported formats show
**Interactive quiz unavailable** with **Open source** when safely resolvable;
answers are never guessed. Structured JSON is also supported for authored quizzes.

Attempts survive closing/reopening the panel within the **same extension session**,
but not an extension/VS Code restart. Source edits invalidate the old attempt when
reread. **Persistent quiz scores are intentionally not implemented**: quiz results
are not exported, do not complete activities, and do not change learning position.
Unit/course **Reset progress** is unchanged and separate from quiz **Restart**.
Feedback follows the **source author's key**, not AI or freshly checked Microsoft
documentation; it is not an official exam result or evidence of certification.
The initial client HTML does not contain the full raw answer key, but **Open source**
remains available for self-study. This is not a secure exam system.

The tree shows **Course overview first, units next, then summary, cheatsheet, and
teardown reference leaves** in manifest order. The manifest's optional `overview`
points to this [README.md](README.md); when omitted, the extension falls back to a
root README only if it exists. Overview/reference pages use a separate read-only
panel with sanitized Markdown and **Open source**. Images and local links are not
loaded; safe HTTPS links need confirmation. These pages contribute **zero** to
activity counts and do not change completion or resume position. Opening teardown
only displays guidance; it never runs cleanup.

Activity-tool drafts are normal-language requests containing the **exact local
course root, prompt, manifest, and lesson paths**, plus course/unit/activity
metadata, **not file bodies, environment values, or credentials**. Review local
paths and metadata before sharing. The Agent is asked to read those specific files
only after you submit; global slash-command discovery is not required. If those
paths are inaccessible, ask for help rather than substitute another course.
Clicking either button does **not** run code, change files, reset progress, or
mark anything complete. Portal guidance requires separate approval for resource
changes or billable actions. Revert requires a verified authored source baseline,
a backup including unsaved work, and explicit confirmation before any local discard;
without a verified baseline or backup, source restoration must stop. Progress reset
is a separate extension **Reset progress** action, never a hidden/legacy-storage
edit, and revert never touches cloud resources.

**Zero auto-run:** installing the extension, adding a course, opening a lesson,
lab or quiz, and navigating activities must not run cells, checks, provisioning, or
cleanup. Execution is always an explicit learner decision. Resetting progress
does not clean up Azure resources; follow [teardown](99_teardown/README.md).

### Prepare labs when ready

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

Then open [00_setup/README.md](00_setup/README.md) and work forward. You can read
and run everything manually, or use the workspace prompts below for guided help.

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

## Contributions and main-branch access

You can propose changes through issues or pull requests from your fork.
**Only [tjav](https://github.com/tjav) may merge pull requests into `main` or
update `main` directly.** GitHub repository rules enforce this; the code-owner
entry in [.github/CODEOWNERS](.github/CODEOWNERS) identifies the reviewer but
does not grant write or merge access.

Never include credentials, local environment files, learner progress, or saved
notebook outputs in a contribution. Public visibility is not an open-source
license grant; no license is added by this publication.

## Using the course prompts

The reusable prompts are in [.github/prompts](.github/prompts). In VS Code or
Discovery **general Agent chat**, type `/`, choose a prompt, and add a unit number
or topic. These workspace prompts are separate from the tool-free `@certlearning`
tutor. If a prompt does not appear immediately after cloning, reload the editor window so it
discovers the workspace prompt files. The extension's activity-tool drafts instead
name the exact local prompt file, so they do not depend on slash-command discovery.

| Prompt | What it does | Example |
|---|---|---|
| **`/explain`** | Adds context to a unit, topic, portal field, exam distinction, or selected code. It reads the course material, explains the idea in plain English, gives an example and exam lens, and links to current official Microsoft Learn documentation. It is read-only. | **`/explain 01.2 DataZoneStandard vs GlobalStandard`** |
| **`/portal-walkthrough`** | Opens the correct Azure or Foundry portal in the integrated browser and teaches one screen at a time. It verifies the tenant and what you build. Navigation is automatic; resource changes require confirmation because they can cost money. | **`/portal-walkthrough 02.3`** |
| **`/revert-unit`** | Plans a selected-unit local restore only after verifying an authored baseline, backing up saved and unsaved work, and obtaining explicit confirmation. Offers separate undoable native output clearing and Learning UI **Reset progress**; never edits hidden/legacy progress or touches cloud resources. | **`/revert-unit 01.2`** |

Useful examples:

- **`/explain 02.2 RAG`** — understand retrieval-augmented generation before the lab.
- **`/explain why managed identity is preferred over API keys`** — explain a topic without knowing its unit number.
- Select code in a notebook, then use **`/explain this code`** — get a line-by-line mental model without receiving the full lab solution.
- **`/portal-walkthrough 01.3 let me click`** — you drive while the agent gives exact click paths and verifies each screen.
- **`/portal-walkthrough 01.2 demo mode`** — the agent navigates while narrating each screen; it still asks before any write or billable action.
- **`/revert-unit 00`** — review a safe local redo plan and separately reset setup progress in the Learning UI without touching the shared Azure environment.

The prompts use the **Course map** above to resolve friendly numbers such as
`01.2`, then [course.json](course.json) for the unit objectives. You can also name
a topic instead of a number. `/explain` uses Microsoft Learn as the source of truth
when Azure documentation has changed; `/portal-walkthrough` uses the unit
instructions plus what is actually visible in your tenant.

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

**When using Cert Learner, the extension is authoritative.** Use the Learning UI
to complete or reset activities and its progress export/import commands to move
records. Do not read or edit the extension's hidden storage, and do not update
[ai103-learning.json](ai103-learning.json) to represent extension progress. An
assistant may query `certLearner.getState` through a supported extension-command
interface if available; otherwise use the Learning UI, not a storage-file fallback.

**Legacy workflow — only when not using the extension:** progress lives in
[ai103-learning.json](ai103-learning.json):

```json
{
  "version": 1,
  "position":    { "courseId": "ai103", "unitId": "...", "activityId": "..." },
  "completions": { "ai103__<unit>__<unit>__<activity>": { "completedAt": "<ISO 8601>" } },
  "startedAt":   "<ISO 8601>"
}
```

In legacy mode only, mark an activity done by adding its key to `completions`, or
ask the agent: *"mark 01_choose_services_and_models complete"*. This is also manual,
unverified progress; it is not automatically synchronized with the extension.

The manifest now declares format `cert-learner`, schema version **1**, and content
version **1.0.0**. This is an additive metadata adaptation: the existing **17 units,
62 activities, and 64 objective entries**, their IDs and wording, and the
**16 April 2026** study-guide version are unchanged. Summary, cheatsheet, and
teardown are supplemental resources, not extra units. The optional main overview
and those reference pages are presentation-only and add **zero** tracked activities;
exposing them does not require a `contentVersion` bump. The current content version
remains **1.0.0** and schema version remains **1**. Unit Lab/Quiz children and
session-only quiz grading likewise add no activities or course completions.

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

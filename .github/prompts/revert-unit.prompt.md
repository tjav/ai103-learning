---
name: "Revert unit"
description: "Reset one AI-103 unit so you can do it again. Uses Learning UI progress reset when Cert Learner is active, or ai103-learning.json only without the extension; clears your work in lab.ipynb and quiz.md, and removes local artifacts. Never deletes Azure resources — that is teardown. Use when a lab has gone sideways, when you want a clean second attempt, or when you are handing the course to someone else. Trigger phrases: revert unit, reset unit, redo this unit, undo my changes, start this unit over, clean slate, restore the lab, roll back unit."
argument-hint: "Unit number to revert, e.g. 02.3 (or 'all' to reset the whole course)"
agent: "agent"
---

# Revert a unit

Reset one unit of the AI-103 course described in the [main README](../../README.md)
so the learner can do it again from scratch.

The unit to revert is in the prompt argument. If it is empty, check the active
editor for an open unit file and offer that one; otherwise list the units from
the Course map in `README.md` and ask.

> **Progress authority:** if Cert Learner is active, query `certLearner.getState`
> through a supported extension-command interface if available. Use Learning UI
> reset/complete controls; never inspect or edit hidden extension storage. If the
> query is unavailable, ask the learner to use the UI, not the legacy file.
> [ai103-learning.json](../../ai103-learning.json) applies only without the
> extension. Manual completion is a self-report, not a verified assessment.

## The one rule that matters

**Revert means "let me do this unit again". It resets learning state, never cloud
state.**

So the default action — the one you take unless told otherwise — is:

1. **Reset progress** through the Learning UI when using Cert Learner; use
  [ai103-learning.json](../../ai103-learning.json) only without the extension.
2. **Clear the learner's work** in `lab.ipynb` / `quiz.md`, if there is any.
3. **Remove local artifacts** — `__pycache__`, checkpoints, generated files.

**Revert never deletes Azure resources.** Not one deployment, not one index, not
one agent. That is teardown, and it lives in
`99_teardown/README.md`. If the learner wants resources gone, point
them there and stop — do not do it from this prompt.

The reason is unit 00. It is the unit that *created the whole lab environment*, so
"revert unit 00" and "destroy the course" would be the same operation if revert
touched Azure. Every other unit has the same problem in miniature: unit 05.1
builds the index 05.2 queries. Learning state is per-unit; cloud state is not.

Still show what will be lost before clearing files, and wait for a yes if the loss
is non-trivial. Never widen scope beyond the unit they named.

## Step 1 — Resolve the unit and find its files

Use the Course map links in `README.md` to map the friendly unit number to its
folder, then read `course.json` for the unit's activities. List what actually
exists:

```powershell
$unit = '02_genai_and_agents/03_build_agents'   # from course.json
Get-ChildItem $unit -Recurse -File | Select-Object FullName, Length, LastWriteTime
```

## Step 2 — Show what will be lost, before touching anything

Do not summarise this vaguely. Be concrete. Count what is actually there:

```powershell
& .venv\Scripts\python.exe -c "import json;nb=json.load(open('$unit/lab.ipynb',encoding='utf-8'));c=[x for x in nb['cells'] if x['cell_type']=='code'];print('code cells',len(c),'| with outputs',sum(1 for x in c if x.get('outputs')),'| executed',sum(1 for x in c if x.get('execution_count')))"
```

A lab with **zero outputs and zero executions is an untouched scaffold** — say so
plainly and skip the ceremony. There is nothing to lose and no confirmation needed.

**Check whether this is even a git repository first:**

```powershell
git -C . rev-parse --is-inside-work-tree 2>$null
```

If it is, use git and offer a stash as the escape hatch:

```powershell
git -C . status --short -- $unit
git -C . stash push -u -m "ai103 revert $unitNumber" -- $unit
```

**If it is not a repository, there is no built-in undo.** Say
that out loud, and take a real copy before clearing anything:

```powershell
Copy-Item "$unit/lab.ipynb" "$unit/lab.ipynb.bak" -Force
```

Then report in this shape:

- **`lab.ipynb`** — N code cells, M with saved output. No git here, so **this
  cannot be recovered** unless I copy it first.
- **`quiz.md`** — unmodified, nothing to lose.

## Step 3 — Revert the files (layer 1)

Prefer git, because it restores the exact authored state:

```powershell
git -C . checkout HEAD -- "$unit/lab.ipynb"
git -C . checkout HEAD -- "$unit/quiz.md"
```

If the file is untracked or git is unavailable, clear the notebook by hand instead
— empty every `source` in cells the learner was meant to fill, and drop all
`outputs` and `execution_count`. **Never delete a `lab.ipynb`**; the scaffold and
its markdown explanations are the course content, not the learner's work.

If they only want outputs cleared while keeping their code, do that alone:

```powershell
& .venv\Scripts\python.exe -m jupyter nbconvert --clear-output --inplace "$unit/lab.ipynb"
```

Offer this variant explicitly — "just clear the outputs, keep my code" is a common
and much less destructive intent than a full revert.

## Step 4 — Reset progress

**With Cert Learner:** use the Learning UI's **Reset progress** control for the
selected unit, review its scope, and follow its confirmation. If this build only
offers a course-wide reset, do not use that for a one-unit request; stop and explain
the limitation. Re-query `certLearner.getState` through the supported interface if
available, or ask the learner to confirm the UI state. Never edit hidden storage
or the legacy progress file. A progress reset does not execute cleanup cells.

### Legacy reset — only when not using the extension

Edit [ai103-learning.json](../../ai103-learning.json):

- Delete every key in `completions` belonging to this unit.
- If `position.unitId` is this unit, set `position.activityId` back to the unit's
  **first** activity from `course.json`. If the learner has moved past this unit,
  leave `position` where it is — resetting a past unit should not drag them
  backwards.
- Leave every other unit's completions untouched.

Check the state before editing. If `completions` is already empty and the position
is already at the unit's first activity, **the reset is a no-op — say so rather
than pretending you changed something.**

```powershell
& .venv\Scripts\python.exe -c "import json;p=json.load(open('ai103-learning.json',encoding='utf-8'));print(p['position']);print([k for k in p.get('completions',{})] or 'no completions')"
```

## Step 5 — Azure: report, never delete

Revert does not touch Azure. But it is useful to **tell** the learner what the unit
left behind, so they can decide for themselves.

Read `.env` from the repository root for their real names — never placeholders — then list
what exists and what it costs at rest:

```powershell
az resource list -g $env:AZURE_RESOURCE_GROUP -o table
az cognitiveservices account deployment list -n $env:AZURE_AI_FOUNDRY_RESOURCE `
    -g $env:AZURE_RESOURCE_GROUP -o table
```

Be accurate about billing, because it decides whether they need to act at all:

| Resource | Bills while idle? |
|---|---|
| Serverless model deployments (`Standard`, `DataZoneStandard`, `GlobalStandard`) | **No** — per token only |
| Agents, threads, indexes, analyzers | No |
| Log Analytics | Per GB ingested; nothing ingesting = nothing |
| Azure AI Search **Basic** | **Yes — ~$75/month** |
| Provisioned / PTU deployments, fine-tuned deployments, managed compute | **Yes — per hour** |

If nothing bills hourly, say plainly that **there is no financial reason to delete
anything** — that is usually the answer, and it saves them rebuilding an
environment for no benefit.

If they do want resources gone, send them to
`99_teardown/README.md`. Do not delete on their behalf here, even if
asked directly — the teardown guide exists so that deletion is deliberate, ordered,
and aware of the 48-hour Cognitive Services name reservation.

## Step 6 — Local artifacts

Safe to remove without much ceremony, but still list them first:

```powershell
Get-ChildItem $unit -Recurse -Include __pycache__,*.pyc,.ipynb_checkpoints |
    Remove-Item -Recurse -Force
```

Leave `.env` alone. It is shared by every unit, and deleting it means re-running
`scripts/01_connect_azure.ps1`.

## Step 7 — Verify and close out

Prove the revert rather than asserting it — check extension state through the
supported command or Learning UI (re-read the legacy progress file only without
the extension), and re-read notebook cell counts. Show the actual numbers; do not
claim a reset happened if the learner has not confirmed the UI action.

Then end with:

- **What was reset**, in two or three lines.
- **What was deliberately kept** — the Azure environment, `.env`, other units.
- **How to get their work back**, if you stashed or copied it.
- **Where to restart**: the unit's `README.md`, or `/portal-walkthrough <unit>`
  for the guided portal version.

## Notes

- `.env` is git-ignored. Git will never restore it and
  `git checkout` will never destroy it.
- Notebook outputs can hold model responses, sample data, and occasionally keys.
  Clearing outputs before committing is good hygiene — mention it if you see keys.
- **Unit `00` is the trap.** It created the Foundry resource, the project, and every
  model deployment the rest of the course depends on. Resetting its progress is
  fine and costs nothing. Deleting what it built is a full course teardown — which
  is exactly why revert stops at learning state.
- `all` is a legitimate argument: reset progress, files and artifacts across every
  unit. It still does not touch Azure.
- This course is normally cloned as a git repository, but always verify before
  relying on `git checkout` or `git stash`; fall back to a `.bak` copy if needed.

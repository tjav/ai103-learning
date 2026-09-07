# Authoring guide (contributors only)

Read this before adding or editing a unit. It exists so every unit feels like it
was written by one person.

## Cert Learner manifest contract

[course.json](course.json) is course metadata, not learner progress. The authoritative
contract is the parent extension's [schema](../cert-learner/schemas/course.schema.json)
and [core types and path validation](../cert-learner/src/core/course.ts), not a new
course-specific validator. The sibling checkout links assume the two repositories
are side by side; the extension's planned home is
[tjav/cert-learner](https://github.com/tjav/cert-learner).

- Required root fields: `format: "cert-learner"`, `schemaVersion: 1`,
  `contentVersion: "1.0.0"`, `courseId`, `title`, and a nonempty `units` array.
  Keep `contentVersion` distinct from the existing `studyGuideVersion` date.
  Optional metadata includes `studyGuideUrl`, `studyGuideVersion`, `language`,
  `references` (objects with `title` and HTTPS `url`), and root `resources`
  (objects with `title` and `path` to Markdown files).
- Each unit requires `unitId`, string `displayNumber`, `title`, `resources`, and
  nonempty `activities`; `domain` is optional and may be null. Preserve existing
  extension-independent metadata such as `weight` and the root `$comment`.
- Resolve friendly numbers from the [README course map](README.md#course-map):
  match the **parent folder basename of each lesson link** to `unitId`, not its
  friendly link text. For example, `01.2` maps to `02_setup_foundry_solutions`.
  Store the map's number as `displayNumber`; never rename an ID to match it.
- Unit `resources.lesson` is required Markdown; optional `resources.lab` is a
  notebook and optional `resources.quiz` is Markdown. Every path is **relative to
  the course root**, not the unit folder, and uses forward slashes. Declare exact,
  existing files: do not infer a lab from its unit ID. Paths must remain within
  the root, including symlink targets; no absolute paths, traversal, hidden paths,
  credential files, or reserved filenames. The root resources for **90**, **91**,
  and **99** remain supplemental Markdown, not units or activities.
- Activities require `activityId`, `title`, and `objectives` (an array that may
  be empty). Unit IDs must be unique within a course; activity IDs within a unit.
  IDs are nonempty strings of at most 128 characters without control characters.
  Preserve all existing IDs, titles, objective wording, and array order.
- `completion` is `"manual"` by default when omitted. **All AI-103 activities
  remain manual**: progress is self-reported, not proof of a successful cloud lab,
  exam readiness, or verified competence. Do not invent cloud validators.
- A deliberately check-based activity uses `completion: "check"` and a `check`
  object with `runtime` (`node`, `python`, or `pwsh`) and root-relative `file`.
  Optional `cwd` is root-relative (`"."` means the course root); optional
  `timeoutSeconds` is an integer from 1 to 3600 in the schema, although the runner
  may impose a lower cap. Do not add arbitrary command strings or arguments.
  Checks receive `--result` and `--run-id`; a result has `schemaVersion: 1`, the
  exact `runId`, `status`, and nonempty `checks` with unique `id`, `status`, and
  optional `message`. Status is `passed`, `failed`, or `blocked`; all individual
  checks must pass for an overall pass. Checks require explicit approval and
  trust, are not sandboxed, and must never run on course load or navigation.

This adaptation adds metadata only: **17 units, 62 activities, and 64 objective
entries** remain unchanged, against the study guide dated **16 April 2026**.
Before a future content revision, review the intended `contentVersion` change
without renaming stable IDs or silently changing the study-guide version.

**Progress authority:** when Cert Learner is active, query `certLearner.getState`
through a supported extension-command interface if available, and use Learning UI
**Mark complete** / **Reset progress** controls. If the query is unavailable, ask
the learner to use the UI; never inspect or edit hidden extension storage. The
legacy [ai103-learning.json](ai103-learning.json) workflow applies only when not
using the extension. **Zero auto-run:** authors must not trigger notebook cells,
checks, provisioning, or cleanup merely by opening course content. Learners select
their own notebook kernel; never advise blind **Run All**, because labs include
cleanup cells.

## Unit anatomy

```
<domain_folder>/<NN_unit_name>/
├── README.md    theory + portal walkthrough
├── lab.ipynb    the same ground in Python
└── quiz.md      10–15 exam-style questions + answer key + lab solutions
```

## README.md

Required order:

1. `# NN — Title` matching `course.json`
2. A `**Time:** … · **Cost:** …` line — be honest about both
3. A `- [ ]` checklist of what the reader will have built by the end
4. **Concepts** — the decisions and vocabulary the exam actually tests
5. **Portal walkthrough** — numbered, click-by-click, with a table for every form
   the reader fills in. Name the exact blade and button labels.
6. A `<details>` block giving the script or CLI alternative
7. **Troubleshooting** — real errors, verbatim, with the fix
8. Links to `quiz.md` and the next unit

Rules:

- **Explain the decision, not just the button.** "Choose Global Standard" is
  worthless without "because it pools capacity globally and gets the highest quota,
  at the cost of data residency."
- Every study-guide bullet assigned to the unit in `course.json` must be visibly
  taught. Do not paraphrase the bullet as a heading and move on.
- Comparison tables beat prose for anything the exam might contrast
  (deployment types, search modes, evaluator families, oversight modes).
- Mark preview features as preview.
- Call out exam traps explicitly with `> **Exam note.**`
- Link to Microsoft Learn for depth; never copy their prose.

## lab.ipynb

- First code cell is always:

  ```python
  import sys, pathlib
  sys.path.insert(0, str(pathlib.Path.cwd().parents[1] / "scripts"))
  from ai103 import cfg, credential, chat_client, project_client
  ```

  (`parents[0]` in `00_setup`, which is one level shallower.)

- Use helpers from `scripts/ai103.py`. Do not re-implement client construction.
- Default to `cfg["MODEL_MINI"]`. Use `MODEL_CHAT` only when you genuinely need
  the stronger or multimodal model, and say why in the markdown above the cell.
- Entra ID auth only. If a service forces a key, say so and explain why.
- Markdown cells carry the teaching; code cells stay short.
- End with an **Exercise** section of 2–4 tasks and an empty cell, with solutions
  in `quiz.md`.
- Clean up what you create (agents, indexes, deployments) in a final cell.

## quiz.md

- 10–15 questions in the exam's style: a short scenario, then a decision.
- Mix single-answer, choose-two, and "which is **not**".
- Answers go at the bottom under `## Answers`, each explaining **why the wrong
  options are wrong** — that is where the learning is.
- Finish with `## Lab exercise solutions`.

## Tone

Direct and technical. Assume a competent developer who has not used Azure AI
before. No filler, no cheerleading, no emoji. Where a service is genuinely awkward
or a limitation will bite, say so.

## Cost

Any lab that creates an hourly-billed resource must say so at the top and delete it
at the end. Azure AI Search, provisioned deployments, and running agents are the
usual offenders.

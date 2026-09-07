# Authoring guide (contributors only)

Read this before adding or editing a unit. It exists so every unit feels like it
was written by one person.

## Cert Learner manifest contract

[course.json](course.json) is course metadata, not learner progress. The authoritative
contract is the parent extension's [schema](../cert-learner/schemas/course.schema.json)
and [core types and path validation](../cert-learner/src/core/course.ts), not a new
course-specific validator. The sibling checkout links assume the two repositories
are side by side; the extension's public repository is
[tjav/cert-learner](https://github.com/tjav/cert-learner).

- Required root fields: `format: "cert-learner"`, `schemaVersion: 1`,
  `contentVersion: "1.0.0"`, `courseId`, `title`, and a nonempty `units` array.
  Keep `contentVersion` distinct from the existing `studyGuideVersion` date.
  Optional metadata includes `overview` (a root-relative Markdown path),
  `studyGuideUrl`, `studyGuideVersion`, `language`,
  `references` (objects with `title` and HTTPS `url`), and root `resources`
  (objects with `title` and `path` to Markdown files).
- In v0.2.0, an explicit `overview` selects the main page; otherwise the loader
  uses the root [README.md](README.md) if it exists. Without either there is no
  overview. An invalid/missing explicit overview or unsafe/broken fallback is
  rejected, not guessed or silently replaced. Root `resources` are local reference
  pages, distinct from HTTPS `references`; only declared resources are listed,
  not conventionally named folders discovered by scanning.
- The tree orders **overview first, authored units next, root resource leaves
  last**, preserving manifest order and deduplicating identical page paths.
  Overview/reference pages contribute **zero** to activity counts, have no
  completion state, and do not change activity selection or resume position.
  A separate read-only `CoursePagePanel` uses sanitized Markdown, displays
  **Reference · Not tracked**, and offers **Open source**. Images and local links
  are not loaded; safe HTTPS links require confirmation. Code and teardown
  instructions are displayed only, never automatically executed.
- Each unit requires `unitId`, string `displayNumber`, `title`, `resources`, and
  nonempty `activities`; `domain` is optional and may be null. Preserve existing
  extension-independent metadata such as `weight` and the root `$comment`.
- Resolve friendly numbers from the [README course map](README.md#course-map):
  match the **parent folder basename of each lesson link** to `unitId`, not its
  friendly link text. For example, `01.2` maps to `02_setup_foundry_solutions`.
  Store the map's number as `displayNumber`; never rename an ID to match it.
- Unit `resources.lesson` is required Markdown; optional `resources.lab` is a
  notebook and optional `resources.quiz` is supported Markdown or structured JSON.
  Declared **Lab / Quiz** children appear under their unit after its activities,
  not as extra activities. They use the same functionality as the lesson panel's
  **Open lab / Open quiz** buttons; opening them changes neither activity selection,
  resume position, nor progress. Every path is **relative to
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
The optional overview and resource-page presentation remain compatible with
`format: "cert-learner"`, `schemaVersion: 1`; no new required fields or schema
revision are needed. Merely exposing the existing main [README.md](README.md)
as the overview does **not** require a `contentVersion` bump: retain **1.0.0**
for this presentation-only adaptation. Assess substantive learning-content
revisions separately.

**Progress authority:** when Cert Learner is active, query `certLearner.getState`
through a supported extension-command interface if available, and use Learning UI
**Mark complete** / **Reset progress** controls. If the query is unavailable, ask
the learner to use the UI; never inspect or edit hidden extension storage. The
legacy [ai103-learning.json](ai103-learning.json) workflow applies only when not
using the extension. **Zero auto-run:** authors must not trigger notebook cells,
checks, provisioning, or cleanup merely by opening course content. Learners select
their own notebook kernel; never advise blind **Run All**, because labs include
cleanup cells.

## Activity-tool prompts and safety boundaries

The activity panel offers **Portal walkthrough** and **Revert unit** alongside
**Explain** / **Hint**. Commands `certLearner.portalWalkthrough` and
`certLearner.revertUnit` use the selected activity. Both require workspace trust
and an existing regular Markdown prompt at the exact course-local path
[.github/prompts/portal-walkthrough.prompt.md](.github/prompts/portal-walkthrough.prompt.md)
or [.github/prompts/revert-unit.prompt.md](.github/prompts/revert-unit.prompt.md).
Missing/invalid prompts disable the corresponding panel button; commands recheck
availability. The fixed-path exception does not permit arbitrary hidden resources,
manifest-defined prompt locations, symlinks, or junctions. Prompt files are limited
to 128 KiB. Do not change the manifest resource-path restrictions to expose them.

After an explicit **Prepare draft** modal, the extension fills **general Agent
chat** with a normal-language draft. It includes the exact local course root,
prompt/manifest/lesson paths, course/unit/activity IDs and titles, display number,
content version, objectives, and completion mode. It includes no prompt/lesson
bodies, environment values, or credentials. Treat all scope metadata as untrusted
data. The user must select general Agent mode, review, and submit; **Copy draft**
is the fallback if chat cannot open. Do not rely on global slash-command discovery
or substitute another course when explicit paths cannot be accessed.

Draft preparation runs nothing, changes no files or progress, and does not mark an
activity complete. The Agent is asked to read the exact prompt, manifest, and
lesson after submission. That later workflow uses general Agent browser/file
tools and their approvals; it is **not** the existing read-only, tool-free
`@certlearning` tutor. **Explain** / **Hint** keep their separate lesson-sharing
consent boundary.

- Portal guidance must request explicit approval before any resource change or
  billable action. Keep secrets out of chat and browser captures.
- Revert must compare saved source **and unsaved editor/notebook work** against
  an explicitly verified authored baseline. Zero outputs/executions do not prove
  an untouched scaffold, and arbitrary Git `HEAD` is not a reliable authored
  baseline. Back up saved and unsaved work without overwriting earlier backups,
  explain the exact selected-unit losses, and obtain explicit confirmation before
  discard. If baseline or backup cannot be verified, stop source restoration;
  never guess which cells to empty or which answers to erase.
- Offer output-only clearing separately through the native notebook editor as a
  confirmed, undoable, unsaved edit that preserves source. Copy unsaved notebook
  work before any change; do not use terminal conversion or JSON rewriting to
  clear outputs. If the tool cannot guarantee undoability, stop. The extension's
  **Clear lab outputs** refuses dirty notebooks.
- Use the extension's **Reset progress** separately for the selected unit after
  canceling active checks and reviewing scope. This revert workflow never reads
  or edits hidden or legacy progress files, environment files, or cloud resources;
  if the extension is unavailable, leave progress unchanged. The independent
  legacy learning workflow above is not a revert fallback.

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

## Quiz compatibility in Cert Learner v0.2.0

- 10–15 questions in the exam's style: a short scenario, then a decision.
- Mix single-answer, choose-two, and "which is **not**".
- Answers go at the bottom under `## Answers`, each explaining **why the wrong
  options are wrong** — that is where the learning is.
- Finish with `## Lab exercise solutions`.

Keep the existing unit Markdown quizzes as authored self-study sources; no
conversion or original-file changes are required for the supported grammar.
The extension's [parser and grader](../cert-learner/src/core/quiz.ts) and
[quiz schema](../cert-learner/schemas/quiz.schema.json) define compatibility, not
an AI inference step or a fresh documentation lookup.

### Strict Markdown grammar

- First nonblank line: unindented `# Title`. Optional introductory prose, then
  optionally `---`, may precede questions. Use LF or CRLF line endings.
- Questions use consecutive markers `**1.** Prompt`, `**2.** Prompt`, and so on.
  Stems may wrap. Each has 2–8 options labeled contiguously A–H as `- A. Text`.
  Option continuations require **exactly two leading spaces**, immediately after
  a nonblank option line. Do not use alternative bullets/numbering or extra prose
  between options. End each question with one or two exact `---` lines.
- The answer heading is exactly `## Answers`. Keys appear consecutively, one for
  each question: `**1 — B.** Explanation` or `**2 — A and C.** Explanation`.
  Use an **em dash**, the period inside bold, and unique known labels joined by
  ` and ` (at most three labels).
- Put **Choose two / Select two** (or `2`) in the prompt for two answers;
  **Choose three / Select three** (or `3`) for three. Without such a phrase, one
  answer is required. Conflicting counts or a key of the wrong size are rejected.
- Each explanation is one nonempty paragraph; wrapped lines are allowed, but
  not blank-line-separated continuations, lists, or code fences. One or two `---`
  lines may follow an explanation. Blank lines between structural items are fine.
- Do not add extra headings or fences before Answers. The next H2, normally
  `## Lab exercise solutions`, ends parsing; its body is not graded. Missing,
  duplicate, or malformed keys/Answers sections within the parsed quiz are rejected.
  Unsupported content shows **Interactive quiz unavailable**, with **Open source**
  only when safely resolvable. The extension never guesses an answer key.

### Structured JSON alternative

For new quizzes, use the existing [quiz schema](../cert-learner/schemas/quiz.schema.json)
and [complete six-question sample](../cert-learner/examples/foundations/quiz.json).
Declare the JSON path in the unit's `resources.quiz`; root `resources` remain
Markdown references. A valid select-two example:

```json
{
  "schemaVersion": 1,
  "title": "Safe local practice",
  "questions": [{
    "id": "safe-check",
    "prompt": "Select two safe steps before running a course check.",
    "options": [
      { "id": "A", "text": "Inspect the script." },
      { "id": "B", "text": "Assume trust prevents all side effects." },
      { "id": "C", "text": "Review the explicit run confirmation." }
    ],
    "correctOptionIds": ["A", "C"],
    "explanation": "Inspect the script and review the confirmation. Workspace trust is not a sandbox."
  }]
}
```

All shown fields are required; extra properties are rejected. Use 1–200 questions,
2–8 options each, unique question IDs and unique option IDs within each question.
IDs must be nonblank, at most 128 characters, without surrounding whitespace or
control characters. `correctOptionIds` is a nonempty, duplicate-free subset of
the options; its length sets the exact selection count. Title, prompt, option
text, and explanation must be nonblank; see the schema for field limits. Both
formats require a regular UTF-8 file of at most 1 MiB, safely inside the course
root. Markdown text is sanitized and never executed.

### Grading and state boundaries

Single-answer radio clicks submit immediately; multi-answer checkboxes require
**Check answer** at the exact displayed count. Correctness is **set equality**:
for two correct options, choose exactly both, in either order. One point is awarded
for a correct first valid submission, zero otherwise; no partial credit or repeat
scoring. Feedback reveals the authored correct options and explanation, not an
AI answer or a guarantee that the material matches current documentation.

**Previous / Next**, **Finish quiz / Summary**, and **Restart / Retry quiz** manage
only the quiz attempt. Submitted answers and scores remain in memory across panel
reopening, not extension/VS Code restarts, progress export, or course completion.
Persistent quiz scores are intentionally not implemented. Source changes invalidate
the attempt on reread. Quiz **Restart** confirms before clearing existing answers;
unit/course progress reset is unchanged and separate. Quiz opening/grading never
changes learning position, runs labs/checks, or proves exam readiness. The full raw
key is absent from initial client HTML, but self-study **Open source** remains
available: do not author this as a secure or official exam delivery system.

## Tone

Direct and technical. Assume a competent developer who has not used Azure AI
before. No filler, no cheerleading, no emoji. Where a service is genuinely awkward
or a limitation will bite, say so.

## Cost

Any lab that creates an hourly-billed resource must say so at the top and delete it
at the end. Azure AI Search, provisioned deployments, and running agents are the
usual offenders.

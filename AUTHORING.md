# Authoring guide (contributors only)

Read this before adding or editing a unit. It exists so every unit feels like it
was written by one person.

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

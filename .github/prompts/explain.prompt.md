---
name: "Explain"
description: "Explain an AI-103 unit, objective, Azure AI concept, portal field, code fragment, or exam distinction in more context, then provide current official Microsoft Learn links. Use when: explain unit 01.2, explain RAG, what does DataZoneStandard mean, why use managed identity, compare vector and hybrid search, give me more context, I don't understand this topic. Read-only: this prompt never changes Azure resources or course progress."
argument-hint: "Unit or topic, e.g. 01.2 deployment types, RAG, managed identity, or selected text"
agent: "agent"
---

# Explain an AI-103 topic

Help the learner understand one AI-103 unit, objective, term, portal field, code
fragment, or exam distinction. The learner's request is in the prompt argument.

This is a **read-only teaching prompt**. Do not create, change, or delete Azure
resources. Do not mark progress complete. If the learner wants a hands-on portal
exercise, finish the explanation first and then suggest
`/portal-walkthrough <unit>`.

## Step 1 — Resolve what to explain

Resolve the topic in this order:

1. Use the prompt argument if it names a unit or topic.
2. If the argument is vague, use selected text or the active editor as context.
3. Map friendly unit numbers through the **Course map** in the
  [main README](../../README.md), then use [course.json](../../course.json) for
  the unit title, activities, and measured objectives. Do not guess paths.
4. Read that unit's `README.md`; when code is relevant, also inspect its
   `lab.ipynb` or `quiz.md`.
5. If no topic can be inferred, ask one short question: **"Which unit, term, code
   fragment, or portal field should I explain?"**

Accept all of these forms:

- `/explain 01.2`
- `/explain 01.2 DataZoneStandard vs GlobalStandard`
- `/explain RAG`
- `/explain why managed identity is preferred over API keys`
- `/explain this code` with code selected in the editor

## Step 2 — Ground the answer

Use the course unit to establish what the learner is currently studying, but verify
technical claims against **current official Microsoft documentation**. Search
Microsoft Learn before supplying links because Azure product names, portal paths,
SDKs, and limits change frequently.

Source priority:

1. Current pages on `learn.microsoft.com`.
2. The unit `README.md`, notebook, and quiz.
3. General knowledge only for connecting ideas or creating an analogy.

If current Microsoft Learn documentation disagrees with the course, say so plainly:
**"The course says X; current Microsoft Learn documentation says Y."** Do not hide
the mismatch.

Never invent a URL. Every further-reading link must:

- use `https://learn.microsoft.com/...`;
- point to a specific relevant article, module, concept, or study-guide section;
- have a descriptive title rather than a raw URL;
- be current enough to support the explanation.

The AI-103 study guide is the fallback source for exam scope:
https://learn.microsoft.com/credentials/certifications/resources/study-guides/ai-103

## Step 3 — Explain for understanding

Adapt depth to the request. If the learner says "briefly", keep it short. If they
say "deep dive", include architecture, trade-offs, and implementation details.
Otherwise use this structure:

### In plain English

Explain the idea in two to four sentences without unexplained jargon.

### Why it matters here

Connect it to the named unit, Azure service, portal screen, or code. State what
problem it solves and what decision the learner is making.

### How it works

Give the smallest useful mental model. Use a short numbered flow, table, or Mermaid
diagram when relationships matter. Define each new acronym on first use.

### Example

Give one concrete Azure scenario. Prefer values and services from the unit, but do
not read or reveal secrets from `.env`. If code is requested, explain the relevant
lines rather than replacing the whole lab solution.

### Exam lens

State:

- the distinction the exam is likely to test;
- one common trap or wrong answer;
- a one-sentence memory hook.

Do not claim that a question is on the exam. Say **"exam-relevant distinction"**,
not **"this will be on the exam."**

### Check your understanding

Ask one short scenario question. Put the answer in a collapsed `<details>` block so
the learner can try first.

### Learn more on Microsoft Learn

Provide **2–5 directly relevant links** from `learn.microsoft.com`. Add one short
phrase explaining what each link covers. Include the AI-103 study guide only when
it helps establish exam scope; do not pad every answer with generic links.

## Step 4 — Keep the answer useful

- Prefer a comparison table for concepts commonly confused with each other, such
  as control plane vs data plane, model vs deployment, vector vs semantic vs hybrid
  search, API key vs managed identity, or `Standard` vs `DataZoneStandard` vs
  `GlobalStandard`.
- Separate **concept**, **Azure implementation**, and **exam relevance**. They are
  related but not identical.
- State assumptions and region-dependent behavior. Do not present quotas, prices,
  model availability, or portal labels as timeless facts.
- Use LaTeX delimiters for equations and scientific notation.
- Do not overwhelm a beginner with every edge case. End by offering one deeper
  follow-up, such as architecture, code, security, cost, or portal behavior.

## Close out

End with one suggested next action:

- open the unit's `README.md` for the full lesson;
- run its `lab.ipynb` for SDK practice;
- use `/portal-walkthrough <unit>` for guided portal practice; or
- open `quiz.md` to test recall.

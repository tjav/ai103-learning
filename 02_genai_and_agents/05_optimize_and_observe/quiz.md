# 02.5 — Optimize and observe: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** A team sets `temperature=0` and `top_p=0.2` together to make output more
predictable. What is wrong with this?

- A. Nothing — they reinforce each other
- B. They are two ways of narrowing the same distribution and interact unpredictably; tune one and leave the other at default
- C. `top_p` is ignored when `temperature` is set
- D. Both must be set for either to take effect

---

**2.** Which parameter caps the output of a reasoning model such as `o4-mini`?

- A. `max_tokens`
- B. `max_completion_tokens`
- C. `n`
- D. `stop`

---

**3.** An application sends `temperature=0.2` to `o4-mini` and observes that output
still varies between calls. Why?

- A. Temperature only applies to streamed responses
- B. Reasoning models do not expose sampling controls, and they are not deterministic
- C. The value is too high; use `0.0`
- D. The deployment type is Global Standard

---

**4.** A response comes back with `finish_reason == "length"`. What happened?

- A. A `stop` sequence was matched
- B. The content filter blocked it
- C. The token limit was reached before generation completed
- D. The model had nothing more to say

---

**5.** Which two statements about `seed` are correct? Choose two.

- A. It guarantees identical output for identical inputs
- B. It provides best-effort reproducibility
- C. Reproducibility also depends on `system_fingerprint` remaining unchanged
- D. It reduces token cost

---

**6.** A model formats extracted dates inconsistently despite clear instructions.
Which technique fixes this most cheaply?

- A. Grounding with retrieved documents
- B. Few-shot examples showing the exact desired format
- C. Switching to a reasoning model
- D. Increasing `max_tokens`

---

**7.** A model confidently states a fact about your internal product that does not
exist. Which technique addresses this?

- A. Few-shot prompting
- B. Lower temperature
- C. Grounding the answer in retrieved documents
- D. A higher frequency penalty

---

**8.** Which is the **most reliable** form of reflection for output that must be
valid JSON conforming to a schema?

- A. Ask the model to review its own output
- B. Ask a stronger model to critique it
- C. Parse and validate deterministically, and retry on failure
- D. Increase temperature to explore alternatives

---

**9.** A self-critique loop always reports "looks good" on the first round, yet a
deterministic check finds violations. Why?

- A. The critique prompt exceeded the context window
- B. Models are biased toward approving their own output; use a different model or an explicit rubric
- C. Structured outputs cannot express a boolean
- D. Temperature was too low

---

**10.** Which two are required to get Foundry traces into Application Insights?
Choose two.

- A. Calling `configure_azure_monitor` with the connection string before the first model call
- B. Setting `AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true`
- C. Instrumenting the client, for example `OpenAIInstrumentor().instrument()`
- D. Deploying the model as Provisioned Throughput

---

**11.** Traces appear in Application Insights, but no prompts or completions are
visible. Why?

- A. Content recording is disabled by default and must be explicitly enabled
- B. Traces take 24 hours to include content
- C. Content is only recorded for streamed responses
- D. The sampling rate is too low

---

**12.** Which span attribute would you use to detect a spike in content-filter
blocks?

- A. `gen_ai.request.model`
- B. `gen_ai.usage.input_tokens`
- C. `gen_ai.response.finish_reasons`
- D. `gen_ai.system`

---

**13.** A support bot handles 100,000 requests a day, of which roughly 85% are
simple FAQ lookups. Which optimisation gives the largest cost reduction with the
least quality risk?

- A. Send everything to a reasoning model with `reasoning_effort=low`
- B. Route with a cheap classifier: small model for simple, large model for complex
- C. Increase `max_tokens` so answers are never truncated
- D. Add a self-critique loop to every response

---

**14.** Which two errors should a fallback policy **not** retry on another
deployment? Choose two.

- A. `429 Too Many Requests`
- B. `400 Bad Request` from an invalid schema
- C. `503 Service Unavailable`
- D. A response blocked by the content filter

---

**15.** Which is **not** a genuine advantage of a hybrid LLM + rules-engine design?

- A. Rule-handled requests are free and instant
- B. Rule decisions are deterministic and auditable
- C. The LLM only sees genuinely ambiguous requests
- D. Rules automatically stay in sync with changing business policy

---
---

## Answers

**1 — B.** `temperature` and `top_p` both narrow the sampled distribution, by
different mechanisms. Setting both compounds them in ways that are hard to reason
about and hard to reproduce. Pick one — usually `temperature` — and leave the other
at its default.

**2 — B.** Reasoning models reject `max_tokens` and use `max_completion_tokens`,
which crucially covers **hidden reasoning tokens as well as visible output**. `n` is
the candidate count and `stop` is a halt marker.

**3 — B.** Reasoning models do not expose `temperature`, `top_p`, or the penalties;
the value is ignored or rejected. They are also not deterministic, so lowering the
number further would not help either. Deployment type is irrelevant.

**4 — C.** `length` means the token budget ran out mid-generation, which users
experience as a sentence stopping mid-word. A matched stop sequence gives `stop`; a
filter block gives `content_filter`; a natural end also gives `stop`.

**5 — B and C.** `seed` is documented as best effort. Determinism holds only while
the backend is unchanged, which the `system_fingerprint` field reports — compare it
across responses before assuming a bug. It has no effect on cost.

**6 — B.** Few-shot examples are the standard fix for format and edge-case
conformance: showing two or three correctly formatted dates is far more effective
than another sentence of instruction, and costs only the example tokens. Grounding
adds knowledge, not format; a reasoning model is expensive overkill.

**7 — C.** A fabricated fact is a knowledge problem, and the fix is to supply the
knowledge — retrieval and grounding, as in unit 02.2. Few-shot changes shape, not
substance. Temperature and penalties change style; a confident hallucination at
`temperature=0` is still a hallucination.

**8 — C.** A deterministic parse-and-validate is not an opinion: it either conforms
or it does not, it costs nothing, and it cannot flatter the model. Use an LLM critic
only for things a program cannot check. (Better still, prevent the problem with
`response_format` `json_schema` and `strict: true` — unit 02.1.)

**9 — B.** Self-evaluation is systematically generous. Fixes, in order of
effectiveness: a deterministic verifier, a different and stronger critic model, and
an explicit rubric with structured output rather than free-form prose.

**10 — A and C.** You need the exporter configured (before any instrumented call, or
early spans are lost) and the client actually instrumented. B is an optional privacy
switch that adds prompt and completion content but is not required for traces to
appear. Deployment type is irrelevant.

**11 — A.** Content recording is off by default precisely because prompts and
completions frequently contain personal data. Enabling
`AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true` writes that content into
Application Insights and is a governance decision, not just a configuration change.

**12 — C.** `gen_ai.response.finish_reasons` carries `stop`, `length`,
`content_filter`, or `tool_calls`. Counting `content_filter` over time is your
jailbreak and prompt-regression signal; counting `length` tells you users are seeing
truncated answers.

**13 — B.** With 85% easy traffic, routing moves the vast majority of requests to a
model roughly an order of magnitude cheaper, at the cost of one small classifier
call. A pays for hidden reasoning tokens on trivial questions. C raises cost without
addressing it. D triples the cost of every response.

**14 — B and D.** A malformed request and a content-filter block are deterministic
outcomes of the request itself — they will fail identically on every deployment, so
retrying only multiplies the cost and delays the error. `429` and `5xx` are transient
capacity and availability problems and are exactly what fallback exists for.

**15 — D.** Rules do **not** maintain themselves; they drift out of date silently
and are a real maintenance burden — arguably the main argument against the pattern.
A, B, and C are all genuine benefits, and the auditability of B is often why
regulated domains mandate a deterministic path.

---

## Lab exercise solutions

**1. Starve a reasoning model.** `message.content` comes back **empty** (or nearly
so), `finish_reason` is `"length"`, and
`usage.completion_tokens_details.reasoning_tokens` shows that essentially the whole
200-token budget went to hidden reasoning. One sentence: on a normal model
truncation cuts a *partial visible answer*, whereas on a reasoning model the hidden
reasoning is drawn from the **same budget** and consumes it before any visible token
is emitted — so an under-sized `max_completion_tokens` produces no answer at all
while still billing you in full. Practical rule: budget reasoning models several
thousand completion tokens, not a few hundred.

**2. Both knobs at once.** `top_p=0.1` dominates: at `temperature=1.5, top_p=0.1`
the `distinct_ratio` stays low, because nucleus sampling has already discarded
almost the entire tail before temperature gets to reshape anything. At
`temperature=0.2, top_p=1.0` variety is also low, but for the opposite reason. The
lesson is that the *more restrictive* of the two dominates, so setting both means
one silently masks the other — you think you are tuning temperature and you are not.
Pin `top_p=1.0` and tune `temperature`, or the reverse, but never both.

**3. Break the self-critic.** With a generous critic, the loop almost always passes
on round 1, and `verify()` frequently still fails it — most often on the
three-sentence rule, and sometimes on a banned term such as "credit" slipping into a
reassuring closing line. General lesson: **an LLM judge inherits the framing of its
prompt.** A critic told to be encouraging produces encouragement, not evaluation.
Judges need an explicit rubric, a structured verdict rather than prose, and
independence from the generator — and anything mechanically checkable should be
checked mechanically instead.

**4. Router economics.** Let $c_r$ be the router cost, $c_s$ the small-model answer
cost, $c_b$ the big-model answer cost, and $f$ the fraction of complex questions.

Routing costs $c_r + (1-f)c_s + f\,c_b$ per request; always-big costs $c_b$. Routing
wins while

$$c_r + (1-f)c_s + f\,c_b < c_b \quad\Longrightarrow\quad f < 1 - \frac{c_r}{c_b - c_s}$$

With `gpt-4o-mini` at roughly 1/16th the blended cost of `gpt-4o`, and a router call
about the same size as a simple answer, break-even lands well above 90% complex — in
other words, routing is almost always worth it on realistic traffic, and the 80%
simple workload saves on the order of 70–85%. The failure mode is not economic but
behavioural: if your classifier is biased toward "complex", $f$ approaches 1, and you
have added a call for nothing. That is why you monitor the **distribution of routing
decisions** as a first-class metric, not just end-to-end cost.

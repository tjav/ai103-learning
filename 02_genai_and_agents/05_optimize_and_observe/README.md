# 02.5 — Optimize and operationalize generative AI systems

**Time:** 90–120 minutes · **Cost:** tokens. The reflection and cascade sections
deliberately make several calls per question, so this unit costs more than the
others — a few tens of cents. Application Insights ingestion is billed by volume;
the lab emits a trivial amount.

By the end you will have:

- [ ] Measured the effect of `temperature`, `top_p`, penalties, `seed`, `stop`, and `max_tokens`
- [ ] Established which parameters reasoning models ignore, and why
- [ ] Applied few-shot, chain-of-thought, and decomposition prompting and measured each
- [ ] Built a generate → critique → revise loop and proved it changes the output
- [ ] Emitted OpenTelemetry traces to Application Insights and read them
- [ ] Built a token, latency, and safety dashboard from your own instrumentation
- [ ] Built a router that sends cheap questions to a small model and hard ones to a large one, and a rules-first hybrid

---

## Concepts

### Generation parameters

| Parameter | Range | What it does | Use when |
|---|---|---|---|
| `temperature` | 0–2 | Flattens or sharpens the token distribution | 0 for extraction, classification, anything you parse; 0.7–1.0 for drafting |
| `top_p` | 0–1 | Nucleus sampling: consider only the smallest set of tokens whose probability sums to `p` | An alternative to temperature. **Change one, not both.** |
| `frequency_penalty` | −2–2 | Penalises tokens by how often they have appeared | Reduces verbatim repetition |
| `presence_penalty` | −2–2 | Penalises tokens that have appeared at all | Pushes toward new topics |
| `max_tokens` | int | Caps visible output | Cost control. Truncation gives `finish_reason: "length"` |
| `max_completion_tokens` | int | The reasoning-model equivalent, and it **includes hidden reasoning tokens** | Reasoning models |
| `stop` | up to 4 strings | Halt generation at a marker. The marker is not returned | Structured or delimited output |
| `seed` | int | Best-effort determinism for a fixed `system_fingerprint` | Reproducible tests. **Not a guarantee.** |
| `n` | int | Generate n candidates | Best-of-n selection; you pay for all n |
| `logprobs` / `top_logprobs` | bool / int | Per-token probabilities | Confidence scoring, routing decisions |

Two rules the exam checks:

- **Do not tune `temperature` and `top_p` together.** They are two ways of narrowing
  the same distribution and interact unpredictably. Pin one at its default.
- **`seed` is best effort.** Reproducibility also depends on
  `system_fingerprint`; when the backend changes, identical seeds diverge.

### What reasoning models ignore

| Parameter | `gpt-4o` / `gpt-4o-mini` | `o4-mini` / `o3` |
|---|---|---|
| `temperature` | yes | **ignored or rejected** |
| `top_p` | yes | **ignored or rejected** |
| `frequency_penalty` / `presence_penalty` | yes | **ignored or rejected** |
| `logprobs` | yes | **not supported** |
| `max_tokens` | yes | **rejected** — use `max_completion_tokens` |
| `reasoning_effort` (`low`/`medium`/`high`) | not applicable | **supported** |
| System message | `system` | `developer` role (`system` is accepted and mapped) |
| Hidden reasoning tokens billed | no | **yes** |

> **Exam note.** "The team sets `temperature=0` on `o4-mini` to make output
> deterministic" is wrong twice over: the parameter is not honoured, and reasoning
> models are not deterministic anyway. And "asking a reasoning model to think step by
> step" is redundant — it already does, internally and at your expense. Explicit
> chain-of-thought prompting is for *non*-reasoning models.

### Prompt engineering techniques

| Technique | What it is | Costs | Best for |
|---|---|---|---|
| Clear instruction + role | Say who, what, format, constraints | free | Everything |
| Delimiters | Fence user input in `###` or XML tags | free | Injection resistance, clarity |
| **Few-shot** | 2–5 input/output examples | prompt tokens per call | Format and edge-case conformance |
| **Chain of thought** | "Think step by step" / "reason first, then answer" | completion tokens | Arithmetic, logic, multi-constraint tasks — on non-reasoning models |
| **Decomposition** | Split into sub-tasks, solve each | multiple calls | Complex tasks; also more traceable |
| **Self-consistency** | Sample n answers, take the majority | n× cost | High-stakes, single-answer questions |
| **Reflection / self-critique** | Generate, critique, revise | 2–3× cost | Long-form writing, code, compliance-sensitive output |
| Grounding | Supply the facts | retrieval + prompt tokens | Anything factual — unit 02.2 |

> **Exam note.** Few-shot fixes *format and edge cases*. It does not add knowledge —
> that is grounding. If a question is about the model not knowing a fact, few-shot is
> the wrong answer.

### Reflection and self-critique

Three shapes, increasingly expensive:

| Shape | Loop | Good for |
|---|---|---|
| **Self-critique** | generate → critique own output → revise | Style, completeness, tone |
| **Critic model** | generate with cheap model → critique with strong model → revise | Correctness with a cost ceiling |
| **Verifier** | generate → check against ground truth or a rule engine → retry | Anything mechanically checkable: JSON, SQL, code, arithmetic |

The verifier is by far the most reliable, because the check is not a language model
opinion. Two practical warnings: a model critiquing itself has a **strong bias toward
approving its own work** — a separate model, or an explicit rubric, is much more
effective; and every loop needs a **hard iteration cap**, or a stubborn failure
becomes an infinite bill.

### Observability

Four signals, four sources:

| Signal | Where it comes from | Why it matters |
|---|---|---|
| **Traces** | OpenTelemetry spans → Application Insights | End-to-end latency and causality: which step was slow, which tool failed |
| **Token analytics** | `usage` on every response; `gen_ai.usage.*` span attributes | Cost per request, per user, per feature |
| **Safety signals** | `content_filter_results`, `finish_reason`, evaluator scores | Detect a spike in filtered or ungrounded output |
| **Latency breakdown** | span durations, TTFT | Distinguishes a slow model from slow retrieval from a slow tool |

Azure AI Foundry uses **OpenTelemetry** with the **GenAI semantic conventions**.
Concretely:

```python
from azure.monitor.opentelemetry import configure_azure_monitor
from azure.ai.inference.tracing import AIInferenceInstrumentor
from opentelemetry.instrumentation.openai_v2 import OpenAIInstrumentor

configure_azure_monitor(connection_string=cfg["APPLICATIONINSIGHTS_CONNECTION_STRING"])
OpenAIInstrumentor().instrument()
AIInferenceInstrumentor().instrument()
```

The project's Application Insights connection string is available from
`project_client().telemetry.get_application_insights_connection_string()`, so you do
not have to plumb it separately.

Span attributes worth knowing by name: `gen_ai.system`, `gen_ai.request.model`,
`gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`,
`gen_ai.response.finish_reasons`.

> **Privacy.** Prompt and completion **content** is not recorded by default. Set
> `AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true` to capture it — and
> understand that you are then writing user content into Application Insights, which
> is a data-governance decision, not just a switch.

**Continuous evaluation** samples live traces, runs evaluators against them, and
writes the scores back to Application Insights so quality can be alerted on like any
other metric. That is the answer to "how do we detect quality regression in
production."

### Orchestrating multiple models

| Pattern | Shape | Wins |
|---|---|---|
| **Routing** | Classify the request, send it to the right model | Cost — most traffic is easy |
| **Cascade** | Try cheap; escalate only if confidence or validation fails | Cost, with a quality floor |
| **Fallback** | On 429/5xx/filter, retry on another deployment or region | Availability |
| **Ensemble / best-of-n** | Several models answer; pick or vote | Quality, at multiplied cost |
| **Hybrid LLM + rules** | Deterministic rules decide what they can; the model handles the rest | Cost, latency, auditability, correctness |

The hybrid rules-first pattern is the one people under-use and the exam likes. If a
regex, a lookup table, or a business-rules engine can answer 60% of requests, those
60% become free, instant, deterministic, and auditable — and the LLM only sees the
genuinely ambiguous remainder. Regulated domains often *require* the deterministic
path for anything auditable.

Routing needs a signal. Cheapest to most expensive: input length and keywords → a
rules table → a small classifier model → `logprobs`-based confidence from the cheap
model itself → an explicit self-assessment.

---

## Portal walkthrough

### Step 1 — Parameters in the playground

**https://ai.azure.com** → **Playgrounds → Chat** → `gpt-4o-mini`. Right-hand pane:

| Control | API parameter |
|---|---|
| Temperature | `temperature` |
| Top P | `top_p` |
| Max response | `max_tokens` |
| Stop sequence | `stop` |
| Frequency penalty | `frequency_penalty` |
| Presence penalty | `presence_penalty` |

Ask for a two-line product description at `temperature=0`, three times. Then at
`1.6`, three times. Then switch the deployment to `o4-mini` and watch the temperature
and penalty controls disappear or stop taking effect — the portal reflects what the
model accepts.

### Step 2 — Connect Application Insights

1. Project → **Tracing** (under *Observability*).
2. If prompted, **Connect** an Application Insights resource. `02_provision_core.ps1`
   creates `appi-ai103`.
3. Run something from the playground, wait a minute or two, and refresh.

Each request becomes a trace. Expand it: spans for the model call, any tool calls,
any retrieval, each with duration and token attributes.

### Step 3 — Read the numbers that matter

Project → **Monitoring** / the Application Insights resource:

| Where | Question it answers |
|---|---|
| Foundry **Tracing** | Why was *this* request slow or wrong? |
| Foundry **Metrics** / model monitoring | Requests, tokens, latency, error rate over time |
| App Insights **Logs** (KQL) | Anything you want — the queries below |
| Foundry **Evaluation** | Is quality holding? |

Useful KQL once traces are flowing:

```kusto
// token spend by model, last 24 hours
dependencies
| where timestamp > ago(24h)
| where isnotempty(customDimensions["gen_ai.request.model"])
| extend model = tostring(customDimensions["gen_ai.request.model"]),
         in_tok = toint(customDimensions["gen_ai.usage.input_tokens"]),
         out_tok = toint(customDimensions["gen_ai.usage.output_tokens"])
| summarize calls = count(), input = sum(in_tok), output = sum(out_tok) by model
| order by output desc
```

```kusto
// latency percentiles by operation
dependencies
| where timestamp > ago(24h) and isnotempty(customDimensions["gen_ai.system"])
| summarize p50 = percentile(duration, 50), p95 = percentile(duration, 95),
            p99 = percentile(duration, 99), n = count() by name
| order by p95 desc
```

```kusto
// requests that stopped for a reason other than a normal completion
dependencies
| where timestamp > ago(24h)
| extend reason = tostring(customDimensions["gen_ai.response.finish_reasons"])
| where isnotempty(reason) and reason !contains "stop"
| summarize count() by reason
```

That last one is your safety and truncation signal: `content_filter` means the filter
fired; `length` means you truncated an answer and users are seeing sentences stop
mid-word.

### Step 4 — Set an alert

Application Insights → **Alerts** → **+ Create** → **Alert rule**. A custom log
search on the finish-reason query above, firing when `content_filter` count exceeds
your baseline, tells you about a jailbreak campaign or a bad prompt deployment within
minutes rather than at the end of the month.

<details>
<summary>Enabling tracing in code</summary>

```python
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry.instrumentation.openai_v2 import OpenAIInstrumentor

conn = project_client().telemetry.get_application_insights_connection_string()
configure_azure_monitor(connection_string=conn)
OpenAIInstrumentor().instrument()

# Optional and consequential: records prompts and completions into App Insights.
# os.environ["AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED"] = "true"
```

For agents, `AIAgentsInstrumentor().instrument()` from `azure.ai.agents.telemetry`
adds spans for runs, tool calls, and run steps.
</details>

---

## Troubleshooting

**`Unsupported parameter: 'max_tokens' is not supported with this model`**
A reasoning model. Use `max_completion_tokens`.

**`temperature` has no effect**
Either a reasoning model, or you are also setting `top_p` and the two are fighting.
Pin one at default.

**Same `seed`, different output**
`seed` is best effort and only holds while `system_fingerprint` is unchanged.
Compare fingerprints across the two responses before assuming a bug.

**Output stops mid-sentence**
`finish_reason == "length"`. `max_tokens` is too low — or, on a reasoning model,
`max_completion_tokens` was consumed by hidden reasoning before any visible text was
produced. Raise it substantially for reasoning models.

**Self-critique always says "looks good"**
Models are poor judges of their own work. Use a different (usually stronger) model as
the critic, give it an explicit rubric, and require it to output a structured verdict
rather than prose.

**Reflection loop never terminates**
You did not cap iterations. Always bound the loop and treat "still failing at the cap"
as an escalation, not a retry.

**No traces in Application Insights**
Check, in order: the connection string is set; `configure_azure_monitor` ran before
the first model call; the instrumentor was actually instrumented; you waited two to
three minutes for ingestion.

**Traces appear but contain no prompts**
By design. Content recording is off unless
`AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED=true`.

**Router sends everything to the expensive model**
Your classifier prompt is biased toward "hard", or the confidence threshold is too
strict. Measure the *distribution* of routing decisions, not just the accuracy — a
router that never routes cheap has saved nothing while adding a call.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on parameters, reasoning-model differences,
reflection, OpenTelemetry, and routing.

## Next

[03.1 — Design and implement image- and video-generation solutions](../../03_computer_vision/01_image_and_video_generation/README.md)

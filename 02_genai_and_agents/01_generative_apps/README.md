# 02.1 — Build generative applications by using Foundry

**Time:** 60–90 minutes · **Cost:** a few cents in tokens. Nothing hourly.

This is the first unit of the highest-weight exam domain (30–35%). Everything that
follows — RAG, agents, orchestration — is built on the three decisions in this unit:
which model, which client, and how you prove the output is any good.

By the end you will have:

- [ ] Called an LLM, a small model, a reasoning model, a code-generation prompt, and a multimodal model
- [ ] Connected an application to a Foundry project three different ways, and understood why each exists
- [ ] Forced a model to return JSON that conforms to a schema you defined
- [ ] Streamed a response token by token
- [ ] Passed an image to a model as input
- [ ] Run quality and safety evaluators over your own outputs and read the scores

---

## Concepts

### Model families and what each is for

The study guide asks you to "deploy and consume LLMs, small models, code models,
and multimodal models." Those are four categories, not four products, and the exam
tests whether you pick the cheapest thing that works.

| Family | Examples in Foundry | Strengths | Costs you |
|---|---|---|---|
| **Large language model (LLM)** | `gpt-4o`, `gpt-4.1`, `Llama-3.3-70B` | Broad reasoning, long context, multi-step instructions | Most expensive per token; highest latency |
| **Small language model (SLM)** | `gpt-4o-mini`, `Phi-4`, `Phi-4-mini`, `Ministral-3B` | Classification, extraction, routing, summarisation at scale | Weaker at multi-hop reasoning and rare knowledge |
| **Reasoning model** | `o4-mini`, `o3` | Maths, planning, code debugging, chain-of-thought tasks | Hidden reasoning tokens you pay for; ignores `temperature` |
| **Code model** | `gpt-4.1`, `o4-mini`, `Codestral` | Generation, refactoring, test writing, diff review | Same billing as its family; nothing special to deploy |
| **Multimodal** | `gpt-4o`, `gpt-4.1`, `Phi-4-multimodal` | Image + text in one prompt; charts, screenshots, documents | Image tokens are counted as prompt tokens and add up fast |
| **Embedding** | `text-embedding-3-small` / `-large` | Turning text into vectors for retrieval | Not a chat model; no completion |

> **Exam note.** There is no separate "code model" deployment type in Foundry. A
> code model is just a chat model chosen because it scores well on coding
> benchmarks. If a question offers "deploy a code-completion endpoint" as an option,
> it is a distractor. `gpt-4.1` and `o4-mini` are the current answer for code work.

Two more distinctions the exam likes:

- **Serverless / pay-as-you-go models** (the Azure OpenAI family, plus catalogue
  models offered as a *serverless API*) bill per token and need no compute.
- **Managed compute models** (most open-weight catalogue entries) deploy onto VMs
  you rent by the hour. They require a **hub-based project**, not a Foundry
  project. If a scenario says "deploy Mistral-7B to a dedicated endpoint," it is
  managed compute and the cost model is hourly.

### Three clients, and when to use which

This is the single most confusable topic in the domain. All three ship as separate
pip packages, all three can talk to the same Foundry resource, and they are not
interchangeable.

| Client | Package | Endpoint it takes | Use it for |
|---|---|---|---|
| **`AIProjectClient`** | `azure-ai-projects` | **Project** endpoint `.../api/projects/<name>` | Deployments, connections, indexes, evaluations, datasets, tracing — and it is the gateway to `.agents` |
| **`AzureOpenAI`** | `openai` | **Inference** endpoint `https://<res>.services.ai.azure.com` | Chat, embeddings, images, audio, structured outputs, streaming. The richest and best-documented surface. |
| **`ChatCompletionsClient`** | `azure-ai-inference` | Inference endpoint, or a model-specific serverless endpoint | A *provider-neutral* chat API. Same code against `gpt-4o`, `Phi-4`, `Llama`, `Mistral`. |

The mental model:

```
AIProjectClient        →  everything the PROJECT owns
   .agents             →  agents, threads, runs
   .deployments        →  what models exist
   .connections        →  Search, Storage, other resources
   .get_openai_client() →  hands you a configured AzureOpenAI

AzureOpenAI            →  everything an OpenAI MODEL can do
ChatCompletionsClient  →  the lowest common denominator across ALL models
```

`AIProjectClient.get_openai_client()` is worth knowing by name: it returns an
`AzureOpenAI` already pointed at the right endpoint with the right credential, so
you do not have to derive the inference endpoint from the project endpoint yourself.

> **Exam note.** "Which client should the application use to create an agent?"
> → `AIProjectClient`, because agents belong to the project. "Which client to
> generate an embedding?" → `AzureOpenAI` (or `EmbeddingsClient`). Mixing these up
> is the most common wrong answer in this domain.

Choose `azure-ai-inference` when you genuinely need model portability — an app that
must run against `gpt-4o-mini` in one tenant and `Phi-4` in an air-gapped one.
Choose `openai` for everything else, because structured outputs, the Responses API,
audio, and images all land there first.

### Structured outputs

Three escalating levels of "please return JSON":

| Mechanism | `response_format` | Guarantee |
|---|---|---|
| Prompt only ("reply in JSON") | none | None. It will eventually return prose or a markdown fence. |
| **JSON mode** | `{"type": "json_object"}` | Syntactically valid JSON. Fields and types are *not* guaranteed. |
| **Structured outputs** | `{"type": "json_schema", "json_schema": {...,"strict": true}}` | Conforms to your schema. Enforced by constrained decoding, not by luck. |

Structured outputs require `"strict": true`, and strict mode requires
`"additionalProperties": false` on every object and every property listed in
`required`. Optional fields are expressed as a union with `null`, not by omission.
The model can still refuse; check `message.refusal` before parsing.

> **Exam note.** JSON mode alone does not validate against a schema. If a question
> says "the response must always contain a `severity` field with one of three
> values," JSON mode is the wrong answer and `json_schema` with `strict: true` is
> the right one.

### Streaming

`stream=True` turns the response into an iterator of chunks. It changes nothing
about cost and it does not make generation faster — it lowers **time to first
token**, which is what users perceive as speed. Two consequences the exam probes:

- By default a streamed response has **no `usage` object**. Ask for it with
  `stream_options={"include_usage": True}` and it arrives in a final chunk.
- Content filtering on streamed responses is *asynchronous* by default: text is
  emitted then annotated. If you must not show unfiltered text, that is what
  **asynchronous filter** vs the default buffered behaviour is about.

### Multimodal input

Images go into the `content` array of a user message as `image_url` parts. Two
sources: a public HTTPS URL, or a `data:` URI with base64 bytes (which is what you
use for anything private). `detail` may be `"low"`, `"high"`, or `"auto"` — `"low"`
downsamples to a fixed small token cost, `"high"` tiles the image and costs far
more. Image tokens are billed as **prompt** tokens.

Only multimodal deployments accept images. Sending an image to `gpt-4o-mini` works;
sending one to `text-embedding-3-small` or a text-only Phi variant returns 400.

### Evaluation: the four questions the exam asks

The study-guide bullet is "detecting fabrications, relevance, quality, and safety."
`azure-ai-evaluation` groups evaluators into families that map onto those words.

| Family | Evaluators | Needs | Answers |
|---|---|---|---|
| **Groundedness / fabrication** | `GroundednessEvaluator`, `GroundednessProEvaluator` (preview) | query, response, **context** | Did the model make it up? |
| **Relevance & quality** | `RelevanceEvaluator`, `CoherenceEvaluator`, `FluencyEvaluator`, `RetrievalEvaluator` | query, response (+context) | Is it a good answer to the question asked? |
| **Similarity to ground truth** | `SimilarityEvaluator`, `F1ScoreEvaluator`, `BleuScoreEvaluator`, `RougeScoreEvaluator` | needs `ground_truth` | Does it match the known-correct answer? |
| **Safety / risk** | `ViolenceEvaluator`, `SexualEvaluator`, `SelfHarmEvaluator`, `HateUnfairnessEvaluator`, `ProtectedMaterialEvaluator`, `IndirectAttackEvaluator` | an **Azure AI project**, not a model | Is the output harmful? |

Two structural facts that get tested:

1. **AI-assisted quality evaluators are LLM-as-judge.** You pass them a
   `model_config` and they cost tokens. `F1`, `BLEU`, and `ROUGE` are pure maths
   and are free.
2. **Safety evaluators do not use your model.** They call a Microsoft-hosted safety
   service, so they take `azure_ai_project` and `credential` instead of
   `model_config`. Their output is a severity label (`very low` … `high`) plus a
   0–7 score and a reason, not a 1–5 quality score.

Quality evaluators score **1–5, higher is better**. Safety evaluators score
**0–7, lower is better**. Getting that backwards is a classic trap.

`GroundednessEvaluator` runs on your model and asks "is every claim supported by the
context?". `GroundednessProEvaluator` (preview) calls the Azure AI Content Safety
groundedness detection service and additionally returns the *ungrounded spans* — use
it when you need to point at the fabricated sentence, not just score the answer.

---

## Portal walkthrough

### Step 1 — Confirm the deployments you need

**https://ai.azure.com** → your project → **Models + endpoints**.

You need at minimum `gpt-4o-mini`. For the multimodal section you also need a model
with vision — `gpt-4o` — and `MODEL_CHAT` in `.env` points at it. If it is missing:

1. **Model catalog** → search `gpt-4o` → **Use this model**.
2. | Field | Value | Why |
   |---|---|---|
   | Deployment name | `gpt-4o` | keeps `.env` simple |
   | Deployment type | **Global Standard** | highest quota, pay per token |
   | TPM | `10K` | the vision calls in this lab are small |

Deploy `o4-mini` too if you have quota — the reasoning-model comparison in the lab
skips gracefully if you do not.

### Step 2 — Compare models in the playground before you commit

1. **Playgrounds** → **Chat**.
2. Pick `gpt-4o-mini`. Enter a system prompt: *"You extract structured data. Reply
   only with JSON."*
3. Send a messy sentence: *"call from Dana Whitfield about invoice 88213, she's
   furious, wants a refund by Friday."*
4. Now switch the deployment dropdown to `gpt-4o` and resend the same thing.

Look at what actually changed. Usually: not much, for extraction. That is the whole
argument for small models, and it is why `MODEL_MINI` is the default in this course.

### Step 3 — Find the JSON schema switch

Still in the chat playground, open the right-hand parameters pane:

| Control | What it maps to in code |
|---|---|
| Response format → **Text / JSON object / JSON schema** | `response_format` |
| Temperature | `temperature` |
| Top P | `top_p` |
| Max response | `max_tokens` / `max_completion_tokens` |
| Past messages included | how many turns the playground replays — **not** an API parameter |

Choose **JSON schema**, paste a small schema, and resend. That last row is worth
noticing: the playground silently manages conversation history for you. Your
application does not. Nothing on the server remembers your last message — you resend
the whole array every turn. That fact is why agents and threads exist, and it is
where unit 02.3 starts.

### Step 4 — Run an evaluation in the portal

1. Left nav → **Evaluation** → **+ New evaluation**.
2. Choose **Evaluate a dataset** (the other options are model comparison and agent
   evaluation, which unit 02.4 uses).
3. Upload a small JSONL with `query`, `response`, and `context` columns, or pick a
   sample dataset.
4. Select evaluators:

   | Evaluator | Column mapping it demands |
   |---|---|
   | Groundedness | `query`, `response`, `context` |
   | Relevance | `query`, `response` |
   | Coherence | `query`, `response` |
   | Violence / Hate / Sexual / Self-harm | `query`, `response` |

5. Pick the judge deployment (`gpt-4o-mini` is fine and much cheaper) and **Create**.

Results land under **Evaluation** with per-row scores and a reason string. Read a
few reasons — that field is what makes an evaluation actionable, and it is the
difference between "score 2" and "the answer asserted a refund window the context
never mentions."

<details>
<summary>SDK alternative</summary>

```python
from azure.ai.evaluation import evaluate, GroundednessEvaluator, RelevanceEvaluator

model_config = {
    "azure_endpoint": cfg["AZURE_OPENAI_ENDPOINT"],
    "azure_deployment": cfg["MODEL_MINI"],
    "api_version": cfg["AZURE_OPENAI_API_VERSION"],
}

result = evaluate(
    data="rows.jsonl",
    evaluators={
        "groundedness": GroundednessEvaluator(model_config),
        "relevance": RelevanceEvaluator(model_config),
    },
    azure_ai_project=cfg["AZURE_AI_PROJECT_ENDPOINT"],   # uploads results to the portal
)
print(result["metrics"])
```

Omit `azure_ai_project` to keep results local. Include it and the run appears in the
portal's Evaluation blade alongside the ones you created by hand.
</details>

---

## Troubleshooting

**`DeploymentNotFound` (404)**
You passed the *model* name where the *deployment* name belongs, or the deployment
lives on a different resource. `AIProjectClient.deployments.list()` is the fastest
check.

**`Invalid schema for response_format ... 'additionalProperties' is required to be supplied and to be false`**
Strict structured outputs require `"additionalProperties": false` on *every* object
in the schema, including nested ones, and every property must appear in `required`.
Make optional fields nullable instead: `{"type": ["string", "null"]}`.

**`Unsupported parameter: 'temperature' is not supported with this model`**
You called a reasoning model (`o4-mini`, `o3`). They ignore or reject `temperature`,
`top_p`, `presence_penalty`, `frequency_penalty`, and use `max_completion_tokens`
rather than `max_tokens`. Unit 02.5 has the full table.

**`400 ... 'image_url' is not supported by this model`**
The deployment is text-only. Use `MODEL_CHAT` (`gpt-4o`), not a text-only Phi or an
embedding deployment.

**Streaming response has `usage = None`**
Expected. Pass `stream_options={"include_usage": True}` and read the final chunk,
which has an empty `choices` list and a populated `usage`.

**`Content filter triggered` / `finish_reason == "content_filter"`**
The DefaultV2 filter blocked it. The response body carries a
`content_filter_result` naming the category and severity. Unit 01.4 covers building
a custom filter and requesting exemptions.

**Evaluators return `nan`**
Almost always a column-mapping problem — the evaluator wanted `context` and your
JSONL called it `documents`. Pass an explicit `column_mapping` in `evaluate()`.

---

## Check yourself

[quiz.md](quiz.md) — 14 questions on clients, model families, structured outputs,
and the evaluator taxonomy.

## Next

[02.2 — RAG, workflows, and multistep reasoning](../02_rag_grounding/README.md)

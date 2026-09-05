# 02.1 — Generative applications: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** An application must create an agent, list the project's model deployments,
and start a conversation thread. Which client should it construct?

- A. `AzureOpenAI`
- B. `ChatCompletionsClient` from `azure-ai-inference`
- C. `AIProjectClient` from `azure-ai-projects`
- D. `CognitiveServicesManagementClient`

---

**2.** A team is building an app that must run against `gpt-4o-mini` in the
commercial cloud and `Phi-4` in a sovereign cloud, with **no code changes** to the
inference call. Which library best fits?

- A. `openai` with `AzureOpenAI`
- B. `azure-ai-inference` with `ChatCompletionsClient`
- C. `azure-ai-projects` with `AIProjectClient`
- D. `requests` against the REST endpoint

---

**3.** A downstream system will fail if the model's JSON reply ever omits the
`severity` field or uses a value outside `low|medium|high`. Which configuration
guarantees this?

- A. A system prompt saying "always include severity"
- B. `response_format={"type": "json_object"}`
- C. `response_format={"type": "json_schema", ...}` with `"strict": true`
- D. `temperature=0`

---

**4.** You enable strict structured outputs and get
`'additionalProperties' is required to be supplied and to be false`. What must you
change?

- A. Set `additionalProperties: false` on the root object only
- B. Set `additionalProperties: false` on every object in the schema, including nested ones
- C. Remove all optional properties from the schema
- D. Set `strict: false`

---

**5.** You stream a chat completion and find `response.usage` is `None`. Why?

- A. Streamed responses are not billed
- B. Usage is only returned when `temperature=0`
- C. Usage is omitted unless you pass `stream_options={"include_usage": True}`
- D. Usage is only available on the project endpoint

---

**6.** Which two statements about reasoning models such as `o4-mini` are correct?
Choose two.

- A. They ignore or reject `temperature` and `top_p`
- B. They use `max_completion_tokens` rather than `max_tokens`
- C. Their reasoning tokens are generated but not billed
- D. They cannot be deployed as Global Standard

---

**7.** Your app must send a private customer screenshot to a model for analysis.
The image is not published anywhere. How do you pass it?

- A. Upload it with the Files API and reference the file ID
- B. Encode it as a base64 `data:` URI in an `image_url` content part
- C. Put the raw bytes in the `content` string
- D. Host it on a public blob and pass the URL

---

**8.** A summary is fluent, on-topic, and confidently states a 90-day return window
that does not appear in the source document. Which evaluator scores this **poorly**?

- A. `CoherenceEvaluator`
- B. `FluencyEvaluator`
- C. `RelevanceEvaluator`
- D. `GroundednessEvaluator`

---

**9.** Which two evaluators require an `azure_ai_project` and a `credential` rather
than a `model_config`? Choose two.

- A. `ViolenceEvaluator`
- B. `F1ScoreEvaluator`
- C. `GroundednessProEvaluator`
- D. `CoherenceEvaluator`

---

**10.** A `RelevanceEvaluator` returns `4`. A `ViolenceEvaluator` returns `4`. What
do these mean?

- A. Both are good — 4 out of 5
- B. Relevance 4 is good; violence 4 is a medium-severity safety problem
- C. Relevance 4 is bad; violence 4 is good
- D. They are the same scale and both mean "acceptable"

---

**11.** A subscription needs to run `Mistral-7B` on a dedicated endpoint the team
controls, billed hourly. Which is true?

- A. It deploys to a Foundry project like any Azure OpenAI model
- B. It is a managed-compute deployment and requires a hub-based project
- C. It is only available as a Batch deployment
- D. It requires a Provisioned Throughput reservation on the Foundry resource

---

**12.** Which is **not** a real distinction between the project endpoint and the
inference endpoint?

- A. The project endpoint ends in `/api/projects/<name>`
- B. Agents, evaluations, and connections live behind the project endpoint
- C. Chat and embedding calls go to the inference endpoint
- D. The project endpoint requires an API key while the inference endpoint supports Entra ID

---

**13.** A team wants to classify 4 million short product reviews as
positive/neutral/negative, with the lowest cost, tonight. Which combination is best?

- A. `gpt-4o` on a Global Standard deployment, streamed
- B. `o4-mini` on Global Standard with a chain-of-thought prompt
- C. `gpt-4o-mini` on a Batch deployment with a strict JSON schema
- D. `text-embedding-3-large` with cosine similarity to three anchor phrases

---

**14.** Which two evaluators can run with **no** model deployment and therefore cost
no tokens? Choose two.

- A. `F1ScoreEvaluator`
- B. `RelevanceEvaluator`
- C. `BleuScoreEvaluator`
- D. `GroundednessEvaluator`

---
---

## Answers

**1 — C.** Agents, threads, deployments, connections, indexes, and evaluations are
all owned by the *project*, so you need the project endpoint and `AIProjectClient`.
A and B are data-plane clients that can only call models. D is the ARM management
plane, used to create the resource, not to use it.

**2 — B.** `azure-ai-inference` exists precisely to give one call shape across
OpenAI, Phi, Llama, Mistral, and Cohere. `AzureOpenAI` (A) is tied to the OpenAI
API surface. C is the control plane, not an inference client. D throws away
retries, auth handling, and typing for no benefit.

**3 — C.** Only `json_schema` with `strict: true` constrains decoding to your
schema, including enum values. B guarantees the reply *parses* as JSON but says
nothing about which fields appear. A is a request, not a guarantee. D reduces
variability but enforces nothing.

**4 — B.** Strict mode requires `additionalProperties: false` on every object in the
schema — root and nested — and every property must appear in `required`. Optional
fields are modelled as nullable unions (`{"type": ["string", "null"]}`), not by
leaving them out of `required`. C is unnecessary and D abandons the guarantee.

**5 — C.** By default a streamed response carries no usage object. Setting
`stream_options={"include_usage": True}` appends a final chunk with an empty
`choices` array and a populated `usage`. Streaming is billed identically to
non-streaming (A is wrong), and usage has nothing to do with temperature or which
endpoint you used.

**6 — A and B.** Reasoning models perform internal deliberation and do not expose
sampling controls; they also renamed the output cap to `max_completion_tokens`.
C is exactly backwards — hidden reasoning tokens *are* billed and appear in
`usage.completion_tokens_details.reasoning_tokens`. D is false; `o4-mini` deploys
as Global Standard.

**7 — B.** Chat completions accept an `image_url` part whose URL may be a `data:`
URI containing base64 bytes — that is the standard route for private images and
requires no upload. A describes the Assistants/Agents file flow, not chat
completions. C is not a valid content shape. D deliberately publishes confidential
data.

**8 — D.** Groundedness is the only one of the four that compares the response
against the supplied **context**. Coherence, fluency, and relevance all judge the
answer on its own terms, and a confident fabrication scores well on all three. This
is why groundedness is the fabrication metric and why relevance alone is never a
sufficient release gate.

**9 — A and C.** Safety evaluators (violence, hate/unfairness, sexual, self-harm,
protected material, indirect attack) call a Microsoft-hosted safety service rather
than your deployment, and `GroundednessPro` (preview) uses the Content Safety
groundedness-detection service the same way. Both take `azure_ai_project` +
`credential`. `Coherence` is LLM-as-judge and takes `model_config`; `F1` is pure
maths and takes nothing.

**10 — B.** The two families use opposite scales. Quality evaluators score **1–5,
higher is better**, so relevance 4 is good. Safety evaluators score **0–7 severity,
lower is better**, so violence 4 is medium severity and something you must
investigate. Assuming one scale is a deliberate exam trap.

**11 — B.** Open-weight catalogue models deployed to dedicated compute are
*managed compute* deployments: you rent VMs by the hour and they require a
hub-based project, not a Foundry project. That is one of the few remaining reasons
to create a hub. Note that many of these models are *also* offered as serverless
pay-per-token APIs, which do work from a Foundry project — the giveaway in the
question is "dedicated endpoint, billed hourly."

**12 — D.** Both endpoints support Microsoft Entra ID via `DefaultAzureCredential`,
and this course uses keyless auth against both. A, B, and C are all accurate
descriptions of the split.

**13 — C.** Classification is the canonical small-model job; Batch halves the
per-token price and the work is offline with no latency requirement; a strict JSON
schema stops the label drifting. A pays roughly ten times more for no accuracy gain.
B adds billed reasoning tokens to a task with no reasoning in it. D is a plausible
embedding trick but is markedly less accurate on nuanced sentiment and still costs
an embedding call per review.

**14 — A and C.** `F1`, `BLEU`, `ROUGE`, `METEOR`, and `GLEU` are deterministic
overlap metrics computed locally — free, fast, and repeatable, but they require a
`ground_truth` column. `Relevance` and `Groundedness` are AI-assisted
(LLM-as-judge), need a `model_config`, and bill tokens on every row.

---

## Lab exercise solutions

**1. Break strict mode.** Removing `additionalProperties: false` returns
**400 Bad Request** with
`Invalid schema for response_format 'ticket': In context=(), 'additionalProperties' is required to be supplied and to be false`.
Removing a field from `required` returns a sibling error naming the offending
property. Both come back from the **service**, not the SDK — the schema is compiled
into a decoding constraint server-side, which is exactly why the guarantee holds at
generation time rather than being a post-hoc validation you could bypass.

**2. Cost the image.** A small chart typically costs on the order of ~85 prompt
tokens at `detail="low"` (a fixed base cost) versus several hundred to a few
thousand at `detail="high"`, depending on resolution — a 3–10x ratio for this image
and much more for a full screenshot. At $2.50/M input tokens, a 1,000-token
`"high"` call is $0.0025, so about **400,000 calls per $1**… no: $1 buys 400 such
calls. The exercise is really about noticing that images are ordinary prompt tokens
and that `"low"` is the right default for anything you only need to classify.

**3. A judge that disagrees with itself.** You will usually see the same score, but
not always — AI-assisted evaluators are LLM calls and are not perfectly
deterministic even at low temperature, and the `reason` string varies almost every
time. The lesson: gate releases on an **aggregate over a dataset** (the `metrics`
dict from `evaluate()`), with a threshold and a minimum row count, not on a single
row's score. Single-row evaluation is for debugging, not for CI.

**4. Portability.**

```python
from azure.ai.inference import EmbeddingsClient

emb = EmbeddingsClient(
    endpoint=f"{cfg['AZURE_OPENAI_ENDPOINT'].rstrip('/')}/openai/deployments/{cfg['MODEL_EMBEDDING']}",
    credential=credential(),
    credential_scopes=["https://cognitiveservices.azure.com/.default"],
    api_version=cfg.get("AZURE_OPENAI_API_VERSION", "2025-04-01-preview"),
)
v = emb.embed(input=["hybrid search"]).data[0].embedding
print(len(v), len(embed("hybrid search")[0]))   # 1536 1536 for text-embedding-3-small
emb.close()
```

Both are 1536 dimensions for `text-embedding-3-small`. The vectors are identical
because it is the same deployment behind two client shapes — which is the whole
point of the exercise.

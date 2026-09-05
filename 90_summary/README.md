# 90 — Study guide summary

**Every bullet from the AI-103 skills-measured list (as of 16 April 2026), with a
condensed answer and a link to the unit that builds it.**

This is the revision document. Read it after you have done the labs — it is a
compression of things you have already run, not a substitute for running them. If a
line here does not trigger a memory of a cell you executed, go back to that unit.

Weights, and what they mean for your revision time:

| Domain | Weight | Units |
|---|---|---|
| [1. Plan and manage an Azure AI solution](#domain-1--plan-and-manage-an-azure-ai-solution-2530) | 25–30% | 01.1 – 01.4 |
| [2. Implement generative AI and agentic solutions](#domain-2--implement-generative-ai-and-agentic-solutions-3035) | 30–35% | 02.1 – 02.5 |
| [3. Implement computer vision solutions](#domain-3--implement-computer-vision-solutions-1015) | 10–15% | 03.1 – 03.3 |
| [4. Implement text analysis solutions](#domain-4--implement-text-analysis-solutions-1015) | 10–15% | 04.1 – 04.2 |
| [5. Implement information extraction solutions](#domain-5--implement-information-extraction-solutions-1015) | 10–15% | 05.1 – 05.2 |

Domains 1 and 2 are **55–65% of the exam between them**. If you are short on time,
that is where it goes.

Need it shorter? [91 — Cheat sheet](../91_cheatsheet/CHEATSHEET.md) is three pages.

---

## Domain 1 — Plan and manage an Azure AI solution (25–30%)

### Choose the appropriate Foundry services for generative AI and agents
→ [Unit 01.1](../01_plan_and_manage/01_choose_services_and_models/README.md)

**"Choose an appropriate model for each task, including large language models
(LLMs), small language models, multimodal models, and Foundry Tools."**

Work down, not up: the cheapest thing that meets the requirement wins.

| Need | Pick |
|---|---|
| Classification, extraction, routing, high volume | **SLM** (`gpt-4o-mini`, Phi) |
| Nuanced reasoning, long context, ambiguity | **LLM** (`gpt-4o`, `gpt-4.1`) |
| Multi-step planning, maths, code, verification | **Reasoning model** (`o4-mini`, `o3`) |
| Images or audio as *input* | **Multimodal** (`gpt-4o`, `gpt-4o-audio`) |
| Image or video as *output* | `gpt-image-1`, `sora` |
| Semantic similarity, retrieval | **Embeddings** (`text-embedding-3-small/large`) |
| Fixed categories, offsets, confidence scores, cheap | **Foundry Tool** (Language, Vision, Speech, Translator, Document Intelligence, Content Understanding) |

The single most useful discriminator on the exam: **if the requirement mentions
exact character offsets, documented categories, per-category confidence, or
regulatory defensibility, the answer is a Foundry Tool, not a model.**

**"Choose the appropriate Foundry services for generative tasks, grounding, vector
search, agent workflows, or multimodal processing."**

| Task | Service |
|---|---|
| Generation | Foundry model deployment (Azure OpenAI / Models-as-a-Service) |
| Grounding on your data | Azure AI Search + RAG, or the agent **File Search** / **Azure AI Search** tool |
| Grounding on the public web | **Grounding with Bing Search** tool |
| Vector search | Azure AI Search vector fields (HNSW / exhaustive KNN) |
| Agent runtime, threads, tools | **Foundry Agent Service** |
| Multimodal ingestion of documents/images/audio/video | **Content Understanding** |
| Safety | Content Safety + deployment content filters |
| Evaluation | Azure AI Evaluation SDK + Foundry portal evaluations |

**"Choose an appropriate method for retrieval and indexing."**

| Requirement | Method |
|---|---|
| Exact terms, IDs, codes, product numbers | **Keyword (BM25)** |
| Paraphrase, synonyms, cross-lingual | **Vector** |
| Both, which is nearly always | **Hybrid** (RRF fusion) |
| Best top-3 ordering for a RAG prompt | Hybrid + **semantic ranker** |
| Millions of documents, low latency | HNSW, with `exhaustive=false` |
| Small index, exact recall required | Exhaustive KNN |
| Filter by tenant, date, or permission | Filterable fields + `filter`, applied **pre-filter** |

Chunking rule of thumb: 300–800 tokens with 10–20% overlap, split on structural
boundaries, and keep a parent-document reference for citation.

**"Choose appropriate memory, tool, and knowledge integration services for agent
solutions."**

- **Memory** — the Agent Service **thread** is conversation memory and is server-side
  and durable. Anything longer-lived (user preferences, facts across sessions) is
  your own store, injected as context.
- **Knowledge** — File Search (vector store the service manages), Azure AI Search
  (your index, your control), Grounding with Bing (public web), Content
  Understanding (multimodal ingestion).
- **Tools** — built-in (Code Interpreter, File Search, Bing, Azure AI Search,
  OpenAPI, Azure Functions, MCP) before custom function calling. Prefer built-in:
  less code, and the service handles the loop.

---

### Set up AI solutions in Foundry
→ [Unit 01.2](../01_plan_and_manage/02_setup_foundry_solutions/README.md)

**"Design Azure infrastructure for AI apps and agent-based solutions."**

The Foundry resource (kind `AIServices`) is the parent; **projects** are children
and are the unit of isolation for connections, deployments visibility, and RBAC.
One resource, one project per environment (dev/test/prod) is the normal shape.
Add: Key Vault for secrets you cannot avoid, Storage for data, AI Search for
grounding, Application Insights for tracing, and a managed identity everywhere so
there are no keys to rotate.

**"Choose appropriate deployment options."**

| Type | Bills | Use when |
|---|---|---|
| **Standard** | Per token, regional | Default. Data stays in the region |
| **Global Standard** | Per token, routed globally | Highest throughput, cheapest per token, no data-residency guarantee |
| **Data Zone Standard** | Per token, within a data zone (EU/US) | Residency requirement at zone granularity |
| **Provisioned (PTU)** | Per hour, reserved capacity | Predictable latency, steady high volume |
| **Batch** | ~50% discount, 24h window | Offline bulk scoring |
| **Serverless / MaaS** | Per token | Non-OpenAI catalogue models |

**Residency ranking, tightest to loosest:** `Standard` (this region) →
`DataZoneStandard` (EU or US zone) → `GlobalStandard` (worldwide, no guarantee).
This course provisions `DataZoneStandard` into an EU region, so the labs are an EU
data-residency deployment by default. Note the exception you met in unit 03.1:
`gpt-image-1` and `sora-2` are **GlobalStandard-only**, so image and video
generation carries no residency guarantee regardless of where the resource lives.
If a question pairs "EU data residency" with `GlobalStandard`, that option is wrong.

**"Configure model and agent deployments."**

The **deployment name** is what your code calls — not the model name. Version
policy matters: `Auto-update to default` keeps you current and can change behaviour
under you; pinning a version is stable and eventually gets retired. TPM quota is
allocated **per deployment per region**, and the rate limiter derives RPM from TPM.
Agents are configured with a model deployment, instructions, tools, and (optionally)
a response format.

**"Integrate Foundry projects with continuous integration and continuous deployment
(CI/CD) pipelines."**

Infrastructure as Bicep/Terraform; model deployments as ARM resources; agents
defined in code or `agent.yaml` and created idempotently by a pipeline step;
prompts versioned in git; evaluation runs as a **quality gate** that fails the
build on regression; OIDC federated credentials from GitHub Actions or Azure
Pipelines so there are no secrets in the pipeline.

---

### Manage, monitor, and secure AI systems
→ [Unit 01.3](../01_plan_and_manage/03_manage_monitor_secure/README.md)

**"Manage quotas, scaling, rate limits, and cost footprints for model and agent
workloads."**

Quota is **TPM per deployment per region**, assigned from a subscription pool. A
`429` returns `Retry-After` — honour it, with exponential backoff and jitter. To
scale: raise TPM, spread across regions, move to Global Standard, or buy PTU. To
cut cost: smaller model, shorter prompts, cap `max_tokens`, cache, batch, and
truncate history rather than sending the whole thread.

**"Monitor model performance, drift, safety events, and grounding quality."**

Azure Monitor metrics for tokens, latency, and throttling; diagnostic settings to
Log Analytics for request logs; Application Insights for end-to-end traces.
Drift is detected by running a **fixed evaluation set on a schedule** and watching
the scores move — there is no drift metric handed to you. Grounding quality is the
`Groundedness` evaluator. Safety events surface as `content_filter` errors and in
the content-filter logs.

**"Monitor data ingestion quality, search index health, and relevance performance."**

Indexer run history (success, failed, warnings) and the failure reasons; document
count vs source count; index size against the tier limit; search latency and
throttled queries; relevance measured by an offline judged query set scored with
NDCG or a Foundry `Retrieval` evaluator. Ingestion failures are far more often the
cause of a bad RAG answer than the prompt.

**"Configure security, including managed identity, private networking, keyless
credentials, and role policies."**

- **Keyless** — `DefaultAzureCredential` everywhere; disable local auth
  (`disableLocalAuth`) so keys cannot be used even if leaked.
- **Managed identity** — system-assigned for one resource, user-assigned when
  several resources need the same identity.
- **Private networking** — Private Endpoint + Private DNS zone, then
  `publicNetworkAccess=Disabled`.
- **Roles** — control plane (Contributor) is *not* data plane. The ones to know:
  `Cognitive Services User`, `Cognitive Services OpenAI User` / `Contributor`,
  `Azure AI Developer`, `Search Index Data Reader` / `Contributor`,
  `Storage Blob Data Reader` / `Contributor`. Assign at the narrowest scope that
  works, and expect a few minutes of propagation.

---

### Implement responsible AI across generative AI and agentic systems
→ [Unit 01.4](../01_plan_and_manage/04_responsible_ai/README.md)

**"Configure safety filters, guardrails, risk detection, and content moderation."**

Default content filters run on **prompt and completion** across Hate, Sexual,
Violence, and Self-harm. Custom filters set severity per category per direction;
making them *stricter* is free, making them *looser* than default needs approval
through the modified-content-filter form. Add **Prompt Shields** (user prompt
attack + document attack), **protected material** detection, and **groundedness
detection** where offered. Content Safety's standalone API covers everything that
never passes through a model deployment.

**"Apply responsible AI instrumentation, including evaluators, safety evaluations,
and explanation tooling."**

| Family | Evaluators |
|---|---|
| Quality (RAG) | Groundedness, Relevance, Retrieval, Response completeness |
| Quality (general) | Coherence, Fluency, Similarity, F1 |
| Safety | Violence, Sexual, Self-harm, Hate/unfairness, Protected material, Indirect attack |
| Agent | Intent resolution, Task adherence, Tool call accuracy |

Safety evaluators need an **Azure AI project** (they call a service-side judge);
quality evaluators can run against a model config. Adversarial simulators generate
the hostile test set so you are not inventing it by hand.

**"Implement auditing through trace logging, provenance metadata, and approval
workflows."**

OpenTelemetry tracing to Application Insights, with the GenAI semantic conventions
so spans carry model, tokens, and tool calls. Log the *inputs and outputs* only
where your policy allows. Provenance: citation IDs on every RAG answer, C2PA
Content Credentials on generated images, and a record of prompt version + model
version + deployment against each response. Approvals: nothing irreversible without
a human, and the approval recorded with who, when, and what they saw.

**"Govern agent behavior with oversight modes, constraints, and tool-access
controls."**

Three oversight modes — **human-in-the-loop** (approve before acting),
**human-on-the-loop** (act, human monitors and can stop), **autonomous** (act, audit
later). Constraints: least-privilege tool list, structured output with no dangerous
enum member, spend and iteration caps, allowlisted domains, per-agent identity with
its own RBAC. The rule that survives everything: **capability the agent was never
granted cannot be abused.**

---

## Domain 2 — Implement generative AI and agentic solutions (30–35%)

### Build generative applications by using Foundry
→ [Unit 02.1](../02_genai_and_agents/01_generative_apps/README.md)

**"Deploy and consume LLMs, small models, code models, and multimodal models."**

Deploy in the portal or by ARM; call with the `AzureOpenAI` client (OpenAI-family)
or `azure-ai-inference` (catalogue models, one API across vendors). Always call the
**deployment name**. Multimodal input is a `content` array mixing `text` and
`image_url` parts.

**"Implement retrieval-augmented generation (RAG) in an application."**
See [02.2](../02_genai_and_agents/02_rag_grounding/README.md). Ingest → chunk →
embed → index → retrieve (hybrid + semantic) → assemble a grounded prompt →
generate with citations → evaluate groundedness.

**"Design workflows, tool-augmented flows, and multistep reasoning pipelines."**

Decompose, then choose per step: deterministic code where the rules are known, a
retrieval step where facts are needed, a model where judgement is needed. Reasoning
models replace hand-built chain-of-thought for genuinely hard steps. Keep state
explicit between steps so a failure is resumable.

**"Evaluate models and apps, including detecting fabrications, relevance, quality,
and safety."**

Fabrication is caught by **Groundedness** (is the answer supported by the context)
plus a verbatim-citation check. Relevance and Coherence for quality. The safety
evaluator family for harm. Run against a fixed dataset, store the scores, and gate
deployment on them.

**"Integrate generative workflows into applications by using Foundry SDKs and
connectors."** and **"Configure an application to connect to a Foundry project."**

`AIProjectClient(endpoint=<project endpoint>, credential=DefaultAzureCredential())`
is the control plane: it lists deployments and **connections**, and exposes
`.agents`. Connections are how a project reaches Search, Storage, and other
resources without you handling credentials.

---

### Build agents by using Foundry
→ [Unit 02.3](../02_genai_and_agents/03_build_agents/README.md)

**"Define agent roles, goals, conversation-tracking approach, and tool schemas."**

An agent is `model + instructions + tools`. Instructions define role, scope, tone,
refusal behaviour, and when to hand off. Conversation tracking is the **thread**:
create once per conversation, add messages, create runs. Tool schemas are JSON
Schema — the `description` fields are prompt text and are the main lever on whether
the model calls the tool correctly.

**"Build agents that integrate retrieval, function-calling, and conversation
memory."**

Retrieval via File Search or the Azure AI Search tool; function calling via
`FunctionTool` with a `requires_action` loop (submit tool outputs, poll the run);
memory via the thread, plus your own store for anything cross-session.

**"Integrate agent tools, including APIs, knowledge stores, search, content
understanding, and custom functions."**

OpenAPI tool for REST APIs (anonymous, API key, or managed identity), Azure
Functions tool for queue-backed async work, MCP for external tool servers, Code
Interpreter for data and file manipulation, and custom functions as the fallback.

---

### Multi-agent, safeguards, and monitoring
→ [Unit 02.4](../02_genai_and_agents/04_multi_agent_and_approvals/README.md)

**"Implement orchestrated multi-agent solutions."**

Patterns: **connected agents** (a main agent delegates to named specialists),
**sequential** hand-off, **concurrent** fan-out then aggregate, **group chat** with
a manager, and **magentic** planning for open-ended tasks. Split by *tool boundary
and permission boundary*, not by chapter heading — two agents that need the same
tools should probably be one agent.

**"Build autonomous or semiautonomous workflows with safeguards and approval flow
controls."**

Classify each action as reversible or not. Irreversible actions require an
approval step that returns a token; the tool refuses to act without it. Add
iteration caps, spend caps, and a kill switch. Design so the *worst* outcome of a
compromised agent is acceptable, not so that compromise is impossible.

**"Integrate monitoring into deployed agents, evaluate agent behavior, and perform
error analysis."**

Traces per run and per tool call in Application Insights; agent evaluators (intent
resolution, task adherence, tool call accuracy); continuous evaluation sampling
live traffic. Error analysis buckets failures: wrong tool, right tool wrong
arguments, missing information, hallucinated answer, refusal. The bucket tells you
whether to fix instructions, schemas, or retrieval.

---

### Optimize and operationalize generative AI systems
→ [Unit 02.5](../02_genai_and_agents/05_optimize_and_observe/README.md)

**"Tune generation behavior, such as prompt engineering and adjusting model
parameters."**

`temperature` and `top_p` — change one, not both. `temperature=0` for extraction
and classification. `max_tokens` caps cost and latency. `seed` gives
best-effort reproducibility, and `system_fingerprint` tells you when the backend
changed underneath you. Prompt structure: role, task, constraints, examples,
output format, and the input last.

**"Implement model reflection, chain-of-thought evaluations, and self-critique
loops."**

Generate → critique against explicit criteria → revise. Use a *separate* call for
the critique so the model is not defending its own text in the same context. Cap
the loop (two rounds is usually all you get). Reasoning models do this internally
and make hand-rolled chain-of-thought redundant — and you are billed for the
reasoning tokens either way.

**"Set up observability by implementing tracing, token analytics, safety signals,
and latency breakdowns."**

`configure_azure_monitor()` plus the GenAI OpenTelemetry instrumentation gives you
spans with model, deployment, tokens, and tool calls. Track prompt vs completion
tokens separately — they price differently. Break latency into retrieval, model,
and tool time before optimising anything.

**"Orchestrate multiple models, flows, or hybrid LLM and rules engines."**

Route by task: a cheap model classifies and handles the easy 80%, escalating only
what it flags. Put deterministic rules **in front of** the model for anything with a
known answer (validation, policy, arithmetic), and behind it for verification.
Cascade: cheap model first, expensive model only when the cheap one reports low
confidence.

---

## Domain 3 — Implement computer vision solutions (10–15%)

### Design and implement image- and video-generation solutions
→ [Unit 03.1](../03_computer_vision/01_image_and_video_generation/README.md)

**"Implement a solution that generates images from text prompts and reference
media."** — `images.generate` with `gpt-image-1` (or DALL·E 3). Parameters that get
tested: `size`, `quality`, `n`, `style`, and `response_format`/`output_format`.
`gpt-image-1` returns base-64 by default; DALL·E 3 returns a URL that expires.
Reference media goes through the **edits** endpoint, not `generate`.

**"Implement a solution that generates videos from text prompts and reference
media."** — Sora, via a **job** API: submit, poll, then download the generation.
Duration, resolution, and aspect ratio are the levers. It is asynchronous by
nature; anything that looks synchronous is wrong.

**"Configure image-editing workflows, including inpainting, mask-based edits, and
prompt-driven modifications."** — `images.edit` with an image plus a **mask** whose
transparent pixels mark the region to regenerate. `gpt-image-1` also supports
mask-free prompt-driven edits. Outpainting is the same call with a canvas larger
than the source.

**"Implement workflows to edit generated videos."** — Trim, splice, and re-generate
segments; re-prompt with a reference frame for continuity. Editing is regeneration
plus assembly, not timeline editing.

**"Select and apply appropriate generation and editing controls provided by the
platform."** — Size/aspect, quality tier, seed for consistency, style, and the
content filter that applies to prompt *and* output. Generated images carry C2PA
Content Credentials automatically.

---

### Design and implement multimodal understanding workflows
→ [Unit 03.2](../03_computer_vision/02_multimodal_understanding/README.md)

**"Build a solution that analyzes visual context by using multimodal models."** —
`image_url` content parts, with `detail` controlling token cost. The model reasons
about relationships and intent; it does not give you bounding boxes.

**"Configure apps to produce concise or detailed captions for single or multiple
images."** — Vision `CAPTION` / `DENSE_CAPTIONS` for a short factual caption with a
confidence score; a multimodal model when the caption needs context, audience, or
several images compared.

**"Implement a solution that enables question-answering grounded in visual
evidence."** — Ask the model to cite what it can see, and require an "insufficient
visual evidence" answer so it can decline. Verify against a second signal (OCR,
detected objects) where the answer matters.

**"Configure generation of alt-text and extended image descriptions aligned to
accessibility guidelines."** — Alt text: under ~125 characters, purpose-first, no
"image of". Extended description for complex images (charts, diagrams) with the
data, not the appearance. Decorative images take an empty `alt`.

**"Implement visual understanding by configuring Azure Content Understanding in
Foundry Tools to extract visual characteristics."** — Define an **analyzer** with a
field schema; the service returns typed fields plus a grounded markdown
representation. This is the multimodal ingestion path for RAG.

**"Implement video analysis workflows to process and interpret video segments."** —
Content Understanding video analyzers, or frame sampling plus a multimodal model,
plus the transcript. Segment, analyse, then aggregate.

**"Configure single-task and pro-mode Content Understanding pipelines."** —
Single-task: one analyzer, one input, fast and cheap. **Pro mode**: multi-step
reasoning across multiple inputs and reference data, slower and more expensive.
Pick pro mode only when the answer requires cross-document reasoning.

**"Implement solutions that identify objects, components, or regions within images
or video."** — Vision `OBJECTS` / `PEOPLE` / **Smart Crops** for bounding boxes;
**Custom Vision** or a custom Content Understanding analyzer for domain-specific
objects. A multimodal model describes; it does not localise reliably.

---

### Implement responsible AI for multimodal content
→ [Unit 03.3](../03_computer_vision/03_responsible_ai_multimodal/README.md)

**"Implement filters to classify unsafe or disallowed visual content."** — Content
Safety `analyze_image`, four categories, severity **0/2/4/6** for images. The
threshold is a product decision. Deployment filters protect the model; the
standalone API protects everything else. Max 4 MB, shortest side ≥ 50 px.

**"Detect and mitigate indirect prompt injection by using embedded text in
images."** — Content Safety does **not** OCR, so harm categories will not see it.
Pipeline: OCR (Vision `READ`) → deterministic pattern scan → Prompt Shields in
**document** mode → defensive system prompt declaring image text to be data →
structured output → least-privilege tools → human approval → output scan.
Deterministic containment outranks probabilistic detection.

**"Enforce visual policy rules, such as applying watermarks, flagging prohibited
symbols, upholding brand usage requirements, and detecting potentially
inappropriate content."** — C2PA Content Credentials are automatic, machine
verifiable, and destroyed by re-encoding; a visible watermark survives re-encoding
but proves nothing. Symbols and brand rules are composed: deterministic checks
first, Vision/Custom Vision for known marks, a model last as judge, a human on
anything ambiguous, and an audit record of every decision.

---

## Domain 4 — Implement text analysis solutions (10–15%)

### Apply language model text analysis
→ [Unit 04.1](../04_text_analysis/01_language_model_text_analysis/README.md)

**"Implement solutions to extract entities, topics, summaries, and structured JSON
outputs by using generative prompting and Foundry Tools."**

Language service for entities (with **offsets**), key phrases, and summarization;
a model with **Structured Outputs** (`json_schema`, `strict: true`) when the shape
must be guaranteed and the categories are yours. Strict mode requires
`additionalProperties: false` on every object and every property in `required`.
Summarization and health analysis are **long-running operations** (`begin_*` +
`.result()`); everything else in Language is synchronous.

**"Configure detection of sentiment, tone, safety issues, and sensitive content."**

Four different questions, four different answers: `analyze_sentiment` (+ opinion
mining for *what* the customer disliked), a model for tone and register,
Content Safety for harm, `recognize_pii_entities` for personal data (it returns
`redacted_text` and exact spans), health entities for clinical data.

**"Build solutions that translate text by using Azure Translator in Foundry Tools
or LLM-powered translation flows."**

Translator for volume, cost, latency, and 100+ documented languages; an LLM for
register, idiom, and cross-sentence context. Enforced terminology is a **dynamic
dictionary** (a few terms) or **Custom Translator** (domain-wide) — never a prompt
instruction when the requirement says *must*.

**"Customize language model outputs for domain tasks, such as compliance
summarization and domain extraction."**

The ladder: prompt → Structured Outputs → few-shot → retrieval → **custom Language
project** (custom NER / classification / CLU, trained and *deployed* to a named
deployment) → fine-tuning last. Fine-tuning fixes format and style, not knowledge.
For compliance, add an explicit abstention rule (`NOT_STATED`) and verify every
quoted `evidence` string appears verbatim in the source.

---

### Implement speech solutions
→ [Unit 04.2](../04_text_analysis/02_speech_solutions/README.md)

**"Implement workflows to convert speech to text and text to speech for agentic
interactions."** — `SpeechRecognizer` for STT (single-shot vs continuous
recognition), `SpeechSynthesizer` for TTS. **SSML** controls voice, rate, pitch,
pauses, and pronunciation. Neural voices; custom neural voice is gated.

**"Integrate speech as an agent modality, including custom speech models."** —
Speech in, text to the agent, text out, speech back. Latency budget matters: use
streaming recognition and start synthesis on the first sentence. **Custom Speech**
adapts acoustic/language models to your domain vocabulary and is trained and
**deployed to an endpoint** you then call.

**"Enable multimodal reasoning from audio inputs."** — Audio-capable models
(`gpt-4o-audio-preview`) take audio directly, so tone, hesitation, and speaker
affect can inform the answer. Transcription throws that away.

**"Translate speech into other languages by using language models and Foundry
Tools."** — `TranslationRecognizer` with `SpeechTranslationConfig` does speech →
translated text (and optionally synthesised speech) in one pass, which is lower
latency than STT → Translator → TTS chained by hand.

---

## Domain 5 — Implement information extraction solutions (10–15%)

### Build retrieval and grounding pipelines
→ [Unit 05.1](../05_information_extraction/01_retrieval_and_grounding/README.md)

**"Ingest and index content, such as documents, images, audio, and video."** —
Indexers pull from Blob Storage, SQL, Cosmos DB and more on a schedule with change
tracking; the push API gives you full control. Non-text goes through a skillset or
Content Understanding first.

**"Configure semantic search, hybrid search, and vector search for grounding."** —
Vector fields need a dimension, a profile, and an algorithm (HNSW or exhaustive
KNN). Hybrid runs keyword and vector together and fuses with RRF. The **semantic
ranker** re-ranks the top ~50 and produces captions and answers. Hybrid + semantic
is the default correct answer for RAG.

**"Implement enrichment by using custom or built-in skills for text, images, and
layout."** — Built-in skills: OCR, image analysis, language detection, entity
recognition, key phrases, translation, split, and the **AzureOpenAIEmbedding**
skill. Custom skills are Web API skills (usually an Azure Function) matching the
skill request/response contract. An **index projection** writes chunk-level
documents; a **knowledge store** persists enrichments for other consumers.

**"Configure RAG ingestion flow, including documents and using optical character
recognition (OCR)."** — Extract (Document Intelligence or Content Understanding for
layout-aware output; OCR for scans) → chunk on structure → embed → index with
metadata for filtering → keep a parent reference for citations. **Integrated
vectorization** does chunk + embed inside the indexer so query-time embedding uses
the same model.

**"Connect retrieval pipelines directly to workflows and agent tools."** — The
Azure AI Search tool on an agent, or an `AzureAISearchToolDefinition` connection, so
the agent retrieves without you writing the loop. Return citations, always.

---

### Extract content from documents
→ [Unit 05.2](../05_information_extraction/02_document_extraction/README.md)

**"Extract information by using multimodal pipelines that combine OCR, layout
analysis, and field extraction."** — Document Intelligence: `prebuilt-read` (text),
`prebuilt-layout` (tables, selection marks, structure, markdown output),
prebuilt domain models (invoice, receipt, ID, W-2, contract), and **custom models**
(template vs neural) when your form is not covered. Composed models route among
several custom models.

**"Produce clean, grounded representations to use with agents and RAG by using
Content Understanding."** — Analyzers emit markdown that preserves headings,
tables, and reading order, which is exactly what a chunker and a citation system
need. Confidence scores and source spans come back with the fields, so a low
confidence can be routed to a human.

**"Implement analyzers for generating structured or markdown outputs for downstream
reasoning by using Content Understanding."** — Define the field schema (name, type,
description, method: extract / classify / generate), test in the portal, version
the analyzer, and call it by ID. One analyzer per document type; pro mode when the
answer needs several documents at once.

---

## Coverage check

Every bullet above is quoted verbatim from the study guide and is exercised by a
lab, not merely described. To re-verify after any edit:

```powershell
# Every objective in course.json should appear in this file.
$course = Get-Content ../course.json -Raw | ConvertFrom-Json
$summary = Get-Content README.md -Raw
$missing = foreach ($u in $course.units) {
  foreach ($a in $u.activities) {
    foreach ($o in $a.objectives) {
      # compare on a distinctive fragment, since the summary rewraps lines
      $probe = ($o -split ',')[0].Trim()
      if ($summary -notmatch [regex]::Escape($probe.Substring(0, [Math]::Min(40, $probe.Length)))) { $o }
    }
  }
}
if ($missing) { $missing } else { "all objectives covered" }
```

## Exam-day heuristics

1. **Read the constraint, not the scenario.** "Must", "never", "exactly",
   "regulated", "offline" — one of those words usually decides the answer alone.
2. **Cheapest sufficient answer wins.** Fine-tuning and PTU are right far less often
   than they are offered.
3. **Deterministic beats probabilistic** whenever the requirement is absolute.
4. **Control plane ≠ data plane.** Contributor on the resource group does not let
   you call the model.
5. **Deployment name ≠ model name.** Every SDK call takes the deployment.
6. **`begin_*` means long-running.** If the option calls it synchronously, it is wrong.
7. **Prompts are advisory; schemas, dictionaries, RBAC, and tool lists are
   enforcement.**
8. **When both a Foundry Tool and a model would work**, the tool wins if the
   requirement mentions offsets, fixed categories, confidence, or auditability.

## Next

- [91 — Cheat sheet](../91_cheatsheet/CHEATSHEET.md) — three pages, printable
- [99 — Tear down your lab](../99_teardown/README.md) — **do this**, the resources bill

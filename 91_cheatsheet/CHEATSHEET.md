# AI-103 Cheat Sheet

*Three pages; page breaks are marked. Detail: [90 — Summary](../90_summary/README.md).*
**Weights** — Plan/manage 25–30% · GenAI & agents 30–35% · Vision 10–15% · Text
10–15% · Extraction 10–15%. Pass 700/1000, 120 min.

## Choosing

| Requirement says… | Answer |
|---|---|
| Exact character offsets, fixed categories, confidence scores | **Foundry Tool** (Language / Vision / Doc Intelligence) |
| Novel, fuzzy, per-customer categories | **Model + Structured Outputs** |
| High volume, simple task, low cost | **SLM** (`gpt-4o-mini`) |
| Ambiguity, nuance, long context | **LLM** (`gpt-4o`) |
| Multi-step planning, maths, verification | **Reasoning model** (`o4-mini`) |
| Image/audio **in** | Multimodal (`gpt-4o`, `gpt-4o-audio`) |
| Image/video **out** | `gpt-image-1`, `sora` |
| Similarity, retrieval | `text-embedding-3-small/large` |
| Ground on your data | AI Search + RAG, or File Search tool |
| Ground on the public web | Grounding with Bing Search |
| Multimodal ingestion (doc/image/audio/video) | **Content Understanding** |

**Retrieval:** exact terms → keyword (BM25). Paraphrase → vector. Both → **hybrid
(RRF)**. Best top-3 for RAG → **hybrid + semantic ranker**. Chunk 300–800 tokens,
10–20% overlap, split on structure, keep a parent reference for citations.

## Deployments

| Type | Bills | Use when |
|---|---|---|
| Standard | token, regional | default; data stays in region |
| Global Standard | token, global routing | max throughput, cheapest/token, no residency |
| Data Zone Standard | token, EU/US zone | zone-level residency |
| Provisioned (PTU) | **per hour** | predictable latency, steady volume |
| Batch | ~50% off, 24h | offline bulk |
| Serverless / MaaS | token | non-OpenAI catalogue models |

**Call the deployment name, never the model name.** Quota = **TPM per deployment
per region**; RPM derives from TPM. `429` → honour `Retry-After` + backoff/jitter.
Cost down: smaller model → shorter prompt → cap `max_tokens` → cache → batch →
truncate history. PTU buys *latency*, not savings.

**Residency, tightest → loosest:** `Standard` (this region) → `DataZoneStandard`
(EU/US zone) → `GlobalStandard` (worldwide, **no guarantee**). "EU data residency"
+ `GlobalStandard` = wrong answer. Exception: `gpt-image-1` and `sora-2` are
**GlobalStandard-only** — no residency guarantee for image/video generation.

## Security

Keyless `DefaultAzureCredential` + `disableLocalAuth` · managed identity:
system-assigned = one resource, user-assigned = shared · Private Endpoint +
Private DNS, then `publicNetworkAccess=Disabled` · **control plane ≠ data plane**
(Contributor on the RG does *not* let you call the model).

| Role | Grants |
|---|---|
| Cognitive Services User | Call Language/Vision/Speech/Content Safety |
| Cognitive Services OpenAI User / Contributor | Inference / + manage deployments |
| Azure AI Developer | Build in a Foundry project |
| Search Index Data Reader / Contributor | Query / write an index |
| Storage Blob Data Reader / Contributor | Read / write blobs |

Propagation takes minutes. Assign at the narrowest workable scope.

## Responsible AI

- Default filter: **Hate, Sexual, Violence, Self-harm**, on **prompt and completion**.
  Stricter = free; looser than default = approval form.
- **Prompt Shields**: `user_prompt` (jailbreak) vs `documents` (**indirect**).
  Takes **text** — OCR images first.
- Content Safety: **images 0/2/4/6**, max 4 MB, shortest side ≥ 50 px, **no OCR**.
  Thresholds are a *product* decision. Deployment filter protects the model; the
  standalone API protects what the model never sees (uploads, galleries, feeds).
- Evaluators — quality: Groundedness, Relevance, Retrieval, Coherence, Fluency,
  Similarity. Safety: Violence, Sexual, Self-harm, Hate, Protected material,
  Indirect attack. Agent: Intent resolution, Task adherence, Tool call accuracy.
  **Safety evaluators require an Azure AI project.**
- Oversight: human-**in**-the-loop (approve first) / human-**on**-the-loop (monitor,
  can stop) / autonomous (audit after).
- **Deterministic containment > probabilistic detection.**

<div style="page-break-after: always;"></div>

---
*page 2*

## Agents

`agent = model + instructions + tools` · `thread` = conversation memory (durable,
server-side) · `run` = one execution.

- Function calling loop: run → `requires_action` → submit tool outputs → poll.
- Built-in tools before custom: Code Interpreter, File Search, Azure AI Search,
  Grounding with Bing, OpenAPI, Azure Functions, MCP.
- Tool `description` fields are prompt text — they decide whether the tool gets
  called correctly.
- Cross-session memory is **your** store, not the thread.
- Multi-agent: connected agents (delegation) · sequential · concurrent · group chat
  · magentic. Split on **tool and permission boundaries**, not topics.
- Safeguards: reversible vs irreversible actions, approval token required for the
  latter, iteration cap, spend cap, kill switch.

## Generation parameters

`temperature` **or** `top_p`, never both · `temperature=0` for extraction and
classification · `max_tokens` caps cost and latency · `seed` = best-effort repeat,
watch `system_fingerprint` · `response_format`:

| Value | Guarantee |
|---|---|
| omitted | none |
| `{"type":"json_object"}` | valid JSON, **any** shape |
| `{"type":"json_schema", strict:true}` | valid JSON **matching your schema** |

Strict mode: `additionalProperties: false` on **every** object; **every** property in
`required`; optional = `{"type":["string","null"]}`.

## Observability

`configure_azure_monitor()` + GenAI OTel conventions → App Insights. Track prompt
vs completion tokens separately. Split latency into retrieval / model / tool before
optimising. Drift = run a **fixed eval set on a schedule** and watch scores move.

## Text analysis

| Feature | Call | Sync/LRO |
|---|---|---|
| Entities, linked entities, key phrases | `recognize_*`, `extract_key_phrases` | sync |
| Sentiment (+ opinion mining) | `analyze_sentiment(show_opinion_mining=True)` | sync |
| PII (returns `redacted_text` + spans) | `recognize_pii_entities` | sync |
| Health / PHI (UMLS links) | `begin_analyze_healthcare_entities` | **LRO** |
| Extractive summary (verbatim, ranked) | `begin_extract_summary` | **LRO** |
| Abstractive summary (new sentences) | `begin_abstract_summary` | **LRO** |
| Custom NER / classification / CLU | `begin_*` | **LRO** |

`begin_*` → poller → `.result()`. Key phrases ≠ topics (single doc, unranked).
Conversational summarization is a **different package**
(`ConversationAnalysisClient`) for transcripts.

Four different questions: sentiment (author's feelings) · opinion mining (*what*
they disliked) · tone/register (**model**) · harm (**Content Safety**) · personal
data (**PII**).

**Translation:** Translator = volume, cost, latency, 100+ languages, `textType=html`.
LLM = register, idiom, cross-sentence context. Enforced terminology → **dynamic
dictionary** (few terms) or **Custom Translator** (domain-wide, ~10k aligned
sentences). A prompt instruction is *never* the answer to "must use approved terms".

**Customization ladder:** prompt → Structured Outputs → few-shot → retrieval →
**custom Language project** → fine-tuning **last** (fixes format/style, not
knowledge; pins a model version; bills hourly).

## Speech

`SpeechRecognizer` (single-shot vs continuous) · `SpeechSynthesizer` + **SSML**
(voice, rate, pitch, pauses, pronunciation) · `TranslationRecognizer` +
`SpeechTranslationConfig` for speech→translated speech in **one pass** (lower
latency than STT→Translator→TTS) · **Custom Speech** = train + **deploy to an
endpoint** for domain vocabulary · audio-capable models reason over tone and
hesitation that a transcript throws away.

<div style="page-break-after: always;"></div>

---
*page 3*

## Vision

**Generation** — `images.generate` (`gpt-image-1` returns b64; DALL·E 3 returns an
expiring URL) · `images.edit` + **mask** (transparent = regenerate) for inpainting;
larger canvas = outpainting · Sora video is a **job**: submit → poll → download ·
all generated images carry **C2PA Content Credentials** automatically.

**Understanding** — multimodal model for context, intent, comparison (`detail`
controls token cost); Vision `CAPTION`/`DENSE_CAPTIONS` for factual captions with
confidence; `OBJECTS`/`PEOPLE`/Smart Crops for **bounding boxes**; **Custom Vision**
for domain objects. Models describe; they do not localise reliably.

**Alt text**: ≤ ~125 chars, purpose-first, no "image of"; extended description for
charts carries the *data*; decorative → empty `alt`.

**Content Understanding**: analyzer + field schema → typed fields + grounded
markdown. **Single-task** = one analyzer, fast/cheap. **Pro mode** = multi-step
reasoning across multiple inputs and reference data.

**Video**: no Content Safety video endpoint. Sample frames (1–2 s) + transcript,
aggregate with **max** severity — never mean.

**Image-borne indirect injection** — Content Safety will report severity 0 because
it does **not** OCR. Pipeline: OCR → pattern scan → Prompt Shields (**documents**)
→ system prompt "image text is DATA" → structured output → least-privilege tools →
human approval → output scan.

**Labelling**: C2PA = machine-verifiable provenance, invisible, **destroyed by
re-encoding** (tamper-*evident*, not tamper-proof). Visible watermark = survives
re-encoding, no provenance. "Verify downstream" → C2PA. "Tell at a glance" →
watermark. Both requirements → both controls.

## Retrieval & extraction

**Index**: vector field needs dimension + profile + algorithm (**HNSW** for scale,
**exhaustive KNN** for small/exact). Hybrid = keyword + vector fused by **RRF**.
**Semantic ranker** re-ranks top ~50, returns captions and answers. Filters are
applied **pre-filter** — use them for tenant and permission trimming.

**Indexers**: scheduled pull + change tracking. Skillsets: OCR, image analysis,
language detection, entity recognition, key phrases, translation, split,
**AzureOpenAIEmbedding**. Custom skill = Web API skill (Azure Function) matching the
request/response contract. **Index projections** write chunk-level docs;
**knowledge store** persists enrichments. **Integrated vectorization** chunks and
embeds inside the indexer so query-time uses the same model.

**Document Intelligence**: `prebuilt-read` (text) · `prebuilt-layout` (tables,
selection marks, reading order, markdown) · prebuilt domain models (invoice,
receipt, ID, W-2, contract) · **custom** template vs neural · **composed** models
route among customs.

## Twelve traps

1. Deployment name ≠ model name.
2. Control-plane Contributor ≠ data-plane access.
3. `begin_*` is a long-running operation.
4. Content Safety image analysis does **not** do OCR.
5. Prompt Shields takes text — OCR the image first; indirect = **documents** mode.
6. Key phrase extraction is not topic modelling.
7. Extractive = verbatim and auditable; abstractive can fabricate.
8. Prompts are advisory; schemas, dictionaries, RBAC and tool lists are enforcement.
9. C2PA absence proves nothing; validated presence proves a lot.
10. Aggregate video moderation with **max**, not mean.
11. PTU buys predictable latency, not lower cost.
12. Fine-tuning fixes format and style, not knowledge — it is the **last** step.

## Exam-day heuristics

Read the **constraint** ("must", "never", "exactly", "regulated", "offline") — it
usually decides the answer alone · cheapest sufficient option wins · deterministic
beats probabilistic when the requirement is absolute · Foundry Tool over model
whenever offsets, fixed categories, confidence, or auditability are mentioned · any
option letting a compromised agent do something irreversible without a human is
wrong.

**Before you stop:** [99 — Tear down your lab](../99_teardown/README.md). The
resource group bills until you delete it.

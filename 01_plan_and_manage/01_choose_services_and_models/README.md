# 01.1 — Choose the appropriate Foundry services for generative AI and agents

**Time:** 60–75 minutes · **Cost:** under $0.50 — a few hundred model calls, nothing hourly

This unit is almost entirely **decisions**. There is very little to build. The exam
for this section reads like a series of short scenarios ending in "which service?"
or "which model?", and the wrong answers are always plausible. What separates a
pass from a fail is knowing the *axis* each choice turns on: latency, cost,
modality, freshness, statefulness, or data residency.

By the end you will have:

- [ ] Queried the model catalog programmatically and read its capability metadata
- [ ] Measured cost, latency, and quality for `gpt-4o-mini`, `gpt-4o`, and `o4-mini`
      on one identical task
- [ ] A written, defensible model choice with numbers behind it
- [ ] A decision table for services, retrieval methods, and agent integrations that
      you can recall under exam pressure

---

## Concepts

### 1. Model families — what each one is *for*

The study guide bullet is "Choose an appropriate model for each task, including
large language models (LLMs), small language models, multimodal models, and Foundry
Tools." Those four are not a spectrum. They are four different answers to four
different questions.

| Family | Examples in Foundry | Strength | Weakness | Reach for it when |
|---|---|---|---|---|
| **LLM** (frontier) | `gpt-4o`, `gpt-4.1`, `Llama-3.3-70B` | Broad world knowledge, long instructions, nuanced writing | Slowest and most expensive per token | Ambiguous, open-ended, or high-stakes generation |
| **SLM** (small) | `gpt-4o-mini`, `Phi-4`, `Phi-4-mini`, `Ministral-3B` | 10–30× cheaper, low latency, deployable to edge | Weaker multi-step reasoning, shallower knowledge | High-volume classification, extraction, routing, summarising retrieved text |
| **Multimodal** | `gpt-4o`, `gpt-4.1`, `Phi-4-multimodal` | Accepts images (and for some, audio) in the same prompt | Image tokens are expensive; resolution affects cost | The input *is* a screenshot, chart, form, or photo |
| **Reasoning** | `o4-mini`, `o3`, `o3-mini` | Deliberate multi-step problem solving, planning, maths, code | Hidden reasoning tokens; high latency; ignores `temperature` | Correctness matters more than latency: planning, verification, hard debugging |
| **Embedding** | `text-embedding-3-small`, `text-embedding-3-large` | Turns text into vectors | Does not generate | Anything retrieval-shaped |
| **Foundry Tools** | Content Understanding, Language, Translator, Speech, Document Intelligence, Vision | Deterministic, trained, priced per unit of input, no prompt to tune | Fixed capability — you cannot ask them something new | The task is a *solved, narrow* task |

> **Exam note.** The single most-tested distinction here is **"prompt an LLM" vs
> "call a Foundry Tool."** If the task is bounded and well-defined — detect
> language, redact PII, transcribe audio, read a receipt, translate — the Tool is
> the correct answer. It is cheaper, faster, deterministic, and comes with
> published accuracy. Choosing an LLM for PII redaction is a trap answer even
> though an LLM *can* do it.

**Small model default.** Start on the SLM. Move up only when an evaluation shows
the small model failing. This course defaults every lab to `cfg["MODEL_MINI"]`
for exactly that reason, and the lab in this unit makes you prove it with numbers
rather than take it on faith.

**Reasoning models bill for tokens you never see.** `o4-mini` emits internal
reasoning tokens that count as completion tokens. A task that looks like 200 tokens
of output can cost 3,000. Read
`usage.completion_tokens_details.reasoning_tokens` before you commit to one.

### 2. Service selection

The second bullet — "generative tasks, grounding, vector search, agent workflows, or
multimodal processing" — maps onto five distinct services. Fix this table:

| Need | Service | Endpoint / client | Why not the alternative |
|---|---|---|---|
| Generate text from a prompt | **Model deployment** on the Foundry resource | `AzureOpenAI` / `ChatCompletionsClient` | An agent adds state and tools you do not need for a stateless call |
| Ground answers in your own documents | **Azure AI Search** index + retrieval in your app (RAG) | `SearchClient` | Fine-tuning teaches style, not facts, and cannot be updated hourly |
| Vector / hybrid / semantic search | **Azure AI Search** (vector fields + semantic ranker) | `SearchClient` | Cosmos DB and PostgreSQL `pgvector` do vectors but not hybrid + semantic reranking in one query |
| Stateful, tool-using assistant | **Foundry Agent Service** | `AIProjectClient.agents` | Hand-rolling threads means you own memory, tool loops, and tracing |
| Read images, documents, audio, video into structured data | **Content Understanding** (Foundry Tools) | Analyzer endpoint | A multimodal LLM is fine ad hoc, but Content Understanding gives schemas and confidence |
| Narrow language task (PII, sentiment, translate, transcribe) | **Foundry Tools** (Language, Translator, Speech) | Service-specific client | LLM costs more and varies run to run |
| Block or flag harmful content | **Azure AI Content Safety** + deployment content filter | `ContentSafetyClient` | Prompt-based self-moderation is trivially bypassed |

**Grounding is not fine-tuning.** This comes up constantly:

| | RAG / grounding | Fine-tuning |
|---|---|---|
| Teaches | Facts, current data | Format, tone, task shape |
| Update latency | Seconds — reindex | Hours — retrain and redeploy |
| Cost model | Per-query tokens (large prompts) | Training cost + hosting cost |
| Citability | Yes — you have the source chunk | No |
| Right answer when | "The bot must know our Q3 policy" | "The bot must always answer in this JSON dialect" |

### 3. Retrieval and indexing method

"Choose an appropriate method for retrieval and indexing" is a bullet that hides
two separate decisions: **how you search**, and **how you get data in**.

#### How you search

| Mode | Matches on | Wins at | Loses at |
|---|---|---|---|
| **Keyword (BM25)** | Exact terms, lexical | Product codes, error IDs, names, acronyms | Synonyms, paraphrase |
| **Vector** | Semantic similarity of embeddings | Paraphrase, cross-lingual, conceptual queries | Rare literal tokens the embedding blurs — SKUs, IDs |
| **Hybrid** | Both, fused with Reciprocal Rank Fusion (RRF) | Nearly every real workload | Slightly more cost and latency |
| **Hybrid + semantic ranker** | Both, then an L2 rerank by a language model | Best relevance available; produces captions and answers | Extra charge; needs Basic tier or above |

> **Exam note.** The default correct answer for a RAG grounding scenario is
> **hybrid search with the semantic ranker**. Pure vector is the trap: it is the
> answer only when the question explicitly rules out lexical matching, and it fails
> the classic "user searches for part number `X-2200`" scenario.

#### How you index

| Method | Mechanism | Choose when |
|---|---|---|
| **Push** (`upload_documents`) | Your code writes into the index | You control the pipeline, need custom chunking, or the source is not an Azure data store |
| **Pull** (indexer + data source) | Search pulls on a schedule from Blob, SQL, Cosmos DB, ADLS | Source is a supported Azure store and a schedule is acceptable |
| **Indexer + skillset** | Pull plus AI enrichment (OCR, split, embed, entity extraction) | You want chunking and embedding to happen inside Search |
| **Integrated vectorization** | Skillset embeds at index time *and* query time | You want a managed chunk-and-embed pipeline with no glue code |

Chunking is the setting that most often decides whether RAG works. Roughly
300–800 tokens with 10–20% overlap is the standard starting point; you tune it
with the `RetrievalEvaluator` in unit 01.4.

### 4. Memory, tools, and knowledge for agents

An agent is a loop over a model plus three kinds of attachment. The exam wants you
to name the right Azure service for each.

| Attachment | Question it answers | Foundry option | Alternative |
|---|---|---|---|
| **Short-term memory** | What did we just say? | Agent Service **thread** — messages persist server-side | Hold the message list yourself |
| **Long-term memory** | What do I know about this user across sessions? | Store outside the thread: Cosmos DB, Azure SQL, or a Search index queried as a tool | — |
| **Knowledge** | What is true about our domain? | **Azure AI Search tool**, **File Search**, **Foundry IQ knowledge base**, **Bing grounding** for the public web | Stuff it into the system prompt (only for tiny, static facts) |
| **Tools — your code** | Do something in our systems | **Function calling**; **Azure Functions** for async/durable work | — |
| **Tools — an API** | Call an existing REST service | **OpenAPI 3.0 specified tool** | Hand-written function wrappers |
| **Tools — a tool server** | Reuse a shared tool catalogue | **MCP tool** (preview) | — |
| **Tools — code execution** | Compute, plot, transform a file | **Code Interpreter** | — |
| **Credentials for any of the above** | How does the agent authenticate? | A project **connection** | Secrets in the tool code — never do this |

> **Exam note.** Threads give you conversation memory *for free but only inside one
> thread*. Anything that must survive across conversations or users is your
> problem, and the expected answer is an external store — Cosmos DB or an index —
> surfaced back to the agent as a tool.

**Cost shape of an agent.** Threads are cheap. Tokens are not. Every turn resends
the accumulated thread, so a long conversation grows quadratically in cost. That is
why unit 02.5 has you truncate or summarise threads.

---

## Portal walkthrough — read the catalog like an architect

1. Go to **https://ai.azure.com**, open `ai103-project`.
2. Left nav → **Model catalog**.
3. Use the filter pane. These filters are the decision axes in UI form:

   | Filter | Values that matter | What it tells you |
   |---|---|---|
   | Collection | Azure OpenAI, Microsoft, Meta, Mistral, Cohere, DeepSeek, xAI | Who supports it and how it bills |
   | Inference tasks | Chat completion, Embeddings, Image generation, Audio | Whether it fits your call shape |
   | Deployment options | Serverless API, Managed compute, Global Standard, Provisioned | **This is the cost and isolation decision** |
   | Modality / Input type | Text, Image, Audio, Video | Multimodal or not |

4. Open **gpt-4o-mini**. On the model card note **Context window**, **Max output
   tokens**, **Training data cutoff**, and the **Deployment options** list.
5. Open **Phi-4-mini-instruct** and compare. **Check its Deployment options list
   against your own region before drawing conclusions** — in EU regions such as
   `swedencentral` the Phi models are offered as **Global Standard only**, while in
   some other regions they also offer **Managed compute**, a dedicated VM you pay
   for by the hour whether or not you call it. Where Managed compute *is* offered,
   that single screen is the whole serverless-versus-managed decision:

   | | Serverless API (Global/Standard) | Managed compute |
   |---|---|---|
   | Billing | Per token | Per VM-hour, always on |
   | Scale to zero | Yes | No |
   | Network isolation | Shared Microsoft-managed | Your VNet possible |
   | Model choice | Models Microsoft hosts | Any catalog model, including custom weights |
   | Right when | Almost always | Fixed high load, strict isolation, or an unhosted model |

6. Left nav → **Model benchmarks**. Compare `gpt-4o` and `gpt-4o-mini` on quality
   and cost. Treat published benchmarks as a shortlist tool only — the lab shows
   why your own task is the only benchmark that counts.

<details>
<summary>CLI alternative</summary>

```powershell
# Models available to deploy in your region
az cognitiveservices account list-models `
    -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
    --query "[?kind=='OpenAI'].{name:name, version:version, format:format, sku:skus[0].name}" `
    -o table

# What is already deployed
az cognitiveservices account deployment list `
    -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP -o table
```
</details>

---

## A decision procedure you can run in your head

The exam gives you a scenario, not a model name. Walk these in order and stop at
the first one that fires:

1. **Is it a solved, narrow task?** → Foundry Tool. Stop.
2. **Is a non-text modality the input?** → multimodal model or Content
   Understanding. Content Understanding if you need a schema out.
3. **Does it need facts the model cannot know?** → add retrieval. Hybrid + semantic
   ranker unless told otherwise.
4. **Does it need to hold state, call tools, and loop?** → Agent Service. Otherwise
   a plain chat call.
5. **Does correctness dominate latency?** → reasoning model. Otherwise the SLM.
6. **Only now:** does an evaluation prove the SLM is insufficient? → move up to the
   frontier LLM.

---

## Troubleshooting

**`The model 'o4-mini' is not available in region 'eastus'`**
Reasoning models roll out to a subset of regions. Check availability, then either
redeploy in `swedencentral` (the course default) or `eastus2`, or create a second
Foundry resource in a supported region and add it to the project as a connection.

**`404 DeploymentNotFound` when calling `o4-mini`**
`MODEL_REASONING` is in `.env` but the deployment may not exist. `02_provision_core.ps1`
creates it; if you built the project by hand in unit 00 you only deployed
`gpt-4o-mini` and `text-embedding-3-small`. Deploy the others or let the lab skip them.

**`400 Unsupported parameter: 'temperature'`**
Reasoning models reject `temperature`, `top_p`, and `presence_penalty`. They also
use `max_completion_tokens` rather than `max_tokens`. The lab handles this by
branching on the model name — production code needs the same branch.

**Model catalog shows a model but deployment fails with `SpecialFeatureOrQuotaIdRequired`**
Some models are gated behind registration or a specific SKU. The catalog lists
everything Microsoft publishes, not everything your subscription may deploy.

**Latency numbers in the lab look wildly inconsistent**
First call to a deployment includes connection setup, and Global Standard routes to
whichever region has capacity. Always discard a warm-up call and take a median, not
a mean. The lab does both.

---

## Check yourself

[quiz.md](quiz.md) — 14 questions on model families, service selection, retrieval
methods, and agent integration.

## Next

[01.2 — Set up AI solutions in Foundry](../02_setup_foundry_solutions/README.md)

# 01.1 — Choose services and models: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** A logistics company needs to redact personal data from 2 million archived
support emails before they can be used for analytics. Accuracy must be auditable
and the process runs once. Which is the best choice?

- A. `gpt-4o` with a redaction prompt
- B. `gpt-4o-mini` with a redaction prompt, in a Batch deployment
- C. Azure AI Language PII detection (Foundry Tools)
- D. A fine-tuned `gpt-4o-mini`

---

**2.** Which two statements about small language models (SLMs) such as `Phi-4-mini`
are correct? Choose two.

- A. They can be deployed to managed compute or to edge devices
- B. They generally outperform frontier models on multi-step reasoning
- C. They cost substantially less per token and return faster
- D. They cannot be used for classification tasks

---

**3.** A user asks your RAG assistant for "the warranty terms on part `MX-4471`."
The assistant returns generic warranty text and misses the part-specific page.
The index uses pure vector search. What is the most likely fix?

- A. Increase the number of retrieved chunks
- B. Switch to hybrid search so lexical matching can catch the part number
- C. Re-embed the corpus with a larger embedding model
- D. Lower the model temperature

---

**4.** You need the assistant to always reply in a strict internal JSON dialect
that the model has never seen. The facts it discusses change weekly. What
combination is correct?

- A. Fine-tune for the facts, RAG for the format
- B. RAG for the facts, fine-tune (or few-shot) for the format
- C. Fine-tune for both
- D. RAG for both

---

**5.** An agent must remember a user's preferred shipping address across separate
conversations that occur weeks apart. Where should that live?

- A. In the Agent Service thread
- B. In the agent's system instructions
- C. In an external store such as Cosmos DB, exposed to the agent as a tool
- D. In the model's context window

---

**6.** Which deployment consideration argues *against* choosing a model that is
only offered on **managed compute** in your region?

- A. Managed compute cannot use Microsoft Entra ID
- B. Managed compute bills per VM-hour and does not scale to zero
- C. Managed compute does not support content filters
- D. Managed compute is limited to a single model per resource

---

**7.** A team wants to add citations to every answer so a compliance officer can
verify the source. Which approach supports this?

- A. Fine-tuning on the source documents
- B. Increasing the model's context window
- C. Retrieval-augmented generation over an index
- D. Raising the temperature to encourage detail

---

**8.** You are choosing between an indexer with a skillset and a push-based
pipeline. Which fact most strongly favours the **indexer**?

- A. The source is a Blob Storage container that changes daily
- B. Documents need bespoke chunking logic written in Python
- C. The source is an internal API with a custom auth scheme
- D. You need sub-second write-to-searchable latency

---

**9.** Which is **not** a valid reason to select a reasoning model such as
`o4-mini`?

- A. The task requires multi-step planning before answering
- B. The task is verifying another model's output for logical errors
- C. The task is a high-volume, latency-sensitive intent classification
- D. The task involves non-trivial mathematics

---

**10.** An application needs to extract invoice number, total, and line items from
scanned PDFs into a fixed schema, with confidence scores per field. Which service?

- A. `gpt-4o` multimodal prompting
- B. Azure AI Content Understanding / Document Intelligence
- C. Azure AI Search with OCR skill
- D. Azure AI Translator

---

**11.** Which two Foundry capabilities give an agent access to *knowledge*? Choose
two.

- A. Code Interpreter
- B. Azure AI Search tool
- C. Bing grounding tool
- D. OpenAPI specified tool

---

**12.** Your team measures `gpt-4o-mini` at 94% accuracy and `gpt-4o` at 97% on
the same task. `gpt-4o` costs 16× more per call and adds 1.4 s of latency. The
workload is 4 million calls a month of internal document tagging, and errors are
corrected downstream by a human reviewer. What is the strongest argument?

- A. Use `gpt-4o` — accuracy always wins
- B. Use `gpt-4o-mini`; the 3-point gap is cheaper to absorb in review than in inference
- C. Use `o4-mini`; reasoning models are more accurate than both
- D. Fine-tune `gpt-4o` to get both accuracy and low cost

---

**13.** Which statement about the semantic ranker in Azure AI Search is correct?

- A. It replaces vector search
- B. It re-ranks an already-retrieved result set and can return captions and answers
- C. It generates embeddings at query time
- D. It is available on the Free tier

---

**14.** An agent must call an existing internal REST API that already publishes an
OpenAPI 3.0 document. What is the least-effort correct integration?

- A. Write a Python function per endpoint and register each as a function tool
- B. Register the OpenAPI specified tool and point it at the document
- C. Put the API docs in the system prompt and let the model construct calls
- D. Use Code Interpreter to issue HTTP requests

---
---

## Answers

**1 — C.** This is the canonical "Foundry Tool, not LLM" decision. PII detection is
a solved, bounded task with a published accuracy profile, per-record pricing, and
deterministic output — all of which matter when the result must be auditable. A
and B work but cost more, vary run to run, and give you nothing to show an auditor.
D is worse still: fine-tuning teaches format, not a detection capability, and you
would be paying training cost to reproduce a service that already exists.

**2 — A and C.** SLMs trade knowledge and deep reasoning for cost, latency, and
deployability — including managed compute and genuinely on-device scenarios. B is
backwards; multi-step reasoning is precisely where SLMs are weakest. D is wrong:
classification is one of the tasks SLMs are *best* at, because the label space is
constrained.

**3 — B.** Rare alphanumeric identifiers carry almost no semantic signal, so their
embeddings sit close to everything else — you saw this directly in section 7 of the
lab. Hybrid search runs BM25 alongside the vector query and fuses the rankings, so
the literal token match surfaces. A retrieves more of the same wrong chunks. C does
not fix the underlying property of embeddings. D affects generation, not retrieval.

**4 — B.** Facts that change weekly must come from retrieval — a fine-tune is stale
the day after training and cannot cite. Output format is exactly what fine-tuning
(or, more cheaply, few-shot examples plus structured outputs) is for. A inverts the
two, which is the trap.

**5 — C.** Threads give conversation memory *within* a thread. Cross-session,
cross-conversation state is your responsibility, and the expected pattern is an
external store surfaced back to the agent as a tool. B does not work because
instructions are static and identical for every user. D confuses the transient
context window with durable storage.

**6 — B.** Managed compute is a dedicated deployment billed by VM-hour with no
scale-to-zero, so an idle endpoint costs the same as a busy one. That is the
decisive economic difference from serverless per-token deployments. A, C, and D are
all false — managed compute supports Entra ID, can have content safety applied, and
is not limited to one model per resource.

**7 — C.** Only retrieval gives you a source chunk to cite, because you retrieved
it and can hand back its identifier. A fine-tune absorbs information into weights
with no provenance. B just lets you paste more text without tracking where it came
from. D is unrelated and would make fabrication *more* likely.

**8 — A.** Indexers are built for supported Azure data sources on a schedule, with
change detection handling the daily delta. B and C both push you to a push-based
pipeline: custom chunking logic and non-standard auth are exactly what indexers do
not accommodate. D also favours push — indexers run on a schedule, so there is
inherent lag.

**9 — C.** High-volume, latency-sensitive classification is the worst possible fit:
reasoning models add seconds of latency and bill hidden reasoning tokens for a task
an SLM handles at a fraction of the cost. A, B, and D are all textbook reasoning-model
use cases.

**10 — B.** Content Understanding (and Document Intelligence beneath it) produces a
defined schema with per-field confidence — the confidence requirement rules
everything else out. A can read the PDF but returns free-form text with no
calibrated confidence. C extracts text but does not populate a business schema. D
is unrelated.

**11 — B and C.** Knowledge attachments provide facts: an Azure AI Search index for
private content, Bing grounding for the public web. A is a computation tool — it
runs code, it does not know anything. D is an action tool that calls an API; it may
*return* data, but it is categorised as a tool integration, not a knowledge store.

**12 — B.** With a human reviewer already in the loop and 4 million monthly calls,
the marginal 3 points of accuracy is bought at 16× inference cost. Compute the
review cost of the extra ~120,000 errors against the inference saving before
deciding — that arithmetic, not a rule of thumb, is the answer the exam wants.
A is dogma. C invents an unmeasured claim and ignores latency. D does not reduce
per-token cost and cannot be justified without evidence the base model's failures
are format-related.

**13 — B.** The semantic ranker is an L2 re-ranking stage applied to results already
returned by keyword and/or vector retrieval, and it can emit semantic captions and
extractive answers. It does not replace retrieval (A), does not create embeddings
(C — that is integrated vectorization), and requires Basic tier or above (D).

**14 — B.** The OpenAPI specified tool consumes the document directly and derives
the tool schema from it, so you write no wrapper code and the schema stays in sync
with the API. A works but is manual and drifts. C is unreliable — the model will
fabricate parameters. D bypasses every governance control the tool framework gives
you.

---

## Lab exercise solutions

**1. Justify a choice.** For the customer-facing widget, `gpt-4o-mini` is almost
always right: a p50 near 1 second leaves headroom under a 3-second p95, the error
mode is "mildly wrong answer" rather than financial loss, and at 80,000 calls a
month the cost difference against `gpt-4o` is typically two orders of magnitude —
cents versus tens of dollars. Quote your own `$/100k` column rather than these
figures.

For the nightly invoice reconciliation the answer flips, and the reason is that
*every input to the decision changed*. Latency is free because nothing is waiting.
Volume is 16× smaller. Errors have direct monetary cost. That combination justifies
`gpt-4o` or `o4-mini`, and Batch deployment cuts the per-token rate by roughly half
since a 24-hour completion window is acceptable. The general lesson: model choice
is a function of the *workload*, not of the model.

**2. Make the small model win.** Adding one worked example plus explicit steps
("compute remaining minutes per tier, sum, divide by monthly capacity, round up")
usually lifts `gpt-4o-mini` to the frontier model's accuracy on this task, because
the failure mode was procedural rather than a knowledge gap.

Cost is the interesting part. A few hundred extra prompt tokens per call is real,
but prompt tokens on `gpt-4o-mini` are roughly 17× cheaper than prompt tokens on
`gpt-4o` — so even a prompt that triples in length remains far cheaper than moving
up a tier. Prompt engineering wins here, and it wins by a wide enough margin that
you should always try it before upgrading the model. Cache the static prefix if the
deployment supports prompt caching and the gap widens further.

**3. Price the reasoning tax.**

```python
_, resp = call(cfg["MODEL_REASONING"])
u = resp.usage
r = u.completion_tokens_details.reasoning_tokens
print(f"completion={u.completion_tokens}  reasoning={r}  visible={u.completion_tokens - r}")
print(f"paid for but never seen: {r / u.completion_tokens:.0%}")
```

On this task you will typically see 90%+ of completion tokens being invisible
reasoning. On "What is 2+2?" the ratio stays high in *proportion* but collapses in
absolute terms, because the model spends far less effort. The practical lesson is
that reasoning-model cost scales with problem difficulty in a way that per-token
headline pricing does not reveal — you cannot forecast the bill from prompt length
alone, which is why you must measure before committing.

**4. Read the catalog for a constraint.**

```python
batch = sorted({e["name"] for e in catalog if "GlobalBatch" in e["skus"]})
print(f"{len(batch)} models support GlobalBatch in {cfg['AZURE_LOCATION']}:")
for name in batch:
    print(" ", name)
```

`GlobalBatch` satisfies the **bulk offline** scenario — asynchronous processing
within a 24-hour window at roughly half the per-token price. It does *not* satisfy
the data-residency scenario (that needs `Standard` or `DataZoneStandard`) or the
guaranteed-throughput scenario (that needs `ProvisionedManaged`). Note that the set
is usually smaller than the full model list: Batch availability is per model per
region, which is exactly the kind of constraint that turns an architecture diagram
into a redesign late in a project.

# 02.2 — RAG, workflows, and multistep reasoning

**Time:** 90–120 minutes · **Cost:** ⚠️ **Azure AI Search bills by the hour, not by
the query.** A Basic service is roughly $75/month; the Free tier is $0 but allows
only 3 indexes and 50 MB. Tokens for this lab are cents. **The expensive thing here
is forgetting the search service exists.** The lab deletes the index it creates, but
deleting an index does not stop the service billing — see [99_teardown](../../99_teardown/README.md).

By the end you will have:

- [ ] Chunked a document three different ways and measured what it costs you
- [ ] Built an Azure AI Search index with a vector field, a semantic configuration, and a scoring profile
- [ ] Retrieved with keyword, vector, hybrid, and hybrid+semantic-reranker, and compared results on the same query
- [ ] Grounded a generation with retrieved context and produced real, checkable citations
- [ ] Measured groundedness and retrieval quality with evaluators
- [ ] Built a multistep pipeline: query rewrite → retrieve → generate → self-check
- [ ] Contrasted naive RAG with the "On Your Data" pattern and with agentic retrieval

---

## Concepts

### What RAG actually is

Retrieval-augmented generation is not a product. It is a loop:

```
                     ┌── indexing (offline, batch) ──────────────────┐
  source docs ──► extract ──► chunk ──► embed ──► index
                     └───────────────────────────────────────────────┘

                     ┌── serving (online, per request) ──────────────┐
  user query ──► rewrite ──► retrieve ──► rerank ──► assemble prompt
                                                          │
                                                          ▼
                                          generate ──► cite ──► verify
                     └───────────────────────────────────────────────┘
```

Almost every RAG failure is a **retrieval** failure, not a generation failure. When
an answer is wrong, look at what came back from search before you touch the prompt.

### Chunking: the decision that determines everything downstream

| Strategy | How | Good for | Fails when |
|---|---|---|---|
| **Fixed-size** | N characters/tokens, fixed overlap | Uniform prose, quick baselines | Splits mid-sentence, orphans table rows |
| **Sentence / paragraph** | Split on natural boundaries, pack to a budget | Most documents | Very long paragraphs blow the budget |
| **Structural** | Split on markdown headings / document layout | Manuals, policies, contracts | Requires layout extraction first |
| **Semantic** | Split where embedding similarity drops | Mixed-topic documents | Expensive — embeds while chunking |
| **Parent–child** | Retrieve small chunks, feed the larger parent to the model | Precision + context together | Two-tier index; more plumbing |

Rules of thumb that survive contact with production:

- **512–1024 tokens** per chunk is the usual sweet spot for `text-embedding-3-*`.
- **10–20% overlap** stops answers being cut in half at a boundary.
- **Prepend the document title and section heading to every chunk.** A chunk that
  reads "It must be filed within 14 days" is useless. "Contoso Returns Policy →
  Disputes → It must be filed within 14 days" is retrievable *and* citable.
- Store the source URI and page/section on every chunk. Without that you cannot
  produce citations and you cannot audit an answer.

> **Exam note.** Bigger chunks are not safer. They dilute the embedding — one vector
> now averages several topics — which *lowers* retrieval precision while *raising*
> prompt cost. If a question offers "increase chunk size to improve relevance," it
> is a distractor.

### Retrieval modes

| Mode | Matches on | Strong at | Weak at |
|---|---|---|---|
| **Keyword (BM25)** | Exact terms, term frequency | Product codes, names, acronyms, error strings | Synonyms, paraphrase |
| **Vector** | Embedding cosine/HNSW distance | Paraphrase, synonyms, cross-lingual | Rare literals, exact IDs |
| **Hybrid** | Both, fused with **RRF** | Nearly everything — the default | Slightly more cost/latency |
| **Hybrid + semantic ranker** | RRF result re-scored by a Microsoft cross-encoder | Best relevance available; also produces captions and answers | Adds latency; billable above the free monthly allowance |

**Reciprocal Rank Fusion (RRF)** merges the two ranked lists by summing
$\frac{1}{k + \text{rank}}$ across lists rather than by comparing raw scores —
which matters because BM25 scores and cosine scores are not on the same scale.

The **semantic ranker** is a separate, second-stage model. It re-ranks the top ~50
results from the first stage, and it is where `@search.rerankerScore` (0–4) comes
from. Ordinary `@search.score` and reranker score are different numbers on different
scales; do not threshold one as if it were the other.

> **Exam note.** "Users search by part number and get nothing relevant" → pure
> vector search; add keyword or switch to hybrid. "Users phrase questions
> differently from the docs" → pure keyword; add vector. "Results are roughly right
> but the best answer is fourth" → add the semantic ranker.

### Vector index configuration

| Setting | Options | Trade-off |
|---|---|---|
| Algorithm | **HNSW** (default), **exhaustive KNN** | HNSW is approximate and fast; KNN is exact and scales badly |
| Metric | `cosine`, `dotProduct`, `euclidean` | `cosine` for OpenAI embeddings |
| `m` / `efConstruction` | HNSW graph parameters | Higher = better recall, larger index, slower build |
| `efSearch` | Query-time breadth | Higher = better recall, slower query |
| **Vectorizer** | Attach an embedding deployment to the index | Lets you query with *text* and have Search embed it — "integrated vectorization" |
| Compression | scalar / binary quantization | Big memory savings, small recall loss |

**Integrated vectorization** (index-attached vectorizer + a skillset that chunks and
embeds during indexing) means Search does the chunk-and-embed for you. Without it,
you embed in your own code — which is what this lab does first, so you can see the
mechanics before letting the platform hide them.

### Grounding and citation

Grounding is a prompt discipline, not a feature:

1. Give the model **only** the retrieved chunks as context.
2. Tell it explicitly: *answer only from the context; if the context does not
   contain the answer, say so.*
3. Give each chunk a stable label (`[1]`, `[2]`, …) and require inline citations.
4. Return the source metadata alongside the answer so a human can click through.
5. Verify: run groundedness over (query, response, context) before you trust it.

Steps 3–5 are what separate a demo from something auditable. The exam phrases this
as "provenance" and "attribution."

### Three architectures the exam contrasts

| Pattern | Who orchestrates | You control | Use when |
|---|---|---|---|
| **Custom RAG** (this lab) | Your code | Chunking, query rewriting, filters, prompt, citation format | You need control or unusual logic |
| **"On Your Data"** | Azure OpenAI service | Very little — you point it at an index and it retrieves, injects, and returns `citations` in the response | You want RAG in one API call |
| **Agentic retrieval / agent + search tool** | The model | Nothing per-turn — the model decides *whether*, *what*, and *how many times* to search | Multi-hop questions; conversational follow-ups |

"On Your Data" is the `extra_body={"data_sources": [...]}` parameter on a chat
completion (or the **Add your data** tab in the playground). One call in, grounded
answer plus a `context.citations` array out. You give up control of chunking and
prompt assembly in exchange.

**Agentic retrieval** goes further: rather than one query producing one search, the
model decomposes the question into subqueries, runs them (in parallel), and merges
the results — then may search again after reading. Azure AI Search exposes this as a
**knowledge agent / knowledge base** (preview), and the Foundry Agent Service
exposes the simpler form as the `AzureAISearchTool`, which unit 02.3 uses.

> **Exam note.** The tell for agentic retrieval is a **multi-hop or conversational**
> question — "how does that compare with last year's policy?" — where a single
> similarity search over the literal user text cannot possibly work, because the
> query depends on the previous turn.

### Multistep reasoning pipelines

The study guide asks for "workflows, tool-augmented flows, and multistep reasoning
pipelines." The building blocks, cheapest first:

| Step | What it fixes | Cost |
|---|---|---|
| **Query rewriting** | Pronouns and follow-ups ("what about theirs?") that retrieve nothing | 1 cheap call |
| **Query decomposition** | Multi-part questions that need several searches | 1 cheap call + N searches |
| **Filtering** | Retrieval that ignores tenant, date, or language | free — an OData `$filter` |
| **Reranking** | Right documents, wrong order | latency |
| **Self-check / reflection** | Ungrounded claims slipping through | 1 extra call |
| **Fallback** | "Not in the docs" answered as a hallucination | routing logic |

Each of these is a deliberate step you can trace, evaluate, and cost — which is the
real argument for a pipeline over one giant prompt.

---

## Portal walkthrough

### Step 1 — Confirm the Search service and your role

Azure AI Search is billed hourly. Check what you have before you create more.

1. **https://portal.azure.com** → resource group `rg-ai103-lab` → your **Search
   service**.
2. **Overview** notes the **Pricing tier**. Free allows 3 indexes / 50 MB and is
   enough for this lab. Basic and above bill continuously.
3. **Settings → Keys** → set **API Access control** to **Role-based access control**
   (or Both). This course uses Entra ID; with key-only auth,
   `DefaultAzureCredential` returns 403.
4. **Access control (IAM)** → **+ Add role assignment**. You need:

   | Role | Why |
   |---|---|
   | **Search Service Contributor** | Create and delete indexes (control plane) |
   | **Search Index Data Contributor** | Upload and delete documents |
   | **Search Index Data Reader** | Query |

   Assign all three to yourself. RBAC takes a few minutes to propagate.

If there is no Search service, `pwsh scripts/03_provision_labs.ps1` creates one on
the Free tier.

### Step 2 — Look at what "Import and vectorize data" does for you

You will build the index in code in the lab, but click through this wizard once —
it is the portal expression of everything the lab does by hand, and the exam
describes it.

1. Search service → **Search management → Indexes** … but instead choose
   **Overview → Import and vectorize data**.
2. Pick a data source (Blob Storage container `ai103-docs`).
3. **Vectorize your text**:

   | Field | Value | What it becomes |
   |---|---|---|
   | Kind | Azure OpenAI | a **vectorizer** on the index |
   | Azure OpenAI service | your Foundry resource | |
   | Model deployment | `text-embedding-3-small` | the embedding used at index *and* query time |
   | Authentication | System-assigned managed identity | keyless — the indexer's identity calls the model |

4. **Advanced settings** → tick **Enable semantic ranker**.
5. Review. Note the *four* objects the wizard creates:

   | Object | Role |
   |---|---|
   | **Data source** | Where the raw documents live |
   | **Skillset** | Split (chunk) + embed. This is where chunk size and overlap are configured. |
   | **Index** | Schema: fields, vector profile, semantic configuration |
   | **Indexer** | The scheduled job that ties the three together |

> **Exam note.** Those four objects and their relationship are heavily tested.
> "Where do you configure chunk size for integrated vectorization?" → in the
> **skillset**, on the `SplitSkill`. Not on the index and not on the indexer.

### Step 3 — Compare retrieval modes in Search Explorer

Search service → **Indexes** → your index → **Search explorer**, JSON view.

```jsonc
// keyword only
{ "search": "refund window for opened items", "top": 3 }

// semantic ranker on top of keyword
{ "search": "refund window for opened items", "top": 3,
  "queryType": "semantic", "semanticConfiguration": "default",
  "captions": "extractive", "answers": "extractive" }
```

Compare `@search.score` (BM25, unbounded) with `@search.rerankerScore` (0–4). They
are different scales measuring different things.

### Step 4 — "On Your Data" in the playground, in one click

1. **https://ai.azure.com** → **Playgrounds → Chat**.
2. **Add your data** → **Add a data source** → Azure AI Search → pick your index.
3. Choose the search type: **Keyword / Vector / Hybrid / Hybrid + semantic**.
4. Ask a question. Expand the citation chips under the answer.

That is the entire "On Your Data" pattern. Behind it, one chat completion carried
`extra_body={"data_sources": [{"type": "azure_search", ...}]}` and returned a
`context.citations` array. You wrote no retrieval code — and you also cannot change
the chunking, the filter logic, or the prompt.

<details>
<summary>"On Your Data" from Python</summary>

```python
resp = chat_client().chat.completions.create(
    model=cfg["MODEL_MINI"],
    messages=[{"role": "user", "content": "Can I refund an opened item?"}],
    extra_body={
        "data_sources": [{
            "type": "azure_search",
            "parameters": {
                "endpoint": cfg["AZURE_SEARCH_ENDPOINT"],
                "index_name": cfg["AZURE_SEARCH_INDEX"],
                "authentication": {"type": "system_assigned_managed_identity"},
                "query_type": "vector_semantic_hybrid",
                "embedding_dependency": {
                    "type": "deployment_name",
                    "deployment_name": cfg["MODEL_EMBEDDING"],
                },
                "in_scope": True,          # refuse questions the index cannot answer
                "strictness": 3,           # 1-5; higher = stricter relevance threshold
                "top_n_documents": 5,
            },
        }]
    },
)
print(resp.choices[0].message.content)
print(resp.choices[0].message.context["citations"])
```

`strictness` and `in_scope` are the two knobs that matter: `in_scope=True` makes the
service refuse off-topic questions, and raising `strictness` trades recall for
fewer weakly-grounded answers.
</details>

---

## Troubleshooting

**`403 Forbidden` from Azure AI Search with a valid `az login`**
Either the service is set to **API keys only** (change to RBAC in *Keys*), or you
lack a data-plane role. Control-plane Contributor does **not** grant document
access — you need *Search Index Data Contributor* / *Reader*.

**`The request is invalid. Details: parameters : The property 'vector' does not exist`**
An `azure-search-documents` version mismatch. Vector search needs `11.4.0+`, and
`VectorizableTextQuery` (query-by-text against an index vectorizer) needs a
`11.6.0b*` preview. `requirements.txt` pins a working version.

**Vector search returns nothing, keyword works**
Usually a dimension mismatch — the index field says 1536 but you indexed with
`text-embedding-3-large` (3072). Check `vector_search_dimensions` against the model.
Also confirm the field is `searchable=True` and has a `vector_search_profile_name`.

**`Semantic search is not enabled for this service`**
Enable it on the service (**Semantic ranker** blade). It is unavailable on the Free
tier in some regions; the lab falls back to plain hybrid.

**Answers cite the wrong chunk**
Your chunks lack identity. Prepend title + heading to the chunk text and store the
source URI as a retrievable field, then include the label in the prompt.

**The model answers from its own knowledge instead of the context**
The instruction is too soft. Use *"Answer ONLY from the numbered context. If the
answer is not there, reply exactly: NOT_IN_CONTEXT."* and set `temperature=0`. Then
verify with `GroundednessEvaluator` rather than trusting the instruction.

**Search costs appear even though you deleted the index**
Deleting an index does not delete the **service**. Only deleting the search service
(or the resource group) stops the hourly charge.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on chunking, retrieval modes, RRF, semantic
ranking, and the three RAG architectures.

## Next

[02.3 — Build agents by using Foundry](../03_build_agents/README.md)

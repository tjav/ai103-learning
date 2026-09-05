# 05.1 — Retrieval and grounding pipelines: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** You are using integrated vectorization. Where do you configure the chunk size
and overlap?

- A. On the index, in the vector search profile
- B. On the indexer, in `IndexingParameters.configuration`
- C. On the skillset, in the `SplitSkill`
- D. On the data source, in the container definition

---

**2.** An index has an `AzureOpenAIEmbeddingSkill` in its skillset but **no**
vectorizer on the index. What happens?

- A. Indexing fails immediately
- B. Documents index with vectors, but a `"kind": "text"` vector query fails
- C. Documents index without vectors, but text queries still work
- D. Nothing — the vectorizer is optional and does the same job

---

**3.** Users complain that searching for the part number `CX-4400` returns
plausible-looking controller documentation that never mentions `CX-4400`. The index
is configured for pure vector search. What is the minimal fix?

- A. Increase `k_nearest_neighbors`
- B. Switch to hybrid search so BM25 contributes to the ranking
- C. Enable the semantic ranker
- D. Re-embed with `text-embedding-3-large`

---

**4.** Which two statements about Reciprocal Rank Fusion in Azure AI Search are
correct? Choose two.

- A. It normalizes BM25 and cosine scores onto a common 0–1 scale before combining them
- B. It combines documents using only their **rank** in each result list
- C. It uses a constant $k = 60$ in the denominator
- D. It requires the semantic ranker to be enabled

---

**5.** You need to store a status code such as `SLA-GOLD` in a field and match it
exactly, never partially. Which configuration?

- A. `searchable=True` with the default `standard.lucene` analyzer
- B. `searchable=True` with `analyzer_name="keyword"`
- C. `facetable=True` only
- D. `retrievable=True` only

---

**6.** Your skillset uses `OcrSkill` and `ImageAnalysisSkill`. Indexer runs fail with
*"Skillset requires a Cognitive Services resource to be attached."* What is missing?

- A. A vectorizer on the index
- B. `imageAction: generateNormalizedImages` on the indexer
- C. A `cognitive_services_account` on the skillset
- D. A knowledge store projection

---

**7.** An OCR pipeline runs successfully, the enrichment tree contains
`/document/normalized_images/*/ocr_text`, and a merge skill produces
`/document/merged_content` — but questions about text printed in images still
return nothing. What is the most likely cause?

- A. The OCR skill's language code is wrong
- B. The split skill still reads `/document/content` instead of `/document/merged_content`
- C. The index has no semantic configuration
- D. `max_failed_items` is set to -1

---

**8.** What is the difference between index projections and a knowledge store?

- A. Index projections write to Azure Storage; a knowledge store writes to a search index
- B. Index projections write to a search index for retrieval; a knowledge store writes enrichments to Azure Storage for downstream analytics
- C. They are two names for the same feature
- D. Index projections are preview; knowledge stores are GA

---

**9.** A customer wants their training videos to be answerable by an agent. Which
architecture is correct?

- A. Point a blob indexer at the MP4 container and set `parsing_mode: "default"`
- B. Enable `imageAction: generateNormalizedImages` so the indexer extracts frames
- C. Extract transcript, keyframes, and chapter segments first with a multimodal analyzer, then index those segments with timestamps
- D. Store the videos as base64 in a `searchable` field

---

**10.** Which is **not** true of a custom `WebApiSkill`?

- A. Search POSTs a `values` array of records containing `recordId` and `data`
- B. Your endpoint must echo `recordId` back in its response
- C. It can authenticate to your API with Entra ID via `authResourceId`
- D. It runs after the index is populated, as a post-processing step

---

**11.** Your search service's identity has *Search Index Data Contributor*. The
indexer fails with 403 reading blobs. What do you assign, and to whom?

- A. *Storage Blob Data Reader* on the storage account, to the search service's managed identity
- B. *Storage Blob Data Reader* on the storage account, to your user account
- C. *Search Service Contributor* on the search service, to the storage account
- D. *Contributor* on the resource group, to the indexer

---

**12.** A result set from a **hybrid** query shows `@search.score` values around
0.032. A colleague proposes rejecting anything below 0.7 as irrelevant. What is
wrong with that?

- A. Nothing — 0.7 is the standard relevance threshold
- B. Hybrid scores are RRF scores derived from ranks, roughly $1/(60+\text{rank})$ per ranker, so they are never near 0.7
- C. The threshold should be applied to `@search.rerankerScore`, which is also 0–1
- D. Scores below 1.0 always indicate a dimension mismatch

---

**13.** Which two things does the `AzureAISearchTool` on a Foundry agent need?
Choose two.

- A. The search service admin key
- B. The id of a project **connection** to the search service
- C. The index name
- D. A skillset name

---

**14.** A user asks an agent: *"And how does that compare to the opened-item
policy?"* Single-shot retrieval over that literal sentence returns nothing useful.
Which capability addresses this directly?

- A. Increasing `top_k` on the search tool
- B. Agentic retrieval — the service decomposes the conversation into multiple subqueries, runs them in parallel, and merges the results
- C. Enabling `facetable` on the content field
- D. Switching the analyzer to `keyword`

---

## Answers

**1 — C.** Chunk size and overlap are `maximum_page_length` and
`page_overlap_length` on the `SplitSkill`, inside the **skillset**.
**A** is where the HNSW algorithm and vectorizer live — dimensions and metric, not
chunking. **B** is where parsing mode, `dataToExtract`, and `imageAction` live.
**D** only knows where the data is and how to authenticate.

**2 — B.** The embedding *skill* vectorises documents at index time; the *vectorizer*
on the index vectorises the query at query time. They are separate objects and you
need both for end-to-end integrated vectorization. With only the skill, documents
have vectors (so **C** is wrong) and indexing succeeds (**A** wrong), but you must
supply raw floats in `VectorizedQuery` yourself. **D** is exactly the confusion the
question tests.

**3 — B.** Embeddings generalise; they are poor at rare literal tokens they were
never trained on. Hybrid brings BM25 back, which excels at exactly this.
**A** returns more of the same wrong neighbours. **C** re-ranks the stage-one
results — if the correct document was never retrieved, there is nothing to promote.
**D** changes the embedding quality slightly but does not solve the class of
problem, and forces a full reindex plus a dimension change everywhere.

**4 — B and C.** RRF deliberately discards the raw scores because BM25 and cosine
are not comparable, and sums $1/(k + \text{rank})$ with $k = 60$.
**A** describes score normalisation, which is what RRF exists to avoid. **D** is
false — hybrid works without the semantic ranker; the ranker is an optional second
stage on top.

**5 — B.** The `keyword` analyzer emits the whole field value as a single token, so
`SLA-GOLD` matches `SLA-GOLD` and not `GOLD`.
**A** lowercases and splits on the hyphen, so `GOLD` alone would match. **C** gives
you facet counts but not matching. **D** only controls whether the field is returned.

**6 — C.** OCR, Image Analysis, Document Intelligence Layout, and the Language
skills are billable AI enrichments and require the skillset to carry a
`cognitive_services_account` — by key or, preferably, `AIServicesAccountIdentity`
with *Cognitive Services User* granted to the search service's identity.
**B** is a real and necessary setting but produces a different error (no images in
the tree at all). **A** and **D** are unrelated.

**7 — B.** The merge skill's output is a *new* node in the enrichment tree. Nothing
downstream reads it until you repoint the consumer. The OCR text exists but never
reaches the index. This is the classic multimodal-pipeline mistake.
**A** would degrade OCR accuracy, not eliminate it. **C** affects ranking, not
content. **D** only controls error tolerance.

**8 — B.** Index projections send enriched chunks to another **search index**, which
is how one document becomes N retrievable chunk documents. A knowledge store writes
tables/objects/files to **Azure Storage** for Power BI and analytics. A skillset can
have both. **A** reverses them; **C** and **D** are false.

**9 — C.** Azure AI Search does not crack audio or video. You transcribe and segment
first — a Content Understanding video analyzer or Video Indexer — then index the
resulting text segments with `start`/`end` as filterable fields so citations can
deep-link.
**A** will skip or fail on the media files. **B** extracts images from *documents*,
not frames from video. **D** is not searchable text and would blow the index size.

**10 — D.** The Web API skill runs **during** enrichment, in the skillset, before
the index is written — that is the whole point. A, B, and C are all accurate
descriptions of the contract.

**11 — A.** The **indexer** reads the blobs using the *search service's* managed
identity, not yours. Your own roles govern what you can do from the SDK.
**B** fixes nothing for the indexer. **C** and **D** are nonsense directions —
roles are assigned to identities, on resources.

**12 — B.** Hybrid returns RRF scores built from ranks, so values cluster near
$1/61 \approx 0.016$ per contributing ranker. A threshold of 0.7 rejects everything.
**C** is right that the reranker score is the thresholdable one, but wrong about its
range — it is **0 to 4**, not 0–1. **A** and **D** are false.

**13 — B and C.** The tool takes `index_connection_id` (a Foundry project connection
to the search service) and `index_name`, plus optional `query_type` and `top_k`.
**A** is exactly what the connection exists to avoid. **D** is an indexing-time
object the query path knows nothing about.

**14 — B.** The question's meaning lives in the previous turn, so no single
similarity search over the literal text can succeed. Agentic retrieval (knowledge
bases / knowledge agents, preview) plans subqueries from the whole conversation,
executes them in parallel, and merges.
**A** returns more weakly-relevant chunks. **C** and **D** are indexing concerns
irrelevant to conversational reference resolution. Query rewriting in your own code
is a valid cheaper alternative, but it is not among the options.

---

## Lab exercise solutions

**1. Make the image searchable.**

```python
# a) repoint the split skill at the merged text
split.inputs = [InputFieldMappingEntry(name="text", source="/document/merged_content")]
ocr_skillset.skills = [ocr, image_analysis, merge, split, embedding]
indexer_client.create_or_update_skillset(ocr_skillset)

# b) repoint the indexer at the OCR skillset
indexer.skillset_name = OCR_SKILLSET_NAME
indexer_client.create_or_update_indexer(indexer)

# c) reset clears the high-water mark so already-seen blobs are reprocessed
indexer_client.reset_indexer(INDEXER_NAME)
indexer_client.run_indexer(INDEXER_NAME)
# ... poll get_indexer_status as in section 7 ...

# d) prove it
for r in sc.search(search_text="depot maintenance window", top=3,
                   select=["title", "chunk"]):
    print(r["title"], "|", " ".join(r["chunk"].split())[:90])
# expect a hit whose title is service-notice.png
```

Without the `reset_indexer` call the run is a no-op: the blobs have not changed
since the last successful run, so change detection skips them all. This catches
almost everyone the first time.

**2. Break the vectorizer deliberately.**

The indexer fails per-document with a message of the form *"The vector field
'chunk_vector' has dimension 3072 but the vector provided has dimension 1536"* (the
exact wording varies with API version). The three places that must agree:

| Place | Setting |
|---|---|
| Skillset | `AzureOpenAIEmbeddingSkill.dimensions` (and the deployment's model) |
| Index field | `vector_search_dimensions` |
| Index vectorizer | `AzureOpenAIVectorizerParameters.deployment_name` / `model_name` |

A fourth, subtler one: if you ever push documents client-side as the fallback cell
does, the model in `embed()` must match too. `text-embedding-3-small` is 1536,
`text-embedding-3-large` is 3072, `ada-002` is 1536.

**3. Measure RRF.**

```python
K = 60
def ranks(results):
    return {r["chunk_id"]: i + 1 for i, r in enumerate(results)}

kw  = ranks(list(sc.search(search_text="restocking fee", top=10, select=SELECT)))
vec = ranks(list(sc.search(
        search_text=None, top=10, select=SELECT,
        vector_queries=[VectorizableTextQuery(
            text="restocking fee", k_nearest_neighbors=10, fields="chunk_vector")])))

scores = {}
for d in set(kw) | set(vec):
    scores[d] = (1 / (K + kw[d]) if d in kw else 0) + (1 / (K + vec[d]) if d in vec else 0)

for d, s in sorted(scores.items(), key=lambda kv: -kv[1])[:5]:
    print(f"{s:.5f}  kw={kw.get(d, '-'):>3}  vec={vec.get(d, '-'):>3}  {d}")
```

A document that appears in the hybrid top-3 but in neither individual top-3 is the
signature of RRF working: being consistently *mid-ranked* by both rankers beats
being top-ranked by one and absent from the other. Your hand-computed ordering
should match Search's closely; small divergences come from the vector list being
truncated at `k` before fusion, so a document ranked 11th by the vector ranker
contributes 0 in your calculation and may also contribute 0 in Search's.

**4. Scope the agent.**

You change the **tool**, not the index and not the skillset — the index already has
`doc_type` as a filterable field, which is precisely why it was made filterable:

```python
tool = AzureAISearchTool(
    index_connection_id=search_conn.id,
    index_name=INDEX_NAME,
    query_type=AzureAISearchQueryType.VECTOR_SEMANTIC_HYBRID,
    top_k=5,
    filter="doc_type eq '.md'",
)
```

Recreate the agent with the new `tool.resources`. The SLA content lives only in
`sla-gold.pdf`, so it is now invisible and the agent returns `NOT_IN_DOCUMENTS`.

The general lesson: **retrieval scoping is a query-time concern** as long as you
made the scoping field `filterable` at index-design time. If you did not, you are
rebuilding the index — which is why the field-attribute decisions in section 5 are
worth taking seriously rather than turning everything on or everything off.

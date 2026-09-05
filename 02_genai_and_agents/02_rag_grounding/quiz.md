# 02.2 — RAG and grounding: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** Users search a product knowledge base by part number (`CX-4400`) and get
irrelevant results, although questions phrased in natural language work well. What
is the most likely cause?

- A. The semantic ranker is disabled
- B. Retrieval is vector-only, and rare literal tokens embed poorly
- C. Chunks are too small
- D. The embedding model has too few dimensions

---

**2.** The same index answers paraphrased questions badly but exact phrases well.
What should you add?

- A. A scoring profile that boosts the title field
- B. A larger chunk size
- C. A vector field and vector queries
- D. An OData filter

---

**3.** A hybrid query in Azure AI Search combines a BM25 ranked list and a vector
ranked list. How are they merged?

- A. The scores are averaged
- B. The higher raw score wins
- C. Reciprocal Rank Fusion over the ranks, not the raw scores
- D. The vector list is used and BM25 only breaks ties

---

**4.** What is `@search.rerankerScore`?

- A. The BM25 score normalised to 0–1
- B. A 0–4 relevance score from the semantic ranker's cross-encoder second stage
- C. Cosine similarity between query and document vectors
- D. The RRF fusion score

---

**5.** Using integrated vectorization, where do you configure chunk size and
overlap?

- A. On the index, in the vector search profile
- B. On the indexer schedule
- C. On the skillset, in the `SplitSkill`
- D. On the data source connection

---

**6.** Vector search returns zero results while keyword search on the same index
works fine. What should you check first?

- A. That the semantic ranker is enabled
- B. That `vector_search_dimensions` matches the embedding model's output size
- C. That the index has a scoring profile
- D. That the service tier supports vector search

---

**7.** Which two are genuine reasons **not** to simply increase chunk size to
"include more context"? Choose two.

- A. A larger chunk's embedding averages several topics and retrieves less precisely
- B. Larger chunks increase prompt tokens and therefore cost per answer
- C. Azure AI Search rejects documents over 1,000 characters
- D. Vector fields cannot exceed 512 dimensions

---

**8.** A RAG answer is fluent and cites chunk [2], but chunk [2] does not contain
the claim. Which evaluator pair best diagnoses whether the problem is retrieval or
generation?

- A. `FluencyEvaluator` and `CoherenceEvaluator`
- B. `RetrievalEvaluator` and `GroundednessEvaluator`
- C. `F1ScoreEvaluator` and `BleuScoreEvaluator`
- D. `ViolenceEvaluator` and `HateUnfairnessEvaluator`

---

**9.** In a chat application, the user asks "how long is the CX-4400 warranty?" then
"and how fast do I have to report a fault?". The second question retrieves nothing
useful. What is the cheapest correct fix?

- A. Increase `top_n_documents`
- B. Switch from hybrid to pure vector search
- C. Add a query-rewriting step that turns the follow-up into a standalone query
- D. Increase the chunk overlap

---

**10.** Which statement about the "On Your Data" pattern
(`extra_body={"data_sources": [...]}`) is correct?

- A. It requires you to embed the query yourself before calling
- B. The service retrieves, injects context, and returns a `context.citations` array
- C. It only supports keyword search
- D. It replaces the need for an Azure AI Search index

---

**11.** In "On Your Data", what does setting `in_scope: true` do?

- A. Limits results to the current user's documents
- B. Restricts the model to answering only questions the index can support
- C. Limits the number of retrieved documents
- D. Enables the semantic ranker

---

**12.** A user asks: "Is my controller still covered, and who signs off a refund
above the Tier 1 limit?" The corpus has this information in two different documents.
Which approach is most likely to answer correctly?

- A. One hybrid search on the literal question, top 3
- B. Increase the chunk size so both policies land in one chunk
- C. Decompose into subqueries, retrieve for each, merge and dedupe the context
- D. Switch to keyword-only search

---

**13.** You have deleted the index your lab created, but the Azure bill still shows
Azure AI Search charges. Why?

- A. Deleted indexes are retained for 30 days and billed
- B. Search bills for the provisioned **service** by the hour, independent of indexes
- C. The semantic ranker has a minimum monthly charge
- D. Vector storage is billed separately from the service

---

**14.** Which two are true of the **agentic retrieval** pattern (an agent with a
search tool, or a knowledge agent)? Choose two.

- A. The model decides whether and how many times to search
- B. Every user turn triggers exactly one search
- C. It handles multi-hop and conversational follow-ups without you writing a rewrite step
- D. It removes the need for chunking

---

**15.** Which is **not** a valid reason to prepend the document title and section
heading to each chunk's embedded text?

- A. It makes an otherwise ambiguous chunk retrievable
- B. It gives the model enough identity to produce a useful citation
- C. It disambiguates chunks that share wording across documents
- D. It reduces the number of prompt tokens per answer

---
---

## Answers

**1 — B.** Embeddings are poor at rare literal tokens: `CX-4400` is close in vector
space to every other alphanumeric part code. BM25 handles exact terms precisely,
which is exactly why hybrid is the default recommendation. The semantic ranker (A)
reorders candidates but cannot surface a document the first stage never retrieved.
Chunk size and dimensionality are unrelated to this symptom.

**2 — C.** Paraphrase is the vector's home ground — "get my money back" and "refund"
are far apart lexically and close semantically. Scoring profiles and filters change
weighting and scope, not matching semantics; larger chunks make the problem worse.

**3 — C.** RRF sums $\frac{1}{k + \text{rank}}$ across the ranked lists. It has to
work on ranks because BM25 scores are unbounded and cosine similarities are in a
different range entirely — averaging them (A) would be meaningless. The resulting
`@search.score` from a hybrid query is an RRF score, typically 0.01–0.03, and is not
comparable to a BM25 score.

**4 — B.** The semantic ranker is a second-stage cross-encoder that re-scores roughly
the top 50 first-stage results on a 0–4 scale, and also produces extractive captions
and answers. It is a different number from `@search.score` and must not be
thresholded as though it were.

**5 — C.** In integrated vectorization the **skillset** owns the enrichment
pipeline: a `SplitSkill` (chunk size, overlap, split mode) feeding an
`AzureOpenAIEmbeddingSkill`. The index defines the schema, the indexer schedules the
run, and the data source says where documents live. This four-object split is
heavily tested.

**6 — B.** A dimension mismatch — an index field declared 1536 while documents were
embedded with `text-embedding-3-large` (3072), or vice versa — is by far the most
common cause. Keyword search is unaffected because it never touches the vector
field, which is exactly the diagnostic signature.

**7 — A and B.** A single embedding is one point in space; the more topics a chunk
covers, the less any query matches it strongly. And every retrieved chunk lands in
the prompt, so chunk size multiplies directly into cost and latency. C and D are
invented limits.

**8 — B.** `RetrievalEvaluator` scores whether the right material was retrieved and
well-ordered; `GroundednessEvaluator` scores whether the answer is supported by that
material. Low retrieval + high groundedness = faithful to bad context, so fix the
index. High retrieval + low groundedness = the model ignored good context, so fix
the prompt. Fluency and coherence say nothing about correctness, and safety
evaluators are a different concern entirely.

**9 — C.** The follow-up contains no retrievable signal — "a fault" matches many
documents and "how fast" matches none. Rewriting it into "How quickly must a
CX-4400 warranty claim be filed after a fault is discovered?" fixes it with one
cheap model call. Retrieving more documents, changing search mode, or increasing
overlap all leave the query itself broken.

**10 — B.** "On Your Data" moves retrieval into the Azure OpenAI service: one chat
completion in, grounded answer plus `context.citations` out. It still requires a
real index (D is wrong), supports keyword, vector, hybrid, and semantic hybrid via
`query_type` (C is wrong), and embeds the query for you via `embedding_dependency`
(A is wrong).

**11 — B.** `in_scope: true` constrains the model to the indexed corpus, so
off-topic questions get a refusal rather than a general-knowledge answer. Per-user
document filtering is done with a `filter` expression, `top_n_documents` limits
result count, and semantic ranking is selected through `query_type`.

**12 — C.** Two facts in two documents means one similarity search over the combined
question will surface a blend of both and rank neither well. Decomposition retrieves
each independently and merges the union. B is the classic wrong instinct — you
cannot chunk two separate policy documents together, and larger chunks retrieve
worse. A under-retrieves and D loses the paraphrase.

**13 — B.** Azure AI Search bills for the provisioned service — replicas and
partitions — by the hour, whether it holds zero indexes or fifty. The only ways to
stop the charge are deleting the service or deleting its resource group. This is the
single most common surprise cost in the course.

**14 — A and C.** Agentic retrieval hands the decision to the model: it may search
zero times, once, or several times with reformulated subqueries, and it naturally
resolves conversational references because it sees the whole thread. It does not
eliminate chunking (D) — the index still has to exist. B describes naive RAG.

**15 — D.** Prepending context *increases* tokens slightly. You do it because it
raises retrieval precision and makes citation possible — the cost is real and worth
paying. A, B, and C are all genuine benefits.

---

## Lab exercise solutions

**1. Chunk size sweep.** Typical shape: 200 characters fragments sentences and
retrieval drops because no single chunk holds a complete rule; 1500 characters
retrieves the right *document* but the chunk contains several policies at once, so
`retrieval` scores fall and `prompt_tokens` roughly triples; ~600 is best on both.
The key observation is that `prompt_tokens` scales linearly with chunk size while
retrieval quality is a hump — bigger is not safer, it is just more expensive with a
worse embedding.

**2. Strip the context prefix.** Retrieval degrades noticeably on the
cross-document questions, because chunks like *"must be filed within 14 days"* no
longer contain the words "CX-4400" or "warranty" and lose both the lexical and the
semantic hook. Citation still technically works — the `title` and `uri` fields are
still stored and retrievable — but the *model* can no longer tell which policy a
chunk belongs to when several look alike, so it attributes claims to the wrong `[n]`.
That is the argument for putting the prefix in the **embedded content**, not just in
metadata.

**3. Filtered retrieval.**

```python
vq = VectorizedQuery(vector=embed(q)[0], k_nearest_neighbors=6, fields="content_vector")
hits = sc.search(search_text=q, vector_queries=[vq], top=3,
                 filter="doc_id eq 'warranty-cx4400'",
                 select=["title", "section", "content", "uri", "id"])
```

The returns question now retrieves only warranty chunks, and the grounded answer
correctly returns `NOT_IN_CONTEXT` — the filter made the answer genuinely
unavailable and the refusal path did its job. This is exactly how **multi-tenancy**
and **document-level security trimming** are implemented: store a tenant or
security-group field on each chunk and append a filter derived from the caller's
identity. Filtering is free (it runs inside the search engine) and, crucially, it
cannot be prompt-injected away — unlike an instruction that says "only discuss
documents belonging to this customer."

**4. Strictness.** At `strictness=1` the service accepts weakly relevant chunks, so
you get an answer to almost anything — with a higher fabrication rate and citations
that only loosely support the claim. At `strictness=5` marginal chunks are discarded
and the model returns "The requested information is not available in the retrieved
data" far more often. You are configuring the **precision/recall trade-off of the
grounding filter**: low strictness favours answering, high strictness favours being
right or silent. Regulated domains want high; a general FAQ bot usually wants 3.

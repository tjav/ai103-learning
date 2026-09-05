# 05.1 — Build retrieval and grounding pipelines

**Time:** 120–150 minutes · **Cost:** ⚠️ **Azure AI Search bills by the hour.** A
**Basic** service is billed continuously from the moment it is created — roughly
$0.10/hour, about $75/month — whether or not you ever issue a query. The Free tier
is $0 but caps you at 3 indexes, 50 MB, no indexer scheduling on some features, and
no semantic ranker in every region. Everything else in this unit (embeddings, a few
hundred OCR pages, one agent run) costs cents. **The lab deletes every index,
indexer, skillset, and data source it creates — but deleting those objects does not
stop the hourly service charge.** Only deleting the search service does. See
[99_teardown](../../99_teardown/README.md).

Unit [02.2 — RAG, workflows, and multistep reasoning](../../02_genai_and_agents/02_rag_grounding/README.md)
already built RAG *by hand*: you chunked in Python, embedded in Python, and pushed
documents with `upload_documents`. Read that unit first if you have not — this one
does not repeat it.

This unit is about the other half: the **indexer pipeline**, where Azure AI Search
does the crawling, cracking, OCR, chunking, embedding, and projection for you on a
schedule, and about wiring the result into an agent.

By the end you will have:

- [ ] Built the full pipeline object model — **data source → indexer → skillset → index → vectorizer** — in code, and understood which object owns which decision
- [ ] Designed an index schema deliberately, choosing `searchable` / `filterable` / `sortable` / `facetable` / `retrievable` / `key` / `stored` per field, and picked an analyzer
- [ ] Enabled **integrated vectorization** so you can query with text and never embed in your own code again
- [ ] Enriched with built-in skills — split, embedding, OCR, image analysis — and seen where a **custom Web API skill** plugs in
- [ ] Projected chunks into a chunk-level index with **index projections**, and shaped enrichments into a **knowledge store**
- [ ] Ingested documents, images, audio, and video, and understood which of those Search cracks natively and which need a different service first
- [ ] Compared BM25, vector, hybrid (RRF), and hybrid + semantic ranker on the same queries
- [ ] Attached the index to a Foundry agent as an `AzureAISearchTool`, and seen where **agentic retrieval** goes further
- [ ] Deleted every object you created

---

## Concepts

### The pipeline object model

This is the single most-tested structure in the information-extraction domain. Five
objects, each owning exactly one decision:

```
        Blob container / SQL / Cosmos DB
                    │
        ┌───────────▼────────────┐
        │  Data source           │  WHERE the content is + how to authenticate
        │  (SearchIndexerData    │  + change/deletion detection policy
        │   SourceConnection)    │
        └───────────┬────────────┘
                    │
        ┌───────────▼────────────┐
        │  Indexer               │  THE JOB. Schedule, batch size, error
        │  (SearchIndexer)       │  tolerance, field mappings, parsing mode.
        │                        │  Ties data source + skillset + index together.
        └─────┬─────────────┬────┘
              │             │
   ┌──────────▼────────┐    │
   │  Skillset         │    │   WHAT HAPPENS to the content in flight:
   │ (SearchIndexer    │    │   crack, OCR, split (chunk), embed, classify,
   │  Skillset)        │    │   call your own API. Also owns index projections
   │                   │    │   and the knowledge store.
   └──────────┬────────┘    │
              │             │
        ┌─────▼─────────────▼────┐
        │  Index                 │  THE SCHEMA. Fields and their attributes,
        │  (SearchIndex)         │  analyzers, vector profiles, semantic config,
        │      └── Vectorizer    │  scoring profiles. The vectorizer lives here
        └────────────────────────┘  and embeds the *query* at query time.
```

Fix these four sentences in your head:

| Question | Answer | Why people get it wrong |
|---|---|---|
| Where do I set **chunk size and overlap**? | The **skillset**, on `SplitSkill` (`maximum_page_length`, `page_overlap_length`) | People guess "the index" or "the indexer" |
| Where do I set the **schedule**? | The **indexer** | |
| Where do I set **which embedding model embeds the query**? | The **index**, on the **vectorizer** in `VectorSearch` | The *skillset's* embedding skill embeds documents at index time. The *index's* vectorizer embeds the query. They are two different objects and **must use the same model and dimensions.** |
| Where do I set **credentials for the source data**? | The **data source** | |

> **Exam note.** "Integrated vectorization" is not one setting. It is the
> combination of an `AzureOpenAIEmbeddingSkill` in the skillset (documents) plus an
> `AzureOpenAIVectorizer` on the index (queries). Enable only the first and you can
> index but must embed queries yourself. Enable only the second and your vector
> field stays empty.

### Index schema design: the field attributes

Every field carries six independent booleans. They are not free — each one you turn
on costs index size, and some cannot be changed after creation without a rebuild.

| Attribute | Enables | Cost / catch |
|---|---|---|
| `key` | The document identity. Exactly one per index, `Edm.String` only. | Must be URL-safe. Blob paths need base64 encoding (`base64EncodeKeys`). |
| `searchable` | Full-text search — the field is tokenized and inverted-indexed | Biggest index-size cost. Only for text you actually want matched. |
| `filterable` | `$filter` OData expressions (`eq`, `ge`, `search.in`) | Stored verbatim, **not** analyzed — `filterable` on a text field matches the *whole* string. |
| `sortable` | `$orderby` | Meaningless on a collection field. |
| `facetable` | Facet counts for navigation UI | Wasteful on high-cardinality fields like free text. |
| `retrievable` | The field comes back in results | Turning it **off** hides it from callers but it is still searched/filtered. |
| `stored` (vector fields) | Keeps the raw vector on disk | Set `stored=False` on vector fields you never return — often **halves** storage. Cannot be changed later. |

> **Exam note.** A vector field must be `searchable=True` **and** carry a
> `vector_search_profile_name`. A field that is `filterable` but not `searchable`
> cannot be found by `search=`; a field that is `searchable` but not `filterable`
> cannot be used in `$filter`. Questions frequently hinge on exactly this.

### Analyzers

An analyzer turns text into the tokens that go into the inverted index. The default
is `standard.lucene`. The two you must recognise:

| Analyzer | Behaviour | Use for |
|---|---|---|
| `standard.lucene` | Lowercases, splits on word boundaries | Default English-ish prose |
| `keyword` | Treats the **entire field value as one token** | SKUs, IDs, status codes — anything that must match exactly |
| `<lang>.microsoft` (e.g. `fr.microsoft`) | Language-aware lemmatisation | Non-English content — better recall than Lucene equivalents |
| Custom (`CustomAnalyzer`) | Your own tokenizer + token filters (e.g. `pattern` tokenizer, `asciifolding`) | Part numbers with punctuation, accent-insensitive search |

You can also set `search_analyzer_name` and `index_analyzer_name` separately, which
is how you build prefix/n-gram search: n-gram at index time, keyword at query time.

> **Exam note.** Analyzer choice is **immutable** on an existing field. Changing it
> means creating a new field or a new index and reindexing.

### Retrieval modes — the short version

Unit 02.2 covers this in depth. The exam-critical summary:

| Mode | Ranking function | Wins on | Loses on |
|---|---|---|---|
| **Keyword / BM25** | Term frequency × inverse document frequency, length-normalised. `@search.score`, unbounded. | Exact literals: part numbers, error codes, surnames, acronyms | Synonyms, paraphrase, other languages |
| **Vector** | Cosine distance over embeddings via HNSW. `@search.score` here is a *similarity*, 0–1. | Paraphrase, intent, cross-lingual, "the thing that does X" | Rare literal tokens the embedding never saw; exact IDs |
| **Hybrid** | Both lists fused with **RRF** | Almost everything. The default recommendation. | Marginally more latency and cost |
| **Hybrid + semantic ranker** | RRF output re-scored by a Microsoft cross-encoder. `@search.rerankerScore`, **0–4**. | Best relevance available; also emits captions and extractive answers | Latency; billed above the free monthly allowance; top-50 only |

**Reciprocal Rank Fusion** exists because BM25 scores and cosine scores are not
comparable numbers. Rather than normalising them, RRF throws the scores away and
uses only the **ranks**:

$$\text{RRF}(d) = \sum_{r \in \text{rankers}} \frac{1}{k + \text{rank}_r(d)}$$

with $k = 60$ in Azure AI Search. A document ranked #1 by either ranker gets
$1/61$; being #1 in both gets $2/61$. That is why hybrid is so robust: a document
only has to be good according to *one* ranker to survive into the fused top-N, and
being good according to both promotes it.

The **semantic ranker** is a genuinely different, second-stage model. It takes the
top ~50 documents from stage one, reads the query and the document text together
(a cross-encoder, not two independent embeddings), and re-scores. Because it reads
both together it can tell that "return within 14 days" answers "how long do I have
to send it back" — something no similarity metric reliably does. It also gives you:

- `@search.rerankerScore` — 0 to 4. **Not** on the same scale as `@search.score`.
- **Captions** (`captions="extractive"`) — the passage of the document that matched,
  with highlights. Perfect as the citation snippet in a RAG answer.
- **Answers** (`answers="extractive"`) — a span the ranker believes directly answers
  the question, with its own confidence.

> **Exam note.** Symptom → fix mapping:
> "part numbers return nothing" → you are on pure vector; add keyword/hybrid.
> "users phrase questions differently from the docs" → pure keyword; add vector.
> "the right doc is in the results but ranked fourth" → add the semantic ranker.
> "I need the snippet that matched, for a citation" → semantic captions.

### Enrichment: the skills catalogue

Skills are the units of work in a skillset. Each has a `context` (the JSON path it
runs over — `/document`, `/document/pages/*`, `/document/normalized_images/*`),
`inputs` mapped from the enriched-document tree, and `outputs` written back into it.
This tree is the **enrichment cache** shape; skill I/O is entirely path-based, which
is why a mistyped `source` path silently produces nothing rather than an error.

| Skill | `@odata.type` | Does | Needs AI Services attached? |
|---|---|---|---|
| **Split** | `Text.SplitSkill` | Chunks text by pages/sentences, with overlap | No |
| **Azure OpenAI embedding** | `Text.AzureOpenAIEmbeddingSkill` | Vectorises chunks | No — has its own endpoint + auth |
| **OCR** | `Vision.OcrSkill` | Text from images, incl. handwriting, with orientation detection | **Yes** |
| **Image analysis** | `Vision.ImageAnalysisSkill` | Tags, captions, objects, brands, faces | **Yes** |
| **Document extraction** | `Util.DocumentExtractionSkill` | Cracks a file into text + `normalized_images` | **Yes** for image extraction |
| **Document Intelligence layout** | `Util.DocumentIntelligenceLayoutSkill` | Layout-aware **markdown** with heading structure — the good chunking input | **Yes** |
| **Merge** | `Text.MergeSkill` | Re-inserts OCR text back into the document text at the right offsets | No |
| **Entity recognition / key phrase / language / sentiment / PII** | `Text.*` | Classic Language-service enrichment | **Yes** |
| **Shaper** | `Util.ShaperSkill` | Builds a nested object out of flat enrichments — mostly for the knowledge store | No |
| **Conditional** | `Util.ConditionalSkill` | Branch / default values | No |
| **Custom Web API** | `Custom.WebApiSkill` | **Calls your HTTPS endpoint** with a batch of records | No |
| **Azure OpenAI / GenAI prompt** | `Custom.AmlSkill`, `Util.GenAIPromptSkill` | LLM-in-the-pipeline: verbalise an image, classify, summarise | No |

**"Needs AI Services attached"** means the skillset must carry a
`cognitive_services_account` pointing at a multi-service Foundry/AI Services
resource, because those skills consume billable AI enrichments. You can attach it
by key (`CognitiveServicesAccountKey`) or, preferred, by the search service's
**managed identity** (`AIServicesAccountIdentity`) — which requires the search
service's identity to hold **Cognitive Services User** on the Foundry resource.
Without an attachment you get 20 free enrichments per day and then failures.

**The custom Web API skill contract** is worth memorising because it is the answer
to every "how do I put my own logic in the pipeline" question:

```jsonc
// Search POSTs this to your endpoint:
{ "values": [ { "recordId": "0", "data": { "text": "..." } } ] }
// Your endpoint must return exactly this:
{ "values": [ { "recordId": "0",
                "data":    { "myOutput": "..." },
                "errors":  [], "warnings": [] } ] }
```

Batch size, timeout (max 230 s), HTTP headers, and `authResourceId` (for Entra ID
auth to your own API) are configured on the skill. `recordId` must be echoed back
or Search cannot correlate the result.

### Index projections vs the knowledge store

Both take enriched output somewhere other than the primary index. They are
different and the exam contrasts them.

| | **Index projections** | **Knowledge store** |
|---|---|---|
| Destination | Another **search index** | Azure **Storage** — tables and/or blobs |
| Purpose | One-to-many: turn one document into N **chunk documents** so vector search operates at chunk granularity | Downstream analytics, Power BI, data science over the enrichments |
| Configured on | Skillset (`index_projection`) | Skillset (`knowledge_store`) |
| Key setting | `projection_mode` — `skipIndexingParentDocuments` is what you almost always want | `TableProjection` / `ObjectProjection` / `FileProjection` |
| Requires | A `parent_key_field_name` in the target index | A storage connection |

Index projections are how integrated vectorization produces a chunk-level index:
`SplitSkill` emits `/document/pages/*`, the embedding skill runs with that context,
and the projection selector maps `/document/pages/*` to one index document each,
carrying the parent id along for citation.

### Ingesting documents, images, audio, and video

The study guide bullet says "documents, images, audio, and video". Search does **not**
handle all four the same way, and pretending it does is the trap:

| Content | How it gets into an index |
|---|---|
| **PDF, Office, HTML, JSON, CSV, plain text** | Native. The indexer *cracks* the file: `parsing_mode` = `default`, `json`, `jsonArray`, `delimitedText`, `markdown`. Text lands in `/document/content`, metadata in `/document/metadata_*`. |
| **Images** (standalone, or embedded in PDFs) | Set `imageAction` = `generateNormalizedImages` in the indexer's `configuration`. Images appear at `/document/normalized_images/*`. Then **OCR skill** for text-in-image, **Image Analysis skill** or a **GenAI prompt/verbalisation** skill for a describable caption you can embed. |
| **Audio** | **Not cracked by Search.** Transcribe first — Azure AI Speech (unit [04.2](../../04_text_analysis/02_speech_solutions/README.md)) or a Content Understanding audio analyzer — then index the transcript with timestamps as ordinary text. |
| **Video** | **Not cracked by Search.** Extract transcript + keyframes + chapter segments first (Content Understanding video analyzer, or Azure AI Video Indexer), then index those segments with `start`/`end` timestamps as filterable fields so a citation can deep-link into the video. |

> **Exam note.** If a question says "index our training videos so agents can answer
> from them," the correct architecture is **extract to text/segments with a
> multimodal analyzer, then index the extraction** — not "point an indexer at the
> MP4 container." Search indexers will skip or fail on media files.

The newer `Util.ContentUnderstandingSkill` (preview) collapses several of these
steps: it cracks the file, chunks semantically, and can verbalise images, in one
skill. Unit [05.2](../02_document_extraction/README.md) covers Content Understanding
properly.

### Connecting retrieval to workflows and agent tools

Three levels, cheapest and least flexible first:

| Level | What it is | You control |
|---|---|---|
| **"On Your Data"** | `extra_body={"data_sources":[{"type":"azure_search", ...}]}` on one chat completion | Almost nothing. Query type, strictness, `in_scope`, top-N. |
| **`AzureAISearchTool` on a Foundry agent** | You register the project's **Search connection** + index name as a tool. The model decides when to call it and with what query. | Index, query type, top-K. Citations arrive as URL-citation annotations on the message. |
| **Agentic retrieval (knowledge bases / knowledge agents)** | Search itself runs an LLM that **decomposes** the conversation into multiple subqueries, executes them in parallel, merges and re-ranks, and can synthesise an answer with references | Knowledge sources, output mode (`extractiveData` vs `answerSynthesis`), reranker thresholds |

The `AzureAISearchTool` needs a **connection** in the Foundry project pointing at
the search service — the agent uses the *connection id*, not an endpoint and key.
That indirection is the point: rotating credentials never touches agent code.

**Agentic retrieval** is Search's own answer to multi-turn RAG. Instead of one
query → one search, you send the whole conversation to a *knowledge base*, and the
service plans subqueries, runs them, and returns either merged grounding data or a
synthesised, cited answer. It is billed as query planning tokens plus the usual
search. Naming has churned: the original preview called them **knowledge agents**
with a `retrieve` operation (`azure-search-documents 11.6.0b*`); the current API
calls them **knowledge bases** built over **knowledge sources**. Expect either
term in exam wording — the concept is identical.

> **Exam note.** The tell for agentic retrieval is a question whose meaning depends
> on prior turns ("how does that compare to last year's policy?") or that needs
> several independent lookups to answer. A single similarity search over the
> literal user text cannot work there.

---

## Portal walkthrough

### Step 1 — Check the service, tier, and your roles

1. **https://portal.azure.com** → `rg-ai103-lab` → your **Search service**.
2. **Overview** → note **Pricing tier**. Free = 3 indexes / 50 MB / no indexer
   schedule. Basic and above = **hourly billing, starting now**.
3. **Settings → Keys** → **API Access control** must be **Role-based access
   control** or **Both**. Key-only means `DefaultAzureCredential` gets 403.
4. **Settings → Identity** → turn **System assigned** to **On**. The indexer needs
   an identity to reach Storage and the Foundry embedding model without keys.
5. **Access control (IAM)** on the search service — assign **yourself**:

   | Role | Grants |
   |---|---|
   | Search Service Contributor | Create/delete indexes, indexers, skillsets, data sources |
   | Search Index Data Contributor | Upload and delete documents |
   | Search Index Data Reader | Query |

6. Now grant the **search service's identity** access to the things it must read:

   | Assign on | Role | So the indexer can |
   |---|---|---|
   | Storage account | **Storage Blob Data Reader** | Read the source blobs |
   | Foundry resource | **Cognitive Services OpenAI User** | Call the embedding deployment |
   | Foundry resource | **Cognitive Services User** | Run OCR / Image Analysis skills |

   This is the keyless indexer pattern and it is exam material. RBAC takes a few
   minutes to propagate; a fresh indexer run may 403 before it settles.

7. **Settings → Semantic ranker** → set to **Free** (1,000 queries/month) or
   **Standard**. If the blade says unavailable, your tier or region does not offer
   it and the lab falls back to plain hybrid.

### Step 2 — Run "Import and vectorize data" once, and read what it built

This wizard is the portal expression of the entire lab. Do it once by hand.

1. Search service → **Overview** → **Import and vectorize data**.
2. **Connect to your data** → **Azure Blob Storage** → container `ai103-docs`.

   | Field | Value | Note |
   |---|---|---|
   | Parsing mode | Default | `markdown`, `json`, `delimitedText` are the alternatives |
   | Enable deletion tracking | on (soft-delete via blob metadata) | How the index learns a source doc is gone |
   | Authenticate using managed identity | **on** | Uses the identity you enabled in step 1 |

3. **Vectorize your text**:

   | Field | Value | Becomes |
   |---|---|---|
   | Kind | Azure OpenAI | |
   | Service | your Foundry resource | |
   | Model deployment | `text-embedding-3-small` | The `AzureOpenAIEmbeddingSkill` **and** the index `AzureOpenAIVectorizer` |
   | Authentication type | System-assigned managed identity | keyless |

4. **Vectorize and enrich your images** — tick it. Choose **Image verbalization**
   (an LLM writes a description, which is then embedded) or **Image embeddings**
   (a multimodal embedding model). Note that this switches the wizard to a
   multimodal pipeline and adds `imageAction: generateNormalizedImages`.
5. **Advanced settings** → **Enable semantic ranker**, and set the indexer
   **schedule** (once / hourly / daily).
6. **Review + create** → note the **prefix** it assigns, then look at the four
   objects it created under **Search management**:

   | Object | Open it and look for |
   |---|---|
   | **Data sources** | Container, folder path, credentials type, deletion detection policy |
   | **Skillsets** | `SplitSkill` (chunk size!), `AzureOpenAIEmbeddingSkill`, `indexProjections` |
   | **Indexes** | `chunk`, `chunk_id`, `parent_id`, `text_vector`; the vectorizer under **vectorProfiles** |
   | **Indexers** | Schedule, `fieldMappings`, `outputFieldMappings`, run history |

7. **Indexers** → your indexer → **Execution history**. Every run shows items
   processed, items failed, and per-document error detail. This is where you debug
   ingestion, and "monitor data ingestion quality and index health" (unit 01.3) is
   graded on knowing it exists.

### Step 3 — Compare retrieval modes in Search explorer

**Indexes** → your index → **Search explorer** → **JSON view**:

```jsonc
// 1. keyword only
{ "search": "CX-4400", "top": 3 }

// 2. vector only, using the index vectorizer (no client-side embedding)
{ "count": true, "top": 3,
  "vectorQueries": [ { "kind": "text", "text": "how long do I have to send it back",
                       "fields": "text_vector", "k": 3 } ] }

// 3. hybrid — search text AND a vector query in the same request
{ "search": "how long do I have to send it back", "top": 3,
  "vectorQueries": [ { "kind": "text", "text": "how long do I have to send it back",
                       "fields": "text_vector", "k": 10 } ] }

// 4. hybrid + semantic ranker
{ "search": "how long do I have to send it back", "top": 3,
  "vectorQueries": [ { "kind": "text", "text": "how long do I have to send it back",
                       "fields": "text_vector", "k": 50 } ],
  "queryType": "semantic", "semanticConfiguration": "default",
  "captions": "extractive", "answers": "extractive" }
```

`"kind": "text"` is only legal because the index has a vectorizer. Without one you
must send `"kind": "vector"` and supply the raw floats.

### Step 4 — Connect the index to a Foundry agent

1. **https://ai.azure.com** → your project → **Management center → Connected
   resources → + New connection → Azure AI Search**. Pick the service,
   authentication **Microsoft Entra ID**. Name it — the agent tool needs the
   connection, not a key.
2. **Build → Agents → + New agent**. Give it instructions that forbid answering
   from prior knowledge.
3. **Knowledge → + Add → Azure AI Search** → pick the connection, the index, and:

   | Setting | Meaning |
   |---|---|
   | Search type | keyword / semantic / vector / **vector_semantic_hybrid** |
   | Top K | How many chunks are handed to the model |
   | Index field mapping | Which field is the content and which is the title/URL for citations |

4. Ask it a question in the playground and expand the citation. The agent's answer
   carries `url_citation` annotations pointing back at index documents.

<details>
<summary>CLI / script alternative</summary>

```powershell
# Create the search service, storage, and the cross-service role assignments
pwsh scripts/03_provision_labs.ps1

# Confirm the search service identity and its role assignments
$svc = az search service show -n $env:AZURE_SEARCH_SERVICE -g $env:AZURE_RESOURCE_GROUP `
        --query "{tier:sku.name, identity:identity.principalId}" -o json
$svc

# Grant the search identity read access to blobs, keylessly
$principal = az search service show -n $env:AZURE_SEARCH_SERVICE -g $env:AZURE_RESOURCE_GROUP `
        --query identity.principalId -o tsv
$storage   = az storage account show -n $env:AZURE_STORAGE_ACCOUNT -g $env:AZURE_RESOURCE_GROUP `
        --query id -o tsv
az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal `
        --role "Storage Blob Data Reader" --scope $storage

# Kick an indexer and watch it
az rest --method post --uri "$env:AZURE_SEARCH_ENDPOINT/indexers/ai103-indexer/run?api-version=2024-07-01" `
        --resource "https://search.azure.com"
```

The lab does all of this from Python so you can see the object definitions
themselves, which is what the exam asks about.
</details>

---

## Troubleshooting

**`403 Forbidden` calling Search with a valid `az login`**
Either the service is set to **API keys only** (change to RBAC under *Keys*), or you
hold Contributor but not a **data-plane** role. Control-plane roles do not grant
document access — you need *Search Index Data Contributor* / *Reader*.

**Indexer status *Success* but `0` documents indexed**
Almost always a path problem in the skillset, not a permissions problem. A skill
`source` path that does not exist produces no output and no error. Check
`/document/pages/*` vs `/document/chunks/*` against the `targetName` you actually
set on the split skill's output.

**`Skill executed but no output was produced` / `Could not execute skill because a skill input was invalid`**
The `context` of the skill and the `source` of its input disagree. If the split
skill's context is `/document` and its output `targetName` is `pages`, the embedding
skill's context must be `/document/pages/*` and its input source `/document/pages/*`.

**`Skillset requires a Cognitive Services resource to be attached`**
You used OCR, Image Analysis, Document Intelligence Layout, or a Language skill
without `cognitive_services_account`. Attach the Foundry resource — by identity
(`AIServicesAccountIdentity`) if the search service has **Cognitive Services User**
on it, otherwise by key.

**Indexer 403 to Storage or to the embedding deployment**
The **search service's** identity, not yours, does the reading. Give it *Storage
Blob Data Reader* on the storage account and *Cognitive Services OpenAI User* on the
Foundry resource. New assignments can take 5–10 minutes.

**`The vector field 'x' has dimension 1536 but the vector provided has dimension 3072`**
The skillset embeds with one model and the index declares another. `text-embedding-3-small`
is 1536, `text-embedding-3-large` is 3072. The embedding skill, the vectorizer, and
`vector_search_dimensions` must all agree.

**`"kind": "text"` vector query returns `Vectorizer is not configured`**
The index has no `AzureOpenAIVectorizer` in its `VectorSearch.vectorizers`, so
Search cannot embed your query text. Either add one or send raw vectors.

**Documents with images index no image text**
`imageAction` defaults to `none`. Set it to `generateNormalizedImages` in the
indexer's `IndexingParameters.configuration`, otherwise `/document/normalized_images`
never exists and the OCR skill has nothing to run on.

**Blob key errors: `Document key cannot be an empty or blank string` / invalid characters**
Blob URLs contain characters illegal in a document key. Set
`configuration = {"dataToExtract": "contentAndMetadata"}` plus
`FieldMapping(source_field_name="metadata_storage_path", target_field_name="id", mapping_function=FieldMappingFunction(name="base64Encode"))`.

**Semantic ranker returns `rerankerScore` of 0 for everything**
The semantic configuration prioritises fields that are empty, or the content field
is not `searchable`. Check `SemanticPrioritizedFields`.

**Search cost appears after you deleted the index**
Deleting indexes, indexers, skillsets, and data sources removes storage and stops
enrichment, but the **service** is what bills hourly. Delete the service (or the
resource group) to stop it.

---

## Check yourself

[quiz.md](quiz.md) — 14 questions on the pipeline object model, field attributes,
skills, projections, retrieval modes, and agent wiring.

## Next

[05.2 — Extract content from documents](../02_document_extraction/README.md) — where
the content that feeds this pipeline actually comes from: Document Intelligence,
Content Understanding, and how to choose between them.

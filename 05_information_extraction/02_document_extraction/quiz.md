# 05.2 — Extract content from documents: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** A finance team processes 40,000 supplier invoices a month. Every extracted
total must be traceable to a location on the page, and values below a confidence
bar go to a human reviewer. Which service?

- A. A multimodal LLM with a JSON response format
- B. Azure AI Document Intelligence `prebuilt-invoice`
- C. Content Understanding with a `generate` field for the total
- D. Azure AI Search with an OCR skill

---

**2.** You need the text of a scanned document and nothing else — no tables, no
structure, at the lowest possible cost per page. Which model?

- A. `prebuilt-read`
- B. `prebuilt-layout`
- C. `prebuilt-invoice`
- D. A custom neural model

---

**3.** RAG answers over technical PDFs are consistently wrong whenever the answer
lives in a table. What is the correct fix?

- A. Increase chunk size from 512 to 2048 tokens
- B. Switch to a larger embedding model
- C. Extract with `prebuilt-layout` using markdown output, then chunk on headings
- D. Enable the semantic ranker on the index

---

**4.** In a Content Understanding analyzer, which generation method produces a value
that is **not** literally present in the content?

- A. `extract`
- B. `classify`
- C. `generate`
- D. `infer`

---

**5.** Which two properties does a Document Intelligence field carry that a
multimodal LLM's JSON output does not? Choose two.

- A. `confidence`
- B. `content`
- C. `boundingRegions`
- D. A field name

---

**6.** You must train a custom extraction model for a supplier form that arrives in
six visually different layouts. Which build mode, and why?

- A. Template — it needs only 5 samples
- B. Neural — it learns structure rather than position, so it generalises across layouts
- C. Composed — it merges the six into one model automatically
- D. Classification — layout variance is a classification problem

---

**7.** A Content Understanding analyzer field is defined as
`{"type": "string", "method": "classify", "enum": ["low","medium","high"]}`.
What does the `enum` do?

- A. Documents the allowed values for humans only
- B. Constrains the model to choose one of the listed categories
- C. Trains a classifier on those three labels
- D. Filters out documents that do not match

---

**8.** A `POST .../analyzers/{id}:analyze` returns `202 Accepted` and an empty body.
What do you do next?

- A. Retry the POST until it returns 200
- B. Read the `Operation-Location` response header and poll that URL until `status` is `Succeeded`
- C. Call `GET /analyzers/{id}` to read the result
- D. Treat 202 as a failure and check your credentials

---

**9.** Which is **not** a reason to prefer Content Understanding over Document
Intelligence?

- A. You need to process audio and video as well as documents
- B. You want to define the output schema in JSON rather than by labelling samples
- C. You need per-field bounding polygons for a regulatory audit
- D. You want summaries and classifications alongside extracted values

---

**10.** In a heading-aware chunking scheme, why prepend the heading path to each
chunk's text?

- A. It improves the embedding model's throughput
- B. It makes the chunk self-describing, so it is both retrievable and citable
- C. It is required by Azure AI Search's index projections
- D. It reduces the token cost of the chunk

---

**11.** Content Understanding analyze calls fail with
*"No default model deployment configured."* What is wrong?

- A. Your Entra role is insufficient
- B. No chat and embedding deployments are registered as resource defaults for Content Understanding
- C. The analyzer schema has an invalid field type
- D. The blob URL is not reachable

---

**12.** You receive mixed batches of loan applications, invoices, and statements in
one folder, and each type needs different fields extracted. Which architecture?

- A. One custom extraction model trained on all three types
- B. Classify first, then route each document to the extraction model for its type
- C. `prebuilt-layout` for everything, then regex
- D. Three separate indexers in Azure AI Search

---

**13.** A `prebuilt-invoice` result gives `InvoiceTotal` a confidence of 0.99, but
the value is the subtotal, not the total. What does this tell you?

- A. Confidence values above 0.95 are unreliable
- B. Confidence measures the model's certainty about its reading of the page, not about your business semantics
- C. The document is corrupted
- D. You should switch to a neural custom model

---

**14.** Which two are true about Content Understanding's relationship to the Foundry
resource? Choose two.

- A. It requires its own dedicated Document Intelligence resource
- B. It shares the Foundry (AI Services) endpoint and RBAC
- C. *Cognitive Services User* is sufficient to create and run analyzers
- D. It only supports API-key authentication

---

**15.** A customer wants an agent that answers from 400 hours of recorded training
video. Which pipeline is correct?

- A. Upload the MP4 files to blob storage and point an Azure AI Search indexer at them
- B. Run a Content Understanding video analyzer to produce transcript and chapter segments with timestamps, index those segments, and give the agent a search tool
- C. Pass each video file directly to a multimodal chat model at query time
- D. Extract keyframes with `imageAction: generateNormalizedImages` and OCR them

---

## Answers

**1 — B.** "Traceable to a location on the page" plus "confidence bar" plus "human
reviewer" is Document Intelligence's exact value proposition, and invoices are a
prebuilt type so there is nothing to train.
**A** returns no confidence and no coordinates — disqualifying for audit. **C** uses
`generate` for a value that is literally printed on the page, throwing away the
grounding you need. **D** gives you OCR text, not typed fields with confidence.

**2 — A.** `prebuilt-read` is the OCR-only model and the cheapest per page.
**B** costs roughly ten times as much for structure you explicitly do not want.
**C** is more expensive still and returns invoice-specific fields. **D** requires
training and is more expensive again.

**3 — C.** Flat text destroys tables — rows interleave and the chunk becomes noise.
Layout-to-markdown preserves the table as a markdown table and gives you heading
boundaries to chunk on.
**A** makes it worse: a bigger chunk dilutes the embedding across more topics and
raises prompt cost. **B** cannot recover structure that extraction never produced.
**D** re-ranks what was retrieved; if the chunk is garbled, promoting it does not
help.

**4 — C.** `generate` writes a value — a summary, an inference, a normalised form —
that the content does not contain.
**A** pulls literal text and returns spans. **B** picks from an enumerated set.
**D** is not a Content Understanding method.

**5 — A and C.** `confidence` and `boundingRegions` are the grounding properties an
LLM cannot produce. (`spans` is a third.)
**B** is text the LLM also returns. **D** is trivially present in any JSON output.

**6 — B.** Neural models learn structural relationships rather than fixed positions,
which is precisely what you need across visual variants.
**A** is positional and breaks on the second layout. **C** composes *already-trained*
models — a valid option if you train one per layout, but it does not solve the
training question being asked. **D** is a different problem: classification routes
documents, it does not extract fields.

**7 — B.** `enum` constrains the model's output to the listed categories at
inference time. No training occurs — that is the point of Content Understanding
versus a custom Document Intelligence classifier.
**A** understates it; **C** describes a trained classifier; **D** describes a filter,
which is not what a field schema does.

**8 — B.** Analyzer creation and analysis are both long-running operations. 202 plus
`Operation-Location` is the success path, and `Running` / `NotStarted` are normal
intermediate statuses.
**A** re-submits work and doubles your bill. **C** returns the analyzer definition,
not the result. **D** misreads 202 as an error.

**9 — C.** Per-field bounding polygons are a **Document Intelligence** strength, so
that is a reason to prefer DI, not CU. A, B, and D are all genuine reasons to prefer
Content Understanding.

**10 — B.** "It must be filed within 14 days" is unretrievable and uncitable.
"Returns Policy > Disputes > It must be filed within 14 days" is both — the heading
words enter the embedding *and* the BM25 index, and the path is the citation.
**A** and **D** are backwards — it adds tokens. **C** is false; projections do not
require it.

**11 — B.** Analyzers run on generative models and must have a chat and an embedding
deployment registered as resource **defaults**, via Studio Settings or
`PATCH /contentunderstanding/defaults`.
**A** produces 401/403, **C** fails at analyzer creation with a schema error, and
**D** produces a fetch error naming the URL.

**12 — B.** Classify-then-extract is the standard mixed-batch architecture, in both
Document Intelligence (custom classification model → custom extraction models) and
Content Understanding (a classifier analyzer whose categories carry `analyzerId` for
routing).
**A** produces a model that is mediocre at all three. **C** is brittle and returns
no confidence. **D** is an indexing concern, not an extraction one.

**13 — B.** Confidence is the model's certainty that it read those pixels correctly.
Reading the wrong number perfectly scores near 1.0. Semantic correctness is caught
by validation rules (does subtotal + tax equal total?), not by confidence.
**A** is the wrong lesson to draw. **C** and **D** do not follow.

**14 — B and C.** Content Understanding is part of Foundry Tools, lives on the
AI Services resource, shares its endpoint and RBAC, and works with Entra ID —
*Cognitive Services User* is enough.
**A** is false, and in fact a standalone Document Intelligence resource is one of
the common reasons the endpoint 404s. **D** is false; key auth exists but is not
required.

**15 — B.** Azure AI Search does not crack media. You extract first — transcript,
chapters, keyframe descriptions, with `start`/`end` timestamps — then index the
extraction, keeping the timestamps as filterable fields so citations can deep-link
into the video.
**A** will skip or fail on the MP4s. **C** is impossibly expensive at 400 hours and
has no retrieval step. **D** extracts images from *documents*, not frames from
video, and OCR of a slide misses everything the presenter said.

---

## Lab exercise solutions

**1. Cost the ladder.**

```python
import time

for model in ["prebuilt-read", "prebuilt-layout"]:
    t0 = time.perf_counter()
    r = analyze(model, PDF_BYTES)
    print(f"{model:<18} {time.perf_counter() - t0:5.1f}s  "
          f"pages={len(r.pages or [])} tables={len(r.tables or [])} "
          f"paragraphs={len(r.paragraphs or [])} styles={len(r.styles or [])}")
```

Layout is slower and roughly ten times the per-page price. It is **not** worth it
when:

- The documents are unstructured prose — a book, a transcript, an email export.
  There is no table to recover and no heading hierarchy to exploit.
- You only need a keyword index, not RAG chunks. BM25 does not care about structure.
- You are doing a first-pass triage over a huge corpus and will re-run layout only
  on the documents that survive the filter. Cheap-then-expensive is a legitimate
  and under-used pattern.

**2. Break `extract`.**

With `method: "extract"` the field comes back null (or empty with no spans): the
model correctly reports that the value is not in the document.

With `method: "generate"` you will typically get a plausible name, or a confident
statement that no project manager is listed — the model is being asked to *produce*
a value, so producing one is compliant behaviour.

The second is more dangerous because **the failure is silent and the output is
well-formed**. A null is obviously missing data and a downstream system will notice.
A fabricated name flows into your database indistinguishable from a real one, and
carries no spans to reveal that it came from nowhere. The rule: **if a value must be
defensible, it must be `extract`.**

**3. Confidence-driven routing.**

```python
def route(doc, thresholds, default=0.80):
    fields, low = {}, []
    for name, field in (doc.fields or {}).items():
        value = next((v for k, v in field.items() if k.startswith("value")),
                     field.get("content"))
        conf = field.get("confidence")
        fields[name] = value
        if conf is not None and conf < thresholds.get(name, default):
            low.append((name, value, conf))
    return ("review", low) if low else ("auto", fields)


thresholds = {
    "InvoiceTotal": 0.95,   # a wrong number here is a wrong payment
    "SubTotal":     0.95,
    "TotalTax":     0.95,
    "InvoiceId":    0.90,   # a wrong id breaks reconciliation, recoverable
    "VendorName":   0.70,   # near-misses are usually harmless and human-obvious
}

for doc in invoice.documents or []:
    verdict, payload = route(doc, thresholds)
    print(verdict, payload if verdict == "review" else f"{len(payload)} fields accepted")
```

The gap is justified by **cost of being wrong**, not by how hard the field is to
read. A misread total moves money. A misread vendor name produces a support ticket.
Set thresholds by consequence, then validate the chosen thresholds against a
labelled sample and measure how much genuine work you are pushing into the review
queue — an over-strict threshold on a common field can make automation pointless.

Add semantic validation on top, because confidence will not catch it:

```python
assert abs(subtotal + tax - total) < 0.01, "arithmetic does not reconcile"
```

**4. Close the loop with 05.1.**

```python
import uuid
from ai103 import search_index_client, search_client, embed
from azure.search.documents.indexes.models import (
    SearchIndex, SearchField, SearchFieldDataType,
    VectorSearch, VectorSearchProfile, HnswAlgorithmConfiguration,
)

NAME = "ai103-52-chunks"
search_index_client().create_or_update_index(SearchIndex(
    name=NAME,
    fields=[
        SearchField(name="id", type=SearchFieldDataType.String, key=True),
        SearchField(name="heading_path", type=SearchFieldDataType.String,
                    searchable=True, filterable=True),
        SearchField(name="source_uri", type=SearchFieldDataType.String),  # retrievable
        SearchField(name="text", type=SearchFieldDataType.String, searchable=True),
        SearchField(name="vector",
                    type=SearchFieldDataType.Collection(SearchFieldDataType.Single),
                    searchable=True, vector_search_dimensions=1536,
                    vector_search_profile_name="p"),
    ],
    vector_search=VectorSearch(
        algorithms=[HnswAlgorithmConfiguration(name="a")],
        profiles=[VectorSearchProfile(name="p", algorithm_configuration_name="a")],
    ),
))

docs = [{"id": uuid.uuid4().hex, **c} for c in chunks]
for d, v in zip(docs, embed([d["text"] for d in docs])):
    d["vector"] = v
search_client(NAME).upload_documents(docs)

for r in search_client(NAME).search(search_text="what happens if I pay late", top=2,
                                    select=["heading_path", "source_uri", "text"]):
    print(r["heading_path"], "|", r["source_uri"])
    print("  ", " ".join(r["text"].split())[:120])

search_index_client().delete_index(NAME)   # and remember: the SERVICE still bills
```

The retrieved chunk should carry a heading path such as `INVOICE > Payment Terms`,
which is exactly what you show the user as the citation. This is the whole
information-extraction domain in one pipeline: **extract with layout → markdown →
structural chunks carrying provenance → index → retrieve → cite.**

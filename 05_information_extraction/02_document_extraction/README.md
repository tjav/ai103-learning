# 05.2 — Extract content from documents

**Time:** 90–120 minutes · **Cost:** a few dollars at most. Document Intelligence
`prebuilt-read` and `prebuilt-layout` are billed **per page** (roughly $1.50 and
$10 per 1,000 pages respectively; prebuilt-invoice and custom models cost more).
Content Understanding is billed per content unit and additionally consumes tokens
on the generative model it is bound to. Nothing here bills hourly, so there is no
idle cost — but a careless loop over a 500-page PDF with `prebuilt-layout` is a
real charge. The lab uses documents it generates itself, a handful of pages total,
and deletes every analyzer it creates.

Unit [05.1](../01_retrieval_and_grounding/README.md) built the pipeline that indexes
content. This unit is about where clean content comes from in the first place, and
about the choice the exam cares most about: **Document Intelligence vs Content
Understanding vs just asking a multimodal LLM.**

By the end you will have:

- [ ] Run `prebuilt-read`, `prebuilt-layout`, and `prebuilt-invoice` and seen exactly what each adds over the last
- [ ] Produced **markdown** from layout analysis and used its heading structure to chunk for RAG — the single highest-leverage trick in document RAG
- [ ] Read a `boundingRegions` / `spans` / `confidence` triple and understood why it is the difference between an extraction and a *grounded* extraction
- [ ] Understood how custom extraction and custom classification models are built and when they are worth it
- [ ] Defined a **Content Understanding analyzer** with a field schema, using all three generation methods — `extract`, `classify`, `generate`
- [ ] Run analyzers across modalities — document, image, audio, video — from one service with one shape of response
- [ ] Written a decision table for Document Intelligence vs Content Understanding vs a multimodal LLM, and be able to defend it
- [ ] Deleted every analyzer you created

---

## Concepts

### The three services that all "read documents"

They overlap enough to be confusing and differ enough that picking wrong is
expensive.

| | **Document Intelligence** | **Content Understanding** | **Multimodal LLM (gpt-4o / gpt-5 class)** |
|---|---|---|---|
| Input | Documents and images | Documents, **images, audio, video** | Text and images (audio in the realtime/audio models) |
| Output | Rigid, typed JSON: pages, lines, words, tables, selection marks, key-value pairs, typed fields | Your **field schema** — typed JSON — plus markdown | Whatever you prompt for |
| Grounding | Bounding polygons + spans + **per-field confidence** on every value | Spans and source references on extracted fields | **None.** No coordinates, no confidence, no provenance |
| Determinism | High. Same input → same output | Moderate — generative under the hood | Low |
| Customisation | Train a custom model on 5+ labelled samples | Define a schema in JSON; no labelling required | Prompt |
| Per-page cost | Low | Medium (plus model tokens) | Highest at scale |
| Fails at | Anything not document-shaped | Very high volume where per-unit cost dominates | Auditability; long documents; consistent structure |

The decision rule, in one line each:

- **A fixed, high-volume, auditable document type** — invoices, claims forms, IDs,
  bank statements — where you must be able to point at *where on the page* a value
  came from and how confident the model was: **Document Intelligence**.
- **Heterogeneous content, several modalities, a schema that is easier to describe
  than to label, and an output shaped for an agent to consume:**
  **Content Understanding**.
- **One-off, exploratory, or genuinely open-ended reasoning over an image or a short
  document, where you do not need provenance:** the **multimodal model**.

> **Exam note.** The tell for Document Intelligence is the words *confidence*,
> *bounding box*, *human review threshold*, or *audit*. The tell for Content
> Understanding is *multimodal*, *schema*, *markdown for RAG*, or *agent-ready*.
> The tell for "just use the model" is *ad hoc* or *no structure required*. If a
> question mentions **regulatory audit of extracted values**, an LLM is always
> wrong — it cannot tell you where the number was on the page.

### Document Intelligence: the model ladder

Each prebuilt model is a superset of the one before it, at a higher price.

| Model | Adds | Use when |
|---|---|---|
| **`prebuilt-read`** | OCR: pages, lines, words, per-word confidence, language, handwriting detection | You want the text and nothing else. Cheapest. |
| **`prebuilt-layout`** | Everything in read **plus tables, selection marks (checkboxes), paragraph roles (title / sectionHeading / pageHeader / footnote), figures**, and **markdown output** | You need structure — and for RAG this is the one you want |
| **`prebuilt-document`** *(3.x; folded into layout in 4.x)* | Generic key-value pairs from any form | Legacy generic extraction |
| **`prebuilt-invoice` / `-receipt` / `-idDocument` / `-businessCard` / `-tax.us.*` / `-healthInsuranceCard.us`** | **Typed, named fields** — `InvoiceTotal`, `VendorName`, `Items[]` — each with a value, a confidence, and a bounding region | The document is one of these well-known types |
| **Custom extraction** (template or neural) | Your own labelled fields | A form Microsoft has never seen. Needs 5+ labelled samples |
| **Custom classification** | Routes a document to a type | You receive mixed batches and must split them before extraction |
| **Composed model** | Several custom models under one id | One endpoint that handles many form layouts |

Two things about custom models the exam asks:

- **Template models** learn positions. They are fast, need as few as 5 samples, and
  break when the layout shifts. **Neural models** learn structure and generalise
  across layouts, but need more samples and take longer to train.
- **Classification then extraction** is the standard mixed-batch architecture: a
  custom classifier decides *what* the document is, then routes it to the right
  extraction model. This exact pattern reappears in Content Understanding as
  classifier analyzers with `analyzerId` routing.

### Why layout's markdown matters more than it sounds

`prebuilt-read` gives you a wall of text in reading order. Tables become interleaved
gibberish and headings are indistinguishable from body text. Chunk that and you get
chunks that answer nothing.

`prebuilt-layout` with `output_content_format="markdown"` gives you:

```markdown
# Contoso Support Contract SLA-GOLD
## Response targets
| Severity | Response | Coverage |
| --- | --- | --- |
| 1 | 2 hours | 24x7 |
```

That unlocks **structural chunking**: split on `#`/`##` boundaries so each chunk is a
complete, self-contained section, and prepend the heading path to every chunk so it
is both retrievable and citable. A table survives as a table, which means a model
can actually read across rows.

> **Exam note.** "Improve RAG answer quality on PDFs containing tables" →
> layout-aware extraction to markdown, then chunk on headings. Not "increase chunk
> size", not "use a bigger embedding model".

Inside Azure AI Search this same capability is the
`Microsoft.Skills.Util.DocumentIntelligenceLayoutSkill` (see
[05.1](../01_retrieval_and_grounding/README.md)) — the skill emits markdown sections
you can chunk on directly, with `markdownHeaderDepth` controlling granularity.

### Grounding: spans, bounding regions, confidence

Every value Document Intelligence returns can be traced back:

| Property | Meaning | Used for |
|---|---|---|
| `content` | The literal text as it appears | Showing the user the raw evidence |
| `spans` | `offset` + `length` into the flat `content` string | Highlighting in a text view; linking a chunk back to source text |
| `boundingRegions` | `pageNumber` + polygon in inches | Drawing a box on the page image — the audit artefact |
| `confidence` | 0–1, **per field**, not per document | Routing to human review |

The **confidence threshold** pattern is the exam's favourite operational question:
auto-accept above a threshold, queue for human review below it. Thresholds are
per-field, because `InvoiceTotal` deserves more caution than `VendorName`, and they
are tuned against a labelled sample, not guessed.

> **Exam note.** A multimodal LLM returns none of these four. That is the entire
> argument for Document Intelligence in a regulated workflow, and it is why
> "replace Document Intelligence with GPT-4o to save money" is a wrong answer
> whenever the scenario mentions compliance, audit, or review queues.

### Content Understanding: analyzers

Content Understanding (in Foundry Tools) is one API over four modalities. Its unit
of work is an **analyzer**: a reusable, named configuration that says *what kind of
content this is* and *what structured data to pull out of it*.

An analyzer is a JSON document with three interesting parts:

```jsonc
{
  "baseAnalyzerId": "prebuilt-documentAnalyzer",   // which prebuilt to build on
  "config": { "returnDetails": true },
  "fieldSchema": {
    "fields": {
      "VendorName":  { "type": "string", "method": "extract",
                       "description": "Legal entity issuing the document" },
      "TotalAmount": { "type": "number", "method": "extract" },
      "Category":    { "type": "string", "method": "classify",
                       "enum": ["invoice", "receipt", "statement", "other"] },
      "Summary":     { "type": "string", "method": "generate",
                       "description": "Two sentences a support agent could act on" },
      "LineItems":   { "type": "array",  "method": "extract",
                       "items": { "type": "object", "properties": {
                          "Description": { "type": "string" },
                          "Amount":      { "type": "number" } } } }
    }
  }
}
```

**The three generation methods are the most testable thing in this unit:**

| Method | Behaviour | Grounded? | Use for |
|---|---|---|---|
| **`extract`** | Pull a value that is **literally present** in the content | Yes — returns spans/source | Invoice totals, dates, names, IDs |
| **`classify`** | Choose one of an **enumerated** set of categories | Partially | Document type, sentiment, priority, routing |
| **`generate`** | **Write** a value that is not literally present — a summary, an inference, a normalised form | No — it is model output | Summaries, titles, abstractive descriptions |

Choosing `generate` where `extract` would do is how you lose auditability. Choosing
`extract` for something the document does not literally contain gets you nulls.

Field types are `string`, `number`, `integer`, `boolean`, `date`, `time`, `array`,
and `object` — arrays and objects are how you model repeating structures such as
line items or per-speaker segments.

**Multi-modality.** The same analyzer shape works across content types; the base
analyzer changes:

| Modality | Base analyzers | What you get before you add any fields |
|---|---|---|
| **Document** | `prebuilt-documentAnalyzer`, `prebuilt-invoice`, … | Markdown of the document, OCR, layout, tables |
| **Image** | `prebuilt-imageAnalyzer`, `prebuilt-imageSearch` | A description, detected text |
| **Audio** | `prebuilt-audioAnalyzer`, `prebuilt-callCenter`, `prebuilt-audioSearch` | Transcript with speaker labels and timestamps |
| **Video** | `prebuilt-videoAnalyzer`, `prebuilt-videoSearch` | Transcript, keyframes, chapter/shot segments with timestamps |

That is the answer to 05.1's "audio and video are not cracked by Search": you run a
Content Understanding analyzer over the media, get a timestamped, structured,
markdown-bearing representation back, and index *that*.

**Pro mode** (preview) is the multi-step variant: it can reason across several input
files at once and consult reference data, at higher latency and cost. Standard mode
handles one file per input. Unit
[03.2](../../03_computer_vision/02_multimodal_understanding/README.md) covers the
pro-mode distinction for visual content.

**API shape.** GA API version is `2025-11-01`.

| Operation | Call |
|---|---|
| Create/replace analyzer | `PUT {endpoint}/contentunderstanding/analyzers/{id}?api-version=2025-11-01` |
| Analyze | `POST {endpoint}/contentunderstanding/analyzers/{id}:analyze?api-version=2025-11-01` with `{"inputs":[{"url": "..."}]}` |
| Poll | `GET` the `Operation-Location` header URL until `status` is `Succeeded` |
| Delete | `DELETE {endpoint}/contentunderstanding/analyzers/{id}?api-version=2025-11-01` |

Both creation and analysis are **long-running operations**: the POST/PUT returns
202 with an `Operation-Location`, and you poll. A synchronous variant exists for
Read and Layout when you need an immediate response. Analyzers must be bound to
model deployments on the Foundry resource — set once via
`PATCH {endpoint}/contentunderstanding/defaults`, or in Content Understanding Studio
under **Settings**.

> **Exam note.** Content Understanding lives on the **Foundry (AI Services)
> resource** and shares its endpoint and RBAC. Entra ID works —
> *Cognitive Services User* is enough to create and run analyzers. It is a separate
> service from Document Intelligence with a separate API surface, even though both
> can read an invoice.

### Producing clean, grounded representations for agents and RAG

"Clean" and "grounded" are two different requirements and both matter:

**Clean** means the text a model sees has the structure the original had. Concretely:

1. Extract to **markdown**, not to a flat string.
2. Chunk on **heading boundaries**, not on character counts, so a chunk is a whole
   idea.
3. **Prepend the heading path** to every chunk: `SLA-GOLD > Response targets > ...`.
   A chunk that begins "It must be filed within 14 days" is unretrievable and
   uncitable.
4. Keep tables as markdown tables. Do not flatten them into prose.

**Grounded** means every chunk can be traced back. Carry `source_uri`, `page`, and —
where the extractor gives you one — the `span` offset, as retrievable fields on the
index document. That is what turns "the model said 14 days" into "the model said 14
days, and here is page 2 of the returns policy with the sentence highlighted."

An agent consuming this gets a markdown chunk with a heading path and a citable
source. That is the whole deliverable of the information-extraction domain.

---

## Portal walkthrough

### Step 1 — Document Intelligence Studio

1. Go to **https://documentintelligence.ai.azure.com** and sign in. Select your
   subscription, resource group, and the Foundry / AI Services resource.
2. Under **Prebuilt models**, open **Read**. Upload a PDF (or use the sample) and
   **Run analysis**. Note what you get: text, per-word confidence, detected
   language, handwriting flag. Nothing structural.
3. Open **Layout** and run the *same* file.

   | Look at | Why |
   |---|---|
   | The **Tables** tab | Rows and columns recovered as a grid, with cell spans |
   | **Selection marks** | Checkbox state — `selected` / `unselected` |
   | Paragraph **roles** in the JSON (`title`, `sectionHeading`, `pageHeader`, `footnote`) | This is what heading-aware chunking keys on |
   | The **output format** control → **Markdown** | The RAG-ready representation |

4. Open **Invoice** and run an invoice. Now compare the shape: named, typed fields
   (`InvoiceId`, `InvoiceDate`, `VendorName`, `InvoiceTotal`, `Items` array), each
   with `confidence` and a highlighted region on the page. Click a field and watch
   the page highlight — that is `boundingRegions`.

5. **Custom models** → **Custom extraction model** → **+ New project**. You do not
   have to train one, but walk the wizard once:

   | Step | What it asks | Note |
   |---|---|---|
   | Connect storage | A blob container of sample documents | Labels are stored beside them as `.labels.json` |
   | Build mode | **Template** or **Neural** | Template = positional, 5 samples, fast, brittle. Neural = structural, generalises, slower |
   | Label | Draw boxes, name fields | Minimum **5** labelled documents |
   | Train | Produces a model id | You then call it exactly like a prebuilt: `begin_analyze_document("<model-id>", ...)` |

### Step 2 — Content Understanding Studio

1. Go to **https://contentunderstanding.ai.azure.com**.
2. **Settings** → **+ Add resource** → pick your Foundry resource. Leave **Enable
   autodeployment for required models if no defaults are available** ticked —
   analyzers need a chat model and an embedding model deployed and set as
   *defaults*, and without them every analyze call fails.
3. **Create project** → **Extract content and fields with a custom schema**.
4. Upload one of the documents this lab generates (or any invoice). The studio
   classifies it and suggests analyzer templates. Take a template.
5. **Define your schema.** For each field set:

   | Control | Maps to |
   |---|---|
   | Field name | the JSON key in `fieldSchema.fields` |
   | Value type | `type` — string / number / date / boolean / array / object |
   | Method | `method` — **extract / classify / generate** |
   | Description | `description` — this is a *prompt*. Write it like one. |

   Use **AI-suggested fields** once to see how the service reads your document, then
   delete the fields you do not need. Every extra field costs latency and tokens.
6. **Test** on a couple of documents, correct what is wrong, and **Build analyzer**.
   The analyzer gets an id you can call from code.
7. **Classification projects** (**Classify and route your data**) build a classifier
   analyzer whose categories can each carry an `analyzerId`. A document is
   classified, then automatically routed to the analyzer for that category. That is
   the mixed-batch pattern, without training a model.

<details>
<summary>REST / CLI alternative</summary>

```powershell
$ep    = $env:AZURE_CONTENT_UNDERSTANDING_ENDPOINT   # the Foundry resource endpoint
$token = az account get-access-token --resource https://cognitiveservices.azure.com `
          --query accessToken -o tsv

# 1. Bind default model deployments (once per resource)
az rest --method patch `
  --uri "$ep/contentunderstanding/defaults?api-version=2025-11-01" `
  --headers "Authorization=Bearer $token" "Content-Type=application/json" `
  --body '{ "modelDeployments": { "gpt-4o-mini": "gpt-4o-mini",
                                  "text-embedding-3-small": "text-embedding-3-small" } }'

# 2. Create an analyzer
az rest --method put `
  --uri "$ep/contentunderstanding/analyzers/ai103-invoice?api-version=2025-11-01" `
  --headers "Authorization=Bearer $token" "Content-Type=application/json" `
  --body '@analyzer.json'

# 3. Analyze (returns 202 + Operation-Location; poll it)
az rest --method post `
  --uri "$ep/contentunderstanding/analyzers/ai103-invoice:analyze?api-version=2025-11-01" `
  --headers "Authorization=Bearer $token" "Content-Type=application/json" `
  --body '{ "inputs": [ { "url": "https://..." } ] }'

# 4. Delete
az rest --method delete `
  --uri "$ep/contentunderstanding/analyzers/ai103-invoice?api-version=2025-11-01" `
  --headers "Authorization=Bearer $token"
```

There is also a preview `azure-ai-contentunderstanding` Python package. This course
calls the REST API directly with a bearer token so there is nothing to install and
the wire format — which is what the exam describes — stays visible.
</details>

---

## Troubleshooting

**`404` on the Content Understanding endpoint**
Content Understanding is not available in every region and requires a **Foundry /
AI Services** resource, not a standalone Document Intelligence resource. Check the
region support list, and confirm `AZURE_CONTENT_UNDERSTANDING_ENDPOINT` points at
`https://<resource>.services.ai.azure.com` (or the `cognitiveservices.azure.com`
custom subdomain), not at a project endpoint.

**Analyze returns `InvalidRequest: No default model deployment configured`**
You skipped the `defaults` binding. Analyzers need a chat model and an embedding
model deployed on the resource and registered as defaults, via Studio **Settings**
or `PATCH /contentunderstanding/defaults`.

**`202 Accepted` and then nothing**
Both analyzer creation and analysis are long-running. Read the `Operation-Location`
response header and poll it until `status` is `Succeeded`. A `Running` or
`NotStarted` status is not an error.

**Content Understanding cannot read my blob URL**
The `url` in `inputs` must be reachable by the service. A plain
`https://acct.blob.core.windows.net/...` URL on a private container returns 403.
Use a short-lived **user-delegation SAS** (derived from your Entra token, not from
an account key), or make the container public — the lab uses the SAS.

**Document Intelligence: `InvalidContent` / `The file is corrupted or format is unsupported`**
Check the actual bytes, not the extension. Supported: PDF, JPEG, PNG, BMP, TIFF,
HEIF, and Office formats for some models. Max file size and page count differ per
tier; the free tier truncates to the first 2 pages, which silently produces
incomplete results.

**Document Intelligence: `output_content_format` is rejected**
Markdown output is a v4.0 (`azure-ai-documentintelligence`) feature and only on
`prebuilt-layout` and models built on it. The legacy `azure-ai-formrecognizer`
package does not have it at all. Also note the enum was renamed between betas:
`ContentFormat.MARKDOWN` in early previews, `DocumentContentFormat.MARKDOWN` in
1.0.0 GA.

**`401` / `403` from either service with a good `az login`**
Both are data-plane calls on the Foundry resource and need a data-plane role.
*Cognitive Services User* covers Content Understanding and Document Intelligence.
Resource-level Contributor does not.

**Custom model training fails: "not enough labeled documents"**
Minimum is **5** labelled documents of the same type. Fewer, or inconsistent field
names across labels, and training refuses.

**Extraction confidence is high but the value is wrong**
Confidence is the model's confidence in *its reading of the pixels*, not in your
business logic. A perfectly-read `Total` from the wrong column scores 0.99. This is
why the auto-accept threshold is tuned against a labelled sample rather than picked.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on the model ladder, markdown chunking, analyzer
schemas, generation methods, and the three-way service choice.

## Next

[90 — Full study-guide summary and mock exam](../../90_summary/README.md) — every
study-guide bullet, mapped to the unit that taught it.

# 02 — Design and implement multimodal understanding workflows

**Time:** 90–120 minutes · **Cost:** under $1 with `gpt-4o`, plus a few cents of Content Understanding

Generation was the expensive half of computer vision. Understanding is the half you
will actually ship. This unit is mostly one question asked repeatedly: **for this
task, does a multimodal LLM win, or does a purpose-built vision service win?** The
exam asks it in a dozen costumes.

By the end you will have:

- [ ] Sent images to `gpt-4o` as base64 data URIs and as public URLs, and understood `detail`
- [ ] Produced concise and detailed captions, for one image and across a set
- [ ] Built visual question answering that refuses to answer beyond the evidence
- [ ] Generated WCAG-aligned alt text and an extended description for a complex image
- [ ] Run Content Understanding analyzers over an image and a video
- [ ] Compared standard and pro mode, and single-task against multi-input pipelines
- [ ] Identified objects and regions, and seen why an LLM cannot give you bounding boxes

---

## Concepts

### Three ways to look at a picture

| | **Multimodal LLM** (`gpt-4o`) | **Azure AI Vision** Image Analysis 4.0 | **Content Understanding** in Foundry Tools |
|---|---|---|---|
| Shape of output | Free text, or JSON you specify | Fixed schema: captions, tags, objects, people, OCR, smart crops | JSON matching a **schema you define**, plus Markdown |
| Bounding boxes | **No** | **Yes**, pixel coordinates with confidence | Not the primary output; grounding refers back to the source |
| Confidence scores | No | Yes, per detection | Yes, per field |
| Reasoning / inference | Yes — "is this safe to publish?" | No | Yes, generative field extraction |
| Custom vocabulary | Prompt it | Requires a custom model | Define fields in the analyzer |
| Video | Frames only, you sample them | Frames / Spatial Analysis | **Native**, with segments and transcript |
| Latency, cost | Seconds, per token | Milliseconds, per transaction (cheapest) | Seconds, per asset |
| Determinism | Low | High | Medium |

Decision rules worth memorising:

- **Need coordinates? Not an LLM.** No amount of prompting makes `gpt-4o` return
  reliable bounding boxes. Use Image Analysis `OBJECTS` or `PEOPLE`.
- **Need a judgement, an explanation, or an answer to a question?** LLM.
- **Need the same structured fields out of thousands of assets, with confidence
  scores and grounding?** Content Understanding.
- **Need it in milliseconds at high volume for a fixed taxonomy?** Image Analysis.
- **Need video with transcript and scene segmentation?** Content Understanding.

> **Exam note.** The trap is a scenario that *sounds* generative — "describe what is
> in the warehouse photo" — but then adds "and highlight each pallet in the UI."
> The highlight requires coordinates, so the answer is Image Analysis (possibly
> alongside an LLM for the prose).

### How images reach a chat model

The chat completions API takes a content array where each part is either text or an
image:

```python
{'role': 'user', 'content': [
    {'type': 'text', 'text': 'What is unusual here?'},
    {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,iVBORw0…',
                                        'detail': 'low'}},
]}
```

Two ways to supply the image:

| | Public URL | Base64 data URI |
|---|---|---|
| Form | `https://…/photo.jpg` | `data:image/jpeg;base64,<payload>` |
| Requires | The image reachable from Azure | Nothing |
| Request size | Small | ~33% larger than the file |
| Works for private data | No | Yes |
| Typical use | Public or CDN assets | Blob Storage behind a firewall, user uploads |

For private images the usual production pattern is a short-lived SAS URL, or read
the bytes with your managed identity and inline them as base64. Passing a private
blob URL directly does not work — the model has no credentials.

**`detail`** controls how the image is tokenised, and therefore what it costs:

| Value | Behaviour | Use for |
|---|---|---|
| `low` | Single low-resolution pass, fixed small token cost | Classification, gist, "is there a person in this frame", video sampling |
| `high` | Downscaled overview **plus** tiled crops — many more tokens | Reading text, fine detail, counting, charts |
| `auto` | Model decides from image size | Default |

On a video pipeline sampling one frame per second, `detail='low'` versus `'high'`
is the difference between a viable feature and an unaffordable one.

### Captions: concise, detailed, and across a set

Three distinct jobs the study guide separates:

| Task | Prompt shape | Watch out for |
|---|---|---|
| **Concise caption** | Constrain hard: "One sentence, max 15 words, no preamble." | Without a length constraint the model writes a paragraph |
| **Detailed caption** | Ask for structure: subject, setting, composition, notable detail | Verbosity is not detail; ask for named aspects |
| **Multi-image** | All images in **one** message, numbered in the text | Send them separately and the model cannot compare them |

Multi-image is the interesting one. Putting several images in a single user message
lets the model do things that are impossible one call at a time: pick the best shot
of a set, spot the difference, group by subject, or write a caption for a gallery
as a whole. It also multiplies your token cost by the number of images, so `detail`
matters even more.

### Visual question answering, and grounding

"Grounded in visual evidence" means the answer must come from the pixels, and the
model must say so when it cannot. Left unconstrained, a multimodal model will
happily answer from world knowledge and present it as observation.

Three things make VQA grounded:

1. **A system prompt that permits refusal.** "Answer only from the image. If the
   image does not show it, reply exactly `NOT_VISIBLE`."
2. **A structured answer that carries its own evidence.** Ask for
   `{answer, evidence, confidence}` and the evidence field becomes auditable.
3. **A verification pass.** For high-stakes answers, re-ask with only the claim and
   the image: "Does this image support this statement? yes/no."

> **Exam note.** Grounding for vision is the same idea as RAG groundedness in unit
> 02.2, applied to a different modality. If a question offers "increase temperature
> for more creative answers" as an option in a grounding scenario, it is wrong.

### Accessibility: alt text is not a caption

This is under-taught and directly examinable. WCAG 2.2 success criterion **1.1.1
Non-text Content** requires a text alternative that serves the *equivalent
purpose*. What that means depends on the image's role:

| Image role | What it needs | Why |
|---|---|---|
| **Decorative** — adds nothing informational | `alt=""` (empty, but present) | An empty alt tells the screen reader to skip it. Omitting `alt` makes it read the file name |
| **Informative** — conveys meaning | Short alt, typically ≤ 125 characters | Read inline; long alt is exhausting in a screen reader |
| **Functional** — a link or button | Describe the **action**, not the picture | "Search", not "magnifying glass icon" |
| **Complex** — chart, diagram, map | Short alt naming what it is, **plus** an extended description nearby | The data belongs in text a user can navigate |
| **Text in image** | The text itself | Otherwise the content is simply lost |

Rules that follow, and that an LLM will violate unless told:

- Do not begin with "Image of" or "Picture of" — the screen reader already announced it.
- Do not editorialise: "a beautiful sunset" is a judgement, not a description.
- Alt text is context-dependent. The same photograph on a news site and in a camera
  review needs different alt text. **This is why full automation is not compliance**
  — a model cannot know the page's purpose unless you tell it, so pass the
  surrounding context into the prompt and keep a human in the loop.

An extended description for a chart should give the reader what a sighted reader
gets: chart type, axes and units, the trend, and the notable values. Not every
data point unless the point of the page is the data.

### Content Understanding: analyzers, standard and pro

Content Understanding is a Foundry Tool that turns documents, images, audio and
video into **your** schema. Two stages:

1. **Content extraction** — modality-appropriate raw signal: OCR and layout for
   documents, transcript and keyframes and shot boundaries for video.
2. **Field extraction** — a generative model fills the fields you defined, with
   confidence scores and grounding back to the source.

Prebuilt analyzers get you started without defining anything:

| Analyzer | Modality | Produces |
|---|---|---|
| `prebuilt-imageSearch` | Image | Markdown description plus a `Summary` field |
| `prebuilt-videoSearch` | Video | Per-segment Markdown, transcript, keyframes, `Summary` |
| `prebuilt-audioSearch` | Audio | Transcript, summary, speaker labels |
| `prebuilt-documentSearch`, `prebuilt-invoice`, … | Document | Layout, fields |

Custom analyzers add a `fieldSchema` — name, type and description per field — and
optionally extend a prebuilt analyzer.

**Standard vs pro mode** (pro introduced in the `2025-05-01-preview` API):

| | Standard (default) | Pro |
|---|---|---|
| Inputs per request | One | **Multiple**, reasoned over together |
| Reasoning | Single pass | Multi-step |
| External knowledge base | No | Yes — link, enrich and validate against reference data |
| Cost, latency | Lower | Higher |
| Use when | One asset in, fields out | Cross-referencing, validation, work that would otherwise need custom code |

The pro-mode decision rule: **if answering the question requires comparing one
asset against another asset or against a reference source, that is pro mode.**
Inspection photo against the specification sheet; claim photo against the policy
document. If each asset is independent, standard mode is correct and cheaper.

> **Exam note.** "Single-task" is standard mode: one analyzer, one input, one
> result. Do not reach for pro mode because a schema has many fields — field count
> is not the criterion. Number of inputs and need for cross-referencing is.

The API is asynchronous, like everything that processes media:

```
POST {endpoint}/contentunderstanding/analyzers/{analyzerId}:analyze?api-version=2025-11-01
  → 202 with an Operation-Location header
GET  {Operation-Location}   → poll until status = Succeeded
```

The Python SDK (`azure-ai-contentunderstanding`, preview) wraps that in
`client.begin_analyze(analyzer_id=..., inputs=[AnalysisInput(url=...)])` returning
a poller.

### Video: segments, not frames

A naive video pipeline samples frames and sends each to an LLM. It works, and it is
the right answer for short clips and simple questions, but it is expensive and it
loses everything temporal — motion, speech, and where one scene ends.

| Approach | Good at | Bad at |
|---|---|---|
| **Sample frames → `gpt-4o`** | Short clips, ad-hoc questions, no extra service | Cost at scale, audio, scene boundaries, timestamps |
| **Content Understanding `prebuilt-videoSearch`** | Segments with start/end times, transcript, per-segment fields, RAG-ready Markdown | Ad-hoc one-off questions |
| **Azure AI Vision Spatial Analysis** | Real-time streams, counting, zone dwell | Semantics — it does not know *why* |

Content Understanding returns one content object per detected segment, each with
`start_time_ms`, `end_time_ms`, `markdown`, and your custom fields. That structure
is what makes video searchable: index each segment, and a retrieval hit points at a
timestamp rather than at a two-hour file.

### Objects and regions

To draw a box around something, you need Image Analysis 4.0:

| Visual feature | Returns |
|---|---|
| `OBJECTS` | Bounding boxes with tag and confidence |
| `PEOPLE` | Bounding boxes for people |
| `TAGS` | Content tags with confidence, no coordinates |
| `CAPTION`, `DENSE_CAPTIONS` | One caption for the image / captions per region **with boxes** |
| `READ` | OCR — text with line and word polygons |
| `SMART_CROPS` | Crop rectangles that preserve the region of interest |

`DENSE_CAPTIONS` is the sweet spot for region identification: a sentence *and* a
box for each notable region. `CAPTION` and `DENSE_CAPTIONS` are only available in
a subset of regions — check
[Image Analysis region support](https://learn.microsoft.com/azure/ai-services/computer-vision/overview-image-analysis)
before you design around them.

The mature pattern is to combine: **Image Analysis for coordinates, an LLM for
meaning.** Detect the objects, feed the list of tags and boxes into the model as
text alongside the image, and ask it to reason. You get boxes you can render and
prose a human wants to read.

---

## Portal walkthrough

### Chat playground with an image

1. **https://ai.azure.com** → your project → **Playgrounds** → **Chat**.
2. Choose the `gpt-4o` deployment. `gpt-4o-mini` also accepts images, but this is
   one of the few places in the course where the stronger model earns its price —
   detail recall on complex images is visibly better.
3. Use the attachment control to add an image and ask `What is unusual here?`
4. Ask a second question about the same image without re-attaching it. The image
   stays in the conversation history — and is re-billed on every turn. That is the
   single biggest cost surprise in multimodal chat.

### Content Understanding Studio

1. Go to **https://aka.ms/cu-studio** and select your Foundry resource.

   Content Understanding is only available in a subset of regions and requires
   **default model deployments** configured on the resource. If the Studio prompts
   you to set defaults, accept — it is a one-time connection between Content
   Understanding and your Foundry model deployments.

2. Choose **Image** as the modality and upload a photograph.
3. Run the prebuilt image analyzer. Inspect the Markdown and the `Summary` field.
4. **+ Create analyzer**. Add fields:

   | Field name | Type | Description |
   |---|---|---|
   | `primarySubject` | string | The main subject of the photograph |
   | `settingType` | string | indoor, outdoor, studio, or unknown |
   | `containsPeople` | boolean | Whether any person is visible |
   | `dominantColors` | array of string | Up to three dominant colours |

5. Run it. Every field comes back with a **confidence score** — that is the thing
   an LLM prompt does not give you, and the reason Content Understanding exists for
   straight-through processing.
6. Switch the mode selector to **pro** and note that the upload control now accepts
   **multiple** files. That is the visible difference.
7. Repeat with a short video and the prebuilt video analyzer. Note the **segments**
   in the output, each with its own timestamps.

<details>
<summary>REST alternative</summary>

```powershell
$token = az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv
$ep    = "<your Foundry endpoint>"

# Submit
$r = curl -i -X POST "$ep/contentunderstanding/analyzers/prebuilt-imageSearch:analyze?api-version=2025-11-01" `
  -H "Authorization: Bearer $token" -H "Content-Type: application/json" `
  -d '{"url":"https://raw.githubusercontent.com/Azure-Samples/azure-ai-content-understanding-assets/main/image/pieChart.jpg"}'

# The response carries an Operation-Location header; poll it until Succeeded
curl -X GET "$ep/contentunderstanding/analyzerResults/<request-id>?api-version=2025-11-01" `
  -H "Authorization: Bearer $token"
```

`2025-11-01` is the GA API version. Use `2026-06-01-preview` only for preview
features.
</details>

---

## The lab

[lab.ipynb](lab.ipynb). It uses `MODEL_CHAT` (`gpt-4o`) rather than `MODEL_MINI`
throughout the vision sections, and says why at each point.

Two optional sections need packages that are **not** in `requirements.txt`:

```powershell
pip install azure-ai-vision-imageanalysis
pip install --pre azure-ai-contentunderstanding
```

Both sections are guarded by a flag and the notebook runs without them.

---

## Troubleshooting

**`Invalid content type. image_url is only supported by certain models`**
The deployment is not a vision-capable model. `gpt-4o` and `gpt-4o-mini` are;
older `gpt-35-turbo` and reasoning-only deployments are not.

**`400 Failed to download the image from the provided URL`**
The URL is not publicly reachable. Azure fetches it server-side and has no access
to your storage account. Use a SAS URL or inline the bytes as base64.

**Token cost far higher than expected on images**
`detail='high'` tiles the image and bills every tile, and in a multi-turn chat the
image is re-sent with every subsequent turn. Use `detail='low'` where the task
allows, and drop old images from the history.

**The model invents details that are not in the image**
No refusal path in the system prompt. Give it an explicit escape hatch
(`NOT_VISIBLE`), lower the temperature, and ask for evidence alongside the answer.

**Alt text starts with "This image shows…"**
Not a model failure, a prompt failure. State the prohibition explicitly and give a
character limit; models comply with concrete constraints and ignore vague ones.

**Content Understanding: `404` on the analyzer endpoint**
Either the resource is in a region where Content Understanding is unavailable, or
the endpoint is wrong. It is the **Foundry (AIServices) resource** endpoint with
`/contentunderstanding/` appended, not the project endpoint.

**Content Understanding: an error about default model deployments**
The resource has no default model deployments configured. Set them once in Content
Understanding Studio, or `PATCH {endpoint}/contentunderstanding/defaults`.

**Image Analysis: `CAPTION` returns `InvalidRequest — feature not supported in this region`**
Caption and dense captions are limited to a subset of regions. Deploy a Vision
resource in a supported one, or use `TAGS` plus `OBJECTS`.

**Video analysis is slow or times out**
Expected — video is processed asynchronously and long assets take minutes. Poll the
operation rather than blocking a request thread, exactly as with Sora in unit 03.1.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on service selection, the `detail` parameter,
accessibility conventions, and Content Understanding modes.

## Next

[03.3 — Implement responsible AI for multimodal content](../03_responsible_ai_multimodal/README.md)

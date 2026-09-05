# 03.2 — Multimodal understanding: quiz

15 questions. Answers at the bottom. Aim for 12+ before moving on.

---

**1.** A warehouse app must describe each shelf photo in prose **and** draw a
highlight rectangle around every damaged carton. What do you use?

- A. `gpt-4o` only, prompted to return bounding boxes as JSON
- B. Azure AI Vision Image Analysis only
- C. Azure AI Vision for object detection plus `gpt-4o` for the prose
- D. Content Understanding in pro mode

---

**2.** Your images live in a private Azure Storage container. You pass the blob URL
in `image_url.url` and get *"Failed to download the image from the provided URL."*
Why?

- A. The chat API does not accept URLs, only base64
- B. Azure fetches the URL server-side with no access to your storage account
- C. The blob needs to be in the same region as the model
- D. `detail` must be set to `high` for URL images

---

**3.** Which two are valid fixes for question 2? Choose two.

- A. Generate a short-lived SAS URL for the blob
- B. Read the bytes with your managed identity and inline them as a base64 data URI
- C. Make the storage account public
- D. Increase the model's rate limit
- E. Switch to `gpt-4o-mini`

---

**4.** You sample one frame per second from a 10-minute video and send each to
`gpt-4o` to check whether anyone is wearing a hard hat. Which `detail` setting?

- A. `high` — accuracy matters for safety
- B. `low` — the task is coarse classification and cost scales with 600 frames
- C. `auto` — let the model decide per frame
- D. `detail` does not affect cost

---

**5.** A support chat lets users upload a screenshot and then asks five follow-up
questions about it. Costs are far higher than estimated. What is happening?

- A. Each follow-up re-uploads the image over the network
- B. The image remains in the message history and is re-billed on every turn
- C. `detail='low'` is being ignored for screenshots
- D. Vision requests are billed per second of processing

---

**6.** You want a model to compare three product photos and pick the best one for a
listing. How should the request be structured?

- A. Three separate calls, then a fourth call summarising the three answers
- B. All three images in a single user message, numbered in the text
- C. Three separate calls with the same conversation ID
- D. One call per image with `n=3`

---

**7.** Which system prompt best supports question answering grounded in visual
evidence?

- A. "Be helpful and answer the user's question about the image."
- B. "Answer using only what is visible. If the image lacks the evidence, reply NOT_VISIBLE. Return {answer, evidence, confidence} as JSON."
- C. "Use the image and your knowledge of the subject to give the most complete answer."
- D. "Answer creatively; set temperature high for richer descriptions."

---

**8.** A purely decorative banner sits at the top of a page. What is the correct
alt attribute?

- A. Omit the `alt` attribute entirely
- B. `alt="decorative banner"`
- C. `alt=""`
- D. A full description, for completeness

---

**9.** Which is **not** a convention for informative alt text?

- A. Roughly 125 characters or fewer
- B. Avoid starting with "Image of" or "Picture of"
- C. Describe rather than evaluate
- D. Include the image file name so users can find the asset

---

**10.** A page contains a complex bar chart. What does WCAG 1.1.1 require?

- A. Alt text listing every data point
- B. A short alt naming the chart, plus an extended description carrying the data
- C. `alt=""`, because the chart is visual
- D. A downloadable image file

---

**11.** Your team proposes generating alt text fully automatically at publish time,
with no review. What is the strongest objection?

- A. The model is too slow at publish time
- B. Alt text is context-dependent — the same image needs different text depending on the page's purpose — so a model without that context cannot produce equivalent-purpose alternatives reliably
- C. WCAG forbids machine-generated alt text
- D. Alt text cannot exceed 125 characters and models cannot count

---

**12.** An insurer wants to check a damage photograph against the policy document
covering that item, in one operation. Which Content Understanding configuration?

- A. Standard mode with a large `fieldSchema`
- B. Standard mode, called twice, with the results merged in code
- C. Pro mode
- D. `prebuilt-imageSearch`

---

**13.** Which statement about Content Understanding **standard** mode is correct?

- A. It accepts multiple input files per request
- B. It processes one input per request and is the default
- C. It requires an external knowledge base
- D. It is only available for documents

---

**14.** Which two are true of Content Understanding video analysis? Choose two.

- A. It returns one content object per detected segment, each with start and end times
- B. It requires you to extract frames yourself before calling the API
- C. Content extraction produces transcript and keyframes; field extraction then fills your schema
- D. It is synchronous — the analyze call returns the result directly
- E. It cannot produce custom fields, only a fixed summary

---

**15.** You need to read a serial number off 100,000 equipment labels, cheaply and
deterministically. What do you use?

- A. `gpt-4o` with `detail='high'`
- B. Azure AI Vision `READ` (OCR), or Document Intelligence if the label has structure
- C. Content Understanding pro mode
- D. `prebuilt-imageSearch`

---

## Answers

**1 — C.** The prose is a reasoning task and the highlight needs pixel coordinates
with confidence. No multimodal LLM produces reliable bounding boxes, so A yields
plausible numbers you cannot trust and cannot audit. B loses the prose — Image
Analysis captions are short and fixed-form, not explanatory. D is the wrong tool:
pro mode is about reasoning over multiple inputs, not about localisation. Combining
services is very often the intended answer.

**2 — B.** When you pass a URL, the service downloads it server-side and carries
none of your credentials. Public reachability is the requirement. A is wrong —
URLs are supported. C and D invent constraints.

**3 — A and B.** A short-lived SAS makes the blob reachable without making it
public; inlining base64 avoids reachability entirely and is the right default for
user uploads and firewalled storage. C solves the error by destroying the security
property you presumably wanted. D and E are unrelated to reachability.

**4 — B.** `low` is a single low-resolution pass at a small fixed token cost, and
"is anyone wearing a hard hat" is exactly the coarse classification it is for. At
600 frames the difference between `low` and `high` decides whether the feature is
affordable. A confuses "safety matters" with "more tokens help" — if `low` is
genuinely insufficient, the right fix is a purpose-built detector, not a more
expensive prompt. D is false.

**5 — B.** Images persist in the conversation history and are re-tokenised on every
subsequent turn, so five follow-ups mean six billings of the same screenshot. The
mitigation is to extract what you need on the first turn and drop the image from
the history. A describes network traffic, which is not what you are billed for.

**6 — B.** Comparison requires all the images in one context. Separate calls (A, C)
mean the model never sees more than one image at a time, and summarising three
independent descriptions is not the same as comparing three images. D misuses `n`,
which controls the number of completions, not inputs.

**7 — B.** It supplies all three grounding mechanisms: an explicit refusal path, a
structured answer that carries its own evidence, and a schema that makes the output
auditable. A gives the model no reason to refuse. C explicitly invites world
knowledge, which is the opposite of grounding. D raises fabrication risk — in any
grounding scenario, "increase temperature" is the wrong answer.

**8 — C.** An empty but present `alt` tells assistive technology to skip the image.
Omitting the attribute (A) causes many screen readers to announce the file name
instead, which is worse than nothing. B announces a useless description. D wastes
the user's time with content that carries no meaning.

**9 — D.** File names are implementation detail and are noise in a screen reader.
A, B and C are all genuine conventions: the length keeps inline reading tolerable,
the redundant prefix is unnecessary because the technology already announces that
an image is present, and evaluation is not description.

**10 — B.** Complex images need a short alt that identifies what the thing is, plus
an extended description nearby that conveys what a sighted reader gets — chart
type, axes and units, trend, notable values. A is unusable inline. C discards
information the page exists to convey. D is not a text alternative.

**11 — B.** The same photograph requires different alt text on a news article and
in a camera review, because the equivalent *purpose* differs. A model that is not
given the page's purpose cannot reliably produce it, which is why the practical
pattern is model-assisted drafting with human review — and why you pass surrounding
context into the prompt. C is false; WCAG constrains the outcome, not the tooling.
D is a convention, not a hard limit, and is trivially enforced in code.

**12 — C.** Two inputs — the photograph and the policy document — that must be
reasoned over together, with the second acting as reference data to validate
against. That is precisely what pro mode adds. A misreads the criterion: schema
size is irrelevant. B is the custom-code workaround pro mode exists to remove, and
it loses the cross-referencing. D is a prebuilt single-image analyzer.

**13 — B.** Standard is the default, takes one input per request, does a single
pass, and is cheaper and faster. A and C describe pro mode. D is false — standard
mode covers documents, images, audio and video.

**14 — A and C.** Segmentation with timestamps is what makes video searchable: index
each segment and a retrieval hit points at a moment rather than a file. The two
stages — content extraction, then generative field extraction — are the service's
core architecture. B is the manual approach you use with a raw LLM. D is false, the
API is asynchronous with an `Operation-Location` poll. E is false, custom fields
are the point.

**15 — B.** OCR is purpose-built, priced per transaction rather than per token,
returns text with polygons, and is deterministic — all four properties matter at
100,000 items. A works but is far more expensive and non-deterministic. C is
heavyweight for a single-field read from a single image. D generates descriptive
summaries, not verbatim text extraction.

---

## Lab exercise solutions

### 1. Measure `detail`

```python
import statistics

Q = 'What kind of chart is this, and what is the largest segment?'
report = {}
for detail in ('low', 'high', 'auto'):
    toks, answers = [], []
    for _ in range(5):
        r = look([{'type': 'text', 'text': Q}, image_part(chart, detail)], temperature=0)
        toks.append(r.usage.prompt_tokens)
        answers.append(r.choices[0].message.content.strip())
    report[detail] = (statistics.mean(toks), len(set(answers)) == 1)

for d, (mean_tokens, agreed) in report.items():
    print(f'{d:<5} mean prompt tokens {mean_tokens:7.0f}   answers identical: {agreed}')
```

You should see `low` at a small fixed cost, `high` several times larger because the
image is tiled and every tile is billed, and `auto` tracking one or the other
depending on image size. For a question this coarse the answers usually agree.

The rule to give a team: **start at `low` and only move to `high` when you can show
a measurable accuracy gap on your own data.** `high` exists for reading small text,
counting, and fine detail. Everything else — classification, gist, "is there an X in
this frame", and anything running per-frame over video — is `low`. Treat `auto` as a
prototyping default that you replace with an explicit value before shipping, because
`auto` makes your bill a function of whatever resolution your users happen to upload.

### 2. A grounded VQA function

```python
def ask_image(question, image_path, detail='high'):
    r = look([{'type': 'text', 'text': question}, image_part(image_path, detail)],
             system=VQA_SYSTEM, temperature=0,
             response_format={'type': 'json_object'})
    out = json.loads(r.choices[0].message.content)

    if out['answer'] == 'NOT_VISIBLE':
        out['verified'] = None          # nothing was claimed, so nothing to verify
        return out

    out['verified'] = verify(f"{question} {out['answer']}", image_path)
    if not out['verified']:
        out['confidence'] = 'low'       # a failed check must lower confidence
    return out


for q in ('What type of chart is shown?', 'Which company produced this data?'):
    print(q, '->', ask_image(q, chart))
```

Two design points. `verified` is `None` rather than `False` for a refusal, because
"we did not check" and "we checked and it failed" are different states and
collapsing them hides real failures. And a failed verification downgrades
`confidence` rather than discarding the answer — the caller decides what to do with
a low-confidence result, which is the right place for that policy.

### 3. An accessibility pipeline

```python
def accessibility_report(pairs):
    rows = []
    for path, context in pairs:
        entry = alt_text_for(path, context, detail='high')
        entry['image'] = pathlib.Path(path).name
        entry['context'] = context
        entry['lint'] = lint_alt(entry)
        rows.append(entry)
    return rows


pairs = [
    (chart, 'A report page analysing weekly working hours. The chart carries the argument.'),
    (photo, 'A product listing. The photo shows the item for sale.'),
    (photo, 'A purely decorative divider between sections. It carries no information.'),
]

for row in accessibility_report(pairs):
    print(f"{row['image']:<12} role={row['role']:<12} lint={row['lint']}")
    print(f"   alt : {row['alt_text']!r}")
    if row['extended_description']:
        print(f"   long: {row['extended_description'][:160]}...")
    print()
```

The third row is the interesting one, and the one worth arguing about. The image is
identical to the second, so the *only* thing that can make it decorative is the
context string. If your prompt does not push the model to `role="decorative"` and
`alt=""` here, it is not using the context, and context-blind alt text is exactly
how an automated pipeline passes a linter and fails a real audit. `lint_alt` catches
the mechanical half of that — non-empty alt on a decorative image, missing extended
description on a complex one — but it cannot catch a wrong *role*. That is what the
human review step is for.

### 4. Argue a design

**Bulk attribute extraction (200,000 photos → 12 attributes).** Azure Content
Understanding in standard mode, with a custom analyzer whose `fieldSchema` defines
the twelve attributes. The requirement is the same schema applied uniformly to
independent assets, which is exactly what standard mode is for and what makes it
cheap: one input per request, one pass, no cross-referencing. The decisive advantage
over prompting `gpt-4o` in a loop is not accuracy, it is **confidence scores and
grounding per field** — with those you can route low-confidence extractions to human
review and let the rest go straight through, which is what makes 200,000 items
tractable at all. A bare LLM gives you a JSON object with no signal about which
fields to distrust, so either everything gets reviewed or nothing does. Analysis is
asynchronous, so this runs as a queue-driven batch, not inline.

**Ad-hoc merchandiser questions.** A multimodal LLM (`gpt-4o`), with the image
supplied as a base64 data URI, a system prompt that forces grounding and permits
`NOT_VISIBLE`, and `detail='high'` because merchandisers ask about small printed
detail. There is no fixed schema here — the questions are open-ended and unknown in
advance — which is precisely the case Content Understanding does not serve. Volume
is low and interactive, so per-token cost is acceptable.

**If each attribute must also be located in the image**, neither service above
suffices: Content Understanding grounds fields back to the source but is not a
localisation API, and the LLM cannot produce trustworthy coordinates at all. Add
Azure AI Vision Image Analysis 4.0 with `OBJECTS` and `DENSE_CAPTIONS`, run it over
the same 200,000 images, and join its boxes to the extracted attributes by tag. The
architecture becomes three services with clearly separated jobs — Vision for
geometry, Content Understanding for the schema, the LLM for open-ended questions —
and that separation is the point: each is the cheapest, most deterministic tool for
its half of the problem.

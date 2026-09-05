# 04.1 — Language model text analysis: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** A legal team needs summaries of contracts. Compliance requires that every
sentence in the summary appears verbatim in the source contract. Which feature?

- A. `begin_abstract_summary`
- B. `begin_extract_summary`
- C. A `gpt-4o` prompt instructing the model to quote the source
- D. `extract_key_phrases`

---

**2.** Your redaction service must replace every social security number, and the
audit log must record the exact character position of each one. Which approach?

- A. `gpt-4o-mini` with a JSON schema containing `start` and `end` integers
- B. `recognize_pii_entities`
- C. Content Safety `analyze_text`
- D. `recognize_entities` filtered to the `PII` category

---

**3.** Which two Text Analytics operations are **long-running** and return a poller?
Choose two.

- A. `analyze_sentiment`
- B. `begin_analyze_healthcare_entities`
- C. `extract_key_phrases`
- D. `begin_abstract_summary`

---

**4.** An application must never receive a response that fails to match its JSON
contract. Which `response_format` setting?

- A. `{"type": "text"}` plus a prompt describing the JSON
- B. `{"type": "json_object"}`
- C. `{"type": "json_schema", "json_schema": {..., "strict": true}}`
- D. `{"type": "json_object"}` plus `temperature=0`

---

**5.** You submit a strict JSON schema and the API returns
*"'additionalProperties' is required to be supplied and to be false"*. What is
wrong?

- A. The model deployment is too old
- B. A nested object in your schema omits `"additionalProperties": false`
- C. You used `json_object` instead of `json_schema`
- D. `temperature` must be 0 for strict mode

---

**6.** A customer writes an extremely angry but non-threatening complaint. What do
`analyze_sentiment` and Content Safety `analyze_text` return?

- A. `negative` sentiment; severity 0 across all four categories
- B. `negative` sentiment; Hate severity 4
- C. `mixed` sentiment; Violence severity 2
- D. Content Safety returns a `sentiment` field of `negative`

---

**7.** Which service call detects that "no history of myocardial infarction" means
the patient did **not** have a heart attack?

- A. `recognize_entities`
- B. `recognize_pii_entities`
- C. `begin_analyze_healthcare_entities`
- D. `analyze_sentiment` with `show_opinion_mining=True`

---

**8.** A pharmaceutical company translates 200,000 product descriptions per month and
must use approved translations for 400 regulated drug names. What should they use?

- A. `gpt-4o` with the glossary in the system message
- B. Azure Translator with a Custom Translator model
- C. Azure Translator with default settings
- D. `gpt-4o-mini` with retrieval over the glossary

---

**9.** A support chat needs to translate two or three product names consistently.
The team has no parallel training corpus. Cheapest correct option?

- A. Train a Custom Translator model
- B. Use a dynamic dictionary in the Translator request
- C. Fine-tune `gpt-4o-mini`
- D. Post-process the translation with string replacement

---

**10.** Your Translator call with `DefaultAzureCredential` returns 401 against
`https://api.cognitive.microsofttranslator.com`. Your role assignment is correct.
What is missing? Choose two.

- A. `region`
- B. `api_version`
- C. `resource_id`
- D. An `AzureKeyCredential`

---

**11.** Which statement about `extract_key_phrases` is **not** true?

- A. It returns noun phrases from the input document
- B. It ranks phrases by importance across the batch
- C. It is a synchronous operation
- D. It provides no cross-document topic modelling

---

**12.** A team wants to classify support tickets into five fixed categories. They
have 3,000 labelled tickets and need a stable per-label confidence score for
routing. Which is the best fit?

- A. Custom text classification project in Azure AI Language
- B. `gpt-4o-mini` with a strict JSON schema and an enum
- C. Fine-tune `gpt-4o-mini` on the 3,000 tickets
- D. Conversational Language Understanding (CLU)

---

**13.** You must call a deployed custom NER model. Which two values must the SDK
call include? Choose two.

- A. The model name
- B. The project name
- C. The deployment name
- D. The training job ID

---

**14.** A call-centre wants each recorded conversation summarized into "issue" and
"resolution". Which is correct?

- A. `begin_abstract_summary` in `azure-ai-textanalytics`
- B. `begin_extract_summary` with `max_sentence_count=2`
- C. Conversation summarization via `ConversationAnalysisClient` in
  `azure-ai-language-conversations`
- D. CLU with two intents named `issue` and `resolution`

---
---

## Answers

**1 — B.** Extractive summarization selects existing sentences and returns them with
a `rank_score`, so faithfulness is structural rather than promised. Abstractive (A)
generates new sentences and can drift. C is the same risk with less accountability —
a model asked to quote will usually quote and occasionally paraphrase, and you have
no mechanism that prevents it. D returns noun phrases, not a summary.

**2 — B.** `recognize_pii_entities` returns `offset` and `length` for every entity
plus a service-generated `redacted_text`. A is the trap: models do not produce
reliable character offsets — the arithmetic is done in the same token stream that
generates the text, and it drifts. C classifies harm categories, not personal data.
D is invented: `recognize_entities` has no `PII` category, PII is a separate
operation with a separate entity taxonomy.

**3 — B and D.** Every `begin_*` method is a long-running operation returning a
poller you must `.result()`. That covers healthcare entities, both summarizers, all
custom features, and `begin_analyze_actions`. `analyze_sentiment`,
`extract_key_phrases`, `recognize_entities`, `recognize_pii_entities`,
`recognize_linked_entities`, and `detect_language` are synchronous.

**4 — C.** Structured Outputs with `strict: true` constrains decoding to the schema,
so a schema-violating response cannot be produced. B (JSON mode) guarantees only
that the output parses — fields can be missing, enums ignored, types wrong. A and D
guarantee nothing; `temperature=0` reduces variance but does not constrain grammar.

**5 — B.** Strict mode requires `"additionalProperties": false` on *every* object in
the schema, including nested ones, and every property listed in `required`. Optional
fields are expressed as a union with `"null"`, not by omission from `required`. The
schema is validated at request time, which is why you find out immediately rather
than at parse time.

**6 — A.** Sentiment and safety answer different questions. Sentiment is about the
author's attitude; Content Safety is about harmful content across Hate, SelfHarm,
Sexual, and Violence. A polite-but-furious complaint is `negative` and severity `0`.
Systems that treat negative sentiment as a moderation signal end up suppressing
legitimate complaints. D is fabricated — Content Safety returns
`categories_analysis`, never a sentiment field.

**7 — C.** Text Analytics for Health returns **assertions** on entities — certainty
(negated, hypothetical), conditionality, and association (patient vs family member) —
alongside UMLS links and entity relations. General NER (A) finds the term and tells
you nothing about negation, which is exactly how naive clinical pipelines record the
opposite of what the note says.

**8 — B.** Volume plus enforced terminology is the Custom Translator case: train on
parallel data, deploy the model, and every request routes through it. A and D put
the glossary in context, which is a strong suggestion the model may ignore, and at
200,000 documents per month the token cost is an order of magnitude worse. C ignores
the terminology requirement entirely.

**9 — B.** A dynamic dictionary
(`<mstrans:dictionary translation="...">...</mstrans:dictionary>`) pins a term
inline with no training data and no extra resource. A needs a parallel corpus you do
not have. C is enormously disproportionate. D breaks on inflection, word order, and
script changes — the reason the dictionary markup exists is that naive replacement
does not survive translation.

**10 — A and C.** Against the global Translator endpoint an Entra ID token does not
identify the resource, so you must pass both `resource_id` (which resource to bill
and authorize) and `region` (where to route). Supplying only one yields 401. B has a
working default. D would be the key-based path, which defeats the point.

**11 — B.** Key phrase extraction is per-document and **unranked** — there is no
importance score and no cross-document aggregation. A, C, and D are all true.
Ranking themes across a corpus needs embeddings plus clustering, or an LLM
summarizing batches.

**12 — A.** Fixed labels, labelled data, and a requirement for a stable confidence
score is the exact shape custom text classification was built for. B gives you an
enum but the "confidence" is either absent or a self-reported number with no
calibration. C is disproportionate for classification and pins you to a model
version with an hourly-billed deployment. D is for **utterances** — intents and
entities in conversational turns — not document classification.

**13 — B and C.** Every custom Language call takes `project_name` and
`deployment_name`. The deployment name is what you version and swap, exactly like a
model deployment name in unit 00. There is no model name in the call, and training
job IDs are an authoring-time concept.

**14 — C.** Conversation summarization is a separate package
(`azure-ai-language-conversations`) and a separate client
(`ConversationAnalysisClient`) with conversation-specific aspects including `issue`,
`resolution`, `chapterTitle`, and `narrative`. A and B are document summarizers with
no notion of speakers or turns. D confuses classification of an utterance's intent
with summarizing a whole conversation.

---

## Lab exercise solutions

**1. Redaction pipeline.**

```python
def redact_with_report(text, threshold=0.8):
    result = language.recognize_pii_entities([text])[0]
    kept = [e for e in result.entities if e.confidence_score >= threshold]
    safe = text
    for e in sorted(kept, key=lambda x: x.offset, reverse=True):
        safe = safe[: e.offset] + f"<{e.category}>" + safe[e.offset + e.length :]
    counts = {}
    for e in kept:
        counts[e.category] = counts.get(e.category, 0) + 1
    report = {
        "counts": counts,
        "min_confidence": min((e.confidence_score for e in kept), default=None),
        "dropped_below_threshold": len(result.entities) - len(kept),
    }
    return safe, report
```

Running the structured extraction over the redacted text: `customer.name` and any
contact detail come back `null`, and `order_id` usually survives because `SO-4471`
is not a PII category. The lesson is about **ordering**. Redact-then-analyse is
correct when the downstream consumer must never see raw personal data — and you
accept losing the fields that *were* the personal data. Analyse-then-redact keeps
those fields but means the analysis service processed unredacted data, which is a
data-residency and processing-agreement question, not a technical one. Real
pipelines usually redact for storage and downstream sharing, while analysing the
original inside the trust boundary, and keep a mapping table under separate access
control.

Also note the `dropped_below_threshold` count. Raising the threshold reduces false
positives and increases the risk of leaking real PII — for redaction the asymmetry
argues for a *low* threshold, the opposite of most classification tuning.

**2. Fabrication under pressure.** With rule 2 in place and `temperature=0`, three
runs give `deadline: null` for the deadline-free obligation, consistently. Remove
rule 2 and you typically see one or two runs invent something plausible — "72
hours", "immediately", or a deadline borrowed from an adjacent section. The schema
alone does not prevent this: `"type": ["string", "null"]` permits null but does not
*prefer* it, and the model's prior is that a compliance obligation has a deadline.

Two takeaways. First, the nullable type and the explicit instruction are doing
different jobs — the schema makes null *possible*, the instruction makes it
*expected*. Second, this is why `source_quote` plus the substring check in section 9
exists: a mechanical verifier catches what a prompt cannot prevent. That is the
cheapest groundedness evaluator you will ever write, and it belongs in the pipeline,
not the notebook.

**3. Hybrid translation.** Typical shape for `POLICY` (~950 characters):

| Approach | Wall clock | Tokens | Notes |
|---|---|---|---|
| Translator only | ~150 ms | 0 | Register is neutral, terminology unmanaged |
| LLM only | ~4 s | ~700 in / ~450 out | Best register, highest cost |
| Translator + LLM post-edit | ~3 s | ~1,100 in / ~450 out | Source *and* MT in the prompt |

The hybrid is *more* expensive per document than the LLM alone here, because you
pay for the machine translation in the prompt on top of the source. It pays off only
when you post-edit **selectively** — translate everything with Translator, then send
to the model just the segments Translator flags as low-confidence, or the segments
in customer-facing surfaces. Post-editing 5% of a corpus is a 20× saving; post-
editing everything is a loss. The break-even is about *selectivity*, not length.

**4. Cost model.** The calculation, with list prices as assumptions you must state:

```
Translator:  ~$10 per 1,000,000 characters
gpt-4o-mini: ~$0.15 per 1,000,000 input tokens, ~$0.60 per 1,000,000 output tokens
Assume 1 token ~ 4 characters of English.
```

For a document of `C` characters translated to one target language:

- Translator: `C x 10 / 1e6` USD
- LLM: input `~C/4` tokens plus a ~100-token system message, output `~C/4` tokens
  (more for languages with lower information density per token — Japanese and Thai
  can be 2–3× worse, which is itself an exam-worthy point).
  Roughly `(C/4) x 0.15/1e6 + (C/4) x 0.60/1e6 = C x 0.1875 / 1e6` USD.

On those numbers `gpt-4o-mini` is *cheaper per character* than Translator —
approximately 50×. That result surprises people and it is the honest answer at
current mini-model prices. The reasons to still choose Translator are latency
(150 ms vs 4 s), determinism, guaranteed language coverage, markup preservation, and
enforceable terminology via Custom Translator — **not** cost. If you switch the
comparison to `gpt-4o` rather than the mini model, the token price rises by roughly
an order of magnitude and Translator wins on cost as well.

The exam-relevant conclusion is the reasoning, not the arithmetic: name the cost
drivers (characters vs bidirectional tokens, output-token expansion in non-Latin
scripts), name the non-cost drivers, and state which constraint is binding.

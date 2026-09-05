# 01 — Apply language model text analysis

**Time:** 90–120 minutes · **Cost:** under $1 — Language, Translator, and Content Safety
are all consumption-priced, and the model calls are on `gpt-4o-mini`. Nothing here
bills by the hour.

Two different tools solve "understand this text": a **purpose-built Foundry Tool**
(Azure AI Language, Translator, Content Safety) and a **language model with a good
prompt**. The exam does not ask you to prefer one; it asks you to justify a choice.
This unit builds both paths for the same tasks so the trade-offs are visible rather
than theoretical.

By the end you will have:

- [ ] Extracted entities and key phrases with Azure AI Language
- [ ] Extracted the same information as schema-validated JSON with `response_format`
- [ ] Compared extractive and abstractive summarization against an LLM summary
- [ ] Run sentiment analysis with opinion mining, and asked a model for tone
- [ ] Detected and redacted PII, and detected PHI with Text Analytics for Health
- [ ] Screened text with Azure AI Content Safety
- [ ] Translated with Azure Translator using Entra ID, and with an LLM, and measured both
- [ ] Built a compliance-summarization prompt that is constrained enough to trust
- [ ] A decision table you can defend in an exam question

---

## Concepts

### The two families

| | Foundry Tools (Language, Translator, Content Safety) | Language model (`gpt-4o-mini`, `gpt-4o`) |
|---|---|---|
| Output shape | Fixed schema, documented categories, confidence scores | Whatever you ask for — free text or JSON |
| Determinism | Same input → same output | Varies unless you pin `temperature=0` and a schema |
| Latency | 100–400 ms typical for a single doc | 0.5–5 s, grows with output length |
| Cost driver | Per 1,000 text records (1,000 chars each) | Per token, input **and** output |
| Novel categories | Only what the service ships, unless you train a custom project | Anything you can describe in a sentence |
| Character offsets | Yes — exact `offset` and `length` for every entity | No. Models paraphrase and hallucinate spans |
| Compliance story | Documented categories, per-category confidence, auditable | You own the evaluation burden |
| Languages | Documented per feature | Broad, uneven, undocumented |

> **Exam note.** The single most reliable discriminator: **if you need exact
> character offsets, stable categories, or a defensible per-category confidence
> score, use Azure AI Language.** Redaction, compliance evidence, and anything
> feeding a downstream rules engine all fall on that side. If the category is
> novel, fuzzy, or changes per customer, use a model.

### The Language service, feature by feature

Everything below is reached through the **same** multi-service Foundry (AIServices)
resource — `AZURE_LANGUAGE_ENDPOINT` in your `.env` — and the same
`TextAnalyticsClient`.

| Feature | Method | Sync/LRO | Notes |
|---|---|---|---|
| Named entity recognition | `recognize_entities` | sync | Person, Location, Organization, DateTime, Quantity… with offsets |
| Entity linking | `recognize_linked_entities` | sync | Disambiguates to Wikipedia URLs |
| Key phrase extraction | `extract_key_phrases` | sync | Unranked noun phrases. Not topic modelling |
| Sentiment analysis | `analyze_sentiment` | sync | Document + per-sentence, four labels |
| Opinion mining | `analyze_sentiment(show_opinion_mining=True)` | sync | Target → assessment pairs |
| Language detection | `detect_language` | sync | Returns ISO code + confidence |
| PII detection | `recognize_pii_entities` | sync | Also returns `redacted_text` for free |
| PHI / health entities | `begin_analyze_healthcare_entities` | **LRO** | UMLS links, relations, assertions |
| Extractive summarization | `begin_extract_summary` | **LRO** | Selects existing sentences with rank |
| Abstractive summarization | `begin_abstract_summary` | **LRO** | Generates new sentences |
| Custom NER | `begin_recognize_custom_entities` | **LRO** | Needs a trained + deployed project |
| Custom classification | `begin_single_label_classify` / `begin_multi_label_classify` | **LRO** | Same |
| Many at once | `begin_analyze_actions` | **LRO** | Batches actions over one document set |

Two traps live in that table:

1. **Summarization, health, and every custom feature are long-running operations.**
   `begin_*` returns a poller; you call `.result()`. Synchronous code that expects an
   immediate answer is a wrong answer on the exam.
2. **Key phrase extraction is not topic extraction.** It returns noun phrases from a
   single document with no ranking across a corpus. "Give me the three themes in
   these 500 tickets" is an LLM job (or a clustering job), not `extract_key_phrases`.

### Extractive vs abstractive summarization

| | Extractive | Abstractive |
|---|---|---|
| Output | Verbatim sentences pulled from the source | New sentences the model wrote |
| Faithfulness | Guaranteed — the words are the document's | Can drift; must be evaluated |
| `max_sentence_count` | Yes | No — you get `sentence_count` on the summary |
| Good for | Legal, regulated, "show me the source" | Executive summaries, meeting notes |
| Trap | Reads choppily; no connective tissue | Fabrication risk in a compliance context |

Conversational summarization (`ConversationAnalysisClient` in
`azure-ai-language-conversations`) is a separate package aimed at transcripts, with
aspects such as `issue`, `resolution`, `chapterTitle`, and `narrative`. It is what
you point at a call-centre transcript; `begin_abstract_summary` is what you point at
a document.

### Structured output from a model

Free-text prompting plus `json.loads` is not "structured output". Two mechanisms
actually constrain the model:

| Mechanism | `response_format` | Guarantee |
|---|---|---|
| JSON mode | `{"type": "json_object"}` | Valid JSON. **No** schema conformance. You must still describe the shape in the prompt |
| Structured Outputs | `{"type": "json_schema", "json_schema": {..., "strict": True}}` | Valid JSON **matching your schema** — the decoder is constrained |

Structured Outputs requires `gpt-4o` / `gpt-4o-mini` (2024-08-06 or later) and API
version `2024-08-01-preview` or later. In strict mode every object needs
`"additionalProperties": false` and every property must appear in `required` —
optional fields are expressed as a union with `"null"`. Get this wrong and the API
rejects the schema at request time, which is exactly the behaviour you want.

> **Exam note.** "The application must never receive malformed JSON" →
> Structured Outputs with `strict: true`. "The application needs exact character
> positions of every social security number" → `recognize_pii_entities`. Do not mix
> them up.

### Sentiment, tone, safety, sensitivity — four different questions

| Question | Right tool | Why |
|---|---|---|
| Is this positive or negative? | Language `analyze_sentiment` | Four labels, per-sentence scores, cheap, stable |
| *What* is the customer unhappy about? | Opinion mining | Target/assessment pairs — "battery" → "terrible" |
| Is the tone hostile, sarcastic, escalating? | LLM | No Language feature models tone |
| Does this contain hate/self-harm/sexual/violent content? | Content Safety `analyze_text` | Four categories, severity 0/2/4/6 |
| Does this contain personal data? | Language `recognize_pii_entities` | Offsets + `redacted_text` |
| Does this contain clinical data? | Language `begin_analyze_healthcare_entities` | UMLS links, assertions |
| Is someone trying to jailbreak my prompt? | Content Safety **Prompt Shields** | Purpose-built for direct and indirect injection |

Sentiment and safety are commonly confused. Sentiment answers "how does the author
feel"; Content Safety answers "is this content harmful". A furious but polite
complaint is `negative` sentiment and severity `0` across every safety category.

Content Safety severities come back as `0, 2, 4, 6` on the text API (the full
0–7 scale is only exposed when you request it). The four categories are **Hate,
SelfHarm, Sexual, Violence**. Content Safety is *not* the same thing as the content
filter attached to your model deployment — the filter runs automatically on prompts
and completions; `analyze_text` is you calling the classifier on arbitrary text you
did not generate.

### Translator vs LLM translation

| | Azure Translator | LLM translation |
|---|---|---|
| Languages | 100+, documented, uniform quality bar | Strong for high-resource languages, unreliable for low-resource |
| Latency | ~100 ms | 1–5 s |
| Cost | Per character, roughly $10 / million characters | Per token, both directions — typically 5–20× more |
| Terminology control | **Custom Translator** models and **dynamic dictionaries** | Prompt instruction or glossary in context; not enforced |
| Tone / register | Limited (`textType`, profanity handling) | Excellent — "formal Japanese business register" just works |
| Context across sentences | Sentence-scoped | Whole-document context, resolves pronouns and ambiguity |
| Determinism | High | Low unless `temperature=0` |
| Detects source language | Yes, automatically | Yes, but you cannot get the confidence score |
| Preserves markup | Yes (`textType="html"`) | Fragile |

The honest rule: **Translator for volume, LLM for nuance.** A product catalogue with
80,000 SKUs goes through Translator with a Custom Translator model trained on your
glossary. A marketing headline that must land as a pun in German goes through an
LLM. A hybrid — Translator first, LLM post-edit on the 5% flagged low-confidence —
is the pattern real systems converge on.

> **Exam note.** "Must use approved terminology for regulated product names" →
> Custom Translator (or a dynamic dictionary for a handful of terms), not prompt
> instructions. Custom Translator needs parallel training data — at minimum 10,000
> aligned sentences for a full custom model; dictionary-only training works with
> far less but only enforces one-to-one term swaps.

### Customizing for a domain — the escalation ladder

Climb this in order. Each step costs more to build and maintain than the last.

| Step | Technique | When it stops being enough |
|---|---|---|
| 1 | Better prompt: role, explicit rules, negative examples | The model is right but inconsistent in format |
| 2 | Structured Outputs with a strict JSON schema | The model is well-formatted but wrong on domain terms |
| 3 | Few-shot: 3–8 examples in the prompt | Examples eat the context window, or edge cases keep appearing |
| 4 | Retrieval: put the policy/glossary in context | Latency or token cost is unacceptable |
| 5 | **Custom Language project** (custom NER / custom classification / CLU) | Your labels are fixed, you have labelled data, you want offsets and stable confidences |
| 6 | Fine-tuning the model | You have thousands of examples, and steps 1–5 genuinely failed |

Fine-tuning is last for a reason: it fixes *style and format*, not *knowledge*, it
pins you to a model version, and a fine-tuned deployment bills by the hour.

**Custom Language projects** are the step people skip and shouldn't. Custom NER,
custom text classification, and CLU (Conversational Language Understanding) are
trained in Language Studio from labelled data, versioned, and **deployed to a named
deployment** — and only then callable from the SDK. Each needs:

- a **project name** and a **deployment name**, both passed on every call;
- labelled data in Azure Storage (custom NER / classification) or authored in the
  portal (CLU);
- a train → evaluate → deploy cycle, with a confusion matrix you should actually read.

CLU is the odd one out: it does **intents and entities for utterances**, not
documents, and it is what sits behind an orchestration workflow that routes a user
between a QnA project, a CLU project, and other CLU projects.

---

## Portal walkthrough — a custom text classification project

You will not train this to completion (you need labelled data and ~30 minutes of
training), but walk the blades so the exam's screenshots are familiar.

1. Go to **https://language.cognitive.azure.com** and sign in. Pick your
   subscription and the Foundry resource from `.env`.
2. **Create new** → **Custom text classification**.
3. Connect storage:

   | Field | Value | Why |
   |---|---|---|
   | Storage account | your `AZURE_STORAGE_ACCOUNT` | Custom features read documents from Blob Storage — the service never holds your training data |
   | Blob container | `ai103-docs` | |
   | Enable identity | **On** | The Language resource uses its managed identity to read the container. Needs *Storage Blob Data Contributor* |

4. Project settings:

   | Field | Value |
   |---|---|
   | Name | `ai103-compliance-classifier` |
   | Classification type | **Single label classification** |
   | Primary language | English |
   | Multiple languages | off |

5. **Data labeling** — create labels (`policy`, `incident`, `marketing`), then label
   documents. Note the **Training set / Testing set** toggle on each document: this
   is where the split comes from, and choosing "Automatically split" instead is a
   perfectly good answer when you have no reason to control it.
6. **Training jobs** → **Start a training job**. Give the model a name. Pick
   **Automatically split** (80/20) unless you set the split by hand in step 5.
7. **Model performance** — read the per-class precision/recall and the confusion
   matrix. A class with high precision and low recall is under-labelled.
8. **Deploying a model** → **Add deployment** → name it `production`, pick the
   trained model. **The deployment name is what your SDK calls.** Same lesson as
   model deployments in unit 00.

Custom NER is the identical flow with entity labels instead of document labels.
CLU lives under **Conversational language understanding** and adds intents,
utterances, and a **testing deployment** you can chat with in the portal.

<details>
<summary>CLI alternative — inspect what exists</summary>

The custom-project lifecycle is REST/portal only; there is no first-class `az`
command group for it. What you can do from the CLI is confirm the resource and its
identity are wired correctly:

```powershell
# Confirm the Foundry resource exposes the Language endpoint
az cognitiveservices account show `
  -n $env:AZURE_AI_FOUNDRY_RESOURCE -g $env:AZURE_RESOURCE_GROUP `
  --query "{endpoint:properties.endpoint, kind:kind, identity:identity.principalId}"

# Grant the Language resource's managed identity read access to training data
$mi = az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE `
      -g $env:AZURE_RESOURCE_GROUP --query identity.principalId -o tsv
$sa = az storage account show -n $env:AZURE_STORAGE_ACCOUNT `
      -g $env:AZURE_RESOURCE_GROUP --query id -o tsv
az role assignment create --assignee-object-id $mi --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $sa

# Your own data-plane access to Language
$me = az ad signed-in-user show --query id -o tsv
$id = az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE `
      -g $env:AZURE_RESOURCE_GROUP --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role "Cognitive Services User" --scope $id
```

Projects themselves are managed through the
[Language authoring REST API](https://learn.microsoft.com/rest/api/language/),
which also gives you export/import for CI/CD.
</details>

---

## Lab

[lab.ipynb](lab.ipynb) runs every comparison in this README against the same three
documents, and prints latency and token counts next to each result so the
cost/latency columns above stop being abstract.

---

## Troubleshooting

**`Resource not found` from `TextAnalyticsClient`**
The endpoint is wrong. For a multi-service Foundry resource the Language endpoint is
`https://<resource>.cognitiveservices.azure.com/` — **not** the
`.services.ai.azure.com` project endpoint and not the OpenAI endpoint. Check
`AZURE_LANGUAGE_ENDPOINT` in `.env`.

**`401` / `403` from Language with a valid `az login`**
You need a data-plane role on the resource: **Cognitive Services User** (or
Contributor). Control-plane Contributor on the resource group does not grant it.
Wait five minutes after assigning — RBAC propagation is not instant.

**`(InvalidRequest) Invalid Request` on `begin_abstract_summary`**
Abstractive summarization is not available in every region, and it requires API
version `2023-04-01` or later. `azure-ai-textanalytics` 5.4.0 defaults to
`2023-04-01`, so the usual cause is region. `swedencentral` and `eastus2` are safe.

**`azure.core.exceptions.HttpResponseError: (InvalidDocument) Document text is empty`**
Every document in the batch must be non-empty. Filter before you send — one bad
document fails only that document, and you will find the error object mixed into the
results list, not raised.

**`response_format` rejected: `Invalid schema ... 'additionalProperties' is required to be supplied and to be false`**
Strict Structured Outputs requires `"additionalProperties": false` on **every**
object in the schema, including nested ones, and every property listed in
`required`.

**`401` from Translator with `DefaultAzureCredential`**
Entra ID against the global Translator endpoint needs *both* `resource_id` and
`region` — the token alone does not identify which resource to bill. Also assign
**Cognitive Services User**. The lab builds the resource ID for you.

**`Unauthorized` from Content Safety**
Content Safety needs its own role: **Cognitive Services User** works, and there is a
narrower *Cognitive Services Content Safety User* if you are being strict.

---

## Check yourself

[quiz.md](quiz.md) — 14 questions on tool selection, LRO vs sync, Structured
Outputs, PII, and Translator customization.

## Next

[02.2 — Implement speech solutions](../02_speech_solutions/README.md)

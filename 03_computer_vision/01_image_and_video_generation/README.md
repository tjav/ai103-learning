# 01 — Design and implement image- and video-generation solutions

**Time:** 90–120 minutes · **Cost:** $2–6, and this is the one unit where you can
genuinely overspend by accident

Everything up to now billed you per token, in fractions of a cent, and you could
run a cell a hundred times without noticing. That stops here.

**Image and video models bill per asset.** One image is a fixed price regardless of
how short your prompt was. One video is priced per second of output multiplied by
resolution. A loop that generates ten variants at high quality costs roughly a
hundred times a chat call, and a video job that renders for four minutes bills the
same whether or not anyone watches the result. Read the cost table below before you
run anything, and treat `quality="low"` as your default until the composition is
final.

There is a second cost: **quota and time**. Neither `gpt-image-1` nor `sora-2` is
pre-deployed by this course, and both are limited to a subset of regions. Part of
this unit is doing that deployment yourself — and, at the end, deleting it.

By the end you will have:

- [ ] Deployed `gpt-image-1` and `sora-2` into a region that supports them
- [ ] Generated images from text prompts and controlled size, quality, count, format, and background
- [ ] Explained where DALL·E 3 and GPT-image-1 differ, parameter by parameter
- [ ] Edited an image with a prompt, and then precisely with an alpha mask (inpainting)
- [ ] Generated a video with the async submit → poll → retrieve job pattern
- [ ] Used reference media as the first frame of a video, and remixed a generated clip
- [ ] Deleted both deployments

---

## Part 1 — Getting the models

### Why they are not already deployed

`00_setup` deployed `gpt-4o`, `gpt-4o-mini`, `o4-mini`, and
`text-embedding-3-small` because they are available almost everywhere and cost
almost nothing at rest. The generation models are different on all three counts.

| | `gpt-image-1` | `sora-2` |
|---|---|---|
| Status | **Preview** | **Preview** |
| Access application | Historically required; **no longer gated in most subscriptions** — check your catalog first | Not required |
| Deployment SKU | **Global Standard** (only option) | **Global Standard** (only option) |
| Default quota | ~5 images/minute per deployment | limited concurrent jobs |
| Availability in `swedencentral` (course default) | Supported | Supported |
| Other EU regions | `polandcentral` only | none at time of writing |

> **Residency note.** Both models are **Global Standard only** — there is no
> `DataZoneStandard` option for them. Unlike the chat models the course deploys in
> unit 00, image and video generation therefore carries **no data-residency
> guarantee**, even when the resource itself sits in an EU region. That is a real
> constraint to remember, and exactly the kind of detail the exam probes.

**Verify against your own subscription before following anything below.** Regional
and access rules for preview models change monthly, and a stale table is worse than
no table:

```powershell
az cognitiveservices model list --location $env:AZURE_LOCATION `
  --query "[?contains(model.name,'image') || contains(model.name,'sora')].{model:model.name, version:model.version, skus:model.skus[].name}" `
  -o table
```

If both models appear, deploy both onto the Foundry resource you already have and
**skip Steps 1 and 2** — you do not need a second resource. That is the case in
`swedencentral`, the course default. If `gpt-image-1` is absent — which it is in
most other EU regions — it is either not served there or still gated for your
subscription, and Steps 1 and 2 apply.

> Newer variants (`gpt-image-1.5`, `gpt-image-2`, and dated `sora-2` versions) may
> also be listed. Take the newest your catalog offers and set the deployment name to
> match what you put in `.env`.

> Check the published lists too:
> [Models and region availability](https://learn.microsoft.com/azure/ai-foundry/openai/concepts/models#image-generation-models).

### If you *do* need a second region

When the image model is unavailable where your project lives, you create a **second
Foundry resource in a supported region** for it.

This is not a lab artefact. It is the normal shape of a real Azure AI deployment —
a project connects to models across several resources and regions, because model
availability is regional and rarely lines up with where you would like your data to
sit.

> **Exam note.** Nothing forces a project's models to live on the project's own
> resource. A project reaches other resources through a **connection**, and models
> in another region are reached by calling that region's endpoint directly. When a
> question says "the model is not available in the customer's region," the answer is
> almost never "wait" and almost never "move everything" — it is "deploy in a
> supported region and connect to it."

### Step 1 — Apply for `gpt-image-1` access *(only if your catalog lacks it)*

1. Open [aka.ms/oai/gptimage1access](https://aka.ms/oai/gptimage1access).
2. Fill in the form using the subscription ID from your `.env`
   (`AZURE_SUBSCRIPTION_ID`) and a short, honest description of the use case
   ("self-study for the AI-102/AI-103 certification" is a legitimate answer).
3. Wait. Approval is not instant.

If you would rather not wait, or you are refused, the whole of Part 2 and Part 3
works against **`dall-e-3`** with two changes — a different `size` set and no
`images.edit()` support. The lab flags every cell that this affects. You will lose
inpainting, which is the most exam-relevant part, so apply if you can.

### Step 2 — Create a second Foundry resource for images *(only if Step 1 applied)*

1. **https://ai.azure.com** → **Management center** (bottom left) → **+ New
   resource** → **Azure AI Foundry resource**.
2. Fill in:

   | Field | Value | Why |
   |---|---|---|
   | Resource name | `<yourprefix>-ai103-img` | Must be globally unique |
   | Subscription | the same one | Quota is per subscription per region |
   | Resource group | `rg-ai103-lab` | Keeps teardown a single delete |
   | Region | a region your catalog query showed | Only some regions serve `gpt-image-1` |

3. **Create**. This resource holds only the image deployment; your project, agents,
   and chat models stay in `swedencentral`.

### Step 3 — Deploy `gpt-image-1`

1. In the Foundry portal, select the resource that serves the model — your **main**
   one if the catalog query found it there, otherwise the new one — then
   **Model catalog**.
2. Search `gpt-image-1`.
3. **Use this model** →

   | Field | Value | Why |
   |---|---|---|
   | Deployment name | `gpt-image-1` | Keeps `.env` simple. This is what your code calls. |
   | Deployment type | **Global Standard** | The only type offered for this model |
   | Capacity | leave at default | Default is ~5 images/minute; the lab needs far less |
   | Content filter | **DefaultV2** | Unit 03.3 replaces this with a multimodal filter |

4. **Deploy**. If you used a separate resource, copy its **Azure OpenAI endpoint**
   from the overview blade — `https://<yourprefix>-ai103-img.openai.azure.com` or
   the `services.ai.azure.com` form. If the model is on your main resource, you need
   no extra endpoint at all.

### Step 4 — Deploy `sora-2`

`sora-2` runs in `swedencentral`, so it goes on the Foundry resource you already have.

1. Switch back to your original resource → **Model catalog** → search `sora`.
2. **Use this model**:

   | Field | Value |
   |---|---|
   | Deployment name | `sora-2` |
   | Deployment type | **Global Standard** |
   | Content filter | **DefaultV2** |

3. **Deploy**. Then **Playgrounds** → **Video** and generate one five-second clip at
   480×480 to confirm it works. That costs well under a dollar and saves you
   debugging auth inside a notebook.

> The original `sora` was superseded by **`sora-2`**, which adds audio, image→video,
> and a genuine `remix` edit operation. The API surface differs between the two and
> the lab shows both, because the older job-style API is still what most existing
> code and exam material describes. Rollout is staged, so availability varies by
> subscription as well as region.

### Step 5 — Record it in `.env`

`01_connect_azure.ps1` already wrote `MODEL_IMAGE` and `MODEL_VIDEO`. Confirm they
match your **deployment names**, and add an endpoint override only if a model ended
up on a different resource:

```ini
MODEL_IMAGE=gpt-image-1
MODEL_VIDEO=sora-2
# Only needed if that model lives on a different resource:
AZURE_OPENAI_IMAGE_ENDPOINT=
AZURE_OPENAI_VIDEO_ENDPOINT=
```

Leave both endpoint variables empty when the deployments are on your main resource —
the lab falls back to `AZURE_OPENAI_ENDPOINT`.

### Step 6 — Grant yourself the data-plane role on the new resource

RBAC does not follow you across resources. The new image resource needs its own
assignment or every call returns 403.

```powershell
$me = az ad signed-in-user show --query id -o tsv
$id = az cognitiveservices account show -n <yourprefix>-ai103-img -g rg-ai103-lab --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
    --role "Cognitive Services OpenAI User" --scope $id
```

Wait about five minutes for propagation.

### Step 7 — Delete both deployments when you finish this unit

Written here, at the top, because the end of a lab is where good intentions go to
die.

```powershell
az cognitiveservices account deployment delete -g rg-ai103-lab `
    -n <yourprefix>-ai103-img --deployment-name gpt-image-1
az cognitiveservices account deployment delete -g rg-ai103-lab `
    -n <your-main-resource> --deployment-name sora
```

Standard and Global Standard deployments do **not** bill when idle, so this is about
freeing scarce regional quota rather than about money. It still matters: quota is a
shared subscription pool, and a forgotten image deployment is the reason the next
one fails. If you created the extra resource only for this unit, delete **and purge**
it — Cognitive Services accounts are soft-deleted and hold their name for 48 hours.

<details>
<summary>Script alternative for the whole of Part 1</summary>

```powershell
$rg   = "rg-ai103-lab"
$main = "<your-main-resource>"

# In swedencentral (the course default) both models live on your existing
# resource, so this is all you need:
az cognitiveservices account deployment create -g $rg -n $main `
    --deployment-name gpt-image-1 --model-name gpt-image-1 `
    --model-format OpenAI --sku-name GlobalStandard --sku-capacity 1

az cognitiveservices account deployment create -g $rg -n $main `
    --deployment-name sora-2 --model-name sora-2 `
    --model-format OpenAI --sku-name GlobalStandard --sku-capacity 1

# Only if your region does NOT serve gpt-image-1 — a second resource elsewhere:
$img = "<yourprefix>-ai103-img"
az cognitiveservices account create -n $img -g $rg -l polandcentral `
    --kind AIServices --sku S0 --custom-domain $img
az cognitiveservices account deployment create -g $rg -n $img `
    --deployment-name gpt-image-1 --model-name gpt-image-1 `
    --model-format OpenAI --sku-name GlobalStandard --sku-capacity 1
```

Model names and versions change — `sora` became `sora-2`, and `gpt-image-1.5` and
`gpt-image-2` now exist. Run
`az cognitiveservices model list -l $env:AZURE_LOCATION` to see what your region
currently serves, and omit `--model-version` to take the default. Read the portal
steps anyway — the exam shows the portal.
</details>

---

## Part 2 — Generating images

### GPT-image-1 vs DALL·E 3 — the table the exam wants

Both are image generation models on the same `images/generations` route, and their
parameter sets overlap just enough to be confusing.

| | **GPT-image-1** | **DALL·E 3** |
|---|---|---|
| Sizes | `1024x1024`, `1024x1536`, `1536x1024` | `1024x1024`, `1792x1024`, `1024x1792` |
| `quality` | `low`, `medium`, `high`, `auto` | `standard`, `hd` |
| `style` | **not supported** — describe style in the prompt | `natural` \| `vivid` (default `vivid`) |
| `n` | 1–10 | **1 only** |
| `response_format` | **not supported** — always base64 | `url` \| `b64_json` (URLs valid 60 min) |
| `output_format` | `png`, `jpeg` (`webp` per the OpenAI spec; Azure docs currently exclude it) | n/a |
| `output_compression` | 0–100, JPEG/WebP only | n/a |
| `background` | `auto`, `transparent`, `opaque` | n/a |
| Max prompt | 32,000 characters | 4,000 characters |
| Prompt rewriting | No | **Yes** — rewrites your prompt, returns `revised_prompt` |
| Editing / inpainting | **Yes** — `images.edit()` with `mask` | No |
| Status on Azure | Limited access preview | GA via REST |

Five of those are exam-grade traps:

1. **`style` does not exist on GPT-image-1.** Migrating DALL·E 3 code by changing
   the deployment name breaks on the first request. Style moves into the prompt.
2. **`response_format` does not exist on GPT-image-1** — every response is
   `b64_json` and there is no URL to fall back on. Code that reads `data[0].url`
   returns `None`.
3. **`n` is capped at 1 for DALL·E 3.** "Generate four variations in one call" is
   only possible on GPT-image-1.
4. **DALL·E 3 rewrites your prompt** before rendering and returns the rewrite in
   `revised_prompt`. If a question complains that output does not match the prompt,
   or that the same prompt is not reproducible, this is why. GPT-image-1 does not do
   this.
5. **Only GPT-image-1 can edit.** Any inpainting or mask question rules DALL·E out
   immediately.

> **Exam note.** DALL·E 3's URLs expire after **60 minutes**. If the requirement is
> to archive generated images, you must download the bytes — a design that stores
> the URL in a database is the wrong answer.

### The controls, and what each one is actually for

| Control | Purpose | Cost effect |
|---|---|---|
| `size` | Resolution and aspect ratio in one parameter — there is no separate aspect-ratio option | Higher with pixel count |
| `quality` | How much rendering effort. `low` is a draft | Roughly 10× from low to high |
| `n` | Variants per call | Strictly linear — `n=4` costs four images |
| `output_format` | Container: PNG (lossless, alpha) vs JPEG (small, no alpha) | None |
| `output_compression` | 0–100 for JPEG/WebP. Bandwidth, not quality of generation | None |
| `background` | `transparent` yields a real alpha channel — needs PNG or WebP | None |
| `moderation` | `auto` or `low` — strictness of the built-in image moderation | None |
| `partial_images` | 1–3 progressive previews when `stream=True` | Extra billed images on some models |

The workflow that keeps the bill sane: **iterate at `quality="low"`,
`size="1024x1024"`, `n=1` until the composition is right, then render once at
`high`.** Composition is decided by the prompt, not by the quality setting, so
paying for `high` while you are still rewording the prompt buys nothing.

`background="transparent"` with `output_format="jpeg"` is a contradiction — JPEG has
no alpha channel and the service rejects it.

### Prompting for images

Different discipline from prompting a chat model. Chat prompts constrain reasoning;
image prompts specify a picture. Name, in roughly this order:

1. **Subject** — one clear thing, described concretely.
2. **Composition** — framing, camera angle, what fills the frame.
3. **Lighting** — the single biggest lever on how "professional" it looks.
4. **Style** — "commercial product photography", "flat vector illustration". On
   GPT-image-1 this is the *only* place style can be expressed.
5. **Exclusions** — "no text, no props, no people". Reliable on GPT-image-1, which
   follows instructions much more literally than DALL·E did.

GPT-image-1's 32,000-character prompt limit means you can paste an entire brand
style guide into the prompt. That is a real technique, not a curiosity.

---

## Part 3 — Editing images

Three operations, and choosing between them is the skill:

| Operation | Call | Inputs | Preserves the original |
|---|---|---|---|
| **Prompt-driven edit** | `images.edit()` | `image` + `prompt` | Loosely — anything may change |
| **Inpainting** | `images.edit()` | `image` + `mask` + `prompt` | Everything outside the mask |
| **Multi-reference composition** | `images.edit()` | `image=[f1, f2, …]` + `prompt` | Neither — it composes a new scene |

### The mask rules — this is where people get stuck

A mask is a **PNG with exactly the same pixel dimensions as the source**, and the
model repaints the pixels where the mask's **alpha channel is 0** (fully
transparent). Opaque pixels are preserved.

Consequences worth stating explicitly, because each is a common failure:

- **The RGB values in the mask are ignored.** A black-and-white bitmap with no alpha
  channel edits nothing. "Paint the area black" is the intuition, and it is wrong —
  it must be *transparent*, not black.
- **Transparent means editable.** Backwards from most people's first guess.
- **Dimensions must match exactly.** A 1024×1024 mask on a 1024×1536 source is a
  400.
- **The prompt describes the finished image**, not the patch. The model reads the
  unmasked pixels as context and the prompt as the target.

`input_fidelity="high"` asks the model to preserve the input's style and features —
notably faces — more aggressively. It costs latency, not extra images, and is not
supported on `gpt-image-1-mini`.

> **Exam note.** "Replace only the sky, leaving the building untouched" → mask with
> the sky transparent. "Restyle the whole photo as a watercolour" → prompt-driven
> edit, no mask. "Preserve the person's face while changing the background" → mask
> plus `input_fidelity="high"`. Recognising which of the three a scenario needs is
> the whole question.

---

## Part 4 — Generating video

### The async job pattern

There is no synchronous video API and there will not be one — renders take one to
five minutes. Every Sora integration is these three calls:

```
POST  {endpoint}/openai/v1/video/generations/jobs?api-version=preview
      -> { "id": "...", "status": "queued" }

GET   {endpoint}/openai/v1/video/generations/jobs/{job_id}?api-version=preview
      -> poll until status is succeeded | failed | cancelled

GET   {endpoint}/openai/v1/video/generations/{generation_id}/content/video?api-version=preview
      -> MP4 bytes
```

Note the change of identifier on the third call: you poll a **job id**, but you
download using the **generation id** found inside the finished job's `generations`
array. A job with `n_variants=3` yields three generation ids.

Everything about your architecture follows from the asynchrony:

- The request that **starts** a render must not be the request that **serves** the
  user. Return the job id immediately; poll from the client, or run the job on a
  queue worker and notify when it lands.
- Poll every 5–10 seconds. Faster polling earns 429s and changes nothing.
- `failed` is a **normal outcome**, not an exception — content filtering rejects
  both prompts and rendered frames. Read `failure_reason` and show the user
  something useful.
- **Generated videos expire.** Jobs are retrievable for about 24 hours. If you need
  the asset, download it to your own storage. Storing the service URL is the wrong
  design, exactly as with DALL·E 3.
- Concurrency is limited (two simultaneous jobs by default), so a queue is not
  optional at any scale.

### Controls

| Sora (job API) | Sora 2 (v1 client) | Notes |
|---|---|---|
| `n_seconds` — integer | `seconds` — `'4'`, `'8'`, `'12'` | Sora 2 supports 1–20 s; billing is per second |
| `width` + `height` | `size` — e.g. `'1280x720'` | Sora 2 sizes: 480×480, 480×854, 854×480, 720×720, 720×1280, 1280×720, 1080×1080, 1080×1920, 1920×1080 |
| `n_variants` | one job per call | 1080p: variants disabled; 720p: max 2; otherwise max 4 |
| `inpaint_items` + `crop_bounds` | `input_reference` | Reference media. Sora 2 requires the reference to match `size` exactly |
| resubmit with the clip | `videos.remix(video_id, prompt)` | Editing an existing clip |
| — | audio in output | Sora 2 only |

Both are **preview**. Sora 2 blocks photorealistic depictions of real people and
recognisable IP outright — a policy limit, not a filter you can tune.

### Editing generated video

Sora 2's `remix` makes a targeted change to an existing generation rather than
re-rendering from scratch, which preserves the parts you liked. **Change one thing
per remix.** Stacking several instructions into one remix degrades fidelity to the
source and you lose what you were trying to keep.

The workflow that actually works in production moves precision to where you have
it:

1. **Generate a still** with `gpt-image-1` at `quality="low"` and iterate — cheap,
   fast, and you control the frame completely.
2. **Inpaint** whatever is still wrong. Frame 0 is now exactly right.
3. **Animate** it by passing the still as the reference/first frame.
4. **Remix** for one narrow change at a time.
5. **Post-process deterministically** — trim, concatenate, overlay a watermark —
   with ffmpeg.

The last point is a general principle: never ask a generative model to do something
a codec can do. It is slower, more expensive, and non-deterministic.

---

## What this costs

Neither image nor video responses carry a `usage` object, because they are not
billed per token. You have to count assets yourself.

| Action | Rough unit |
|---|---|
| Image, `low`, 1024×1024 | cents |
| Image, `high`, 1536×1024 | ~10× the above |
| `n=4` | exactly 4× |
| Video | per second of output × resolution; 5 s at 480×480 is well under $1, 20 s at 1080p is not |
| A blocked prompt | free — nothing is rendered |
| A blocked **output** | **billed** — the image rendered, then failed the filter |

That last row is the one people are surprised by. Build the same guard rails you
would for any per-unit cost: a per-request cap, a per-session counter, and a hard
refusal rather than a retry loop.

---

## The lab

[lab.ipynb](lab.ipynb) — generation, the full control surface, prompt-driven
editing, mask-based inpainting, a content-filter rejection, and the complete video
job lifecycle. Every cell that spends money says so in the markdown above it.

Outputs are written to `lab_output/`, which is already git-ignored.

---

## Troubleshooting

**`gpt-image-1` does not appear in the model catalog**
Either your access application has not been approved, or the resource is in an
unsupported region. Both are silent — the model is simply absent. Check the region
first; it is the more common cause.

**`404 DeploymentNotFound` on a name you can see in the portal**
You are calling the wrong endpoint. The image deployment is on the second resource,
so it needs `AZURE_OPENAI_IMAGE_ENDPOINT`, not `AZURE_OPENAI_ENDPOINT`. This is the
single most common failure in this unit.

**`403` from the image resource although chat works**
RBAC is per resource. Assign *Cognitive Services OpenAI User* on the new resource
too, and wait five minutes.

**`'ImagesResponse' object has no attribute 'url'` / `data[0].url` is `None`**
GPT-image-1 always returns base64. Read `data[0].b64_json` and
`base64.b64decode` it. `response_format` is not an accepted parameter on this model.

**`400 Invalid value: 'transparent'`**
`background="transparent"` requires `output_format="png"` or `"webp"`. JPEG has no
alpha channel.

**The mask changed nothing**
The mask has no alpha channel, or you painted the region black instead of making it
transparent. Convert to `RGBA` and set alpha to 0 where you want repainting. Verify
by counting pixels with alpha 0 before you send it.

**`400` on a masked edit that looks correct**
Mask dimensions must equal the source's exactly. Re-open both and compare `.size`.

**`Your task failed as a result of our safety system`**
The **prompt** was blocked; nothing rendered and you were not billed.

**`Generated image was filtered as a result of our safety system`**
The prompt passed, the image rendered, and the **output** was blocked. You were
billed. Unit 03.3 covers tuning these filters.

**Video job stuck in `queued` for several minutes**
Normal. Renders take one to five minutes and queueing adds to that. Do not poll
faster; you will just collect 429s. Only treat it as an error after ~10 minutes.

**Video job returns `failed` with no obvious reason**
Read `failure_reason`. The usual causes are content policy — recognisable people,
branded content, or photorealistic depictions that Sora 2 refuses categorically.

**`429 Too Many Requests` on image generation**
Default image quota is around five images per minute per deployment, which a loop
exhausts instantly. Back off, or raise capacity in **Management center → Quota**.

---

## Check yourself

[quiz.md](quiz.md) — 15 questions on model differences, generation controls, mask
semantics, and the async video pattern.

## Next

[03.2 — Design and implement multimodal understanding workflows](../02_multimodal_understanding/README.md)

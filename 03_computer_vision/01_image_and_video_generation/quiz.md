# 03.1 — Image and video generation: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** You migrate an application from a `dall-e-3` deployment to `gpt-image-1`.
The code reads `response.data[0].url` and passes `response_format="url"`. What
happens?

- A. Nothing — both parameters are supported and ignored
- B. `response_format` is rejected as an unknown parameter, and `url` is never populated
- C. The image is returned as a URL that expires after 24 hours
- D. The call succeeds but the image is downscaled to 512×512

---

**2.** A designer asks for the same prompt rendered "in a more natural,
less saturated style" on `gpt-image-1`. What do you change?

- A. Set `style="natural"`
- B. Set `quality="standard"`
- C. Describe the style in the prompt text
- D. Set `moderation="low"`

---

**3.** You need a product image with a transparent background for compositing onto
a web page. Which two settings are required? Choose two.

- A. `background="transparent"`
- B. `output_format="jpeg"`
- C. `output_format="png"`
- D. `quality="high"`
- E. `response_format="b64_json"`

---

**4.** You are inpainting with `images.edit()`. Which describes a valid mask?

- A. A JPEG the same size as the source, white where the model should paint
- B. A PNG the same size as the source, fully transparent where the model should paint
- C. A PNG of any size, black where the model should paint
- D. A grayscale bitmap half the resolution of the source, for performance

---

**5.** Your masked edit changes the entire image instead of only the intended
region. What is the most likely cause?

- A. `quality` is set too low
- B. The mask has no alpha channel, or the transparent region is inverted
- C. `n` is greater than 1
- D. `input_fidelity` is not set to `high`

---

**6.** A retoucher needs a person's face preserved exactly while the background is
replaced. Which parameter most directly helps?

- A. `moderation="low"`
- B. `partial_images=3`
- C. `input_fidelity="high"`
- D. `output_compression=100`

---

**7.** Which is **not** a valid way to reduce the cost of an image-generation
feature?

- A. Iterate on prompts at `quality="low"` and render finals at `high`
- B. Reduce `n` from 4 to 1
- C. Use a smaller `size`
- D. Set `output_compression=20` to reduce the amount billed

---

**8.** Your web API exposes `POST /videos` which calls Sora and returns the MP4 in
the response body. Reviewers reject the design. Why?

- A. Sora only supports batch deployments
- B. Video generation is asynchronous and can take minutes; the handler must return a job ID and let the client poll or be notified
- C. MP4 cannot be returned over HTTP without chunked encoding
- D. The video model does not support Entra ID authentication

---

**9.** Put the Sora job API calls in order.

1. `GET /openai/v1/video/generations/{generation_id}/content/video`
2. `POST /openai/v1/video/generations/jobs`
3. `GET /openai/v1/video/generations/jobs/{job_id}`

- A. 1, 2, 3
- B. 2, 3, 1
- C. 3, 2, 1
- D. 2, 1, 3

---

**10.** A Sora job returns `status: "failed"`. What should the application do?

- A. Retry immediately with the same prompt — failures are transient
- B. Raise an unhandled exception; this state should not occur
- C. Read `failure_reason`, surface it to the user, and treat content-filter rejections as a normal outcome
- D. Fall back to `gpt-image-1` and return a still image

---

**11.** A brand needs a 6-second clip that opens on an exact, art-directed shot of
their packaging. Which workflow gives the most control over frame 0?

- A. Write a very long, detailed Sora prompt and regenerate until it is right
- B. Generate and inpaint the still with `gpt-image-1`, then pass it to Sora as the reference/first frame
- C. Generate the video, then use `remix` repeatedly on the first frame
- D. Generate at 1920×1080 so there is more detail to work with

---

**12.** You want to change only the colour grade of a completed Sora 2 video.
Which is the correct and cheapest approach?

- A. `client.videos.create()` with the original prompt plus the colour instruction
- B. `client.videos.remix(video_id=..., prompt="Shift the palette to cool blue.")`
- C. Download it and re-upload it as `input_reference`
- D. Set `seconds` to the same value and regenerate

---

**13.** `gpt-image-1` is not available in the region where your Foundry project
lives. What is the appropriate design response?

- A. Recreate the project and all its resources in a region that has the model
- B. Use `dall-e-3` instead
- C. Create a second Foundry resource in a supported region and call the image deployment there; the project stays put
- D. Wait for the model to become available in your region

---

**14.** Which two statements about Sora reference media are true? Choose two.

- A. On Sora 2, the `input_reference` image resolution must match the requested `size` exactly
- B. Reference images are optional and can be any resolution — the service rescales them
- C. On the Sora job API, `crop_bounds` selects which part of the reference image to use, as fractions from each edge
- D. Reference media replaces the prompt; you cannot supply both
- E. `frame_index` must always be 0

---

## Answers

**1 — B.** GPT-image models never return a URL; they always return `b64_json`, and
`response_format` is not an accepted parameter for them, so it is an error rather
than a silently ignored field. This is the single most common breakage when
migrating from DALL·E. A is wrong because the parameter is rejected, not ignored.
C describes DALL·E 3 behaviour. D invents a downscale that does not exist.

**2 — C.** `style` (`vivid` / `natural`) was a DALL·E 3 parameter and does not
exist on GPT-image. Style is expressed in the prompt. B confuses `quality`, which
on GPT-image takes `low` / `medium` / `high` / `auto` and controls rendering
effort, not aesthetic. D changes moderation strictness, which has nothing to do
with appearance.

**3 — A and C.** Transparency needs an alpha channel, which PNG (or WebP) has and
JPEG does not — so B is not merely suboptimal, it is rejected. D affects rendering
effort, not transparency. E is not a valid parameter for GPT-image at all.

**4 — B.** The mask must be a PNG with the same dimensions as the source, and the
editable region is defined by **alpha = 0**. A is wrong twice: JPEG has no alpha,
and white pixels mean nothing. C fails the dimension requirement and the alpha
requirement. D fails the dimension requirement.

**5 — B.** The model repaints transparent pixels only. If the mask is fully opaque
the edit degenerates toward an unmasked prompt-driven edit; if the alpha is
inverted, the wrong region is repainted. A and C do not affect which pixels are
editable. D affects fidelity to the source style, not the mask geometry.

**6 — C.** `input_fidelity="high"` makes the model work harder to preserve the
style and features of the input, and faces specifically. It costs latency, not
extra images, and is unsupported on `gpt-image-1-mini`. B streams partial renders
— a latency-perception feature. A and D are unrelated.

**7 — D.** `output_compression` only affects the encoded file size; billing is per
image, driven by size and quality. A, B and C are all genuine levers: quality can
be roughly an order of magnitude, `n` is linear, and larger sizes cost more.

**8 — B.** There is no synchronous video API. A render can take minutes, so the
request that starts it must not be the request that serves the user — return the
job ID, then poll or notify. The other options describe constraints that do not
exist.

**9 — B.** Submit the job, poll the job until it reaches a terminal state, then
fetch the content for the generation ID found in the succeeded response. Note that
the download URL is keyed on the **generation** ID, not the job ID — jobs can
produce several generations when `n_variants` > 1.

**10 — C.** `failed` is an expected terminal state, most often because content
filtering rejected the prompt or the rendered frames. Blind retries (A) waste money
on a deterministic rejection. B turns a normal outcome into an outage. D may be a
reasonable product decision but is not the handling the question asks about.

**11 — B.** Precise visual control belongs in the image model. Generate and inpaint
the still until it is exactly right — cheap and fully controllable — then animate
it. A is expensive trial and error; prompt length does not buy frame-level control.
C misunderstands remix, which alters the whole clip. D raises cost without
improving control.

**12 — B.** Remix reuses the source video's structure, motion and framing and
applies one narrow change — cheaper and far more faithful than regenerating. Keep
to one clearly articulated adjustment per remix; stacking instructions degrades
fidelity. A and D discard the original entirely. C is the Sora 1 idiom and still
regenerates.

**13 — C.** Regional model availability is solved by putting the model where it
exists and connecting to it, not by relocating the whole solution. The project
endpoint, agents, indexes and connections stay where they are; only the inference
call crosses regions. A is disproportionate. B is impossible — DALL·E 3 was retired
on 4 March 2026 and existing deployments are non-functional. D is not a design.

**14 — A and C.** Sora 2 requires the `input_reference` image resolution to match
the requested `size` exactly — mismatches are a 400, not a rescale, which rules out
B. On the job API, `crop_bounds` gives crop distances from each edge as fractions
of the image dimensions. D is wrong: prompt and reference are used together, and
the prompt drives the motion. E is wrong: `frame_index` defaults to 0 but can place
the reference at any frame, which is how you extend or continue a clip.

---

## Lab exercise solutions

### 1. Quality is not composition

```python
for q, size in (('high', '1024x1024'), ('high', '1536x1024')):
    r = images.generate(model=IMAGE_MODEL, prompt=PROMPT, n=1,
                        size=size, quality=q, output_format='png')
    save_result(r, f'mug_{q}_{size}')
```

What changes between `low` and `high` is micro-detail: material texture, edge
cleanliness, specular highlights, legibility of small features. What does **not**
change is the composition — camera angle, framing, object placement and colour
scheme are driven by the prompt and the seed, not by rendering effort. That is the
whole argument for the two-phase workflow: settle composition in the cheap loop,
because paying 10× per iteration buys you nothing while you are still arguing about
what should be in the frame. Render `high` once, at the end.

### 2. A precise mask

```python
from PIL import Image as PILImage, ImageDraw

src = PILImage.open(base_path).convert('RGBA')
w, h = src.size

mask = PILImage.new('RGBA', (w, h), (0, 0, 0, 255))     # preserve everything
r = min(w, h) // 4
ImageDraw.Draw(mask).ellipse(
    [w // 2 - r, h // 2 - r, w // 2 + r, h // 2 + r],
    fill=(0, 0, 0, 0),                                   # alpha 0 = editable
)
circle_mask = OUT / 'circle_mask.png'
mask.save(circle_mask)

# Validate before spending money on a request that will 400.
assert mask.size == src.size, f'mask {mask.size} != source {src.size}'
assert mask.mode == 'RGBA', f'mask mode {mask.mode}, need RGBA'
assert any(px[3] == 0 for px in mask.getdata()), 'mask has no transparent pixels'

with open(base_path, 'rb') as i, open(circle_mask, 'rb') as m:
    out = images.edit(model=IMAGE_MODEL, image=i, mask=m,
                      prompt='A small potted succulent standing where the mug was, '
                             'same lighting and backdrop.',
                      size='1024x1024', quality='low')
save_result(out, 'mug_circle_inpaint')
```

The three asserts are not decoration. Dimension mismatch, a missing alpha channel
and an all-opaque mask are the three ways this call fails, and all three are
detectable locally for free.

### 3. A reusable job runner

```python
import time, pathlib, requests


def generate_video(prompt, seconds=5, width=480, height=480,
                   poll_every=5, timeout=600, out_dir=OUT):
    """Submit, poll, download. Returns a Path, or None if the job did not succeed."""
    hdrs = {
        'Authorization': f"Bearer {credential().get_token('https://cognitiveservices.azure.com/.default').token}",
        'Content-Type': 'application/json',
    }
    base = f'{VIDEO_ENDPOINT}/openai/v1/video/generations'

    r = requests.post(f'{base}/jobs?api-version=preview', headers=hdrs, timeout=60, json={
        'model': VIDEO_MODEL, 'prompt': prompt,
        'width': width, 'height': height, 'n_seconds': seconds, 'n_variants': 1,
    })
    r.raise_for_status()
    job_id = r.json()['id']

    deadline, state, status = time.time() + timeout, {}, None
    while status not in ('succeeded', 'failed', 'cancelled'):
        if time.time() > deadline:
            print(f'{job_id}: timed out after {timeout}s (job may still be running)')
            return None
        time.sleep(poll_every)          # never spin faster than this
        state = requests.get(f'{base}/jobs/{job_id}?api-version=preview',
                             headers=hdrs, timeout=60).json()
        status = state.get('status')

    if status != 'succeeded':
        print(f'{job_id}: {status} — {state.get("failure_reason", "no reason given")}')
        return None

    gen_id = state['generations'][0]['id']
    mp4 = requests.get(f'{base}/{gen_id}/content/video?api-version=preview',
                       headers=hdrs, timeout=300)
    mp4.raise_for_status()
    path = pathlib.Path(out_dir) / f'{gen_id}.mp4'
    path.write_bytes(mp4.content)
    return path
```

Three details worth defending in an interview: all three terminal states are
handled rather than only `succeeded`; timeout returns `None` instead of raising,
because the job is still running server-side and the caller may want to resume;
and the token is fetched per call so a long-running worker never uses an expired
one.

### 4. Cost guard

```python
PRICE = {                       # USD per image — check the pricing page for real values
    ('1024x1024', 'low'):    0.011,
    ('1024x1024', 'medium'): 0.042,
    ('1024x1024', 'high'):   0.167,
    ('1024x1536', 'low'):    0.016,
    ('1024x1536', 'high'):   0.25,
    ('1536x1024', 'low'):    0.016,
    ('1536x1024', 'high'):   0.25,
}

_spent = 0.0


def generate_guarded(prompt, budget=1.00, *, size='1024x1024', quality='low', n=1, **kw):
    global _spent
    unit = PRICE.get((size, quality))
    if unit is None:
        raise ValueError(f'no price for {size}/{quality} — refusing to guess')
    cost = unit * n
    if _spent + cost > budget:
        raise RuntimeError(
            f'refusing: this call costs ~${cost:.3f}, session total would be '
            f'${_spent + cost:.2f} against a ${budget:.2f} budget'
        )
    result = images.generate(model=IMAGE_MODEL, prompt=prompt, n=n,
                             size=size, quality=quality, **kw)
    _spent += cost
    print(f'spent ~${cost:.3f}, session total ~${_spent:.2f}')
    return result
```

The important design choice is raising on an **unknown** `(size, quality)` pair
rather than defaulting to zero. A cost guard that silently prices unfamiliar
combinations at nothing is worse than no guard, because it gives you confidence you
have not earned. In production this counter belongs in a shared store, not a module
global, and it should be checked per tenant as well as per process.

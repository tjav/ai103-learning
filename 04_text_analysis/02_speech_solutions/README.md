# 02 — Implement speech solutions

**Time:** 90–120 minutes · **Cost:** under $2. Speech is per-hour-of-audio and the
lab uses seconds of it. `gpt-4o-audio-preview` bills audio tokens at a
noticeably higher rate than text — the audio section is the expensive part, and it
is small.

Voice is the modality where architecture choices are visible to the user. A
200-millisecond difference in turn-taking latency is the difference between a
conversation and an interrogation. This unit builds both the classic cascaded
pipeline and the native speech-to-speech alternative, and makes you measure the gap.

By the end you will have:

- [ ] Synthesized speech to a `.wav` file, with and without SSML
- [ ] Recognized speech once, and continuously, from a file
- [ ] Improved recognition of domain terms with a phrase list
- [ ] Sent audio directly to an audio-capable model and reasoned over it
- [ ] Translated speech with `TranslationRecognizer` and with an LLM
- [ ] Measured cascaded STT → LLM → TTS against native speech-to-speech
- [ ] A defensible answer to "why not just use the Realtime API for everything"

Everything writes to `lab_output/`, which is git-ignored. **No microphone is
required** — the lab synthesizes its own audio first and then recognizes from that
file.

---

## Concepts

### Authentication: the one place a key is defensible

The Speech SDK is the awkward service in this course. Here is the honest state of it:

| Object | Entra ID support | How |
|---|---|---|
| `SpeechRecognizer`, `ConversationTranscriber` | Yes | `SpeechConfig(token_credential=cred, endpoint=custom_domain_endpoint)` |
| `TranslationRecognizer` | Yes | `SpeechTranslationConfig(token_credential=cred, endpoint=...)` |
| `SpeechSynthesizer` and everything else | Via authorization token | `SpeechConfig(auth_token="aad#{resourceId}#{token}", region=...)` |
| Simplest path | — | `SpeechConfig(subscription=key, region=region)` |

Two things follow.

**First, Entra ID for recognition requires a custom domain** on the Foundry
resource. The default `*.cognitiveservices.azure.com` name issued at creation is
already a custom domain for AIServices resources; a plain Speech resource created
without one must have it set, and **the custom domain name cannot be changed once
set**:

```powershell
az cognitiveservices account update -n <resource> -g <rg> --custom-domain <name>
```

**Second, the `aad#` token format is real and specific.** For the paths that do not
take a `TokenCredential`, you construct the authorization token yourself:

```
aad#{resourceId}#{entraAccessToken}
```

The `aad#` prefix and the `#` separator are both required. `resourceId` is the full
ARM resource ID of the Foundry resource. The Entra token is scoped to
`https://cognitiveservices.azure.com/.default`. That token expires — the SDK exposes
`speech_config.authorization_token` as a settable property so you can refresh it on
a long-lived recognizer without rebuilding the object.

Roles: **Cognitive Services Speech User** (data plane) or **Cognitive Services
Speech Contributor** (also lets you manage custom models).

`AZURE_SPEECH_KEY` exists in `.env` so the lab runs even where your tenant blocks
one of the above. Use it as a fallback, understand why it exists, and do not ship
it.

> **Exam note.** "Keyless authentication for Speech" is answered by
> `TokenCredential` + custom-domain endpoint for recognition, and the
> `aad#resourceId#token` authorization token elsewhere. Answers that say "Speech
> does not support Entra ID" are wrong; answers that say "just pass
> `DefaultAzureCredential` everywhere" are also wrong.

### Speech to text: three shapes

| Shape | API | Use when |
|---|---|---|
| **Single utterance** | `recognize_once_async()` | One command, one question. Stops at the first silence, or at 15 seconds |
| **Continuous** | `start_continuous_recognition_async()` + event handlers | Dictation, meetings, anything longer than a sentence |
| **Batch** | Batch transcription REST API | Files already in Blob Storage, no latency requirement, cheapest per hour |

`recognize_once_async` is the one that catches people. It returns after the first
detected end-of-speech **or** 15 seconds, whichever comes first. Feeding it a
two-minute recording gives you the first sentence and no error — the result reason
is `RecognizedSpeech` and everything looks fine. If the audio is longer than one
utterance, you need continuous recognition.

Continuous recognition is event-driven. The events you must know:

| Event | Fires when |
|---|---|
| `recognizing` | Partial hypothesis, updated as the user speaks — this is what you render live |
| `recognized` | A final result for one utterance. `reason` is `RecognizedSpeech` or `NoMatch` |
| `session_started` / `session_stopped` | Session boundaries |
| `canceled` | Error or end of stream. **Check `cancellation_details.reason`** — auth failures land here, not as exceptions |

Auth failures surfacing as a `canceled` event rather than a raised exception is the
single most confusing thing about this SDK. A wrong key produces a silent recognizer
that returns nothing unless you wired up `canceled`.

### Text to speech

`SpeechSynthesizer` with three output destinations:

| Destination | `AudioOutputConfig` | Use |
|---|---|---|
| Speakers | `use_default_speaker=True` | Local demo |
| File | `filename="out.wav"` | Batch, testing, no audio device |
| Memory / stream | omit `audio_config` (pass `None`) | Servers — you get `result.audio_data`, or a `PullAudioOutputStream` |

**For agents, streaming is the whole game.** Passing `audio_config=None` and reading
`result.audio_data` still waits for the full synthesis. To start playing before
synthesis finishes you use the streaming result — first-byte latency drops from
"length of the utterance" to a few hundred milliseconds, and that is what makes a
voice agent feel responsive. Set the output format explicitly
(`set_speech_synthesis_output_format`); the default is not necessarily what your
playback path wants, and mismatched sample rates are a classic source of
chipmunk audio.

Voice names follow `<locale>-<Name>Neural`, e.g. `en-GB-SoniaNeural`,
`ja-JP-NanamiNeural`. Multilingual voices (`en-US-AvaMultilingualNeural` and family)
speak many languages from one voice identity — useful when an agent must switch
language mid-conversation without changing apparent speaker.

### SSML — the controls that matter

Plain text gets you a default reading. SSML gets you control:

| Element | Controls | Typical use |
|---|---|---|
| `<prosody rate pitch volume>` | Speed, pitch, loudness | Slow down a confirmation number |
| `<break time="500ms"/>` | Pauses | Separating list items, thinking pauses |
| `<say-as interpret-as="...">` | Digits, date, telephone, currency | `"SO-4471"` read as letters and digits, not a word |
| `<phoneme alphabet="ipa" ph="...">` | Pronunciation | Brand names, drug names, surnames |
| `<lexicon uri="..."/>` | A reusable pronunciation dictionary | Many terms, applied consistently |
| `<mstts:express-as style="..." styledegree>` | Speaking style — cheerful, empathetic, newscast | Support agents matching user affect |
| `<voice name="...">` | Voice switching mid-document | Dialogue, multi-speaker readouts |
| `<lang xml:lang="...">` | Language switching | Multilingual voices |

The SSML root needs the namespace, and `mstts:` elements need theirs:

```xml
<speak version="1.0"
       xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts"
       xml:lang="en-GB">
  <voice name="en-GB-SoniaNeural">...</voice>
</speak>
```

`xml:lang` on `<speak>` is required, and the voice must exist in the region you are
calling. A missing namespace or a bad voice name gives you a `canceled` result with
`reason=Error`, not an exception.

> **Exam note.** "The agent must read an order reference as individual characters"
> → `<say-as interpret-as="characters">`. "The agent must pronounce a drug name
> correctly" → `<phoneme>` for one term, `<lexicon>` for a catalogue of them.
> "The agent must sound sympathetic" → `<mstts:express-as style="empathetic">`,
> which only works on voices that support styles.

### Customization: three rungs, very different prices

| Rung | What it is | Cost / gating | Use when |
|---|---|---|---|
| **Phrase list** | A runtime hint list attached to a recognizer via `PhraseListGrammar` | Free, zero setup, applies to that recognizer only | A bounded set of terms — product names, menu options, contact names |
| **Custom Speech** | A trained acoustic/language model built in Speech Studio from your audio + transcripts, deployed to an endpoint | Training and hosting cost; a deployed endpoint bills while it exists | Domain jargon, accents, noisy channels, telephony audio |
| **Custom Neural Voice** | A synthetic voice cloned from a specific speaker | **Limited Access** — application, approval, and explicit recorded consent from the voice talent | Brand voice, and only with a governance story |

Reach for a phrase list first. It costs nothing, needs no data, and fixes most
"the recognizer keeps mangling our product names" complaints. Custom Speech is the
answer when the *audio* is the problem — accents, background noise, 8 kHz telephony
— because a phrase list cannot fix acoustics.

**Custom Neural Voice is gated.** It sits under Microsoft's Limited Access policy:
you register for access, describe the use case, and provide documented consent from
the voice talent including a recorded consent statement. Custom Neural Voice Lite
lowers the data bar but not the approval bar. An exam answer that has a team cloning
a celebrity voice next week is wrong on process, not just on ethics.

Custom Speech, once trained, is used by pointing the SDK at the deployment:
`speech_config.endpoint_id = "<custom endpoint id>"`. That is the whole integration —
same as swapping a model deployment name.

### Audio as a model input, and the two architectures

There are now three ways to get from a person talking to an agent replying:

| Architecture | Path | Latency to first audio | Prosody | Cost | Control |
|---|---|---|---|---|---|
| **Cascaded** | Speech SDK STT → LLM → Speech SDK TTS | ~1.5–3 s | Lost — the model only sees text | Lowest | Highest: you can inspect and edit the transcript, apply Content Safety, log everything |
| **Audio-in chat** (`gpt-4o-audio-preview`, preview) | Audio → `/chat/completions` → text and/or audio | ~1–3 s | Preserved on input | Higher — audio tokens | Turn-based, not streaming |
| **Realtime API** (preview) | Bidirectional WebSocket, speech in and speech out | ~300–800 ms | Preserved both ways | Highest | Lowest: no intermediate text to gate |

The cascaded pipeline throws information away at the first step. Tone, hesitation,
emphasis, emotion, and background context all die in the transcript — "fine." and
"fine!" and a sarcastic "fine…" are the same three characters. Audio-capable models
keep that signal.

`gpt-4o-audio-preview` and `gpt-4o-mini-audio-preview` (version `2024-12-17`,
**preview**) add the audio modality to the ordinary `/chat/completions` API. Audio
arrives as base64 in a content part of type `input_audio` with a `format` of `wav`
or `mp3`; audio output is requested with `modalities: ["text", "audio"]` plus an
`audio` parameter naming a voice and format. Maximum audio file size is 20 MB, and
API version `2025-01-01-preview` or later is required.

The **Realtime API** (preview) uses the same underlying audio model over a
persistent WebSocket, with server-side voice activity detection, barge-in, and
incremental audio out. That is where sub-second turn-taking comes from. It is also
where your observability goes to die: there is no transcript checkpoint to moderate
before the audio leaves, so safety must be configured on the session rather than
inserted between stages.

> **Exam note.** The trade-off to memorize: **cascaded gives you control and
> auditability; speech-to-speech gives you latency and prosody.** A regulated
> workflow that must log and moderate every utterance argues for cascaded even
> though it feels slower. A consumer voice assistant argues for Realtime.

### Speech translation

| Approach | API | Characteristics |
|---|---|---|
| `TranslationRecognizer` | Speech SDK, `SpeechTranslationConfig` | Speech in → transcript **and** translations out, in one pass. Multiple targets per call. Can synthesize the translation directly |
| STT → Translator → TTS | Three services | Most control, adds Custom Translator terminology |
| STT → LLM → TTS | Two services | Best register and context handling, slowest |
| Audio model | `gpt-4o-audio-preview` | Translates from audio directly, keeps paralinguistic cues |

`TranslationRecognizer` is the one to reach for by default: one call, both the source
transcript and the translations, and `add_target_language` for each target. Set
`speech_synthesis_voice_name` on the config and it will also produce translated
audio, giving you speech-to-speech translation without wiring three services
together.

---

## Portal walkthrough — Speech Studio

1. Go to **https://speech.microsoft.com** and sign in. Select your subscription and
   the Foundry resource from `.env`.
2. **Voice gallery** — filter to your locale. Note which voices show a **Styles**
   badge; `<mstts:express-as>` only works on those. Play `en-GB-SoniaNeural` and a
   multilingual voice back to back.
3. **Audio Content Creation** (under Voice Gallery) — paste a sentence, then use the
   toolbar to insert a break and change the rate. Switch to the **SSML** view. This
   is the fastest way to learn SSML: build it with the UI, then read what it wrote.
4. **Custom speech** → **Create a project**:

   | Field | Value |
   |---|---|
   | Name | `ai103-custom-speech` |
   | Description | anything |
   | Language | English (United Kingdom) |

5. Inside the project, walk the tabs without training:
   - **Test data** — upload audio + human-labelled transcripts to *measure* accuracy.
   - **Training data** — the data types are the exam-relevant part:

     | Data type | What it fixes | Minimum useful |
     |---|---|---|
     | Plain text (related text) | Vocabulary and phrasing | A few hundred utterances |
     | Structured text (patterns) | Slot-filling phrasings | — |
     | Pronunciation | Words spelled unlike they sound | — |
     | Audio + human-labelled transcript | Accents, acoustics, noise | 1–20 hours |
     | Audio only | Acoustics, unsupervised | — |

   - **Train custom models** — pick a base model version. Note that base models are
     **retired on a schedule**; a custom model built on a retired base must be
     rebuilt.
   - **Test models** — compare word error rate (WER) against the base model. If your
     custom model is not better than base on *your* test set, you have not fixed
     anything.
   - **Deploy models** — creates an endpoint with an **Endpoint ID**. That ID is what
     goes into `speech_config.endpoint_id`. **A deployed custom endpoint bills while
     it exists.** Delete it when you are finished.

6. **Custom voice** — open it and read the gating screen. You will see the Limited
   Access application requirement and the consent statement obligation. Do not apply.

<details>
<summary>CLI alternative — check auth wiring and clean up endpoints</summary>

```powershell
# Confirm the resource has a custom domain (needed for Entra ID recognition)
az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE `
  -g $env:AZURE_RESOURCE_GROUP --query "properties.customSubDomainName"

# Set one if it is null. This CANNOT be changed later.
az cognitiveservices account update -n $env:AZURE_AI_FOUNDRY_RESOURCE `
  -g $env:AZURE_RESOURCE_GROUP --custom-domain $env:AZURE_AI_FOUNDRY_RESOURCE

# Data-plane role for Speech
$me = az ad signed-in-user show --query id -o tsv
$id = az cognitiveservices account show -n $env:AZURE_AI_FOUNDRY_RESOURCE `
      -g $env:AZURE_RESOURCE_GROUP --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role "Cognitive Services Speech User" --scope $id

# The key, only if you need the fallback path
az cognitiveservices account keys list -n $env:AZURE_AI_FOUNDRY_RESOURCE `
  -g $env:AZURE_RESOURCE_GROUP --query key1 -o tsv
```

Custom Speech models and endpoints are managed through the
[Speech to text REST API](https://learn.microsoft.com/azure/ai-services/speech-service/rest-speech-to-text),
not `az`.
</details>

---

## Lab

[lab.ipynb](lab.ipynb) synthesizes its own audio first, so nothing needs a
microphone. It ends by timing a cascaded pipeline end to end so the latency table
above becomes a number you measured.

---

## Troubleshooting

**Recognition returns nothing and raises nothing**
You did not subscribe to `canceled`. Auth failures, quota problems, and bad
endpoints all arrive as a `canceled` event with `cancellation_details.reason ==
CancellationReason.Error` and an `error_details` string. Always wire it up.

**`WebSocket upgrade failed: Authentication error (401)`**
Wrong key, wrong region, or an `aad#` token that is malformed. The region must match
the resource — a key from an `eastus2` resource with `region="westus"` produces this
exact error.

**`Speech recognition canceled: NoMatch`**
The audio contains no recognizable speech in the configured language. Check
`speech_recognition_language` — the default is `en-US`, so British-accented audio
tagged `en-GB` and vice versa degrades noticeably, and a completely wrong language
gives `NoMatch`.

**`recognize_once_async` only transcribes the first sentence**
Working as designed. It stops at the first end-of-speech or 15 seconds. Use
continuous recognition.

**`Synthesis canceled: Error ... Invalid SSML`**
Almost always a missing `xmlns` on `<speak>`, a missing `xmlns:mstts` when using
`<mstts:express-as>`, an absent `xml:lang`, or a voice name that does not exist in
your region.

**Synthesized audio plays too fast or too slow**
Output format mismatch. You wrote 24 kHz PCM into a container declared as 16 kHz, or
handed raw PCM to something expecting RIFF. Set
`set_speech_synthesis_output_format` explicitly and match it at the consumer.

**`DeploymentNotFound` for `gpt-4o-audio-preview`**
Audio models are not deployed by the setup scripts and are not available in every
region. Deploy `gpt-4o-mini-audio-preview` in the portal and add
`MODEL_AUDIO=<deployment-name>` to `.env`. The lab skips that section cleanly if it
is absent.

**`Invalid parameter: 'modalities'` or audio content part rejected**
API version too old. Audio completions need `2025-01-01-preview` or later. Set
`AZURE_OPENAI_API_VERSION` accordingly.

---

## Check yourself

[quiz.md](quiz.md) — 14 questions on recognition modes, SSML, customization gating,
and the cascaded-vs-realtime trade-off.

## Next

[05.1 — Build retrieval and grounding pipelines](../../05_information_extraction/01_retrieval_and_grounding/README.md)

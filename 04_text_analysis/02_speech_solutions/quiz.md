# 04.2 — Speech solutions: quiz

14 questions. Answers at the bottom. Aim for 11+ before moving on.

---

**1.** You call `recognize_once_async()` on a 90-second recording. What happens?

- A. The full 90 seconds is transcribed
- B. An exception is raised because the audio is too long
- C. The first utterance is transcribed and `reason` is `RecognizedSpeech`
- D. `reason` is `NoMatch`

---

**2.** Your continuous recognition session produces no text and throws no exception.
The key is wrong. Where does the error appear?

- A. As an exception from `start_continuous_recognition_async()`
- B. In the `canceled` event, in `cancellation_details`
- C. In `session_stopped`
- D. In the `recognizing` event with an empty `text`

---

**3.** An agent must read the order reference `SO-4471` as individual letters and
digits rather than as a word. Which SSML element?

- A. `<prosody rate="-20%">`
- B. `<phoneme alphabet="ipa" ph="...">`
- C. `<say-as interpret-as="characters">` and `<say-as interpret-as="digits">`
- D. `<mstts:express-as style="newscast">`

---

**4.** A call centre transcribes 8 kHz telephony audio from callers with strong
regional accents. Recognition of ordinary words is poor. What should they do?

- A. Add a phrase list of common words
- B. Train a Custom Speech model with audio and human-labelled transcripts
- C. Use a multilingual neural voice
- D. Switch to `recognize_once_async`

---

**5.** A retailer's recognizer keeps mangling twelve product names. The audio is
clean studio-quality. Cheapest effective fix?

- A. Custom Speech with audio training data
- B. `PhraseListGrammar` with the twelve names
- C. Custom Neural Voice
- D. A `<lexicon>` SSML element

---

**6.** Which statement about Custom Neural Voice is correct?

- A. It is generally available to any subscription with a Speech resource
- B. It requires Limited Access approval and documented consent from the voice talent
- C. Custom Neural Voice Lite removes the approval requirement
- D. It is configured with `speech_config.endpoint_id`

---

**7.** You want keyless authentication for a `SpeechRecognizer`. What do you need?
Choose two.

- A. A custom domain endpoint on the resource
- B. `SpeechConfig(token_credential=..., endpoint=...)`
- C. `SpeechConfig(subscription=..., region=...)`
- D. An `AzureKeyCredential`

---

**8.** For Speech operations that do not accept a `TokenCredential`, what is the
correct authorization token format?

- A. `Bearer {token}`
- B. `{resourceId}:{token}`
- C. `aad#{resourceId}#{token}`
- D. `{region}#{token}`

---

**9.** A regulated bank builds a voice agent. Every customer utterance must be
logged, moderated, and redacted before any response is produced. Which architecture?

- A. Realtime API for lowest latency
- B. Cascaded STT → LLM → TTS
- C. `gpt-4o-audio-preview` with audio in and audio out
- D. `TranslationRecognizer`

---

**10.** What is the main information loss in a cascaded speech pipeline?

- A. Word accuracy drops below a native audio model
- B. Tone, emphasis, hesitation, and emotion are discarded at the transcript
- C. The model cannot call tools
- D. Output audio cannot use SSML

---

**11.** Which two are true of `gpt-4o-audio-preview`? Choose two.

- A. It adds the audio modality to the `/chat/completions` API
- B. It is a streaming WebSocket API with server-side voice activity detection
- C. Audio input is supplied as base64 with a `format` of `wav` or `mp3`
- D. It bills audio at the same rate as text tokens

---

**12.** You need live captions of an English meeting in German, Japanese, and
Portuguese with the lowest possible latency. Which is best?

- A. Continuous recognition, then Azure Translator on each final utterance
- B. `TranslationRecognizer` with three target languages
- C. Continuous recognition, then `gpt-4o-mini` for each language
- D. Batch transcription followed by document translation

---

**13.** Which requirement makes you choose STT → Translator → TTS over
`TranslationRecognizer`?

- A. Lowest possible latency
- B. Translated audio output
- C. Enforced approved terminology using a Custom Translator model
- D. Multiple target languages in one call

---

**14.** In a voice agent, which measurement best reflects perceived responsiveness of
speech synthesis?

- A. Total synthesis time for the utterance
- B. Time to the first audio chunk
- C. The `audio_duration` of the result
- D. The size of `result.audio_data`

---
---

## Answers

**1 — C.** `recognize_once_async` returns at the first detected end-of-speech, or at
15 seconds, whichever comes first. It reports success. That is what makes it
dangerous: you get a plausible-looking partial transcript with no error anywhere,
and a pipeline that silently drops 80% of every call. Anything longer than a single
utterance needs continuous recognition.

**2 — B.** The Speech SDK surfaces authentication, quota, and endpoint failures as a
`canceled` event with `cancellation_details.reason == CancellationReason.Error` and
an `error_details` string. Nothing is raised. A recognizer without a `canceled`
handler fails silently — this is the most common Speech SDK bug and worth wiring up
reflexively.

**3 — C.** `<say-as>` controls interpretation of the text content: `characters`,
`digits`, `date`, `telephone`, `currency`, and others. A only changes speed, B fixes
pronunciation of a word the engine mispronounces, D changes speaking style. None of
those cause a reference to be spelled out.

**4 — B.** Accents, background noise, and narrowband telephony audio are **acoustic**
problems. Only audio plus human-labelled transcripts as Custom Speech training data
addresses them. A phrase list biases the language model toward known terms and does
nothing for acoustics. C is a synthesis feature. D makes it worse by truncating.

**5 — B.** A phrase list is free, needs no training data or deployment, and is
attached to a recognizer in two lines. It is precisely designed for a bounded set of
known terms in clean audio. A is disproportionate and creates a billable endpoint. C
is synthesis and gated. D is an SSML element — it affects text to speech, not
recognition.

**6 — B.** Custom Neural Voice is under Microsoft's Limited Access policy: you apply,
describe the use case, and provide documented consent from the voice talent
including a recorded consent statement. Lite (C) reduces the amount of recorded data
needed, not the approval requirement. D describes Custom **Speech** — a recognition
endpoint, not a voice.

**7 — A and B.** `SpeechRecognizer`, `ConversationTranscriber`, and
`TranslationRecognizer` accept a `TokenCredential` directly, but only against a
custom-domain endpoint — the default regional endpoint will not work. C is the key
path and D is not a Speech SDK concept.

**8 — C.** `aad#{resourceId}#{entraAccessToken}`, with both the `aad#` prefix and the
`#` separator required. `resourceId` is the full ARM resource ID; the token is scoped
to `https://cognitiveservices.azure.com/.default`. Because the token expires,
`speech_config.authorization_token` is settable so long-lived objects can refresh
without being rebuilt.

**9 — B.** The requirement is a text checkpoint at every stage — something you can
log, run PII detection over, screen with Content Safety, and redact before the model
sees it and again before synthesis. Speech-to-speech architectures (A, C) have no
such checkpoint; moderation is configured on the session and there is no transcript
to redact between stages. D is a translation feature and does not answer the
question.

**10 — B.** The transcript is text, and text has no prosody. Sarcasm, hesitation,
urgency, and emotional state all vanish at step one — "fine." and a sarcastic
"fine…" are identical strings. A is false: cascaded STT is generally at least as
accurate on words. C and D are unrelated to the architecture.

**11 — A and C.** The audio models extend the ordinary chat completions API with an
`input_audio` content part carrying base64 audio (`wav` or `mp3`, max 20 MB) and an
optional `modalities: ["text","audio"]` for audio output. B describes the **Realtime
API**, which uses the same underlying model over a WebSocket. D is wrong — audio
tokens are counted separately and are materially more expensive.

**12 — B.** `TranslationRecognizer` performs recognition and translation to multiple
targets in a single pass, so you pay one round trip rather than one per language,
and partial results arrive while the speaker is still talking. A and C add a serial
hop per language after each utterance is finalized. D is asynchronous and has no
live output at all.

**13 — C.** Enforced terminology needs a Custom Translator model, which is a
Translator feature and not reachable through `TranslationRecognizer`. A, B, and D are
all reasons to *keep* `TranslationRecognizer` — it is lower latency, will synthesize
translated audio directly when you set `speech_synthesis_voice_name`, and takes
multiple targets in one call.

**14 — B.** Users perceive the silence before audio starts, not the total time to
generate it. That is why `start_speaking_text_async` with an `AudioDataStream` beats
`speak_text_async().get()` for agents: first-byte latency drops from roughly the
length of the utterance to a few hundred milliseconds. C measures the length of the
audio, D measures its size — neither is a latency measure.

---

## Lab exercise solutions

**1. The 15-second rule.** Synthesize ~40 seconds, then compare:

```python
long_text = " ".join([f"This is sentence number {i}, describing part of the order." for i in range(1, 16)])
speechsdk.SpeechSynthesizer(
    speech_config=sc,
    audio_config=speechsdk.audio.AudioOutputConfig(filename=str(OUT / "long.wav")),
).speak_text_async(long_text).get()

once = recognize_file(OUT / "long.wav")
print(once.reason, len(once.text.split()), "words")   # ~15-30 words, RecognizedSpeech
```

The single-shot call returns `ResultReason.RecognizedSpeech` with roughly the first
one or two sentences. Continuous recognition returns all fifteen. The danger is
precisely that `reason` is a **success** value — there is no error, no warning, and
no truncation flag. A pipeline that checks only `reason == RecognizedSpeech` will
happily process 10% of every call and report a green status. The defence is a rule,
not a check: `recognize_once_async` is for single utterances only.

**2. SSML for a confirmation flow.**

```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-GB">
  <voice name="en-GB-SoniaNeural">
    <prosody rate="-15%">
      Your contact number is
      <say-as interpret-as="telephone">020 7946 0912</say-as>.
      <break time="500ms"/>
      Your order reference is
      <say-as interpret-as="characters">SO</say-as>
      <break time="200ms"/>
      <say-as interpret-as="digits">4471</say-as>.
      <break time="500ms"/>
      Delivery is expected on
      <say-as interpret-as="date" format="dmy">20-03-2026</say-as>.
    </prosody>
  </voice>
</speak>
```

Transcribing the result does **not** round-trip cleanly, and that is the lesson.
`<say-as interpret-as="digits">4471</say-as>` is spoken "four four seven one", and
the recognizer returns the words — or `4 4 7 1`, or `4471`, depending on
normalization. The date comes back as "the twentieth of March twenty twenty-six".
Speech recognition output is *normalized text*, not a reconstruction of the input.

The practical consequence: never confirm a value by transcribing your own synthesis.
If a voice agent must confirm a reference, it should compare against the value it
already holds and ask the caller a yes/no question, or use recognition with a phrase
list of the expected value. Round-tripping through audio is a lossy channel in both
directions.

**3. Redact before you speak.**

```python
transcript = TRANSCRIPT
pii = language.recognize_pii_entities([transcript])[0]
safe = pii.redacted_text

summary = ask(
    f"Summarise this support call in two sentences for an internal handover:\n{safe}",
    system="Never restate personal data. Refer to the caller as 'the customer'.",
)
synth.speak_text_async(summary).get()
```

Redaction must happen **before the text leaves your process for any downstream
service** — before the summarization model, and certainly before the TTS call.
Sending the raw transcript to the model and asking it not to repeat the card number
is not redaction; the number has already been transmitted, logged in traces, and
included in prompt tokens. The order is: recognize → redact → everything else.

Two refinements a real system needs. First, keep the mapping from placeholder to
original value inside the trust boundary, under separate access control, so the
agent can still act on the order. Second, note that STT output is normalized —
"four two four two" may transcribe as `4242` or as words, and
`recognize_pii_entities` will only catch the digit form. Redaction over speech
transcripts is systematically leakier than over typed text, which is an argument for
recognizing with a phrase list or a pattern-aware post-process, and for treating
call recordings as sensitive at rest regardless.

**4. Budget the architecture.** Typical shape per turn, with a 5-second user
utterance and a 15-word reply. State these as assumptions — regional latency and
list prices both move.

| | Latency to first audio | Dominant cost | Notes |
|---|---|---|---|
| (a) Cascaded STT → mini → TTS | ~1.5–2.5 s | Speech per-hour + a few hundred text tokens | Cheapest by a wide margin |
| (b) Audio in, text out, Speech TTS | ~1.5–3 s | Audio **input** tokens + text out + TTS | Keeps input prosody; output prosody is yours to author in SSML |
| (c) Audio in, audio out | ~1–3 s | Audio tokens **both** directions | Several times (b); best naturalness in a turn-based flow |
| Realtime API | ~0.3–0.8 s | Audio tokens both directions, plus session time | Only option where barge-in feels natural |

For a 24/7 support line the answer is usually **(a) with a targeted upgrade**, and
the reasoning matters more than the choice. Support lines are dominated by
transactional turns — order status, address confirmation, appointment booking — where
a clean transcript is worth more than prosody because it is what you log, moderate,
QA, and feed to analytics. Cost scales linearly with volume and a 24/7 line has
volume. Cascaded also lets you swap the model without touching the voice, and apply
PII redaction between stages, which (c) and Realtime structurally cannot.

The defensible upgrade is (b) on a *subset*: route to an audio-in model when the
cascaded path detects escalation language or low STT confidence, so the model can
hear frustration the transcript flattened. That buys the signal where it changes
behaviour without paying audio-token prices on every "where is my order".

Reach for Realtime when turn-taking *is* the product — a hands-free assistant, a
live interpreter — and you can accept degraded auditability. On a regulated support
line, that trade is usually the wrong way round.

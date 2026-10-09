# Voice effect: exploration

Status: **exploration**. A Debug-only prototype is in Settings → Prototypes → "Voice effect (prototype)". It doesn't ship and asks for no permissions.

## The reference

The reference is [Jakub Antalik's "voice effect" in SwiftUI](https://doomers.ai/launches/voice-effect-swiftui), from October 2026. It's a 13-second video with no published code. Its caption says the **colour theme reacts to the emotion in your speech**. Two on-device models drive the colour: emotion2vec reads the tone of voice, and a word-emotion classifier reads the transcript. Separately, the shape moves with the sound: a soft glowing form that swells and ripples while you talk, similar to Siri's glow in Apple Intelligence.

We couldn't watch the video from here (X needs a login). This description comes from the caption and from how effects like this are usually built. Watch it before deciding on the look.

So the reference has two layers:
1. **Motion from loudness**: the shape breathes with the microphone level. That's cheap and well understood.
2. **Colour from emotion**: an ML model guesses your mood and changes the palette. That's a different and much bigger decision (see below).

## How we'd build it in SwiftUI (iOS 27)

- **The shape.** The edge of a circle is pushed in and out by a few sine waves. Quiet means nearly round. Louder means bigger and wobblier. Inside it, a `MeshGradient` (the same thing the Journal's ambient field uses) drifts between three inks. A blurred copy behind it is the glow. `TimelineView(.animation)` redraws it about 60 times a second. The prototype does exactly this in plain SwiftUI.
- **A shader version.** A Metal shader can draw the same orb per pixel, with a smoother edge, real noise and a nicer halo, through SwiftUI's `.colorEffect(ShaderLibrary.voiceOrb(...))`. A draft is in [`voice-exploration/VoiceOrb.metal`](voice-exploration/VoiceOrb.metal). It isn't in the build yet: compiling `.metal` files needs the **Metal Toolchain**, a one-time Xcode download (Xcode → Settings → Components). Worth it only if the SwiftUI version looks flat on the phone.
- **The level.** `AVAudioEngine` with a tap on the microphone input. For each audio buffer, compute the loudness (RMS, in decibels), map roughly −50…−10 dB to 0…1, then smooth it: rise fast, fall slowly, like a level meter. The prototype fakes this number with sine waves and noise, so it's easy to swap in the real one later.

## How it fits felt air

The rule in [visual-style.md](visual-style.md) is that **colour is for data**. So:

- **The orb's inks are today's conditions, not your mood.** They're the same weave inks and levels the Journal's ambient field uses (air pink, humidity blue, temperature red, and pollen yellow once it exists). Speaking makes the orb move. It never changes the colours to mean something new.
- **Emotion colour: we suggest no.** A colour that says "you sound anxious" is a claim about the user that we can't back with numbers, and it adds a third model. If we ever want it, it should be a confirmed tag ("Stress"), not a hue.
- Frosted glass (`frostedCard`) for the button and transcript card, so the orb sits on the stage like the Journal's cards do.
- Tag chips are **never inked**: dashed outline = suggested, filled = confirmed.
- One New York line: "Hold to tell felt air what's going on."

## The full flow

1. **Hold to record.** The orb wakes up while held and settles when released. VoiceOver users get a tap to start and a tap to stop (holding doesn't work with VoiceOver).
2. **Transcribe on device.** Speech framework, `SpeechAnalyzer` with a `SpeechTranscriber` module (both are in the iOS 27 SDK). Recognition stays on device, and the language model is downloaded once through `AssetInventory`. The transcript shows in the card and can be edited.
3. **Suggest tags.** `VoiceNoteTagger.suggest(transcript:using:)` from `AsthmaCore`, with Foundation Models as the `TagProposer`. Keyword rules and negation still work without Apple Intelligence (the prototype runs this path with `nil` for the model).
4. **Confirm chips.** Tap to confirm. Only confirmed tags become bins, stored as a `TagReview` on the moment.
5. Audio and transcript are kept locally (SwiftData). Nothing leaves the phone.

## Permissions (owner approval needed before shipping)

| Permission | Info.plist key | Why |
|---|---|---|
| Microphone | `NSMicrophoneUsageDescription` | Record the note and read the level for the orb |
| Speech recognition | `NSSpeechRecognitionUsageDescription` | On-device transcript |

Both are new permission prompts, so per AGENTS.md they need a yes from the owner first. The prototype adds neither.

## Effort, in steps

Each step ends on the phone.

1. **Look.** Try the prototype on the iPhone and pick a direction: SwiftUI blob or shader, and how strong the glow is. *(0.5 day)*
2. **Real level.** `AVAudioEngine` tap → smoothed 0…1 → orb. Asks for the microphone. *(1 day)*
3. **Transcript.** `SpeechAnalyzer` + `SpeechTranscriber`, asset download, live text while speaking. *(1–2 days)*
4. **Tags.** Foundation Models `TagProposer` → `VoiceNoteTagger` → chips → `TagReview` saved on the moment. *(1 day; the logic and tests already exist)*
5. **Entry point.** A mic in the check-in sheet after "Used inhaler", plus the "Anything going on?" row in the Journal. *(0.5 day)*
6. **Polish.** VoiceOver, Reduce Motion, Dynamic Type, interruption handling (calls, AirPods). *(1 day)*

About **5–6 working days** in total.

## Risks

- **Battery and heat.** A 60 fps animation plus the audio engine. The orb only runs while recording, which is short, and stops when the sheet closes. Drop to 30 fps if the phone gets warm.
- **Reduce Motion.** The orb is a still frame that grows slightly while listening (the prototype does this). The words "Listening…" carry the state.
- **Reduce Transparency.** Solid card instead of glass, and no glow.
- **Accessibility.** The orb is decoration and hidden from VoiceOver. The button, transcript and chips are the real interface.
- **Privacy.** Audio, transcript and tags stay on the device. On-device recognition only, with no server fallback. If the speech model isn't downloaded or Apple Intelligence is off, the user can still type a note and pick chips by hand (fail open).
- **Over-reading.** The orb mustn't look like it's measuring breathing or lungs. It reacts to loudness only, and the copy never suggests otherwise.

## Decisions for the owner

1. Approve the **microphone** and **speech recognition** prompts (or not yet).
2. **Colour**: today's conditions (suggested) vs emotion like the reference.
3. **Renderer**: SwiftUI blob (no setup) vs Metal shader (install the Metal Toolchain in Xcode).
4. **Where it lives**: in the check-in sheet after a log, in the Journal's Notes row, or both.

# The recorder, surface by surface

Oct 18, 2026. One recording session, five places it can be started from. The session is the same everywhere
(`VoiceNotes` → on-device speech, live words → `VoiceNoteTagger` → review → `VoiceNote` on the moment). What
changes per surface is how much of the loop is visible, what the prompt says, and what one tap means. This is
the map for deciding what each surface shows; nothing here is built yet beyond the rail.

## The session (shared)

| State | What's happening | What every surface must show |
|---|---|---|
| idle | nothing | a way to start, and whether there's already a note on this moment |
| listening | mic open, words arriving | that it's live (ink, motion), the words so far, the current prompt |
| writing | mic closed, last words settling | a short "writing it down" |
| review | words + suggested tags, editable | the words, the tags pre-ticked, Save / Redo |
| saved | note on the moment | a quiet confirmation, then back to idle |

Prompts are past tense and rotate (`VoicePrompts`): "What were you doing?", "Where were you?", "How did you
feel?", "What was in the air?"; then the one not yet answered; then "Keep going…". Words that match a tag rule
light up in the inhaler's ink as they're recognised, on every surface that can show words.

## The surfaces

### 1. The rail (in the app, on Now or a moment)
*Built.* Hold Voice and it records; the panel beside the thumb is the live surface (tinted glass, lit edge, the
grain breathing with your voice, lit words, the prompt). Lift to stop; review in the same panel; Save or Redo.
The most complete loop, because the screen is big and the hand is already on the rail.

### 2. The Lock Screen card (Live Activity)
*Built, older shape.* 160 pt tall, no live words possible (Live Activities don't stream text). So: the prompt as
the headline ("What were you doing?" instead of "What's going on?"), the mic as the one control, the ring in the
inhaler's ink while listening, then the chips on review (suggested first, pre-ticked). The words show only on
review, in italics. Keep "Here if you need it." on standby.
Change to make: past-tense prompts; pre-ticked symptom tags when they exist; Save then "Saved" for 2 s.

### 3. The notification (after a press, when there's no card)
A tap opens the app straight into the rail panel, already listening, with the moment selected. The
notification's body carries the prompt. No recording from the notification itself (iOS can't).

### 4. Control Center / the Action button
"Rescue voice note": logs a rescue (or joins one from the last 10 minutes) and starts listening with the phone
still locked. The Dynamic Island is the surface: compact, the mic in ink and a timer; expanded, the prompt and
the last few words as they arrive. Stop from the island; review happens later, on the Lock Screen card or in
the app ("Still want to add a note?").

### 5. The watch
Logging only, by decision. A press on the watch lights the phone's Lock Screen card (already). No recording on
the wrist for the MVP; if ever, it's surface 4's shape.

## What differs, in one table

| | Rail | Lock Screen card | Notification | Control Center / Action | Watch |
|---|---|---|---|---|---|
| Start | hold Voice | tap mic | tap → app | one press | press → phone card |
| Live words | yes, lit | no (review only) | → rail | island, last few | no |
| Prompt | panel, rotating | headline | body | island | — |
| Stop | lift | tap stop | lift (rail) | island | — |
| Review | panel | chips on card | panel | later | — |
| Symptom tags | pre-ticked | pre-ticked | pre-ticked | later | — |

## Open

- Symptom tags (ideas.md): the set, the colour, the `BinSpec` bump.
- Should the Lock Screen card's prompt rotate too, or always be "What were you doing?" (the most answerable
  from a locked phone)?
- Control Center start with no moment in the last 10 minutes: log a rescue, or make a Note? (Today: a rescue.)

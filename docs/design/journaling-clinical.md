# Journaling that a clinician would trust

Oct 19, 2026. What the voice note should capture so a provider can use it, and what it must not pretend to
be. Grounded in two sources Pandji pulled: the LUMA/AstraZeneca *BREATHE* daily asthma journal (the fields a
paper diary asks for) and NICE guideline NG245, evidence review L, "Symptom diary for monitoring asthma"
(Nov 2024: what the evidence says diaries are and aren't good for). For the doctor critique on Friday.

## What the evidence says, in one paragraph

NICE reviewed seven RCTs of symptom diaries and questionnaires (ACT, ACQ) used to monitor asthma. The
evidence was low or very low certainty and the committee **did not recommend routine daily or weekly
symptom monitoring**. Three things they did say that matter for us: focused questions are "a much better way
of assessing asthma control than a general 'how have you been?' approach"; validated control questionnaires
are known to predict future risk of severe flares; and the right home for self-monitoring is a **personalised
asthma action plan**, not a diary read on its own. Lay members added that questionnaires need recall over
weeks and are hard to fill in day to day. The one trial with a clear benefit paired the questionnaire with a
pharmacist acting on it.

So: felt air's journal is not a monitoring tool and must never score control or steer treatment. It is a
**record of moments** that makes the next conversation with a provider better, and the diary is read *with*
the action plan, not instead of it. That is already our principle (advice is a provocation for providers);
the evidence sharpens it.

## What a paper journal asks for, and where felt air already has it

The BREATHE journal's 14-day tracker has one row per day: triggers · signs/symptoms (wheeze, cough, shortness
of breath, sleep disturbance) · rescue inhaler puffs per day · AM/PM peak flow against a personal best ·
outcomes (missed school or work, unplanned medical visit). Plus the "Rules of 2" (night waking > 2×/month,
reliever use > 2×/week, refills > 2×/year, oral steroids > 2×/year).

| Journal field | felt air today | Gap |
|---|---|---|
| Rescue puffs, when | automatic: the press, puffs within 2 min, time, place, air | none |
| Triggers | the air is stamped; indoor things come from voice tags (12, all triggers) | tags are trigger-only |
| Symptoms (wheeze, cough, breathless, sleep) | not captured anywhere | **the big gap** |
| Night waking | not captured (Apple Health sleep is read in words, not linked) | gap |
| Activity limitation / missed work | not captured | gap |
| Outcomes (unplanned visit, oral steroids) | not captured | gap, rare but high-value |
| Peak flow | not captured | out of scope for voice; a HealthKit read later |
| Controller taken (AM/PM) | Standard moments | none |
| "Rules of 2" | never shown (no counts on screen) | by design; the export has the data |

## The proposal

### 1. Two kinds of tag: what was in the air, and what you felt
Add a second closed list, **symptoms**, next to the trigger tags. Same pipeline (keyword rules + model
suggests, you confirm, only confirmed tags become bins), their own colour so they never read as triggers:

`wheeze` · `cough` · `shortOfBreath` · `tightChest` · `wokeAtNight` · `couldntDoActivity` ·
`secondPuffNeeded` · `betterAfter` · `unplannedVisit` · `oralSteroids`

The first four are the journal's hallmark symptoms, worded the way people say them. The next four are the
outcomes that change a provider's decision. `secondPuffNeeded` and `betterAfter` come free from the puff
count and a follow-up note. Each needs a `BinSpec` bump and a sentence in `TheRead.noun`.

### 2. Prompts that are the focused questions, in the past tense
The NICE finding is the reason the prompts exist: focused beats "what's going on?". Rotating opener, then the
one not yet answered (built: `VoicePrompts`). Tune the set to the journal's fields:

- "What were you doing?" (activity, exertion)
- "Where were you?" (place, indoors or out)
- "How did it feel?" (symptoms: wheeze, cough, tight, breathless)
- "What was in the air?" (triggers the APIs can't see)
- "Did it wake you?" only when the moment is between midnight and 6 am
- "Did you need a second puff?" only when puffs = 1 and the note is within 30 min

Never "How have you been?" and never a question that asks for a count.

### 3. The transcript lights up as data
Built: words that match a rule light in the inhaler's ink. With symptom tags the lit words split by colour,
so while you talk you can see "wheezing" (symptom) and "the cat" (trigger) picked up. This is the moment the
journal stops being a voice memo. The review step then shows both tag rows pre-ticked.

### 4. A provider page, not a control score
Insights never shows the Rules of 2 or any score (no counts on screen, and NICE's point that scores need
weeks of recall). Instead, **"For your next visit"**: a one-screen summary a provider can read in a minute,
in words, with the export behind it:
- the rescue moments since the last visit, each with its symptoms, triggers and air, newest first
- what shows up on flare days (the Insights categories, in the same words)
- the outcomes that happened (night waking, missed work, unplanned visit, oral steroids), as a list
- a line: "felt air records; it doesn't score control. Your action plan is the plan."
Shareable as a PDF or text from the moments export. This is where the pharmacist-in-the-loop finding points:
the value is in a human reading it.

### 5. The action plan sits beside the diary
Settings › "My action plan": a photo or PDF of the provider's plan, opened from the capture card's "i".
Nothing is parsed; it's just there, because NICE's committee says that's the right thing to be looking at.

## Questions for the doctor

1. Are wheeze / cough / short of breath / tight chest the right four symptom words for patients to say?
   Anything missing that changes your decision (sputum, chest pain, blue lips)?
2. Night waking and a second puff: are these the two outcomes you'd most want flagged from a diary?
3. Would you read a one-page "since your last visit" summary? What's the first line you'd want on it?
4. Is it right that we never show the Rules of 2 or an ACT-like score in the app, only in the export?
5. "How did it feel?" versus "How did you feel?": does the symptom question need to be about the airways
   specifically to be useful?
6. Should a rescue moment with no note ever be allowed to count toward patterns, or should symptoms be
   required for it to be a "flare"?
7. Anything in the advice cards you'd strike ("Bring your inhaler" was the one we flagged)?

## What we won't do

- Score control, name a zone, or show counts (ACT/ACQ/Rules of 2) on screen.
- Prompt daily. Notes follow moments; the evidence is against routine monitoring.
- Say cause. "Often shows up on your flare days" stays as the only claim.
- Parse the action plan.

## Build order (if the critique agrees)

1. Symptom tags in `JournalTag` (own list, own colour), rules, `BinSpec` bump, lit words by colour.
2. Prompt tuning (the night and second-puff conditions).
3. "For your next visit" from the moments export.
4. The action plan in Settings.

# Journaling that a clinician would trust

Oct 19, 2026. What the voice note should capture so a provider can use it, and what it must not pretend to
be. Grounded in two sources Pandji pulled: the LUMA/AstraZeneca *BREATHE* daily asthma journal (the fields a
paper diary asks for) and NICE guideline NG245, evidence review L, "Symptom diary for monitoring asthma"
(Nov 2024: what the evidence says diaries are and aren't good for). **Wording follows the US references** a
US provider works from: NHLBI's NAEPP guidelines (EPR-3 and the 2020 update) and GINA, which the BREATHE
journal itself cites. For the doctor critique on Friday.

## The US frame: the four control domains (sources quoted)

Both NAEPP and GINA assess control over the past 2–4 weeks on the same four things. The exact wording, so
the critique can hold us to it:

**NAEPP EPR-3 (NHLBI, 2007), Figure 3–5c "Assessing asthma control in youths ≥12 years of age and adults",
p. 77.** Components of control, impairment domain, with the Well-Controlled / Not Well-Controlled / Very
Poorly Controlled thresholds:
- *Symptoms*: ≤2 days/week · >2 days/week · throughout the day
- *Nighttime awakening*: ≤2×/month · 1–3×/week · ≥4×/week
- *Interference with normal activity*: none · some limitation · extremely limited
- *Short-acting beta2-agonist use for symptom control (not prevention of EIB)*: ≤2 days/week · >2 days/week ·
  several times per day
- *FEV1 or peak flow*: >80% · 60–80% · <60% predicted / personal best
- *Validated questionnaires*: ATAQ 0 · 1–2 · 3–4; ACQ ≤0.75 · ≥1.5; ACT ≥20 · 16–19 · ≤15
Risk domain: *exacerbations requiring oral systemic corticosteroids* 0–1/year vs ≥2/year. Note: "Assess
impairment domain by patient's recall of previous 2–4 weeks."

**GINA 2024, Box 2-2 "GINA assessment of asthma control at clinical visits in adults, adolescents and
children 6–11 years", p. 37.** Part A, "In the past 4 weeks, has the patient had:"
- Daytime asthma symptoms more than twice/week?
- Any night waking due to asthma?
- SABA reliever for symptoms more than twice/week?
- Any activity limitation due to asthma?
Well controlled = none of these; partly controlled = 1–2; uncontrolled = 3–4. Part B lists risk factors for
exacerbations independent of symptoms, including *exposures: smoking, e-cigarettes, allergen exposure if
sensitized, air pollution*, and *SABA over-use*. Footnote: "There are no validated tools for assessing
long-term symptom control, i.e., over periods longer than 4 weeks."

| Domain (NAEPP / GINA) | How a patient says it | In felt air |
|---|---|---|
| **Symptoms** (daytime) | wheezing, coughing, chest tightness, shortness of breath | symptom tags (new) |
| **Nighttime awakenings** / night waking | "it woke me up" | `wokeAtNight` (new) |
| **Interference with normal activity** / activity limitation | "it kept me from doing something" | `activityLimited` (new) |
| **SABA use for symptom control** / reliever for symptoms | puffs, how often | automatic from the press |

Lung function and the questionnaires are out of scope for a voice note. NAEPP says "short-acting
beta2-agonist", GINA "SABA reliever", patients say "rescue inhaler"; Rescue stays on screen.

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

## The evidence our engine stands on (for "does inhaler use track the air at all?")

- **Su JG, Barrett MA, Combs V, Henderson K.** Identifying impacts of air pollution on subacute asthma
  symptoms using digital medication sensors. *Int J Epidemiol* 2022;51(1):213–224. PMID 34664072. 1,039
  people in Jefferson County, KY; 286,980 sensor-logged rescue uses over 193,697 patient-days, each tied to
  the nearest monitor's SO2, NO2, PM2.5 and O3. An interquartile rise in each pollutant raised rescue use per
  person per day; "time-lagged exposure effects of 0–3 days were observed." This is the population-level
  version of what felt air does per person, and the lag finding is why our frames carry a 48-hour look-back.
- **Su JG et al.** Health effects of air pollution on respiratory symptoms: a longitudinal study using digital
  health sensors. *Environ Int* 2024;189:108810. PMID 38875815. 456,779 SABA puffs, 3,386 people, California,
  2012–2019: daily NO2, PM2.5 and O3 each raised daily SABA use.
- **Barrett M, Combs V, Su JG, Henderson K.** AIR Louisville: addressing asthma with technology,
  crowdsourcing, cross-sector collaboration, and policy. *Health Aff* 2018;37(4):525–534. PMID 29608361.
  The programme behind the data: inhaler sensors, where and when, fed back to the person and to city policy.

## The method our journal uses (capture at the moment, not recall)

- **Shiffman S, Stone AA, Hufford MR.** Ecological momentary assessment. *Annu Rev Clin Psychol*
  2008;4:1–32. PMID 18509902. "Assessment … typically relies on global retrospective self-reports … which are
  limited by recall bias"; EMA "involves repeated sampling of subjects' current behaviors and experiences in
  real time, in subjects' natural environments" and "aims to minimize recall bias." A note that starts when
  the inhaler does is EMA; a daily diary is the retrospective report both NICE's lay members and Shiffman
  warn about.

## The proposal

### 1. Two kinds of tag: what was in the air, and what you felt
Add a second closed list, **symptoms**, next to the trigger tags. Same pipeline (keyword rules + model
suggests, you confirm, only confirmed tags become bins), their own colour so they never read as triggers:

`wheezing` · `coughing` · `chestTightness` · `shortnessOfBreath` · `wokeAtNight` · `activityLimited` ·
`secondPuffNeeded` · `betterAfter` · `urgentVisit` · `oralSteroids`

On screen: "Wheezing", "Coughing", "Chest tightness", "Shortness of breath" (NHLBI's four symptom words),
"Woke at night", "Kept me from doing something", "Needed a second puff", "Felt better after",
"Urgent care or ER visit", "Oral steroids". The first six are NAEPP's control domains as a patient says them;
the last four are the outcomes that change a provider's decision. `secondPuffNeeded` and `betterAfter` come
free from the puff count and a follow-up note. Each needs a `BinSpec` bump and a sentence in `TheRead.noun`.

### 2. Prompts that are the focused questions, in the past tense
The NICE finding is the reason the prompts exist: focused beats "what's going on?". Rotating opener, then the
one not yet answered (built: `VoicePrompts`). Tune the set to the journal's fields:

- "What were you doing?" (activity, exertion)
- "Where were you?" (place, indoors or out)
- "How did your breathing feel?" (symptoms: wheezing, coughing, chest tightness, shortness of breath)
- "What was in the air?" (triggers the APIs can't see)
- "Did it wake you up?" only when the moment is between midnight and 6 am (nighttime awakenings)
- "Did it keep you from doing something?" (interference with normal activity)
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
- the outcomes that happened (nighttime awakenings, activity limited, urgent visits, oral steroids), as a list
- a line: "felt air records; it doesn't score control. Your action plan is the plan."
Shareable as a PDF or text from the moments export. This is where the pharmacist-in-the-loop finding points:
the value is in a human reading it.

### 5. The action plan sits beside the diary
Settings › "My action plan": a photo or PDF of the provider's plan, opened from the capture card's "i".
Nothing is parsed; it's just there, because NICE's committee says that's the right thing to be looking at.

## Questions for the doctor

1. NHLBI's four: wheezing, coughing, chest tightness, shortness of breath. Are those the words your
   patients say? Anything missing that changes your decision (mucus, chest pain, blue lips)?
2. Nighttime awakenings and a second puff: are these the two things you'd most want flagged from a diary?
   Do you work from NAEPP (EPR-3 / 2020 update), GINA, or something else?
3. Would you read a one-page "since your last visit" summary? What's the first line you'd want on it?
4. Is it right that we never show the Rules of 2 or an ACT-like score in the app, only in the export?
5. "How did your breathing feel?": is naming the breathing the right nudge, or does it lead the answer?
6. Should a rescue moment with no note ever be allowed to count toward patterns, or should symptoms be
   required for it to be a "flare"?
7. Anything in the advice cards you'd strike ("Bring your inhaler" was the one we flagged)?

## What we won't do

- Score control, name a zone, or show counts (ACT/ACQ/Rules of 2) on screen.
- Prompt daily. Notes follow moments; the evidence is against routine monitoring.
- Say cause. "Often shows up on your flare days" stays as the only claim.
- Parse the action plan.

## Built (Oct 19), as A/B test A1

Symptom and outcome tags (kept out of the lift table), the interview (`AsthmaCore/Journal/Interview.swift`),
live words lit in two inks, and two capture styles growing from the capture card: **chat** and **journal**. The
current full-screen recorder is the third arm. See [ab-tests.md](ab-tests.md).

## Build order (if the critique agrees)

1. Symptom tags in `JournalTag` (own list, own colour), rules, `BinSpec` bump, lit words by colour.
2. Prompt tuning (the night and second-puff conditions).
3. "For your next visit" from the moments export.
4. The action plan in Settings.

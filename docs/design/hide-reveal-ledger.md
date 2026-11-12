# What felt air hides and what it reveals

Nov 12, 2026. For next week's presentation. A ledger of the design decisions from Oct 16 to Oct 23, read through
one question: when felt air makes something simpler, what goes out of sight, and can the person get it back?
Written from the repo's own trail (`decisions-this-week.md`, `risk-color.md`, `moment-details.md`,
`personal-insights.md`, `journey/journey-map.md`, the commits to Oct 23). Where something isn't built or isn't
tested, the Status column says so.

## The argument this serves (owner, Nov 12)

felt air is one of several works behind a larger argument: indexes and other flattening systems choose what to
hide and what to reveal, and when they flatten, they take agency away from the person. The Air Quality Index is
the case here. It folds six pollutants, a monitor that may be miles away and a population threshold into one
colour. The colour tells you where the air sits on a scale. It can't tell you why, how near the measurement
was, or where you sit.

felt air also makes things simpler, so it has to say how its simplifying differs. Two distinctions do the work.

**1. A summary that opens, against one that doesn't.** Every simple thing on screen (a sentence, a dot, a word
like "often") has to lead to what it was made from. Three questions, asked of each row below and of any other
work:

- What is hidden?
- Who chose that, and is the choice stated?
- Can the person get it back, and how many steps away is it?

**2. Whose number it is.** Flattening isn't having fewer numbers. It is replacing your number with everyone's.

| Kind of number | Example | About | On screen |
|---|---|---|---|
| Everyone's | AQI 101, "cold starts at freezing" | A population | Only as a reference beside yours or beside a reading |
| The data's | "8 of 14 flare days" | felt air's sample | Never. In the export and the tests |
| The air's | "9 ppb · OpenAQ · 2 mi" | A measurement, with where it came from | When you hold the sky, and in a moment's details |
| Yours | "below about 40°F" | Where a reading starts to matter for you | In the sentence on Insights |

So the rule from Oct 17 ("no numbers on screen") is restated: **numbers about you and the air, never about the
data.**

## The picture to lead with

"Your flare days often came when it was below about 40°F." Under it: "For most people, cold starts at freezing."
(`PersonalEdgeCard.swift`.) One line holds the index's number and the person's number side by side. The index
can only ever say the second.

## The ledger

Status: **built** is in the app; **default** is the arm in force where there's a switch; **untested** means no
session with people has been recorded in the repo.

### Taking the index apart

| Decision | Hides | Reveals | Whose number | How it opens | Status |
|---|---|---|---|---|---|
| The sky is layers, one per thing in the air (Oct 16–21) | Units, until asked | That "the air" is several things that move separately | The air's | Hold the rail: each stop names its layer and its reading | Built |
| The AQI is a summary on a heading, never a row (Oct 21) | Nothing; it demotes the index | The index next to what it's made of: "AQI 42 · Good · mostly ozone", then each pollutant | Everyone's, beside the air's | Tap a moment's sky › The air | Built; not compiled since last edits |
| One provenance line per family; "regional", never "at your location" (principle 2) | — | How far away and how coarse the measurement was: "Regional outdoor · AirNow 11 mi · OpenAQ 2 mi" | The air's | Moment details; Every reading; Where your data comes from | Built |
| Missing is "No reading", never "Good" (Oct 17) | — | The gap itself. "Couldn't read the air here just now." Pollen "not included yet", in grey | — | Always on screen | Built |
| Every reading labelled outdoor; "What felt air can't see" | — | The edge of the instrument: indoor air, colds, missed doses | — | Outdoor label built; the "can't see" line is proposed (journey map §7) | Part built |

### The person's number

| Decision | Hides | Reveals | Whose number | How it opens | Status |
|---|---|---|---|---|---|
| "Cold, for you" (Oct 21) | The search behind it (cut points, repeated half-splits) | Where cold starts for you, beside where it starts for most people | Yours, beside everyone's | Insights › Weather; the dots arm shows the moments it came from | Built, sentence is default (C4); temperature only; untested |
| Orange means "this is one of yours" and nothing else (Oct 21) | Family colour next to risk marks | Which part of the air, the forecast or a sparkline is yours | Yours | The rail's pattern dot, the sparkle's key, Insights | Built, default (A + D); five-second test not run |
| Two tiers of extreme: past the general edge is heavier, past yours is highlighted (Oct 21) | — | The difference between "extreme" and "extreme for you" on one line | Everyone's and yours | Sparklines in details | Built |
| Green, gold, red retired (Oct 21) | — | That the forecast isn't an air-quality status. It had been using the AQI's own colours | — | — | Built, default; "Today" arm keeps the old colours for comparison |

### The pattern, and how sure it is

| Decision | Hides | Reveals | Whose number | How it opens | Status |
|---|---|---|---|---|---|
| Words, not counts: "often", "sometimes", ✦✦ / ✦ (Oct 17–18) | The counts and the ratio | That the pattern is about your days, in words you'd use | The data's, kept off screen | Tap the sparkle for its sentence; counts only in Insights › Your moments › Export table | Built; A4 (is ✦ read as cause?) untested |
| The gate: nothing is said until there's enough of both kinds of day | Ungated leanings | That there isn't enough yet: "Still learning…". Certainty shown as silence, not as a count | — | The thin arc on the Insights button | Built |
| Code finds the pattern; the model only suggests tags you confirm (principle 1; Oct 17) | — | The whole method. Bins, counts and comparison are plain code, checked against fixtures and exportable | — | Export; `fixtures/`; the docs | Built |
| Facts, never causes; "looks like", never "will" (Oct 17) | A story about why | What was in the air and how often it shows up. The limit of what the data can say | — | — | Built; copy tests enforce it |
| The future is a sketch (Oct 16–18) | — | That a forecast hour isn't a record: hollow particles, dashed chip, no pin | — | Drag the timeline ahead | Built |
| "Learned · may shift with the seasons"; profile history (Oct 17) | — | That the profile is dated and can change | — | Insights › Your profile history | Built |

### Where felt air flattens, and what answers it

These are the rows a critic will pick. Each is a real compression. The answer is whether it opens.

| Decision | Hides | Reveals | How it opens | Open question |
|---|---|---|---|---|
| Three-step verdict (baseline-like · a bit like · looks more like) | The score behind it | A comparison with your own days, not with a scale | The sentence beside it names what's behind it (`0424796`) | It can't be opened to the score. Should it? |
| Archetype names ("Hot, hazy days") | That the name is a rule over category strengths | A way to say it to someone else | The category cards under it list everything in the family, measured or not | Can read as a diagnosis. Candidate test: name vs no name |
| Good / OK / Not good on air and pollen | The value | The official band in plain words | The value with its unit is on the same row in details, and on hold | This is the AQI's move at small scale. It is one tap from the number; the AQI isn't |
| Baselines hidden from the journal (Oct 17) | Every ordinary hour felt air sampled | Only the verdict that depends on them | The export | **Weakest row.** The comparison rests on moments the person can't see or correct in the app |
| The dots are a halftone screen; nothing says where (Oct 21) | Position | That a regional reading has no position to show | The map in details says where you were, "not this exact spot" | Hiding here prevents a false reveal. Worth saying aloud |
| Tags suggested by the on-device model, silently | That a model was involved | — | You confirm every tag; unconfirmed tags never count | A2 (ticked vs suggested) untested. "Silently" needs defending |
| The learning arc | The two counts it stands for | That learning is under way | — | "A quantity in disguise" (journey map §6) |
| Counts reachable only by export | — | — | Insights › Your moments › Export table (a CSV) | Three steps and a file format away. Say so, or bring a plain-words "what this rests on" onto the pattern |

## What the ledger shows

- **Most compressions open in one gesture** (hold, or tap the sky). The export is the exception.
- **The personal number exists once.** Temperature has "for you"; humidity and the forecast don't yet
  (`risk-color.md`: "Next, if it holds"). As evidence for a principle, one card is a proof of concept.
- **Nothing here has been put in front of people.** A1–A8 and the five-second test are defined
  (`ab-tests.md`, `risk-color.md`) with no results in the repo. "Agency" is argued, not observed.
- **Two things are hidden without a way back in the app:** the baselines, and the score behind the verdict.

## Still to do before the talk

1. One hour shown twice: as the AQI shows it and as felt air shows it. A real hour, with its provenance.
2. Ask a few people what they can do with the AQI's colour, then with the 40°F line. Record the words they use.
3. Decide whether baselines get a way in (even a line: "compared with 24 ordinary hours" breaks the rule;
   "compared with your ordinary days · see them" doesn't).
4. Decide whether humidity gets "for you" before the talk. The core logic can be tested in the cloud; the card
   needs a build in Xcode.
5. Write down what the Oct 23 review and the doctor said. It isn't in the repo.

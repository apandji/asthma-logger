# A/B tests: the decisions we settle with people

Oct 19, 2026. Some design questions won't be settled in a crit; they need people with asthma using the app.
Each test below is one setting with two or three arms, set before a session on the phone
(Settings › Demo and development › **What we're testing**, in every build including TestFlight). The page shows
the arms in force as one line (`C1=today … A1=chat A2=ticked …`) to paste into the session notes. Nothing is
logged or sent: the measure is what the facilitator watches and asks.

Since Oct 21 the page holds every open question, grouped by screen (Colour, Now, Insights, Logging and notes,
Words and type). **A-numbers** are tested with people (below). **C-numbers** are design crits decided in review:
C1 risk colour (docs/design/risk-color.md), C2 family inks, C3 weather on the rail, C4 how we say where cold
starts for you. "All back to the current design" resets every one. The rest of Demo and development is "Staged
for a demo" (made-up moments and situations) and "Tools" (onboarding, tutorial, exertion check, prototypes).

Debug builds can also set arms at launch: `-ab "A1=journal,A2=suggested"`.

## How to run a session

- One arm per test per person, assigned in advance (alternate across people so each arm gets half).
- Role-play a moment: "You just used your inhaler after climbing stairs; your chest is tight." Then hand over
  the phone on Now.
- Watch first, ask after. Questions to ask are in each test's "Watch".
- Note the arms line, then the observations against each test id.
- Small n is fine: we're looking for clear preferences and failures, not significance.

## The tests

| Id | Question | Arms (default first) | Watch |
|---|---|---|---|
| **A1** | Is a note a conversation or a journal entry? | **chat** (one question at a time, like an assistant's thread) · **journal** (your words + sections of chips) · **sheet** (the current full-screen recorder, control) | Time to a saved note; how many of the four control domains get answered (symptoms, night, activity, reliever); talk vs tap; does it feel like "talking to a thing", and is that good (ask) |
| **A2** | Should heard tags be ticked for you, or only suggested? | **ticked** · **suggested** (dashed, you tick) | Wrong ticks left in vs right suggestions left unconfirmed; trust ("did it put words in your mouth?") |
| **A3** | Should the first question rotate, or always be the same? | **rotate** (doing / breathing / around) · **fixed** ("What were you doing?") | Do people answer the opener or say what they came to say; fatigue over a week of notes |
| **A4** | Is the sparkle understood without words? | **mark** (✦✦ / ✦) · **words** ("It often shows up on your flare days.") | Ask what ✦ means before the tip; does either read as cause |
| **A5** | How should a puff be logged on the phone? | **pull** (glass well) · **menu** (system menu on the +) · **buttons** (two labelled) | Time to log; wrong-kind logs; first try without the tip; one-handed role-play |
| **A6** | In the pull, which is nearest the thumb? | **rescue first** · **standard first** | Wrong-kind logs; daily-inhaler users' expectation |
| **A7** | Do the sounds help? | **on** · **off** | Do people notice the tick; does it bother them in public (ask) |
| **A8** | Which face for the sentence? | **Recursive** · System · Funnel Sans | Read the sentence aloud; which feels like felt air talking; glanceability |

A1 is the big one. The research behind it is in [journaling-clinical.md](journaling-clinical.md): NICE NG245
found focused questions beat "how have you been?", and EMA says capture at the moment beats recall. Chat asks
the focused questions one at a time; the journal shows them all as sections. Both use the same interview
(`AsthmaCore/Journal/Interview.swift`), the same tags and the same lit words, so the comparison is the
interface, not the content.

## Candidates, not built yet

Decisions that came up this week and could become tests once they're built as switches:

- **Verdict language:** "A bit like your flare days" vs action-plan zones (green / yellow / red). Zones are
  what US patients are handed (NAEPP), but they read as a clinical status, which we don't claim. Needs the
  doctor first.
- **Voice on the rail:** hold to record vs tap to record.
- **Header cards:** the Watch-style stack vs a horizontal pager.
- **The archetype name** on Insights ("Hot, hazy days") vs no name, only the categories.
- **"For your next visit"** summary vs the moments list, once the summary exists.
- **Undo after a merged press:** silent vs "2 puffs · Undo" (counts on screen, against the rule, so only as a test).

## Retired switches

The old Journal home and its crit switches (header style, card style and marker, gesture models, sky reading,
layer spread and strength, field style, Insights entry) belong to a screen the app no longer opens; Now is the
only home. They're left in code for now and are not tests. The "Home" switch was removed.

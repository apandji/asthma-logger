# The header: one grammar for Back, Now and Ahead

Oct 17, 2026. The header above the sky reads the same way at every time on the timeline. Only what fills each slot changes.
Built in `ios/AsthmaLog/Journal/NowHomeView.swift` (header, cards) and `ios/AsthmaCore/Sources/AsthmaCore/Narrator/TheRead.swift`
(the sentence, tested).

## Four slots

| Slot | What | Word |
|---|---|---|
| 1 | Where and when: the moment's tag (Rescue / Standard), the place, and the **verdict** beside them. No event chip: the read and the cards already name the event | **Context line** |
| 2 | One sentence on why this time matters to you: the air, compared with your days. Never a weather readout (the sky and Weather details have the numbers) | **The read** |
| 3 | How it compares with your days: green / yellow / red, or the learning pill. Sits on the context line | **Verdict** |
| 4 | What to do or see. When several are true, they **stack**: swipe through them, most important first, with page dots | **Cards** |

The verdict is the scannable label; the read explains it. They never say the same thing.

## Three times: Back · Now · Ahead

| | Context line | The read | Verdict | Cards |
|---|---|---|---|---|
| **Now** (watching) | Here / Home · verdict | The event as a fact, then the counts you share with flare days ("High weed pollen came up at 9 of your 14 rescue moments."), or what's high, or "Nothing in the air stands out right now." | Yes | Advice: the event, then each high pollutant or pollen (up to 3) |
| **Now · just logged** (2 minutes) | Rescue / Standard tag · place | "Rescue logged. What's going on?" | None, it's happening | Capture (say it or tap a tag), then the event's advice if one is on |
| **Back · Rescue** | Tag · place · date and time | Facts and counts, and the 48-hour look-back ("…fine particles were high in the two days before.") | None, it's done | Your note and tags, or "Add what was going on" |
| **Back · Standard** | Tag · place · date and time | "Your daily inhaler. It doesn't count toward patterns." | None | Your note, only if there is one |
| **Ahead** | [place ▾] · verdict | "Thursday afternoon looks more like your flare days: high ozone." / "…looks like your baseline days." / what's high | Yes | **Planning ahead** advice, for the forecast's place (Home → staying put) |

## Rules

- **Advice only on Now and Ahead.** On a past moment it would read as hindsight.
- **Card order:** capture → event → pollutants and pollen by how high they are. At most four.
- **Before felt air has learned** there's nothing to compare: the read states what's notable, the verdict is the learning pill
  ("Learning: 25 moments to go").
- **The disclaimer** sits behind an "i" on each advice card, not printed on every one.
- **The read is about the air.** When and where you used your inhaler (time of day, season, place, indoors or out) is
  about you: it lives in Insights, "You used your inhaler most in the evening: 4 of your 10 rescue moments."
- **Wildfire smoke** reads as on the FigJam board: "There are two active wildfires 50 miles north. Heavy smoke is drifting
  into your area." Fires come from Ambee's fire data (`WildfiresNearby`), demo fires until the key arrives.
- **Facts only.** No causes, no odds, no "attack" (tested in `TheReadTests` and `AirAdviceTests`).

## Open

- Words to check with a doctor: Rescue / Standard (vs reliever / preventer / controller), "flare", "flare days", every advice line.
- No-data and stale states for each time (offline, a failed air check) need their own read.
- The Lock Screen card and Now's capture card should keep looking alike as either changes.
- VoiceOver order: context line → read → verdict → cards, at every time.

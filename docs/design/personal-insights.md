# Personal Insights

Oct 17, 2026. The Insights page, renamed **Personal Insights**. Numbers come from AsthmaCore (`AirProfile`, `Archetype`,
`Rhythm`, `ProfileSnapshot`, all tested); the page lays them out (`ios/AsthmaLog/Insights/`).

## Top to bottom

1. **Personal Insights**, large and centred.
2. **Who you are, so far:** the archetype's name, one plain line, the evidence ("Most often: high ozone (8 of 10) and
   heat (7 of 10)."), and what it rests on ("From 10 rescue and 24 baseline moments."). Before felt air has learned: the
   learning ring instead.
3. **The radar** (weather · particulates & gases · exertion · biologics).
4. **What shows up on your flare days:** a card per category with the things inside it and a strength word, with the
   counts under each.
5. **When** and **Where**, two boxes on one line, plain counts of rescue moments; Where has a small map of them.
6. **Your profile history** → every profile felt air has kept. **Your moments** → every moment, by day, with
   **Export table** (the CSV that used to be "For your doctor").

## Archetypes (first pass, for testing)

A category counts when it has a pattern and is at least 60% as strong as the strongest one.

| Predominant | Name | Line |
|---|---|---|
| Weather | Weather-sensitive | Your flare days follow the weather: heat, cold snaps or humid air. |
| Biologics | Allergen-led | …living things in the air: pollen, pets or mold. |
| Particulates & gases | Air-quality-led | …what's floating in the air: ozone, fine particles or smoke. |
| Exertion | Effort-led | …come with effort: exercise, or laughing or crying hard. |
| Weather (hot) + particulates | Hot, hazy days | …tend to be hot, with ozone or fine particles up. |
| Weather + particulates | Weather and air quality | …follow both the weather and what's in the air. |
| Weather + biologics | Seasonal | …follow the seasons: the weather and what's growing. |
| Biologics + particulates | Airborne | …what's in the air, living or not. |
| Weather + exertion | Weather and effort | …come with effort in certain weather. |
| Biologics + exertion | Allergens and effort | …effort while pollen or other allergens are around. |
| Particulates + exertion | Outdoor effort | …effort while the air is poor. |
| Three or four | Mixed | Several kinds of things show up on your flare days: … |
| None, with enough data | Nothing stands out yet | Nothing in the air shows up much more on your flare days than on others. That's worth knowing too. |
| Not enough data | Still getting to know you | |

## Decisions and pushback (Oct 17)

- **No "correlation".** Strength words instead: Strong (passes the gate, 30+ points more often on flare moments), Some
  (passes the gate), Leaning (more often but not enough moments), Not more than usual, Not tracked yet. Counts always shown.
- **Not "triggers" on screen.** The copy rules forbid claiming a clinical trigger (predictive-engine.md). The section
  is "What shows up on your flare days".
- **"Mixed", not "Balanced"** (balanced reads as healthy), and distinct from "Nothing stands out yet".
- **Species** (ragweed, oak…) waits for Ambee and belongs on a moment's details: 10 moments split across species is noise.
  Tree and grass pollen show as "Not tracked yet".
- **When and Where are counts, not comparisons**, until baseline moments are spread across the day (they're taken when
  the app opens, mostly at home). Next: background baseline sampling and backfill (owner, Oct 17).
- **Profile history:** a snapshot when the archetype changes, or monthly. Hypothesis: it moves with the seasons.
- **Profile as the app icon:** possible only by switching between pre-made icons (one per archetype), and iOS shows an
  alert on every switch. Later.

## Data sets for demos (Settings › Data sets, Debug)

- **Load a data set:** your saved usage, or a made-up person (Still learning, Allergen-led, Air-quality-led,
  Weather-sensitive, Hot hazy days, Effort-led, Mixed, Nothing stands out). Made-up people run through the real
  pattern maths; `DataSetPresetTests` checks each lands on its archetype. Loading replaces the Journal and keeps your
  own data as "My data" first.
- **Save current as…** keeps the Journal as a file on the phone (Documents/DataSets), e.g. "Andrew". Never committed.
- **Fresh start:** erases moments, voice notes, settings, pairing, tips and profile history and opens onboarding.
  Permissions survive until the app is deleted: `ios/scripts/fresh-install.sh` (optionally `--data hotHazy`).
- Launch arguments (Debug): `-dataSet <preset>`, `-freshStart`.
- **Category cards:** the leading one opens, the rest are collapsed; inside, what stands out first (★ on what leads
  your profile), "See all" for the rest. A leaning needs at least two flare moments.

## No numbers on screen (owner, Oct 17)

felt air pushes back on the "quantified self": you're not a number. No counts or ratios anywhere: patterns read in words
(Often · Sometimes · Maybe · No more than usual · Not tracked yet; categories Often · Maybe · Not much), the profile is
**Still learning…** or **Learned · may shift with the seasons**, When/Where say "Mostly in the afternoon." The only
numbers people see are readings with units, when they hold the sky on Now (an intention to learn). Counts stay in the
data, the tests and the exported table. This supersedes the strength words and counts described above.

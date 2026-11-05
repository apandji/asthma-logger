# Moment details: the one place a moment's readings live

Oct 21, 2026. What opens when you tap a moment's sky (on Now, a sheet; in the Journal zoom, in place under the map hero).
Built in `ios/AsthmaLog/Journal/MomentDetailsView.swift`; the families and the provenance and AQI lines are plain Swift in
`ios/AsthmaCore/Sources/AsthmaCore/Conditions/ReadingFamily.swift` (tested in `ReadingFamilyTests.swift`).

## Order

Printed on the same paper as Now (paper token plus a still riso grain), in the order you'd want after a rescue:

| # | Section | What |
|---|---|---|
| 1 | **The moment** | The context line as on Now (Rescue / Standard tag, when and where; "Now" for a live snapshot). Then **the read you came from**: the header's sentence for this moment, marks and all, set in the page's one Recursive sentence. Facts sit under it, one line each with an icon: each inhaler use ("Albuterol · 2 puffs · felt button"). "Before this" facts go here later |
| 2 | **The air** | Weather · Pollutants · Allergens, the rail's three families, each headed in its own ink with a rule under the name |
| 3 | **What you said** | The voice note in quotes, its confirmed tags as chips, the voice-note button. A rescue with no note asks for a few words |
| 4 | **The evidence** | The hours around it (temperature and PM2.5, six hours either side, the moment as a dashed rule in the page's ink), Where (small map, place, indoors or out), Every reading (folded, full provenance), Apple Weather attribution, "Where your data comes from" |
| 5 | **Edit this moment** | Saved moments only |

A live snapshot from Now (not saved) has no voice note and no edit.

## The air

- **One row per reading**: icon in the family's ink, name (with a detail line: the weather condition, the main pollen species), amount dots, the word, the value with its unit.
- **Words**: air and pollen say Good / OK / Not good from the same `AirLayers` the sky and the rail read, so a word here never disagrees with the rail. Weather gets plain words (Hot, Humid), never a judgement; dew point, wind and UV show just the value.
- **Missing is "No reading"**, greyed, never "Good". Every pollutant and pollen row is always listed so the stack is the same every time; weather rows appear only when there's a value.
- **The AQI is a summary, not a row**: on the Pollutants heading, "AQI 42 · Good · mostly ozone" (EPA band in our three words, main pollutant from AirNow's category).
- **One provenance line per family**: the broadest scale word, then each source once at its nearest distance: "Regional outdoor · AirNow 11 mi · OpenAQ 2 mi". Never "at your location". Demo pollen says "Sample pollen for this season, not a reading".
- Weather alerts at the time list under Weather.

## Rules

- The sentence carries over from Now (`NowHomeView.detailsRead`): opening details keeps your place. From elsewhere the moment's own past-tense sentence stands in.
- The map says where *you* were, never where the air was measured: "The readings are for the outdoor air around here, not this exact spot."
- Colour stays with the air: the moment's marker on the charts is the page's ink, not a family's.
- Puffs show here and only here, as facts you logged.
- Icons come from `Theme/Icons.swift` (`Icons.inhaler` for uses).

## Screenshots

Launch with `-openDetails` to open the latest rescue's details on Now after three seconds.

## Status

Not compiled since the last edits (shared `FlowLayout` from `Voice/QuickRecord.swift` now used instead of a private copy; `Icons.inhaler` added). Compile and screenshot before merging.

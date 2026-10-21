# Ideas log

Things noticed while building, not yet decided. Add as you go; move an item out when it's built or dropped
(say where). Newest at the top of each section.

## Interaction

- **Hold the + for a 2-puff log.** A long press on the + (no pull) could log a rescue with two puffs straight
  away, since most rescues are two puffs. The well would show "×2" under Rescue while held. (Oct 18)
- **Undo by shake.** iOS's shake-to-undo on the just-logged moment, for the pocket case. (Oct 18)
- **The lens tints the sky.** While the thumb is in the Rescue zone, the sky's grain could pre-tint orange at
  the + corner, a hint of the ripple to come. Cheap, but might be noise. (Oct 18)
- **Rail: a swipe inward from a stop could open its details**, so Weather's hourly chart is one gesture away
  from the rail without the Details page. (Oct 18)

## Copy

- **"Say it or tap it"** on the capture card is instruction-shaped. A warmer line: "What was going on?" is
  already the header, so the card could drop its title and just show the chips and mic. (Oct 18)
- **Lock Screen standby** now reads "Here if you need it. / The mic logs a rescue and listens." The provider
  sheet should ask whether a standing card is welcome at all. (Oct 18)

## Insights

- **"Learned" as a date.** "Learned · may shift with the seasons" could carry when it was learned ("since
  September"), which says how settled the pattern is without a number. (Oct 18)
- **A season turn.** When the season changes, a one-time card: "Autumn. What shows up on your flare days may
  shift; felt air keeps watching." Sets expectations before patterns move. (Oct 18)

## Later, bigger

- **Sound design proper.** If the two test sounds land, a small set (log, learned, note saved, undo) from one
  instrument, composed, not stock. (Oct 18)
- **Apple Intelligence / Siri**: see apple-intelligence-later.md.

## Found while building (Oct 18, night)

- **The rail moved out from under the thumb.** Holding a stop opened the rail and every stop slid to make
  room, so the selection jumped to whatever landed under the finger. Fixed: the rail now grows around the
  pressed stop (`railShift`). Worth a look on the phone: does the rail ever push off the top or bottom?
- **Interactive glass on a container swallows its buttons' taps.** The Insights/Settings pill was built with
  `.glassEffect(.regular.interactive())` around two Buttons and neither responded. Plain `.regular` on the
  container, press feedback on the buttons. Rule for the design system: interactive glass goes on the
  button's label, never around a group.
- **Undo merges, it doesn't delete.** A second press within two minutes adds a puff; Undo takes one off.
  Only a single-puff moment is deleted by Undo. Clear in the data model, less clear on screen: should the
  card say "2 puffs · Undo" so the arithmetic is visible?
- **Counts on Insights.** "Your moments · 14" and "Your profile history · 1 so far" are the only numbers on
  screen that aren't readings. They're list lengths, not stats, but worth a decision: keep, or "Your moments ›"
  alone. (Oct 18)
- **"Not tracked yet" rows** could say *when*: "Pressure swings · later", "Tree pollen · with Ambee". (Oct 18)
- **Symptom tags** (Oct 18): a second tag set (tight chest, wheeze, cough, short of breath, woke at night,
  needed a second puff, felt better after), auto-selected from the live words, in their own colour. The lit
  words in the transcript are where these would show first. Needs a `BinSpec` bump.
- **The recorder per surface** (Oct 18): one session state machine (idle → listening → writing → review →
  saved) rendered differently per surface: the rail panel (beside the thumb, prompts, lit words), the Lock
  Screen card (one line + mic, chips after), a notification (tap to open the panel), Control Center / Action
  button (starts listening, the Dynamic Island shows the words). To map out together.
- **Journaling, clinical** (Oct 19): see journaling-clinical.md. Symptom tags as a second list, past-tense
  focused prompts (NICE: focused beats "how have you been?"), a "For your next visit" page instead of any
  control score, the action plan kept beside the diary. Questions for the doctor are in the doc.
- **Sources by how local they are** (Oct 19, owner): modeled (Apple Weather, Ambee) → regional monitors
  (AirNow) → the nearest monitor (OpenAQ) → sensors on your street. "Where your data comes from" is laid out
  this way. Next step: when two sources give the same reading, prefer the more local one (EnvObservation
  already carries spatialScale and distanceKm), and say which won on the reading.
- **PurpleAir** (Oct 19): hyperlocal PM2.5 from community sensors, often a block away. Needs a key and paid
  API points; raw readings need the EPA correction (humidity) before they match monitors; indoor sensors must be
  filtered out. A new data source, so: owner's OK, the location card updated (another place the position goes),
  and it counts toward the "hyperlocal" story for the study.
- **Weather by what it does** (Oct 21): see weather-grouping.md. Three items under Weather (Cold, dry air /
  Heat and humidity / Sudden change) instead of instruments; pressure joins Sudden change as one bin later
  (`pressure_change`, from WeatherKit history). Crit switch: Design crit › Weather on the rail.

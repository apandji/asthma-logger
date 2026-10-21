# Weather: separate it, or group it?

Oct 21, 2026. Exploration for the owner's question: "separating out temperature / humidity / pressure, or
grouping it in ways that make sense." Options with trade-offs, a recommendation, and a crit switch to try the
recommended one on the phone (Settings › Demo and development › Design crit › **Weather on the rail**). Nothing
here changes the default.

## Where Weather stands today

| Surface | Pollutants / Allergens | Weather |
|---|---|---|
| Rail | A stop, and when held, one dot per item (PM2.5, PM10, ozone, NO₂ / tree, grass, weed) | One stop, no items (`RailGroup.weather.items == []`). Holding it reads temperature, with humidity and a sharp drop in the note |
| Sky | Each item is its own particles, in the family's ink | One pink wash: distance of the **temperature** from mild (0 at 57–73°F, full by 32°F or 98°F). Humidity and change don't tint it |
| Insights card | Its bins, one row each | Temperature, Humidity, Sharp temperature drop, Heat alert, then "not yet": Pressure swings, Wind, Thunderstorms (`Archetype.notYet`) |
| Lift table | `pm25`, `ozone`, `pollen_weed` | `temp` (cold ≤32 / mild / hot ≥90), `humidity` (dry <35% / ok / humid >65%), `temp_drop` (≥10°F in 3 h, v4), `heat_alert`, plus the journal tag `tag_coldAir` |
| Data | | WeatherKit: temperature, humidity, dew point, wind speed, UV now; hourly temperature and humidity for history and forecast. **Pressure is not read at all.** Wind isn't in the hourly history |

So the bins are already split; the screen lumps them. And the one thing the screen does tint by (the wash) is
temperature only.

## What the research says matters (guidance slide 6)

[guidance-and-archetypes.md §6](../research/guidance-and-archetypes.md) lists the weather-sensitive signals as
"cold, dry air narrows airways, especially when breathing hard; sudden temperature drops, heat and humidity".
That is three mechanisms, not four instruments:

1. **Cold, dry air.** Breathing it cools and dries the airway lining (Koskela 2007 ✓). Worse with effort, which
   is why "Weather and effort" is already an archetype.
2. **Heat and humidity.** Hot, humid air can itself narrow airways in people with asthma (Hayes et al., AJRCCM
   2012, not re-checked), and humid warm weather is mold weather (slide 4).
3. **Sudden change.** Temperature drops, fronts (pressure swings), thunderstorms. The evidence is mixed and
   varies by place; the slide's note says to present weather "as facts on your days, not a mechanism".

Pressure on its own (a reading in hPa) means nothing to a person or, as far as the literature goes, to an
airway. Its **change** is the signal, and it mostly marks a front passing, which is also when temperature drops
and storms happen. Wind is two-faced: it clears pollutants and carries pollen and dust. Neither belongs on the
rail as a bare instrument.

## Option A: instruments, like the other families

Weather gets items like Pollutants: **Temperature, Humidity, Pressure, Wind**, all pink.

| | |
|---|---|
| Rail | Held: four pink dots, size = how far each is from ordinary (Temperature from mild, Humidity from 35–65%, Pressure from steady, Wind from calm) |
| Sky | Wash stays temperature, or becomes the biggest of the four |
| Insights | One row per instrument; matches the bins one-to-one |
| Bins | New: `pressure_change` and `wind` (BinSpec v6). Web lags (it has neither) |
| Data | Pressure and wind are in WeatherKit's `HourWeather`; we'd add them to `WeatherProvider.Hour` so baselines (`BaselineFiller`) and the forecast get them too. Without history, baselines can't have them and the bin is useless (principle 3) |
| Rules | Fits Print (one hue, coverage = amount). No numbers: words only on the dot ("Humid", "Breezy"), readings on hold |

**For:** symmetrical with the other families; easy to explain ("what the weather station measures").
**Against:** it's the instrument's view, not the airway's. "Pressure: steady" and "Wind: breezy" will be most
of what people read, and neither says anything. Four dots that are always partly lit make Weather look busier
than the air that matters more. Hot and cold are the same item, so "Temperature" lit full could mean either.

## Option B: by what it does to airways

Weather gets three items named for the mechanism: **Cold, dry air · Heat and humidity · Sudden change**, all pink.

| | |
|---|---|
| Rail | Held: three pink dots. Cold, dry air = how cold, or how dry (the larger). Heat and humidity = how hot, or how muggy. Sudden change = how far it fell in the last 3 hours (later: pressure swings, storms). Usually only one of the first two is lit, which is the point: the dot says which way the weather is pushing |
| Sky | Wash = the biggest of the three, so a muggy 80°F afternoon and a sharp drop tint the sky too (today they don't). Or keep temperature-only; see "open questions" |
| Insights | The Weather card's rows sorted under the three headings. The mapping is by **bin and level**, not bin: `temp=cold`, `humidity=dry`, `tag_coldAir` → Cold, dry air; `temp=hot`, `heat_alert`, `humidity=humid` → Heat and humidity; `temp_drop` (later `pressure_change`, `storm`) → Sudden change |
| Bins | **No new composite bins.** "Cold and dry" as a bin would double-count temperature and humidity in the risk score ([predictive-engine.md §3](../predictive-engine.md), the non-redundant set). The groups are a reading of the existing rows. Pressure, when it comes, is one new bin (`pressure_change`, v6) filed under Sudden change |
| Data | Works today with temperature, humidity and the 3-hour fall. Pressure needs `HourWeather.pressure` in history (cheap, same call). Storms: `HourWeather.condition` in history, also the same call |
| Rules | Print: all pink, coverage = amount; cold vs hot is in the words and the icon, never the hue, as the Print table already says. No numbers on the dots; readings with units on hold |

**For:** reads the way the guidance slide reads and the way people talk ("cold air gets me"). Matches the
exposure question we already ask ("It was cold out. Were you breathing cold air?") and the `coldAir` tag.
Every dot says something; none is a reading for its own sake. Pressure finally has a home where it means
something. It doesn't touch the lift table to ship.
**Against:** the names are a claim of sorts: "what it does to airways" edges toward mechanism, which slide 6
warns against. The words on screen must stay facts ("Cold and dry", "It fell 12° in 3 hours"), never "this
narrows your airways". Two items can't both be full, so the rail looks emptier than Pollutants. The groups
are our editorial choice; a humid 50°F day is "humid" but not "heat", so `humidity=humid` below ~60°F has
no group (we'd count it under Heat and humidity anyway, and say "Humid").

## Option C: one stop, a breakdown when you hold it

The rail stays as it is. Holding Weather shows a summary like Pollutants' `GroupSummary`: Temperature,
Humidity, Change (and Pressure, Wind when read), each with a word and a pink amount.

| | |
|---|---|
| Rail | Unchanged: Weather, Pollutants, Allergens |
| Sky | Unchanged |
| Insights | Unchanged |
| Bins | None |
| Data | What we have |
| Rules | Fits everything |

**For:** cheapest; nothing to learn. **Against:** doesn't answer the question; Weather stays the odd family
that can't be slid through, and the wash still ignores humidity and change.

## Option D: split the family

Temperature and humidity become one family ("Weather"), and change gets its own ("Changes": drops, fronts,
storms), with the storm event already overprinting pollen. **Against:** a fourth family needs a fourth ink, and
the Print rule is three. Rejected on the colour rule alone; listed so it isn't re-proposed.

## Recommendation: B, in two steps

1. **Now, display only.** The rail's Weather stop gets three items (Cold, dry air / Heat and humidity / Sudden
   change) from the readings we already have, and the Insights Weather card groups its rows under the same three.
   No BinSpec bump, web unaffected. That's the crit switch on this branch, for the rail.
2. **Next, pressure.** Add `pressure` to `WeatherProvider.Hour` (history and forecast are the same call), a
   `PressureChange` detector next to `TempDrop` (a change of 3 hPa or more in 3 hours is a front by the usual
   meteorology rule of thumb; check the edge against a few weeks of real data), and the bin `pressure_change`
   in BinSpec v6, filed under Sudden change. Baselines get it from history like `temp_drop`. Web lags; note it
   in AGENTS.md's contracts. Storms can follow the same way (`HourWeather.condition` → `storm`), which would let
   the Thunderstorm air event become a bin rather than a demo.

Wind stays a reading in Moment details, not a group or bin, until there's a reason to think its direction of
effect is knowable (it clears pollutants and brings pollen; a single wind bin would average the two away).

## How the prototype reads (step 1)

Crit switch **Weather on the rail**: *One stop (current)* / *By what it does (three items)*. With the second:

- Held, the Weather stop shows three pink dots under it, each sized by its amount (faint when nothing).
- Sliding onto one reads it: the name, the word ("Cold and dry", "Humid", "Steady"), the temperature or the
  fall as the large reading with its unit, and the other readings in the note.
- The stop itself is full pink when any of the three is lit (today: only when it's far from mild).
- The wash and Insights are unchanged in the prototype.

The amounts live in `AsthmaCore/Frames/WeatherFacet.swift` (tested): cold from temperature (0 at 57°F, full
at 32°F, the wash's scale), dry (0 at 40%, full at 15%), heat (0 at 73°F, full at 98°F), muggy (0 at 65%, full
at 95%, only from 60°F up), change from the 3-hour fall (0 at 3°F, full at the 10°F sharp-drop edge).
`WeatherFacet.of(bin:level:)` is the bin-and-level mapping for the Insights step.

## Things found on the way

- **The temperature bin is coarse for this.** `temp` is cold ≤32°F, hot ≥90°F, mild in between. A 40°F
  morning tints the sky pink and the rail calls it cold air, but bins as mild. If Cold, dry air is to mean
  something in Insights, `temp` probably wants a `cool` level (33–50°F) in a BinSpec bump. Owner's call; web
  lags.
- **A new hue in the Weather probe:** the humidity sparkline is drawn in a light blue
  (`NowHomeView.select`, `Color(red: 0.55, green: 0.7, blue: 0.95)`). Under Print it should be pink or plain.
- `RailGroup.marked` already looks for "rain", "storm" and "wind" in the read, though no bin produces them.
- Any new weather bin must come from **history** as well as now, or baselines can't carry it and the row can
  never gate. `WeatherProvider.Hour` holds temperature and humidity only today.

## Open questions for the owner

1. B's three names: "Cold, dry air / Heat and humidity / Sudden change", or shorter ("Cold & dry / Hot &
   humid / Changes")? The rail name tag is narrow.
2. Should the wash follow the biggest of the three (a muggy day tints the sky) or stay temperature-only?
3. Add `cool` to the temperature bin? It's the biggest gap between what the sky shows and what Insights can learn.
4. Pressure next (step 2), or storms first (the Thunderstorm event has a demo but no data)?

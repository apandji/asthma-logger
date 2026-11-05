# Archetypes

Oct 21, 2026. How Insights names who you are with your triggers. Code: `AsthmaCore/Lift/AirProfile.swift`
(families), `Archetype.swift` (the name), `Journal/DataSetPresets.swift` (a mock Journal per archetype,
checked by `DataSetPresetTests`). Research behind the families: [../research/trigger-lens.md](../research/trigger-lens.md).

## Families (the radar's five corners)

| Family | Bins | Ink |
|---|---|---|
| Weather (groups: cold, dry air · heat and humidity · sudden change, `WeatherFacet`) | temp, humidity, temp_drop, heat_alert, tag coldAir | pink |
| Allergens | pollen_weed, tags pets, mold | yellow |
| Irritants and pollution | pm25, ozone, smoke_at_point, tags smoke, dust, cleaning, scents, cooking | aqua |
| Exercise (raw value `exertion`) | exertion, tags exercise, laughingOrCrying | text |
| Colds and flu (`infections`) | ili (v6, not stamped on real moments until after the MVP), tag coldOrFlu | text |

Stress stays off the radar: it only comes from voice notes, which baselines never carry, so it can't pass the gate.

A family's **strength** is the biggest flare-minus-baseline gap among its rows; **pattern** when one of them passed
the gate (8 flare / 20 baseline sampled, 4 in the level, lift > 1.25), **early** when one leans but didn't pass.

## The name

1. Not enough moments overall (8 rescue, 20 baseline) → *Still getting to know you*.
2. No family with a pattern → *Nothing stands out yet*.
3. Keep the families at least 60% as strong as the strongest, strongest first.
4. One → its own name (Weather by its group): Cold-air sensitive, Heat-sensitive, Sensitive to sudden changes,
   Allergen-led, Air-quality-led, Effort-led, Comes with colds.
5. Two → a known pair, else "<lead>, with <companion>" (e.g. *Effort-led, with allergens*):

   | Pair | Name |
   |---|---|
   | Heat and humidity + Irritants | Hot, hazy days |
   | Cold, dry air + Exercise | Cold air and effort |
   | Sudden change + Allergens | Storm season |
   | Other weather + Allergens | Seasonal |
   | Cold, dry air or sudden change + Colds and flu | Cold season |

6. Three or more → *Mixed*.

Names are a first pass for testing, never diagnostic ("allergic", "infection-triggered"). Profile History stores the
name with each snapshot, since a composed pair's name isn't in the enum. Retired kinds from the four-family profile
(`weatherAir`, `airborne`, `weatherEffort`, `allergenEffort`, `outdoorEffort`) still read from old history.

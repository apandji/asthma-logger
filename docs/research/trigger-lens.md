# The trigger lens: seeing the air and the body through common asthma triggers

Oct 21, 2026. Written as slides, like [guidance-and-archetypes.md](guidance-and-archetypes.md): each `##` is one
slide, with its sources under it. ✓ = checked this week by web search (title, authors, journal, year). No ✓ =
well known but not re-checked; confirm before quoting. felt air is **not** a medical device and gives no medical
advice. Answers Pandji's question: *are pressure and temperature/humidity separated in the research, and can the
profile be organised around common triggers?*

---

## 1. The answer in one line

**Yes, organise the profile by trigger, the way the guidelines do; split Weather into three by what it does,
and keep pressure inside "sudden change".** Infections stay, but only as something you tell us, nudged by your
watch; never inferred and never from public data (for now).

One thing the code changes underneath: nothing. The lift table bins stay; only how `AirProfile` files them
changes (slide 9).

---

## 2. What the guidelines call triggers

**GINA** defines asthma's variability as "often triggered by factors such as exercise, allergen or irritant
exposure, change in weather, or viral respiratory infections" ✓. Its pocket and summary guides add laughter,
cold air, tobacco smoke and stress as symptom triggers, and name viral infections, pollen or pollution, and
poor controller adherence as the usual exacerbation triggers ✓. GINA separately lists *risk factors* that make
flares likelier over months (high reliever use, poor adherence, smoking, obesity, rhinosinusitis, reflux,
pregnancy, major psychological or socioeconomic problems) ✓ via secondary summary.

**NAEPP EPR-3 (2007)** puts triggers under its "control of environmental factors and comorbid conditions"
component: inhalant allergens (pets, dust mites, cockroach, mold, pollen), occupational exposures, irritants
(tobacco smoke, indoor and outdoor pollution), and comorbid conditions and other factors (rhinitis/sinusitis,
reflux, obesity, stress and depression, aspirin/NSAID and beta-blocker sensitivity, sulfites, viral infections
and flu vaccination). The **2020 focused update** reviewed only indoor allergen mitigation from that list ✓.

So both group the same way: **allergens · irritants and pollution · weather · exercise · infections · emotion
and stress**, with medicines, reflux, hormones and work as "other factors".

Sources:
- ✓ Global Initiative for Asthma. *Global Strategy for Asthma Management and Prevention*, 2024 update (same
  sentence in the Nov 2025 update). [ginasthma.org](https://ginasthma.org/wp-content/uploads/2024/05/GINA-2024-Strategy-Report-24_05_22_WMS.pdf)
- ✓ GINA. *Summary Guide for Asthma Management and Prevention*, 2025; *Pocket Guide*, 2023.
- NAEPP. *Expert Panel Report 3*, NHLBI, 2007, Section 3 Component 3 (list from secondary summaries; confirm in the PDF).
- ✓ Expert Panel Working Group of the NHLBI. *2020 Focused Updates to the Asthma Management Guidelines.*
  J Allergy Clin Immunol. 2020;146(6):1217–1270. doi:10.1016/j.jaci.2020.10.003

---

## 3. Weather, settled: are they studied separately?

Yes. Studies take temperature, humidity, temperature change and storms as separate exposures, and the
results differ a lot between them. Pressure is barely studied.

| Signal | Studied as | What the evidence supports | Strength |
|---|---|---|---|
| **Cold, dry air** | Lab challenge; cold spells in time series | Breathing cold, dry air cools and dries the airway and provokes narrowing, especially with effort. Cold spells line up with more admissions in several cities | **Strong** for the mechanism, moderate for visits |
| **Heat and humidity** | Lab challenge; heat in time series | Hot, humid air narrowed airways in people with mild asthma, not in healthy controls (6 per group). Heat is linked to admissions in some places; humidity alone is inconsistent in both directions | Moderate for heat, **weak/mixed** for humidity alone |
| **Temperature change** (day to day, diurnal range, sharp drops) | Time series | About five studies in the adult review; larger daily ranges and sudden drops tied to more ED visits in some cities; others find no effect. No pooled estimate exists | **Mixed**; varies by place and season |
| **Barometric pressure** | Rarely, in single-city studies | The 2019 adult systematic review found **no** included study that measured it. Single studies disagree (one paediatric study: humidity and temperature mattered, pressure didn't). Best read as a marker of fronts and storms, not an effect of its own | **Weak** |
| **Thunderstorms** | Event studies; meta-analysis | Extreme weather pooled: asthma ED visits RR 1.25; thunderstorms RR 1.24. Grass pollen plus storm outflow is the usual story (Melbourne 2016) | **Strong** for epidemics in pollen season, rare events |

So the three weather groups from [weather-grouping.md](../design/weather-grouping.md) Option B hold up:
**Cold, dry air** (strong) · **Heat and humidity** (moderate) · **Sudden change** (mixed: drops, fronts,
pressure swings, storms). Storms also belong to Allergens when pollen is high; we say both facts, never the
mechanism.

Sources:
- ✓ Bodaghkhani E, Mahdavian M, MacLellan C, Farrell A, Asghari S. *Effects of meteorological factors on
  hospitalizations in adult patients with asthma: a systematic review.* Can Respir J. 2019;2019:3435103.
  doi:10.1155/2019/3435103
- ✓ Makrufardi F, Manullang A, Rusmawatiningtyas D, Chung KF, Lin SC, Chuang HC. *Extreme weather and asthma:
  a systematic review and meta-analysis.* Eur Respir Rev. 2023;32(168):230019. doi:10.1183/16000617.0019-2023
- ✓ Hayes D Jr, Collins PB, Khosravi M, Lin RL, Lee LY. *Bronchoconstriction triggered by breathing hot humid
  air in patients with asthma: role of cholinergic reflex.* Am J Respir Crit Care Med. 2012;185(11):1190–1196.
- ✓ Koskela HO. *Cold air-provoked respiratory symptoms: the mechanisms and management.* Int J Circumpolar
  Health. 2007;66(2):91–100.
- ✓ Idrose NS, et al. *A systematic review of the role of grass pollen and fungi in thunderstorm asthma.*
  Environ Res. 2020;181:108911 (conclusions not re-read; aims and scope checked).
- ✓ Thien F, et al. *The Melbourne epidemic thunderstorm asthma event 2016.* Lancet Planet Health. 2018;2(6):e255–e263.

Notes: pressure needs `HourWeather.pressure` in history (same WeatherKit call); without baseline history the
bin is useless. File it as `pressure_change` under Sudden change, never as a reading on its own.

---

## 4. Infections: why it matters, and the catch

Viruses are the commonest flare trigger in the literature: in a year-long community study of 9–11 year olds,
viruses were found in about 80% of reported wheeze or peak-flow-drop episodes ✓. Leaving infections out would
hide the biggest category.

**The catch, from our own code:** baselines are filled in automatically and never carry a voice note, and
`LogEvent.wantsNote` asks only on rescue moments. So the `tag_coldOrFlu` row has flare moments but almost no
baseline moments sampled; it can never pass the 20-baseline gate. Today *every* tag-only category (colds,
stress) is structurally mute. An infection signal has to be measurable on ordinary days too, or asked about
the day rather than the puff.

Source:
- ✓ Johnston SL, Pattemore PK, Sanderson G, et al. *Community study of role of viral infections in exacerbations
  of asthma in 9–11 year old children.* BMJ. 1995;310(6989):1225–1229.

---

## 5. Infections: four ways to get it, honestly

| Option | What it is | Can it reach baselines? | Honest limit |
|---|---|---|---|
| **(a) Self-report** | "Cold or flu" tag from a note (exists) | Only if asked per **day** ("Under the weather today?"), not per puff | Recall; people tag colds they notice |
| **(b) Watch signals** | Resting heart rate, HRV (SDNN), sleeping respiratory rate, sleeping wrist temperature, sleep length, each against your own 30-day usual | **Yes**, passively, for every night | Detects "your body is off its usual", not infection. Stress, alcohol, travel and hard training trip it too. Needs a watch worn to bed |
| **(c) Public data** | CDC wastewater viral activity (flu A, RSV, COVID, weekly, by state) or NREVSS test positivity (weekly, HHS region) | Yes, but it's the same for everyone in your state that week | Regional, weekly: "colds going around", not you. **New data source; needs Pandji's OK** |
| **(d) Don't track** | Say it in "what we can't see" | n/a | Hides the biggest trigger |

**What the wearable studies show:** Fitbit resting heart rate and sleep improved *state-level* flu-like-illness
estimates in five US states (Radin 2020) ✓. In DETECT, adding resting heart rate, sleep and activity to symptoms
raised the AUC for telling COVID-positive from negative among symptomatic people from 0.71 to 0.80 (54
positives) ✓. Stanford's pilot saw heart-rate, step or sleep changes in 26 of 32 infections, often before
symptoms ✓; the follow-up real-time alerts caught most pre-symptomatic cases but also fired for stress,
alcohol and travel ✓. None used wrist temperature, and none claims to diagnose a person.

**HealthKit types** (Apple docs ✓): `restingHeartRate`, `heartRateVariabilitySDNN`, `respiratoryRate` (already
read), `appleSleepingWristTemperature` (iOS 16 / watchOS 9; Series 8+, Ultra, SE 3; one value per night, read
only, needs Sleep Focus; Health shows it after ~5 nights), `sleepAnalysis` (already read). Apple calls wrist
temperature not a medical device ✓.

Sources:
- ✓ Radin JM, Wineinger NE, Topol EJ, Steinhubl SR. *Harnessing wearable device data to improve state-level
  real-time surveillance of influenza-like illness in the USA.* Lancet Digit Health. 2020;2(2):e85–e93.
- ✓ Quer G, Radin JM, Gadaleta M, et al. *Wearable sensor data and self-reported symptoms for COVID-19
  detection.* Nat Med. 2021;27(1):73–77 (online Oct 2020; volume and pages not re-checked).
- ✓ Mishra T, Wang M, Metwally AA, et al. (Snyder MP). *Pre-symptomatic detection of COVID-19 from smartwatch
  data.* Nat Biomed Eng. 2020;4(12):1208–1220. doi:10.1038/s41551-020-00640-6
- ✓ Alavi A, Bogu GK, Wang M, et al. (Snyder MP). *Real-time alerting system for COVID-19 and other stress
  events using wearable data.* Nat Med. 2022;28(1):175–184.
- ✓ Apple. HealthKit `HKQuantityTypeIdentifier.appleSleepingWristTemperature`; Apple Support 102674 (wrist temperature).
- ✓ CDC. *Wastewater Viral Activity Level for SARS-CoV-2, Influenza A and RSV* (data.cdc.gov, weekly, Socrata
  JSON/CSV); CDC NREVSS *Percent of Tests Positive for Viral Respiratory Pathogens* (data.cdc.gov). Endpoint IDs
  not verified against the live portal.

---

## 6. Infections: the recommendation

**(a) + (b), with you as the judge.** The watch never says "infection".

1. A passive bin, `body_off_usual` (v6): **yes** when last night's resting heart rate and one of sleeping
   respiratory rate or wrist temperature are both above your own 30-day usual; **missing** when there's no watch
   night (never "no"). It's computed for flare and baseline frames alike, like `exertion`, so it can pass the gate.
   It files under **Infections**, labelled for what it is.
2. When it's on for a morning, ask once, the day after, in the 8 am look-ahead or on Now: **"Your nights have
   been off your usual. Coming down with something?"** Yes / No / Not sure. A yes sets a day-level "cold or flu"
   for that day and the next few, on every moment including baselines. This is what fixes slide 4's catch.
3. (c) later, as context only, never a bin: "Colds and flu are going around in your state this week." It could
   be fetched as the national table and filtered on the phone so no location leaves it. Ask Pandji first.

**What it may say on screen** (gated, words only):
- Pattern: "Your flare days often came when you'd said you were coming down with something."
- Watch only: "Your flare days often followed nights your heart and breathing ran above your usual."
- Never: "infection", "virus", "you were sick", "your cold caused it".

New Health reads (resting heart rate, HRV, wrist temperature) widen an existing prompt; still a permission
change, so ask before building.

---

## 7. Exercise, stress, menstrual cycle

| Trigger | Evidence | HealthKit | Today |
|---|---|---|---|
| **Exercise** | **Strong.** Exercise-induced bronchoconstriction is common in asthma; cold, dry or polluted air makes it likelier ✓ | Workouts, steps (read) | `exertion` bin, passive, both kinds of frame. Works |
| **Stress and emotion** | **Moderate.** A meta-analysis of 10 prospective cohorts (31,432 adults) links psychological dysfunction to more exacerbations ✓; laughing and crying hard are GINA symptom triggers ✓ | State of Mind (iOS 18 ✓, read, only when logged); HRV is too noisy to call stress | Tags only, so mute (slide 4). A logged State of Mind with unpleasant valence could be a day-level bin, missing when not logged |
| **Menstrual cycle** | **Weak to moderate.** Perimenstrual worsening reported in roughly 19–40% of women with asthma; no agreed definition ✓ | `menstrualFlow` (category, exists ✓) | Not read. A `cycle_phase` bin (perimenstrual yes/no, missing when not tracked) is cheap. Sensitive: opt-in, separate ask |

Sources:
- ✓ Parsons JP, Hallstrand TS, et al. *ATS Clinical Practice Guideline: Exercise-induced Bronchoconstriction.*
  Am J Respir Crit Care Med. 2013;187(9):1016–1027.
- ✓ Zhang L, et al. *Co-morbid psychological dysfunction is associated with a higher risk of asthma
  exacerbations: a systematic review and meta-analysis.* J Thorac Dis. 2016;8(6). PMC4886028 (pooled RR not re-read).
- ✓ Graziottin A, Serafini A. *Perimenstrual asthma: from pathophysiology to treatment strategies.* Multidiscip
  Respir Med. 2016;11:30. doi:10.1186/s40248-016-0065-0

---

## 8. The proposed lens

Six axes on the radar. The air keeps its three inks; everything about you prints in the text colour.

| Category (radar axis) | Ink | Have | Could add | Can't | Evidence |
|---|---|---|---|---|---|
| **Allergens** | yellow | pollen (weed; tree, grass with Ambee), tags pets, mold | storms in pollen season (shared with Weather) | dust mites, indoor pets without a note | Strong |
| **Irritants & pollution** | aqua | PM2.5, ozone, smoke at point, tags smoke, dust, cleaning, scents, cooking | NO₂, PM10 | tobacco smoke indoors, work fumes | Strong |
| **Weather** · Cold, dry air | pink | `temp=cold`, `humidity=dry`, tag coldAir | | | Strong |
| **Weather** · Heat and humidity | pink | `temp=hot`, `heat_alert`, `humidity=humid` | | | Moderate |
| **Weather** · Sudden change | pink | `temp_drop` | `pressure_change`, `storm` | | Mixed |
| **Exercise** | text | `exertion`, tag exercise | | | Strong |
| **Infections** | text | tag coldOrFlu (mute today) | `body_off_usual`, day-level "coming down with something" | lab-confirmed infection | Strong trigger, weak measure |
| **Stress & emotion** | text | tags stress, laughing/crying (mute today) | State of Mind day bin | | Moderate |
| *What we can't see* | text, no axis | | `cycle_phase` (opt-in) | medicines, reflux, work exposures, adherence | Listed, not scored |

**Radar:** Weather is one axis (pink) whose strength is its strongest sub-group; the card shows the three.
Infections and Stress draw as **"not yet"** (dotted, no fill) until they have baselines, so the shape never
suggests "no" where we just can't see. "What we can't see" is a line under the radar, not an axis.

**Archetypes:** air ones stay (Weather-sensitive, Allergen-led, Air-quality-led, Seasonal, Hot hazy days,
Airborne). "Effort-led" stays for Exercise. Add **"Comes with colds"** (Infections) and **"Weather and colds"**
(the cold-season pair). Body-only categories never name an archetype until they pass the gate on their own.
Never "you're allergic", "infection-triggered", or anything diagnostic.

---

## 9. What changes in code, what stays

**Changes (`AirProfile`, `Archetype`):**
- `Category`: `weather, biologics, particulates, exercise, infections, stress` (keep raw values `biologics`,
  `particulates` for Profile History; retitle to "Allergens", "Irritants and pollution"). `exertion` → `exercise`
  needs a migration of saved `Archetype.Kind`, or keep the raw value.
- `of(bin:)` becomes `of(bin:level:)` so Weather can sub-group by level (`temp=cold` vs `temp=hot`).
- `tag_coldOrFlu`, `body_off_usual` → infections; `tag_stress`, `tag_laughingOrCrying` → stress; `exertion`,
  `tag_exercise` → exercise.

**Stays:** the lift table, its bins and edges, `BinSpec.version` (until a new bin lands), scoring, narrator I/O.
New bins (`pressure_change`, `storm`, `body_off_usual`, a day-level cold, `cycle_phase`) each bump the version
and need baseline history before they mean anything.

**Minimum before a category speaks:** the existing gate, per row: 8 flare moments and 20 baselines sampled for
that bin, 4 in the level, lift above 1.25. A category says something only if one of its rows passed; "early"
and "not yet" read in words. No new thresholds.

---

## 10. Open questions for Pandji

1. Six axes, or keep four (air three + "You") with Exercise, Infections, Stress inside "You"?
2. OK to ask Health for resting heart rate, HRV and wrist temperature (same prompt, more types)?
3. The morning "Coming down with something?" question: worth one more tap on ordinary days?
4. Public "colds going around" (CDC wastewater): later, never, or a demo first? It's a new data source.
5. Menstrual cycle: in scope for TestFlight, or a later opt-in?
6. Storms: file under Weather, Allergens, or show in both?

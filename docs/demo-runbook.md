# felt air: demo runbook (final presentation, Nov 20, 2026)

Presenters: Pandji and April. The demo is about 6 minutes. Everything runs from **Settings › Demo and development › Presentation**: one tap per step.

## Who we are showing: the navigator

A travel nurse between contracts. Six weeks: two finishing a contract in **Fresno**, twelve days at her sister's in **Denver**, two weeks into a new contract in **St. Louis**.

Why her:
- Every move resets "usual". New air, new home, no regular doctor. An app that assumes one home flattens exactly what matters to her.
- She is health-literate. She doesn't need to be told what asthma is; she needs her own record.
- The finding is the story: **it isn't the city. Fine particles show up on her inhaler days in all three.**

What is real and what is made up:
- **Made up:** her, her moments, her notes.
- **Real:** the outdoor air on every moment. Open-Meteo for the six weeks (PM2.5, ozone, temperature, humidity), Ambee for the last two days in St. Louis (with pollen). Each reading names its source in the moment's details.
- Nothing is forced. Her rescue moments were placed mostly on hours when the real PM2.5 was up, and the pattern comes out of the same maths as anyone's data.

(Considered and set aside: a digital nomad, which reads as a lifestyle choice, and a migrant, where tracking location is a much heavier subject than a six-minute demo can carry.)

## Night before

- [ ] Refresh the air (it is dated; do this the day before):
  ```sh
  python3 ios/scripts/pull-navigator-air.py
  ```
- [ ] Build to the phone:
  ```sh
  cd ios && xcodegen && open AsthmaLog.xcodeproj
  ```
  Pick the iPhone, press ⌘R. Check Signing on the AsthmaLog and AsthmaLogWatch targets if Xcode complains.
- [ ] The look is now April's by default (light, flowers). If the phone still shows the old dark look, it has an old switch saved: Demo and development › More › Design switches › App look › **felt air (flowers, the default)**.
- [ ] Tap **Presentation › 1** once and log a rescue, so the Apple Health sheet appears now and not in front of the room.
- [ ] Run steps 1 to 5 once, in order.
- [ ] Charge the phone, the watch and the felt button.

## So the Lock Screen card and the notification always appear

The card (a Live Activity) only shows when felt air was logged from the **felt button or the watch** while the phone is locked. A tap in the app never triggers it.

In felt air › Settings › Logging:
- [ ] **After a press, ask what was going on**: on
- [ ] **Keep felt air on the Lock Screen**: on

In iOS Settings › Apps › felt air:
- [ ] **Notifications**: Allow, with Lock Screen and Banners ticked
- [ ] **Live Activities**: on

In iOS Settings:
- [ ] **Focus: off.** No Do Not Disturb, no Sleep. A Focus hides both the card's alert and the notification. If you need quiet, flip the ring switch to silent instead.
- [ ] **Notifications › Screen Sharing › Allow Notifications: on**, if the phone is mirrored to the projector. iOS hides notifications while mirroring unless this is on.
- [ ] Face ID & Passcode › Allow Access When Locked › **Live Activities: on**

Right before you present:
- [ ] Open felt air, wait two seconds, then lock the phone. iOS only lets an app start its card from the foreground, and the card lapses after 8 hours. Opening the app renews it.
- [ ] Check the standby card is on the Lock Screen.
- [ ] Press the watch's **Rescue** (or the felt button). The card should light up and ask what was going on.

If the card doesn't appear, the notification is the fallback: "Rescue logged · Add what was going on, while it's fresh."

## The script

**1 · Now, then log a puff** (Presentation › 1)
> "This is a travel nurse, two weeks into St. Louis. The flowers are the outdoor air right now: taller means more of it."

Tap **+**, log a rescue, add a voice note. Say something with a trigger in it ("I ran for the bus in the cold").
> "It wrote down when, where and the outdoor air. It suggests tags from my words, and I choose. It never decides how I felt."

**2 · Look back at a moment** (Presentation › 2)
> "One of her inhaler moments. The sentence is what the air was. Open it and every reading says where it came from and how far away."

**3 · Timeline to calendar** (Presentation › 3)
Drag the timeline, then open **Moments**: Day, Month, Year. Then **Map**.
> "Six weeks, three cities. The same record at three distances."

**4 · Insights** (Presentation › 4)
> "What her inhaler days share: fine particles. In Fresno, in Denver, in St. Louis. It's in words, not a score, and it says what it doesn't track yet."

**5 · Evening look-back** (Presentation › 5)
> "After six, the app lays out what it recorded today and asks for the part it couldn't see. 'Not sure' is a real answer."

**Closed-app moment** (any time after step 1): lock the phone, press the watch.
> "No app open. The Lock Screen asks once, while it's fresh."

**Fallback · Still learning**: a week of made-up data, if you want to show Insights before it has learned.

## One line per feature

| Feature | Hide and reveal (Pandji) | Who names the feeling (April) |
|---|---|---|
| Logging a puff | One press hides the form. What it stamped is one tap away, with its source. | It records a dose. It doesn't ask if you're okay. |
| High-puff card | The rule is shown with where it comes from, so you weigh it instead of obeying it. | It states a guideline. It doesn't say it's worried. |
| Lock Screen card | It says what was recorded and lets you decline to add more. | It asks once and leaves. No streaks, no "we missed you". |
| Voice note and tags | The app shows which words it picked up, and you can overrule them. | It isolates words. You name the feeling. |
| Timeline, calendar, map | The ordinary days, the half of the comparison usually hidden, are on the page, and so are the gaps. | A record, not a scorecard. No good or bad days. |
| Moment details | Every reading: source, distance, time, outdoor only. What it can't see is said out loud. | Readings, never a verdict on you. |
| Insights | The pattern is the visible difference between inhaler days and ordinary days, in words. | "Looks more like your inhaler days", never "you will". |
| Evening look-back | It lays out what it holds about your day and asks for what it couldn't see. | It prompts memory with facts, not a persona asking how your day was. |
| The navigator | A system that assumes one home flattens her. Showing the source and place of every reading gives the comparison back. | It follows her without pretending to know her. |

Opening line, if useful: *"The app hides the work so logging is one press. Everything it hides, it will show you if you ask, and it never claims to know how you felt."*

## If something breaks

| Problem | Do this |
|---|---|
| Old dark look | Design switches › App look › felt air (flowers, the default) |
| Insights says "Still learning…" | You are on your own data. Tap Presentation › 4. |
| Evening screen pops up on its own | It is after 6 pm, or "Evening look-back at any hour" is on (Stage a moment). Tap **Do later**. |
| Evening screen is empty or missing | Run step 1 first, or turn on "Evening look-back at any hour". |
| No Lock Screen card | Open the app, lock, press again. Still nothing: show the notification, or say "iOS limits these to eight hours". |
| No network | The navigator works offline. A new log saves without air: "it fails open." |
| Navigator missing from Load a data set | `navigator-air.json` wasn't bundled. Run the pull script and rebuild. |
| App crashes | Play the GIFs in the deck. |

To get your own data back: Demo and development › Load a data set › **My data**.

## Likely questions

**Is that real data?** The air is: Open-Meteo for six weeks, Ambee for the last two days. The person and her moments are made up. Ambee's current plan only returns two days of history, which is why there are two sources, and the app says which is which.

**Does it predict attacks?** No. At most it says a day "looks more like your inhaler days".

**Why not detect stress or mood from the voice?** On purpose. The app picks out words. A person names a feeling.

**Indoor air?** It can't see it, and it says so.

**Is the puff advice medical?** It is guideline wording with the source named. It has not been reviewed by a clinician yet and would be before any user testing. felt air is not a medical device.

**Where does my data go?** It stays on the phone. No account, no server.

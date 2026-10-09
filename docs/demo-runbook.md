# felt air: demo runbook (studio critique)

Presenter: Pandji. Backup and watch: April. Total demo: about 5 minutes.

## Night before

- [ ] Charge the iPhone. Charge the Apple Watch if you can. The demo works without it.
- [ ] Build to the phone:
  ```sh
  cd ~/Developer/asthma-logger && git switch claude/ambient-journal-watch && cd ios && xcodegen
  open AsthmaLog.xcodeproj
  ```
  In Xcode, check **Signing & Capabilities → Team** on both the **AsthmaLog** and **AsthmaLogWatch** targets. Pick the iPhone as the destination. Press ⌘R.
- [ ] Watch app missing? On the iPhone: **Watch app → Available Apps → felt air → Install**.
- [ ] Gear (top right) → **Add a demo week to the Journal**. Check the strip fills in.
- [ ] Tap **Rescue** once (bottom of the screen). Tap **Allow** on the Apple Health sheet. Do this now, not in front of the room.
- [ ] Find a humid rescue moment in the demo week. Note which day it is.
- [ ] Open `docs/gallery/private/videos/felt-air-demo-final.mp4` in QuickTime. Leave it paused on the first frame. (Local only, not in git.)

## Morning of

- [ ] Airplane mode test: turn it on, open the Journal, tap through the demo week and one chart. It should all work offline. Turn airplane mode off.
- [ ] Do Not Disturb on, on both phone and watch.
- [ ] Brightness up, auto-lock off (Settings → Display & Brightness → Auto-Lock → Never).
- [ ] Location and Wi-Fi on. Open the app once in the room so the live air has a fresh reading.
- [ ] Gear → **Play onboarding demo** is the first thing you'll tap. Know where it is.

## The 5-minute script

**1. Onboarding (1 min).** Gear → **Play onboarding demo**.
> "No account. It opens on a photo, one sentence, and a plain line: outdoor air only, not medical advice."

> "The photos are on purpose. This is a chronic condition. We wanted it to feel like going outside, not like a medical chart."

Tap through: how you'll log (Watch, app, or felt button), location ("stays on this phone"). On the last screen tap **Skip for now**. (**Check the air** saves a real "I'm okay" moment. Fine if you want it, but it needs network.)

**2. Journal (1.5 min).**
> "This is the week. Each square is one moment. Its weave is the air outside at that time: denser means higher."

Tap the info button to show the key if anyone looks lost. Then tap the humid rescue moment.
> "Watch the background. The whole screen takes on the air of the moment you pick. Humid day, different colour."

Tap a calmer moment, then back, so the shift is easy to see.
> "The two counts up top are just counts. Rescue, standard, this week."

**3. Moment chart (1 min).** Tap the card under the strip. "How the air changed" sits at the top.
> "This is the air over the week around that moment. Orange is rescue, blue is standard, open rings are 'I'm okay' moments. The circle is this one."

Switch **Air → Humidity**.
> "These are only the moments we captured. The line joins them. It isn't a sensor running all day."

**4. Log live (45 s).** Back to the Journal. Tap **Rescue** on the phone, or April presses **Rescue** on the watch.
> "One tap. It saves the time, the place, and the outdoor air. It goes to Apple Health too."

The new square shows a spinner, then fills in.

**5. Close (45 s).**
> "Three rules we kept. Counts, not ratios or scores: '8 of 14 inhaler days', never a percent. No blame: this isn't a performance score, asthma is often out of your control. And outdoor air only: we say where each number comes from and how far away it was measured."

## If something breaks

| Problem | What you'll see | Do this |
|---|---|---|
| No network | New log says it couldn't get the air | Say "it fails open: the log still saves." Stay on the demo week. It works offline. |
| Location denied | Log saves with no place or air | Same line. Fix later in iOS Settings → felt air → Location. |
| Health sheet appears | Apple Health permission sheet | Tap **Allow**. Say "it asks the first time you log." |
| Watch not connected | Watch says "saved · sends to iPhone" | Log on the phone instead. "The watch queues it and sends when it can." |
| App crashes or hangs | — | Switch to QuickTime, play `felt-air-demo-final.mp4`, keep talking over it. |
| Demo week gone | Empty strip | Gear → **Add a demo week to the Journal**. |

## Likely questions

**Does it predict attacks?**
No. It compares the air on your inhaler moments with your "I'm okay" moments. At most it will say a day "looks more like your inhaler days."

**What about indoor air?**
It can't see it. Every number is labelled outdoor, with its source and distance. Indoor is a known gap.

**Pollen?**
Not yet. Our pollen source is still being sorted out, so the app says "Not yet" instead of guessing.

**When do I see a pattern?**
After 8 inhaler uses and 20 "I'm okay" moments. Until then Insights shows progress. The demo week is labelled Demo and doesn't count.

**Where does my data go?**
It stays on the phone. No account, no server. Inhaler uses can be saved to Apple Health if you allow it.

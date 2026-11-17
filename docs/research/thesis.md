# Thesis, research questions and studies

Nov 17, 2026. The thesis statement is the owner's (chosen Nov 17). The questions and studies are a first draft
for Pandji and April to edit. The sources behind them are in [literature-review.md](literature-review.md); the
design decisions they test are in [../design/hide-reveal-ledger.md](../design/hide-reveal-ledger.md).

## Thesis

> Systems that index the world make it usable by flattening it: many measurements become one number, one
> colour, one ranked feed. Every flattening is a decision about what to hide, and when people cannot see that
> decision or undo it, they lose the ability to judge for themselves. My work rebuilds these summaries so they
> can be opened, giving back what was hidden and, with it, the choice of what to do.

## Terms, used the same way everywhere

| Term | Means here |
|---|---|
| **Flatten** | Turn many different things into one value on one scale, and seal how it was done |
| **Summary** | What the person is shown: a number, a colour, a word, a ranked list, a map |
| **Open** | Get from the summary to what it was made from, and be able to act on what you find |
| **Distance back** | How many steps it takes to open a summary, and whether you need help to do it |
| **Whose number** | Everyone's (a population's), the data's (the sample's), the air's (a reading), or yours |
| **Judge for yourself** | Say what the summary is made of, say what it leaves out, and decide with a reason of your own |

"Judge for yourself" is the working definition of agency. It is something a person can be seen to do in a
session, which is why it is defined this way.

## Research questions

**RQ1. What does each summary hide, who decided that, and how far is the way back?**
Asked of the things the works answer (the Air Quality Index, a bird-sound map, an endless feed, a compiled web
page) and of the works themselves. An audit, not a study with people.

**RQ2. When a summary can be opened, do people open it, and what do they do with what they find?**
The thesis fails quietly if the way back exists and nobody takes it.

**RQ3. Does a number about you, set beside the number about everyone, change what you feel able to decide?**
The personal threshold ("below about 40°F", beside the general mark for cold) is the clearest case. No study of
this was found in the literature search, so this question is the most likely to be new.

**RQ4. What does opening cost, and what is the least a summary can show and stay honest?**
Attention, alarm, misreading and trust. This is where "words, not counts" is tested, since the literature is
most divided there.

## Studies

Small sessions, one person at a time, 20 to 30 minutes. The aim is clear preferences and clear failures, not
significance (as in `ab-tests.md`). Each study says in advance what would count against the thesis.

### S1. One hour, shown twice (RQ2, RQ3)

- **What.** The same hour shown as the AQI shows it (number, colour, category, main pollutant) and as felt air
  shows it (the air in parts, each with its source and distance). Each person sees both, in alternating order.
- **The hour.** The EPA's own worked example: ozone 126, fine particles 102, carbon monoxide 90, reported as
  "126, ozone". Staged, and labelled as the EPA's example.
- **Ask.** "You have asthma and planned a run at five. What do you do, and why?" Then: "What is this made of?"
  "Where was it measured?" "What would you want to know that isn't here?"
- **Note.** The decision and the reason given; how many true things they can say about what the summary is made
  of; whether they name a limit (distance, outdoor only, time); whether they open anything unprompted;
  confidence, one to five.
- **Supports the thesis if** reasons in the felt air version name a specific part of the air or a limit of the
  measurement, and reasons in the AQI version stop at the colour.
- **Counts against it if** decisions and reasons are the same in both, or the felt air version is slower, more
  alarming, or no better understood.
- **Needs.** Two still screens. Can be run on paper this week.

### S2. Yours beside everyone's (RQ3)

- **What.** The "Cold, for you" card in its three built versions (sentence with the number, words only, the
  dots; test C4) plus a fourth showing only the general mark. One version per person. Data set: "Cold, below
  about 40°F".
- **Ask.** "In your own words, what is this telling you?" "It will be 38° tomorrow morning. Does anything
  change for you?" "Is felt air saying cold causes your flares?"
- **Note.** Whether they make a plan of their own; whether they use cause or diagnosis words; whether they
  notice the two numbers differ and what they make of it.
- **Supports the thesis if** people with the personal number state a plan that uses it, and people with only
  the general mark do not.
- **Counts against it if** the personal number is read as a diagnosis or a rule to obey, or makes no
  difference.
- **Needs.** The built switch (Settings › Demo and development › What we're testing › C4). The general-mark
  line needs its wording fixed first: no source was found for "for most people, cold starts at freezing".

### S3. Does anyone open it? (RQ2, RQ4)

- **What.** First use with no tips, in two looks: felt air (hold to read) and April's Menus look (readings
  always on the page). One look per person.
- **Ask.** "What is in the air right now, and where was it measured?" Then, after a pattern is shown: "What is
  that based on?"
- **Note.** Found without help, yes or no; time; the path they tried first. Separately, fill in the distance
  back for each summary in the app: steps to the reading, to its source, to the moments behind a pattern, to
  the counts.
- **Supports the thesis if** most people reach the reading and its source without help in at least one look.
- **Counts against it if** the way back is there and people don't find it or don't want it. The literature
  warns of this: most tracker use is a glance of a few seconds.
- **Needs.** A build with April's branch (not compiled here).

### S4. Words, counts, or words that open (RQ4)

- **What.** One pattern said three ways: "often" (as built); "8 of 14 flare days, 3 of 40 ordinary days";
  "often", with a tap that shows the days behind it. One version per person. Includes test A4 (the sparkle).
- **Ask.** "Out of ten flare days, on how many was ozone high?" "Did ozone cause them?" "How does reading this
  make you feel about your asthma?"
- **Note.** The spread of the estimates; cause words; whether the feeling is about themselves ("I'm bad at
  this") or about the air.
- **Supports the thesis if** words that open do as well as counts on understanding and better on how it
  feels.
- **Counts against it if** "often" alone is read very differently by different people and the tap is not
  used. Then the counts belong on screen, in some form.
- **Needs.** Three mock screens. The third version is not built.

### S5. Can you catch the mistake? (RQ2)

- **What.** A made-up person's data with two planted errors: an ordinary hour placed at home when they were
  away, and a wrong tag. With and without a way to see the ordinary days.
- **Ask.** "Something here is wrong. Can you find it and fix it?"
- **Note.** Found, fixed, or neither; what they tried.
- **Supports the thesis if** people can only catch the baseline error when the ordinary days can be seen.
- **Needs.** The "see your ordinary days" list, which is not built. After the talk.

### S6. Four works, one audit (RQ1)

- **What.** A table. Rows: the AQI as AirNow shows it, a bird-sound map, an endless feed, a compiled web page,
  and then felt air, the birdsong project, the colour scroller and the author's own site. Columns: what is
  hidden, who chose it and whether the choice is stated, the distance back, whose number it is.
- **Why.** It turns four separate critiques into one test applied four times, and shows where the works
  themselves fall short.
- **Needs.** No participants. Can be drafted now; the birdsong row needs the project's own description.

### S7. Four weeks with it (all questions)

- **What.** Five to eight people from the TestFlight group use felt air for four weeks, with a talk at the
  start and the end.
- **Ask at the end.** "What did felt air tell you that you didn't know?" "What did you look into further?"
  "Did you do anything differently?" "Did anything you told a doctor or anyone else change?"
- **Note.** What they opened is by their own account. Counting it in the app would be new logging, which
  today's rule forbids ("nothing is logged or sent"), so that needs a decision first.
- **Needs.** A stable build. After the talk.

## Order

| When | Study | Why then |
|---|---|---|
| This week, before the talk | S6 (draft), S1 and S2 with three to five people each | Paper or built already; they test the lead picture and put one participant behind the agency claim |
| Next | S4, S3 | S4 needs mock screens; S3 needs a build with both looks |
| After the baseline list is built | S5 | Tests the weakest row in the ledger |
| When a build is stable | S7 | Only time shows whether opening survives the first week |

## Before recruiting

- **Who.** People who use a rescue inhaler, for S1 to S5 and S7. Fellow students are fine for a first pass at
  S1 and S4, said as such when presented.
- **Role-play only.** Sessions use made-up data and imagined situations. Nobody is asked to change what they
  do about their asthma, and every session opens with "this is not medical advice".
- **Ethics review.** Check with the thesis advisor whether these sessions need review by the university's
  board before any are run or shown. This draft assumes nothing about that.
- **Notes.** Keep the arms in force and the observations per session, as `ab-tests.md` already describes.

# HCI and design literature on agency, personal data, self-tracking and data representation (base for the eight design decisions)

**How to read these notes**

- Decisions are numbered as in the brief: **D1** no counts/scores, words only · **D2** personal threshold beside population threshold · **D3** provenance on every reading, missing shown as missing · **D4** no cause, no prediction, forecast drawn as a sketch · **D5** summaries open into their sources · **D6** one-press felt button, voice later, automatic baselines · **D7** riso/textile language, ambiguity, one warm ink · **D8** deterministic inspectable pattern-finding, model only suggests tags.
- **Verification levels.** `[A]` = bibliographic details and abstract content confirmed in this session from a publisher, DOI, PubMed/PMC, institutional repository or author page (via search result of that page). `[B]` = bibliographic record confirmed (DBLP, repository) but abstract seen only in fragments or via a secondary summary. `[U]` = not checked this session; listed from prior knowledge only; verify before citing.
- **Quotes.** Every quote below is text returned from the cited page or its abstract during this session. Almost all were read through a search/fetch tool, not by opening the PDF, so **check each quote against the publisher version before it goes into the thesis**. Where I only have a paraphrase, no quotation marks are used.
- DOIs marked "(DOI from memory)" were not shown on a page I read; confirm at doi.org.

---

## 1. Personal informatics: models, lived practice, burden, lapsing, and the costs of quantification

### Takeaway
The field moved from a rational, behaviour-change pipeline (Li et al. 2010) to "lived informatics", where tracking is intermittent, emotional and often dropped; there is direct experimental and qualitative evidence that measurement can reduce enjoyment and make illness more salient. This supports D1 and D6, but the same literature shows monitoring also works for goal attainment (see section 9), so "no numbers" has to be argued as a choice for this condition and this audience, not as a general truth.

### Cited Findings

1. **Li, I., Dey, A., & Forlizzi, J. (2010). A stage-based model of personal informatics systems. CHI '10, 557–566.** DOI 10.1145/1753326.1753409 (DOI from memory). `[B]`
   - Claim: from surveys and interviews with people who collect personal data, derives five stages (preparation, collection, integration, reflection, action) and catalogues barriers in each; barriers cascade to later stages. — [author page](https://ianli.owlstown.net/publications/17-a-stage-based-model-of-personal-informatics-systems)
   - Maps to: **D6** (collection barriers justify one-press capture and automatic baselines); **D5** (integration/reflection barriers justify doing the integration in code and letting the person open it). Also the model the thesis argues against: it treats the person as a rational analyst of their own index.

2. **Rooksby, J., Rost, M., Morrison, A., & Chalmers, M. (2014). Personal tracking as lived informatics. CHI '14, 1163–1172.** DOI 10.1145/2556288.2557039. `[A]`
   - Claim: interview study of activity-tracker users; people interweave several trackers, tracking is social, and people adopt different "styles" of tracking rather than a rational optimisation loop. — [Glasgow repository](https://eprints.gla.ac.uk/94944)
   - Maps to: **D1, D6**. Supports "embodied self over quantified self": tracking is something lived, not a dashboard to be optimised.

3. **Epstein, D. A., Ping, A., Fogarty, J., & Munson, S. A. (2015). A lived informatics model of personal informatics. UbiComp '15, 731–742.** DOI 10.1145/2750858.2804250. `[B]`
   - Claim: existing models assume behaviour-change goals; from surveys of trackers of physical activity, finances and location (105, 99 and 83 respondents) and 22 interviews, proposes a model that includes deciding, selecting, lapsing and resuming. — [Self-Research library record](https://library.selfresearch.org/research/a-lived-informatics-model-of-personal-informatics/); [DBLP](https://dblp.dagstuhl.de/rec/conf/huc/EpsteinPFM15.html)
   - Maps to: **D6** (design for lapses: automatic baseline back-fill means a lapse in logging does not destroy the comparison set); **D3** (lapsed periods are "missing", not "good").

4. **Choe, E. K., Lee, N. B., Lee, B., Pratt, W., & Kientz, J. A. (2014). Understanding quantified-selfers' practices in collecting and exploring personal data. CHI '14, 1143–1152.** DOI 10.1145/2556288.2557372. `[A]`
   - Claim: analysis of 52 Quantified Self meetup talk recordings. Even these "extreme users" fall into recurring pitfalls.
   - Quote: "tracking too many things, not tracking triggers and context, and insufficient scientific rigor." — [Microsoft Research page](https://www.microsoft.com/en-us/research/publication/understanding-quantified-selfers-practices-collecting-exploring-personal-data/)
   - Maps to: **D6** (context is stamped automatically, so "not tracking triggers and context" is designed out); **D8** and **D4** (rigor is put in code: gates, baselines, no causal language). Strong single citation for why baselines are sampled automatically.

5. **Epstein, D. A., Caldeira, C., Figueiredo, M. C., et al. (2020). Mapping and taking stock of the personal informatics literature. Proc. ACM IMWUT 4(4), Article 126.** DOI 10.1145/3432231. `[A]`
   - Claim: maps 523 publications (ACM DL, IEEE Xplore, PubMed). The literature concentrates on health and wellness and on barriers to collection and reflection; calls for work on other stages, more domain experts, and more attention to privacy and ethics. — [NSF PAR record](https://par.nsf.gov/biblio/10252696)
   - Maps to: framing. Use to position the project in the field and to show that the ethics of representation is an acknowledged gap.

6. **Lazar, A., Koehler, C., Tanenbaum, T. J., & Nguyen, D. H. (2015). Why we use and abandon smart devices. UbiComp '15, 635–646.** DOI 10.1145/2750858.2804288 (DOI from memory). `[A]`
   - Claim: participants bought devices toward a self-defined goal and were interviewed after two months.
   - Quote (reasons for abandonment): devices "did not fit with the[ir] conceptions of themselves, the data collected by devices were perceived to not be useful, and device maintenance became unmanageable." — [author PDF](https://thatlab.umd.edu/papers/2015_p635-lazar.pdf)
   - Maps to: **D1** (data that clashes with self-image is dropped), **D6** (maintenance burden).

7. **Clawson, J., Pater, J. A., Miller, A. D., Mynatt, E. D., & Mamykina, L. (2015). No longer wearing: investigating the abandonment of personal health-tracking technologies on Craigslist. UbiComp '15.** DOI 10.1145/2750858.2807554. `[B]` — author list from memory; only the title, venue and DOI were confirmed (in the reference list of [Epstein et al. 2016, PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5428074)). Abstract not read. Recalled claim (unverified): abandonment is often not failure; people sell devices because goals were met or life changed.
   - Maps to: **D6**; nuance for "abandonment = bad design".

8. **Epstein, D. A., Caraway, M., Johnston, C., Ping, A., Fogarty, J., & Munson, S. A. (2016). Beyond abandonment to next steps: understanding and designing for life after personal informatics tool use. CHI '16, 1109–1113.** DOI 10.1145/2858036.2858045. `[A]`
   - Claim: survey of 193 people and 12 interviews; identifies six reasons people stop tracking and five perspectives on life after tracking. — [PMC author manuscript](https://pmc.ncbi.nlm.nih.gov/articles/PMC5428074)
   - Maps to: **D6**, and the "Learned" end state of the app (a diary that can be finished is legitimate).

9. **Etkin, J. (2016). The hidden cost of personal quantification. Journal of Consumer Research, 42(6), 967–984.** DOI 10.1093/jcr/ucv095. `[A]`
   - Quote: "Six experiments demonstrate that while measurement increases how much of an activity people do (e.g., walk or read more), it can simultaneously reduce how much people enjoy those activities." — [Duke Scholars record](https://scholars.duke.edu/publication/1134328)
   - Maps to: **D1** (support and challenge in one source). Measurement makes an activity feel like work; it also increases output. For an asthma diary the "output" is not something to increase, which is the argument for dropping counts. Note the experiments are on enjoyable activities (walking, reading), not symptom logging: an extrapolation.

10. **Ancker, J. S., Witteman, H. O., Hafeez, B., Provencher, T., Van de Graaf, M., & Wei, E. (2015). "You get reminded you're a sick person": personal data tracking and patients with multiple chronic conditions. Journal of Medical Internet Research, 17(8), e202.** DOI 10.2196/jmir.4209. `[A]`
    - Claim: semi-structured interviews with 22 patients and 7 providers. Tracking felt like work; health data carried emotional and moral weight rather than being neutral; patients noticed clinicians trusted machine-measured data more. The authors suggest developers wrongly assume patients want to self-track. — [JMIR](https://jmir.org/2015/8/e202)
    - Maps to: **D1** and "don't blame the user" (the best single empirical citation for it); **D6**. Caveat: the sample was patients with multiple chronic conditions (diabetes, heart disease, pain, depression), not asthma.

11. **Kristensen, D. B., & Ruckenstein, M. (2018). Co-evolving with self-tracking technologies. New Media & Society, 20(10), 3624–3640.** DOI 10.1177/1461444818755650. `[A]`
    - Claim: longitudinal view of Quantified-Self-inspired tracking as "a laboratory of the self" in which people co-evolve with devices; some aspects of the self are amplified while others are reduced and restricted. — [Crossref record](https://api.crossref.org/works/10.1177%2F1461444818755650)
    - Maps to: thesis core (indexing amplifies some aspects and restricts others) and **D1**.

12. **Pink, S., Ruckenstein, M., Willim, R., & Duque, M. (2018). Broken data: conceptualising data in an emerging world. Big Data & Society, 5(1).** DOI 10.1177/2053951717753228. `[A]`
    - Claim: "broken data" as a concept-metaphor: data are always in processes of decay, repair and re-making; one of three cases is "the incompleteness, inaccuracy and dispersed nature of personal self-tracking data". — [Monash record](https://research.monash.edu/en/publications/broken-data-conceptualising-data-in-an-emerging-world/)
    - Maps to: **D3** (show gaps and repair instead of hiding them), **D7**.

13. **Lupton, D. (2017). Feeling your data: touch and making sense of personal digital data. New Media & Society, 19(10), 1599–1614.** DOI 10.1177/1461444817717515. `[A]`
    - Claim: three-dimensional materialisations of personal data invite people to "feel your data", in both the tactile sense and the sense of visceral response. The term "data sense" comes from the later Lupton, Pink, LaBond & Sumartojo (2018) paper, not this one (that later paper is `[U]`). — [Canberra record](https://researchprofiles.canberra.edu.au/en/publications/feeling-your-data-touch-and-making-sense-of-personal-digital-data/)
    - Maps to: **D6** (felt button), **D7** (material/print language).

14. **Kennedy, H., & Hill, R. L. (2018). The feeling of numbers: emotions in everyday engagements with data and their visualisation. Sociology, 52(4), 830–848.** DOI 10.1177/0038038516674675. `[A]`
    - Quote: "It is not only numbers but also the feeling of numbers that is important." — [White Rose repository](https://eprints.whiterose.ac.uk/id/eprint/106567/)
    - Maps to: **D1, D7**. People meet data emotionally first; a design that plans for the feeling is not less rigorous.

### Inferences
- The strongest chain for D1 is: Ancker 2015 (tracking reminds people they are ill; data are morally loaded) + Etkin 2016 (measurement turns activity into work) + Lazar 2015 (data that conflicts with self-image is abandoned). None is about asthma.
- D6's automatic baselines answer two named failures at once: Choe's "not tracking triggers and context" and Epstein's lapsing.

### Gaps
- Not checked this session (`[U]`): Lupton, *The Quantified Self* (Polity, 2016); Neff & Nafus, *Self-Tracking* (MIT Press, 2016); Schüll, "Data for life" (BioSocieties, 2016); Ruckenstein & Pantzar, "Beyond the Quantified Self" (New Media & Society, 2017); Sharon & Zandbergen, "From data fetishism to quantifying selves" (New Media & Society, 2017). All real and relevant to D1; details need checking at the publisher.
- No study found that tests removing counts from a symptom diary and measures the effect on distress or use.

---

## 2. Chronic illness, sensemaking, blame, and personal trigger discovery

### Takeaway
HCI work on diabetes, IBS and migraine shows people want to find personal triggers, that everyday data are too messy for clinical-grade inference, and that tools should scaffold reflection and avoid negative reinforcement. It supports D2, D4 and D8, and warns that discovering triggers can itself add burden.

### Cited Findings

15. **Mamykina, L., Mynatt, E. D., Davidson, P. R., & Greenblatt, D. (2008). MAHI: investigation of social scaffolding for reflective thinking in diabetes management. CHI '08, 477–486.** DOI 10.1145/1357054.1357131. `[B]`
    - Claim: deployment with 25 newly diagnosed people with diabetes; MAHI helped with diet-related goals and moved participants toward an internal locus of control. Abstract seen only in truncated form. — [Georgia Tech ECL page](https://ecl.cc.gatech.edu/node/81); [Sciweavers abstract](https://www.sciweavers.org/node/42569)
    - Maps to: **D5, D6** (capture in the moment, reflect later with scaffolding). Tension with "don't blame the user": internal locus of control is a good outcome here, so the thesis should distinguish agency from blame.

16. **Karkar, R., Schroeder, J., Epstein, D. A., et al. (2017). TummyTrials: a feasibility study of using self-experimentation to detect individualized food triggers. CHI '17, 6850–6863.** DOI 10.1145/3025453.3025480. `[A]`
    - Claim: app that runs n-of-1 (single-case) experiments for IBS food triggers; field study with 15 IBS patients, 12-day experiments.
    - Quote: the work motivates "a need for the design of self-experimentation systems to balance rigor with the uncertainties of everyday life." — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5432136)
    - Maps to: **D2, D4, D8**. Also a **challenge**: TummyTrials gets causal evidence by having the person manipulate the trigger. The asthma app only observes, which is exactly why it must not say "cause". You cannot ethically randomise ozone or cold exposure for a person with asthma.

17. **Schroeder, J., Chung, C.-F., Epstein, D. A., et al. (2018). Examining self-tracking by people with migraine: goals, needs, and opportunities in a chronic health condition. DIS '18, 135–148.** DOI 10.1145/3196709.3196738. `[B]`
    - Claim: people with migraine track to find triggers (factors that bring on or worsen symptoms), to monitor symptoms, and for social recognition; providers recommend tracking because triggers vary between individuals; each goal implies different tool needs. — [author PDF](https://people.ucsc.edu/~cfchung/assets/papers/dis2018-migraines.pdf); [DBLP](https://dblp.uni-trier.de/rec/bibtex/conf/ACMdis/SchroederCEKPMF18)
    - Maps to: **D2** (triggers are individual), **D6**.

18. **Schroeder, J., Karkar, R., Murinova, N., Fogarty, J., & Munson, S. A. (2019). Examining opportunities for goal-directed self-tracking to support chronic condition management. Proc. ACM IMWUT 3(4), Article 151.** DOI 10.1145/3369809. `[A]`
    - Claim: paper prototype tested in interviews with 14 people with migraine and 5 providers. Goal-directed tracking helps with "eliciting different types and hierarchies of management and tracking goals", preparing for every stage of tracking, and patient–provider collaboration; pitfalls include goal creep and unrealistic goals. — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7351123)
    - Maps to: **D6**; partial **challenge to D1/D5**: the app fixes one goal (see what your inhaler days have in common) and does not let the person set others.

19. **Lin, J. J., Mamykina, L., Lindtner, S., Delajoux, G., & Strub, H. B. (2006). Fish'n'Steps: encouraging physical activity with an interactive computer game. UbiComp 2006, LNCS 4206, 261–278.** DOI 10.1007/11853565_16. `[B]`
    - Claim: step count drives the growth and mood of a virtual fish; 14-week study, 19 participants. Lesson reported in abstract fragments: such games should encourage rather than give negative reinforcement, especially when people are not meeting their own expectations. — [Springer chapter](https://doi.org/10.1007/11853565_16)
    - Maps to: **D1** and "don't blame the user" (a sad fish is a punishing score). Also a precedent.

20. **Daskalova, N., Metaxa-Kakavouli, D., Tran, A., et al. (2016). SleepCoacher: a personalized automated self-experimentation system for sleep recommendations. UIST '16, 347–358.** DOI 10.1145/2984511.2984534. `[A]`
    - Claim: phone sensor data plus clinician-authored template recommendations; guides users through short iterative experiments; two studies (24 and 19 participants per press coverage); sleep improved as adherence to recommendations increased. — [author PDF](https://jeffhuang.com/papers/SleepCoacher_UIST16.pdf)
    - Maps to: **D8** (templates written by experts, filled by deterministic analysis: the same architecture as the app's template narrator). **Challenge to D4**: SleepCoacher goes on to recommend actions; the asthma app stops before advice.

### Inferences
- The HCI trigger literature treats personal trigger-finding as legitimate and wanted, but gets its rigor from experiments. An observational diary can honestly offer only "showed up more often on", which is what D4 enforces.
- "Don't blame the user" has an empirical anchor (Ancker; Lin et al.), but Mamykina's locus-of-control result means the thesis should say the app gives control over interpretation without assigning responsibility for attacks.

### Gaps
- Not checked this session (`[U]`): Mamykina et al. (2017) "Personal discovery in diabetes self-management" (JBI); Katz et al. (2018) on type 1 diabetes apps; O'Kane et al. on situated use of medical devices; Felipe et al. on Parkinson's/chronic tracking; Pichon et al. (2020/2021) "Divided we stand" on personalised tracking in endometriosis. Likely relevant to D1/D2; verify before citing.

---

## 3. Asthma self-management, digital tools, smart inhalers, and what patients know about their triggers

### Takeaway
Sensor-based inhaler tracking has trial and programme evidence of reduced rescue-inhaler use, but the evidence for asthma apps is inconsistent and low-certainty, and NICE does not recommend smart inhalers for routine use. Patients' self-reported triggers correlate only modestly with objective tests, and becoming aware of new triggers can raise perceived burden: support for D2–D4 and a warning for D1 and D2.

### Cited Findings

21. **Merchant, R. K., Inamdar, R., & Quade, R. C. (2016). Effectiveness of population health management using the Propeller Health asthma platform: a randomized clinical trial. Journal of Allergy and Clinical Immunology: In Practice, 4(3), 455–463.** DOI 10.1016/j.jaip.2015.11.022. NCT01509183. `[B]`
    - Claim: RCT (495 adults and children per secondary coverage) of inhaler sensors plus app and feedback; rescue (SABA) use and SABA days were lower in the intervention arm. I did not read the results section; take effect sizes from the paper. Note the brief's "Merchant et al." co-authors are Inamdar and Quade, not Barrett. — [PubMed 26778246](https://pubmed.ncbi.nlm.nih.gov/26778246/); [later JMIR mHealth paper citing it](https://mhealth.jmir.org/2018/6/e133/)
    - Maps to: **D6** (passive, one-action capture of each puff is the proven core). **Challenge to D1**: the Propeller intervention includes numeric feedback and clinician dashboards, and that package is what was tested.

22. **Barrett, M., Combs, V., Su, J. G., Henderson, K., Tuffli, M., & the AIR Louisville Collaborative (2018). AIR Louisville: addressing asthma with technology, crowdsourcing, cross-sector collaboration, and policy. Health Affairs, 37(4), 525–534.** DOI 10.1377/hlthaff.2017.1315. `[A]` (author list beyond Barrett from memory)
    - Claim: Louisville residents with asthma used inhaler sensors that stamped time and place of each use; the abstract reports a 78% reduction in rescue inhaler use and a 48% improvement in symptom-free days over 12 months, and the pooled data informed city policy. No control group (before/after). An "82%" figure in press coverage is from a 2017 programme summary, not the paper. — [Health Affairs](https://www.healthaffairs.org/doi/pdf/10.1377/hlthaff.2017.1315)
    - Maps to: **D6** and the whole "when, where, what conditions" frame (closest clinical precedent for stamping puffs with place and air). **D3**: environmental values in that programme were joined from regional sources, which is why the app's "regional, not at your location" labelling matters.

23. **Hui, C. Y., Walton, R., McKinstry, B., Jackson, T., Parker, R., & Pinnock, H. (2017). The use of mobile applications to support self-management for people with asthma: a systematic review of controlled studies to identify features associated with clinical effectiveness and adherence. JAMIA, 24(3), 619–632.** DOI 10.1093/jamia/ocw143. `[A]`
    - Claim: 12 controlled studies; meta-analysis of 3 showed improved asthma control (mean difference −0.25, 95% CI −0.37 to −0.12); the most successful interventions combined several features, but effects were inconsistent.
    - Quote: "No studies explicitly reported adoption of and adherence to the technology system." — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7651908)
    - Maps to: context for all decisions. Honest framing: an asthma diary app is not known to improve outcomes; the project is a design argument, not a clinical one. Note the brief lists the authors as "Hui et al."; co-authors are as above.

24. **Chan, A., De Simoni, A., Wileman, V., et al. (2022). Digital interventions to improve adherence to maintenance medication in asthma. Cochrane Database of Systematic Reviews, Issue 6, CD013030.** DOI 10.1002/14651858.CD013030.pub2. `[A]`
    - Claim: 40 RCTs, over 15,000 participants.
    - Quote: "Overall, digital interventions may result in a large increase in adherence (low-certainty evidence)." Also low-certainty evidence of fewer exacerbations; electronic monitoring devices and adherence feedback were among the more effective elements. — [PubMed 35691614](https://pubmed.ncbi.nlm.nih.gov/35691614/); [Cochrane](https://cochranelibrary.com/cdsr/doi/10.1002/14651858.CD013030.pub2/information)
    - Maps to: **counter-evidence for D1**: feedback of adherence data (numbers) is one of the things that appears to help. But this concerns preventer adherence, not rescue-inhaler diaries or trigger insight.

25. **NICE, BTS & SIGN (2024). Asthma: diagnosis, monitoring and chronic asthma management. NICE guideline NG245.** https://www.nice.org.uk/guidance/ng245 `[B]`
    - Claim: emphasises personalised action plans; the research recommendations ask whether digital inhaler monitors cost-effectively improve preventer adherence, i.e. smart inhalers are not recommended for routine use. The related quality standard (QS25, statement 2) asks that plans include ways to minimise exposure to indoor and outdoor air pollution. I read these via search summaries of NICE pages, not the full guideline text. — [NG245 research recommendations](https://www.nice.org.uk/guidance/ng245/chapter/recommendations-for-research); [QS25 statement 2](https://www.nice.org.uk/guidance/QS25/chapter/quality-statement-2-documented-personalised-action-plan)
    - Maps to: positioning ("not medical advice"; an action plan from a clinician is the standard of care, and the app is a diary beside it). Supports **D4** indirectly: what to do belongs to the action plan, not the app.

26. **Janssens, T., & Ritz, T. (2013). Perceived triggers of asthma: key to symptom perception and management. Clinical & Experimental Allergy, 43(9), 1000–1008.** DOI 10.1111/cea.12138. `[A]`
    - Claim: review. People differ in which triggers they perceive; the correlation between self-reported triggers and allergy tests "is only modest"; trigger perceptions shape symptom perception and behaviour. — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3748392)
    - Maps to: **D2** (personal trigger profile differs from the population list), **D4** (beliefs about triggers can be wrong in both directions, so the app says "showed up on", not "causes"), **D8**.

27. **Janssens, T., & Harver, A. (2015). Effects of symptom perception interventions on trigger identification and quality of life in children with asthma. Pulmonary Medicine, 2015.** `[B]`
    - Claim: symptom-perception interventions increased the number of triggers children reported; the authors note that complementary strategies are needed for the change in perceived burden that comes with awareness of new triggers. — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC4641187)
    - Maps to: **counter-evidence for D2 and Insights generally**: surfacing more "your triggers" can make the illness feel heavier. Supports the gate (few, well-supported patterns) and the plain "Still learning…" state.

### Inferences
- The clinical evidence supports capture of each puff with time and place (D6) far better than it supports any particular way of showing insights. No trial isolates "words vs numbers" in asthma.
- Because self-reported triggers are only modestly accurate, the app's contribution is comparison against baseline hours (D3, D6), not the trigger list itself.

### Gaps
- Not checked this session (`[U]`): Tinschert et al. (2017) review of asthma app features (JMIR mHealth); the Cochrane review of written personalised action plans / self-management education (Gibson et al.) and Pinnock et al.'s PRISMS meta-review. Verify before citing.
- I found no published n-of-1 or personalised trigger-discovery study specific to asthma environmental triggers. Treat this as a real gap that the thesis can name.
- Trial effect sizes for Merchant 2016 were not read at source.

---

## 4. N-of-1, small data, and communicating personal correlations

### Takeaway
N-of-1 trials are the accepted method for individual-level inference, and HCI systems that mine observational personal data report that people find plain-language correlations useful but that most surfaced correlations are noise unless filtered. This grounds D2, D4 and the gate behind D8, and shows D1's plain-words statements have a tested precedent (Health Mashups).

### Cited Findings

28. **Lillie, E. O., Patay, B., Diamant, J., Issell, B., Topol, E. J., & Schork, N. J. (2011). The n-of-1 clinical trial: the ultimate strategy for individualizing medicine? Personalized Medicine, 8(2), 161–173.** DOI 10.2217/pme.11.7 (DOI from memory). PMID 21695041. `[A]`
    - Quote: "The ultimate goal of an n-of-1 trial is to determine the optimal or best intervention for an individual patient using objective data-driven criteria." — [PubMed](https://pubmed.ncbi.nlm.nih.gov/21695041/)
    - Maps to: **D2** (the individual is a legitimate unit of evidence). **Challenge to any causal reading**: n-of-1 means randomised crossover within one person; the app's data are observational.

29. **Kravitz, R. L., Duan, N. (eds.) and the DEcIDE Methods Center N-of-1 Guidance Panel (2014). Design and Implementation of N-of-1 Trials: A User's Guide. AHRQ Publication No. 13(14)-EHC122-EF. Rockville, MD: Agency for Healthcare Research and Quality.** `[A]` — [AAFP-hosted PDF](https://www.aafp.org/content/dam/AAFP/documents/patient_care/nrn/design-implementation-n1-trials.pdf)
    - Claim: the standard methods guide for single-patient trials (indications, design, statistics, ethics). I confirmed the citation only, not chapter content.
    - Maps to: **D2, D4** (the bar the app does not meet, and says so).

30. **Bentley, F., Tollmar, K., Stephenson, P., Levy, L., Jones, B., Robertson, S., Price, E., Catrambone, R., & Wilson, J. (2013). Health Mashups: presenting statistical patterns between wellbeing data and context in natural language to promote behavior change. ACM TOCHI, 20(5), Article 30.** DOI 10.1145/2503823. `[B]`
    - Claim: system that finds significant relationships across streams (weight, sleep, steps, calendar, location, weather, pain, food, mood) and shows them on the phone as natural-language statements; pilot then a 90-day trial. Results not read at source. — [DBLP](https://dblp.org/rec/journals/tochi/BentleyTSLJRPCW13.html); [abstract summary](https://typeset.io/papers/health-mashups-presenting-statistical-patterns-between-3bybc0iq44)
    - Maps to: **D1** (closest research precedent for "patterns said in words") and **D8** (statistics in code, sentence on top). Difference worth stating: Health Mashups aimed at behaviour change; the asthma app declines to.

31. **Jones, S. L., & Kelly, R. (2018). Dealing with information overload in multifaceted personal informatics systems. Human–Computer Interaction, 33(1), 1–48.** DOI 10.1080/07370024.2017.1302334. `[A]`
    - Claim: three-month study, 20 participants using the Exist system, which surfaces correlations. Automated filters cut the number of correlations shown by about 55% on average and raised the share rated interesting to about 81%. — [Bath research portal](https://researchportal.bath.ac.uk/en/publications/dealing-with-information-overload-in-multifaceted-personal-inform/)
    - Maps to: **D8** and the gate (8 inhaler logs, 20 baselines, 4 in level, lift > 1.25): filtering before display is evidence-based. The brief's title for this paper ("Dealing with information from multiple wearables") is not the published title.

32. **Liang, Z., Ploderer, B., Liu, W., Nagata, Y., Bailey, J., Kulik, L., & Li, Y. (2016). SleepExplorer: a visualization tool to make sense of correlations between personal sleep data and contextual factors. Personal and Ubiquitous Computing, 20(6), 985–1000.** DOI 10.1007/s00779-016-0960-6. `[A]`
    - Claim: web tool combining Fitbit sleep data and diary entries; shows correlations between sleep and context; two-week field study with 12 participants, who reported better understanding and found relationships they had not noticed. — [Springer](https://www.doi.org/10.1007/S00779-016-0960-6)
    - Maps to: **D2**; also the counter-model (correlation coefficients shown to the person), useful contrast for **D1**.

### Inferences
- The app's honest claim is weaker than n-of-1 and stronger than a raw correlation list: a gated comparison of inhaler hours against sampled ordinary hours. The thesis should name it that way.
- D2 (personal beside population threshold) has support from the n-of-1 argument and from Janssens & Ritz, but I found no study that tests showing both thresholds side by side.

### Gaps
- Not checked (`[U]`): Estrin, "Small data, where n = me" (CACM, 2014); Rapp & Cena (2016) "Personal informatics for everyday life" (IJHCS); Hekler et al. on precision behaviour change. Verify before citing.
- No source found on how people read a personal threshold next to a population threshold (anchoring, false reassurance). This is a gap in evidence for D2.

---

## 5. Words versus numbers, uncertainty, sketchiness, missing data, and causal misreading

### Takeaway
The evidence is split in a way the thesis must face. Verbal likelihood terms are read very inconsistently and often overestimated, and text descriptions of a correlation invite the strongest causal reading. On the other side, showing uncertainty does not necessarily cost trust, sketchy and dashed marks are understood as "less certain", and how missing values are drawn changes how people judge data quality. So D3 and D4 are well supported; D1's words need guarding by D5 and by fixed wording rules.

### Cited Findings

33. **Budescu, D. V., Broomell, S., & Por, H.-H. (2009). Improving communication of uncertainty in the reports of the Intergovernmental Panel on Climate Change. Psychological Science, 20(3), 299–308.** DOI 10.1111/j.1467-9280.2009.02284.x. `[A]`
    - Claim: participants read IPCC sentences and gave numeric meanings for terms like "very likely"; interpretations varied widely and departed from IPCC's own guideline ranges even when the guidelines were available; the authors recommend pairing words with numeric ranges. — [APS journal page](https://www.psychologicalscience.org/journals/psychological-science/j.1467-9280.2009.02284.x/). Follow-up across 24 countries: Budescu, Por, Broomell & Smithson (2014), Nature Climate Change, DOI [10.1038/nclimate2194](https://link.springer.com/10.1038/nclimate2194) `[B]`.
    - Maps to: **direct challenge to D1**. "Often" and "sometimes" will mean different things to different people. Mitigations already in the design: a small closed vocabulary with fixed code-side cut-offs (D8) and the count one gesture away (D5).

34. **Berry, D. C., Knapp, P., & Raynor, D. K. (2002). Provision of information about drug side-effects to patients. The Lancet, 359(9309), 853–854.** `[A]` (abstract at [Reading repository](https://centaur.reading.ac.uk/4656)); and **Knapp, P., Raynor, D. K., & Berry, D. C. (2004). Comparison of two methods of presenting risk information to patients about the side effects of medicines. Quality & Safety in Health Care, 13(3), 176–180.** `[A]` ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC1743828))
    - Claim: across four studies with over 750 participants, verbal descriptors produced large overestimates of side-effect risk. In the 2004 study, mean estimated likelihood of constipation was 34.2% with the label "common" against 8.1% with the number; pancreatitis 18% ("rare") against 2.1%.
    - Maps to: **strongest health-specific counter-evidence to D1**. A word like "often" may inflate perceived risk. Note the difference: those words described a probability of future harm; the app's words describe a frequency in the person's own past, and D4 forbids the probability reading.

35. **Peters, E., Västfjäll, D., Slovic, P., Mertz, C. K., Mazzocco, K., & Dickert, S. (2006). Numeracy and decision making. Psychological Science, 17(5), 407–413.** DOI 10.1111/j.1467-9280.2006.01720.x. `[A]`
    - Claim: four studies; highly numerate people were less affected by framing and drew more precise affective meaning from numbers; less numerate people were more influenced by irrelevant affect; effects not explained by general intelligence. — [Chalmers record](https://research.chalmers.se/en/publication/82667)
    - Maps to: cuts both ways for **D1**. Numbers disadvantage less numerate people (support), but numerate people get real meaning from them, and removing them takes that away (challenge). D5 is the answer for the second group.

36. **van der Bles, A. M., van der Linden, S., Freeman, A. L. J., Mitchell, J., Galvao, A. B., Zaval, L., & Spiegelhalter, D. J. (2019). Communicating uncertainty about facts, numbers and science. Royal Society Open Science, 6(5), 181870.** DOI 10.1098/rsos.181870. `[A]`
    - Claim: review and framework: three objects of uncertainty (facts, numbers, science), two levels (direct, and indirect = quality of underlying evidence), and nine forms of expression from full distributions down to not mentioning it. Some evidence that communicating epistemic uncertainty "does not necessarily affect audiences negatively". — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6549952)
    - Maps to: **D3** (provenance = indirect uncertainty, shown), **D4**. Use the nine-level scale to place the app's choices: words and visual cues, not ranges.

37. **Kay, M., Kola, T., Hullman, J. R., & Munson, S. A. (2016). When (ish) is my bus? User-centered visualizations of uncertainty in everyday, mobile predictive systems. CHI '16, 5092–5103.** DOI 10.1145/2858036.2858558. `[A]`
    - Quote: "Quantile dotplots reduce the variance of probabilistic estimates by about 1.15 times compared to density plots and facilitate more confident estimation by end-users." — [UW IDL page](https://idl.uw.edu/papers/when-ish-is-my-bus)
    - Maps to: **D4, D7** (uncertainty for lay users on a phone; discrete dots are a well-founded mark). **Challenge**: quantile dotplots are countable on purpose, so people can read off a probability. The app's dots deliberately are not countable. The thesis should say this is a choice against the paper's goal, justified by D4's "no percent risk".

38. **Hullman, J. (2020). Why authors don't visualize uncertainty. IEEE TVCG, 26(1), 130–139.** DOI 10.1109/TVCG.2019.2934287. `[A]`
    - Claim: survey of 90 visualisation authors and interviews with 13 influential designers; authors say uncertainty matters yet routinely leave it out; proposes a rhetorical model of omission and argues that showing uncertainty reduces viewers' degrees of freedom in inference. — [arXiv 1908.01697](https://arxiv.org/abs/1908.01697)
    - Maps to: **D3, D4** (the app does what practitioners say they value and skip), and the thesis claim that hiding is a design decision with a rhetoric.

39. **Boukhelifa, N., Bezerianos, A., Isenberg, T., & Fekete, J.-D. (2012). Evaluating sketchiness as a visual variable for the depiction of qualitative uncertainty. IEEE TVCG, 18(12), 2769–2778.** DOI 10.1109/TVCG.2012.220 (DOI from memory). `[A]`
    - Claim: compares sketchiness with blur, dashing and grayscale for uncertain lines. Sketchiness is about as intuitive as blur; **participants preferred dashing** over blur, grayscale and sketchiness. — [IEEE VIS 2012 page](https://ieeevis.org/year/2012/paper/infovis/evaluating-sketchiness-visual-variable-depiction-qualitative-uncertainty); [HAL](https://hal-universite-paris-saclay.archives-ouvertes.fr/LISN/hal-00717441)
    - Maps to: **D4** directly. The forecast's dashed edges have empirical backing (dashing preferred); hand-drawn wobble is understood but less liked.

40. **Wood, J., Isenberg, P., Isenberg, T., Dykes, J., Boukhelifa, N., & Slingsby, A. (2012). Sketchy rendering for information visualization. IEEE TVCG, 18(12), 2749–2758.** DOI 10.1109/TVCG.2012.262. `[A]`
    - Quotes: "relative area judgment is compromised by sketchy rendering and that its influence is dependent on the shape being rendered"; degree of sketchiness "may be judged on an ordinal scale but that its judgement varies strongly between individuals"; and where a visualisation is clearly sketchy, "engagement may be increased". — [City Research Online PDF](https://openaccess.city.ac.uk/id/eprint/1274/1/wood_sketchy_2012.pdf)
    - Maps to: **D4, D7**. Support (engagement, signals informality) and limit (do not ask people to compare sizes of sketchy shapes; do not encode several levels of certainty in degree of sketchiness).

41. **Song, H., & Szafir, D. A. (2019). Where's my data? Evaluating visualizations with missing data. IEEE TVCG, 25(1), 914–924.** DOI 10.1109/TVCG.2018.2864914. `[A]`
    - Claim: two crowdsourced studies on line and bar charts. Designs that highlight imputed values were judged higher in data quality; designs that break visual continuity, or that downplay or remove missing-value information, lowered perceived quality and could bias interpretation. — [NSF PAR PDF](https://par.nsf.gov/servlets/purl/10111567); [project page](https://cmci.colorado.edu/visualab/MissingData)
    - Maps to: **D3**. Supports marking missing values explicitly instead of silently filling them. **Tension**: leaving a visible gap (breaking continuity) lowered perceived quality; in this app that honest loss of confidence is the intended effect, but say so.

42. **Xiong, C., Shapiro, J., Hullman, J., & Franconeri, S. (2020). Illusion of causality in visualized data. IEEE TVCG, 26(1), 853–862.** DOI 10.1109/TVCG.2019.2934399. `[A]`
    - Claim: three crowdsourced experiments on reading correlation as causation. Causal ratings were highest for text descriptions and bar graphs and lower for scatterplots; more aggregation went with higher perceived causality. (Sources I saw disagree on the direction of the dot-vs-bar encoding effect in Experiment 3; check the published paper before citing that detail.) — [arXiv/NSF PDF](https://par.nsf.gov/servlets/purl/10196693); [MU Collective page](https://mucollective.northwestern.edu/project/2019-correlation-causation-vis)
    - Maps to: **D4** (people will infer cause unless the design resists) and a **serious challenge to D1**: a plain sentence is the form most likely to be read causally, and "inhaler days vs usual days" is a two-bin aggregate. Mitigations: fixed non-causal phrasing ("showed up on"), an always-present caveat line, and D5 opening to the less aggregated record.

### Inferences
- D1 is the least supported decision if judged only by risk-communication research. The defensible position is words **plus** a drill-down (D5) and a fixed vocabulary bound to thresholds in code (D8), which is close to Budescu's own recommendation (words tied to defined ranges), with the range kept one gesture away.
- D4's drawing choices are well supported: dashed outline (Boukhelifa), sketchiness as an ordinal cue of informality (Wood), dots for lay probability reading (Kay).
- D3 is the best supported decision in this section (van der Bles, Hullman, Song & Szafir).

### Gaps
- Not checked (`[U]`): Budescu & Wallsten's earlier work on verbal probability phrases; Fischhoff (e.g., "Communicating risks and benefits", FDA 2011; "The sciences of science communication", PNAS 2013); IPCC AR5/AR6 uncertainty guidance note (Mastrandrea et al. 2010); provenance-in-visualisation surveys (e.g., Ragan et al. 2016, TVCG). Verify before citing.
- No study found on verbal *frequency* terms ("often", "sometimes") applied to a person's own past data, as opposed to probability of a future event.
- No study found that tests hollow marks specifically as an uncertainty cue.

---

## 6. Ambiguity, reflection, slowness and calm as design values

### Takeaway
A coherent HCI design tradition treats ambiguity and open interpretation as resources that make people engage and interpret for themselves. It directly licenses D7 and the "sketch" in D4. None of it was developed for or tested in health-risk settings, which is where a critic will press.

### Cited Findings

43. **Gaver, W. W., Beaver, J., & Benford, S. (2003). Ambiguity as a resource for design. CHI '03, 233–240.** DOI 10.1145/642611.642653 (DOI from memory). `[A]`
    - Claim: ambiguity, normally a fault in HCI, can be "a resource for design" that encourages close personal engagement. Distinguishes ambiguity of information, of context and of relationship, and offers tactics for each; argues for design as giving people resources for interpretation rather than solutions to defined problems. — [Goldsmiths repository](https://research.gold.ac.uk/id/eprint/272); [DBLP](https://dblp.uni-trier.de/rec/conf/chi/GaverBB03.html)
    - Maps to: **D7, D4**. The halftone field is "ambiguity of information": imprecise display that asks the viewer to fill in. Limit: the paper's examples are art and domestic prototypes, not health.

44. **Sengers, P., & Gaver, B. (2006). Staying open to interpretation: engaging multiple meanings in design and evaluation. DIS '06, 99–108.** DOI 10.1145/1142405.1142422 (DOI from memory). `[B]`
    - Claim: design and evaluation change once you drop the presumption that a system needs one authoritative interpretation; interpretation is shared between user, system and designer. Abstract seen in fragments only. — [DBLP](https://dblp.uni-trier.de/db/conf/ACMdis/ACMdis2006.html); [Sciweavers abstract](https://www.sciweavers.org/node/107686)
    - Maps to: **D1, D5, D7**: the system proposes a reading ("often came below about 40°F") and the person holds the authority to open it and disagree.

45. **Sengers, P., Boehner, K., David, S., & Kaye, J. (2005). Reflective design. Critical Computing '05, 49–58.** DOI 10.1145/1094562.1094569. `[A]`
    - Claim: reflection on the unconscious values embedded in computing, by designers and by users, should be a core principle of technology design; illustrated with two design case studies. — [Cornell-hosted PDF](https://nissenbaum.tech.cornell.edu/papers/reflectivedesign.pdf)
    - Maps to: thesis method (naming the values in the index), **D3, D5**.

46. **Baumer, E. P. S. (2015). Reflective informatics: conceptual dimensions for designing technologies of reflection. CHI '15, 585–594.** DOI 10.1145/2702123.2702234. `[B]`
    - Claim: from a literature survey, three dimensions of reflection for designers: breakdown, inquiry and transformation. Abstract not read; dimensions confirmed via the bibliographic record and a citing paper. — [DBLP](https://dblp.org/rec/conf/chi/Baumer15)
    - Maps to: **D5** (hold-to-read is the "inquiry" move), **D2** (personal vs population threshold is a designed "breakdown": the mismatch prompts reflection).

47. **Hallnäs, L., & Redström, J. (2001). Slow technology: designing for reflection. Personal and Ubiquitous Computing, 5(3), 201–212.** DOI 10.1007/PL00000019. `[A]`
    - Claim: a design agenda for technology aimed at reflection and mental rest rather than efficiency in performance; examples are "soniture" and "informative art". — [Springer DOI](https://doi.org/10.1007/PL00000019)
    - Maps to: **D6** (baselines filled in a day later; "Still learning…"), **D7**.

48. **Weiser, M., & Brown, J. S. (1995). Designing calm technology. Xerox PARC, 21 December 1995.** `[A]` — [text at calmtech.com](https://calmtech.com/papers/designing-calm-technology)
    - Claim: calm technology moves between the periphery and the centre of attention; the example is Natalie Jeremijenko's Dangling String, an 8-foot plastic string on a motor driven by Ethernet traffic.
    - Maps to: **D7** (air as texture at the periphery), **D6** (the button), **D5** (periphery to centre in one gesture).

### Inferences
- The ambiguity tradition justifies D7 as a way to return interpretation to the person, which is the thesis' agency argument. It does not answer whether ambiguity is safe when someone might act on it. The app's answer is structural: ambiguity is confined to the air and the forecast sketch; readings with units, provenance and the record itself stay exact (D3, D5).

### Gaps
- Not checked (`[U]`): Boehner, DePaula, Dourish & Sengers (2007) "How emotion is made and measured" (IJHCS); Höök, *Designing with the Body* (MIT Press, 2018); Dourish, *Where the Action Is* (MIT Press, 2001); Odom et al. on slow technology (e.g., Photobox, CHI 2014); Dunne & Raby, *Speculative Everything* (2013); DiSalvo, *Adversarial Design* (2012). Real and relevant; verify details.
- I found no published critique of ambiguity specifically in health interfaces. The nearest counter-evidence is the risk-communication work in section 5 (Berry/Knapp; Budescu).

---

## 7. Data humanism, data feminism, capta, critical visualisation, materiality

### Takeaway
Humanities and design writing gives the thesis its vocabulary: data are made, local, partial and felt, and a visualisation should disclose that. These sources support D3, D5 and D7 as principle; they are arguments, not empirical tests.

### Cited Findings

49. **Lupi, G. (2017). Data Humanism: the revolution will be visualized. Print Magazine (30 January 2017; date from memory, the page read gives no date).** `[A]` — [author's site](https://giorgialupi.com/data-humanism-my-manifesto-for-a-new-data-wold)
    - Quotes: "Data is a tool that filters reality in a highly subjective way"; "Data is primarily human-made."; "We should experiment with how to visualize uncertainty, possible errors and imperfections in our data."
    - Maps to: **D3, D4, D7**; also the thesis claim that indexing filters. Note "small data" as a phrase is not in the text I read; she describes Dear Data as "a slow, small, and incredibly analog transmission".

50. **D'Ignazio, C., & Klein, L. F. (2020). Data Feminism. MIT Press.** Open access: https://data-feminism.mitpress.mit.edu/ `[B]`
    - Claim: seven principles, including "elevate emotion and embodiment" (ch. 3, valuing knowledge that comes from people "as living, feeling bodies in the world") and "consider context" (ch. 6, data are not neutral or objective; context is needed for accurate, ethical analysis). Chapter text not read this session; wording via reviews. — [principles summary](https://responsibledata.io/?p=3331); [review in IEEE Technology and Society](https://technologyandsociety.org/?p=6384)
    - Maps to: **D1, D7** (emotion and embodiment), **D3** (context = provenance). Chapter 3 also discusses when *withholding* visual minimalism is itself rhetoric: useful for answering the critic in D5.

51. **Drucker, J. (2011). Humanities approaches to graphical display. Digital Humanities Quarterly, 5(1).** `[A]` — [DHQ](https://digitalhumanities.org/dhq/vol/5/1/000091/000091.html)
    - Quote: "Data are capta, taken not given, constructed as an interpretation of the phenomenal world, not inherent in it."
    - Maps to: **D3** (every reading names who took it, where, when), **D4**. Also the thesis' central claim about indexing.

52. **Dörk, M., Feng, P., Collins, C., & Carpendale, S. (2013). Critical InfoVis: exploring the politics of visualization. CHI '13 Extended Abstracts (alt.chi), 2189–2198.** DOI 10.1145/2468356.2468739 (DOI from memory). `[B]`
    - Claim: values and assumptions shape visualisation; proposes four principles for a critical approach: **disclosure, plurality, contingency, empowerment**. — [DBLP](https://dblp.uni-trier.de/rec/conf/chi/DorkFCC13.html); [Ontario Tech repository](https://ontariotechu.scholaris.ca/items/4e828571-88f6-4f61-ba20-3052eb338df4/full)
    - Maps to: **D3 and D5** (disclosure), **D2** (plurality: two thresholds), **D4** (contingency), **D5/D8** (empowerment). A compact frame for the whole set of eight.

53. **Loukissas, Y. A. (2019). All Data Are Local: Thinking Critically in a Data-Driven Society. MIT Press.** `[A]` — [MIT Press Bookstore](https://mitpressbookstore.mit.edu/book/9780262545174); [author site](https://loukissas.lmc.gatech.edu/?p=973)
    - Claim: study "data settings rather than data sets"; data are "made by people and their machines, at a particular time and place"; six principles, including that interfaces recontextualise data and that data are indexes to local knowledge.
    - Maps to: **D3** exactly (source, distance, spatial scale, as-of time are the "setting" of each reading); thesis framing on indexes.

54. **Offenhuber, D. (2023). Autographic Design: The Matter of Data in a Self-Inscribing World. MIT Press (metaLABprojects).** ISBN 9780262547024. `[A]` — [MIT Press Bookstore](https://mitpressbookstore.mit.edu/book/9780262547024); [metaLAB page](https://metalab.harvard.edu/p/autographic-design)
    - Claim: data as "a material entity rather than an abstract representation"; design practices that make traces legible as evidence and make data production accountable. Publication date is given as December 2023 or January 2024 depending on the listing.
    - Maps to: **D6** (the press of the button is a trace, the puff inscribes itself), **D7** (riso/textile as material mark-making), **D3**.

### Inferences
- Dörk et al.'s four principles map cleanly onto the eight decisions and give the thesis a published rubric to evaluate itself against.
- The critic's point in D5 ("plain words are also a flattening") is conceded by these sources: Drucker and Loukissas would say every interface is an interpretation. The defence is disclosure and reversibility, not neutrality.

### Gaps
- Not checked (`[U]`): Lupi & Posavec, *Dear Data* (Princeton Architectural Press / Particular Books, 2016) text; Jansen et al. (2015) "Opportunities and challenges for data physicalization" (CHI '15); Lupton on data materialisation beyond item 13; "data visceralization" (Lee et al., IEEE TVCG 2021; the term also appears in *Data Feminism* ch. 3). Verify before citing.

---

## 8. Agency in HCI, intelligibility, scrutability, details on demand, seams

### Takeaway
HCI uses "agency" in several senses; the thesis needs to say which. The measured sense (sense of agency) supports the physical one-press button and warns against too much automation; the interpretive sense (intelligibility, scrutability) supports D5 and D8. "Overview first, details on demand" and seamful design are the standard answers to the "flattening" critique.

### Cited Findings

55. **Bennett, D., Metatla, O., Roudaut, A., & Mekler, E. D. (2023). How does HCI understand human agency and autonomy? CHI '23, Article 375.** DOI 10.1145/3544548.3580651. `[A]`
    - Claim: review of 161 papers over 32 years; understandings of autonomy and agency "remain ambiguous"; the terms cover sense of control, material independence and identity; identifies open issues and themes. — [arXiv 2301.12490](https://arxiv.org/abs/2301.12490); [Bristol record](https://research-information.bris.ac.uk/en/publications/how-does-hci-understand-human-agency-and-autonomy/)
    - Maps to: thesis framing. Use it to define which agency is at stake: self-causality and identity in interpretation (the person, not the index, says what their days mean), not just control over the UI.

56. **Coyle, D., Moore, J., Kristensson, P. O., Fletcher, P., & Blackwell, A. (2012). I did that! Measuring users' experience of agency in their own actions. CHI '12, 2025–2034.** DOI 10.1145/2207676.2208350. `[A]`
    - Claim: uses intentional binding as an implicit measure. Skin-based input gave a stronger sense of agency than a conventional button-style input, and beyond a certain level of computer assistance the sense of agency dropped significantly. — [author PDF](https://pokristensson.com/pubs/CoyleEtAlCHI2012.pdf)
    - Maps to: **D6** (a deliberate bodily press as the one explicit act) and **D8** (limit assistance: model suggests, person confirms). **Tension**: automatic baseline sampling is high assistance; it is defensible because baselines are not the person's act, but they should be visible (they are, as "Baseline").

57. **Bellotti, V., & Edwards, K. (2001). Intelligibility and accountability: human considerations in context-aware systems. Human–Computer Interaction, 16(2–4), 193–212.** DOI 10.1207/S15327051HCI16234_05. `[B]`
    - Claim: context-aware systems cannot simply act on our behalf; they must be intelligible, i.e. able to "represent to their user what they know, how they know it, and what they are doing about it" (wording via a secondary summary; check the paper), and must keep users accountable and in control. — [author PDF](https://faculty.cc.gatech.edu/~keith/pubs/hcij-context.pdf)
    - Maps to: **D3** (what it knows and how), **D5**, **D8**. The best single HCI citation for provenance on every reading.

58. **Shneiderman, B. (1996). The eyes have it: a task by data type taxonomy for information visualizations. IEEE Symposium on Visual Languages, 336–343.** DOI 10.1109/VL.1996.545307. `[A]`
    - Quote (the mantra): "overview first, zoom and filter, then details on demand". — [UMD record](https://drum.lib.umd.edu/items/155a868e-fb83-4115-9899-9187ea8c0498)
    - Maps to: **D5** (the classic answer to "a summary that opens"). The app's sentence is the overview; hold-to-read is details on demand.

59. **Chalmers, M., & Galani, A. (2004). Seamful interweaving: heterogeneity in the theory and design of interactive systems. DIS '04, 243–252.** DOI 10.1145/1013115.1013149. `[A]`
    - Claim: questions seamlessness and "disappearance" as ubicomp ideals; the seams between heterogeneous media and infrastructures (e.g., coverage, positioning error) can be revealed and used as design resources. — [Glasgow repository](https://eprints.gla.ac.uk/3457)
    - Maps to: **D3** (a monitor 15 miles away is a seam; show it), **D4**.

60. **Peters, D., Calvo, R. A., & Ryan, R. M. (2018). Designing for motivation, engagement and wellbeing in digital experience. Frontiers in Psychology, 9, 797.** DOI 10.3389/fpsyg.2018.00797. `[A]`
    - Claim: the METUX model, grounded in Self-Determination Theory: technology supports or undermines autonomy, competence and relatedness across several "spheres" (interface, task, behaviour, life, society). — [Frontiers](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2018.00797/full)
    - Maps to: **D1** (controlling feedback such as scores can undermine autonomy; this is SDT's general claim, apply with care), **D5**, **D6**. **Challenge**: SDT also names *competence*; informational feedback supports it. Hiding all numbers could reduce felt competence unless the words and drill-down supply it.

### Inferences
- "Agency" in the thesis is best pinned to Bennett et al.'s categories and then argued through Bellotti & Edwards (intelligibility) for D3/D5/D8 and Coyle et al. (felt agency in action) for D6.
- D5 has a canonical citation (Shneiderman) and a critical one (Dörk's "disclosure"). The reply to the critic: a summary is a flattening only if it is irreversible.

### Gaps
- Not checked (`[U]`): Kay, J. (2006) "Scrutable adaptation: because we can and must" (AH 2006, LNCS 4018, pp. 11–19; record confirmed at [researchr](https://researchr.org/publication/Kay06), abstract not available) — directly relevant to **D8**; Limerick, Coyle & Moore (2014) "The experience of agency in human-computer interactions: a review" (Frontiers in Human Neuroscience); Shneiderman & Maes (1997) "Direct manipulation vs. interface agents" (interactions 4(6)); Shneiderman, *Human-Centered AI* (OUP, 2022); Lukoff et al. on sense of agency in apps (CHI 2021); work on LLM tag suggestion with human confirmation. Verify before citing.
- I found no source that evaluates "deterministic statistics + template narrator, model limited to suggestions" as an interaction pattern. D8 rests on intelligibility/scrutability principles, plus Jones & Kelly (item 31) and SleepCoacher (item 20) as architectural precedents.

---

## 9. Low-burden and tangible capture; and counter-evidence that numbers and monitoring help

### Takeaway
In-the-moment capture reduces recall distortion, and tangible single-purpose devices lower the cost of reporting, which supports D6. But a large meta-analysis shows that monitoring progress improves goal attainment, more so when recorded and reported, and glanceable-feedback research finds abstraction works alongside comparison to targets. D1 should be argued as right for a condition with no "more is better" target, not as a rejection of feedback.

### Cited Findings

61. **Shiffman, S., Stone, A. A., & Hufford, M. R. (2008). Ecological momentary assessment. Annual Review of Clinical Psychology, 4, 1–32.** DOI 10.1146/annurev.clinpsy.3.022806.091415. `[A]`
    - Claim: retrospective self-reports are subject to recall bias and miss variation over time and context; EMA samples current experience repeatedly in real time in natural settings, by event-based or time-based (often random) schedules. — [PubMed 18509902](https://pubmed.ncbi.nlm.nih.gov/18509902/)
    - Maps to: **D6**. A puff press is event-based sampling; the automatic baselines are the time-based samples EMA says you need for comparison. **Challenge**: adding context "later by voice" reintroduces recall; baselines back-filled a day later are not momentary self-report (they use recorded air and place, so recall is not involved, but say this).

62. **Choe, E. K., Abdullah, S., Rabbi, M., Thomaz, E., Epstein, D. A., Cordeiro, F., Kay, M., Abowd, G. D., Choudhury, T., Fogarty, J., Lee, B., Matthews, M., & Kientz, J. A. (2017). Semi-automated tracking: a balanced approach for self-monitoring applications. IEEE Pervasive Computing, 16(1), 74–84.** DOI 10.1109/MPRV.2017.18. `[A]`
    - Claim: combine manual and automated capture to lower burden while keeping the awareness that manual tracking brings; design by data-capture feasibility, purpose of self-monitoring, and motivation level. — [Microsoft Research page](https://www.microsoft.com/en-us/research/?p=337103)
    - Maps to: **D6** almost point for point: the puff is manual (awareness, agency), conditions and baselines are automatic.

63. **Vega, J., Couth, S., Poliakoff, E., Kotz, S., Sullivan, M., Jay, C., Vigo, M., & Harper, S. (2018). Back to analogue: self-reporting for Parkinson's disease. CHI '18, Paper 74.** DOI 10.1145/3173574.3173648. `[A]`
    - Claim: started from the premise that a technology-based approach would be effective and flexible; ended with a paper diary that was more accessible and lower burden. Five design implications, including reducing completion burden, implicit reminders, and accounting for the consequences of greater symptom awareness. — [Manchester record](https://research.manchester.ac.uk/en/publications/back-to-analogue-self-reporting-for-parkinsons-disease/)
    - Maps to: **D6, D7** (analogue, physical, low-burden), and **D1** (symptom awareness has consequences).

64. **Paruthi, G., Raj, S., Baek, S., Wang, C., Huang, C.-C., Chang, Y.-J., & Newman, M. W. (2018). Heed: exploring the design of situated self-reporting devices. Proc. ACM IMWUT 2(3), Article 132.** DOI 10.1145/3264942 (DOI from memory). `[B]`
    - Claim: simple low-cost physical devices placed in the environment for self-report; two one-week field studies (10 and 7 participants); devices complemented phones, with single-purpose design and dedicated location as the advantage. — [author PDF](https://people.cs.nycu.edu.tw/~armuro/pubs/paruthi-et-al-2018-imwut.pdf); [DBLP](https://dblp.org/rec/journals/imwut/ParuthiRBWHCN18)
    - Maps to: **D6** (felt button). **Limit**: a situated device is where it sits; an inhaler travels. Small short studies.

65. **Adams, A. T., Murnane, E. L., Adams, P., Elfenbein, M., Chang, P. F., Sannon, S., Gay, G., & Choudhury, T. (2018). Keppi: a tangible user interface for self-reporting pain. CHI '18, Paper 502.** DOI 10.1145/3173574.3174076. `[A]`
    - Claim: pressure-based tangible device for reporting pain intensity; lab studies with 28 participants showed reliable reports; a further 7 older adults with chronic pain were receptive to the wearable form. — [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6287633)
    - Maps to: **D6** (the body reports through pressure, not a number scale), **D1**.

66. **Consolvo, S., McDonald, D. W., Toscos, T., et al. (2008). Activity sensing in the wild: a field trial of UbiFit Garden. CHI '08, 1797–1806.** DOI 10.1145/1357054.1357335 (DOI from memory). `[B]`
    - Claim: on-body sensing, activity inference and a personal mobile display (a garden on the phone wallpaper in which flowers stand for activities); three-week field trial with 12 participants. — [Google Research page](https://research.google/pubs/activity-sensing-in-the-wild-a-field-trial-of-ubifit-garden/); [author PDF](https://makeabilitylab.cs.washington.edu/media/publications/Consolvo_ActivitySensingInTheWildAFieldTrialOfUbifitGarden_CHI2008.pdf)
    - Maps to: **D1, D7** as the canonical non-numeric, abstract display of personal health data. **Caveat**: flowers were still countable units tied to a weekly goal; it is not evidence that removing quantity helps.

67. **Gouveia, R., Pereira, F., Karapanos, E., Munson, S. A., & Hassenzahl, M. (2016). Exploring the design space of glanceable feedback for physical activity trackers. UbiComp '16, 144–155.** DOI 10.1145/2971648.2971754. `[A]`
    - Claim: over 70% of tracker use is glances of about five seconds; 21 concepts and six design qualities for glanceable feedback, including being **abstract**, **supporting comparisons to targets and norms**, and being actionable; four prototypes deployed in the wild differed significantly in effect on behaviour. — [UW repository](https://digital.lib.washington.edu/researchworks/items/2f4abc80-ce1b-4ba4-a2f1-ffa85e6d5557)
    - Maps to: **D1, D7** (abstract works at a glance); **D2** (comparison to norms is a named quality). **Challenge to D4**: "actionable" is also a named quality, and the app withholds action advice.

68. **Harkin, B., Webb, T. L., Chang, B. P. I., Prestwich, A., Conner, M., Kellar, I., Benn, Y., & Sheeran, P. (2016). Does monitoring goal progress promote goal attainment? A meta-analysis of the experimental evidence. Psychological Bulletin, 142(2), 198–229.** DOI 10.1037/bul0000025 (DOI from memory). `[A]`
    - Claim: 138 studies, N = 19,951. Interventions increased monitoring frequency (d+ = 1.98) and goal attainment (d+ = 0.40, 95% CI 0.32–0.48); effects were larger when progress was physically recorded and when it was reported or made public. — [White Rose repository](https://eprints.whiterose.ac.uk/id/eprint/91437/); [APA release](https://www.apa.org/news/press/releases/2015/10/progress-goals)
    - Maps to: **main counter-evidence to D1**. Monitoring with explicit, recorded progress works when there is a goal. The app's reply: there is no goal to progress toward (fewer puffs is not something to will), so the mechanism does not transfer, and Etkin/Ancker describe the cost. A critic can still say counts would help someone trying to reduce reliever use with their clinician; the exported table (D5) is the answer.

### Inferences
- D6 is the best supported decision overall: EMA (Shiffman), semi-automated tracking (Choe 2017), tangible reporting (Keppi, Heed, Vega), and clinical inhaler-sensor evidence (items 21–22).
- The fair statement of D1: quantified feedback helps goal pursuit (Harkin; Cochrane item 24) and harms enjoyment and self-image for some (Etkin; Ancker). A rescue-inhaler diary has no pursuit, so the cost side dominates. That is an argument, not a finding.

### Gaps
- Not checked (`[U]`): ModEx; Consolvo et al. (2006) "Design requirements for technologies that encourage physical activity" (CHI '06); Bauer et al. (2012) ShutEye (CHI '12); Kim et al. on semi-automated tracking tools (e.g., OmniTrack, IMWUT 2017). Verify before citing.
- No direct evidence found that hiding numbers reduces trust in a health app. Nearest: van der Bles et al. (item 36) on uncertainty and trust, and Ancker (item 10) on clinicians trusting machine-measured data more. Mark as an open risk.
- No study found on felt/fabric buttons for health logging specifically.

---

## 10. Design precedents (products, research prototypes, art)

### Takeaway
Precedents fall into three groups: non-numeric or ambient displays the project inherits from (Dangling String, UbiFit Garden, Fish'n'Steps, Dear Data), consumer trackers that log in words and chips (Apple State of Mind), and the counter-model of a single daily score (Oura, WHOOP).

### Cited Findings

| Precedent | Who / year | What it is, and relevance | Link | Status |
|---|---|---|---|---|
| **Dangling String (LiveWire)** | Natalie Jeremijenko, Xerox PARC, c. 1995 | 8-foot plastic string on a ceiling motor driven by Ethernet traffic; busy network = whirling string. The founding example of calm, peripheral, non-numeric data. **D7, D5** | [Weiser & Brown text](https://calmtech.com/papers/designing-calm-technology) | `[A]` |
| **UbiFit Garden** | Consolvo et al., Intel Research Seattle / UW, 2008 | Phone wallpaper garden; flowers for activities. Non-numeric glanceable display. **D1, D7** | [Google Research page](https://research.google/pubs/activity-sensing-in-the-wild-a-field-trial-of-ubifit-garden/) | `[B]` |
| **Fish'n'Steps** | Lin, Mamykina et al., Siemens Corporate Research, 2006 | Step count grows a virtual fish; lesson: avoid negative reinforcement. **D1** ("don't blame the user") | [DOI](https://doi.org/10.1007/11853565_16) | `[B]` |
| **Health Mashups** | Bentley et al., Motorola / Georgia Tech, 2013 | Personal correlations as natural-language sentences on the phone. **D1, D8** | [DOI](https://doi.org/10.1145/2503823) | `[B]` |
| **TummyTrials** | Karkar et al., UW, 2017 | Guided n-of-1 food-trigger experiments for IBS. **D2, D4** (the rigorous alternative) | [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC5432136) | `[A]` |
| **SleepCoacher** | Daskalova et al., Brown, 2016 | Clinician-written templates + deterministic analysis + self-experiments; code released. **D8** | [project site](https://sleepcoacher.cs.brown.edu) | `[A]` |
| **Keppi** | Adams et al., Cornell, 2018 | Squeeze-to-report pain device (necklace, bracelet, keychain forms). **D6** | [Dartmouth project page](https://empowerlab.dartmouth.edu/projects/pain-reporting-uis) | `[A]` |
| **Heed** | Paruthi et al., U. Michigan, 2018 | Small situated physical self-report devices. **D6** | [project page](https://gparuthi.github.io/HEED) | `[B]` |
| **Quantile dotplot / OneBusAway study** | Kay et al., UW, 2016 | Uncertainty as countable dots on a phone. **D4** (and the contrast: countable vs not) | [code and data](https://github.com/mjskay/when-ish-is-my-bus) | `[A]` |
| **Handy (sketchy renderer for Processing)** | Wood et al., giCentre, City University London, 2012 | Library that draws charts in a hand-drawn style to signal informality/uncertainty. **D4, D7** | [paper PDF](https://openaccess.city.ac.uk/id/eprint/1274/1/wood_sketchy_2012.pdf) | `[A]` (library name from memory) |
| **Dear Data** | Giorgia Lupi & Stefanie Posavec, 2014–15; book 2016; acquired by MoMA 2016 | A year of weekly hand-drawn postcards of personal data; 104 postcards and sketchbooks in MoMA's collection. **D7, D1** | [MoMA collection](https://www.moma.org/collection/works/216739); [Posavec's site](https://www.stefanieposavec.com/projects/dear-data) | `[A]` |
| **Propeller Health** | Founded as Asthmapolis by David Van Sickle, 2010 (founding details from memory); trials 2016, 2018 | Sensor on the inhaler logs each puff with time and place; app and clinician dashboard. Closest clinical precedent for **D6**; numeric counter-model for **D1** | [outcomes page](https://www.propellerhealth.com/outcomes/) (company page; marketing figures) | `[B]` |
| **AIR Louisville** | Propeller Health, City of Louisville, Institute for Healthy Air, Water and Soil, 2015–17 | City-scale inhaler-sensor programme joined with environmental data. **D3, D6** | [Health Affairs](https://www.healthaffairs.org/doi/pdf/10.1377/hlthaff.2017.1315) | `[A]` |
| **Apple Health: State of Mind** | Apple, iOS 17 / watchOS 10, 2023 | Log a momentary emotion or daily mood on a slider with word labels, then add "associations" chips; history as calendar. Word-first logging. **D1, D6**. I did not reach Apple's own iPhone support article; details from third-party guides. | [iPhone Life guide](https://iphonelife.com/content/how-to-use-daily-mood-log); [Apple Watch guide](https://support.apple.com/en-al/guide/watch/apd7de0f5610/watchos) | `[B]` |
| **Apple Health: Cycle Tracking** | Apple, iOS 13, 2019 | Week strip, tinted log days, predicted days drawn differently from logged days. **D4** (prediction drawn as lighter/hatched). Not verified this session. | https://support.apple.com/en-us/120356 (URL from memory) | `[U]` |
| **Oura Readiness Score** | Oura | Daily 0–100 score from several "contributors" against personal baselines; bands 85–100 Optimal, 70–84 Good, 60–69 Fair, 0–59 "Pay Attention"; formula not published. Counter-model for **D1, D8**; note it *does* use a personal baseline (**D2**). | [Oura support](https://support.ouraring.com/hc/en-us/articles/360057791533) | `[A]` |
| **WHOOP Recovery** | WHOOP | Daily 0–100% recovery in green/yellow/red zones; weighting undisclosed. Counter-model for **D1, D8**. Zone cut-offs read from third-party summaries, not WHOOP's own page. | [comparison article](https://wellnesspulse.com/healthtech/wearable-recovery-scores-explained/) | `[B]` |
| **Clue, Bearable, Daylio, Awair, Plume Labs Flow, IQAir / Tomorrow.io apps, Ambient Orb, Spark (Fan, Forlizzi & Dey 2012), ShutEye (Bauer et al. 2012)** | various | Named in the brief; **not checked this session**. Relevance from memory: Daylio and Bearable log with icons and words; Awair and IQAir show a single air score (counter-model for D3: a score hides source and distance); Ambient Orb is a colour-only ambient display; Spark and ShutEye are abstract/glanceable research displays. | — | `[U]` |

### Inferences
- The counter-model is consistent: one opaque number, colour-banded, with wording that judges ("Pay Attention"). The project inverts each property: no score, one ink that means "yours" not "bad", inspectable rules.
- Oura's use of personal baselines shows D2 is not unique to this project; what is distinctive is showing the personal and population thresholds side by side and in words.

### Gaps
- Consumer-product details change with releases; anything in the table marked `[B]` or `[U]` should be re-checked against the vendor's current page, with screenshots dated, before going into the thesis.
- No art/print precedent for risograph-style health data was searched for; the project's own `docs/design/riso-visual-language.md` may already hold these.

---

## 11. Map: which sources support or challenge each decision

### Takeaway
D3, D4 (as drawing), D5 and D6 are well supported. D1 is supported on affect and burden but challenged on comprehension and causal reading. D2 and D8 rest more on principle and architecture precedents than on direct tests.

### Cited Findings
(Item numbers refer to the entries above; each carries its own source link.)

| Decision | Supports | Challenges / counter-evidence |
|---|---|---|
| **D1** no counts, words | 9 Etkin; 10 Ancker; 6 Lazar; 14 Kennedy & Hill; 19 Fish'n'Steps; 30 Health Mashups; 35 Peters (low numeracy); 63 Vega; 66 UbiFit; 67 Gouveia (abstract); 60 METUX (autonomy) | 33 Budescu (words read inconsistently); 34 Berry/Knapp (words inflate risk); 42 Xiong (text read most causally); 68 Harkin (monitoring works); 24 Cochrane (adherence feedback helps); 35 Peters (numerate people gain from numbers); 60 METUX (competence needs feedback); 18 Schroeder 2019 (people have varied goals) |
| **D2** personal beside population threshold | 26 Janssens & Ritz; 17 Schroeder 2018; 28 Lillie; 29 Kravitz & Duan; 46 Baumer (breakdown); 52 Dörk (plurality); 67 Gouveia (comparison to norms); Oura precedent | 27 Janssens & Harver (new triggers raise burden); 28–29 (observational data are not n-of-1); no direct test found |
| **D3** provenance; missing is missing | 57 Bellotti & Edwards; 36 van der Bles (indirect uncertainty); 38 Hullman; 41 Song & Szafir; 51 Drucker; 53 Loukissas; 59 Chalmers & Galani; 12 Pink et al.; 49 Lupi; 52 Dörk (disclosure); 3 Epstein 2015 (lapses) | 41 Song & Szafir (visible gaps lower perceived quality); glance-time cost (67 Gouveia: five-second glances) |
| **D4** no cause, no prediction; sketch | 42 Xiong; 39 Boukhelifa (dashing preferred); 40 Wood; 37 Kay; 36 van der Bles; 16 TummyTrials (rigor vs everyday life); 26 Janssens & Ritz; 43 Gaver | 40 Wood (sketchiness harms area judgement, varies by person); 37 Kay (people want and can use probability); 67 Gouveia ("actionable"); 20 SleepCoacher (recommendations helped) |
| **D5** summary opens | 58 Shneiderman; 52 Dörk; 57 Bellotti & Edwards; 46 Baumer (inquiry); 44 Sengers & Gaver; 45 Sengers et al.; 1 Li (integration barrier) | Critic's point stands in 51 Drucker / 53 Loukissas: any interface is an interpretation; 67 Gouveia: most use is a glance, so few will open it |
| **D6** one press, voice later, auto baselines | 61 Shiffman; 62 Choe 2017; 4 Choe 2014; 56 Coyle; 63 Vega; 64 Heed; 65 Keppi; 21 Merchant; 22 Barrett; 13 Lupton; 54 Offenhuber; 3, 8 Epstein | 61 Shiffman (later context = recall); 56 Coyle (high automation lowers felt agency); 64 Heed (situated devices do not travel) |
| **D7** riso/textile, ambiguity, one ink | 43 Gaver; 44 Sengers & Gaver; 47 Hallnäs & Redström; 48 Weiser & Brown; 49 Lupi; 50 D'Ignazio & Klein; 14 Kennedy & Hill; 40 Wood (engagement); 66 UbiFit; Dear Data | Ambiguity untested in health; 34 Berry/Knapp and 33 Budescu show imprecise expression is read with wide variance; 40 Wood (precision loss) |
| **D8** deterministic code, model suggests only | 57 Bellotti & Edwards; 31 Jones & Kelly (filtering); 20 SleepCoacher (templates); 30 Health Mashups; 4 Choe 2014 (rigor); 56 Coyle (assistance limit); Kay 2006 scrutability `[U]`; Oura/WHOOP as opaque counter-model | No direct evaluation found; rule thresholds are themselves an index the person did not choose (thesis must own this) |

### Inferences
- The thesis' own argument applies to the app: gates, bins and the closed tag list are an index that hides and reveals. D5 and D8 (inspectable, exportable) are what make that defensible; it is worth saying so explicitly instead of leaving it for an examiner.
- If only ten sources can be cited, the highest-yield set is: Ancker 2015; Etkin 2016; Choe 2014; Janssens & Ritz 2013; Bellotti & Edwards 2001; Boukhelifa 2012; Xiong 2020; Budescu 2009; Gaver 2003; Dörk 2013, with Harkin 2016 and Knapp 2004 as the stated counter-evidence.

### Gaps
- Verification limits: I worked through search and fetch tools; no paper was read in full. Study sizes and findings above come from abstracts or repository records as linked. Items marked `[B]` had truncated abstracts; items marked `[U]` and DOIs marked "from memory" must be checked.
- Unverified sources named in the brief, in one place for follow-up: Lupton 2016; Neff & Nafus 2016; Schüll 2016; Ruckenstein & Pantzar 2017; Sharon & Zandbergen 2017; Lupton et al. 2018 ("data sense"); Mamykina 2017; Katz 2018; O'Kane; Felipe; Pichon 2020/21; Tinschert 2017; Cochrane action-plan reviews; Estrin 2014; Rapp & Cena 2016; Budescu & Wallsten; Fischhoff; IPCC guidance note; Boehner 2007; Höök 2018; Dourish 2001; Odom; Dunne & Raby; DiSalvo; Jansen 2015; Limerick 2014; Shneiderman & Maes 1997; Shneiderman 2022; Lukoff 2021; Kay 2006 (record only); Consolvo 2006; ShutEye; ModEx; Spark; and the consumer products listed as `[U]` in section 10.
- Corrections to the brief found while checking: Merchant 2016's co-authors are Inamdar and Quade; the Jones & Kelly title is "Dealing with information overload in multifaceted personal informatics systems"; "data sense" is from Lupton et al. 2018, not Lupton 2017; AIR Louisville's peer-reviewed figure is 78%, not 82%.

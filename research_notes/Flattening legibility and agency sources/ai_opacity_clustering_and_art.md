# AI opacity ("the black box"): how machine learning hides the way it clusters, classifies and embeds, and the art and design that exposes it

How to read these notes

- **Verification status** is given on every entry:
  - **[page read]** = I fetched the publisher, arXiv, DOI or project page this session and the details and quotes come from it.
  - **[search-verified]** = the publisher page blocked the fetch (SAGE, Springer, Elsevier, MIT Press, PeerJ all returned 403 or a login redirect); citation details and wording come from search results that point to the publisher, DOAJ, an institutional repository or the author's page. **Check any quote against the PDF before it goes in the thesis.**
  - **[not verified]** = listed under Gaps only, from memory, with no page checked.
- Quotes are short on purpose and are only given where a page returned the words. Page fetches were read through a summarising model, so treat every quote as "check against the original once", even the [page read] ones.
- "Bearing on the thesis" lines are my reading, not the source's.
- The web search budget ran out before the last round finished. What that left unchecked is listed in the Gaps of each section.

The thesis, as given: indexing systems flatten information, choose what to hide and reveal, and so take agency from the person. Refinement: the problem is **a summary that cannot be opened back into what it was made from**.

---

## 1. Opacity theory: what kinds of opacity are there, and is "opening the box" the right goal?

### Takeaway
The core literature gives the thesis its vocabulary (Burrell's three opacities, Latour's black-boxing, Pasquinelli and Joler's "information compression") but its strongest authors also warn that "opening the box" is the wrong picture: Ananny and Crawford and Seaver both argue that seeing inside is not the same as understanding or being able to act. The refinement ("a summary that cannot be opened back") fits this literature better than a plain demand for transparency.

### Cited Findings

**1. Burrell, Jenna (2016). "How the machine 'thinks': Understanding opacity in machine learning algorithms." *Big Data & Society* 3(1). DOI 10.1177/2053951715622512.** [search-verified]
- Core claim: opacity is not one thing. The abstract separates three forms: "(1) opacity as intentional corporate or state secrecy, (2) opacity as technical illiteracy, and (3) an opacity that arises from the characteristics of machine learning algorithms and the scale required to apply them usefully" (abstract wording as returned from the DOAJ and Berkeley records). The article looks at classifiers and rankers (spam filters, credit scoring, search) and does a light code audit. Its conclusion is that knowing which form is at work decides which technical or non-technical remedy can help. — [DOI](https://doi.org/10.1177/2053951715622512); [DOAJ record](https://doaj.org/article/e24df3681a27440f95339729c7a4e28c); [Berkeley I School page](https://www.ischool.berkeley.edu/research/publications/2016/how-machine-thinks-understanding-opacity-machine-learning-algorithms)
- Bearing on the thesis: **supports and sharpens.** The birdsong work is about Burrell's third kind: not secrecy, not the viewer's lack of training, but the mismatch between a high-dimensional computation and human-scale reading. Naming that lets the thesis avoid the easy objection "the code is open source".

**2. Ananny, Mike & Crawford, Kate (2018). "Seeing without knowing: Limitations of the transparency ideal and its application to algorithmic accountability." *New Media & Society* 20(3): 973–989. DOI 10.1177/1461444816676645.** [search-verified]
- Core claim: the transparency ideal assumes that "seeing a phenomenon creates opportunities and obligations to make it accountable and thus to change it" (as returned by search of the abstract). The authors trace that ideal's history, set out ten limits to it, and sketch an alternative account of accountability that works with those limits and looks across the whole system, not inside one component. — [DOI](https://doi.org/10.1177/1461444816676645); [Microsoft Research page](https://www.microsoft.com/en-us/research/publication/seeing-without-knowing-limitations-of-the-transparency-ideal-and-its-application-to-algorithmic-accountability/)
- Bearing on the thesis: **complicates.** If the thesis says "reveal the hidden clustering and agency returns", this is the paper an examiner will cite against it. It supports the refined claim: what matters is whether a person can go from the summary back to its sources and act, not whether they can look.

**3. Seaver, Nick (2017). "Algorithms as culture: Some tactics for the ethnography of algorithmic systems." *Big Data & Society* 4(2). DOI 10.1177/2053951717738104.** [search-verified]
- Core claim: algorithms are not rigid formulas hidden in a box but "heterogeneous and diffuse sociotechnical systems"; they are "multiples", enacted by the practices of the people who work with them, critics included. Auditing itself "enacts an understanding of algorithms as black boxes" (phrases as returned from the DOAJ abstract). — [DOI](https://doi.org/10.1177/2053951717738104); [DOAJ record](https://doaj.org/article/ec1f2c44e7554a65b280242af44d9fe7)
- Bearing on the thesis: **complicates.** The "black box" is partly made by the way we approach it. A work that stages the box as sealed risks reinforcing the myth. Useful if the birdsong piece shows the people and choices (who recorded, who labelled, who set the parameters) and not only the machine.

**4. Latour, Bruno (1999). *Pandora's Hope: Essays on the Reality of Science Studies.* Harvard University Press, glossary entry "blackboxing", p. 304.** [search-verified, secondary sources only]
- Core claim: blackboxing is "the way scientific and technical work is made invisible by its own success"; the follow-on sentence says that the more science and technology succeed, "the more opaque and obscure they become". Both phrases and the page number were confirmed only through secondary pages (a Wikipedia entry and a course page), not the book. — [Wikipedia: Blackboxing](https://en.wikipedia.org/wiki/Blackboxing)
- Bearing on the thesis: **supports.** Opacity is a product of things working. A species label that is right most of the time stops anyone asking how it was reached.

**5. Crawford, Kate & Paglen, Trevor (2019). "Excavating AI: The Politics of Images in Machine Learning Training Sets." AI Now Institute, 19 September 2019.** [page read]
- Core claim: training sets are where classification gets its politics. Labels are attached to images by people and taxonomies, then treated as ground truth. Quotes: "Images do not describe themselves." "Datasets aren't simply raw materials to feed algorithms, but are political interventions." "ImageNet's labels often compress and simplify images into deadpan banalities." — [excavating.ai](https://excavating.ai/)
- Bearing on the thesis: **supports directly.** The verb "compress" is the thesis's "flatten". It also moves the hidden thing from the model to the labelled data, which is the part a design project can actually show.

**6. Crawford, Kate & Joler, Vladan (2018). "Anatomy of an AI System: The Amazon Echo as an Anatomical Map of Human Labor, Data and Planetary Resources." AI Now Institute and SHARE Lab.** [page read]
- Core claim: one voice command rests on a planetary system of mining, labour and data that the interface hides. Quoted fragments: each "small moment of convenience" "requires a vast planetary network, fueled by the extraction of non-renewable materials, labor, and data"; "the material details of those costs remain vague in the social imagination." — [anatomyof.ai](https://anatomyof.ai/)
- Bearing on the thesis: **supports, and is also a design precedent** (a map that opens one summary, "Alexa, turn on the lights", back into what it was made from).

**7. Pasquinelli, Matteo & Joler, Vladan (2021). "The Nooscope manifested: AI as instrument of knowledge extractivism." *AI & Society* 36: 1263–1280. DOI 10.1007/s00146-020-01097-6.** [search-verified; open access copy on PMC]
- Core claim: machine learning is best understood as an instrument, like a lens, not as an intelligence. The map's stated purpose is "to secularize AI from the ideological status of 'intelligent machine' to one of knowledge instruments" (as returned by search). "Information compression" is one of the paper's keywords; the authors treat ML as a statistical compression of training data with characteristic distortions. A second version appeared in *Interface Critique* 3 (2021), pp. 37–68. — [DOI](https://doi.org/10.1007/s00146-020-01097-6); [PMC full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC7680082); [author's page](https://matteopasquinelli.com/nooscope)
- Bearing on the thesis: **supports the refinement most directly.** A lens that compresses and distorts is exactly "a summary". The authors' position that the black box is partly rhetoric also **complicates**: they say the box can be diagrammed.

**8. Amoore, Louise (2020). *Cloud Ethics: Algorithms and the Attributes of Ourselves and Others.* Duke University Press.** [search-verified at Duke UP page]
- Core claim: the ethics of algorithms lies in "the conditions of partiality and opacity that haunt both human and algorithmic decisions" (publisher description as returned by search). Chapter 5 is "The Doubtful Algorithm: Ground Truth and Partial Accounts". Amoore argues against the demand for full transparency: every account, human or machine, is partial. — [Duke UP](https://www.dukeupress.edu/cloud-ethics); [Project MUSE](https://muse.jhu.edu/book/74022)
- Bearing on the thesis: **complicates.** Opacity is not a fault to be removed; the question is what the output closes off (the alternatives that are discarded when many possibilities become one answer). That is close to the refinement: one output that cannot be reopened.

**9. Mackenzie, Adrian (2017). *Machine Learners: Archaeology of a Data Practice.* MIT Press.** [search-verified via Lancaster University repository and catalogue records]
- Core claim: a Foucault-style archaeology of machine learning as a form of knowledge production and power. The contents include a chapter titled "Vectorization and its consequences": everything must first be made into a vector in a common space before it can be learned from. — [Lancaster eprints](https://eprints.lancs.ac.uk/id/eprint/84451)
- Bearing on the thesis: **supports.** Gives the technical name for the first flattening: a bird call, an image and a person become rows of numbers in one table before any clustering starts.

**10. Steyerl, Hito (2023). "Mean Images." *New Left Review* 140/141, March–June 2023.** [page read]
- Core claim: generated images are statistical renderings, not records of anything. Quotes: "They converge around the average, the median; hallucinated mediocrity." "They represent the norm by signalling the mean." "They replace likenesses with likelinesses." — [New Left Review](https://newleftreview.org/issues/ii140/articles/hito-steyerl-mean-images)
- Bearing on the thesis: **supports.** A mean is the plainest case of a summary that cannot be opened back into its members.

### Inferences
- Three positions are available and the thesis should say which one it takes: (a) the box hides something that could be shown (Pasquale-style secrecy, Burrell type 1); (b) the box cannot be shown in human terms at all (Burrell type 3); (c) "the box" is the wrong picture and the thing to look at is the whole arrangement of people, data and choices (Seaver, Ananny & Crawford, Crawford & Joler). The refinement, "a summary that cannot be opened back into what it was made from", sits best with (c): it asks for a path back to sources, not a window on weights.
- The claim "takes agency from the person" is asserted more than shown in this literature. Ananny & Crawford's point that seeing does not give the power to change is the best support for treating agency (being able to trace, contest, redo) as the test, in place of visibility.

### Gaps
- **Not verified this session (search budget ran out or publisher blocked); details below are from memory and need checking at the publisher:**
  - Pasquale, Frank (2015). *The Black Box Society: The Secret Algorithms That Control Money and Information.* Harvard University Press. (Secrecy as business and legal strategy; Burrell's type 1.)
  - Bucher, Taina (2018). *If...Then: Algorithmic Power and Politics.* Oxford University Press. (Argues the black box is a "red herring"; proposes studying how people experience algorithms.)
  - Crawford, Kate (2021). *Atlas of AI.* Yale University Press. (Classification chapter.)
  - Chun, Wendy Hui Kyong (2021). *Discriminating Data: Correlation, Neighborhoods, and the New Politics of Recognition.* MIT Press. (Homophily as the built-in assumption of clustering and recommendation.) The MIT Press page returned 403. **This is the most relevant unverified source for the clustering argument; it should be read directly.**
  - Pasquinelli, Matteo (2023). *The Eye of the Master: A Social History of Artificial Intelligence.* Verso.
  - Bowker, Geoffrey C. & Star, Susan Leigh (1999). *Sorting Things Out: Classification and Its Consequences.* MIT Press. (Classifications as invisible infrastructure; "residual categories".)
  - Seaver, Nick (2022). *Computing Taste: Algorithms and the Makers of Music Recommendation.* University of Chicago Press.
- I could not open the Burrell, Ananny & Crawford or Seaver full texts (SAGE returned 403), so I have no page-numbered quotes and could not list Ananny & Crawford's ten limits. Both *Big Data & Society* papers are open access and should open in a browser.
- The Latour quote is confirmed only from secondary pages.

---

## 2. Dimensionality reduction as literal flattening: what do t-SNE and UMAP maps hide?

### Takeaway
This is the thesis's best-evidenced ground. The makers and closest users of these methods say in plain words that cluster sizes and the distances between clusters in a 2D map may mean nothing, that the picture changes with settings, and that pure noise can look like structure; Chari and Pachter show the same data can be fitted to the shape of an elephant with comparable scores. "Flattening" here is not a metaphor: hundreds of dimensions become two, and the step cannot be reversed.

### Cited Findings

**11. van der Maaten, Laurens & Hinton, Geoffrey (2008). "Visualizing Data using t-SNE." *Journal of Machine Learning Research* 9(86): 2579–2605.** [page read]
- Core claim: t-SNE gives each high-dimensional data point a place on a 2D or 3D map. Quote: "t-SNE is better than existing techniques at creating a single map that reveals structure at many different scales." It is "a variation of Stochastic Neighbor Embedding". — [JMLR](https://www.jmlr.org/papers/v9/vandermaaten08a.html)
- Bearing on the thesis: the primary source for the method behind the 2016–17 Bird Sounds map. Note the word "reveals": the method is presented as a tool for showing, which the later literature qualifies.

**12. McInnes, Leland; Healy, John & Melville, James (2018). "UMAP: Uniform Manifold Approximation and Projection for Dimension Reduction." arXiv:1802.03426.** [page read]
- Core claim: quote: "UMAP (Uniform Manifold Approximation and Projection) is a novel manifold learning technique for dimension reduction." "The result is a practical scalable algorithm that applies to real world data." — [arXiv](https://arxiv.org/abs/1802.03426)
- Bearing on the thesis: primary source for the method now standard for embedding maps.

**13. Wattenberg, Martin; Viégas, Fernanda & Johnson, Ian (2016). "How to Use t-SNE Effectively." *Distill*, 13 October 2016. DOI 10.23915/distill.00002.** [page read]
- Core claim: t-SNE plots are easy to misread. The section headings are the argument: "Those hyperparameters really matter"; "Cluster sizes in a t-SNE plot mean nothing"; "Distances between clusters might not mean anything"; "Random noise doesn't always look random."; "You can see some shapes, sometimes"; "For topology, you may need more than one plot". Further quotes: "The basic message is that distances between well-separated clusters in a t-SNE plot may mean nothing." "A classic pitfall is thinking you see patterns in what is really just random data." — [Distill](https://distill.pub/2016/misread-tsne/)
- Bearing on the thesis: **supports strongly, and is itself a precedent.** It is an interactive essay where the reader moves the settings and watches the "clusters" change: an interface that hands the hidden choice back to the person. Written by the people who build the tools, so it cannot be dismissed as outside critique.

**14. Chari, Tara & Pachter, Lior (2023). "The specious art of single-cell genomics." *PLoS Computational Biology* 19(8): e1011288. DOI 10.1371/journal.pcbi.1011288.** [page read; the page notes a correction was published in November 2025, check what it changes]
- Core claim: quote: "extreme dimension reduction, from hundreds or thousands of dimensions to 2, inevitably induces significant distortion of high-dimensional datasets." The authors "find that extensive distortions and inconsistent practices make such embeddings counter-productive". To make the point they "developed an autoencoder framework to fit cells from any dataset to an arbitrary 2D shape", showing "it is possible to embed data in the shape of a 'von Neumann elephant'", with scores comparable to t-SNE and UMAP on their distance metrics. They recommend targeted analysis in higher dimensions in place of 2D maps for exploration. — [PLOS](https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1011288)
- Bearing on the thesis: **the strongest single support for "flattening".** The word "inevitably" matters: the loss is a property of going to two dimensions, not a flaw of one tool. The elephant is a ready-made image for a defence. It is about genomics, so say so; the mathematics carries over, the domain evidence does not.

**15. Coenen, Andy & Pearce, Adam (Google PAIR). "Understanding UMAP." Interactive article, pair-code.github.io/understanding-umap.** [existence and authorship search-verified; body text not read: the page renders with scripts and returned only its title]
- Core claim: an explorable in the style of entry 13, for UMAP. The one sentence I could confirm: "The most important parameter is n_neighbors - the number of approximate nearest neighbors used to construct the initial high-dimensional graph." — [article](https://pair-code.github.io/understanding-umap/); [source repository](https://github.com/PAIR-code/understanding-umap)
- Bearing on the thesis: precedent for an interface that exposes the setting that decides what counts as a neighbour.

**16. Carter, Shan; Armstrong, Zan; Schubert, Ludwig; Johnson, Ian & Olah, Chris (2019). "Activation Atlas." *Distill*, 6 March 2019. DOI 10.23915/distill.00015.** [page read]
- Core claim: an atlas shows "how the network typically represents some concepts". It is built by projecting activation vectors to 2D with UMAP or t-SNE, laying a grid over the result, averaging the activations in each cell and drawing a picture for each average. The authors state it is "dependent on the distribution of the data we choose to sample activations from." — [Distill](https://distill.pub/2019/activation-atlas/)
- Bearing on the thesis: **complicates.** The best-known tool for opening the box is built from the same flattening (project to 2D, then average). The explanation is another summary.

**17. Olah, Chris; Mordvintsev, Alexander & Schubert, Ludwig (2017). "Feature Visualization." *Distill*. DOI 10.23915/distill.00007.** [page read]
- Core claim: "Feature visualization answers questions about what a network — or parts of a network — are looking for". Stated limit: "By itself, feature visualization will never give a completely satisfactory understanding." — [Distill](https://distill.pub/2017/feature-visualization/)
- Bearing on the thesis: **partly opposes** (some of the box can be shown), with the limit admitted by its own authors.

### Inferences
- What an embedding map hides, pulling the sources together: (1) **which features drove the grouping**: the axes of a t-SNE or UMAP plot have no meaning, so position cannot be read back into "because of pitch" or "because of rhythm" (entries 13, 14); (2) **true distances**: only near neighbours are roughly kept; cluster size and gaps between clusters "mean nothing" or "might not mean anything" (13); (3) **the settings**: perplexity or n_neighbours decide what a neighbourhood is, and a single published map shows one setting (13, 15); (4) **what went in**: the result depends on the sample chosen (16) and, for supervised models, on labels attached by people (entry 5).
- The step is one-way. You cannot recover a point's original features from its 2D position. That is the precise technical sense in which this is "a summary that cannot be opened back into what it was made from".
- A fair limit on the argument: these maps are honest about being maps to the people who make them (11–17 are all by practitioners). The opacity arrives when the map is shown to the public without its caveats, as a finished picture. The thesis is on firmer ground attacking the presentation than the mathematics.

### Gaps
- I could not read the body of "Understanding UMAP" (script-rendered) so have no quotes on what UMAP fails to preserve; a mirror PDF returned 503.
- I did not find, and did not have budget to search for, a paper that measures how lay viewers misread embedding maps. The claim that the public reads cluster distance as similarity is an inference from entries 13 and 14, not a cited finding.
- Not searched: Kobak & Berens (2019) on t-SNE in single-cell work, and the published replies to Chari & Pachter defending UMAP when used with care. An examiner from data science may raise these.

---

## 3. Birdsong and bioacoustics machine learning: what is a bird's sound reduced to, and what is discarded?

### Takeaway
Across the systems checked, a bird's sound becomes a short spectrogram image, then a vector, then a species name (sometimes with a score); the unit is the species, and training requires people to mark and name every call. I found good technical and field-accuracy sources, and a real critical literature on machine listening for human voice, but **no peer-reviewed sound-studies or ethnographic critique of bird ID apps**. That absence is a finding: the birdsong work is entering a gap, not a crowded field.

### Cited Findings

**18. Kahl, Stefan; Wood, Connor M.; Eibl, Maximilian & Klinck, Holger (2021). "BirdNET: A deep learning solution for avian diversity monitoring." *Ecological Informatics* 61: 101236. DOI 10.1016/j.ecoinf.2021.101236.** [search-verified; Elsevier returned 403; the abstract details below came through a Chinese-language mirror of the abstract]
- Core claim: a deep neural network that identifies 984 North American and European bird species by sound. Input is a spectrogram; the paper reports that finer time resolution in the spectrogram improved results. Reported performance: mean average precision 0.791 on single-species recordings, F0.5 of 0.414 on annotated soundscapes. — [DOI](https://doi.org/10.1016/j.ecoinf.2021.101236); [BirdNET code](https://github.com/birdnet-team/birdnet)
- Bearing on the thesis: shows the chain audio → picture → fixed list of species. The drop from 0.791 on clean single-species clips to 0.414 on real soundscapes is the gap between the tidy category and the field. A fixed list of 984 also means a sound from outside the list must still be answered from inside it or dropped.

**19. Hoffman, Benjamin & Van Horn, Grant (2021). "Behind the Scenes of Sound ID in Merlin." Macaulay Library, Cornell Lab of Ornithology, 22 June 2021.** [page read]
- Core claim: quotes: "Merlin converts the audio into an image called a spectrogram." "This spectrogram image is then fed into a modern computer vision model called a deep convolutional neural network." The model was trained "based on 140 hours of audio containing bird sounds" plus "126 hours of audio containing non-bird background sounds, like whistling and car noises"; experts "found the precise moments when birds were making sounds" and tagged them with the species. The user sees "live predictions of who's singing." — [Macaulay Library](https://www.macaulaylibrary.org/2021/06/22/behind-the-scenes-of-sound-id-in-merlin/)
- Bearing on the thesis: **supports, with a twist.** Listening is first turned into looking (sound becomes an image and is handed to a vision model). And the "who" in "who's singing" is a species, never an individual. The human work of marking each call is named here by the makers but is invisible in the app.
- Related figures: Cornell material returned by search says more than 150 recordings per species are needed to train Merlin for that species, and a Cornell Lab year-end summary from early 2026 gives 2,066 species for Sound ID (an earlier, undated release gave 1,054). — [Birding Wire, Cornell Lab milestones](https://www.birdingwire.com/releases/2026/01/milestones-at-the-cornell-lab-ebird-merlin-macaulay-library-and-birds-of-the-world-reach-historic/) [search-verified, not read]

**20. Ghani, Burooj; Denton, Tom; Kahl, Stefan & Klinck, Holger (2023). "Global birdsong embeddings enable superior transfer learning for bioacoustic classification." *Scientific Reports* 13: 22876. DOI 10.1038/s41598-023-49989-z (arXiv:2307.06292).** [arXiv page read; journal page redirected to login. Volume and article number are from memory]
- Core claim: this is the paper behind Google's Perch model family and BirdNET embeddings. Quotes: "high-quality feature embeddings from large-scale acoustic bird classifiers can be harnessed for few-shot transfer learning"; "embeddings extracted from the models trained on bird vocalization data consistently allowed higher quality classification". — [arXiv](https://arxiv.org/abs/2307.06292); [journal DOI](https://doi.org/10.1038/s41598-023-49989-z)
- Bearing on the thesis: **complicates.** The embedding is not only a loss. The same vector that hides the bird behind a species name holds enough structure to be reused for other animals and call types with a handful of examples. The summary keeps more than its label shows; it is the interface, not the vector, that throws the rest away.

**21. Goodman, B. D.; Lima, K. A.; Benz, S.; Fisichelli, N. A. & Kitzes, J. (2025). "Humans outperform Merlin Sound ID in field-based point-count surveys." *Ornithological Applications* 127(4): 1–8. DOI 10.1093/ornithapp/duaf049.** [page read]
- Core claim: quotes: "Precision was similar with 92% and 86% for humans and Merlin, respectively." "Merlin disagreed with itself on 57% of point counts when running on 2 different devices at the same time." Search results for the same paper report that humans detected 72% more individual birds than Merlin; the authors suggest Merlin fits best as a second observer. — [Oxford Academic](https://academic.oup.com/condor/article/127/4/1/8222742); [Schoodic Institute summary](https://schoodicinstitute.org/whats-that-bird-humans-outperform-merlin-sound-id/)
- Bearing on the thesis: **supports.** Two phones side by side give different species lists more than half the time, and the app shows neither that variation nor a count of individuals. A confident list hides an unstable process.

**22. Audubon Magazine, "Merlin Is Magical, but It Still Makes Mistakes."** [search-verified, not read]
- Core claim: the app analyses sound in three-second intervals, but an accurate identification sometimes needs a longer stretch of song. — [Audubon](https://www.audubon.org/magazine/merlin-magical-it-still-makes-mistakes)
- Bearing on the thesis: the window is a flattening in time: anything a bird does over more than three seconds (a long phrase, a sequence, a duet) is cut into pieces before it is judged.

**23. Robinson, David et al. (Earth Species Project) (2024). "NatureLM-audio: an Audio-Language Foundation Model for Bioacoustics." arXiv:2411.07186; ICLR 2025.** [search-verified]
- Core claim: an audio encoder joined to a large language model (LLaMA 3.1-8B) for classification, detection and captioning of animal sound. The project reports it "predicts the scientific name of the correct species 20% of the time" for species it has never heard, choosing among two hundred. — [arXiv](https://arxiv.org/abs/2411.07186); [Earth Species Project announcement](https://earthspecies.org/2024/11/11/introducing-naturelm-audio-an-audio-language-foundation-model-for-bioacoustics/)
- Bearing on the thesis: the direction of travel. The output is moving from a label to a sentence about the sound, which reads as richer but is a further layer of summary with no path back.

**24. Sterne, Jonathan & Sawhney, Mehak (2022). "The Acousmatic Question and the Will to Datafy: Otter.ai, Low-Resource Languages, and the Politics of Machine Listening." *Kalfou* 9(2): 288–306.** [search-verified]
- Core claim: machine listening takes over the question "Who is this?" and answers it by turning voices into data. From the abstract as returned: "While machine listening is promoted to users in the name of utility, inclusiveness, and access, it also serves corporate purposes: the expropriation and ownership of massive collections of data." The article is about speech, not birds. — [Kalfou](https://tupjournals.temple.edu/index.php/kalfou/article/view/617); [author's PDF](https://sterneworks.org/wp-content/uploads/2024/01/Sterne-Sawhney-AcousmaticQuestion.pdf)
- Bearing on the thesis: **supports by analogy.** "Who is this?" answered with a category is the Merlin interface. The access argument cuts both ways (see section 6).

**25. Machine Listening (Sean Dockray, James Parker, Joel Stern; Liquid Architecture). "Machine Listening, a Curriculum." 2020–, machinelistening.exposed.** [page read; the page itself does not name the three authors, that attribution is from the task brief and my memory]
- Core claim: an open, growing curriculum (readings, commissioned writing, interviews, works, workshops). It describes itself as a "site of collective learning about and mobilisation against the coming world of listening machines" and names "oppressive and extractive forms of state and corporate listening". — [machinelistening.exposed](https://machinelistening.exposed/curriculum/)
- Bearing on the thesis: the nearest organised critical field, and a precedent for teaching as a way of opening the box. I could not confirm from the page whether it has a module on animals or birdsong.

**Practitioner views on bird ID apps (not scholarship)** [search-verified, not read]
- A Colby College birding blog reports that a minority of birders oppose Merlin for censuses or identification "because of possible errors and because Merlin could be a barrier to developing our own skills in auditory and visual identification"; the same post says Sound ID lets "birds … be enjoyed even if an observer has difficulty in seeing the birds." — [Colby, Maine Birds](https://web.colby.edu/mainebirds/2022/09/11/merlin-and-the-use-of-artificial-intelligence-in-bird-identification/)
- A Digital Seams essay notes that generating the training data "is labor intensive, because it requires sound ID experts to listen to each audio file carefully." — [Digital Seams](https://digitalseams.com/blog/what-birdsong-and-backends-can-teach-us-about-magic)

### Inferences
- The reduction chain, assembled from entries 18–23: **living bird in a place → microphone recording → three-second window → spectrogram image → embedding vector → nearest species in a fixed list → name on a screen (and at most a score).** Each arrow drops something: the individual bird; regional dialect and song learned from neighbours; what the bird was doing and to whom; sequence longer than the window; anything the list has no row for. None of entries 18–21 describes output at the level of the individual or the dialect. This list of what is dropped is my inference from what the systems output; I did not find a source that sets it out.
- The spectrogram step deserves a line in the thesis: before any clustering, hearing is converted to an image so that tools built for seeing can be used (19). That is a design decision with consequences, and it is rarely shown to users.
- The unknown is handled by training on "non-bird background sounds" (19): the world is divided into listed species and background. A call that is neither has no place to go. This parallels Bowker & Star's residual categories (unverified, see section 1 Gaps).
- The 2D birdsong map (entry P1 below) and the species ID apps hide different things. The map hides why two sounds are neighbours. The app hides that there was ever a neighbourhood: it shows one name. The thesis should say which of these the birdsong work addresses.

### Gaps
- **No scholarly ethnography or sound-studies critique of Merlin, BirdNET or birding by app was found** in two targeted searches, one extended. Results were field-accuracy studies, trade press and blogs. I could not run further searches (budget). Worth trying by hand: *Sound Studies*, *Science, Technology, & Human Values*, *Environmental Humanities*; search terms "eBird" and "citizen science" with "classification"; work by Mack Hagood, Dan McQuillan and Jonathan Sterne's "Is Machine Listening Listening?" (*communication +1*, 2022, title confirmed in search results only) were on the brief and were **not verified**.
- Stowell, Dan (2022). "Computational bioacoustics with deep learning: a review and roadmap." *PeerJ* 10: e13152 **[not verified, PeerJ returned 403; from memory]**. This review would be the right source for what the field itself counts as unsolved (individual identification, open-set recognition, call types). Read it directly before citing.
- Google Perch: I verified the paper (entry 20) but not a Google project page, model name history or embedding size.
- I could not open the BirdNET paper itself; the 984-species figure and scores come from a mirror of the abstract.
- I found no source on how these apps display or hide the confidence score to users.

---

## 4. Art and design that opens the box (precedent projects)

### Takeaway
The precedents sort into four strategies: show the data and the labour behind it; let the classifier act on the viewer so its categories are felt; map the whole system; build an interface where the viewer moves the hidden settings. The birdsong work's closest ancestor, Google's Bird Sounds, does the reverse of all four: it presents the map as the finding.

### Cited Findings

**P1. Kyle McDonald, Manny Tan, Yotam Mann and friends at Google Creative Lab — *Bird Sounds* (AI Experiments).** Listed as published May 2017 on Experiments with Google (the brief says 2016; AI Experiments launched in late 2016. Check the date you cite). [page read]
- What it does: lays out thousands of bird recordings on a 2D map. Page text: "This experiment uses machine learning to organize thousands of bird sounds." "The computer wasn't given tags or the birds' names – only the audio." "Using a technique called t-SNE, the computer created this map, where similar sounds are placed closer together." Sounds are from the Macaulay Library's Essential Set for North America, with thanks to the Cornell Lab of Ornithology. — [project page](https://experiments.withgoogle.com/bird-sounds); [source code](https://github.com/googlecreativelab/aiexperiments-bird-sounds)
- Reveals: that sounds can be arranged by likeness without names. Hides: what "similar" was computed from, the t-SNE settings, and everything entry 13 warns about. The sentence "similar sounds are placed closer together" is the exact reading that Wattenberg et al. say fails between clusters. **This is the direct foil for the thesis's birdsong work.**

**P2. Anna Ridler — *Myriad (Tulips)*, 2018.** [page read]
- What it does: thousands of tulip photographs taken and labelled by hand by the artist, shown as prints on a wall over 50 square metres; the same set trained her *Mosaic Virus*. Page text: "each photograph has a handwritten label underneath it with some of the categories that were used"; the work is "helping to expose the human element in machine learning, usually hidden by algorithmic processes"; "By choosing to make the dataset an artwork it draws attention to the skill, labour and time that goes into constructing it". — [annaridler.com](https://annaridler.com/myriad-tulips)
- Reveals: the dataset and the labeller's hand. The summary is physically opened back into what it was made from. Closest precedent for the refined thesis.

**P3. Trevor Paglen & Kate Crawford — *ImageNet Roulette*, 2019 (in *Training Humans*, Fondazione Prada Osservatorio, Milan).** [search-verified from press]
- What it does: a web tool that classified an uploaded selfie using ImageNet's "person" categories. Days after it spread, ImageNet said it would remove 438 people categories and 600,040 associated images (ImageNet did not credit the project). The artists took it offline on 27 September 2019. — [The Art Newspaper](https://www.theartnewspaper.com/2019/09/23/leading-online-database-to-remove-600000-images-after-art-project-reveals-its-racist-bias); [Artforum](https://www.artforum.com/news/image-database-purges-600k-photos-after-trevor-paglen-project-reveals-biases-80829); essay at [excavating.ai](https://excavating.ai/)
- Reveals: the label set, by turning it on the viewer. Evidence that exposure can change the system exposed.

**P4. Trevor Paglen — *Adversarially Evolved Hallucinations*, 2017 (in *A Study of Invisible Images*, Metro Pictures, New York, 8 September–21 October 2017).** [search-verified; artist's page exists]
- What it does: Paglen built training sets from "literature, philosophy, folk-wisdom, history, and other 'irrational' things" (for example "Omens and Portents", "Interpretation of Dreams") and showed the images a generator made from each. — [paglen.studio](https://paglen.studio/2020/04/09/hallucinations/); [Brooklyn Rail review](https://brooklynrail.org/2017/10/artseen/TREVOR-PAGLEN-A-Study-of-Invisible-Things/)
- Reveals: that the category is chosen by someone, by choosing absurd ones. Each title names its corpus.

**P5. Mimi Ọnụọha — *The Library of Missing Datasets*, 2016 (version 2.0, 2018).** [search-verified; my direct fetch of the artist's page returned 404, so open it in a browser]
- What it does: a filing cabinet of empty folders, each titled with a dataset that does not exist. Artist's text as returned: "'Missing data sets' are the blank spots that exist in spaces that are otherwise data-saturated." — [artist's page](https://mimionuoha.com/the-library-of-missing-datasets); [running list on GitHub](https://github.com/MimiOnuoha/missing-datasets); [AIGA Eye on Design](https://eyeondesign.aiga.org/finding-the-blank-spots-in-big-data/)
- Reveals: what an index leaves out. Precedent for the unknown or unlisted call.

**P6. Memo Akten — *Learning to See*, 2017–.** [page read]
- What it does: a camera looks at cloths and cables on a table; networks trained on waves, flowers or fire redraw the scene live as what they know. Page text: "But it can only see through the filter of what it already knows." "Just like us." — [memo.tv](https://www.memo.tv/works/learning-to-see/)
- Reveals: the training set as the limit of what can be seen, in real time, with the input beside the output.

**P7. Refik Anadol — *Unsupervised — Machine Hallucinations — MoMA*, 2022 (acquired by MoMA 2023), and its critics.** [critiques: e-flux page read; others search-verified]
- What it does: a model trained on MoMA's collection data generates moving forms on a lobby-scale screen.
- R.H. Lossin, "Refik Anadol's 'Unsupervised'", *e-flux Criticism*, 14 March 2023: "The AI is not, as the press release implies and many reviewers have assumed, 'seeing' images." "This is hard to discern through its fun, candy-colored spectacle". The concern is "the cultural work that the spectacular AI is doing to normalize surveillance systems". — [e-flux](https://www.e-flux.com/criticism/527236/refik-anadol-s-unsupervised)
- Ben Davis, "An Extremely Intelligent Lava Lamp", Artnet News: treating the collection as a dataset implies art history is only visual motifs to be permuted, and words like "dreams" and "hallucinations" obscure what the system does (paraphrase from search results). — [Artnet](https://news.artnet.com/art-world/refik-anadol-unsupervised-moma-2242329)
- Jerry Saltz called it a "glorified lava lamp"; Travis Diehl in the *New York Times* called it "only a screen saver" (as reported). — [Artforum on the acquisition](https://www.artforum.com/news/moma-acquires-refik-anadols-unsupervised-517497/); [Ocula](https://ocula.com/magazine/art-news/to-refik-anadol-criticism-is-just-more-data/)
- Hides: the works, artists and metadata it was made from. The counter-example: a summary of a whole collection that cannot be opened back into a single painting. Useful to define the birdsong work against.

**P8. Jenna Sutela with Memo Akten and Damien Henry — *nimiia cétiï*, 2018 (n-dimensions, Google Arts & Culture residency at Somerset House Studios).** [search-verified]
- What it does: "an audio-visual work … using machine learning to generate a new written and spoken language", from recordings of an invented Martian language and the movements of nattō bacteria. — [A4 listing](https://a4.linkedbyair.net/works/rec0dI6yKdP8d5Ypd-nimiia-cetii?locale=en); [MIT ACT profile](https://act.mit.edu/about/people/jenna-sutela/)
- Reveals/hides: makes the machine a medium for non-human signal and keeps the opacity as the subject. A precedent for work with non-human sound that does not claim to translate.

**P9. Philipp Schmitt — *Declassifier*, 2019–20 (date from memory).** [search-verified from Juxtapoz only; my fetch of the artist's page returned 404]
- What it does: runs an object detector trained on Microsoft's COCO set over his own street photographs and, in place of a box and a label, overlays the training images the label was learned from. — [Juxtapoz](https://www.juxtapoz.com/news/photography/humans-of-ai-philipp-schmitt-s-algorithm-generated-collages/)
- Reveals: the source images behind a label. **The clearest existing example of "opening a summary back into what it was made from."** Worth confirming the artist's own description.

**P10. Adam Harvey & Jules LaPlace — *MegaPixels* (2017–2020) and *Exposing.ai* (launched January 2021).** [search-verified; project About page exists]
- What it does: lets a person search by Flickr username to see whether their photos are in face recognition training sets. "Only datasets that were publicly accessible, include Flickr images, and included metadata are searchable". — [exposing.ai/about](https://exposing.ai/about/); [HfG Karlsruhe](https://kim.hfg-karlsruhe.de/exposing-ai/)
- Reveals: a path from the model back to one person's contribution. Agency in the thesis's sense: you can find yourself in the summary.

**P11. Holly Herndon & Mat Dryhurst (Spawning) — *Have I Been Trained?*, 2022–.** [search-verified from press]
- What it does: searches LAION-5B for your images and records opt-outs; Spawning reported opt-out requests for tens of millions of works, with partial uptake by model makers (Stability AI agreed; LAION had not formally). Some 2026 guides say the public search has been intermittently offline. — [TechCrunch](https://techcrunch.com/2023/05/03/spawning-lays-out-its-plans-for-letting-creators-opt-out-of-generative-ai-training); [Vice](https://www.vice.com/en/article/ai-is-probably-using-your-images-and-its-not-easy-to-opt-out/)
- Reveals: the dataset as searchable; adds a way to act (refuse). Shows the limit too: the opt-out depends on others honouring it.

**P12. Moniker — *Do Not Draw a Penis*, 2018–19, with support from Mozilla.** [search-verified; studio page exists]
- What it does: a drawing site that scolds and erases what Google's Quick, Draw! set left out; Moniker released a dataset of 25,000 such drawings as an "appendix" to Quick, Draw!. — [studiomoniker.com](https://studiomoniker.com/projects/do-not-draw-a-penis); [FlowingData](https://flowingdata.com/2019/07/17/machine-learning-to-erase-penis-drawings)
- Reveals: an omission in a dataset, through play, and repairs it.

**P13. Christo Buschek & Jer Thorp (Knowing Machines) — *Models All The Way Down*, 2024 (the page does not state a year; 2024 is from the brief).** [page read]
- What it does: a scrolling visual investigation of LAION-5B: how it was built from Common Crawl, which thresholds and classifiers filtered it, how its subsets were made. Quotes: "LAION-5B is what we call a 'foundation dataset' for generative artificial intelligence." "It contains less about how humans see the world than it does about how search engines see the world." "LAION-5B is made by measure." — [knowingmachines.org](https://knowingmachines.org/models-all-the-way)
- Reveals: that the dataset is itself the output of earlier models and cut-off scores. Design precedent for explaining a pipeline step by step.

**P14. Tega Brain — *Deep Swamp*, 2018.** [search-verified from NYU]
- What it does: three AI agents ("Harrison, Hans, and Nicholas"), trained on web images, each adjust light, water and fog in a tank of wetland plants toward a different goal: a natural wetland, a work of art, or attention. — [NYU Tandon](https://engineering.nyu.edu/news/professors-work-explores-intersection-ai-and-environment)
- Reveals: the objective. The same living system is managed differently depending on what the model was told to want. Relevant as ML applied to non-human life.

**P15. Joy Buolamwini & Timnit Gebru — *Gender Shades*, 2018.** *Proceedings of the 1st Conference on Fairness, Accountability and Transparency*, PMLR 81: 77–91. [page read]
- What it does: an audit of three commercial gender classifiers. "darker-skinned females are the most misclassified group (with error rates of up to 34.7%)". "The maximum error rate for lighter-skinned males is 0.8%." — [PMLR](https://proceedings.mlr.press/v81/buolamwini18a.html)
- Reveals: what a single accuracy figure hides, by opening it back into subgroups. A summary reopened, with numbers.

**P16. Kate Crawford & Vladan Joler — *Anatomy of an AI System*, 2018** (map and essay; entry 6) and **Matteo Pasquinelli & Vladan Joler — *The Nooscope*, 2020** (diagram; entry 7). [see entries 6 and 7]
- What they do: large diagrams that lay out, respectively, the material supply chain of one voice command and the stages and typical errors of machine learning. — [anatomyof.ai](https://anatomyof.ai/); [Nooscope](https://matteopasquinelli.com/nooscope)
- Reveal: the whole arrangement in one view. A fair criticism to anticipate: a map is also a flattening.

**P17. Explainability interfaces as design: *Distill* (2016–2021) and Google PAIR explorables.** [see entries 13, 15, 16, 17]
- What they do: essays where the reader changes the inputs and settings. Entry 13 lets you move perplexity and watch clusters form and dissolve; entry 16 lets you browse what a vision network responds to. — [How to Use t-SNE Effectively](https://distill.pub/2016/misread-tsne/); [Activation Atlas](https://distill.pub/2019/activation-atlas/); [Understanding UMAP](https://pair-code.github.io/understanding-umap/)
- Reveal: the hidden parameter, by handing it to the reader.

### Inferences
- Four strategies, with the thesis's refinement as the test (can the viewer get from the summary back to its sources?):
  1. **Show the data and labour**: P2, P9, P10, P11, P13. These pass the test most fully.
  2. **Turn the classifier on the viewer**: P3, P6, P12. These make categories felt but do not open them.
  3. **Map the whole system**: P16, P13. These trade one summary for a larger one.
  4. **Hand over the controls**: P17. These show that the picture is one of many.
- Anadol (P7) and Bird Sounds (P1) are the two works to define the birdsong project against: both present the latent map as the thing to look at, and neither offers a way back to the sources' reasons.
- P15 shows the refinement applies to numbers as much as pictures: one accuracy score is a summary, and the audit is the act of opening it.

### Gaps
- **Not verified (search budget ran out); from memory, check before citing:** Everest Pipkin, *Lacework* (2020), made from MIT's Moments in Time video dataset, with the essay "On Lacework: watching an entire machine-learning dataset" (Unthinking Photography); Philipp Schmitt, *Computed Curation* (2017), a photobook sequenced by a model; Herndon & Dryhurst, *xhairymutantx* (Whitney Biennial 2024); Kyle McDonald's *Infinite Drum Machine* (Google AI Experiments, t-SNE map of drum sounds); any Sam Lavigne work on ML specifically; Adam Harvey's earlier *CV Dazzle*.
- Whether Bird Sounds lets a viewer play the source recording for each point (so that the map can be opened back to the item, though not to the reasons) was not confirmed from the page text. I believe it does; check in the live experiment, because it matters to the argument.
- No source found that discusses "aestheticising the latent space" in those words about Anadol. Lossin and Davis are the nearest; Piotr Zawojski's academic article on Anadol's "machine hallucinations" appeared in results but was not read.
- Dates for P9 and P13 are not confirmed on a primary page.

---

## 5. Explainable AI and its critics; contestability; seamful design

### Takeaway
The explainability literature largely agrees that "interpretable" has no single meaning, and that explaining a model after the fact is different from being able to question or challenge it. The contestability and seamful-design papers give the thesis its constructive vocabulary: agency comes from being able to dispute and trace, and from seeing the seams, not from an explanation supplied by the system.

### Cited Findings

**26. Lipton, Zachary C. (2016/2018). "The Mythos of Model Interpretability." arXiv:1606.03490 (ICML 2016 Workshop on Human Interpretability in ML; later in *ACM Queue* / *Communications of the ACM*, 2018).** [arXiv page read; the journal version details are from memory]
- Core claim: "we want models to be not only good, but interpretable", yet the term is ill-defined and claimed without argument. Lipton separates transparency (can a person follow the model?) from post-hoc explanation (a story told afterwards), and questions the assumptions that linear models are interpretable and deep networks are not. — [arXiv](https://arxiv.org/abs/1606.03490)
- Bearing on the thesis: **complicates.** "The black box hides how it clusters" needs to say hidden in which sense and from whom. A post-hoc explanation is another summary.

**27. Rudin, Cynthia (2019). "Stop explaining black box machine learning models for high stakes decisions and use interpretable models instead." *Nature Machine Intelligence* 1: 206–215 (arXiv:1811.10154).** [arXiv page read; journal DOI 10.1038/s42256-019-0048-x from memory]
- Core claim: "Black box machine learning models are currently being used for high stakes decision-making throughout society." Explaining them after the fact "is likely to perpetuate bad practices and can potentially cause catastrophic harm to society." "There is a way forward -- it is to design models that are inherently interpretable." — [arXiv](https://arxiv.org/abs/1811.10154)
- Bearing on the thesis: **supports** the refinement (an explanation of a black box is not the box) and **opposes** any fatalism: for many tasks an openable model exists. Bird ID is not high stakes, so use with care.

**28. Selbst, Andrew D. & Barocas, Solon (2018). "The Intuitive Appeal of Explainable Machines." *Fordham Law Review* 87: 1085.** [search-verified at the Fordham repository and SSRN]
- Core claim: calls for explanation run together two problems: **inscrutability** (the rules cannot be grasped) and **nonintuitiveness** (the rules can be stated but we cannot see why they should hold). The first asks for a description, the second for a justification. Explaining the model is not enough; the process of building it must be documented. — [Fordham Law Review](https://ir.lawnet.fordham.edu/flr/vol87/iss3/11); [SSRN](https://papers.ssrn.com/abstract=3126971)
- Bearing on the thesis: **sharpens.** A cluster of bird sounds may be perfectly describable and still make no sense to a listener. That second problem is the birdsong work's territory.

**29. Miller, Tim (2019). "Explanation in Artificial Intelligence: Insights from the Social Sciences." *Artificial Intelligence* 267: 1–38 (arXiv:1706.07269).** [arXiv page read; journal volume, pages and DOI 10.1016/j.artint.2018.07.007 from memory]
- Core claim: "This paper argues that the field of explainable artificial intelligence should build on this existing research" in philosophy, psychology and social science on how people explain things to each other. (From memory, not from the page: the paper's findings are that human explanations are contrastive, selective and social.) — [arXiv](https://arxiv.org/abs/1706.07269)
- Bearing on the thesis: **complicates.** A good explanation is itself selective. If people want "why this and not that", a design that opens everything may serve them worse than one that answers a contrast.

**30. Kluttz, Daniel N.; Kohli, Nitin & Mulligan, Deirdre K. (2020). "Shaping Our Tools: Contestability as a Means to Promote Responsible Algorithmic Decision Making in the Professions." In Kevin Werbach (ed.), *After the Digital Tornado*, Cambridge University Press, ch. 6, pp. 137–152.** [search-verified at Cambridge Core, SSRN and Berkeley]
- Core claim: contestability, the ability to challenge a system's output, "has distinct advantages over transparency and explainability". Systems designed for it keep professionals actively engaged in the decision. — [Cambridge Core](https://www.cambridge.org/core/product/311281626ECA50F156A1DDAE7A02CECB/core-reader); [SSRN](https://papers.ssrn.com/abstract=3311894)
- Bearing on the thesis: **supports the agency claim and gives it a design goal.** The person keeps agency when they can argue with the output.

**31. Lyons, Henrietta; Velloso, Eduardo & Miller, Tim (2021). "Conceptualising Contestability: Perspectives on Contesting Algorithmic Decisions." *Proceedings of the ACM on Human-Computer Interaction* 5(CSCW1). DOI 10.1145/3449180 (arXiv:2103.01774).** [arXiv page read; venue from the related DOI and memory]
- Core claim: "the ability to contest algorithmic decisions is being recognised as an important safeguard for individuals"; "while the nature of contestability is disputed, it is seen as a way to protect individuals". A companion paper by the same authors, "Fair and Responsible AI: A Focus on the Ability to Contest" (arXiv:2102.10787), notes "there is little guidance on how AI systems can be designed to support contestation." — [arXiv 2103.01774](https://arxiv.org/abs/2103.01774); [arXiv 2102.10787](https://arxiv.org/abs/2102.10787)
- Bearing on the thesis: **supports**, and marks an open design problem the thesis can claim to work on.

**32. Ehsan, Upol & Riedl, Mark O. (2020). "Human-centered Explainable AI: Towards a Reflective Sociotechnical Approach." HCI International 2020 (arXiv:2002.01092).** [arXiv page read]
- Core claim: "we introduce Human-centered Explainable AI (HCXAI) as an approach that puts the human at the center of technology design." Explanation depends on who the person is and their setting; the authors draw on Critical Technical Practice, value-sensitive design and participatory design. — [arXiv](https://arxiv.org/abs/2002.01092)
- Bearing on the thesis: **supports** a design-led, reflective approach over a purely technical one.

**33. Ehsan, Upol; Liao, Q. Vera; Passi, Samir; Riedl, Mark O. & Daumé III, Hal (2024). "Seamful XAI: Operationalizing Seamful Design in Explainable AI." *Proceedings of the ACM on Human-Computer Interaction* 8(CSCW1). DOI 10.1145/3637396 (arXiv:2211.06753).** [arXiv page read]
- Core claim: "Mistakes in AI systems are inevitable, arising from both technical limitations and sociotechnical gaps." Hiding them leaves users unable to respond. The authors propose revealing "seams" (mismatches across the AI lifecycle) and test a design process with 43 practitioners and end users, who became better at foreseeing harms, locating their causes and using that to improve explainability and user agency. — [arXiv](https://arxiv.org/abs/2211.06753); [ACM DOI](https://doi.org/10.1145/3637396)
- Bearing on the thesis: **the closest design-research ally.** "Seam" is a usable word for the point where a summary can be opened. It also ties explainability to agency in so many words.

### Inferences
- The thesis can borrow a three-step position from this section: explanation is not one thing (26, 28); explanations supplied by the system are further summaries (27, 29); what protects the person is the ability to contest and to see seams (30, 31, 33). This matches the refinement better than a call for transparency.
- A contestable bird ID would let the listener say "no, that is not what I heard" and see what the alternatives were. None of the bird sources in section 3 describes such a feature; that absence is an inference from what I read, not a cited finding.

### Gaps
- Journal details for Lipton (*Queue* / *CACM* 2018), Rudin (DOI), Miller (volume, pages, DOI) and Ehsan & Riedl (Springer proceedings DOI) come from memory; the arXiv pages confirm authors, titles and abstracts only.
- I did not read the full text of any paper in this section; quotes are from abstracts.
- Mechanistic interpretability after 2020 (circuits, sparse autoencoders, "features") was on the brief under Olah et al. and was not researched beyond entries 16 and 17.

---

## 6. Counter-arguments the thesis must answer

### Takeaway
Four objections have published support: looking inside does not give understanding or power; explanations can raise trust without raising correctness; a 2D map can be a useful tool and embeddings keep more than they show; and the black box sometimes gives access or protection to the person. The refined thesis survives all four if it claims "there should be a way back to the sources", and fails if it claims "show everything".

### Cited Findings

**34. Kaur, Harmanpreet; Nori, Harsha; Jenkins, Samuel; Caruana, Rich; Wallach, Hanna & Wortman Vaughan, Jennifer (2020). "Interpreting Interpretability: Understanding Data Scientists' Use of Interpretability Tools for Machine Learning." CHI 2020. DOI 10.1145/3313831.3376219.** [search-verified at Microsoft Research and the author's PDF]
- Core claim: from a contextual inquiry (N=11) and a survey (N=197): "Our results indicate that data scientists over-trust and misuse interpretability tools. Furthermore, few of our participants were able to accurately describe the visualizations output by these tools." — [Microsoft Research](https://www.microsoft.com/en-us/research/publication/interpreting-interpretability-understanding-data-scientists-use-of-interpretability-tools-for-machine-learning/); [PDF](https://www.jennwv.com/papers/interp-ds.pdf)
- Bearing on the thesis: **opposes a naive version.** Even experts treat an explanation picture as reassurance. Opening the box with a visual can produce false confidence.

**35. Bansal, Gagan; Wu, Tongshuang; Zhou, Joyce; Fok, Raymond; Nushi, Besmira; Kamar, Ece; Ribeiro, Marco Tulio & Weld, Daniel S. (2021). "Does the Whole Exceed its Parts? The Effect of AI Explanations on Complementary Team Performance." CHI 2021 (arXiv:2006.14779).** [arXiv page read; ACM DOI 10.1145/3411764.3445717 from memory]
- Core claim: "While we observed complementary improvements from AI augmentation, they were not increased by explanations." "Rather, explanations increased the chance that humans will accept the AI's recommendation, regardless of its correctness." — [arXiv](https://arxiv.org/abs/2006.14779)
- Bearing on the thesis: **opposes.** Explanation can reduce agency by making people defer more. A defence should have an answer: the birdsong work is not an explanation that asks for trust but a way of showing what the summary left out.

**Transparency does not equal accountability** — Ananny & Crawford (entry 2): seeing is assumed to create the power to change, and often does not. — [DOI](https://doi.org/10.1177/1461444816676645)

**The box is partly made by how we look at it** — Seaver (entry 3): auditing "enacts an understanding of algorithms as black boxes". — [DOI](https://doi.org/10.1177/2053951717738104)

**All accounts are partial** — Amoore (entry 8): partiality and opacity "haunt both human and algorithmic decisions". — [Duke UP](https://www.dukeupress.edu/cloud-ethics)

**Demanding intuitive rules has a cost** — Selbst & Barocas (entry 28) warn, per the search summary of the article, that requiring models to be intuitive could lose discoveries, including ones that reduce bias. — [Fordham Law Review](https://ir.lawnet.fordham.edu/flr/vol87/iss3/11)

**The summary keeps more than it shows** — Ghani et al. (entry 20): bird-classifier embeddings transfer to other bioacoustic tasks with few examples. — [arXiv](https://arxiv.org/abs/2307.06292)

**The explanation tools flatten too** — Carter et al. (entry 16): the atlas is built by 2D projection and averaging and is "dependent on the distribution of the data we choose to sample". — [Distill](https://distill.pub/2019/activation-atlas/)

**The black box gives access** — a birding blog notes Sound ID lets "birds … be enjoyed even if an observer has difficulty in seeing the birds"; Sterne & Sawhney (entry 24) grant that machine listening is promoted "in the name of utility, inclusiveness, and access" while arguing it also serves data ownership. A forum user reported that running Merlin in the background "brought my aural birding on much more quickly". — [Colby, Maine Birds](https://web.colby.edu/mainebirds/2022/09/11/merlin-and-the-use-of-artificial-intelligence-in-bird-identification/); [Kalfou](https://tupjournals.temple.edu/index.php/kalfou/article/view/617); [BirdForum](https://www.birdforum.net/threads/started-using-merlins-sound-id-holy-smokes-its-a-game-changer.462195/)

**Exposure can work** — after *ImageNet Roulette*, ImageNet announced removal of 438 people categories and 600,040 images (P3). — [The Art Newspaper](https://www.theartnewspaper.com/2019/09/23/leading-online-database-to-remove-600000-images-after-art-project-reveals-its-racist-bias)

### Inferences
- "Takes agency from the person" is the weakest link empirically. The bird-app evidence found here is mixed: some users say the app speeds their learning, some say it blocks it, and one field study shows trained humans still outperform it (entry 21). None of this is a controlled study of skill. The thesis should present the agency claim as an argument about what the interface allows (no way to question, trace or see alternatives), not as a measured effect on people.
- A defensible form of the thesis after these objections: *the harm is not that a summary exists, or that its inner working is hard to follow, but that the person is given the summary with no route back to what it was made from and no way to dispute it.* Entries 2, 30, 31 and 33 support that form; entries 34 and 35 warn against solving it with an explanation panel.
- "Opacity is sometimes protective" (for example, not disclosing a model so it cannot be gamed, or not exposing people in a dataset) was on the brief. I found no source for it this session beyond Ananny & Crawford's general point that transparency can harm; treat it as unsupported here.

### Gaps
- No source verified for the claim that opacity protects (privacy of data subjects, resistance to gaming). Ananny & Crawford's ten limits likely include this, but I could not open the text to confirm.
- No controlled study found of whether species ID apps build or erode listening skill.
- Replies defending UMAP and t-SNE as exploratory tools (the main technical counter-argument to entry 14) were not searched.
- The web search budget for the session was exhausted during the final round; six planned checks (Sterne's "Is Machine Listening Listening?", Pipkin's *Lacework*, Stowell's review, *xhairymutantx*, Chun's *Discriminating Data*, Schmitt's own *Declassifier* page) did not run.

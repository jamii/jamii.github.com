---
layout: post
title: 'Notes on ''PSYCGD02: Principles of Cognition'''
hidden: true
---

<https://www.ucl.ac.uk/lifesciences-faculty-php/courses/viewcourse.php?coursecode=PSYCGD02>

>  This module outlines general theoretical principles that underlie cognitive processes across many domains, ranging from perception to language, to reasoning and decision making. The focus will be on general, quantitative regularities, and the degree to which theories focusing on specific cognitive scientific topics can be constrained by such principles. There will be an introduction on general methods and approaches in cognitive science and some of the problems related to them. Later in the course, some computational approaches in cognitive science will be discussed. There will be particular emphasis on understanding cognitive principles that are relevant to theories of decision making.  

## [What is Cognitive Science?](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.645.8834&rep=rep1&type=pdf)

Brief history. 

Notable that the narrative revolves around several key conferences where prominent figures from different fields became aligned.

## [Bridging Levels of Analysis for Probabilistic Models of Cognition](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.704.2311&rep=rep1&type=pdf)

Levels of models:

* Computational - problem and declarative solution eg Bayesian inference
* Algorithmic - representation and constructive solution eg message passing
* Implementation - physical processes eg neurons

Popular research method is to look at where people diverge from ideal solutions, to figure out what algorithms their mind is using to approximate the solution. But..
.
* Vulnerable to misidentifying the computational problem being solved.
  * eg strategies for iterated PD look irrational in single PD
* Requires understanding how levels constrain each other
  * eg are probalistic models fundamentally incompatible with connectionist models or can we implement one on top of the other?

Rational process models - identify algorithm for approximating probabilistic inference under time/space limits, compare to what we know about mind and behavior.

* Bridges computational and algorithmic levels.
* Constrains possible algorithms to those that produce ideal behavior in limit.
* Explains many cases where individuals deviate but average behavior is close to ideal.

Example - Monte Carlo with small number of samples is tractable. Consistent with:

* Averaging multiple guesses from one person increases accuracy (ie contains some independent error)
* Recall similar events ~= importance sampling. __Predicts availability bias? Incorrect re-weighting?__
* Order effects (order of information incorrectly affects results of update) ~= particle filter.
* Perceptual bistability ~= random walk. 

Some progress in bridging to implementation level eg neural models of importance sampling.

## [Lecture 1](https://moodle.ucl.ac.uk/pluginfile.php/4302613/mod_resource/content/2/Lecture%201.pdf)

Cognitive science as reverse engineering - understand how the mind works by trying to build one and see what differs.

Brief history:

* Structuralism
  * Building blocks are qualia
  * Learning via systematic introspection
    * Controlled, replicable experiments
    * But different labs struggled to replicate each others results
    * Difficult to relate conscious experiences which don't match qualia (eg non-visual mental models)
    * Vulnerable to observer effects, confirmation, priming, retroactive justification
    * Introspection actually = retrospection
    * eg visual illusions, choice blindness
* Behaviorism
  * Only talk about observable stimulus and response
  * Mostly experiments with animal learning
  * eg classic conditioning (event -> event -> response => event -> ... -> response)
  * eg operant conditioning (action -> +/- => +/- action)
  * Reinforcement machines, not reasoning machines
  * Doesn't allow internal state/structure
    * Doesn't explain how stimulus/response are categorized - theoryless learning
    * But language has infinite structure => can't be learned from stimulus/response without hyperpriors
    * Rats choose shorted route available, rather than most reinforced route
* Cognitive science
  * Thought as computation / information processing - data + algorithms
  * __We needed to invent computation first to be able to have this idea!__
  
Methods: 
  
* Behavioral studies
* Lesion studies
* Single-cell recordings
* fMRI
  * Neural activity -> blood de-oxygenation -> magnetic interaction changes -> measure with big magnets
  * Spatial resolution ~1mm
  * Temporal resolution ~seconds
* EEG
  * Neural activity -> electromagnetic field -> measure with electrodes on scalp
  * Can only measure large fields
  * Spatial resolution ~poor
  * Temporal resolution ~1ms
* MEG
  * Neural activity -> electromagnetic field -> measure with ?
  * Spatial resolution ~better
  * Temporal resolution ~1ms
* tDCS

Review:

* Recount three main periods of history.
* Explain levels of models, with examples.

## [Automaticity of Social Behavior: Direct Effects of Trait Construct and Stereotype Activation on Action](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.333.7523&rep=rep1&type=pdf)

(Paired with the more recent failed replication.)

Arguing that non-conscious priming can strongly affect behavior.

Experiment 1:

* 34 undergrads
* Use scrambled sentence test with words that prime rude/polite/neutral
* All experimenters blinded
* Sent to another room for next test, where waiting confederate is asking experimenter questions
* Time how long it takes them to interrupt
* Huge effect sizes: almost 2x mean time, <20% vs >60% interruptions within 10min cutoff
* No significant differences in reported perceptions of experimenters politeness
* __Should we trust reports of politeness? It's a bad idea to call your professor rude!__
* __Effect sizes are enormous. If a few words can double impatience, what could listening to angry music on the journey do? If we're so strongly susceptible to small influences, how is there room for personality? How do we have any resistance to marketing?__

Experiment 2:

* Two successful iterations!
* 30 + 30 undergrads
* Same setup, but priming elderly/neutral (without priming slow)
* Timed how long subjects took to walk to the next room
* Much smaller effect size - mean 7.30s -> 8.28s
* __Near identical results in both iterations!__
* __Elderly -> slow? I get thinking about rudeness making me rude, but thinking about elderly making me slow seems a much bigger stretch. Thinking about predators makes me want to eat meat? Being chased by a tiger and stop for a steak sandwich?__
* Followup experiment with 19 undergrads found only 1 noticed the elderly priming

* 33 undergrads
* Do elderly priming, then Affect-Arousal Scale
* Primed group were in slightly more positive mood, but not significantly
* __Uses this to defend against the idea that they walked slower because sad, but seems bizarre that they are affected so much that they move differently but not so much that they feel differently.__

Experiment 3:

* 41 non-African-American undergrads
* Long boring computer task. 
* Flash either African-American or Caucasian face before each trial. 
* On 130th claim error and say they have to start again. Experimenter explains error, but is blinded.
* Facial expression caught by camera and rated by blinded experimenter.
* Only two subjects reported seeing the faces when asked and couldn't identify which they saw
* __Both experimenter in room and raters of pictures gave near-identical results!__
* But no difference in self-reported racial prejudice.

Argues that this works where subliminal adverts for pepsi don't because they directly activate traits which contain behavior whereas pepsi just activates the pepsi representation. __So elderly -> walk slow but pepsi -/> drink pepsi?__ Also because there is some activation energy to get up and buy coke, whereas they setup situations where the action was already required and the only difference was in accessibility. So priming for hostility will make people more likely to react to an annoying trigger but not to be randomly hostile.

Note that results for behavior here are stronger than their previous results for judgments, but would assume that judgments mediate behavior. But in ex1 there was no effect on perception of the experimenter. And little evidence so far for judgment mediating behavior.

## [Behavioral Priming: It’s all in the Mind, but Whose Mind?](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0029081)

Failed replication of previous paper.

Reasons to doubt original:

* Only two indirect replications.
* Small sample sizes.
* Evidence from neuroscience suggests that top-down attention and bottom-up saliency are both required for the spreading activations that are used to explain priming. 
* Experimenter who administered the task was not blinded enough - authors found that it was easy to accidentally glimpse the task sheet (__original describes them as being in a closed envelope?__)
* Measuring time with a stopwatch is susceptible to bias
* Not clear exactly what participants where asked afterwards - aware of stimulus vs aware of response vs aware of link.

Experiment 1:

* 120 (French) undergrads
* Task sheets in a closed envelope, opened by subjects
* Experimenters assigned to subjects are random
* Experimenters follow a strict script
* Walking speed recorded by infrared beam
* No significant difference in walking times
* Four students reported being aware of the elderly-ness
* Primed group chose pictures of old people significantly more often in forced choice test
* No experimenters reported having any specific expectations about subject behavior

Experiment 2:

* 50 subjects, 10 experimenters
* Half of experimenters told that primed participants will walk slower, other half told faster
* Experimenters were unblinded
* First subject for each experimenter was a confederate who behaved to confirm this expectation
* Experimenters measured with stopwatch
* For stopwatch times, fast+prime went faster and slow+prime went slower.
* For infrared times, slow+prime went slightly slower and fast+prime was same as fast+control.

Most subjects were aware of the prime (__but it said 6%...__) and are in psych course so might be expected to be suspicious. 

__Priming via social cues is way more believable to me than priming via word choice. Clear selective pressure for understanding and reacting to social cues.__

## [Lecture 2](https://moodle.ucl.ac.uk/pluginfile.php/3694895/mod_resource/content/3/Scientific Reasoning.pdf)

Scientific reasoning. Psi hypothesis as running example.

Base-rate fallacy vs significance testing.

Successful replication could just mean replicating the mistakes of the original.

In a replication aim to improve on original methods or test some new factor - more likely to be received in good faith and more likely to generate new insight beyond back-and-forth.

A good successfully replication can falsify a hypothesis by more accurately identifying the mechanism behind the effect eg previous paper replicated slow walking, but showed that the effect disappeared under proper blinding.

Defenses of priming:

* Hidden moderators
* Experienced researchers

But:

* Then the original effect is less powerful/robust than claimed 
* Post-hoc reasoning - just a hypothesis until tested
* Administering questionnaires is not that hard
* Most of the legwork is done by grad students anyway

Try to structure experiments with multiple competing hypotheses where any given result would support some hypothesis and weaken the others.

Review:

* What should an ideal replication aim to do?

## [The Cognitive Neuroscience of Human Memory Since H.M.](https://pdfs.semanticscholar.org/981b/7074fcb20d0b1366c7a0d2660085ddbcf465.pdf)

Intro:

* Current categories used in memory took time to establish - non-obvious.
* Specific impairments from lesions rather than general degradation shows that brain is structured and specialized.

Hippocampus:

* Hippocampal volume reduction of ~40% is common in memory-impaired patients - may be maximum cell loss ie 60% remaining is just dead tissue.
* Damage to other regions can also impair memory.

HM:

* Learned a motor skill => memory not one single unit
* Reasoning and perception intact => memory not required for reasoning/perception
* Could sustain attention and had short-term recall => damaged ares not required for working memory
* Had memories from before surgery => long-term storage not in damaged areas

Other patients:

* Perceptual priming still works
* Can learn in Bayesian fashion, but not explicit memorization
* Learned skills are rigid, fail if task is modified

Declarative: facts, representations, conscious recall, compare/contrast memories
Non-declarative memory: unconscious performance, black box

Visual perception:

* Initially thought to require memory in some cases, but...
* Tests accidentally benefit from memory
* Often damage to adjacent vision-processing areas
* Requires better imaging/locating of lesions to clear up confusion
  
Immediate and working memory:

* HM limited to 6 digit recall, but could maintain memory for 15 mins
* => Immediate memory not time-limited, but maintenance-limited
* Demonstrated in other patients - they do fine on tasks where distractions impair healthy subjects (working memory) but fail on tasks where distractions are fine for healthy subjects (long-term memory)
* Open question - are there tasks that can be handled by working memory but are still impaired by hippocampus damage
  * Debate around path integration - unclear whether subjects are each using same process and representation

Remote memory:

* HM initially had autobiographical memory
* (Later in life was limited to factual recall, but later MRIs also showed changes since initial event)
* Many other patients also have autobiographical memory.
* In patients without, often unclear how far damage extends and whether it might affect other areas

Working theory of long-term memory::

* Medial temporal lobes deal with creating and maintaining declarative memories
* Sensory memories stored in same area that initially processed them
  * Supported by many individual patients eg 'colorblind painter' - after damage that removed color perception, could no longer remember colors except declaratively
* Recall consists of tying all of these together
  * Supported by various fMRI studies
* Initially requires hippocampus, but over years memories reorganized, stored more permanently by changes across neocortex that tie these areas together

Structure::

* Working theory - organized by semantic categories
  * eg JBR lost memory of things identified by attributes but not things identified by function
* Recollection = what was in specific memory?
* Familiarity = was prompt in any memory?
* Hippocampus damaged patients are impaired on both old/new task (familiarity + some recollection) and free recall (recollection)
* Combine old/new with recall of which source - patients have less instances of familiarity without recall => damage is not recall only

Group studies average out individual variation - allows studying less obvious effects

## [Finding the engram](https://pdfs.semanticscholar.org/2696/57152b4666ebd489ee54c2ab17534bb72496.pdf)

Engram def=

* Persistance - persistent physical change in brain resulting from specific experience
* Ecphory - automatic retrieval in presence of cue
* Content - reflects what happened and what can be retrived
* Dormancy - exists (but dormant) even when encoding and retrieval not active

The hunt:

* Moving target eg reconsolidation
* Many learning-related changes observed in brain eg synaptic, chemical, epigenetic. 
* Different persistence periods. 
* Not clear if related to engrams.
* Often don't predict retrieval success.
* Dominant theory - stronger connections between neurons that are active during encoding - neuronal ensemble

Sharp-wave ripple events in hippocampus:

* Multi-unit recordings in rodents, fMRI in humans
* Replay observed during tasks, resting and sleeping
* Strength of replay correlates with later retrieval performance
* Disrupting waves impairs subsequent expression
* Some progress on correlating content
* Related sensory cues may trigger replay
* Hard to observe dormancy

Tracking: 

* Non-specific lesions only caused retrieval failure when wide areas damaged => memories are distributed
  * But overtrained rats => resilient memories
  * But may have accidentally damaged hippocampus with large lesions
* Would like to lesion specific ensembles
* Tagging shows that some same neurons active during both encoding and retrieval (~10%, >chance, possibly collateral tagging during encoding)
* Neurons with higher levels of CREB are more often recruited into ensemble
* Neurons with virally over-expressed CREB are more often recruited into ensemble
* More CREB -> more excitable
* Increasing excitability via various other methods also has same effect
* Allocate-and-erase - ablating (__killing?__) artificially excitable neurons reduces retrieval performance without affecting future learning 
  * Even if only one brain region is targeted => some parts of ensemble have key roles
* Tag-and-erase - tag active neurons, apply inhibitors (__how are these targeted?__), same effect
* Worries about collateral tagging resolved:
  * Tag 1st experience
  * Silence during 2nd 
  * 2nd still learned but 1st is gone => not enough collateral tagging to interfere with 2nd task

Activating:

* Uncontrolled experiments with focal electrical stimulation during surgery
* Tag-and-manipulate / allocate-and-manipulate - re-triggers learned behavior even in unrelated contexts
* In both cases, activation seems to spread from initial site to entire ensemble
* Can create false associations:
  * Tag ensemble in context 1
  * Activate in context 2 and shock mice
  * Learned fear response in context 1
  * No fear response in context 2
* Even indirectly
  * Tag ensemble in context 1
  * Tag ensemble during shock
  * Repeatedly active both in context 2
  * Learned fear response in context 2
  * No fear response in context 1
* Artificial activation paired with chemical that inhibits reconsolidation removes association
* So far stimuli limited to fear/reward and response limited to freeze/approach/avoid - need more complex tasks to test episodic memory

## [Memory, navigation and theta rhythm in the hippocampal-entorhinal system](https://pdfs.semanticscholar.org/d18c/c66f7f87e041dec544a0b843496085ab54e1.pdf)

__Having a lot of trouble with this paper. Needs much more time and depth.__

Navigation:

* Allocentric / map-based navigation - static representation, navigate by external landmarks
* Egocentric navigation / path integration - track motion, estimate path from origin
* Hippocampus and entorhinal cortex support both declarative memory and navigation
* Semantic memory (data independent of temporal context) ~ allocentric navigation
* Episodic memory (first-person experiences in context) ~ egocentric navigation
* Semantic memory abstracts repeated patterns in episodic memory ~ allocentric maps abstract repeated paths and observations

Implementation possibilities:

* Place cells in hippocampus - fire at specific locations in space - possibly encode position or distance?
* Grid cells in medial entorhinal cortex - fire in repeating hexagonal pattern in space - different scales - possibly coordinate system?
* Head direction cells - ?
* Border cells - ?
* __This is too complicated to skim__
* Firing patterns are not simple - small changes in environment can result in large change in firing patterns - provides high-dimensional code for storing many different envs?

* Insects manage to navigate with much simpler circuits / less storage. 
* Massive excess capacity in mammals might be related to reuse for different kinds of memory.
* Might also enable 'maps' of semantic knowledge
* __cf spatial metaphors in language__
* Recognition and recall associated with unique firing patterns in that area for each object/event

* If episodic memories are stored similarly to paths through environment, might explain time-asymmetry and temporal contiguity (recalling one events makes it easier to recall other events that are nearby in time)

* 
Neuronal assembly sequences:

* __Patterns of activation in time?__
* Generated continuously even when environment and body signals are kept constant
* Can predict correct/incorrect moves in maze seconds before motor event
* Maybe used to organize episodic memory
* Are chunked, just like paths and memory
  * Limits error in long sequences
  * __Is chunking like a hash tree?__

__Some complex ideas about implementation in theta waves that I can't follow, but apparently explains:__

* Fine resolution near recalled event/location, coarse structure elsewhere
* Limited number of concurrently recalled events/locations
* Long-distance jumps between events/locations (__related to chunking?__)
* Compressed recall eg episodic recall tends to focus around highlights/lowlights rather than being linear in time
* Why episodic recall plays out in real-time - tied to same mechanism that implements subjective time tracking

__Maybe this explains why word-vec works? Are we just reverse-engineering the minds spatial relationships?__

Questions:

* Encoding/meaning of firing patterns
* Other animals have similar cells but that are not theta modulated - do they have some substitute system?
* What does the representation space look like (size, layout)?
* How does the cell layout vary between rodents and primates? Do some areas grow out of proportion?
* ?
* Does awareness of recollections require only the prefontal cortex, or also interaction with the rest of the cerebral cortex.

[The role of the hippocampus in navigation is memory](http://sci-hub.cc/10.1152/jn.00005.2017)

Place cells, grid cells etc seem to imply that the hippocampus provides navigation. Paper argues that the evidence actually shows that it provides general cognitive maps and that navigation is just one usecase.

Navigation strategies:

* Search
  * No active goal orientation
  * Just movement and goal recognition
* Target approaching
  * Orienting towards observable goal
* Guidance
  * Towards pre-calculated goal location
  * eg defined by relationship between multiple landmarks
  * Requires some spatial computation, and thereafter is just target approaching
* Wayfinding
  * Recognizing and approaching landmarks
  * Joining landmarks into route
  * Joining routes together into topological map
* Survey / metric navigation
  * Embed known routes/maps into common frame of reference
  * Supports novel routes, detours, shortcuts
  
Rats with hippocampal lesions:

* Can handle route navigation (eg turn left a T) - presumably recognition-triggered
* Can handle alternating routes - again presumably recognition-triggered - but not if delays are inserted
* Can handle guidance navigation with single route (eg water maze task - memorizing location of invisible platform relative to objects on wall - same starting point)
* Can't handle guidance navigation with multiple routes (eg water maze task with different starting points)
* Can't handle survey navigation (eg maze rotated after learning)
* May or may not be able to handle path integration
  * (and both rats and humans suck at it anyway)
  * In one experiment, humans could but rats couldn't
  * In another, rats were impaired even when visual cues existed => maybe the problem is forgetting where the goal is
  * Recording studies haven't found compelling evidence of hippocampal neurons involved in path integration
  * Grid cell firing patterns degrade in the dark => they don't work well with path integration alone
  
Humans with hippocampal lesions:

* Can navigate by reading a map
* Can handle guidance navigation and path integration, so long as fits in working memory
* Can describe routes in areas they knew before damage

Working theory: 

* Hippocampus is required for survey navigation.
* But survey navigation is sometimes used even when lower-level strategies would suffice, explaining failures on simpler tasks
  * eg when foraging for food in open field, see firing patterns in grid cells et al, see place cells fire in sequence when navigating to regular food drops, seee map updates when goal locations change
  * eg when disoriented animals reorient, they use local geometry even if prominent landmark is available
* Hippocampus probably not required for path integration, except to remember starting point and goal

Evidence that different spatial mappings are used for different tasks within the same environment.

Hippocampus maps abstract spaces:

* Rats with lesions can learn direct SR but not transitive
* Humans with lesions have higher deficits for order of events than for direct recall
* Rats with lesions can recognize odors but not recall order in which they were presented
* Interesting signals in human brains when presented with social or associative problems
* Similarly to in spatial tasks, some memory tasks engage hippocampal relational processing even when not required (__this paragraph seems to contradict itself?__)

Imaging suggests that hippocampus is not continuously involved when using cognitive maps in navigation, but only when learning or when planning/altering routes.

Speculation that hippocampus originally evolved for navigation but was co-opted for abstract relationships. (__How does hippocampus size vary across species?__).

## [Lecture 3](https://moodle.ucl.ac.uk/pluginfile.php/4345907/mod_resource/content/5/Memory%20and%20Navigation.pdf)

Divide into declarative vs non-declarative memory no longer seems to be carving at the joints:

* HM couldn't learn maze routes but could learn mirror drawing.
* House task - recall vs recognition of complex spatial arrangements (front doors and porches). Suddenly recall tanks for patients.
* Patients impaired at statistical learning of relationships and associations.
* Mountain task - normal when matching color/time-of-day but impaired when matching arrangement/rotation.
* Lesioned rats can detect novel objects and novel placements but can't pair placement with background context.

Pattern separator vs pattern completer. 

* Old/new task -> old/similar/new task. 
* Old people struggle at pattern separation (old vs similar). 
* CA1 responds to any difference, CA3/DG responds to degree of difference.

Patients learn facts at school, have high IQ and get good grades.

Use fMRI to detect 60% periodicity in humans when navigating => grid cells. Periodicity correlates with success on spatial memory task.

Experiment suggesting that periodicity can be observed even for abstract spaces, by pairing a coordinate system with bird pictures of varying neck and leg length.

Something analogous to space cells for time observed in rats.

__TODO figure out review__

## [Uniting the Tribes of Fluency to Form a Metacognitive Nation](https://web.princeton.edu/sites/opplab/papers/alteropp09.pdf)

Theory: the difficulty of a cognitive task (from fluent to non-fluent) is used as a meta-cognitive cue that feeds into other judgments via 'naive theories' aka heuristics.

Fluency:

* Perceptual
  * Physical eg illegible text, varying contrast
  * Temporal eg briefly flashed images
* Memory
  * Retrieval eg availability heuristic
  * Encoding eg memorization techniques
* Embodied (__not connected to judgments by the references here__)
  * Facial expressions eg smiling in math class
  * Body feedback eg mirror writing 
* Linguistic
  * Phonological eg pronounceable vs unpronounceable letter strings
  * Lexical eg familiar vs unfamiliar synonyms
  * Syntactic eg sentence tree structure
  * Orthographic eg using other alphabets, 12% vs twelve percent (__reading latex?__)
* Conceptual eg priming with structurally similar explanations, semantic coherence
* Spatial reasoning eg rotating shapes (__not connected to judgments by the references here__)
* Imagery eg imagining hypothetical scenarios
* Decision eg jam choices 

Judgments:

* Truth
* Liking
* Confidence

Discounting - if fluency is recognized, subject corrects and may even over-correct.

__Seems like discounting provides a lot of adjustment room in this theory. How to falsify? Could try varying eg legibility over a wide scale and looking for a discounting effect.__

## [Lecture 4](https://moodle.ucl.ac.uk/pluginfile.php/3716951/mod_resource/content/3/Mental%20construction%20slides.pdf)

Fluency can induce:

* familiarity 
* likability
* dis-likability (but not replicated).
* perception of light or darker image (but not replicated)
* judgments of fame (abolished by eating popcorn)
* judgments of danger (abolished by eating popcorn)
* volume of background noise

Familiarity seems like a reasonable heuristic - exposure => fluency, so assume fluency => exposure. 

Explanation for the popcorn is that it prevents subvocalisation so can't judge pronunciation fluency of words.

Others make less sense to me.

__Notable that the class was typically split when asked to predict outcome of experiments ie proposed mechanism is so vague that either outcome is plausible.__

Other 'constructs':

* Subjects reconstruct past to create useful narratives
* Subjects claim even under strong pressure to remember seeing events that only their partner saw
* Subjects remember seeing words when only related words were present

__Not worth reviewing, not confident in results.__

## [Understanding face recognition](http://www.psicologia1.uniroma1.it/repository/13/Bruce_1986_copia.pdf)

Broad view of facial recognition, including processes like retrieving information about the faces owner.

What information might components of facial recognition produce?

* Pictorial - when viewing static photo, reconstruct some 3d representation after correcting for lighting, grain etc
* Structural - angle/lighting/expression -invariant model of face shape/structure usable for recognition
  * Identifiable from low-res photos and caricatures
  * Pictorial vs structural - recognition of photos of strangers faces is impaired by changing angle/lighting => structural representation takes time to build up.
  * Recognition of familiar faces is less impaired by changes to external features => over long-term representation picks up on more unchangeable details eg feature arrangement vs hair color
  * Recognition from restricted (eg just eyes) and occluded (eg wearing sunglasses) views => heavy redundancy in structural code
* Visually-derived semantic eg age, gender, similar faces
* Identity-specific semantic eg occupation, friends
  * Slower than recognition alone
* Name
  * Separated from identity-specific because it is sometimes uniquely effected by injury
  * Often get familiarity without identity, or identity without name. But name without identity would be surprising.
  * Usually try to get name by searching for further identity details, suggests it's attached to identity rather than directly to structural info.
  * Slower than identity-specific semantic alone
* Expression 
* Facial speech - everyone lip-reads a little.
  * Separated from recognition by injury in both directions

Open questions:

* Finer-grained breakdown of cognitive processes involved.
* Do we decide that something is a face and then apply facial recognition or vice versa?
* How is contextual information included? eg not recognizing someone because you didn't expect to see them in that place

## [Are faces special?](https://books.google.co.uk/books?hl=en&lr=&id=2UXx9rdfriQC&oi=fnd&pg=PA149&dq=are+faces+special+robbins&ots=ZEbAtY5Ght&sig=z7wEOT3Omef6RZ062zSTTPp5nI4#v=onepage&q=are%20faces%20special%20robbins&f=false)

Are there dedicated cognitive process for facial processing, or do we just reuse generic object recognition?

Main arguments:

* Face-directed activity in infants => innate
* Holistic recognition only occurs for faces, not other objects
* There are face-specific neural representations

Main challenges

* Most experiments test within-class discrimination for faces vs between-class discrimination for objects - may be different processes
* Expertise hypothesis - maybe similar results for any class that is well practiced eg dog judge recognizing different dogs

Innate:

* Newborn babies can distinguish similar faces even after changing hair and viewpoint
* Same for young monkeys with no previous exposure to faces
* But only for upright faces
* Perceptual narrowing to faces of familiar races occurs

Holistic/configural processing vs within-class discrimination:

* Inversion effects much stronger for faces than within other classes
* Inversion effects occur for ambiguous patterns that are primed as faces, but not if primed as characters
* Part-whole effect - much better recognition for face parts when presented in a face vs alone, not for objects
* Composite effect - much worse recognition for top half with non-matching bottom half than top half alone, not for objects
* Inversion effects for objects disappear with repeated trials, but not for faces.

Neural:

* Monkeys and humans show face-selective cells in large clusters
* Can be disrupted with TMS
* Face and object discrimination can be separated by injury
* FFA is strongly activated by face tasks but (usually) not by object tasks

Expertise:

* No holistic effects found in object experts (eg radiologists, ornithologists)

Argument that too many studies rely on significant vs not-significant, rather than testing interactions.

## [Lecture 5](https://moodle.ucl.ac.uk/pluginfile.php/3737861/mod_resource/content/2/UCL_CoDeS_FacePerception.pdf)

Are faces special?

* Functional specificity - specialized mechanisms
* Neural specificity - implemented in face-selective areas/neurons/cells
* Holistic - face is not represented as collection of parts, but as single object. (__Tricky to pin down - makes more sense relative to later experiments.__)
* Configural - face representation depends on spatial configuration of features, not just features alone

Face recognition could be:

* Domain-general object recognition (item-level hypothesis)
* Domain-specific object recognition (eg expertise hypothesis)
* Face-specific (face-specificity hypothesis)
* Some mixture of the above

Behavioral experiments:

* Have to separate 'face' from 'low-level details that happen to occur in faces' - inverted faces are good control
* Face inversion effect - face recognition impaired much more by inversion than other expert objects
  * But much more expert in faces than anything else
  * Experiments testing correlation between degree of expertise and inversion effect have mixed results - still unsettled
* Face-composite effect - easier to tell if top halves of faces are different when bottom halves are misaligned
* Part-whole effect - easier to discriminate features in context of whole face, rather than alone
* (__Face-composite and part-whole seem directly opposed?__)
* Both effects much stronger for faces vs objects of expertise
* Measures of degree of holistic processing? Comparing strengths of effects within subjects:
  * Inversion ~ part-whole = 0.28
  * Inversion ~ composite = -0.03
  * Part-whole ~ composite = 0.05
  * Inversion ~ face recognition = 0.42
  * Part-whole ~ face recognition = 0.25
  * Composite ~ face recognition = 0.04
  * Would expect strong correlations all round

Neural experiments:

* In FMRI, FFA reacts more strongly to faces vs objects
* Low-level features? Faces vs scrambled faces.
* Item-level recognition? Faces vs houses/porches.
* Animate objects? Faces vs hands.
* But stronger response for inverted faces. 
  * __More processing for triggered-but-failed recognition?__
* Similar results for other objects categories in other areas - indicates other specificities?
  * Places
  * Visual words
  * Bodies
  * Other peoples thoughts
* Similar results for single-cell recordings in monkeys
* Can find cells which react linearly to continuous changes in several of many face features
* Deep brain stimulation results in mis-recognition
* Face space (Chang & Tsao 2017)
  * Use PCA to choose vectors in face space
  * Found faces cells that react only to single vectors
  * Can reconstruct faces from cell responses

Medical cases:

* Prosopagnosia (developmental in ~2% of population)
  * Module defect or the tail of a bell curve?
  * Most visible symptom of general object agnosia? Some prosopagnosiacs have normal object recognition
  * Impairment of item-level recognition? Some prosopagnosiacs have normal item-level recognition
  * Impaired recognition of visually similar forms? Some prosopagnosiacs score normally on differentiation of morphed objects, as long as they are not faces
  * Impaired recognition of objects-of-expertise? WJ learned to recognize sheep at expert levels after injury.
* Some subjects with object agnosia can recognize faces made out of vegetables, but can't recognize the vegetables => independent mechanisms, not superset

Innate:

* Babies orient more towards face-like arrangements
* Subject with upside-down head shows normal recognition accuracy on inverted faces, and > inverted accuracy on normal faces
  * (__Surprised by interpretation. Also, maybe vision is flipped upstream?__)

## [Lecture 6](https://moodle.ucl.ac.uk/pluginfile.php/3742047/mod_resource/content/2/MSC-CODES-social-cognition-17.pdf)

__Skipped the reading this week :S__

Social cognition - 'the psychological processes that result from inferring the actual, imagined, or implied mental state of another'

Affect is creeping back into models of decision-making.

Moving away from 2-process model because of neuro evidence - clearly many systems involved.

What makes a process automatic? Not requiring:

* Intent
* Capacity
* Effort
* Awareness

Rare for any given process to hit all 4.

Illusion of agency - maybe intent does not exist.

Debate over value of heuristics vs rationality.

Mentalizing:

* inferring intentions, goals, desires of other mind (or own mind?)
* typically care about intent and capability (eg warmth, competence etc)

When do we attribute responsibility to an agent for an action?

* Jones says single behavior => specific intent when:
  * given choice
  * has capability
  * departs from behavior of other agents
  * behaves differently in other contents / with other targets
* Kelley says behavior over time => disposition when:
  * departs from behavior of other agents
  * behaves differently in other contents / with other targets
  * consistently behaves in this way in this context
  
> John laughs at the comedian. No one else laughs at the comedian. John laughs at every comedian. John laughs at the comedian every time. => Behavior is attributable to John, not to comedian

Experimentally, seems to be less sensitive to consensus than other two.

Attribute agency to objects similarly, but not moral status eg 'computer said no' but don't feel bad for throwing the computer away. How do we tell the difference?

Emotions hard to define. 

* Facial expressions are interpreted in context - changing context changes perception
* No 1-1 mapping from face muscles to emotions - complex signal
* Much disagreement on mapping emotions to brain regions
* Anxious reappraisal
* Self-reported eg happiness easily influenced by context, but discounted if made aware
* Ability to mimic faces is innate, so universality of expressions could be from cultural transmission
* Subjects with amygdala lesions can be fear-conditioned but are not aware of being afraid
* Awareness of own heart rate predicts differing emotional reactions

Dominant theory - emotion as cognitive interpretation of physiological signals
.
Behavior change:

* motivation + capacity
* very resistant eg anti-smoking ads
* changing environment almost always easier than changing the person

Default mode = social cognition applied to self?

## [Lecture 7](https://moodle.ucl.ac.uk/pluginfile.php/4429745/mod_resource/content/4/Lecture%207.pdf)

Examples of theories that try to unify multiple phenomena:

* Scale invariance
* Decision by sampling
* A theory of magnitude

Scale invariance:

* $y \propto x^\alpha$
* Examples in cogsci:
  * Weber's law - smallest perceptable change : magnitude of stimulus
  * Fechner's law - subjective intensity : physical intensity
    * Exponent varies by sense
  * Fitt's law - time to hit target : log (target distance / target width)
  * Forgetting - recollection probability(?) : time
    * Surprising - exponential decay is a much more natural model
  * Practice - task reaction time : practice time
  * Recall - number of items recalled : time spent recalling
    * Seems not to depend at all on period covered by recall
  * Luce's choice rule and Herrnstein's matching law - probability of choosing item : attractiveness/payoff
* Most examples cover a few ranges of magnitude but fall down at extremes
* Causes?
  * __Need to operate at multiple different scales => use a representation that is scale invariant__
  * __Log-scale turns constant error into proportional error - useful if operating over different scales cf floating point__
  * __Maybe just over-fitting - [with proper testing many examples stop looking like power laws](https://arxiv.org/abs/0706.1062)__
* Tends to be null hypothesis since it turns up so often
* Violations, switching points are interesting

Decision by sampling:

* Need to be able to trade-off between utility of different outcomes, subjective probability, time
* Well-calibrated 
  * eg prospect theory matches up with empirical distribution of credits/debits into bank accounts, supermarket prices
  * eg temporal discounting matches up with number of google hits / newspaper entries for different durations
  * eg subjective risk evaluation matches up with probability judgments of probabilistic phrases + distribution of phrases in British National Corpus
* How to explain this calibration?
* __Could be caused in other direction - subjective curves => behavior - but hard to see why it would affect distribution in this way.__
* Plausible algorithm - no numerical scale, just sample several similar elements and compare to get a rough ranking
* How does sampling work? How is the reference class decided?
  * From memory - choose a reference class - explains framing
  * From context - explains anchoring and effect of irrelevant options
  * From exploration
* __How do we translate between reference scales eg trade off time vs money?__
  * __Poorly, usually.__
  * __CFAR's 'units of exchange' provides anchors / exchange rate?__
* __Picoeconomics claims willpower problems caused by hyperbolic discounting. Can we change the discounting curve by changing sampling process?__

A theory of magnitude:

* Walsh 2003
* Proposes that time, space and number are represented by same mechanism
* Poorly supported, lecturer expects it to be wrong but useful as research direction
* Time and space usually need to processed together eg for motor action, predicting movement
* Plausible that number sense piggybacks on same system
* Number vs space (well supported):
  * Quicker to distinguish numbers that have larger differences (ie further apart on number line)
  * SNARC effect - quicker response to small numbers on left side of vision, large numbers on right side of vision
  * Attention bias effect - quicker to notice stimuli in left when fixated on small number, right when fixated on large number
  * Line bisection effect - left/right bias when picking middle of string depending on number word in string eg "twotwotwotwo"
  * Asymmetric deficits on number tasks in neglect patients / TMS subjects
  * Some subjects describe weird number lines and also deviate from these patterns
* Time vs number (poorly supported):
  * Number tasks and time estimation impair each other
* Time vs space (poorly supported):
  * Subjects imaging 30m activity in scale model take longer for larger models
  * Neglect patients show asymmetric deficits when estimating duration of stimulus in neglected side of field

## [Scale-invariance as a unifying psychological principle](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.323.3478&rep=rep1&type=pdf)

Scale invariance common in nature. Psych processes adapted to reflect this?

Clear examples in perception:

* Luminance between sunlight and shade can be 10000x but brightness and color of an object is perceived same in both - visual system processes ratios, not absolute magnitudes
* Similarly for hearing frequency - absolute pitch is rare but relative pitch is common
* Weber's law - difficulty of distinguishing perceptions proportional to ratio of magnitude, not absolute difference
  * But power varies across scale, so not totally clear
* Steven's law - in >30 perceptual/motor dimensions mapping to numerical scale is power law
  * __When making judgments on numerical scale, does anchoring a point in the middle shift judgements in a scale-invariant fashion?__

Can't be purely scale-invariant, because it is possible to judge magnitudes, but usually poorly.

Not true at all for eg color perception.

Perhaps reflects that the systems themselves are implemented physically.

## [A theory of magnitude: common cortical metrics of time, space and quantity](http://sci-hub.bz/http://www.sciencedirect.com/science/article/pii/S1364661303002304)

Argues that:

* Hemispheric asymmetry is because numerical calculation tied to language
* Number-selective neurons located in same space as space-selective neurons, and some circumstantial evidence of temporal-sensitive neurons in same area

Explaining interference in terms of attention is way too unconstrained. Sounds like single theory but close reading of literature shows that wide variety of proposed effects and causal mechanisms.

Predicts SNARC should work for any space/action -coded magnitude.

## [Decision by sampling](https://pdfs.semanticscholar.org/1b64/bb307016aad4e39b3aeef63a399718403755.pdf)

Typical theories of decision-making take utility functions as given. How do we build/calibrate a utility function given basic psychological operations?

__To relate this back to previous two papers, how do we get an absolute judgment of utility out of brain systems that are only good at relative, scale-invariant judgments?__

Many examples of utility functions (in aggregate) matching cumulative distribution of events in the real world.

Proposes that we sample several items from memory and use these to estimate percentile on empirical distribution.

Many other examples of similar processes:

* Norm theory - judge normality by similarity to sampled events
* Decision field theory - compare alternative by weighted sampling of advantages on random walk
* Support theory - subjective probability depends on alternative hypotheses sampled
* MINERVA-DM - subjective probability/plausibility based on similarity to sampled events
* Stochastic difference model - ?

Assumes that sampling from memory is a good approximation of sampling from reality. Some evidence for this eg [Anderson & Schooler 1991](http://act-r.psy.cmu.edu/wordpress/wp-content/uploads/2012/12/37JRA_LS_PS_1991.pdf).

__Has anyone tested the predicted binomial noise?__

Tweaks:

* Temporal discount rate decreases with magnitude of gain. Explained by assuming that time and magnitude are sampled together, not independently. 
* Temporal discount rate is higher for gains than losses. Explained by curvature of gain/loss utility interacting with base discount rate - discount applies to utility, not gain/loss directly.
* Working-memory load increases discounting of delayed vs immediate gains. Explained by failing to sample enough large delays - biases score upwards.

## [Lecture 8](https://moodle.ucl.ac.uk/pluginfile.php/3788017/mod_resource/content/2/Structure%20and%20Function%20of%20the%20Brain%20-%20%20Language%20and%20the%20Brain.pdf)

Language is hard to define:

* Clark & Clark 1977
  * Arbitrary - mapping from words to meanings
  * Structured - mapping from sentence to meaning
  * Generative - not limited to fixed set of meanings
  * Dynamic - words and structure change over time
* Hocket 1963 - 13 features, of which 10-13 are claimed to only exist in humans
  * Displacement - refer to things removed in time and space
  * Productivity - create novel utterances/meanings which are nevertheless understood by others
  * Cultural transmission
  * Duality of patterning - generative
  * (But many of these arguably displayed in animals eg Alex the parrot)
  
Levels of analysis:

* Phonology - phonemes, speech perception, spectrograms
* Semantics - words, semantic priming
* Grammar - hierarchical structure, formal grammars
* Orthography - writing, reading

Traditional Wernicke-Geschwind model:

* Broca's area = speech production
* Wernicke's area = speech comprehension
* Connected by arcuate fasciculus
* Concentrated in left hemisphere:
  * Wada test - inject sodium amital into artery to sedate one hemisphere
  * Anatomical asymmetry in related areas
  * Asymmetry in PET and fMRI on language tasks
  * Differences in neuron shape between hemispheres
  * But hugely confounded by motor control which is also asymmetric

Problems with model:

* No clear causal relation between lesions and defects (including patients recovering from defects over time)
* No consistent correlation established by functional imaging
* Activations in non-linguistic tasks
* Voxel-based lesion-symptom mapping identifies different areas
* Evidence for multiple networks for language comprehension
* Right hemisphere dominant for many complex language tasks
* Word-specific activation distributed throughout brain, seemingly paralleling organization of sensory and motor systems eg action words in the motor system

Speech perception is ambiguous - requires top-down processing. Illusion of speech units.

* At phonology level:
  * Segmentation problem - cannot find word/syllable boundaries in spectrogram
  * 'Lack of invariance' problem - phonemes do no have consistent representation in spectrogram
  * Speaking rate eg careful pronunciation vs normal conversation produce different spectrograms
  * Huge variation between accents
* At word level:
  * Homonyms
  * Polysemy eg 'the door fell off its hinge' vs 'the child ran through the door'
* At syntax level:
  * Ambiguous binding
* Combined eg 'Mary made her dress correctly'
* Correct interpretation improved by access to mouth movements, body movements (co-speech), conversational context

Really no reason to continue teaching Wernicke-Geschwind model.

## [The free-energy principle: a unified brain theory?](http://www.fil.ion.ucl.ac.uk/~karl/The%20free-energy%20principle%20A%20unified%20brain%20theory.pdf)

[Summary of Surfing Uncertainty](http://slatestarcodex.com/2017/09/05/book-review-surfing-uncertainty/)

[Summary of The Predictive Mind](http://ndpr.nd.edu/news/the-predictive-mind/)

[Wikipedia on free-energy principle](https://en.wikipedia.org/wiki/Free_energy_principle)

Variational Bayes:

* Posterior $P(Z | X)$ is hard to calculate exactly, so instead we approximate it by some family of distributions $Q_\theta(Z)$
* Want to minimize $D_{\mathrm{KL}}(Q(Z) || P(Z|X))$, because we have to minimize something and this is both reasonable and tractable. 
  * __Related - $P_\mathrm{new}(\theta, X) = \mathrm{argmin}_Q D_{KL}(Q(\theta, X) || P_\mathrm{old}(\theta, X)) \text{ subject to } \sum_\theta Q(\theta, X=x) = 1 \text{ and } \sum_\theta Q(\theta, X \neq x) = 0$. Is minimizing distance to posterior equivalent to minimizing distance to prior subject to constraints?__ 
  * [Implications for forward vs reverse KL](https://wiseodd.github.io/techblog/2016/12/21/forward-reverse-kl/)
* Can rewrite as $D_{\mathrm{KL}}(Q || P) = \mathrm{constant} -H(Q) -E_Q[\log{P(Z,X)}]$. Last term (last two terms?) is called 'variational free energy'. __Because thermodynamics?__
* If $Q$ has some factorization over $Z$ can use [calculus of variations](https://en.wikipedia.org/wiki/Calculus_of_variations) (__somehow__) to produce a set of recursive equations that describe the minimum and which converge under iteration.

Free energy principle

* $P$ is joint distribution of world model ('causes') and sensory input. Bayesian update on this model predicts future sensory inputs from past sensory inputs, via inferring underlying causes.
* $Q$ is referred to as recognition density. (__Why?__)
* Express free energy $F$ wrt energy and entropy:
  * $F = -E_Q[\log{P(\mathrm{sense}, \mathrm{cause})}] -H(Q(\mathrm{cause}) = \mathrm{energy} - \mathrm{entropy} = \mathrm{expected surprise} - \mathrm{complexity of model}$
  * Shows that free energy can be evaluated using information that the agent has
* Rewrite free energy $F$ wrt action:
  * $F = D(\mathrm{approx posterior} || \mathrm{prior}) - E_Q[\log{P(\mathrm{sense caused by action} | \mathrm{cause}, \mathrm{model underlying p})}] = \mathrm{complexity / Bayesian surprise} - \mathrm{accuracy / expected surprise}$
  * IE how much we had to mess with the model vs how much predictive accuracy we gained for the recent sensation
  * The action that minimizes free energy is the one that minimizes surprise about the resulting sensations => act to confirm predictions
  * __Hard to interpret. Eg changing point of view to disambiguate optical illusion?__
  * Active inference 
* Rewrite free energy $F$ wrt sensation:
  * $F = D(\mathrm{approx posterior} || \mathrm{posterior}) - \log{P(\mathrm{sense} | \mathrm{model})} = \mathrm{accuracy of approximation} + \mathrm{surprise}$
  * As approximation -> model, $F$ -> surprise
  * Choosing actions and models to minimize $F$ places an upper bound on surprise
* Perceptions feed into online update of $Q$ to more accurately model causes and hence future perceptions.
  
__But we like surprising things? Presumably this is to be explained. Or are actions chosen to minimize $F$ in general, rather than for this specific action?__

Relation to infomax principle (maximizing mutual information between sense and model subject to constraints on complexity of model). Complexity term in 1st formulation penalizes more complex models - regularization/shrinking.

> The fact that these models predict empirically observed receptive fields so well suggests that we are endowed with (or acquire) prior expectations that the causes of our sensations are largely independent and sparse.

Arranged hierarchically, so each model passes prediction error up and passes predictions down. Precision parameter models noise at each level. High noise => more trust in priors / predictions from above. Low noise => more trust in sensory data from below.

States 'value is inverse proportional to surprise'. (In a particular simple model) if we perform gradient ascent on value, then the long-term proportion of time spent in a state is proportional to value, so surprise is inversely proportional to value. Since we act to minimize free energy, priors can encode values. __But does acting to minimize free energy lead to gradient ascent on value? Seems like the argument is backwards.__

__Starting to get flashes of picoeconomics here - recursive relation between model of the future and model of own decision making.__

__Many references to more general connections between minimizing free energy and defying thermodynamics over lifetime of agent, which I don't follow at all.__

## [Active Inference, Curiosity and Insight](http://www.mitpressjournals.org/doi/pdf/10.1162/neco_a_00999)

Various activities can be explained as acting to reduce uncertainty:

* Hidden states -> perceptual inference 
* Future states -> information-seeking behavior, intrinsic motivation
* Future outcomes -> goal-seeking behavior, extrinsic motivation
* World model / parameters -> novelty-seeking behavior, curiosity

To infer expected free energy, we need priors on our own behavior. 

* Minimizing free energy == avoiding surprise
* Minimizing expected free energy == acting to resolve uncertainty
* Need prior on our own behavior to calculate expected free energy. Active inference == prior that we will minimize free energy.

Using example of learning complex rules by active inference. Use prior beliefs about own behavior to encode rules of task, in a way that I don't understand.

Non-REM sleep. In absence of new sensory input, minimizing free energy => minimizing model complexity vs accuracy. Pruning as regularization.

REM sleep. After pruning parameters, need to reevaluate posterior. Can do this by re-simulating observed evidence.

Superstition as premature pruning.

__Open confusions: choice of action vs expected free energy, encoding values as priors, explore vs exploit, precision. Suspect that many of these would be resolved by implementing one of the examples__

## [Active inference and epistemic value](http://sci-hub.bz/http://www.tandfonline.com/doi/full/10.1080/17588928.2015.1020053?scroll=top&needAccess=true)

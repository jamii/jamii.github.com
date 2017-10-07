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

## [Automaticity of Social Behavior: Direct Effects of Trait Construct and Stereotype Activation on Action](https://s3.amazonaws.com/academia.edu.documents/32183592/bargh__chen__burrows.pdf?AWSAccessKeyId=AKIAIWOWYYGZ2Y53UL3A&Expires=1507410409&Signature=cbU%2B6KSCi8jGZWoV4Qriqi9OH%2BA%3D&response-content-disposition=inline%3B%20filename%3DAutomaticity_of_Social_Behavior_Direct_E.pdf)

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

---
layout: post
title: 'Notes on ''PSYCGD02: Principles of Cognition'''
---

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

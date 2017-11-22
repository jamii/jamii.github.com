---
layout: post
title: Notes on 'CoDeS Seminars'
hidden: true
---

## [On Making the Right Choice: The Deliberation-Without-Attention Effect](https://www.dc.uba.ar/materias/incc/2015/c2/practicas/p1/The%20Deliberation-Without_Attention.pdf)

Unconscious Thought Theory

Theory is that conscious thought is sub-optimal for decisions with many aspects because it can only focus on a few things at a time.

Experiment 1:

* Simple car choice (4 aspects) vs complex car choice (12 aspects)
* Car 1 75% positive aspects, cars 2+3 50%, car 4 25%
* Conscious thought - think for 4 mins. Unconscious thought - distracted for 4 mins by anagrams.
* Conscious thinkers won in simple choice but lost in complex choice (where win = pick 75%)
* __Not blinded__
* __Assumption that 75% is the right choice - maybe the one good aspect is important. Are they subsets?__
* __Assumes students bring no outside knowledge in. Were there names or pictures?__

Experiment 2:

* Same, but asked for opinion instead and measured opinion diff

Experiment 3:

* Survey to ask what aspects people would take into consideration for 40 different products
* 49 students asked how much time the spent thinking about a recently bought product and how satisfied they were
* Interaction effect between complexity, time thinking and satisfaction 
* __Need to learn to translate effect sizes back into original scale__
* __Question how accurate recollection is - don't want to admit spending 15 mins thinking about shampoo.__
* __More time conscious = less time subconscious is poor assumption at these time-scales - plenty of time for both.__

Experiment 4:

* Survey of people exiting IKEA (assumed complex) or Bijenkorf (assumed simple).
* Split at median (__why throw away scale?__) (__why use regression above but split here?__)

## Seminar 1

Further comments:

* Conscious vs unconscious processing is poorly defined - they don't give enough detail to justify their interpretation of the experiment
  * eg did unconscious processing actually take place during distraction (later conceptual replication used snap judgments with same effect)
  * eg did distraction actually prevent unconscious processing
  * eg does unconscious processing also take place in non-distracted condition, alongside conscious processing
  * eg could the effect instead be explained by conscious processing in both cases, but performing poorer with more time
* No concrete mechanism proposed - what algorithm is unconscious processing using that makes it better
* Satisfaction is poorly defined
  * eg maybe people who think too much about a purchase have lower satisfaction because of the thinking, not because the choice was worse (consistent with choice regret)
* Lots of instances of p=.04, suspicious of p-hacking

General points:

* If effects are small, not robust and shed no further light on mental mechanism, just don't do the experiment. This is not a useful direction to pursue.
* Don't compare p-values - to test if one effect is significantly stronger than another you need to compare the effect sizes directly.
* Be wary of subjective scales, especially for between-subjects designs.
* Treat '...demonstrates...' and '...clearly shows...' as warning signs that the evidence is weak and the author is compensating (as opposed to '...suggests...' or '...supports...')

## [Childhood forecasting of a small segment of the population with large economic burden](https://moffittcaspi.com/sites/moffittcaspi.com/files/field/publication_uploads/Caspi_NHB_Childhood%20Forecasting%202016.pdf)

Lede: Small% of Dunedin Longitudinal Study account for large% of government cost sectors. 45min test at age 3, longitudinal data both weakly predict membership.

Authors:

* Most authors from Duke, one from NZ.

Story:

* Categories with high costs for society: injury, obesity, smoking, hospital stays, welfare, single-parent families, long-term medication, criminal convictions. 
* Costs within each sector are heavily skewed
* Not independent - small number of people fill many categories. 
* Can predict these people fairly well with childhood tests.
* Which implies that childhood interventions could prevent.

Totally plausible, apart from last which they ack, so main question is how useful is this test.

* Are the methods replicable?
* Will it generalize across generations and regions?
* Is the analysis over-fitted?
* Is it worth using over simpler methods?

Method:

* Dunedin Longitudinal Study
* 1037 people, population representative (NZ), 1972-3 birth cohort, birth to 38yo, 95% retention
* Risk predictors measured at time, not post-hoc
* 20% of cohort account for bignum% of various cost sectors
* Define top 20% in each cost sector as high-risk group (because Pareto)
  * __Top 20% by what measure?__
* Risk factors
  * SES
  * maltreatment
  * low IQ
  * low self-control
* Subjective 'brain health' exam at 3
* Poisson regression for brain health vs cost sectors. All significant except injury claims just outside. AUC .56-.73
  * __Note lack of correlation between significance and AUC - need to work out the relationship.__
* Negative binomial regression for brain health vs number of cost sectors. Significant.
  * __Think model here is binomial with parameter per person, and different weightings on each sector.__
* Decision procedure = ?. __Presumably cutoff on score?__
* Significantly ? for brain health vs multiple cost sectors 
* All approaching AUC=0.8 which is apparently typical standard for medical intervention
* Sensitivity analysis - leave out each sector, still good => not down to good predictions on one sector
  * __But strong causal correlations across multiple cost sectors__

Methods replicable?:

* Subjective exam - picking up on other factors? 
* Exam depends on examiner expertise?

Generalization:

* Survey is 'population representative'
* NZ similar income inequality, health expenditure to UK/US and has national health care and strong welfare
* Variation over time?
* Thematically consistent with other results

Over-fitting:

* Not preregistered, post-hoc predictions, no hold-out
* Much unmentioned data - http://dunedinstudy.otago.ac.nz/studies/assessment-phases/the-assessments
  * Other risk factors eg birth weight, 
  * Other cost sectors eg mental health, dental health, self-harm, gambling
* Choices of coding 
  * Risk factors eg factor analysis, variables included, coding
  * Cost sectors
* Why is 'multiple cost sectors' easier to predict?

But

* But pretty similar scores across many presented models

Usefulness:

* Compare to simpler model eg birth weight, grades, income, teacher predictions
* No causal analysis, but some interventions just target correlates and see success anyway
* Multi-wave risk measurement is impractical

## Paper-reading checklist

* Contents
  * Authors
  * Story
  * Method 
    * Blinding
    * Measurement
    * Intervention 
      * eg using distraction to prevent attention
  * Analysis 
    * Model
    * Sample size
    * Sample characteristics
    * Effect size
  * Interpretation
    * Mechanism
    * Limits of generalization
    * Related work
    
Why design the experiment this way?
    
* Links
  * Authors
    * Prior trust in authors
    * Experimenter experience
  * Method
    * Experimenter effect
    * Measurement error
    * Validated measurement method?
    * Validated intervention method?
      * eg did the distraction actually prevent conscious attention?
    * Alternative causes of effect
  * Analysis
    * Numerical mistakes
    * Inappropriate use of tests
    * Broken test assumptions
    * Estimated effect size on original scale
    * P-hacking? Funnel plots. R-index.
  * Interpretation
    * Plausible mechanism?
    * Existing support for mechanism
    * Predicted/plausible effect size
    * Justify connection between experiment and interpretation
    * Alternative interpretations of effect
    
* Wider
  * Replications
  * Consistency with other results
  * Publication bias, file-drawer effect
  
Maybe Bayes net?

## Seminar 2

Missed points:

* Also used admin db alongside survey
* Risk ratio = treatment risk : control risk
* Binary categorization of cost sector = lost granularity
* Didn't attempt to establish incremental validity

## [The Thatcher Illusion Reveals Orientation Dependence in Brain Regions Involved in Processing Facial Expressions](http://journals.sagepub.com/doi/full/10.1177/0956797613501521)

Story:

* Thatcher illusion => face recognition and expression recognition may be independent. 
* Replicated failure to distinguish inverted Thatcherized faces
* Used adaptation test to try to separate responsible brain areas
* Previous studies couldn't find differential response - credit adaptation design for their results
* __Results seem vague to me__

Behavioral experiment:

* 10 subjects, 2 runs of 108 trials
* Face pairs varying along:
  * normal-normal / normal-Thatcher / Thatcher-Thatcher
  * same-identity / different-identity
  * upright / inverted
* Presented for 800ms
* Subjects asked whether the faces are different
* Accuracy drops only for same-identity inverted normal-Thatcher - huge effect

fMRI experiment:

* 27 subjects
* Picked regions of interest by localizer scan across faces/objects/places/scrambled-faces.
* Present block of 6 different faces, each block from one of:
  * normal-normal / normal-Thatcher (alternating) / Thatcher-Thatcher
  * same-identity / different-identity
  * upright / inverted
* 6 conditions * 6 runs = 36 blocks
* Asked participants to detect red dot on images, to maintain attention (95% accuracy)
* Lots of details about fMRI setup - I have no idea
* Saw no significant details between left/right hemisphere voxels, so combined them
* STS shows release from adaptation for upright images which differ only in Thatcherization
  * => expression recognition?
  * Other results agree that STS most sensitive to changes in expression when face stays same
* FFA shows (weak) release from adaptation for upright/inverted images which differ only in Thatcherization 
  * => facial recognition?
  * Other results show FFA has reduced response for recognizing inverted faces, so surprising
* OFA shows no significant release from adaptation
* (Note not every region present was localized in every subject)

Comments: 

* Behavioral experiment seems solid, even with small n
  * If we use true/false rather than correct/incorrect, are the results still significant? ie are they just guessing?
  * Made sure effect was replicated before using it
* No idea how to judge fMRI analysis
* Conclusions seem weak
* What is a typical effect size in this sort of experiment?
* 2013 - post-dead-salmon. No mention of correction for multiple comparisons.
* Is localization legit?

## Seminar 3

* Uses localization to avoid need for multiple comparison correction
* Assumes Thatcherization detection == facial expression detection
* Why not just test upside-down expressions?
* Doesn't establish that those regions are involved with facial expression, maybe downstream (cf reverse inference)
* Effectively comparing p-values between areas, rather than direct comparison, should use anova and multiple comparison correction (evidence of absence vs absence of evidence)

## Seminar 4

<https://www.testable.org/>

## [Power Posing: Brief Nonverbal Displays Affect Neuroendocrine Levels and Risk Tolerance](https://www0.gsb.columbia.edu/mygsb/faculty/research/pubfiles/4679/power.poses_.PS_.2010.pdf)

Experiment:

  * poses powerful
    * n=75 survey p < .001
  * effects due to power
    * n=19 report comfort (p>.80), difficulty (p>.45), painfulness (p>.42)
  * main experiment
    * n=42 hold two poses for 1m each (why two?), filler task
    * video recording to verify that they hold poses
    * self-reported 'powerful' and 'in-charge'
      * F(1,41)=9.53 p=.004 r=.44
    * behavioral - gambling task with equal EV (related to power?)
      * 86% vs 60%
    * saliva collection 
      * depends on time
      * use gender as covariate
      * F(1,39)=4.29 p=.045
      * F(1,38)=7.45 p=.010
        * (confidence intervals close to 0 for low-power)
  * extra
    * n = 49
    * three more high-power, three more low-power
    * feelings of power F(1, 48) = 4.38, p < .05, r = .30
    * risk-taking χ2(1, N = 49) = 4.84, p < .03, Φ = .31

Experimental flaws:

  * low power, not pre-registered
  * experimenter not blinded, experimenter interaction eg touching limbs 

Conceptual gaps:

  * define 'power'
  * define 'pose projects power'
  * pose => power => effects (vs alternate mechanisms)
  * self-reporting reliable?
  * does it work if you don't draw attention to it?
  
No connection to conclusions: 

  * any long-term effects
  * improved performance in difficult situations
  * improved health
  * get used to pose, no effect after time

[High-powered replication](https://www.anatomytrains.com/wp-content/uploads/2016/08/Assessing-the-Robustness-of-Power-Posing-No-Effect-on-Hormones-and-Risk-Tolerance-in-a-Large-Sample-of-Men-and-Women.pdf) replicated self-reported power, but no effect on hormones or risk-taking. 

  * n=100+100
  * informed participants
  * poses
    * longer poses - 3 min
    * computer instruction = blinded experimenter
    * different filler task
  * self-reported power 
    * t(193) = 2.399, p=.017, Cohens d=0.344
  * risk-taking tests
    * gain test, same as original
    * loss test, flipped framing
    * 6 choices on each rather than 1
    * gain t(198)=−1.245, p=.215, Cohen’s d=−0.176
      * confidence interval does not overlap original -> precise
    * loss 'not significant'
  * saliva
    * testosterone t(196) = −1.405, p=.162, Cohen’s d=−0.200
    * cortisol t(196)=−1.101, p=.272, Cohen’s d=−0.15
  * break analysis down by comfort levels, still no effect

[P-curve analysis paper](https://sci-hub.bz/http://journals.sagepub.com/doi/abs/10.1177/0956797616658563?journalCode=pssa)and [blog post](http://datacolada.org/37).

  * 33 published studies
  * concludes 'evidence for the basic effect seems too fragile to search for moderators or to advocate for people to engage in power posing to better their lives'

Time-reversal heuristic.

## Seminar 5

  * Note footnote on outlier
  * Later revealed optional stopping
  * 5 participants excluded, not mentioned in paper
  * Selective reporting of p-values (but hardly differs)
  * Selective reporting of self-reported questions

Beware collections of studies varying in sample size without justification - sounds like optional stopping.

(Did they ever release data)?

## Seminar 6

Naught.

---
layout: "post"
title: "Notes on 'Statistical Rethinking'"
date: "2017-03-20 20:11"
---

<https://smile.amazon.com/dp/1482253445>

__Focuses on practical elements of modeling. Very skimpy on the math, but can get that elsewhere.__ Book focuses on Bayesian data analysis, multilevel modelling and model comparison using information criteria.

Hypothesis <-> model <-> data are many-many relationships. Naive falsification is a myth - multiple hypotheses might have models which predict the same data, and one hypothesis might have multiple models that each predict different data. Worse, most interesting hypotheses are probabalistic. Eg 80% of swans are white - how many black swans do we have to see to falsify? How many blurry photos of Nessie do we have to see to falsify the no-Nessie hypothesis?

(NHST is not even naive falsification - it attempts to falsify the null hypothesis rather than the hypothesis in question. In many domains there is not even an obvious neutral hypothesis.)

Clearly need to be able to reason about evidence/belief/confidence. Bayesian approach is defined by using probability for both observed frequencies and evidence/belief/confidence. __See [Jaynes](https://www.amazon.com/Probability-Theory-Principles-Elementary-Applications-ebook/dp/B00AKE1Q40/ref=mt_kindle?_encoding=UTF8&me=) for the canonical argument that probability is the right way to think about belief.__

No free lunch. Bayesian inference always takes place within some model. Within the assumptions of the model being fitted, Bayaesian inference is optimal. BUT IT CANNOT TELL YOU IF YOUR MODEL IS CORRECT. Small world vs large world.

Cute metaphor of statistical modelling tools as golems - immensely powerful but brutally unthinking. User is responsible for supplying all the wisdom and interpretation.

Bayesian model consists of:

* Set of parameters 
* Prior distribution on parameters
* Model mapping parameters to distribution on observed evidence

Multilevel models - models where parameters are themselves supplied by models. Typical reasons for use:

* To adjust estimates for imbalanced / biased samples
* To study variation between subjects 
* To avoid averaging over samples

__The distinction only seems to need stating because the history of the subject focuses on single-level models.__

Information criteria are used to estimate prediction performance across different models. Still no free lunch - each criteria embodies some set of assumptions about prediction. But useful for detecting overfitting, and for comparing multiple non-null models. 

Book introduces three methods for conditioning on evidence:

* Grid approximation: approximate parameters by a discrete distribution on regular grid, compute discrete posterior directly
* Quadratic approximation: under reasonable assumptions the posterior is approximately gaussian, so use hill-climbing to find peak (mean) and use numerical methods to approximate curvature near peak (variance).
* Markov chain Monte Carlo: construct a Markov chain whose steady-state distribution is the posterior, sample repeatedly to approximate.

Percentile intervals - what range of paramaters occupies central X% of mass. Highest posterior density interval - what is the smallest range of parameters that covers X% of mass. Usually similar. If they aren't, the distribution is weird and you should show the whole thing instead of summarizing it anyway.

What if we need a point estimate? Choose a loss function appropriate to your decision problem, and choose the point estimate that minimises expected loss under the posterior distribution.

Maximum A Posteriori estimate - parameter with highest density in posterior.

Simulate posterior for:

* Model checking - see if the implied predictions make sense.
* Software validation - simulate some known model and then fit it again to see if we can recover the orginal parameters.
* Research design - simulate hypothesis to see if the proposed experiment will be effective (includes power analysis).
* Forecasting - use model to make new predictions, for application or for testing the model out-of-sample.

Posterior predictive distribution - sample from both posterior and model to compute prediction.

Model checking. Look at various summary statistics to check assumptions eg run lengths in assumed IID samples.

![](/img/posterior-predictive.png)

---
layout: "post"
title: "Notes on 'Statistical Rethinking'"
date: "2017-03-20 20:11"
---

<https://smile.amazon.com/dp/1482253445>

__Focuses on practical elements of modeling. Very skimpy on the math, but can get that elsewhere. Most of the value is in working through the exercises.__ 

Book focuses on Bayesian data analysis, multilevel modelling and model comparison using information criteria.

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
* Quadratic approximation: under reasonable assumptions the posterior is approximately Gaussian, so use hill-climbing to find peak (mean) and use numerical methods to approximate curvature near peak (variance).
* Markov chain Monte Carlo: construct a Markov chain whose steady-state distribution is the posterior, sample repeatedly to approximate.

Percentile intervals - what range of paramaters occupies central X% of mass. Highest posterior density interval - what is the smallest range of parameters that covers X% of mass. Usually similar. If they aren't, the distribution is weird and you should show the whole thing instead of summarizing it anyway.

What if we need a point estimate? Choose a loss function appropriate to your decision problem, and choose the point estimate that minimises expected loss under the posterior distribution.

MAP estimate - maximum a posteriori - parameter with highest density in posterior.

Simulate posterior for:

* Model checking - see if the implied predictions make sense.
* Software validation - simulate some known model and then fit it again to see if we can recover the orginal parameters.
* Research design - simulate hypothesis to see if the proposed experiment will be effective (includes power analysis).
* Forecasting - use model to make new predictions, for application or for testing the model out-of-sample.



Model checking. Look at various summary statistics to check assumptions eg run lengths in assumed IID samples.

## Modelling

Epistemological assumption - about how to model the world. Ontological assumption - about the world. Projection fallacy - confusing the two. Eg model of height assumes that individual heights are IID. Not true for eg twins, but true enough to make the model useful.

TODO de Finitte's theorem

For Gaussian priors, can weigh confidence by $\sigma_{\text{post}} = 1 / \sqrt{N}$. So we are saying that we have $N = 1 / \sigma_{\text{prior}}^2$ prior observations centered around $\mu$. TODO double-check this

Often useful to standardize input data into $\text{mean} + x * \text{stddev}$. Makes the resulting parameters easier to compare directly to each other. For large inputs, may avoid loss of precision. In linear models, removes the strong correlation between intercept and slope. 

## Fitting

## Checking

Posterior predictive distribution - sample from both posterior and model to compute prediction. Could compute it analytically but fuck it, we have a computer for that kind of thing. 

![](/img/posterior-predictive.png)

Can display model uncertainty by sampling from the posterior and plotting the implied model eg for simple linear model plot the lines for each posterior sample.

## Applying 

## Linear regression

Model outcome as linear function of predictors plus Gaussian error. 

Why Gaussian? Gaussian distribution can originate from sum of similar-sized random variables or product of variables close to one ($(1+x)(1+y) \approx 1+x+y$), log of product of variables etc. TODO Also Gaussian is lowest entropy distribution if all we know is mean and variance.

Posterior for variance parameter tends to have a long right tail, because we know it's non-negative. This makes the quadratic approximation suspect. Better to estimate $\log{\sigma}$ instead, which is closer to guassian. In general, using exponentials to constrain parameters to be positive, rather than using a one-sided prior, is a useful trick.

Handle catergorical variables by breaking down into indicator variables.

Can use multivariate linear regression to 'control' for effects of multiple variables.

Multicollinearity - when two predictor variables are strongly correlated, any linear combination of them will be equally plausible. Symptom is large spread and high covariance between posteriors for the two variables. 

Residual - difference between observation and prediction.

With multiple predictors, can no longer visualize predictions directly with a line + hpdi. Can use:

* Predictor residual plots - use all but one predictor to model remaining predictor, then regress+plot residuals against outcome. Shows the unique contribution of that predictor. 
* Counterfactual plots - simulate altering one variable while holding the others constant.
* Posterior prediction plots - simulate and plot predicted outcome vs observed outcome, prediction error vs predictors, distribution of prediction error per case etc. __In prediction error vs predictors, if the model is accurate we expect to see normally distributed error independent of the predictor. Obvious patterns are an opportunity for a better model.__

## Polynomial regression

Model outcome as polynomial of predictors plus Gaussian error.

Not generally a good choice - hard to interpret and prone to overfitting. Better to start from a hypothesized mechanism.

Recommends preprocessing data for polynomials, without justification eg `d$weight.s2 <- d$weight.s^2`.

<script type="text/javascript" async
  src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-MML-AM_CHTML">
</script>

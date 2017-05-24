---
layout: "post"
title: "Notes on 'Statistical Rethinking'"
date: "2017-03-20 20:11"
---

<https://smile.amazon.com/dp/1482253445>

__Focuses on practical elements of modeling. Very skimpy on the math, but can get that elsewhere. Most of the value is in working through the exercises.__ 

Book focuses on Bayesian data analysis, multilevel modeling and model comparison using information criteria.

Hypothesis <-> model <-> data are many-many relationships. Naive falsification is a myth - multiple hypotheses might have models which predict the same data, and one hypothesis might have multiple models that each predict different data. Worse, most interesting hypotheses are probabilistic. Eg 80% of swans are white - how many black swans do we have to see to falsify? How many blurry photos of Nessie do we have to see to falsify the no-Nessie hypothesis?

(NHST is not even naive falsification - it attempts to falsify the null hypothesis rather than the hypothesis in question. In many domains there is not even an obvious neutral hypothesis.)

Clearly need to be able to reason about evidence/belief/confidence. Bayesian approach is defined by using probability for both observed frequencies and evidence/belief/confidence. __See [Jaynes](https://www.amazon.com/Probability-Theory-Principles-Elementary-Applications-ebook/dp/B00AKE1Q40/ref=mt_kindle?_encoding=UTF8&me=) for the canonical argument that probability is the right way to think about belief.__

No free lunch. Bayesian inference always takes place within some model. Within the assumptions of the model being fitted, Bayesian inference is optimal. BUT IT CANNOT TELL YOU IF YOUR MODEL IS CORRECT. Small world vs large world.

Cute metaphor of statistical modeling tools as golems - immensely powerful but brutally unthinking. User is responsible for supplying all the wisdom and interpretation.

Bayesian model consists of:

* Set of parameters 
* Prior distribution on parameters
* Model mapping parameters to distribution on observed evidence

Epistemological assumption - about how to model the world. Ontological assumption - about the world. Projection fallacy - confusing the two. Eg model of height assumes that individual heights are IID. Not true for eg twins, but true enough to make the model useful.

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

Simulate posterior for:

* Model checking - see if the implied predictions make sense eg look at various summary statistics to check assumptions eg run lengths in assumed IID samples.
* Software validation - simulate some known model and then fit it again to see if we can recover the orginal parameters.
* Research design - simulate hypothesis to see if the proposed experiment will be effective (includes power analysis).
* Forecasting - use model to make new predictions, for application or for testing the model out-of-sample.

## Modeling

Often useful to standardize input data into $\text{mean} + x * \text{stddev}$. Makes the resulting parameters easier to compare directly to each other. For large inputs, may avoid loss of precision. In linear models, removes the strong correlation between intercept and slope. 

Recommends preprocessing data for polynomials, without justification eg `d$weight.s2 <- d$weight.s^2`.

Posterior predictive distribution - sample from both posterior and model to compute prediction. Could compute it analytically, but we invented computers for this sort of thing.

![](/img/posterior-predictive.png)

Percentile intervals - what range of parameters occupies central X% of mass. Highest posterior density interval - what is the smallest range of parameters that covers X% of mass. Usually similar. If they aren't, the distribution is weird and you should show the whole thing instead of summarizing it anyway.

What if we need a point estimate? Choose a loss function appropriate to your decision problem, and choose the point estimate that minimizes expected loss under the posterior distribution.

MAP estimate - maximum a posteriori - parameter with highest density in posterior.

Can display model uncertainty by sampling from the posterior and plotting the implied model eg for simple linear model plot the lines for each posterior sample.

Residual - difference between observation and prediction.

With multiple predictors, can no longer visualize predictions directly with a line + hpdi. Can use:

* Predictor residual plots - use all but one predictor to model remaining predictor, then regress+plot residuals against outcome. Shows the unique contribution of that predictor. 
* Counterfactual plots - simulate altering one variable while holding the others constant.
* Posterior prediction plots - simulate and plot predicted outcome vs observed outcome, prediction error vs predictors, distribution of prediction error per case etc. __In prediction error vs predictors, if the model is accurate we expect to see error distributed like the error term in our model. Obvious patterns are an opportunity for a better model.__

Non-identifiability - when data and model structure do not allow estimating the value of a parameter.

Post-treatment bias - any variable that is a causal consequence of the treatment being studied can screen off the inferred influence of the treatment. Model is asking the wrong question, so model comparison using information criteria or out-of-sample prediction quality can't help.

## Linear models

Model outcome as linear function of predictors plus Gaussian error. 

Why Gaussian? Gaussian distribution can originate from sum of similar-sized random variables or product of variables close to one ($(1+x)(1+y) \approx 1+x+y$), log of product of variables etc. TODO Also Gaussian is lowest entropy distribution if all we know is mean and variance.

Handle categorical variables by separating into indicator variables.

Posterior for variance parameter tends to have a long right tail, because we know it's non-negative. This makes the quadratic approximation suspect. Better to estimate $\log{\sigma}$ instead, which is closer to Gaussian. In general, using exponentials to constrain parameters to be positive, rather than using a one-sided prior, is a useful trick.

Can use multivariate linear regression to 'control' for effects of multiple variables.

Multicollinearity - when two predictor variables are strongly correlated, any linear combination of them will be equally plausible. Symptom is large spread and high covariance between posteriors for the two variables. (Special case of non-identifiability).

Polynomial regression - model outcome as polynomial of predictors plus Gaussian error. Not generally a good choice - hard to interpret and prone to overfitting. Better to start from a hypothesized mechanism. 

## Model comparison

__I found this section really hard to follow. Eventually realized that it's notational sloppiness - not clearly distinguishing between expectations under reality and expectations under observation, and lack of clear indices on sums. These notes are heavily supplemented by other sources.__

Under- vs over-fitting.

Regularization - use strong priors to penalize models which we believe are unlikely. Reduces over-fitting.

Cross-validation - partition the data into training and test set. Test how sensitive the parameters are to the partitioning.

For prediction tasks we can just choose models based on some cost function that matches the task. For scientific work we care about the model itself, so there is no clear cost function. KL-divergence from reality is a popular measure. __The use of KL-divergence is really poorly justified in this text.__ 

$D_{KL}(p,q) - D_{KL}(p,r) = E_p[\log(r) - \log(q)]$. We know $r$ and $q$ and we can approximate $E_p[\cdot]$ by averaging over the observed data, so we can easily estimate the difference in divergence between two models.

Minimizing KL-divergence is equivalent to maximizing the likelihood of the posterior over the observed data. Define deviance as $D(q) = -2 sum_i \log(q_i)$ (summing over data). __Roughly speaking, deviance : divergence as mean : expectation.__

Now we want to estimate out-of-sample deviance. Various different estimators making different assumptions:

Akaike Information Criterion. $AIC = D(E_\theta[\theta]) + 2p$. Assuming flat priors, Gaussian posterior and sample size N >> parameters k. 

Deviance Information Criterion. $DIC = D(E_\theta[\theta]) + 2p_{DIC}$ where $p_{DIC} = E_\theta[D(\theta)] - D(E_\theta[\theta])$. Similar to AIC, but takes into account the fact that priors constrain degrees of freedom. Still assumes Gaussian posterior.

Widely Applicable Information Criterion. $WAIC = -2\text{lppd} - 2p_{WAIC}$ where $\text{lppd} = \sum_{i=1}^N \log E_\theta[P(y_i|\theta)]$ and $p_{WAIC} = \sum_{i=1}^N \text{Var}_\theta(\log P(y_i|\theta))$. Truely Bayesian calculation of deviance. Penalizes data points which have been fitted into a narrow peak. Assumes independent observations and that $p \ll N$.

Bayesian Information Criterion. Can be heavily influenced by choice of prior - not recommended.

Prefer WAIC where applicable, cross-validation otherwise.

Uniformitarian assumption - future data are expected to come from the same process as past data, with a similar range of hidden parameters. Pretty hard to avoid. __Induction problem, basically.__

Comparing models using information criteria only makes sense if both models are trained on the same data. Beware code that automatically drops missing data.

Akaike weight - map WAIC to probability scale, normalize across models. Use to compare relative accuracy. No consensus on how to interpret these weights - Akaike says:

> A model’s weight is an estimate of the probability that the model will make the best predictions on new data, conditional on the set of models considered.

Model averaging - create an ensemble by summing Akaike weighted posteriors.

With enough model generation and comparison, we can overfit again.

## Interactions

For linear interactions, multiply predictors together in the model.

Interactions are symmetric, so be sure to consider both interpretations.

Really hard to interpret, so definitely have to plot predictions now. Can use multiple plots to view interaction effects - varying predictor A across plots and predictor B within plots.

Centering data also becomes more important.

<script type="text/javascript" async
  src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-MML-AM_CHTML">
</script>

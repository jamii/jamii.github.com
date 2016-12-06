---
layout: "post"
title: "Notes on 'Everything is fucked'"
date: "2016-11-30 17:18"
---

Sanjay Srivastava posted a syllabus for a course called [Everything is fucked](https://hardsci.wordpress.com/2016/08/11/everything-is-fucked-the-syllabus/). The course itself is a joke but it has an interesting reading list.

## [Why summaries of research on psychological theories are often uninterpretable](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.392.6447&rep=rep1&type=pdf)

After reading all the evidence on a given theory, how do you interpret the evidence to decide how much confidence to place in the theory?

Concerned mainly with theories/experiments/papers that are:

* Soft. Eg psychology or sociology rather than physics or chemistry. Defined in a 'you know them when you see them' sort of way. __I might characterize them as lacking computable theories.__
* Correlational. Based on observational data, or randomized experiments that examine an interaction with a non-randomized factor. __TIL that the latter breaks randomized controls. Obvious in hindsight.__
* Vague. Do not predict a specific value of the outcome variable, so that anything other than the null result confirms the theory. __Making them observationally indistinguishable from other non-null-hypotheses.__

> Null hypothesis testing of correlational predictions from weak substantive theories in soft psychology is subject to the influence of ten obfuscating factors whose effects are usually (1) sizeable, (2) opposed, (3) variable, and (4) unknown. The net epistemic effect of these ten obfuscating influences is that the usual research literature review is well-nigh uninterpretable.

1. Loose derivation chain. Chain of premises connecting theory to observation is large and mostly unstated. Falsification of a prediction does not strongly falsify the theory. __Not totally clear on the meaning here, but perhaps the point is that the various causal mechanisms and measurements are not strongly reliable eg a reliability of 0.8 would be considered pretty high for a psych test, but embarrassingly low for a telescope.__
2. Problematic auxiliary theories. __Eg interpreting astronomical observations depends on auxiliary theories of how light and telescopes and computers work.__ Eg suppose we test interaction between anxiety and intro/extraversion by giving students personality tests and then telling them they failed their midterm. A null result might tell us there is no effect on intro/extraversion on anxiety, or it might tell us that students don't get anxious if you tell them they failed.
3. Problematic ceteris paribus clause. Eg suppose we test interaction between anxiety and intro/extraversion by giving students personality tests and then telling them they failed their midterm. It might be that good students react with anxiety but poor students already expected to fail. If there is a correlation between being a good student and intro/extraversion then the randomized control is broken.
4. Experimenter error and bias.
5. Inadequate statistical power. 
6. Crud factor. In causally dense environments like psychology everything correlates with everything else. (Author gives examples of some observational studies of schoolchildren where out of 990 pairs of variables, 92% had statistically significant correlations). Therefore refuting the null hypothesis is not unusual and is not strong evidence for any specific theory.
7. Pilot studies. Negative pilot studies are usually not published, producing a strong publication bias and leading to duplicated work. Pilot studies also give a good indicator of the size of the crud effect, allowing the followup experiment to be sized to likely reach statistical significance.
8. Submission bias. Negative or uninteresting results usually not submitted for publication.
9. Publication bias. Negative or uninteresting results often reject when submitted.
10. Detached validation claim for psychometric instruments. Validity/reliability of instruments need to be included in statistical analysis, yet most papers provide evidence that the instrument is somewhat valid and then do the stats as if it is 100% valid. Particularly bad case is instruments with low validity and high reliability ie the instrument reliably measures *something*, but mostly not the thing you care about, so if the outcome correlates highly with the instrument it still doesn't tell you much about the input variable.

Some back-of-the-envelope sketches with just a few of these factors show that true and false theories might both expect similar levels of confirmation/rejection in published results.

These factors are much less of a problem in, say, agronomy because a) theories such as 'fertilizer makes corn grow better than no fertilizer' are practically equivalent to refuting the null hypothesis b) the environment is better understood and much less causally dense eg if corn in fertilized fields grows better, there are very few competing explanations and c) it's much easier to run randomized controlled experiments on corn than on people. __Point a) is similar to Deutschs idea of 'good explanations'.__

Notes that when weighing evidence, both students and faculty seem to implicitly conflate the theory being tested with the refutation of the null hypothesis - even though they would never make that mistake explicitly.

Suggestions for improvement:

* Try to build theories which roughly predict effect size.
* Aim for higher power to counter 2) and 3)
* Dedicate space at the back of journals for brief, low-effort publishing of pilot studies.
* Mention power in papers.
* Don't put faith in 'box scores'
* Force PhD students to take math courses. Using methods without understanding them should be embarrassing, not the norm.
* Maybe backpedal a little on publish-or-perish?
* Maybe study the crud factor in various domains?
* Accept that some theories cannot currently be tested by the means we have at our disposal, and stop wasting taxpayer money pretending to test them.

## [Things I have learned (so far)](http://moityca.com.br/pdfs/Cohen_1990.pdf)

Use fewer variables. With eg MRA the number of hypthesis tests is at least the product of the number of dependent and independent variables. 

Drop non-significant significant figures. 

Visualize your data. Not all data is normal. Many summary variables are incredibly sensitive to a few outliers. 

Simple models (eg using unit weights for linear regression) are less prone to overfitting.

Don't throw away information eg reducing continuous variables like IQ to categories like dumb/average/smart.

Recounts the progression from Fisherian null-hypothesis tests to power analysis.

Authors meta-analysis of contemporary papers finds most are underpowered.

Report effect sizes and uncertainty intervals foremost, rather than p-values.

Run power analysis when planning your experiment. Can it actually detect an effect of the size you expect?

New stats ideas take a long time to percolate through the scientific body.

## [Is there a free lunch in inference?](http://pcl.missouri.edu/sites/default/files/freeLunch_0.pdf)

Free lunch in null-hypothesis significance testing - don't need to fully specify the alternate hypothesis to reject the null hypothesis. 

'If A, probably not B. B, therefore probably not A.' NOT VALID in general eg 'If Sally is American, she is probably not a congressperson. Sally is a congressperson, therefore she is probably not American.'

Call a procedure consistent if it converges to the correct decision as the sample size increases. NHST is not consistent - with a cutoff of p=0.05 the rejection rate for a true hypothesis converges to 5% as the sample size increases.

Suppose we set $$\alpha_N = min(0.05, \beta_N)$$, so that the rejection rate converges to 0 as the sample size increases. This requires knowing $$\beta_N$$ which requires specifying an effect size for the alternate hypothesis.

Another way to look at this. In NHST the observed effect size needed to reject the null hypothesis converges to zero. With the above procedure, it converges to half the hypothesized effect size.

All similar consistent frequentist procedures that have been proposed have the same property - they must specify an alternative hypothesis.

(Confidence intervals are also inconsistent, for the same reason)

Explanation of Bayesian update of a parametric model. Bayesian update is consistent, but also requires specifying an alternative through the prior distribution on the parameter.

Credible intervals - use 95% inner percentile of prior distribution. Does not satisfy Bayes rule - evidence might concentrate belief from other areas into a tight 95% interval even when the Bayes factor for the null hypothesis is 1.

Demonstrates that the Bayes factor does not vary wildly between different reasonable priors.

Alternatives may be subjective, but would be subject to review as much as anything else. __Seems a somewhat weak defence - no idea how to review alternatives. Am I not incentivized to pick the most extreme alternative effect size I can get away with?__

Re: arguments for effect size estimates. All of the above still works given interval null hypotheses. Estimation of effect size doesn't tell us how to weigh evidence for competing theories. Estimation is not model-free - different models produce different best estimates for the same sample. In a Bayesian mindset, our degree of prior belief in the null hypothesis should weight our estimate towards zero.

## Structural equations with latent variables

Skipped - didn't want to buy the book.

## [Yes, but what’s the mechanism?(don’t expect an easy answer)](http://www2.psych.ubc.ca/~schaller/528Readings/BullockGreenHa2010.pdf)

Randomized experiments reveal causation, but not mechanisms. Want to be able to determine mediating variables. Typical approach is to use this model:

$$
M_i = \alpha_1 + aX_i + e_i1
Y_i = \alpha_2 + cX_i + e_i2
Y_i = \alpha_3 + dX_i + bM_i + e_i3
$$

X affects M and Y, and M affects Y. We want to know how much X affects Y directly ($$d$$) vs indirectly through M ($$ab$$).

The estimator used converges to:

$$
estimate(b) = b + cov(e_1, e_3) / var(e_1)
estimate(d) = d - a(cov(e_1, e_3) / var(e_1))
$$

Problem 1: if $$e_1$$ and $$e_3$$ are correlated then the estimator is biased. In practice this nearly always happens because $$e_1$$ and $$e_3$$ are the dumping ground for all the other mediating variables. So we must also randomize M somehow.

Problem 2: the procedure we use to control M must not also affect other mediating variables, otherwise $$e_1$$ and $$e_3$$ will be correlated again. We have to rule out all other causal pathways between X and Y.

Problem 3: changing M while holding X constant is philosophically weird, because the model says that X affects M. Worse, we typically can't measure M directly because it's some internal mental state. We ought to at least test many different interventions that aim to change M and see if they all produce similar estimates.

Problem 4: we assume $$a$$, $$b$$, $$c$$ and $$d$$ are constant. If they vary per subject, the estimator is giving us $$mean(a) mean(b)$$ when what we care about is $$mean(ab)$$. We should look for in-group differences to attempt to catch this.

__I think the core problem here is that we can't distinguish between a bad model and missing variables. The same problem is more obvious in a simple linear regression between X and Y. If we get a large error term, we could conclude that X and Y are not strongly related. Or we could conclude that the relation is not well modeled by a linear function. All the problems above are hard to detect because they just get swallowed by the error terms.__

## [Using analysis of covariance (ANCOVA) with fallible covariates](http://www.hermanaguinis.com/PM2011.pdf)

Multiple regression analysis. Want to measure relationship between dependent and independent variable while controlling for other known factors.

If the mean covariate effect differs between the control and treatment group AND the measurement of the covariates is not perfectly reliable, then ANCOVA is biased towards Type I errors. 

__There are no examples to concretize the math here. Let's say we want to know if traders are more likely than the average person to buy a fancy car, controlling for wealth. Suppose our measure for wealth is totally unreliable ie just a random number and we run a very high-powered experiment. Then if wealth has any effect, it will be attributed instead to being a trader because our random-number-generator measure of wealth does not explain the effect.__

__Notably, in a randomized experiment the expected covariate effect is the same for both groups and so this specific bias doesn't exist, although measurement error would still presumably screw up mediation analysis in a similar fashion.__

The actual size of the bias can be pretty large for reasonable parameters. 

The authors use Monte Carlo simulations to test many different scenarios, and find that of the 4 methods for correcting this bias the Errors In Variables model was most effective. __Does this depend on the generated data? You could certainly produce bad results for any given method by just generating data that violates it's assumptions.__

[Statistically controlling for confounding constructs is harder than you think](http://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0152719&type=printable)

__The problem above has a name - residual confounding!__ TODO

Incremental validity - is X useful for predicting Y even after controlling for A,B and C?

Same problem as above - imperfect measures produce imperfect controls. Type I error results.

> The intuitive explanation for this is that measurement unreliability makes it easier for the regression model to confuse the direct and indirect paths (i.e., to apportion variance in the outcome incorrectly between the various predictors).

Error rate peaks when reliability is ~0.5, not at 0. __I think this is because they set the reliability for both the controlled variable and the independent variable at the same time, so at 0 both are totally random and there is no correlation at all with the dependent variable.__

Similarly structured arguments that have similar problems:

* Argument for separable constructs eg if two intelligence tests both predict performance even while controlling for each other, we argue that they are measuring separate attributes. Could both be noisy measurements of the same attribute.
* Argument for improved measurement eg if in a regression on an old test and a new test, only the new test is significant, we argue that the new test is a strict improvement on the old. Not even valid logic and produces poorly (and weirdly) calibrated errors. __I'm not totally clear on why this is wrong - the explanation is very brief.__

Structured Equation Modelling incorporates an estimate of measurement error into the regression. Can perturb the estimates to see how sensitive the results are. Shows that as the reliability estimate is reduced, the standard error of the estimator grows.

Under realistic settings (low direct contribution, unreliable measures) the sample sizes required for reasonable power with SEM are huge.

## [Is the replicability crisis overblown? Three arguments examined.](http://pps.sagepub.com.sci-hub.cc/content/7/6/531.abstract)

Counters to common arguments against the replicability crisis.

Argument 1: setting alpha to 5% means the false positive rate is about 5%, which is reasonable. __Apparently not a strawman - many people haven't been paying attention.__ Some back-of-the-envelope math with publication bias, forking paths and priors on theories being correct is enough to counter this.

Argument 2: conceptual replications are good enough. Publication bias - failed conceptual replications are likely to lead to adjusting experiments rather than publication. And if published, would not likely be seen as falsifying the original theory. __Bad explanations strike again.__ Also produces moving targets (eg cold fusion) where direct replication fails but conceptual replication succeeds, and supporters demand failed replications of new improved experiments.

Argument 3: science self-corrects eventually. Notes that median times for failed replication attempt is only 4 years after original, so not much attempt at correcting enshrined mistakes. Subargument is that old mistakes are abandoned rather than explicitly discredited, but how does one distinguish between a subject that is abandoned and one that is simply mature? Certainly many old subjects that are taught in textbooks etc but not actively studied today. Eg Amgen Corp tried to replicate 53 landmark studies with only 11% success rate.

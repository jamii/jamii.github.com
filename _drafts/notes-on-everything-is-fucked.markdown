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

## [Statistically controlling for confounding constructs is harder than you think](http://journals.plos.org/plosone/article/file?id=10.1371/journal.pone.0152719&type=printable)

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

## [Estimating the reproducibility of psychological science](http://www.spelab.org/uploads/2/7/8/4/27842457/open_science_collaboration_2015.pdf)

> We conducted replications of 100 experimental and correlational studies published in three psychology journals using high-powered designs and original materials when available.

Previous reports about poor replication rates lacked clear methods, selection etc. Methods for this project are detailed in excruciating detail. Highlights:

* Selection from a limited but replenished pool of papers, to balance good experiment-team matches against controlling selection bias.
* Checklists for various processes
* Each team shared data publicly for independent re-analysis by a different analyst
* Covered multiple journals and disciplines

How to measure replication? Many options:

* Is new result significant and in same direction? Unfairly penalizes results close to the cutoff. 35/97 fail.
* Is old effect size withing 95% CI of new effect size? Doesn't penalize replications which don't produce strong results. 43/73 fail. 
* Directly compare effect sizes. 82/99 had larger old effects. Mean ratio is ~0.5.
* Combine results from both. Retains publication bias of old, but may correct for any unknown bias in new. 24/75 had 95% CIs containing 0. 
* Subjective judgment of team. 61/100 fail.

23/49 experiments testing main/simple effects had significant replications, but only 8/27 experiments testing interaction effects.

Replication success is predicted better by strength of original evidence than by characteristics of the experiment or replication team.

__Worth noting that this doesn't fix most of the stats problems already discussed either. This is only addresses the effects of publication bias and low power. Real situation may be even worse.__

## [Comment on “Estimating the reproducibility of psychological science.”](http://science.sciencemag.org/content/sci/351/6277/1037.2.full.pdf)

Objections:

1. OSC drew samples from different populations to original experiments. (Gives only 3 examples).
2. OSC used different procedures from original experiments. (Gives only 3 examples, but they seem pretty clearly different).
3. Picking random experiments from Many Labs Project as 'original' find a 35% failure rate without any chance of publication bias
4. Using OSCs methods with MLP data, get replication rate of 35%. But using MLPs pooling method get 85%.
5. Only 69% of OSC authors reported endorsing original experimental protocol. Endorsers had 59.7% success rate, non-endorsers had 15.4%. Possible experimenter bias against replication? __Or maybe the experimenters are just good judges of which experiments suck? Original paper noted that 'surprise' was anti-correlated with replication.__

__1 and 2 seem pretty weak - fair odds that the original results were interpreted very generally, so the fact that small changes to the protocol result in failed replication indicates at least a lack of external validity.__

## [Response to Comment on “Estimating the reproducibility of psychological science](http://datacolada.org/wp-content/uploads/2016/03/5322-Nosek-response.pdf)

__Not in the original list, added on a whim.__

Half of the 'failures' in this comparison had larger effect sizes than the original, compared to only 5% of the OSC replications.

Variation between replications in MLP was highest for largest effects and lowest for smallest effects. Replication failures in OSC were more common for small effects.

MLP had high replication rate but ad-hoc selection procedure for papers. Later project by same group had only 30% replication rate.

Of the six examples of different experiment design, three were endorsed by the original experimenters and the fourth was a succesful replication.

Maybe the experimenters are just good judges of which experiments suck? Surprise was anti-correlated with replication success. __Yay, validation of my paper-reading skills!__

## [Is psychology suffering from a replication crisis? What does “failure to replicate” really mean?](http://sci-hub.cc/10.1037/a0039400)

If publication bias causes over-estimates of effect sizes, then power analysis for replications based on that effect size is likely to overestimate power, leading to Type II errors.

__Didn't OSC mention that experiments with large effect sizes were more likely to be replicated?__

Predictive power analysis takes into account a confidence interval on the estimated effect size. Tends to predict much lower power, because effect size -> power is not a linear function. Can result in surprisingly large sample sizes for adequately powered replication attempts.

Suppose we manage a high-powered replication and don't obtain a significant result. Usually interpreted as casting doubt on the original experiment and supporting the null hypothesis.

Frequentist approach - see how tight the CI is around 0. __This method was criticized in one of the earlier papers as inconsistent.__

Bayesian method 1 - look at the inner 95% of the posterior. __Also inconsistent.__

Bayesian method 2 - look at the Bayes Factor. (This requires that the alternative hypothesis has a specified effect size).

Differing effect sizes in conceptual replications don't necessarily require explaining, the difference might not be significant anyway.

Examples of cases where many low-powered experiments all had CIs contain 0, but their combined data did not.

__Arguments here don't seem to address the other results in OSC eg lower effect sizes.__

__Seems to be really focused on decision procedure for accepting the literal null hypothesis. Can we just estimate the effect size instead, and if it looks small decide we don't care?__

## [Negative results are disappearing from most disciplines and countries](http://link.springer.com.sci-hub.cc/article/10.1007/s11192-011-0494-7)

Sampled 4656 at random from 10800 journals published between 1990 and 2007. 

Increase in positive results from 70% in 1990 to 86% in 2007. Looks very roughly linear. 

Controlling for discipline, domain, methodology, country and single vs multiple results has little effect.

Space science and neuroscience show slight decline over the years. __Doesn't that contradict the previous statement?__

Strongest increases in medicine/pharmacy area. 

__Graphs for individual subjects are really noisy.__

Hypotheses:

* Theories are more likely to be true. Perhaps publish-or-perish makes scientists play it safe and only test theories they are confident in.
* Statistical power has increased, so discovery of true relationships increases. Cites evidence against this.
* Publication bias causes negative results to be published less, or turned into positive results by post-hoc analysis, or buried in papers with at least one positive result.

## [Why most published research findings are false](http://journals.plos.org/plosmedicine/article/file?id=10.1371/journal.pmed.0020124&type=printable)

Create a simple model that calculates prior odds of a published result being correct. Plug in reasonable numbers for various fields and see that posterior odds are miniscule.

__Main contributor is low prior odds of a given hypothesis being correct - what if we take into account exploratory and pilot studies that are used to select hypotheses for the actual published findings?__

If prior odds are very low, large effect sizes and small p-values are, counter-intuitively, more likely to be caused by bias than by true results.

__Interesting to think about specificity of hypotheses. Imagine a measure over the field of possible hypotheses. Given a blank slate, we should prefer to run experiments that test large swathes of the space. Testing a small, specific part of the space would be premature.__

Can run high-powered, low-bias experiments on established findings as a way to estimate prior odds and bias for a given field.

## [Bias-Correction Techniques Alone Cannot Determine Whether Ego Depletion is Different from Zero](https://poseidon01.ssrn.com/delivery.php?ID=335074111074015067108111125095104073109017024072035030106079023111120085009067083107037033035060058099112005015102025098125100062066043049061127117119003094102012067086029023124124089098082119066106099030080031028106126118072071073030113002024117009091&EXT=pdf)

Smaller sample sizes should lead to more variance in measured effect size but around the same true center. If experiments with smaller sample sizes in fact show larger effect sizes, we can use this as a measure of bias. Several techniques exist using this idea to correct for bias in meta-analysis.

Conducted a range of simulations with different effect sizes, aiming to mimic conditions in social psychology.  Standard non-corrected meta-analysis performed worst. PET performed poorly. PEESE, Trim&Fill and Top10 each did well in certain regions and poorly in others.

Recommends against using PET.

Recommends using a variety of methods to check for agreement. 

Probably better to focus on registered replications for reducing bias rather than trying to correct for it.

## [Meta-analyses are no substitute for registered replications: a skeptical perspective on religious priming](http://journal.frontiersin.org/article/10.3389/fpsyg.2015.01365/full)

Existing meta-analysis with Trim&Fill shows effect. Re-analysis with PET and PEESE shows no effect. Re-analysis with Bayesian Bias Correction shows effect. 

Criticisms of original meta-analysis: 

* Trim&Fill assumes bias is driven by low effect size - seems more likely to be driven by p<=0.05
* Unclear selection method
* Some relevant negative results seem to be missing, and there is a strong negative correlation between effect size and sample size in the selected papers
* Didn't control for existing known moderators
* Unlikely number of CIs in selected papers fall just above 0

Notes that bias correction can only correct for certain simple kinds of bias eg withholding papers with low effect sizes. Can't possibly correct for eg systematic experimenter bias.

## [The rules of the game called psychological science](http://pps.sagepub.com.sci-hub.cc/content/7/6/543.full.pdf+html)

Treat publishing as a game. The many-small-studies strategy dominates the one-big-study strategy in fields where the effect sizes are small. 

Simulates each strategy with different effect sizes. Compare funnel plots to published meta-analyses. 

> We found indications of bias in nearly half of the psychological research lines we scrutinized

__Somewhat unfocused paper. Not really sure what it's adding to the discussion.__

## [Scientific utopia II. Restructuring incentives and practices to promote truth over publishability](http://pps.sagepub.com.sci-hub.cc/content/7/6/615.full.pdf+html)

Incentive design.

Notes that pharma labs attempt many more replications than academia, because they are incentivized to weed out false positives before they become expensive. 

Things that won't work:

* Creating journals for negative results will not work, because they will accrue no prestige. 
* Decades of education and discussion have not changed behaviour.
* Can't rely on peer review - too overworked and not enough information in the paper itself to catch most questionable practices.
* Requiring replication before publishing results might work, but publishing is hard and slow enough as is. Might stifle creativity and put further pressure on researchers.

Things that might work:

* Paradigm-driver research - making small, controlled changes to established methods rather than designing each experiment from scratch. Builds replication into work that also finds publishable new results. __Not really clear how this fixes the problem.__
* Author, reviewer and editor checklists. Effective nudge towards good practices eg reporting effect sizes.
* Challenge the mindset. Based on anecdotal data, the author suspects that publish-or-perish is actually not as strong as force as young postgrads are led to believe.
* Crowd-sourcing replications eg OSC. Helps with limited resources. __But the total resource pool is still the same. This just redistributes effort. Not necessarily a bad thing, but not a clear win either.__
* Peer review based on soundness rather than perceived importance eg PLoS ONE. No need for page limits any more, can simply publish everything that meets the bar.
* Post-publication review - decouple making results available from judging their quality.

Ideal:

* Release all data so it can be independently analyzed
* Publish methodology in sufficient detail for accurate replication. Eg publish videos of experimental procedure.
* Record and publish workflow in real-time in a non-revocable manner. Registered experiments are just the start.

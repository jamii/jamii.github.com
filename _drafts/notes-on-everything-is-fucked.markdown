---
layout: "post"
title: "Notes on 'Everything is fucked'"
date: "2016-11-30 17:18"
---

Sanjay Srivastava posted a syllabus for a course called [Everything is fucked](https://hardsci.wordpress.com/2016/08/11/everything-is-fucked-the-syllabus/). The course itself is a joke, but the reading list seems worthwhile.

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

---
layout: post
title: 'Notes on ''The Rationality Quotient: Toward a Test of Rational Thinking'''
date: '2017-03-15 16:51'
---

<https://smile.amazon.com/gp/product/B01M19F7A6/>

__Followup to [What Intelligence Tests Miss](http://scattered-thoughts.net/blog/2016/01/29/notes-on-what-intelligence-tests-miss-the-psychology-of-rational-thought/).__

## Model

__Tripartite model seems largely the same as previous book.__

Innate responses tend to be efficient and normative in environments that aren't actively hostile. Arguable that modern environments are *often* actively hostile and deliberately try to exploit edge cases in heuristics eg marketing, politics.

Normative response in hostile environment requires that the correct mindware is available, either innate or installed. Zones of mindware instantiation:

* Low. No chance of normative response.
* Medium. Requires detecting non-normative response, initiating and sustaining System 2 override.
* High. Normative response provided by System 1.

In middle zone, normative response is gated on sustaining override, which we already believe to be strongly correlated with IQ. Also suspect that mindware acquisition is related to IQ. So any rationality test is going to strongly correlate with IQ.

Taxonomy of thinking errors:

* Miserly processing
  * Default to the autonomous mind (eg bat and ball)
  * Failure of sustained override (eg willpower failure, 'going with my gut', syllogism test)
  * Default to serial associative cognition with focal bias (eg passively accepting the frame, WYSIATI)
* Mindware problems
  * Contaminated mindware (eg superstitious beliefs)
  * Mindware gaps

__Should failure to correctly execute mindware come under it's own heading? Eg if I know about Bayes rule but the calculations are too complicated to carry out in my head.__

Can arrange CART subtests on two axes: knowledge dependence (mindware) and processing requirements (detect + initiate + sustain).

* High knowledge + high processing eg probabilistic reasoning, scientific reasoning
* High knowledge + low processing eg financial literacy, risk knowledge
* Low knowledge + high processing: eg disjunctive reasoning, framing
* Low knowledge + low processing: thinking dispositions scale, most daily activities

__There are a bunch more charts and taxonomies and flowcharts and they don't all seem to agree. Feels a little muddy.__

Emphasizes that all of this so far is conjecture from limited evidence. Have to start somewhere.

## Tests

Probabilistic and statistical reasoning:

* Base rate neglect.
* Conjunction fallacy.
* Gamblers fallacy.
* Insensitivity to sample size.
* Regression to the mean.
* Probability matching (for a biased coin p>0.5 should always bet heads, not bet heads p and tails 1-p).

(Very generous range of accepted answers - focus on getting the right magnitude or direction)

Scientific reasoning:

* Ignoring `P(D|~H)`.
* Hypothesis testing and falsification (4 card test).
* Covariation detection.
* Controlling variables (everything except 'change all the variables' is marked correct).
* Converging evidence (judging cumulative result of multiple experiments).

Avoidance of miserly information procession (direct):

* Reflection vs intuition (bat-and-ball style questions)
* Belief bias in syllogisms (with a tricky correction - there is also a bias to just agree)
* Ratio bias (choose from two bowls with different distributions)
* Disjunctive reasoning (eg is a married person looking at an unmarried person).

Avoidance of miserly information procession (indirect):

* Avoiding framing (consistent response to different frames at different times)
* Avoiding anchoring (rather than consistent response, scored generously against 3rd-party calibration)
* Avoiding preference anomalies (both tests seem to be framing tests - don't violate dominance across multiple questions, but with different framings)
* Avoiding myside bias (looks at correlation between how subjects rate an argument and their own prior beliefs, seems weak eg might expect prior beliefs to be based on how much they agree with common arguments)
* Avoiding overconfidence (scored by mean confidence - mean correctness)
* Temporal discounting (scored based on interest rates of short-term loans)

Knowledge tests:

* Probabilistic numeracy (math test)
* Financial literacy and economic knowledge (US- and adult- centric)
* Sensitivity to expected value (gambling questions with easy math and small stakes)
* Risk knowledge (estimate rates of common risks).

Contaminated mindware:

* Superstitious thinking (do you believe in astrology etc)
* Antiscience attitudes (self-reported)
* Conspiracy beliefs (balance of popular conspiracies from left and right, doesn't correlate with political beliefs or voting history, US centric)
* Dysfunctional personal beliefs (self-reported, eg excessive perfectionism or concern with social acceptance, no example questions shown)

Dispositions and attitudes:

* Actively open-minded thinking (willingness to consider different viewpoints and update based on evidence)
* Deliberative thinking (?)
* Future orientation (?)
* Differentiation of emotions (based on existing tests for inadequate behavioral regulation due to inability to use emotional associations to filter possible actions)
* Impression management (concern with opinions of others)

(All self-reported. Differs from other tests in that it's not a 'more is better' test, so not folded into final score. BUT most people are probably short of optimum point in modern environment and there are interesting correlations with other tests.)

__Skipping much of the detail on scoring mechanisms - not very compressible and hard to assess.__

## Results

CART takes up to 3 hours. Tested on 350 paid volunteers in lab, and 397 mechanical turkers. Includes self-reported SAT score, missing for half of the turkers. Turkers also took a short cognitive ability test, focused mostly on verbal.

Short-form CART up to 2 hours. Keeps core reasoning, contaminated mindware, numeracy and AOM thinking tests. Skips knowledge-heavy, non-AOM disposition and difficult-to-score tests. Includes self-reported SAT score. Tested on 372 uni students.

__Skipping much of the detail on results - hard to assess without a particular question in mind.__

Used multiple regression to compare SAT score and AOT score as predictors of other tests. Surprisingly, on many of the tests they get similar beta weights. AOT is a better predictor of full CART score. AOT didn't correlate strongly with impression management test (__but impression management test is also self-reported?__).

Principle component analysis is not super revealing. Groups into, roughly: most of the actual tests, the self-reported mindware contamination tests, other stuff.

Students in later years score significantly higher. Makes sense - much of that mindware is supposed to be taught in uni.

Gender difference in scores exist after controlling for cognitive ability and years of education. Female scores significantly higher on temporal discounting. Male scores significantly higher on prob/stat reasoning, reflection vs intuition, practical numeracy, financial literacy / economic knowledge. __Cognitive ability scores were higher in general for males, so not sure how much to trust the controlling. Sounds similar to the gender gap across different STEM subjects.__

Correlation between full and short CART was 0.97. Severely shortened 38-point test made of prob/stat reasoning and scientific reasoning correlates 0.79 with remaining tests and 0.88 with full CART, and has significant betas when regressed alongside cognitive ability and AOT.

## Context

CART aims to be broad rather than deep, so chooses cheap subtests rather than the best known test of each aspect.

Compares CART to Decision-Making Competence Scale for Adults and Halpern Critical Thinking Assessment. Argues A-DMC is heavily process loaded. Most A-DMC tests are also tested in CART. Social norm test is not in CART because it doesn't fit in their tripartite model of rationality. CART mostly dominates HCTA in coverage, excluding the real-world problem solving section which is arguably hard to score objectively.

Notes that their samples are pretty non-representative of the general population. But most potential uses of the CART would at least be on university-educated subjects.

Notes that the correlations with cognitive ability might be increased by adapting existing tests to be within-subject rather than between-subject - higher ability subjects are more likely to notice the structure of the test.

CART vs Great Rationality Debate. Argues that System 2 is more aligned to the persons overall goals, so override should generally be preferred. __My System 2 is maybe more aligned to what I think my goals are - that doesn't mean that it's more likely to maximize my happiness or satisfaction. Sometimes my conscious goals are dumb.__ Also, subjects often retrospectively endorse the normative response and the axiom behind it.

Thin rationality - make choices that maximize your values/goals/desires. Broad rationality - are your values/goals/desires dumb? CART focuses on thin notion of rationality to avoid grappling with unsolved philosophical questions.

Justifies relatively low (0.75 and 0.67) reliability of prob/stat and scientific reasoning tests - they are an amalgam of different skills and mindwares, rather than a single skill/mindware that is tested in multiple ways. No reason to expect something like a g factor for rationality - too many independent supporting skills and mindwares. Eg teaching someone about Bayes rule should not be expected to improve their temporal discounting score. Might still be high correlations between skills, which is useful for quickly measuring but still need to test all skills if you care about improving rationality.

Many tests they would like to include were just too unwieldy to administer (eg requiring multiple testing sessions) or had normative responses that were still under dispute (eg unrealistic optimism).

Correlation with IQ is 0.50 for short-form and 0.69 for full-form. Would be happy to find that the CART only measure intelligence, because it would mean that intelligence could be measured with a test that has more obvious real-world applicability than eg obscure vocab questions and so would be more widely accepted. Also plenty of room for dissociation in there eg reading comprehension correlates with IQ at 0.6-0.7 but we treat dyslexia (high IQ, low reading comprehension) as a useful concept.

Possibly susceptible to coaching effects but argues that coaching for CART (at least the non-self-reported parts) should also increase rationality.

## Thoughts

__This predictive power of the AOT test is really weird! Self-reported open-mindedness is a good predictor on all the hard tests, including numerical reasoning, even when controlling for SAT score. Is using multiple regression like this legit? Are we just measuring a correlation with IQ or education or studiousness? Or is an open-minded disposition a result of being better able to examine and suppress gut reactions to new ideas? Also, AOT is not supposed to be a more-is-better test but it sure looks like one. Is the average student just very close-minded?__

__The previous book hammered pretty strongly on the idea that various rationality subtests had low correlation with IQ. This book seems to be walking that claim back a little. The CART has been [criticized](https://pbs.twimg.com/media/C14rrdEW8AAdLmm.jpg:large) for it's strong correlation with IQ compared to the original framing of rationality being largely orthogonal to IQ ie 'smart people acting dumb'. I think Stanovich's explanation is reasonable and it seems valuable to attempt to expand IQ tests to include hostile environments.__

__A more compelling criticism for me is that they intend their tests to be typical conditions rather than maximal conditions, but to anyone with any relevant education most of the questions clearly signal what is being tested. The fact that I can apply Bayes law in a clearly coded test question does not mean that I will habitually detect real-life situations that require it. The CART is very much a maximal condition test for me.__

__Still, if I was hiring for a position where rationality was important I would probably be tempted to administer at least the short-form CART, for exactly the reasons that Stanovich discusses at the end - even if it's basically an IQ test, it's an IQ test in a form that is more clearly relevant to on-the-job performance.__

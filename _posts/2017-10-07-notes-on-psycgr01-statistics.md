---
layout: post
title: 'Notes on ''PSYCGR01: Statistics'''
hidden: true
---

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  tex2jax: {inlineMath: [['$','$'], ['\\(','\\)']]}
});
</script>
<script type="text/javascript" async
  src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=TeX-MML-AM_SVG">
</script>

<https://www.ucl.ac.uk/lifesciences-faculty-php/courses/viewcourse.php?coursecode=PSYCGR01>

> This course provides a thorough introduction to the General Linear Model, which incorporates analyses such as multiple regression, ANOVA, ANCOVA, repeated-measures ANOVA. We will also cover extensions to linear mixed-effects models and logistic regression. All techniques will be discussed within a general framework of building and comparing statistical models. Practical experience in applying the methods will be developed through exercises with the statistics package SPSS. 

## [Lecture 1](https://moodle.ucl.ac.uk/course/view.php?id=11131)

Ignore cookbook approach, do model comparison.

General linear model.

Inference as attempted generalization from sample to population (__non-Bayesian?__).

Want estimators to be:

* Unbiased - expected value is true value
* Consistent - variance decreases as sample size increases
* Efficient - smallest variance out of all unbiased estimators

Efficient estimators:

* Count of errors -> mode
* Sum of absolute errors -> median
* Sum of squared errors -> mean

$MSE = \sum (Y_i - \hat{Y}_i)^2 / n - p$. TODO Why degrees of freedom?

Review:

* What is inference?
* Three desirable properties of estimators.

## [Lecture 2](https://moodle.ucl.ac.uk/course/view.php?id=11131&section=2)

Model is model of population (__which implies that we can include sampling method in inference if we think we can accurately model the bias__).

Sum of squares reduced $SSR = \operatorname{SSE}(C) - \operatorname{SSE}(A)$

Proportional reduction in error $PRE = \frac{\operatorname{SSE}(C) - \operatorname{SSE}(A)}{\operatorname{SSE}(C)}$. On population is usually denoted $\eta^2$.

F-score for GLM: $F = \frac{\mathrm{PRE} / (\mathrm{PA} - \mathrm{PC})}{(1-\mathrm{PRE})/(n - \mathrm{PA})} \sim F(\mathrm{PA} - \mathrm{PC}, n - \mathrm{PA})$

F-test: reject null if $P_\mathrm{null}(F > F_\mathrm{observed}) < \alpha$. Fixes $P_\mathrm{null}(\mathrm{Type1}) = \alpha$. Produces tradeoff curve between $P_\mathrm{null}(\mathrm{Type2})$ and real effect size.

95% confidence interval of estimate = on 95% of samples, confidence interval falls around true population value = reject null if (1-$\alpha$) confidence interval does not contain null.

Review:

* Define f-score.
* Define f-test.
* Define confidence interval.

## [Lecture 3](https://moodle.ucl.ac.uk/course/view.php?id=11131&section=3)

Multiple regression.

Test for unique effect of $X_i$ by comparing with model where $\beta_i=0$.

Omnibus test - testing multiple parameters at once. Prefer tests where $PA - PC = 1$ - easier to interpret success/failure.

$R^2$ - squared multiple correlation coefficient - 'coefficient of determination' - 'proportion of variance explained' - PRE of model over $Y_i = \beta_0 + \epsilon_i$.

$\eta^2$ - true value of PRE in population. Unbiased estimate $\hat{\eta}^2 = 1 - \frac{(1 - \mathrm{PRE})(n - \mathrm{PC})}{n - \mathrm{PA}}$.

Conventionally:

* Small effect $\eta^2=.03$
* Medium effect $\eta^2=.13$
* Large effect $\eta^2=.26$

$1-\alpha$ confidence interval for slope $b_j \pm \sqrt{\frac{F_{1,n-p;\alpha}\mathrm{MSE}}{(n-1)S^2_{X_j}(1-R^2_j)}}$ where:

* $\mathrm{MSE} = \frac{\mathrm{SSE}}{n-p}$
* Sample variance $$S^2_{X_j} = \frac{\sum_{i=1}^n(X_j,i - \bar{X}_j)^2}{n-1}$$
* $$R^2_j$$ is PRE of model $$X_{j,i} = b_0 + \prod_{k \neq j} b_k X_{k,i} + e_i$$ vs model $$X_{j,i}=b_0 + e_i$$ (proportion of variance of $$X_j$$ that can be explained by other predictors) 

$(1 - R^2_j)$ also called tolerance - how uniquely useful is $X_j$

Model search:

* Enter - add variables in blocks
* Forwards - start with best predictor, keep adding next best until PRE not significant
* Backwards - start with all, keep removing worst until PRE becomes significant
* Stepwise - forwards but may also remove parameters that fall beneath some threshold

Better to rely on theory

Note, for null model $Y_i = b_0 + \epsilon $ we get $SSE = (n - 1)\operatorname{Var}(Y_i)$

## [Lecture 4](https://moodle.ucl.ac.uk/course/view.php?id=11131&section=4)

GLM assumptions:

1. Normality - $\epsilon_i \sim Normal$
  * Biased predictions
2. Unbiasedness - $\epsilon_i$ has mean 0
  * Biased test results
3. Homoscedasticity - $\epsilon_i$ has constant variance (per i)
  * Unbiased parameter estimates (__?__)
  * Biased test results
4. Independence - $\epsilon_i$ are pairwise independent
  * Model mis-specification

Histogram of residuals should be roughly normal (1).

Should be no relationship in residual vs predicted graph (2,3).

Quantile-quantile plot - $Y_i$ vs $Q_i$ where $Q_i$ s.t. $P(Y \leq Q_i) = \hat{p}_i \approx p(Y \leq Y_i)$ ie quantiles vs cdf of normal distribution. If $Y_i$ are normal than should be roughly straight.

Shapiro-Wilk or Kolmogorov-Smirnov tests for normality.

Breush-Pagan or Koenker or Levene test for homoscedasticity.

Randomized control or sequential dependence test for independence.

Transform dependent variables to achieve 1,3. Transform predictor to achieve 2.

Outlier detection:

* Mahalanobis distance - distance of data point from center
* Leverage - weight of data point in parameter estimate
* Studentized deleted residual - ?
* Cook's distance - does omission of a data point change model predictions

Outlier tests run on all data points, so need multiple comparison correction.

Multicollinearity - as $R^2_j \xrightarrow 1$ the confidence interval $\xrightarrow \infty$. Detection:

* Tolerance or variance inflation factor
* Correlation matrix

Partial correlation between $Y$ and $X_i$ is $\operatorname{sign}(\beta_i) \sqrt{\operatorname{PRE}(M, M-X_i)} = \frac{\operatorname{PRE}(M, NULL) - \operatorname{PRE}(M - X_i, NULL)}{1 - \operatorname{PRE}(M - X_i, NULL)}$ 

## [Lecture 5](https://moodle.ucl.ac.uk/course/view.php?id=11131&section=5)

Moderation

* Effect of $X_1$ varies depending on value of $X_2$ 
* Fit $Y \sim \beta_1 X_1 + \beta_2 X_2 + \beta_3 X_1 X_2$
* Formula for confidence interval is same as simple model
* Center predictors for moderation
  * Easier to interpret
  * Reduces redundancy between $X_1$ and $X_1 X_2$ but does not change confidence interval of $\beta_3$, as long as we have simple parameters ($\beta_1$ and $\beta_2$)
    * This is true of any linear change to parameters

Mediation (cf [Mediation Analysis](https://sci-hub.bz/http://www.annualreviews.org/doi/abs/10.1146/annurev.psych.58.110405.085542)):

* Want to separate direct effect of $X_1$ on $Y$ vs indirect effect via effect on $X_2$
* Fit $$
M = i_1 + aX + e_1\\
Y = i_2 + cX + e_2\\
Y = i_3 + dX + bM + e_3
$$
* Casual steps procedure
  * Test a is significant vs null
  * Test c is significant vs null
  * Test b is significant vs without b
  * Test d is not significant vs without d
  * Often low power
* Sobel test:
  * Test $Z = ab \sim Normal$
  * $Z \sim Normal$ is often a poor approximation - use simulation instead
* [Structural Equation Modeling](https://en.wikipedia.org/wiki/Structural_equation_modeling)

__Caution - [Don't Expect An Easy Answer](http://www2.psych.ubc.ca/~schaller/528Readings/BullockGreenHa2010.pdf)__

## [Lecture 6](https://moodle.ucl.ac.uk/course/view.php?id=11131&section=6)

ANOVA - analysis of variance - modeling differences between group means.

Null model = same means.

Contrast codes:

* Want to compare against a null-model where the parameters are restricted to some hyperplane, but analytic solution to GLM can only handle axis-aligned hyperplanes.
  * Eg 2x2 control/diet x male/female. 'Diet effect does not vary between male/female' is equiv to 'control/male - diet/male = control/female - diet/female'
* Solution: change to basis - $Y = A + BLX$
* Rows of $L$ should be orthogonal
  * Avoids introducing spurious correlations in transformed data
  * Otherwise can't interpret as difference of means - null hypothesis is same but error is split differently across parameters
  * Allows partitioning out $SSR$ due to each parameter (because SSR is linear function of group means)
    * For given row $\lambda$, comparing against model without that parameter reduces to $\mathrm{SSR} = \frac{(\sum_k \lambda_k \bar{Y}_k) ^2}{\sum_k (\lambda_k^2 / n_k)}$
* If a row sums to 0, parameter can be interpreted as difference of means ([source](http://journals.sagepub.com/doi/full/10.1177/0013164416668950)). 
* Formula for confidence interval is same as simple model
* To test for differences between means of $m$ groups, can use $m-1$ orthogonal rows
  * Gives $b = \frac{\sum_k \lambda_k \bar{Y}_k}{\sum_k \lambda_k^2}$
  * (__Means $L$ does not have rank n - can't reconstruct original parameters - is this ok?__)
  
Ways to generate contrast codes:

* Helmert codes - $\lambda_{i,i} = m-i$ and $\forall j > i \ldot \lambda{i,j} = -1$
* 

Tukey-Kramer to test all possible pairs of groups.

## [Lecture 7](https://moodle.ucl.ac.uk/course/view.php?id=11131&section=7)

ANCOVA - analysis of covariance - same as ANOVA but with continuous as well as categorical predictors.

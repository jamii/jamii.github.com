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

Omnibus test - testing multiple parameters at once.

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
2. Unbiasedness - $\epsilon_i$ has mean 0
3. Homoscedasticity - $\epsilon_i$ has constant variance (per i)
4. Independence - $\epsilon_i$ are pairwise independent

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

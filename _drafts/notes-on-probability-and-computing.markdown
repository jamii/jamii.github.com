---
layout: "post"
title: "Notes on 'Probability and Computing'"
date: "2017-01-14 12:06"
---

### 1. Events and Probability

Measures. Inclusion/exclusion principle. Independence. Conditional probability. Principle of deferred decisions. Law of total probability. Bayes law.

Algorithms with one-sided error can be amplified by running multiple times. 

$1-x<=e^{-x}$ often useful when encountering $(1-p)^n$.

### 2. Discrete Random Variables and Expectation

Random variables. Discrete - take on only countable number of values. Mutual independence. Expectation.

Expectation is linear even over non-independent variables. Use linear decomposition of random variables to simplify calculation.

Jensen's inequality: $E[f(X)] > f(E[X])$ for convex $f$. Intuition: with two points, $f(E[X])$ is on curve, $E[f(X)]$ is on line joining points, convex f => curve is below line. Alternative intuition: find some line g under curve at $E[X]$ (eg via Taylor expansion if differentiable), f(X) >= g(X), so $E[f(X)] >= E[g(X)] = g(E[X]) = f(E[X])$. Convex = superlinear.

Conditional expectation. Law of total expectation: $E[Y] = E[E[Y|Z]]$.

When $Im(X) \subset \mathbb{N}_0$ then $E[X] = \sum_{i=1}^\infty Pr(X \geq i)$ 

Harmonic number $H(n) = \sum_{k=1}^n 1/k \in [\ln(n), \ln(n) + 1]$

TODO 16b 

<script type="text/javascript" async
  src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=TeX-MML-AM_CHTML">
</script>

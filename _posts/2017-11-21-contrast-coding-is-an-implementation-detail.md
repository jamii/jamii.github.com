---
layout: post
title: Contrast codes are an implementation detail
---

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  tex2jax: {inlineMath: [['$','$']]}
});
</script>
<script type="text/javascript" async
  src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=TeX-MML-AM_SVG">
</script>

I found [contrast codes](https://en.wikipedia.org/wiki/Contrast_(statistics)) really confusing on first contact. In hindsight, this is because they are typically presented as being part of the model, but it seems much more ergonomic to me to consider them part of the inference algorithm, as I'll explain here.

If you haven't encountered contrast codes before - good. Stay there. You are not missing out.

If you have encountered contrast codes and are confused, maybe this will help.

Let's set the scene. A typical instance of the [General Linear Model](https://en.wikipedia.org/wiki/General_linear_model) looks like this:

\begin{align}
y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix} \begin{pmatrix}x_1\\\x_2\end{pmatrix} + e
\end{align}

Where $\begin{pmatrix}b_1 & b_2\end{pmatrix}$ is chosen to minimize error on the training data.

We want to ask questions like:

* Q1: Is knowing $x_1$ useful if we already know $x_2$?

We can answer this by comparing the prediction accuracy of this model against a simpler model:

\begin{align}
\text{full model: } & y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix}\begin{pmatrix}x_1\\\x_2\end{pmatrix} + e \cr
\text{null model: } & y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix}\begin{pmatrix}x_1\\\x_2\end{pmatrix} + e \text{ where } b_1 = 0 \cr
\end{align}

* Q1*: Does assuming that $x_1$ has no effect ($b_1 = 0$) lead to less prediction error on unseen data?

The null model is a restricted version of the full model, so it will always have at least as much error on the training data as the full model. But if that is purely due to over-fitting then the null model will probably have less error on as-yet unseen data than the full model will.

Unfortunately in many fields we [usually don't have enough data](http://datacolada.org/20) to begin with, so we can't afford to leave any data unseen. Instead we ask a different question:

* Q2: If reality behaved exactly according to the fitted null model, what is the probability that the full model would have this much less error on the training data?

In this case we can give an exact analytic answer to Q2. (Whether that answer has any bearing on the answer to Q1 is another, much more complicated matter).

So where do contrast codes come in?

Suppose we are testing a drug and measuring some patient outcome $y$. We want to know the answer to:

* Q1: Do patients in the treatment group have better outcomes than patients in the control group?

If we code the data as $X=\begin{pmatrix}1\\\0\end{pmatrix}$ for subjects in the treatment group and $X=\begin{pmatrix}0\\\1\end{pmatrix}$ for subjects in the control group, we can rephrase this question as:

\begin{align}
\text{full model: } & y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix}\begin{pmatrix}x_1\\\x_2\end{pmatrix} + e \cr
\text{null model: } & y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix}\begin{pmatrix}x_1\\\x_2\end{pmatrix} + e & \text{ where } b_1 = b_2 \cr
\end{align}

* Q1*: Does assuming that the treatment group and the control group have the same outcome distribution ($b_1 = b_2$) lead to less prediction error on unseen data?

Again, answering this question is hard so we're going to substitute a different question:

* Q2: If reality behaved exactly according to the fitted null model, what is the probability that the full model would have this much less error on the training data?

Unfortunately the nice analytic answer __only works for constraints of the form $b_i = 0$__. To apply it here, we need to [transform the data](https://en.wikipedia.org/wiki/Change_of_basis) so that our model has the correct form:

\begin{align}
L & = \begin{pmatrix}1 & {-1}\\\1 & 1\end{pmatrix} \cr
\text{full model: } y & = a + \begin{pmatrix}c_1 & c_2\end{pmatrix} L \begin{pmatrix}x_1\\\x_2\end{pmatrix} + e  \cr
  & = a + \begin{pmatrix}c_1 & c_2\end{pmatrix} \begin{pmatrix}x_1 - x_2\\\x_1 + x_2\end{pmatrix} + e  \cr
\text{null model: } y & = a + \begin{pmatrix}c_1 & c_2\end{pmatrix} L \begin{pmatrix}x_1\\\x_2\end{pmatrix} + e & \text{ where } c_1 = 0 \cr
& = a + \begin{pmatrix}c_1 & c_2\end{pmatrix} \begin{pmatrix}x_1 - x_2\\\x_1 + x_2\end{pmatrix} + e & \text{ where } c_1 = 0 \cr
\end{align}

Now we can apply the same analytic solution as before.

The rows of $L$ are called __contrast codes__. But where do they come from? Well, I picked $\begin{pmatrix}1 & {-1}\end{pmatrix}$ for the first row because I wanted to restrict the null model to $(1)b_1 + (-1)b_2 = 0$, and I picked whatever second row would make $L$ invertible.

Since the rows of $L$ are orthogonal, we can interpret the confidence interval of $c_1$ as the confidence interval of the difference between the mean outcome in the control group and the mean outcome in the treatment group, which is exactly what we care about. (If the rows were not orthogonal the difference would get spread out across $c_1$ and $c_2$. Equivalently, the confidence intervals for $c_1$ and $c_2$ would not be independent.)

Additionally, since $L$ is invertible there is a 1-1 mapping between the transformed model and the original model:

\begin{align}
& \begin{pmatrix}b_1 & b_2\end{pmatrix} = \begin{pmatrix}c_1 & c_2\end{pmatrix} L \cr
& \begin{pmatrix}b_1 & b_2\end{pmatrix} L^{-1} = \begin{pmatrix}c_1 & c_2\end{pmatrix} \cr
\end{align}

(It doesn't seem to be common to care about this though - I see many examples of non-invertible contrast codes.)

Importantly, none of this changes the fact the comparison we actually care about is still:

\begin{align}
\text{full model: } & y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix}\begin{pmatrix}x_1\\\x_2\end{pmatrix} + e \cr
\text{null model: } & y = a + \begin{pmatrix}b_1 & b_2\end{pmatrix}\begin{pmatrix}x_1\\\x_2\end{pmatrix} + e \text{ where } b_1 = b_2 \cr
\end{align}

Contrast codes are just an implementation detail by which we transform the comparison we care about into a comparison we can easily calculate the answer to. They don't belong in the interface. In a world where we cared about ergonomics in statistics, we would just write the model above and our stats library would take care of the transformation itself.

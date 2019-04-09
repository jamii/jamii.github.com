---
layout: post
title: Frugality is non-linear
---

Most people have a mental model of budgeting which is roughly linear. If you spend half as much money, your money will last twice as long. As you approach zero spending, your runway goes up to infinity.

In this model, the space of options looks like this:

<div style="width: 100%; display: flex; align-items: center; justify-content: center; padding-top: 1em;">
<div id="contour" style="width: 600px; height: 600px;">[I am an interactive graph made of javascript!]</div>
</div>

<div style="width: 100%; display: flex; align-items: center; justify-content: center; padding-top: 1em;">
  <label for="interest">Effective interest =&nbsp;</label>
  <input id="interest" type="text" style="width: 4em" value="0%">
</div>

This model is wrong.

It's wrong because your savings grow over time. If you change the interest rate above to 5%[^1], you can see that someone who has 500k in savings and spends 75k per year has a runway of 7 years. At 50k per year that extends to 13 years. But if they can cut their spending to 25k per year they have a runway of 62 years!

Effectively, including interest in the model moves the asymptote to the right - your runway goes up to infinity as your spending approaches some percentage of your total savings, rather than as your spending approaches zero.

I picked the examples above with a particular motive in mind. According to [Dan Luu's conservative estimates](https://danluu.com/startup-tradeoffs/) a fresh grad at a big tech company can safely earn ~$500k post-tax in 5 years. And the US median income post-tax is ~$25k. So as a tech worker, if you can manage to leave as 'frugally' as the average American, you can [comfortably retire](https://networthify.com/calculator/earlyretirement?income=120000&initialBalance=0&expenses=25000&annualPct=5&withdrawalRate=4) before 30.[^2]

In the midst of conversations about how to keep free software alive, how to keep the web open, how to prevent the constant erosion of privacy by adtech, how to protect our time and agency from manipulative skinner boxes - it seems useful to note that many of the people involved in the conversation are, by any normal standards, fabulously wealthy and if we all stopped buying $6 lattes we would have a great deal more leverage and autonomy.

---

[^1]: A fixed interest rate is unrealistic, but [simulations based on historical data](https://retirementplans.vanguard.com/VGApp/pe/pubeducation/calculators/RetirementNestEggCalc.jsf) produce similar results, and [retirement planning literature](https://www.kitces.com/wp-content/uploads/2014/11/Kitces-Report-March-2012-20-Years-Of-Safe-Withdrawal-Rate-Research.pdf) tends to put the asymptote at around 4-5% which is consistent with the simple model here.

[^2]: The numbers work out similarly in the UK. Salaries are lower, unless you can land a remote job, but free healthcare and lower cost of living make up a lot of the difference. I wouldn't be surprised if the same holds in most tech hubs.

<script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
<script src="/code/frugality-is-non-linear.js"></script>

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

It's wrong because your savings grow over time. If you change the interest rate above to 5%, you can see that someone who has 500k in savings and spends 75k per year has a runway of 7 years. At 50k per year that extends to 13 years. But if they can cut their spending to 25k per year they have a runway of 62 years!

Effectively, including interest in the model moves the asymptote to the right - your runway goes up to infinity as your spending approaches some percentage of your total savings, rather than as it approaches zero.

So halving your expenses can much more than double your runway. Or to put it another way - halving your expenses can much more than halve the number of years of your life you need to spend working.

---

I picked the examples above with a particular motive in mind. According to [Dan Luu's conservative estimates](https://danluu.com/startup-tradeoffs/) a fresh grad at a big tech company can safely earn ~$500k post-tax in 5 years. And the US median income post-tax is ~$25k. So as a tech worker, if you can manage to leave as 'frugally' as the average American, you can [comfortably retire](https://networthify.com/calculator/earlyretirement?income=120000&initialBalance=0&expenses=25000&annualPct=5&withdrawalRate=4) before 30.

In the tech industry we have some very loud voices arguing that if you desire autonomy or leverage, the best path forwards is to start a VC-backed startup. But reducing spending and saving towards early retirement has some compelling advantages:

* It's much more reliable - most startups fail, but most people who work at a large tech company make sufficient money to be able to retire early.
* Financial independence is a huge safety net - reducing stress and lowering the risk of later projects. If you still want to run a startup, doing it from a position of infinite personal runway will be a lot less stressful.
* By separating the means of earning money from the freedom you are pursuing, it enables pursuing goals in that under-served intersection of valuable but not profitable. Whether that's supporting free software, producing art or home-schooling your children, trying to fit such activities into a profitable enterprise inevitably produces uncomfortable compromises which can be avoided by removing the need to earn money.

The last point is particularly compelling if you have strong ethical/political/economic beliefs that would benefit from the leverage of financial independence. I'd like to see more independent people in general though, regardless of their personal beliefs, so I'll save the more contentious topics for a separate post.

---

### FAQ

__What about inflation?__ Inflation is essentially negative interest, so you can subtract it from the interest rate and then keep the rest of the calculations in today-dollars. 5% seems to be a reasonable

__What about volatility?__ I used a fixed average interest rate above, which doesn't tell you odds of running out of money early due to a string of bad years. [But simulations based on historical data](https://retirementplans.vanguard.com/VGApp/pe/pubeducation/calculators/RetirementNestEggCalc.jsf) produce similar results to those above, and [retirement planning literature](https://www.kitces.com/wp-content/uploads/2014/11/Kitces-Report-March-2012-20-Years-Of-Safe-Withdrawal-Rate-Research.pdf) tends to put the asymptote at around 4-5% which is consistent with the numbers above.

__What about crashes?__ The simulation linked above uses data that covers existing crashes, including the Great Depression. But in the event that they are overly optimistic, I think there is a strong argument that having large savings and cheap habits are useful for weathering a crash as having a filled-in employment history. Especially if you used the additional free time to build useful non-tech skills or strong communities.

__What about other countries?__ Dan Luu's article suggests that similar salaries are available in many major hubs. I've built a reasonably detailed model for my own situation in the UK and arrived at similar numbers. (Salaries are lower, unless you can land a remote job, but free healthcare and lower cost of living make up a lot of the difference.) It's worth at least running the numbers for your own country, just so you know what your options are.

__Hasn't the [FIRE community](https://en.wikipedia.org/wiki/FIRE_movement) already said all of this?__ Yes, but I very rarely see it discussed in tech circles, so it seems worth repeating. Also I haven't seen the calculation in terms of runway before, and the graph above improved my intuition on the subject.

<script src="https://cdn.plot.ly/plotly-1.47.0.min.js"></script>
<script src="/code/frugality-is-non-linear.js"></script>

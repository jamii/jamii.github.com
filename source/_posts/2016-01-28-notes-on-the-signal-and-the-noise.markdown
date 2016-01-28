---
layout: post
title: "Notes on 'The Signal and the Noise'"
date: 2016-01-28 14:40
comments: true
categories:
---

http://www.amazon.com/gp/product/B007V65R54

Why so many predictions fail - but some don't.

__Notes are sparse because this is mostly just long narratives.__

## Chapters

### More information, more problems

Invention of the printing press allowed knowledge to accumulate across generations for the first time. Previous methods of transmission (verbal, scribed) were error-prone and degraded over time.

The industrial revolution began largely in countries that had a free press. For the first time in history, per capita wealth begins to increase and living standards rise to match. __How strong is the link between printing press and industrial revolution?__

Computer revolution produced a temporary decline economic and scientific productivity, as measured by proxies such as research cost per patent filed. Took some time to realize that computers are not magical, and to figure out what they are good for and how to effectively use them.

New fashion for Big Data. Predicts a similar trend - currently hyped but will eventually crash and then finally level out, as we figure out what kind of problems Big Data is good for.

Prediction domains: weather, earthquakes, economy, medicine (2/3 of positive findings fail to replicate). In some of these fields there has been steady progress. In others there has been none. Why?

Availability of more information is not always good. Coupled with confirmation bias, gives more opportunities to fool yourself. Eg the more informed people are about global warming, the less they agree with each other.

New methods of communication spread misinformation just as fast as information - faster if it appeals to bias.

Cannot make objective predictions. Always tainted by perspective. Does not mean nihilism - indeed, pursuit of the objective truth is the vital first step. But the second step is to realize that you perceive the truth imperfectly.

### A catastrophic failure of prediction

Housing bubble. According to ratings, only 0.12% of CDOs were expected to default. In reality, 28% defaulted. Ratings agencies claimed 'noone could have seen this coming'.

Google searches for 'housing bubble' increased 10x from Jan 2004 to summer 2005. The phrase 'housing bubble' appeared in the new 8 times in 2001, but 3447 times in 2005 ie about 10x per day.

Ratings agencies were paid to rate CDOs, and customers would send more custom to the agencies that gave the best ratings. Clear misalignment of incentives.

A 2005 memo inside one agency simulated a crash of similar magnitude to what later happened, and concluded that there would be no problems.

Fault in their rating model was that it assumed odds of each mortgage defaulting were independent. Roughly true during good times, but not during crashes.

Risk - a danger with known odds eg most gambling games.

Uncertainty - a danger with unknown odds.

Ratings agencies presented systematic uncertainty as risk, which the banks then made presumed safe gambles on.

There have been very similar bubbles in other countries. Using that data for simulation would have predicted the risk.

Crash magnified by huge leverage, ~30x for major banks. Meaning that only need the price to drop by 1/30 to wipe out their safety margin and make lenders nervous.

In March 2007, Lehman Brothers still believed in a housing 'hiccup' and continued to invest.

Federal stimulus justified by a model showing projected unemployment rates with and without stimulus. Reality was far higher than either. If historic accuracy rates for such projection had been taken into account would have been much less convincing, but reality would have just fallen inside the range.

Prediction failures due to using out-of-sample data:
* Home owners predicted prices would continue to rise (there had never before been such a large boom in the US)
* Ratings agencies and banks failed to predict correlated default rates (they had never rated such novel and complex)
* Hardly anyone predicted that a US housing crisis could cause a global financial crisis (the financial system had never been so highly leveraged before)
* Economists and policy makers failed to predict the severity of the impact (financial crises causes more severe and long-lasting impacts than over economic crises)

Complex models can exhibit non-linear effects - small mistakes can cause huge mis-predictions.

Large amounts of data can exacerbate over-confidence. Intuitively feels like error should shrink with so much data, but we forget eg model error or sample error.

### Are you smarter than a television pundit?

Political pundits on a talk show make predictions, do no better than random.

Retells Tetlocks research on predicting fall of USSR and other major events.

Foxes and hedgehogs.

Hedgehog pundits making predictions did worse on questions where they had more info. Hedgehogs like to construct stories, and are confident if the story is coherent and fits well. More data gives them more details to cherrypick, making the story fit better and increasing their confidence.

FiveThirtyEight. Only impressive because the bar was set so low. Nate Silvers strategy in general is to pick areas where the bar is so low that improving it is easy. __Worth thinking about, in terms of future direction. What areas are sorely lacking in skills that I have?__

Principle 1: Think probabilistically. There is noise, and you must account for it.

Principle 2: Todays forecast is the first forecast for the rest of your life. Don't be afraid to change predictions in the face of new information.

Principle 3: Look for consensus. Being the lone dissenter who is proved right is rare. If you prediction is different from that of other similarly informed forecasters, you should worry.

Beware of magic bullets. Reality is complicated. Any model that claims to boil it down to a few variables should be regarded with suspicion.

Quantitative methods are not magical. Don't forget model error and sample error. Unknown unknowns can kill you.

Don't ignore qualitative information. Code it and use it. __Some research suggests using a structure approach where possible to enforce discipline eg interviewing candidates is more successful if the interviewer has a short list of attributes and records marks for or against on the spot.__

Improving objectivity is hard. Acknowledging that your view is subjective is the first step.

### All I care about is W's and L's

Baseball forecasting. Not just a matter of crunching numbers. Interpreting requires deep knowledge of the game and of player psychology. Scouts are still crucial for adding qualitative information to the pool - demonstrably improving forecasts.

### For years you've been telling us that rain is green

Weather forecasting has steadily improved over time. Non-linear system to increasing computational power has declining returns. Weather Service still uses human input - visual pattern matching for catching and correcting outliers - improves forecasts by 10% for temperature and 25% for precipitation.

How to judge a forecast service. Accuracy - how often is it correct. Honesty - was it the best forecast they could make, or was it tweaked for other reasons. Economic value - does it help people make better decisions.

Some commercial weather services optimize for number of angry customers rather than accuracy eg wet bias - increasing rain prediction from %5 to 20% because people get mad if you say 5% and then they get wet. Can detect this by looking at calibration curve.

Weather forecasts are less and less accurate over time, to the point that by 9 days out they are less accurate than just predicting historical averages. Possibly because of feedback loops in the model itself?

Many local forecast services are significantly worse than the national ones, and they don't care. Claim noone trust them anyway - kind of circular.

Many people refused to evacuate for Katrina. One of the reasons is that many people didn't believe the forecasted severity. Eroding trust in forecasts can cost lives.

### Desperately seeking signal

L'Aquila - taking scientists to court over failure to predict earthquakes.

No success in earthquake prediction so far. None likely any time soon.

Many examples of prediction systems looking good, but only as a result of over-fitting.

Do know that magnitudes in any given region follow a power law. This would have been sufficient to put small but frightening odds on the Fukushima earthquake happening at some point. Instead they overfit on a few datapoints near the end. Many rationalizations were given for why the model was different from the normal model eg unique rock composition of the area.

This is a common duality. In many system we cannot even theoretically predict individual events, but we can still easily predict stochastic trends.

### How to drown in three feet of water

Grand Forks flood. Predicted water level was just below levees. But uncertainty was not communicated - actual prediction showed 35% chance of topping the levee. Communicating uncertainty is vital.

Typical overconfidence story. Economists asked to make predictions with confidence ranges. Reality is way outside the ranges.

Many well-regarded indicators of economic health did not predict the 2007 recession despite working well for the previous two recessions. __Overfitting again?__. Also often give false alarms.

Goodhart's law - theory that once an economic measure is proposed it quickly loses it's value, as policy makers begin targeting it and artificially distort the signal. Observer effect.

Economy changes on long scale too. Incorrect models of the 2007 recession were calibrated on recent data, but from 1983 to 2006 the US saw uncharacteristic growth that may not be maintainable by any economy. Also no major recessions during this period. Models were calibrated on an outlier.

Data is not enough. Have to understand what's going on behind the data to know if you are in-sample. No amount of statistical magic would be able to make correct predictions from the 1983-2006 data.

Economic data is noisy too. Frequently gets major corrections years after the fact.

How can we reduce the bias in economic forecasts? Supply-side - create markets for good forecasts eg prediction markets. Demand-side - educate people to be able to judge forecaster accuracy.

### Role models

H1N1 outbreak in Fort Dix. Predictions that it would be widespread in the next flu season - secretary of health predicted that 1M Americans might die. Mass vaccination program for $180m.
That summer, no signs of H1N1 in southern hemisphere. Administration doubles down on vaccination with dramatic PSAs. ~500 vaccinees develop Guillan-Barre syndrome - 10x the rate in usual population. Program shut down. Never any other confirmed cases of H1N1.

Appeared decades later in Mexico with 1900 cases and 150 deaths. Huge reaction followed. But nowhere near as virulent when it hit US - normal numbers of deaths for flu season.

Cannot reliably estimate infection rate / death rate until disease is widespread, at which point it is too late. Forced to extrapolate from early cases. Reported fatality rate in Mexico was likely high because only severe cases were actually diagnosed.

Predictions can be self-fulfilling or self-cancelling when they interact with the system being predicted. Eg pandemic predictions may look alarmist because if they are early enough the pandemic is averted. Eg news reports of swine flu may have increased diagnose rate, exaggerating the real infection rate.

SIR model to simple. Eg serosorting in gay men in SF. Eg Fort Dix has higher R_0 than normal environments for any disease. Eg measle outbreak in Pittsburgh because, while population overall is vaccinated to the point of herd immunity, non-vaccinated people occur in clusters.

SimFlu - agent based simulation. Currently limited to 'modeling for insights' rather than prediction.

All models are wrong, but some models are useful. You have to simplify something to not just end up with a copy of the system.

### Less and less and less wrong

Anecdotes about a foxy sports bettor.

Bayes theorem.

Sometimes Bayes theorem shows you that the evidence is so huge that the prior barely matters.

False positives. More data = more hypotheses. Possibly correlations between variables increase quadratically with number of variables. But number of true hypotheses is constant. Harder to filter the signal from the noise.  __Not entirely convinced by this. Big Data also means many more samples of the same variable, which allows teasing out more subtle correlations.__

Rise of Frequentism. Fisher contended that the existence of the prior in Bayes rule allowed for bias. Frequentist statistics were supposed to remove that bias, but instead just hit it. Also does not allow accounting for bias in experiment selection.

Bayesian updates from any prior all converge towards truth as samples increase, just at different rates.

Currently starting to see progress away from significance testing as gold standard.

### Rage against the machines

Long discussion of how computers play chess. Key to beating a computer (back when they were beatable) was that they could look further but had worse heuristics, so push them into situations where they choose tactical wins that are also strategic losses.

A/B testing at google. Measure search query quality with survey team and train model on results.

### The poker bubble

Poker involves approximate Bayesian reasoning about opponents hand. Expert players attempt to exploit systematic mis-predictions in opponents eg confusing 'unlikely' and 'impossible'. Bluffing and aggressive play is on the rise - makes it harder to gain information from your actions.

Psychological challenge of professional poker. Luck has a huge effect, so actual skill is hard to see without many months of data.

### If you can't beat em...

Prediction markets and group predictions. Average forecast may be better than individual, but that's not the same as good. Group predictions only work well when predictions are independent (can be feedback loops in predictions markets). Some individuals may be better than the group forecast.

Efficient-market hypothesis. Variants:
* Weak. Stock market prices cannot be predicted from statistical analysis alone.
* Semistrong. Predictions using only public ally available information cannot consistently beat the market.
* Strong. Predictions using even insider information cannot consistently beat the market.

So why does so much trading happen if it's not profitable?

Strong form is empirically false eg members of Congress consistently get returns 5-10% higher than market averages.

Addendums to efficient market - cannot consistently beat the market on risk-adjusted gains after transaction costs.

Bubbles happen. They can maybe be predicted eg by P/E ratios. But making money from them is difficult for technical reasons. "The market can stay irrational longer than you can stay solvent".

Efficient market hypothesis does not hold over the long term, because not enough exploitation of predictable long-term patterns. Traders need to demonstrate short-term returns to keep their jobs/clients.

Fun simulation - assume traders are perfectly rational but overconfident. Results in lots of trading, lots of volatility, strange correlations and below-average returns for active traders.

Trading profits come from "noise traders" - inexperienced, non-professional traders. Like fish in poker. There has to be a sucker at the table.

Of course the sucker doesn't care much in this case, because they don't mind get suckered for 0.5% in exchange for liquidity.

So professionals do make money, but to beat the market you have to be as well educated/trained/resourced as them. You probably aren't.

### A climate of healthy skepticism

Similar criticism of MRA as seen in Mindware.

Predictions are much stronger when backed up by understanding of the underlying system, rather than just data.

Huge confidence that greenhouse effect exists.

Expect to see noise in the data. A single datapoint does not outweigh all the other evidence. "It snowed in July, so much for global warming."

Healthy skepticism in climate science is generally directed at computer models. Broad consensus on current state of the climate and on the physical laws, and that the climate will get more energetic. Less agreement on exactly what the consequences are.

Initial condition uncertainty - what state are we in now? Scenario uncertainty - what input variables will change in the future? Structural uncertainty - do we understand the problem correctly? These vary over time and there is a sweetspot around 20 years out where uncertainty is minimized. __No idea where this magic number came from.__

First IPCC report in 1990 should have sweet spot in 2010. It's predictions are beaten by a model that simply looks at CO_2 levels and temperatures and extrapolates linearly. This suggest that the complexity of current climate models may not be justified.

Problem of how to publicly present these predictions. A scientifically accurate level of uncertainty would not be effective at persuading the public.

### What you don't know can hurt you

Pearl Harbour. Had the data that suggested a possible attack, but were not able to even generate that hypothesis. Similarly for 9/11 attacks. __Similar to Superforecasting chapter on how to generate good questions.__

Deaths in terrorist attacks also follow power law. Like Fukishima, could have used that to imagine an attack on that scale being plausible. Debate on whether similar analysis suggests that a nuclear or biological terrorist attack should be considered a plausible threat.

### Conclusion

__Much the same as Superforecasting__

## Thoughts

__While very entertaining, the book is mostly anecdotes. What insights it does contain are a subset of the material in Superforecasting.__

__The dives into various domains are interesting but not immediately useful. I would have to dedicate time to any one of them to really get a good understanding.__

__One interesting point is the idea that Pearl Harbour, Fukishima and 9/11 should have been imaginable. This adds to Tetlock and Taleb's debate about predicting black swan events - you may not be able to predict the exact event, but good prediction habits can at least tell you that something like it is possible so you should prepare.__

__Also interesting to see many domains where the combination of human insight and computer models outperforms either alone. How to effectively combine the two is definitely a subject worth looking into.__

__Overall, not a lot of insight but maybe worth following up on some of the examples.__

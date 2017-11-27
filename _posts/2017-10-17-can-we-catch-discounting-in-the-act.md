---
layout: post
title: Can we catch discounting in the act?
hidden: true
---

Replicated study?

* Need a good q - want to get lots of data from each participant
* Figure out what effect size to expect
* Look up discounting results?
* Survey - https://web.princeton.edu/sites/opplab/papers/alteropp09.pdf
* Font eg https://pdfs.semanticscholar.org/7c28/2ebf7502c104deabab2c5f7563058839b6cc.pdf
* Opacity/color - https://pdfs.semanticscholar.org/7c28/2ebf7502c104deabab2c5f7563058839b6cc.pdf
* Interpolate bold/italic eg http://www.tandfonline.com/doi/abs/10.1080/13825585.2015.1102194
* Blurring - https://link.springer.com/article/10.3758/s13421-012-0255-8

Procedure:

* Typicality
* TODO Question source? Are original questions online?
* Vary opacity of text?
* Interpolate between fonts? https://alistapart.com/article/live-font-interpolation-on-the-web https://erikbern.com/2016/01/21/analyzing-50k-fonts-using-deep-neural-networks.html http://vecg.cs.ucl.ac.uk/Projects/projects_fonts/projects_fonts.html
  * Calibrate by surveying subjective difficulty and reading short display
* Between subjects (within subjects is tricky - once they twig might discount for the rest of experiment)
* Image, not text, so can't highlight
* Calibrate image size

Mechanical Turk:

* ~$1 per 10 mins (https://sci-hub.cc/http://www.sciencedirect.com/science/article/pii/S0022103116303201)
* Attention checks - throw in some obvious answers
* Give bonus per correct answer to incentivize trying
* Diversity - probably doesn't matter if WEIRD
* Make sure clicking randomly doesn't make experiment finish faster. 
* Only one try. 
* Randomize so can't share information.

Results:

* Expect to see hump in the middle. 
* Fit 2-spline, numerically calculate p-value vs linear?
* Uri Simonsohn suggests a better procedure - http://datacolada.org/27 http://datacolada.org/62

Power / stopping:

* Run until money amount? Or run until HPDI tight?
* Stopping rules - http://doingbayesiandataanalysis.blogspot.co.uk/2013/11/optional-stopping-in-data-collection-p.html
* Want confidence interval that doesn't overlap with original - 2.5x replication - http://datacolada.org/4
* TODO figure out original confidence interval
* TODO Numerical power analysis for spline? 






---
layout: post
title: "Scaling down"
date: 2015-02-09 13:42
comments: true
categories:
---

The programming world is obsessed with scaling up. How many million lines of code can we maintain? How many petabytes of data can we process? How deeply can I customise this editor? More code, more data, more people, more machines.

Nobody talks about scaling down.

<!--more-->

The vast majority of programs are never written. Ideas die stillborn because the startup cost is too high to bear. When we focus entirely on the asymptotic cost of developing large systems we neglect the constant costs that make tedious grinds out of simple tasks.

There is a great deal to be gained from switching the focus from *what we can do* to *what we can get done*, from creating the most *expressive* tools to creating the most *efficient* tools. To do this we need to become conscious of the friction imposed by our tools. When we scale up, the concerns are performance, modularity, maintainability, expressiveness. A toolset optimised for small-scale programming must have different metrics:

* How long does it take to create a project? Creating a github repo, making a build file, editing the project template, opening editors, starting repls, launching dev servers.

* How long does it take to get results on the screen? Compare to how long it takes to get bored and lose interest.

* How long does it take to leverage libraries? Figuring out which library to use, installing the correct version, understanding the documentation, making a successful api call.

* How long does it take to deploy? Serving a website, uploading a package, emailing a self-contained script, installing a cron job.

* How hard is it to see what is going on? Can you inspect variables, set breakpoints, trace messages, rewind time?

* How quickly are bugs found and corrected? How much time passes between making a mistake, noticing the damage, reproducing the trigger, understanding what went wrong and applying the fix?

* How much time do you spend on incidental tasks? Installing libraries, committing to version control, drawing module boundaries, constructing class hierarchies, writing build scripts. Anything that is supporting the process rather than directly solving the original problem.

* How easy is it to collaborate with another person? What is the latency of sharing? Can you work together in real time? How long does it take before the other person is in a state to work on the code?

* How quickly can you change the program when your goals change? Are you stuck with your architectural mistakes? Is everything tangled together? Do all the boundaries have to change?

The instinctive reaction is that the problems are overblown and everything would be fine if everybody would just use language / tool / methodology X.

So let's try it. Pick one of these programs and solve it however you think best. Record a video and afterwards break down your activity minute by minute.

* Fairly queue song choices in the office.

* Display a notification whenever an email arrives from a specific address.

* Record audio whenever some hardware button is held on your phone lock-screen and save in a browseable / playable list.

* Fetch transaction records from your online bank, break down costs by regex categories and display a pie-chart for each month.

So much of what we actually do goes unnoticed after years of practice and routine. The reality may be quite different from what you imagine.

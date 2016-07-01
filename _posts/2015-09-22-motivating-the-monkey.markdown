---
layout: post
title: "Motivating the monkey"
date: 2015-09-22 22:00
comments: true
categories:
---

I struggle a lot with motivation. This is probably not an unfamiliar story - there is some exciting project I want to work on but every time I try to get started my mind just shies away and reaches for the reddit refresh button.

There is a lot of advice on the subject. Some of the advice is basic sanity maintenance like getting regular exercise, nurturing your social life, eating healthily and taking time out. This is sensible advice. Other advice revolves around shoring up motivation through blocking websites, setting timers, tracking goals etc. I find this kind of advice unhelpful.

The reason it's unhelpful is that procrastination is fundamentally a [monkey-brain](http://mindingourway.com/not-yet-gods/) problem and that these are all human-brain solutions - bandaids over a gaping wound.

Rather than wrestle with willpower I've found it much more useful to directly attack the underlying problems. The two main problems that I suffer from are lack of rewards and lack of a plan.

## Lack of rewards

Not big rewards, like a meaningful project or high status or good salary or lots of perks. The monkey-brain is not into complex cause-effect chains or long-term consequences. It only cares about here and now. If every time I look at an editor I feel stressed and tired and nothing pleasant happens *immediately afterwards* then the monkey-brain will just refuse to look at the editor anymore. Procrastination sets in.

Some projects are easy to sell to the monkey-brain. If I'm doing optimisation work then I get to run benchmarks. Sometimes I run a benchmark and the numbers have gotten bigger! Monkey-brain is really into frequent, unpredictable rewards so it lets me work on optimisation for hours on end without needing distraction.

Other projects just need better planning. A common trap I used to fall into was to start a project where the todo list looks like:

* Do hard thing A
* Do hard thing B
* ...
* Do hard thing Y
* Do hard thing Z
* Shiny exciting results!

Usually I make it as far as hard thing C before the monkey-brain decides that this sucks and we should go eat icecream instead.

These days when I plan projects I try to front-load the shiny. For example, when working on Imp I could have broken up the work by subsystem: write the runtime, write the compiler, write the parser, write the repl. But the exciting, motivating part is getting to play with the repl and that wouldn't have happened until right at the end. Instead I broke it up by feature: get inputs working, get joins working, get functions working etc so that every chunk of work results in a new toys to play with.

Some projects really are just a grind and the only way to avoid burnout is to mix in other rewards. If I have to spend weeks refactoring some gnarly legacy code, I will also take time out to work on little projects that I can finish easily, just to make sure that the monkey-brain doesn't get the impression that programming sucks in general.

What actually constitutes a reward probably varies from person to person. For some people, the satisfaction of seeing clean code checked in or a suite of tests passing might be enough. For me, the only reliable rewards are numbers getting bigger or new toys to play with, so I have to make sure that those happen.

## Lack of a plan

There are lot of ways my momentum can break down: I can't figure out how to solve some problem, I can't decide what to do, I don't know where to start etc. What they all have in common is that nothing is happening, there is no clear next step and I just wallow in the quicksand of indecision. This can go on for weeks. The way I've learnt to deal with this is to have pre-planned procedures that get triggered when I notice one of those failure modes.

If I can't figure out how to solve some problem:

* Write down the problem in as much detail as possible.
* Write down what exactly would constitute a solution.
* Write down why I need to solve this problem and why I can't just do something simpler.
* Write down a list of examples and try to solve each one by hand.
* Write down any problems other people have solved that seem related. See if the solutions can be adapted.
* Write down problems that are similar but easier. Try to solve those.
* Open up [How To Solve It](http://www.amazon.com/How-Solve-It-Mathematical-Princeton/dp/069111966X) and try each of the heuristics.
* Explain all of the above to someone else.

If I can't decide what to do:

* Write down the problem.
* Write down the criteria by which I should judge each option.
* Write down all the options I can think of.
* Write down the pros and cons of each.
* If possible, go do something else instead.
* Otherwise, start a 30 minute timer and at the end pick the least bad option still on the list.

If I don't know where to start:

* List all the things that need to happen, in time order.
* If the first thing on the list is something I can do, do it.
* Otherwise, take the first thing on the list and break it down into smaller steps.

The key thing about all of these is that they generate momentum. As long as I am systematically attacking a problem I will get somewhere. The failure mode to avoid is just circling around on the same thoughts again and again until the monkey-brain freaks out about the lack of progress and calls for icecream and cat videos.
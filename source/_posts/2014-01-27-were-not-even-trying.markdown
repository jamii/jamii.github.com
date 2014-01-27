---
layout: post
title: "We're not even trying"
date: 2014-01-27 00:31
comments: true
categories:
---

Light Table has a feature called [watches](http://www.youtube.com/watch?v=d8-b6QEN-rk), where you select an expression to watch and behind the scenes the editor wraps that expression in some code that sends the results back to the editor every time the expression is executed. You can also write custom watches that wrap the selected expression however you like. For example, this watch displays the time the expression took to execute.

<!--more-->

``` clj
"alt-m" [(:editor.watch.custom-watch-selection
           "(let [start (.getTime (js/Date.))
                  res (do __SELECTION__)]
              __|(str (- (.getTime (js/Date.)) start) \" ms\")|__
              res)"
           {:class "timed" :verbatim true})]
```

Similarly, you can write custom eval commands which wrap the selected expression before evaluating it. I have a whole pile of these for tasks from benchmarking an expression to displaying the bytecode for the resulting object.

``` clj
"alt-shift-b" [(:eval.custom "(do (require '[criterium.core]) (with-out-str (criterium.core/bench (do __SELECTION__))))" {:result-type :inline :verbatim true})]
"alt-d" [(:eval.custom "(do (require '[no.disassemble]) (no.disassemble/disassemble (do __SELECTION__)))" {:result-type :inline :verbatim true})]
```

This has completely replaced print statement debugging for me. It probably saves me 10-20 minutes of typing per day, reduces context switching a little and prevents me accidentally checking in print statements. It doesn't sound like much, but if you make three or four improvements like that it starts to add up.

But the point of this post is not Light Table is awesome (although it is). The point is that I spent four years as a professional programmer typing in print statements every day and I never once thought to automate that process. If I missed something so simple, what else am I missing?

I lose hours and hours every week to mistyped variables and function names. When using clojurescript in Light Table there are no warnings shown and the stack traces don't identify which variable was mistyped. But the clojurescript compiler can emit warnings and webkit inspector can show which line the error occured at. All I have to do is take a few hours to improve the clojurescript plugin and I would never suffer from mistyped names again.

I spend even more hours painstakingly inserting watches and setting up test cases when all I really want to do is step through the call-stack. We have a debugger! The webkit inspector has an excellent debugger which uses the source maps that we so carefully emit to enable stepping though clojurescript code directly. But I haven't gotten around to taking ten minutes to learn to use it, so I rely entirely on watches instead.

I know I'm not the only one. I've seen otherwise intelligent people go through a code file and manually rename every occurence of a function, as if they had never heard of find-and-replace. I know people who write code in notepad because they don't need any "fancy IDE features" getting in the way.

{% img /images/square1.gif %}

I see people tolerate waiting minutes to compile and endure restarting their program every time they make a change. I worked with one company whose build process so annoyed me that I started writing down the time I spent waiting and worked out it was costing them an hour of consulting time every day. They wouldn't let me fix it. At another company, a new service made it into master despite the fact that it crashed on startup. Setting up a working mock environment was so painful that neither the original developer nor the reviewer had actually tried running the code.

How does this happen? What the hell went wrong?

## I don't have the time to fix the problem

The correct response to this is to make a note of how much time I waste every day by not fixing the problem. That's *why* I don't have time.

{% img /images/square-time.jpg %}

Just taking a few hours a week to fix the low-hanging fruit will pay for itself dozens of times over, and every time I add a feature to my editor or write a little command line tool I will learn things that will make it faster and easier next time. Productivity is multiplicative. Small improvements add up to remarkable changes.

## I didn't notice there was a problem

This suprised me at first, but I realised that the reason I had never fixed the undefined variable problem was because I had never sat down and figured out how much it cost me in terms of lost time and focus. When I'm coding I'm not really conciously aware of the mechanical details of what I'm doing. My head is focused on data and algorithms, bugs and performance problems. I'm only vaguely aware that at the other end my hands are repeatedly mistyping println.

I'm trying now to maintain some sort of record. Whenever I lose focus or forget what I was doing I write down what distracted me. Whenever something annoys or frustrates me I write it down. Every time I take a break I make a quick note of what I spent the last hour or two doing. Whenever I fix a bug I write down the process that lead me to finding it, what the cause was and how it slipped through testing.

Something else I am considering trying is recording a few hours of video and going back to analyse in detail what worked and what didn't. I suspect that I will spot a number of bad habits that are obvious in hindsight.

The advantage of recording all this evidence is that I can get an *accurate* picture of where my time is going and how my tools and processes could be improved. Going by my memory of what happened has proven to be less than useful.

## I have a vested interest in there not being a problem

My favourite language doesn't have a debugger so clearly I don't need one. Besides, real programmers don't need a debugger. They just simulate the program directly in their head.

People [lie to themselves](http://www.amazon.co.uk/Thinking-Fast-Slow-Daniel-Kahneman/dp/0141033576/ref=sr_1_1?ie=UTF8&qid=1390773807&sr=8-1&keywords=thinking+fast+and+slow). We all regularly defend on the grounds of technical merit when really the decision is governed by comfort zones, fashion, superficial impressions and random prejudices. It's hard to make good decisions when you aren't even aware of your own biases.

One idea for combatting this is to take the [outside view](http://wiki.lesswrong.com/wiki/Outside_view). I imagine *specific cases* where I have seen other developers trying to solve similar bugs and in each one of those cases I would have recommended that they learn to use the debugger rather than painstakingly engineering a test case out of print statements and watches.

Another idea I keep in mind is [keeping my identity small](http://www.paulgraham.com/identity.html). If I persist in thinking of myself as a 'real hardcore programmer' then I will forever be stuck peering at an 80 character ANSI terminal while other people get shit done.

Finally, I hope to be able to rely more on emperical results. If I am disciplined about collecting data then it will be easier to see what the correct answer is without malformed preconceptions getting in the way.

## I didn't realise the problem could be fixed

The reason I never automated attaching watches is because it never occured to me that that was possible, let alone easy. My mental model of progamming involved me typing text into an editor and later running it. The editor might help me move text around but it couldn't change the text on the way to the repl. I was a victim of first order thinking, seeing my programming environment as a fixed tool where text goes in one end and programs come out the other. The only solution is to tattoo 'everything is data' across my forehead.

It is 2014. We have been programming for six decades. The software world has invested tens of thousands of man-years into building tools to help us write code (I'm told that the Visual Studio team alone is 2000 developers). How is it still the case that my fat fingers can mistype a function name and the first I hear about it is "Cannot call method 'call' of undefined". Is this really the best we can do? It feels like it takes a monumental amount of effort just to enable the simplest features.

{% img /images/square2.gif %}

Computers are not just a tool for writing code, they are a tool for thinking. We can [extend the language](http://clojure.org/macros). We can [make new languages](http://cascalog.org/). We can write code that [analyses code](https://github.com/clojure/core.typed), code that [rewrites code](https://github.com/technomancy/slamhound), code that [inspects code](http://trac.webkit.org/wiki/WebInspector), code that [finds slow code](https://github.com/plasma-umass/causal), code that [finds bugs](http://www.st.cs.uni-saarland.de/dd/), code that [predicts bugs](http://google-engtools.blogspot.co.uk/2011/12/bug-prediction-at-google.html), code that [breaks code](http://db.cs.berkeley.edu/papers/hotdep10-fts-dts.pdf), code that [visualises code execution](http://worrydream.com/MediaForThinkingTheUnthinkable/), code that [queries code execution](http://db.cs.berkeley.edu/papers/eurosys10-boom.pdf). We are barely scratching the surface. We have to stop thinking of code as text and start thinking of code as data.

And I have to go learn how to use the webkit debugger in Light Table.

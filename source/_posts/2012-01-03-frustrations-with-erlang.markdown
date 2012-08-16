---
layout: post
title: "Frustrations with erlang"
date: 2012-01-03 06:16
comments: true
categories:
- erlang
---

With my work on erl-telehash and at Smarkets I find myself fighting erlang more and more. The biggest pains are the dearth of libraries, the lack of polymorphism and being forced into a single model of concurrency.

<!--more-->

The first is self-explanatory and pretty well-known. I frequently have to fire up a python process through a port to do something simple like send an email. Even the standard library is incomplete and inconsistent.

The second doesn't start to hurt until your codebase gets a bit bigger. For example, Smarkets makes a lot of use of fixed-precision decimal arithmetic which leads to code like this:

``` erlang
decimal:mult(Qty,  decimal:sub(decimal:to_decimal(1), Price))
```
It also means any time you want to change a data-structure for one with an equivalent interface you have to rewrite whole swathes of code.

The third point is a bit more contentious. I'm fairly convinced that the erlang philosophy of fail-early, crash-only, restartable tasks is the right solution for most problems. What bugs me is that erlang conflates addresses, queues and actors by giving each process a single mailbox. This leads to problems like requiring the recipient of a message to have a global name if it is to be independently restartable, which means you can't run more than one copy of that message topology on the same node. It also encourages processes to send messages directly to other processes which makes it difficult to create flexible, rewirable topologies or to isolate pieces of a topology for testing. I would prefer a model in which processes send and receive messages through queues which are wired together outside of the process. This would also allow restarting a process (and clearing but not deleting its queues) without giving it a global name.

I'm not about to run out now and rewrite erl-telehash in another language. It's close enough to complete (for my purposes at least) that I'll just continue with the existing code. For future experiments, however, I want something better.

The top candidate at the moment is clojure. It has the potential to replace my use of erlang and python, saving lots of cross-language pain. Agents look a lot like a (cleaner, saner) implementation of the [mealy machines](http://scattered-thoughts.net/one/1300/292121/72985) that I wrote at Smarkets. [Lamina](https://github.com/ztellman/lamina) neatly solves the queue pains I described above. [Datalog](http://code.google.com/p/clojure-contrib/wiki/DatalogOverview) is the natural way to describe a lot of collections, including [th_bucket](https://github.com/jamii/erl-telehash/blob/master/src/th_bucket.erl) which is in its current form is not obviously correct. The clojure community just seems to churn out well-designed libraries (lamina, aleph, slice, incanter, pallet, cascalog, storm, overtone etc).

In the short term I will get started by rewriting [binmap](https://github.com/jamii/binmap), since it's fresh in my mind and simple enough to finish quickly. If that goes well it might eventually become an educational port of [swift](http://libswift.org).


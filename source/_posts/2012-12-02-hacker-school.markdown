---
layout: post
title: "Hacker School"
date: 2012-12-02 01:16
comments: true
categories: mist droplet strucjure
---

I've spent the last ten weeks or so at [Hacker School](https://www.hackerschool.com/). It's something like a writer's retreat for programmers. Unlike a traditional school there is very little structure and the focus is on project-based learning. In order to make the most of this environment, it's important to be clear exactly what your goals are.

<!--more-->

So here is my goal - to create better tools for the problems I regularly encounter. My focus is on building distributed systems and p2p networks but I suspect that these tools will be generally useful. When working as a freelancer I am necessarily constrained to using proven ideas and techniques because the risk assumed is not mine. Hacker School is a chance for me to explore some more far-out ideas. These ideas are drawn primarily from two places: the [Viewpoint Research Institute](http://vpri.org/) and the [Berkeley Order Of Magnitude](boom.cs.berkeley.edu/) project.

## Viewpoint Research Institute

Specifically, I'm interested in the [Steps Towards Expressive Programming](http://www.vpri.org/pdf/tr2011004_steps11.pdf) project. Their goal is no less than the reinvention of programming. By way of proof of concept they aim to develop an entire computing system, from OS to compilers to applications, in less than 20k LOC. Such a system would be compact enough to be understood in its entirety by a single person, something that is unthinkable in todays world of multi-million LOC systems. Amazingly, their initial prototypes of various subsystems actually approach this goal.

Their approach relies heavily on the use of [DSLs](http://en.wikipedia.org/wiki/Domain-specific_language) to capture high-level, domain-specific expressions of intent which are then compiled into efficient code. By way of example, they describe their TCP-IP stack:

> Most  interesting  ideas  have  more  than  one  fruitful  way  to  view  them,  and  it  occurred  to  us  that,
> abstractly,  one  could  think  of  TCP/IP  as  a  kind  of  “non‐deterministic  parser  with  balancing
> heuristics”,  in  that  it  takes  in  a  stream  of  things,  does  various  kinds  of  pattern‐matching  on  them,
> deals with errors by backing up and taking other paths, and produces a transformation of the input in
> a specified form as a result.
>
> Since the language transformation techniques we use operate on arbitrary objects, not just strings (see
> above), and include some abilities of both standard and logic programming, it seemed that this could
> be used to make a very compact TCP/IP. Our first attempt was about 160 lines of code that was robust
> enough to run a website. We think this can be done even more compactly and clearly, and we plan to
> take another pass at this next year.

The 'language transformation techniques' they refer to are embodied in [OMeta](http://lambda-the-ultimate.org/node/2477), a [PEG](http://en.wikipedia.org/wiki/PEG)-based language for parsing and pattern-matching. OMeta provides an incredible amount of leverage for such a simple abstraction. For starters, it leads to very concise and readable descriptions of tokenisers, parsers and tree transformers which are all crucial for developing DSLs.

## Berkeley Order Of Magnitude

The Berkeley Order Of Magnitude project has spent a number of years experimenting with using logic languages for distributed systems. Like the STEPS project, their goals are audaciously ambitious.

> Enter BOOM, an effort to explore implementing Cloud software using disorderly, data-centric languages. BOOM stands for the Berkeley Orders Of Magnitude project, because we seek to enable people to build systems that are OOM bigger than are building today, with OOM less effort than traditional programming methodologies.

Among their [myriad publications](boom.cs.berkeley.edu/papers.html) they describe an [API-compliant reimplementation of Hadoop and HDFS](http://www.srcf.ucam.org/~ms705/temp/eurosys2010/boom.pdf) in ~1K lines of Overlog code, which they then extend with a variety of features (eg master-node failover via MultiPaxos) not yet found in Hadoop. Thanks to a number of high-level optimisations enabled by the simpler code-base their implementation is almost as fast as the original.

For me, the most interesting aspect is the amount of reflective power gained by treating everything as data:

> One key to our approach is that everything is data, i.e. rows in tables that can be queried and manipulated. This includes persistent data (e.g. filesystem metadata), runtime state (e.g. Hadoop scheduler bookkeeping), summary stats (e.g. for advanced straggler scheduling), in-flight msgs and system events, even parsed code. When everything in a system is data, it becomes easy to do things like parallelize computations on the state, make it fault tolerant, and express (and enforce) invariants on legal states of the system.

The latest project from the BOOM group is the [Bloom language](http://www.bloom-lang.net/). Bloom has a more solid theoretical foundation than their previous languages and also enables an amazing level of static analysis, even being able to guarantee that certain Bloom programs are eventually consistent.

## Core Ideas

What can I take away from these projects? Here are some vague ideas, which to my mind all seem related.

__Higher-level reasoning__. The STEPS notes talk about 'separating meaning from tactics'. It's often easier to specify what a correct solution to a problem looks like than it is to actually find it. In many domains, finding a solution is then just a matter of applying a suitable search algorithm. For example, constraint solvers such as [gecode](http://www.gecode.org/) or [core.logic](https://github.com/clojure/core.logic) express a problem as a set of logical constraints on the possible solutions and then search through the space of variable assignments to find a solution. By automatically pruning parts of the search space which break one or more constraints and applying user-specified search heuristics, constraint solvers can often be faster than hand-coded solvers for complex problems whilst at the same time allowing a clear, concise, declarative specification of the problem.

__Everything is data__. Constraint solving is enabled by treating both the problem specification and the solution space as data, reducing the problem to search. In lisps, treating code as data enables macros and code rewriting. In Overlog, everything from persistent data to scheduler state to the language runtime is available as data and can be queried and manipulated using the same powerful abstractions. Tracing in Overlog is as simple as adding a rule that fires whenever a new fact is derived, because the derivation itself is stored alongside the fact. Whatever you are working on, making it accessible as plain data enables turning the full power and expressivity of your language directly onto the problem. This is where OO falls down, in trying to hide data behind custom interfaces. Rob Pike recently put it: "It has become clear that OO zealots are afraid of data".

__Reflection__. When you expose the internals of a system as data to that same system, amazing (and, yes, sometimes terrifying) things happen. The STEPS folks manage to stay withing their code budget by building highly dynamic, self-hosting, meta-circular, introspective languages. Many of the amazing results of the Overlog project, from the optimising compiler to declarative distributed tracing, resulted from exposing the language runtime and program source code to the same logic engine that it implements. Turning a system in on itself and allowing it to reason about its own behaviour is an incredibly powerful idea. Certainly it can be dangerous, and it's all too easy to tangle oneself in knots, but the results speak for themselves. This is an idea that has been [expounded](http://steve-yegge.blogspot.com/2007/01/pinocchio-problem.html) [many](http://en.wikipedia.org/wiki/G%C3%B6del,_Escher,_Bach) [times](http://www.paulgraham.com/diff.html) before but I think there is still so much more to explore here.

# Progress

My attempts to keep up with this have been focused on three projects.

[Shackles](https://github.com/jamii/shackles) is a constraint solver supporting both finite-domain and logical constraints. It was originally an experiment to see what, if any, extra power could be gained from implementing a gecode-style solver using persistent data-structures (constraint solvers in traditional languages spend much of their time cloning program state to enable back-tracking). Fortunately, [core.logic](https://github.com/clojure/core.logic) now supports finite domain variables with constraint propagation and there has been noise about implementing user-specified search heuristcs, so that's one less piece of code I need to write :D

[Strucjure](https://github.com/jamii/strucjure) is similar to OMeta but aims to be a good clojure citizen rather than a totally separate tool. As such, all of its core components are [protocols](http://clojure.org/protocols), semantic actions are plain clojure code and the resulting patterns and views are just nested [records](http://clojure.org/datatypes) which can be manipulated by regular clojure code. Following the principles above, the syntax of strucjure patterns/views is [self-defined using views](https://github.com/jamii/strucjure/blob/master/src/strucjure/parser.clj#L94) and the test suite [parses the documentation](https://github.com/jamii/strucjure/blob/master/src/strucjure/test.clj#L1) to verify the correctness of the examples.

[Droplet](https://github.com/jamii/droplet) is based on the Bloom^L language (an extension of the Bloom language that operates over arbitrary semi-lattices). Droplet is so far less developed than the other projects but the core interpreter is working as well as basic datalog-like rules. Again, droplet attempts to be a good clojure citizen. Rules are just clojure functions. The datalog syntax is implemented via a simple macro which produces a rule function. Individual droplets are held in [agents](http://clojure.org/agents) and communicate either via agent sends or over [lamina](https://github.com/ztellman/lamina) queues. I'm currently working out a composable, extensible query language that is able to operate over arbitrary semi-lattices, rather than just sets. In its current (and largely imaginary) form, it looks something like [this](https://gist.github.com/4171094).

I'll go into more detail on the latter two projects soon but for now I'm content to just throw these ideas out into the world, without justification, and see what bounces back.

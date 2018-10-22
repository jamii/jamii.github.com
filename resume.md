---
title: Resume
layout: page
---

## Researcher at [RelationalAI](http://relational.ai/)

#### May 2017 - Aug 2018

RelationalAI is building a relational database, a probabilistic programming language and various integrated machine learning systems. I took on the task of figuring out how to make this project feasible, given the small size of the team and the limited funding time-frame.

I built several prototypes in Julia, demonstrating better performance than existing work with much less implementation effort. To allay concerns about adopting Julia, I:

* Implemented a [pattern matching extension to Julia](https://github.com/RelationalAI-oss/Rematch.jl), used for rewrite passes in the compiler.

* Surveyed the Julia garbage collector and task system, to allay concerns about parallelism.

* Wrote a library for [zero-copy deserialization without overhead](https://github.com/RelationalAI-oss/Blobs.jl), used for implementing database indexes.

* Helped develop [static analysis tools](https://github.com/MikeInnes/Traceur.jl) for detecting performance problems in generated Julia code.

As a result RelationalAI adopted Julia for all ongoing development, after which I:

* Assisted with Julia training, on-boarding and debugging.

* Wrote the current execution engine; a combination of a rewriting system and a simple interpreter.

* Developed executable semantics for debugging the language design.

* Demonstrated the use of partial evaluation to obtain compiler-like performance from an annotated interpreter, to further reduce development effort (<https://youtu.be/BBUrQId0HhQ>).

## Independent Researcher

#### Aug 2016 - Apr 2017

Initially planned as a sabbatical, but later supported by funding from [LogicBlox](https://developer.logicblox.com/).

* Built a relational query compiler that produces zero-allocation, [worst-case optimal](https://arxiv.org/abs/1310.3314) native code and [outperforms Postgres](http://scattered-thoughts.net/blog/2016/10/11/a-practical-relational-query-compiler-in-500-lines/) on the Join Order Benchmark.

* Built a declarative language for building GUIs directly on top of a relational database, without any application code, that [performs on par with React](http://scattered-thoughts.net/blog/2017/07/28/relational-ui/).

* Built a live-coding interpreter and editor plugin for a relational language, capable of executing code as it's typed whilst being resilient to bugs, typos and infinite loops.

## CTO at [Eve](http://witheve.com/)

#### Nov 2013 - Jan 2016

* Together with the CEO built a language and IDE which secured a [$2.3m seed round](https://techcrunch.com/2014/10/01/eve-raises-2-3m-to-rethink-programming/) from Andreessen Horowitz.

* Created a [live relational language](http://witheve.com/philosophy/) based on temporal-logic extensions of datalog.

* Built relational databases, query planners and bootstrapped compilers for a series of prototypes (demonstrated in <https://youtu.be/VZQoAKJPbh8>).

* Wrote the [company research blog](http://incidentalcomplexity.com/archive/), which saw ~100k views/year.

* Spoke at the MIT Media Lab.

* Invited as a [resident](https://www.recurse.com/blog/68-a-small-step-in-a-new-direction) at the Recurse Center.

* Helped [release Light Table](http://www.chris-granger.com/2014/01/07/light-table-is-open-source/) as an open-source project.

* Sat on the program committee for the [Future of Programming Workshop](http://www.future-programming.org/2015/call.html).

## Consultant

#### May 2009 – Nov 2013

Highlighted commercial projects:

* Built a [LaTeX aware search engine](http://scattered-thoughts.net/blog/2010/12/08/optimising-texsearch/) to power [latexsearch.com](http://latexsearch.com). Covers the entire Springer library of more than 8m LaTeX equations. Searches by tree-edit distance on compressed syntax trees, using suffix arrays as a first-pass filter.

* Built a prototype replacement for the core trading engine at the [Smarkets](https://smarkets.com/) betting exchange: 10x less code, 40x better throughput, 10x better 99% latency.

* [Provided item-item article recommendations](https://github.com/jamii/springer-recommendations) for Springer users based on ~600m past downloads. Uses locality-sensitive hashing and external sorting to run on a single low-powered server.

## Sabbatical at the [Recurse Centre](https://www.recurse.com/)

#### Sep 2012 - Dec 2012

* Extended the core.logic CLP solver with [fair conjunction and a parallel solver](http://scattered-thoughts.net/blog/2012/12/19/search-trees-and-core-dot-logic/).

* Created a clojure DSL for [pattern matching and parsing using PEGs](http://scattered-thoughts.net/blog/2012/12/04/strucjure-motivation/).

* Built a [multi-user clojure REPL](https://github.com/jamii/concerto) for collaborative live-coding.

## MSc Computer Science at Oxford University

#### Oct 2008 – Sep 2010

* Studied randomized algorithms, probabilistic model checking, logics of multi-agent information flow, machine learning and intelligent systems.

* Dissertation: [Design and analysis of a gossip overlay](https://github.com/jamii/dissertation/blob/master/writeup/main.pdf).

## BA Mathematics at University of Cambridge

#### Oct 2005 – July 2008

* Specialized in real analysis, discrete maths, probability and stochastic systems.

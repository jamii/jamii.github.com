---
layout: "post"
title: "A practical relational query compiler in 800 lines"
date: "2016-09-16 16:20"
---

As part of my work on [Imp], I wrote an in-memory relational database and query language that is:

* __Fast__. On benchmarks with real-world datasets, Imp is ?-?x faster than both sqlite and postgres (see the [benchmark] section below for more details).
* __Simple__. 300 lines for relations. 500 lines for the query compiler.
* __Predictable__. Query compilation is deterministic - no heuristics, and no sudden plan changes in the middle of the night. There is a straightforward mental model for predicting query performance. A simple hint system allows the programmer to control plan choice (see the [benchmark] section below to find out how this performs in practice).
* __Easy__. The query language is accessed via a single macro. Relations can contain any[1] datatype from the host language. Queries can call any function from the host language. 
* __Allocation-free__. Memory is only allocated when creating indexes, returning results or running user-defined functions. (TODO remove query init allocation). Queries do not allocate *any* intermediate results.
* __Portable__. Imp is implemented in [Julia], but the implementation is simple enough to easily port to your favourite language. 

The rest of this post will explain how the compiler works and explore the benchmarks against sqlite and postgres.

## Compilation

The query compiler is based on the recent flurry of research on [worst-case optimal join algorithms]. The only novel contributions here are the clear implementation and the use of a programmer hints rather than cardinality estimates. 

Let's take the following query as a running example:

TODO query

Possible query plans in Imp vary only in the order in which they explore the variables. The variable ordering is determined by simply noting the order in which the variables first occur in the source:

TODO highlighted query and variable order

The user can change this ordering by rearranging the clauses of the query or by adding `@hint` clauses. These changes can only effect performance - the results of the query are the same regardless of variable ordering.

TODO example hint 

Given a query and a variable ordering, the compiler emits code for a backtracking search that looks something like[2]:

TODO simplified search code

The key functions here are `intersect` and `project`. `project` returns the subset of the relation which matches the given value, in `O(log(n))` time. `intersect` returns an iterator over the values which are contained in all of the input columns, in `O(min_size(columns) log max_size(columns))`. There are a variety of ways to do this - the current implementation uses the [Leapfrog algorithm](http://arxiv.org/abs/1210.0481). 

This leads to a useful mental model. To a first approximation, the runtime is proportional to the total number of calls to `intersect`. That is, to the total number of results from these queries:

TODO prefix queries

Finally, there are no intermediate allocations, so the total memory usage and allocation rate is entirely determined by:

TODO result push statements, relation return

## Benchmark

This benchmark not intended to be a direct comparison between Imp and sqlite - they are totally different kinds of systems with totally different tradeoffs. Instead, the goal is to demonstrate that this approach to query compilation is practical. If your data fits in memory and sqlite would be fast enough, the Imp should also be fast enough.

This benchmark only tests query performance. Imp's indexes are currently read-optimised, so insert times are likely much worse than sqlite. I have reasonable confidence that fixing this will not impact performance dramatically enough to change the conclusion - the [tradeoff curve](http://www.cs.au.dk/~gerth/papers/alcomft-tr-03-75.pdf) is not super steep - but it's definitely a large caveat. 

I'm using the [Join Order Benchmark](http://www.vldb.org/pvldb/vol9/p204-leis.pdf). This benchmark compares 33 queries, each with 3-4 variants, on the [IMDB dataset]. The csv dataset is 3.7GB on disk. The largest tables are cast_info and movie_info at 36M and 15M rows, respectively. Queries contain only joins and filters - no aggregation or sorting - but are still reasonably challenging for most query compilers. The queries ask for the `MIN` row to minimize the cost of displaying/returning the results.

``` sql
# example query
SELECT MIN(mi_idx.info) AS rating,
       MIN(t.title) AS movie_title
FROM info_type AS it,
     keyword AS k,
     movie_info_idx AS mi_idx,
     movie_keyword AS mk,
     title AS t
WHERE it.info ='rating'
  AND k.keyword LIKE '%sequel%'
  AND mi_idx.info > '5.0'
  AND t.production_year > 2005
  AND t.id = mi_idx.movie_id
  AND t.id = mk.movie_id
  AND mk.movie_id = mi_idx.movie_id
  AND k.id = mk.keyword_id
  AND it.id = mi_idx.info_type_id;
```

I chose this benchmark because, as demonstrated in the [paper](http://www.vldb.org/pvldb/vol9/p204-leis.pdf), query compilers based on cardinality estimates struggle more on real-world datasets than they do on synthetically generated datasets such as [TPC](http://www.tpc.org/). The main thing I want to show here is that it's feasible for many use-cases to do away with cardinality estimates all together. 

I wrote the Imp queries based only on the schema, the table sizes mentioned above and some common-sense assumptions about the data distribution. I report the median run-time produced by [BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl). In cases where it took multiple attempts to arrive at a good hint, I give the times for each attempt.

Both sqlite and postgres are using on-disk tables, but on a machine with enough memory to cache the entire dataset. Both are configured using the default settings (TODO is this fair? does postgres need eg bigger cache size). Each query is repeated at least TODO times and the median time is reported. TODO timing methodology

TODO results here

TODO reproduction instructions

## Future

There are three main features I'm planning for the next few months:

* Persistence and read-write-balanced indexes (followed by a more complete comparison with sqlite)
* Incremental maintenance of view graphs (based roughly on [differential dataflow](https://github.com/frankmcsherry/differential-dataflow))
* Tools for building interactive GUIs on top of view graphs (most likely based on [React]-like tree-diffing - early experiments [here](https://github.com/jamii/imp/blob/master/examples/))

The goal is to support rapid application development by removing the mental overhead of the traditional database-server-client stack, and do so with the minimum of unpredictable magic. If you are interested in funding this work, please contact me at [jamie@scattered-thoughts.net].

[1]: The current implementation requires that datatypes implement Base.cmp so the columns can be sorted

[2]: The actual generated code is substantially uglier due to the need to avoid allocation and to play nicely with Julia's type inference, but the basic idea is the same.

TODO
finish all benchmark queries
automate comparison to sqlite and postgres
add instructions to reproduce benchmark 
Imp readme (prominently mention reliance on Julia v0.5+)

optional TODO
remove allocation in query init
remove allocation for aggregates over sub-queries

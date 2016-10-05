---
layout: "post"
title: "A practical relational query compiler in 700 lines of code"
date: "2016-09-16 16:20"
---

[Imp](https://github.com/jamii/imp/) needed a relational query compiler that is easy to modify and extend, but fast enough to power real applications.

SQLite is [116,000 lines of code](https://www.sqlite.org/testing.html). PostgreSQL is [840,000 lines of code](https://www.openhub.net/p/postgres/). MySQL is (apparently) [2,733,000 lines of code](https://www.openhub.net/p/mysql). These are not easy to experiment with.

But the people who made those systems are pretty smart. If there was a way to solve the same problem with substantially less effort then they would have done it already. So we need to change the problem. 

IO, transactions and write-concurrency [make up much of the code and runtime](http://nms.csail.mit.edu/~stavros/pubs/OLTP_sigmod08.pdf) in a typical database. So I built a single-writer, in-memory database and used immutable data-structures rather than undoing from a transaction log.

SQL is a [large and complex language](https://mariadb.com/kb/en/sql-99/). Instead of building a entire language from scratch, I embedded a query language in [Julia](http://julialang.org/) and got the type system, data layout, memory management and standard library for free.

Rather than implementing an interpreter over a stable of query operators, I generate and compile a single instance of [GenericJoin](https://arxiv.org/pdf/1310.3314.pdf) per query, relying on JIT [codegen](http://docs.julialang.org/en/release-0.5/manual/metaprogramming/#generated-functions) and [specialization](https://arxiv.org/pdf/1209.5145v1.pdf) to remove the overheads of running in a dynamic language.

So far none of this is particularly novel. One can barely move these days without stepping on a [new](http://hyper-db.de/) [in-memory](http://www.memsql.com/) [database](https://en.wikipedia.org/wiki/VoltDB). [LINQ](https://en.wikipedia.org/wiki/Language_Integrated_Query) has brought in-language queries firmly into the mainstream. [LogicBlox](http://www.logicblox.com/) and [EmptyHeaded](https://github.com/HazyResearch/EmptyHeaded) have demonstrated the practicality of the new multi-join algorithms. Research projects such as [LegoBase](http://www.vldb.org/pvldb/vol7/p853-klonatos.pdf) show the potential of high-level code generation.

But I haven't talked about query planning yet. LegoBase delegates planning to an existing commercial database, which is cheating. EmptyHeaded expects to touch entire tables and so can get away with entropic bounds, but this doesn't cut it for OLTP queries. 

Production-quality OLTP databases employ [complex heuristic planners](http://www.neilconway.org/talks/optimizer/optimizer.pdf) which use statistical summaries of the database to estimate the costs of various possible query plans. Despite many, many programmer-years of tuning these planners still [occasionally barf out a 7-orders-of-magnitude mistake](http://db.cs.berkeley.edu/cs286/papers/queryopt-sigmodblog2014.pdf). 

Even if I was capable of building such a planner by myself, that [opacity](http://s3-ap-southeast-1.amazonaws.com/erbuc/files/3eda2d05-9e83-48bd-948d-e61516be43df.pdf) and [fragility](http://web.eecs.umich.edu/~mozafari/php/data/uploads/sigmod_2015.pdf) would still be cause for concern, since one of my overriding goals for Imp is to have a simple mental model for performance. 

So I have employed a cunning solution to the problem of query planning - I don't do it.

Using GenericJoin reduces the entire planning problem to choosing the variable ordering, and it turns out that picking a not-terrible variable ordering by hand tends to be pretty easy. (And not-terrible is definitely the goal - I don't care so much if I don't get the best possible query plan every time, so long as I'm not getting the 7-orders-of-magnitude failures.)

Take a simple query, such as:

``` sql
SELECT MIN(mc.note) AS production_note,
       MIN(t.title) AS movie_title,
       MIN(t.production_year) AS movie_year
FROM company_type AS ct,
     info_type AS it,
     movie_companies AS mc,
     movie_info_idx AS mi_idx,
     title AS t
WHERE ct.kind = 'production companies'
  AND it.info = 'top 250 rank'
  AND mc.note not like '%(as Metro-Goldwyn-Mayer Pictures)%'
  and (mc.note like '%(co-production)%'
       or mc.note like '%(presents)%')
  AND ct.id = mc.company_type_id
  AND t.id = mc.movie_id
  AND t.id = mi_idx.movie_id
  AND mc.movie_id = mi_idx.movie_id
  AND it.id = mi_idx.info_type_id;
```

We can write this in Imp's awful-but-temporary syntax as:

``` julia
@query begin 
  info_type.info(it, "top 250 rank")
  movie_info_idx.info_type(mi, it)
  movie_info_idx.movie(mi, t)
  title.title(t, title)
  title.production_year(t, production_year)
  movie_companies.movie(mc, t)
  movie_companies.company_type(mc, ct)
  company_type.kind(ct, "production companies")
  movie_companies.note(mc, note)
  @when !contains(note, "(as Metro-Goldwyn-Mayer Pictures)") &&
    (contains(note, "(co-production)") || contains(note, "(presents)"))
  return (note::String, title::String, production_year::Int64)
end
```

Wherever a variable is repeated in more than one field this indicates a join. The compiler simply walks through the query and lists the variables in the order they are mentioned - `it, mi, t, title, production_year, mc, ct, note` - and emits code to run GenericJoin in that order. 

GenericJoin is basically a backtracking search algorithm. That means that the time taken to execute this query is, to a first approximation, proportional to the number of values of `it` that fit the query, plus the number of values of `it, mi` that fit the query, plus the number of values of `it, mi, t` etc. In addition, aside from a constant setup cost, the query only allocates memory to store the final results. That's a mental model that I can work with.

The title of this post includes the word 'practical' which is a pretty strong claim. To back it up, I [translated 112 SQL queries](https://github.com/jamii/imp/blob/fdfad0b0ce686aaab7e9077667d38d25aa4d11f5/examples/Job.jl) from the [Join Order Benchmark](http://www.vldb.org/pvldb/vol9/p204-leis.pdf) into Imp. These queries run against the [IMDB dataset](http://www.imdb.com/interfaces) - 3.7GB of data across 74m rows - and are sufficiently complicated to fool PostgreSQL's cardinality estimator into [10000-fold underestimates](http://i.imgur.com/FMBrjy8.png). 

I wrote each Imp query based only on knowing the sizes of the two largest tables (cast_info at 36m rows and movie_info at 15m rows, and I mis-remembered both while writing this) and common-sense deductions based on the table names. The translation process was mostly mechanical - put a variable that looks like it has high selectivity near the top and walk the join graph from there. The queries are tested against PostgreSQL, and roughly 95% were correct first time. Aside from queries 1a, 2a, 3a and 4a which I repeatedly rewrote while developing the compiler, I only made one attempt per query.

I'm running PostgreSQL 5.4 with default settings (tuning `shared_buffers` and `effective_cache_size` according to the [wiki](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server) yielded worse performance) and with indexes built on every column. The test machine has 32GB of RAM, easily enough to cache the entire database. I used [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl) for deciding the number of trials for each query, and measured median wall time for Imp and median execution time (as reported by `EXPLAIN ANALYZE`) for PostgreSQL.

The full results are [here](https://docs.google.com/spreadsheets/d/1X3kBUYrTZSBfUPzJ2DLtdjp97rcPBE-AKner5KUzScc/edit?usp=sharing). On 95 queries Imp is between 1.1x and 560x faster than PostgreSQL. On 16 queries Imp is between 1.1x and 6x slower. On 1 query Imp is 24x slower. (On a [factorized version](https://github.com/jamii/imp/blob/fdfad0b0ce686aaab7e9077667d38d25aa4d11f5/examples/Job.jl#L2837-L2930) of that last query, Imp is 20x faster than PostgreSQL. I guess I'll put [factorizing query planner](https://arxiv.org/abs/1504.04044) back on the TODO list.)

To be clear, as a direct comparison this is nonsense. An in-memory, single-threaded query compiler *should* outperform a fully-featured OLTP database. It's a much easier problem. (The fact that Imp is only just barely outperforming PostgreSQL instead of grinding it into the dust is actually somewhat embarrassing, but there's plenty of room for improvement yet).

The point is instead to explore a different set of tradeoffs. Hosting the database inside the language reduces the impedance mismatch and provides a richer collection of types and functions. Replacing the heuristic planner with hints from the user makes the performance more predictable. Using modern join algorithms simplifies the implementation and [raises the performance ceiling](https://pdfs.semanticscholar.org/cd49/d6f4b86ae47d7d08dd7deccecdc424797aa7.pdf).

The whole reason we invented relational databases is because we got fed up of [coupling code to data-structures](https://en.wikipedia.org/wiki/Data_independence). But our existing databases are such a pain in the ass to interact with that the genius of that idea has been largely forgotten. Instead I spend much of my life hand-navigating webs of hashtables.

SQLite has the tagline 'SQLite competes with fopen()'. I would like to get to the point where I can claim 'Imp competes with hashtables'.

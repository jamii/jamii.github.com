---
layout: "post"
title: "A relational query compiler in 500 lines of code"
date: "2016-09-16 16:20"
---

[Imp](https://github.com/jamii/imp/) needed a relational database that is easy to modify and extend, but fast enough to power real applications. 

Relational databases are usually complicated beasts. Even SQLite, a relatively lightweight database, is [116,000 lines of code](https://www.sqlite.org/testing.html). The [btree implementation](http://www.sqlite.org/src/artifact/7a45743fb947c89b) alone is almost 10000 lines, and the [core of the query plan interpreter](http://www.sqlite.org/src/artifact/f43aa96f2efe9bc8) is another 7000 lines. At 100 lines of correct code per day, that's half a year of work just for those two files. Not to mention writing tests and optimizing code.

Rompf and Amin demonstrated that using [Lightweight Modular Staging](https://scala-lms.github.io/) it's possible to build a [practical query compiler in 500 lines of code](https://www.cs.purdue.edu/homes/rompf/papers/rompf-icfp15.pdf), and the related [LegoBase compiler](http://www.vldb.org/pvldb/vol7/p853-klonatos.pdf) is able to outperform commercial in-memory systems with only a few thousand more lines. This is an exciting approach to *query compilation*, but neither of these systems have anything to say about *query planning*. LegoBase borrows the query planner from an existing database, while the smaller compiler doesn't do any planning at all.

The system I built for Imp is not nearly as elegant as LegoBase, and likely not as fast either, but it is similarly concise, is implementable in any language that has a macro system or preprocessor and uses a unusual approach to query planning based on programmer hints. In the rest of this post I'll walk through the underlying data-structures, the query compiler and the planning system, followed by a set of benchmarks against PostgreSQL on a small but non-trivial dataset. 

## Relations

There is a [fundamental tradeoff between read and write speed](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.211.8649&rep=rep1&type=pdf) in index data-structures. Writes in Imp can mostly be batched and query planning is hard, so I'm leaning all the way towards read speed. Indexes in Imp are just sorted structs-of-arrays. Each relation might need to be sorted in multiple orders, so relations contain a map from column orderings to sorted indexes.

``` julia
type Relation{T <: Tuple} # where T is a tuple of columns
  columns::T
  indexes::Dict{Vector{Int},T}
end

function index{T}(relation::Relation{T}, order::Vector{Int})
  get!(relation.indexes, order) do
    columns = tuple(((ix in order) ? copy(column) : Vector{eltype(column)}() for (ix, column) in enumerate(relation.columns))...)
    sort!(tuple((columns[ix] for ix in order)...))
    columns
  end::T
end
```

Of course, `sort!` doesn't yet know what to do with a tuple of columns. In an ideal world, I would only have to implement:

``` julia
type Index{T <: Tuple}
  columns::T
end

function Base.length(index::Index)
  length(index[1])
end

function Base.getindex(index::Index, i)
  map((c) -> c[i], index.columns)
end

function Base.setindex(index::Index, i, vals)
  for (c, v) in zip(index.columns, vals)
    c[i] = v
  end
end
```

That is, define the array interface on indexes to get and set tuples of values. Unfortunately, until [Julia's unboxing is improved](https://github.com/JuliaLang/julia/pull/18632) those tuples will sometimes be allocated on the heap, and this leads to pretty heavy performance penalties on large indexes. For the time being I've had to [inline the entire sort implementation](https://github.com/jamii/imp/blob/d27ab3fed056e6d551a58fa3525a8ed1a11c98c5/src/Data.jl#L7-L92). 

That's all thats needed to support queries. For actual practical use there are another [150 lines of so](https://github.com/jamii/imp/blob/d27ab3fed056e6d551a58fa3525a8ed1a11c98c5/src/Data.jl#L109-L253) of useful functions for creating, updating and diffing relations.

## Queries (in theory)

Rather than the [traditional System-R -style tree of operations](http://www.neilconway.org/talks/optimizer/optimizer.pdf), Imp uses one of the recently developed [worst-case-optimal](http://arxiv.org/abs/1310.3314) join algorithms - [Leapfrog Triejoin](https://arxiv.org/abs/1210.0481). This algorithm essentially performs a backtracking search over all the unknown variables in the query.

Let's take a simple SQL query.

``` sql
SELECT artist.name
FROM playlist, playlist_track, track, album, artist
WHERE playlist.name = 'Heavy Metal Classic'
  AND playlist.id = playlist_track.playlist
  AND track.id = playlist_track.track
  AND album.id = track.album
  AND artist.id = album.artist
```

Here is the same query in Imp.

``` julia
@query begin
  playlist(playlist_id, "Heavy Metal Classic")
  playlist_track(playlist_id, track_id)
  track(track_id, track_name, album_id)
  album(album_id, _, artist_id)
  artist(artist_id, artist_name)
  return (track_name::String, artist_name::String,)
end
```

Imp is aimed at highly-normalized schemas so it uses positional arguments instead of named columns. `playlist`, `playlist_track` etc are table names. `playlist_id`, `track_id` etc are variable names. Whenever the same variable is used in more than one field, it indicates a join on those fields.

The query compiler is given this query and an order in which to search the variables, let's say `"Heavy Metal Classic", playlist_id, track_id, track_name, album_id, artist_id, artist_name`, and emits code that looks something like:

``` julia
index_playlist = index(playlist, [2,1])
index_playlist_track = index(playlist_track, [1,2])
index_track = index(track, [1,2,3])
index_album = index(album, [1,3])
index_artist = index(artist, [1,2])
results_track_name = Vector{String}()
results_artist_name = Vector{String}()
for playlist_id in intersect(index_playlist["Heavy Metal Classic"], index_playlist_track)
  for track_id in intersect(index_playlist_track[playlist_id], index_track)
    for track_name in intersect(index_track[track_id])
      for album_id in intersect(index_track[track_id, track_name], index_album)
        for artist_id in intersect(index_album[album_id], index_artist)
          for artist_name in intersect(index_artist[artist_id])
            push!(results_track_name, track_name)
            push!(results_artist_name, artist_name)
          end
        end
      end
    end
  end
end
return Relation((results_track_name, results_artist_name,))          
```

Let's unpack that a little.

First, it finds or builds indexes for each table, sorted in the same order as the search order for the matching variables. `track_id` comes before `album_id` in the search order, so the index for `track(track_id, _, album_id)` is sorted in the order `[1,3]`, ignoring the unused second column. 

Next, we take `index_playlist` and project it down to the rows where the playlist name is `"Heavy Metal Classic"` (we can do this efficiently because the index is sorted first by playlist name, and then by playlist id). Then we lazily iterate over all the playlist ids that are contained in both `index_playlist["Heavy Metal Classic"]` and in the first column of `index_playlist_track`.

For each `playlist_id`, we take `index_playlist_track` and project it down to the rows with a matching playlist id. Then we lazily iterate over all the track ids that are contained in both `index_playlist_track[playlist_id]` and `index_track`. 

And so on, until we have found a valid value for every variable, at which point we can emit a result row with `push!(results_track_name, track_name); push!(results_artist_name, artist_name)`.

Finally, the `Relation` constructor sorts the results columns and removes duplicate entries.

Pretty simple so far. The real magic happens in `intersect`. A simplified version for two columns looks like this:

``` julia
function intersect(column_a, column_b)
  ix_a = 1
  ix_b = 1
  while true
    if ix_a > length(column_a)
      return
    end
    value_a = column_a[ix_a]
    ix_b = gallop(column_b, ix_b, >=, value_a)
    value_b = column_b[ix_b]
    if value_a == value_b
      yield value_a
      ix_a = gallop(column_a, ix_a, >, value_a)
      ix_b = gallop(column_b, ix_b, >, value_b)
    else
      ix_a, ix_b = ix_b, ix_a
      column_a, column_b = column_b, column_a
    end
  end
end
```

At each step, it takes the current value in one column and searches (using a variant of binary search) for the first equal-or-greater value in the other column. If it finds a matching value, it yields that value and skips ahead in both columns. If it finds a greater value, it swaps the two columns and starts again.

The process is similar with more columns, searching in each column for the current value of the last column, until all the columns reach the same value. 

This has the neat property of adapting to the distribution of the data - it runs in `O(min_length(columns) log max_length(columns))`. (There are [simpler ways](http://www.frankmcsherry.org/dataflow/relational/join/2015/04/11/genericjoin.html) to achieve this, but they require more complexity in the index - either removing duplicate keys in each column or adding extra metadata to count them.)

That's pretty much the whole query compilation process. Extra features such as user-defined functions and filters are implemented by just inserting the quoted code into the appropriate spot in the search:

``` julia
@query begin
  foo(x)
  bar(x)
  y = x + 1
  @when x < y
  quux(y, z)
  return (x, y, z)
end
```

``` julia
for x in intersect(index_foo, index_bar)
  y = x + 1
  if x < y
    for z in intersect(index_quux[y])
      ...
    end
  end
end
```

Aggregation just uses the normal Julia aggregate functions, and takes advantage of the fact that user-defined functions can be used to nest queries:

``` julia
function cost_of_playlist()
  @query begin
    playlist(p, pn)
    tracks = @query begin 
      playlist_track(p, t)
      track(t, _, _, _, _, _, _, _, price)
      return (t::Int64, price::Float64)
    end
    total = sum(tracks[2])
    return (pn::String, total::Float64)
  end
end
```

All of this leads to a simple mental model for performance. The total amount of memory allocated by a query is proportional to the number of results (and to the size of the indexes, the first time they are built). The total runtime is, to a first approximation, proportional to the total number of times each loop is reached. In the original example query above, that's equal to the number of values of `(playlist_id,)` that satisfy `playlist.name = 'Heavy Metal Classic' AND playlist.id = playlist_id `, plus the number of `(playlist_id, track_id)` pairs that satisfy `playlist.name = 'Heavy Metal Classic' AND playlist.id = playlist_id AND playlist_track.playlist = playlist.id AND playlist_track.track = track.id`, plus the number of `(playlist_id, track_id, track_names)` that satisfy... etc.

At least, that seems simple to me after a few hours of writing queries. The benchmarks later test how well I'm able to actually reason about performance using this mental model.

## Queries (in reality)
    
The description above was somewhat simplified. There are a number of additional optimizations and workarounds to be added before the benchmarks begin.

The most important change is removing wasted lookups. In the example above, every time we find a valid value of `playlist_id` by intersecting `playlist["Heavy Metal Classic"]` with `playlist_track` we then immediately look for it again in `playlist_track[playlist_id]`. In the actual implementation the intersect function returns not just the values but the ranges at which those values can be found in each index:

``` julia
for (playlist_id, range_playlist, range_playlist_track) in intersect((playlist, platlist_track), (range_playlist, range_playlist_track))
  ...
end
```

Another important optimization: in many queries it's possible to skip some results. For example in:

``` julia
for x in intersect(...)
  for y in intersect(...)
    for z in intersect(...)
      push!(results_x, x)
    end
  end
end
```

Once we find some valid set of values for `x, y, z` there is no point in searching for more values of `y` and `z` for the same `x` - that will only result in producing duplicate copies of `x` which will be removed before returning the results anyway. So instead we emit:

``` julia
xs: for x in intersect(...)
  for y in intersect(...)
    for z in intersect(...)
      push!(results_x, x)
      continue xs
    end
  end
end
```

(Or something like it. Julia doesn't have goto or even labeled break/continue, and wrapping the inner loops in `function() ... return` causes other issues.)

Lastly, while it's possible to implement the generated code exactly as presented, it again runs afoul of the current unboxing limitations in Julia. Rather than generating elegant code and bearing the cache pressure of allocating on each loop iteration, I choose to generate, well, this:

``` julia
let  # /home/jamie/imp/src/Query.jl, line 340:
    local index_2 = index($(Expr(:escape, :playlist)),[2,1])
    local index_2_2 = index_2[2]
    local index_2_1 = index_2[1]
    local lo_2_0 = 1
    local hi_2_0 = 1 + length(index_2_2)
    local index_3 = index($(Expr(:escape, :playlist_track)),[1,2])
    local index_3_1 = index_3[1]
    local index_3_2 = index_3[2]
    local lo_3_0 = 1
    local hi_3_0 = 1 + length(index_3_1)
    local index_4 = index($(Expr(:escape, :track)),[1,2,3])
    local index_4_1 = index_4[1]
    local index_4_2 = index_4[2]
    local index_4_3 = index_4[3]
    local lo_4_0 = 1
    local hi_4_0 = 1 + length(index_4_1)
    local index_5 = index($(Expr(:escape, :album)),[1,3])
    local index_5_1 = index_5[1]
    local index_5_3 = index_5[3]
    local lo_5_0 = 1
    local hi_5_0 = 1 + length(index_5_1)
    local index_6 = index($(Expr(:escape, :artist)),[1,2])
    local index_6_1 = index_6[1]
    local index_6_2 = index_6[2]
    local lo_6_0 = 1
    local hi_6_0 = 1 + length(index_6_1) # /home/jamie/imp/src/Query.jl, line 341:
    local results_1 = Vector{$(Expr(:escape, :String))}()
    local results_2 = Vector{$(Expr(:escape, :String))}() # /home/jamie/imp/src/Query.jl, line 342:
    let  # /home/jamie/imp/src/Query.jl, line 343:
        local $(Expr(:escape, Symbol("##constant#2737")))
        local $(Expr(:escape, :playlist_id))
        local $(Expr(:escape, :track_id))
        local $(Expr(:escape, :track_name))
        local $(Expr(:escape, :album_id))
        local $(Expr(:escape, :artist_id))
        local $(Expr(:escape, :artist_name)) # /home/jamie/imp/src/Query.jl, line 344:
        let  # /home/jamie/imp/src/Query.jl, line 318:
            $(Expr(:escape, Symbol("##constant#2737"))) = $(Expr(:escape, "Heavy Metal Classic")) # /home/jamie/imp/src/Query.jl, line 319:
            begin  # /home/jamie/imp/src/Query.jl, line 33:
                (lo_2_1,c) = gallop(index_2_2,$(Expr(:escape, Symbol("##constant#2737"))),lo_2_0,hi_2_0,0) # /home/jamie/imp/src/Query.jl, line 34:
                if c == 0 # /home/jamie/imp/src/Query.jl, line 35:
                    (hi_2_1,_) = gallop(index_2_2,$(Expr(:escape, Symbol("##constant#2737"))),lo_2_1 + 1,hi_2_0,1) # /home/jamie/imp/src/Query.jl, line 36:
                    begin  # /home/jamie/imp/src/Query.jl, line 48:
                        begin  # /home/jamie/imp/src/Query.jl, line 49:
                                lo_2_2 = lo_2_1
                                lo_3_1 = lo_3_0 # /home/jamie/imp/src/Query.jl, line 50:
                                total = 1 # /home/jamie/imp/src/Query.jl, line 51:
                                while true # /home/jamie/imp/src/Query.jl, line 52:
                                    if total == 2 # /home/jamie/imp/src/Query.jl, line 53:
                                        (hi_2_2,_) = gallop(index_2_1,index_2_1[lo_2_2],lo_2_2 + 1,hi_2_1,1)
                                        (hi_3_1,_) = gallop(index_3_1,index_3_1[lo_3_1],lo_3_1 + 1,hi_3_0,1) # /home/jamie/imp/src/Query.jl, line 54:
                                        $(Expr(:escape, :playlist_id)) = index_2_1[lo_2_2] # /home/jamie/imp/src/Query.jl, line 55:
                                        begin  # /home/jamie/imp/src/Query.jl, line 48:
                                            begin  # /home/jamie/imp/src/Query.jl, line 49:
                                                    lo_3_2 = lo_3_1
                                                    lo_4_1 = lo_4_0 # /home/jamie/imp/src/Query.jl, line 50:
                                                    total = 1 # /home/jamie/imp/src/Query.jl, line 51:
                                                    while true # /home/jamie/imp/src/Query.jl, line 52:
                                                        if total == 2 # /home/jamie/imp/src/Query.jl, line 53:
                                                            (hi_3_2,_) = gallop(index_3_2,index_3_2[lo_3_2],lo_3_2 + 1,hi_3_1,1)
                                                            (hi_4_1,_) = gallop(index_4_1,index_4_1[lo_4_1],lo_4_1 + 1,hi_4_0,1) # /home/jamie/imp/src/Query.jl, line 54:
                                                            $(Expr(:escape, :track_id)) = index_3_2[lo_3_2] # /home/jamie/imp/src/Query.jl, line 55:
                                                            begin  # /home/jamie/imp/src/Query.jl, line 48:
                                                                begin  # /home/jamie/imp/src/Query.jl, line 49:
                                                                        lo_4_2 = lo_4_1 # /home/jamie/imp/src/Query.jl, line 50:
                                                                        total = 1 # /home/jamie/imp/src/Query.jl, line 51:
                                                                        while true # /home/jamie/imp/src/Query.jl, line 52:
                                                                            if total == 1 # /home/jamie/imp/src/Query.jl, line 53:
                                                                                (hi_4_2,_) = gallop(index_4_2,index_4_2[lo_4_2],lo_4_2 + 1,hi_4_1,1) # /home/jamie/imp/src/Query.jl, line 54:
                                                                                $(Expr(:escape, :track_name)) = index_4_2[lo_4_2] # /home/jamie/imp/src/Query.jl, line 55:
                                                                                begin  # /home/jamie/imp/src/Query.jl, line 48:
                                                                                    begin  # /home/jamie/imp/src/Query.jl, line 49:
                                                                                            lo_4_3 = lo_4_2
                                                                                            lo_5_1 = lo_5_0 # /home/jamie/imp/src/Query.jl, line 50:
                                                                                            total = 1 # /home/jamie/imp/src/Query.jl, line 51:
                                                                                            while true # /home/jamie/imp/src/Query.jl, line 52:
                                                                                                if total == 2 # /home/jamie/imp/src/Query.jl, line 53:
                                                                                                    (hi_4_3,_) = gallop(index_4_3,index_4_3[lo_4_3],lo_4_3 + 1,hi_4_2,1)
                                                                                                    (hi_5_1,_) = gallop(index_5_1,index_5_1[lo_5_1],lo_5_1 + 1,hi_5_0,1) # /home/jamie/imp/src/Query.jl, line 54:
                                                                                                    $(Expr(:escape, :album_id)) = index_4_3[lo_4_3] # /home/jamie/imp/src/Query.jl, line 55:
                                                                                                    begin  # /home/jamie/imp/src/Query.jl, line 48:
                                                                                                        begin  # /home/jamie/imp/src/Query.jl, line 49:
                                                                                                                lo_5_2 = lo_5_1
                                                                                                                lo_6_1 = lo_6_0 # /home/jamie/imp/src/Query.jl, line 50:
                                                                                                                total = 1 # /home/jamie/imp/src/Query.jl, line 51:
                                                                                                                while true # /home/jamie/imp/src/Query.jl, line 52:
                                                                                                                    if total == 2 # /home/jamie/imp/src/Query.jl, line 53:
                                                                                                                        (hi_5_2,_) = gallop(index_5_3,index_5_3[lo_5_2],lo_5_2 + 1,hi_5_1,1)
                                                                                                                        (hi_6_1,_) = gallop(index_6_1,index_6_1[lo_6_1],lo_6_1 + 1,hi_6_0,1) # /home/jamie/imp/src/Query.jl, line 54:
                                                                                                                        $(Expr(:escape, :artist_id)) = index_5_3[lo_5_2] # /home/jamie/imp/src/Query.jl, line 55:
                                                                                                                        begin  # /home/jamie/imp/src/Query.jl, line 48:
                                                                                                                            begin  # /home/jamie/imp/src/Query.jl, line 49:
                                                                                                                                    lo_6_2 = lo_6_1 # /home/jamie/imp/src/Query.jl, line 50:
                                                                                                                                    total = 1 # /home/jamie/imp/src/Query.jl, line 51:
                                                                                                                                    while true # /home/jamie/imp/src/Query.jl, line 52:
                                                                                                                                        if total == 1 # /home/jamie/imp/src/Query.jl, line 53:
                                                                                                                                            (hi_6_2,_) = gallop(index_6_2,index_6_2[lo_6_2],lo_6_2 + 1,hi_6_1,1) # /home/jamie/imp/src/Query.jl, line 54:
                                                                                                                                            $(Expr(:escape, :artist_name)) = index_6_2[lo_6_2] # /home/jamie/imp/src/Query.jl, line 55:
                                                                                                                                            begin  # /home/jamie/imp/src/Query.jl, line 302:
                                                                                                                                                need_more_results = true # /home/jamie/imp/src/Query.jl, line 303:
                                                                                                                                                begin  # /home/jamie/imp/src/Query.jl, line 285:
                                                                                                                                                    push!(results_1,$(Expr(:escape, :track_name)))
                                                                                                                                                    push!(results_2,$(Expr(:escape, :artist_name))) # /home/jamie/imp/src/Query.jl, line 287:
                                                                                                                                                    need_more_results = false
                                                                                                                                                end
                                                                                                                                            end # /home/jamie/imp/src/Query.jl, line 56:
                                                                                                                                            lo_6_2 = hi_6_2 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                                                            if lo_6_2 >= hi_6_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                                                                break
                                                                                                                                            end # /home/jamie/imp/src/Query.jl, line 58:
                                                                                                                                            total = 1
                                                                                                                                        end # /home/jamie/imp/src/Query.jl, line 60:
                                                                                                                                        begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                                                                                                            if total < 1 # /home/jamie/imp/src/Query.jl, line 62:
                                                                                                                                                (lo_6_2,c) = gallop(index_6_2,index_6_2[lo_6_2],lo_6_2,hi_6_1,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                                                                                                total = if c == 0
                                                                                                                                                        total + 1
                                                                                                                                                    else 
                                                                                                                                                        1
                                                                                                                                                    end # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                                                                if lo_6_2 >= hi_6_1 # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                                                                    break
                                                                                                                                                end
                                                                                                                                            end
                                                                                                                                        end
                                                                                                                                    end
                                                                                                                                end
                                                                                                                        end # /home/jamie/imp/src/Query.jl, line 56:
                                                                                                                        lo_5_2 = hi_5_2
                                                                                                                        lo_6_1 = hi_6_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                                        if lo_5_2 >= hi_5_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                                            break
                                                                                                                        end
                                                                                                                        if lo_6_1 >= hi_6_0 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                                            break
                                                                                                                        end # /home/jamie/imp/src/Query.jl, line 58:
                                                                                                                        total = 1
                                                                                                                    end # /home/jamie/imp/src/Query.jl, line 60:
                                                                                                                    begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                                                                                        if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                                                                                                            (lo_5_2,c) = gallop(index_5_3,index_6_1[lo_6_1],lo_5_2,hi_5_1,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                                                                            total = if c == 0
                                                                                                                                    total + 1
                                                                                                                                else 
                                                                                                                                    1
                                                                                                                                end # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                                            if lo_5_2 >= hi_5_1 # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                                                break
                                                                                                                            end
                                                                                                                        end
                                                                                                                    end
                                                                                                                    begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                                                                                        if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                                                                                                            (lo_6_1,c) = gallop(index_6_1,index_5_3[lo_5_2],lo_6_1,hi_6_0,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                                                                            total = if c == 0
                                                                                                                                    total + 1
                                                                                                                                else 
                                                                                                                                    1
                                                                                                                                end # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                                            if lo_6_1 >= hi_6_0 # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                                                break
                                                                                                                            end
                                                                                                                        end
                                                                                                                    end
                                                                                                                end
                                                                                                            end
                                                                                                    end # /home/jamie/imp/src/Query.jl, line 56:
                                                                                                    lo_4_3 = hi_4_3
                                                                                                    lo_5_1 = hi_5_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                    if lo_4_3 >= hi_4_2 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                        break
                                                                                                    end
                                                                                                    if lo_5_1 >= hi_5_0 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                                        break
                                                                                                    end # /home/jamie/imp/src/Query.jl, line 58:
                                                                                                    total = 1
                                                                                                end # /home/jamie/imp/src/Query.jl, line 60:
                                                                                                begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                                                                    if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                                                                                        (lo_4_3,c) = gallop(index_4_3,index_5_1[lo_5_1],lo_4_3,hi_4_2,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                                                        total = if c == 0
                                                                                                                total + 1
                                                                                                            else 
                                                                                                                1
                                                                                                            end # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                        if lo_4_3 >= hi_4_2 # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                            break
                                                                                                        end
                                                                                                    end
                                                                                                end
                                                                                                begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                                                                    if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                                                                                        (lo_5_1,c) = gallop(index_5_1,index_4_3[lo_4_3],lo_5_1,hi_5_0,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                                                        total = if c == 0
                                                                                                                total + 1
                                                                                                            else 
                                                                                                                1
                                                                                                            end # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                        if lo_5_1 >= hi_5_0 # /home/jamie/imp/src/Query.jl, line 64:
                                                                                                            break
                                                                                                        end
                                                                                                    end
                                                                                                end
                                                                                            end
                                                                                        end
                                                                                end # /home/jamie/imp/src/Query.jl, line 56:
                                                                                lo_4_2 = hi_4_2 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                if lo_4_2 >= hi_4_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                                                    break
                                                                                end # /home/jamie/imp/src/Query.jl, line 58:
                                                                                total = 1
                                                                            end # /home/jamie/imp/src/Query.jl, line 60:
                                                                            begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                                                if total < 1 # /home/jamie/imp/src/Query.jl, line 62:
                                                                                    (lo_4_2,c) = gallop(index_4_2,index_4_2[lo_4_2],lo_4_2,hi_4_1,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                                    total = if c == 0
                                                                                            total + 1
                                                                                        else 
                                                                                            1
                                                                                        end # /home/jamie/imp/src/Query.jl, line 64:
                                                                                    if lo_4_2 >= hi_4_1 # /home/jamie/imp/src/Query.jl, line 64:
                                                                                        break
                                                                                    end
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                            end # /home/jamie/imp/src/Query.jl, line 56:
                                                            lo_3_2 = hi_3_2
                                                            lo_4_1 = hi_4_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                            if lo_3_2 >= hi_3_1 # /home/jamie/imp/src/Query.jl, line 57:
                                                                break
                                                            end
                                                            if lo_4_1 >= hi_4_0 # /home/jamie/imp/src/Query.jl, line 57:
                                                                break
                                                            end # /home/jamie/imp/src/Query.jl, line 58:
                                                            total = 1
                                                        end # /home/jamie/imp/src/Query.jl, line 60:
                                                        begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                            if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                                                (lo_3_2,c) = gallop(index_3_2,index_4_1[lo_4_1],lo_3_2,hi_3_1,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                total = if c == 0
                                                                        total + 1
                                                                    else 
                                                                        1
                                                                    end # /home/jamie/imp/src/Query.jl, line 64:
                                                                if lo_3_2 >= hi_3_1 # /home/jamie/imp/src/Query.jl, line 64:
                                                                    break
                                                                end
                                                            end
                                                        end
                                                        begin  # /home/jamie/imp/src/Query.jl, line 61:
                                                            if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                                                (lo_4_1,c) = gallop(index_4_1,index_3_2[lo_3_2],lo_4_1,hi_4_0,0) # /home/jamie/imp/src/Query.jl, line 63:
                                                                total = if c == 0
                                                                        total + 1
                                                                    else 
                                                                        1
                                                                    end # /home/jamie/imp/src/Query.jl, line 64:
                                                                if lo_4_1 >= hi_4_0 # /home/jamie/imp/src/Query.jl, line 64:
                                                                    break
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                        end # /home/jamie/imp/src/Query.jl, line 56:
                                        lo_2_2 = hi_2_2
                                        lo_3_1 = hi_3_1 # /home/jamie/imp/src/Query.jl, line 57:
                                        if lo_2_2 >= hi_2_1 # /home/jamie/imp/src/Query.jl, line 57:
                                            break
                                        end
                                        if lo_3_1 >= hi_3_0 # /home/jamie/imp/src/Query.jl, line 57:
                                            break
                                        end # /home/jamie/imp/src/Query.jl, line 58:
                                        total = 1
                                    end # /home/jamie/imp/src/Query.jl, line 60:
                                    begin  # /home/jamie/imp/src/Query.jl, line 61:
                                        if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                            (lo_2_2,c) = gallop(index_2_1,index_3_1[lo_3_1],lo_2_2,hi_2_1,0) # /home/jamie/imp/src/Query.jl, line 63:
                                            total = if c == 0
                                                    total + 1
                                                else 
                                                    1
                                                end # /home/jamie/imp/src/Query.jl, line 64:
                                            if lo_2_2 >= hi_2_1 # /home/jamie/imp/src/Query.jl, line 64:
                                                break
                                            end
                                        end
                                    end
                                    begin  # /home/jamie/imp/src/Query.jl, line 61:
                                        if total < 2 # /home/jamie/imp/src/Query.jl, line 62:
                                            (lo_3_1,c) = gallop(index_3_1,index_2_1[lo_2_2],lo_3_1,hi_3_0,0) # /home/jamie/imp/src/Query.jl, line 63:
                                            total = if c == 0
                                                    total + 1
                                                else 
                                                    1
                                                end # /home/jamie/imp/src/Query.jl, line 64:
                                            if lo_3_1 >= hi_3_0 # /home/jamie/imp/src/Query.jl, line 64:
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                    end
                end
            end
        end
    end # /home/jamie/imp/src/Query.jl, line 346:
    Relation(tuple(results_1,results_2),2)
end
```

I'm not even ashamed.

Essentially, this is what you get if you take the pretty code above and manually inline all the functions and data-structures. It's not the most beautiful code I've ever written, but it was easy to implement and it works. Hopefully it won't be long before Julia improves to the point that I can write the pretty version without sacrificing performance.

However, even the the current version, in all its grotesque splendor, is only [350 lines](https://github.com/jamii/imp/blob/d27ab3fed056e6d551a58fa3525a8ed1a11c98c5/src/Query.jl#L7-L357), including the parser and 'planner'.

## Planning

Earlier, the query compiler was magically handed a variable ordering with no explanation. Different variable orderings can produce vastly different performance. In the running example above we choose to search from `"Heavy Metal Classic"` and following the joins down to `artist_name`. If we had instead decided to start from `artist_name` and finish at `"Heavy Metal Classic"` we would have enumerated every single artist-track-album-playlist combination, before filtering the results down to the heavy metal playlist. That would be a disaster. 

Traditional OLTP databases employ [complex heuristic query planners](http://www.neilconway.org/talks/optimizer/optimizer.pdf) which use statistical summaries of the database to estimate the costs of various possible query plans. Even if I was capable of building such a planner by myself, the [opacity](http://s3-ap-southeast-1.amazonaws.com/erbuc/files/3eda2d05-9e83-48bd-948d-e61516be43df.pdf) and [fragility](http://web.eecs.umich.edu/~mozafari/php/data/uploads/sigmod_2015.pdf) of those systems would wreck my performance mental model.

Another problem is that many of the uses I have in mind for Imp require compiling queries *before* the data is known. Statistics aren't much help there.

So I have employed a cunning solution to the problem of automatic query planning - I don't do it.

Using Triejoin reduces the entire planning problem to choosing the variable ordering, and it turns out that picking a not-terrible variable ordering by hand tends is not too hard. (And not-terrible is definitely the goal - I don't care so much if I don't get the best possible query plan every time, so long as I'm not getting the 7-orders-of-magnitude failures.)

The compiler simply takes the variables in the order they are first mentioned (with constants moved to the top). The programmer can change the variable ordering by reordering the lines of the query. Reordering the lines can only change the performance of the query, not the results, so we still have a clean separation between the query logic and the execution plan and it's still much less work than writing out the imperative code by hand.

``` julia
playlist(playlist_id, "Heavy Metal Classic")
playlist_track(playlist_id, track_id)
track(track_id, track_name, album_id)
album(album_id, _, artist_id)
artist(artist_id, artist_name)
return (track_name::String, artist_name::String,)

# becomes...

constant_1 = "Heavy Metal Classic"
playlist(playlist_id, constant_1)
playlist_track(playlist_id, track_id)
track(track_id, track_name, album_id)
album(album_id, _, artist_id)
artist(artist_id, artist_name)
return (track_name::String, artist_name::String,)

# which is ordered...

[constant_1, playlist_id, track_id, track_name, album_id, artist_id, artist_name]
```

(I also implemented a hint syntax - `@hint foo bar` has no effect except to mention `foo` and `bar` - but this wasn't needed for any of the benchmarks).

## Benchmarks

This approach to query planning is a pretty major departure from normal practice, so I spent some time testing it out.

I translated 112 queries from the [Join Order Benchmark](http://www.vldb.org/pvldb/vol7/p853-klonatos.pdf) into Imp and benchmarked them against Postgres. 

These queries test complex joins with many constraints, but do not test aggregation or subqueries. They run against the [IMDB dataset](http://www.imdb.com/interfaces) - 3.7GB of data across 74m rows - and are sufficiently complicated to fool Postgres' cardinality estimator into [10000-fold underestimates](http://i.imgur.com/FMBrjy8.png). I chose it because it uses a real dataset which, as the paper demonstrates, is more challenging for heuristic planners then the synthetic datasets used by [TPC](http://www.tpc.org/). 

This is in no way intended to be a direct comparison to Postgres - the two systems are so wildly different that it makes no sense to compare them. Instead, I'm using Postgres as a milestone for 'fast enough' performance - if Imp can keep up with Postgres on a real dataset, even one this small, I can have some confidence that I haven't dug myself into a hole with these design decisions. 

I wrote each Imp query based only on knowing the sizes of the two largest tables (cast_info at 36m rows and movie_info at 15m rows, and I mis-remembered both while writing this) and common-sense deductions based on the table names. The translation process was mostly mechanical - put a variable that looks like it has high selectivity near the top and walk the join graph from there. The queries are tested against Postgres, and roughly 95% were correct first time. Aside from queries 1a, 2a, 3a and 4a which I repeatedly rewrote while developing the compiler, I only made one attempt per query.

You can find the dataset [here](http://homepages.cwi.nl/%7Eboncz/job/imdb.tgz), the queries and schema [here](http://www-db.in.tum.de/~leis/qo/job.tgz), my postgres setup [here](https://github.com/jamii/imp/blob/d27ab3fed056e6d551a58fa3525a8ed1a11c98c5/data/postgres_job) and the benchmarking code [here](https://github.com/jamii/imp/blob/d27ab3fed056e6d551a58fa3525a8ed1a11c98c5/examples/Job.jl#L2873-L2994). Here are some quick highlights:

* I test that both Imp and Postgres return the same results for each query.
* Postgres has btree indexes on every column, but does not have any indexes that support `LIKE`.
* I didn't find a configuration for Postgres that dominated all other configurations. I give results for a) for the default configuration and b) defaults plus `geqo=off` and `shared_buffers=8gb`.
* I use [BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) to decide the number of trials, with a minimum of 3 and with a single warmup beforehand.
* I measure wall time for Imp and execution time for Postgres (as reported by `EXPLAIN ANALYZE`), and report the median.
* I run Postgres queries with `EXPLAIN (ANALYZE, BUFFERS)` and fail the benchmark if any query has a buffer miss i.e. all reported times are for fully buffered data.
* Yes, I ran `VACUUM` and `ANALYZE` before benchmarking.

The full results are [here](https://docs.google.com/spreadsheets/d/1X3kBUYrTZSBfUPzJ2DLtdjp97rcPBE-AKner5KUzScc/edit?usp=sharing). On 12 queries Imp is 1.0-6.3x slower than Postgres. On 100 queries Imp is faster than Postgres, usually by 1-10x but with a few outliers of up to 867x. Examining the outlying [queries](https://gist.github.com/jamii/c36a0036503be18834a2127ba4e2e02c) and [their plans](https://explain.depesz.com/s/R628) my judgment is that, contrary to their claims of innocence, the author deliberately crafted them to confuse Postgres with cross-constraint correlations. Many of the queries contain correlations that might realistically come up (eg between `company.country_code = "[jp]"` and `name.name LIKE "%Yu%"`) but the worst outliers have silly redundant constraints.

My interpretation of the results is that, by omitting most of the features that Postgres provides Imp manages a large constant-factor performance advantage, which it then uses to cushion the impact of naive query planning. Exactly how much cushioning is going on is hard to tell from such an uncontrolled experiment. A useful follow-up would be to extract variable orderings from [LogicBlox](http://www.logicblox.com/), which uses the same join algorithm, and run them in Imp to see how much performance a commercial-quality planner buys. 

Memory usage for Imp during the benchmarks is around 16GB. The dataset is only 3.7GB on disk and overhead of the indexes only accounts for a few more GB. I haven't run a memory profiler yet, but I have a strong suspicion that the blame is shared between the overhead of allocating each string individually on the heap and memory fragmentation from the loading process (Julia does not have a compacting collector). The natural way to fix this would be to concatenate each column into a single string, and then fill the column with ranges into that string. But substrings can't currently be unboxed in Julia....

## Conclusion

There are three things that I think are worth taking away from this experiment:

1. Julia is *almost* a fantastic language for [generative programming](http://drops.dagstuhl.de/opus/volltexte/2015/5029/pdf/19.pdf). The combination of a dynamic language, multiple dispatch, quasi-quoting, macros, eval and [generated functions](http://docs.julialang.org/en/release-0.5/manual/metaprogramming/#generated-functions) with *predictable* type-inference and specialization is killer. But in almost every part of Imp there was an elegant, extensible, efficient design that *would* work if the support for unboxing was [as complete as the Julia team want it to be](https://github.com/JuliaLang/julia/pull/18632) and I spent [so much time](https://github.com/jamii/imp/blob/master/diary.md) beating my head against this missing feature. It's so nearly there!

2. The recent wave of worst-case-optimal join algorithms are really easy to implement with code generation and this lowers the bar for writing a query compiler. LegoBase and co already demonstrated the power of staging, but if you don't already have a fancy staging library in your favorite language you don't have to wait - Imp's query compiler could be directly translated into pretty much any language, either as a macro or as preprocessor pass.

3. Automatic query planning might not be essential for every use-case. It certainly makes sense for interactive usage, and for cases where you are splicing user input into a query. But in cases where the queries are fixed and you have a rough idea of what the data looks like, you can choose to have the benefit of a query compiler without sacrificing predictable performance.

I have a plenty more ideas for query compiler and language, but I think for the next month or two I'm going to switch focus to the other side of Imp - building interactive GUIs on top of relations and views.

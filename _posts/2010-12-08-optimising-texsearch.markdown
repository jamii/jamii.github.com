---
layout: post
title: "Optimising texsearch"
date: 2010-12-08 06:16
comments: true
categories: project
redirect_from: one/1291/799313/731344
---

[Texsearch](https://github.com/jamii/texsearch) is a search engine for LaTeX formulae. It forms part of the backend for [latexsearch.com](http://latexsearch.com) which indexes the entire Springer corpus.

Texsearch has only a minimal understanding of LaTeX and no understanding of the structure of the formulae it searches in, but unlike it's competitors (eg [Uniquation](http://uniquation.com/en/)) it's able to index the entire Springer corpus and answer queries quickly and cheaply. It's a brute force solution that gave us an good-enough search engine search engine with minimal research risk.

## Parsing

When searching within LaTeX content we want results that represent the same formulae as the search term. Unfortunately LaTeX presents plenty of opportunities for obfuscating content with macros, presentation commands and just plain weird lexing.

Texsearch uses [PlasTeX](http://plastex.sourceforge.net/) to parse LaTeX formulae and expand macros. The preprocessor then discards any LaTeX elements which relate to presentation rather than content (font, weight, colouring etc). The remaining LaTeX elements are each hashed into a 63 bit integer. This massively reduces the memory consumption, allowing the entire corpus and search index to be held in RAM. Collisions should be rare given that there are far less than 2^63 possible elements.

## Indexing

At the core of texsearch is a search algorithm which performs approximate searches over the search corpus. Specifically, given a search term S and a search radius R we want to return all corpus terms T such that the [Levenshtein distance](http://en.wikipedia.org/wiki/Levenshtein_distance) between S and some substring of T is less than R. This is a common problem in bioinformatics and NLP and there is a [substantial amount of research](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.96.7225&rep=rep1&type=pdf) on how to solve this efficiently. I have been through a range of different algorithms in previous iterations of texsearch and have only recently achieved reasonable performance (mean search time is now ~300ms for a corpus of 1.5m documents). The code is available [here](https://github.com/jamii/texsearch).

We define the distance from latexL to latexR as the minimum Levenshtein distance between latexL and any substring of latexR. With this definition we can specify the results of the search algorithm more simply as returning all corpus terms with distance R of S.

``` ocaml
let distance latexL latexR =
  let maxl, maxr = Array.length latexL, Array.length latexR in
  if maxl = 0 then 0 else
  if maxr = 0 then maxl else
  (* cache.(l).(r) is the distance between latexL[l to maxl] and latexR[r to maxr] *)
  let cache = Array.make_matrix (maxl + 1) (maxr + 1) 0 in
  (* Must match everything on the left *)
  for l = maxl - 1 downto 0 do
    cache.(l).(maxr) <- 1 + cache.(l+1).(maxr)
  done;
  (* General matching *)
  for l = maxl - 1 downto 1 do
    for r = maxr - 1 downto 0 do
      cache.(l).(r) <-
          minimum
            (1 + cache.(l).(r+1))
            (1 + cache.(l+1).(r))
            ((abs (compare latexL.(l) latexR.(r))) + cache.(l+1).(r+1))
  done done;
  (* Non-matches on the right dont count until left starts matching *)
  for r = maxr - 1 downto 0 do
    cache.(0).(r) <-
        minimum
          (cache.(0).(r+1))
          (1 + cache.(1).(r))
          ((abs (compare latexL.(0) latexR.(r))) + cache.(1).(r+1))
  done;
  cache.(0).(0)
```

The search algorithm is built around a [suffix array](http://en.wikipedia.org/wiki/Suffix_array) presenting the following interface:

``` ocaml
type 'a t

val create : unit -> 'a t
val add : 'a t -> ('a * Latex.t) list -> unit
val prepare : 'a t -> unit

val delete : 'a t -> ('a -> bool) -> unit

val find_exact : 'a t -> Latex.t -> (int * 'a) list
val find_approx : 'a t -> float -> Latex.t -> (int * 'a) list
val find_query : 'a t -> float -> Query.t -> (int * 'a) list
```

The data structure is pretty straightforward. We store the LaTeX elements in a DynArray and represent suffixes by a pair of pointers - the first into the DynArray and the second into the LaTeX term itself. Each LaTeX term is matched to an opaque object which is used by the consumer of this module to id the terms.

``` ocaml
type id = int
type pos = int

type 'a t =
  { latexs : Latex.t DynArray.t
  ; opaques : 'a DynArray.t
  ; mutable next_id : id
  ; mutable array : (id * pos) array
  ; mutable unsorted : ('a * Latex.t) list }

let create () =
  { latexs = DynArray.create ()
  ; opaques = DynArray.create ()
  ; next_id = 0
  ; array = Array.make 0 (0,0)
  ; unsorted = []}
```

The suffix array is built in a completely naive way. We just throw all the suffixes into a list and sort it. There are much more efficient methods known but this is fast enough, especially since we do updates offline. The building is separated into two functions to make incremental updates easier.

``` ocaml
let add sa latexs =
  sa.unsorted <- latexs @ sa.unsorted

let insert sa (opaque, latex) =
  let id = sa.next_id in
  sa.next_id <- id + 1;
  DynArray.add sa.opaques opaque;
  DynArray.add sa.latexs latex;
  id

let prepare sa =
  let ids = List.map (insert sa) sa.unsorted in
  let new_suffixes = Util.concat_map (suffixes sa) ids in
  let cmp = compare_suffix sa in
  let array = Array.of_list (List.merge cmp (List.fast_sort cmp new_suffixes) (Array.to_list sa.array)) in
  sa.unsorted <- [];
  sa.array <- array
```

## Exact queries

So now we have a sorted array of suffixes of all our corpus terms. If we want to find all exact matches for a given search term we just do a binary search to find the first matching suffix and then scan through the array until the last matching suffix. For reasons that will make more sense later, we divide this into two stages. Most of the work is done in `gather_exact`, where we perform the search and dump the resulting LaTeX term ids into a HashSet. Then `find_exact` runs through the HashSet and looks up the matching opaques.

``` ocaml
(* binary search *)
let gather_exact ids sa latex =
  (* find beginning of region *)
  (* lo < latex *)
  (* hi >= latex *)
  let rec narrow lo hi =
    let mid = lo + ((hi-lo) / 2) in
    if lo = mid then hi else
    if leq sa latex sa.array.(mid)
    then narrow lo mid
    else narrow mid hi in
  let n = Array.length sa.array in
  let rec traverse index =
    if index >= n then () else
    let (id, pos) = sa.array.(index) in
    if is_prefix sa latex (id, pos)
    then
      begin
	Hashset.add ids id;
	traverse (index+1)
      end
    else () in
  traverse (narrow (-1) (n-1))

let exact_match sa id =
  (0, DynArray.get sa.opaques id)

let find_exact sa latex =
  let ids = Hashset.create 0 in
  gather_exact ids sa latex;
  List.map (exact_match sa) (Hashset.to_list ids)
```

## Approximate queries

Suppose the distance from our search term S to some corpus term T is strictly less than the search radius R. That means that if we split S into R pieces at least one of those pieces must match a substring of T exactly. So our approximate search algorithm is to perform exact searches for each of the R pieces and then calculate the distance to each of the results. Notice the similarity in structure to the previous algorithm. You can also see now that the exact search is split into two functions so that we can reuse `gather_exact`.

``` ocaml
let gather_approx sa precision latex =
  let k = Latex.cutoff precision latex in
  let ids = Hashset.create 0 in
  List.iter (gather_exact ids sa) (Latex.fragments latex k);
  ids

let approx_match sa precision latexL id =
  let latexR = DynArray.get sa.latexs id in
  match Latex.similar precision latexL latexR with
  | Some dist ->
      let opaque = DynArray.get sa.opaques id in
      Some (dist, opaque)
  | None ->
      None

let find_approx sa precision latex =
  let ids = gather_approx sa precision latex in
  Util.filter_map (approx_match sa precision latex) (Hashset.to_list ids)
```

We can also extend this to allow boolean queries.

``` ocaml
let rec gather_query sa precision query =
  match query with
  | Query.Latex (latex, _) -> gather_approx sa precision latex
  | Query.And (query1, query2) -> Hashset.inter (gather_query sa precision query1) (gather_query sa precision query2)
  | Query.Or (query1, query2) -> Hashset.union (gather_query sa precision query1) (gather_query sa precision query2)

let query_match sa precision query id =
  let latexR = DynArray.get sa.latexs id in
  match Query.similar precision query latexR with
  | Some dist ->
      let opaque = DynArray.get sa.opaques id in
      Some (dist, opaque)
  | None ->
      None

let find_query sa precision query =
  let ids = gather_query sa precision query in
  Util.filter_map (query_match sa precision query) (Hashset.to_list ids)
```

This is a lot simpler than my previous approach, which required some uncomfortable reasoning about overlapping regions in quasi-metric spaces.

## Memory usage

This is a significant speed improvement over previous versions but it now consumes a ridiculous amount of memory. The instance running [latexsearch.com](http://latexsearch.com) wavers around 4.7 gb during normal operation and reaches 7-8 gb when updating the index. This pushes other services out of main memory and everything is horribly slow until they swap back in.

The main data structure looks like this:

``` ocaml
type 'a t =
  { latexs : Latex.t DynArray.t
  ; opaques : 'a DynArray.t
  ; deleted : bool DynArray.t
  ; mutable next_id : id
  ; mutable array : (id * pos) array
  ; mutable unsorted : ('a * Latex.t) list }
```

The array field is responsible for the vast majority of the memory usage. Each cell in the array contains a pointer to a tuple containing two integers for a total of 4 words per suffix. The types id and pos are both small integers so if we pack them into a single unboxed integer we can reduce this to 1 word per suffix.

``` ocaml
module Suffix = struct

type id = int
type pos = int

type t = int

let pack_size = (Sys.word_size / 2) - 1
let max_size = 1 lsl pack_size

exception Invalid_suffix of id * pos

let pack (id, pos) =
  if (id < 0) || (id >= max_size)
  || (pos < 0) || (pos >= max_size)
  then raise (Invalid_suffix (id, pos))
  else pos lor (id lsl pack_size)

let unpack suffix =
  let id = suffix lsr pack_size in
  let pos = suffix land (max_size - 1) in
  (id, pos)

end
```

The main data structure then becomes:

``` ocaml
type 'a t =
  { latexs : Latex.t DynArray.t
  ; opaques : 'a DynArray.t
  ; deleted : bool DynArray.t
  ; mutable next_id : id
  ; mutable array : Suffix.t array
  ; mutable unsorted : ('a * Latex.t) list }
```

With this change the memory usage drops down to 1.4 gb. The mean search time also improves. It seems that having fewer cache misses makes up for the extra computation involved in unpacking the suffixes.

Now that the array field is a single block in memory it is easy to move it out of the heap entirely so the gc never has to scan it.

``` ocaml
let ancientify sa =
  sa.array <- Ancient.follow (Ancient.mark sa.array);
  Gc.full_major ()
```

This eliminates gc pauses, and we finally have a usable system.

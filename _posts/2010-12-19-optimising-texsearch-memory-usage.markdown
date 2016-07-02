---
layout: post
title: "Optimising texsearch: memory usage"
date: 2010-12-19 06:16
comments: true
categories: project
redirect_from: /one/1292/752863/348678
---

In my last post I discussed the new search algorithm behind texsearch. There is a significant speed improvement over previous versions but it now consumes a ridiculous amount of memory. The instance running [latexsearch.com](http://latexsearch.com) wavers around 4.7 gb during normal operation and reaches 7-8 gb when updating the index. This pushes other services out of main memory and everything is horribly slow until they swap back in.

<!--more-->

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

The array field is responsible for the vast majority of the memory usage. Each cell in the array contains a pointer to a tuple containing two integers for a total of 4 words per suffix. The types id and pos are both small integers so if we pack them into a single unboxed integer we can reduce this to 1 word per suffix. We have a new module suffix.ml with some simple bit-munging:

``` ocaml
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
```

Notice how confusing infix functions are in ocaml.

The suffix array type becomes:

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

Now that the array field is a single block it is easy to move it out of the heap entirely so the gc never has to scan it.

``` ocaml
let ancientify sa =
  sa.array <- Ancient.follow (Ancient.mark sa.array);
  Gc.full_major ()
```

This eliminates the annoyingly noticeable gc pauses.

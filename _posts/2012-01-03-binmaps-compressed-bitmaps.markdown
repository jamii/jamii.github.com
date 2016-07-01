---
layout: post
title: "Binmaps: compressed bitmaps"
date: 2012-01-03 06:16
comments: true
categories: project
redirect_from: one/1325/618081/392902
---

Lately I've been porting some code from c++. The code in question is a compressed bitmap used in [swift](http://libswift.org) to track which parts of a download have already been retrieved. To reduce the memory usage the original uses lots of pointer tricks. Replicating these in ocaml is interesting.

<!--more-->

Here is the basic idea. Conceptually a binmap is a tree of bitmaps. In a leaf at the bottom of the tree each bit in the bitmap represents one bit. In a leaf one layer above the bottom each bit in the bitmap represents two bits. In a leaf two layers above the bottom each bit in the bitmap represents four bits etc.

``` ocaml
type t =
  { layers : int
  ; tree : tree }

type tree =
  | Bitmap of int
  | Branch of tree * tree
```

Let's pretend for simplicity our bitmaps are only 1 bit wide. Then the string 00000000 would be represented as:

``` ocaml
{ layers = 3
; tree = Bitmap 0 }
```

And the string 00001100 would be:

``` ocaml
{ layers = 3
; tree =
    Branch
      (Bitmap 0)
      (Branch
        (Bitmap 1)
        (Bitmap 0)) }
```

The worst case for this data structure is the string 0101010101... In this case we use about 6.5x as much memory as needed by a plain bitmap (3 words for a Branch with two pointers, 4 words for a Bitmap with a pointer to a boxed Int32). The c++ version uses some simple tricks to reduce this overhead to just over 2x that of a plain bitmap. We can replicate these in ocaml by using a bigarray to simulate raw memory access.

Our data structure looks like this:

``` ocaml
module Array =
struct
  include Bigarray.Array1
  let geti array i = Bitmap.to_int (Bigarray.Array1.get array i)
  let seti array i v = Bigarray.Array1.set array i (Bitmap.of_int v)
end

type t =
    { length : int
    ; layers : int
    ; mutable array : (Bitmap.t, Bitmap.bigarray_elt, Bigarray.c_layout) Array.t
    ; pointers : Widemap.t
    ; mutable free : int }

type node =
  | Bitmap of Bitmap.t
  | Pointer of int

let get_node binmap node_addr is_left =
  let index = node_addr + (if is_left then 0 else 1) in
  match Widemap.get binmap.pointers index with
  | false -> Bitmap (Array.get binmap.array index)
  | true -> Pointer (Array.geti binmap.array index)

let set_node binmap node_addr is_left node =
  let index = node_addr + (if is_left then 0 else 1) in
  match node with
  | Bitmap bitmap ->
      Widemap.set binmap.pointers index false;
      Array.set binmap.array index bitmap
  | Pointer int ->
      Widemap.set binmap.pointers index true;
      Array.seti binmap.array index int
```

Each pair of cells in the array represents a branch. Leaves are hoisted into their parent branch, replacing the pointer. Widemap.t is an extensible bitmap which we use here to track whether a given cell in the array is a pointer or a bitmap. The length field is the number of bits represented by bitmap. The free field will be explained later.

Our previous example string 00001100 would now be represented like this:

``` ocaml
(*
  0 -> Bitmap 0
  1 -> Pointer 2
  2 -> Bitmap 1
  3 -> Bitmap 0
*)

{ length = 8;
; layers = 3;
; array = [| 0, 2, 1, 0 |]
; pointers = Widemap.of_string "0100"
; free = 0 }
```

When the bitmap is changed we may have to add or delete pairs eg if the above example changed to 00001111 it would be represented as:

``` ocaml
(*
  0 -> Bitmap 0
  1 -> Bitmap 1
  2 -> ?
  3 -> ?
*)
```

We can grow and shrink the array as necessary, but since deleted pairs won't necessarily be at the end of the used space the bigarray will become fragmented. To avoid wasting space we can write a linked list into the empty pairs to keep track of free space. 0 is always the root of the tree so we can use it as a list terminator. The free field marks the start of the list.

``` ocaml
let del_pair binmap node_addr =
  Array.seti binmap.array node_addr binmap.free;
  binmap.free <- node_addr

(* double the size of a full array and then initialise the freelist *)
let grow_array binmap =
  assert (binmap.free = 0);
  let old_len = Array.dim binmap.array in
  assert (old_len mod 2 = 0);
  assert (old_len <= max_int);
  let new_len = min max_int (2 * old_len) in
  assert (new_len mod 2 = 0);
  let array = create_array new_len in
  Array.blit binmap.array (Array.sub array 0 old_len);
  binmap.array <- array;
  binmap.free <- old_len;
  for i = old_len to new_len-4 do
    if i mod 2 = 0  then Array.seti array i (i+2)
  done;
  Array.seti array (new_len-2) 0

let add_pair binmap node_left node_right =
  (if binmap.free = 0 then grow_array binmap);
  let node_addr = binmap.free in
  let free_next = Array.geti binmap.array binmap.free in
  binmap.free <- free_next;
  set_node binmap node_addr true node_left;
  set_node binmap node_addr false node_right;
  node_addr
```

I haven't yet written any code to shrink the array but it should be fairly straightforward to recursively copy the tree into a new array and rewrite the pointers.

With the freelist our modified example now looks like this:

``` ocaml
{ length = 8;
; layers = 3;
; array = [| 0, 2, 0, 0 |]
; pointers = Widemap.of_string "0100"
; free = 2 }
```

With the representation sorted the rest of the code more or less writes itself.

The only difficulty lies in choosing the width of the bitmaps used. Using smaller bitmaps increases the granularity of the binmap allowing better compression by compacting more nodes. Using larger bitmaps increases the size of the pointers allowing larger bitmaps to be represented. I've written the binmap code to be width-agnostic; it can easily be made into a functor of the bitmap module.

The paper linked below suggests using a layered address scheme to expand the effective pointer size, where the first bit of the pointer is a flag indicating which layer the address is in. I would suggest rather than putting the flag in the pointer it would be simper to use information implicit in the structure of the tree eg is the current layer mod 8 = 0. Either way, this hugely increases the size of the address space at a the cost of a little extra complexity.

The original version is [here](https://github.com/gritzko/swift/blob/master/doc/binmaps-alenex.pdf) and my version is [here](https://github.com/jamii/binmap). This is just an experiment so far, I certainly wouldn't suggest using it without some serious testing.

Overall I'm not sure how useful this particular data structure is but this method of compacting tree-like types in ocaml is certainly interesting. I suspect it could be at least partially automated.

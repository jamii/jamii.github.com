---
layout: post
title: "Telehash: bit_trees revisited"
date: 2011-03-24 06:16
comments: true
categories:
- erlang
- telehash
---

It has been suggested that the bit_trees presented in my last post are overly complicated. Indeed, in the cold light of the morning there is absolutely no need for that zipper. Without further ado, here is the much simpler version.

<!--more-->

``` erlang
% implements the tree part of kademlias k-buckets
% a bit_tree maps ends (lists of bits) to buckets
% as far as the bit_tree is concerned the buckets are completely opaque
% the bit_tree also calculates various numbers needed for splitting decisions

-module(bit_tree).

-include("conf.hrl").

-export([empty/2, update/4, iter/2]).

% a bit_tree is either a leaf or a branch
-record(leaf, {
	  size, % size of bucket
	  bucket % some opaque bucket of stuff
	 }).
-record(branch, {
	  size, % size(childF) + size(childT)
	  childF, % tree containing nodes whose next bit is false
	  childT % tree containing nodes whose next bit is true
	 }).

% --- api ---

empty(Size, Bucket) ->
    #leaf{size=Size, bucket=Bucket}.
		
update(Fun, Bits, Self, Tree) when is_function(Fun), is_list(Bits), is_list(Self) ->
    update(Fun, Bits, {self, Self}, 0, Tree).

update(Fun, Bits, Gap, Depth, #leaf{bucket=Bucket}) ->
    Gap_size =
	case Gap of
	    {gap, G} -> G;
	    {self, _} -> 0
	end,
    bucket_update_to_tree(Fun(Bits, Depth, Gap_size, Bucket));
update(Fun, Bits, Self, Depth, #branch{childF=ChildF, childT=ChildT}) ->
    [Next|Bits2] = Bits,
    Self2 =
	case Self of
	    {gap, _} -> Self;
	    {self, [Next|Rest]} -> {self, Rest};
	    {self, [false|_]} -> {gap, tree_size(ChildF)};
	    {self, [true|_]} -> {gap, tree_size(ChildT)}
	end,
    Depth2 = Depth+1,
    case Next of
	true ->
	    ChildT2 = update(Fun, Bits2, Self2, Depth2, ChildT),
	    Size = tree_size(ChildF) + tree_size(ChildT2),
	    #branch{size=Size, childF=ChildF, childT=ChildT2};
	false ->
	    ChildF2 = update(Fun, Bits2, Self2, Depth2, ChildF),
	    Size = tree_size(ChildF2) + tree_size(ChildT),
	    #branch{size=Size, childF=ChildF2, childT=ChildT}
    end.

% iterate through buckets in ascending order of xor distance to Bits
iter(Bits, Tree) ->
    iter(Bits, Tree, fun() -> done end).
			     
iter(_Bits, #leaf{bucket=Bucket}, Iter) ->
    fun () ->
	    {Bucket, Iter}
    end;
iter([Bit|Bits], #branch{childF=ChildF, childT=ChildT}, Iter) ->
    case Bit of 
	true ->
	    iter(Bits, ChildT, iter(Bits, ChildF, Iter));
	false ->
	    iter(Bits, ChildF, iter(Bits, ChildT, Iter))
    end.

% --- internal functions ---

tree_size(#leaf{size=Size}) ->
    Size;
tree_size(#branch{size=Size}) ->
    Size.

bucket_update_to_tree({ok, Size, Bucket}) ->
    #leaf{size=Size, bucket=Bucket};
bucket_update_to_tree({split, SplitF, SplitT}) ->
    ChildF = bucket_update_to_tree(SplitF),
    ChildT = bucket_update_to_tree(SplitT),
    #branch{size=tree_size(ChildF)+tree_size(ChildT), childF=ChildF, childT=ChildT}.

% --- end ---
```

And the corresponding test code.

``` erlang
% simple buckets used for testing bit_tree

-module(test_bucket).

-include("conf.hrl").

-export([bits/1, add/3, split/1, add_to_tree/2, make_tree/1, distance/2, list_from/2]).

-define(MAX_SIZE, 3).
-define(BITS, ?END_BITS).

bits(Int) ->
    util:to_bits(<<Int:?BITS>>).

add(Suffix, Int, Bucket) ->
    split([{Suffix, Int} | Bucket]).

split(Bucket) ->
    if 
	length(Bucket) > ?MAX_SIZE -> 
	    BucketF = [{Suffix2, Int2} || {[false | Suffix2], Int2} <- Bucket],
	    BucketT = [{Suffix2, Int2} || {[true | Suffix2], Int2} <- Bucket],
	    {split, split(BucketF), split(BucketT)};
	true ->
	    {ok, length(Bucket), Bucket}
    end.

add_to_tree(Int, Tree) ->
    bit_tree:update(
      fun (Suffix, _Depth, _Gap_size, Bucket) -> 
	      add(Suffix, Int, Bucket) 
      end, 
      bits(Int),
      bits(Int), % dont care about gap for now
      Tree).

make_tree(Ints) ->   
    Tree = bit_tree:empty(0, []),
    lists:foldl(fun add_to_tree/2, Tree, Ints).

distance(IntA, IntB) ->
    util:distance({'end', <<IntA:?BITS>>}, {'end', <<IntB:?BITS>>}).

% output *should* be in ascending order
list_from(Int, Tree) ->
    List = util:iter_to_list(bit_tree:iter(bits(Int), Tree)),
    lists:map(
      fun (Bucket) ->
	      lists:sort([{distance(Int, Elem), Elem} || {_,Elem} <- Bucket])
      end,
      List).
```

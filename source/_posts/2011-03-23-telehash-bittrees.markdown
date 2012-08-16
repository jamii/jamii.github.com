---
layout: post
title: "Telehash: bit_trees"
date: 2011-03-23 06:16
comments: true
categories:
- erlang
- telehash
---

The next step in building a switch is managing a routing table. Actually, the next step is handling sessions via _ring/_line but I'm still mulling over the protocol so we'll skip to the routing table.

<!--more-->

I'll add the usual 'I don't understand Kademlia and I didn't test my code' disclaimer in here.

Routing in the Kademlia paper is described using what can best be called the 'mash everything together and be vague about the details' pattern. I want my switch to be a bit cleaner than that so I've split it into three modules. The first of these is the bit_tree. 

The bit_tree is a suffix tree which maps ends (lists of bits) to buckets. The bit_tree neither knows nor cares what a bucket is and for now you don't either. The utility of this tree comes down to one important property: the floor of the log (base 2) of the XOR distance between two ends is the height of the smallest sub-tree which contains both of them. Got that? For example, if log(distance(EndA,EndB)) == 7.234... then the height of the smallest sub-tree containing both EndA and EndB is 7 nodes. This makes it easy to locate the nearest known nodes to a specified end, something we are supposed to do in response to a *.see* command.

So here is a bog-standard binary suffix tree:

``` erlang
% a bit_tree is either a leaf or a branch
-record(leaf, {
	  size, % size of bucket
	  bucket % some opaque bucket of stuff
	 }).
-record(branch, {
	  size, % size(childF) + size(childT)
	  childF, % tree containing nodes whose next bit is false
	  childT % % tree containing nodes whose next bit is true
	 }).
```

When adding nodes to a bucket we need to keep track of certain numbers which will be used by the router to decide when to split buckets. Some of these are quite complicated so to make this easier we will work with a zipper-like structure instead of using *leaf* and *branch* directly. If you know what a zipper is the code in this post will make sense. If you don't know what a zipper is, go find out. When you come back the code in this post will make sense.

``` erlang
% zipper-esque structure marking a position in a bit_tree
-record(finger, {
	  sizer, % a size function for buckets
	  tree, % current sub-tree
	  self, % the path *to* self (the nodes own end). either {down, Down_bits} or {up, Up_bits, Down_bits, Gap}
		% where Gap is the size of the largest tree containing self but not touching this finger
	  depth, % the number of bits away from the root tree
	  zipper % a list of {Bit, Tree} pairs marking branches NOT taken
	 }).
```

The finger keeps track of where the nodes own end is located in the tree in order to calculate something I have termed the gap - the size of the largest sub-tree containing the nodes own end but not touching the finger.

The empty bit_tree is easy to define:

``` erlang
empty(Self, Bucket, Sizer) ->
    #finger{
       sizer = Sizer,
       tree = #leaf{size=Sizer(Bucket), bucket=Bucket},
       self = {down, Self},
       depth = 0,
       zipper = []
      }.
```

Moving around within the tree is a little more complicated but if you already went away and read about zippers it should feel familiar. Most of the work is in keeping track of the gap.

``` erlang
extend(Bits, #finger{tree=#leaf{}}=Finger) -> % must always end on a leaf
    {Bits, Finger};
extend([Next | Bits],
       #finger{
	 tree = #branch{childF=ChildF, childT=ChildT},
	 self = Self,
	 depth = Depth,
	 zipper = Zipper
	}=Finger) ->
    {Branch_taken, Branch_missed} =
	case Next of
	    false -> {ChildF, ChildT};
	    true -> {ChildT, ChildF}
	end,
    Self2 = 
	case Self of
	    {up, Up, Down, Gap} -> 
		% already stepped out of gap
		{up, [not(Next)|Up], Down, Gap};
	    {down, [Bit|Down]} when Bit == Next ->
		% still in the gap
		{down, Down};
	    {down, [Bit|Down]} when Bit /= Next ->
		% leaving gap, check its size
		{up, [not(Next)], [Bit|Down], tree_size(Branch_missed)}
	end,
    Depth2 = Depth+1,
    Zipper2 = [{not(Next), Branch_missed} | Zipper],
    Finger2 = Finger#finger{
      tree = Branch_taken,
      self = Self2,
      depth = Depth2,
      zipper = Zipper2
     },
    extend(Bits, Finger2).
    
retract(0, Finger) ->
    Finger;
retract(N, 
	#finger{
	  tree = Tree,
	  self = Self,
	  depth = Depth,
	  zipper = [{Last,Branch}|Zipper]
	 }=Finger) when N>0 ->
    Size = tree_size(Tree) + tree_size(Branch),
    Tree2 =
	case Last of
	    false -> #branch{size=Size, childF=Branch, childT=Tree};
	    true -> #branch{size=Size, childF=Tree, childT=Branch}
	end,
    Self2 = 
	case Self of
	    {down, Down} ->
		% already in gap
		{down, [Last|Down]};
	    {up, [], Down, _Gap} ->
		% just entered gap
		{down, [Last|Down]};
	    {up, [Bit|Up], Down, Gap} ->
		% still outside gap
		true = (Bit==Last), % assert
		{up, Up, Down, Gap}
	end,
    Depth2 = Depth-1,
    Finger2 =
	Finger#finger{
	  tree=Tree2,
	  self=Self2,
	  depth=Depth2,
	  zipper=Zipper
	 },
    retract(N-1, Finger2).
```

The *extend* and *retract* functions are only used internally. We export a much simpler function, *move_to*, which moves the finger to point at the bucket corresponding to the specified end.

``` erlang
move_to(Bits, #finger{depth=Depth}=Finger) when length(Bits) == ?END_BITS ->
    % !!! naive version
    extend(Bits, retract(Depth, Finger)).
```

We could make this more efficient by only retracting until the finger meets *Bits* partway up. For now I don't expect performance of the bit_tree to be an issue.

Now that we can find buckets we can modify them. Deciding when to split buckets is not the concern of the bit_tree so we delegate it to the caller.

``` erlang
update(Fun,
       #finger{
	 sizer=Sizer,
	 tree=#leaf{bucket=Bucket}
	}=Finger) ->
    Tree = bucket_update_to_tree(Sizer, Fun(Bucket)),
    Finger#finger{tree=Tree}.

bucket_update_to_tree(Sizer, {ok, Bucket}) ->
    #leaf{size=Sizer(Bucket), bucket=Bucket};
bucket_update_to_tree(Sizer, {split, SplitF, SplitT}) ->
    ChildF = bucket_update_to_tree(Sizer, SplitF),
    ChildT = bucket_update_to_tree(Sizer, SplitT),
    #branch{size=tree_size(ChildF)+tree_size(ChildT), childF=ChildF, childT=ChildT}.
```

In order to handle *.see* commands the *iter* function is used to return buckets in order of distance from the specified end. Here we are making use of the aforementioned nice properties of the bit_tree in order to efficiently return the buckets in order. 

``` erlang
% iterate through buckets in ascending order of xor distance to (current position ++ Suffix)
iter(Suffix, #finger{tree=Tree, zipper=Zipper}) ->
    iter_buckets(Tree, Suffix, iter_zipper(Zipper, Suffix)).

% iterate through buckets in ascending order of xor distance to (current position ++ Suffix)
iter_zipper([], _Suffix) ->
    fun () -> 
	    done
    end;
iter_zipper([{Bit, Tree} | Zipper], Suffix) ->
    iter_buckets(Tree, Suffix, iter_zipper(Zipper, [not(Bit)|Suffix])).

% iterate through buckets in ascending order of xor distance to Bits, then hand over to Iter
iter_buckets(#leaf{bucket=Bucket}, _Bits, Iter) ->
    fun () ->
	    {Bucket, Iter}
    end;
iter_buckets(#branch{childF=ChildF, childT=ChildT}, [Bit|Bits], Iter) ->
    case Bit of 
	true ->
	    iter_buckets(ChildT, Bits, iter_buckets(ChildF, Bits, Iter));
	false ->
	    iter_buckets(ChildF, Bits, iter_buckets(ChildT, Bits, Iter))
    end.
```

It will typically be called like this:

``` erlang
{Suffix, Tree2} = bit_tree:move_to(util:to_bits(End), Tree),
bit_tree:iter(Suffix, Tree2)
```

Splitting the routing table into separate structures like this makes for easier testing. The bit_tree can be tested independently using really simple buckets where the elements are just integers and the buckets split when they reach more than three elements.

``` erlang
% simple buckets used for testing bit_tree

-module(test_bucket).

-include("conf.hrl").

-export([bits/1, add/3, split/1, move_to/2, add_to_tree/2, make_tree/2, distance/2, move_list_from/2, list_from/3]).

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
	    {ok, Bucket}
    end.

move_to(Int, Tree) ->
    bit_tree:move_to(bits(Int), Tree).

add_to_tree(Int, Tree) ->
    {Suffix, Tree2} = move_to(Int, Tree),
    bit_tree:update(fun (Bucket) -> add(Suffix, Int, Bucket) end, Tree2).

make_tree(Int, Ints) ->   
    Tree = bit_tree:empty(bits(Int), [], fun (Bucket) -> length(Bucket) end),
    lists:foldl(fun add_to_tree/2, Tree, Ints).

distance(IntA, IntB) ->
    util:distance({'end', <<IntA:?BITS>>}, {'end', <<IntB:?BITS>>}).

% output *should* be in ascending order
move_list_from(Int, Tree) -> 
    {Suffix, Tree2} = bit_tree:move_to(bits(Int), Tree),
    list_from(Int, Suffix, Tree2).

list_from(Int, Suffix, Tree) ->
    List = util:iter_to_list(bit_tree:iter(Suffix, Tree)),
    lists:map(
      fun (Bucket) ->
	      lists:sort([{distance(Int, Elem), Elem} || {_,Elem} <- Bucket])
      end,
      List).
```

We can play around with the test buckets a bit:

``` erlang
25> Tree = test_bucket:make_tree(47, lists:seq(1,1000)).      
{finger,#Fun<test_bucket.1.121651971>,
        {leaf,1,[{[false,false,false],1000}]},
        {up,[false,true,false,false,false,false,false,true,true,
             true,true,true,true,true,true,true,true,true,true,true,true,
             true,true|...],
            [true,true,true,true,true,true,true,true,true,true,true,
             true,true,true,true,true,true,true,true,true,true,true|...],
            0},
        157,
        [{false,{branch,8,
                        {branch,4,
                                {leaf,2,[{[true],993},{[false],992}]},
                                {leaf,2,[{[true],995},{[false],994}]}},
                        {branch,4,
                                {leaf,2,[{[true],997},{[false],996}]},
                                {leaf,2,[{[true],999},{[false],998}]}}}},
         {...}|...]}
26> List = test_bucket:move_list_from(657, Tree).             
[[{0,657},{1,656}],
 [{2,659},{3,658}],
 [{4,661},{5,660}],
 [{6,663},{7,662}],
 [{8,665},{9,664}],
 [{10,667},{11,666}],
 [{12,669},{13,668}],
 [{14,671},{15,670}],
 [{16,641},{17,640}],
 [{18,643},{19,642}],
 [{20,645},{21,644}],
 [{22,647},{23,646}],
 [{24,649},{25,648}],
 [{26,651},{27,650}],
 [{28,653},{29,652}],
 [{30,655},{31,654}],
 [{32,689},{33,688}],
 [{34,691},{35,690}],
 [{36,693},{37,692}],
 [{38,695},{39,694}],
 [{40,697},{41,696}],
 [{42,699},{43,698}],
 [{44,701},{45,700}],
 [{46,703},{47,702}],
 [{48,673},{49,672}],
 [{50,675},{51,...}],
 [{52,...},{...}],
 [{...}|...],
 [...]|...]
27> lists:flatten(List) == lists:sort(lists:flatten(List)).
true
```

As usual the full code is in the [repo](http://github.com/jamii/erl-telehash).

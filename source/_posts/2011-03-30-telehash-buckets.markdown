---
layout: post
title: "Telehash: buckets"
date: 2011-03-30 06:16
comments: true
categories:
- erlang
- telehash
---

The other half of the routing table is the buckets which store node addresses.

<!--more-->

Usual disclaimer: none of this is properly tested yet.

The Kademlia paper has much to say on the issue of routing, most of it contradictory. My takeaway from many readings and from browsing the source code of various different implementations is that the following points are the most important:

* each bucket should contain at most *K* nodes
* we should only ever report node addresses which we have personally confirmed exist
* responsive nodes should never be removed from buckets
* nodes should never be removed from buckets unless a suitable replacement exists

The first three points make the routing table very resistant to flooding and spoofing. In particular, they prevent a common attack for p2p networks where some bad guy floods the routing tables of all the other nodes so that all traffic is routed through nodes controlled by the bad guy. The last point prevents nodes from flushing their routing tables if their own network connection goes down.

I think the implementation I have come up with is fairly clean, if a little lengthy. Like the bit_tree I want the bucket to be completely pure. All side effects will be handled by the router itself. The main data structures are explained pretty well by the comments:

``` erlang
-define(K, ?DIAL_DEPTH).

-record(node, {
	  address, % node #address{} record
	  'end', % node end
	  suffix, % the remaining bits of the nodes end left over from the bit_tree
	  status, % one of [live, stale, cache]
	  last_seen % for live/stale nodes, the time of the last received message. for cache nodes the time of the last .see reference to the node
	 }).

-record(bucket, {
	  nodes, % gb_tree mapping addresses to {Status, Last_seen}
	  % remaining fields are pq's of nodes sorted by their last_seen field
	  live, % nodes currently expected to be alive
	  stale, % nodes which have not replied recently
	  cache % potential nodes which we have not yet verified 
	 }). % invariant: pq_maps:size(live) + pq_maps:size(stale) <= ?K
```

The bucket is a two-stage data structure. This allows us the keep nodes of different statuses sorted by the last_seen time but still be able to get/delete nodes just knowing the address. The *get_node* function should make it clear how this works:

``` erlang
get_node(Address, 
	 #bucket{nodes=Nodes, live=Live, stale=Stale, cache=Cache}) ->
    case gb_trees:lookup(Address, Nodes) of
	{value, {Status, Last_seen}} ->
	    case Status of 
		live ->
		    {ok, pq_maps:get({Last_seen, Address}, Live)};
		stale ->
		    {ok, pq_maps:get({Last_seen, Address}, Stale)};
		cache ->
		    {ok, pq_maps:get({Last_seen, Address}, Cache)}
	    end;
	none -> 
	    none
    end.
```

This is only long because records are purely a compile time structure ie we can't write *Bucket#bucket.Status* so we have to pattern match on *Status* instead. We also define *add_node/2*, *del_node/2* and *update_node/2*, which look pretty similar, as well as *to_list/1*, *from_list/1* and *sizes/1*.

The router is going to react to various events by calling the appropriate bucket functions and possibly sending out messages based on the result. The first event it has to handle is a node becoming unresponsive. The bucket will mark this node as stale and return a cache node which the router can attempt to verify.

``` erlang
% this address failed to reply in a timely manner
timedout(Address, Bucket) ->
    log:info([?MODULE, timing_out, Address, Bucket]),
    case get_node(Address, Bucket) of
	{ok, Node} ->
	    case Node#node.status of
		live ->
		    % mark as stale, return a cache node that might be a suitable replacement
		    Bucket2 = update_node(Node#node{status=stale}, Bucket),
		    pop_cache_hi(Bucket2);
		_ -> 
		    % if cache or stale already we don't care 
		    ok(Bucket)
	    end;
	none ->
	    % wtf? we don't even know this node?
	    % one way this could happen: 
	    % send N1, sendN1, timedout N1, add N2 (pushing N1 out of stale), timedout N1 
	    log:warning([?MODULE, unknown_node_timedout, Address, Bucket]),
	    ok(Bucket)
    end.

% return most recently seen cache node, if any exist
pop_cache_hi(#bucket{cache=Cache}=Bucket) ->
    case pq_maps:pop_hi(Cache) of
	{_Key, Node, Cache2} ->
	    {node, Node, ok(Bucket#bucket{cache=Cache2})};
	false ->
	    ok(Bucket)
    end.
```

The next event is receiving a *.see* command. This may be as a result of a *+end* sent by the router but is more likely to be part of a dialing process happening elsewhere. The beauty of Kademlia is that the router can populate the routing table just by listening in on dialing attempts.

For each node listed in the *.see* command the router will call *seen*. This adds the node to the cache and returns the least recently seen live node so the router can check that it is still responsive.

``` erlang
% this address has been reported to exist by another node
seen(Address, Time, Suffix, Bucket) ->
    log:info([?MODULE, seeing, Address, Bucket]),
    case get_node(Address, Bucket) of
	{ok, Node} ->
	    case Node#node.status of
		cache ->
		    % for cache nodes being in a .see is good enough
		    ok(update_node(Node#node{last_seen=Time}, Bucket));
		_ ->
		    % for live/stale nodes we require direct contact so ignore this
		    ok(Bucket)
	    end;
	none ->
	    % put node in cache, return a live node to ping
	    Node = #node{
	      address = Address,
	      'end' = util:to_end(Address),
	      suffix = Suffix,
	      status = cache,
	      last_seen = Time
	     },
	    Bucket2 = add_node(Node, Bucket),
	    case peek_live_lo(Bucket) of
		none -> ok(Bucket2);
		{ok, Live_node} -> {node, Live_node, ok(Bucket2)}
	    end
    end.

% return the oldest live node
peek_live_lo(#bucket{live=Live}) ->
    case pq_maps:peek_lo(Live) of
	none -> none;
	{_, Node} -> {ok, Node}
    end.
```

Any time we receive a message we learn that the node sending it exists (or not - we'll deal with address spoofing in a later post) so we can potentially mark it as a live node. The *touched* function checks if the node is already in the bucket or if it needs to be added.

``` erlang
% this address has been verified as actually existing
touched(Address, Suffix, Time, Bucket, May_split) ->
    log:info([?MODULE, touching, Address, Bucket]),
    case get_node(Address, Bucket) of
	{ok, Node} ->
	    case Node#node.status of
		live -> 
		    % update last_seen time
		    ok(update_node(Node#node{last_seen=Time}, Bucket));
		stale ->
		    % update last_seen time and promote to live
		    ok(update_node(Node#node{last_seen=Time, status=live}, Bucket));
		cache ->
		    % potentially promote the node to live
		    Bucket2 = del_node(Node, Bucket),
		    new_node(Address, Suffix, Time, Bucket2, May_split)
	    end;
	none ->
	    % potentially add the node to live
	    new_node(Address, Suffix, Time, Bucket, May_split)
    end.
```

If the node needs to be added then *touched* calls *new_node* which decides if there is space in the bucket and, if so, adds the new node. If the bucket is full and *May_split* is true then *new_node* will split the bucket before adding the new node. Deciding whether or not splitting is allowed is the routers job.

``` erlang
% assumes Address is not already in Bucket, otherwise crashes
new_node(Address, Suffix, Time, Bucket, May_split) ->
    Node = #node{
      address = Address,
      'end' = util:to_end(Address),
      suffix = Suffix,
      status = undefined,
      last_seen = Time
     },
    {Lives, Stales, _} = sizes(Bucket),
    if
	Lives + Stales < ?K ->
	    % space left in live
	    log:info([?MODULE, adding, Node, Bucket]),
	    ok(add_node(Node#node{status=live}, Bucket));
	(Lives < ?K) and (Stales > 0) ->
	    % space left in live if we push something out of stale
	    log:info([?MODULE, adding, Node, Bucket]),
	    Bucket2 = drop_stale(Bucket),
	    ok(add_node(Node#node{status=live}, Bucket2));
	May_split and (Suffix /= []) ->
	    % allowed to split the bucket to make space
	    log:info([?MODULE, splitting, Node, Bucket]),
	    {split, BucketF, BucketT} = split(Bucket),
	    [Bit | Suffix2] = Suffix,
	    case Bit of
		false ->
		    BucketF2 = new_node(Address, Suffix2, Time, BucketF, May_split),
		    {split, BucketF2, BucketT};
		true ->
		    BucketT2 = new_node(Address, Suffix2, Time, BucketT, May_split),
		    {split, BucketF, BucketT2}
	    end;
	true ->
	    % not allowed to split, will have to go in the cache
	    log:info([?MODULE, caching, Node, Bucket]),
	    ok(add_node(Node#node{status=cache}, bucket))
    end.

% drop the oldest stale node, crashes if none exist
drop_stale(#bucket{stale=Stale}=Bucket) ->
    {_Key, _Node, Stale2} = pq_maps:pop_one_hi(Stale),
    Bucket#bucket{stale=Stale2}.

split(Bucket) ->
    Nodes = to_list(Bucket),
    NodesF = [Node#node{suffix=Suffix2} || #node{suffix=[false|Suffix2]}=Node <- Nodes],
    NodesT = [Node#node{suffix=Suffix2} || #node{suffix=[true|Suffix2]}=Node <- Nodes],
    {split, from_list(NodesF), from_list(NodesT)}.
```

Finally, upon receiving a *+end* signal the router needs to reply with a *.see* command listing the *K* nearest nodes to the specified end. This will be done using a combination of *bit_tree:iter* and *bucket:nearest*.

``` erlang
nearest(N, End, #bucket{live=Live, stale=Stale}) ->
    Nodes = pq_maps:to_list(Live) ++ pq_maps:to_list(Stale),
    Num_nodes = pq_maps:size(Live) + pq_maps:size(Stale),
    if 
	Num_nodes =< N ->
	    [Node#node.address || {_Key, Node} <- Nodes];
	true ->    
	    % !!! maybe should prefer to return live nodes even if further away
	    Nodes_by_dist = [{util:distance(End, Node#node.'end'), Node} || {_Key, Node} <- pq_maps:to_list(Live)],
	    {Closest, _} = lists:split(N, lists:sort(Nodes_by_dist)),
	    [Node#node.address || {_Dist, Node} <- Closest]
    end.
```

As usual all the code is sitting in the [repo](https://github.com/jamii/erl-telehash).

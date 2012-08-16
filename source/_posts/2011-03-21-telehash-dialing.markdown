---
layout: post
title: "Telehash: dialing"
date: 2011-03-21 06:16
comments: true
categories:
- erlang
- telehash
---

The next step in building a telehash switch is being able to dial.

<!--more-->

First a disclaimer: this post reflects my current understanding of TeleHash and Kademlia and is highly likely to be wrong. This code has only received minimal testing. Properly testing a p2p network is not something I'm entirely sure how to do yet. Expect to see more on that in later posts.

Each TeleHash node and each key in the DHT is identified by a 160 bit sha1 hash (aka end). In the original Kademlia paper the node ids are selected at random but in TeleHash they are the hashed address (IP:port) of the node. This means that malicious nodes don't get to choose where they are inserted in the DHT.

Kademlia routing is based on the XOR distance between ends. This forms a metric space over the set of ends.

``` erlang
distance(A, B) ->
    {'end', EndA} = to_end(A),
    {'end', EndB} = to_end(B),
    Bytes = lists:zip(binary_to_list(EndA), binary_to_list(EndB)),
    Xor = list_to_binary([ByteA bxor ByteB || {ByteA, ByteB} <- Bytes]),
    <<Dist:?END_BITS>> = Xor,
    Dist.
```

The Kademlia paper defines two constants, K and A. K controls the amount of redundant storage in the DHT and A controls the number of parallel requests issued by each node. To insert a key into the DHT a node must be able to locate the K nodes whose IDs are closest to the key. This process is called dialing.

Dialing works roughly as follows. Each node keeps track of all the other nodes it has seen. Upon receiving a +end signal a node will reply with a .see command containing the K nodes it is aware of which are closest to the specified end. To dial an end we send a +end signal to each of the K closest nodes we are aware of. Then to each node contained in the .see replies we send +end signals, and so on until we run out of nodes to contact.

Now this is nice and simple and will work but it generates a huge amount of load on the network. To reduce this Kademlia introduces two additional rules. First, we only send up to A signals at a time and don't send any new signals until previous signals have either generated a reply or timed out. Second, we finish early if at any point we have received replies from K nodes which are closer to the end than all the nodes we are waiting to contact. The Kademlia paper proves that under reasonable assumptions about the knowledge of each node this still has a very high chance to return the correct results.

The dialer process is an event handler which has two important data structures. The first stores the dialer configuration:

``` erlang
-record(conf, {
          target, % the end to dial
          timeout, % the timeout for the entire dialing process
          ref, caller % reply details
         }).
```

The second record stores the state of the dialing process. The principle around which the dialer is designed is that the state record is a reflection of the outside world and the sole job of the dialer is to keep this record up to date while maintaining the invariants in the comments. This is often the way that I write code and I feel that it needs it's own post once I can articulate it properly. It's certainly heavily informed both by the designs in [Okasaki's Purely Functional Data Structures](http://books.google.co.uk/books?id=SxPzSTcTalAC&printsec=frontcover&dq=okasaki+purely+functional&hl=en&ei=6GiHTdTcKY_RcfjR_ZkD&sa=X&oi=book_result&ct=result&resnum=1&ved=0CC4Q6AEwAA#v=onepage&q&f=false) and by Conal Elliott's ideas about [denotational semantics and type class morphisms](http://conal.net/blog/posts/denotational-design-with-type-class-morphisms/).

``` erlang
-record(state, {
          fresh, % nodes which have not yet been contacted
          pinged, % nodes which have been contacted and have not replied
          waiting, % nodes in pinged which were contacted less than ?DIAL_TIMEOUT ago
          ponged, % nodes which have been contacted and have replied
          seen % all nodes which have been seen
         }). % invariant: pq:length(waiting) = ?A or pq:empty(fresh)
```
         
The dialer module exports the dial function which creates the records and starts the event handler.

``` erlang
dial(To, From, Timeout) ->
    log:info([?MODULE, dialing, To, From, Timeout]),
    Ref = erlang:make_ref(),
    Target = util:to_end(To),
    Conf = #conf{
      target = Target,
      timeout = Timeout,
      ref = Ref,
      caller = self()
     },
    Nodes = [{util:distance(Address, Target), Address}
             || Address <- From],
    State = #state{
      fresh=pq:from_list(Nodes),
      pinged=sets:new(),
      waiting=pq:empty(),
      ponged=pq:empty(),
      seen=sets:new()
     },
    ok = switch:add_handler(?MODULE, {Conf, State}),
    Ref.
```
    
The aim is to handle events and maintain the state invariants until we are finished. How do we define finished?

``` erlang
% is the dialing finished yet?
finished(#state{fresh=Fresh, waiting=Waiting, ponged=Ponged}) ->
    (pq:is_empty(Fresh) and pq:is_empty(Waiting)) % no way to continue
    or
    (case pq:length(Ponged) >= ?K of
         false ->
             false; % dont yet have K nodes
         true ->
             % finish if the K closest nodes we know are closer than all the nodes we haven't checked yet
             {Dist_fresh, _} = pq:peek(Fresh),
             {Dist_waiting, _} = pq:peek(Waiting),
             {Nodes, _} = pq:pop(Ponged, ?K),
             {Dist_ponged, _} = lists:last(Nodes),
             (Dist_ponged < Dist_fresh) and (Dist_ponged < Dist_waiting)
     end).
```
     
One of the invariants we aim to maintain is that either the fresh queue is empty or the length of the waiting queue is A. This ensures that we send out +end signals whenever possible. This invariant is maintained by calling the ping_nodes function after every event.

``` erlang
% contact nodes from fresh until the waiting list is full
ping_nodes(#conf{target=Target}, #state{fresh=Fresh, waiting=Waiting, pinged=Pinged}=State) ->
    Num = ?A - pq:length(Waiting),
    {Nodes, Fresh2} = pq:pop(Fresh, Num),
    Telex = {struct, [{'+end', util:end_to_hex(Target)}]},
    lists:foreach(
      fun ({Dist, Address}=Node) ->
              log:info([?MODULE, ping, Dist, Address]),
              switch:send(Address, Telex),
              erlang:send_after(?DIAL_TIMEOUT, self(), {timeout, Node})
      end,
      Nodes),
    Waiting2 = pq:push(Nodes, Waiting),
    Pinged2 = sets:union(Pinged, sets:from_list(Nodes)),
    State#state{fresh=Fresh2, waiting=Waiting2, pinged=Pinged2}.
```
    
We handle replies by moving the replying node from the waiting queue to the ponged queue and inserting the .see nodes into the fresh list. We cannot allow duplicate nodes so the seen set is kept up to date. The pinged set will be used later to ensure that we only accept replies from nodes we have already contacted and only accept one reply per node.

``` erlang
% handle a reply from a node
ponged(Node, See, #state{fresh=Fresh, waiting=Waiting, pinged=Pinged, ponged=Ponged, seen=Seen}=State) ->
    Waiting2 = pq:delete(Node, Waiting),
    Pinged2 = sets:del_element(Node, Pinged),
    Ponged2 = pq:push_one(Node, Ponged),
    New_nodes = lists:filter(fun (See_node) -> not(sets:is_element(See_node, Seen)) end, See),
    Fresh2 = pq:push(New_nodes, Fresh),
    Seen2 = sets:union(Seen, sets:from_list(See)),
    State#state{fresh=Fresh2, waiting=Waiting2, pinged=Pinged2, ponged=Ponged2, seen=Seen2}.
```
    
Once we are finished we need to return the results to the caller.

``` erlang
% return results to the caller
return(#conf{ref=Ref, caller=Caller}, #state{ponged=Ponged}) ->
    {Nodes, _} = pq:pop(Ponged, ?K),
    log:info([?MODULE, returning, Nodes]),
    Result = [Address || {_Dist, Address} <- Nodes],
    Caller ! {dialed, Ref, Result}
```

Finally, after each event we call continue to decide whether to finish and return results or to carry on sending signals.

``` erlang
% either continue to dial or return results
% meant for use at the end of a gen_event callback
continue(Conf, State) ->
    case finished(State) of
        true ->
            return(Conf, State),
            remove_handler;
        false ->
            State2 = ping_nodes(Conf, State),
            {ok, {Conf, State2}}
    end.
```

The functions above are glued together by a gen_event handler. The handler is attached to the switch gen_event manager and receives an event for each telex arriving at the switch.

``` erlang
-behaviour(gen_event).
-export([init/1, handle_event/2, handle_call/2, handle_info/2, terminate/2, code_change/3]).
```

The init function is called when the handler is started. It sends out the first +end signals and sets a timer that tells the handler when to give up dialling.

``` erlang
init({#conf{timeout=Timeout}=Conf, State}) ->
    erlang:send_after(Timeout, self(), giveup),
    State2 = ping_nodes(Conf, State),
    {ok, {Conf, State2}}.
```
    
The giveup timeout is simple to deal with.

``` erlang
handle_info(giveup, {Conf, State}) ->
    log:info([?MODULE, giveup, Conf, State]),
    remove_handler;
```
    
As are the timeouts from individual signals.

``` erlang
handle_info({timeout, Node}, {Conf, #state{waiting=Waiting}=State}) ->
    log:info([?MODULE, timeout, Node]),
    State2 = State#state{waiting=pq:delete(Node, Waiting)},
    continue(Conf, State2);
```
    
The last callback is the messiest. This essentially just calls ponged and continue, but first has to sanity check the incoming message.

``` erlang
handle_event({recv, Address, Telex}, {#conf{target=Target}=Conf, #state{pinged=Pinged}=State}) ->
    case telex:get(Telex, '.see') of
        {error, not_found} ->
            {ok, {Conf, State}};
        {ok, Address_binaries} ->
            Dist = util:distance(Address, Target),
            Node = {Dist, Address},
            case sets:is_element(Node, Pinged) of % !!! command ids would make a better check
                false ->
                    {ok, {Conf, State}};
                true ->
                    try [{util:distance(Target, Bin), util:binary_to_address(Bin)} || Bin <- Address_binaries] of
                        Nodes ->
                            log:info([?MODULE, pong, Node, Nodes]),
                            State2 = ponged(Node, Nodes, State),
                            continue(Conf, State2)
                    catch
                        _:Error ->
                            log:info([?MODULE, bad_see, Address, Telex, Error, erlang:get_stacktrace()]),
                            {ok, {Conf, State}}
                    end
            end
    end;
```
    
That's pretty much it - we now (probably) have a working dialer. I spent a fair few hours teasing this apart but hopefully the end result is fairly simple to understand. The full code is in the [repo](http://github.com/jamii/erl-telehash) as always.

``` erlang
4> switch:start_link().
{ok,<0.79.0>,<0.80.0>}
5> Root = {address, "208.68.163.247", 42424}.
{address,"208.68.163.247",42424}
6> dialer:dial_sync(Root, [Root], 10000).

=INFO REPORT==== 21-Mar-2011::14:48:06 ===
    pid: <0.35.0>
    dialer
    dialing
    {address,"208.68.163.247",42424}
    [{address,"208.68.163.247",42424}]
    10000

=INFO REPORT==== 21-Mar-2011::14:48:06 ===
    pid: <0.79.0>
    dialer
    ping
    0
    {address,"208.68.163.247",42424}

=INFO REPORT==== 21-Mar-2011::14:48:06 ===
    pid: <0.80.0>
    switch_event
    send
    {address,"208.68.163.247",42424}
    struct: [{<<"_to">>,<<"208.68.163.247:42424">>},
             {'+end',<<"38666817e1b38470644e004b9356c1622368fa57">>}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.80.0>
    switch_event
    recv
    {address,"208.68.163.247",42424}
    struct: [{<<"_ring">>,18115},
             {<<".see">>,
              [<<"204.232.205.180:42424">>,<<"208.68.163.247:42424">>]},
             {<<"_br">>,240},
             {<<"_to">>,<<"203.218.138.245:42424">>}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.79.0>
    dialer
    pong
    0: {address,"208.68.163.247",42424}
    [{535375931004298447338698443374311161987273280591,
      {address,"204.232.205.180",42424}},
     {0,{address,"208.68.163.247",42424}}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.79.0>
    dialer
    ping
    0
    {address,"208.68.163.247",42424}

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.79.0>
    dialer
    ping
    535375931004298447338698443374311161987273280591
    {address,"204.232.205.180",42424}

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.80.0>
    switch_event
    send
    {address,"208.68.163.247",42424}
    struct: [{<<"_to">>,<<"208.68.163.247:42424">>},
             {'+end',<<"38666817e1b38470644e004b9356c1622368fa57">>}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.80.0>
    switch_event
    send
    {address,"204.232.205.180",42424}
    struct: [{<<"_to">>,<<"204.232.205.180:42424">>},
             {'+end',<<"38666817e1b38470644e004b9356c1622368fa57">>}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.80.0>
    switch_event
    recv
    {address,"204.232.205.180",42424}
    struct: [{<<"_ring">>,16506},
             {<<".see">>,
              [<<"204.232.205.180:42424">>,<<"208.68.163.247:42424">>]},
             {<<"_br">>,162},
             {<<"_to">>,<<"203.218.138.245:42424">>}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.79.0>
    dialer
    pong
    535375931004298447338698443374311161987273280591: {address,
                                                       "204.232.205.180",
                                                       42424}
    [{535375931004298447338698443374311161987273280591,
      {address,"204.232.205.180",42424}},
     {0,{address,"208.68.163.247",42424}}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.80.0>
    switch_event
    recv
    {address,"208.68.163.247",42424}
    struct: [{<<"_ring">>,18115},
             {<<".see">>,
              [<<"204.232.205.180:42424">>,<<"208.68.163.247:42424">>]},
             {<<"_br">>,320},
             {<<"_to">>,<<"203.218.138.245:42424">>}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.79.0>
    dialer
    pong
    0: {address,"208.68.163.247",42424}
    [{535375931004298447338698443374311161987273280591,
      {address,"204.232.205.180",42424}},
     {0,{address,"208.68.163.247",42424}}]

=INFO REPORT==== 21-Mar-2011::14:48:07 ===
    pid: <0.79.0>
    dialer
    returning
    [{0,{address,"208.68.163.247",42424}},
     {535375931004298447338698443374311161987273280591,
      {address,"204.232.205.180",42424}}]
{ok,[{address,"208.68.163.247",42424},
     {address,"204.232.205.180",42424}]}
```

One last note: after I finished writing this I started thinking about what would happen if I run more than one dialer in parallel. Unlike Kademlia, TeleHash does not currently use command IDs so the dialer cannot tell if the response came in reply to its own command or in reply to the command of another dialer on the same node. It's the kind of bug that would be very rare in actual use but might be carefully exploited by a malicious node. Finding these kinds of bugs is going to be really hard.

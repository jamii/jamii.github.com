---
layout: post
title: "Telehash: router"
date: 2011-04-19 06:16
comments: true
categories:
- erlang
- telehash
---

Now that we have all the necessary datastructures we can build the router itself. Most of the routing table logic is handled by the bit_tree and bucket modules. The router just ties these together and handles I/O.

<!--more-->

Before actually running the routing table the router has to find out its own address, as it is seen from the outside world. It does this by sending +end signals to a list of known telehash nodes (eg telehash.org:42424).

``` erlang
record(bootstrap, { % the state of the router when bootstrapping
	  timeout, % give up if no address received before this time
	  addresses % list of addresses contacted to find out our address
	 }).

bootstrap(Addresses, Timeout) ->
    ?INFO([bootstrapping]),
    State = #bootstrap{timeout=Timeout, addresses=Addresses},
    {ok, _Pid} = gen_server:start_link(?MODULE, State, []).

init(State) ->
    switch:listen(),
    case State of
	#bootstrap{timeout=Timeout, addresses=Addresses} ->
	    Telex = telex:end_signal(util:random_end()),
	    lists:foreach(fun (Address) -> switch:send(Address, Telex) end, Addresses),
	    erlang:send_after(Timeout, self(), giveup);
	#state{} ->
	    ok
    end,
    {ok, State}.
```

Then we listen until we either get a reply with a _to field or run out of time.

``` erlang
handle_info({switch, {recv, From, Telex}}, #bootstrap{addresses=Addresses}=Bootstrap) ->
    % bootstrapping, waiting to receive a message telling us our own address
    case {lists:member(From, Addresses), telex:get(Telex, '_to')} of
	{true, {ok, Binary}} ->
	    try util:to_end(util:binary_to_address(Binary)) of
		End ->
		    Self = util:to_bits(End),
		    Table = touched(From, Self, empty_table(Self)),
		    dialer:dial(End, [From], ?ROUTER_DIAL_TIMEOUT),
		    refresh(Self, Table),
		    ?INFO([bootstrap, finished, {self, Binary}, {from, From}]),
		    {noreply, #state{self=Self, pinged=sets:new(), table=Table}}
	    catch
		_ ->
		    ?WARN([bootstrap, bad_self, {self, Binary}, {from, From}]),
		    {noreply, Bootstrap}
	    end;
	_ ->
	    {noreply, Bootstrap}
    end;

handle_info(giveup, #bootstrap{}=Bootstrap) ->
    % failed to bootstrap, die
    ?INFO([giveup, {state, Bootstrap}]),
    {stop, {shutdown, gaveup}, Bootstrap};
```

Once we know our own address we can fill in the state record and start managing the routing table.

``` erlang
-record(state, { % the state of the router in normal operation
	  self, % the bits of the routers own end
	  pinged, % set of addresses which have been pinged and not yet replied/timedout
	  table % the routing table, a bit_tree containing buckets of nodes
	 }).
```

One of the jobs of the router is to remove unresponsive nodes from the routing table. To check if a node is responsive we just a random +end signal and wait for a reply. If the node is unresponsive it gets marked as stale and we try to find a suitable replacement. The node won't actually be dropped from the table until a replacement is found - this prevents the table from getting flushed if our network connection goes down.

``` erlang
ping(To) ->
    Telex = telex:end_signal(util:random_end()),
    % do this in a message to self to avoid some awkward control flow
    self() ! {pinging, To},
    switch:send(To, Telex),
    erlang:send_after(?ROUTER_PING_TIMEOUT, self(), {timeout, Address}).

timedout(Address, Self, Table) ->
    bit_tree:update(
      fun (_Suffix, _Depth, _Gap, Bucket) ->
	      case bucket:timedout(Address, Bucket) of
		  {node, Node, Update} ->
		      % try to touch this node, might be suitable replacement
		      ping(Node),
		      Update;
		  Update ->
		      Update
	      end
      end,
      util:to_bits(Address),
      Self,
      Table
     ).

handle_info({pinging, Address}, #state{pinged=Pinged}=State) ->
    % do this in a message to self to avoid some awkward control flow
    ?INFO([recording_ping, {address, Address}]),
    Pinged2 = sets:add_element(Address, Pinged),
    {noreply, State#state{pinged=Pinged2}};
handle_info({timeout, Address}, #state{self=Self, pinged=Pinged, table=Table}=State) ->
    case lists:member(Address, Pinged) of
	true ->
	    % ping timedout
	    ?INFO([timeout, {address, Address}]),
	    Table2 = timedout(Address, Self, Table),
	    {ok, State#state{table=Table2}};
	false ->
	    % address already replied
	    {ok, State}
    end;
```

One of the rules of the router is that it should never pass on information about a node that it hasn't personally confirmed to exist. Once we receive a message from a node we know that it exists (later we will implement ring/line to protect against address spoofing):

``` erlang
touched(Address, Self, Table) ->
    bit_tree:update(
      fun (Suffix, _Depth, Gap, Bucket) ->
	      May_split = (Gap < ?K), % !!! or (Depth < ?ROUTER_TABLE_EXPANSION)
	      bucket:touched(Address, Suffix, now(), Bucket, May_split)
      end,
      util:to_bits(Address),
      Self,
      Table
     ).
```

On receiving a .see command we record all the contained addresses as potential nodes and ping them to try to confirm their existence.

``` erlang
seen(Address, Self, Table) ->
    bit_tree:update(
      fun (Suffix, _Depth, _Gap, Bucket) ->
	      case bucket:seen(Address, Suffix, now(), Bucket) of
		  {node, Node, Update} ->
		      % check if this node is stale
		      ping(Node),
		      Update;
		  Update ->
		      Update
	      end
      end,
      util:to_bits(Address),
      Self,
      Table
     ).
```

On receiving a +end signal we reply with a .see command containing the nearest K addresses which we have confirmed to exist.

``` erlang
see(To, End, Table) ->
    Telex = telex:see_command(nearest(?K, End, Table)),
    switch:send(To, Telex).

nearest(N, End, Table) when N>=0 ->
    Bits = util:to_bits(End),
    iter:take(
      N,
      iter:flatten(
	iter:map(
	  fun ({_Prefix, Bucket}) -> bucket:by_dist(End, Bucket) end,
	  bit_tree:iter(Bits, Table)))).
```

On receiving a message we have handle the above three cases, which gets a little ugly.

``` erlang
handle_info({switch, {recv, From, Telex}}, #state{self=Self, pinged=Pinged, table=Table}=State) ->
    % this counts as a reply
    Pinged2 = sets:del_element(From, Pinged),
    % touched the sender
    % !!! eventually will check _line here
    ?INFO([touched, {node, From}]),
    Table2 = touched(From, Self, Table),
    % maybe seen some nodes
    Table3 =
	case telex:get(Telex, '.see') of
	    {ok, Binaries} ->
		try [util:binary_to_address(Bin) || Bin <- Binaries] of
		    Addresses ->
			?INFO([seen, {nodes, Addresses}, {from, From}]),
			lists:foldl(fun (Address, Table_acc) -> seen(Address, Self, Table_acc) end, Table2, Addresses)
		catch
		    _ ->
			?INFO([bad_seen, {nodes, Binaries}, {from, From}]),
			Table2
		end;
	    _ ->
		Table2
	end,
    % maybe send some nodes back
    case telex:get(Telex, '+end') of
	{ok, Hex} ->
	    try util:hex_to_end(Hex) of
		End ->
		    ?INFO([see, {'end', End}, {from, From}]),
		    see(From, End, Table3)
	    catch
		_ ->
		    ?WARN([bad_see, {'end', Hex}, {from, From}])
	    end;
	_ ->
	    ok
    end,
    {noreply, State#state{pinged=Pinged2, table=Table2}};
```

The last responsibility of the router is to periodically refresh buckets which haven't recently seen any activity.

``` erlang
handle_info(refresh, #state{self=Self, table=Table}=State) ->
    ?INFO([refreshing_table]),
    refresh(Self, Table),
    {noreply, State};
handle_info({dialed, _, _}, State) ->
    % response from a bucket refresh, we don't care
    {noreply, State};

dialed(Address, Self, Table) ->
    bit_tree:update(
      fun (_Suffix, _Depth, _Gap, Bucket) ->
	      bucket:dialed(now(), Bucket)
      end,
      util:to_bits(Address),
      Self,
      Table
     ).

needs_refresh(Bucket, Now) ->
    case bucket:last_dialed(Bucket) of
	never ->
	    true;
	Last ->
	    (timer:now_diff(Now, Last) div 1000) < ?ROUTER_REFRESH_TIME
    end.

refresh(Self, Table) ->
    Now = now(),
    iter:foreach(
      fun ({Prefix, Bucket}) ->
	      case needs_refresh(Bucket, Now) of
		  true ->
		      ?INFO([refreshing_bucket, {prefix, Prefix}, {bucket, Bucket}]),
		      To = util:random_end(Prefix),
		      From = nearest(?K, To, Table),
		      dialer:dial(To, From, ?ROUTER_DIAL_TIMEOUT);
		  false ->
		      ok
	      end
      end,
      bit_tree:iter(Self, Table)
     ),
    erlang:send_after(?ROUTER_REFRESH_TIME, self(), refresh),
    ok.
```

That's it. As usual the (untested) code is in the [repo](https://github.com/jamii/erl-telehash). The next post will probably deal with taps.

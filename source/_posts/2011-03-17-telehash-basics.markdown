---
layout: post
title: "Telehash: basics"
date: 2011-03-17 06:16
comments: true
categories:
- erlang
- telehash
---

[TeleHash](http://telehash.org) is a p2p network based on the [Kademlia DHT](http://en.wikipedia.org/wiki/Kademlia) that provides addressing and NAT traversal. These are problems that every p2p app has to deal with, including my [poppi](https://github.com/jamii/dissertation). Unfortunately there is no erlang implementation yet so I have to roll my own. The code so far lives [here](http://github.com/jamii/erl-telehash) In this first post I'll just cover the absolute basics - sending, receiving, encoding and decoding messages.

<!--more-->

TeleHash messages (telexes) are utf8-encoded json packets sent over udp. Luckily, mochijson2 uses utf8 by default so encoding/decoding is trivial.

``` erlang
encode(Telex) ->
    mochijson2:encode(Telex).

decode(Json) ->
    mochijson2:decode(Json).
```

The *telex* module also defines some convenience methods for working with json - *get/2*, *set/3*, *update/4* - which are used like this:

``` erlang
2> T = telex:decode("{\"foo\":[\"bar\", {\"baz\":0}]}").
{struct,[{<<"foo">>,[<<"bar">>,{struct,[{<<"baz">>,0}]}]}]}
3> telex:get(T, foo).
[<<"bar">>,{struct,[{<<"baz">>,0}]}]
4> telex:get(T, {foo,2}).
{struct,[{<<"baz">>,0}]}
5> telex:get(T, {foo,2,baz}).
0
6> telex:set(T, {foo,2,baz}, 1).
{struct,[{<<"foo">>,[<<"bar">>,{struct,[{<<"baz">>,1}]}]}]}
7> telex:set(T, bigger, true).
{struct,[{<<"bigger">>,true},
         {<<"foo">>,[<<"bar">>,{struct,[{<<"baz">>,0}]}]}]}
8> telex:update(T, {foo,2,baz}, fun (X) -> X + 10 end, -1).
{struct,[{<<"foo">>,[<<"bar">>,{struct,[{<<"baz">>,10}]}]}]}
```

The next step is to be able to send and receive messages. The *switch* module runs a gen_server which manages the udp socket and a gen_event which allows other processes to subscribe to incoming messages.

``` erlang
-module(switch).

-include("conf.hrl").

-export([start_link/0, add_handler/2, add_sup_handler/2, send/2]).

-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {socket}).
-define(EVENT, switch_event).
-define(SERVER, switch_server).

% --- api ---

start_link() ->
    {ok, Gen_event} = gen_event:start_link({local, ?EVENT}),
    {ok, Gen_server} = gen_server:start_link({local, ?SERVER}, ?MODULE, [], []),
    {ok, Gen_event, Gen_server}.

add_handler(Module, Args) ->
    gen_event:add_handler(?EVENT, Module, Args).

add_sup_handler(Module, Args) ->
    gen_event:add_sup_handler(?EVENT, Module, Args).

send({address, _Host, _Port}=Address, Telex) ->
    gen_server:cast(?SERVER, {telex, Address, Telex}).

% --- gen_server callbacks ---

init([]) ->
    {ok, Socket} = gen_udp:open(?PORT),
    {ok, #state{socket=Socket}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({telex, {address, Host, Port}, Telex}, #state{socket=Socket}=State) ->
    gen_udp:send(Socket, Host, Port, telex:encode(Telex)),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({udp, Socket, Host, Port, Msg}, #state{socket=Socket}=State) ->
    Event = {telex, {address, Host, Port}, telex:decode(Msg)},
    gen_event:notify(?EVENT, Event),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{socket=Socket}) ->
    gen_udp:close(Socket),
    ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

% --- end ---
```

To demonstrate this, let's write the simplest possible event handler:

``` erlang
-module(log).

-export([start/0]).
-export([info/1, warn/1, error/1]).

-behaviour(gen_event).
-export([init/1, handle_event/2, handle_call/2, handle_info/2, terminate/2, code_change/3]).

% --- api ---

start() ->
    switch:add_sup_handler(?MODULE, none).

info(Info) ->
    error_logger:info_report([{pid, self()} | Info]).

warn(Warn) ->
    error_logger:warning_report([{pid, self()} | Warn]).

error(Error) ->
    error_logger:error_report([{pid, self()} | Error]).

% --- gen_event callbacks ---

init(none) ->
    {ok, none}.

handle_event(Event, State) ->
    log:info([Event]),
    {ok, State}.

handle_call(_Request, State) ->
    {ok, ok, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

% --- end ---
```

Here we have some wrappers around the standard error logger and an event handler which (after masses of gen_event boilerplate) simply logs every event.

This is enough functionality now to start talking to a TeleHash node:

``` erlang
1> c(util), c(telex), c(switch), c(log).
{ok,log}
2> switch:start_link().
{ok,<0.55.0>,<0.56.0>}
3> log:start().
ok
4> T = {struct, [{'+end', 'a9993e364706816aba3e25717850c26c9cd0d89d'}]}.
{struct,[{'+end',a9993e364706816aba3e25717850c26c9cd0d89d}]}
5> switch:send({address, "127.0.0.1", 55555}, T).
ok
6> 
=INFO REPORT==== 17-Mar-2011::12:21:13 ===
    pid: <0.55.0>
    {telex,{address,{127,0,0,1},55555},
           {struct,[{<<"_ring">>,5932},
                    {<<".see">>,[]},
                    {<<"_br">>,51},
                    {<<"_to">>,<<"127.0.0.1:42424">>}]}}

```

Here we ask localhost:55555 for the nearest nodes it knows to the end 'a99...89d'. The reply is contained in the *.see* field (which is empty because localhost:55555 hasn't seeded itself yet and so doesn't know any nodes at all). 

The next post will deal with dialing, at which point we will have a working announcer.

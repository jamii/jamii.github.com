---
layout: post
title: "Telehash: gen_event woes"
date: 2011-04-19 06:16
comments: true
categories:
- erlang
- telehash
---  

I ran into some tricky bugs caused by a misconception I had about gen_event. Since this is not explicitly stated in the gen_event documentation I will say it here: gen_event does NOT spawn individual processes for each handler. Each handler is run sequentially in the event manager process.

<!--more-->

Now obviously the documentation is not at fault here. I assumed that each handler got its own process solely because the callbacks resembled gen_server. However, a little googling reveals that several other people made the same mistake so I thought it was worth mentioning.

Here is how I found this out. I was working on the router implementation for telehash. When I tested the bootstrapping algorithm everything looked fine until the first dial, after which nothing else happened. Straight away I suspected a bug in the dialer, but repeating the exact same call in the console worked fine. After a few deadends I opened pman to look for anything suspicious but couldn't find the dialer process (because it doesn't exist, it's an event handler). I assumed that it was somehow crashing silently and wasted an hour or so reading and rereading the code and stepping through various calls in the debugger. No matter what I tried the dialer worked absolutely perfectly unless it was called by the router. 

Eventually I noticed that the switch_event process was blocking inside a receive and the whole thing unravelled. The dialer is an event handler so when started it calls:

``` erlang
  gen_event:add_handler(switch_event, dialer, State)
```

which is a synchronous call to the switch_event process. The router event handler is running inside the switch_event process so when the router tries to dial it deadlocks.

The moral of this story is *RTFM*.

This is easily fixed by changing

``` erlang
  dialer:dial(End, [Address])
```

to

``` erlang
  spawn(fun () -> dialer:dial(End, [Address]) end)
```

but there were more problems. Most of the event handlers used erlang:send_after to handle timeouts but since they all run in the same process they all receive each others timeouts. Also, every event handler is run sequentially so the switch_event process becomes a huge bottleneck. 

The solution I settled on was to change each event handler into a gen_server and write a simple event handler that just forwards events to its owner. By using gen_event:add_sup_handler and listening for event handler exits we can keep the two in sync.

---
layout: post
title: "Transactional mealy machiens"
date: 2011-03-16 06:16
comments: true
categories:
- erlang
- mealy
- smarkets
---

This is a hugely overdue post about an interesting system I worked on almost a year ago whilst at [Smarkets](http://smarkets.com) and never got around to writing about. Unfortunately I don't have the code in front of me but the overall idea is simple enough to explain without examples.

<!--more-->

Smarkets is a betting exchange (effectively a small stock exchange for buying and selling bets). The exchange system which handles all the money and manages the markets has quite stringent requirements. We want events to be serializable (because ordering is very important in a fast moving market), low latency and ideally distributed across more than one machine. However the exchange also has to handle a large number of bursty updates focused on a small number of records (popular markets, power users). I'm told that the early prototypes using postgres simply couldn't handle the high contention so a move to a more loosely coupled system was necessary. 

The architecture in place when I arrived at Smarkets was based on [this paper](http://www.cidrdb.org/cidr2007/papers/cidr07p15.pdf) which I highly recommend reading. The main idea is that serializability across machines is difficult verging on impossible and that systems which try to paper over this (eg fully ACID distributed transactions) tend to be fragile at scale. The proposed solution is to identify specific sets of actions which must be serializable and handle each set with a single actor on a single machine. These actors then communicate with each other via asynchronous messages. In Smarkets' case the actors are individual markets, users, accounts and orders. These can be modeled nicely as [mealy machines](http://en.wikipedia.org/wiki/Mealy_machine) where the output value is a list of messages, hence the title.

This idea was very effective but the implementation at Smarkets was some of the scariest code in the repository (thanks mostly to being the oldest code). Each actor was implemented as a single erlang process which archived messages (using couchdb) after reading them. There was a lot of repetitive boilerplate code, it was hard to test (because the actors message each other directly) and worst of all there were ways to lose messages before they were archived (eg process inbox is lost if the process dies, messages between machines can be dropped silently). 

I wrote a new system to handle the actor implementation whilst keeping the domain-specific logic of each actor mostly unchanged. Each actor is defined by a pair of callback functions (a behaviour, in erlang-speak). The *init* function sets the initial state of the actor. The *transition* function takes the current state and an incoming message and returns the new state and possibly some outgoing messages. Everything else is handled by a generic module which takes this behaviour and turns it into a running actor. Each actor consists of an inbox, outbox and a current state, all of which are persisted using mnesia. Each actor also has a unique id used for addressing messages. The transition process - pop a message off the inbox queue, run the transition function, store the new state, push outgoing messages to the outbox - is implemented as a single ACID transaction using mnesia. For actors on the same machine messages are moved directly from one actor’s outbox to another's inbox directly using mnesia transactions. For actors on different machines the outbox using erlang messages and sends repeatedly (with exponential backoff) until the receiver confirms receipt. The outbox attaches auto-incrementing message ids to each message which, together with the actor id of the sender, allows the receiver to ignore duplicate messages.

In this way the domain-specific logic is separated from message handling and storage. This led to much less repetition and a more maintainable system. It also made it easy to setup tests or replay past events without recreating the whole system. Last, but certainly not least, it can only lose messages if the database or disk fails and even then is easier to restore from backup than the previous system. 

Note that this explanation is somewhat simplified. I have glossed over some fiddly implementation details like error handling (if an actor fails to handle a message the sender needs to be notified in many cases) and also left out extra features like subscribing to state changes (eg notify me when this order is filled). There is also a knack to designing actors which must cooperate without [common knowledge](http://en.wikipedia.org/wiki/Common_knowledge_(logic)). Hopefully the [Smarkets team](https://smarkets.com/about/contact/) will find some time to open-source the actual code.

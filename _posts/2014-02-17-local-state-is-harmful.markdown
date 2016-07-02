---
layout: post
title: "Local state is harmful"
date: 2014-02-17 05:02
comments: true
categories: thought
---

Don't lynch me just yet :)

<!--more-->

Picture a traditional webapp. We have a bunch of stateless workers connected to a stateful, relational database. This is a setup with a number of excellent properties:

* All state can be queried using a uniform api - SQL. This enables flexible ad-hoc exploration of the application state as well as generic UIs like [django admin](https://docs.djangoproject.com/en/dev/ref/contrib/admin/)
* Every item of state has a unique and predictable name by which it can be identified - a unique key in the table.
* Access to state can be restricted and controlled. Transactions prevent different workers from interfering with each other. ACLs allow giving individual workers access to only the information they need to limit the scope of mistakes.
* Changes to state can be monitored. Tailing the transaction log is an effective way to stream to a backup server or to debug errors that occurred in production. One can reconstuct the state of the database at any time.
* State is separate from code. You can change client code, rename all your classes or restart workers on the fly and the state in the database will be unharmed.

The database state is also pervasive, mutable and *global*.

Now let's zoom in and look at our imperative, object-oriented workers:

* State is encapuslated in objects and hidden behind an ad-hoc collection of methods.
* Objects are effectively named only by their location in the (cyclic, directed) object graph or their position in memory.
* Access to state can be restricted and controlled through encapsulation. Concurrent modifications are a constant source of bugs. Access control is adhoc and transitive - if you can walk the object graph to an object you can access it.
* Changes to state are usually monitored via adhoc methods such as manually inserting debug statements. Approximating history by watching debug statements and reconstructing state in ones head is the normal method of debugging.
* State is entangled with code. Portable serialization is difficult. Live-coding works to some extent but requires reasoning about the interaction of state and code (eg in js redefining a function does not modify old instances that may still be hanging around in data structures or in callbacks)

Functional programmers need not look so smug at this point. The Haskell/OCaml family struggles to redefine types at runtime or handle live data migrations (the declaration of a nominal type is a side-effect in a live language). Clojure does better on these points but still gets burned by nominal types (eg extend a deftype/defrecord and the reeval the definition) and more generally by treating the definition of new code as mutation of state (which has to be papered over by [tools.namespace](https://github.com/clojure/tools.namespace/)).

Why are these points important? We spend most of our time not writing code but *reasoning about code*, whether hunting for bugs, refactoring old code or trying to extend a module. We end up with questions like:

* When did this state change?
* What caused it to change?
* Did this invariant ever break?
* How did this output get here?

How do we answer these questions?

In the database we have a transaction log containing for each transaction: the queries involved, the commit time, the client name etc. We can write code that specifies the condition we are interested in via an sql query, locates the relevant transactions by running through the log and then recreates the state of the database at that point. This works even if the error happened elsewhere - just have the user ship you their transaction log.

In the worker, we have two familiar workhorses:

* Manually add print statements, recompile the code, try to recreate the conditions we are interested in and then reconstruct the causality by reading the printed statements
* Add a breakpoint in the debugger, try to recreate the conditions we are interested in and then step through the code line by line

What these two have in common is that they are both achingly *manual*. There is no easy way to automate the process. There are no libraries full of debugging strategies that you can deploy. The questions we have are about time and causality but our current tools restrict us to looking at tiny slices of space (print statements) or time (debuggers) and offer no way to automate our actions.

I propose that if we were to manage state more like a database and less like a traditional imperative language then understanding and debugging programs would become easier. As is traditional, I aim to convince the reader by the use of an unrealistically simple example.

## Counting sheep

As everyone knows the main purpose of advanced technology has always been to help us [count our sheep](http://sl4.org/wiki/TheSimpleTruth). At the dawn of time this was very simple.

``` clj
(def count (atom 0))

(defn inc! []
  (swap! count + 1))

(defn dec! []
  (swap! count - 1))

(defn run-counter [port]
  (let [socket (open port)]
    (while true
      (case (receive-message socket)
        :sheep-in (inc!)
        :sheep-out (dec!)))))

(run-counter 1081)
```

But as civilisation advanced so too did the demands on technology. With newfound riches came multiple pens of sheep. People soon realised that the trusty old global variable had a crucial flaw - it was not reentrant. Having been burned by mutable state they decided to keep it under lock and guard.

``` clj
(defn make-counter []
  (let [count (atom 0)]
    {:inc! (swap! count + 1)
     :dec! (swap! count - 1)}))

(defn run-counter [port]
  (let [socket (open port)
        {:keys [inc! dec!]} (make-counter)]
    (while true
      (case (receive-message socket)
        :sheep-in (inc!)
        :sheep-out (dec!)))))

(run-counter 1081)
(run-counter 1082)
```

Later programmers were a more trusting bunch and left their data unprotected, but still hidden.

``` clj
(defn run-counter [port]
  (let [socket (open port)
        count (atom 0)]
    (while true
      (case (receive-message socket)
        :sheep-in (swap! count + 1)
        :sheep-out (swap! count - 1)))))

(run-counter 1081)
(run-counter 1082)
```

It took thousands of years of progress before anyone asked the crucial question: "So how many sheep do we actually have?". The guardian of the count was reluctant to give up this delicate information, having been lectured all its life about the importance of data hiding. The only solution was torture.

``` clj
(defn run-counter [port]
  (let [socket (open port)
        count (atom 0)]
    (while true
      (case (receive-message socket)
        :sheep-in (swap! count + 1)
        :sheep-out (swap! count - 1)
        :how-many-sheep (send-message socket [@count :sheep])))))

(run-counter 1081)
(run-counter 1082)
```

In erlang they still hold to these cruel and brutal traditions.

Let's try something different. We can separate state from code and allow uniform access to all application state. We just have to carefully control access to that state.

``` clj
;; in the code

(defn run-counter [port count]
  (let [socket (open port)]
    (while true
      (case (receive-message socket)
        :sheep-in (swap! count + 1)
        :sheep-out (swap! count - 1)))))

;; in the repl

(def state
  {:count-a (atom 0)
   :count-b (atom 0)})

(run-counter 1081 (state :count-a))
(run-counter 1082 (state :count-b))

@(state :count-a) ;; check the number of sheep

(run-counter 1083 (state :count-a)) ;; share sheep with 1081
```

This is a kind of pseudo-global state. We can easily examine any application state in the repl but functions can only modify state this is passed to them directly. All we need now is to monitor changes to the state.

``` clj
(defn run-counter [port count]
  (let [socket (open port)]
    (while true
      (case (receive-message socket)
        :sheep-in (swap! count + 1)
        :sheep-out (swap! count - 1)))))

(def state
  (atom {:count-a 0
         :count-b 0}))

(run-counter 1081 (subatom state :count-a))
(run-counter 1082 (subatom state :count-b))
```

`subatom` is not a clojure function, but it shows up regularly in clojure libraries (eg my [bigatom](https://github.com/jamii/bigatom) is a simple, self-contained implementation). All it does is create a view on the original atom. This approximates a mutable tree while still allowing immutable snapshots.

``` clj
(def x (atom {:foo {:bar 0}}))

(def y (subatom x :foo :bar))

@y ;; => 0

(swap! y inc) ;; => 1

@x ;; => {:foo {:bar 1}}
```

Now we can record changes and explore them programatically. Suppose that sheep pen 1082 is actually inside sheep pen 1081. If everything is working correctly, we should have the invariant `(> (:count-a @state) (:count-b @state))`. Most of the time this is indeed the case, but once in a blue moon an unhappy customer reports that the invariant is broken.

Luckily, as modern programmers we can simply query the clients state history to find out what happened.

``` clj
(def history
  (atom [[(time) @state]]))

(add-watch state history (fn [_ _ new-state] (swap! history conj [(time) new-state])))

(drop-while
  (fn [[time state]]
    (> (:count-a state) (:count-b state)))
  @history)
```

This is a trivial example, but this kind of ability to debug programmatically is potentially very valuable.

## Real world use

Removing hidden state does not have to be a binary change. The more you move in that direction the more of the benefits you will gain.

The project that convinced me was a prototype betting exchange written in clojure. Although I relied on mutable collections (and thus lost the ablity to record history easily) I used [Graph](https://github.com/prismatic/plumbing) to wire components together.

``` clj
(def log
  {:stream (fnk [log-file] (java.io.FileOutputStream. log-file))
   :channel (fnk [stream] (.getChannel stream))
   :writer (fnk [stream] (clojure.java.io/writer stream))})

(def server
  {:log log
   :queue (fnk [batch-size] (java.util.concurrent.ArrayBlockingQueue. batch-size))
   :server (fnk [queue frame port] (network/receive-events queue frame port))
   :state (fnk [init-state] (atom init-state))
   :persistor (fnk [state queue [:log channel writer] handler batch-size]
                   (future-loop (persistence/handle-events state queue channel writer handler batch-size)))})

(defnk client [frame port]
  (lamina/wait-for-result (tcp/tcp-client {:host "localhost" :port port :frame frame})))

;; wiring for throughput test
(def load
  {:client client
   :send-count (fnk [] (atom 0))
   :recv-count load/recv-count
   :counter (fnk [recv-count] (future (load/counter-loop recv-count @recv-count)))
   :loader (fnk [client send-count recv-count rate-limit]
                (future (load/loader-loop client send-count recv-count rate-limit)))})

;; wiring for latency test
(def measure
  {:client client
   :measurer (fnk [client] (future (load/measurer-loop client)))})
```

With explicit names for all state, dependency injection is easy. When I start a component I can swap out the network implementation for testing or compare different implementations of the event handler etc.

``` clj
  (def s ((graph/eager-compile server)
          {:port 19997
           :frame etf-frame
           :init-state load/init-state
           :handler exchange/handle-event
           :log-file "test-out"
           :batch-size 1000}))
```

Creating a component returns a nested map of all the state in all the subcomponenets. I can poke around inside the state whilst debugging. A little snippet I often used polls the queue size and prints to the console whenever it is full.

``` clj
(future
  (while true
    (when (>= (.size (:queue s)) (:batch-size s))
      (println "Full at" (time)))))
```

Uniform access to all state makes it easy to write generic functions to eg view the entire object graph or shutdown every component.

``` clj
(defprotocol Poke
  (poke [this]))

(extend-protocol Poke
  java.util.concurrent.Future
  (poke [this] (deref this 0 :pending-future))
  clojure.lang.Atom
  (poke [this] @this))

(defn poke-all [form]
  (if (satisfies? Poke form)
    (walk identity poke-all (poke form))
    (walk identity poke-all form)))

(defprotocol Kill
  (kill [this]))

(extend-protocol Kill
  clojure.lang.Fn
  (kill [this] (this))
  java.util.concurrent.Future
  (kill [this] (future-cancel this)))

(defn kill-all [form]
  (walk #(if (satisfies? Kill %) (kill %) %) kill-all form))
```

The difference in productivity compared to the old actor-based version was incredible.

## Examples

[Overlog](http://boom.cs.berkeley.edu/) makes use of this idea by reflecting many runtime events into in-process tables. My favourite [paper](http://db.cs.berkeley.edu/papers/eurosys10-boom.pdf) describes using streaming queries on these tables for programmable profiling, monitoring and even distributed debugging.

[Om](https://github.com/swannodette/om) uses cursors similarly to the way I use subatoms here, to manage relative names within the state tree. David Nolen's [blog](http://swannodette.github.io/) has some excellent examples of using this global state to enable application-wide undo and syncing state without modifying application code.

The [React devtools](http://facebook.github.io/react/blog/2014/01/02/react-chrome-developer-tools.html) allow you to click on an element on the page and display the state of the component that created that element.  A trivial extension in Om would be to display the past states and for each state change show the event and handler that caused that change. Together with the ability to programmatically access state and history this could lead to a beautiful debugging experience.

"Why is this box here? Ah, it comes from component Foo. The state of component Foo is messed up. When did that happen? Ah, it was caused by event handler Bar firing with these arguments." How long would that same chain of reasoning take you with println debugging? In a language with tighter tool integration it should be possible to just directly drop into the debugger at that point in history and replay the events.

## Summary

Interaction with running programs (live coding, debugging, monitoring, hot code reloading etc) is greatly aided by several design principles:

* All state can be queried using some uniform api.
* Every item of state has a unique and predictable name by which it can be identified.
* Access to state can be restricted and controlled.
* Changes to state can be monitored.
* State is separate from code.

These principles are well understood in database systems and in ops in general.

The same principles are not applied in the small by most programmers and are not encouraged by most languages.

Several examples exist of using these principles to quickly produce simple, powerful programs.

Most of our questions about code are questions about time, state and causality. Our existing tools do not lend much support in answering those questions. Following these principles makes it easier to develop better tools.

I would also speculate that a large part of the [frustration](http://www.youtube.com/watch?v=ayPD0U_FO4Y) that people experience with computers is a result of opaque abstractions which prevent users from being able to connect cause and effect when the machine misbehaves.

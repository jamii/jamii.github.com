---
layout: post
title: "Search trees and core.logic"
date: 2012-12-19 20:32
comments: true
categories:
---

I mentioned in an [earlier post](http://scattered-thoughts.net/blog/2012/12/02/hacker-school/) that I had spent some time working on [shackles](https://github.com/jamii/shackles), an extensible [constraint solver](http://en.wikipedia.org/wiki/Constraint_programming) based on [gecode](http://www.gecode.org/) with extensions for [logic programming](http://en.wikipedia.org/wiki/Logic_programming). I eventually gave up working on shackles in favor of using [core.logic](https://github.com/clojure/core.logic) which is much more mature and has actual maintainers. Last week David Nolen (the author of core.logic) was visiting Hacker School so I decided to poke around inside core.logic and see what could be brought over from shackles. The [first chunk of work](https://github.com/clojure/core.logic/pull/13) adds fair conjunction, user-configurable search and a parallel solver.

<!--more-->

First, a little background. From a high-level point of view, a constraint solver does three things:

* specifies a search space in the form of a set of constraints

* turns that search space into a search tree

* searches the resulting tree for non-failed leaves

Currently core.logic (and cKanren before it) complects all three of these. My patch partly decomplects the latter from the first two, allowing different search algorithms to be specified independently of the problem specification.

Let's look at how core.logic works. I'm going to gloss over a lot of implementation details in order to make the core ideas clearer.

The search tree in core.logic is representated as a lazy stream of the non-failed leaves of the tree. This stream can be:

* ```nil``` - the empty stream

* ```(Choice. head tail)``` - a cons cell

Disjunction of two goals produces a new goal which contains the search trees of the two goals as adjacent branches. In core.logic, this is implemented by combining their streams with ```mplus```. A naive implementation might look like this:

``` clojure
(defn mplus [stream1 stream2]
  (cond
    (nil? stream1) stream2
    (choice? stream1) (Choice. (.head stream1) (mplus (.tail stream1) stream2))))
```

This amounts to a depth-first search of the leaves of the tree. Unfortunately, search trees in core.logic can be infinitely deep so a depth-first search can get stuck. If the first branch has an infinite subtree we will never see results from the second branch.

``` clojure
;; simple non-terminating goal
(def forevero
  (fresh []
    forevero))

(run* [q]
  (conde
    [forvero]
    [(== q 1)]))

;; with depth-first search blocks immediately, returning (...)
;; with breadth-first search blocks after the first result, returning (1 ...)
```

We can perform breadth-first search by adding a new stream type:

* ```(fn [] stream)``` - a thunk representing a branch in the search tree

And then interleaving results from each branch:

``` clojure
(defn mplus [stream1 stream2]
  (cond
    ...
    (fn? stream1) (fn [] (mplus stream2 (stream1)))))
```

This is how core.logic implements fair disjunction (fair in the sense that all branches of ```conde``` will be explored equally). However, we still have a problem with fair conjunction. Conjunction is performed in core.logic by running the second goal starting at each of the leaves of the tree of the first goal. In terms of the stream representation, this looks like:

``` clojure
(defn bind [stream goal]
  (cond
    (nil? stream) nil ;; failure
    (choice? stream) (Choice. (bind (.head stream) goal) (bind (.tail stream) goal))
    (fn? stream) (fn [] (bind (stream) goal))))
```

This gives rise to similar behaviour as the naive version of ```mplus```:

``` clojure
(run* [q]
  (all
    forevero
    (!= q q)))

;; with unfair conjunction blocks immediately, returning (...)
;; with fair conjunction the second branch causes failure, returning ()
```

I suspect the reason that core.logic didn't yet have fair conjunction is entirely due to this stream representation, which complects all three stages of constraint solving and hides the underlying search tree. Since shackles is based on gecode it has the advantage of a much clearer theoretical framework (I strongly recommend [this paper](http://www.gecode.org/paper.html?id=Tack:PhD:2009), not just for the insight into gecode but as a shining example of how mathematical intuition can be used to guide software design).

The first step in introducing fair conjunction to core.logic is to explicitly represent the search tree. The types are similar:

* ```nil``` - the empty tree
* ```(Result. state)``` - a leaf
* ```(Choice. left right)``` - a branch
* ```(Thunk. state goal)``` - a thunk containing the current state and a sub-goal

Defining ```mplus``` is now trivial since it is no longer responsible for interleaving results:

``` clojure
(defn mplus [tree1 tree2]
  (Choice. tree1 tree2))
```

And we now have two variants of bind:

``` clojure
(defn bind-unfair [tree goal]
  (cond
    (nil? goal) nil ;; failure
    (result? tree) (goal (.state tree)) ;; success, start the second tree here
    (choice? tree) (Choice. (bind-unfair (.left tree) goal) (bind-unfair (.right tree) goal))
    (thunk? tree) (Thunk. (.state tree) (bind-unfair ((.goal tree) state) goal))))

(defn bind-fair [tree goal]
  (cond
    (nil? goal) nil ;; failure
    (result? tree) (goal (.state tree)) ;; success, start the second tree here
    (choice? tree) (Choice. (bind-fair (.left tree) goal) (bind-fair (.right tree) goal))
    (thunk? tree) (Thunk. (.state tree) (bind-fair (goal state) (.goal tree))))) ;; interleave!
```

The crucial difference here is that bind-fair takes advantage of the continuation-like thunk to interleave both goals, allowing each to do one thunk's worth of work before switching to the next.

(We keep bind-unfair around because it tends to be faster in practice - when you know what order your goals will be run in you can use domain knowledge to specify the most optimal order. However, making program evaluation dependent on goal ordering is less declarative and there are also some problems that cannot be specified without fair conjunction. It's nice to have both.)

Now that we explicity represent the tree we can use different search algorithms. My patch defaults to lazy, breadth-first search (to maintain the previous semantics) but it also supplies a variety of others including a [parallel depth-first search](https://github.com/jamii/core.logic/blob/flexible-search/src/main/clojure/clojure/core/logic/par.clj#L49) using [fork-join](http://docs.oracle.com/javase/tutorial/essential/concurrency/forkjoin.html).

I still need to write a few more tests and sign the clojure contributor agreement before this can be considered for merging. I also have a pesky performance regression in lazy searches - this branch sometimes does more work than the original when only finding the first solution. I'm not sure yet whether this is down to a lack of laziness somewhere or maybe just a result of a slightly different search order. Either way, it needs to be fixed.

After this change, core.logic still complects the specification of the search space and the generation of the search tree (eg we have to choose between bind-unfair and bind-fair in the problem specification). At some point I would like to either fix that in core.logic or finish work on shackles. For now though, I'm going back to working on [droplet](https://github.com/jamii/droplet).

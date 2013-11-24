---
layout: post
title: "Hugo-a-go-go: optimisation"
date: 2013-11-24 04:43
comments: true
categories: clojure go
---

After a little optimisation work [hugo] now manages to play out ~12k games per second on a 9x9 board. Besides fixing the two incorrect optimisations I made during the last minutes of the competition, the main wins were changing the board representation and carefully inspecting the compiler output to eliminate unneccesary work. A lot of the things I discovered are generally applicable to calculation-heavy, cpu-bound cljs code (with all the usual disclaimers about profiling and premature optimsation).

<!--more-->

## Layout

The board is now packed into a Uint8Array. With borders included, the board is an 11x11 grid.

``` clj
(def size 9)
(def array-size (+ 2 size))
(def max-pos (* array-size array-size))

(defn ->pos [x y]
  (+ 1 x (* array-size (+ 1 y))))
```

The first 121 entries in the array represent the colour of each cell on the board.

``` clj
(def empty 0)
(def black 1)
(def white 2)
(def grey 3) ;; for the border

(defmacro get-colour [board pos]
  `(aget ~board ~pos))

(defmacro set-colour [board pos colour]
  `(aset ~board ~pos ~colour))
```

The next 121 entries track which string is present on a cell. Strings are just represented by an integer id. The last entry in the array tracks the next id to be assigned.

``` clj
(def empty-string 0)
(def grey-string 1)

(defmacro new-string [board]
  `(let [next-string# (aget ~board 1023)]
     (aset ~board 1023 (+ next-string# 1))
     next-string#))

(defmacro get-string [board pos]
  `(aget ~board (+ ~max-pos ~pos)))

(defmacro set-string [board pos string]
  `(aset ~board (+ ~max-pos ~pos) ~string))
```

The next 121 entries track the number of non-empty neighbouring cells, which is useful for short-circuiting `suicide?` and `eyelike?` tests.

``` clj
(defmacro get-neighbours [board pos]
  `(let [freedom-ix# (+ ~(* 2 max-pos) ~pos)]
     (aget ~board freedom-ix#)))

(defmacro add-neighbours [board pos amount]
  `(let [freedom-ix# (+ ~(* 2 max-pos) ~pos)]
     (aset ~board freedom-ix# (+ (aget ~board freedom-ix#) ~amount))))
```

Finally, the remaining cells map string ids to the number of pseudo-liberties belonging to that string.

``` clj
(defmacro get-liberties [board pos]
  `(let [string-ix# (+ ~(* 3 max-pos) (get-string ~board ~pos))]
     (aget ~board string-ix#)))

(defmacro add-liberties [board pos amount]
  `(let [string-ix# (+ ~(* 3 max-pos) (get-string ~board ~pos))]
     (aset ~board string-ix# (+ (aget ~board string-ix#) ~amount))))
```

Packing the board this way gives two benefits. First, every field access is reduced to a few instructions. This isn't as big a win as one might think, given that the structure of the old layout was predictable enough for the jit to replace hash lookups with struct access. More importantly, packing the board means that creating a copy is a single array copy. Cheap copying means we can cache boards all over the place and this leads to a lot of saved work in the UCT stage.

My implementation here is a little clumsy but in the future a cljs port of [vertigo](https://github.com/ztellman/vertigo) would make this a lot cleaner. This is the kind of abstraction that would be difficult to implement in plain js.

## Truth

In cljs, only `false` and `nil` are falsey. In generated code, if the cljs compiler cannot infer that the test in a branch is a boolean, it wraps it in `cljs.core.truth_` to test for cljs truthiness rather than js truthiness.

``` clj
(defn foo? [x]
  (= "foo" x))

(defn unfoo [x]
  (if (foo? x)
    nil
    x))
```

``` js
hugo_a_go_go.board.foo_QMARK_ = function(a) {
  return cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2("foo", a)
};
hugo_a_go_go.board.unfoo = function(a) {
  return cljs.core.truth_(hugo_a_go_go.board.foo_QMARK_(a)) ? null : a
};
```

Normally this doesn't matter but hugo is optimised enough already that profiling showed it spending ~15% of it's time inside `cljs.core.truth_`. You can avoid it either by adding type hints...

``` clj
(defn ^boolean foo? [x]
  (= "foo" x))

(defn unfoo [x]
  (if (foo? x)
    nil
    x))
```

``` js
hugo_a_go_go.board.foo_QMARK_ = function(a) {
  return cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2("foo", a)
};
hugo_a_go_go.board.unfoo = function(a) {
  return hugo_a_go_go.board.foo_QMARK_(a) ? null : a
};
```

... or by wrapping the test in a function that is already hinted.


``` clj
(defn foo? [x]
  (= "foo" x))

(defn unfoo [x]
  (if (true? (foo? x))
    nil
    x))
```

``` js
hugo_a_go_go.board.foo_QMARK_ = function(a) {
  return cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2("foo", a)
};
hugo_a_go_go.board.unfoo = function(a) {
  return!0 === hugo_a_go_go.board.foo_QMARK_(a) ? null : a
};
```

## Equality

Clojure defaults to structural equality where possible, rather than using javascript's insane notion of equality.

``` clj
(defn opposite-colour [colour]
  (if (= colour black) white black))
```

``` js
hugo_a_go_go.board.opposite_colour = function(a) {
  return cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(a, hugo_a_go_go.board.black) ? hugo_a_go_go.board.white : hugo_a_go_go.board.black
};
```

Again, this is something that normally doesn't matter but hugo was spending ~20% of cpu time in `cljs.core.__EQ__`. Since we know we are comparing integers we can use `==` instead, which compiles down to `===` in js.

``` clj
(defn opposite-colour [colour]
  (if (== colour black) white black))
```

``` js
hugo_a_go_go.board.opposite_colour = function(a) {
  return a === hugo_a_go_go.board.black ? hugo_a_go_go.board.white : hugo_a_go_go.board.black
};
```

For other primitive types it seems that `identical?` will inline to `===`. For keywords you now have to use `keyword-identical?` which unfortunately does not inline.

## Polyadic calls

Clojure functions can dispatch on the number of arguments. Usually the cljs compiler does a good job of compiling away the extra indirection, but it struggles with local functions.

``` clj
(defn foo []
  (letfn [(bar [x y] (= x y))]
    (bar :foo :bar)))
```

``` js
hugo_a_go_go.board.foo = function() {
  var a = function(a, c) {
    return cljs.core._EQ_.cljs$core$IFn$_invoke$arity$2(a, c)
  };
  return a.cljs$core$IFn$_invoke$arity$2 ? a.cljs$core$IFn$_invoke$arity$2(new cljs.core.Keyword(null, "foo", "foo", 1014005816), new cljs.core.Keyword(null, "bar", "bar", 1014001541)) : a.call(null, new cljs.core.Keyword(null, "foo", "foo", 1014005816), new cljs.core.Keyword(null, "bar", "bar", 1014001541))
};
```

The important part to notice here is that it tests if `a.cljs$core$IFn$_invoke$arity$2` exists before calling it, despite the fact that that is statically known. We had some small (~5%) performance improvements in a few places (notably board/flood-fill) by lifting all closures up to top-level functions so that the compiler can remove that check.

## Mutable variables

Sometimes you need a mutable variable. Using atoms incurs overhead for eg checking watches. According to [David Nolen](http://swannodette.github.io/2013/06/10/porting-notchs-minecraft-demo-to-clojurescript/), the best option in cljs is creating a one-element array.

It would be nice to have safe access to mutable vars in the style of [proteus](https://github.com/ztellman/proteus) instead.

## Next

While it meet seem annoying to have to work around the compiler sometimes to get decent performance, I far prefer to have sane semantics by default and just remember a few simple tricks for speeding up inner loops. Having access to macros also opens the door to a world of performant abstractions that would be extremely painful in plain js (eg [core.match](https://github.com/clojure/core.match), [vertigo](https://github.com/ztellman/vertigo)). Now that the core of hugo is just bashing on integers and byte arrays there is also the potential to compile sections of it to [asm.js](http://asmjs.org/) for even more performance.

Hugo now plays fairly sensibly but is still easy to defeat even for a novice player like me. I suspect that the UCT stage is still not entirely correct so the next step is to build a visualiser for the game tree so I can see the reasoning behind it's moves.

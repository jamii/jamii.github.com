---
layout: post
title: "Strucjure: motivation"
date: 2012-12-04 02:31
comments: true
categories: project
---
I feel that the readme for [strucjure](https://github.com/jamii/strucjure) does a reasonable job of explaining how to use the library but not of explaining why you would want to. I want to do that here. I'm going to focus on the motivation behind strucjure and the use cases for it rather than the internals, so try not to worry too much about how this all works and just focus on the ideas (the implementation itself is [very simple](http://en.wikipedia.org/wiki/Parsing_expression_grammar) but liable to keep changing).

<!--more-->

The core idea is that strucjure (and the [OMeta](http://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=4&cad=rja&ved=0CFIQFjAD&url=http%3A%2F%2Flambda-the-ultimate.org%2Fnode%2F2477&ei=lQ69UJqrLK-WyAHC1IGIBg&usg=AFQjCNEJAMQULpZ62ASYefNHadlUWTlgKA&sig2=E1ePKzLJJNaFw5BfEG9rrA) library on which it is based) is not just yet-another-parser, but is instead a concise language for describing, manipulating and transforming data structures. The [VPRI](http://www.vpri.org/) folks have done some amazing things with OMeta. My goal with strucjure is to see how much further this idea can be taken.

(Note: For the purposes of this post I'll use the terms pattern and view interchangeably. There *is* a difference, but the line between the two is not yet clear to me and will probably change in future implementations)

## Pattern matching

Pattern matching is a concept found in many functional languages. The basic idea is something like a switch statement, combined with a mini-language for describing patterns which the input should be tested against. The first pattern which matches has its corresponding branch executed.

As a very simple example, we can use strucjure to write fizzbuzz like this:

``` clojure
(doseq [i (range 100)]
  (prn
   (match [(mod i 3) (mod i 5)]
          [0 0] "fizzbuzz"
          [0 _] "fizz"
          [_ 0] "buzz"
          _      i)))
```

This is a concise, readable description of the various cases and replaces a chain of if-statements.

If we stopped there, you could be forgiven for not caring. Simple examples don't really demonstrate the power of pattern matching. Let's instead look at a more complicated example - [red-black trees](http://en.wikipedia.org/wiki/Red%E2%80%93black_tree). An important operation on red-black trees is re-establishing the balance invariants after inserting a new node. Here is a java implementation of the balance operation (from [this implementation](http://algs4.cs.princeton.edu/33balanced/RedBlackBST.java.html)):

``` java
    // make a left-leaning link lean to the right
    private Node rotateRight(Node h) {
        assert (h != null) && isRed(h.left);
        Node x = h.left;
        h.left = x.right;
        x.right = h;
        x.color = x.right.color;
        x.right.color = RED;
        x.N = h.N;
        h.N = size(h.left) + size(h.right) + 1;
        return x;
    }

    // make a right-leaning link lean to the left
    private Node rotateLeft(Node h) {
        assert (h != null) && isRed(h.right);
        Node x = h.right;
        h.right = x.left;
        x.left = h;
        x.color = x.left.color;
        x.left.color = RED;
        x.N = h.N;
        h.N = size(h.left) + size(h.right) + 1;
        return x;
    }

    // flip the colors of a node and its two children
    private void flipColors(Node h) {
        // h must have opposite color of its two children
        assert (h != null) && (h.left != null) && (h.right != null);
        assert (!isRed(h) &&  isRed(h.left) &&  isRed(h.right))
            || (isRed(h)  && !isRed(h.left) && !isRed(h.right));
        h.color = !h.color;
        h.left.color = !h.left.color;
        h.right.color = !h.right.color;
    }

    // restore red-black tree invariant
    private Node balance(Node h) {
        assert (h != null);

        if (isRed(h.right))                      h = rotateLeft(h);
        if (isRed(h.left) && isRed(h.left.left)) h = rotateRight(h);
        if (isRed(h.left) && isRed(h.right))     flipColors(h);

        h.N = size(h.left) + size(h.right) + 1;
        return h;
    }
```

This pile of if-statements obscures the intent of the code, which is to re-arrange the tree so that no red node has a red child. What we really want to see is 'if the tree looks like foo, replace it with bar'. Using pattern matching we can express this directly (code based on [this implementation](http://www.cs.cornell.edu/courses/cs3110/2009sp/lectures/lec11.html)):

``` clojure
(defrecord Leaf [])
(defrecord Red [left value right])
(defrecord Black [left value right])

(defview balance
  ;; if it looks like one of these...
  (or
   (Black. (Red. (Red. ?a ?x ?b) ?y ?c) ?z ?d)
   (Black. (Red. ?a ?x (Red. ?b ?y ?c)) ?z ?d)
   (Black. ?a ?x (Red. (Red. ?b ?y ?c) ?z ?d))
   (Black. ?a ?x (Red. ?b ?y (Red. ?c ?z ?d))))
  ;; replace it with this...
  (Red. (Black. a x b) y (Black. c z d))

  ;; otherwise, leave it alone
  ?other
  other)
```

(Note that this isn't exactly the same operation as the code above, because the corresponding implementation has a slightly different insert algorithm too. Nevertheless, converting this operation to java would result in the same grotesque expansion of if-statements).

Strucjure is not very optimized yet, but if you use a more mature pattern-matching library then this code would be as fast as what you would write by hand. For complex patterns [core.match](https://github.com/clojure/core.match) often does a better job of optimizing the decision tree than I can manage by hand, in much the same way that GCC does a better job of writing assembly code than I ever could.

Strucjure patterns are first-class values and can call other patterns or recursively call themselves, so they can express much more complex patterns than other pattern matchers. For example:

``` clojure
(defview balanced-height
  Leaf
  0

  (and (Black. _
         (balanced-height ?l)
         (balanced-height ?r))
       #(= l r))
  (+ 1 l)

  (and (Red. _
         (and (not Red) (balanced-height ?l))
         (and (not Red) (balanced-height ?r)))
       #(= l r))
  l)
```

This is a pattern which only matches balanced red-black trees, by recursively matching against each branch and returning the number of black nodes per path (see property 5 [here](http://en.wikipedia.org/wiki/Red%E2%80%93black_tree#Properties)).

## Parsing

Strucjure supports patterns which only consume part of the input and can chain these patterns together. Combine that with pattern matching and you can very easily write back-tracking recursive-descent parsers.

We can use this for traditional text parsing (you have to be feeling a little masochistic at the moment because strucjure can't directly handle strings yet, only sequences of \c \h \a \r \s). For example, strucjure [parses its own readme](http://scattered-thoughts.net/blog/2012/10/25/strucjure-reading-the-readme/) to ensure all the examples are correct.

Parsing doesn't have to be limited to text. We can apply the same techniques to any sequential data structure.

``` clojure
user> (defnview zero-or-more-prefix [elem]
        (prefix & (elem ?x) & ((zero-or-more-prefix elem) ?xs)) (cons x xs)
        (prefix ) nil)
#'user/zero-or-more-prefix
user> (defview self-counting
        (prefix 1) 'one
        (prefix 2 2) 'two
        (prefix 3 3 3) 'three)
#'user/self-counting
user> (run (zero-or-more-prefix self-counting) [1 3 3 3 2 2 1 2 2])
(one three two one two)
```

Since we live in lisp land, code is data too. We can use strucjure to easily and *readably* (hopefully) operate over sexps.

``` clojure
;; generic parser for (right-binding) infix operators with precedence

(defn value? [all form]
  (not-any? #(contains? % form) all))

(defn bind* [all current]
  (if-let [[ops & tighter] current]
    (view
     (prefix & ((bind* all tighter) ?x) (and #(contains? ops %) ?op) & ((bind* all current) ?y)) `(~op ~x ~y)
     (prefix & ((bind* all tighter) ?x)) x)
    (view
     (prefix [((bind* all all) ?x)]) x
     (prefix (and #(value? all %) ?x)) x)))

(defn bind [binding-levels]
  (bind* binding-levels binding-levels))

;; run 'bind with basic arithmetic precedences
(defmacro math [& args]
  (run (bind [#{'+ '-} #{'* '/}]) args))

(macroexpand '(math 1 - 2 + 3 - 4))
;; (- 1 (+ 2 (- 3 4)))
(macroexpand '(math 1 + 2 * 7 + 1 / 2))
;; (+ 1 (+ (* 2 7) (/ 1 2)))
(macroexpand '(math 1 + 2 * (7 + 1) / 2))
;; (+ 1 (* 2 (/ (7 + 1) 2)))
```

No more death-by-polish-notation!

(The operators above really ought to bind to the left but, unlike ometa, strucjure doesn't yet support [left-recursion](http://en.wikipedia.org/wiki/Left_recursion) and I'm too lazy to manually transform the grammar. It's a temporary limitation.)

Taking this to its logical conclusion, the syntax for patterns and views in strucjure is itself defined [using views](https://github.com/jamii/strucjure/blob/master/src/strucjure/parser.clj#L178). This is a fairly complex DSL but with strucjure it's was very easy to write, read and modify the parser.

## Generic programming

Clojure has some great facilities for generic traversals in the form of clojure.walk:

``` clojure
(defn walk
  "Traverses form, an arbitrary data structure.  inner and outer are
  functions.  Applies inner to each element of form, building up a
  data structure of the same type, then applies outer to the result.
  Recognizes all Clojure data structures. Consumes seqs as with doall."

  {:added "1.1"}
  [inner outer form]
  (cond
   (list? form) (outer (apply list (map inner form)))
   (instance? clojure.lang.IMapEntry form) (outer (vec (map inner form)))
   (seq? form) (outer (doall (map inner form)))
   (coll? form) (outer (into (empty form) (map inner form)))
   :else (outer form)))

(defn postwalk
  "Performs a depth-first, post-order traversal of form. Calls f on
each sub-form, uses f's return value in place of the original.
Recognizes all Clojure data structures except sorted-map-by.
Consumes seqs as with doall."
  {:added "1.1"}
  [f form]
  (walk (partial postwalk f) f form))
```

Essentially, all this is doing is specifying how to take apart clojure data structures and how to put them back together again. Strucjure supports passing optional :pre-view and :post-view functions to modify the input to or output from any named view encountered during parsing, so we can do something very similar:

``` clojure
(defview clojure
  (and list? ((zero-or-more clojure) ?xs)) xs
  (and clojure.lang.IMapEntry [?x ?y]) [x y]
  (and seq? ((zero-or-more clojure) ?xs)) xs
  (and coll? ?coll ((zero-or-more clojure) ?xs)) (into (empty coll) xs)
  ?other other)

(defn postwalk [form f]
  (run clojure form {:post-view (fn [_ sub-form] (f sub-form)}))
```

The problem with using this (or clojure.walk) for generic traversals is that it loses context. When a given sub-form is encountered, the function f is given no indication of where in the data structure that sub-form is or how it is being used. If we apply the above idea to domain-specific views we can do generic traversals *with context*. The motivating example for this was a simple game I was porting called [l-seed](https://github.com/jamii/l-seed) (I haven't yet updated l-seed to use strucjure, but you can see a precursor to it in [l-seed.syntax](https://github.com/jamii/l-seed/blob/master/src/l_seed/syntax.clj)). In l-seed, players submit programs defining the growth of their plant species and compete with other player's plants for sunlight and nutrients. The plant language can be defined like this:

``` clojure
(defview +name+
  string? %)

(defview +tag+
  string? %)

(defview +length+
  (and number? #(<= 0 %)) %)

(defview +direction+
  (and number? #(<= -360 % 360)) %)

(defview +relation+
  (or '= '> '>= '< '<=) %)

(defview +property+
  (or 'tag 'length 'direction) %)

(defview +condition+
  ['and & ((zero-or-more +condition+) ?conditions)] (cons 'and conditions)
  ['or & ((zero-or-more +condition+) ?conditions)] (cons 'or conditions)
  ['not (+condition+ ?condition)] (list 'not condition)
  [(+relation+ ?relation) (+property+ ?property) ?value] (list relation property value))

(defview +condition-head+
  ['when (+condition+ ?condition)] (list 'when condition)
  'whenever 'whenever)

(defview +action+
  ['grow-by (+length+ ?length)] (list 'grow-by length)
  ['turn-by (+direction+ ?direction)] (list 'turn-by direction)
  ['turn-to (+direction+ ?direction)] (list 'turn-to direction)
  ['tag (+tag+ ?tag)] (list 'tag tag)
  ['blossom (+tag+ ?tag)] (list 'blossom tag)
  ['branch & ((zero-or-more (zero-or-more +action+)) ?action-lists)] (cons 'branch action-lists))

(defview +rule+
  ['rule (+name+ ?name) (+condition-head+ ?condition-head) & ((zero-or-more +action+) ?actions)] (apply list 'rule name condition-head actions))

(defview +rules+
  [& ((zero-or-more +rule+) ?rules)] rules)
```

(Note that we specify both how to take apart a data structure and how to put it together. Really, the latter should be derived from the former. I think strucjure will eventually feature reversible patterns for this purpose.)

We can then operate on these programs in a generic way. For example, deciding which rule to execute next:

``` clojure
(defn select* [properties]
  (defview
    [`+relation+ ?relation] (resolve relation)
    [`+property+ ?property] (get properties property)
    [`+condition+ ['and & ?conds]] (every? true? conds)
    [`+condition+ ['or & ?conds]] (some true? conds)
    [`+condition+ ['not ?cond]] (not cond)
    [`+condition+ [?relation ?property ?value]] (relation property value)
    [`+condition-head+ ['when ?condition]] condition
    [`+condition-head+ ['whenever]] true
    [`+rule+ ['rule _ ?condition & ?actions]] (when condition actions)
    [`+rules+ [& ?rules]] (choose (filter seq rules))
    [_ ?other] other))

(defn select [rules properties]
  "Pick a valid rule and return its list of actions (or nil if no rules are valid)"
  (utilpostwalk +rules+ rules (select* properties)))
```

Writing code like this allows us to separate the shape of the data from the computation we perform over it.

We're also not limited to just walking over data structures. We can perform more complex operations in the same generic fashion.

``` clojure
(defn map-reduce [strucjure form map-op reduce-op]
  "Call map-op on every sub-form and reduce results with reduce-op"
  (let [acc (atom (reduce-op))]
    (run strucjure form
           {:post-view (fn [name form]
                         (swap! acc reduce-op (map-op name form))
                         form)})
    @acc))

(defn collect [strucjure form filter-op]
  "Return all sub-forms satisfying filter-op"
  (let [acc (atom nil)]
    (run strucjure form
           {:post-view (fn [name form]
                         (if (filter-op name form)
                           (swap! acc conj result)))})
    @acc))
```

## Types

I originally learned to code in haskell. One of the things I miss about strong static typing is it that it automatically provides documentation about the data structures used in your program. Strucjure patterns can fulfill the same role. In l-seed, if you are confused about what a rule should look like you can just go look at the +rule+ pattern.

We can't quite get static typing out of this, but we do get runtime checking for complex typedata-structures:

``` clojure
(defmacro defgenotype [name & rules]
  ;; compile-time syntax check for the genotype language
  (run +rules+ rules)
  `(def ~name '~(vec rules)))
```

In theory, it should also be possible to generate random data structures satisfying a given pattern. This would be useful for providing examples and for [generative testing](https://github.com/clojure/test.generative). In erlang, [proper](https://github.com/manopapad/proper) allows using type-specs directly alongside hand-written generators. I haven't yet implemented this in strucjure but I think it should be reasonably easy once reversible patterns are implemented.

## State machines

One can think of parsers in general as state machines with look-ahead and backtracking. OMeta takes this idea and runs with it:

> Most  interesting  ideas  have  more  than  one  fruitful  way  to  view  them,  and  it  occurred  to  us  that,
> abstractly,  one  could  think  of  TCP/IP  as  a  kind  of  “non‐deterministic  parser  with  balancing
> heuristics”,  in  that  it  takes  in  a  stream  of  things,  does  various  kinds  of  pattern‐matching  on  them,
> deals with errors by backing up and taking other paths, and produces a transformation of the input in
> a specified form as a result.
>
> Since the language transformation techniques we use operate on arbitrary objects, not just strings (see
> above), and include some abilities of both standard and logic programming, it seemed that this could
> be used to make a very compact TCP/IP. Our first attempt was about 160 lines of code that was robust
> enough to run a website. We think this can be done even more compactly and clearly, and we plan to
> take another pass at this next year.

I haven't yet tried doing anything like this in strucjure, but all the machinery is there. It would make an interesting complement to [droplet](https://github.com/jamii/droplet).

## Moving forward

There are of lot of different directions for improvement and experimentation.

One of my top priorities is better error reporting. This sucks:

```clojure
clojure.lang.ExceptionInfo: throw+: #strucjure.view.PartialMatch{:view #strucjure.view.Or{:views [#strucjure.view.Match{:pattern #strucjure.pattern.Seq{:pattern #strucjure.pattern.Chain{:patterns [#strucjure.view.Import{:view-fun #<test$bind_STAR_$fn__2339 test$bind_STAR_$fn__2339@60a896b8>, :pattern #strucjure.pattern.Bind{:symbol x}} #strucjure.pattern.Head{:pattern #strucjure.pattern.And{:patterns [#strucjure.pattern.Guard{:fun #< clojure.lang.AFunction$1@5c3f3b9b>} #strucjure.pattern.Bind{:symbol op}]}} #strucjure.view.Import{:view-fun #<test$bind_STAR_$fn__2343 test$bind_STAR_$fn__2343@3b626c6d>, :pattern #strucjure.pattern.Bind{:symbol y}}]}}, :result-fun #< clojure.lang.AFunction$1@3abc8690>} #strucjure.view.Match{:pattern #strucjure.pattern.Seq{:pattern #strucjure.pattern.Chain{:patterns [#strucjure.view.Import{:view-fun #<test$bind_STAR_$fn__2347 test$bind_STAR_$fn__2347@2f267610>, :pattern #strucjure.pattern.Bind{:symbol x}}]}}, :result-fun #< clojure.lang.AFunction$1@6112c9f>}]}, :input (1 - 2 + 3 - 4), :remaining (- 2 + 3 - 4), :output 1}
```

I have some ideas about how to improve this but nothing totally concrete. I could, at the very least, return the bindings that existed at the point of failure along with some kind of failure stack. If I can figure out a reasonable way to implement [cut](http://en.wikipedia.org/wiki/Cut_%28logic_programming%29) that will also help.

Another short-term priority is some form of [tail call elemination](http://en.wikipedia.org/wiki/Tail_call#Tail_recursion_modulo_cons). Many patterns and views are naturally implemented in a recursive fashion:

``` clojure
(defnview zero-or-more [elem]
  (prefix (elem ?x) & ((zero-or-more elem) ?xs)) (cons x xs)
  (prefix ) nil)
```

But in the current implementation of strucjure this will quickly overflow the stack. The current workaround is to define such views by hand:

``` clojure
(defrecord ZeroOrMore [view]
  View
  (run* [this input opts]
    (when (or
           (nil? input)
           (instance? clojure.lang.Seqable input))
      (loop [elems (seq input)
             outputs nil]
        (if-let [[elem & elems] elems]
          (if-let [[remaining output] (run view elem opts)]
            (if (nil? remaining)
              (recur elems (cons output outputs))
              [(cons elem elems) (reverse outputs)])
            [(cons elem elems) (reverse outputs)])
          [nil (reverse outputs)])))))

(def zero-or-more ->ZeroOrMore)
```

This is gross. I don't have any ideas on how to overcome this.

I've already briefly mentioned reversible patterns. At the beginning of this post I warned that I would use the terms view and pattern interchangeably. The line between them in strucjure is currently blurry but I think that the distinction should be that patterns must be reversible while views are allowed to destroy information.

Lastly, there will eventually be a need for some level of optimization. Given the extra flexibility in strucjure I don't expect to ever be as fast as core.match but there is certainly lots of room for improvement on the current code. Originally, strucjure patterns were compiled into efficient clojure code but the implementation was complicated and it was difficult to rapidly iterate around it. I will probably return to compilation once the semantics and interface settle down.

For now, I'm going to dogfood strucjure in various projects while ruminating on improvements. I'm already very happy with how much leverage can be had from such a simple idea, especially if I can fix the problems above. Hopefully the examples here might get other people thinking along the same lines.

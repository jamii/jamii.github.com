---
layout: post
title: "Hugo-a-go-go"
date: 2013-10-06 13:22
comments: true
categories: project
---

For the [2013 Clojure Cup](http://clojurecup.com/) myself and [Tom Hall](http://www.thattommyhall.com/) wrote a [go](http://en.wikipedia.org/wiki/Go_%28game%29) AI in clojurescript, inspired by [pushkin](https://github.com/ztellman/pushkin). The source is [here](https://github.com/jamii/hugo-a-go-go/) and it can currently be played on the [clojure cup site](http://hugoagogo.clojurecup.com/) (only tested in chrome).

<!--more-->

Before reading this post it would help to understand the rules of go. Hugo-a-go-go follows (an approximation of) the [chinese rules](http://en.wikipedia.org/wiki/Rules_of_Go#Chinese_rules). Due to the limited time we don't yet check for [ko](http://en.wikipedia.org/wiki/Rules_of_Go#Ko) and don't even attempt to detect the end of the game. The code at the moment is incredibly messy and probably very buggy (the version we submitted seems to actually *try* to lose) so treat it with suspicion.

## Board

The best place to start is with the board representation. The most expensive operation for the AI is detecting suicide and death. To make this fast we track connected strings of pieces.

``` clojure
(defrecord String [colour liberties])
```

`colour` is one of `:black`, `:white`, `:grey` (for the border) or `:empty`. `liberties` tracks the number of [pseudo-liberties](https://groups.google.com/forum/#!msg/computer-go-archive/hs259RQQ5hI/TOLFX2d5Y6UJ) the string has (for black or white strings; for empty or grey strings the `liberties` value is never read and exists just to avoid having to branch on the colour).

The board is represented by a 1d array of pointers to strings (this representation is inspired by [gnugo](http://www.gnu.org/software/gnugo/) rather than pushkin) and a pointer to the empty string (which we use for fast `empty?` checks).

``` clojure
(defrecord Board [strings empty-string])

(def size 9)
(def array-size (+ 2 size))
(def max-pos (* array-size array-size))

(defn ->pos [x y]
  (+ 1 x (* array-size (+ 1 y))))
```

To create a board we just have to setup the empty-string and border-string.

``` clojure
(defn new []
  (let [empty-string (->String :empty 0)
        border-string (->String :grey 0)
        strings (object-array max-pos)]
    (dotimes [i max-pos]
      (aset strings i empty-string))
    (dotimes [i array-size]
      (aset strings (->pos (dec i) -1) border-string)
      (aset strings (->pos (dec i) size) border-string)
      (aset strings (->pos -1 (dec i)) border-string)
      (aset strings (->pos size (dec i)) border-string))
    (->Board strings empty-string)))
```

A given move is *not* suicide if, after the move is made, there is at least one neighbour which is either:

* the same colour and has more than zero liberties

* the opposite colour and has zero liberties (ie would die if the move was carried through)

* empty

``` clojure
(defn suicide? [^Board board colour pos]
  (let [suicide (atom true)
        opposite-colour (condp keyword-identical? colour :black :white :white :black)]
    ;; decrement all the neighbours liberties
    (foreach-neighbour neighbour-pos pos
      (let [string (aget (.-strings board) neighbour-pos)]
        (set! (.-liberties string) (dec (.-liberties string)))))
    ;; check for suicide
    (foreach-neighbour neighbour-pos pos
      (let [string (aget (.-strings board) neighbour-pos)]
        (condp keyword-identical? (.-colour string)
          colour (when (> (.-liberties string) 0)
                   (reset! suicide false))
          opposite-colour (when (= (.-liberties string) 0)
                            (reset! suicide false))
          :empty (reset! suicide false)
          :grey nil)))
    ;; undo the decrement
    (foreach-neighbour neighbour-pos pos
      (let [string (aget (.-strings board) neighbour-pos)]
        (set! (.-liberties string) (inc (.-liberties string)))))
    @suicide))
```

Actually making a move is similar but we have to clear out dead strings and join adjacent strings together. Proving that it's safe to do all this in a single pass is straightforward, if tedious.

``` clojure
defn set-colour [^Board board pos colour]
  (let [string (->String colour 0)]
    (aset (.-strings board) pos string)
    (foreach-neighbour neighbour-pos pos
                       (let [neighbour-string (aget (.-strings board) neighbour-pos)
                             neighbour-colour (.-colour neighbour-string)]
                         (condp keyword-identical? neighbour-colour
                           :empty
                           (set! (.-liberties (aget (.-strings board) pos)) (inc (.-liberties (aget (.-strings board) pos))))

                           :grey
                           nil

                           colour
                           (do
                             (set! (.-liberties neighbour-string) (dec (.-liberties neighbour-string)))
                             (join-strings board (aget (.-strings board) pos) neighbour-string pos neighbour-pos))

                           ;; opposite colour
                           (do
                             (set! (.-liberties neighbour-string) (dec (.-liberties neighbour-string)))
                             (when (= 0 (.-liberties neighbour-string))
                               (clear-string board neighbour-string neighbour-pos))))))))
```

## Monte Carlo

Go branches far too much to exhaustively check all possible futures. Instead we use a heuristic measure of the value of a move - the Monte Carlo estimate of the expected score when both players choose from the set of valid moves uniformly at random. To put it simply, we run large numbers of random games from this board position and take the mean score as our measure of how strong this board position is. Since we don't have a test for the end of the game we just run until either 100 moves have been made or until both sides have no valid moves remaining.

``` clojure
(defn flood-fill [board colour]
  (let [filled (object-array max-pos)]
    (letfn [(flood-fill-around [pos]
              (foreach-neighbour pos pos
                  (when (and (not (aget filled pos))
                             (keyword-identical? :empty (get-colour board pos)))
                    (aset filled pos true)
                    (flood-fill-around pos))))]
      (dotimes [x size]
        (dotimes [y size]
          (let [pos (->pos x y)]
            (when (keyword-identical? colour (get-colour board pos))
              (aset filled pos true)
              (flood-fill-around pos))))))
    (count (filter identity filled))))

(defn score [board]
  (let [white-flood (flood-fill board :white)
        black-flood (flood-fill board :black)
        total (* size size)
        overlap (- (+ white-flood black-flood) total)
        white-score (- white-flood overlap)
        black-score (- black-flood overlap)]
    {:white white-score :black black-score}))

(defn random-move [board colour]
  (let [starting-pos (random-int board/max-pos)]
    (loop [pos starting-pos]
      (if (and (board/valid? board colour pos)
               (not (board/eyelike? board colour pos)))
        pos
        (let [new-pos (mod (inc pos) board/max-pos)]
          (if (= starting-pos new-pos)
            nil
            (recur new-pos)))))))

(defn with-random-moves [board n starting-colour]
  (doseq [colour (take n (interleave (repeat starting-colour) (repeat (board/opposite-colour starting-colour))))]
      (when-let [move (random-move board colour)]
        (board/set-colour board move colour)))
  board)
```

You may notice that the above code actually only runs until one side has no moves - this is the first of many bugs.

The scoring and random-move code was a huge bottleneck so at the last minute I 'optimised' it by changing it to:

``` clojure
;; rough approximation of the final score if the board is tightly packed
(defn score [board colour]
  (let [score (atom 0)]
    (dotimes [pos board/max-pos]
      (when (keyword-identical? colour (board/get-colour board pos))
        (swap! score inc)))
    @score))

;; massive speedup at the expense of never playing in killed spaces
(defn with-random-moves-from [board n starting-colour moves]
  (js/goog.array.shuffle moves)
  (loop [colour starting-colour]
    (if-let [move (.pop moves)]
      (board/set-colour board move colour)
      (recur (board/opposite-colour colour))))
  board)
```

I think it is these two changes that are largely responsible for the submitted version playing so poorly - it doesn't check for eyes in the random playouts, doesn't allow the other player to keep killing strings when the ai player has no moves and doesn't count eyes in the final score. This explains why it likes to tightly pack pieces against the edge of the board.

## UCT

While the monte-carlo estimate gives us a reasonable heuristic for move strength it doesn't re-use any information between passes. With such a large move space we need to explore more intelligently. The [UCT](http://teytaud.over-blog.com/article-35709049.html) algorithm treats move-selection like a [multi-armed bandit problem](http://en.wikipedia.org/wiki/Multi-armed_bandit).

<iframe width="640" height="360" src="//www.youtube.com/embed/dbvoPg51CqQ?feature=player_embedded" frameborder="0" allowfullscreen="allowfullscreen">video</iframe>

We build a tree of moves where each node in the tree tracks not just the estimated score for all its child nodes but also the upper bound of a confidence interval on that estimate.

``` clojure
(defrecord Node [parent colour pos count sum nodes valids])
```

`colour` is the colour making the move at this node. `pos` is the position at which it is moving. `nodes` is a list of child nodes for which we have estimates. `valids` is a list of valid moves which have not yet been converted into nodes. `count` and `sum` track the mean score for all the children in `nodes`.

On each iteration we pick a path through the tree, choosing some explore/exploit tradeoff using the upper confidence bounds. Given the limited time we had, I decided to just copy a scoring function from a paper without stopping to understand it, so I don't actually know what explore/exploit tradeoff we are making :S

``` clojure
(defn best-child [node]
  (let [best-score (atom (- (/ 1 0)))
        best-child (atom nil)]
    (doseq [child (.-nodes node)]
      (let [score (+ (/ (.-sum child) (.-count child))
                     (js/Math.sqrt
                      (/ (* 2 (js/Math.log (.-count node)))
                         (* 5 (.-count child)))))]
        (when (> score @best-score)
          (reset! best-score score)
          (reset! best-child child))))
    @best-child))

(defn expand [board node ai-colour]
  (let [pos (.-pos node)]
    (if (not= 0 pos) ;; top node has pos 0 - probably a smell
      (board/set-colour board pos (.-colour node))))
  (if-let [valid-pos (.pop (.-valids node))]
    (.push (.-nodes node) (expand-leaf board ai-colour node (board/opposite-colour (.-colour node)) valid-pos))
    (if-let [child (if (= (.-colour node) ai-colour)
                     (worst-child node)
                     (best-child node))]
      (expand board child ai-colour)
      nil ;; no possible moves - pass
      )))
```

On reaching a leaf we extend it by one more move, estimate the value of that move using monte-carlo simulations and then propagate the value back up the path to the top of tree.

``` clojure
(defn expand-leaf [board ai-colour parent colour pos]
  (board/set-colour board pos colour)
  (let [valids (valids board (board/opposite-colour colour))]
    (random/with-random-moves-from board 100 (board/opposite-colour colour) (aclone valids))
    (let [value (value board ai-colour)]
      (add-value parent value)
      (->Node parent colour pos 1 value (object-array 0) valids))))

(defn add-value [node value]
  (set! (.-count node) (+ (.-count node) 1))
  (set! (.-sum node) (+ (.-sum node) value))
  (if-let [parent (.-parent node)]
    (recur parent value)))
```

Finally, the ai chooses its move by running a number of iterations of this algorithm and returning the value of `best-child` at the root (this is probably wrong - at this point we should just exploit, not explore).

``` clojure
(defn move-for [board colour n]
  (let [node (hugo-a-go-go.tree/new (board/copy board) colour)]
    (dotimes [_ n]
      (expand (board/copy board) node colour))
    (when-let [child (best-child node)]
      (.-pos child))))
```

## Postmortem

Together we spent around 20 man-hours on the competition. I spent the first two thirds of the competition just getting the board representation to work correctly. Part of the delay was that after moving to a cljs-only implementation the feedback loop was much slower. I wasted an hour or two tring to get brepl working without any success and after that had to rely on print statements and pre-compiled test cases. Finding errors in cljs also leaves a lot to be desired (eg a typo in a field name resulted in an `undefined` value which, several functions later, became a `NaN` which then behaves interestingly inside max/min). I only started on the UCT code an hour or two before the deadline. Tom started on the user input around the same time. We played our first game against the ai about five minutes before the deadline and frantically submitted whatever code we had running.

If we were taking it more seriously we certainly could have done a lot more to prepare - being familiar with the cljs dev tools, actually learning the rules of go, sketching out the board representation and the UCT implementation before the weekend started, not walking a marathon on the same weekend. But winning was not the goal and instead we had a lot of fun and excitement seeing just how much we can hack together in such a short space of time.

Our AI is definitely not correct so it's difficult to evaluate the project yet. The code is relatively short and simple (especially compared to eg [gnugo](http://git.savannah.gnu.org/cgit/gnugo.git/tree/engine)) but that doesn't mean much until it actually works. The performance is promising - the current version can simulate around 5k games per second in chrome. Fixing the monte-carlo step and the scoring will eat into that performance but I've already spotted plenty of inefficiencies in other places. We haven't even started experimenting with [vertigo](https://github.com/ztellman/vertigo) or [asm.js](http://asmjs.org/) yet so there is certainly lots of headroom.

I am definitely hoping to come back to this project. To echo [Zach Tellman's motivation](http://www.youtube.com/watch?v=v5dYE0CMmHQ), it will be really interesting to see if it is possible to write a competitive go AI in a high-level language. We've also thought about distributing the UCT step and have team games pitching the aggregated wisdom of a group of human players voting on their next move against the assembled computing power of their browsing machines.

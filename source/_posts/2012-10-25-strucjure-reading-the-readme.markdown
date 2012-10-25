---
layout: post
title: "Strucjure - reading the readme"
date: 2012-10-25 19:37
comments: true
categories: clojure strucjure
---

I just released [strucjure](https://github.com/jamii/strucjure), a clojure library and DSL for parsing and pattern matching based on [Ometa](http://lambda-the-ultimate.org/node/2477).

The readme on github has detailed descriptions of the syntax etc which I won't repeat here. What I do want to do is run through a realistic example.

<!--more-->

The readme has a large number of examples and I want to be sure that these are all correct and up to date. As part of the test-suite for strucjure I parse the [readme source](https://raw.github.com/jamii/strucjure/master/README.md), pull out all the examples and make sure that they all run correctly and return the expected output.

```bash
jamie@alien:~/strucjure$ lein test strucjure.test
WARNING: newline already refers to: #'clojure.core/newline in namespace: strucjure.test, being replaced by: #'strucjure.test/newline

lein test strucjure.test

Ran 1 tests containing 166 assertions.
0 failures, 0 errors.
```

The readme parser is pretty simple. Since I control both the parser and the readme source so it doesn't need to be bullet-proof, just the simplest thing that will get the job done. Strucjure is very bare-bones at the moment though so we have to create a lot of simple views that really belong in a library somewhere.

```clojure
(defview space
  \space %)

(defview newline
  \newline %)

(defview not-newline
  (not \newline) %)

(defview line
  (and (not []) ; have to consume at least one char
       (prefix & ((zero-or-more not-newline) ?line)
               & ((optional newline) ?end)))
  line)

(defview indented-line
  (prefix & ((one-or-more space) _) & (line ?line))
  line)
```

We want a tokeniser for various parts of the readme. We could write it like this:

```clojure
(defnview tokenise [sep]
  ;; empty input
  [] '(())
  ;; throw away separator, start a new token
  [& (sep _) & ((tokenise sep) ?results)] (cons () results)
  ;; add the current char to the first token
  [?char & ((tokenise sep) [?result & ?results])] (cons (cons char result) results))
```

Unfortunately in the current implementation of strucjure that recursive call goes on the stack, so this view will blow up on large inputs. For now we just have to implement this view by hand to get access to recur.

```clojure
(defn tokenise [sep]
  (view/->Raw
   (fn [input opts]
     (when-let [elems (seq input)]
       (loop [elems elems
              token-acc nil
              tokens-acc nil]
         (if-let [[remaining _] (view/run sep elems opts)]
           (recur remaining nil (cons (reverse token-acc) tokens-acc))
           (if-let [[elem & elems] elems]
             (recur elems (cons elem token-acc) tokens-acc)
             [nil (reverse (cons (reverse token-acc) tokens-acc))])))))))
```

The rest of the parser makes more sense reading in reverse order. We start by splitting up the readme by code delimiters (triple backticks). This gives us chunks of alternating text and code, so we parse every other chunk as a block of code.

```clojure
(defview code-delim
  (prefix \` \` \`)
  :code-delim)

(defview readme
  ((tokenise code-delim) ?chunks)
  (apply concat (map (partial run code-block) (take-nth 2 (rest chunks)))))
```

We only want to look at code blocks that are marked as clojure code.

```clojure
(defview code-block
  [\c \l \o \j \u \r \e \newline & (code-block-inner ?result)]
  result)
```

A few of the code blocks don't contain examples - we can detect these because they don't start with a "user> " prompt. All the other blocks contain a list of examples separated by prompts.

```clojure
(defview prompt
  (prefix \u \s \e \r \> \space)
  :prompt)

(defview code-block-inner
  (and (prompt _)
       ((tokenise prompt) ?chunks))
  (map (partial run example) (filter #(not (empty? %)) chunks))

  _ ;; not a block of examples
  nil)
```

An example consists of an input, which may be on multiple lines, zero or more lines of printed output and finally a result.

```clojure
(defview example
  [& (line ?input-first)
   & ((zero-or-more-prefix indented-line) ?input-rest)
   & ((one-or-more-prefix line) ?output-lines)]
  {:input (with-out-str (doseq [line (cons input-first input-rest)] (print (apply str line) \space)))
   :prints (with-out-str (doseq [line (butlast output-lines)] (println (apply str line))))
   :result (run result (last output-lines))})
```

The result is either a return value or an exception.

```clojure
;; #"[a-zA-Z\.]"
(defview exception-chars
  (or \.
      #(<= (int \a) (int %) (int \z))
      #(<= (int \A) (int %) (int \Z)))
  %)

(defview result
  [\E \x \c \e \p \t \i \o \n \I \n \f \o \space
   \t \h \r \o \w \+ \: \space
   \# & ((one-or-more exception-chars) ?exception)
   & _]
  [:throws (apply str exception)]

  ?data
  [:returns (apply str data)])
```

That's it - parsing done.

Now we just have to turn the results into unit tests. We have to be careful about comparing the results of the examples because they might contain closures, which look different every time.

```clojure
(defn replace-fun [unread-form]
  (.replaceAll unread-form "#<[^>]*>" "#<fun>"))

(defn prints-as [string form]
  (= (replace-fun string) (replace-fun (with-out-str (pr form)))))
```

Running the examples is a little tricky because some of them create bindings or classes that are used by later examples. We end up needing to eval the code at runtime.

```clojure
(defn example-test [input prints result]
  (match result
         [:returns ?value]
         (do
           (is (prints-as value (input)))
           (is (= prints (with-out-str (input)))))

         [:throws ?exception]
         (do
           (is (try+ (input)
                     nil
                     (catch java.lang.Object thrown
                       (prints-as exception (class thrown)))))
           (is (= prints (with-out-str
                           (try+ (input)
                                 (catch java.lang.Object _ nil))))))))

(defmacro insert-example-test [{:keys [input prints result]}]
  `(example-test (fn [] (eval '(do (use '~'strucjure) ~(read-string input)))) ~prints '~result))

(defmacro insert-readme-test [file]
  `(do
     ~@(for [example (run readme (seq (slurp (eval file))))]
         `(insert-example-test ~example))))

(deftest readme-test
  (insert-readme-test "README.md"))
```

This is fun. Not only does strucjure parse its own syntax, it checks its own documentation!

Parts of this were a little painful. The next version of strucjure will definitely have improved string matching. I'm also looking at optimising/compiling views, as well as memoisation. Previous versions of strucjure supported both but were hard to maintain. For now I'm going to be moving on to using strucjure to build other useful DSLs.

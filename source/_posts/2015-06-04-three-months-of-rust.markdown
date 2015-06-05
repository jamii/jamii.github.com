---
layout: post
title: "Three months of Rust"
date: 2015-06-04 16:30
comments: true
categories: thought
---

I work on [Eve](http://incidentalcomplexity.com/), a functional-relational programming language and environment. Since the Eve editor has to run in a browser we built the first few versions entirely in javascript. This has been pretty painful, so a little over three months ago we started looking at other options.

The only hard requirements for the runtime are a) we need control over memory layout and b) we need to safely execute untrusted Eve code. Preemptive threads and the ability to compile to efficient javascript would also be valuable.

Javascript *can* support manual memory layout but provides very little help in getting it right. Native objects have some [necessary limitations](https://news.ycombinator.com/item?id=8793817) and asm.js is impractical to write by hand.

C can run in the browser via Emscripten but the available evidence suggests that writing secure C is not a thing that mortals are good at.

Rust is an unknown. It provides control over memory layout, has a community with a strong focus on safety and *may* support Emscripten in the future. It also promises a minimum of [footguns](http://www.urbandictionary.com/define.php?term=footgun&defid=7493319), which is an attractive feature after many months of javascript and ArrayBuffers. Our initial experiments were promising, so we decided that in the next version of Eve we would write the query planner and runtime in Rust.

("You should look at language X!". We did, and then we decided to use Rust. We can still be friends.)

There are a number of things that made this much less risky than it sounds. First, the query planner is on the way to being bootstrapped and the remaining runtime is only a few thousand lines of code. Most of the development time is spent experimenting with different language semantics and evaluation strategies, rather than building up a large codebase that would tie us to Rust. Second, we have two escape hatches if Rust doesn't work out. We can use the FFI to gradually port components to C, or we can use the websocket interface to the editor to gradually port components to javascript.

So here is what I think after three months of working with Rust full-time. TLDR: mostly impressive, a few worrying quirks, probably the best option for us right now.

## Community

The Rust community seems to be populated entirely by human beings. I have no idea how this was done. I suspect Graydon Hoare deserves a large share of the credit for leading by example but everyone I have interacted with in the community has been friendly and patient.

Despite my concerns over the size and complexity of the compiler and the LLVM toolchain, I haven't encountered any compiler bugs and only a [single bug](https://github.com/rust-lang/rust/issues/24557) in the standard library. The community's attitude towards reliability and safety is by far the strongest point in favour of us continuing to use Rust.

## Tooling

Compile times are brutal. For our 2400 loc it takes 20s for a dev build and 70s for a release build. Word is that compile time just hasn't been a focus so far and will improve in future releases. Type checking occurs very early in that 20s so running `cargo build` in a loop gives reasonably fast feedback on type errors, but any time we want to add an extra print statement we pay the full price. Moving the Eve editor into Rust would simplify the overall architecture but the people writing the editor refuse to wait 20s for a page refresh.

Error messages are better than any other tool I have used. For most errors the compiler not only clearly explains the problem but also offers the correct solution. There is no secret sauce, it's just the result of long hours from the compiler team and a culture of caring about usability.

``` rust
src/relation.rs:110:29: 110:38 error: unresolved name `before_op`. Did you mean `before_opt`?
src/relation.rs:110                             before_op = befores.next();
```

``` rust
src/relation.rs:121:29: 121:33 error: attempted to take value of method `iter` on type `collections::vec::Vec<collections::string::String>`
src/relation.rs:121         let ix = self.names.iter.position(|my_name| &my_name[..] == name).unwrap();
                                                ^~~~
src/relation.rs:121:29: 121:33 help: maybe a `()` to call it is missing? If not, try an anonymous function
```

``` rust
src/value.rs:14:15: 14:20 error: cannot move out of borrowed content
src/value.rs:14         match *self {
                              ^~~~~
src/value.rs:17:27: 17:33 note: attempting to move value to here
src/value.rs:17             Value::String(string) => string.fmt(formatter),
                                          ^~~~~~
src/value.rs:17:27: 17:33 help: to prevent the move, use `ref string` or `ref mut string` to capture value by reference
```

Cargo is solid. Building projects, versioning dependencies and running tests/benchmarks are all easy. I would like to see `cargo bench` produce comparison graphs (like [readygo](https://github.com/garybernhardt/readygo)). I'm also looking forward to [rustfmt](https://github.com/nrc/rustfmt) since most editors currently do a pretty poor job of auto-indenting.

Javascript profilers tend to tell me that the Eve runtime spends 100% of its time in `main` and calls no other functions. With Rust I get to use valgrind and perf which actually return useful information.

Debugging is less exciting - both GDB and LLDB work and there is a [macros package](https://michaelwoerister.github.io/2015/03/27/rust-xxdb.html) that makes them more useful but the Chrome debugger is still far more useable (when it doesn't crash).

## Ownership

One of the unique features of Rust is that the type system tracks ownership of data. Shared mutability is the root of many bugs and vulnerabilities, especially in concurrent environments. Functional languages address this by removing or strictly controlling mutability. Rust addresses this by tracking and controlling sharing. See the [documentation](https://doc.rust-lang.org/book/ownership.html) for the gory details.

Most code I write now compiles without error. Most errors I see are clearly mistakes on my part and are easy to fix. About once a week, I hit an error that causes some headscratching. In most case I fume for a while before realising that I was trying to blow my foot off.

```
src/view.rs:205:70: 205:81 error: `outer_items` does not live long enough
src/view.rs:205                     output_pairs.push((&aggregate.outer.fields[..], &outer_items[..]));

                                                                                     ^~~~~~~~~~~
note: in expansion of for loop expansion
src/view.rs:172:17: 212:18 note: expansion site
src/view.rs:203:47: 212:18 note: reference must be valid for the block suffix following statement 3 at 203:46...
src/view.rs:203                         ).collect::<Vec<_>>();
src/view.rs:204                     let outer_items = vec![outer_values];
src/view.rs:205                     output_pairs.push((&aggregate.outer.fields[..], &outer_items[..]));
src/view.rs:206                     if aggregate.selects_inner {
src/view.rs:207                         output_pairs.push((&aggregate.inner.fields[..], group))
src/view.rs:208                     }
                ...
src/view.rs:204:58: 212:18 note: ...but borrowed value is only valid for the block suffix following statement 4 at 204:57
src/view.rs:204                     let outer_items = vec![outer_values];
src/view.rs:205                     output_pairs.push((&aggregate.outer.fields[..], &outer_items[..]));
src/view.rs:206                     if aggregate.selects_inner {
src/view.rs:207                         output_pairs.push((&aggregate.inner.fields[..], group))
src/view.rs:208                     }
src/view.rs:209                     let mut tuples = Vec::with_capacity(output_pairs.len());
```

It took me a while to realise that this error is trying to tell me is that `output_pairs` is declared one line before `outer_items`. Declarations for a block are freed in reverse order, so `outer_items` will be freed first and there will be a dangling pointer when `output_pairs` is freed. All I have to do to fix it is declare `output_pairs` after `outer_items`.

Most of my confusion looks like this. There is some pattern that I didn't think about before and now that I understand it I won't struggle with that kind of error again. As the language matures I expect that these patterns will be collected and documented.

There are also some patterns that the borrow checker can't understand (or, more accurately, there is no matching pattern in the standard library). This is a heavily simplified version of a common pattern in the query engine:

``` rust
fn step<'a>(table: &'a [String], state: &mut Vec<&'a String>, results: &mut Vec<Vec<String>>) {
    if table.len() == 0 {
        results.push(state.iter().map(|s| (*s).to_owned()).collect());
    } else if table.len() % 2 == 0 { // some complicated condition
        state.push(&table[0]);
        step(&table[1..], state, results);
        state.pop();
    } else {
        let s = "some new thing".to_owned();
        state.push(&s);
        step(&table[1..], state, results);
        state.pop();
    }
}

fn main() {
   let table = vec!["a".to_owned(), "b".to_owned(), "c".to_owned(), "d".to_owned()];
   let mut state = vec![];
   let mut results = vec![];
   step(&table[..], &mut state, &mut results);
}
```

Which produces this error:

``` rust
<anon>:10:21: 10:22 error: `s` does not live long enough
<anon>:10         state.push(&s);
                              ^
<anon>:1:95: 14:2 note: reference must be valid for the lifetime 'a as defined on the block at 1:94...
<anon>:1 fn step<'a>(table: &'a [String], state: &mut Vec<&'a String>, results: &mut Vec<Vec<String>>) {
<anon>:2     if table.len() == 0 {
<anon>:3         results.push(state.iter().map(|s| (*s).to_owned()).collect());
<anon>:4     } else if table.len() % 2 == 0 { // some complicated condition
<anon>:5         state.push(&table[0]);
<anon>:6         step(&table[1..], state, results);
         ...
<anon>:9:40: 13:6 note: ...but borrowed value is only valid for the block suffix following statement 0 at 9:39
<anon>:9         let s = "some new thing".to_owned();
<anon>:10         state.push(&s);
<anon>:11         step(&table[1..], state, results);
<anon>:12         state.pop();
<anon>:13     }
```

The core problem is that I'm pushing a value `s` into a vector which lives longer than `s`. The borrow checker isn't capable of proving that I remove the value again before it is freed. I could build a wrapper around the vector library that understands this pattern, or I could just promise the borrow checker that I know what I'm doing:

``` rust
    let s = "some new thing".to_owned();
    // promise the borrow checker that we will pop s before we exit this scope
    let s = unsafe { ::std::mem::transmute::<&String, &'a String>(&s) };
    state.push(s);
    step(&table[1..], state, results);
    state.pop();
```

I like this pragmatic approach to safety. When the type-system understands what I'm doing I get the full benefit. When it doesn't I can escape and do my own reasoning. If a particular pattern appears frequently I can put that reasoning into a library (like [RefCell](https://doc.rust-lang.org/std/cell/struct.RefCell.html) or [Rc](https://doc.rust-lang.org/std/rc/struct.Rc.html)) and expose a safe interface that the type system understands. It feels like having an extensible type system that can learn to understand the way each project manages memory.

EDIT [quxxy](http://www.reddit.com/r/rust/comments/38ljzu/three_months_of_rust/crw6f9m) suggested a better solution, using the copy-on-write type to allow the vec to own some of the strings and borrow the others:

``` rust
use std::borrow::Cow;

fn step<'a>(table: &'a [String], state: &mut Vec<Cow<'a, str>>, results: &mut Vec<Vec<String>>) {
    if table.len() == 0 {
        results.push(state.iter().map(|s| (**s).to_owned()).collect());
    } else if table.len() % 2 == 0 { // some complicated condition
        state.push(Cow::Borrowed(&table[0][..]));
        step(&table[1..], state, results);
        state.pop();
    } else {
        let s = "some new thing".to_owned();
        state.push(Cow::Owned(s));
        step(&table[1..], state, results);
        state.pop();
    }
}
```

## Control

Rust has [algebraic data-types](http://en.wikipedia.org/wiki/Algebraic_data_type) that layout data consecutively. Pointers are opt-in. Gaining a similar level of control in javascript *is* possible but it requires some mightily unpleasant gymnastics. Rust feels like a high-level language most of the time but manages to do it without vomiting all over the cache.

Rust doesn't help at all with [blobs](http://bitsquid.blogspot.com/2010/02/blob-and-i.html) though. They have to be handled with 'unsafe' code which subverts the normal Rust guarantees. The unsafe code could be wrapped in a library (like [columnar](https://github.com/frankmcsherry/columnar)) to ensure that clients use it correctly but the library code itself will still need very careful review. And speaking of review...

## Unsafe

There is a very recent effort to define [exactly what unsafe code has to do](http://cglab.ca/~abeinges/blah/rust-unsafe-intro/) to not ruin all the guarantees that Rust works so hard to provide. The list of [undefined behaviour](https://doc.rust-lang.org/reference.html#behavior-considered-undefined) is long and scary. It looks like consensus and documentation is on the way but until then ... here be dragons.

## Zero cost

Rust provides a lot of high-level abstractions which LLVM then optimises away. For example, large chains of iterator functions usually optimise into imperative loops. And the word 'usually' is what makes me worry. So far Rust has behaved but I have been bitten badly by other 'sufficiently smart' compilers.

Modern machines are a huge pile of opaque and unreliable heuristics and the current trend is to add more and more layers on top. The vast majority of systems are built this way and it is by all accounts a successful strategy. That doesn't mean I have to like it.

## Syntax

Doesn't matter that much. I got used to it.

There is a hint of object-orientation in that one can write `foo.bar(x, y, z)` and it desugars to something like `bar(foo, x, y, z)`. If it was only sugar I would be happy enough, but it also has non-trivial interactions with namespaces, trait dispatch, auto-deref and auto-borrow which I will go into below. There is a whole pile of intertwined design decisions here that have been made for totally valid ergonomic reasons but give rise to some interactions that make me nervous.

## Namespaces

There are effectively three kinds of namespaces.

Modules behave like most static languages - you can call functions using their full path or you can import them under a short name eg

``` rust
::my::global::namespace::foo(bar)

use my::global::namespace;
namespace::foo(bar);

use my::global::namespace::foo;
foo(bar);
```

There is some funkiness around how modules are structured and how they are scoped relative to each other that I haven't taken the trouble to understand. I only need one level of namespaces.

Types can also be namespaces. You can add a method to a type and access it either through the type or through the dot syntax.

``` rust
struct Bar{
  ...
}

impl Bar{
  fn foo(self) {...}
}

Bar::foo(bar);
bar.foo();
```

Lastly, traits can attach methods to types. To prevent collisions, the methods are namespaced by the trait.

``` rust
struct Bar {
  ...
}

trait Foo{
  fn foo(self);
}

impl Foo for Bar {...}

Foo::foo(bar);

use Foo; // import foo for the dot syntax
bar.foo();
```

Not unreasonable so far. It can sometimes be hard to track down where a particular method came from but the dispatch is at least direct. No inheritance or prototype chains to deal with.

## Traits

Haskell suffers from an excess of magic. Typeclass methods can dispatch on the type of any argument (or on the return type!) but the types are usually inferred. Reading haskell code that overuses typeclasses may require running the inference algorithms in your head, which is difficult and error-prone. This can also lead to bugs when an edit in one place changes a type, causing a different instance to be silently selected somewhere else (Don Stewart warned against this in his [PADL keynote](http://code.haskell.org/~dons/talks/padl-keynote-2012-01-24.pdf)).

OCaml leans entirely the other way. Code is very readable and maintainable because all the information needed to follow the dispatch is written down explicitly. On the other hand, printing a simple data-structure can require chaining together multiple lines of functors to get to the correct function.

Rust has very similar capabilities to haskell but (so far) abuses them less often. There are only a few cases so far where I felt lost in types - [rust-websocket](http://cyderize.github.io/rust-websocket/doc/websocket/index.html) being the biggest offender.

EDIT The section here on constraints was completely wrong and has been removed - see the [discussion](https://news.ycombinator.com/item?id=9664017) that corrected me.

## Auto-deref

Self types are further privileged. Suppose we have:

``` rust
trait Foo {
  fn foo(self);
}

x.foo()
```

If `x` implements `Foo` then life is simple. If `x` doesn't implement `Foo` but does implement `Deref` then the compiler will change the call to `x.deref().foo()`. This continues with `x.deref().deref().foo()` and so on until compiler finds a type that doesn't implement `Deref` or a type that does implement `Foo`. This is great ergonomically - it means you can call methods on a smart pointer as it were the pointed-at object. But it only works on the self argument - other arguments have to be manually deref-ed.

Similarly, if a method is declared to take `&self` or `&mut self` the compiler will insert the appropriate borrow before making the call. `foo.bar()` could desugar to `bar(foo)` or `bar(&foo)` or `bar(&mut foo)` depending on the type of `bar`.

Auto-deref and auto-borrow can interact unpleasantly with traits and inference. Here is a real example that totally confused me:

``` rust
let x = "foo":
print_type_of(x.to_owned()); // prints String

let xs = vec!["foo"];
for x in xs.into_iter() {
  print_type_of(x.to_owned()); // prints String
}

let xs = vec!["foo"];
for x in xs.iter() {
  print_type_of(x.to_owned()); // prints &str
)
```

What's going on? The standard library has the following implementations:

```
impl ToOwned for str {
  type Owned = String
  ...
}

impl<T> ToOwned for T where T: Clone {
  type Owned = T
  ...
}

impl Clone for &T
```

The type of `x` in the first two examples is `&str` which auto-derefs to `str` and gets `Owned = String`. The type of `x` in the third example is `&&str` (because iter borrows elements of the vec). `&str` implements `Clone` so `&&str` implements `ToOwned` directly and does not auto-deref to `str`.

This is a risk for traits in general, but auto-deref exacerbates it by creating multiple types that might choose an instance. In this case it caused a type error but you can imagine cases where adding a new trait implementation silently changes the selected instance of a seemingly unrelated call in far away code. Very difficult for code review to catch.

A similar mistake can happen if both the dereferenced type and the pointer type implement a method with the same name, but it looks like the standard library authors are aware of this and have stopped implementing methods directly on pointer types.


## Learning curve

The borrow checker was initially huge impediment to productivity but I reached the break-even point around the second month. Ownership and borrowing have become intuitive and I no longer have to contort designs around them.

Safety is an enormous productivity boon. I've checked in a total of 10k lines of Rust code and written many more experiments that didn't make it to master, and in that time I haven't had a single segfault, nor any bugs caused by accidental mutation, aliasing, type errors or null pointers. The vast majority of typing mistakes are also caught at compile time (the exceptions being interactions with dynamically typed Eve data).

Despite the restrictions of the type system, I am more productive in Rust than I am in either Javascript or Haskell. It manages somehow to hit a sweet spot between safety and ease of use.

By far, the feature I miss most is interactive development. The [repl](https://github.com/murarth/rusti) is only a thin layer over the compiler - it's equally slow and nukes all state between every eval. Adding interactivity to a language that wasn't designed for it is generally unsatisfying so this is not something that it likely to be fixed.

## For Eve

One of the core values of Eve is radical simplicity, in the same vein as the [STEPS](http://www.vpri.org/pdf/tr2011004_steps11.pdf) and [BOOM](http://boom.cs.berkeley.edu/) projects. We have to make compromises if we want to ever ship, but sitting atop Rust, LLVM and possibly Emscripten feels like a pretty big compromise.

The complexity in Rust exists to create a general-purpose systems language with an array of features and zero-cost abstractions that are incredibly useful for building large projects. But we aren't building a large project, by design, and we don't *need* most of the features.

The only places where we absolutely need manual layout so far are for Eve data and indexes. Those are nicely self-contained - no pointers to the outside world - and have a well-defined life-cycle. I wonder how far we could get with an approach like [Terra](http://terralang.org/), writing the core data-structures and algorithms in some scary unsafe language and interact with them safely from a managed language. With a staged approach we could build just the safety mechanisms that we need and avoid carrying around the complexity of the rest. Javascript seems to have all the features needed to make this kind of approach work but it doesn't have the tools needed to make it bearable. Creating one programming language is hard enough - we probably shouldn't start on another.

Regardless, Rust is an incredible language in general. Even if we end up using something else for Eve, I can see myself using Rust for other projects where I care about performance, safety or reliability.

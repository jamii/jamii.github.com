---
title: Journal
layout: page
date: 2016-01-29 19:40
comments: true
sharing: true
footer: true
---

<script type="text/x-mathjax-config">
MathJax.Hub.Config({
  tex2jax: {inlineMath: [['$','$'], ['\\(','\\)']]}
});
</script>
<script type="text/javascript" async
  src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=TeX-MML-AM_SVG">
</script>

This is a concatenation of work journals from various projects and points in time. It's in chronological order, but doesn't start using dates until about a year in.

### Next

The time has come to do the visa dance again, which means that for the next couple of months I will working on a new side project while I wait for immigration to decide my fate.

I've spent the last 18 months working on [Eve](http://witheve.com/), a project aimed at helping [knowledge workers](https://en.wikipedia.org/wiki/Knowledge_worker) analyse data, automate tasks and move information around. The focus has been on nailing the learning curve so that beginners can treat it like a simple spreadsheet and only gradually introduce features as they are needed. As I leave we're finally approaching a point where I feel optimistic about the shape of things - that the core ideas are mostly nailed down and we actually have something that could be useful to a lot of people.

However, it's not yet useful for *me*. I spend my days building compilers and IDEs, tasks which are not exactly a core focus for Eve. So if Eve is an experiment in 'programming for knowledge workers' then [Imp](https://github.com/jamii/imp) is an experiment in 'programming for people who make things like Eve'. The core ideas are the same but the immediate priorities are very different. To be able to build something like the Eve editor, I have to care about:

* __Performance__. Eve could survive and be useful even if it were never faster than, say, Excel. The Eve IDE, on the other hand, can't afford to miss a frame paint. That means Imp must be not just fast but predictable - the nemesis of the SufficientlySmartCompiler. It might also mean I need a way to split off long-running computations from the UI.

* __Bootstrapping__. It's not possible to use Eve without the IDE, and both the language and IDE are constantly changing and often incomplete. To make a language I can actually use today I need to figure out how to make it useable immediately and progressively enhance the tools later. The upside is that rather than building a polished interface for a general audience, I only need to build a tolerable starting point that I can work with.

* __UI__. I want to reduce the time it takes to try out new ideas for tools. Previous versions of Eve had a UI interface that was capable enough to [bootstrap a simple IDE](http://incidentalcomplexity.com/images/5.png) but required writing raw html and css. A more recent version sported a [UI editor](http://incidentalcomplexity.com/images/mamj-ui.png) that could handle data binding but only allowed static layout. I'm not sure if there is a better approach that I could feasibly finish - perhaps allowing binding to templates made by existing UI tools?

Performance is the only point for which I actually have something resembling a plan, so that's where I'll begin.

### Runtime

Like Eve, Imp is going to be a [Bloom](http://boom.cs.berkeley.edu/)-like language. There are a couple of stateful tables used for inputs and everything else is built out of [views](https://en.wikipedia.org/wiki/View_%28SQL%29) written in a Turing-complete query language. That means that the internals look more like a relational database than a programming language.

The query optimisation problem is almost the opposite of a normal database though - I know all the queries ahead of time but I don't know what the data will look like. I'm also not planning to attempt incremental view maintenance yet so all the views will be recomputed from scratch on every update. This means that I have to consider index creation as part of the cost of each query, rather than a one-off upfront cost.

[Traditional query optimizers](https://en.wikipedia.org/wiki/IBM_System_R) are out of the window then. Instead I'm planning to rely on good data layout, cache-friendly algorithms and some new (and some old but forgotten) breakthroughs on the theory side.

For performance work it's really important to set a goal so that you know when to stop. The closest good comparison I can think of is [SQLite](https://www.sqlite.org/). It's still a database rather than a language and is optimised for [OLTP](https://en.wikipedia.org/wiki/Online_transaction_processing)-style workloads, but it is often used as the main data-structure for complex apps (eg [Fossil](http://fossil-scm.org/index.html/doc/trunk/www/index.wiki)) and can run in-memory. It's a totally rigged competition because Imp-style workloads will break a lot of the assumptions that SQLite is built on, but it gives me something to aim for.

### Joins

Let's start with a really simple problem - joining two tables of 1E6 random 64bit integers each drawn from U(1,1E6). I will count both the time to solve the join and the time taken to build the indexes. I'm just trying to get a rough sense of how expensive various operations are and there is an ocean betwen me and [Zed Shaw](http://zedshaw.com/archive/programmers-need-to-learn-statistics-or-i-will-kill-them-all/) so it's probably safe to just give mean times.

SQLite gives the baseline:

``` sql
SELECT count(A.id) FROM A INNER JOIN B WHERE A.id=B.id;
/* ~1150ms to index A + ~750ms to join */
```

Let's try replicating this in Rust. Sadly [std::collection::BTreeMap](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html) does terribly on this problem regardless of what node size I pick, probably because of the linear search. [std::collection::HashMap](https://doc.rust-lang.org/std/collections/struct.HashMap.html) does a better job, even though it's using a [stronger and slower hash](https://doc.rust-lang.org/std/hash/struct.SipHasher.html) than most databases would bother with.

``` rust
let mut results = Vec::with_capacity(max_size);
let mut index = HashSet::with_capacity(max_size);
for id in ids_a.iter() {
    index.insert(*id);
}
for id in ids_b.iter() {
    if index.contains(id) {
        results.push(*id);
    }
}
black_box(results);
// 107ms to index A + 100ms to join
```

Why is this so much faster than SQLite? OLTP databases tend to have a [ton of overhead](http://nms.csail.mit.edu/~stavros/pubs/OLTP_sigmod08.pdf), most of which is used to support features Imp won't need. For example, even though I am running SQLite in-memory it still has to go through the same interface as is used for on-disk tables. Another reason is that SQLite is designed under the assumption that queries will be small and much more common than index building, so it is optimised for fast lookups rather than bulk joins. Yet another reason why this competition is rigged.

Let's try something even simpler - just sort both tables and then iterate through them in parallel.

``` rust
pub fn intersect_sorted(ids_a: &Vec<Id>, ids_b: &Vec<Id>) -> Vec<Id> {
    let mut results = Vec::with_capacity(max(ids_a.len(), ids_b.len()));
    let mut ix_a = 0;
    let mut ix_b = 0;
    loop {
        match (ids_a.get(ix_a), ids_b.get(ix_b)) {
            (Some(&a), Some(&b)) => {
                match a.cmp(&b) {
                    Ordering::Less => {
                        ix_a += 1;
                    }
                    Ordering::Equal => {
                        let mut end_ix_a = ix_a;
                        while ids_a.get(end_ix_a) == Some(&a) { end_ix_a += 1; }
                        let mut end_ix_b = ix_b;
                        while ids_b.get(end_ix_b) == Some(&b) { end_ix_b += 1; }
                        for ix in (ix_a..end_ix_a) {
                            for _ in (ix_b..end_ix_b) {
                                results.push(ids_a[ix]);
                            }
                        }
                        ix_a = end_ix_a;
                        ix_b = end_ix_b;
                    }
                    Ordering::Greater => {
                        ix_b += 1;
                    }
                }
            }
            _ => break,
        }
    }
    results
}
```

``` rust
// the clone unfairly penalises this test, since in a real use I could just sort in place
let mut sorted_a = ids_a.clone();
let mut sorted_b = ids_b.clone();
sorted_a.sort();
sorted_b.sort();
let results = intersect_sorted(&sorted_a, &sorted_b);
black_box(results);
// 162ms to sort A and B + 20ms to join
```

If I vary the size of the tables the hashing wins on small tables and sorting wins on large tables. That's because my naive use of the HashMap is jumping all over memory for each lookup and on large tables that starts to cause expensive cache misses. There is a [ton](http://dl.acm.org/citation.cfm?id=2732227) [of](http://dl.acm.org/citation.cfm?id=2619232) [research](https://github.com/frankmcsherry/blog/blob/master/posts/2015-08-15.md) on the tradeoffs between sorting and hashing and much more sophisticated implementions exist for each.

For my purposes, the main concern is ease of implementation. I can't use [std::slice::sort](https://doc.rust-lang.org/std/primitive.slice.html#method.sort) because my tables won't be simple Vecs and I can't use [std::collection::HashMap](https://doc.rust-lang.org/std/collections/struct.HashMap.html) because it requires the size of keys to be known at compile time. I'm going to have to roll my own. [Radix sort](https://en.wikipedia.org/wiki/Radix_sort) to the rescue!

``` rust
pub fn radix_sort(ids: &mut Vec<Id>) {
    let ids: &mut Vec<[u8; 8]> = unsafe{ ::std::mem::transmute(ids) };
    let mut buffer = ids.clone();
    let mut counts = [[0; 256]; 8];
    for id in ids.iter() {
        for offset in (0..8) {
            counts[offset][id[offset] as usize] += 1
        }
    }
    let mut buckets = [[0; 256]; 8];
    for offset in (0..8) {
        for ix in (1..256) {
            buckets[offset][ix] = buckets[offset][ix-1] + counts[offset][ix-1];
        }
    }
    for offset in (0..8) {
        for id in ids.iter() {
            let byte = id[offset] as usize;
            buffer[buckets[offset][byte]] = *id;
            buckets[offset][byte] += 1;
        }
        ::std::mem::swap(&mut buffer, ids);
    }
}
```

``` rust
// the clone unfairly penalises this test, since in a real use I could just sort in place
let mut sorted_a = ids_a.clone();
let mut sorted_b = ids_b.clone();
radix_sort(&mut sorted_a);
radix_sort(&mut sorted_b);
let results = intersect_sorted(&sorted_a, &sorted_b);
black_box(results);
// 60ms to sort A and B + 19ms to join
```

Easy to implement and fast too, even with all the bounds checks that I didn't bother taking out. I can handle types with variable lengths (like strings) by sorting their hashes instead - again showing the duality between sorting and hashing.

How much faster could I get? Let's break this down into really simple problems:

``` rust
// sequential read pass - 0.4ms
let mut sum = 0;
for ix in (0..ids.len()) {
    unsafe{ sum += *ids.get_unchecked(ix); }
}
black_box(sum);

// sequential write pass - 1.2ms
for ix in (0..ids.len()) {
    unsafe{ *buffer.get_unchecked_mut(ix) = *ids.get_unchecked(ix); }
}
black_box(&buffer);

// random write pass - 6.8ms
for ix in (0..ids.len()) {
    let id = unsafe{ *ids.get_unchecked(ix) };
    unsafe{ *buffer.get_unchecked_mut(id as usize) = id; }
}
black_box(&buffer);
```

I'm talking nanobenchmarks now and any claim to science has long gone out the window, but this is still a useful sanity check. Radix sort does 1 read pass and 8 write passes and comes to 30ms per table. Even if I removed all the logic, turned off the bounds checks and made the writes totally predictable, it would still cost us (1 * 0.4) + (8 * 1.2) = 10ms just to touch all the memory using these primitives. That means I don't have much to gain from micro-optimising this code - I would have to change the algorithm to do significantly better.

Radix join has some other nice properties. It only makes one memory allocation (for the buffer). The sort time and join time both scale nearly linearly in tests from 1<<10 elements to 1<<29 elements. The time is incredibly consistent across different data-sets (the only outlier I've found being perfect ranges like (0..1<<29) which I suspect may be causing cache collisions because the write addresses are always large powers of two apart). It fits the bill for a simple, predicable runtime.

### Storage

I expect views to be built from scratch each time, rather than incrementally updated, and I am using sorting instead of building data-structures for indexes. That means that I can just store each table as a single chunk of memory, which is ideal in terms of memory locality and reducing pressure on the allocator.

Joining will be common and the most expensive operation is sorting and I expect tables to be highly normalised. Compression and row reconstruction both make sorting harder so a [column store](https://en.wikipedia.org/wiki/Column-oriented_DBMS) is probably a bad idea. Row store it is.

Handling variable-length data like strings is painful in most SQL databases. If it's stored inline in the table the user either has to pick a maximum length or the implementation has to give up fixed-size rows which breaks in-place sorting. Since most of the data in Imp will be from views we can also end up with many references to a given string, which would all be separate copies if they were stored inline. I'll just keep store a hash and a pointer instead and give up on memory locality for string comparisons.

I also want to be able to treat all the data as just plain bytes so that the query engine doesn't have any special cases for eg reference-counting string pointers. Luckily, I can take advantage of the semantics of Bloom to do reference counting out-of-band - I can just count the inserts and removes for input tables and stateful views at the end of each tick.

So that leaves us with these types:

``` rust
type Id = u64;
type Hash = u64;
type Number = f64;
type Text = &'static String;

#[derive(Clone, Debug)]
enum Value {
    Id(Id),
    Number(Number),
    Text(Hash, Text),
}
```

(Note the `&'static String` - this is Rust-speak for "a string will live forever". That will change later on when I start reference counting strings.)

I could store views as a `Vec<Value>` but this works out to be pretty wasteful. An enum always takes enough space to store the largest possible value - in this case a Value::Text(Hash, Text). Thats 1 byte for the enum tag, 8 for the hash and 8 for the text pointer. After alignment we end up with a brutal 24 bytes per value. I almost want to do it anyway just to keep things simple, but good memory locality is pretty much the only trick I have up my sleeve here.

Instead I'm going to enforce that each column has a fixed type and then manage my own data packing. This saves me a ton of memory and will also cut down on dynamic type checks when I add functions later on.

The underlying layer just treats every row as a sequence of bytes and has no idea where each column starts and ends or what type it is.

``` rust
#[derive(Clone, Debug)]
struct Chunk {
    data: Vec<u64>,
    row_width: usize,
}
```

Then the layer on top tracks the mapping between fields and data.

``` rust
#[derive(Copy, Clone, Debug)]
enum Kind {
    Id,
    Number,
    Text,
}

#[derive(Clone, Debug)]
struct Relation {
    fields: Vec<Id>,
    kinds: Vec<Kind>,
    chunk: Chunk,
}
```

I'm not sure yet what I want the external interface for Relation to look like, so I'll move on to the internals instead.

### Operators

We need a whole army of relational operations.

``` rust
impl Chunk {
    fn sort(&self, key: &[usize]) -> Chunk
    fn groups<'a>(&'a self) -> Groups<'a>
    fn project(&self) -> Chunk
    fn diffs<'a>(&'a self, other: &'a Chunk) -> Diffs<'a>
    fn semijoin(&self, other: &Chunk) -> (Chunk, Chunk)
    fn join(&self, other: &Chunk) -> Chunk
    fn union(&self, other: &Chunk) -> Chunk
    fn difference(&self, other: &Chunk) -> Chunk
}
```

All of them are going to rely on their inputs being sorted in the correct order. Rather than passing in a key for each operation I'm instead storing the sort key in the chunk and using that for any subsequent operations, so you would write eg `a.sort(&[0, 1]).join(b.sort(&[3, 2]))` for the query `where a.0=b.3 and a.1=b.2`.

There are two iterators: `groups` yields slices of consecutive rows which are equal on the sort key and `diffs` runs through two sorted chunks and matches up groups which are equal on the corresponding sort keys.

``` rust
#[derive(Clone, Debug)]
pub struct Groups<'a> {
    pub chunk: &'a Chunk,
    pub ix: usize,
}

impl<'a> Iterator for Groups<'a> {
    type Item = &'a [u64];

    fn next(&mut self) -> Option<&'a [u64]> {
        let data = &self.chunk.data;
        let row_width = self.chunk.row_width;
        let key = &self.chunk.sort_key[..];
        if self.ix >= data.len() {
            None
        } else {
            let start = self.ix;
            let mut end = start;
            loop {
                end += row_width;
                if end >= data.len()
                || compare_by_key(&data[start..start+row_width], key, &data[end..end+row_width], key) != Ordering::Equal {
                    break;
                }
            }
            self.ix = end;
            Some(&data[start..end])
        }
    }
}

#[derive(Clone, Debug)]
pub struct Diffs<'a> {
    pub left_key: &'a [usize],
    pub left_groups: Groups<'a>,
    pub left_group: Option<&'a [u64]>,
    pub right_key: &'a [usize],
    pub right_groups: Groups<'a>,
    pub right_group: Option<&'a [u64]>,
}

impl<'a> Iterator for Diffs<'a> {
    type Item = Diff<'a>;

    fn next(&mut self) -> Option<Diff<'a>> {
        match (self.left_group, self.right_group) {
            (Some(left_words), Some(right_words)) => {
                match compare_by_key(left_words, self.left_key, right_words, self.right_key) {
                    Ordering::Less => {
                        let result = Some(Diff::Left(left_words));
                        self.left_group = self.left_groups.next();
                        result
                    }
                    Ordering::Equal => {
                        let result = Some(Diff::Both(left_words, right_words));
                        self.left_group = self.left_groups.next();
                        self.right_group = self.right_groups.next();
                        result
                    }
                    Ordering::Greater => {
                        let result = Some(Diff::Right(right_words));
                        self.right_group = self.right_groups.next();
                        result
                    }
                }
            }
            _ => None,
        }
    }
}
```

All of the relational operators are then pretty straightforward eg:

``` rust
fn join(&self, other: &Chunk) -> Chunk {
    let mut data = vec![];
    for diff in self.diffs(other) {
        match diff {
            Diff::Both(self_words, other_words) => {
                for self_row in self_words.chunks(self.row_width) {
                    for other_row in other_words.chunks(other.row_width) {
                        data.extend(self_row);
                        data.extend(other_row);
                    }
                }
            }
            _ => ()
        }
    }
    let row_width = self.row_width + other.row_width;
    let mut sort_key = self.sort_key.clone();
    for word_ix in other.sort_key.iter() {
        sort_key.push(self.row_width + word_ix);
    }
    Chunk{data: data, row_width: row_width, sort_key: sort_key}
}
```

We can compare the performance to our previous tests to see how much overhead has been added:

``` rust
let mut chunk_a = Chunk{ data: ids_a.clone(), row_width: 1, sort_key: vec![] };
let mut chunk_b = Chunk{ data: ids_b.clone(), row_width: 1, sort_key: vec![] };
chunk_a = chunk_a.sort(&[0]);
chunk_b = chunk_b.sort(&[0]);
black_box(chunk_a.join(&chunk_b));
// 84ms to sort A and B + 46ms to join
```

The sort time has gone up by 30%, which is bearable, but the join time has more than doubled. I originally wrote the join directly before pulling out the nice iterators, so I know that those didn't affect the performance. I've tried cutting parts out, removing abstractions, disabling bounds checks etc with no significant effect. As best as I can tell, the culprit is:

``` rust
pub fn compare_by_key(left_words: &[u64], left_key: &[usize], right_words: &[u64], right_key: &[usize]) -> Ordering {
    for ix in 0..min(left_key.len(), right_key.len()) {
        match left_words[left_key[ix]].cmp(&right_words[right_key[ix]]) {
            Ordering::Less => return Ordering::Less,
            Ordering::Equal => (),
            Ordering::Greater => return Ordering::Greater,
        }
    }
    return Ordering::Equal;
}
```

Where we used to have a single comparison, we now have a bunch of array reads and branches bloating up the inner join loop, even though in this particular benchmark the actual effect is exactly the same. This is a good example of why code generation is such a big deal in database research at the moment - you can get huge improvements from specialising functions like this to the exact data layout and parameters being used. I would love to have something like [Terra](http://terralang.org/) or [LMS](http://scala-lms.github.io/) with the same level of polish and community support as Rust.

### Plans

The compiler is going to output query plans, which in Imp are just a list of actions to run.

``` rust
#[derive(Clone, Debug)]
pub enum Action {
    Sort(usize, Vec<usize>),
    Project(usize),
    SemiJoin(usize, usize),
    Join(usize, usize),
    Debug(usize),
}

#[derive(Clone, Debug)]
pub struct Plan {
    pub actions: Vec<Action>,
    pub result: usize,
}
```

The query engine just directly interprets these plans.

``` rust
impl Plan {
    pub fn execute(&self, mut chunks: Vec<Chunk>) -> Chunk {
        for action in self.actions.iter() {
            match action {
                &Action::Sort(ix, ref key) => {
                    let chunk = chunks[ix].sort(&key[..]);
                    chunks[ix] = chunk;
                },
                &Action::Project(ix) => {
                    let chunk = chunks[ix].project();
                    chunks[ix] = chunk;
                }
                &Action::SemiJoin(left_ix, right_ix) => {
                    let (left_chunk, right_chunk) = chunks[left_ix].semijoin(&chunks[right_ix]);
                    chunks[left_ix] = left_chunk;
                    chunks[right_ix] = right_chunk;
                },
                &Action::Join(left_ix, right_ix) => {
                    let chunk = chunks[left_ix].join(&chunks[right_ix]);
                    chunks[left_ix] = Chunk::empty();
                    chunks[right_ix] = chunk;
                }
                &Action::Debug(ix) => {
                    println!("{:?}", chunks[ix]);
                }
            }
        }
        ::std::mem::replace(&mut chunks[self.result], Chunk::empty())
    }
}
```

I wrote some quick and hacky csv import code so I can play with the [Chinook dataset](http://chinookdatabase.codeplex.com/).

```
sqlite> SELECT count(*) FROM Artist;
275
sqlite> SELECT count(*) FROM Album;
347
sqlite> SELECT count(*) FROM Track;
3503
sqlite> SELECT count(*) FROM PlaylistTrack;
8715
sqlite> SELECT count(*) FROM Playlist;
18
```

Let's level the playing field somewhat and use a nice OLTP-style query - finding all the artists on the "Heavy Metal Classic" playlist. The Chinook db comes with prebuilt indexes and this query only touches a small subset of the data - exactly the use case sqlite is intended for.

``` python
In [9]: def test():
    for _ in range(0,10000):
        cur.execute('SELECT DISTINCT Artist.Name FROM Playlist JOIN PlaylistTrack ON Playlist.PlaylistId=PlaylistTrack.PlaylistId JOIN Track ON PlaylistTrack.TrackId=Track.TrackId JOIN Album ON Track.AlbumId=Album.AlbumId JOIN Artist ON Album.ArtistId = Artist.ArtistId WHERE Playlist.Name="Heavy Metal Classic"')
        cur.fetchall()
   ...:

In [10]: time test()
CPU times: user 12.6 s, sys: 48.1 ms, total: 12.7 s
Wall time: 12.7 s

In [11]: time test()
CPU times: user 12.7 s, sys: 48 ms, total: 12.7 s
Wall time: 12.7 s

```

So thats 1.27 ms per query for sqlite. I hand-compiled the same query into an Imp plan:

``` rust
let plan = Plan{
    actions: vec![
    // semijoin Query and Playlist on Name
    Sort(5, vec![0]),
    Sort(4, vec![1]),
    SemiJoin(5,4),

    // semijoin Playlist and PlaylistTrack on PlaylistId
    Sort(4, vec![0]),
    Sort(3, vec![0]),
    SemiJoin(4,3),

    // semijoin PlaylistTrack and Track on TrackId
    Sort(3, vec![1]),
    Sort(2, vec![0]),
    SemiJoin(3,2),

    // semijoin Track and Album on AlbumId
    Sort(2, vec![3]),
    Sort(1, vec![0]),
    SemiJoin(2,1),

    // join Artist and Album on ArtistId
    Sort(0, vec![0]),
    Sort(1, vec![3]),
    Join(0, 1),
    // project Artist.Name and AlbumId
    Sort(1, vec![1, 2, 3]),
    Project(1),

    // join Artist*Album and Track on AlbumId
    Sort(1, vec![2]),
    Sort(2, vec![3]),
    Join(1, 2),
    // project Artist.Name and TrackId
    Sort(2, vec![0,1,3]),
    Project(2),

    // join Artist*Album*Track and PlaylistTrack on TrackId
    Sort(2, vec![2]),
    Sort(3, vec![1]),
    Join(2, 3),
    // project Artist.Name and PlaylistId
    Sort(3, vec![0,1,3]),
    Project(3),

    // join Artist*Album*Track*PlaylistTrack and Playlist on PlaylistId
    Sort(3, vec![2]),
    Sort(4, vec![0]),
    Join(3, 4),
    // project Artist.Name and Name
    Sort(4, vec![0,1,4]),
    Project(4),

    // join Artist*Album*Track*PlaylistTrack*Playlist and Query on Name
    Sort(4, vec![2]),
    Sort(5, vec![0]),
    Join(4, 5),
    // project Artist.Name (without hash)
    Sort(5, vec![1]),
    Project(5),
    ],

    result: 5
};
```

I'll go into more detail on where this plan came from when we get to the compiler section, but an important note is that the planning algorithm doesn't use any information about the actual data, just the query and the schema.

```
test query::tests::bench_chinook_metal     ... bench:   1,976,232 ns/iter (+/- 43,442)
```

So close! And without any indexes or statistics. The urge to optimise is huge, but I'm going to focus and get the compiler working first.

### Planning

[OLTP](https://en.wikipedia.org/wiki/Online_transaction_processing) databases are built for small, frequent changes to data and join-heavy queries which touch a small part of the dataset. They typically rely on indexes and use infrequently gathered statistics about the data to estimate how fast various query plans will run. When these statistics are incorrect, old or just [misused]() the query planner can make disastrously bad decisions.

[OLAP](https://en.wikipedia.org/wiki/Online_analytical_processing) databases are built for infrequently changing data and aggregation-heavy queries which touch a large part of the dataset. They typically rely on compact data layout and compression rather than indexes. They also on gathered statistics but, in my experience, are less sensitive to mistakes because most queries already involve table scans and aggregation is less susceptible than joining to blowing up and producing huge intermediate results.

Imp doesn't fit nicely into either of these categories. Inputs and views may change entirely on each execution. Queries might be join-heavy or aggregation-heavy and might touch any amount of data. On the other hand, a typical OLTP application might issue the same query hundreds of times with different parameters (eg get the friend count for user X) where an Imp program would build a single view over all the parameters (eg get the friend count for all active users). I also want to have predictable and stable performance so I can build interactive programs without suffering mysterious and unpredictable pauses, so I would prefer to have a planner that always produces mediocre plans over one that mostly produces amazing plans but occasionally explodes.

I've started with Yannakakis' algorithm, which provides tight guarantees for a large class of joins and does not require indexes or statistics. Unfortunately the original paper doesn't seem to be openly available, but the lecture notes [here](http://infolab.stanford.edu/~ullman/cs345notes/slides01-3.pdf) and [here](http://infolab.stanford.edu/~ullman/cs345notes/slides01-5.pdf) give a good overview and I'll try to explain it informally here too.

Let's start with a simple query:

``` sql
-- Find all companies with employees who are banned
SELECT * FROM
Companies
JOIN Users WHERE User.Employer = Company.Id
JOIN Logins WHERE Logins.UserId = Users.Id
JOIN Bans WHERE Bans.IP = Logins.IP
```

There are no filters or constants and we are selecting everything. We don't have indexes so we have to read all of the inputs to the query. We also have to produce all the outputs, obviously. So that gives us a lower bound on the runtime of O(IN + OUT).

Suppose we just walked through the input tables one by one and joined them together. What could go wrong? Imagine we have 1,000,000 companies and they each have one 10,000 employees, so joining Companies with Users would produce 10,000,000,000 rows. We then have to join each of those rows with, say, 100 logins per user. But we might not have banned anyone at all, so the final result is empty and we have done a ton of unnecessary work.

The core problem here is that if we naively join tables together we may end up with intermediate results that are much larger than the final result. How much extra work this causes depends on what order the tables are joined in and how the data is distributed, both of which are hard to predict when writing the query. Traditional query planners try to estimate the size of intermediate results based on the statistics they gather about the currrent dataset.

Yannakakis algorithm is much simpler. It works like this:

1. If there is only one table, you are finished!
2. Otherwise, pick an __ear__ table and it's __parent__ table where all the joined columns in the ear are joined on the parent
3. [Semijoin](https://en.wikipedia.org/wiki/Relational_algebra#Semijoin_.28.E2.8B.89.29.28.E2.8B.8A.29) the ear with it's parent ie remove all the rows in each table that do not join with any row in the other table
4. Recursively solve the rest of the query without the ear table
5. Join the results with the ear table

The crucial part is step 2 which removes any rows that do not contribute to the output (the proof of this is in the notes linked earlier). This guarantees that results at step 3 contain at most IN + OUT rows. Each recursion step removes one table, so the whole algorithm runs O(IN + OUT) time which is the best we can do in this situation. It's also simple to implement and easy to predict.

Our example query is a little too simplistic though. Most realistic queries only want a few columns:

``` sql
-- Find all companies with employees who are banned
SELECT DISTINCT(Companies.Id) FROM
Companies
JOIN Users WHERE User.Employer = Company.Id
JOIN Logins WHERE Logins.UserId = Users.Id
JOIN Bans WHERE Bans.IP = Logins.IP
```

Let's modify the algorithm to handle this:

1. If there is only one table, remove all unwanted columns (ie those that are not needed for the output or for later joins)
2. Otherwise, pick an __ear__ table and it's __parent__ table where all the joined columns in the ear are joined on the parent
3. [Semijoin](https://en.wikipedia.org/wiki/Relational_algebra#Semijoin_.28.E2.8B.89.29.28.E2.8B.8A.29) the ear with it's parent ie remove all the rows in each table that do not join with any row in the other table
4. Recursively solve the rest of the query without the ear table
5. Join the results with the ear table and remove all unwanted columns (ie those that are not needed for the output or for later joins)

This messes with our runtime guarantees. Even if we only return one company for the above query they might have 1000 banned employees. To predict the runtime cost we now have to think about how many redundant results we get in the output. It still works out pretty well though.

There is a much worse problem - step 2 might fail. We can't always find an ear table. An example of a query with no ears is:

``` sql
-- Count triangles in graph
SELECT COUNT(*) FROM
Edges AS A
JOIN Edges AS B WHERE A.To = B.From
JOIN Edges AS C WHERE B.To = C.From AND C.To = A.From
```

A is joined on both A.From and A.To, but B only covers A.To and C only covers A.From so A is not an ear. Similarly for B and C.

When working with cylic queries like this it's really hard to prevent large intermediate results. For example, it is possible to [construct a dataset](http://arxiv.org/abs/1310.3314) for the above query where joining any two tables produces O(n^2) results but the whole query only produces O(n) results. Traditional query optimisers can't handle this well and only in the last few years has there been any progress on general purpose algorithms for cyclic queries. I'm hoping to bring in some of that work later but for now I'll just ban cyclic queries entirely.

The code that implements the query planner in Imp is mostly plumbing. There is a data-structure that tracks the current state of the plan:

``` rust
#[derive(Clone, Debug)]
pub struct State {
    pub actions: Vec<runtime::Action>,
    pub chunks: Vec<Chunk>,
    pub to_join: Vec<usize>,
    pub to_select: Vec<VariableId>,
}

#[derive(Clone, Debug)]
pub struct Chunk {
    pub kinds: Vec<Kind>,
    pub bindings: Vec<Option<VariableId>>,
}
```

A few helper functions:

``` rust
impl Chunk {
    fn vars(&self) -> HashSet<VariableId>
    fn project_key(&self, vars: &Vec<VariableId>) -> (Vec<usize>, Vec<Kind>, Vec<Option<VariableId>>)
    fn sort_key(&self, vars: &Vec<VariableId>) -> Vec<usize>
}

impl State {
    pub fn project(&mut self, chunk_ix: usize, sort_vars: &Vec<VariableId>, select_vars: &Vec<VariableId>)
    pub fn semijoin(&mut self, left_chunk_ix: usize, right_chunk_ix: usize, vars: &Vec<VariableId>)
    pub fn join(&mut self, left_chunk_ix: usize, right_chunk_ix: usize, vars: &Vec<VariableId>)
```

And finally the core planner:

``` rust
impl State {
    pub fn find_ear(&self) -> (usize, usize) {
        for &chunk_ix in self.to_join.iter() {
            let chunk = &self.chunks[chunk_ix];
            let vars = chunk.vars();
            let mut joined_vars = HashSet::new();
            for &other_chunk_ix in self.to_join.iter() {
                if chunk_ix != other_chunk_ix {
                    let other_vars = self.chunks[other_chunk_ix].vars();
                    joined_vars.extend(vars.intersection(&other_vars).cloned());
                }
            }
            for &other_chunk_ix in self.to_join.iter() {
                if chunk_ix != other_chunk_ix {
                    let other_vars = self.chunks[other_chunk_ix].vars();
                    if joined_vars.is_subset(&other_vars) {
                        return (chunk_ix, other_chunk_ix);
                    }
                }
            }
        }
        panic!("Cant find an ear in:\n {:#?}", self);
    }

    pub fn compile(&mut self) -> usize {
        let to_select = self.to_select.clone();
        if self.to_join.len() == 2 {
            let left_ix = self.to_join[0];
            let right_ix = self.to_join[1];
            let left_vars = self.chunks[left_ix].vars();
            let right_vars = self.chunks[right_ix].vars();
            let join_vars = left_vars.intersection(&right_vars).cloned().collect();
            self.project(left_ix, &join_vars, &to_select);
            self.project(right_ix, &join_vars, &to_select);
            self.join(left_ix, right_ix, &join_vars);
            self.project(right_ix, &vec![], &to_select);
            right_ix
        } else {
            let (ear_ix, parent_ix) = self.find_ear();
            let ear_vars = self.chunks[ear_ix].vars();
            let parent_vars = self.chunks[parent_ix].vars();
            let join_vars = ear_vars.intersection(&parent_vars).cloned().collect();
            self.project(ear_ix, &join_vars, &to_select);
            self.project(parent_ix, &join_vars, &parent_vars.iter().cloned().collect());
            self.semijoin(ear_ix, parent_ix, &join_vars);
            self.to_join.retain(|&ix| ix != ear_ix);
            self.to_select = ordered_union(&join_vars, &to_select);
            let result_ix = self.compile();
            self.join(ear_ix, result_ix, &join_vars);
            self.project(result_ix, &vec![], &to_select);
            result_ix
        }
    }
}
```

Note the panic on not finding an ear. Also, note the base case in the planner is for two tables, saving an unnecessary semijoin.

Finally, the whole process is kicked off from:

``` rust
impl Query {
    pub fn compile(&self, program: &Program) -> runtime::Query {
        let upstream = self.clauses.iter().map(|clause| {
            let ix = program.ids.iter().position(|id| *id == clause.view).unwrap();
            program.schedule[ix]
        }).collect();
        let mut state = State{
            actions: vec![],
            chunks: self.clauses.iter().map(|clause| {
                let ix = program.ids.iter().position(|id| *id == clause.view).unwrap();
                Chunk{
                    kinds: program.schemas[ix].clone(),
                    bindings: clause.bindings.clone(),
                }
            }).collect(),
            to_join: (0..self.clauses.len()).collect(),
            to_select: self.select.clone(),
        };
        let result = state.compile();
        runtime::Query{upstream: upstream, actions: state.actions, result: result}
    }
}
```

I've already written the dataflow compiler and a crude parser, so let's look at those quickly before seeing some benchmark numbers.

### Flow

The main job of the rest of the Imp runtime is to keep all the views up to date as the inputs change. The state of the runtime is tracked in:

``` rust
#[derive(Clone, Debug)]
pub struct Program {
    pub ids: Vec<ViewId>,
    // TODO store field ids too
    pub schemas: Vec<Vec<Kind>>,
    pub states: Vec<Rc<Chunk>>,
    pub views: Vec<View>,
    pub downstreams: Vec<Vec<usize>>,
    pub dirty: Vec<bool>, // should be BitSet but that has been removed from std :(

    pub strings: Vec<String>, // to be replaced by gc
}

#[derive(Clone, Debug)]
pub enum View {
    Input,
    Query(Query),
}

#[derive(Clone, Debug)]
pub struct Query {
    pub upstream: Vec<usize>,
    pub actions: Vec<Action>,
    pub result: usize,
}
```

The views are all stored in some order decided by the compiler. The upstream and downstream fields track the positions of dependencies between the views. Whenever we change an input we have to dirty all the downstream views.

``` rust
impl Program {
    pub fn set_state(&mut self, id: ViewId, state: Chunk) {
        let &mut Program{ref ids, ref mut states, ref views, ref downstreams, ref mut dirty, ..} = self;
        let ix = ids.iter().position(|&other_id| other_id == id).unwrap();
        match views[ix] {
            View::Input => {
                states[ix] = Rc::new(state);
                for &downstream_ix in downstreams[ix].iter() {
                    dirty[downstream_ix] = true;
                }
            }
            View::Query(_) => {
                panic!("Can't set view {:?} - it's a query!", id);
            }
        }
    }
}
```

Then to run the program we just keep updating views until nothing is dirty.

``` rust
impl Program {
    pub fn run(&mut self) {
        let &mut Program{ref mut states, ref views, ref downstreams, ref mut dirty, ref strings, ..} = self;
        while let Some(ix) = dirty.iter().position(|&is_dirty| is_dirty) {
            match views[ix] {
                View::Input => panic!("How did an input get dirtied?"),
                View::Query(ref query) => {
                    dirty[ix] = false;
                    let new_chunk = query.run(strings, &states[..]);
                    if *states[ix] != new_chunk {
                        states[ix] = Rc::new(new_chunk);
                        for &downstream_ix in downstreams[ix].iter() {
                            dirty[downstream_ix] = true;
                        }
                    }
                }
            }
        }
    }
}
```

If there are cycles in the graph of views then the order in which they are run could potentially affect the result. I'll cover that problem in more detail when I get to implementing [stratification](https://en.wikipedia.org/wiki/Stratification_%28mathematics%29).

### Syntax

My parser is a thing of shame so let's just talk about the syntax itself. I'm aiming for the madlib style that was used in [earlier Eve demos](http://incidentalcomplexity.com/images/5.png). I like this style because the table names become self-documenting and because it (mildly) encourages normalization and writing [facts rather than state](https://github.com/matthiasn/talk-transcripts/blob/master/Hickey_Rich/ValueOfValues.md).

Here is a snippet of Imp:

```
artist ?a:id is named ?an:text
= data/Artist.csv 0 1

?an:text is on a metal playlist
+
playlist ?p is named "Heavy Metal Classic"
track ?t is on playlist ?p
track ?t is on album ?al
album ?al is by artist ?a
artist ?a is named ?an
```

There are two views here. The first defines an input view called `artist _ is named _` and loads data from Artist.csv, parsing ids from column 0 and text from 1. The second defines are query view called `_ is on a metal playlist`. The body of the query joins pulls data from five other views, joining them wherever the same variable is used in more than one place.

I'm deliberately using short variables to keep the focus on the rest of the sentence and make it easier to quickly scan for joins.

The reason that queries are indicated by a `+` is that I want to introduce non-monotonic reasoning later on so I can write queries like:

```
?an:id can fly
+
?an is a bird
-
?an is a penguin
+
?an is Harry the Rocket Penguin
```

This reads as "birds can fly, but penguins can't, but Harry the Rocket Penguin can". This sort of reasoning is clumsy in traditional datalog and it often comes up when setting defaults or when updating values (all the values, minus the one I'm changing, plus it's new value).

Functions can be treated as infinite relations:

```
?a + ?b = ?c
```

There are some simple static checks we can use to ensure that the resulting query doesn't produce infinite results. More on that when I actually implement functions.

I haven't decided how I want to handle aggregation yet, so there is no syntax for it.

### First steps

I'm excited to show Imp's first whole program:

```
playlist ?p:id is named ?pn:text
= data/Playlist.csv 0 1

track ?t:id is on playlist ?p:id
= data/PlaylistTrack.csv 1 0

track ?t:id is on album ?al:id
= data/Track.csv 0 2

album ?al:id is by artist ?a:id
= data/Album.csv 0 2

artist ?a:id is named ?an:text
= data/Artist.csv 0 1

?pn:text is the name of a metal playlist
= data/Metal.csv 0

?an:text is on a metal playlist
+
?pn is the name of a metal playlist
playlist ?p is named ?pn
track ?t is on playlist ?p
track ?t is on album ?al
album ?al is by artist ?a
artist ?a is named ?an
```

This is the same example query I've been using all along but now it's running through the whole compiler. I haven't implemented constants yet so I'm loading the playlist name from Metal.csv instead.

So how does it stack up against sqlite?

```
let bootstrap_program = Program::load(&["data/chinook.imp", "data/metal.imp"]);
let runtime_program = bootstrap_program.compile();
bencher.iter(|| {
    let mut runtime_program = runtime_program.clone();
    runtime_program.run();
    black_box(&runtime_program.states[6]);
});
// test bootstrap::tests::bench_metal_run       ... bench:     864,801 ns/iter (+/- 45,810)
```

A beautiful 0.86 ms vs SQLites 1.2ms. I'm gaining some advantage from normalizing the database and I got lucky with the clause ordering and it's not much of a benchmark to begin with, but I'm still feeling pretty good :)

What was that about the clause ordering? The planner picks the first ear it can find and it searches the clauses in the order they are given in the program. If we reverse the ordering we get a plan that takes 1.7ms, because it runs the filtering phase from artist to playlist instead of the other direction, resulting in absolutely no filtering. No matter what order is chosen, every plan has to sort all of the inputs once and then all of the intermediate results once. The size of the intermediate results are still bounded, so we can expect the difference between the best and worst plans to at most 2x.

### Filtering

I added a filtering phase at the start of each query to handle self-joins and constants, so we can now write queries like:

```
?x is friends with #42
?x has 7 friends
?x is from "England"
?x is friends with ?x
```

Whenever a self-join or a constant is spotted, the planner adds an action that calls one of:

``` rust
impl Chunk {
    pub fn selfjoin(&self, left_ix: usize, right_ix: usize) -> Chunk {
        let mut data = vec![];
        for row in self.data.chunks(self.row_width) {
            if row[left_ix] == row[right_ix] {
                data.extend(row);
            }
        }
        Chunk{ data: data, row_width: self.row_width}
    }

    pub fn filter(&self, ix: usize, value: u64) -> Chunk {
        let mut data = vec![];
        for row in self.data.chunks(self.row_width) {
            if row[ix] == value {
                data.extend(row);
            }
        }
        Chunk{ data: data, row_width: self.row_width}
    }
}
```

### Data entry

Now that the parser can handle constants, I can add tables of constants:

```
there is an edge from ?a:id to ?b:id
=
#0 #1
#1 #2
#2 #3
#3 #4
#3 #1
```

### Unions

Finally, the reason for the weird "+" syntax. Queries can be made up of multiple stages which can each add or remove results:

```
?a:text can fly
+
?a is a bird
-
?a is a penguin
+
?a is Harry the Rocket Penguin
```

This starts to enable the use of recursive views too, so we can write:

```
there is a path from ?a:id to ?b:id
+
there is an edge from ?a to ?b
+
there is an edge from ?a to ?c
there is a path from ?c to ?b
```

Most of the work was in the monstrous parser. The final runtime structure is very simple:

``` rust
#[derive(Debug, Clone)]
pub struct Union {
    pub upstream: Vec<usize>,
    pub members: Vec<Member>,
    pub key: Vec<usize>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Member {
    Insert,
    Remove,
}

impl Union {
    fn run(&self, states: &[Rc<Chunk>]) -> Chunk {
        assert_eq!(self.members[0], Member::Insert);
        let mut result = Cow::Borrowed(&*states[self.upstream[0]]);
        for ix in 1..self.upstream.len() {
            result = Cow::Owned(match self.members[ix] {
                Member::Insert => result.union(&*states[self.upstream[ix]], &self.key[..]),
                Member::Remove => result.difference(&*states[self.upstream[ix]], &self.key[..]),
            });
        }
        result.into_owned()
    }
}
```

### Interlude

I've been trying to extend Yannakakis' algorithm to handle primitives (ie infinite relations such as addition). I initially thought I could just treat them as normal relations during planning and then replace them by finite relations during the semijoin phase. The trouble is that many uses of primitives create cyclic queries, which I was hoping to punt on for a while longer eg

```
?bid is the max buy in market ?m with price ?bp and quant ?bq
?sid is the min sell in market ?m with price ?sp and quant ?sq
?bp >= ?sp
?q = min(?bq, ?sq)
```

In a query like this you really don't want to replace >= or min by finite relations until after joining the buys and sells on ?m, otherwise you end up with O(n**2) rows in the replacements. In general it looks like primitives shouldn't be applied until all their inputs have been joined together, but that means that they can't take part in the semijoin phase which breaks the guarantees of Yannakakis' algorithm.

An alternative is to ignore primitives while planning the join tree and then insert them as extra nodes afterwards. This can blow up in queries like:

```
person ?p has first name ?fn
person ?p has last name ?ln
?n = concat(?fn, ?ln)
letter ?l is addressed to ?n
```

Ignoring the concat, *a* valid join tree for Yannakakis would be "letter ?l is addressed to ?n" -> "person ?p has first name ?fn" -> "person ?p has last name ?ln". The concat can't be applied until after the last join so the first join is an expensive and unnecessary product.

Intuitively though, it seems that for every query there should be *some* sensible join tree. I'm currently trying to figure out if there is a way to bound the costs of a given tree containing primitives. Then the compiler could just generate every valid tree and choose the tree with the lowest bounds.

Today I'm rereading http://arxiv.org/pdf/1508.07532.pdf and http://arxiv.org/pdf/1508.01239.pdf, both of which calculate bounds for related problems. Hopefully something in there will inspire me. I've been stalled on this for a week or so, so I would be happy to find a crude solution for now and come back to it later.

### Primitives

I finally settled on a solution. I'm pretty sure there are cases where it will do something daft but I'll worry about those when I come to them.

We start by ignoring the primitives, building a join tree just for the views and running a full [GYO reduction](http://infolab.stanford.edu/~ullman/cs345notes/slides01-3.pdf).

``` rust
let mut join_tree = build_join_tree(&chunks);
for chunk_ix in 0..chunks.len() {
    filter(&mut chunks, &mut actions, chunk_ix);
    selfjoin(&mut chunks, &mut actions, chunk_ix);
}
for edge in join_tree.iter().rev() {
    if let &(child_ix, Some(parent_ix)) = edge {
        semijoin(&mut chunks, &mut actions, child_ix, parent_ix);
    }
}
for edge in join_tree.iter() {
    if let &(child_ix, Some(parent_ix)) = edge {
        semijoin(&mut chunks, &mut actions, parent_ix, child_ix);
    }
}
```

Then we repeatedly:

* find the smallest subtree which contains enough variables to apply some primitive
* join together all the chunks in the subtree
* apply the primitive

``` rust
while primitives.len() > 0 {
    let (primitive_ix, subtree) = cheapest_primitive_subtree(&chunks, &join_tree, &primitives);
    let root_ix = collapse_subtree(&mut chunks, &mut actions, &mut join_tree, &subtree);
    apply(&mut chunks, &mut actions, strings, root_ix, &primitives[primitive_ix]);
    primitives.remove(primitive_ix);
}
```

Finally, we join together any remaining chunks and project out the result variables.

``` rust
let remaining_tree = join_tree.clone();
let root_ix = collapse_subtree(&mut chunks, &mut actions, &mut join_tree, &remaining_tree);
sort_and_project(&mut chunks, &mut actions, root_ix, &query.select, &vec![]);
```

The reasoning here is that primitives are usually cheap to compute and may be useful in later joins, so we want to apply them as early as possible. Running the full reduction (instead of the half reduction I was using before) allows joining the chunks in any order, at the cost of some extra sorting. The end result is:

* views which don't use primitives still gain the runtime bounds from Yannakakis
* views which do use primitives have the runtime bounds that Yannakakis would have IF all the primtives were removed from the query

Note that removing primitives can potentially vastly increase the output size, which means that these bounds are much looser. For example:

```
person ?p has first name ?fn
person ?p has last name ?ln
?n = concat(?fn, ?ln)
letter ?l is addressed to ?n
```

```
person ?p has first name ?fn
person ?p has last name ?ln
letter ?l is addressed to ?n
```

Thie first query is guaranteed to take no more time than the second query, which generates every possible combination of letter and person. That's not a very tight bound.

In practice, simple examples like this end up with sensible plans, but in complex queries with multiple primitives it is possible to coerce the compiler into bad decisions. My intuition is that is should be possible to prevent this by being more careful about which order primitives are applied in - choosing the subtree with the smallest bound rather than the least number of nodes - but computing the bounds is complicated and I want to move on to other subjects.

### Notes on design

The rest of the compiler is mostly dull book-keeping but I want to call attention to the style of programming. Over the last year or two I've leaned more and more towards data-oriented design as advocated by eg [Mike Acton](http://www.slideshare.net/cellperformance/data-oriented-design-and-c). The primary reason for that is *not* performance but because I find it prevents me agonising over code organisation and because it plays well with the Rust borrow checker. An example of this is the join tree. A traditional approach would be something like:

``` rust
struct Tree {
    chunk: Chunk,
    children: Vec<Tree>,
}
```

Since everything is connected by pointers I have to think carefully about where to keep data eg if later I am walking the tree and I need a list of the bindings for the chunk, I either have to include the bindings in the Chunk struct beforehand or I have to look it up in some chunk-to-bindings hashtable. Is the chunk hashable? Am I ever going to mutate it?

In Rust I have to think about ownership too. Does the chunk-to-bindings hashtable have it's own copy of the chunk or is it sharing with the tree? The former adds unnecessary copies but the latter imposes a bunch of lifetime annotations that clog up all my code.

A much simpler approach is to store all the information separately and tie it together with a simple key. In this case, I just store the chunks in one vector, the bindings in another vector and use the position in the vector as the key.

``` rust
struct Tree {
    chunk: usize,
    children: Vec<Tree>,
}
```

But we still have a recursive, mutable type which is [painful](http://stackoverflow.com/questions/28608823/how-to-model-complex-recursive-data-structures-graphs) in Rust. Even in a normal language we have to write extra code to handle operations like inserting edges or traversing the tree. Life is easier with a simpler representation.

``` rust
// (child, parent) sorted from root downwards
type Tree = Vec<(usize, Option<usize>)>;
```

Most of the code that touches this the tree becomes delightfully simple eg:

``` rust
while unused.len() > 1 { // one chunk will be left behind as the root
    let (child_ix, parent_ix) = find_join_ear(chunks, &unused);
    unused.retain(|ix| *ix != child_ix);
    tree.push((child_ix, Some(parent_ix)));
}
tree.push((unused[0], None));
tree.rev();
```

There are incidental performance benefits - we now have a single contiguous allocation for the whole tree - but the main benefit is just simplicity. I'm leaning more and more towards just [putting things in arrays](https://youtu.be/JjDsP5n2kSM?t=752) until profiling demands otherwise.

I think it's interesting that the borrow checker directly encourages what I judge to be good design. I wonder what kind of effect that will have on the long-term quality of the Rust ecosystem.

### Aggregates

Aggregates have been a constant ergonomic nightmare in Eve. This shouldn't be surprising - they are the dumping ground for everything non-relational and non-monotonic - all the awkward bits of logic that actually intrinsically require waiting or ordering. They also interact weirdly with set semantics, because projecting out unused columns also removes duplicates in the remaining data which can change the result of an aggregate like `sum`.

So I'm surprised to find myself not entirely hating the design in Imp. There are some places in the compiler that I suspect might be buggy, but I think the semantics at least are sound. Aggregates look like this:

```
company ?c:text spends ?t:number USD
+
person ?p works at company ?c for ?d USD
?t = sum(?d) over ?p

total salary is ?t:number USD
+
person ?p works at company ?c for ?d USD
?t = sum(?d) over ?p ?c
```

Syntactically, aggregates behave exactly like primitives except that there is an optional 'over' clause that controls grouping and sorting. When `sum(?d) over ?p` is applied, it groups the current chunk by everything except ?d and ?p and then sums over ?d in each group, giving the total salary across all people at the same company. Similarly, `sum(?d) over ?p ?c` groups the current chunk by everything except ?d, ?p and ?c, giving the total salary overall.

A weakness of this scheme is it doesn't always capture intent. For example, we might want to change the second query to:

```
total salary at european companies is ?t:number USD
+
person ?p works at company ?c for ?d USD
?t = sum(?d) over ?p ?c
company ?c is based in ?country
?country is in europe
```

This now calculates the total salary per country, not for the whole of Europe. The correct query is:

```
total salary at european companies is ?t:number USD
+
person ?p works at company ?c for ?d USD
?t = sum(?d) over ?p ?c ?country
company ?c is based in ?country
?country is in europe
```

But this can still double-count if it is possible for a company to be based in multiple countries. In cases like this, it may be safer to just split it into two views:

```
person ?p:text works at european company ?c:text for ?d:number USD
+
person ?p works at company ?c for ?d USD
company ?c is based in ?country
?country is in europe

total salary at european companies is ?t:number USD
+
person ?p works at european company ?c for ?d USD
?t = sum(?d) over ?p ?c
```

The upside of specifying groups this way is that can handle sorting too. The primitive `row _` sorts each group in the order specified by 'over' and then numbers them in ascending order. This gives us min, max, limit, pagination etc.

```
?p:text is paid least at their company
+
?p works at ?c for ?d USD
row 1 over ?d ?p

?p:text is in the top ten at their company
+
?p works at ?c for ?d USD
row ?n over -?d ?p
n <= 10
```

The `-?d` in the second example specifies that `?d` should be sorted in descending order.

The implementation of aggregates took very little work since it piggybacks on primitives. The scheduler now allows primitives to specify variables on which they depend non-monotonically and will only schedule the primitive when anything that might filter down those variables has already been applied. In the last example above, if we added the clause `?p is a real employee` it would have to be joined with `?p works at ?c for ?d USD` *before* the rows were sorted and numbered.

The sorting also has to be handled specially. The radix sort used for joining just sorts values by their bitwise representation, which gives the wrong results for numbers and strings. For aggregates I added a hideously inefficient sort function that piggybacks on the stdlib sort.

``` rust
// TODO this is grossly inefficient compared to untyped sort
fn typed_sort(chunk: &Chunk, ixes: &[(usize, Kind, Direction)], strings: &Vec<String>) -> Chunk {
    let mut data = chunk.data.clone();
    for &(ix, kind, direction) in ixes.iter().rev() {
        let mut new_data = Vec::with_capacity(data.len());
        match kind {
            Kind::Id => {
                let mut buffer = vec![];
                for row in data.chunks(chunk.row_width) {
                    buffer.push((row[ix], row));
                }
                match direction {
                    Direction::Ascending => buffer.sort_by(|&(key_a, _), &(key_b, _)| key_a.cmp(&key_b)),
                    Direction::Descending => buffer.sort_by(|&(key_a, _), &(key_b, _)| key_b.cmp(&key_a)),
                }
                for (_, row) in buffer.into_iter() {
                    new_data.extend(row);
                }
            }
            Kind::Number => {
                let mut buffer = vec![];
                for row in data.chunks(chunk.row_width) {
                    buffer.push((to_number(row[ix]), row));
                }
                // TODO NaN can cause panic here
                match direction {
                    Direction::Ascending => buffer.sort_by(|&(key_a, _), &(key_b, _)| key_a.partial_cmp(&key_b).unwrap()),
                    Direction::Descending => buffer.sort_by(|&(key_a, _), &(key_b, _)| key_b.partial_cmp(&key_a).unwrap()),
                }
                for (_, row) in buffer.into_iter() {
                    new_data.extend(row);
                }
            }
            Kind::Text => {
                let mut buffer = vec![];
                for row in data.chunks(chunk.row_width) {
                    buffer.push((&strings[row[ix+1] as usize], row));
                }
                match direction {
                    Direction::Ascending => buffer.sort_by(|&(ref key_a, _), &(ref key_b, _)| key_a.cmp(key_b)),
                    Direction::Descending => buffer.sort_by(|&(ref key_a, _), &(ref key_b, _)| key_b.cmp(key_a)),
                }
                for (_, row) in buffer.into_iter() {
                    new_data.extend(row);
                }
            }
        }
        data = new_data;
    }
    Chunk{data: data, row_width: chunk.row_width}
}
```

The query language is basically feature-complete at this point. I'm missing state and stratification but I don't *need* either of those to bootstrap. The compiler has become a bit of a mess and is probably full of bugs though. I think the next thing I want to do is to get some basic editor integration working to make debugging easier and then write some actual programs. If everything works well enough, it may be worth trying to bootstrap right away instead of cleaning up the existing compiler.

### Negation

I totally forgot I needed negation. I added it only at the level of individual clauses, like standard datalog. This means I can write:

```
?p:text works at alice crop but not evil eve studios
+
?p works at "alice corp" for _ USD
! ?p works at "evil eve studios" for _ USD
```

But I can't directly write:

```
?p:text only works at alice crop
+
?p works at "alice corp" for _ USD
! {
  ?p works at ?c for _ USD
  c != "alice corp"
}
```

Most query languages don't support that anyway, so maybe it's ok?

I piggybacked negation onto primitives too. The compiler is getting gnarly. Might be time for a cleanup soon.

### Parsing

I tried to work on editor integration and ended up just [procrastinating](https://github.com/jamii/imp/blob/master/data/csa.imp) a lot. This week I changed tack and started bootstrapping instead.

The current parser is a [nasty mess](https://github.com/jamii/imp/blob/2e344bcdb4fd288c37052b8340cfad3b0dfc6878/src/bootstrap.rs#L626-L763) of regular expressions. This is partly because I care more at this stage about getting something working than making it pretty, but it's also because Imp doesn't really need or benefit from the traditional parsing formalisms.

One reason for that is that I want parsing errors to be locally contained. In most languages, deleting a single parenthesis can make the whole program unparseable. This is a disaster for live programming. In Imp, the high-level structure of the program is a [regular language](https://en.wikipedia.org/wiki/Regular_language). There are only three levels of nesting (program -> view -> member -> clause) so each one gets to use a unique delimiter. The first half of the parser just splits up the program at these delimiters, not caring about the text between them. This means that syntax errors can only break things locally eg missing a view delimiter mashes two views together but leaves all the other views intact.

The second reason is that the clauses themselves don't have a very well rigid grammar. Given the clause `most "cats" prefer ?x` the parser picks out the bindings `"cats"` and `?x` and then converts the remainder into the view name `most _ prefer _`. Handling that in a traditional grammar is mildly unpleasant.

So instead the Imp grammar is given by tree of regular expressions:

```
?parent:text contains ?child:text found by capture ?n:number of ?regex:text
=
"program" "view" 0 "(.+\n?)+"
"view" "head" 0 "^.*"
"view" "insert" 1 "\n\+((\n[^\+-=].*)+)"
"view" "remove" 1 "\n-((\n[^\+-=].*)+)"
"view" "input" 1 "\n=(.*(\n[^\+-=].*)+)"
"head" "variable with kind" 2 "(^|\s)(\?[:alnum:]*:[:alnum:]*)"
"variable with kind" "kind" 1 ":([:alnum:]*)"
"variable with kind" "variable" 1 "\?([:alnum:]*)"
"insert" "clause" 1 "\n(.*)"
"remove" "clause" 1 "\n(.*)"
"clause" "negation" 0 "^! "
"clause" "clause body" 2 "^(! )?(.*)"
"clause body" "binding" 2 "(^|\s)(_\S*|\?[:alnum:]*|#[:digit:]+|-?[:digit:]+(\.[:digit]+)?|\x22(\\\x22|[^\x22])*\x22)"
"binding" "unbound" 0 "^_\S*$"
"binding" "variable" 1 "^\?([:alnum:]*)$"
"binding" "id" 0 "^#[:digit:]+$"
"binding" "number" 0 "^-?[:digit:]+(\.[:digit]+)?$"
"binding" "text" 0 "^\x22(\\\x22|[^\x22])*\x22$"
"input" "import" 0 "^.*"
"import" "filename" 1 "^\s*(\S*)"
"import" "cols" 1 "^\s*\S*(.*)"
"cols" "col" 1 "\s*(\S*)"
"input" "row" 1 "\n(.*)"
"row" "value" 2 "(^|\s)(#[:digit:]+|-?[:digit:]+(\.[:digit]+)?|\x22(\\\x22|[^\x22])*\x22)"
"value" "id" 0 "#[:digit:]+"
"value" "number" 0 "-?[:digit:]+(\.[:digit]+)?"
"value" "text" 0 "\x22(\\\x22|[^\x22])*\x22"
```

The result of parsing is a similar tree, where each node is identified by rule creating it and by the byte indices at which it starts and ends in the program text.

```
child ?ck:text ?ca:number ?cz:number of ?pk:text ?pa:number ?pz:number has text ?c:text
+
outside says ?pk ?pa ?pz has child ?ck ?ca ?cz with text ?c
+
?pk contains ?ck found by capture ?n of ?re
child ?pk ?pa ?pz of _ _ _ has text ?p
capture ?n of result _ of ?p searched by ?re is at ?ra to ?rz
?ca = ?pa + ?ra
?cz = ?pa + ?rz
the text at ?ra to ?rz in ?p is ?c
```

I also added some basic debugging support which watches the file and prints results like:

```
View 4: "child _ _ _ of _ _ _ has text _"
[Text, Number, Number, Text, Number, Number, Text]
"value" 184 193 "row"   184 213 "\"program\""
"value" 194 200 "row"   184 213 "\"view\""
"value" 201 202 "row"   184 213 "0"
"value" 203 213 "row"   184 213 "\"(.+\\n?)+\""
"value" 214 220 "row"   214 235 "\"view\""
"value" 221 227 "row"   214 235 "\"head\""
...
```

That's the whole parser. It isn't pretty and there is some unpleasant repetition in the grammar, but every attempt I've made to reduce that repetition has resulted in something that is more complicated overall. When the whole parser consists of 28 rules and 6 lines of logic it's hard to gain anything from adding further abstraction.

The [nasty mess](https://github.com/jamii/imp/blob/2e344bcdb4fd288c37052b8340cfad3b0dfc6878/src/bootstrap.rs#L626-L763) in the Rust version expresses more or less the same logic but is much more verbose. The reason for that is that I started by writing down the types I wanted to output:

``` rust
#[derive(Clone, Debug)]
pub struct Program {
    pub ids: Vec<ViewId>,
    pub schedule: Vec<usize>,
    pub schemas: Vec<Vec<Kind>>,
    pub views: Vec<View>,
}

#[derive(Clone, Debug)]
pub enum View {
    Input(Input),
    Query(Query),
    Union(Union),
}

#[derive(Clone, Debug)]
pub struct Input {
    pub tsv: Option<(String, Vec<usize>)>,
    pub rows: Vec<Vec<Value>>,
}

#[derive(Clone, Debug)]
pub struct Query {
    pub clauses: Vec<Clause>,
    pub select: Vec<VariableId>,
}

#[derive(Clone, Debug)]
pub struct Union {
    pub members: Vec<Member>,
}

#[derive(Clone, Debug)]
pub enum Member {
    Insert(ViewId),
    Remove(ViewId),
}

#[derive(Clone, Debug)]
pub struct Clause {
    pub view: ViewId,
    pub bindings: Vec<Binding>,
    pub over_bindings: Vec<(Binding, runtime::Direction)>,
}
```

By starting with a heterogenous tree of custom types I had *already missed* the opportunity to build a simple, data-driven parser like the Imp version. What's more, I can easily add information to the Imp version in a way that would require modifying types in the Rust version:

```
head ?va:number ?vz:number is named ?n:text
+
child "head" ?va ?vz of _ _ _ has text ?v
"head" contains "variable with kind" found by capture _ of ?re
?v with ?re replaced by "$1_" is ?n

clause ?va:number ?vz:number is named ?n:text
+
child "clause body" _ _ of "clause" ?va ?vz has text ?v
"clause" contains "binding" found by capture _ of ?re
?v with ?re replaced by "$1_" is ?n

view ?n:text is primitive
=
"_ = _ + _"
"_ = sum(_)"
"row _"
"_ < _"
"_ <- _"
"_ <<- _"
"min"
"result _ of _ split by _ is at _ to _ breaking at _"
"result _ of _ searched by _ is at _ to _"
"capture _ of result _ of _ searched by _ is at _ to _"
"_ with _ replaced by _ is _"
"the text at _ to _ in _ is _"
"_ has length _"

clause ?va:number ?vz:number is primitive
+
clause ?va ?vz is named ?n
view ?n is primitive

clause ?va:number ?vz:number is negated
+
child "negation" _ _ of "clause" ?va ?vz has text _

clause ?va:number ?vz:number is finite
+
clause ?va ?vz is named _
! clause ?va ?vz is primitive
! clause ?va ?vz is negated
```

In a pointerful language like Rust or Clojure or Javascript I would have to spend time deciding where this data lives and how to access it. Any change to the organization of the pointer graph would require rewriting all the code that traverses it. In Imp I just define the data and refer to it directly. I strongly suspect that this is going to be a major improvement.

### Mid-mortem

At about 400 lines of Imp code, the bulk of the parser/compiler is finished and working. Progress has been halting - in part because I've been distracted by other work and by having to leave the country to get a new visa (going from two 30" monitors on a standing desk to a 12" laptop on a wooden chair has not been kind to my body) - but I think I'm at the point now where I've learned all I'm going to and the rest of the work is going to be just more of the same.

So far, [imp.imp](https://github.com/jamii/imp/blob/master/data/imp.imp) can correctly parse programs, compile input and union views and generate join trees for query views. The primitive scheduling for query views exists but is incomplete and the action list is missing entirely. I'm also missing the Rust code that will take the plans generated by imp.imp and assemble them into the corresponding runtime data-structures. If I plowed ahead without changing anything, I'm guessing the finished version would be ~600 lines of Imp and ~100 lines of Rust (the native compiler is ~1000 lines of Rust and ~200 lines of PEG grammar).

### Performance

The Rust version takes ~2ms to parse imp.imp and ~2ms to compile imp.imp. The Imp version takes ~60ms to parse itself and ~60ms to (incompletely) compile itself. (The current parser in the Rust version is a [rust-peg](https://github.com/kevinmehall/rust-peg) parser contributed by [wtaysom](https://github.com/wtaysom). For a fairer comparison, the old regex mess takes ~50ms.)

Oprofile and valgrind agree that a large chunk of the runtime is spent in applying primitives and sorting. Looking at the individual view timings, most of the time is spent in just a few views and those all use either recursion or regex primtives or both, which matches up with the profiling results.

Recursion is a problem on two fronts. Firstly, I haven't implemented [semi-naive evaluation](http://infolab.stanford.edu/~vassalos/cs345_98/datalog3.ps) so every iteration of a recursive view has to recalculate the entire view so far. Secondly, I don't maintain indexes between executions so every one of those iterations requires re-sorting everything. This means lots of extra sorting and lots of redundant calls to primitives.

Valgrind puts 15% of the total runtime in the primitive `capture _ of result _ of _ searched by _ is at _ to _` but this is likely a result of the ~15000 calls (!) to this primitive, rather than a sign that regexes themselves are slow to run. Compiling regexes *is* slow but I already [added a regex cache](https://github.com/jamii/imp/commit/982afa85fb75f9bcf822008f422a582ea95b7a0d), a strategy [used by many high-level languages](https://msdn.microsoft.com/en-us/library/8zbs0h2f%28v=vs.110%29.aspx). Just hitting the regex cache is responsible for 5% of the total runtime but, again, 15000 calls is the root problem here.

Valgrind puts another 8% at the feet of `_ with _ replaced by _ is _` with only ~750 calls. I'm don't know why it is so much more expensive than the regex search alone.

I expected string allocation to be an issue but it barely even registers. The way I handle strings still needs more thought, but it doesn't look to be at all urgent.

Overall, I'm pleasantly surprised by the performance. I expected it to be much slower than it is and I expected the culprits to be spread out all over the place. As it is, it looks like I can get huge improvements just from maintaining indexes intelligently and implementing semi-naive evaluation, both of which I was planning to do anyway.

### Expressiveness

Most of the code has been pretty straightfoward to write.

Being able to aggregate over arbitary subqueries has been really useful eg:

```
union node ?n:number has key ?f:number = ?v:number
+
field ?f of node ?n has variable _ and kind ?k
field ?f2 of node ?n has variable _ and kind ?k2
?f2 < ?f
values of kind ?k2 have width ?w
?v = sum(?w) over ?f2 ?k2
```

This calculates, for each field, the sum of the widths of all the earlier fields. In all versions of Eve so far, doing that would require creating another intermediate view just to track which fields are earlier than others, because aggregates can only be applied to entire views:

```
union node ?n:number field ?f:number is ahead of field ?f2:number with width ?w:number
+
field ?f of node ?n has variable _ and kind _
field ?f2 of node ?n has variable _ and kind ?k
values of kind ?k have width ?w
?f2 < ?f

union node ?n:number has key ?f:number = ?v:number
+
union node ?n field ?f is ahead of field ?f2 with width ?w
?v = sum(?w) over ?f2
```

I have a similar situation with negation. Negation can currently only be applied to a single clause so I often end up creating intermediate views instead eg:

```
clause ?c:number of node ?n:number is unjoined in step ?s:number
+
clause ?c of node ?n is finite
?s <- 0
+
node ?n reaches step ?s
clause ?c of node ?n is unjoined in step ?s2
?s = ?s2 + 1
! clause ?c of node ?n is joined to clause _ in step ?s2

# in use later
clause ?c of node ?n is unjoined in step ?s
```

Which would be more directly expressed with negation over a subquery:

```
# direct use, no intermediate view
! ?s2 [
  clause ?c of node ?n is joined to clause _ in step ?s2
  ?s2 < ?s
]
```

This is only a small improvement in this case, but elsewhere in imp.imp it would save a lot of boilerplate because the intermediate views often copy lots of context from the main view in order to ensure that they have a finite number of results. It also allows for a more efficient interpretation since an intermediate view has to be generated in full but a negation can shortcircuit as soon as it finds one result.

Another approach to this general problem would be to allow views with infinite results so long as they are only used in contexts that guarantee the end result if finite. This is leaning away from the restrictions that make datalog so much easier to evaluate than prolog and kin, so it would require very careful though. The upside would be that it would provide a mechanism for user-defined functions as well as an implementation of aggregates and negations over sub-queries.

There are also a few cases where disjunction would be useful, but it's not nearly as common as I would have expected.

Finally, I made a big fuss about the syntax I added for non-monotonic reasoning and so far I have used it exactly 0 times. It's [roughly equivalent](https://twitter.com/arntzenius/status/658735928803008512) in power to negation and in every place I could have used it so far I've found negation to be the cleaner option.

### Context

I don't really have a good name for this category yet, but it is a pattern that seems to be important.

In the Rust version, the compiler operates on one query at a time. I think of the function stack as defining a context in which the code is currently operating. Imp doesn't have a function stack, or any kind of nesting, so every view has to track it's whole context. Notice how the node ?n is not really being used in the following view, it's just there for context:

```
in node ?n:number wave ?w:number primitive ?p:number is scheduled on subtree ?t:id
+
in node ?n wave ?w primitive ?p is unscheduled
node ?n has subtree ?t with root _
! node ?n clause ?p cannot be run on subtree ?t
in node ?n wave ?w subtree ?t has ?numc clauses
min over ?numc ?t ?p
```

This is kind of a refactoring problem. In a normal language I can write code as if there is only one node in the world and then reuse that function across multiple nodes. It would be useful to be able to do the same in Imp - write a set of views as if there was only one node and then select them all and declare a node context to be threaded throughout.

I think there are some problems with the way that context works in most languages that I would like to avoid. In particular, the tools given to you are primarily hierachical data-structures (pointers, structs, hashtables etc are all one-way mappings) and the hierachichal function call-graph. But context doesn't necessarily decompose nicely into a tree-like structure. It's common that different contexts overlap but don't contain each other, and one symptom of this is when you find that state sharing doesn't respect your tree-like breakdown eg functions that act on a single node have to access type information that comes from multiple nodes.

In my mind, context looks like [plate notation](https://www.google.co.uk/search?q=plate+notation+graphical+model&client=ubuntu&hs=HX5&channel=fs&biw=1118&bih=561&source=lnms&tbm=isch&sa=X&ved=0ahUKEwirl6uBorHJAhVBAxoKHYLdCmk4FBD8BQgGKAE), where each plate surrounds a set of views that are paremeterised on some shared field. For each plate, you could choose to see all the data or instead fix the shared field to a single value. For example, in the Imp compiler I might want to see the whole dataflow or instead narrow it to a single query node or a single view step in the plan for a node. This narrowing is similar to the views you can get by stepping in and out of functions in a normal language, but following the shape of the data flow rather than the control flow.

Navigating context will become more important in larger programs, but there is a related problem that is already unpleasant in the compiler. I often want to describe one instance of a context as being based on another, with some small changes. For example, for each step in the query plan the state is mostly the same as the previous step. At the moment, maybe 30% of the code in imp.imp is just boilerplate copying of state and it's going to be worse in the parts that are yet to be written.

```
in node ?n:number wave ?w:number primitive ?p:number is unscheduled
+
?w <- 0
clause ?p of node ?n is primitive
+
in node ?n wave ?w2 primitive ?p is unscheduled
in node ?n wave ?w2 primitive _ is scheduled on subtree _
! in node ?n wave ?w2 primitive ?p is scheduled on subtree _
?w = ?w2 + 1

in node ?n:number wave ?w:number clause ?c:number is unjoined
+
?w <- 0
clause ?c of node ?n is finite
+
in node ?n wave ?w2 clause ?c is unjoined
in node ?n wave ?w2 primitive _ is scheduled on subtree _
! in node ?n wave ?w2 clause ?c is joined
?w = ?w2 + 1
```

[Bloom](http://bloom-lang.net/) provides one way of dealing with this by providing syntax sugar for views which change over time, but this is a very limited subset of the problem. I already run into it in calculating the join tree, in scheduling primitives within a query, in scheduling joins for each primitive application and in scheduling actions within each join. Lots of nested, overlapping contexts that don't fit well into a single timeline with a forgotten past.

I strongly suspect that this context problem is the most important on this list, and is vital for making Imp a practical language.

### Structure

I notice that I get often get lost while working on the compiler. I think there are some accidents of syntax that have conspired to force me to context switch a lot more than I really need to.

At the moment, each view is defined in a single place together with all the logic that contributes to it:

```
child ?ck:text ?ca:number ?cz:number of ?pk:text ?pa:number ?pz:number has text ?c:text
+
outside says ?pk ?pa ?pz has child ?ck ?ca ?cz with text ?c
+
?pk contains ?ck found by capture ?n of ?re
child ?pk ?pa ?pz of _ _ _ has text ?p
capture ?n of result _ of ?p searched by ?re is at ?ra to ?rz
?ca = ?pa + ?ra
?cz = ?pa + ?rz
the text at ?ra to ?rz in ?p is ?c
```

This has some unfortunate side effects.

First is that the schema definition is spread out all over the program. In Rust I tend to push all the important type definitions to the top of the file so that the reader can see the overall structure at a glance. Even in Clojure, I tend to start each namespace with a long comment describing the data. In Imp I can't do that, and not only does that make it harder to refer to but I also end up with a messier schema.

Second, each query can only feed into one view, so I tend to push lots of data into one view rather than repeat the body of the query multiple times. This results in a somewhat denormalised schema which is harder for me to remember later on and harder to refactor when I want to change something.

I would be better off with the structure that we used back in older versions of Eve, where each query body can push data into multiple views:

```
?ck:text ?ca:number ?cz:number has parent ?pk:text ?pa:number ?pz:number
?ck:text ?ca:number ?cz:number has text ?c:text

outside says ?pk ?pa ?pz has child ?ck ?ca ?cz with text ?c
=>
?ck ?ca ?cz has parent ?pk ?pa ?z
?ck ?ca ?cz has text ?c

?pk contains ?ck found by capture ?n of ?re
?pk ?pa ?pz has text ?p
capture ?n of result _ of ?p searched by ?re is at ?ra to ?rz
?ca = ?pa + ?ra
?cz = ?pa + ?rz
the text at ?ra to ?rz in ?p is ?c
=>
?ck ?ca ?cz has parent ?pk ?pa ?z
?ck ?ca ?cz has text ?c
```

This also removes the need for the ugly assignment primitive `_ <- _`, since I can use constants and repeated variables in the output.

I'm also less keen on the sentence-like syntax experiment. While it makes the meaning of individual views easier to express, it hinders pattern matching when reading large amounts of code. I may adopt [LogicBlox' parametric relations](http://2015.splashcon.org/event/splash2015-splash-i-shan-shan-huang-talk) instead which enable some nice syntactic sugar. Not sure whether their approach to aggregation is general enough to handle the compiler though, so I'll still have to figure that out separately.

```
parent(kind, number, number) = (kind, number, number)
text(kind, number, number) = text

contains-child(pk, ck) = (re, n)
text(pk, pa, pz) = p
search(p, re, n) = (ra, rz)
pa + ra = ca
pa + rz = cz
text-at(p, ra, rz) = c
=>
parent(ck, ca, cz) = (pk, pa, pz)
text(ck, ca, cz) = c
```

With all the of the surrounding text gone those variable names will need to be longer, but otherwise this looks pretty reasonable. That may have something to do with the decade I've spent looking at such patterns though.

### Correctness

Annoyingly, I didn't think to keep a record of the bugs I found while writing the compiler. My rough recollection is that most code worked on the first run. Most of the bugs I ran into were in the implementation itself and not the Imp code that I wrote. All but one of the Imp bugs that I can remember were caused either by typing errors or by incorrectly terminated loops. The former could all be caught by checking for unused variables and basic type-checking. The latter happened mostly in the boilerplate state changes for the primitive scheduling and might be avoided by removing the boilerplate, as discussed earlier in *context*. Finally, the only logic bug I can recall is still in the code at the time of writing - I forgot to track when the outputs of primitives may be used so queries with multiple chained primitives don't compile.

On the other hand, checking that the code is correct tends to be pretty hard. Data is scattered across many views and I don't have a good way of viewing yet it other than printing out the entire database. So while I don't spend much time debugging I do spend a lot of time scrolling back and forth through the output trying to figure out if I got the correct results.

There isn't much in the way of error handling yet but I'm quite happy with the way it has worked out so far. For the most part, I've been able to write the happy path first and then add error handling without having to modify the happy path. For example, if the compiler cannot find a join tree for a given query, it will simply stop short. A later view checks to see which views have not been finished:

```
clause ?c:number is not joined in node ?n:number
+
clause ?c of node ?n is unjoined in step 0
! clause ?c of node ?n is joined to clause _ in step _
! node ?n has root clause ?c
```

By contrast, the Rust version immediately throws an exception inline if it can't find a join tree. This makes it much harder to build a resilient compiler (I don't seem to have written about this anywhere, but the current Eve compiler can partially compile partially correct code and continue running without losing state).

### Tooling

[wtaysom](https://github.com/wtaysom)'s new parser at least gives me line numbers and readable errors, which is already a huge improvement on my regex mess. Adding syntax highlighting, checking for unused variables and type-checking would catch most of my remaining mistakes.

Showing the data for whatever view the cursor is currently inside would provide much faster feedback, especially since I could then use throwaway queries to ask questions like `clause ?c of node 3 is joined to clause _ in step ?s`. I would also like an overview of the whole dataset, since a common symptom of mistakes is that some views will suddenly have 0 rows.

When a view is empty, I often resort to tracing the data back by hand. [Why-not provenance](https://www.lri.fr/~herschel/resources/bidoit_BDA2013.pdf) would automate this process. Similarly, when trying to figure out why a view has unexpected results in it, [why provenance](https://users.soe.ucsc.edu/~tan/papers/2001/whywhere.pdf) would be much better than simulating it by hand.

### Types

For the most part, I've been perfectly happy with only strings and numbers. The sole exception is when calculating subtrees of the join tree. Since there are many paths by which I can generate the same subtree I want to ensure that I remove duplicates. The natural way to do this would be to use the set of nodes in the subtree as the key but I don't have a set type. Instead I'm currently (ab)using the id type as a bitset:

```
node ?n:number has subtree ?t:id with root ?r:number
+
clause ?r of node ?n is unjoined in step 0
?t = set bit ?r of #0
+
clause ?c of node ?n is joined to clause ?p in step _
node ?n has subtree ?t2 with root ?r
1 = get bit ?p of ?t2
?t = set bit ?c of ?t2
```

This is a hacky solution but so far it's the only time I've felt the need for a complex type. I'll wait untill it happens at least a few more times before I start thinking about how to solve it.

### Implementation

At the start of this diary I explained that I was making the assumption that I could get away without maintaining indexes because I would mostly be processing data in bulk. This has gotten me pretty far, but it won't let me take advantage of semi-naive or incremental evaluation - both of which rely on the assumption that making one of the inputs much smaller greatly reduces the work needed to answer the query, an assumption which does not hold if all the inputs have to be re-indexed anyway.

Eve is also moving more towards a database-like system where the focus is on external user-driven mutation rather than internal, programmatic state changes. I would like to share the runtime if practical, so that also violates some of my early assumptions.

My handling of primitives, especially aggregates, is still somewhat dubious and I would like to have a proper theory around that rather than just a crude heuristic. I also have some new ideas around the relationship between [Tetris](http://arxiv.org/pdf/1404.0703.pdf), [Triejoin](http://arxiv.org/abs/1210.0481) and Yannakakis algorithm that may bear fruit.

All of that points towards revisiting the query planner with an eye towards incremental evaluation and a better theoretical basis for planning aggregates.

### Summary

Things that worked out:

* Compact data layout, with strings stored elsewhere but hashes stored inline
* Hypertrees as a basis for planning queries
* Yannakikis algorithm
* Primitives as infinite relations
* Bootstrapping
* Error handling out-of-band

Things that need work:

* Syntax
* Error checking / static analysis
* Viewing data
* Negation

Things that need thought:

* Aggregates
* Incremental evaluation
* Index data-structures
* Context / time / mutation
* Infinite views?
* Provenance

I think I'm going to look at the aggregates first, because I have a lot of half-formed ideas around query planning that may make incremental evaluation and provenance easier too.

### Theory

I spent two weeks carefully reading all the recent work on join algorithms and eventually reached a tipping point where suddenly it all made sense. I've written most of an article explaining the rough ideas in simpler terms, but before publishing it I want to spend some time trying to simplify the implementation and proof too.

### Unsafe

I also spent a week or two exploring data-structures for the indexes. I tried building a [HAMT](https://en.wikipedia.org/wiki/Hash_array_mapped_trie)-like structure in unsafe Rust. I learned a lot about how unsafe Rust works and how to use valgrind and gdb, but eventually concluded that it just isn't worth the time it would take to finish it.

Using the same layout as [Champ](http://michael.steindorfer.name/publications/oopsla15.pdf) would be far easier and produce far less segfaults. I haven't seen a comparison between the original C++ HAMT and the various descendants in managed languages so it's hard to say how much the extra pointer indirections cost. I wonder if there is some way to estimate the difference without actually having to implement both...

### Compiling

Imp is currently an interpreter. The overhead of interpreting query plans is hard to determine exactly, but the execution time is dominated by sorting and the sort function is ~35% faster if I hardcode the data layout for a specific table, so it's certainly non-trivial.

The current runtime works table-at-a-time to amortise the overhead of interpretation. For example, when applying functions like `+` there is a single dispatch to find the matching code and then a loop over the whole table:

``` rust
match (*self, input_ixes) {
    (Primitive::Add, [a, b]) => {
        for row in chunk.data.chunks(chunk.row_width) {
            data.extend(row);
            data.push(from_number(to_number(row[a]) + to_number(row[b])));
        }
    }
    ...
```

All the new join algorithms I have been researching work tuple-at-a-time so it's not possible to amortise the overhead in the same way. The algorithms are generally simple to write for a specific case, but building an interpreter that efficiently executes any case is difficult. It would be far easier to just emit code for each query, but Rust doesn't make that easy.

In fact, there would be a lot of things that would get easier if was just emitting code in the same language. I could let the existing language handle data layout and type checking. I would be able to use the existing libraries directly instead of [arduously wrapping them](https://github.com/jamii/imp/blob/1c41bdd4f0d5372be307d9d483caf8e8e6e9a1e8/src/primitive.rs) and I could use the repl and other tools with Imp.

This is what I did for most of the early versions of Eve. The problem is that the languages that make this kind of meta-programming practical tend to also have poor control over data layout and very opaque performance models. It's possible to [hack around](http://objectlayout.org/) the limitations but you end up in much the same boat as before - implementing your own data layout and type system that can't play with the existing standard library.

<blockquote class="twitter-tweet" lang="en"><p lang="en" dir="ltr">Heartening to see the focus on multi-stage programming in <a href="https://t.co/iSqkk9fmtW">https://t.co/iSqkk9fmtW</a>. There is a distinct lack of good staging languages.</p>&mdash; Jamie Brandon (@jamiiecb) <a href="https://twitter.com/jamiiecb/status/676921026601725953">December 16, 2015</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

I ended up using Rust after one too many evenings of wanting to stab Hotspot in the face. Back when I made the decision Mike Innes [argued](https://groups.google.com/forum/#!searchin/eve-talk/julia/eve-talk/5EifQQUHQUw/u3U_ERkbKFcJ) for using Julia instead. Of the objections that I brought up, some have since been fixed and some look like they are going to be fixed in the near future. The remainder (no interior pointers, layout restricted by the gc) seem like a fair trade for potentially removing the interpreter overhead. So I played around with Julia over the holidays.

### Return of the Yannakakis

The first thing I tried in Julia is porting part of the current Imp runtime - enough to hand-compile one of the Chinook queries.

Tables in the Rust version are a `Vec<u64>` with all the data layout being handled by the Imp compiler a layer above. Julia is dynamically typed so I can just use a vector of tuples and let the Julia compiler figure out the layout.

``` julia
ids() = ids(1000000)
ids(n) = rand(1:n, n)

eg_table = [(a,b) for (a,b) in zip(ids(), ids())]

typeof(eg_table
# Array{Tuple{Int64,Int64},1}
```

In Julia, immutable types like tuples are treated as value types. That means that this `Array{Tuple{Int64,Int64},1}` is a single contiguous allocation, not an array of pointers to tuple objects. To get this in Clojure or Javascript I would have to use a flat array and then write all my own sort functions from scratch to account for the rows. In Julia I can rely on the compiler to handle this for me.

``` julia
f() = begin
  xs = [(a,b) for (a,b) in zip(ids(), ids())]
  @time sort(xs, alg=QuickSort)
end

# 0.193217 seconds (10 allocations: 15.259 MB, 0.39% gc time)
```

This is on par with the stdlib sort in Rust and ~2x slower than the radix sort used in Imp. Also note that only 10 allocations were reported. The compiler is smart enough to reuse allocations for the boxed tuples rather than creating 1M temporary tuples on the heap.

We need to build up some basic relational functions.

``` julia
project(xs, ykey) = begin
  ys = Vector(0)
  for x in xs
    push!(ys, x[ykey])
  end
  sort!(ys, alg=QuickSort)
  dedup_sorted(ys)
end

f() = begin
  xs = [(a,b) for (a,b) in zip(ids(), ids())]
  @time project(xs, [2])
end

# 1.418393 seconds (4.00 M allocations: 220.172 MB, 8.61% gc time)
```

That's not good. Far too slow, far too many allocations and, worst of all, the returned value is a `Vector{Any}` ie an array of pointers to tuples.

First, let's fix the return type. By default `Vector` returns a `Vector{Any}`, but we can specify the type if we want something else. Since types are first-class values in Julia we can just pass the return type as an argument.

``` julia
project(xs, ykey, ytype) = begin
  ys = Vector{ytype}(0)
  for x in xs
    push!(ys, x[ykey])
  end
  sort!(ys, alg=QuickSort)
  dedup_sorted(ys)
end

f() = begin
  xs = [(a,b,c) for (a,b,c) in zip(ids(), ids(), ids())]
  project(xs, [1,2], Tuple{Int64, Int64})
end

# 0.645461 seconds (5.00 M allocations: 254.867 MB, 10.12% gc time)
```

Next, we need to give the compiler enough information that it can reuse the allocation for `x[ykey]`. Suppose we made it's job easy by pulling out the critical function and by hardcoding the key:

``` julia
reshape(xs, ys, ykey) = begin
  for x in xs
    push!(ys, (x[1], x[2]))
  end
end

project(xs, ykey, ytype) = begin
  ys = Vector{ytype}(0)
  reshape(xs, ys, ykey)
  sort!(ys, alg=QuickSort)
  dedup_sorted(ys)
end

f() = begin
  xs = [(a,b,c) for (a,b,c) in zip(ids(), ids(), ids())]
  @time project(xs, [1,2], Tuple{Int64, Int64})
end

#   0.216851 seconds (42 allocations: 34.001 MB, 0.61% gc time)
```

That's much better. Now I just have to figure out how to make a hardcoded version of reshape for each key. I could (and did) do it with macros, but macros have a tendency to spread and turn everything else into macros. It would be nice if we could just piggyback on the existing specialisation machinery, and Julia recently gained the ability to do just that through the combination of two new features.

The first new feature is [value types](http://docs.julialang.org/en/release-0.4/manual/types/#value-types). `Val{x}` takes an immutable value `x` and turns it into a type, which allows us to specialise on values as well as types.

``` julia
reshape{T}(xs, ys, ykey::Type{Val{T}}) = begin
  for x in xs
    push!(ys, construct(ykey, x))
  end
end

project(xs, ykey, ytype) = begin
  ys = Vector{ytype}(0)
  reshape(xs, ys, Val{ykey})
  sort!(ys, alg=QuickSort)
  dedup_sorted(ys)
end
```

The second feature is [generated functions](http://docs.julialang.org/en/release-0.4/manual/metaprogramming/#generated-functions) which allow the programmer to emit custom code for each specalisation of the function.

``` julia
@generated construct{T}(key::Type{Val{T}}, value) = begin
  ixes = key.parameters[1].parameters[1]
  :(begin
      tuple($([:(value[$ix]) for ix in ixes]...))
    end)
end
```

This is true [multi-stage programming](http://www.cs.rice.edu/~taha/MSP/), something which is painful to achieve with macros and eval alone.

``` julia
f() = begin
  xs = [(a,b,c) for (a,b,c) in zip(ids(), ids(), ids())]
  @time project(xs, (1,2), Tuple{Int64, Int64})
end
# 0.208217 seconds (41 allocations: 34.001 MB, 1.06% gc time)
```

Just as fast as the hardcoded version.

Not so happy if we try some other types though.

``` julia
f() = begin
  xs = [(a,Float64(b),c) for (a,b,c) in zip(ids(), ids(), ids())]
  @time project(xs, (1,2), Tuple{Int64, Float64})
end
# 2.746427 seconds (98.79 M allocations: 2.234 GB, 14.23% gc time)
```

I'm not sure what's going on here yet. I [started a thread](https://groups.google.com/forum/#!topic/julia-users/4L693Z8qePw) on the mailing list. I suspect either a bug in the boxing analysis or some heuristics around when to specialise `push!`.

So tuples don't always work nicely, but fortunately Julia is the kind of language where we can make our own tuples.

``` julia
abstract Row

macro row(name, types)
  types = types.args
  :(immutable $(esc(name)) <: Row
      $([:($(symbol("f", i))::$(types[i])) for i in 1:length(types)]...)
    end)
end

@generated cmp_by_key{R1 <: Row, R2 <: Row}(x::R1, y::R2, xkey, ykey) = begin
  xkey = xkey.parameters[1].parameters[1]
  ykey = ykey.parameters[1].parameters[1]
  @assert(length(xkey) == length(ykey))
  :(begin
      $([:(if !isequal(x.$(xkey[i]), y.$(ykey[i])); return isless(x.$(xkey[i]), y.$(ykey[i])) ? -1 : 1; end) for i in 1:length(xkey)]...)
      return 0
    end)
end

@generated Base.isless{R <: Row}(x::R, y::R) = begin
  key = [symbol("f", i) for i in 1:length(fieldnames(R))]
  last = pop!(key)
  :(begin
      $([:(if !isequal(x.$k, y.$k); return isless(x.$k, y.$k); end) for k in key]...)
      return isless(x.$last, y.$last)
    end)
end

@generated construct{C,K}(constructor::Type{C}, key::Type{Val{K}}, value) = begin
  constructor = constructor.parameters[1]
  fields = key.parameters[1].parameters[1]
  :(begin
      $constructor($([:(value.$field) for field in fields]...))
    end)
end

...

f() = begin
  xs = [A(a,b,c) for (a,b,c) in zip(ids(), ids(), ids())]
  @time project(xs, (:f1,:f2), B)
end

# 0.211331 seconds (41 allocations: 34.001 MB, 1.09% gc time)
```

So it does the job. Hopefully this is a temporary fix, because tuples are nicer ergonomically, but it's reassuring that we have this level of access to low-level primitives.

Some merge-joins:

``` julia
join_sorted_inner{X,Y,Z,XK,YK,ZK1,ZK2}(
  xs::Vector{X}, ys::Vector{Y}, ztype::Type{Z},
  xkey::Type{Val{XK}}, ykey::Type{Val{YK}}, zkey1::Type{Val{ZK1}}, zkey2::Type{Val{ZK2}}
  ) = begin
  zs = Vector{Z}(0)
  xi = 1
  yi = 1
  while (xi <= length(xs)) && (yi <= length(ys))
    x = xs[xi]
    y = ys[yi]
    c = cmp_by_key(x, y, xkey, ykey)
    if c == -1
      xi += 1
    elseif c == 1
      yi += 1
    else
      xj = xi
      yj = yi
      while (xj <= length(xs)) && (cmp_by_key(x, xs[xj], xkey, xkey) == 0)
        xj += 1
      end
      while (yj <= length(ys)) && (cmp_by_key(y, ys[yj], ykey, ykey) == 0)
        yj += 1
      end
      for xk in xi:(xj-1)
        for yk in yi:(yj-1)
          push!(zs, construct2(Z, zkey1, zkey2, xs[xk], ys[yk]))
        end
      end
      xi = xj
      yi = yj
    end
  end
  zs
end

@inline join_sorted(xs, ys, ztype, xkey, ykey, zkey1, zkey2) =
  join_sorted_inner(xs, ys, ztype, Val{xkey}, Val{ykey}, Val{zkey1}, Val{zkey2})

semijoin_sorted_inner{X,Y,XK,YK}(
  xs::Vector{X}, ys::Vector{Y},
  xkey::Type{Val{XK}}, ykey::Type{Val{YK}}
  ) = begin
  zs = Vector{X}(0)
  xi = 1
  yi = 1
  while (xi <= length(xs)) && (yi <= length(ys))
    x = xs[xi]
    y = ys[yi]
    c = cmp_by_key(x, y, xkey, ykey)
    if c == -1
      xi += 1
    elseif c == 1
      yi += 1
    else
      push!(zs, x)
      xi += 1
    end
  end
  zs
end

@inline semijoin_sorted(xs, ys, xkey, ykey) =
  semijoin_sorted_inner(xs, ys, Val{xkey}, Val{ykey})
```

And import the data for the benchmark:

``` julia
read_tsv(rowtype, filename) = begin
  fieldtypes = [fieldtype(rowtype, fieldname) for fieldname in fieldnames(rowtype)]
  raw = readdlm(filename, '\t', UTF8String, header=true, quotes=false, comments=false)[1]
  results = Vector{rowtype}(0)
  for i in 1:size(raw,1)
    row = Vector{Any}(vec(raw[i,:]))
    for j in 1:length(fieldtypes)
      if issubtype(fieldtypes[j], Number)
        row[j] = parse(fieldtypes[j], row[j])
      end
    end
    push!(results, rowtype(row...))
  end
  results
end

@row(Artist, [Int64, UTF8String])
@row(Album, [Int64, UTF8String, Int64])
@row(Track, [Int64, UTF8String, Int64, Int64, Int64, UTF8String, Float64, Float64, Float64])
@row(PlaylistTrack, [Int64, Int64])
@row(Playlist, [Int64, UTF8String])

chinook() = begin
  Any[
    read_tsv(Artist, "code/imp/data/Artist.csv"),
    read_tsv(Album, "code/imp/data/Album.csv"),
    read_tsv(Track, "code/imp/data/Track.csv"),
    read_tsv(PlaylistTrack, "code/imp/data/PlaylistTrack.csv"),
    read_tsv(Playlist, "code/imp/data/Playlist.csv"),
    ]
end
```

And finally, hand-compile the query plan:

``` julia
@row(I1, [Int64, UTF8String]) # playlist_id playlist_name
@row(I2, [Int64, Int64]) # playlist_id track_id
@row(I3, [Int64, Int64]) # track_id playlist_id
@row(I4, [Int64, Int64]) # track_id album_id
@row(I5, [Int64, Int64]) # album_id track_id
@row(I6, [Int64, Int64]) # album_id artist_id
@row(I7, [Int64, Int64]) # artist_id album_id
@row(I8, [Int64, UTF8String]) # artist_id artist_name
@row(I9, [Int64, UTF8String]) # album_id artist_name
@row(I10, [Int64, UTF8String]) # track_id artist_name
@row(I11, [Int64, UTF8String]) # playlist_id artist_name
@row(I12, [UTF8String, UTF8String]) # playlist_name artist_name

metal(data) = begin
  i0 = filter(row -> row.f2 == "Heavy Metal Classic", data[5])

  i1 = project(i0, I1, (1,2))
  i2 = project(data[4], I2, (1,2))
  i2s = semijoin_sorted(i2::Vector{I2}, i1::Vector{I1}, (1,), (1,))

  i3 = project(i2s, I3, (2,1))
  i4 = project(data[3], I4, (1,3))
  i4s = semijoin_sorted(i4, i3, (1,), (1,))

  i5 = project(i4s, I5, (2,1))
  i6 = project(data[2], I6, (1,3))
  i6s = semijoin_sorted(i6, i5, (1,), (1,))

  i7 = project(i6s, I7, (2,1))
  i8 = project(data[1], I8, (1,2))
  i9 = join_sorted(i7, i8, I9, (1,), (1,), (2,), (2,))

  i9s = project(i9, I9, (1,2))
  i10 = join_sorted(i5, i9s, I10, (1,), (1,), (2,), (2,))

  i10s = project(i10, I10, (1,2))
  i11 = join_sorted(i3, i10s, I11, (1,), (1,), (2,), (2,))

  i11s = project(i11, I11, (1,2))
  i12 = join_sorted(i1, i11s, I12, (1,), (1,), (2,), (2,))

  i12
end
```

Fingers crossed:

``` julia
using Benchmark

f() = begin
  data = chinook()
  @time benchmark(()->metal(data), "", 1000)
end

# mean 1.57ms, max 6.68ms, min 1.27ms
# total 3.354096 seconds (1.70 M allocations: 1.349 GB, 4.40% gc time)
```

Compared to the original:

``` bash
jamie@wanderer:~/code/imp$ cargo bench bench_chinook
     Running target/release/imp-fdad7c291f20f4c3

running 1 test
test runtime::tests::bench_chinook_metal     ... bench:   1,524,175 ns/iter (+/- 188,483)
```

Eerily neck and neck. While the Julia stdlib sort is slower than the radix sort used in Rust imp, it catches up by making reshape and join much faster.

I'm really happy with this. The code is easy to write and debug. Being able to freely mix generated code with normal functions is basically a superpower. It's funny that the two features that made it possible were quietly added without much fanfare. Is Julia the only commercially supported language for multi-stage programming? I can only think of [Terra](http://terralang.org/), [MetaOCaml](http://www.cs.rice.edu/~taha/MetaOCaml/) and [LMS](https://scala-lms.github.io/), none of which I'd want to risk using right now.

### Indexing

I put together a crude first pass at a HAMT-like thing.

``` julia
type Node{T}
  leaf_bitmap::UInt32
  node_bitmap::UInt32
  leaves::Vector{T}
  nodes::Vector{Node{T}}
end

type Tree{T}
  root::Node{T}
end

Tree(T) = Tree(Node{T}(0, 0, T[], Node{T}[]))

const key_length = Int64(ceil(sizeof(hash(0)) * 8.0 / 5.0))

chunk_at(key, ix) = (key >> (ix*5)) & 0b11111

singleton{T}(row::T, column, ix) = begin
  if ix >= key_length
    column += 1
    ix = 0
    if column > length(row)
      error("Out of bits")
    end
  end
  value = row[column]
  key = hash(value)
  chunk = chunk_at(key, ix)
  Node{T}(1 << chunk, 0, T[row], Node{T}[])
end

Base.push!{T}(tree::Tree{T}, row::T) = begin
  node = tree.root
  for column in 1:length(row)
    value = row[column]
    key = hash(value)
    for ix in 0:(key_length-1)
      chunk = chunk_at(key, ix)
      mask = 1 << chunk
      if (node.node_bitmap & mask) > 0
        node_ix = 1 + count_ones(node.node_bitmap << (32 - chunk))
        node = node.nodes[node_ix]
        # continue loop
      elseif (node.leaf_bitmap & mask) > 0
        leaf_ix = 1 + count_ones(node.leaf_bitmap << (32 - chunk))
        leaf = node.leaves[leaf_ix]
        if row == leaf
          return tree # was a dupe
        else
          deleteat!(node.leaves, leaf_ix)
          child = singleton(leaf, column, ix+1)
          node.leaf_bitmap $= mask
          node.node_bitmap |= mask
          node_ix = 1 + count_ones(node.node_bitmap << (32 - chunk))
          insert!(node.nodes, node_ix, child)
          node = child
          # continue loop
        end
      else
        node.leaf_bitmap |= mask
        leaf_ix = 1 + count_ones(node.leaf_bitmap << (32 - chunk))
        insert!(node.leaves, leaf_ix, row)
        return tree # inserted
      end
    end
  end
  error("Out of bits!")
end

Base.in{T}(row::T, tree::Tree{T}) = begin
  node = tree.root
  for column in 1:length(row)
    value = row[column]
    key = hash(value)
    for ix in 0:(key_length-1)
      chunk = chunk_at(key, ix)
      mask = 1 << chunk
      if (node.node_bitmap & mask) > 0
        node_ix = 1 + count_ones(node.node_bitmap << (32 - chunk))
        node = node.nodes[node_ix]
        # continue loop
      elseif (node.leaf_bitmap & mask) > 0
        leaf_ix = 1 + count_ones(node.leaf_bitmap << (32 - chunk))
        leaf = node.leaves[leaf_ix]
        return row == leaf
      else
        return false
      end
    end
  end
  error("Out of bits!")
end
```

Naively comparing it to sorting to get a feel for how far away it is from the baseline:

``` julia
f() = begin
  rows = [(a,) for a in ids(1000000)]
  make_tree() = begin
    tree = Tree(Tuple{Int64})
    for row in rows
      push!(tree, row)
    end
    tree
  end
  tree = make_tree()
  (benchmark(()->sort(rows, alg=QuickSort), "", 100),
  benchmark(make_tree, "", 100),
  benchmark(()->all([(row in tree) for row in rows]), "", 100))
end

# ~280ms for sorting
# ~890ms for insert
# ~480ms for lookup
```

So this first pass is about 4x slower to build an index than sorting is. Let's start speeding that up.

Some quick digging in the generated code reveals:

```
julia> @code_native count_ones(0)
    .text
Filename: int.jl
Source line: 133
    pushq    %rbp
    movq    %rsp, %rbp
Source line: 133
    movq    %rdi, %rax
    shrq    %rax
    movabsq    $6148914691236517205, %rcx # imm = 0x5555555555555555
    andq    %rax, %rcx
    subq    %rcx, %rdi
    movabsq    $3689348814741910323, %rcx # imm = 0x3333333333333333
    movq    %rdi, %rax
    andq    %rcx, %rax
    shrq    $2, %rdi
    andq    %rcx, %rdi
    addq    %rax, %rdi
    movabsq    $72340172838076673, %rcx # imm = 0x101010101010101
    movabsq    $1085102592571150095, %rax # imm = 0xF0F0F0F0F0F0F0F
    movq    %rdi, %rdx
    shrq    $4, %rdx
    addq    %rdi, %rdx
    andq    %rdx, %rax
    imulq    %rcx, %rax
    shrq    $56, %rax
    popq    %rbp
    ret
```

Which is not what I was hoping. Googling avails me not. Kristoffer Carlsson [points me in the right direction](https://groups.google.com/forum/#!topic/julia-users/z7To2f1i1K8). After rebuilding Julia for my native arch I get:

```
julia> @code_native count_ones(0)
	.text
Filename: int.jl
Source line: 133
	pushq	%rbp
	movq	%rsp, %rbp
Source line: 133
	popcntq	%rdi, %rax
	popq	%rbp
	ret
```

Rebuilding nets us a small improvement in both sorting and insert:

```
# ~170ms for sorting
# ~560ms for insert
# ~500ms for lookup
```

I *think* the slight increase in lookup is just crappy benchmarking on my part, but I don't have a good way to reset the system image to test it. And I have no idea where to start looking if I want to figure out why sorting is faster. Maybe if I could find out what extra instructions were enabled...

Since sorting is a little faster now I reran the query benchmark from the last post and got ~1.4ms, down from ~1.6ms, making it just slightly faster on average than the Rust version.

Next I made `Node{T}` immutable, thinking that it would be stored inline in the parent array, saving half of the pointer chases. No change in the benchmarks. Uh oh.

``` julia
immutable A
  a::UInt32
  b::UInt32
  c::UInt64
  d::UInt64
end

sizeof(A[A(0,0,0,0), A(0,0,0,0)]) # 48

immutable B
  a::UInt32
  b::UInt32
  c::Vector{UInt64}
  d::Vector{UInt64}
end

sizeof(B[B(0,0,[],[]), B(0,0,[],[])]) # 16
```

At first glance this kind of makes sense, because if `Vector{UInt64}` was just a pointer to some contiguous array then that pointer would have to be mutated if the array is resized. (In Rust that's fine - we can pass around interior pointers and happily mutate them.)

But thinking about it some more, the same is true of variables on the stack. If I do:

``` julia
a = [1,2,3]
b = a
push!(a,4)
println(b)
```

The only way this could work is if a and b both point to some heap value which itself points to the actual array data. Looking at https://github.com/JuliaLang/julia/blob/master/src/julia.h#L193-L229 confirms my suspicion - we have a double pointer hop for every use of an array.

That doesn't explain why `B` doesn't get stored inline in the array, but it kicks a hole in this whole plan anyway. I need to figure out how to get this down to a single pointer hop per node. Perhaps something like:

``` julia
type Node{T, L, N}
  leaf_bitmap::UInt32
  node_bitmap::UInt32
  leaves::NTuple{L, Nullable{T}}
  nodes::NTuple{N, Nullable{Any}}
end
```

It depends on where those numbers get stored. I have a sneaking suspicion that it's going to be in another boxed intermediate separating the nodes.

``` julia
sizeof(Node{Int, 0, 0}) # 8
```

It certainly doesn't seem to be in the node itself, unless `sizeof` is not counting the metadata.

Humbug.

### Layout

My [question about storing B inline](https://groups.google.com/forum/#!topic/julia-users/9ADnjy1Zcx4) was answered - only types which satisfiy `isbits` will be stored inline ie no types that contain pointers. Fixing that would require modifying the gc, so it's very low on my list of options :)

My plan for today is to better understand the Julia runtime, starting with memory layout.

Tagged Julia values are defined in [julia.h](https://github.com/JuliaLang/julia/blob/master/src/julia.h#L151-L158) - a pointer to the type (with the lower 2 bits used for gc) followed by the value itself. The types are also tagged Julia values, built out of structs later on in [julia.h](https://github.com/JuliaLang/julia/blob/master/src/julia.h#L298-L368). The recursion ends with
some hardcoded types that are initialized in [jltypes.c](https://github.com/JuliaLang/julia/blob/25c3659d6cec2ebf6e6c7d16b03adac76a47b42a/src/jltypes.c#L3177-L3611).

We can do horrible things with pointers to get a look at the underlying memory:

``` julia
julia> view_raw(x, n) = begin
         p = convert(Ptr{UInt}, pointer_from_objref(x))
         for e in pointer_to_array(p, (n,), false)
           println(e)
         end
       end
view_raw (generic function with 1 method)

julia> view_raw(Z(5, true, [1,2,3]), 3)
5
1
140234783861264
```

It looks like type constructors are cached, which makes sense because somewhere there has to be a method cache where these are the keys:

``` julia
julia> type X{T} a::T end

julia> x1 = X{Int}
X{Int64}

julia> x2 = X{Int}
X{Int64}

julia> is(x1, x2)
true

julia> pointer_from_objref(x1)
Ptr{Void} @0x00007f8af3e2f2b0

julia> pointer_from_objref(x2)
Ptr{Void} @0x00007f8af3e2f2b0
```

Arrays are defined in [julia.h](https://github.com/JuliaLang/julia/blob/master/src/julia.h#L219-L255). It's way more complicated than I expected so I need to poke around to see what's going on. Luckily, they seem to be allocated near other stuff so I don't segfault all other the place while guessing the length.

``` julia
julia> view_raw([], 10)
139805903543424
0
569348
0
0
0
0
139805834444816
139805834490240
0

julia> view_raw([7,7,7], 10)
139805896193984
3
561156
3
3
4294967296
7
7
7
0

julia> view_raw(collect(777:7777), 10)
28339056
7001
561158
7001
7001
0
0
139805835290192
139805901526672
10

julia> view_raw(collect(777:7777), 20)
28395088
7001
561158
7001
7001
0
0
139805835290192
139805901532816
20
544772
20
20
0
0
139805834283184
139805901532992
0
569348
0

julia> view_raw(collect(777:888), 20)
139805873991552
112
561156
112
112
0
777
778
779
780
781
782
783
784
785
786
787
788
789
790
```

Up to around 2048 words and it gets stored inline. Above that and it gets dumped somewhere else. (Which is weird, because [MALLOC_THRESH=1048576](https://github.com/JuliaLang/julia/blob/ea952fc289a8f8e2aeb317e0ccb9ce59ec745c4f/src/array.c#L555)).

Resizing is interesting:

``` julia
julia> x = collect(1:10)
4-element Array{Int64,1}:
...

julia> view_raw(x, 20)
139805874711584
10
561156
10
10
139814526530144
1
2
3
4
5
6
7
8
9
10
0
139805834285488
139805874711728
0

julia> Int64(pointer(x))
139805874711584

julia> append!(x, 1:10000000)
10000004-element Array{Int64,1}:
...

julia> view_raw(x, 20)
139805488328720
10000004
561158
10000004
16777216
4294967296
1
2
3
4
0
139805875018024
139805875017984
24
102404
24
24
1099511627776
7954884599197543732
8897249683018162292

julia> x = collect(1:2000)
2000-element Array{Int64,1}:
...

julia> view_raw(x, 20)
37207568
2000
557060
2000
2000
0
1
2
3
4
5
6
7
8
9
10
11
12
13
14

julia> append!(x, 1:10000000)
10002000-element Array{Int64,1}:
...

julia> view_raw(x, 20)
139805082062864
10002000
557062
10002000
16384000
0
1
2
3
4
5
6
7
8
9
10
11
12
13
14
```

If pushing causes the array to be resized it calls realloc and just sets the pointer. If the realloc resized it in place everything is fine. If the realloc made a new allocation elsewhere then we now have an extra pointer hop and, as far as I can tell from reading https://github.com/JuliaLang/julia/blob/master/src/array.c#L561-L607, the old allocation just hangs around. But that can only happen when the original allocation was inline which means the wasted allocation is fairly small.

There are also 6 words of overhead per (1d) array, not including the type tag. But if I count up fields in the struct I get 5 words and I've only ever seen the last word be 0. Maybe the list of dimensions is 0-terminated?

Anyway, I should definitely not be using arrays for my trie.

Other types are created in [boot.jl](https://github.com/JuliaLang/julia/blob/master/base/boot.jl). Strings are arrays of bytes, so they also pay the 6 word overhead. There don't seem to be any other surprises.

I'm tentatively assuming that tuples get laid out like C structs but I haven't found their constructor yet.

(I also got a [walkthrough](https://groups.google.com/forum/#!topic/julia-users/-qgRbw8AaaU) on how to get LLDB working nicely today, and spent a few hours trying to do the same for oprofile and valgrind with no success.)

(I also wrote the [beginnings of a layout inspector](https://github.com/jamii/imp/blob/master/src/Layout.jl) which I have vague plans of turning into a little gui thing.)

### Baseline

How much is my naive julia layout costing me?

I [ported the Julia HAMT to Rust](https://github.com/jamii/imp/blob/7c3d76afe7c2288c13677966ff28a870c8b7ea85/src/map.rs). The code is nearly identical. Since they use different hashing algorithms I removed hashing in both and instead just use random keys generated uniformly over the whole UInt64 range. The Julia version *should* have full type information and obviously the Rust version is fully typed. The both use the same codegen and are both specializing on type.

```
Rust sort 1M - 0.08s

Rust insert 1M - 0.21s
Rust lookup 1M - 0.12s
Rust insert 10M - 3.11s
Rust lookup 10M - 1.92s
Rust insert 100M - 48.97s
Rust lookup 100M - 31.26s

Julia insert 1M - 0.59s
Julia lookup 1M - 0.25s
Julia insert 10M - 8.59s
Julia lookup 10M - 5.02s
Julia insert 100M - OOM
Julia lookup 100M - OOM

Rust insert 10M peak rss - 475MB
Julia insert 10M peak rss - 1034MB
Julia insert 10M allocations - 765MB
```

(Note that the Rust version could be further optimized. It is currently storing the lengths and capacity of both vectors in each node - an extra 32 bytes per node that could be calculated from the bitmaps instead.)

I suspect that the difference in performance is attributable mostly to the different memory layout (and, for insert, the cost of allocation/gc). To test this, I'm going to add the same overhead to the Rust version:

``` rust
#[derive(Clone, Debug)]
pub struct JuliaArray<T> {
    metadata: [u64; 5], // 7 words, but length/capactity are shared with Vector
    vec: Vec<T>,
}

#[derive(Clone, Debug)]
pub struct Node<T> {
    metadata: [u64; 1],
    leaf_bitmap: u32,
    node_bitmap: u32,
    leaves: Box<JuliaArray<T>>,
    nodes: Box<JuliaArray<Node<T>>>,
}
```

```
Julian Rust insert 1M - 0.29s
Julian Rust lookup 1M - 0.18s
Julian Rust insert 10M - 4.91s
Julia Rust lookup 10M - 3.28s

Julian Rust insert 10M peak rss - 670MB
```

Huh. The memory usage is now similar but the Rust version is still much faster.

The Julia insert spends ~20% of it's time in gc, which would still only bring the Rust version up to ~6s vs ~9s for Julia. The lookup doesn't report any allocations in Julia, so I think I can rule out the cost of allocation.

So now I'm not sure what's going on. Let's try looking at the cpu performance counters. I [can't get line numbers for Julia](https://groups.google.com/forum/#!topic/julia-users/-qgRbw8AaaU) but I can still see if there is any difference in the overall pattern between the two.

No, wait, before that - I forgot an extra overhead from Julia. Nodes are boxed too:

``` rust
#[derive(Clone, Debug)]
pub struct JuliaArray<T> {
    metadata: [u64; 5], // 7 words, but length/capactity are shared with Vector
    vec: Vec<T>,
}

#[derive(Clone, Debug)]
pub struct Node<T> {
    metadata: [u64; 1],
    leaf_bitmap: u32,
    node_bitmap: u32,
    leaves: Box<JuliaArray<T>>,
    nodes: Box<JuliaArray<Box<Node<T>>>>,
}
```

```
Julian Rust insert 1M - 0.36s
Julian Rust lookup 1M - 0.24s
Julian Rust insert 10M - 6.00
Julian Rust lookup 10M - 4.83s

Julia Rust insert 10M peak rss - 633MB
```

So now the lookup time is almost identical. The insert time is still short even if we add 20% gc. Let's break out the perf counters! These numbers are for 10x insert+lookup 10M rows:

```
jamie@wanderer:~/code/imp/src$ perf stat -e cycles,instructions,branches,branch-misses,context-switches,cache-references,cache-misses -B ../target/release/imp
5.199791108999989s for insert
4.474710060000007s for lookup
7.080400916000144s for insert
6.229417960999854s for lookup
7.060942442999931s for insert
6.299797809999973s for lookup
7.109493033000035s for insert
6.253823409000006s for lookup
7.016020142000116s for insert
6.215963810000176s for lookup
7.078056773000071s for insert
6.315231796000035s for lookup
7.38005259800002s for insert
6.26794608199998s for lookup
7.138151556999901s for insert
6.276204322000012s for lookup
7.058818885999926s for insert
6.217261228000098s for lookup
7.040932895000196s for insert
6.261231286000111s for lookup

 Performance counter stats for '../target/release/imp':

   356,295,147,143      cycles                                                        (66.67%)
   138,966,714,020      instructions              #    0.39  insns per cycle          (83.33%)
    19,330,421,477      branches                                                      (83.33%)
       335,132,522      branch-misses             #    1.73% of all branches          (83.33%)
               407      context-switches
     3,865,389,150      cache-references                                              (83.33%)
     2,242,127,883      cache-misses              #   58.005 % of all cache refs      (83.33%)

     159.602175650 seconds time elapsed
```

The Rust version is faster on the first iteration and slower for all following iterations. This is consistent across multiple runs. I have no idea why. But it means that my benchmarks earlier with a single run per process are not telling the whole story. That's what I get for being lazy.

```
jamie@wanderer:~/code/imp/src$ perf stat -e cycles,instructions,branches,branch-misses,context-switches,cache-references,cache-misses -B julia Hamt.jl
WARNING: Base.String is deprecated, use AbstractString instead.
  likely near /home/jamie/.julia/v0.4/Benchmark/src/benchmarks.jl:13
WARNING: Base.String is deprecated, use AbstractString instead.
  likely near /home/jamie/.julia/v0.4/Benchmark/src/benchmarks.jl:13
WARNING: Base.String is deprecated, use AbstractString instead.
  likely near /home/jamie/.julia/v0.4/Benchmark/src/benchmarks.jl:41

WARNING: deprecated syntax "{a,b, ...}" at /home/jamie/.julia/v0.4/Benchmark/src/compare.jl:23.
Use "Any[a,b, ...]" instead.
  8.136648 seconds (15.31 M allocations: 766.329 MB, 10.92% gc time)
  4.815498 seconds (2 allocations: 9.537 MB)

 10.014619 seconds (15.31 M allocations: 766.329 MB, 25.24% gc time)
  4.692582 seconds (2 allocations: 9.537 MB)

 10.211293 seconds (15.31 M allocations: 766.329 MB, 23.99% gc time)
  5.035553 seconds (2 allocations: 9.537 MB)

  9.908472 seconds (15.31 M allocations: 766.329 MB, 24.53% gc time)
  4.786145 seconds (2 allocations: 9.537 MB)

 10.174752 seconds (15.31 M allocations: 766.329 MB, 24.43% gc time)
  4.983574 seconds (2 allocations: 9.537 MB)

  9.897518 seconds (15.31 M allocations: 766.329 MB, 24.45% gc time)
  4.976863 seconds (2 allocations: 9.537 MB)

 10.016775 seconds (15.31 M allocations: 766.329 MB, 24.93% gc time)
  4.608078 seconds (2 allocations: 9.537 MB)

  9.571723 seconds (15.31 M allocations: 766.329 MB, 24.56% gc time)
  4.663033 seconds (2 allocations: 9.537 MB)

  9.683189 seconds (15.31 M allocations: 766.329 MB, 24.38% gc time)
  4.614693 seconds (2 allocations: 9.537 MB)

 10.616815 seconds (15.31 M allocations: 766.329 MB, 23.37% gc time)
  5.474383 seconds (2 allocations: 9.537 MB)

nothing

 Performance counter stats for 'julia Hamt.jl':

   461,891,446,139      cycles                                                        (66.66%)
   172,704,455,804      instructions              #    0.37  insns per cycle          (83.33%)
    30,037,830,863      branches                                                      (83.34%)
       448,233,381      branch-misses             #    1.49% of all branches          (83.34%)
            18,070      context-switches
     5,017,726,390      cache-references                                              (83.34%)
     2,915,696,296      cache-misses              #   58.108 % of all cache refs      (83.33%)

     169.362873754 seconds time elapsed
```

Same effect in the Julia version. Benchmarking is hard :S

What else can we see. The Julia version runs for longer, executes more instructions, executes more branches and reads memory more often. The branch-miss rate and cache-miss rate are very similar to the Rust version.

But the Julia version has waaaay more context-switches: 18,070 vs 407. Where are they coming from?

```
jamie@wanderer:~/code/imp/src$ sudo perf record -e context-switches --call-graph dwarf -B julia Hamt.jl
...
jamie@wanderer:~/code/imp/src$ sudo perf report -g graph --no-children

-   99.57%  julia          [kernel.kallsyms]  [k] schedule
   - schedule
      - 70.90% retint_careful
           9.08% 0x7f80f5a386bc
           9.03% 0x7f80f4aa715f
           7.37% 0x7f80f4aa7d85
           6.09% 0x7f80f4aa8964
           3.19% 0x7f80f5a383c5
           2.85% 0x7f80f5a38a8d
           2.47% 0x7f80f5a387fb
           2.47% 0x7f80f5a383fa
           2.23% 0x7f80f5a387f4
           2.23% 0x7f80f5a383f3
    etc...
```

Gee, thanks perf.

```
jamie@wanderer:~/code/imp/src$ strace -c julia Hamt.jl
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 87.15    0.008217          74       111           read
 12.74    0.001201           0    206532           madvise
  0.12    0.000011           0       116           mmap
...
```

The only place that madvise is called in the Julia repo is in [gc.c](https://github.com/JuliaLang/julia/blob/6cc48dcd24322976bdc193b3c578acb924f0b8e9/src/gc.c#L952). It looks like something to do with the allocation pools that Julia uses for small allocations. If I disable the gc I still get lots of context switches but no madvise. In fact, without gc I have ~12k context switches and only ~4k system calls. Mysterious.

Let's try something different. I'll start up Julia, compile everything and run through the benchmark once, then attach perf and run through it again. Just to see if those context switches are actually coming from my code or are all from compilation.

```
jamie@wanderer:~$ perf stat -e cycles,instructions,branches,branch-misses,context-switches,cache-references,cache-misses -p 6315
^C
 Performance counter stats for process id '6315':

   363,276,940,351      cycles                                                        (66.67%)
   163,202,516,794      instructions              #    0.45  insns per cycle          (83.33%)
    28,053,778,030      branches                                                      (83.33%)
       418,751,631      branch-misses             #    1.49% of all branches          (83.33%)
               848      context-switches
     4,859,874,620      cache-references                                              (83.33%)
     2,563,913,645      cache-misses              #   52.757 % of all cache refs      (83.33%)

     173.421545858 seconds time elapsed
```

So it was a red herring. Bad benchmarking again :S

But we can see now that the numbers are very similar, with the Julia version just doing more work overall and nothing in particular standing out.

If we run without gc...

```
julia> f()
  5.709961 seconds (15.30 M allocations: 766.156 MB)
  3.705573 seconds (2 allocations: 9.537 MB)

  6.067698 seconds (15.30 M allocations: 766.156 MB)
  3.800082 seconds (2 allocations: 9.537 MB)

  5.877812 seconds (15.30 M allocations: 766.156 MB)
  3.573286 seconds (2 allocations: 9.537 MB)

  5.663457 seconds (15.30 M allocations: 766.156 MB)
  3.539182 seconds (2 allocations: 9.537 MB)

  5.710040 seconds (15.30 M allocations: 766.156 MB)
  3.711398 seconds (2 allocations: 9.537 MB)

  6.102098 seconds (15.30 M allocations: 766.156 MB)
  3.679805 seconds (2 allocations: 9.537 MB)

  6.603569 seconds (15.30 M allocations: 766.156 MB)
  3.722283 seconds (2 allocations: 9.537 MB)

Killed
```

..it's actually faster than the Rust version. It looks like the Rust version isn't generating popcnt. Cargo won't let me pass options to LLVM so we have this monstrousity instead:

```
jamie@wanderer:~/code/imp$ rustc src/main.rs --crate-name imp --crate-type bin -C opt-level=3 -g --out-dir /home/jamie/code/imp/target/release --emit=dep-info,link -L dependency=/home/jamie/code/imp/target/release -L dependency=/home/jamie/code/imp/target/release/deps --extern time=/home/jamie/code/imp/target/release/deps/libtime-22c21fe32894ddad.rlib --extern regex=/home/jamie/code/imp/target/release/deps/libregex-ca23fbfc498b741a.rlib --extern peg_syntax_ext=/home/jamie/code/imp/target/release/deps/libpeg_syntax_ext-3094fcce08564e8c.so --extern rand=/home/jamie/code/imp/target/release/deps/librand-12e778fcd5eb28e9.rlib -C target-cpu=native

jamie@wanderer:~/code/imp$ perf stat -e cycles,instructions,branches,branch-misses,context-switches,cache-references,cache-misses target/release/imp
3.5112703029999466s for insert
2.288155586999892s for lookup
5.355302826999832s for insert
2.946845485999802s for lookup
5.500407145000281s for insert
2.9404805889998897s for lookup
5.594997771000635s for insert
3.302149258999634s for lookup
5.507628701000613s for insert
3.064086700000189s for lookup
5.822303377000026s for insert
3.465523935999954s for lookup
5.836835606000022s for insert
3.4077694679999695s for lookup
6.276327544000196s for insert
3.469119299999875s for lookup
5.55367445399952s for insert
2.969313937000152s for lookup
5.593115818000115s for insert
3.053487084000153s for lookup

 Performance counter stats for 'target/release/imp':

   329,000,811,832      cycles                                                        (66.66%)
   120,350,860,733      instructions              #    0.37  insns per cycle          (83.33%)
    19,325,072,668      branches                                                      (83.33%)
       328,275,527      branch-misses             #    1.70% of all branches          (83.34%)
               855      context-switches
     3,829,953,580      cache-references                                              (83.34%)
     2,075,840,379      cache-misses              #   54.200 % of all cache refs      (83.34%)

     111.281388975 seconds time elapsed
```

Sure makes a difference.

Finally, I realized that the Rust version isn't counting the time taken to free the tree after the benchmark, while the Julia version is paying that cost in gc during insert. So I'll time the Rust drop and the Julia gc separately after each run, and disable the gc otherwise.

```
julia> f()
  5.098385 seconds (15.30 M allocations: 765.923 MB)
  2.972040 seconds (2 allocations: 9.537 MB)
  1.975303 seconds, 100.00% gc time

  6.835982 seconds (15.30 M allocations: 765.923 MB)
  4.519367 seconds (2 allocations: 9.537 MB)
  2.255991 seconds, 100.00% gc time

  7.356767 seconds (15.30 M allocations: 765.923 MB)
  4.709045 seconds (2 allocations: 9.537 MB)
  2.694803 seconds, 100.00% gc time

  8.482212 seconds (15.30 M allocations: 765.923 MB)
  4.322303 seconds (2 allocations: 9.537 MB)
  2.330776 seconds, 100.00% gc time

  7.022945 seconds (15.30 M allocations: 765.923 MB)
  4.480007 seconds (2 allocations: 9.537 MB)
  2.261318 seconds, 100.00% gc time

  6.858507 seconds (15.30 M allocations: 765.923 MB)
  4.340702 seconds (2 allocations: 9.537 MB)
  2.283254 seconds, 100.00% gc time

  7.039293 seconds (15.30 M allocations: 765.923 MB)
  4.427812 seconds (2 allocations: 9.537 MB)
  2.270358 seconds, 100.00% gc time

  6.904196 seconds (15.30 M allocations: 765.923 MB)
  4.305911 seconds (2 allocations: 9.537 MB)
  2.345520 seconds, 100.00% gc time

  6.593265 seconds (15.30 M allocations: 765.923 MB)
  4.251790 seconds (2 allocations: 9.537 MB)
  2.277189 seconds, 100.00% gc time

  6.617482 seconds (15.30 M allocations: 765.923 MB)
  4.410888 seconds (2 allocations: 9.537 MB)
  2.478191 seconds, 100.00% gc time

jamie@wanderer:~/code/imp$ perf stat -e cycles,instructions,branches,branch-misses,context-switches,cache-references,cache-misses -p 8445
^C
 Performance counter stats for process id '8445':

   398,054,461,640      cycles                                                        (66.66%)
   132,453,050,158      instructions              #    0.33  insns per cycle          (83.33%)
    21,660,806,420      branches                                                      (83.33%)
       375,102,742      branch-misses             #    1.73% of all branches          (83.34%)
             1,341      context-switches
     3,932,521,463      cache-references                                              (83.34%)
     2,337,178,854      cache-misses              #   59.432 % of all cache refs      (83.33%)
```

```
jamie@wanderer:~/code/imp$ perf stat -e cycles,instructions,branches,branch-misses,context-switches,cache-references,cache-misses target/release/imp
3.5180486560002464s for insert
2.8689307719996577s for lookup
2.254919785000311s for drop
6.634633460000259s for insert
3.2209488700000293s for lookup
2.691355521999867s for drop
5.714246575999823s for insert
3.3670170309997047s for lookup
2.601664489999166s for drop
6.162275493000379s for insert
4.827575713999977s for lookup
2.969592765000016s for drop
6.158259736000218s for insert
3.1756934750001165s for lookup
2.7672535319998133s for drop
5.674778747000346s for insert
3.1917649069991967s for lookup
2.652667846999975s for drop
5.5488982560000295s for insert
3.4133420640000622s for lookup
2.7529494509999495s for drop
5.82873814300001s for insert
3.2499250539995046s for lookup
2.7247443930000372s for drop
5.960908308000398s for insert
3.437930901999607s for lookup
2.88357682700007s for drop
5.899732896999922s for insert
3.095586663999711s for lookup
2.583231364999847s for drop

 Performance counter stats for 'target/release/imp':

   344,024,562,305      cycles                                                        (66.66%)
   120,094,681,100      instructions              #    0.35  insns per cycle          (83.32%)
    19,321,743,906      branches                                                      (83.33%)
       329,449,114      branch-misses             #    1.71% of all branches          (83.33%)
             1,915      context-switches
     3,868,027,630      cache-references                                              (83.34%)
     2,160,131,618      cache-misses              #   55.846 % of all cache refs      (83.34%)
```

Julia is still slower. I have a version lying around that I compiled from source with debug symbols. Let's run that through the profiler and see if anything in the runtime looks suspicious.

```
jamie@wanderer:~/code/imp$ sudo perf record -p 10205
...
jamie@wanderer:~/code/imp$ sudo perf report
11.14%  julia    libjulia-debug.so  [.] gc_push_root
10.37%  julia    perf-10205.map     [.] 0x00007fd5ff08ba5c
10.03%  julia    perf-10205.map     [.] 0x00007fd5ff08b52d
 6.94%  julia    perf-10205.map     [.] 0x00007fd5ff08ba97
 6.62%  julia    perf-10205.map     [.] 0x00007fd5ff08b564
 4.77%  julia    perf-10205.map     [.] 0x00007fd5ff08b2fb
 4.53%  julia    perf-10205.map     [.] 0x00007fd5ff08ba90
 4.45%  julia    perf-10205.map     [.] 0x00007fd5ff08b55d
 3.14%  julia    libc-2.21.so       [.] __memmove_avx_unaligned
 3.04%  julia    libjulia-debug.so  [.] sweep_page
 2.95%  julia    libjulia-debug.so  [.] gc_setmark_pool
 2.93%  julia    libjulia-debug.so  [.] __pool_alloc
 2.81%  julia    libjulia-debug.so  [.] gc_setmark_buf
 1.85%  julia    libjulia-debug.so  [.] push_root
 1.78%  julia    perf-10205.map     [.] 0x00007fd5ff08bbcd
 1.71%  julia    perf-10205.map     [.] 0x00007fd5ff08bbc0
 1.39%  julia    perf-10205.map     [.] 0x00007fd5ff08b5cc
 1.34%  julia    libjulia-debug.so  [.] _new_array_
 1.32%  julia    perf-10205.map     [.] 0x00007fd5ff08b5c5
 0.97%  julia    perf-10205.map     [.] 0x00007fd5ff08adf6
 0.93%  julia    libc-2.21.so       [.] __memcpy_avx_unaligned
 0.74%  julia    libjulia-debug.so  [.] jl_array_grow_end
 0.58%  julia    libjulia-debug.so  [.] find_region
 0.55%  julia    perf-10205.map     [.] 0x00007fd5ff08b247
...
```

Not really. We already knew gc was about 20% of the cost. The hex values are jitted code ie not part of the runtime. Nothing else is that expensive.

Eugh, I forgot to remove one of the hashes in the Julia version. Julia's lookup is actually as slow as its insert, and 2x as slow as Rust's lookup. There must be something wrong in there somewhere.

Let's look at the ast for the lookup:

```
julia> @code_warntype in((UInt64(1),), tree)
Variables:
  row::Tuple{UInt64}
  tree::Tree{Tuple{UInt64}}
  node::Node{Tuple{UInt64}}
  #s4::Int64
  column::Int64
  value::UInt64
  key::UInt64
  #s1::Int64
  ix::Int64
  chunk::UInt64
  mask::Int64
  node_ix::Int64
  leaf_ix::Int64
  leaf::Tuple{UInt64}

Body:
  begin  # /home/jamie/code/imp/src/Hamt.jl, line 72: # /home/jamie/code/imp/src/Hamt.jl, line 73:
      node = (top(getfield))(tree::Tree{Tuple{UInt64}},:root)::Node{Tuple{UInt64}} # /home/jamie/code/imp/src/Hamt.jl, line 74:
      GenSym(4) = (Base.nfields)(row::Tuple{UInt64})::Int64
      GenSym(0) = $(Expr(:new, UnitRange{Int64}, 1, :(((top(getfield))(Base.Intrinsics,:select_value)::I)((Base.sle_int)(1,GenSym(4))::Bool,GenSym(4),(Base.box)(Int64,(Base.sub_int)(1,1)))::Int64)))
      #s4 = (top(getfield))(GenSym(0),:start)::Int64
      unless (Base.box)(Base.Bool,(Base.not_int)(#s4::Int64 === (Base.box)(Base.Int,(Base.add_int)((top(getfield))(GenSym(0),:stop)::Int64,1))::Bool)) goto 1
      2:
      GenSym(6) = #s4::Int64
      GenSym(7) = (Base.box)(Base.Int,(Base.add_int)(#s4::Int64,1))
      column = GenSym(6)
      #s4 = GenSym(7) # /home/jamie/code/imp/src/Hamt.jl, line 75:
      value = (Base.getfield)(row::Tuple{UInt64},column::Int64)::UInt64 # /home/jamie/code/imp/src/Hamt.jl, line 76:
      key = value::UInt64 # /home/jamie/code/imp/src/Hamt.jl, line 77:
      GenSym(5) = (Base.box)(Int64,(Base.sub_int)(Main.key_length,1))
      GenSym(2) = $(Expr(:new, UnitRange{Int64}, 0, :(((top(getfield))(Base.Intrinsics,:select_value)::I)((Base.sle_int)(0,GenSym(5))::Bool,GenSym(5),(Base.box)(Int64,(Base.sub_int)(0,1)))::Int64)))
      #s1 = (top(getfield))(GenSym(2),:start)::Int64
      unless (Base.box)(Base.Bool,(Base.not_int)(#s1::Int64 === (Base.box)(Base.Int,(Base.add_int)((top(getfield))(GenSym(2),:stop)::Int64,1))::Bool)) goto 5
      6:
      NewvarNode(:node_ix)
      NewvarNode(:leaf_ix)
      NewvarNode(:leaf)
      GenSym(8) = #s1::Int64
      GenSym(9) = (Base.box)(Base.Int,(Base.add_int)(#s1::Int64,1))
      ix = GenSym(8)
      #s1 = GenSym(9) # /home/jamie/code/imp/src/Hamt.jl, line 78:
      chunk = (Base.box)(UInt64,(Base.and_int)((Base.box)(UInt64,(Base.lshr_int)(key::UInt64,(Base.box)(Int64,(Base.mul_int)(ix::Int64,5)))),(Base.box)(UInt64,(Base.zext_int)(UInt64,0x1f)))) # /home/jamie/code/imp/src/Hamt.jl, line 79:
      mask = (Base.box)(Int64,(Base.shl_int)(1,chunk::UInt64)) # /home/jamie/code/imp/src/Hamt.jl, line 80:
      unless (Base.slt_int)(0,(Base.box)(Int64,(Base.and_int)((Base.box)(Int64,(Base.zext_int)(Int64,(top(getfield))(node::Node{Tuple{UInt64}},:node_bitmap)::UInt32)),mask::Int64)))::Bool goto 8 # /home/jamie/code/imp/src/Hamt.jl, line 81:
      node_ix = (Base.box)(Base.Int,(Base.add_int)(1,(Base.box)(Int64,(Base.zext_int)(Int64,(Base.box)(UInt32,(Base.ctpop_int)((Base.box)(UInt32,(Base.shl_int)((top(getfield))(node::Node{Tuple{UInt64}},:node_bitmap)::UInt32,(Base.box)(UInt64,(Base.sub_int)((Base.box)(UInt64,(Base.check_top_bit)(32)),chunk::UInt64)))))))))) # /home/jamie/code/imp/src/Hamt.jl, line 82:
      node = (Base.arrayref)((top(getfield))(node::Node{Tuple{UInt64}},:nodes)::Array{Node{Tuple{UInt64}},1},node_ix::Int64)::Node{Tuple{UInt64}}
      goto 10
      8:  # /home/jamie/code/imp/src/Hamt.jl, line 84:
      unless (Base.slt_int)(0,(Base.box)(Int64,(Base.and_int)((Base.box)(Int64,(Base.zext_int)(Int64,(top(getfield))(node::Node{Tuple{UInt64}},:leaf_bitmap)::UInt32)),mask::Int64)))::Bool goto 9 # /home/jamie/code/imp/src/Hamt.jl, line 85:
      leaf_ix = (Base.box)(Base.Int,(Base.add_int)(1,(Base.box)(Int64,(Base.zext_int)(Int64,(Base.box)(UInt32,(Base.ctpop_int)((Base.box)(UInt32,(Base.shl_int)((top(getfield))(node::Node{Tuple{UInt64}},:leaf_bitmap)::UInt32,(Base.box)(UInt64,(Base.sub_int)((Base.box)(UInt64,(Base.check_top_bit)(32)),chunk::UInt64)))))))))) # /home/jamie/code/imp/src/Hamt.jl, line 86:
      leaf = (Base.arrayref)((top(getfield))(node::Node{Tuple{UInt64}},:leaves)::Array{Tuple{UInt64},1},leaf_ix::Int64)::Tuple{UInt64} # /home/jamie/code/imp/src/Hamt.jl, line 87:
      return row::Tuple{UInt64} == leaf::Tuple{UInt64}::Bool
      goto 10
      9:  # /home/jamie/code/imp/src/Hamt.jl, line 89:
      return false
      10:
      7:
      unless (Base.box)(Base.Bool,(Base.not_int)((Base.box)(Base.Bool,(Base.not_int)(#s1::Int64 === (Base.box)(Base.Int,(Base.add_int)((top(getfield))(GenSym(2),:stop)::Int64,1))::Bool)))) goto 6
      5:
      4:
      3:
      unless (Base.box)(Base.Bool,(Base.not_int)((Base.box)(Base.Bool,(Base.not_int)(#s4::Int64 === (Base.box)(Base.Int,(Base.add_int)((top(getfield))(GenSym(0),:stop)::Int64,1))::Bool)))) goto 2
      1:
      0:  # /home/jamie/code/imp/src/Hamt.jl, line 93:
      return (Base.throw)(((top(getfield))((top(getfield))(Base.Main,:Base)::Any,:call)::Any)((top(getfield))((top(getfield))(Base.Main,:Base)::Any,:ErrorException)::Any,"Out of bits!")::Any)::Union{}
  end::Bool
```

All the types are correctly derived. There is a lot of boxing going on, but it disappears by the time we reach LLVM IR:

```
define i1 @julia_in_22401([1 x i64]*, %jl_value_t*) {
pass:
  %row = alloca [1 x i64], align 8
  %leaf = alloca [1 x i64], align 8
  %2 = alloca [6 x %jl_value_t*], align 8
  %.sub = getelementptr inbounds [6 x %jl_value_t*]* %2, i64 0, i64 0
  %3 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 2
  %4 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 3
  store %jl_value_t* inttoptr (i64 8 to %jl_value_t*), %jl_value_t** %.sub, align 8
  %5 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 1
  %6 = load %jl_value_t*** @jl_pgcstack, align 8
  %.c = bitcast %jl_value_t** %6 to %jl_value_t*
  store %jl_value_t* %.c, %jl_value_t** %5, align 8
  store %jl_value_t** %.sub, %jl_value_t*** @jl_pgcstack, align 8
  store %jl_value_t* null, %jl_value_t** %3, align 8
  store %jl_value_t* null, %jl_value_t** %4, align 8
  %7 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 4
  store %jl_value_t* null, %jl_value_t** %7, align 8
  %8 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 5
  store %jl_value_t* null, %jl_value_t** %8, align 8
  %9 = load [1 x i64]* %0, align 8
  store [1 x i64] %9, [1 x i64]* %row, align 8
  %10 = getelementptr inbounds %jl_value_t* %1, i64 0, i32 0
  %11 = load %jl_value_t** %10, align 8
  store %jl_value_t* %11, %jl_value_t** %3, align 8
  %12 = getelementptr [1 x i64]* %0, i64 0, i64 0
  %13 = load i64* %12, align 8
  br label %L2

L2:                                               ; preds = %pass5, %pass
  %14 = phi %jl_value_t* [ %11, %pass ], [ %45, %pass5 ]
  %"#s1.0" = phi i64 [ 0, %pass ], [ %48, %pass5 ]
  %15 = mul i64 %"#s1.0", 5
  %16 = ashr i64 %13, %15
  %17 = and i64 %16, 31
  %18 = shl i64 1, %17
  %19 = bitcast %jl_value_t* %14 to i8*
  %20 = getelementptr i8* %19, i64 4
  %21 = bitcast i8* %20 to i32*
  %22 = load i32* %21, align 4
  %23 = zext i32 %22 to i64
  %24 = and i64 %18, %23
  %25 = icmp eq i64 %24, 0
  br i1 %25, label %L6, label %if3

if3:                                              ; preds = %L2
  %26 = sub i64 32, %17
  %27 = trunc i64 %26 to i32
  %28 = shl i32 %22, %27
  %29 = icmp ugt i64 %26, 31
  %30 = select i1 %29, i32 0, i32 %28
  %31 = call i32 @llvm.ctpop.i32(i32 %30)
  %32 = zext i32 %31 to i64
  %33 = getelementptr inbounds %jl_value_t* %14, i64 2, i32 0
  %34 = load %jl_value_t** %33, align 8
  %35 = getelementptr inbounds %jl_value_t* %34, i64 1
  %36 = bitcast %jl_value_t* %35 to i64*
  %37 = load i64* %36, align 8
  %38 = icmp ult i64 %32, %37
  br i1 %38, label %idxend, label %oob

oob:                                              ; preds = %if3
  %39 = add i64 %32, 1
  %40 = alloca i64, align 8
  store i64 %39, i64* %40, align 8
  call void @jl_bounds_error_ints(%jl_value_t* %34, i64* %40, i64 1)
  unreachable

idxend:                                           ; preds = %if3
  %41 = bitcast %jl_value_t* %34 to i8**
  %42 = load i8** %41, align 8
  %43 = bitcast i8* %42 to %jl_value_t**
  %44 = getelementptr %jl_value_t** %43, i64 %32
  %45 = load %jl_value_t** %44, align 8
  %46 = icmp eq %jl_value_t* %45, null
  br i1 %46, label %fail4, label %pass5

fail4:                                            ; preds = %idxend
  %47 = load %jl_value_t** @jl_undefref_exception, align 8
  call void @jl_throw_with_superfluous_argument(%jl_value_t* %47, i32 82)
  unreachable

pass5:                                            ; preds = %idxend
  %48 = add i64 %"#s1.0", 1
  store %jl_value_t* %45, %jl_value_t** %3, align 8
  %49 = icmp eq i64 %"#s1.0", 12
  br i1 %49, label %L17, label %L2

L6:                                               ; preds = %L2
  %50 = bitcast %jl_value_t* %14 to i32*
  %51 = load i32* %50, align 16
  %52 = zext i32 %51 to i64
  %53 = and i64 %52, %18
  %54 = icmp eq i64 %53, 0
  br i1 %54, label %L11, label %if7

if7:                                              ; preds = %L6
  %55 = sub i64 32, %17
  %56 = trunc i64 %55 to i32
  %57 = shl i32 %51, %56
  %58 = icmp ugt i64 %55, 31
  %59 = select i1 %58, i32 0, i32 %57
  %60 = call i32 @llvm.ctpop.i32(i32 %59)
  %61 = zext i32 %60 to i64
  %62 = getelementptr inbounds %jl_value_t* %14, i64 1, i32 0
  %63 = load %jl_value_t** %62, align 8
  %64 = getelementptr inbounds %jl_value_t* %63, i64 1
  %65 = bitcast %jl_value_t* %64 to i64*
  %66 = load i64* %65, align 8
  %67 = icmp ult i64 %61, %66
  br i1 %67, label %idxend9, label %oob8

oob8:                                             ; preds = %if7
  %68 = add i64 %61, 1
  %69 = alloca i64, align 8
  store i64 %68, i64* %69, align 8
  call void @jl_bounds_error_ints(%jl_value_t* %63, i64* %69, i64 1)
  unreachable

idxend9:                                          ; preds = %if7
  %70 = bitcast %jl_value_t* %63 to i8**
  %71 = load i8** %70, align 8
  %72 = bitcast i8* %71 to [1 x i64]*
  %73 = getelementptr [1 x i64]* %72, i64 %61
  %74 = load [1 x i64]* %73, align 8
  store [1 x i64] %74, [1 x i64]* %leaf, align 8
  %75 = call i1 @"julia_==540"([1 x i64]* %row, [1 x i64]* %leaf)
  %76 = load %jl_value_t** %5, align 8
  %77 = getelementptr inbounds %jl_value_t* %76, i64 0, i32 0
  store %jl_value_t** %77, %jl_value_t*** @jl_pgcstack, align 8
  ret i1 %75

L11:                                              ; preds = %L6
  %78 = load %jl_value_t** %5, align 8
  %79 = getelementptr inbounds %jl_value_t* %78, i64 0, i32 0
  store %jl_value_t** %79, %jl_value_t*** @jl_pgcstack, align 8
  ret i1 false

L17:                                              ; preds = %pass5
  %80 = load %jl_value_t** inttoptr (i64 139773691732392 to %jl_value_t**), align 8
  store %jl_value_t* %80, %jl_value_t** %4, align 8
  store %jl_value_t* inttoptr (i64 139782383826328 to %jl_value_t*), %jl_value_t** %7, align 8
  %81 = call %jl_value_t* @jl_f_get_field(%jl_value_t* null, %jl_value_t** %4, i32 2)
  store %jl_value_t* %81, %jl_value_t** %4, align 8
  store %jl_value_t* inttoptr (i64 139782383820776 to %jl_value_t*), %jl_value_t** %7, align 8
  %82 = call %jl_value_t* @jl_f_get_field(%jl_value_t* null, %jl_value_t** %4, i32 2)
  store %jl_value_t* %82, %jl_value_t** %4, align 8
  %83 = load %jl_value_t** inttoptr (i64 139773691732392 to %jl_value_t**), align 8
  store %jl_value_t* %83, %jl_value_t** %7, align 8
  store %jl_value_t* inttoptr (i64 139782383826328 to %jl_value_t*), %jl_value_t** %8, align 8
  %84 = call %jl_value_t* @jl_f_get_field(%jl_value_t* null, %jl_value_t** %7, i32 2)
  store %jl_value_t* %84, %jl_value_t** %7, align 8
  store %jl_value_t* inttoptr (i64 139782383893576 to %jl_value_t*), %jl_value_t** %8, align 8
  %85 = call %jl_value_t* @jl_f_get_field(%jl_value_t* null, %jl_value_t** %7, i32 2)
  store %jl_value_t* %85, %jl_value_t** %7, align 8
  store %jl_value_t* inttoptr (i64 139773758179264 to %jl_value_t*), %jl_value_t** %8, align 8
  %86 = getelementptr inbounds %jl_value_t* %82, i64 -1, i32 0
  %87 = load %jl_value_t** %86, align 8
  %88 = ptrtoint %jl_value_t* %87 to i64
  %89 = and i64 %88, -16
  %90 = inttoptr i64 %89 to %jl_value_t*
  %91 = icmp eq %jl_value_t* %90, inttoptr (i64 139773691822656 to %jl_value_t*)
  br i1 %91, label %isf, label %notf

isf:                                              ; preds = %L17
  %92 = bitcast %jl_value_t* %82 to %jl_value_t* (%jl_value_t*, %jl_value_t**, i32)**
  %93 = load %jl_value_t* (%jl_value_t*, %jl_value_t**, i32)** %92, align 8
  %94 = call %jl_value_t* %93(%jl_value_t* %82, %jl_value_t** %7, i32 2)
  br label %fail18

notf:                                             ; preds = %L17
  %95 = call %jl_value_t* @jl_apply_generic(%jl_value_t* inttoptr (i64 139773716284272 to %jl_value_t*), %jl_value_t** %4, i32 3)
  br label %fail18

fail18:                                           ; preds = %notf, %isf
  %96 = phi %jl_value_t* [ %94, %isf ], [ %95, %notf ]
  call void @jl_throw_with_superfluous_argument(%jl_value_t* %96, i32 93)
  unreachable
}
```

That's a lot of code. I learned a lot more llvm commands today than I planned to.

First thing I notice:

```
julia> x = UInt32(0)
0x00000000

julia> @code_llvm (x << 32)

define i32 @"julia_<<_21947"(i32, i64) {
top:
  %2 = trunc i64 %1 to i32
  %3 = shl i32 %0, %2
  %4 = icmp ugt i64 %1, 31
  %5 = select i1 %4, i32 0, i32 %3
  ret i32 %5
}

julia> @code_native (x << 32)
	.text
Filename: int.jl
Source line: 109
	pushq	%rbp
	movq	%rsp, %rbp
Source line: 109
	movb	%sil, %cl
	shll	%cl, %edi
	xorl	%eax, %eax
	cmpq	$31, %rsi
	cmovbel	%edi, %eax
	popq	%rbp
	ret
```

There is some extra logic in [shl_int](https://github.com/JuliaLang/julia/blob/15cae8649392195e6c5cb5a31eac87b4b49b2a85/src/intrinsics.cpp#L1332-L1339) to handle the case where the shift amount is more than the number of bits. Compare this to js:

```
jamie@wanderer:~$ nodejs
> 42 << 64
42
```

That was a nasty surprise earlier this year - js just masks off all but the bottom 5 bits. [Apparently C is free to do this too](http://stackoverflow.com/questions/7401888/why-doesnt-left-bit-shift-for-32-bit-integers-work-as-expected-when-used).

```
%46 = icmp eq %jl_value_t* %45, null
br i1 %46, label %fail4, label %pass5

fail4:                                            ; preds = %idxend
%47 = load %jl_value_t** @jl_undefref_exception, align 8
call void @jl_throw_with_superfluous_argument(%jl_value_t* %47, i32 82)
unreachable
```

Null check on `node = node.nodes[node_ix]`. Can I put nulls in arrays?

```
julia> Vector(3)
3-element Array{Any,1}:
 #undef
 #undef
 #undef
```

Yep.

```
%row = alloca [1 x i64], align 8
%leaf = alloca [1 x i64], align 8
%2 = alloca [6 x %jl_value_t*], align 8
%.sub = getelementptr inbounds [6 x %jl_value_t*]* %2, i64 0, i64 0
%3 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 2
%4 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 3
store %jl_value_t* inttoptr (i64 8 to %jl_value_t*), %jl_value_t** %.sub, align 8
%5 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 1
%6 = load %jl_value_t*** @jl_pgcstack, align 8
%.c = bitcast %jl_value_t** %6 to %jl_value_t*
store %jl_value_t* %.c, %jl_value_t** %5, align 8
store %jl_value_t** %.sub, %jl_value_t*** @jl_pgcstack, align 8
store %jl_value_t* null, %jl_value_t** %3, align 8
store %jl_value_t* null, %jl_value_t** %4, align 8
%7 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 4
store %jl_value_t* null, %jl_value_t** %7, align 8
%8 = getelementptr [6 x %jl_value_t*]* %2, i64 0, i64 5
store %jl_value_t* null, %jl_value_t** %8, align 8
```

Embedding a linked list in the stack, I think? It allocates stack space for the row and leaf tuples, and then for 6 pointers. The first pointer is set to 8 (ie the size of this stack frame), the second pointer is set to jl_pgcstack and jl_pgcstack is set to point at the first pointer.

```
%75 = call i1 @"julia_==540"([1 x i64]* %row, [1 x i64]* %leaf)
```

`chunk_at` was inlined but `row == leaf` was not. Maybe llvm will decide to inline it later? Replacing it with `row[1] == leaf[1]` has little impact.

The IR for the Rust version (with debug info stripped) is:

```
define internal fastcc zeroext i1 @"_ZN3map15Tree$LT$u64$GT$8contains20h0b90de763b72ec39YnaE"(%"map::Tree<u64>"* noalias nocapture readonly dereferenceable(8), i64* noalias nonnull readonly, i64) unnamed_addr #9 {
entry-block:
  %3 = icmp eq i64 %2, 0, !dbg !50185
  br i1 %3, label %clean_ast_26544_25, label %match_case.lr.ph, !dbg !50187

match_case.lr.ph:                                 ; preds = %entry-block
  %4 = getelementptr inbounds %"map::Tree<u64>", %"map::Tree<u64>"* %0, i64 0, i32 0, !dbg !50173
  br label %"_ZN5slice36_$u5b$T$u5d$.ops..Index$LT$usize$GT$5index5index21h17911719332607156456E.exit", !dbg !50187

loop_body.loopexit:                               ; preds = %"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit"
  %.lcssa227 = phi %"map::Node<u64>"** [ %29, %"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit" ]
  %5 = icmp ult i64 %6, %2, !dbg !50185
  br i1 %5, label %"_ZN5slice36_$u5b$T$u5d$.ops..Index$LT$usize$GT$5index5index21h17911719332607156456E.exit", label %clean_ast_26544_25.loopexit, !dbg !50187

"_ZN5slice36_$u5b$T$u5d$.ops..Index$LT$usize$GT$5index5index21h17911719332607156456E.exit": ; preds = %loop_body.loopexit, %match_case.lr.ph
  %node.0167 = phi %"map::Node<u64>"** [ %4, %match_case.lr.ph ], [ %.lcssa227, %loop_body.loopexit ]
  %.sroa.0125.0..val.i145166 = phi i64 [ 0, %match_case.lr.ph ], [ %6, %loop_body.loopexit ]
  %6 = add nuw i64 %.sroa.0125.0..val.i145166, 1, !dbg !50191
  %7 = getelementptr inbounds i64, i64* %1, i64 %.sroa.0125.0..val.i145166, !dbg !50212
  %8 = load i64, i64* %7, align 8, !dbg !50213
  br label %match_case13, !dbg !50218

match_case13:                                     ; preds = %"_ZN5slice36_$u5b$T$u5d$.ops..Index$LT$usize$GT$5index5index21h17911719332607156456E.exit", %"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit"
  %node.1165 = phi %"map::Node<u64>"** [ %node.0167, %"_ZN5slice36_$u5b$T$u5d$.ops..Index$LT$usize$GT$5index5index21h17911719332607156456E.exit" ], [ %29, %"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit" ]
  %.sroa.0105.0..val.i.80141164 = phi i64 [ 0, %"_ZN5slice36_$u5b$T$u5d$.ops..Index$LT$usize$GT$5index5index21h17911719332607156456E.exit" ], [ %9, %"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit" ]
  %9 = add nuw nsw i64 %.sroa.0105.0..val.i.80141164, 1, !dbg !50222
  %10 = mul nuw nsw i64 %.sroa.0105.0..val.i.80141164, 5, !dbg !50229
  %11 = lshr i64 %8, %10, !dbg !50229
  %.tr.i = trunc i64 %11 to i32, !dbg !50229
  %12 = and i32 %.tr.i, 31, !dbg !50229
  %13 = shl i32 1, %12, !dbg !50231
  %14 = load %"map::Node<u64>"*, %"map::Node<u64>"** %node.1165, align 8, !dbg !50232, !nonnull !361
  %15 = getelementptr inbounds %"map::Node<u64>", %"map::Node<u64>"* %14, i64 0, i32 2, !dbg !50232
  %16 = load i32, i32* %15, align 4, !dbg !50232
  %17 = and i32 %16, %13, !dbg !50232
  %18 = icmp eq i32 %17, 0, !dbg !50232
  br i1 %18, label %else-block, label %then-block-921-, !dbg !50232

then-block-921-:                                  ; preds = %match_case13
  %19 = zext i32 %16 to i64, !dbg !50235
  %20 = sub nsw i32 32, %12, !dbg !50235
  %21 = zext i32 %20 to i64, !dbg !50235
  %22 = shl i64 %19, %21, !dbg !50235
  %23 = trunc i64 %22 to i32, !dbg !50235
  %24 = tail call i32 @llvm.ctpop.i32(i32 %23) #1, !dbg !50238
  %25 = zext i32 %24 to i64, !dbg !50239
  %26 = getelementptr inbounds %"map::Node<u64>", %"map::Node<u64>"* %14, i64 0, i32 4, !dbg !50240
  %27 = load %"map::JuliaArray<Box<map::Node<u64>>>"*, %"map::JuliaArray<Box<map::Node<u64>>>"** %26, align 8, !dbg !50240, !nonnull !361
  %.idx79 = getelementptr %"map::JuliaArray<Box<map::Node<u64>>>", %"map::JuliaArray<Box<map::Node<u64>>>"* %27, i64 0, i32 1, i32 1
  %.idx79.val = load i64, i64* %.idx79, align 8, !alias.scope !50242
  %28 = icmp ugt i64 %.idx79.val, %25, !dbg !50253
  br i1 %28, label %"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit", label %cond.i, !dbg !50240, !prof !47339

cond.i:                                           ; preds = %then-block-921-
  %.idx79.val.lcssa = phi i64 [ %.idx79.val, %then-block-921- ]
  %.lcssa224 = phi i64 [ %25, %then-block-921- ]
  tail call void @_ZN9panicking18panic_bounds_check20h2760eb7b4877ebd5RmKE({ %str_slice, i32 }* noalias nonnull readonly dereferenceable(24) @panic_bounds_check_loc12605, i64 %.lcssa224, i64 %.idx79.val.lcssa), !dbg !50253
  unreachable, !dbg !50253

"_ZN3vec31Vec$LT$T$GT$.Index$LT$usize$GT$5index5index20h7209727245129996211E.exit": ; preds = %then-block-921-
  %.idx78 = getelementptr %"map::JuliaArray<Box<map::Node<u64>>>", %"map::JuliaArray<Box<map::Node<u64>>>"* %27, i64 0, i32 1, i32 0, i32 0, i32 0, i32 0
  %.idx78.val = load %"map::Node<u64>"**, %"map::Node<u64>"*** %.idx78, align 8, !alias.scope !50254
  %29 = getelementptr inbounds %"map::Node<u64>"*, %"map::Node<u64>"** %.idx78.val, i64 %25, !dbg !50253
  %30 = icmp ult i64 %9, 13, !dbg !50259
  br i1 %30, label %match_case13, label %loop_body.loopexit, !dbg !50218

else-block:                                       ; preds = %match_case13
  %.lcssa221 = phi %"map::Node<u64>"* [ %14, %match_case13 ]
  %.lcssa218 = phi i32 [ %13, %match_case13 ]
  %.lcssa = phi i32 [ %12, %match_case13 ]
  %31 = getelementptr inbounds %"map::Node<u64>", %"map::Node<u64>"* %.lcssa221, i64 0, i32 1, !dbg !50261
  %32 = load i32, i32* %31, align 4, !dbg !50261
  %33 = and i32 %32, %.lcssa218, !dbg !50261
  %34 = icmp eq i32 %33, 0, !dbg !50261
  br i1 %34, label %clean_ast_897_, label %then-block-951-, !dbg !50261

then-block-951-:                                  ; preds = %else-block
  %35 = zext i32 %32 to i64, !dbg !50272
  %36 = sub nsw i32 32, %.lcssa, !dbg !50272
  %37 = zext i32 %36 to i64, !dbg !50272
  %38 = shl i64 %35, %37, !dbg !50272
  %39 = trunc i64 %38 to i32, !dbg !50272
  %40 = tail call i32 @llvm.ctpop.i32(i32 %39) #1, !dbg !50275
  %41 = zext i32 %40 to i64, !dbg !50276
  %42 = mul i64 %41, %2, !dbg !50276
  %43 = getelementptr inbounds %"map::Node<u64>", %"map::Node<u64>"* %.lcssa221, i64 0, i32 3, !dbg !50277
  %44 = load %"map::JuliaArray<u64>"*, %"map::JuliaArray<u64>"** %43, align 8, !dbg !50277, !nonnull !361
  %45 = add i64 %42, %2, !dbg !50277
  %.idx = getelementptr %"map::JuliaArray<u64>", %"map::JuliaArray<u64>"* %44, i64 0, i32 1, i32 0, i32 0, i32 0, i32 0
  %.idx.val = load i64*, i64** %.idx, align 8
  %.idx75 = getelementptr %"map::JuliaArray<u64>", %"map::JuliaArray<u64>"* %44, i64 0, i32 1, i32 1
  %.idx75.val = load i64, i64* %.idx75, align 8
  %46 = icmp ult i64 %45, %42, !dbg !50295
  br i1 %46, label %then-block-37390-.i.i, label %else-block.i.i, !dbg !50295

then-block-37390-.i.i:                            ; preds = %then-block-951-
  tail call void @_ZN5slice22slice_index_order_fail20h86e0cbc11bd0c115C8NE(i64 %42, i64 %45), !dbg !50296, !noalias !50298
  unreachable, !dbg !50296

else-block.i.i:                                   ; preds = %then-block-951-
  %47 = icmp ugt i64 %45, %.idx75.val, !dbg !50309
  br i1 %47, label %then-block-37404-.i.i, label %"_ZN3vec54Vec$LT$T$GT$.ops..Index$LT$ops..Range$LT$usize$GT$$GT$5index5index21h10954783785114391776E.exit", !dbg !50309

then-block-37404-.i.i:                            ; preds = %else-block.i.i
  tail call void @_ZN5slice20slice_index_len_fail20h0426121f8200b444C7NE(i64 %45, i64 %.idx75.val), !dbg !50316, !noalias !50298
  unreachable, !dbg !50316

"_ZN3vec54Vec$LT$T$GT$.ops..Index$LT$ops..Range$LT$usize$GT$$GT$5index5index21h10954783785114391776E.exit": ; preds = %else-block.i.i
  %48 = getelementptr inbounds i64, i64* %.idx.val, i64 %42, !dbg !50325
  br label %loop_body.i.i, !dbg !50343

loop_body.i.i:                                    ; preds = %"_ZN3vec54Vec$LT$T$GT$.ops..Index$LT$ops..Range$LT$usize$GT$$GT$5index5index21h10954783785114391776E.exit", %next.i.i
  %.sroa.037.0..val.i46.i.i = phi i64 [ %50, %next.i.i ], [ 0, %"_ZN3vec54Vec$LT$T$GT$.ops..Index$LT$ops..Range$LT$usize$GT$$GT$5index5index21h10954783785114391776E.exit" ], !dbg !50344
  %49 = icmp ult i64 %.sroa.037.0..val.i46.i.i, %2, !dbg !50347
  br i1 %49, label %next.i.i, label %clean_ast_897_.loopexit, !dbg !50349

next.i.i:                                         ; preds = %loop_body.i.i
  %50 = add i64 %.sroa.037.0..val.i46.i.i, 1, !dbg !50353
  %51 = getelementptr inbounds i64, i64* %1, i64 %.sroa.037.0..val.i46.i.i, !dbg !50374
  %52 = getelementptr inbounds i64, i64* %48, i64 %.sroa.037.0..val.i46.i.i, !dbg !50375
  %.val.i.i = load i64, i64* %51, align 8, !dbg !50344, !alias.scope !50376, !noalias !50379
  %.val26.i.i = load i64, i64* %52, align 8, !dbg !50344, !alias.scope !50379, !noalias !50376
  %53 = icmp eq i64 %.val.i.i, %.val26.i.i, !dbg !50381
  br i1 %53, label %loop_body.i.i, label %clean_ast_897_.loopexit, !dbg !50375

clean_ast_897_.loopexit:                          ; preds = %loop_body.i.i, %next.i.i
  %sret_slot.0.ph = phi i1 [ false, %next.i.i ], [ true, %loop_body.i.i ]
  br label %clean_ast_897_, !dbg !50383

clean_ast_897_:                                   ; preds = %clean_ast_897_.loopexit, %else-block
  %sret_slot.0 = phi i1 [ false, %else-block ], [ %sret_slot.0.ph, %clean_ast_897_.loopexit ]
  ret i1 %sret_slot.0, !dbg !50383

clean_ast_26544_25.loopexit:                      ; preds = %loop_body.loopexit
  br label %clean_ast_26544_25, !dbg !50384

clean_ast_26544_25:                               ; preds = %clean_ast_26544_25.loopexit, %entry-block
  tail call fastcc void @_ZN10sys_common6unwind12begin_unwind12begin_unwind20h7713200070592497824E(i8* noalias nonnull readonly getelementptr inbounds ([12 x i8], [12 x i8]* @str12911, i64 0, i64 0), i64 12, { %str_slice, i32 }* noalias readonly dereferenceable(24) bitcast ({ %str_slice, i32, [4 x i8] }* @"_ZN3map15Tree$LT$u64$GT$8contains10_FILE_LINE20h198f9582d21749b0fqaE" to { %str_slice, i32 }*)), !dbg !50384
  unreachable, !dbg !50384
}
```

The first thing that jumps out at me is that it's way more typed. The Julia AST had all the types it needed, but discards them by the time it reaches LLVM eg:

```
Rust
%26 = getelementptr inbounds %"map::Node<u64>", %"map::Node<u64>"* %14, i64 0, i32 4, !dbg !50240
%27 = load %"map::JuliaArray<Box<map::Node<u64>>>"*, %"map::JuliaArray<Box<map::Node<u64>>>"** %26, align 8, !dbg !50240, !nonnull !361

Julia
%33 = getelementptr inbounds %jl_value_t* %14, i64 2, i32 0
%34 = load %jl_value_t** %33, align 8
```

It also has a lot more metadata about aliasing, nulls, mutability etc.

I don't know how much any of that makes a difference. If it generates better assembly, it's not showing up in the performance counters.

So that's where I'm at for today. Both versions use similar data layouts, generate similar code, use similar amounts of memory and show similar numbers of instructions executed, branches taken/missed and cache references/misses. But one of them is consistently twice as fast as the other.

```
Performance counter stats for '../target/release/imp':

  101,828,660,572      cycles                                                        (66.65%)
   26,539,799,614      instructions              #    0.26  insns per cycle          (83.32%)
    4,320,044,658      branches                                                      (83.33%)
       59,527,376      branch-misses             #    1.38% of all branches          (83.34%)
              326      context-switches
    1,250,325,036      cache-references                                              (83.33%)
      926,747,895      cache-misses              #   74.121 % of all cache refs      (83.34%)

     36.120043773 seconds time elapsed

Performance counter stats for process id '16164':

  150,210,926,888      cycles                                                        (66.66%)
   31,434,058,110      instructions              #    0.21  insns per cycle          (83.33%)
    4,811,978,240      branches                                                      (83.33%)
       57,565,871      branch-misses             #    1.20% of all branches          (83.34%)
              521      context-switches
    1,324,801,988      cache-references                                              (83.34%)
      920,160,263      cache-misses              #   69.456 % of all cache refs      (83.33%)

     59.871103895 seconds time elapsed
```

### Unsafe nodes

Julia has a bunch of limitations that are making this difficult:

* No fixed-length mutable arrays
* Pointerful types are not stored inline
* Limited control over specialization
* No shared layout between types (see the discussion on [struct inheritance in Rust](https://github.com/rust-lang/rfcs/issues/349))

I work around the first two problems by generating custom types that have the layout I want:

``` julia
# equivalent to:
# type Node{N}
#   bitmap::UInt32
#   nodes::NTuple{N, Node} # <- this needs to be stored inline
# end

abstract Node

macro node(n)
  :(begin
  type $(symbol("Node", n)) <: Node
    bitmap::UInt32
    $([symbol("node", i) for i in 1:n]...)
  end
end)
end

# aims to fit into pool sizes - see https://github.com/JuliaLang/julia/blob/6cc48dcd24322976bdc193b3c578acb924f0b8e9/src/gc.c#L1308-L1336
@node(2)
@node(4)
@node(8)
@node(16)
@node(32)
```

I work around the last two problems by hiding the type behind a raw pointer and using my own knowledge of the layout to manually access data:


``` julia
@inline get_node(node::Ptr{Void}, pos::Integer) = begin
  convert(Ptr{Node}, node + nodes_offset + ((pos-1) * sizeof(Ptr)))
end

@inline set_node!(node::Ptr{Void}, val::Ptr{Void}, pos::Integer) = begin
  unsafe_store!(convert(Ptr{Ptr{Void}}, get_node(node, pos)), val)
end
```

I also have to allocate memory and manage write barriers myself, which took a while to get right:

``` julia
@inline is_marked(val_pointer::Ptr{Void}) = begin
  (unsafe_load(convert(Ptr{UInt}, val_pointer), 0) & UInt(1)) == UInt(1)
end

@inline gc_write_barrier(parent_pointer::Ptr{Void}, child_pointer::Ptr{Void}) = begin
  if (is_marked(parent_pointer) && !is_marked(child_pointer))
    ccall((:jl_gc_queue_root, :libjulia), Void, (Ptr{Void},), parent_pointer)
  end
end

grow(parent_pointer::Ptr{Void}, node_pointer::Ptr{Node}, size_before::Integer, size_after::Integer, type_after::Type) = begin
  node_before = unsafe_load(convert(Ptr{Ptr{UInt8}}, node_pointer))
  node_after = ccall((:jl_gc_allocobj, :libjulia), Ptr{UInt8}, (Csize_t,), size_after)
  unsafe_store!(convert(Ptr{Ptr{Void}}, node_after), pointer_from_objref(type_after), 0)
  for i in 1:size_before
    unsafe_store!(node_after, unsafe_load(node_before, i), i)
  end
  for i in (size_before+1):size_after
    unsafe_store!(node_after, 0, i)
  end
  unsafe_store!(convert(Ptr{Ptr{UInt8}}, node_pointer), node_after)
  gc_write_barrier(parent_pointer, convert(Ptr{Void}, node_after))
  return
end
```

I could still inline rows into the node structure by generating custom nodes for each row type (bring on [generated types](https://github.com/JuliaLang/julia/issues/8472) already!) but for now I'm just leaving them individually boxed. I'm not happy with how much gc overhead that creates but it will do for now.

The code is currently messy and gross because I just hacked on it until it worked, but it could be cleaned up if I decide to commit to this route. Writing unsafe code like this in Julia isn't actually that hard (except that I keep forgetting that most types in Julia are boxed). It's much easier to debug memory corruption when you can just poke around in the repl and view raw memory interactively.

I had much more trouble with tracking down allocations in the safe code eg I started by using tuples for rows, but even when they were boxed initially and were going to be boxed in the tree, they were often unboxed in intervening code which causes extra allocations when they have to be reboxed. In the end I just gave up and created custom row types again. (Note to self: Julia tuples are for multiple return, not for data-structures. Stop putting them in data-structures.) I think at some point I would benefit from writing a linting macro that warns me if anootated functions contain allocations or generic dispatch.

There were a few other minor problems. Julia does not have a switch statement and LLVM does not manage to turn this code into a computed goto:

``` julia
# TODO figure out how to get a computed goto out of this
maybe_grow(parent_pointer::Ptr{Void}, node_pointer::Ptr{Node}, length::Integer) = begin
  if length == 2
    grow(parent_pointer, node_pointer, sizeof(Node2), sizeof(Node4), Node4)
  elseif length == 4
    grow(parent_pointer, node_pointer, sizeof(Node4), sizeof(Node8), Node8)
  elseif length == 8
    grow(parent_pointer, node_pointer, sizeof(Node8), sizeof(Node16), Node16)
  elseif length == 16
    grow(parent_pointer, node_pointer, sizeof(Node16), sizeof(Node32), Node32)
  end
  return
end
```

```
julia> code_llvm(Hamt.maybe_grow, (Ptr{Void}, Ptr{Hamt.Node}, Int))

define void @julia_maybe_grow_21919(i8*, %jl_value_t**, i64) {
top:
  %3 = icmp eq i64 %2, 2
  br i1 %3, label %if, label %L

if:                                               ; preds = %top
  %4 = load %jl_value_t** inttoptr (i64 140243957646200 to %jl_value_t**), align 8
  call void @julia_grow_21920(i8* %0, %jl_value_t** %1, i64 24, i64 40, %jl_value_t* %4)
  br label %L8

L:                                                ; preds = %top
  %5 = icmp eq i64 %2, 4
  br i1 %5, label %if1, label %L3

if1:                                              ; preds = %L
  %6 = load %jl_value_t** inttoptr (i64 140243957646248 to %jl_value_t**), align 8
  call void @julia_grow_21920(i8* %0, %jl_value_t** %1, i64 40, i64 72, %jl_value_t* %6)
  br label %L8

L3:                                               ; preds = %L
  %7 = icmp eq i64 %2, 8
  br i1 %7, label %if4, label %L6

if4:                                              ; preds = %L3
  %8 = load %jl_value_t** inttoptr (i64 140243957646296 to %jl_value_t**), align 8
  call void @julia_grow_21920(i8* %0, %jl_value_t** %1, i64 72, i64 136, %jl_value_t* %8)
  br label %L8

L6:                                               ; preds = %L3
  %9 = icmp eq i64 %2, 16
  br i1 %9, label %if7, label %L8

if7:                                              ; preds = %L6
  %10 = load %jl_value_t** inttoptr (i64 140243957646344 to %jl_value_t**), align 8
  call void @julia_grow_21920(i8* %0, %jl_value_t** %1, i64 136, i64 264, %jl_value_t* %10)
  br label %L8

L8:                                               ; preds = %if7, %L6, %if4, %if1, %if
  ret void
}
```

Complex ranges don't seem to inline very well eg this loop compiles to code which still has a function call handling the range:

``` julia
for i in length:-1:pos
  set_node!(node, unsafe_load(convert(Ptr{Ptr{Void}}, get_node(node, i))), i+1)
end
```

```
pass:                                             ; preds = %if
  %30 = add i64 %17, 1
  %31 = load %jl_value_t** %0, align 1
  %32 = bitcast %jl_value_t* %31 to i8*
  %33 = trunc i64 %26 to i32
  %34 = bitcast %jl_value_t* %31 to i32*
  store i32 %33, i32* %34, align 1
  %35 = call i64 @julia_steprange_last3371(i64 %25, i64 -1, i64 %30)
  %36 = icmp slt i64 %25, %35
  %37 = add i64 %35, -1
  %38 = icmp eq i64 %25, %37
  %39 = or i1 %36, %38
  br i1 %39, label %L4, label %L.preheader.L.preheader.split_crit_edge
```

Apart from those two issues, and once I tracked down all the errant allocations, this approach compiles down to pretty tight assembly eg:

``` julia
get_child(node_pointer::Ptr{Node}, ix::Integer) = begin
  node = unsafe_load(convert(Ptr{Ptr{Void}}, node_pointer))
  bitmap = get_bitmap(node)
  if (bitmap & (UInt32(1) << ix)) == 0
    convert(Ptr{Node}, 0)
  else
    get_node(node, get_pos(bitmap, ix))
  end
end
```

```
julia> code_native(Hamt.get_child, (Ptr{Hamt.Node}, Int))
	.text
Filename: /home/jamie/code/imp/src/Hamt.jl
Source line: 98
	pushq	%rbp
	movq	%rsp, %rbp
	movl	$1, %eax
Source line: 98
	movb	%sil, %cl
	shll	%cl, %eax
	xorl	%r8d, %r8d
	cmpq	$31, %rsi
	cmoval	%r8d, %eax
Source line: 96
	movq	(%rdi), %rdx
Source line: 97
	movl	(%rdx), %edi
Source line: 98
	testl	%eax, %edi
	je	L67
	movl	$32, %ecx
Source line: 101
	subq	%rsi, %rcx
	shll	%cl, %edi
	cmpq	$31, %rcx
	cmoval	%r8d, %edi
	popcntl	%edi, %eax
	leaq	8(%rdx,%rax,8), %rax
	popq	%rbp
	ret
L67:	xorl	%eax, %eax
Source line: 99
	popq	%rbp
	ret
```

Performance-wise this has some interesting effects. The best Rust version so far does a full benchmark run in ~65s and peaks at 704MB RSS, or 115s and 1060MB RSS if I force it to use boxed rows. This Julia version takes 85s and peaks at 1279MB RSS, or 65s and 718MB RSS if I delay gc until after building (mutable trees seem to be a pessimal case for generational gcs - they are constantly creating pointers from the old generation into the new generation, requiring costly write barriers). Compare this to 32s for a Julia hashset or 51s for a sorted (and unboxed) Julia array, neither of which can handle prefix searches or persistence.

I'm still a little concerned about the interaction with the gc, but the performance in these crude benchmarks is totally acceptable, especially once I take into account that the Rust version would have to add reference counts once I make the trees semi-persistent and allow sharing data between multiple indexes.

I am frustrated by the amount of work this took. If Julia had fixed-size arrays and would inline pointerful types this could have just been:

``` julia
immutable Node
  bitmap: UInt32
  nodes: FixedArray{Node} # pointer to array of (bitmap, nodes pointer)
end
```

If I end up using Julia heavily it's likely that I will try to improve inline storage. As far as I can tell there is no fundamental reason why this use case isn't supported - it just needs someone to do the work. Pointers are always word-aligned, so one possible implementation would be to change the 'is a pointer' metadata for each field from a boolean to a bitmap of pointer offsets.

This work has taken longer than I expected. There are a few more things I would like to try out, but I'm going to timebox this to the end of the week and then next week just run with whatever has worked best so far.


### 2016 Jul 27

I have a plan and it starts with some sorted arrays.

Ideally I would just throw some tuples or structs into an array and sort it. Unfortunately, Julia still has this restriction on structs that contain pointers. Everything is happy as long as I stick to PODs but as soon as I want to have, say, a string column, I suddenly end up with an array of pointers to heap-allocated rows. Which is not what I want at all.

``` julia
r2 = [(id::Int64, id::Int64) for id in ids]
@time sort!(r2, alg=QuickSort)
# 0.056419 seconds (5 allocations: 240 bytes)

r2 = [(id::Int64, string(id)::ASCIIString) for id in ids]
@time sort!(r2, alg=QuickSort)
# 2.340892 seconds (34.94 M allocations: 533.120 MB)
# heap-allocated *and* pass-by-value! tuples are weird!

r2 = [Row(id::Int64, id::Int64) for id in ids]
@time sort!(r2, alg=QuickSort)
# 0.058970 seconds (5 allocations: 240 bytes)

r2 = [Row(id::Int64, string(id)::ASCIIString) for id in ids]
@time sort!(r2, alg=QuickSort)
# 0.124810 seconds (5 allocations: 240 bytes)
```

We can get round this by flipping the layout into columns, but we still need to sort it. Julia's standard sort function only requires length, getindex and setindex:

``` julia
type Columns2{A,B} <: Columns{Row2{A,B}}
  as::Vector{A}
  bs::Vector{B}
end

function Base.length{A,B}(c2::Columns2{A,B})
  length(c2.as)
end

@inline function Base.getindex{A,B}(c2::Columns2{A,B}, ix)
  Row2(c2.as[ix], c2.bs[ix])
end

@inline function Base.setindex!{A,B}(c2::Columns2{A,B}, val::Row2{A,B}, ix)
  c2.as[ix] = val.a
  c2.bs[ix] = val.b
end
```

But these still have to return something row-like which leaves us with exactly the same problem:

``` julia
c2 = Columns2([id::Int64 for id in ids], [id::Int64 for id in ids])
@time sort!(c2, alg=QuickSort)
# 0.056417 seconds (5 allocations: 240 bytes)

c2 = Columns2([id::Int64 for id in ids], [string(id)::ASCIIString for id in ids])
@time sort!(c2, alg=QuickSort)
# 0.542212 seconds (19.06 M allocations: 582.780 MB, 46.45% gc time)
```

I would enjoy Julia a lot more if this wasn't a thing.

So, let's just brute-force a workaround. I'll copy the sorting code from the base library and generate different versions of it for every number of columns, using multiple variables to hold the values instead of tuples or structs.

``` julia
function define_columns(n)
  cs = [symbol("c", c) for c in 1:n]
  ts = [symbol("C", c) for c in 1:n]
  tmps = [symbol("tmp", c) for c in 1:n]

  :(begin

  @inline function lt($(cs...), i, j)
    @inbounds begin
      $([:(if !isequal($(cs[c])[i], $(cs[c])[j]); return isless($(cs[c])[i], $(cs[c])[j]); end) for c in 1:(n-1)]...)
      return isless($(cs[n])[i], $(cs[n])[j])
    end
  end

  @inline function lt2($(cs...), $(tmps...), j)
    @inbounds begin
      $([:(if !isequal($(tmps[c]), $(cs[c])[j]); return isless($(tmps[c]), $(cs[c])[j]); end) for c in 1:(n-1)]...)
      return isless($(tmps[n]), $(cs[n])[j])
    end
  end

  @inline function swap2($(cs...), i, j)
    @inbounds begin
      $([:(begin
      $(tmps[c]) = $(cs[c])[j]
      $(cs[c])[j] = $(cs[c])[i]
      $(cs[c])[i] = $(tmps[c])
    end) for c in 1:n]...)
  end
  end

  @inline function swap3($(cs...), i, j, k)
    @inbounds begin
      $([:(begin
      $(tmps[c]) = $(cs[c])[k]
      $(cs[c])[k] = $(cs[c])[j]
      $(cs[c])[j] = $(cs[c])[i]
      $(cs[c])[i] = $(tmps[c])
    end) for c in 1:n]...)
  end
  end

  # sorting cribbed from Base.Sort

  function insertion_sort!($(cs...), lo::Int, hi::Int)
      @inbounds for i = lo+1:hi
        j = i
        $([:($(tmps[c]) = $(cs[c])[i]) for c in 1:n]...)
        while j > lo
            if lt2($(cs...), $(tmps...), j-1)
              $([:($(cs[c])[j] = $(cs[c])[j-1]) for c in 1:n]...)
              j -= 1
              continue
            end
            break
        end
        $([:($(cs[c])[j] = $(tmps[c])) for c in 1:n]...)
    end
  end

  @inline function select_pivot!($(cs...), lo::Int, hi::Int)
      @inbounds begin
          mi = (lo+hi)>>>1
          if lt($(cs...), mi, lo)
              swap2($(cs...), lo, mi)
          end
          if lt($(cs...), hi, mi)
              if lt($(cs...), hi, lo)
                  swap3($(cs...), lo, mi, hi)
              else
                  swap2($(cs...), mi, hi)
              end
          end
          swap2($(cs...), lo, mi)
      end
      return lo
  end

  function partition!($(cs...), lo::Int, hi::Int)
      pivot = select_pivot!($(cs...), lo, hi)
      i, j = lo, hi
      @inbounds while true
          i += 1; j -= 1
          while lt($(cs...), i, pivot); i += 1; end;
          while lt($(cs...), pivot, j); j -= 1; end;
          i >= j && break
          swap2($(cs...), i, j)
      end
      swap2($(cs...), pivot, j)
      return j
  end

  function quicksort!($(cs...), lo::Int, hi::Int)
      @inbounds while lo < hi
          if hi-lo <= 20
            insertion_sort!($(cs...), lo, hi)
            return
          end
          j = partition!($(cs...), lo, hi)
          if j-lo < hi-j
              lo < (j-1) && quicksort!($(cs...), lo, j-1)
              lo = j+1
          else
              j+1 < hi && quicksort!($(cs...), j+1, hi)
              hi = j-1
          end
      end
      return
  end

  function quicksort!{$(ts...)}(cs::Tuple{$(ts...)})
    quicksort!($([:(cs[$c]) for c in 1:n]...), 1, length(cs[1]))
    return cs
  end
  end)
end

for i in 1:10
  eval(define_columns(i))
end
```

It's not pretty. But...

``` julia
c2 = ([id::Int64 for id in ids], [id::Int64 for id in ids])
@time quicksort!(c2)
# 0.017385 seconds (4 allocations: 160 bytes)

c2 = ([id::Int64 for id in ids], [string(id)::ASCIIString for id in ids])
@time quicksort!(c2)
# 0.053001 seconds (4 allocations: 160 bytes)
```

Onwards.

### 2016 Jul 28

I kinda thought that Julia specialized on closures, but this turns out not to be true in the current release. So I upgraded to v0.5-rc0 and then spent most of the day persuading Juno to cooperate. I lost a lot of time before realizing that the Ubuntu 'nightly' PPA hasn't been updated in two months. After switching to the generic linux build and patching Juno in a few places it mostly works now, apart from a weird issue where displaying results inline in Atom sometimes leaves Julia spinning for minutes.

But with that out of the way, we can write a really cute version of leapfrog triejoin:

``` julia
# gallop cribbed from http://www.frankmcsherry.org/dataflow/relational/join/2015/04/11/genericjoin.html
function gallop{T}(column::Vector{T}, value::T, lo::Int64, hi::Int64, cmp)
  if (lo < hi) && cmp(column[lo], value)
    step = 1
    while (lo + step < hi) && cmp(column[lo + step], value)
      lo = lo + step
      step = step << 1
    end

    step = step >> 1
    while step > 0
      if (lo + step < hi) && cmp(column[lo + step], value)
        lo = lo + step
      end
      step = step >> 1
    end

    lo += 1
  end
  lo
end

@inline function intersect{T,N}(handler, cols::NTuple{N, Vector{T}}, los::Vector{Int64}, his::Vector{Int64})
  # assume los/his are valid
  # los inclusive, his exclusive
  n = length(cols)
  local value::T
  value = cols[n][los[n]]
  inited = false
  while true
    for c in 1:n
      if inited && (cols[c][los[c]] == value)
        matching_his = [gallop(cols[c], value, los[c], his[c], <=) for c in 1:n]
        handler(value, los, matching_his)
        los[c] = matching_his[c]
        # TODO can we set los = matching_his without breaking the stop condition?
      else
        los[c] = gallop(cols[c], value, los[c], his[c], <)
      end
      if los[c] >= his[c]
        return
      else
        value = cols[c][los[c]]
      end
    end
    inited = true
  end
end
```

It's really unoptimised at the moment - I need to reuse allocations, remove bounds/null checks, unroll loops etc. But it seems to work:

``` julia
function f()
  edges_x = [[1, 2, 3, 3, 4], [2, 3, 1, 4, 2]]
  edges_y = [[1, 2, 3, 3, 4], [2, 3, 1, 4, 2]]
  edges_z = [[1, 2, 2, 3, 4], [3, 1, 4, 2, 3]]
  intersect((edges_x[1], edges_z[1]), [1,1], [6,6]) do x, x_los, x_his
    intersect((edges_x[2], edges_y[1]), [x_los[1],1], [x_his[1],6]) do y, y_los, y_his
      intersect((edges_y[2], edges_z[2]), [y_los[2], x_los[2]], [y_his[2], x_his[2]]) do z, z_los, z_his
        println(x,y,z)
      end
    end
  end
end
```

It needed a bit of help typing `value` for some reason, and it insists on boxing it, but the code for `f` looks good otherwise. No generic calls and all the intersections are inlined.

### 2016 Jul 29

Ooops, the anonymous functions aren't inlined. Can fix that pretty easily:

``` julia
@time intersect((edges_x[1], edges_z[1]), (1,1), (n,n), @inline function (x, x_los, x_his)
  intersect((edges_x[2], edges_y[1]), (x_los[1],1), (x_his[1],n), @inline function (y, y_los, y_his)
    intersect((edges_y[2], edges_z[2]), (y_los[2], x_los[2]), (y_his[2], x_his[2]), @inline function (z, z_los, z_his)
      println(x,y,z)
    end)
  end)
end)
```

I had to change the syntax because `@inline` is fussy about about what it accepts. I guess it wasn't intended for use with anonymous functions, because they were specialized on there was no opportunity to inline them anyway.

I cleaned up most of the obvious allocations by changing arrays to tuples, and unpacking them in the function body. That requires unrolling the inner loops too, which is probably not harmful.

``` julia
@generated function intersect{T,N}(cols::NTuple{N, Vector{T}}, los::NTuple{N, Int64}, his::NTuple{N, Int64}, handler)
  # assume los/his are valid
  # los inclusive, his exclusive
  quote
    $(Expr(:meta, :inline))
    @inbounds begin
      local value::$T
      @nextract $N col cols
      @nextract $N lo los
      @nextract $N hi his
      value = col_1[lo_1]
      inited = false
      while true
        @nexprs $N c->
        begin
          if inited && (col_c[lo_c] == value)
            @nexprs $N c2-> matching_hi_c2 = gallop(col_c2, value, lo_c2, hi_c2, <=)
            handler(value, (@ntuple $N lo), (@ntuple $N matching_hi))
            lo_c = matching_hi_c
            # TODO can we set los = matching_his without breaking the stop condition?
          else
            lo_c = gallop(col_c, value, lo_c, hi_c, <)
          end
          if lo_c >= hi_c
            return
          else
            value = col_c[lo_c]
          end
          inited = true
        end
      end
    end
  end
end
```

It's nice that the facilities exist to do this kind of code rewriting, but I wouldn't have to do it in the first place if I could just mutate some stack-allocated tuple-like thing. Like a grownup.

Annoyingly, there is still a lot of allocation going on. Looking at the generated code it seems that, while all the anonymous functions have been inlined, the closures are still being created. And heap-allocated :(

It also looks like any values that are closed over become boxed, presumably because Julia can't guarantee that the closure doesn't escape the lifetime of the current stackframe. But the box doesn't get a type and that messed up downsteam inference - note the return type of `f` is `ANY` rather than `Int64`.

``` julia
function f(xs)
  const t = 0
  foreach(xs) do x
    t += x
  end
  t
end
```

``` julia
Variables:
  #self#::Relation.#f
  xs::Array{Int64,1}
  t::CORE.BOX
  #43::Relation.##43#44

Body:
  begin
      t::CORE.BOX = $(Expr(:new, :(Core.Box)))
      (Core.setfield!)(t::CORE.BOX,:contents,0)::Int64 # line 213:
      #43::Relation.##43#44 = $(Expr(:new, :(Relation.##43#44), :(t)))
      SSAValue(0) = #43::Relation.##43#44
      $(Expr(:invoke, LambdaInfo for foreach(::Relation.##43#44, ::Array{Int64,1}), :(Relation.foreach), SSAValue(0), :(xs))) # line 216:
      return (Core.getfield)(t::CORE.BOX,:contents)::ANY
  end::ANY
```

It looks like Julia's closures just aren't there yet.

### 2016 Jul 30

I managed a macro-y version that does the trick, producing zero allocations in the main body. The nice `@nexprs` macro I was using before doesn't interact well with the macro hygienisation so I have to do stuff by hand, with much additional syntax.

``` julia
function unpack(expr)
  assert(expr.head == :tuple)
  for value in expr.args
    assert(typeof(value) == Symbol)
  end
  expr.args
end

macro intersect(cols, los, ats, his, next_los, next_his, handler)
  cols = unpack(cols)
  los = unpack(los)
  ats = unpack(ats)
  his = unpack(his)
  next_los = unpack(next_los)
  next_his = unpack(next_his)
  n = length(cols)
  quote
    # assume los/his are valid
    # los inclusive, his exclusive
    @inbounds begin
      $([
      quote
        $(esc(ats[c])) = $(esc(los[c]))
      end
      for c in 1:n]...)
      value = $(esc(cols[n]))[$(esc(ats[n]))]
      fixed = 1
      finished = false
      while !finished
        $([
        quote
          if fixed == $n
            $([
            quote
              $(esc(next_los[c2])) = $(esc(ats[c2]))
              $(esc(next_his[c2])) = gallop($(esc(cols[c2])), value, $(esc(ats[c2])), $(esc(his[c2])), <=)
              $(esc(ats[c2])) = $(esc(next_his[c2]))
            end
            for c2 in 1:n]...)
            $handler # TODO huge code duplication
          else
            $(esc(ats[c])) = gallop($(esc(cols[c])), value, $(esc(ats[c])), $(esc(his[c])), <)
          end
          if $(esc(ats[c])) >= $(esc(his[c]))
            finished = true
          else
            next_value = $(esc(cols[c]))[$(esc(ats[c]))]
            fixed = (value == next_value) ? fixed+1 : 1
            value = next_value
          end
          inited = true
        end
        for c in 1:n]...)
      end
    end
  end
end
```

This is fast but awful to look at, so I played around with closures some more. I discovered that boxing of closed-over variables only happens if a stack-allocated thing is mutated. Heap-allocated things propagate their types just fine. (I'm sure I had a case where a stack-allocated thing got boxed without being mutated. Not sure if I imagined it or if the nest of closures was confusing the mutation analysis.)

``` julia
function f(xs)
  t = [0]
  foreach(xs) do x
    t[1] += x
  end
  t[1]
end
```

``` julia
Variables:
  #self#::Relation.#f
  xs::Array{Int64,1}
  t::Array{Int64,1}
  #267::Relation.##267#268{Array{Int64,1}}

Body:
  begin
      t::Array{Int64,1} = $(Expr(:invoke, LambdaInfo for vect(::Int64, ::Vararg{Int64,N}), :(Base.vect), 0)) # line 215:
      #267::Relation.##267#268{Array{Int64,1}} = $(Expr(:new, Relation.##267#268{Array{Int64,1}}, :(t)))
      SSAValue(0) = #267::Relation.##267#268{Array{Int64,1}}
      $(Expr(:invoke, LambdaInfo for foreach(::Relation.##267#268{Array{Int64,1}}, ::Array{Int64,1}), :(Relation.foreach), SSAValue(0), :(xs))) # line 218:
      return (Base.arrayref)(t::Array{Int64,1},1)::Int64
  end::Int64
```

This is reflected in the emitted code - the non-boxed version has a constant 6 allocations whereas the boxed version allocates for each x in xs.

To avoid having to create closures on each nexted iteration, I moved all the state variables to heap-allocated arrays at the top of the query.

``` julia
function f(edges_xy::Tuple{Vector{Int64}, Vector{Int64}}, edges_yz::Tuple{Vector{Int64}, Vector{Int64}}, edges_xz::Tuple{Vector{Int64}, Vector{Int64}})
  cols = (edges_xy[1], edges_xy[2], Int64[], edges_yz[1], edges_yz[2], Int64[], edges_xz[1], edges_xz[2], Int64[])
  los = [1 for _ in 1:length(cols)]
  ats = [1 for _ in 1:length(cols)]
  his = [length(cols[i])+1 for i in 1:length(cols)]
  count = [0]

  @time begin
    intersect(cols, los, ats, his, (1, 7)) do
      intersect(cols, los, ats, his, (2, 4)) do
        intersect(cols, los, ats, his, (5, 8)) do
          count[1] += 1
        end
      end
    end
  end

  count[1]
end
```

Those nested closures still get created every time though (even though they are all identical) causing many many heap allocations. Rewriting like this fixed the problem:

``` julia
function f(edges_xy::Tuple{Vector{Int64}, Vector{Int64}}, edges_yz::Tuple{Vector{Int64}, Vector{Int64}}, edges_xz::Tuple{Vector{Int64}, Vector{Int64}})
  cols = (edges_xy[1], edges_xy[2], Int64[], edges_yz[1], edges_yz[2], Int64[], edges_xz[1], edges_xz[2], Int64[])
  los = [1 for _ in 1:length(cols)]
  ats = [1 for _ in 1:length(cols)]
  his = [length(cols[i])+1 for i in 1:length(cols)]
  count = [0]

  cont4 = () -> count[1] += 1
  cont3 = () -> intersect(cont4, cols, los, ats, his, (5, 8))
  cont2 = () -> intersect(cont3, cols, los, ats, his, (2, 4))
  cont1 = () -> intersect(cont2, cols, los, ats, his, (1, 7))

  @time cont1()

  count[1]
end
```

Now `intersect` gets to be a normal function again.

``` julia
function intersect(next, cols, los, ats, his, ixes)
  # assume los/his are valid
  # los inclusive, his exclusive
  @inbounds begin
    for ix in ixes
      ats[ix] = los[ix]
    end
    n = length(ixes)
    value = cols[ixes[n]][ats[ixes[n]]]
    fixed = 1
    while true
      for ix in ixes
        if fixed == n
          for ix2 in ixes
            los[ix2+1] = ats[ix2]
            his[ix2+1] = gallop(cols[ix2], value, ats[ix2], his[ix2], <=)
            ats[ix2] = his[ix2+1]
          end
          next()
        else
          ats[ix] = gallop(cols[ix], value, ats[ix], his[ix], <)
        end
        if ats[ix] >= his[ix]
          return
        else
          next_value = cols[ix][ats[ix]]
          fixed = (value == next_value) ? fixed+1 : 1
          value = next_value
        end
      end
    end
  end
end
```

This is only slightly slower than the macro version.

Belatedly, I realise that now that the state is kept outside the function I could just have avoided the closures all together:

``` julia
function start_intersect(cols, los, ats, his, ixes)
  # assume los/his are valid
  # los inclusive, his exclusive
  @inbounds begin
    for ix in ixes
      ats[ix] = los[ix]
    end
  end
end

function next_intersect(cols, los, ats, his, ixes)
  @inbounds begin
    fixed = 1
    n = length(ixes)
    value = cols[n][ats[ixes[n]]]
    while true
      for c in 1:n
        ix = ixes[c]
        if fixed == n
          for c2 in 1:n
            ix2 = ixes[c2]
            los[ix2+1] = ats[ix2]
            his[ix2+1] = gallop(cols[c2], value, ats[ix2], his[ix2], <=)
            ats[ix2] = his[ix2+1]
          end
          return true
        else
          ats[ix] = gallop(cols[c], value, ats[ix], his[ix], <)
        end
        if ats[ix] >= his[ix]
          return false
        else
          next_value = cols[c][ats[ix]]
          fixed = (value == next_value) ? fixed+1 : 1
          value = next_value
        end
      end
    end
  end
end
```

Wish I had thought of that two days ago.

The setup is now kind of ugly, but the query compiler is going to be handling this anyway.

``` julia
function f(edges_xy::Tuple{Vector{Int64}, Vector{Int64}}, edges_yz::Tuple{Vector{Int64}, Vector{Int64}}, edges_xz::Tuple{Vector{Int64}, Vector{Int64}})
  cols_x = [edges_xy[1], edges_xz[1]]
  cols_y = [edges_xy[2], edges_yz[1]]
  cols_z = [edges_yz[2], edges_xz[2]]
  ixes_x = [1,7]
  ixes_y = [2,4]
  ixes_z = [5,8]
  los = [1 for _ in 1:9]
  ats = [1 for _ in 1:9]
  his = [length(cols_x[1])+1 for i in 1:9]
  count = 0

  @time begin
    start_intersect(cols_x, los, ats, his, ixes_x)
    while next_intersect(cols_x, los, ats, his, ixes_x)
      x = cols_x[1][los[2]]
      start_intersect(cols_y, los, ats, his, ixes_y)
      while next_intersect(cols_y, los, ats, his, ixes_y)
        y = cols_y[1][los[3]]
        start_intersect(cols_z, los, ats, his, ixes_z)
        while next_intersect(cols_z, los, ats, his, ixes_z)
          z = cols_z[1][los[6]]
          # println((x,y,z))
          count += 1
        end
      end
    end
  end

  count
end
```

### 2016 Jul 31

I had some time this evening so I hashed out the core codegen.

To write code I have to figure out what data to compute, how to compute it, how to store it, in what order to compute it, how to organise the code, what to name things etc. I find that if I just sit down with an editor and try to do this all at once I spend a lot of time context switching, which manifests as these mental stack overflows where I just go blank for a while.

Over the last year or so, I gradually started to batch these tasks together. I start by choosing a couple of examples and writing down the inputs and outputs. Then I sketch out what data will help me to get from input to output.

``` julia
q = quote
  edge(a,b)
  edge(b,c)
  edge(c,a)
end

fieldnames(q)
q.head
q.args
q.args[2].head
q.args[2].args

a => (r1, c1), (r3, c2)
b => ...
c => ...

var order

indexes
r1 => (1,2)
...

ixes
r1, c1 => 1
r1, c2 => 2
r1, end => 3
...
r3, c2 => 7
r3, c1 => 8
r3, end => 9

cols = [r1, ...]
quicksort!((cols[1][2], cols[1][1]))
...
cols_a = (cols[1][2], cols[1][1])
ixes_a = (1, 7)
...
los, ats = 1
his = length(cols[r][c])
results = []

start_intersect
while next_intersect
  a = cols[1][2][los[3]]
  ...
     push!(results, (a,b,c))
end
```

Then I pick names and topo-sort the chunks of data. That whole plan then goes on one side of the screen and I can start cranking out code on the other side of the screen. The plan fills in my patchy short-term memory so the code flows smoothly. I didn't quite manage to type the compiler without hitting backspace, but it was close.

``` julia
function plan(query, variables)
  relations = [line.args[1] for line in query.args if line.head != :line]

  sources = Dict()
  for (clause, line) in enumerate(query.args)
    if line.head != :line
      assert(line.head == :call)
      for (column, variable) in enumerate(line.args[2:end])
        assert(variable in variables)
        push!(get!(()->[], sources, variable), (clause,column))
      end
    end
  end

  sort_orders = Dict()
  for variable in variables
    for (clause, column) in sources[variable]
      push!(get!(()->[], sort_orders, clause), column)
    end
  end

  ixes = Dict()
  next_ix = 1
  for (clause, columns) in sort_orders
    for column in columns
      ixes[(clause, column)] = next_ix
      next_ix += 1
    end
    ixes[(clause, :buffer)] = next_ix
    next_ix += 1
  end

  column_inits = Vector(length(ixes))
  for ((clause, column), ix) in ixes
    if column == :buffer
      column_inits[ix] = :()
    else
      clause_name = query.args[clause].args[1]
      column_inits[ix] = :(copy($(esc(clause_name))[$column]))
    end
  end

  sorts = []
  for (clause, columns) in sort_orders
    sort_ixes = [ixes[(clause, column)] for column in columns]
    sort_args = [:(columns[$ix]) for ix in sort_ixes]
    sort = :(quicksort!(tuple($(sort_args...))))
    push!(sorts, sort)
  end

  variable_inits = []
  for variable in variables
    clauses_and_columns = sources[variable]
    variable_ixes = [ixes[(clause, column)] for (clause, column) in clauses_and_columns]
    variable_columns = [:(columns[$ix]) for ix in variable_ixes]
    variable_init = quote
      $(symbol("columns_", variable)) = [$(variable_columns...)]
      $(symbol("ixes_", variable)) = [$(variable_ixes...)]
    end
    push!(variable_inits, variable_init)
  end

  setup = quote
    columns = tuple($(column_inits...))
    $(sorts...)
    los = Int64[1 for i in 1:$(length(ixes))]
    ats = Int64[1 for i in 1:$(length(ixes))]
    his = Int64[length(columns[i]) for i in 1:$(length(ixes))]
    $(variable_inits...)
    results = []
  end

  function body(variable_ix)
    if variable_ix <= length(variables)
      variable = variables[variable_ix]
      variable_columns = symbol("columns_", variable)
      variable_ixes = symbol("ixes_", variable)
      result_column = ixes[sources[variable][1]]
      quote
        start_intersect($variable_columns, los, ats, his, $variable_ixes)
        while next_intersect($variable_columns, los, ats, his, $variable_ixes)
          $(esc(variable)) = columns[$result_column][los[$(result_column+1)]]
          $(body(variable_ix + 1))
        end
      end
    else
      quote
        push!(results, tuple($([esc(variable) for variable in variables]...)))
      end
    end
  end

  quote
    $setup
    @time $(body(1))
    results
  end
end
```

With a crappy little macro we can now write the previous query as:

``` julia
macro query(variables, query)
  plan(query, variables.args)
end

function f(edge)
  @query([a,b,c],
  begin
    edge(a,b)
    edge(b,c)
    edge(c,a)
  end)
end
```

Thats the basics. The next big steps are embedding an expression language and choosing the variable ordering automatically.

EDIT: I found a little more time, so here is the chinook query from earlier in the year:

``` julia
album = read_columns("data/Album.csv", [Int64, String, Int64])
artist = read_columns("data/Artist.csv", [Int64, String])
track = read_columns("data/Track.csv", [Int64, String, Int64])
playlist_track = read_columns("data/PlaylistTrack.csv", [Int64, Int64])
playlist = read_columns("data/Playlist.csv", [Int64, String])

metal = read_columns("data/Metal.csv", [String])

function who_is_metal(album, artist, track, playlist_track, playlist, metal)
  @query([pn, p, t, al, a, an],
  begin
    metal(pn)
    playlist(p, pn)
    playlist_track(p, t)
    track(t, _, al)
    album(al, _, a)
    artist(a, an)
  end
  )[6]
end
```

Runs in 0.37ms, of which only about 0.01ms is solving the query and the rest is copying and sorting the inputs. My notes say the rust version took 0.8ms all together and SQLite took 1.2ms just to solve the query (both on an older machine). I won't bother benchmarking properly until the compiler is feature complete and I have tests, but looks like I'm inside my performance budget so far.

### 2016 Aug 1

Expressions just act as extra filters on results, so I can write things like:

``` julia
edge(a,b)
a < b
edge(b,c)
b < c
edge(c,a)
```

Evaluating them is pretty straightforward. I grab all the variables in the expression, assume any that aren't in the variable order are external constants, and figure out the earliest time when the remainder have been assigned.

``` julia
filters = [[] for _ in variables]
for clause in expression_clauses
  line = query.args[clause]
  callable_at = maximum(indexin(collect_variables(line), variables))
  push!(filters[callable_at], line)
end

function filter(filters, tail)
  if length(filters) == 0
    tail
  else
    quote
      if $(filters[1])
        $(filter(filters[2:end], tail))
      end
    end
  end
end

function body(variable_ix)
  ...
          $(filter(filters[variable_ix], body(variable_ix + 1)))
  ...
end
```

Equations are a bit trickier. An expression like `a == b + 1` could be treated as a filter on the results, but in many cases it would be much better to run it as soon as `b` is assigned, before wasting time generating many `a`s. On the other hand, that limits the compiler to variable orders where `b` comes before `a`, which may be inefficient.

One of my core goals is to make performance predictable, so rather than deciding this in the compiler with some heuristic I'm going to have the programmer communicate intent directly. `a == b + 1` is a filter that will be run once `a` and `b` are both defined. `a = b + 1` is an assignment that forces `b` to be assigned before `a` and that will be run just before the intersection for `a`. In a true relational language this distinction wouldn't exist, but I want to be pragmatic for now.

``` julia
function assign(cols, los, ats, his, ixes, value)
  @inbounds begin
    n = length(ixes)
    for c in 1:n
      ix = ixes[c]
      los[ix+1] = gallop(cols[c], value, los[ix], his[ix], <)
      if los[ix+1] >= his[ix]
        return false
      end
      his[ix+1] = gallop(cols[c], value, los[ix+1], his[ix], <=)
    end
    return true
  end
end

function body(variable_ix)
  ...
    if haskey(assignment_clauses, variable)
      quote
        let $variable = $(assignment_clauses[variable])
          if assign($variable_columns, los, ats, his, $variable_ixes, $variable)
            # println($(repeat("  ", variable_ix)), $(string(variable)), "=", $variable)
            $tail
          end
        end
      end
    else
      ...
    end
  ...
end
```

Now we can do:

``` julia
begin
  pn = "Heavy Metal Classic"
  playlist(p, pn)
  playlist_track(p, t)
  track(t, _, al)
  album(al, _, a)
  artist(a, an)
end
```

What next? I have some ideas about variable ordering, but I need a lot more examples to see if they are realistic. Maybe projection/aggreation? I need to think a bit about how I want to handle that.

### 2016 Aug 4

Projection is really easy - we can just reuse the same building blocks:

``` julia
metal = @query([pn, p, t, al, a, an],
begin
  pn = "Heavy Metal Classic"
  playlist(p, pn)
  playlist_track(p, t)
  track(t, _, al)
  album(al, _, a)
  artist(a, an)
end
)

metal_projected = @query([an],
begin
  metal(_, _, _, _, _, an)
end)
```

While I was doing that, I noticed that I'm returning columns of type `Any`. Fixing that is pretty tricky, because I don't actually know the type of the variables when I generate the query code. I'm relying on Julia's type inference, but type inference only happens after I generate code. I could wait until the first result to initialize the columns, but that doesn't work for queries with no results.

Let's just work around it for now by allowing the user to specify the types in the query:

``` julia
function plan(query, typed_variables)
  variables = []
  variable_types = []
  for typed_variable in typed_variables
    if isa(typed_variable, Symbol)
      push!(variables, typed_variable)
      push!(variable_types, :Any)
    elseif isa(typed_variable, Expr) && typed_variable.head == :(::)
      push!(variables, typed_variable.args[1])
      push!(variable_types, typed_variable.args[2])
    else
      throw("Variable must be a symbol (with optional type annotation)")
    end
  end
  ...
     $(symbol("results_", variable)) = Vector{$(variable_type)}()
  ...
end
```

``` julia
@join([a,b,c], [a::Int64,b::Int64,c::Int64],
begin
  edge(a,b)
  a < b
  edge(b,c)
  b < c
  edge(c,a)
end)
```

We can also do Yannakis-style queries:

``` julia
function who_is_metal2(album, artist, track, playlist_track, playlist)
  i1 = @query([pn::String, p::Int64],
  begin
    pn = "Heavy Metal Classic"
    playlist(p, pn)
  end)
  i2 = @query([p::Int64, t::Int64],
  begin
    i1(_, p)
    playlist_track(p, t)
  end)
  i3 = @query([t::Int64, al::Int64],
  begin
    i2(_, t)
    track(t, _, al)
  end)
  i4 = @query([al::Int64, a::Int64],
  begin
    i3(_, al)
    album(al, _, a)
  end)
  i5 = @query([a::Int64, an::String],
  begin
    i4(_, a)
    artist(a, an)
  end)
  @query([an::String],
  begin
    i5(_, an)
  end)
end
```

On to aggregation. I have a planner that turns this:

``` julia
@join([pn],
[p::Int64, pn::String, t::Int64, al::Int64, price::Float64],
(0.0,+,price::Float64),
begin
  playlist(p, pn)
  playlist_track(p, t)
  track(t, _, al, _, _, _, _, _, price)
end)
```

Into this:

```
begin  # /home/jamie/imp/src/Imp.jl, line 586:
    begin  # /home/jamie/imp/src/Imp.jl, line 411:
        begin  # /home/jamie/imp/src/Imp.jl, line 333:
            #11256#columns = tuple(copy(playlist_track[1]),copy(playlist_track[2]),(),copy(playlist[1]),copy(playlist[2]),(),copy(track[1]),copy(track[3]),copy(track[9]),()) # /home/jamie/imp/src/Imp.jl, line 334:
            quicksort!(tuple(#11256#columns[1],#11256#columns[2]))
            quicksort!(tuple(#11256#columns[4],#11256#columns[5]))
            quicksort!(tuple(#11256#columns[7],#11256#columns[8],#11256#columns[9])) # /home/jamie/imp/src/Imp.jl, line 335:
            #11257#los = Int64[1 for #11258#i = 1:10] # /home/jamie/imp/src/Imp.jl, line 336:
            #11259#ats = Int64[1 for #11258#i = 1:10] # /home/jamie/imp/src/Imp.jl, line 337:
            #11260#his = Int64[length(#11256#columns[#11258#i]) + 1 for #11258#i = 1:10] # /home/jamie/imp/src/Imp.jl, line 338:
            begin  # /home/jamie/imp/src/Imp.jl, line 323:
                #11261#columns_p = [#11256#columns[4],#11256#columns[1]] # /home/jamie/imp/src/Imp.jl, line 324:
                #11262#ixes_p = [4,1] # /home/jamie/imp/src/Imp.jl, line 325:
                nothing
            end
            begin  # /home/jamie/imp/src/Imp.jl, line 323:
                #11263#columns_pn = [#11256#columns[5]] # /home/jamie/imp/src/Imp.jl, line 324:
                #11264#ixes_pn = [5] # /home/jamie/imp/src/Imp.jl, line 325:
                #11265#results_pn = Vector{String}()
            end
            begin  # /home/jamie/imp/src/Imp.jl, line 323:
                #11266#columns_t = [#11256#columns[2],#11256#columns[7]] # /home/jamie/imp/src/Imp.jl, line 324:
                #11267#ixes_t = [2,7] # /home/jamie/imp/src/Imp.jl, line 325:
                nothing
            end
            begin  # /home/jamie/imp/src/Imp.jl, line 323:
                #11268#columns_al = [#11256#columns[8]] # /home/jamie/imp/src/Imp.jl, line 324:
                #11269#ixes_al = [8] # /home/jamie/imp/src/Imp.jl, line 325:
                nothing
            end
            begin  # /home/jamie/imp/src/Imp.jl, line 323:
                #11270#columns_price = [#11256#columns[9]] # /home/jamie/imp/src/Imp.jl, line 324:
                #11271#ixes_price = [9] # /home/jamie/imp/src/Imp.jl, line 325:
                nothing
            end # /home/jamie/imp/src/Imp.jl, line 339:
            #11272#results_aggregate = Vector{Float64}()
        end # /home/jamie/imp/src/Imp.jl, line 412:
        begin  # /home/jamie/imp/src/Imp.jl, line 392:
            start_intersect(#11261#columns_p,#11257#los,#11259#ats,#11260#his,#11262#ixes_p) # /home/jamie/imp/src/Imp.jl, line 393:
            while next_intersect(#11261#columns_p,#11257#los,#11259#ats,#11260#his,#11262#ixes_p) # /home/jamie/imp/src/Imp.jl, line 394:
                #11273#p = (#11256#columns[4])[#11257#los[5]] # /home/jamie/imp/src/Imp.jl, line 395:
                begin  # /home/jamie/imp/src/Imp.jl, line 392:
                    start_intersect(#11263#columns_pn,#11257#los,#11259#ats,#11260#his,#11264#ixes_pn) # /home/jamie/imp/src/Imp.jl, line 393:
                    while next_intersect(#11263#columns_pn,#11257#los,#11259#ats,#11260#his,#11264#ixes_pn) # /home/jamie/imp/src/Imp.jl, line 394:
                        #11274#pn = (#11256#columns[5])[#11257#los[6]] # /home/jamie/imp/src/Imp.jl, line 395:
                        begin  # /home/jamie/imp/src/Imp.jl, line 364:
                            #11275#aggregate = 0.0 # /home/jamie/imp/src/Imp.jl, line 365:
                            begin  # /home/jamie/imp/src/Imp.jl, line 392:
                                start_intersect(#11266#columns_t,#11257#los,#11259#ats,#11260#his,#11267#ixes_t) # /home/jamie/imp/src/Imp.jl, line 393:
                                while next_intersect(#11266#columns_t,#11257#los,#11259#ats,#11260#his,#11267#ixes_t) # /home/jamie/imp/src/Imp.jl, line 394:
                                    #11276#t = (#11256#columns[2])[#11257#los[3]] # /home/jamie/imp/src/Imp.jl, line 395:
                                    begin  # /home/jamie/imp/src/Imp.jl, line 392:
                                        start_intersect(#11268#columns_al,#11257#los,#11259#ats,#11260#his,#11269#ixes_al) # /home/jamie/imp/src/Imp.jl, line 393:
                                        while next_intersect(#11268#columns_al,#11257#los,#11259#ats,#11260#his,#11269#ixes_al) # /home/jamie/imp/src/Imp.jl, line 394:
                                            #11277#al = (#11256#columns[8])[#11257#los[9]] # /home/jamie/imp/src/Imp.jl, line 395:
                                            begin  # /home/jamie/imp/src/Imp.jl, line 392:
                                                start_intersect(#11270#columns_price,#11257#los,#11259#ats,#11260#his,#11271#ixes_price) # /home/jamie/imp/src/Imp.jl, line 393:
                                                while next_intersect(#11270#columns_price,#11257#los,#11259#ats,#11260#his,#11271#ixes_price) # /home/jamie/imp/src/Imp.jl, line 394:
                                                    #11278#price = (#11256#columns[9])[#11257#los[10]] # /home/jamie/imp/src/Imp.jl, line 395:
                                                    #11275#aggregate = #11275#aggregate + #11278#price::Float64
                                                end
                                            end
                                        end
                                    end
                                end
                            end # /home/jamie/imp/src/Imp.jl, line 366:
                            if #11275#aggregate != 0.0 # /home/jamie/imp/src/Imp.jl, line 367:
                                push!(#11265#results_pn,#11274#pn) # /home/jamie/imp/src/Imp.jl, line 370:
                                push!(#11272#results_aggregate,#11275#aggregate)
                            end
                        end
                    end
                end
            end
        end # /home/jamie/imp/src/Imp.jl, line 413:
        tuple(#11265#results_pn,#11272#results_aggregate)
    end
end
```

It only aggregates after the last variable in the ordering that is returned, so if I want to aggregate over variables that are earlier in the ordering I need to apply another join to the result.

``` julia
result = @join([p, pn, t],
[p::Int64, pn::String, t::Int64, al::Int64, price::Float64],
(0.0,+,price::Float64),
begin
  playlist(p, pn)
  playlist_track(p, t)
  track(t, _, al, _, _, _, _, _, price)
end)

@join([t],
[t::Int64, p::Int64, pn::String, price::Float64],
(0.0,+,price::Float64),
begin
  result(p, pn, t, price)
end)
```

I want to wrap that up in another ugly macro but right now I'm just flailing and nothing works. Tomorrow...

### 2016 Aug 5

Ok, I finally got this nailed down. There were a bunch of little things I had to fix.

The inputs to queries are sets, but the query effectively projects out the columns it cares about. That didn't matter before, but for aggregates we care about the number of results, not just the values. Now I count the number of repeated solutions:

``` julia
repeats = 1
for buffer_ix in buffer_ixes
  repeats = :($repeats * (his[$buffer_ix] - los[$buffer_ix]))
end
body = :(aggregate = $(aggregate_add)(aggregate, $aggregate_expr, $repeats))
```

The `aggregate_add` is now required to take a third argument that gives an exponent to the operation.

``` julia
@inline add_exp(a, b, n) = a + (b * n)
@inline mul_exp(a, b, n) = a * (b ^ n)
```

I split the old `plan` into `analyse` and `plan_join` so that I could reuse the parts:

``` julia
function plan_query(returned_variables, typed_variables, aggregate, query)
  aggregate_zero, aggregate_add, aggregate_expr = aggregate
  aggregate_type, variables, variable_types, return_ix = analyse(returned_variables, typed_variables, aggregate)
  join = plan_join(returned_variables, aggregate, aggregate_type, variables, variable_types, return_ix, query)
  project_variables = Any[variable for (variable, variable_type) in zip(variables, variable_types) if variable in returned_variables]
  project_variable_types = Any[variable_type for (variable, variable_type) in zip(variables, variable_types) if variable in returned_variables]
  push!(project_variables, :prev_aggregate)
  push!(project_variable_types, aggregate_type)
  project_aggregate = [aggregate_zero, aggregate_add, :prev_aggregate]
  project_query = quote
    intermediate($(project_variables...))
  end
  project_return_ix = length(returned_variables) + 1
  project = plan_join(returned_variables, project_aggregate, aggregate_type, project_variables, project_variable_types, project_return_ix, project_query)
  quote
    let $(esc(:intermediate)) = let; $join; end
      $project
    end
  end
end
```

The default aggregate just counts the number of results:

``` julia
macro query(returned_variables, typed_variables, query)
  :(@query($returned_variables, $typed_variables, (0, add_exp, 1::Int64), $query))
end

macro query(returned_variables, typed_variables, aggregate, query)
  plan_query(returned_variables.args, typed_variables.args, aggregate.args, query)
end
```

Now we can ask questions like how many times each artist appears on a given playlist:

``` julia
@query([pn, an],
[pn::String, p::Int64, t::Int64, al::Int64, a::Int64, an::String],
begin
  playlist(p, pn)
  playlist_track(p, t)
  track(t, _, al)
  album(al, _, a)
  artist(a, an)
end)
```

I've been putting off dealing with hygiene in the planner, but I spent about an hour on a hygiene bug today so I suppose I should move that up the todo list.

I also have to do something about caching sorted relations, and then I think I have enough to try the [Join Order Benchmark](http://www.vldb.org/pvldb/vol9/p204-leis.pdf). It uses the IMDB dataset (which is about 3.6GB of strings) and asks questions such as:

``` sql
SELECT MIN(cn1.name) AS first_company,
       MIN(cn2.name) AS second_company,
       MIN(mi_idx1.info) AS first_rating,
       MIN(mi_idx2.info) AS second_rating,
       MIN(t1.title) AS first_movie,
       MIN(t2.title) AS second_movie
FROM company_name AS cn1,
     company_name AS cn2,
     info_type AS it1,
     info_type AS it2,
     kind_type AS kt1,
     kind_type AS kt2,
     link_type AS lt,
     movie_companies AS mc1,
     movie_companies AS mc2,
     movie_info_idx AS mi_idx1,
     movie_info_idx AS mi_idx2,
     movie_link AS ml,
     title AS t1,
     title AS t2
WHERE cn1.country_code != '[us]'
  AND it1.info = 'rating'
  AND it2.info = 'rating'
  AND kt1.kind IN ('tv series',
                   'episode')
  AND kt2.kind IN ('tv series',
                   'episode')
  AND lt.link IN ('sequel',
                  'follows',
                  'followed by')
  AND mi_idx2.info < '3.5'
  AND t2.production_year BETWEEN 2000 AND 2010
  AND lt.id = ml.link_type_id
  AND t1.id = ml.movie_id
  AND t2.id = ml.linked_movie_id
  AND it1.id = mi_idx1.info_type_id
  AND t1.id = mi_idx1.movie_id
  AND kt1.id = t1.kind_id
  AND cn1.id = mc1.company_id
  AND t1.id = mc1.movie_id
  AND ml.movie_id = mi_idx1.movie_id
  AND ml.movie_id = mc1.movie_id
  AND mi_idx1.movie_id = mc1.movie_id
  AND it2.id = mi_idx2.info_type_id
  AND t2.id = mi_idx2.movie_id
  AND kt2.id = t2.kind_id
  AND cn2.id = mc2.company_id
  AND t2.id = mc2.movie_id
  AND ml.linked_movie_id = mi_idx2.movie_id
  AND ml.linked_movie_id = mc2.movie_id
  AND mi_idx2.movie_id = mc2.movie_id;
```

Or:

``` sql
SELECT MIN(mc.note) AS production_note,
       MIN(t.title) AS movie_title,
       MIN(t.production_year) AS movie_year
FROM company_type AS ct,
     info_type AS it,
     movie_companies AS mc,
     movie_info_idx AS mi_idx,
     title AS t
WHERE ct.kind = 'production companies'
  AND it.info = 'top 250 rank'
  AND mc.note NOT LIKE '%(as Metro-Goldwyn-Mayer Pictures)%'
  AND (mc.note LIKE '%(co-production)%'
       OR mc.note LIKE '%(presents)%')
  AND ct.id = mc.company_type_id
  AND t.id = mc.movie_id
  AND t.id = mi_idx.movie_id
  AND mc.movie_id = mi_idx.movie_id
  AND it.id = mi_idx.info_type_id;
```

### 2016 Aug 6

Ok, so we're gonna store the columns in some object that caches various sort orders.

``` julia
type Relation{T <: Tuple} # where T is a tuple of columns
  columns::T
  indexes::Dict{Vector{Int64},T}
end

function Relation{T}(columns::T)
  Relation(columns, Dict{Vector{Int64},T}())
end

function index{T}(relation::Relation{T}, order::Vector{Int64})
  get!(relation.indexes, order) do
    index::T = tuple([(ix in order) ? copy(column) : Vector{eltype(column)}() for (ix, column) in enumerate(relation.columns)]...)
    quicksort!(tuple([index[ix] for ix in order]...))
    index
  end
end
```

We're not being very smart about sharing indexes. If we request [1,2] and there is already an index for [1,2,3] we could just return that, but instead we make a new and pointless index. I'll fix that one day.

When we create a new index, we sort the columns in the order specified but return them in the original order, with any unsorted columns emptied out. This ensures that the return type of the function doesn't depend on the order. Eventually I'll get around to wrapping each query in a function to create a dispatch point and then it won't matter, but for now this helps Julia correctly infer types downstream.

I currently have IMDbPY inserting data into postgres. That reportedly takes about 8 hours (although the hardware described in the readme is anaemic) but as a side-effect it will spit out csv versions of all the tables that I can use in Imp.

One hour later:

```
loading CSV files into the database
 * LOADING CSV FILE imdb/csv/imdb/csv/complete_cast.csv...
ERROR: unable to import CSV file imdb/csv/imdb/csv/complete_cast.csv: could not open file "imdb/csv/imdb/csv/complete_cast.csv" for reading: No such file or directory
```

It created all the csv files just fine and then somehow mangled the filenames before trying to load them. Trying to just run the csv->db step ran into a different set of errors (which I lost by closing the wrong window :), so let's run it again with the row-by-row insert option.

In the meantime, I tried to load the livejournal dataset into Julia, which caused the atom plugin to blowup:

```
/home/jamie/.atom/packages/julia-client/lib/connection/local.coffee:16
RangeError: Invalid string length
    at Socket.<anonymous> (/home/jamie/.atom/packages/julia-client/lib/connection/local.coffee:16:26)
    at emitOne (events.js:77:13)
    at Socket.emit (events.js:169:7)
    at readableAddChunk (_stream_readable.js:146:16)
    at Socket.Readable.push (_stream_readable.js:110:10)
    at TCP.onread (net.js:523:20)
```

Maybe the problem is that it displays relations by printing the entire contents, rather than just showing the head and tail like it does with large arrays. I poked around inside the source code, found the function that controls rendering and added an override for relations:

``` julia
import Atom
function Atom.render(editor::Atom.Editor, relation::Relation)
  Atom.render(editor, relation.columns)
end
```

I checked with a smaller relation that it does affect the rendering. Does it fix the bug? Nope:

```
/home/jamie/.atom/packages/julia-client/lib/connection/local.coffee:16
RangeError: Invalid string length
    at Socket.<anonymous> (/home/jamie/.atom/packages/julia-client/lib/connection/local.coffee:16:26)
    at emitOne (events.js:77:13)
    at Socket.emit (events.js:169:7)
    at readableAddChunk (_stream_readable.js:146:16)
    at Socket.Readable.push (_stream_readable.js:110:10)
    at TCP.onread (net.js:523:20)
```

Debugging by guessing - not a thing.

### 2016 Aug 8

Still working through various problems getting IMDbPY to work.

```
ERROR: unable to import CSV file /home/jamie/imdb/csv/movie_link.csv: null value in column "movie_id" violates not-null constraint
DETAIL:  Failing row contains (15021, null, 101237, 12).
CONTEXT:  COPY movie_link, line 15021: "15021,NULL,101237,12"

 * LOADING CSV FILE /home/jamie/imdb/csv/char_name.csv...
# TIME loadCSVFiles() : 6min, 24sec (wall) 0min, 0sec (user) 0min, 0sec (system)
# TIME TOTAL TIME TO INSERT/WRITE DATA : 28min, 42sec (wall) 21min, 52sec (user) 0min, 23sec (system)
building database indexes (this may take a while)
# TIME createIndexes() : 8min, 44sec (wall) 0min, 0sec (user) 0min, 0sec (system)
adding foreign keys (this may take a while)
ERROR caught exception creating a foreign key: insert or update on table "aka_title" violates foreign key constraint "movie_id_exists"
DETAIL:  Key (movie_id)=(0) is not present in table "title".
```

Instead, I found a [link](http://homepages.cwi.nl/~boncz/job/imdb.tgz) to the CSV files the authors of the paper used, and loaded those directly into postgres myself. Which took about 5 minutes.

```
\i job/schema.sql

\copy aka_name from 'imdb/aka_name.csv' csv escape '\'
\copy aka_title from 'imdb/aka_title.csv' csv escape '\'
\copy cast_info from 'imdb/cast_info.csv' csv escape '\'
\copy char_name from 'imdb/char_name.csv' csv escape '\'
\copy comp_cast_type from 'imdb/comp_cast_type.csv' csv escape '\'
\copy company_name from 'imdb/company_name.csv' csv escape '\'
\copy company_type from 'imdb/company_type.csv' csv escape '\'
\copy complete_cast from 'imdb/complete_cast.csv' csv escape '\'
\copy info_type from 'imdb/info_type.csv' csv escape '\'
\copy keyword from 'imdb/keyword.csv' csv escape '\'
\copy kind_type from 'imdb/kind_type.csv' csv escape '\'
\copy link_type from 'imdb/link_type.csv' csv escape '\'
\copy movie_companies from 'imdb/movie_companies.csv' csv escape '\'
\copy movie_info from 'imdb/movie_info.csv' csv escape '\'
\copy movie_info_idx from 'imdb/movie_info_idx.csv' csv escape '\'
\copy movie_keyword from 'imdb/movie_keyword.csv' csv escape '\'
\copy movie_link from 'imdb/movie_link.csv' csv escape '\'
\copy name from 'imdb/name.csv' csv escape '\'
\copy person_info from 'imdb/person_info.csv' csv escape '\'
\copy role_type from 'imdb/role_type.csv' csv escape '\'
\copy title from 'imdb/title.csv' csv escape '\'

\i job/fkindexes.sql
```

Now let's dump the schema in a way that's easy for Imp to read:

```
copy (select table_name, ordinal_position, column_name, data_type from information_schema.columns) to '/home/jamie/imp/data/job_schema.csv' with csv delimiter ',';
```

Eugh, and the csv files themselves have backslash-escaped strings that Julia can't read, so let's re-export those.

```
\copy aka_name to 'job/aka_name.csv' csv escape '"'
\copy aka_title to 'job/aka_title.csv' csv escape '"'
\copy cast_info to 'job/cast_info.csv' csv escape '"'
\copy char_name to 'job/char_name.csv' csv escape '"'
\copy comp_cast_type to 'job/comp_cast_type.csv' csv escape '"'
\copy company_name to 'job/company_name.csv' csv escape '"'
\copy company_type to 'job/company_type.csv' csv escape '"'
\copy complete_cast to 'job/complete_cast.csv' csv escape '"'
\copy info_type to 'job/info_type.csv' csv escape '"'
\copy keyword to 'job/keyword.csv' csv escape '"'
\copy kind_type to 'job/kind_type.csv' csv escape '"'
\copy link_type to 'job/link_type.csv' csv escape '"'
\copy movie_companies to 'job/movie_companies.csv' csv escape '"'
\copy movie_info to 'job/movie_info.csv' csv escape '"'
\copy movie_info_idx to 'job/movie_info_idx.csv' csv escape '"'
\copy movie_keyword to 'job/movie_keyword.csv' csv escape '"'
\copy movie_link to 'job/movie_link.csv' csv escape '"'
\copy name to 'job/name.csv' csv escape '"'
\copy person_info to 'job/person_info.csv' csv escape '"'
\copy role_type to 'job/role_type.csv' csv escape '"'
\copy title to 'job/title.csv' csv escape '"'
```

Let's grab the first query from the benchmark and get a feel for long it takes.

```
postgres=# prepare q1a as SELECT MIN(mc.note) AS production_note, MIN(t.title) AS movie_title, MIN(t.production_year) AS movie_year FROM company_type AS ct, info_type AS it, movie_companies AS mc, movie_info_idx AS mi_idx, title AS t WHERE ct.kind = 'production companies' AND it.info = 'top 250 rank' AND mc.note  not like '%(as Metro-Goldwyn-Mayer Pictures)%' and (mc.note like '%(co-production)%' or mc.note like '%(presents)%') AND ct.id = mc.company_type_id AND t.id = mc.movie_id AND t.id = mi_idx.movie_id AND mc.movie_id = mi_idx.movie_id AND it.id = mi_idx.info_type_id;
ERROR:  prepared statement "q1a" already exists
Time: 0.356 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 6.213 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 6.578 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 6.109 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 6.317 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 6.187 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 5.794 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 5.536 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 5.981 ms
postgres=# execute q1a;
             production_note             |    movie_title     | movie_year
-----------------------------------------+--------------------+------------
 (as Indo-British Films Ltd.) (presents) | A Clockwork Orange |       1934
(1 row)

Time: 6.122 ms
```

So around 6ms.

```
postgres=# EXPLAIN ANALYZE execute q1a;
                                                                                 QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=30010.08..30010.09 rows=1 width=45) (actual time=5.704..5.704 rows=1 loops=1)
   ->  Nested Loop  (cost=6482.03..30010.06 rows=3 width=45) (actual time=0.098..5.658 rows=142 loops=1)
         Join Filter: (mc.movie_id = t.id)
         ->  Hash Join  (cost=6481.60..30008.29 rows=3 width=32) (actual time=0.092..5.225 rows=142 loops=1)
               Hash Cond: (mc.company_type_id = ct.id)
               ->  Nested Loop  (cost=6462.68..29987.21 rows=566 width=36) (actual time=0.071..5.173 rows=147 loops=1)
                     ->  Nested Loop  (cost=6462.25..22168.36 rows=12213 width=4) (actual time=0.036..0.091 rows=250 loops=1)
                           ->  Seq Scan on info_type it  (cost=0.00..2.41 rows=1 width=4) (actual time=0.012..0.013 rows=1 loops=1)
                                 Filter: ((info)::text = 'top 250 rank'::text)
                                 Rows Removed by Filter: 112
                           ->  Bitmap Heap Scan on movie_info_idx mi_idx  (cost=6462.25..18715.86 rows=345009 width=8) (actual time=0.022..0.036 rows=250 loops=1)
                                 Recheck Cond: (info_type_id = it.id)
                                 Heap Blocks: exact=2
                                 ->  Bitmap Index Scan on info_type_id_movie_info_idx  (cost=0.00..6375.99 rows=345009 width=0) (actual time=0.015..0.015 rows=250 loops=1)
                                       Index Cond: (info_type_id = it.id)
                     ->  Index Scan using movie_id_movie_companies on movie_companies mc  (cost=0.43..0.63 rows=1 width=32) (actual time=0.020..0.020 rows=1 loops=250)
                           Index Cond: (movie_id = mi_idx.movie_id)
                           Filter: ((note !~~ '%(as Metro-Goldwyn-Mayer Pictures)%'::text) AND ((note ~~ '%(co-production)%'::text) OR (note ~~ '%(presents)%'::text)))
                           Rows Removed by Filter: 33
               ->  Hash  (cost=18.88..18.88 rows=4 width=4) (actual time=0.017..0.017 rows=1 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     ->  Seq Scan on company_type ct  (cost=0.00..18.88 rows=4 width=4) (actual time=0.011..0.011 rows=1 loops=1)
                           Filter: ((kind)::text = 'production companies'::text)
                           Rows Removed by Filter: 3
         ->  Index Scan using title_pkey on title t  (cost=0.43..0.58 rows=1 width=25) (actual time=0.003..0.003 rows=1 loops=142)
               Index Cond: (id = mi_idx.movie_id)
 Execution time: 5.757 ms
```

The overwhelming majority of the time is attributed to the final aggregate, which is weird. I don't know much about how it calculates these times, but I would expect producing the data to take at lesat as much time as reducing it.

Let's get some data into Imp!

``` julia
function read_job()
  schema = readdlm(open("data/job_schema.csv"), ',', header=false, quotes=true, comments=false)
  tables = Dict()
  for column in 1:size(schema)[1]
    table_name, ix, column_name, column_type = schema[column, 1:4]
    push!(get!(tables, table_name, []), (ix, column_name, column_type))
  end
  relations = []
  names = []
  for (table_name, columns) in tables
    if isfile("../job/$(table_name).csv")
      rows = readdlm(open("../job/$(table_name).csv"), ',', header=false, quotes=true, comments=false)
      n = size(rows)[1]
      ids = Int64[rows[r,1] for r in 1:n]
      push!(names, symbol(table_name))
      push!(relations, Relation((ids,)))
      for (ix, column_name, column_type) in columns[2:end]
        @show table_name ix column_name column_type
        if column_type == "integer"
          ids = Int64[]
          column = Int64[]
          for r in 1:n
            if !(rows[r, ix] in ("", "null", "NULL"))
              push!(ids, rows[r, 1])
              push!(column, rows[r, ix])
            end
          end
        else
          ids = Int64[]
          column = String[]
          for r in 1:n
            if !(rows[r, ix] in ("", "null", "NULL"))
              push!(ids, rows[r, 1])
              push!(column, string(rows[r, ix]))
            end
          end
        end
        push!(names, symbol(table_name, "_", column_name))
        push!(relations, Relation((ids, column)))
      end
    end
  end
  (names, relations)
end
```

This reads the schema I dumped out of postgres and builds a normalized set of relations (taking advantage of the fact that every table in the dataset has a single integer as it's primary key). I'm normalizing it this way to avoid having to represent with null entries directly. Possible future feature.

I'm using the stdlib csv reading function, which generates a single big array containing all the data, meaning that if there are any strings then all the integers have to be boxed too and everything goes to poop.

The csv reading code also returns `SubString`s - pointers to slices of the mmaped file - rather than allocating individual strings. But this seems unrealistic - I don't actually expect real-world data to arrive all in one nice contiguous file. So I'm reallocating them all as individual strings.

All of this means that loading the data takes FOREVER, but the final representation is pretty sensible. Later I'll have to find a faster way of doing this. Maybe DataFrames.jl is better?

``` julia
using DataFrames

function read_job()
  schema = readdlm(open("data/job_schema.csv"), ',', header=false, quotes=true, comments=false)
  table_column_names = Dict()
  table_column_types = Dict()
  for column in 1:size(schema)[1]
    table_name, ix, column_name, column_type = schema[column, 1:4]
    push!(get!(table_column_names, table_name, []), column_name)
    push!(get!(table_column_types, table_name, []), (column_type == "integer" ? Int64 : String))
  end
  relations = []
  names = []
  for (table_name, column_names) in table_column_names
    if isfile("../job/$(table_name).csv")
      column_types = table_column_types[table_name]
      @show table_name column_names column_types
      frame = readtable(open("../imdb/$(table_name).csv"), header=false, eltypes=column_types)
      n = length(frame[1])
      ids = copy(frame[1].data)
      for (ix, (column_name, column_type)) in enumerate(zip(column_names, column_types))
        @show table_name ix column_name column_type
        data_array = frame[ix]
        if ix == 1
          push!(names, symbol(table_name))
          push!(relations, Relation((ids,)))
        else
          column_ids = Int64[id for (ix, id) in enumerate(ids) if !(data_array.na[ix])]
          local column
          if isa(data_array, DataArray{Int64})
            let data::Vector{Int64} = data_array.data
              column = Int64[d for (ix, d) in enumerate(data) if !(data_array.na[ix])]
            end
          elseif isa(data_array, DataArray{String})
            let data::Vector{String} = data_array.data
              column = String[d for (ix, d) in enumerate(data_array.data) if !(data_array.na[ix])]
            end
          end
          push!(names, symbol(table_name, "_", column_name))
          push!(relations, Relation((column_ids, column)))
        end
      end
    end
  end
  (names, relations)
end
```

Woah, way way faster.

Weirdly, unpacking the results into individual variable names blows up with an out-of-memory error.

``` julia
person_info,person_info_person_id,person_info_info_type_id,person_info_info,person_info_note,title,title_title,title_imdb_index,title_kind_id,title_production_year,title_imdb_id,title_phonetic_code,title_episode_of_id,title_season_nr,title_episode_nr,title_series_years,title_md5sum,link_type,link_type_link,cast_info,cast_info_person_id,cast_info_movie_id,cast_info_person_role_id,cast_info_note,cast_info_nr_order,cast_info_role_id,movie_info_idx,movie_info_idx_movie_id,movie_info_idx_info_type_id,movie_info_idx_info,movie_info_idx_note,name,name_name,name_imdb_index,name_imdb_id,name_gender,name_name_pcode_cf,name_name_pcode_nf,name_surname_pcode,name_md5sum,info_type,info_type_info,aka_name,aka_name_person_id,aka_name_name,aka_name_imdb_index,aka_name_name_pcode_cf,aka_name_name_pcode_nf,aka_name_surname_pcode,aka_name_md5sum,movie_info,movie_info_movie_id,movie_info_info_type_id,movie_info_info,movie_info_note,role_type,role_type_role,aka_title,aka_title_movie_id,aka_title_title,aka_title_imdb_index,aka_title_kind_id,aka_title_production_year,aka_title_phonetic_code,aka_title_episode_of_id,aka_title_season_nr,aka_title_episode_nr,aka_title_note,aka_title_md5sum,complete_cast,complete_cast_movie_id,complete_cast_subject_id,complete_cast_status_id,movie_keyword,movie_keyword_movie_id,movie_keyword_keyword_id,kind_type,kind_type_kind,movie_link,movie_link_movie_id,movie_link_linked_movie_id,movie_link_link_type_id,company_name,company_name_name,company_name_country_code,company_name_imdb_id,company_name_name_pcode_nf,company_name_name_pcode_sf,company_name_md5sum,keyword,keyword_keyword,keyword_phonetic_code,comp_cast_type,comp_cast_type_kind,char_name,char_name_name,char_name_imdb_index,char_name_imdb_id,char_name_name_pcode_nf,char_name_surname_pcode,char_name_md5sum,movie_companies,movie_companies_movie_id,movie_companies_company_id,movie_companies_company_type_id,movie_companies_note,company_type,company_type_kind = relations
```

I have no idea why. At a guess, unpacking 100-odd variables at once triggers some weird corner case in the compiler.

But now the julia process is dead and I have to load all that data into memory again. Sigh...

The reason I wanted to unpack everything is that the query compiler currently can't handle non-symbol relation names eg `person_info_person_id(p, pi)` works but `db[:person_info, :person_id](p, pi)` does not. But I can fix that pretty easily - let's finally get around to wrapping the query in a function.

``` julia
function plan(...)
  ...
  quote
    # TODO pass through any external vars too to avoid closure boxing grossness
    function query($([symbol("relation_", clause) for clause in relation_clauses]...))
      $setup
      $body
      Relation(tuple($([symbol("results_", variable) for variable in returned_variables]...), results_aggregate))
    end
    query($([esc(query.args[clause].args[1]) for clause in relation_clauses]...))
  end
end
```

So the generated code will look like:

``` julia
function query(relation_1, ...)
  ...
end
query(db[:person_info, :person_id], ...)
```

Now I'll load the imdb data into a dict of relations, and then try to serialize it so I don't have to do it again:

``` julia
job = @time read_job()

open("../job/imp.bin", "w") do f
    @time serialize(f, job)
end

# 743.572276 seconds (4.92 G allocations: 139.663 GB, 65.42% gc time)
# 42.551220 seconds (92.15 M allocations: 1.384 GB, 7.74% gc time)
```

140GB of temporary allocations. Something in there is still a mess.

``` julia
job = @time deserialize(open("../job/imp.bin"))
# 700.359796 seconds (943.00 M allocations: 50.969 GB, 78.30% gc time)
# OutOfMemoryError()
```

So that's weird. It made a big mess of allocations deserializing the data, finished, then about 3 seconds later threw an out of memory error.

Later, trying to rebuild the dataset, Julia dies with:

```
Julia has stopped: null, SIGKILL
```

This is frustrating. Reading a 6gb dataset on a machine with 32gb of ram should not be difficult.

After several attempts, JLD manages to both save and load the dataset without exploding, although never both sequentially. After gc, top shows:

```
13908 jamie     20   0 22.560g 0.017t  64752 S  61.4 54.2   2:03.90 julia
```

I asked to see the results (bearing in mind that the representation is truncated) and...

```
OutOfMemoryError()
 in resize!(::Array{UInt8,1}, ::UInt64) at ./array.jl:470
 in ensureroom at ./iobuffer.jl:194 [inlined]
 in unsafe_write(::Base.AbstractIOBuffer{Array{UInt8,1}}, ::Ptr{UInt8}, ::UInt64) at ./iobuffer.jl:275
 in write(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Array{UInt8,1}) at ./io.jl:161
 in show at ./show.jl:234 [inlined]
 in show_delim_array(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Array{Int64,1}, ::String, ::String, ::String, ::Bool, ::Int64, ::Int64) at ./show.jl:318
 in show_delim_array(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Array{Int64,1}, ::String, ::String, ::String, ::Bool) at ./show.jl:300
 in show_vector(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Array{Int64,1}, ::String, ::String) at ./show.jl:1666
 in #showarray#252(::Bool, ::Function, ::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Array{Int64,1}, ::Bool) at ./show.jl:1585
 in show_delim_array(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Tuple{Array{Int64,1},Array{Int64,1}}, ::Char, ::Char, ::Char, ::Bool, ::Int64, ::Int64) at ./show.jl:355
 in show(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Tuple{Array{Int64,1},Array{Int64,1}}) at ./show.jl:376
 in show_default(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Any) at ./show.jl:130
 in show(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::Any) at ./show.jl:116
 in show(::IOContext{Base.AbstractIOBuffer{Array{UInt8,1}}}, ::MIME{Symbol("text/plain")}, ::Dict{Any,Any}) at ./replutil.jl:94
 in verbose_show(::Base.AbstractIOBuffer{Array{UInt8,1}}, ::MIME{Symbol("text/plain")}, ::Dict{Any,Any}) at ./multimedia.jl:50
 in #sprint#226(::Void, ::Function, ::Int64, ::Function, ::MIME{Symbol("text/plain")}, ::Vararg{Any,N}) at ./strings/io.jl:37
 in Type at /home/jamie/.julia/v0.5/Atom/src/display/view.jl:78 [inlined]
 in Type at /home/jamie/.julia/v0.5/Atom/src/display/view.jl:79 [inlined]
 in render(::Atom.Editor, ::Dict{Any,Any}) at /home/jamie/.julia/v0.5/Atom/src/display/display.jl:23
 in (::Atom.##91#95)(::Dict{String,Any}) at /home/jamie/.julia/v0.5/Atom/src/eval.jl:62
 in handlemsg(::Dict{String,Any}, ::Dict{String,Any}, ::Vararg{Dict{String,Any},N}) at /home/jamie/.julia/v0.5/Atom/src/comm.jl:71
 in (::Atom.##5#8)() at ./event.jl:46
```

But if I treat it with kid gloves and never ask to see the actual result, I can write my first tiny query against the dataset:

``` julia
@query([cid, cn],
[cid::Int64, cn::String],
begin
  job["company_name", "name"](cid, cn)
end)
```

That works fine.

But if I wrap it in a function and run the function I get a bounds error (which takes a long time to generate because Julia prints the entire relation in the error). I think inside a function scope, functions are all defined up top, but globally the definitions are executed sequentially. So if the function names collide, behaviour in each scope is different. I added a counter just uniquefies each function name and the problem went away.

Let's have a go at query 1a.

``` julia
# SELECT MIN(mc.note) AS production_note,
#        MIN(t.title) AS movie_title,
#        MIN(t.production_year) AS movie_year
# FROM company_type AS ct,
#      info_type AS it,
#      movie_companies AS mc,
#      movie_info_idx AS mi_idx,
#      title AS t
# WHERE ct.kind = 'production companies'
#   AND it.info = 'top 250 rank'
#   AND mc.note NOT LIKE '%(as Metro-Goldwyn-Mayer Pictures)%'
#   AND (mc.note LIKE '%(co-production)%'
#        OR mc.note LIKE '%(presents)%')
#   AND ct.id = mc.company_type_id
#   AND t.id = mc.movie_id
#   AND t.id = mi_idx.movie_id
#   AND mc.movie_id = mi_idx.movie_id
#   AND it.id = mi_idx.info_type_id;

function f()
  @query([],
  [ct_kind::String, ct_id::Int64, mc_id::Int64, mc_note::String, t_id::Int64, mii_id::Int64, it_id::Int64, it_info::String, t_production_year::Int64],
  (3000, min_exp, t_production_year),
  begin
    ct_kind = "production companies"
    it_info = "top 250 rank"
    job["company_type", "kind"](ct_id, ct_kind)
    job["info_type", "info"](it_id, it_info)
    job["movie_companies", "note"](mc_id, mc_note)
    ismatch(r".*as Metro-Goldwyn-Mayer Pictures.*", mc_note) == false
    (ismatch(r".*co-production.*", mc_note) || ismatch(r".*presents.*", mc_note)) == true
    job["movie_companies", "company_type_id"](mc_id, ct_id)
    job["title", "production_year"](t_id, t_production_year)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_info_idx", "movie_id"](mii_id, t_id)
    job["movie_info_idx", "info_type_id"](mii_id, it_id)
  end)
end

# first run (indexing + compilation)
# 7.278131 seconds (479.39 k allocations: 192.071 MB, 82.77% gc time)

# second run
# 0.118113 seconds (292.96 k allocations: 4.476 MB)
```

118ms. Not going to knock postgres off any pedastals just yet.

I want to know what's going on with those allocations. There should barely be any. I squelched a few type-inference failures but it didn't change the number of allocations at all, which is weird.

### 2016 Aug 09

Looks like `ismatch` causes a single heap allocation on each call. So nothing wrong with my compiler.

Let's pick a query with no regexes.

``` julia
# SELECT MIN(t.title) AS movie_title
# FROM company_name AS cn,
#      keyword AS k,
#      movie_companies AS mc,
#      movie_keyword AS mk,
#      title AS t
# WHERE cn.country_code ='[de]'
#   AND k.keyword ='character-name-in-title'
#   AND cn.id = mc.company_id
#   AND mc.movie_id = t.id
#   AND t.id = mk.movie_id
#   AND mk.keyword_id = k.id
#   AND mc.movie_id = mk.movie_id;

function q2a()
  @query([],
  [cnit::String, k_id::Int64, mk_id::Int64, t_id::Int64, mc_id::Int64, cn_id::Int64, de::String, title::String],
  ("zzzzzzzzzzz", min_exp, title::String),
  begin
    de = "[de]"
    job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    job["movie_companies", "company_id"](mc_id, cn_id)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    job["title", "title"](t_id, title)
  end)
end

@time q2a()

# 1.998575 seconds (142.43 k allocations: 44.412 MB, 63.25% gc time)
# 0.126513 seconds (108 allocations: 7.250 KB)
# 0.125623 seconds (108 allocations: 7.250 KB)
```

```
postgres=# execute q2a;
       movie_title
--------------------------
 008 - Agent wider Willen
(1 row)

Time: 2388.770 ms
postgres=# execute q2a;
       movie_title
--------------------------
 008 - Agent wider Willen
(1 row)

Time: 449.339 ms
postgres=# execute q2a;
       movie_title
--------------------------
 008 - Agent wider Willen
(1 row)

Time: 449.340 ms
```

Not worth reading too much into that, because I'm getting a different answer to postgres.

Man, where do I even start debugging something like that. I guess, break the query down into pieces and find where it starts to diverge.

``` julia
function q2a()
  @query([cnit, k_id],
  [cnit::String, k_id::Int64], #, mk_id::Int64, t_id::Int64, mc_id::Int64, cn_id::Int64, de::String, title::String],
  begin
    # de = "[de]"
    # job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    # job["movie_companies", "company_id"](mc_id, cn_id)
    # job["movie_companies", "movie_id"](mc_id, t_id)
    # job["movie_keyword", "movie_id"](mk_id, t_id)
    # job["movie_keyword", "keyword_id"](mk_id, k_id)
    # job["title", "title"](t_id, title)
  end)
end

function q2a()
  @query([mk_id],
  [cnit::String, k_id::Int64, mk_id::Int64], # t_id::Int64, mc_id::Int64, cn_id::Int64, de::String, title::String],
  begin
    # de = "[de]"
    # job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    # job["movie_companies", "company_id"](mc_id, cn_id)
    # job["movie_companies", "movie_id"](mc_id, t_id)
    # job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    # job["title", "title"](t_id, title)
  end)
end

function q2a()
  @query([t_id],
  [cnit::String, k_id::Int64, mk_id::Int64, t_id::Int64], #, mc_id::Int64, cn_id::Int64, de::String, title::String],
  begin
    # de = "[de]"
    # job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    # job["movie_companies", "company_id"](mc_id, cn_id)
    # job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    # job["title", "title"](t_id, title)
  end)
end

function q2a()
  @query([mc_id],
  [cnit::String, k_id::Int64, mk_id::Int64, t_id::Int64, mc_id::Int64], # cn_id::Int64, de::String, title::String],
  begin
    # de = "[de]"
    # job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    # job["movie_companies", "company_id"](mc_id, cn_id)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    # job["title", "title"](t_id, title)
  end)
end

function q2a()
  @query([cn_id],
  [cnit::String, k_id::Int64, mk_id::Int64, t_id::Int64, mc_id::Int64, cn_id::Int64], #, de::String, title::String],
  begin
    # de = "[de]"
    # job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    job["movie_companies", "company_id"](mc_id, cn_id)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    # job["title", "title"](t_id, title)
  end)
end

function q2a()
  @query([title],
  [cnit::String, k_id::Int64, mk_id::Int64, t_id::Int64, mc_id::Int64, cn_id::Int64, de::String, title::String],
  begin
    de = "[de]"
    job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    job["movie_companies", "company_id"](mc_id, cn_id)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    job["title", "title"](t_id, title)
  end)
end
```

Eugh, that was tedious. Turns out that the query is correct, but `min` in sql uses a different ordering and I forget to use `count(distinct ...)` when I double-checked the total results.

So let's have sql return the distinct count and Imp return the column of results, which seems roughly fair.

```
postgres=# execute q2a_all;
Time: 443.249 ms
postgres=# prepare q2a_distinct as select count(distinct t.title) AS movie_title FROM company_name AS cn, keyword AS k, movie_companies AS mc, movie_keyword AS mk, title AS t WHERE cn.country_code ='[de]' AND k.keyword ='character-name-in-title' AND cn.id = mc.company_id AND mc.movie_id = t.id AND t.id = mk.movie_id AND mk.keyword_id = k.id AND mc.movie_id = mk.movie_id;
PREPARE
Time: 0.468 ms
postgres=# execute q2a_distinct
postgres-# ;
 movie_title
-------------
        4127
(1 row)

Time: 455.719 ms
postgres=# execute q2a_distinct;
 movie_title
-------------
        4127
(1 row)

Time: 450.318 ms
postgres=# execute q2a_distinct;
 movie_title
-------------
        4127
(1 row)

Time: 441.992 ms
```

``` julia
function q2a()
  @query([title],
  [cnit::String, k_id::Int64, mk_id::Int64, t_id::Int64, mc_id::Int64, cn_id::Int64, de::String, title::String],
  begin
    de = "[de]"
    job["company_name", "country_code"](cn_id, de)
    cnit = "character-name-in-title"
    job["keyword", "keyword"](k_id, cnit)
    job["movie_companies", "company_id"](mc_id, cn_id)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    job["title", "title"](t_id, title)
  end)
end

@time q2a()

# 0.128545 seconds (197 allocations: 646.297 KB)
# 0.140465 seconds (197 allocations: 646.297 KB)
# 0.138893 seconds (197 allocations: 646.297 KB)
```

Score. Faster than postgres on q2a, with the first variable ordering I tried.

Let's go back to q1a and steal the execution plan from postgres.

```
postgres=# prepare q1a_distinct as SELECT count(distinct t.production_year) AS movie_year FROM company_type AS ct, info_type AS it, movie_companies AS mc, movie_info_idx AS mi_idx, title AS t WHERE ct.kind = 'production companies' AND it.info = 'top 250 rank' AND mc.note  not like '%(as Metro-Goldwyn-Mayer Pictures)%' and (mc.note like '%(co-production)%' or mc.note like '%(presents)%') AND ct.id = mc.company_type_id AND t.id = mc.movie_id AND t.id = mi_idx.movie_id AND mc.movie_id = mi_idx.movie_id AND it.id = mi_idx.info_type_id;
ERROR:  prepared statement "q1a_distinct" already exists
Time: 0.715 ms
postgres=# explain analyze execute q1a_distinct;
                                                                                 QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=30010.06..30010.07 rows=1 width=4) (actual time=9.987..9.987 rows=1 loops=1)
   ->  Nested Loop  (cost=6482.03..30010.06 rows=3 width=4) (actual time=0.314..9.934 rows=142 loops=1)
         Join Filter: (mc.movie_id = t.id)
         ->  Hash Join  (cost=6481.60..30008.29 rows=3 width=8) (actual time=0.302..9.292 rows=142 loops=1)
               Hash Cond: (mc.company_type_id = ct.id)
               ->  Nested Loop  (cost=6462.68..29987.21 rows=566 width=12) (actual time=0.266..9.193 rows=147 loops=1)
                     ->  Nested Loop  (cost=6462.25..22168.36 rows=12213 width=4) (actual time=0.137..0.243 rows=250 loops=1)
                           ->  Seq Scan on info_type it  (cost=0.00..2.41 rows=1 width=4) (actual time=0.031..0.033 rows=1 loops=1)
                                 Filter: ((info)::text = 'top 250 rank'::text)
                                 Rows Removed by Filter: 112
                           ->  Bitmap Heap Scan on movie_info_idx mi_idx  (cost=6462.25..18715.86 rows=345009 width=8) (actual time=0.100..0.160 rows=250 loops=1)
                                 Recheck Cond: (info_type_id = it.id)
                                 Heap Blocks: exact=2
                                 ->  Bitmap Index Scan on info_type_id_movie_info_idx  (cost=0.00..6375.99 rows=345009 width=0) (actual time=0.070..0.070 rows=250 loops=1)
                                       Index Cond: (info_type_id = it.id)
                     ->  Index Scan using movie_id_movie_companies on movie_companies mc  (cost=0.43..0.63 rows=1 width=8) (actual time=0.035..0.035 rows=1 loops=250)
                           Index Cond: (movie_id = mi_idx.movie_id)
                           Filter: ((note !~~ '%(as Metro-Goldwyn-Mayer Pictures)%'::text) AND ((note ~~ '%(co-production)%'::text) OR (note ~~ '%(presents)%'::text)))
                           Rows Removed by Filter: 33
               ->  Hash  (cost=18.88..18.88 rows=4 width=4) (actual time=0.023..0.023 rows=1 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 9kB
                     ->  Seq Scan on company_type ct  (cost=0.00..18.88 rows=4 width=4) (actual time=0.017..0.019 rows=1 loops=1)
                           Filter: ((kind)::text = 'production companies'::text)
                           Rows Removed by Filter: 3
         ->  Index Scan using title_pkey on title t  (cost=0.43..0.58 rows=1 width=8) (actual time=0.004..0.004 rows=1 loops=142)
               Index Cond: (id = mi_idx.movie_id)
 Execution time: 10.158 ms
(27 rows)

Time: 10.551 ms
postgres=# execute q1a_distinct;
 movie_year
------------
         57
(1 row)

Time: 20.732 ms
postgres=# execute q1a_distinct;
 movie_year
------------
         57
(1 row)

Time: 18.280 ms
```

The execution plan is a bit bushy so I can't copy it perfectly without caching or factorisation, but I can approximate it with this ordering.

``` julia
function q1a()
  @query([t_production_year],
  [it_info::String, it_id::Int64, mii_id::Int64, t_id::Int64, ct_id::Int64, ct_kind::String, mc_id::Int64, mc_note::String, t_production_year::Int64],
  begin
    ct_kind = "production companies"
    it_info = "top 250 rank"
    job["company_type", "kind"](ct_id, ct_kind)
    job["info_type", "info"](it_id, it_info)
    job["movie_companies", "note"](mc_id, mc_note)
    ismatch(r".*as Metro-Goldwyn-Mayer Pictures.*", mc_note) == false
    (ismatch(r".*co-production.*", mc_note) || ismatch(r".*presents.*", mc_note)) == true
    job["movie_companies", "company_type_id"](mc_id, ct_id)
    job["title", "production_year"](t_id, t_production_year)
    job["movie_companies", "movie_id"](mc_id, t_id)
    job["movie_info_idx", "movie_id"](mii_id, t_id)
    job["movie_info_idx", "info_type_id"](mii_id, it_id)
  end)
end

@time q1a()

# 0.004359 seconds (1.05 k allocations: 35.516 KB)
# 0.002895 seconds (1.05 k allocations: 35.516 KB)
# 0.003321 seconds (1.05 k allocations: 35.516 KB)
```

So my code is fine, I'm just a crappy query planner.

I only had an hour or two to work on this today, but I'm glad I got to see some exciting numbers.

### 2016 Aug 10

So here is q3a:

``` julia

function q3a()
  # "Denish" is in original too
  mi_infos = Set(["Sweden", "Norway", "Germany", "Denmark", "Swedish", "Denish", "Norwegian", "German"])
  @query([t_title],
  [mi_info::String, mi_id::Int64, k_keyword::String, k_id::Int64, mk_id::Int64, t_id::Int64, t_production_year::Int64, t_title::String],
  begin
    job["keyword", "keyword"](k_id, k_keyword)
    contains(k_keyword, "sequel") == true
    job["movie_info", "info"](mi_id, mi_info)
    (mi_info in mi_infos) == true
    job["title", "production_year"](t_id, t_production_year)
    t_production_year > 2005
    job["movie_info", "movie_id"](mi_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    job["title", "title"](t_id, t_title)
  end)
end
```

It touches `movie_info` which is one of the biggest tables in the dataset at ~15m rows. This takes forever to index, so long that I haven't succesfully waited it out yet.

(I have to restart Julia if something gets stuck in a loop or is taking too long, which means reloading the IMDB dataset. Sometimes Atom gets stuck and can't restart Julia, so I have to restart Atom too. Sometimes Atom forgets my project settings, so I have to reopen and reorganize all the files I'm working with. This costs me a significant proportion of the day and the endless context switches are a huge problem. What can I improve?)

But if I index a similarly-sized relation full of random integers:

``` julia
edge = Relation((rand(1:Int64(1E5), Int64(15E6)), rand(1:Int64(1E5), Int64(15E6))))
@time index(edge, [1,2])
# 2.178177 seconds (146.18 k allocations: 235.030 MB, 0.84% gc time)
```

Even if I put in a string column and force it so touch all the strings:

``` julia
edge = Relation(([1 for _ in 1:Int64(15E6)], String[string(i) for i in rand(1:Int64(1E5), Int64(15E6))]))
@time index(edge, [1,2])
# 17.183060 seconds (59 allocations: 228.885 MB)
```

Sorting the text version of movie_info at the terminal works ok:

```
jamie@machine:~$ time sort job/movie_info.csv > /dev/null

real	0m8.972s
user	0m30.316s
sys	0m4.148s
```

So what's the deal? Why does this take seconds when `movie_info` takes hours or more?

Maybe there's a bug in my quicksort? Let's print the lo/hi for each recursive call and see if it's getting stuck somewhere.

Eugh, atom crashed. Maybe let's print to a file then.

```
...
14431187 14431188
14431184 14431185
14431181 14431182
14431178 14431179
14431175 14431176
14431172 14431173
14431169 14431170
14431166 14431167
14431163 14431164
14431160 14431161
14431157 14431158
14431154 14431155
14431151 14431152
14431148 14431149
14431145 14431146
14431142 14431143
14431139 14431140
14431136 14431137
14431133 14431134
14431130 14431131
14431127 14431128
14431124 14431125
14431121 14431122
14431118 14431119
14431115 14431116
14431112 14431113
...
```

Look at that, recursive calls to `quicksort!` on a bunch of single element subarrays, spaced out by exactly 3 each time. Something funky is going on.

Let's look at the function I copied from the stdlib. There is some weirdness in here where it sorts the smallest partition first and then recurs on the larger partition.

``` julia
function quicksort!($(cs...), lo::Int, hi::Int)
  write(test, string(lo, " ", hi, "\n"))
  @inbounds while lo < hi
    if hi-lo <= 20
      insertion_sort!($(cs...), lo, hi)
      return
    end
    j = partition!($(cs...), lo, hi)
    if j-lo < hi-j
      lo < (j-1) && quicksort!($(cs...), lo, j-1)
      lo = j+1
    else
      j+1 < hi && quicksort!($(cs...), j+1, hi)
      hi = j-1
    end
  end
  return
end
```

It also does something funky to get lo/mid/hi in the right order before partitioning:

``` julia
@inline function select_pivot!($(cs...), lo::Int, hi::Int)
  @inbounds begin
    mi = (lo+hi)>>>1
    if lt($(cs...), mi, lo)
      swap2($(cs...), lo, mi)
    end
    if lt($(cs...), hi, mi)
      if lt($(cs...), hi, lo)
        swap3($(cs...), lo, mi, hi)
      else
        swap2($(cs...), mi, hi)
      end
    end
    swap2($(cs...), lo, mi)
  end
  return lo
end
```

Let's try just picking pivots at random.

``` julia
function partition!($(cs...), lo::Int, hi::Int)
  @inbounds begin
    pivot = rand(lo:hi)
    swap2($(cs...), pivot, lo)
    i, j = lo+1, hi
    while true
      while lt($(cs...), i, lo); i += 1; end;
      while lt($(cs...), lo, j); j -= 1; end;
      i >= j && break
      swap2($(cs...), i, j)
      i += 1; j -= 1
    end
    swap2($(cs...), lo, j)
    return j
  end
end

function quicksort!($(cs...), lo::Int, hi::Int)
  @inbounds if hi-lo <= 0
    return
  elseif hi-lo <= 20
    insertion_sort!($(cs...), lo, hi)
  else
    j = partition!($(cs...), lo, hi)
    quicksort!($(cs...), lo, j-1)
    quicksort!($(cs...), j+1, hi)
  end
end
```

Not totally sure that's correct, but I haven't found any mis-sorts so far.

Sorting becomes slightly slower, maybe around 10%, not enough to make me care, because:

``` julia
@time index(job["movie_info", "info"], [1,2])
# 1.450726 seconds (210.51 k allocations: 235.458 MB)
```

``` julia
function q3a()
  # "Denish" is in original too
  mi_infos = Set(["Sweden", "Norway", "Germany", "Denmark", "Swedish", "Denish", "Norwegian", "German"])
  @query([t_title],
  [k_keyword::String, k_id::Int64, mk_id::Int64, t_id::Int64, t_title::String, t_production_year::Int64, mi_id::Int64, mi_info::String],
  begin
    job["keyword", "keyword"](k_id, k_keyword)
    contains(k_keyword, "sequel") == true
    job["movie_info", "info"](mi_id, mi_info)
    (mi_info in mi_infos) == true
    job["title", "production_year"](t_id, t_production_year)
    t_production_year > 2005
    job["movie_info", "movie_id"](mi_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    job["title", "title"](t_id, t_title)
  end)
end

# Job.q3a x1 (+compilation +indexing)
#  5.088275 seconds (545.92 k allocations: 692.371 MB)
# Job.q3a x20
#  2.178364 seconds (3.60 k allocations: 510.625 KB)
```

```
postgres=# prepare q3a_distinct as SELECT count(distinct t.title) AS movie_title FROM keyword AS k, movie_info AS mi, movie_keyword AS mk, title AS t WHERE k.keyword  like '%sequel%' AND mi.info  IN ('Sweden', 'Norway', 'Germany', 'Denmark', 'Swedish', 'Denish', 'Norwegian', 'German') AND t.production_year > 2005 AND t.id = mi.movie_id AND t.id = mk.movie_id AND mk.movie_id = mi.movie_id AND k.id = mk.keyword_id;
PREPARE
Time: 5.955 ms
postgres=# execute q3a_distinct;
 movie_title
-------------
         105
(1 row)

Time: 2596.093 ms
postgres=# execute q3a_distinct;
 movie_title
-------------
         105
(1 row)

Time: 220.938 ms
postgres=# execute q3a_distinct;
 movie_title
-------------
         105
(1 row)

Time: 187.519 ms
postgres=# execute q3a_distinct;
 movie_title
-------------
         105
(1 row)

Time: 177.598 ms
```

About 2x faster than postgres on this one. Imp is a bit handicapped atm because it can't turn that `in` into a join, and instead gets stuck with a table scan. Should be an easy optimisation to add though.

I wrote q4a early while waiting on q3a, so let's try that too.

``` julia
function q4a()
  @query([mii_info],
  [k_keyword::String, k_id::Int64, mk_id::Int64, t_id::Int64, t_production_year::Int64, it_info::String, it_id::Int64, mii_id::Int64, mii_info::String],
  begin
    job["info_type", "info"](it_id, it_info)
    it_info = "rating"
    job["keyword", "keyword"](k_id, k_keyword)
    contains(k_keyword, "sequel") == true
    job["movie_info_idx", "info"](mii_id, mii_info)
    mii_info > "5.0"
    job["title", "production_year"](t_id, t_production_year)
    t_production_year > 2005
    job["movie_info_idx", "movie_id"](mii_id, t_id)
    job["movie_keyword", "movie_id"](mk_id, t_id)
    job["movie_keyword", "keyword_id"](mk_id, k_id)
    job["title", "title"](t_id, t_title)
    job["movie_info_idx", "info_type_id"](mii_id, it_id)
    job["movie_info_idx", "movie_id"](mii_id, t_id)
  end)
end

# Job.q4a x1 (+compilation +indexing)
#   0.552385 seconds (63.57 k allocations: 43.060 MB)
# Job.q4a x100
#   5.834656 seconds (24.30 k allocations: 5.669 MB)
```

```
postgres=# prepare q4a_distinct as SELECT count(distinct mi_idx.info) AS rating, MIN(t.title) AS movie_title FROM info_type AS it, keyword AS k, movie_info_idx AS mi_idx, movie_keyword AS mk, title AS t WHERE it.info ='rating' AND k.keyword  like '%sequel%' AND mi_idx.info  > '5.0' AND t.production_year > 2005 AND t.id = mi_idx.movie_id AND t.id = mk.movie_id AND mk.movie_id = mi_idx.movie_id AND k.id = mk.keyword_id AND it.id = mi_idx.info_type_id;
PREPARE
Time: 0.420 ms
postgres=# execute q4a_distinct;
 rating |                movie_title
--------+--------------------------------------------
     45 | 20-seiki shônen: Dai 2 shô - Saigo no kibô
(1 row)

Time: 226.453 ms
postgres=# execute q4a_distinct;
 rating |                movie_title
--------+--------------------------------------------
     45 | 20-seiki shônen: Dai 2 shô - Saigo no kibô
(1 row)

Time: 123.440 ms
postgres=# execute q4a_distinct;
 rating |                movie_title
--------+--------------------------------------------
     45 | 20-seiki shônen: Dai 2 shô - Saigo no kibô
(1 row)

Time: 119.281 ms
postgres=# execute q4a_distinct;
 rating |                movie_title
--------+--------------------------------------------
     45 | 20-seiki shônen: Dai 2 shô - Saigo no kibô
(1 row)

Time: 123.111 ms
```

A little over 2x faster than postgres.

That's all I have time for today. What next? I could keep going with these benchmarks and setup proper harnesses and tune postgres properly so they are, you know, actual benchmarks and not just a for loop and some guess work. I could fix the query syntax, which is painful and error-prone and would be nice to fix before writing out 100-odd queries. I could add some automated tests instead of hand-checking things against sql.

I have two more days before I go climbing, so maybe I'll see if I can come up with a nicer syntax in that time. Adding more benchmark queries is something that's easy to do with little chunks of time while travelling, but figuring out the syntax requires some concentration.

### 2016 Aug 11

There are two problems I want to fix with the syntax.

First, naming the tables is verbose and error prone eg `job["company_type", "kind"]`. It would be nice to just call this `kind` and somehow resolve the ambiguity with other similary named tables.

Second, the bulk of each the queries so far consists of chains of lookups which are difficult to follow in this form (and in sql too). Compare:

``` sql
FROM company_type AS ct,
     info_type AS it,
     movie_companies AS mc,
     movie_info_idx AS mi_idx,
     title AS t
WHERE ct.kind = 'production companies'
  AND it.info = 'top 250 rank'
  AND mc.note NOT LIKE '%(as Metro-Goldwyn-Mayer Pictures)%'
  AND (mc.note LIKE '%(co-production)%'
       OR mc.note LIKE '%(presents)%')
  AND ct.id = mc.company_type_id
  AND t.id = mc.movie_id
  AND t.id = mi_idx.movie_id
  AND mc.movie_id = mi_idx.movie_id
  AND it.id = mi_idx.info_type_id;
```

```
title.movie_info.info_type.info = 'top 250 rank'
title.movie_companies.company_type.kind = 'production_companies'
title.movie_companies.note = note
!note.like('%(as Metro-Goldwyn-Mayer Pictures)%') and
  (note.like('%(co-production)%') || note.like('%(presents)%'))
```

The structure and intent of the query is so much more obvious in the latter (made-up) syntax.

SQL handles the first problem by using tables as namespaces. This has the disadvantage that the namespace is closed - if I want to add more information about, say, `title`, I have to do so with a new table that refers to `title` with a foreign key, and I'm back to the chaining problem.

LogicBlox has a neat syntax where relations are reduced to sixth normal form and treated as finite functions, so one can write:

```
info(info_type(movie_info(title))) = 'top 250 rank'
```

It doesn't have any disambiguation mechanism other than namespaces though, so in practice that might be something like:

```
movei_info.info(movie_info.info_type(title.movie_info(title))) = 'top 250 rank'
```

Datomic (and I think Eve?) has an alternative option - rather than disambiguating several `name` relations, you just emit `7 :name "Best Film Ever"` and ensure that the entity `7` is not used anywhere else. Effectively the disambiguation is done by whatever constructs the entity ids, rather than by the relation name.

The main thing I dislike about this is the existence of unique entity ids. Creating unique identities is easy enough in an imperative model - just generate something random at transaction time. But in a timeless model, identity is much trickier. I don't really have a firm enough grasp on what I mean by that to explain it, but I have a fuzzy sort of intuition that it's an important problem and that existing programming models handle it in a way that causes problems. Certainly, it's a problem I run into in many different areas. I don't have a good idea of what I'm going to do about it, so I don't want to pick a model that railroads me into any particular notion of identity.

So, back to the problem. I could make this nicer with a combination of foreign key declarations and type inference, so that we can have many relations called `name` but each must have a different schema.

```
name(title.id) -> string
name(company.id) -> string

t::title
t.name # resolves to name(title.id) -> string
```

This is really appealing because it recovers the SQL-style namespacing, but allows open additions, doesn't require ids to be globally unique and can handle multi-column keys. The use of foreign key constraints in the schema also allows for auto-completing such lookups in the future.

A year or two ago I would probably have jumped in and started working on this. These days I'm a bit warier.

This system requires a database schema, which is known at compile time. I have to write a type-inference algorithm. There needs to be some way to report ambiguous names to the user. It only works for foreign-key joins, so there needs to be some separate system for disambiguating other joins. It's not obviously open to extension. And all I get for that effort is slightly less typing.

A mistake I used to make far too often is to make design decisions like these based only on how the value of the outcome, rather than on the effort-value ratio.

Let's do something much simpler. We can clean up the chaining by switching the syntax from `relation(x,y,z)` to `(x,y,z) > relation`, and allowing prefixes such as `(x,y) > relation = z` and `x.relation > (y,z)`, and similarly `(x,y,z) < relation`, `(y,z) < relation = x`, `z < relation = (x,y)`. This allows writing chains like `title < movie_info_title > movie_info_type < info_type_info = 'top 250 rank'` in most cases, but without losing the full generality of relations.

We'll still allow arbitrary Julia expressions as relation names,. So depending on how the relations are stored in Julia we could write any one of:

```
title < movie_info_title > movie_info_type < info_type_info = "top 250 rank"
title < Job.movie_info.title > Job.movie_info.type < Job.info_type.info = "top 250 rank"
title < job["movie_info", "title"] > job["movie_info", "type"] < job["info_type", "info"] = "top 250 rank"
```

i.e. rather than writing our own namespace system for Imp, just call out to Julia and let the user do whatever.

We also need a way to execute Julia functions and filters. Let's use `=` to signify that the RHS is arbitrary Julia code to be run on each tuple, rather than a relational Imp expression:

```
x::Int64 = y + 1 # assignment
true = x > y # filter
```

This is becoming a theme in Imp - handling only the core value-adding parts myself and fobbing everything else off on Julia. It's very similar to how [Terra](http://terralang.org/) handles low-level coding but delegates namespaces, packaging, macros, polymorphism etc to Lua.


(We could maybe even add a macro system to allow eg:

```
@path title info
```

Where `path` is some user-defined function that reads a schema, figures out the obvious join path between title and info, and returns the corresponding query fragment. [This paper](http://homepages.inf.ed.ac.uk/wadler/papers/qdsl/pepm.pdf) has some really interesting ideas along those lines.)

Let's write out the first few JOB queries in this imagined syntax, to see how it behaves:

``` julia
q1a = @query(production_year) begin
  "top 250 rank" < info_type.info < movie_info.info_type < movie_info
  movie_info > movie_info.movie_id > title
  title > title.production_year > production_year
  title < movie_companies.movie_id < movie_company
  movie_company > movie_companies.company_type > company_type.kind > "production companies"
  movie_company > movie_companies.note > note
  true = !contains(note, "as Metro-Goldwyn-Mayer Pictures") && (contains(note, "co-production") || contains(note, "presents")
end
```

Hmmm. It's *ok*. Syntax highlighting to separate variables from relations would really help.

You might notice that I don't really need `<`, since eg `title < movie_companies.movie_id < movie_company` could be written as `movie_company > movie_companies.movie_id > title`, and using both in the same line is actually kind of confusing. But... I want to have the flexibility to use both because I want to convey variable ordering directly in the query, by just taking the first occurence of each variable. Eg the above query would produce the ordering `[#info, #info_type, movie_info, title, production_year, movie_company, #company_type, #kind, #note]` (where variables beginning with # are unnamed intermediates in chains).

The `true = ...` is gross though. Maybe I should pick a symbol that's less commonly used in Julia, like `|>` or `>>`, and declare that any line containing that symbol is an Imp line. I wish I could use `->` and `<-` but Julia doesn't parse those as functions calls.

``` julia
julia> :(foo -> bar -> baz)
:(foo->begin  # none, line 1:
            bar->begin  # none, line 1:
                    baz
                end
        end)

julia> :(foo <- bar <- baz)
:(foo < -bar < -baz)
```

Hmmm, let's see:

``` julia
q1a = @query(production_year) begin
  "top 250 rank" << info_type.info << movie_info.info_type << movie_info
  movie_info >> movie_info.movie_id >> title
  title >> title.production_year >> production_year
  title << movie_companies.movie_id << movie_company
  movie_company >> movie_companies.company_type >> company_type.kind >> "production companies"
  movie_company >> movie_companies.note >> note
  !contains(note, "as Metro-Goldwyn-Mayer Pictures") && (contains(note, "co-production") || contains(note, "presents"))
end
```

``` julia
q1a = @query(production_year) begin
  "top 250 rank" <| info_type.info <| movie_info.info_type <| movie_info
  movie_info |> movie_info.movie_id |> title
  title |> title.production_year |> production_year
  title <| movie_companies.movie_id <| movie_company
  movie_company |> movie_companies.company_type |> company_type.kind |> "production companies"
  movie_company |> movie_companies.note |> note
  !contains(note, "as Metro-Goldwyn-Mayer Pictures") && (contains(note, "co-production") || contains(note, "presents"))
end
```

I find the latter a little more readable. Let's go with that. `|>` is also used for function chaining in the Julia stdlib, so it's a nice analogy.

Let's check the other queries:

``` julia
q2a = @query(name) begin
  "character-name-in-title" <| keyword.keyword <| movie_keyword.keyword_id <| movie_keyword.movie_id |> title
  title |> title.name |> name
  title <| movie_companies.movie_id |> movie_companies.company_id |> company_name.country_code |> "[de]"
end

infos = Set(["Sweden", "Norway", "Germany", "Denmark", "Swedish", "Denish", "Norwegian", "German"])
q3a = @query(name) begin
  contains(keyword, "sequel")
  keyword <| keyword.keyword <| movie_keyword.keyword_id |> movie_keyword.movie_id |> title
  title |> title.name |> name
  title |> title.production_year |> production_year
  production_year > 2005
  title <| movie_info.movie_id |> movie_info.info |> info
  info in infos
end

q4a = @query(info) begin
  contains(keyword, "sequel")
  keyword <| keyword.keyword <| movie_keyword.keyword_id |> move_keyword.movie_id |> title
  title |> title.production_year |> production_year
  production_year > 2005
  "rating" <| info_type.info <| movie_info.info_type_id <| movie_info
  movie_info |> move_info.info |> info
  info > "5.0"
end
```

Hmmm. It's fine for these bidirectional edges, but it doesn't really work for single column relations eg `vertex(v)`.

Here's a different idea. `keyword <| keyword.keyword <| movie_keyword.keyword_id |> move_keyword.movie_id |> title` could be written as `keyword.keyword(keyword, t1); movie_keyword.keyword_id(t1, t2);  movie_keyword.movie_id(t2, title)` in a more traditional syntax. There's the risk of accidentally reusing a temporary variable, but maybe I could make them line- or block- scoped.

``` julia
q1a = @query(production_year) begin
  info_type.info(t1, "top 250 rank"); movie_info.info_type(movie_info, t1);
  movie_info.movie_id(movie_info, title)
  title.production_year(title, production_year)
  movie_companies.movie_id(movie_company, title)
  movie_companies.company_type(movie_company, t1); company_type.kind(t1, "production companies")
  movie_companies.note(movie_company, note)
  !contains(note, "as Metro-Goldwyn-Mayer Pictures") && (contains(note, "co-production") || contains(note, "presents"))
end
```

Weirdly, I don't find that as readable. The former had this nice visual emphasis on the variables and the connections between them that this lacks. This one also messes with the variable ordering a little (t1 comes before "top 250 rank"), but that will also happen in the other syntax with >2 columns.

Part of the problem in any case is that the JOB schema is pretty distorted to avoid multiple allocations of the same string, but since we're running in-memory we can just share pointers. With a nicer schema:

``` julia
q4a = @query(rating) begin
  true = contains(keyword, "sequel")
  movie_keyword(movie, keyword)
  movie_production_year(movie, production_year)
  true = production_year > 2005
  movie_info(movie, "rating", rating)
  true = rating > "5.0"
end
```

Which is totally readable.

But what about my variable ordering? Picking the first occurence works ok here, but is that flexible enough in general? Maybe I'll allow adding hints inline if I find a need.

So, actually, all I really need to change is to allow inline constants (which I'll lift to the top of the query) and derive the variable ordering from the query. And do something prettier with aggregates.

### 2016 Aug 14

Some quick little ergonomic improvements tonight.

I moved type annotations from the variable ordering to the return statement, which is the only place they are now needed and also doubles up as a schema for views. This also simplifed the code for `plan_query` to:

``` julia
function plan_query(returned_typed_variables, aggregate, variables, query)
  join = plan_join(returned_typed_variables, aggregate, variables, query)

  project_variables = map(get_variable_symbol, returned_typed_variables)
  push!(project_variables, :prev_aggregate)
  project_aggregate = [aggregate[1], aggregate[2], :(prev_aggregate::$(get_variable_type(aggregate[3])))]
  project_query = quote
    intermediate($(project_variables...))
  end
  project = plan_join(returned_typed_variables, project_aggregate, project_variables, project_query)

  quote
    let $(esc(:intermediate)) = let; $join; end
      $project
    end
  end
end
```

 I added some code to the compiler that allows writing Julia constants or expressions where Imp variables should be.

 ``` julia
 for clause in relation_clauses
   line = query.args[clause]
   for (ix, arg) in enumerate(line.args)
     if ix > 1 && !isa(arg, Symbol)
       variable = gensym("variable")
       line.args[ix] = variable
       assignment_clauses[variable] = arg
       callable_at = 1 + maximum(push!(indexin(collect_variables(arg), variables), 0))
       insert!(variables, 1, variable)
     end
   end
 end
 ```

I created nicer names for the various JOB tables.

``` julia
for (table_name, column_name) in keys(job)
  @eval begin
    $(symbol(table_name, "_", column_name)) = job[$table_name, $column_name]
    export $(symbol(table_name, "_", column_name))
  end
end
```

I rewrote each job query so that the order in which in each variable first appears matches the variable ordering I chose, and then changed `plan_query` to use this ordering directly. It also allows simply mentioning a variable to insert in the order.

``` julia
variables = []
for clause in 1:length(query.args)
  line = query.args[clause]
  if clause in hint_clauses
    push!(variables, line)
  elseif clause in relation_clauses
    for (ix, arg) in enumerate(line.args)
      if ix > 1 && !isa(arg, Symbol)
        variable = gensym("variable")
        line.args[ix] = variable
        assignment_clauses[variable] = arg
        insert!(variables, 1, variable) # only handles constants atm
      elseif ix > 1 && isa(arg, Symbol)
        push!(variables, arg)
      end
    end
  end
end
variables = unique(variables)
```

It doesn't look inside assignments or expressions yet, but I just use hints to work around that for now.

The job queries now look like:

``` julia
function q1a()
  @query([t_production_year::Int64],
  begin
    info_type_info(it_id, "top 250 rank")
    movie_info_idx_info_type_id(mii_id, it_id)
    movie_info_idx_movie_id(mii_id, t_id)
    movie_companies_movie_id(mc_id, t_id)
    movie_companies_company_type_id(mc_id, ct_id)
    company_type_kind(ct_id, "production companies")
    movie_companies_note(mc_id, mc_note)
    @when !contains(mc_note, "as Metro-Goldwyn-Mayer Pictures") &&
      (contains(mc_note, "co-production") || contains(mc_note, "presents"))
    title_production_year(t_id, t_production_year)
  end)
end

function q2a()
  @query([title::String],
  begin
    keyword_keyword(k_id, "character-name-in-title")
    movie_keyword_keyword_id(mk_id, k_id)
    movie_keyword_movie_id(mk_id, t_id)
    movie_companies_movie_id(mc_id, t_id)
    movie_companies_company_id(mc_id, cn_id)
    company_name_country_code(cn_id, "[de]")
    title_title(t_id, title)
  end)
end

function q3a()
  # "Denish" is in original too
  mi_infos = Set(["Sweden", "Norway", "Germany", "Denmark", "Swedish", "Denish", "Norwegian", "German"])
  @query([t_title::String],
  begin
    k_keyword
    @when contains(k_keyword, "sequel")
    keyword_keyword(k_id, k_keyword)
    movie_keyword_keyword_id(mk_id, k_id)
    movie_keyword_movie_id(mk_id, t_id)
    title_title(t_id, t_title)
    title_production_year(t_id, t_production_year)
    @when t_production_year > 2005
    movie_info_movie_id(mi_id, t_id)
    movie_info_info(mi_id, mi_info)
    @when mi_info in mi_infos
  end)
end

function q4a()
  @query([mii_info::String],
  begin
    k_keyword
    @when contains(k_keyword, "sequel")
    keyword_keyword(k_id, k_keyword)
    movie_keyword_keyword_id(mk_id, k_id)
    movie_keyword_movie_id(mk_id, t_id)
    title_production_year(t_id, t_production_year)
    @when t_production_year > 2005
    info_type_info(it_id, "rating")
    movie_info_idx_info_type_id(mii_id, it_id)
    movie_info_idx_movie_id(mii_id, t_id)
    movie_info_idx_info(mii_id, mii_info)
    @when mii_info > "5.0"
  end)
end
```

The remaining grossness is mostly just the awful table/variable names from the original benchmark. I'm ok with that.

I'm going on a long climbing trip, so the next few weeks will be sparse.

### 2016 Aug 20

Fixed a sorting bug - choosing the pivot at random breaks the invariant that there is always at least one element smaller or larger than the pivot, so the partitioning can run off the end of the array.

```
diff --git a/src/Data.jl b/src/Data.jl
index bccfa6f..1088331 100644
--- a/src/Data.jl
+++ b/src/Data.jl
@@ -60,8 +60,8 @@ function define_columns(n)
         swap2($(cs...), pivot, lo)
         i, j = lo+1, hi
         while true
-          while lt($(cs...), i, lo); i += 1; end;
-          while lt($(cs...), lo, j); j -= 1; end;
+          while (i <= j) && lt($(cs...), i, lo); i += 1; end;
+          while (i <= j) && lt($(cs...), lo, j); j -= 1; end;
           i >= j && break
           swap2($(cs...), i, j)
           i += 1; j -= 1
```

### 2016 Aug 29

I added support for `in` so that we can write things like:

``` julia
@query([x,y],
begin
  x in 1:10
  y in 1:10
  @when x < y
end)
```

It works almost identically to `=`, except that it loops over the result of the expression instead of assigning.

``` julia
body = quote
  for $(esc(variable)) in $(esc(loop_clauses[variable]))
    if assign($variable_columns, los, ats, his, $variable_ixes, $(esc(variable)))
      $body
    end
  end
end
```

I could also have sorted the result and treated it like another column for intersection, but that would have been a bit more work and I'm not sure yet whether it would pay off.

I also removed a limitation of the variable ordering detection where it only looked at grounded variables. It can now look inside `=`, `in` and `@when`.

### 2016 Aug 30

Going to start looking at UI. I'll need to do more work on queries and dataflow along the way, but I think it will be helpful to do add features as they are required by real programs, rather than planning them in advance and finding later that they aren't quite right.

I'm going with HTML just because it's familiar and widely supported.

With Blink.jl and Hiccup.jl it's really easy to get a window up and display content:

``` julia
w = Window()
body!(w, Hiccup.div("#foo.bar", "Hello World"))
```

Handling events is a bit harder. There is a [issue thread](https://github.com/JunoLab/Blink.jl/issues/57) but I'm just reproducing the same error as the person asking the question. To the debugger! Which I haven't used before...

``` julia
using Gallium
breakpoint(Blink.ws_handler)
```

```
signal (11): Segmentation fault
while loading /home/jamie/.atom/packages/julia-client/script/boot.jl, in expression starting on line 327
evaluate_generic_instruction at /home/jamie/.julia/v0.5/DWARF/src/DWARF.jl:376
unknown function (ip: 0x7f9323b5a5c9)
...
```

Bah. To be fair, I have a pretty janky setup with various packages running at weird versions on top of a Julia RC. When Julia 0.5 is released I'll clean it up and try the debugger again.

Instead I just poke around in the source code and eventually figure out that the data sent back has to be a dict, and that there is a baked-in magic function in `@js` for making such.

``` julia
x = [1,2]
@js_ w document.getElementById("my_button").onclick = () -> Blink.msg("press", d(("foo", $x)))
handle(w, "press") do args...
  @show args
end
```

But I want these callbacks to be specified by values in the dom, not by a separate side-effect.

``` julia
function event(table_name, values)
  Blink.jsexpr(quote
    Blink.msg("event", d(("table", $table_name), ("values", $values)))
  end).s
end

macro event(expr)
  assert(expr.head == :call)
  :(event($(string(expr.args[1])), [$(expr.args[2:end]...)]))
end

function Window(event_tables)
  w = Window()
  event_number = 1
  handle(w, "event") do args
    values = args["values"]
    insert!(values, 1, event_number)
    event_number += 1
    push!(event_tables[args["table"]], values)
  end
end

macro Window(event_tables...)
  :(Window(Dict($([:($(string(table)) => $table) for table in event_tables]...))))
end
```

``` julia
using Data
clicked = Relation((Int64[], String[]))
w = @Window(clicked)
body!(w, button("#my_button", Dict(:onclick => @event clicked("my_button")), "click me!"))
```

I haven't actually implemented `push!` yet for relations, so let's do that too. I'm still just using sorted arrays so this is a little hacky. It'll do for now.

``` julia
function Base.push!{T}(relation::Relation{T}, values)
  assert(length(relation.columns) == length(values))
  for ix in 1:length(values)
    push!(relation.columns[ix], values[ix])
  end
  empty!(relation.indexes)
  # TODO can preserve indexes when inserted value is at end or beginning
  # TODO remove dupes
end
```

Uh, but I don't have a proper dataflow yet and I'll want to run things on each event, so maybe this is poorly thought out. Let's add a callback to the window:

``` julia
function Blink.Window(flow, event_tables)
  w = Window()
  event_number = 1
  handle(w, "event") do args
    values = args["values"]
    insert!(values, 1, event_number)
    push!(event_tables[args["table"]], values)
    flow(w, event_number)
    event_number += 1
  end
  flow(w, 0)
  w
end

macro Window(flow, event_tables...)
  :(Window($flow, Dict($([:($(string(table)) => $table) for table in event_tables]...))))
end
```

``` julia
clicked = Relation((Int64[], String[]))
@Window(clicked) do w, event_number
  body!(w, button("#my_button", Dict(:onclick => @event clicked("my_button")), "clicked $event_number times"))
end
```

Somehow I ended up tidying up code and setting up proper tests. There doesn't seem to be much builtin structure for tests so I just have a scratch file to run things from:

``` julia
include("src/Data.jl")
include("src/Query.jl")
include("src/UI.jl")

include("examples/JobData.jl")

include("examples/Graph.jl")
include("examples/Chinook.jl")
include("examples/Job.jl")

Graph.test()
Chinook.test()
Job.test()

Graph.bench()
Chinook.bench()
Job.bench()
```

I need some examples to work with to figure out what to implement next. I started with a simple minesweeper game. I don't think it's a particularly good usecase for Imp, but someone recently posted an Eve version and I was feeling cheeky. A sketch of the core mechanics:

``` julia
function run(num_x, num_y, num_mines)
  @relation state() => Symbol
  @relation mine(Int64, Int64)
  @relation mine_count(Int64, Int64) => Int64
  @relation cleared(Int64, Int64)
  @relation clicked(Int64) => Int64, Int64

  @query begin
    + state() = :game_ok
  end

  while length(mine) < num_mines
    @query begin
      x = rand(1:num_x)
      y = rand(1:num_y)
      + mine(x,y)
    end
  end

  @query begin
    x in 1:num_x
    y in 1:num_y
    c = count(
      nx in -1:1
      ny in -1:1
      @when (nx != 0) || (ny != 0)
      mine(x+nx, y+ny) = true
    )
    + mine_count(x, y) = c
  end

  @Window(clicked) do display, event_number
    @query begin
      clicked($event_number) = (x, y)
      + cleared(x, y)
    end

    fix!(cleared) do
      @query begin
        cleared(x,y)
        mine_count(x,y,0)
        nx in -1:1
        ny in -1:1
        @when (nx * ny == 0) && (nx + ny != 0) # no boolean xor :(
        + cleared(x+nx, y+ny)
      end)
    end

    @query
      clicked($event_number) = (x, y)
      mine(x,y)
      + state() = :game_over
    end

    @query begin
      state() = state
      x in 1:num_x
      y in 1:num_y
      cleared = exists(cleared(x,y))
      mine = exists(mine(x,y))
      mine_count(x,y,count)
      node = @match (state, mine, cleared, count) begin
        (:game_over, true, _, _) => button("💣")
        (:game_over, false, _, _) => button(string(count))
        (:game_ok, _, true, 0) => button(" ")
        (:game_ok, _, true, _) => button(string(count))
        (:game_ok, _, false, _) => button("X", :onclick => @event clicked(x,y))
      end
      @group y node = h_box(node)
      @group x node = v_box(node)
      + display() = node
    end

  end
end
```

This requires:

* a relation macro that records a functional dependecy
* query syntax updated to match
* syntax for upsert into a relation
* (probably also want delete)
* with change tracking to handle fix!
* better aggregates / subqueries / negation

The last point is a design problem that has been bugging me for ages, so it bears some thinking about.

Fundeps / upsert is simpler, but it does move Imp away from being a general purpose library. It probably won't be hard to support a separate macro that just returns results though.

I was imagining that eg `+ mine_count(x, y) = c` would replace any existing value for `(x, y)`, but what should happen if a single query execution produces multiple values of `c` for a single `(x,y)`. Probably an error?

Well, let's start with something I do know how to implement:

``` julia
type Relation{T <: Tuple} # where T is a tuple of columns
  columns::T
  indexes::Dict{Vector{Int64},T}
  key_types::Vector{Type}
  val_types::Vector{Type}
end

# examples:
# @relation height_at(Int64, Int64) = Float64
# @relation married(String, String)
# @relation state() = (Int64, Symbol)
macro relation(expr)
  if expr.head == :(=)
    name_and_keys = expr.args[1]
    vals_expr = expr.args[2]
  else
    name_and_keys = expr
    vals_expr = Expr(:tuple)
  end
  assert(name_and_keys.head == :call)
  name = name_and_keys.args[1]
  assert(isa(name, Symbol))
  keys = name_and_keys.args[2:end]
  for key in keys
    assert(isa(key, Symbol))
  end
  if vals_expr.head == :block
    vals_expr = vals_expr.args[2]
  end
  if isa(vals_expr, Symbol)
    vals = [vals_expr]
  else
    assert(vals_expr.head == :tuple)
    vals = vals_expr.args
  end
  for val in vals
    assert(isa(val, Symbol))
  end
  typs = [keys..., vals...]
  quote
    columns = tuple($([:(Vector{$typ}()) for typ in typs]...))
    indexes = Dict{Vector{Int64}, typeof(columns)}()
    $(esc(name)) = Relation(columns, indexes, Type[$(keys...)], Type[$(vals...)])
  end
end
```

### 2016 Sep 1

Next thing I need is a way to merge relations, with the values from the more recent version winning key collisions. I also threw in a function that checks the fundep invariant.

``` julia
function define_keys(n, num_keys)
  olds = [symbol("old", c) for c in 1:n]
  news = [symbol("new", c) for c in 1:n]
  results = [symbol("result", c) for c in 1:n]
  ts = [symbol("C", c) for c in 1:n]

  quote

    function merge_sorted!{$(ts...)}(old::Tuple{$(ts...)}, new::Tuple{$(ts...)}, result::Tuple{$(ts...)}, num_keys::Type{Val{$num_keys}})
      @inbounds begin
        $([:($(olds[c]) = old[$c]) for c in 1:n]...)
        $([:($(news[c]) = new[$c]) for c in 1:n]...)
        $([:($(results[c]) = result[$c]) for c in 1:n]...)
        old_at = 1
        new_at = 1
        old_hi = length($(olds[1]))
        new_hi = length($(news[1]))
        while old_at <= old_hi && new_at <= new_hi
          c = c_cmp($(olds[1:num_keys]...), $(news[1:num_keys]...), old_at, new_at)
          if c == 0
            $([:(push!($(results[c]), $(news[c])[new_at])) for c in 1:n]...)
            old_at += 1
            new_at += 1
          elseif c == 1
            $([:(push!($(results[c]), $(news[c])[new_at])) for c in 1:n]...)
            new_at += 1
          else
            $([:(push!($(results[c]), $(olds[c])[old_at])) for c in 1:n]...)
            old_at += 1
          end
        end
        while old_at <= old_hi
          $([:(push!($(results[c]), $(olds[c])[old_at])) for c in 1:n]...)
          old_at += 1
        end
        while new_at <= new_hi
          $([:(push!($(results[c]), $(news[c])[new_at])) for c in 1:n]...)
          new_at += 1
        end
      end
    end

    function assert_no_dupes_sorted{$(ts...)}(result::Tuple{$(ts...)}, num_keys::Type{Val{$num_keys}})
      $([:($(results[c]) = result[$c]) for c in 1:n]...)
      for at in 2:length($(results[1]))
        assert(c_cmp($(results[1:num_keys]...), $(results[1:num_keys]...), at, at-1) == 1)
      end
    end

  end
end

for n in 1:10
  for k in 1:n
    eval(define_keys(n, k))
  end
end

function Base.merge{T}(old::Relation{T}, new::Relation{T})
  # TODO should Relation{T} be typed Relation{K,V} instead?
  assert(old.key_types == new.key_types)
  assert(old.val_types == new.val_types)
  result_columns = tuple([Vector{eltype(column)}() for column in old.columns]...)
  order = collect(1:(length(old.key_types) + length(old.val_types)))
  merge_sorted!(index(old, order), index(new, order), result_columns, Val{length(old.key_types)})
  result_indexes = Dict{Vector{Int64}, typeof(result_columns)}(order => result_columns)
  Relation(result_columns, result_indexes, old.key_types, old.val_types)
end

function assert_no_dupes{T}(relation::Relation{T})
  order = collect(1:(length(relation.key_types) + length(relation.val_types)))
  assert_no_dupes_sorted(index(relation, order), Val{length(relation.key_types)})
  relation
end
```

There's all kinds of grossness in here, similar to the sort functions before, dealing with the annoying restrictions on stack allocation. Might be worth cleaning this up before I continue.

First, let's add some microbenchmarks to make sure I don't screw anything up.

``` julia
function bench()
  srand(999)
  x = rand(Int64, 10000)
  @show @benchmark quicksort!((copy($x),))

  srand(999)
  y = [string(i) for i in rand(Int64, 10000)]
  @show @benchmark quicksort!((copy($y),))

  srand(999)
  x = unique(rand(1:10000, 10000))
  y = rand(1:10000, length(x))
  z = rand(1:10000, length(x))
  a = Relation((x,y), Dict{Vector{Int64}, typeof((x,y))}(), Type[Int64], Type[Int64])
  b = Relation((x,z), Dict{Vector{Int64}, typeof((x,y))}(), Type[Int64], Type[Int64])
  @show @benchmark merge($a,$b)
end
```

``` julia
@benchmark(quicksort!((copy($(Expr(:$, :x))),))) = BenchmarkTools.Trial:
  samples:          8320
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  78.22 kb
  allocs estimate:  3
  minimum time:     463.05 μs (0.00% GC)
  median time:      545.95 μs (0.00% GC)
  mean time:        599.23 μs (4.81% GC)
  maximum time:     11.10 ms (92.95% GC)
@benchmark(quicksort!((copy($(Expr(:$, :y))),))) = BenchmarkTools.Trial:
  samples:          1025
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  78.22 kb
  allocs estimate:  3
  minimum time:     3.73 ms (0.00% GC)
  median time:      4.72 ms (0.00% GC)
  mean time:        4.87 ms (0.48% GC)
  maximum time:     14.11 ms (58.82% GC)
@benchmark(merge($(Expr(:$, :a)),$(Expr(:$, :b)))) = BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  258.72 kb
  allocs estimate:  47
  minimum time:     105.06 μs (0.00% GC)
  median time:      115.67 μs (0.00% GC)
  mean time:        196.96 μs (39.01% GC)
  maximum time:     7.80 ms (97.17% GC)
```

The only functions that actually pull a row onto the stack are `cmp`, `lt`, `lt2`, `swap` and `insertion_sort!`. First let's rewrite insertion sort to use swapping, and see if doubling the number of writes slows things down appreciably.

``` julia
function insertion_sort!($(cs...), lo::Int, hi::Int)
  @inbounds for i = lo+1:hi
    j = i
    while j > lo && lt($(cs...), j, j-1)
      swap($(cs...), j, j-1)
      j -= 1
    end
  end
end
```

Any change to the benchmarks is within the range of noise. `lt2` was only used in `insertion_sort!`, so that leaves us with just `cmp`, `lt` and `swap`. `lt` is redundant.

``` julia
@inline function c_cmp($(olds...), $(news...), old_at, new_at)
  @inbounds begin
    $([quote
      c = cmp($(olds[c])[old_at], $(news[c])[new_at])
      if c != 0; return c; end
    end for c in 1:(n-1)]...)
    return cmp($(olds[n])[old_at], $(news[n])[new_at])
  end
end

@inline function swap($(cs...), i, j)
  @inbounds begin
    $([quote
      $(tmps[c]) = $(cs[c])[j]
      $(cs[c])[j] = $(cs[c])[i]
      $(cs[c])[i] = $(tmps[c])
    end for c in 1:n]...)
  end
end
```

Both of these need the loops to be unrolled because the type of `tmp` changes on each iteration. Without unrolling, it will get the type `Any` which will cause it to heap-allocate eg integers that were allocated as values in the array.

``` julia
@generated function cmp_in{T <: Tuple}(xs::T, ys::T, x_at::Int64, y_at::Int64)
  n = length(T.parameters)
  quote
    $(Expr(:meta, :inline))
    @inbounds begin
      $([:(result = cmp(xs[$c][x_at], ys[$c][y_at]); if result != 0; return result; end) for c in 1:(n-1)]...)
      return cmp(xs[$n][x_at], ys[$n][y_at])
    end
  end
end

@generated function swap_in{T <: Tuple}(xs::T, i::Int65, j::Int64)
  n = length(T.parameters)
  quote
    $(Expr(:meta, :inline))
    @inbounds begin
      $([quote
        let tmp = xs[$c][i]
          xs[$c][i] = xs[$c][j]
          xs[$c][j] = tmp
        end
      end for c in 1:n]...)
    end
  end
end
```

I'm no longer unpacking the tuple of columns, so I can use `@generated` to generate them on the fly rather than `for n in 1:10; eval(define_columns(n)); end`.

Now I can make the rest of the sorting code into normal functions:

``` julia
function insertion_sort!{T <: Tuple}(cs::T, lo::Int, hi::Int)
  @inbounds for i = lo+1:hi
    j = i
    while j > lo && (cmp_in(cs, cs, j, j-1) == -1)
      swap_in(cs, j, j-1)
      j -= 1
    end
  end
end

function partition!{T <: Tuple}(cs::T, lo::Int, hi::Int)
  @inbounds begin
    pivot = rand(lo:hi)
    swap_in(cs, pivot, lo)
    i, j = lo+1, hi
    while true
      while (i <= j) && (cmp_in(cs, cs, i, lo) == -1); i += 1; end;
      while (i <= j) && (cmp_in(cs, cs, lo, j) == -1); j -= 1; end;
      i >= j && break
      swap_in(cs, i, j)
      i += 1; j -= 1
    end
    swap_in(cs, lo, j)
    return j
  end
end

function quicksort!{T <: Tuple}(cs::T, lo::Int, hi::Int)
  @inbounds if hi-lo <= 0
    return
  elseif hi-lo <= 20
    insertion_sort!(cs, lo, hi)
  else
    j = partition!(cs, lo, hi)
    quicksort!(cs, lo, j-1)
    quicksort!(cs, j+1, hi)
  end
end

function quicksort!{T <: Tuple}(cs::T)
  quicksort!(cs, 1, length(cs[1]))
end
```

`merge` and `assert_no_dupes` change similarly.

This adds a bunch of tuple accesses to the hot path, so let's check if it hurt the benchmarks:

``` julia
@benchmark(quicksort!((copy($(Expr(:$, :x))),))) = BenchmarkTools.Trial:
  samples:          8569
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  78.22 kb
  allocs estimate:  3
  minimum time:     491.56 μs (0.00% GC)
  median time:      556.94 μs (0.00% GC)
  mean time:        582.50 μs (3.39% GC)
  maximum time:     7.47 ms (91.25% GC)
@benchmark(quicksort!((copy($(Expr(:$, :y))),))) = BenchmarkTools.Trial:
  samples:          1335
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  78.22 kb
  allocs estimate:  3
  minimum time:     3.26 ms (0.00% GC)
  median time:      3.68 ms (0.00% GC)
  mean time:        3.74 ms (0.47% GC)
  maximum time:     10.67 ms (58.69% GC)
@benchmark(merge($(Expr(:$, :a)),$(Expr(:$, :b)))) = BenchmarkTools.Trial:
  samples:          7918
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  442.06 kb
  allocs estimate:  11769
  minimum time:     351.98 μs (0.00% GC)
  median time:      398.31 μs (0.00% GC)
  mean time:        630.96 μs (34.79% GC)
  maximum time:     13.66 ms (93.77% GC)
```

Ouch, `merge` got a lot slower and is making a ton of allocations. What went wrong in there?

Oh, that's disappointing. `merge_sorted!` contains:

``` julia
old_key = old[1:num_keys]
new_key = new[1:num_keys]
```

And julia doesn't infer the correct types. Easily fixed though - I'll just pass them as args instead of `num_keys`.

``` julia
@benchmark(merge($(Expr(:$, :a)),$(Expr(:$, :b)))) = BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  259.06 kb
  allocs estimate:  57
  minimum time:     93.48 μs (0.00% GC)
  median time:      123.75 μs (0.00% GC)
  mean time:        206.21 μs (38.39% GC)
  maximum time:     8.54 ms (96.65% GC)
```

Eh, that'll do.

### 2016 Sep 2

Now I have to deal with aggregates. In terms of expressivity, what I really want are first-class relations within the query language. But I don't want to actually materialize or allow them to end up in the output, because that just brings back all of the pointer-chasing problems of high-level languages.

One option would be something like [T-LINQ](http://homepages.inf.ed.ac.uk/jcheney/publications/cheney13icfp.pdf) which allows first-class sets in queries but guarantees to normalize them away before execution. I like the principle, but the small addendum in the paper about not being able to normalize aggregates makes it seem like more work is necessary.

What I'm going to do instead is to make queries return an iterator instead of executing all in one go. Then aggregates can be handled by normal Julia functions. This will make queries much harder to analyse when I come to look at things like incremental evaluation, but in the meantime it's easier and safer to implement. I'll come back to T-LINQy ideas later.

Sidenote: I just noticed that Julia has a neat feature that I really wanted when working on Strucjure - you can embed pointers directly into an ast:

``` julia
xs = [1,2,3]

q = let ys = xs
  :(push!($ys, 4))
end

@show q
# :(push!([1,2,3],4))

@show xs
# xs = [1,2,3]

@show ys
# UndefVarError: ys not defined

eval(q)

@show xs
# xs = [1,2,3,4]

@show q
# :(push!([1,2,3,4],4))
```

So, let's pick an example query:

``` julia
@query begin
  cleared(x,y)
  mine_count(x,y) = 0
  nx in -1:1
  ny in -1:1
  @when (nx * ny == 0) && (nx + ny != 0) # no boolean xor :(
end
```

This is going to be replaced by a couple of closures that close over all the necessary data:

``` julia
begin
  ixes_x = [1,1]
  function start()
    los = [...]
    ats = [...]
    his = [...]
    index_1 = index(cleared, [1,2])
    index_2 = index(mine_count, [3,1,2])
    ...
    row = Row(ats)
    (row, los, ats, his, index_1, index_2, ...)
  end
  function next(state)
    row, los, ats, his, index_1, index_2, ... = state
    ...
    row
  end
  Query(start, next)
end
```

I've already checked in previous experiments that in Julia 0.5 closures can be specialized on, so if the query has a known type then these closures shouldn't cause any dispatch overhead while looping over the results.

### 2016 Sep 5

I let that idea stew and worked on some other projects for a few days. I kept going back and forth between various different implementations with different trade-offs and eventually realized that I was failing to make decision because I don't have enough information. I don't have nearly enough example code and datasets to think about the impact of different implementations.

Let's instead just try to pick something that is easy and doesn't limit future choices too much. What if I had queries just return everything and then used normal Julia functions for aggregation? I can replace the internal aggregation code with the simple optimization that bails out after finding a single solution for each returned row.

``` julia
while ...
  a = ...
  while ...
    b = ...
    need_more_results = true
    while need_more_results && ...
      c = ...
      while need_more_results && ...
        d = ...
        push!(results, (a, b))
        need_more_results = false
      end
    end
  end
end
```

While working on this I spent hours tracking down a subtle bug. `assign` does not bail out if the value is not found but a higher value is. This doesn't cause any test failures because the later aggregate handling multiplies the aggregate value by number of matching rows in each table. If the value is missing the number of matching rows is 0, so the aggregate is 0 and is not returned. Fixing this yields some mild speedups:

``` julia
@benchmark(q1a()) = BenchmarkTools.Trial:
  samples:          2932
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  23.20 kb
  allocs estimate:  156
  minimum time:     1.27 ms (0.00% GC)
  median time:      1.68 ms (0.00% GC)
  mean time:        1.70 ms (0.92% GC)
  maximum time:     17.64 ms (86.49% GC)
@benchmark(q2a()) = BenchmarkTools.Trial:
  samples:          79
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  713.50 kb
  allocs estimate:  249
  minimum time:     61.60 ms (0.00% GC)
  median time:      63.79 ms (0.00% GC)
  mean time:        64.01 ms (0.36% GC)
  maximum time:     71.39 ms (13.57% GC)
@benchmark(q3a()) = BenchmarkTools.Trial:
  samples:          42
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  30.20 kb
  allocs estimate:  234
  minimum time:     117.45 ms (0.00% GC)
  median time:      119.76 ms (0.00% GC)
  mean time:        119.83 ms (0.00% GC)
  maximum time:     122.71 ms (0.00% GC)
@benchmark(q4a()) = BenchmarkTools.Trial:
  samples:          109
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  60.28 kb
  allocs estimate:  229
  minimum time:     43.93 ms (0.00% GC)
  median time:      45.35 ms (0.00% GC)
  mean time:        46.25 ms (0.00% GC)
  maximum time:     51.02 ms (0.00% GC)
```

Then I removed the aggregates from inside the query handling and replaced them with the early exit optimization. Disappointingly, it didn't seem to affect performance much. Perhaps the runtime is dominated by the early table scans.

### 2016 Sep 9

I'm back from my climbing trip now, so Imp dev should return to it's usual rhythm.

First thing is a syntactic tweak - moving returned variables to the end of the query. It's cleaner visually and it removes a lot of punctuation.

``` julia
function who_is_metal()
  @query begin
    playlist(playlist, "Heavy Metal Classic")
    playlist_track(playlist, track)
    track(track, _, album)
    album(album, _, artist)
    artist(artist, artist_name)
    return (artist_name::String,)
  end
end
```

I'm also playing around with nesting queries for aggregation.

``` julia
function cost_of_playlist()
  @query begin
    playlist(p, pn)
    tracks = @query begin
      p = p
      playlist_track(p, t)
      track(t, _, _, _, _, _, _, _, price)
      return (t::Int64, price::Float64)
    end
    total = sum(tracks.columns[1])
    return (pn::String, total::Float64)
  end
end
```

I don't like the current implementation at all. It allocates a new relation on each loop, only to aggregate over it and throw it away. I don't want to get bogged down in this forever though, so I'm going to leave it for now and revisit it when I look at factorizing queries.

That `p = p` is caused by a scoping issue. I can't tell at the moment whether `p` is being used as a variable or as a constant from an outside scope, so I have to create a new `p` to resolve the ambiguity. The ideal way to fix this would be if macros could query what variables are defined in their enclosing scope, but I think this may be impossible in Julia because declarations can float upwards - a later macro could create a new variable that is available in this macro. So instead I'll just explicitly escape variables eg `$p` for constant, `p` for variable.

I also fixed a minor bug that caused a crash on queries that don't return any results. I've been aware of it for a while but it was only worth fixing once I started working on sub-queries.

With several more hours of unrecorded bug-fixing, I finally have a working version!

``` julia
function run(num_x, num_y, num_mines)
  srand(999)

  @relation state() = Symbol
  @relation mine(Int64, Int64)
  @relation mine_count(Int64, Int64) = Int64
  @relation cleared(Int64, Int64)
  @relation clicked(Int64) = (Int64, Int64)
  @relation display() = Hiccup.Node

  @merge! state begin
    s = :game_in_progress
    return (s::Symbol,)
  end

  @fix! mine begin
    mines = @query begin
      mine(x, y)
      return (x::Int64, y::Int64)
    end
    @when length(mines) < num_mines
    x = rand(1:num_x)
    y = rand(1:num_y)
    return (x::Int64, y::Int64)
  end

  @merge! mine_count begin
    x in 1:num_x
    y in 1:num_y
    neighbouring_mines = @query begin
      nx in (x-1):(x+1)
      ny in (y-1):(y+1)
      @when (nx != x) || (ny != y)
      mine(nx, ny)
      return (nx::Int64, ny::Int64)
    end
    c = length(neighbouring_mines)
    return (x::Int64, y::Int64, c::Int64)
  end

  @Window(clicked) do window, event_number

    @merge! cleared begin
      clicked($event_number, x, y)
      return (x::Int64, y::Int64)
    end

    @fix! cleared begin
      cleared(x,y)
      mine_count(x,y,0)
      nx in (x-1):(x+1)
      ny in (y-1):(y+1)
      @when nx in 1:num_x
      @when ny in 1:num_y
      @when (nx != x) || (ny != y)
      return (nx::Int64, ny::Int64)
    end

    @merge! state begin
      num_cleared = length(@query begin
        cleared(x,y)
        return (x::Int64, y::Int64)
      end)
      @when num_cleared + num_mines >= num_x * num_y
      s = :game_won
      return (s::Symbol,)
    end

    @merge! state begin
      clicked($event_number, x, y)
      mine(x,y)
      s = :game_lost
      return (s::Symbol,)
    end

    node = vbox(map(1:num_y) do y
      return hbox(map(1:num_x) do x
        current_state = state.columns[1][1]
        is_cleared = exists(@query begin
          cleared($x,$y)
          e = true
          return (e::Bool,)
        end)
        is_mine = exists(@query begin
          mine($x,$y)
          e = true
          return (e::Bool,)
        end)
        count = (@query begin
          mine_count($x,$y,count)
          return (count::Int64,)
        end).columns[1][1]
        return @match (current_state, is_mine, is_cleared, count) begin
         (:game_in_progress, _, true, 0) => button("_")
         (:game_in_progress, _, true, _) => button(string(count))
         (:game_in_progress, _, false, _) => button(Dict(:onclick => @event clicked(x,y)), "X")
         (_, true, _, _) => button("💣")
         (_, false, _, _) => button(string(count))
         _ => error()
       end
     end)
   end)

   Blink.body!(window, node)

  end

  (state, mine, mine_count, clicked, display, cleared)
end

(state, mine, mine_count, clicked, display, cleared) = run(10, 20, 10)
```

The Imp computation takes around 0.1-3.0ms per event, where the top end is down to `@fix!` not doing semi-naive evaluation. Building the Hiccup node takes up to 100ms, which is disgraceful. About half of that is the repeated inner queries and the other half is entirely inside Hiccup.

There's a ton of minor stuff to fix before I'll consider this finished:

* Queries support `relation(keys) => value` syntax
* Declare merge in return statement
* Remove need for type declarations in merged returns
* Allow returning expressions, not just symbols
* Sort only by keys in query, so that we can have non-sortable objects as values
* Distinguish empty set from set containing empty tuple

I also want to reduce the noise of inner aggregates, but I have no good ideas right now.

### 2016 Sep 11

I figured out how to hook into Julia's type inference at runtime. The simple way is:

``` julia
Base.return_types(() -> ..., [])[1]
```

This executes at runtime and Julia can't infer the return type. I think that works fine if I move it outside the function that wraps the query.

Another option is:

``` julia
@generated function infer_type(closure, args...)
  m = Core.Inference._methods_by_ftype(Tuple{closure, (arg.parameters[1] for arg in args)...}, 1)[1]
  _, ty, inferred = Core.Inference.typeinf(m[3], m[1], m[2], false)
  t = inferred ? ty : Any
  quote
    $(Expr(:meta, :inline))
    $t
  end
end
```

This returns the correct results when I execute it by itself, but if I wrap it in a function call it always returns `Any`. No idea why.

Also, sometimes it segfaults. I guess there is a reason that the exported reflection functions refuse to work inside `@generated` :D

I could just use `Base.return_types` at compile time, but macros run before later functions in the same module are compiled, so it wouldn't know the types of those functions. Evalling the same module twice would produce different type inferences.

If I use it at runtime, the query itself would be fine because it's wrapped in a function, but the return type of the query would be un-inferrable.

I spent a lot of time thinking about this and eventually realised that Julia's array comprehensions have exactly the same problem - giving a stable type to the empty array. So I have a truly glorious hack:

``` julia
# nearly works, but x and y get boxed
results_x = [x for _ in []]
results_y = [y for _ in []]
x = 3
y = x + 1

# actually works!
f_x = () -> 3
f_y = (x) -> x + 1
results_x = [f_x() for _ in []]
results_y = [f_y(results_x[1]) for _ in []]
x = 3
y = x + 1
```

It's a bit sketchy, because the Julia folks keep warning everyone that type inference is not stable/predictable and that runtime behaviour shouldn't depend on inference. But as far as I'm concerned, allocating ints on the stack vs making a bajillion heap allocations *is* important runtime behavior, so I'm *already* a hostage to type inference and/or manual assertions. Throwing an error on pushing to a weirdly typed array is much less annoying than trying to allocate 100gb of Int64 objects and crashing my machine.

The actual implementation of this plan was simple enough, but the type inference really struggles with subqueries and I can't figure out why. A large part of the problem is that the generated code is pretty verbose, so it's really hard for me to work through the lowered, inferred ast and find problems. I think I'm going to abandon inference for now. I'll finish the rest of the bullet points, then clean up the compiler and then try inference again.

### 2016 Sep 12

Let's figure out what I want the emitted code to look like.

``` julia
@query begin
  playlist(p, pn)
  tracks = @query begin
    playlist_track($p, t)
    track(t, _, _, _, _, _, _, _, price)
    return (t::Int64, price::Float64)
  end
  total = sum(tracks.columns[1])
  return (pn::String, total::Float64)
end
```

``` julia
index_playlist = index(esc(playlist), [1,2])

columns_p = tuple(index_playlist[1])
infer_p() = infer(columns_p)

columns_pn = tuple(index_playlist[2])
infer_pn() = infer(columns_pn)

begin # subquery init
  index_playlist_track = index(esc(playlist_track), [1, 2])
  index_track = index(esc(track), [1, 9])

  @inline function eval_tmp1(p) = p
  columns_tmp1 = tuple(index_playlist_track[1])
  infer_tmp1() = infer(columns_tmp1, infer_p())

  columns_t = tuple(index_playlist_track[2], index_track[1])
  infer_t() = infer(columns_t)

  columns_price = tuple(index_track[9])
  infer_price() = infer(columns_price)

  @inline function query2_outer(results_t, results_price, p)
    for tmp1 in intersect(columns_tmp1, eval_tmp1(p))
      for t in intersect(columns_t)
        for price in intersect(columns_price)
          query2_inner(results_t, results_price, p, tmp1, t, price)
        end
      end
    end
    Relation(tuple(results_t, results_price), tuple()) # dedup
  end

  @inline function query2_inner(results_t, results_price, p, tmp1, t, price)
    push!(results_t, t)
    push!(results_price, price)
    return
  end
end

@inline eval_tracks(p) = query2_outer([infer_t() for _ in []], [infer_price() for _ in []], p)
columns_tracks = tuple()
infer_tracks() = infer(columns_tracks, eval_tracks(infer_p()))

eval_total(tracks) = sum(track.columns[1])
columns_total = tuple()
infer_total() = infer(columns_totals, eval_total(infer_tracks()))

@inline function query1_outer(results_pn, results_total)
  for p in intersect(columns_p)
    for pn in intersect(columns_pn)
      for tracks in intersect(columns_tracks, eval_tracks(p))
        for total in intersect(columns_total, eval_total(tracks))
          query1_inner(results_pn, results_total, p, pn, tracks, total)
        end
      end
    end
  end
  Relation((results_pn, results_total)) # dedup
end

@inline function query1_inner(results_pn, results_total, p, pn, tracks, total)
  push!(results_pn, pn)
  push!(results_total, total)
  return
end

query2_outer([infer_pn() for _ in []], [infer_total() for _ in []])
```

The first step is to clean up the compiler itself, while still generating the same code. I've got the bulk of this done but it'll need some debugging tomorrow.

### 2016 Sep 13

I have the cleaned up compiler working now, and it's a relief to have done it.

However, the generated code is not identical - there is a significant slowdown in some of the JOB queries. It looks like the cause is that I'm no longer lifting constants to the top of the variable order. Easily fixed.

Here is the new compiler code, in all it's commented glory:

``` julia
function plan_join(query)
  # parse
  clauses = []
  for line in query.args
    clause = @match line begin
      line::Symbol => Hint(line)
      Expr(:call, [:in, var, expr], _) => In(var, expr, collect_vars(expr))
      Expr(:call, [name, vars...], _) => Row(name, Any[vars...])
      Expr(:(=), [var, expr], _) => Assign(var, expr, collect_vars(expr))
      Expr(:macrocall, [head, expr], _), if head == Symbol("@when") end => When(expr, collect_vars(expr))
      Expr(:return, [Expr(:tuple, [vars...], _)], _) => Return((), map(get_var_symbol, vars), map(get_var_type, vars))
      Expr(:return, [Expr(:call, [:tuple, vars...], _)], _) => Return((), map(get_var_symbol, vars), map(get_var_type, vars))
      Expr(:return, [Expr(:call, [name, vars...], _)], _) => Return(name, map(get_var_symbol, vars), map(get_var_type, vars))
      Expr(:line, _, _) => ()
      _ => error("Confused by: $line")
    end
    if clause != ()
      push!(clauses, clause)
    end
  end

  # check all assignments are to single vars
  for clause in clauses
    if typeof(clause) in [In, Assign]
      @assert isa(clause.var, Symbol)
    end
  end

  # add a return if needed
  returns = [clause for clause in clauses if typeof(clause) == Return]
  if length(returns) == 0
    return_clause = Return((), [], [])
  elseif length(returns) == 1
    return_clause = returns[1]
  else
    error("Too many returns: $returns")
  end

  # rewrite expressions nested in Row
  old_clauses = clauses
  clauses = []
  for clause in old_clauses
    if typeof(clause) in [Row]
      for (ix, expr) in enumerate(clause.vars)
        if !isa(expr, Symbol)
          var = gensym("constant")
          clause.vars[ix] = var
          value = @match expr begin
            Expr(:$, [value], _) => value
            value => value
          end
          insert!(clauses, 1, Assign(var, value, collect_vars(value)))
        end
      end
    end
    push!(clauses, clause)
  end

  # collect vars created in this query
  created_vars = Set()
  for clause in clauses
    if typeof(clause) in [Row]
      for var in clause.vars
        push!(created_vars, var)
      end
    end
    if typeof(clause) in [Assign, In]
      push!(created_vars, clause.var)
    end
  end
  delete!(created_vars, :_) # _ is a wildcard, not a real var

  # collect vars mentioned in this query, in order of mention
  mentioned_vars = []
  for clause in clauses
    if typeof(clause) in [Row, When, Assign, In]
      for var in clause.vars
        push!(mentioned_vars, var)
      end
    end
    if typeof(clause) in [Assign, In, Hint]
      push!(mentioned_vars, clause.var)
    end
  end

  # use mention order to decide execution order
  vars = unique((var for var in mentioned_vars if var in created_vars))

  # collect clauses that assign a value to a var before intersect
  var_assigned_by = Dict()
  for clause in clauses
    if typeof(clause) in [Assign, In]
      @assert !haskey(var_assigned_by, clause.var) # only one assignment per var
      var_assigned_by[clause.var] = clause
    end
  end

  # for each var, collect list of relation/column pairs that need to be intersected
  sources = Dict(var => Tuple{Int64, Int64}[] for var in vars)
  for (clause_ix, clause) in enumerate(clauses)
    if typeof(clause) == Row
      for (var_ix, var) in enumerate(clause.vars)
        if var != :_
          push!(sources[var], (clause_ix, var_ix))
        end
      end
    end
  end

  # for each Row clause, figure out what order to sort the index in
  sort_orders = Dict(clause_ix => Int64[] for clause_ix in 1:length(clauses))
  for var in vars
    for (clause_ix, var_ix) in sources[var]
      push!(sort_orders[clause_ix], var_ix)
    end
  end

  # assign a slot in the los/ats/his arrays for each relation/column pair
  ixes = Tuple{Int64, Any}[]
  for (clause_ix, var_ixes) in sort_orders
    for var_ix in var_ixes
      push!(ixes, (clause_ix, var_ix))
    end
    push!(ixes, (clause_ix, :buffer))
  end
  ix_for = Dict(column => ix for (ix, column) in enumerate(ixes))

  # --- codegen ---

  # for each Row clause, get the correct index
  index_inits = []
  for (clause_ix, clause) in enumerate(clauses)
    if typeof(clause) == Row
      order = sort_orders[clause_ix]
      index_init = :($(Symbol("index_$clause_ix")) = index($(Symbol("relation_$clause_ix")), $order))
      push!(index_inits, index_init)
    end
  end

  # for each var, collect up the columns to be intersected
  columns_inits = []
  for var in vars
    columns = [:($(Symbol("index_$clause_ix"))[$var_ix]) for (clause_ix, var_ix) in sources[var]]
    columns_init = :($(Symbol("columns_$var")) = [$(columns...)])
    push!(columns_inits, columns_init)
  end

  # for each var, make list of ixes into the global state
  ixes_inits = []
  for var in vars
    ixes_init = :($(Symbol("ixes_$var")) = $([ix_for[source] for source in sources[var]]))
    push!(ixes_inits, ixes_init)
  end

  # initialize arrays for storing results
  results_inits = []
  for (ix, var) in enumerate(return_clause.vars)
    if return_clause.name == ()
      typ = return_clause.typs[ix]
    else
      typ = :(eltype($(esc(return_clause.name)).columns[$ix]))
    end
    result_init = :($(Symbol("results_$var")) = Vector{$typ}())
    push!(results_inits, result_init)
  end

  # initilize global state
  los = [1 for _ in ixes]
  ats = [1 for _ in ixes]
  his = []
  for (clause_ix, var_ix) in ixes
    if var_ix == :buffer
      push!(his, 0)
    else
      push!(his, :(length($(Symbol("index_$clause_ix"))[$var_ix]) + 1))
    end
  end

  # combine all the init steps
  init = quote
    $(index_inits...)
    $(columns_inits...)
    $(ixes_inits...)
    $(results_inits...)
    los = [$(los...)]
    ats = [$(ats...)]
    his = [$(his...)]
  end

  # figure out at which point in the variable order each When clause can be run
  whens = [[] for _ in vars]
  for clause in clauses
    if typeof(clause) == When
      var_ix = maximum(indexin(collect_vars(clause.expr), vars))
      push!(whens[var_ix], clause.expr)
    end
  end

  # figure out at which point in the variable order we have all the variables we need to return
  return_after = maximum(push!(indexin(return_clause.vars, vars), 0))

  # store results
  body = quote
    $([:(push!($(Symbol("results_$var")), $(esc(var))))
    for var in return_clause.vars]...)
    need_more_results = false
  end

  # build up the main loop from the inside out
  for var_ix in length(vars):-1:1
    var = vars[var_ix]
    var_columns = Symbol("columns_$var")
    var_ixes = Symbol("ixes_$var")

    # run any When clauses
    for when in whens[var_ix]
      body = :(if $(esc(when)); $body; end)
    end

    # after return_after, only need to find one solution, not all solutions
    if var_ix == return_after
      body = quote
        need_more_results = true
        $body
      end
    end
    need_more_results = var_ix > return_after ? :need_more_results : true

    # find valid values for this variable
    clause = get(var_assigned_by, var, ())
    if typeof(clause) == Assign
      body = quote
        let $(esc(var)) = $(esc(clause.expr))
          if assign($var_columns, los, ats, his, $var_ixes, $(esc(var)))
            $body
          end
        end
      end
    elseif typeof(clause) == In
      body = quote
        let
          local iter = $(esc(clause.expr))
          local state = start(iter)
          local $(esc(var))
          while $need_more_results && !done(iter, state)
            ($(esc(var)), state) = next(iter, state)
            if assign($var_columns, los, ats, his, $var_ixes, $(esc(var)))
              $body
            end
          end
        end
      end
    else
      result_column = ix_for[sources[var][1]]
      body = quote
        start_intersect($var_columns, los, ats, his, $var_ixes)
        while $need_more_results && next_intersect($var_columns, los, ats, his, $var_ixes)
          let $(esc(var)) = $(Symbol("columns_$var"))[1][los[$(result_column+1)]]
            $body
          end
        end
      end
    end

  end

  query_symbol = gensym("query")
  relation_symbols = [Symbol("relation_$clause_ix") for (clause_ix, clause) in enumerate(clauses) if typeof(clause) == Row]
  relation_names = [esc(clause.name) for clause in clauses if typeof(clause) == Row]
  result_symbols = [Symbol("results_$var") for var in return_clause.vars]

  code = quote
    function $query_symbol($(relation_symbols...))
      $init
      $body
      Relation(tuple($(result_symbols...)))
    end
    $query_symbol($(relation_names...))
  end

  (code, return_clause)
end

function plan_query(query)
  (join, return_clause) = plan_join(query)

  (project, _) = plan_join(quote
    intermediate($(return_clause.vars...))
    return intermediate($(return_clause.vars...)) # returning to intermediate is just a temporary hack to convey types
  end)

  quote
    let $(esc(:intermediate)) = let; $join; end
      $((return_clause.name == ()) ? project : :(merge!($(esc(return_clause.name)), $project)))
    end
  end
end
```

Now to start cleaning up the generated code. First step is to remove the second join and do the deduping in the `Relation` constructor instead.

``` julia
function Relation{T}(columns::T)
  deduped = tuple((Vector{eltype(column)}() for column in columns)...)
  quicksort!(columns)
  at = 1
  hi = length(columns[1])
  while at <= hi
    push_in!(deduped, columns, at)
    while (at += 1; (at <= hi) && cmp_in(columns, columns, at, at-1) == 0) end
  end
  order = collect(1:length(columns))
  key_types = Type[eltype(column) for column in columns]
  Relation(deduped, Dict{Vector{Int64},T}(order => deduped), key_types, Type[])
end
```

Some slight slowdowns on queries that produce a large number of intermediate results, but nothing that bothers me too much:

``` julia
@benchmark(q1a()) = BenchmarkTools.Trial:
  samples:          3016
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  7.28 kb
  allocs estimate:  66
  minimum time:     1.25 ms (0.00% GC)
  median time:      1.66 ms (0.00% GC)
  mean time:        1.66 ms (0.00% GC)
  maximum time:     3.17 ms (0.00% GC)
@benchmark(q2a()) = BenchmarkTools.Trial:
  samples:          73
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  318.03 kb
  allocs estimate:  3730
  minimum time:     67.10 ms (0.00% GC)
  median time:      68.82 ms (0.00% GC)
  mean time:        69.36 ms (0.46% GC)
  maximum time:     95.58 ms (24.48% GC)
@benchmark(q3a()) = BenchmarkTools.Trial:
  samples:          43
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  11.31 kb
  allocs estimate:  81
  minimum time:     113.73 ms (0.00% GC)
  median time:      115.70 ms (0.00% GC)
  mean time:        116.35 ms (0.00% GC)
  maximum time:     120.57 ms (0.00% GC)
@benchmark(q4a()) = BenchmarkTools.Trial:
  samples:          108
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  21.92 kb
  allocs estimate:  98
  minimum time:     44.07 ms (0.00% GC)
  median time:      46.17 ms (0.00% GC)
  mean time:        46.55 ms (0.00% GC)
  maximum time:     53.74 ms (0.00% GC)
```

### 2016 Sep 14

My latest attempt at type inference spawned a two day debugging session. I was very confused for a long time by the following situation.

``` julia
infer_p() # inferred result type is Int64
infer_tracks(1::Int64) # inferred result type is Relation{Int64, Float64}
infer_tracks(infer_p()) # inferred result type is Any
```

I finally found the bug. At some point I had typed `$(Symbol("infer_$var()"))` rather than `$(Symbol("infer_$var"))()`. The latter creates a call to the function `infer_p`. The former creates a load of the variable `infer_p()`, which is nonsense. But both print the same way when the ast is rendered! And, weirdly, the type inference for the former produced `Any`, instead of producing `Union{}` which would have clued me in to the fact that I was producing nonsense code.

But it's fixed now. I have type inference.

``` julia
const num_x = 3
const num_y = 4

@relation mine(Int64, Int64)

function neighbours()
  @query begin
    x in 1:num_x
    y in 1:num_y
    neighbouring_mines = @query begin
      nx in (x-1):(x+1)
      ny in (y-1):(y+1)
      @when (nx != x) || (ny != y)
      mine(nx, ny)
    end
    c = length(neighbouring_mines)
    return (x, y) => c
  end
end

Base.return_types(neighbours)
# [Data.Relation{Tuple{Array{Int64,1},Array{Int64,1},Array{Int64,1}}}]
```

I also fixed all the bullet points from the minesweeper post. The only remaining problem is that hiccup nodes are not comparable, so I can't sort them into a relation column.

### 2016 Sep 15

So many strange bugs today. One query only gets the correct inferred type if the module is compiled twice. That makes no sense.

Ignoring that for now. Node comparisons:

``` julia
function Base.cmp{T1, T2}(n1::Hiccup.Node{T1}, n2::Hiccup.Node{T2})
  c = cmp(T1, T2)
  if c != 0; return c; end
  c = cmp(length(n1.attrs), length(n2.attrs))
  if c != 0; return c; end
  for (a1, a2) in zip(n1.attrs, n2.attrs)
    c = cmp(a1, a2)
    if c != 0; return c; end
  end
  c = cmp(length(n1.children), length(n2.children))
  if c != 0; return c; end
  for (c1, c2) in zip(n1.children, n2.children)
    c = cmp(c1, c2)
    if c != 0; return c; end
  end
  return 0
end
```

Which means the UI can now happen in Imp too. Here is the whole minesweeper:

``` julia
@relation state() => Symbol
@relation mine(Int64, Int64)
@relation mine_count(Int64, Int64) => Int64
@relation cleared(Int64, Int64)
@relation clicked(Int64) => (Int64, Int64)

@relation cell(Int64, Int64) => Hiccup.Node
@relation row(Int64) => Hiccup.Node
@relation grid() => Hiccup.Node

@query begin
  return state() => :game_in_progress
end

while length(@query mine(x,y)) < num_mines
  @query begin
    nx = rand(1:num_x)
    ny = rand(1:num_y)
    return mine(nx, ny)
  end
end

@query begin
  x in 1:num_x
  y in 1:num_y
  neighbouring_mines = @query begin
    nx in (x-1):(x+1)
    ny in (y-1):(y+1)
    @when (nx != x) || (ny != y)
    mine(nx, ny)
  end
  c = length(neighbouring_mines)
  return mine_count(x, y) => c
end

@Window(clicked) do window, event_number

  @query begin
    clicked($event_number) => (x, y)
    return cleared(x, y)
  end

  fix(cleared) do
    @query begin
      cleared(x,y)
      mine_count(x,y) => 0
      nx in (x-1):(x+1)
      ny in (y-1):(y+1)
      @when nx in 1:num_x
      @when ny in 1:num_y
      @when (nx != x) || (ny != y)
      return cleared(nx, ny)
    end
  end

  @query begin
    num_cleared = length(@query cleared(x,y))
    @when num_cleared + num_mines >= num_x * num_y
    return state() => :game_won
  end

  @query begin
    clicked($event_number) => (x, y)
    mine(x,y)
    return state() => :game_lost
  end

  @query begin
    state() => current_state
    x in 1:num_x
    y in 1:num_y
    is_cleared = exists(@query cleared($x,$y))
    is_mine = exists(@query mine($x,$y))
    mine_count(x, y) => count
    cell_node = (@match (current_state, is_mine, is_cleared, count) begin
      (:game_in_progress, _, true, 0) => button("_")
      (:game_in_progress, _, true, _) => button(string(count))
      (:game_in_progress, _, false, _) => button(Dict(:onclick => @event clicked(x,y)), "X")
      (:game_won, true, _, _) => button("💣")
      (:game_lost, true, _, _) => button("☀")
      (_, false, _, _) => button(string(count))
      other => error("The hell is this: $other")
    end)::Hiccup.Node
    return cell(x,y) => cell_node
  end

  @query begin
    y in 1:num_y
    row_node = hbox((@query cell(x,$y) => cell_node).columns[3])::Hiccup.Node
    return row(y) => row_node
  end

  @query begin
    grid_node = vbox((@query row(y) => row_node).columns[2])::Hiccup.Node
    return grid() => grid_node
  end

  Blink.body!(window, grid.columns[1][1])

end
```

Still a couple of ugly parts.

* Those `::Hiccup.Node`s are necessary because the compiler infers `Union{Hiccup.Node, Void}` otherwise. Haven't figured that out yet.

* `.columns[3]` should just be `[3]` or `.cell_node`. The latter will work if I store variable names in the relation and implement `getfield`. Just have to be careful not to break inference.

* The call to `Blink.body!` should happen in the UI lib.

The first one appears to be an inference problem. I figured out a way to simplify the inference stage. While doing that, I discovered that I had broken the JOB queries some time ago and somehow not noticed. I could bisect the problem, but I've changed the representation of relations a few times in the past days so I would have to rebuild the JOB dataset on every commit, which takes about 30 minutes each time.

Maybe I can just figure it out by comparing smaller queries to postgres.

The smallest query that disagrees with postgres is:

``` julia
@query begin
  info_type_info(it_id, "top 250 rank")
  movie_info_idx_info_type_id(mii_id, it_id)
  movie_info_idx_movie_id(mii_id, t_id)
  title_production_year(t_id, t_production_year)
  # movie_companies_movie_id(mc_id, t_id)
  # movie_companies_company_type_id(mc_id, ct_id)
  # company_type_kind(ct_id, "production companies")
  # movie_companies_note(mc_id, mc_note)
  # @when !contains(mc_note, "as Metro-Goldwyn-Mayer Pictures") &&
  #   (contains(mc_note, "co-production") || contains(mc_note, "presents"))
  return (t_production_year,)
end
```

Comparing `title_production_year` to the csv I notice that the length is correct but the data is wrong. A few minutes later it all snaps into focus - the changed the Relation constructor to sort it's input data for deduping, but I share input columns in the JOB data. This was fine for a while because I save the relations on disk and it was only when I changed the representation of relations and had to regenerate the JOB data from scratch that it all went wrong.

An aliasing/mutation bug. I feel so dirty.

Back to inference. I noticed something that is probably responsible for a lot of my confusion.

``` julia
julia> function foo1()
         function bar()
           @inline eval_a() = 1
           @inline eval_b(a) = a
           a = [(([[eval_a()]])[1])[1] for _ in []]
           b = [(([[eval_b(a[1])]])[1])[1] for _ in []]
         end
         bar()
       end
foo1 (generic function with 1 method)

julia> foo1()
0-element Array{Int64,1}

julia> function foo2()
         function bar()
           @inline eval_a() = 1
           @inline eval_b(a) = a
           @show a = [(([[eval_a()]])[1])[1] for _ in []]
           @show b = [(([[eval_b(a[1])]])[1])[1] for _ in []]
         end
         bar()
       end
foo2 (generic function with 1 method)

julia> foo2()
a = [(([[eval_a()]])[1])[1] for _ = []] = Int64[]
b = [(([[eval_b(a[1])]])[1])[1] for _ = []] = Any[]
0-element Array{Any,1}
```

The `@show` macro I immediately turn to to help me debug these issues also confuses type inference itself. So as soon as I tried to debug some problem, I was creating a new problem. Hopefully I shouldn't have any more crazy self-doubting inference debugging sessions now that I've figured this out.

The problem with the buttons in minesweeper seems to be that inference just rounds up to `Any` when encountering an abstract type in an array:

``` julia
function foo()
  const bb = button("")
  const t = typeof(bb)
  x = Vector{t}()
  y = [bb]
end
```

``` julia
Variables:
  #self#::Minesweeper.#foo
  bb::HICCUP.NODE{TAG}
  t::TYPE{_<:HICCUP.NODE}
  x::ANY
  y::ANY

Body:
  begin
      bb::HICCUP.NODE{TAG} = $(Expr(:invoke, LambdaInfo for #button#1(::Array{Any,1}, ::Function, ::String, ::Vararg{String,N}), :(Minesweeper.#button#1), :((Core.ccall)(:jl_alloc_array_1d,(Core.apply_type)(Core.Array,Any,1)::Type{Array{Any,1}},(Core.svec)(Core.Any,Core.Int)::SimpleVector,Array{Any,1},0,0,0)::Array{Any,1}), :(Minesweeper.button), "")) # line 167:
      t::TYPE{_<:HICCUP.NODE} = (Minesweeper.typeof)(bb::HICCUP.NODE{TAG})::TYPE{_<:HICCUP.NODE} # line 168:
      x::ANY = ((Core.apply_type)(Minesweeper.Vector,t::TYPE{_<:HICCUP.NODE})::TYPE{_<:ARRAY{_<:HICCUP.NODE,1}})()::ANY # line 169:
      SSAValue(0) = (Base.vect)(bb::HICCUP.NODE{TAG})::ANY
      y::ANY = SSAValue(0)
      return SSAValue(0)
  end::ANY
```

So I fix that by just using tuples instead which don't have any weird type coercion behavior. And finally we get to the root of the issue:

``` julia
# inferred types
cell.columns[3] # Array{Hiccup.Node,1}
cell.columns[3][1] # HICCUP.NODE{TAG}
[cell.columns[3][1]] # ANY
```

`ANY` is not quite the same as `Any`. In user annotations, the former indicates not to specialize on this type at all. I'm guessing that the all-caps in `HICCUP.NODE{TAG}` means something similar.

So the core issue seems to be that if you have an array of an abstract type and you take something out of it and put it in a new array, Julia just bails out entirely. I don't know why it behaves this way, but I can at least work around it by just never taking anything out of an array during inference. I make the results vectors like this now:

``` julia
type_x = eltype([eval_x(results_y[1]) for _ in []])
results_x = Vector{typejoin(type_x, eltype(index_2[3]), eltype(index_4[3]))}()
```

All my tests pass and none of them require type annotations. I've also added new tests that look at the inferred return types for all the old tests to make sure it stays that way.

### 2016 Sep 16

I spent today mostly deciding what to do next. I want to publish some sort of progress report before the end of the month, so I spent a few hours drafting that report. Chipping away at all the caveats in that report gives me a nice todo list for the next few weeks.

### 2016 Sep 17

I spent a few hours getting the JOB data into SQLite, figuring out how to use SQLite.jl and running benchmarks.

``` julia
import SQLite
function bench_sqlite()
  db = SQLite.DB("../job/job.sqlite")
  SQLite.execute!(db, "PRAGMA cache_size = 1000000000;")
  SQLite.execute!(db, "PRAGMA temp_store = memory;")
  medians = []
  for q in 1:4
    query = rstrip(readline("../job/$(q)a.sql"))
    @time SQLite.query(db, query)
    trial = @show @benchmark SQLite.query($db, $query)
    push!(medians, @show (median(trial.times) / 1000000))
  end
  medians
end
```

For postgres I'm instead just running the queries through bash, but using the execution times from EXPLAIN ANALYZE instead of the @benchmark time.

``` julia
function bench_pg()
  medians = []
  for q in 1:4
    query = rstrip(readline("../job/$(q)a.sql"))
    query = query[1:(length(query)-1)] # drop ';' at end
    bench = "explain analyze $query"
    cmd = `sudo -u postgres psql -c $bench`
    times = Float64[]
    @show q
    @show @benchmark push!($times, parse(Float64, match(r"Execution time: (\S*) ms", readstring($cmd))[1]))
    push!(medians, @show median(times))
  end
  medians
end
```

I've also changed the Imp JOB data to use exactly the same schema as the other databases, so queries now look like:

``` julia
function q1a()
  @query begin
    info_type(it_id, "top 250 rank")
    movie_info_idx(mii_id, t_id, it_id, _, _)
    title(t_id, title, _, _, production_year)
    movie_companies(mc_id, t_id, _, ct_id, note)
    company_type(ct_id, "production companies")
    @when !contains(note, "as Metro-Goldwyn-Mayer Pictures") &&
      (contains(note, "co-production") || contains(note, "presents"))
    return (note, title, production_year)
  end
end
```

They're all broken now though, so it's debugging time.

I added some tests against SQLite to help out.

``` julia
db = SQLite.DB("../job/job.sqlite")
for q in 1:4
  results_imp = eval(Symbol("q$(q)a"))()
  query = rstrip(readline("../job/$(q)a.sql"))
  query = replace(query, "MIN", "")
  frame = SQLite.query(db, query)
  num_columns = length(results_imp.columns)
  results_sqlite = Relation(tuple((frame[ix].values for ix in 1:num_columns)...), num_columns)
  @show q
  @test length(results_imp.columns[1]) == length(results_sqlite.columns[1])
  @test results_imp.columns == results_sqlite.columns
end
```

### 2016 Sep 19

Only have a few hours today. Debugging time.

Q1 and Q3 don't work. Q2 and Q4 do. All of them worked before I changed the schema and rewrote the queries to match.

I want to narrow the failure down to a single incorrect row, so let's add:

``` julia
function diff_sorted!{T <: Tuple, K <: Tuple}(old::T, new::T, old_key::K, new_key::K, old_only::T, new_only::T)
  @inbounds begin
    old_at = 1
    new_at = 1
    old_hi = length(old[1])
    new_hi = length(new[1])
    while old_at <= old_hi && new_at <= new_hi
      c = cmp_in(old_key, new_key, old_at, new_at)
      if c == 0
        old_at += 1
        new_at += 1
      elseif c == 1
        push_in!(new_only, new, new_at)
        new_at += 1
      else
        push_in!(old_only, old, old_at)
        old_at += 1
      end
    end
    while old_at <= old_hi
      push_in!(old_only, old, old_at)
      old_at += 1
    end
    while new_at <= new_hi
      push_in!(new_only, new, new_at)
      new_at += 1
    end
  end
end

function diff{T}(old::Relation{T}, new::Relation{T})
  @assert old.num_keys == new.num_keys
  order = collect(1:length(old.columns))
  old_index = index(old, order)
  new_index = index(new, order)
  old_only_columns = tuple([Vector{eltype(column)}() for column in old.columns]...)
  new_only_columns = tuple([Vector{eltype(column)}() for column in new.columns]...)
  diff_sorted!(old_index, new_index, old_index[1:old.num_keys], new_index[1:new.num_keys], old_only_columns, new_only_columns)
  old_only_indexes = Dict{Vector{Int64}, typeof(old_only_columns)}(order => old_only_columns)
  new_only_indexes = Dict{Vector{Int64}, typeof(new_only_columns)}(order => new_only_columns)
  (Relation(old_only_columns, old.num_keys, old_only_indexes), Relation(new_only_columns, new.num_keys, new_only_indexes))
end
```

And change the test to:

``` julia
(imp_only, sqlite_only) = Data.diff(results_imp, results_sqlite)
@test imp_only.columns == sqlite_only.columns # ie both empty - but @test will print both otherwise
```

And for Q1 we get:

``` julia
Test Failed
  Expression: imp_only.columns == sqlite_only.columns
   Evaluated: (String["(as A Selznick International Picture) (as Selznick International presents its picturization of Daphne Du Maurier's celebrated novel also)","(as Warner Bros.- Seven Arts presents)","(presents: Ernest Lehman's production of Edward Albee's)"],String["Rebecca","The Wild Bunch","Who's Afraid of Virginia Woolf?"],[1940,1969,1966]) == (String[],String[],Int64[])
```

I have a sudden suspicion. Maybe I don't track ixes correctly when there are `_`s in between variables.

Let's dump the ixes for Q1.

``` julia
ixes = Tuple{Int64,Any}[(7,2),(7,1),(7,:buffer),(4,3),(4,2),(4,:buffer),(9,:buffer),(2,:buffer),(3,2),(3,1),(3,:buffer),(5,1),(5,2),(5,5),(5,:buffer),(8,:buffer),(6,2),(6,4),(6,5),(6,:buffer),(1,:buffer)]
```

Nope, looks fine. Back to systematic debugging.

Let's first see if those rows actually exist in the Imp tables.

``` julia
for ix in 1:length(title)
  if title.columns[2][ix] == "Who's Afraid of Virginia Woolf?"
    @show title.columns[1][ix] title.columns[5][ix]
  end
end

# (title.columns[1])[ix] = 2499084
# (title.columns[5])[ix] = 1966

for ix in 1:length(movie_companies)
  if movie_companies.columns[2][ix] == 2499084
    @show movie_companies.columns[5][ix]
  end
end

# (movie_companies.columns[5])[ix] = "(1973) (USA) (TV) (original airing)"
# (movie_companies.columns[5])[ix] = "(1976) (Finland) (TV)"
# (movie_companies.columns[5])[ix] = "(1966) (USA) (theatrical)"
# (movie_companies.columns[5])[ix] = "(1966) (Finland) (theatrical)"
# (movie_companies.columns[5])[ix] = "(2004) (Czech Republic) (theatrical)"
# (movie_companies.columns[5])[ix] = "(1966) (West Germany) (theatrical)"
# (movie_companies.columns[5])[ix] = "(2006) (Canada) (DVD) (4 film set)"
# (movie_companies.columns[5])[ix] = "(19??) (West Germany) (VHS)"
# (movie_companies.columns[5])[ix] = "(2006) (Germany) (DVD)"
# (movie_companies.columns[5])[ix] = "(2007) (Finland) (DVD)"
# (movie_companies.columns[5])[ix] = "(2007) (Netherlands) (DVD)"
# (movie_companies.columns[5])[ix] = "(1966) (Sweden) (VHS)"
# (movie_companies.columns[5])[ix] = "(1992) (USA) (video) (laserdisc)"
# (movie_companies.columns[5])[ix] = "(1994) (USA) (VHS)"
# (movie_companies.columns[5])[ix] = "(1997) (USA) (DVD)"
# (movie_companies.columns[5])[ix] = "(2000) (USA) (VHS)"
# (movie_companies.columns[5])[ix] = "(2006) (USA) (DVD) (4 film set)"
# (movie_companies.columns[5])[ix] = "(2006) (USA) (DVD) (two-disc special edition)"
# (movie_companies.columns[5])[ix] = "(1966) (Sweden) (theatrical)"
# (movie_companies.columns[5])[ix] = "(uncredited)"
# (movie_companies.columns[5])[ix] = "(presents: Ernest Lehman's production of Edward Albee's)"
```

So that looks legit. What about the info?

``` julia
for ix in 1:length(info_type)
  if info_type.columns[2][ix] == "top 250 rank"
    @show info_type.columns[1][ix]
  end
end

# (info_type.columns[1])[ix] = 112

for ix in 1:length(movie_info_idx)
  if movie_info_idx.columns[2][ix] == 2499084 && movie_info_idx.columns[3][ix] == 112
    @show movie_info_idx.columns[1][ix]
  end
end

(movie_info_idx.columns[1])[ix] = 1379970
```

Wait, so it does match the whole query. Let's just confirm that in postgres too.

```
postgres=# select distinct info_type.info, title.title from title, movie_info_idx, info_type where info_type.info = 'top 250 rank' and title.id = 2499084 and info_type.id = movie_info_idx.info_type_id and movie_info_idx.movie_id = title.id;
     info     |              title
--------------+---------------------------------
 top 250 rank | Who's Afraid of Virginia Woolf?
```

```
sqlite> select distinct info_type.info, title.title from title, movie_info_idx, info_type where info_type.info = 'top 250 rank' and title.id = 2499084 and info_type.id = movie_info_idx.info_type_id and movie_info_idx.movie_id = title.id;
top 250 rank|Who's Afraid of Virginia Woolf?
sqlite>
```

Oh, did I check the company type?

``` julia
for ix in 1:length(movie_companies)
  if movie_companies.columns[2][ix] == 2499084
    @show movie_companies.columns[4][ix] movie_companies.columns[5][ix]
  end
end

# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1973) (USA) (TV) (original airing)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1976) (Finland) (TV)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1966) (USA) (theatrical)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1966) (Finland) (theatrical)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2004) (Czech Republic) (theatrical)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1966) (West Germany) (theatrical)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2006) (Canada) (DVD) (4 film set)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(19??) (West Germany) (VHS)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2006) (Germany) (DVD)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2007) (Finland) (DVD)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2007) (Netherlands) (DVD)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1966) (Sweden) (VHS)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1992) (USA) (video) (laserdisc)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1994) (USA) (VHS)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1997) (USA) (DVD)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2000) (USA) (VHS)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2006) (USA) (DVD) (4 film set)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(2006) (USA) (DVD) (two-disc special edition)"
# (movie_companies.columns[4])[ix] = 1
# (movie_companies.columns[5])[ix] = "(1966) (Sweden) (theatrical)"
# (movie_companies.columns[4])[ix] = 2
# (movie_companies.columns[5])[ix] = "(uncredited)"
# (movie_companies.columns[4])[ix] = 2
# (movie_companies.columns[5])[ix] = "(presents: Ernest Lehman's production of Edward Albee's)"

for ix in 1:length(company_type)
  if company_type.columns[1][ix] in [1,2]
    @show company_type.columns[1][ix] company_type.columns[2][ix]
  end
end

# (company_type.columns[1])[ix] = 1
# (company_type.columns[2])[ix] = "distributors"
# (company_type.columns[1])[ix] = 2
# (company_type.columns[2])[ix] = "production companies"
```

```
postgres=# select title.title, movie_companies.company_type_id from title, movie_companies where title.id = 2499084 and movie_companies.movie_id = title.id;
              title              | company_type_id
---------------------------------+-----------------
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               1
 Who's Afraid of Virginia Woolf? |               2
 Who's Afraid of Virginia Woolf? |               2
(21 rows)

postgres=# select * from company_type where company_type.id in (1,2);
 id |         kind
----+----------------------
  1 | distributors
  2 | production companies
(2 rows)
```

Maybe it's the LIKE patterns that I'm messing up? Let's modify Q1A to specify this particular title, return everything and then remove conditions until we get results.

```
postgres=# SELECT distinct mc.note AS production_note, (t.title) AS movie_title, (t.production_year), ct.kind, it.info AS movie_year FROM company_type AS ct, info_type AS it, movie_companies AS mc, movie_info_idx AS mi_idx, title AS t WHERE ct.kind = 'production companies' AND it.info = 'top 250 rank' AND mc.note  not like '%(as Metro-Goldwyn-Mayer Pictures)%' and (mc.note like '%(co-production)%' or mc.note like '%(presents)%') AND ct.id = mc.company_type_id AND t.id = mc.movie_id AND t.id = mi_idx.movie_id AND mc.movie_id = mi_idx.movie_id AND it.id = mi_idx.info_type_id and t.id = 2499084;
 production_note | movie_title | production_year | kind | movie_year
-----------------+-------------+-----------------+------+------------
(0 rows)

postgres=# SELECT distinct mc.note AS production_note, (t.title) AS movie_title, (t.production_year), ct.kind, it.info AS movie_year FROM company_type AS ct, info_type AS it, movie_companies AS mc, movie_info_idx AS mi_idx, title AS t WHERE ct.kind = 'production companies' AND it.info = 'top 250 rank' AND ct.id = mc.company_type_id AND t.id = mc.movie_id AND t.id = mi_idx.movie_id AND mc.movie_id = mi_idx.movie_id AND it.id = mi_idx.info_type_id and t.id = 2499084;
production_note                      |           movie_title           | production_year |         kind         |  movie_year
----------------------------------------------------------+---------------------------------+-----------------+----------------------+--------------
(uncredited)                                             | Who's Afraid of Virginia Woolf? |            1966 | production companies | top 250 rank
(presents: Ernest Lehman's production of Edward Albee's) | Who's Afraid of Virginia Woolf? |            1966 | production companies | top 250 rank
(2 rows)

postgres=# SELECT distinct mc.note AS production_note, (t.title) AS movie_title, (t.production_year), ct.kind, it.info AS movie_year FROM company_type AS ct, info_type AS it, movie_companies AS mc, movie_info_idx AS mi_idx, title AS t WHERE ct.kind = 'production companies' AND it.info = 'top 250 rank' AND ct.id = mc.company_type_id AND t.id = mc.movie_id AND t.id = mi_idx.movie_id AND mc.movie_id = mi_idx.movie_id AND it.id = mi_idx.info_type_id and t.id = 2499084 and mc.note like '%presents%';
production_note                      |           movie_title           | production_year |         kind         |  movie_year
----------------------------------------------------------+---------------------------------+-----------------+----------------------+--------------
(presents: Ernest Lehman's production of Edward Albee's) | Who's Afraid of Virginia Woolf? |            1966 | production companies | top 250 rank
(1 row)

postgres=# SELECT distinct mc.note AS production_note, (t.title) AS movie_title, (t.production_year), ct.kind, it.info AS movie_year FROM company_type AS ct, info_type AS it, movie_companies AS mc, movie_info_idx AS mi_idx, title AS t WHERE ct.kind = 'production companies' AND it.info = 'top 250 rank' AND ct.id = mc.company_type_id AND t.id = mc.movie_id AND t.id = mi_idx.movie_id AND mc.movie_id = mi_idx.movie_id AND it.id = mi_idx.info_type_id and t.id = 2499084 and mc.note like '%(presents)%';
 production_note | movie_title | production_year | kind | movie_year
-----------------+-------------+-----------------+------+------------
(0 rows)
```

It appears that "(presents: Ernest Lehman's production of Edward Albee's)" is LIKE "%presents%" but not LIKE "%(presents)%". The postgres docs tell me that the parens are used for grouping patterns, but I guess that doesn't apply if there is only one alternative.

If I use parens too then I get the correct results. Fine. On to Q3.

``` julia
q = 3
length(results_sqlite) = 107
Test Failed
  Expression: imp_only.columns == sqlite_only.columns
   Evaluated: (String[],) == (String["Austin Powers 4","Teeny-Action Volume 7"],)
```

Imp returns 105 rows. SQLite returns 107 rows. Postgres returns 105 rows. That sounds like I messed up my data sources.

Oh well, let's blow everything away and rebuild, to make sure I have a consistent set of data.

I'm using the [original csv files](http://homepages.cwi.nl/%7Eboncz/job/imdb.tgz) from the author of the JOB paper. Postgres can import them directly. SQLite doesn't understand the escapes, so I'll re-export them from postgres to feed to SQLite (this requires giving the postgres user write access to the directory). Imp can read the originals. Then if Imp and Postgres agree on the results and SQLite disagrees, we can suspect the export/import process.


``` julia
length(Job.q3a())
# 105
```

```
postgres=# SELECT count(distinct t.title) FROM keyword AS k, movie_info AS mi, movie_keyword AS mk, title AS t WHERE k.keyword  like '%sequel%' AND mi.info  IN ('Sweden', 'Norway', 'Germany', 'Denmark', 'Swedish', 'Denish', 'Norwegian', 'German') AND t.production_year > 2005 AND t.id = mi.movie_id AND t.id = mk.movie_id AND mk.movie_id = mi.movie_id AND k.id = mk.keyword_id;
 count
-------
   105
(1 row)
```

```
sqlite> SELECT count(distinct t.title) FROM keyword AS k, movie_info AS mi, movie_keyword AS mk, title AS t WHERE k.keyword  like '%sequel%' AND mi.info  IN ('Sweden', 'Norway', 'Germany', 'Denmark', 'Swedish', 'Denish', 'Norwegian', 'German') AND t.production_year > 2005 AND t.id = mi.movie_id AND t.id = mk.movie_id AND mk.movie_id = mi.movie_id AND k.id = mk.keyword_id;
107
```

Well there you go.

Let's pick one of the extra rows and see what's going on.

```
sqlite> SELECT distinct t.title, k.keyword, mi.info, t.production_year FROM keyword AS k, movie_info AS mi, movie_keyword AS mk, title AS t WHERE k.keyword  like '%sequel%' AND mi.info  IN ('Sweden', 'Norway', 'Germany', 'Denmark', 'Swedish', 'Denish', 'Norwegian', 'German') AND t.production_year > 2005 AND t.id = mi.movie_id AND t.id = mk.movie_id AND mk.movie_id = mi.movie_id AND k.id = mk.keyword_id AND t.title == 'Austin Powers 4';
"Austin Powers 4",sequel,Germany,""
```

```
postgres=# SELECT title.production_year FROM title where title.title = 'Austin Powers 4';
 production_year
-----------------

(1 row)
```

Oh dear. The production year is null and SQLite thinks null > 2005. Imp and Postgres both think that if there is no production year it can't be > 2005.

...

Maybe I should test against Postgres instead.

``` julia
function test()
  @test Base.return_types(q1a) == [Relation{Tuple{Vector{String}, Vector{String}, Vector{Int64}}}]
  @test Base.return_types(q2a) == [Relation{Tuple{Vector{String}}}]
  @test Base.return_types(q3a) == [Relation{Tuple{Vector{String}}}]
  @test Base.return_types(q4a) == [Relation{Tuple{Vector{String}, Vector{String}}}]

  # db = SQLite.DB("../imdb/imdb.sqlite")
  # for q in 1:4
  #   results_imp = eval(Symbol("q$(q)a"))()
  #   query = rstrip(readline("../job/$(q)a.sql"))
  #   query = replace(query, "MIN", "")
  #   frame = SQLite.query(db, query)
  #   num_columns = length(results_imp.columns)
  #   results_sqlite = Relation(tuple((frame[ix].values for ix in 1:num_columns)...), num_columns)
  #   (imp_only, sqlite_only) = Data.diff(results_imp, results_sqlite)
  #   @show q
  #   @test imp_only.columns == sqlite_only.columns # ie both empty - but @test will print both otherwise
  # end

  for q in 1:4
    results_imp = eval(Symbol("q$(q)a"))()
    query = rstrip(readline("../job/$(q)a.sql"))
    query = query[1:(length(query)-1)] # drop ';' at end
    query = replace(query, "MIN", "")
    query = "copy ($query) to '/tmp/results.csv' with CSV DELIMITER ',';"
    run(`sudo -u postgres psql -c $query`)
    frame = DataFrames.readtable(open("/tmp/results.csv"), header=false, eltypes=[eltype(c) for c in results_imp.columns])
    num_columns = length(results_imp.columns)
    results_pg = Relation(tuple((frame[ix].data for ix in 1:num_columns)...), num_columns)
    (imp_only, pg_only) = Data.diff(results_imp, results_pg)
    @show q
    @test imp_only.columns == pg_only.columns # ie both empty - but @test will print both otherwise
  end
end
```

All tests pass.

Early bench results (median, in ms, to 2 sf). Imp 0.30 31 82 54. Pg 6.8 530 180 120. SQLite 250 200 93 87.

Ok, what next? Completing all the JOB queries has to come last, because I want to test the number of attempts required to get a good variable ordering by hand. I want to use read-write balanced data-structures in Imp for a fair comparison, instead of the read-optimized arrays I have at the moment, but I don't know if I have time to finish that before the end of the week. One of the steps towards that though is moving from Triejoin to a different worst-case join that makes fewer assumptions about the layout of the data. I'll try it using the same indexes I have now and see if it hurts performance at all.

### 2016 Sep 20

I have a few different index data-structures in mind. Coming up with a interface that can efficiently support joins on any of them is tricky.

The first thing I want to find out is how much it would cost me to switch from TrieJoin to GenericJoin. I can do that just by rewriting the intersection.

``` julia
body = quote
  let
    local iter = shortest($var_columns, los, ats, his, $var_ixes)
    local state = start(iter)
    local $var
    while $need_more_results && !done(iter, state)
      ($var, state) = next(iter, state)
      if assign($var_columns, los, ats, his, $var_ixes, $var)
        $body
      end
    end
  end
end
```

Times after are 0.58 47 170 110, times before were 0.30 31 82 54. I'm seeing a lot of allocations, so maybe those subarrays are a problem. Let's try just returning the ixes.

``` julia
body = quote
  let
    local min_i = shortest(los, ats, his, $var_ixes)
    local column = $var_columns[min_i]
    local at = los[$var_ixes[min_i]]
    local hi = his[$var_ixes[min_i]]
    while $need_more_results && (at < hi)
      let $var = column[at]
        at += 1
        if assign($var_columns, los, ats, his, $var_ixes, $var)
          $body
        end
      end
    end
  end
end
```

(I just want to once again note how much easier my life would be if Julia could stack-allocate things containing points.)

Ok, allocations go away, and the times are a little better - 0.47 42 160 110.

Actually though, in both cases I need to skip repeated values so `at += 1` needs to be `at = gallop(column, $var, at, hi, <=)`, which is a little more expensive in this case.

Altogether it looks like about 2x the time, which makes sense because the `assign` repeats work done by iteration. Maybe if we were a little smarter we could remove that. Let's add a parameter to `assign` that skips whichever column we're drawing from.

``` julia
function assign(cols, los, ats, his, ixes, value, skip)
  @inbounds begin
    n = length(ixes)
    for c in 1:n
      if c != skip
        ix = ixes[c]
        los[ix+1] = gallop(cols[c], value, los[ix], his[ix], <)
        if los[ix+1] >= his[ix]
          return false
        end
        his[ix+1] = gallop(cols[c], value, los[ix+1], his[ix], <=)
        if los[ix+1] >= his[ix+1]
          return false
        end
      end
    end
    return true
  end
end
```

``` julia
body = quote
  @inbounds let
    local min_i = shortest(los, ats, his, $var_ixes)
    local ix = $var_ixes[min_i]
    local column = $var_columns[min_i]
    ats[ix] = los[ix]
    while $need_more_results && (ats[ix] < his[ix])
      let $var = column[ats[ix]]
        los[ix+1] = ats[ix]
        ats[ix] = gallop(column, $var, ats[ix], his[ix], <=)
        his[ix+1] = ats[ix]
        if assign($var_columns, los, ats, his, $var_ixes, $var, min_i)
          $body
        end
      end
    end
  end
```

Now we get 0.38 34 73 44. That's actually somewhat better than the original. I'm confused.

Perhaps lookups in the job queries almost always succeed, because most of them are foreign key joins, so the leapfrog part of triejoin just ends up being wasted work?

But counting triangles also shows a similar improvement, from 636ms to 598ms. Really not sure what to make of that.

The upside is that it looks like I can switch to GenericJoin without major losses, at least on my current benchmarks.

Julia 0.5 is out for real now, so let's quickly upgrade. Benchmark numbers are about the same.

### 2016 Sep 21

Ok, let's figure out what the query plan should look like. I'm going to preallocate all the needed state up front, to avoid messing around with trying to split up structures so that non-pointerful parts can be stack-allocated.

``` julia
index_1 = index(edge, [1,2])
index_2 = index(edge, [1,2])
index_3 = index(edge, [2,1])

results_a = ...
results_b = ...
results_c = ...

state_ix = @min_by_length(index_1, Val{1}, index_2, Val{1})
while @switch state_ix !done(index_1, Val{1}) !done(index_2, Val{1})
  a = @switch state_ix next!(index_1, Val{1}) next!(index_2, Val{1})
  ok_1 = (state_ix == 1) || skip!(index_1, Val{1})
  ok_2 = (state_ix == 2) || skip!(index_2, Val{1})
  if ok_1 && ok_2
    ...
  end
end
```

I'm using the `Val{1}` to specify the column, making the return type predictable.

I don't really like breaking up the iter interface into done/next. I would rather have a `foreach` and pass a closure, but if `index_1` and `index_2` have different types this risks blowing up the amount of code generated at each step. It seems best to stick to a single path through the query.

So now I need to implement this iterator interface for sorted arrays.

``` julia
type Index{T}
  columns::T
  los::Vector{Int64}
  ats::Vector{Int64}
  his::Vector{Int64}
end

function index{T}(relation::Relation{T}, order::Vector{Int64})
  columns = get!(relation.indexes, order) do
    columns = tuple([copy(relation.columns[ix]) for ix in order]...)
    quicksort!(columns)
    columns
  end
  n = length(order) + 1
  los = [1 for _ in 1:n]
  ats = [1 for _ in 1:n]
  his = [length(relation)+1 for _ in 1:n]
  Index(columns, los, ats, his)
end

function span{T,C}(index::Index{T}, ::Type{Val{C}})
  # not technically correct - may be repeated values
  index.his[C] - index.ats[C]
end

function start!{T,C}(index::Index{T}, ::Type{Val{C}})
  index.ats[C] = index.los[C]
end

function next!{T,C}(index::Index{T}, ::Type{Val{C}})
  val = index.columns[C][index.ats[C]]
  index.los[C+1] = index.ats[C]
  index.ats[C] = gallop(index.columns[C], val, index.ats[C], index.his[C], <=)
  index.his[C+1] = index.ats[C]
  val
end

function skip!{T,C}(index::Index{T}, ::Type{Val{C}}, val)
  index.los[C+1] = gallop(index.columns[C], val, index.los[C], index.his[C], <)
  if index.los[C+1] >= index.his[C]
    return false
  end
  index.his[C+1] = gallop(index.columns[C], val, index.los[C+1], index.his[C], <=)
  if index.los[C+1] >= index.his[C+1]
    return false
  end
  return true
end
```

Major debugging follows. I've totally destroyed type inference, somehow.

I learned how to get at closure objects:

``` julia
Base.return_types(eval(Expr(:new, Symbol("#eval_tracks#10"))), (Int64,))
```

I spent the entire day debugging newly created type inference issues and eventually decided to give up on it entirely. It's been nothing but a time sink, and I knew it was going to be a time sink from the beginning and I did it anyway. Note to self - do not ignore that feeling of creeping doom.

Bench numbers for new relation api are 0.45 35 67 38. Within a margin of error of previous numbers.

I belatedly realised that typing this stateful interface was going to be really hard for the other index structures I had in mind, so I also tried out a stateless interface.

``` julia
immutable Finger{C}
  lo::Int64
  hi::Int64
end

function finger(index)
  Finger{1}(1, length(index[1])+1)
end

function Base.length{C}(index, finger::Finger{C})
  # not technically correct - may be repeated values
  finger.hi - finger.lo
end

@generated function project{C}(index, finger::Finger{C}, val)
  quote
    column = index[$C]
    down_lo = gallop(column, val, finger.lo, finger.hi, <)
    down_hi = gallop(column, val, down_lo, finger.hi, <=)
    Finger{$(C+1)}(down_lo, down_hi)
  end
end

function Base.start{C}(index, finger::Finger{C})
  finger.lo
end

function Base.done{C}(index, finger::Finger{C}, at)
  at >= finger.hi
end

@generated function Base.next{C}(index, finger::Finger{C}, at)
  quote
    column = index[$C]
    next_at = gallop(column, column[at], at, finger.hi, <=)
    (Finger{$(C+1)}(at, next_at), next_at)
  end
end

function head{C}(index, finger::Finger{C})
  index[C-1][finger.lo]
end
```

`project` and `next` have to be generated because the type inference sees `C+1` as opaque and then terrible things happen down the road.

Times (on battery power, so not super trustworthy) are 0.57 160 79 48. Allocation numbers are really high, especially for q2a. Maybe things are not ending up on the stack as I'd hoped.

Aha, `head` also needs to be generated, again because the type inference sees `C-1` as opaque. Battery power numbers now are 0.35 33 62 35. Happy with that.

Allocations are still much higher than I expected though. How do I debug this...

Let's take one of the queries and remove clauses until we get to the minimal surprise-allocating query.

``` julia
@query begin
  movie_keyword(_, t_id, _)
  title(t_id, _, _, _, _)
  @when t_id < -1
  return (t_id::Int64,)
end
# 0 results
# (5.06 M allocations: 161.319 MB, 56.56% gc time)
```

The types are all correctly inferred and there is nothing surprising in the lowered code, so let's poke around in the llvm bitcode.

Every gallop is followed by a heap allocation:

``` julia
%159 = call i64 @julia_gallop_73100(%jl_value_t* %148, i64 %158, i64 %at.0, i64 %97) #0
%160 = call %jl_value_t* @jl_gc_pool_alloc(i8* %ptls_i8, i32 1456, i32 32)
```

It's hard to follow the rest of the bitcode, but my first suspicion is that it's allocating the type `Finger{C}`. So let's calculate those at compile time:

``` julia
@generated function project{C}(index, finger::Finger{C}, val)
  quote
    column = index[$C]
    down_lo = gallop(column, val, finger.lo, finger.hi, <)
    down_hi = gallop(column, val, down_lo, finger.hi, <=)
    $(Finger{C+1})(down_lo, down_hi)
  end
end

@generated function Base.next{C}(index, finger::Finger{C}, at)
  quote
    column = index[$C]
    next_at = gallop(column, column[at], at, finger.hi, <=)
    ($(Finger{C+1})(at, next_at), next_at)
  end
end
```

No difference.

Offhand, I notice this chunk of code:

``` julia
SSAValue(16) = (Core.tuple)($(Expr(:new, Data.Finger{2}, :(at), :(next_at@_29))),next_at@_29::Int64)::Tuple{Data.Finger{2},Int64}
SSAValue(5) = SSAValue(16)
SSAValue(28) = (Base.getfield)(SSAValue(5),1)::UNION{DATA.FINGER{2},INT64}
```

Now there is some shitty type inference. It put a thing in a tuple, then took it out again, and immediately forgot what it was.

I wonder if I can get rid of the tuples.

Took a bit of fiddling, but I can use the down_finger as the iterator for the loop too.

``` julia
function finger(index)
  Finger{0}(1, length(index[1])+1)
end

function Base.length{C}(index, finger::Finger{C})
  # not technically correct - may be repeated values
  finger.hi - finger.lo
end

@generated function project{C}(index, finger::Finger{C}, val)
  quote
    column = index[$(C+1)]
    down_lo = gallop(column, val, finger.lo, finger.hi, <)
    down_hi = gallop(column, val, down_lo, finger.hi, <=)
    Finger{$(C+1)}(down_lo, down_hi)
  end
end

@generated function Base.start{C}(index, finger::Finger{C})
  quote
    column = index[$(C+1)]
    hi = gallop(column, column[finger.lo], finger.lo, finger.hi, <=)
    Finger{$(C+1)}(finger.lo, hi)
  end
end

function Base.done{C, C2}(index, finger::Finger{C}, down_finger::Finger{C2})
  down_finger.hi >= finger.hi
end

function Base.next{C,C2}(index, finger::Finger{C}, down_finger::Finger{C2})
  column = index[C2]
  hi = gallop(column, column[down_finger.hi], down_finger.hi, finger.hi, <=)
  Finger{C2}(down_finger.hi, hi)
end

function head{C}(index, finger::Finger{C})
  index[C][finger.lo]
end
```

Still have 5m allocations though.

``` julia
function foo()
  finger = Finger{1}(1,1)
  for _ in 1:1000
    finger = Finger{1}(finger.hi + finger.lo, finger.lo)
  end
  finger
end
```

This doesn't allocate at all. So fingers definitely *can* be stack-allocated. The lowered code doesn't look any different to me. Not sure what else to do.

Inlining all the finger functions has no effect.

Changing the switch macros to avoid accidental returns actually increases the number of allocations to 7m. That's interesting. It shouldn't do anything...

### 2016 Sep 22

Yesterday was a bit long, so I want to just try a few simple things today and switch project for the rest of the day.

Unlike the type system, there's no insight into how Julia decides whether or not to stack-allocate something, so I've just been repeatedly guessing. I could really do with a tool that explains the decision. I sent a question to the mailing list, asking if there is a better debugging process than just trying things at random.

Judging by the order of occurence, it looks like the allocations are for `start` and `project` but not for `next`.

Poking around inside the llvm bitcode I'm about 50% confident that the allocation for `next` is being reusued, but it's still not on the stack. But while I'm in there I notice that there are a lot of checks for undefined variables.

Of course - if the compiler can't prove that a variable might be null, it can't possibly stack-allocate it. So what if I just zero out the fingers at the beginning:

``` julia
$([:(local $down_finger = Finger{$col_ix}(0,0)) for (down_finger, col_ix) in zip(down_fingers, col_ixes)]...)
```

Down to 2.5m allocations. Excellent. That also explains why messing with `switch` affected the number of allocations - it made it harder for the compiler to figure out that the variable was definitely allocated.

Solving the same problem for `var` reduces the allocations to 32. Happy days.

Bench numbers 0.33 28 60 34.

Let's comb through the llvm bitcode a little more to make sure there are no other surprises, and then I'll move on.

There's some messy allocation and generic calls resulting from the fact that the return type of `index` is not inferrable. I don't see a way around this that also leaves the return type of `head` inferrable. The latter is much more important, so this stays for now. It will only matter in subqueries, and I have other possible solutions for those.

I will move it into the index function itself though, so that other data-structures can have their own individual hacks.

``` julia
@generated function index{T, O}(relation::Relation{T}, ::Type{Val{O}})
  order = collect(O)
  typs = [:(typeof(relation.columns[$ix])) for ix in order]
  quote
    index(relation, $order)::Tuple{$(typs...)}
  end
end
```

I guess the next thing to do is build a new index type. I have a bunch of ideas, but let's start tomorrow with something really simple - nested hashtables.

### 2016 Sep 23

I wrote most of the nested hashtables implementation before getting bogged down in details of the finger protocol again. I ended up going back to something similar to my original mutable implementation, except with individual fingers rather than some hard-to-type agglomeration of state. While the actual instructions executed are probably the same, it feels much easier to reason about.

``` julia
type Finger{T}
  column::Vector{T}
  lo::Int64
  hi::Int64
end

function finger(relation::Relation, index)
  Finger(Void[], 1, length(index[1])+1)
end

@inline function finger(relation::Relation, index, finger, col_ix)
  Finger(index[col_ix-1], 0, 0)
end

function Base.length(finger::Finger)
  # not technically correct - may be repeated values
  finger.hi - finger.lo
end

function project{T,T2}(finger::Finger{T}, down_finger::Finger{T2}, val)
  down_finger.lo = gallop(down_finger.column, val, finger.lo, finger.hi, <)
  down_finger.hi = gallop(down_finger.column, val, down_finger.lo, finger.hi, <=)
  down_finger.lo < down_finger.hi
end

function Base.start{T,T2}(finger::Finger{T}, down_finger::Finger{T2})
  down_finger.lo = finger.lo
  down_finger.hi = gallop(down_finger.column, down_finger.column[down_finger.lo], down_finger.lo, finger.hi, <=)
  down_finger.lo < down_finger.hi
end

function Base.next{T,T2}(finger::Finger{T}, down_finger::Finger{T2})
  if down_finger.hi >= finger.hi
    false
  else
    down_finger.lo = down_finger.hi
    down_finger.hi = gallop(down_finger.column, down_finger.column[down_finger.lo], down_finger.lo, finger.hi, <=)
    true
  end
end

function head{C, C2}(finger::Finger{C}, down_finger::Finger{C2})
  down_finger.column[down_finger.lo]
end
```

``` julia
starts = [:(start($finger, $down_finger)) for (finger, down_finger) in fingers]
projects = [:((ix == $ix) || project($finger, $down_finger, $(esc(var)))) for (ix, (finger, down_finger)) in enumerate(fingers)]
heads = [:(head($finger, $down_finger)) for (finger, down_finger) in fingers]
nexts = [:(next($finger, $down_finger)) for (finger, down_finger) in fingers]
body = quote
  let
    local ix = @min_by_length($(fingers...))
    local more = @switch ix $(starts...)
    local $(esc(var))
    while $need_more_results && more
      $(esc(var)) = @switch ix $(heads...)
      if $(reduce((a,b) -> :($a && $b), projects))
        $body
      end
      more = @switch ix $(nexts...)
    end
  end
end
```

Times now are 0.35 31 68 40. The slight slowdown didn't occur from the move to the mutable api, but only after I moved the columns into the individual fingers. Best guess is the extra field access is a little more expensive than fetching the column out of a register? I'll live, I guess.

I finished the core of the nested relations implementation, but it's currently missing results on some queries. I'll finish debugging tomorrow.

### 2016 Sep 24

Feeling a little unmotivated today so I'm working on fixing minor annoyances in my environment.

I fixed palm detection on my touchpad, disabled the unity multi-touch gestures that I keep using by accident, and in the process accidentally fixed a race condition where some of my window manager keyboard shortcuts would get swallowed.

``` bash
jamie@machine:~$ sudo cat /etc/modprobe.d/synaptics.conf
blacklist i2c-designware-platform
jamie@machine:~$ tail -n 2 .bashrc
pkill syndaemon
syndaemon -i 0.2 -K -d
```

I disabled coasting to avoid the notorious ctrl-zoom bug.

``` bash
jamie@machine:~$ tail -n 1 .bashrc
synclient CoastingSpeed=0
```

I moved all of my Julia and Atom packages off master and onto stable versions, now that Julia 0.5 is officially released. I also updated Atom by hand, since the automatic update fails.

The default Atom spell checker does not work if your system locale is not en-US. I switched to the spell-check-test package which allows specifying alternate locales.

If I have one atom window open and I accidentally close it, restarting atom will restore that window. If have two atom windows open and I accidentally close one, it's gone forever. The project-manager package is a decent workaround for this.

I've had problems with graphical corruption in Atom. The internet seems to believe that SNA is the most likely culprit, so I'm tentatively switching to UXA and I'll see if it happens again in the next few days.

``` bash
jamie@machine:~$ sudo cat /etc/X11/xorg.conf
Section "Device"
	Identifier "Intel Graphics"
	Driver "intel"
	Option "AccelMethod" "uxa"
EndSection
```

### 2016 Sep 25

Graph queries for nested hashes are missing a result. Let's try debugging again now that I'm fresh.

The finger implementation looks correct.

The indexes for the graph are correct.

Dumping the assigned vars:

``` julia
a = 4
b = 2
a = 2
b = 2
a = 3
b = 2
a = 1
b = 2
c = 3
```

All the possible values of `a` are checked. It also checks `a=2, b=2` and `a=3, b=2` which are not possible combinations. In fact, `b=2` every time.

Let's also dump the fingers:

``` julia
(#542#finger_1_0,#543#finger_1_1) = (Nested.Finger{Dict{Int64,Dict{Int64,Void}}}(Dict(4=>Dict(2=>nothing),2=>Dict(3=>nothing),3=>Dict(4=>nothing,1=>nothing),1=>Dict(2=>nothing)),-1),Nested.Finger{Dict{Int64,Void}}(Dict{Int64,Void}(),-1))
(#550#finger_5_0,#551#finger_5_1) = (Nested.Finger{Dict{Int64,Dict{Int64,Void}}}(Dict(4=>Dict(3=>nothing),2=>Dict(4=>nothing,1=>nothing),3=>Dict(2=>nothing),1=>Dict(3=>nothing)),-1),Nested.Finger{Dict{Int64,Void}}(Dict{Int64,Void}(),-1))
a = 4
(#543#finger_1_1,#544#finger_1_2) = (Nested.Finger{Dict{Int64,Void}}(Dict(2=>nothing),2),Nested.Finger{Void}(nothing,-1))
(#546#finger_3_0,#547#finger_3_1) = (Nested.Finger{Dict{Int64,Dict{Int64,Void}}}(Dict(4=>Dict(2=>nothing),2=>Dict(3=>nothing),3=>Dict(4=>nothing,1=>nothing),1=>Dict(2=>nothing)),-1),Nested.Finger{Dict{Int64,Void}}(Dict{Int64,Void}(),-1))
b = 2
a = 2
(#543#finger_1_1,#544#finger_1_2) = (Nested.Finger{Dict{Int64,Void}}(Dict(2=>nothing),6),Nested.Finger{Void}(nothing,17))
(#546#finger_3_0,#547#finger_3_1) = (Nested.Finger{Dict{Int64,Dict{Int64,Void}}}(Dict(4=>Dict(2=>nothing),2=>Dict(3=>nothing),3=>Dict(4=>nothing,1=>nothing),1=>Dict(2=>nothing)),-1),Nested.Finger{Dict{Int64,Void}}(Dict(3=>nothing),-1))
b = 2
a = 3
(#543#finger_1_1,#544#finger_1_2) = (Nested.Finger{Dict{Int64,Void}}(Dict(2=>nothing),7),Nested.Finger{Void}(nothing,17))
(#546#finger_3_0,#547#finger_3_1) = (Nested.Finger{Dict{Int64,Dict{Int64,Void}}}(Dict(4=>Dict(2=>nothing),2=>Dict(3=>nothing),3=>Dict(4=>nothing,1=>nothing),1=>Dict(2=>nothing)),-1),Nested.Finger{Dict{Int64,Void}}(Dict(3=>nothing),-1))
b = 2
a = 1
(#543#finger_1_1,#544#finger_1_2) = (Nested.Finger{Dict{Int64,Void}}(Dict(2=>nothing),16),Nested.Finger{Void}(nothing,17))
(#546#finger_3_0,#547#finger_3_1) = (Nested.Finger{Dict{Int64,Dict{Int64,Void}}}(Dict(4=>Dict(2=>nothing),2=>Dict(3=>nothing),3=>Dict(4=>nothing,1=>nothing),1=>Dict(2=>nothing)),-1),Nested.Finger{Dict{Int64,Void}}(Dict(3=>nothing),-1))
b = 2
(#547#finger_3_1,#548#finger_3_2) = (Nested.Finger{Dict{Int64,Void}}(Dict(3=>nothing),-1),Nested.Finger{Void}(nothing,-1))
(#551#finger_5_1,#552#finger_5_2) = (Nested.Finger{Dict{Int64,Void}}(Dict(3=>nothing),-1),Nested.Finger{Void}(nothing,-1))
c = 3
```

On the second line, it finds `b=2` from one of the fingers and then projects in the other and fails. This is incorrect, both have a key for `b=2`.

Ah, the project doesn't fail, it hits `a<b` on the next line. I forgot about those.

Next we go to `a=2` which is legit, but then somehow hit `b=2` again.

Aha - `next` needs to set `down_finger.index` as well as `down_finger.state`. Oops.

This query works now. The test doesn't, because it looks at internal state. I need to add an method that dumps out the columns for tests.

I'll have to remove the return type tests entirely, but they aren't all that useful now that I've given up on inference anyway.

Nested hashtables now work ok for simple queries, but they are far too memory inefficient to load the JOB data, even with 32GB of RAM. But that's ok, they weren't intended to be the final solution and they helped me hash out the finger protocol.

### 2016 Sep 28

Totally forgot to diarize today.

I made a Franken-hashtable today that uses the sorted columns as backing storage, and builds a hashtable of ranges pointing into each column.

``` julia
type Index{C}
  columns::C
  hashtables::Vector{Vector{UnitRange{Int}}}
  probe_ranges::Vector{UnitRange{Int}}
end
```

I'm using Robin Hood hashing, mostly because it's easy to implement. The theory says that the maximum probe distance at 90% occupancy should be around 6. I'm seeing ~50. Some quick experiments confirm that some buckets are seeing ~20 collisions, so a probe distance of 6 is out of the question with this hash function. I'll stick to 66% occupancy instead.

Each finger keeps track of the last hash so the down finger only has to combine that with it's new key, rather than rehashing the whole row.

I'm able to get the JOB data loaded, although JLD doesn't play nicely with the UnitRanges in the hashtables so saving/loading is a mess.

Max probe lengths on the JOB tables hover around 20.

Benchmark times are poor. As usual there are a ton of allocations that need to be tracked down.

Peeking at the code for a simple query, it looks like the types in the indexes aren't known. Simple fix.

Times are still poor. Let's have the hashtable lookup bail out early on empty slots - forgot to include that earlier.

Numbers are still not great. 0.64 110 190 140.

### 2016 Sep 29

I still sometimes run out of memory when trying to run the benchmarks with hashtables. Which is ridiculous. It's a 6GB dataset on disk but the columns alone are taking up 20GB in memory. I've been putting off dealing with that for a while, but it looks like it's time.

Julia can measure memory allocation by line, but that's just going to tell me that the allocation all comes from loading the huge datasets into memory.

Let's just load a single file as one string and see what happens:

``` bash
jamie@machine:~/imp$ du -h ../imdb/movie_info.csv
920M	../imdb/movie_info.csv
```

``` julia
@time begin
  s = readstring(open("../imdb/movie_info.csv"))
  nothing
end
# 0.223532 seconds (150 allocations: 919.144 MB, 6.54% gc time)
```

(The weird construction is so that the Atom plugin doesn't try to render the whole string. It really needs some way to lazily render large data-structures.)

``` bash
PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
842 jamie     20   0 10.485g 1.947g  63168 R  99.7  6.2   0:37.76 julia
```

``` julia
@time gc()
# 0.132644 seconds (648 allocations: 33.249 KB, 98.78% gc time)
```

The gc reports taking 0.13s. It takes about 10s to show up in Atom, and then julia-client crashes. [Reliably](https://github.com/JunoLab/atom-julia-client/issues/247).

But julia-client aside, just reading in the whole file results in a reasonable amount of allocation. What about parsing the csv using DataFrames.jl?

``` julia
job = @time read_job("movie_info")
# 52.275075 seconds (348.80 M allocations: 10.628 GB, 6.00% gc time)
```

``` bash
PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
2652 jamie     20   0 11.562g 5.583g  13140 S   0.0 17.9   1:12.23 julia
```

``` julia
gc()
```

``` bash
PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
2652 jamie     20   0 9896544 3.560g  13732 S   0.0 11.4   1:14.83 julia
```

So ~3.5gb just to split it into strings. That seems wrong.

``` julia
length(Set(job.columns[4].data)) # 2720930
length(Set(job.columns[5].data)) # 133610
sum([1 for s in job.columns[4].data if s == ""]) # 0
sum([1 for s in job.columns[5].data if s == ""]) # 13398750
```

Are empty strings interned in Julia?

``` julia
pointer_from_objref("") == pointer_from_objref("") # false
```

Nope.

``` julia
ss = Dict{String, String}()
job.columns[4].data = String[get!(ss, s, s) for s in job.columns[4].data]
job.columns[5].data = String[get!(ss, s, s) for s in job.columns[5].data]
gc()
```

This is taking forever...

Drops memory usage to 2.8gb. Better than nothing. Stills seems like a lot of overhead for a sub-1gb file.

Small numbers are only a few bytes in ascii, but always 8 bytes as an Int64. Postgres treats `integer` as 32 bits. SQLite stores it adaptively depending on the max value. Let's copy SQLite.

The first three columns of this table end up being Int32, Int32, Int8. Only saves about 140mb, but at least the increased locality might help when joining.

It seems like the remaining overhead must be entirely from breaking up into many tiny string allocations. Can't fix that easily unless Julia unifies String and SubString at some point in the future.

Interning probably won't survive load/save with JLD, so I might have to re-intern on loading...

Anyway, back to hashtables. I was trying to figure out why they are so slow. The Julia profiler is not particularly helpful - most of the trace is in Hashed.get_range as expected, but it also places a lot of time in Relation. But timing each part of the query with @time disagrees, and I trust the latter more.

I suspect the memory overhead of the current hash-table representation is a problem. I can test that by changing UnitRange{Int64} to UnitRange{Int32} and seeing how it affects the timings.

Slightly better: 0.56 83 160 130. Not enough to matter. No more hashtables.

Constantly loading this dataset is a huge time-sink, so let's see if I can make it faster. I have an idea that DataFrames is loading stuff row-wise, which means dynamic dispatch on types (unless it's doing something clever with generated types). Let's try doing stuff column-wise instead. I'll use sqlite to avoid having to do any csv parsing.

``` julia
function read_job()
  schema = readdlm(open("data/job_schema.csv"), ',', header=false, quotes=true, comments=false)
  table_column_names = Dict()
  table_column_types = Dict()
  for column in 1:size(schema)[1]
    table_name, ix, column_name, column_type = schema[column, 1:4]
    push!(get!(table_column_names, table_name, []), column_name)
    push!(get!(table_column_types, table_name, []), column_type)
  end
  relations = Dict()
  for (table_name, column_names) in table_column_names
    if isfile("../imdb/$(table_name).csv")
      column_types = table_column_types[table_name]
      @show table_name column_names column_types
      columns = []
      for (column_name, column_type) in zip(column_names, column_types)
        query = "select $column_name from $table_name"
        lines = readlines(`sqlite3 ../imdb/imdb.sqlite $query`)
        if column_type == "integer"
          numbers = Int64[line == "" ? 0 : parse(Int64, line) for line in lines]
          minval, maxval = minimum(numbers), maximum(numbers)
          typ = first(typ for typ in [Int8, Int16, Int32, Int64] if (minval > typemin(typ)) && (maxval < typemax(typ)))
          column = convert(Vector{typ}, numbers)
        else
          interned = Dict{String, String}()
          column = String[get!(interned, line, line) for line in lines]
        end
        push!(columns, column)
      end
      relations[table_name] = Relation(tuple(columns...), 1)
    end
  end
  relations
end
```

A few back-and-forths with code_warntype refine this to:

``` julia
function read_job()
  schema = readdlm(open("data/job_schema.csv"), ',', header=false, quotes=true, comments=false)
  table_column_names = Dict{String, Vector{String}}()
  table_column_types = Dict{String, Vector{String}}()
  for column in 1:size(schema)[1]
    table_name, ix, column_name, column_type = schema[column, 1:4]
    push!(get!(table_column_names, table_name, []), column_name)
    push!(get!(table_column_types, table_name, []), column_type)
  end
  relations = Dict{String, Relation}()
  for (table_name, column_names) in table_column_names
    if isfile("../imdb/$(table_name).csv")
      column_types = table_column_types[table_name]
      @show table_name column_names column_types
      columns = Vector[]
      for (column_name, column_type) in zip(column_names, column_types)
        query = "select $column_name from $table_name"
        lines::Vector{String} = readlines(`sqlite3 ../imdb/imdb.sqlite $query`)
        if column_type == "integer"
          numbers = Int64[(line == "" || line == "\n") ? 0 : parse(Int64, line) for line in lines]
          minval = minimum(numbers)
          maxval = maximum(numbers)
          typ = first(typ for typ in [Int8, Int16, Int32, Int64] if (minval > typemin(typ)) && (maxval < typemax(typ)))
          push!(columns, convert(Vector{typ}, numbers))
        else
          interned = Dict{String, String}()
          for ix in 1:length(lines)
            lines[ix] = get!(interned, lines[ix], lines[ix])
          end
          push!(columns, lines)
        end
      end
      relations[table_name] = Relation(tuple(columns...), 1)
    end
  end
  relations
end
```

Got to go now, will see how long it takes tomorrow.

### 2016 Sep 30

The load time is cut in half. Still much too long. I'll try saving just the columns, so at least I don't have to rebuild whenever I change the representation of relations.

Let's try using substrings to reduce allocation.

``` julia
function read_job()
  db = SQLite.DB("../imdb/imdb.sqlite")
  schema = readdlm(open("data/job_schema.csv"), ',', header=false, quotes=true, comments=false)
  table_column_names = Dict{String, Vector{String}}()
  table_column_types = Dict{String, Vector{String}}()
  for column in 1:size(schema)[1]
    table_name, ix, column_name, column_type = schema[column, 1:4]
    push!(get!(table_column_names, table_name, []), column_name)
    push!(get!(table_column_types, table_name, []), column_type)
  end
  tables = Dict{String, Tuple}()
  for (table_name, column_names) in table_column_names
    if isfile("../imdb/$(table_name).csv")
      column_types = table_column_types[table_name]
      @show table_name column_names column_types
      columns = Vector[]
      for (column_name, column_type) in zip(column_names, column_types)
        query = "select $column_name from $table_name"
        lines::Vector{SubString{String}} = split(readstring(`sqlite3 ../imdb/imdb.sqlite $query`), '\n')
        if column_type == "integer"
          numbers = Int64[(line == "") ? 0 : parse(Int64, line) for line in lines]
          minval = minimum(numbers)
          maxval = maximum(numbers)
          typ = first(typ for typ in [Int8, Int16, Int32, Int64] if (minval > typemin(typ)) && (maxval < typemax(typ)))
          push!(columns, convert(Vector{typ}, numbers))
        else
          push!(columns, lines)
        end
      end
      tables[table_name] = tuple(columns...)
    end
  end
  tables
end
```

Still a ton of allocation. Of course, because SubString contains a pointer so it can't be stack-allocated. It's also immutable, so I can't just allocate one and mutate it in a loop. Worst of both worlds.

This is really frustrating. I'm taking one big string and turning it into one big chunk of integers, and there is no way to use the string api to do this without creating a new heap object for every line.

It looks like the [fix](https://github.com/JuliaLang/julia/pull/18632) for this is pretty close to landing. Hopefully in the next month or two I get to stop complaining about this. Maybe I should just finish the JOB benchmarks with the code as it stands, and then come back to performance work later once it's less frustrating.

For some reason JLD is now hanging when I try to save the columns. I tried Feather. which [crashed](https://github.com/JuliaStats/Feather.jl/issues/21). I tried HDF5 but now it's hanging before I even get to saving. Is my SSD dying? So frustrating.

I've spent 10 days now working on indexes. It feels like it's been a meandering and aimless slog. I think the reason for this is that I don't have a concrete problem to solve. I only wanted indexes at this point for a 'fair' comparison with sqlite so that I can write a progress report without feeling dishonest.

Engineering is mostly about tradeoffs. To decide which tradeoffs to make I need concrete use-cases against which to evaluate them and a good-enough point so I know when to stop working. The most common mistake I make in programming is to try and build something without those. I end up constantly changing my mind, flailing back and forth between different designs. It's stressful and exhausting.

So no more indexes. Let's do the minimum possible to finish:

* Remove Hashed indexes
* Return to single indexes per column
* Write all benchmarks
* Benchmark insert time
* Measure import and load time
* Write report
* Write benchmark repro
* Fix minesweeper
* Add readme

Hashed indexes are gone.

Bunch of faff with serialization - most Julia serialization libraries I tried don't work. Still have horrible load times. But I have the original dataframes saved and back to single indexes.

Bench times for single indexes: 3.04 58.5 99.5 52.5. Looking all the way back, I previously had 1.66 68.8 116 46 for single indexes.

I added the first 26 of 116 queries. Very time-consuming work.

Benchmarks so far:

```
1a imp=3.053742 sqlite=272.002707 pg=8.245
1b imp=0.025493 sqlite=270.378863 pg=0.3545
1c imp=0.3997515 sqlite=269.570717 pg=6.4695
1d imp=0.0296175 sqlite=268.658936 pg=0.409
2a imp=52.3988785 sqlite=248.268076 pg=668.3215
2b imp=50.513265 sqlite=244.603772 pg=637.964
2c imp=46.459809 sqlite=247.278891 pg=609.987
2d imp=67.589642 sqlite=248.307465 pg=829.885
3a imp=103.3306 sqlite=108.787906 pg=200.249
3b imp=55.1109555 sqlite=54.162339 pg=131.461
3c imp=145.452778 sqlite=239.3878935 pg=370.3905
4a imp=52.49697 sqlite=1007.083345 pg=134.812
4b imp=51.2409345 sqlite=115.5015855 pg=72.392
4c imp=59.6302305 sqlite=2306.46438 pg=146.917
5a imp=97.826341 sqlite=498.090845 pg=201.365
5b imp=94.930138 sqlite=498.81496 pg=197.129
5c imp=106.009394 sqlite=586.696994 pg=258.47
6a imp=2.037003 sqlite=15.344694 pg=18.965
6b imp=1153.088708 sqlite=90.9772715 pg=273.2355
6c imp=0.0359965 sqlite=11.6395965 pg=14.14
6d imp=1137.420032 sqlite=2259.020631 pg=7490.549
6e imp=2.098454 sqlite=15.563986 pg=21.8
6f imp=3175.456101 sqlite=2186.361888 pg=7876.016
7a imp=3.101584 sqlite=737.849858 pg=1095.4915
7b imp=2.202317 sqlite=122.181171 pg=291.897
7c imp=597.880991 sqlite=8784.628611 pg=3715.3475
```

In 6b and 6d I do a table scan with a regex. Apparently a bad idea. In 6f I'm suffering from not having factorized queries - a lot of those movies will be repeatedly visited. For all three I would probably be better off starting at title and taking advantage of the early bailout. I'm not going to change any queries until I have the first-attempt results for all of them though, since what I want to demonstrate in this report is that query planning by hand is feasible.

### 2016 Oct 1

Up to q14 now. Tedious.

### 2016 Oct 3

Finished! Did I mention tedious?

### 2016 Oct 4

First benchmark run.

```
query_name imp pg sqlite
1a 3.071881 6.7705 279.363504
1b 0.0263035 0.299 274.663133
1c 0.4211085 5.0635 275.692298
1d 0.033006 0.3205 275.171367
2a 55.495408 561.2585 214.3062825
2b 55.160391 546.6990000000001 213.441694
2c 49.817386 517.1514999999999 212.778674
2d 66.310482 725.064 217.177619
3a 92.679652 180.15 96.235637
3b 48.3193085 117.828 48.850807
3c 131.290474 328.961 219.033419
4a 46.43083 117.355 980.9101165
4b 44.559459 61.4545 104.938573
4c 50.2855675 129.01999999999998 2366.23596
5a 97.617968 200.446 525.961315
5b 97.432777 200.458 520.4906375
5c 107.53948 267.85 603.459389
6a 1.85895 17.997999999999998 13.362409
6b 1028.928198 249.967 85.233788
6c 0.038648 11.541 11.333578
6d 1030.35003 6617.195 2084.073462
6e 1.8559195 18.212 14.013924
6f 2943.7297565 6895.882 2141.013491
7a 2.958819 976.3245 686.1519205
7b 2.0541875 253.956 108.449734
7c 554.682386 3375.3125 7810.208279
8a 37.477649 3003.2889999999998 2128.652536
8b 35.471968 390.313 134.5666935
8c 3397.110242 8374.778 52601.765993
8d 374.441778 4697.5655 47468.901567
9a 1001.729029 640.039 8210.799575
9b 538.684329 630.583 3177.2906035
9c 1024.892182 1843.491 46727.984953
9d 1499.7894565 5042.235 47155.854412
10a 345.042314 561.2235000000001 380.0974195
10b 97.9970765 211.739 129.301383
10c 14963.198416 7037.848 29738.480588
11a 7.1610035 57.05 4.075278
11b 3.2977385 29.478 0.838232
11c 35.5103445 206.652 739.169877
11d 35.8314435 179.1395 2715.0278505
12a 201.6289805 381.6865 2070.368664
12b 0.351489 0.663 1918.953183
12c 278.645284 1433.67 3084.5736475
13a 663.082294 3014.3655 744.67811
13b 1066.653256 1123.806 1780.47162
13c 1053.354259 1088.156 1697.40457
13d 3238.985109 5006.748 5474.839887
14a 84.0854095 370.95500000000004 512.4031535
14b 23.56192 153.8 282.514509
14c 222.752032 807.959 1530.3825565
15a 544.531318 702.47 7832.009614
15b 2.965658 32.719 37.654282
15c 3858.9454415 667.2735 394152.840059
15d 3636.7637605 784.207 1.178934880293e6
16a 13.103604 232.153 56.2300195
16b 8518.017965 20322.864 10938.242331
16c 573.129466 1677.619 863.188182
16d 448.0165805 1342.874 674.621042
17a 1809.938807 13111.624 7526.848849
17b 1713.686166 8762.209 13585.672607
17c 1702.306961 8492.641 13442.318623
17d 1738.433212 8589.439 13857.123371
17e 5358.413131 13629.412 6309.469217
17f 1864.826318 11532.09 13757.17439
18a 810.201093 10065.163 21057.091939
18b 87.452809 339.207 529.5813095
19a 629.3732875 652.357 5555.695429
19b 493.187239 355.527 1058.993306
19c 660.457585 1917.405 25442.382734
19d 1033.585309 15797.603 30571.114081
20a 711.6771485 3251.322 107023.383618
20b 271.369411 2301.563 9355.733106
20c 222.872613 1267.932 2127.687286
21a 12.462066 77.983 4.054863
21b 11.3896365 60.558 3.594502
21c 12.963332 68.1635 5.8681245
22a 308.396646 518.366 977.3640315
22b 85.853997 325.516 670.5025745
22c 1159.071359 2449.2664999999997 3379.20423
22d 2126.412915 1110.95 6101.439595
23a 265.550127 380.778 98362.413036
23b 17.536473 42.723 1438.3061185
23c 701.8458905 454.929 224723.583161
24a 434.0135775 386.512 7449.437054
24b 1.66058 39.0105 33.206921
25a 1044.914869 3649.65 23759.102137
25b 31.157697 611.747 436.175846
25c 7710.527347 10181.595 24783.495814
26a 97.623228 1157.52 1324.76143
26b 19.634994 265.987 529.391853
26c 228.226249 2130.604 2117.88685
27a 8.718032 25.88 11.726329
27b 3.509686 17.653 5.6765365
27c 8.689416 26.7815 15.320234
28a 278.040839 4366.493 1959.46839
28b 133.448594 346.54150000000004 1063.917472
28c 168.1971225 1008.5464999999999 2624.989602
29a 0.2306125 128.668 187.388822
29b 0.232277 17.816 183.5762085
29c 19.112286 645.936 1214.135009
30a 757.11687 5787.802 821.827739
30b 84.217824 796.575 168.963133
30c 4335.9167925 3540.66 2898.6302355
31a 432.1715465 2843.2295 2367.575553
31b 96.161288 529.9435 432.2645775
31c 692.5884955 2835.7780000000002 2394.80942
32a 0.00469 11.434 237.68343
32b 19.072634 146.0395 234.221476
33a 57.208684 24.683 5.2306125
33b 74.584004 52.11 2.483724
33c 779.229866 31.918 51.4210295
```

Looking at the cases where Imp wins dramatically, they all seem to be single key lookups on indexes that pg and sqlite don't have. That seems unfair, so let's index every column in both databases.

``` julia
for (table_name, column_names) in table_column_names
  for column_name in column_names
    println("create index index_$(table_name)_$(index_name) on $(table_name)($(index_name));")
  end
end
```

I'm going to rebuild the Julia sysimg while I'm at it. Not sure if it will make much of a difference, but it's worth doing.

``` julia
include(joinpath(dirname(JULIA_HOME),"share","julia","build_sysimg.jl")); build_sysimg(force=true)
```

While both of those are running, let's look through the queries that do poorly and figure out what I'm doing wrong.

6b. 12x slower. Table scan with regex.

6f. 1.4x slower. Unclear. Repeatedly hitting the same title?

9a. 1.5x slower. Unclear. No clear starting point. Perhaps put production_year earlier?

10c. 2.1x slower. Unclear.

11a. 1.7x slower. Unclear. Maybe scan company name table?

11b. 3.9x slower. Unclear. Maybe scan company name table?

15c. 5.8x slower. Unclear.

15d. 4.6x slower. Unclear.

19b. 1.4x slower. Maybe title and name filters are too far down?

21a-c. ~3x slower. Company name probably should be higher.

22d. 1.9x slower. Unclear.

23c. 1.5x slower. Internet release too far down?

24a. 1.1x slower.

30c. 1.5x slower. Probably should have started from keywords, not genres.

33a-c. ~30x slower. Not sure about a and c, but b should probably have raised the production_year much higher. Maybe a and c should have used rating?

The most surprising thing for me is the variance between pg and sqlite. Pg is between 3000x faster and 35x slower than sqlite depending on the query.

When there is a clear starting point, the Imp plan is usually obvious and it does well. The really bad numbers come out when there are a bunch of non-indexed constraints and I have to choose which table to scan, without even having looked at how big the tables are.

Imp would definitely benefit from having range lookups (eg 2000 <= production_year <= 2010) which I could already implement pretty well. Regex lookups would be similarly helpful, but probably too much effort to implement right now.

I have a suspicion that factorized queries would do better. In a lot of the query plans I was having to choose which joins to repeatedly evaluate, when a factorized query wouldn't have to repeat any of them. There are also places where I suspect that I'm repeatedly visiting the same keys.

Rerunning the benchmarks now with the extra indexes. I'm expecting to see pg and sqlite to overtake Imp.

### 2016 Oct 5

```
1a 3.1202115 6.9595 714.755314
1b 0.0257545 0.266 1253.4464195
1c 0.4013495 5.2855 596.911987
1d 0.0310445 0.2915 1549.806406
2a 57.964222 528.5129999999999 226.979648
2b 57.0518545 514.4715 226.992055
2c 50.192977 492.427 224.74445
2d 73.451781 683.819 231.8685845
3a 103.396302 176.97500000000002 362.172093
3b 55.3837195 115.32 5.396267
3c 142.2892345 323.4915 2926.0697205
4a 53.6762765 114.16 1032.958873
4b 50.9984105 14.268 174.5805495
4c 59.424809 125.87 2312.750792
5a 95.082645 201.503 509.9380735
5b 97.3775635 202.708 510.5966295
5c 111.208154 251.058 594.544603
6a 1.957761 5.06 2.6287995
6b 1006.102863 217.701 64.005839
6c 0.031437 0.505 0.277817
6d 1000.947793 6468.033 2320.37252
6e 1.830566 7.081 3.063485
6f 2934.395963 6784.543 2358.775037
7a 2.8209975 6.5225 4.782431
7b 1.960479 2.05 0.800264
7c 552.2459225 3381.3705 2528.5973425
8a 35.107938 2988.8050000000003 58.6299025
8b 34.801288 190.562 97.5034705
8c 3574.727053 8322.726 15994.57942
8d 392.911171 4598.378000000001 2152.827988
9a 975.9131825 296.693 3814.6485415
9b 506.1561515 287.195 586.138012
9c 989.774157 1842.02 4187.451232
9d 1506.518 4976.998 5004.8475245
10a 343.275878 536.877 5716.062919
10b 95.312548 183.611 5484.824958
10c 14496.398719 6897.331 28601.112296
11a 6.811867 38.295 450.2559045
11b 3.238811 20.11 452.9634425
11c 34.8917255 172.79399999999998 1817.943096
11d 35.194864 160.855 21247.530559
12a 197.6314385 300.378 1567.7824555
12b 0.34365 0.68 1672.541799
12c 273.457263 1383.03 2382.885773
13a 659.979154 2933.4440000000004 1779.096776
13b 1049.678017 1114.0035 1079.116244
13c 1029.872256 1072.366 953.9510605
13d 3073.325846 4858.845499999999 4603.9182085
14a 81.2734675 343.55 508.1616175
14b 23.130869 136.6515 273.506766
14c 216.014408 746.6220000000001 1609.584826
15a 540.610489 701.432 7930.997191
15b 2.782742 3.563 1168.457507
15c 3700.361472 667.654 1.169465944449e6
15d 3519.1675725 787.214 1.198311287141e6
16a 12.5486395 209.297 47.10287
16b 8540.832453 19933.58 10504.133574
16c 579.138577 1629.88 806.040774
16d 440.858181 1305.267 620.568618
17a 1791.891394 12908.545 5364.176037
17b 1691.674157 8691.878 11440.365504
17c 1680.976286 8355.929 11418.454143
17d 1717.838847 8461.689 11650.675027
17e 5248.298737 13241.499 5375.40818
17f 1821.900949 11355.119 11748.35144
18a 818.59906 10105.076 1574.11824
18b 96.975638 259.153 0.2503385
19a 604.091671 298.06 3881.0141455
19b 470.478289 210.752 746.163688
19c 639.070404 1675.016 4969.1130775
19d 988.719035 15530.924 10587.216846
20a 697.9063015 3183.5555 3589.6914605
20b 295.4850945 2228.325 900.5101145
20c 221.0699405 1211.642 2063.360925
21a 12.228561 47.725 485.073355
21b 11.24698 43.069 481.065692
21c 12.712685 48.596 483.426167
22a 324.2410095 468.607 1059.349457
22b 97.917814 300.765 715.962638
22c 1102.837342 2144.779 6873.302364
22d 2157.846096 1038.7235 14583.581357
23a 259.119604 381.3295 96696.354517
23b 16.7828095 27.257 765.868064
23c 667.43128 451.844 227790.97049
24a 510.320524 309.669 3996.475217
24b 1.64739 3.75 3952.9654885
25a 1044.864274 3597.538 1486.341207
25b 30.467337 378.8765 41.4811205
25c 8029.421799 10246.668 5307.931861
26a 105.9152885 1906.107 1304.715799
26b 20.623313 48.375 523.0151345
26c 247.196486 1733.723 2118.861378
27a 8.936741 45.89 478.353622
27b 3.5890685 44.2795 477.592084
27c 8.8660915 82.846 481.728975
28a 287.8502915 1017.9929999999999 1386.401539
28b 137.398647 903.4725 521.4545765
28c 174.171348 355.126 2206.824854
29a 0.2221165 492.3995 3920.3215215
29b 0.227203 21.439 3966.124948
29c 19.9306195 631.2484999999999 5179.043264
30a 815.20509 5289.308 565.059446
30b 86.6437595 509.36400000000003 32.753604
30c 4705.838128 3557.5755 2714.830581
31a 460.270231 2697.607 607.882617
31b 100.4009585 493.0725 106.1555815
31c 744.030692 2713.9759999999997 5114.846874
32a 0.004895 0.105 0.162307
32b 20.813718 132.73399999999998 55.7848295
33a 52.25795 23.877 49.8586
33b 79.896146 23.746499999999997 62.552559
33c 741.256199 50.125 822.530545
```

Both postgres and sqlite do worse on some queries if you give them the option of using more indexes. I think I knew this theoretically but I'm still really shocked to see it happen so easily.

SQLite also does really well on some of these queries, but when I look into individual examples I find that it does so by returning the wrong answers. That's not ideal.

``` julia
function test_sqlite(qs = query_names())
  db = SQLite.DB("../imdb/imdb.sqlite")
  SQLite.execute!(db, "PRAGMA cache_size = -1000000000;")
  SQLite.execute!(db, "PRAGMA temp_store = memory;")
  for query_name in qs
    results_imp = eval(Symbol("q$(query_name)"))()
    query = rstrip(readline("../job/$(query_name).sql"))
    query = query[1:(length(query)-1)] # drop ';' at end
    query = replace(query, "MIN", "")
    frame = SQLite.query(db, query)
    num_columns = length(results_imp)
    if length(frame.columns) == 0
      correct = (length(results_imp[1]) == 0)
    else
      results_sqlite = Relation(tuple((convert(typeof(results_imp.columns[ix]), frame[ix].values) for ix in 1:num_columns)...), num_columns)
      (imp_only, sqlite_only) = Data.diff(results_imp, results_sqlite)
      imp_only = map((c) -> c[1:min(10, length(c))], imp_only)
      sqlite_only = map((c) -> c[1:min(10, length(c))], sqlite_only)
      correct = (imp_only == sqlite_only)
    end
    println("$query_name $correct")
  end
end
```

```
1a true
1b false
1c true
1d false
2a true
2b true
2c true
2d true
3a false
3b false
3c false
4a true
4b true
4c true
5a true
5b true
5c false
6a true
6b true
6c true
6d true
6e true
6f false
7a true
7b true
7c false
8a false
8b true
8c false
8d true
9a false
9b false
9c false
9d true
10a true
10b true
10c false
11a false
11b false
11c true
11d false
12a true
12b true
12c true
13a true
13b false
13c true
13d true
14a true
14b true
14c true
15a true
15b true
15c false
15d false
16a true
16b false
16c true
16d true
17a false
17b false
17c true
17d false
17e true
17f false
18a false
18b false
19a false
19b true
19c false
19d false
20a false
20b true
20c true
21a false
21b false
21c false
22a false
22b false
22c false
22d false
23a true
23b true
23c true
24a false
24b false
25a true
25b true
25c true
26a true
26b true
26c true
27a false
27b false
27c false
28a false
28b true
28c false
29a true
29b true
29c false
30a false
30b true
30c true
31a true
31b true
31c true
32a true
32b true
33a true
33b true
33c true
```

SQLite isn't even playing the same game here. I'm going to have to exclude it from the results.

If we just compare Imp to Postgres, and look at relative times:

```
imp	pg (fk only)	pg (all)
1.00	2.20	2.27
1.00	11.37	10.11
1.00	12.02	12.55
1.00	9.71	8.83
1.00	10.11	9.52
1.00	9.91	9.33
1.00	10.38	9.88
1.00	10.93	10.31
1.00	1.94	1.91
1.00	2.44	2.39
1.00	2.51	2.46
1.00	2.53	2.46
3.12	4.31	1.00
1.00	2.57	2.50
1.00	2.05	2.06
1.00	2.06	2.08
1.00	2.49	2.33
1.00	9.68	2.72
4.73	1.15	1.00
1.00	298.62	13.07
1.00	6.42	6.28
1.00	9.81	3.82
1.00	2.34	2.30
1.00	329.97	2.20
1.00	123.88	1.00
1.00	6.09	6.10
1.00	80.14	79.75
1.00	11.00	5.37
1.00	2.47	2.45
1.00	12.55	12.28
3.38	2.16	1.00
1.88	2.20	1.00
1.00	1.80	1.80
1.00	3.36	3.32
1.00	1.63	1.56
1.00	2.16	1.87
2.17	1.02	1.00
1.00	7.97	5.35
1.00	8.94	6.10
1.00	5.82	4.87
1.00	5.00	4.49
1.00	1.89	1.49
1.00	1.89	1.93
1.00	5.15	4.96
1.00	4.55	4.42
1.00	1.05	1.04
1.00	1.03	1.02
1.00	1.55	1.50
1.00	4.41	4.09
1.00	6.53	5.80
1.00	3.63	3.35
1.00	1.29	1.29
1.00	11.03	1.20
5.78	1.00	1.00
4.64	1.00	1.00
1.00	17.72	15.97
1.00	2.39	2.34
1.00	2.93	2.84
1.00	3.00	2.91
1.00	7.24	7.13
1.00	5.11	5.07
1.00	4.99	4.91
1.00	4.94	4.87
1.00	2.54	2.47
1.00	6.18	6.09
1.00	12.42	12.47
1.00	3.88	2.96
2.11	2.19	1.00
2.34	1.69	1.00
1.00	2.90	2.54
1.00	15.28	15.03
1.00	4.57	4.47
1.00	8.48	8.21
1.00	5.69	5.44
1.00	6.26	3.83
1.00	5.32	3.78
1.00	5.26	3.75
1.00	1.68	1.52
1.00	3.79	3.50
1.00	2.11	1.85
2.05	1.07	1.00
1.00	1.43	1.44
1.00	2.44	1.55
1.55	1.01	1.00
1.40	1.25	1.00
1.00	23.49	2.26
1.00	3.49	3.44
1.00	19.63	12.16
1.00	1.32	1.33
1.00	11.86	19.53
1.00	13.55	2.46
1.00	9.34	7.60
1.00	2.97	5.26
1.00	5.03	12.62
1.00	3.08	9.53
1.00	15.70	3.66
1.00	2.60	6.77
1.00	6.00	2.11
1.00	557.94	2135.18
1.00	76.70	92.30
1.00	33.80	33.03
1.00	7.64	6.99
1.00	9.46	6.05
1.22	1.00	1.00
1.00	6.58	6.24
1.00	5.51	5.13
1.00	4.09	3.92
1.00	2437.95	22.39
1.00	7.66	6.96
2.40	1.03	1.00
3.14	2.19	1.00
24.41	1.00	1.57
```

I'd say 8a, 29a and 29b are clear failures for postgres. 33c is a clear failure for Imp. Otherwise, I think it's fair to say that both imp and pg have good plans, with Imp leading by a constant factor that's most likely due to the in-memory, read-optimized indexes rather than the query compiler itself.

Let's see what pg did different for 33c.

```
Aggregate  (cost=3988.02..3988.03 rows=1 width=84)
  ->  Nested Loop  (cost=927.04..3988.01 rows=1 width=84)
        ->  Nested Loop  (cost=926.62..3987.55 rows=1 width=69)
              ->  Nested Loop  (cost=926.19..3986.89 rows=1 width=77)
                    Join Filter: (it2.id = mi_idx2.info_type_id)
                    ->  Nested Loop  (cost=925.76..3979.64 rows=13 width=71)
                          ->  Nested Loop  (cost=925.34..3970.07 rows=21 width=56)
                                Join Filter: (kt1.id = t1.kind_id)
                                ->  Nested Loop  (cost=925.34..3966.76 rows=74 width=60)
                                      Join Filter: (ml.movie_id = t1.id)
                                      ->  Nested Loop  (cost=924.91..3927.85 rows=74 width=51)
                                            ->  Index Scan using index_info_type_id on info_type it2  (cost=0.14..14.12 rows=1 width=4)
                                                  Filter: ((info)::text = 'rating'::text)
                                            ->  Nested Loop  (cost=924.77..3912.99 rows=74 width=47)
                                                  Join Filter: (ml.movie_id = mc1.movie_id)
                                                  ->  Hash Join  (cost=924.34..3903.16 rows=15 width=39)
                                                        Hash Cond: (t2.kind_id = kt2.id)
                                                        ->  Nested Loop  (cost=923.22..3901.70 rows=54 width=43)
                                                              ->  Hash Join  (cost=922.79..3354.28 rows=130 width=18)
                                                                    Hash Cond: (mi_idx1.info_type_id = it1.id)
                                                                    ->  Merge Join  (cost=920.37..3295.38 rows=14713 width=22)
                                                                          Merge Cond: (mi_idx1.movie_id = ml.movie_id)
                                                                          ->  Index Scan using index_movie_info_idx_movie_id on movie_info_idx mi_idx1  (cost=0.43..43808.01 rows=1380035 width=14)
                                                                          ->  Sort  (cost=919.92..932.42 rows=5000 width=8)
                                                                                Sort Key: ml.movie_id
                                                                                ->  Nested Loop  (cost=37.49..612.73 rows=5000 width=8)
                                                                                      ->  Seq Scan on link_type lt  (cost=0.00..1.25 rows=3 width=4)
                                                                                            Filter: ((link)::text = ANY ('{sequel,follows,"followed by"}'::text[]))
                                                                                      ->  Bitmap Heap Scan on movie_link ml  (cost=37.49..185.08 rows=1875 width=12)
                                                                                            Recheck Cond: (link_type_id = lt.id)
                                                                                            ->  Bitmap Index Scan on index_movie_link_link_type_id  (cost=0.00..37.02 rows=1875 width=0)
                                                                                                  Index Cond: (link_type_id = lt.id)
                                                                    ->  Hash  (cost=2.41..2.41 rows=1 width=4)
                                                                          ->  Seq Scan on info_type it1  (cost=0.00..2.41 rows=1 width=4)
                                                                                Filter: ((info)::text = 'rating'::text)
                                                              ->  Index Scan using index_title_id on title t2  (cost=0.43..4.20 rows=1 width=25)
                                                                    Index Cond: (id = ml.linked_movie_id)
                                                                    Filter: ((production_year >= 2000) AND (production_year <= 2010))
                                                        ->  Hash  (cost=1.09..1.09 rows=2 width=4)
                                                              ->  Seq Scan on kind_type kt2  (cost=0.00..1.09 rows=2 width=4)
                                                                    Filter: ((kind)::text = ANY ('{"tv series",episode}'::text[]))
                                                  ->  Index Scan using index_movie_companies_movie_id on movie_companies mc1  (cost=0.43..0.59 rows=5 width=8)
                                                        Index Cond: (movie_id = mi_idx1.movie_id)
                                      ->  Index Scan using index_title_id on title t1  (cost=0.43..0.51 rows=1 width=25)
                                            Index Cond: (id = mc1.movie_id)
                                ->  Materialize  (cost=0.00..1.10 rows=2 width=4)
                                      ->  Seq Scan on kind_type kt1  (cost=0.00..1.09 rows=2 width=4)
                                            Filter: ((kind)::text = ANY ('{"tv series",episode}'::text[]))
                          ->  Index Scan using index_company_name_id on company_name cn1  (cost=0.42..0.45 rows=1 width=23)
                                Index Cond: (id = mc1.company_id)
                                Filter: ((country_code)::text <> '[us]'::text)
                    ->  Index Scan using index_movie_info_idx_movie_id on movie_info_idx mi_idx2  (cost=0.43..0.53 rows=2 width=14)
                          Index Cond: (movie_id = t2.id)
                          Filter: (info < '3.5'::text)
              ->  Index Scan using index_movie_companies_movie_id on movie_companies mc2  (cost=0.43..0.62 rows=5 width=8)
                    Index Cond: (movie_id = t2.id)
        ->  Index Scan using index_company_name_id on company_name cn2  (cost=0.42..0.44 rows=1 width=23)
              Index Cond: (id = mc2.company_id)
```

Not all that different. It puts the production year and country code higher up than I did, but copying that doesn't help much.

I thought maybe the problem here is that I hitting all the movie_companies and all the infos before I get to return, so there are going to be huge numbers of dupes. But no, I'm only producing 114 rows total for 96 unique results.

Oh, I guess I'm also redoing all the t1 work for every t2 company. That seems like a bad idea. Let's factor it out into multiple queries:

``` julia
function q33c_factored()
  rating_type = @query begin
    info_type.info(it, "rating")
    return (it::Int8,)
  end
  kind_types = @query begin
    kt_kind in ["tv series", "episode"]
    kind_type.kind(kt, kt_kind)
    return (kt::Int8,)
  end
  movie_links = @query begin
    link in ["sequel", "follows", "followed by"]
    link_type.link(lt, link)
    movie_link.link_type(ml, lt)
    return (ml::Int16,)
  end
  linked_movies = @query begin
    rating_type(it)
    movie_links(ml)
    movie_link.linked_movie(ml, t2)
    title.kind(t2, kt)
    kind_types(kt)
    title.production_year(t2, production_year)
    @when 2000 <= production_year <= 2010
    movie_info_idx.movie(mii2, t2)
    movie_info_idx.info_type(mii2, it)
    movie_info_idx.info(mii2, rating2)
    @when rating2 < "3.5"
    return (ml::Int16, t2::Int32, rating2::String)
  end
  linking_movies = @query begin
    rating_type(it)
    linked_movies(ml, _, _)
    movie_link.movie(ml, t1)
    title.kind(t1, kt)
    kind_types(kt)
    movie_companies.movie(mc1, t1)
    movie_companies.company(mc1, cn1)
    company_name.country_code(cn1, code)
    @when code != "[us]"
    title.title(t1, title1)
    movie_info_idx.movie(mii1, t1)
    movie_info_idx.info_type(mii1, it)
    movie_info_idx.info(mii1, rating1)
    company_name.name(cn1, name1)
    return (ml::Int16, t1::Int32, name1::String, rating1::String, title1::String)
  end
  @query begin
    linking_movies(ml, t1, name1, rating1, title1)
    linked_movies(ml, t2, rating2)
    title.title(t2, title2)
    movie_companies.movie(mc2, t2)
    movie_companies.company(mc2, cn2)
    company_name.name(cn2, name2)
    return (name1::String, name2::String, rating1::String, rating2::String, title1::String, title2::String)
  end
end
```

```
@benchmark(q33c_factored()) = BenchmarkTools.Trial:
  samples:          1957
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  89.27 kb
  allocs estimate:  510
  minimum time:     1.69 ms (0.00% GC)
  median time:      2.44 ms (0.00% GC)
  mean time:        2.55 ms (2.67% GC)
  maximum time:     22.87 ms (88.64% GC)
```

That's about 20x faster than postgres and 320x faster than the original. Maybe I should go ahead and write a factorizing compiler?

[Tuning postgres](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server) resulted in worse performance.

### 2016 Oct 6

I wrote up my results so far and showed them to a few people, and everyone I showed it to said that the report was too short and didn't make sense without going into the code.

But the code is really ugly. So I further delaying the report by going back to clean things up.

I realized I could simplify a lot of the codegen if I was willing to give up on the depth-first model and eat some extra allocations in the query - one buffer per variable. I'm now running an entire intersection at once:

``` julia
immutable Intersection{C, B}
  columns::C
  buffer::B
end

function Intersection(columns)
  buffer = Vector{NTuple{length(columns), UnitRange{Int64}}}()
  Intersection(columns, buffer)
end

function project(column::Vector, range, val)
  lo = gallop(column, val, range.start, range.stop, 0)
  hi = gallop(column, val, lo, range.stop, 1)
  lo:hi
end

@generated function project_at{N}(intersection, ranges::NTuple{N}, val)
  :(@ntuple $N ix -> project(intersection.columns[ix], ranges[ix], val))
end

function intersect_at(intersection, ranges)
  empty!(intersection.buffer)
  min_ix = indmin(map(length, ranges))
  while ranges[min_ix].start < ranges[min_ix].stop
    val = intersection.columns[min_ix][ranges[min_ix].start]
    projected_ranges = project_at(intersection, ranges, val)
    if all(r -> r.start < r.stop, projected_ranges)
      push!(intersection.buffer, projected_ranges)
    end
    ranges = map((old, new) -> new.stop:old.stop, ranges, projected_ranges)
  end
  intersection.buffer
end

function intersect_at(intersection, ranges, val)
  empty!(intersection.buffer)
  projected_ranges = project_at(intersection, ranges, val)
  if all(r -> r.start < r.stop, projected_ranges)
    push!(intersection.buffer, projected_ranges)
  end
  intersection.buffer
end

function val_at(intersection, ranges)
  intersection.columns[1][ranges[1].start]
end
```

This replaces both the finger interface and much of the codegen. The generated code for the queries is now a little more readable:

``` julia
begin  # /home/jamie/imp/src/Query.jl, line 339:
    let  # /home/jamie/imp/src/Query.jl, line 340:
        local #2173#index_1 = (Query.index)(edge,[1,2])
        local #2179#range_1_0 = 1:(Query.length)(#2173#index_1[1]) + 1
        local #2174#index_3 = (Query.index)(edge,[1,2])
        local #2175#index_5 = (Query.index)(edge,[2,1])
        local #2180#range_3_0 = 1:(Query.length)(#2174#index_3[1]) + 1
        local #2181#range_5_0 = 1:(Query.length)(#2175#index_5[1]) + 1 # /home/jamie/imp/src/Query.jl, line 341:
        local #2182#intersection_a = (Query.Intersection)((Query.tuple)(#2173#index_1[1],#2175#index_5[2]))
        local #2183#intersection_b = (Query.Intersection)((Query.tuple)(#2173#index_1[2],#2174#index_3[1]))
        local #2184#intersection_c = (Query.Intersection)((Query.tuple)(#2174#index_3[2],#2175#index_5[1])) # /home/jamie/imp/src/Query.jl, line 342:
        local #2176#results_1 = (Query.Vector){Int64}()
        local #2177#results_2 = (Query.Vector){Int64}()
        local #2178#results_3 = (Query.Vector){Int64}() # /home/jamie/imp/src/Query.jl, line 343:
        begin  # /home/jamie/imp/src/Query.jl, line 327:
            for (#2185#range_1_1,#2186#range_5_1) = (Query.intersect_at)(#2182#intersection_a,(#2179#range_1_0,#2181#range_5_0)) # /home/jamie/imp/src/Query.jl, line 328:
                local a = (Query.val_at)(#2182#intersection_a,(#2185#range_1_1,#2186#range_5_1)) # /home/jamie/imp/src/Query.jl, line 329:
                begin  # /home/jamie/imp/src/Query.jl, line 327:
                    for (#2187#range_1_2,#2188#range_3_1) = (Query.intersect_at)(#2183#intersection_b,(#2185#range_1_1,#2180#range_3_0)) # /home/jamie/imp/src/Query.jl, line 328:
                        local b = (Query.val_at)(#2183#intersection_b,(#2187#range_1_2,#2188#range_3_1)) # /home/jamie/imp/src/Query.jl, line 329:
                        if a < b # /home/jamie/imp/src/Query.jl, line 292:
                            begin  # /home/jamie/imp/src/Query.jl, line 327:
                                for (#2189#range_3_2,#2190#range_5_2) = (Query.intersect_at)(#2184#intersection_c,(#2188#range_3_1,#2186#range_5_1)) # /home/jamie/imp/src/Query.jl, line 328:
                                    local c = (Query.val_at)(#2184#intersection_c,(#2189#range_3_2,#2190#range_5_2)) # /home/jamie/imp/src/Query.jl, line 329:
                                    begin  # /home/jamie/imp/src/Query.jl, line 298:
                                        #2191#need_more_results = true # /home/jamie/imp/src/Query.jl, line 299:
                                        if b < c # /home/jamie/imp/src/Query.jl, line 292:
                                            begin  # /home/jamie/imp/src/Query.jl, line 281:
                                                (Query.push!)(#2176#results_1,a)
                                                (Query.push!)(#2177#results_2,b)
                                                (Query.push!)(#2178#results_3,c) # /home/jamie/imp/src/Query.jl, line 283:
                                                #2191#need_more_results = false
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end # /home/jamie/imp/src/Query.jl, line 344:
        (Query.Relation)((Query.tuple)(#2176#results_1,#2177#results_2,#2178#results_3),3)
    end
end
end
```

As a bonus, compilation time is waaaaay lower.

As usual, there are type inference failures and I'll pick them off one by one.

I can't get proper benchmarks because I'm on a bus and benchmarking without mains power is sketchy, but it looks like this might actually be faster too. I had no idea in advance which way it would fall. There is more cache pressure from filling the buffers, but there is less code and better code locality (because it runs an entire intersection at once rather than jumping back and forth between different intersections) and I also reduced the number of comparisons in project (which could also have been done for the old version).

I'm also down to about 600 lines of code, of which maybe 200 can be deleted once unboxing improves.

Argh. I was seeing really big slowdowns on some of the queries and started to panic a little, but it turns out I forgot to include the `return_after` optimization when I changed to bfs. This uglifies the code again. It would be prettier to wrap the return_after part in a function and call return to break out of the loop, but then I would lose the ability to easily check the code with `@code_warntype`.

``` julia
if typeof(clause) == Assign
  body = (quote let
    local $(esc(var)) = $(esc(clause.expr))
    for $after_ranges in intersect_at($intersection, $before_ranges, $(esc(var)))
      $body
    end
  end end).args[2]
elseif typeof(clause) == In
  body = (quote let
    local iter = $(esc(clause.expr))
    local state = start(iter)
    while $need_more_results && !done(iter, state)
      ($(esc(var)), state) = next(iter, state)
      for $after_ranges in intersect_at($intersection, $before_ranges, $(esc(var)))
        $body
      end
    end
  end end).args[2]
else
  body = (quote let
    local iter = intersect_at($intersection, $before_ranges)
    local state = start(iter)
    local $(after_ranges.args...)
    while $need_more_results && !done(iter, state)
      ($after_ranges, state) = next(iter, state)
      local $(esc(var)) = val_at($intersection, $after_ranges)
      $body
    end
  end end).args[2]
end
```

Bah, still slow. Back to dfs :(

I noticed a problem with my benchmarks. On longer queries, it seems to always run exactly two samples and then include a gc in the second sample, regardless of how much allocation the function performed. So those queries are being charged half of the cost of a full gc, instead of it being amortized over the number of executions it would take to trigger a gc. This *might* be why the bfs version with buffers looked like it had such large regressions.

Notably, I reran 33c and got 6.5ms instead of 740ms.

### 2016 Oct 10

Clear signs of wheel-spinning last week. Most of the last month has been spent trying to persuade Julia to generate the code that I want. That was waste of effort. I'm just going to generate it myself. The resulting code is ugly but I'll live. The report can just explain the problem, and I can write another post when the unboxing pull-request lands in Julia. It also means that there is no longer a clear interface between indexes and queries, but I only wanted that to experiment with different indexes anyway and I'm not doing that anymore. I also switched back to triejoin so I don't have to worry about correctly counting keys.

New benchmarks:

```
"1a" 1.41 ms
"1b" 16.31 μs
"1c" 318.84 μs
"1d" 17.51 μs
"2a" 49.72 ms
"2b" 47.00 ms
"2c" 37.53 ms
"2d" 71.73 ms
"3a" 98.62 ms
"3b" 56.26 ms
"3c" 140.12 ms
"4a" 58.80 ms
"4b" 57.01 ms
"4c" 61.19 ms
"5a" 18.07 ms
"5b" 18.06 ms
"5c" 37.87 ms
"6a" 2.44 ms
"6b" 1.12 s
"6c" 24.37 μs
"6d" 1.19 s
"6e" 2.42 ms
"6f" 3.39 s
"7a" 3.20 ms
"7b" 2.28 ms
"7c" 568.99 ms
"8a" 21.99 ms
"8b" 22.16 ms
"8c" 3.46 s
"8d" 365.90 ms
"9a" 248.63 ms
"9b" 85.12 ms
"9c" 267.16 ms
"9d" 842.88 ms
"10a" 389.45 ms
"10b" 110.14 ms
"10c" 19.76 s
"11a" 7.34 ms
"11b" 6.40 ms
"11c" 32.91 ms
"11d" 33.13 ms
"12a" 187.78 ms
"12b" 80.83 μs
"12c" 264.14 ms
"13a" 697.97 ms
"13b" 1.15 s
"13c" 1.15 s
"13d" 3.25 s
"14a" 82.53 ms
"14b" 25.27 ms
"14c" 178.19 ms
"15a" 650.16 ms
"15b" 1.65 ms
"15c" 3.69 s
"15d" 2.99 s
"16a" 21.67 ms
"16b" 8.35 s
"16c" 566.33 ms
"16d" 449.61 ms
"17a" 2.05 s
"17b" 2.10 s
"17c" 2.02 s
"17d" 1.99 s
"17e" 4.81 s
"17f" 2.27 s
"18a" 442.67 ms
"18b" 109.62 ms
"19a" 406.24 ms
"19b" 292.64 ms
"19c" 408.73 ms
"19d" 806.69 ms
"20a" 969.01 ms
"20b" 346.08 ms
"20c" 300.93 ms
"21a" 13.42 ms
"21b" 12.49 ms
"21c" 13.81 ms
"22a" 172.89 ms
"22b" 97.67 ms
"22c" 470.89 ms
"22d" 739.10 ms
"23a" 109.80 ms
"23b" 8.32 ms
"23c" 253.05 ms
"24a" 217.09 ms
"24b" 819.59 μs
"25a" 1.10 s
"25b" 40.71 ms
"25c" 8.20 s
"26a" 125.42 ms
"26b" 24.10 ms
"26c" 310.49 ms
"27a" 9.27 ms
"27b" 7.44 ms
"27c" 9.32 ms
"28a" 230.57 ms
"28b" 120.77 ms
"28c" 156.38 ms
"29a" 66.33 μs
"29b" 65.88 μs
"29c" 15.00 ms
"30a" 786.33 ms
"30b" 110.01 ms
"30c" 4.59 s
"31a" 405.43 ms
"31b" 130.09 ms
"31c" 594.81 ms
"32a" 4.63 μs
"32b" 20.02 ms
"33a" 2.20 ms
"33b" 56.88 ms
"33c" 5.10 ms
```

Following the advice of [malisper](https://github.com/malisper) I disabled the genetic optimizer in postgres, increasing the query planning time to multiple seconds but dramatically improving the quality of the plans. I also increased the size of `shared_buffers` to 8gb and added an assertion in the benchmark harness that there are no buffer misses.

``` julia
function bench_pg(qs = query_names())
  medians = []
  for query_name in qs
    query = rstrip(readline("../job/$(query_name).sql"))
    query = query[1:(length(query)-1)] # drop ';' at end
    bench = "explain (analyze, buffers) $query"
    cmd = `sudo -u postgres psql -c $bench`
    times = Float64[]
    @show query_name now()
    readstring(cmd)
    trial = @benchmark begin
      result = readstring($cmd)
      time = parse(Float64, match(r"Execution time: (\S*) ms", result)[1])
      missed_buffer = ismatch(r"Buffers [^\n]* read=", result)
      if missed_buffer == true
        println("Miss!")
        println(result)
        @assert false
      end
      push!($times, time)
    end evals=3
    @show trial
    push!(medians, median(times))
  end
  medians
end
```

Updated results for pg:

```
Any[8.384,0.488,6.06,0.4995,579.993,574.173,562.608,717.823,148.766,108.611,262.496,121.608,17.775,126.95,205.613,204.72,233.988,17.2675,179.119,1.443,4020.29,17.279,4420.67,9.888,3.5715,3290.45,2001.78,161.021,9185.58,5408.18,303.381,294.729,1779.26,5369.51,388.797,175.678,7214.28,56.2895,34.1675,186.62,178.331,275.39,1.138,1324.61,3560.86,1227.57,1125.06,5442.63,261.023,112.609,593.089,679.625,8.149,646.972,843.843,174.935,21178.3,1719.74,1381.67,11364.6,4670.83,4392.36,4418.51,10329.0,8133.33,7233.86,235.051,301.255,184.303,1619.21,16241.8,2174.88,1526.24,890.889,72.671,57.3285,63.346,411.781,233.087,1987.7,925.014,391.474,43.981,378.682,541.283,483.223,2302.06,286.858,6186.31,1573.1,119.445,1321.33,56.237,60.613,33.318,1079.37,719.925,879.48,56.557,5.4465,1775.88,2642.17,363.429,2466.51,2592.47,365.791,2624.17,0.165,143.5,30.939,33.864,35.1965]
```

Some queries are better, some are worse.

I finished up the report. Just waiting for a last round of feedback and some non-1am editing for flow.

### 2016 Oct 24

Ok, let's get going again.

Last month I used the benchmark against postgres as a goal to work towards. I wrote the blog post first and then spent the month working to make everything in it true.

Today I started doing the same for the project as whole. I put up a [sketch](https://github.com/jamii/jamii.github.com/blob/master/_drafts/imp.markdown) of what I want the eventual overview to look like.

I also need to pick another short-term goal. I'm leaning towards building a simple stock exchange and trading interface. It's the kind of thing that someone might want to do in a spreadsheet, but it's made difficult by the variable size collections and quantity of data.

Here's a sketch of the core logic for a single market:

``` julia
bitstype 64 Order
@enum Side Buy Sell

@relation order(Order) => (DateTime, Dec64, Int64, Side)
@relation matched(Order, Order) => (Dec64, Int64)
@relation remaining(Side, Dec64, DateTime, Order) => Int64

@query begin
  @minimum remaining(Buy, buy_price, buy_time, buy_order) => buy_quantity
  @maximum remaining(Sell, sell_price, sell_time, sell_order) => sell_quantity
  @when buy_price >= sell_price
  price = (buy_time < sell_time) ? buy_price : sell_price
  quantity = min(buy_quantity, sell_quantity)
  return matched(buy_order, sell_order) => (price, quantity)
end

@query begin
  order(order) => (time, price, quantity, side)
  bought = @query match(order, matched_order) => (_, matched_quantity)
  sold = @query match(matched_order, order) => (_, matched_quantity)
  remaining = quantity - sum(bought[3]) - sum(sold[3])
  @when remaining > 0
  return remaining(side, price, time, order) => remaining
end
```

`@minimum` doesn't currently exist and is awkward to fake using `=` and `@query`, so now is a good time to figure out what to do with aggregates in general.

I want to think of aggregates in general as functions that take a query and return a new relation (possibly containing only one row in the case of simple aggregates like sum), but ideally without having to allocate the intermediate relation.

Meanwhile, I belatedly discovered that Julia has an undocumented goto macro, which means I don't have to manually desugar loops in order to break out in a controlled way.

### 2016 Oct 25

Here are some things that I might want to do with a query:

* Materialize the results into a relation
* Aggregate the results into a single value
* Take the first result, last results, 42nd-57th results etc
* Check whether a specific value is in the results
* Materialize the factorized results, without computing the full results

At the moment I'm struggling because I'm mashing them all into a single chunk of codegen. The original triejoin paper instead defines an trie iterator protocol that both indexes and queries implement. If I did something similar, I could just generate code for the iterator and implement the materialization, aggregates, first/last/range etc as functions of the query.

That feels like another huge compiler time-sink though. Not sure that I want to dive into that again.

### 2016 Nov 7

Wow, a month without any real work. For the sake of just getting something done, I started on a little debugging UI:

``` julia
function debug(relation)
  @relation displaying() => (Int64, String)

  @query return displaying() => (0, relation[1][1])

  @Window(displaying) do window, event_number

    header = @query begin
      relation(name) => _
      displayed = @exists displaying() => (_, $name)
      style = displayed ? "font-weight: bold" : ""
      node = button(Dict(:onclick => @event(displaying() => name), :style => style), name)
      return (name::String,) => node::Node
    end

    grid = @query begin
      displaying() => (_, name)
      relation(name) => relation
      c in 1:length(relation)
      style = "margin-left: 2em"
      node = vbox(map((v) -> Hiccup.div(Dict(:style=>style), string(v)), relation[c]))
      return (c::Int64,) => node::Node
    end

    Blink.body!(window, vbox([hbox(header[2]), hbox(grid[2])]))

  end
end
```

It required tweaking a couple of things elsewhere. Most notably, I changed event push to take account of unique keys properly, so that I only ever store the last chosen relation here.

### 2016 Nov 8

Got most of the way towards making the tables editable, but got bogged down in the details of passing data back and forth between Julia and the browser. I didn't really think through events properly.

### 2016 Nov 9

Really crude awful committing now works for the editor. I never got around to writing a delete function for relations so it only does the right thing if the unique key is left unchanged.

I tried to switch to Escher for the dom diffing but after a few hours ended up with just a [handful of filed issues](https://github.com/shashi/Escher.jl/issues/created_by/jamii) and no hello world.

Trying to update some of the other packages I rely on and finding that package manager is hanging when trying to clone. Cloning the same url directly with git at the command line works fine. No idea what's going on there.

Frustrating.

### 2016 Nov 22

Eugh. Is this thing still on?

The way I've been working with relations at the moment requires blowing away all the state and opening a new UI window whenever I change anything. Clearly that's not good.

To fix this, I have to switch from the current imperative updates to something more declarative. The input state is all going to want to go in a data-structure somewhere, which means that the queries need to be amended to read names out of that structure. I added a new macro that takes a query expression and returns a callable object with some useful metadata.

``` julia
type View
  relation_names::Vector{Symbol}
  query
  code
  eval::Function
end

macro view(query)
  (code, relation_names) = plan_query(query)
  escs = [:($(esc(relation_name)) = $relation_name) for relation_name in relation_names]
  code = quote
    $(escs...)
    $code
  end
  :(View($relation_names, $(Expr(:quote, query)), $(Expr(:quote, code)), $(Expr(:->, relation_names..., code))))
end

function (view::View){R <: Relation}(state::Dict{Symbol, R})
  args = map((s) -> state[s], view.relation_names)
  view.eval(args...)
end
```

Then a bunch of these get wrapped together in a Flow:

``` julia
type Flow
  relations::Dict{Symbol, Relation}
  views::Vector{Pair{Symbol, View}} # TODO make views a dict, do topo sort
  cached::Dict{Symbol, Relation}
  watchers::Set{Any}
end

function Flow()
  Flow(Dict{Symbol, Relation}(), Vector{Pair{Symbol, View}}(), Dict{Symbol, Relation}(), Set{Any}())
end

function refresh(flow::Flow)
  old_cached = flow.cached
  cached = copy(flow.relations)
  for (name, view) in flow.views
    cached[name] = view(cached)
  end
  flow.cached = cached
  for watcher in flow.watchers
    watcher(old_cached, cached)
  end
end

function Base.getindex(flow::Flow, name::Symbol)
  flow.cached[name]
end

function Base.setindex!(flow::Flow, relation::Relation, name::Symbol)
  flow.relations[name] = relation
  refresh(flow)
end

function setviews(flow::Flow, views::Vector{Pair{Symbol, View}})
  flow.views = views
  refresh(flow)
end

function watch(watcher, flow::Flow)
  push!(flow.watchers, watcher)
end
```

The idea is to structure programs like this:

``` julia
flow = Flow()

# set up state
flow[:foo] = @relation ...
flow[:bar] = @relation ...

# set up views
setviews(flow, [
  :quux => @view ...
])

# open a UI
window = Window(flow)
watch(flow) do _, cached
  Blink.body!(window, cached[:body][1][1])
end
```

Then re-evalling any part of the file results in updates to the currently open window, without blowing any state away.

Right now this can't handle fixpoints or unions, because I've been doing those imperatively before, and it doesn't handle subqueries/aggregates because their metadata doesn't get parsed up in the view. Those are fixable.

It also doesn't handle loops over time. The way that Dedalus and Eve handle time is by having a single, serial timeline built in to the language. (Eve has plans for distributed execution, but I don't think they've published anything yet). Time is used to break non-monotonic fixpoints, but also for efficient mutation and for functions that are more easily expressed in sequential form. Tying the latter to the single timeline seems problematic.

I much prefer the model in Timely Dataflow, which allows multiple loops and nested loops. I think this can be done in a way that allows writing reactive programs without baking time into the language.

### 2016 Nov 23

Quickly added subqueries to the syntax. Instead of writing:

``` julia
@view begin
  playlist(p, pn)
  tracks = @query begin
    playlist_track($p, t)
    track(t, _, _, _, _, _, _, _, price)
    return (t::Int64, price::Float64)
  end
  total = sum(tracks[2])
  return (pn::String, total::Float64)
end
```

I can now write:

``` julia
@view begin
  playlist(p, pn)
  @query begin
    playlist_track(p, t)
    track(t, _, _, _, _, _, _, _, price)
    return (t::Int64, price::Float64)
  end
  total = sum(price)
  return (pn::String, total::Float64)
end
```

And the subquery metadata gets propagated up to the final view.

At least in theory. In practice I broke something somewhere and it's pulling NaNs out of thin air...

### 2016 Nov 24

It was variable clashes between the two macros. I suspected as much, but actually figuring out which variable was beyond me last night. Fixed now.

The compiler is an unholy mess. The root of the problem is that without stack allocation it's expensive to abstract out any part of the query into functions. Instead I have to mash everything together into one huge function and carefully keep track of scopes and variable collisions myself. I don't know what to do about that, short of just accepting the performance hit. Based on the slowdowns I had whenever I allocated by mistake, it might about an order of magnitude.

I tweaked the way flows work so that views always merge into some existing relation rather than defining a new one, which gives us back union, but then reconsidered after thinking about the effects on debugging - it means that the value of a given view changes during flow refresh.

It's easy to write union in the current setup:

``` julia
type Union <: AbstractView
  views::Vector{AbstractView}
end

function (union::Union)(inputs::Dict{Symbol, Relation})
  reduce(merge, (view(inputs) for view in union.views))
end
```

Writing fixpoint is less easy, because it doesn't know what output name it's going to be assigned. It's also impossible to write fixpoint over multiple views because the current interface only allow returning one result. Ooops.

I've made and undone changes for an hour or two now. I think it's clear I need to sit down and think about exactly what I want out of this.

### 2016 Dec 11

So I've made some janky flow stuff that I don't really like but will live with for the sake of momentum.

``` julia
abstract Flow

type Create <: Flow
  output_name::Symbol
  input_names::Vector{Symbol}
  meta::Any
  eval::Function
end

type Merge <: Flow
  output_name::Symbol
  input_names::Vector{Symbol}
  meta::Any
  eval::Function
end

type Sequence <: Flow
  flows::Vector{Flow}
end

type Fixpoint <: Flow
  flow::Flow
end

function output_names(create::Create)
  Set(create.output_name)
end

function output_names(merge::Merge)
  Set(merge.output_name)
end

function output_names(sequence::Sequence)
  union(map(output_names, sequence.flows)...)
end

function output_names(fixpoint::Fixpoint)
  output_names(fixpoint.flow)
end

function (create::Create)(inputs::Dict{Symbol, Relation})
  output = create.eval(map((name) -> state[name], create.input_names))
  inputs[create.output_name] = output
end

function (merge::Merge)(inputs::Dict{Symbol, Relation})
  output = merge.eval(map((name) -> state[name], merge.input_names))
  inputs[merge.output_name] = merge(inputs[merge.output_name], output)
end

function (sequence::Sequence)(inputs::Dict{Symbol, Relation})
  for flow in sequence.flows
    flow(inputs)
  end
end

function (fixpoint::Fixpoint)(inputs::Dict{Symbol, Relation})
  names = output_names(fixpoint.flow)
  while true
    old_values = map((name) -> inputs[name], names)
    fixpoint.flow(inputs)
    new_values = map((name) -> inputs[name], names)
    if old_values == new_values
      return
    end
  end
end

function query_to_flow(constructor, query)
  (clauses, vars, created_vars, input_names, return_clause) = Query.parse_query(query)
  code = Query.plan_query(clauses, vars, created_vars, input_names, return_clause, Set())
  escs = [:($(esc(input_name)) = $input_name) for input_name in input_names]
  code = quote
    $(escs...)
    $code
  end
  :($constructor(return_clause.name, $(collect(input_names)), $(Expr(:quote, query)), $(Expr(:->, Expr(:tuple, input_names...), code))))
end

macro create(query)
  query_to_flow(Create, query)
end

macro merge(query)
  query_to_flow(Merge, query)
end
```

I realised that with the way I have things setup currently, I can't write code like I did before that reacts to events and mutates the world state. I think this is probably a good thing. Let's see how far I can get with all mutation confined to the immediate effects of user interaction. A little like the Monolog experiment I worked on earlier this year.

I got it all hooked up to UI too, so I can write things like this:

``` julia
world = World()

world[:window] = Relation(([span("hello")],), 1)

window(world)

world[:window] = Relation(([span("world")],), 1)
```

Next up is redoing the table interface in this new style.

### 2016 Dec 12

Here it is:

``` julia
world = World()

world[:displaying] = @relation () => String

world[:cell] = @relation (Int64, Int64) => Hiccup.Node
world[:row] = @relation (Int64,) => Hiccup.Node
world[:tab] = @relation (String,) => Hiccup.Node
world[:window] = @relation () => Hiccup.Node

begin
  setflow(world, Sequence([
    @create begin
      name in map(string, keys(world.outputs))
      node = button(Dict(:onclick=>@event displaying() => name), name)
      return tab(name) => node
    end

    @create begin
      displaying() => name
      columns = world[Symbol(name)].columns
      c in 1:length(columns)
      column = columns[c]
      r in 1:length(column)
      value = column[r]
      style = "height: 2em; flex: $(100/length(columns))%"
      cell = Hiccup.div(Dict(:style=>style), render_value(value))
      return cell(c, r) => cell
    end

    @merge begin
      displaying() => name
      columns = world[Symbol(name)].columns
      c in 1:length(columns)
      column = columns[c]
      typ = eltype(column)
      style = "border-bottom: 1px solid #aaa; height: 2em; flex: $(100/length(columns))%"
      node = Hiccup.div(Dict(:style=>style), string(typ))
      return cell(c, 0) => node
    end

    @create begin
      cell(_, r) => _
      @query cell(c, r) => cell_node
      row = hbox(cell_node)
      return row(r) => row
    end

    @create begin
      @query tab(name) => tab_node
      tabs = hbox(tab_node)
      @query row(r) => row_node
      rows = vbox(row_node)
      window = vbox([tabs, rows])
      return window() => window
    end
  ]))
end

window(world)
```

Live updating works nicely.

It's missing row editing, but that didn't really work properly in the previous version anyway. Next thing I need to do is figure out how to handle how to deal with user input correctly.

### 2016 Dec 17

I have incremental dom patching sort-of working. The actual dom patching works, but somehow messages back to Julia are getting lost, and anything that waits on a message gets stuck eg `@js w console.log("ok")` hangs in a lock:

``` julia
InterruptException:
 in process_events(::Bool) at ./libuv.jl:82
 in wait() at ./event.jl:147
 in wait(::Condition) at ./event.jl:27
 in lock(::ReentrantLock) at ./lock.jl:74
 in (::Atom.##65#68)(::Dict{String,Any}) at /home/jamie/.julia/v0.5/Atom/src/eval.jl:107
 in handlemsg(::Dict{String,Any}, ::Dict{String,Any}, ::Vararg{Dict{String,Any},N}) at /home/jamie/.julia/v0.5/Atom/src/comm.jl:163
 in (::Atom.##14#17)() at ./event.jl:68
```

Annoyingly, the network tab in electron shell doesn't seem to be able to see the websocket. I can verify in wireshark that the message is sent to the server. The event handler doesn't get called. And... that's about it. What now?

Somehow I managed to figure out that the culprit was that `@js(window, morphdom(document.getElementById("main"), $html))` never returns. I don't know why. If I change it to an async call `@js_(window, morphdom(document.getElementById("main"), $html))` everything works fine. That sounds like a bug in Blink. I don't really want to dive into the networking code though, so I'm just gonna leave it and hope it doesn't happen again. That'll probably work...

### 2016 Dec 18

I found a problem with my approach to handling state. I wanted to have mutations occur only in event handlers, but the event handlers produce json and I need arbitrary Julia values. I could probably fix that by putting julia code strings in the event handler and evalling it on the server. Or I could just generate some unique id and store the events client-side. That seems more sensible. But then how do I get values out of eg textboxes?

The core problem here is the asynchrony between server and the client. The client knows what the current value of the textbox is. The server knows how to interpret the value. If other mutations have happened in the meantime, the server may have forgotten what the client is currently seeing, and might wrongly interpret the event (this is the problem with naive applications of CQRS where the events are things like "user 7 clicked on button 42").

I think it's clear that any model that allows mutation at all is still going to be subject to subtle asynchrony bugs, but I want to continue to allow it for now so that I don't have to figure out how to deal with time yet.

Maybe a better option would be to remove the asynchrony by using a native gui framework. It would be far easier to write this query if I could just access the value of the textbox in the query.

Maybe I should try to write a blog post on the problem to clear up my thinking.

### 2016 Dec 21

So I just gave up and introduced arbitrary state. I don't like it, but I don't see a way around it right now. Maybe I'll end up with something like Elm where the view and update functions are separated.

I moved all the query code into the `@merge` macro, which works like before, and created `@state` and `@fresh` macros for creating stateful and stateless tables. (`@fresh` is a shitty name but `@view` is already taken in Julia. Maybe `@stateful` and `@transient`?)

With those I now have pretty decent editing working, but I'm having to splice in javascript to get the most recent state out of the textbox.

``` julia
@merge begin
  displaying() => name
  editing() => (name, c, r, value)
  columns = world[Symbol(name)].columns
  style = "height: 2em; flex: $(100/length(columns))%"
  onkeydown = """
    if (event.which == 13) {
      Blink.msg('event', {'table': 'editing', 'values': ['$name', $c, $r, this.value]});
      Blink.msg('event', {'table': 'committed', 'values': [true]});
      return false;
    }
    if (event.which == 27) {
      Blink.msg('event', {'table': 'editing', 'values': ['', 0, 0, '']});
      return false;
    }
  """
  cell = textarea(Dict(:style=>style, :rows=>1, :onkeydown=>onkeydown), value)
  return cell(c, r) => cell
end
```

There's a similar problem in the other direction where if anything causes the flow to refresh, the textbox gets reset.

Both problems are caused by the fact that I don't have synchronous access to the dom, so the model and the view can get out of sync. I could get synchronous access either by porting Imp to js or by using a native toolkit. Or I could figure out a way to deal with asynchronous access.

### 2016 Dec 26

The UI-as-a-value-embedded-in-the-debugger thing I was pushing for was interesting but a) it caused major problems with not having a vdom <-> dom bijection and b) when pressed I couldn't come up with any actual usecases that weren't just buttons. So let's scrap it and go with the flat relational representation that we used in Eve since way back in early 2014.

Every DOM node gets a unique id:

``` julia
# typealias Id UInt

# macro id(args...)
#   h = :(zero(UInt))
#   for arg in args
#     h = :(hash($(esc(arg)), $h))
#   end
#   h
# end

# root = UInt(0)

typealias Id String

macro id(args...)
  :(join([$(map(esc,args)...)], "-"))
end

root = "root"
```

I haven't implemented multiple returns yet so I'll just mush everything important into one table:

``` julia
# (id) => (parent, ix, kind, class, text)
pre = @transient node(Id) => (Id, Int64, String, String, String)
```

The main program fills lots of stuff into that table, and then the UI lib sorts it by depth and sends it to the frontend:

``` julia
post = Sequence([
  # (level, parent, ix, id, kind, class, text)
  @transient sorted_node(Int64, Id, Int64, Id, String, String, String)

  @merge begin
    root = UI.root
    node(id) => (root, ix, kind, class, text)
    return sorted_node(1, root, ix, id, kind, class, text)
  end

  Fixpoint(
    @merge begin
      sorted_node(level, _, _, parent, _, _, _)
      node(id) => (parent, ix, kind, class, text)
      return sorted_node(level+1, parent, ix, id, kind, class, text)
    end
  )
])

function render(window, state)
  (_, id, parent, ix, kind, class, text) = state[:sorted_node].columns
  @js(window, render($id, $parent, $ix, $kind, $class, $text))
end
```

Then the frontend erases the old DOM and builds a new one from scratch:

``` js
function render(parent, ix, id, kind, className, textContent) {
    document.getElementById("root").innerHTML = "";
    for (var i = 0; i < parent.length; i++) {
        node = document.createElement(kind[i]);
        node.id = id[i];
        node.className = className[i];
        node.textContent = textContent[i];
        document.getElementById(parent[i]).appendChild(node);
    }
}
```

The next thing I have to do is make this incremental. It's not too hard - just diff the new sorted_nodes table against the old and then do deletions before insertions.

I've ported the readonly parts of the table interface to this model:

``` julia
@merge begin
  root = UI.root
  return node(@id(:top)) => (root, 1, "div", "vbox", "")
end

@merge begin
  return node(@id(:tabs)) => (@id(:top), 1, "div", "hbox", "")
end

@merge begin
  ix_name in enumerate(keys(world.state))
  ix = ix_name[1]
  name = ix_name[2]
  return node(@id(:tabs, ix)) => (@id(:tabs), ix, "button", "", string(name))
end

@merge begin
  return node(@id(:cells)) => (@id(:top), 2, "div", "vbox", "")
end

@merge begin
  displaying() => name
  columns = world[Symbol(name)].columns
  r in 0:length(columns[1])
  return node(@id(:cells, r)) => (@id(:cells), r, "div", "hbox", "")
end

@merge begin
  displaying() => name
  columns = world[Symbol(name)].columns
  c in 1:length(columns)
  column = columns[c]
  r in 1:length(column)
  value = column[r]
  # style = "height: 2em; flex: $(100/length(columns))%"
  # onclick = (c > world[Symbol(name)].num_keys) ? @event(editing() => (name, c, r, string(value))) : ""
  return node(@id(:cells, r, c)) => (@id(:cells, r), c, "div", "flex1", string(value))
end

@merge begin
  displaying() => name
  editing() => (name, c, r, value)
  columns = world[Symbol(name)].columns
  # style = "height: 2em; flex: $(100/length(columns))%"
  # onkeydown = """
  #   if (event.which == 13) {
  #     Blink.msg('event', {'table': 'editing', 'values': ['$name', $c, $r, this.value]});
  #     Blink.msg('event', {'table': 'committed', 'values': [true]});
  #     return false;
  #   }
  #   if (event.which == 27) {
  #     Blink.msg('event', {'table': 'editing', 'values': ['', 0, 0, '']});
  #     return false;
  #   }
  # """
  # cell = textarea(Dict(:style=>style, :rows=>1, :onkeydown=>onkeydown), value)
  return node(@id(:cells, r, c)) => (@id(:cells, r), c, "textarea", "flex1", string(value))
end

@merge begin
  displaying() => name
  columns = world[Symbol(name)].columns
  c in 1:length(columns)
  column = columns[c]
  typ = eltype(column)
  # weight = (c > world[Symbol(name)].num_keys) ? "normal" : "bold"
  # style = "border-bottom: 1px solid #aaa; height: 2em; font-weight: $weight; flex: $(100/length(columns))%"
  # node = Hiccup.div(Dict(:style=>style), string(typ))
  return node(@id(:cells, 0, c)) => (@id(:cells, 0), c, "div", "flex1", string(typ))
end
```

I haven't hooked up events yet so that's all commented out for now. I'll need to create some way of unpacking ids to get the useful data back out.

### 2016 Dec 27

DOM patching seems to be working. The implementation is pretty simple. The server does a little more work than before to compute diffs between old and new node tables:

``` julia
post = Sequence([
  # (level, parent, ix, id, kind, class, text)
  @transient sorted_node(Int64, Id, Int64, Id, String)

  @merge begin
    root = UI.root
    node(id) => (root, ix, kind, _, _)
    return sorted_node(1, root, ix, id, kind)
  end

  Fixpoint(
    @merge begin
      sorted_node(level, _, _, parent, _,)
      node(id) => (parent, ix, kind, _, _)
      return sorted_node(level+1, parent, ix, id, kind)
    end
  )

  @transient class(Id, String)

  @merge begin
    node(id) => (_, _, _, class, _)
    return class(id, class)
  end

  @transient text(Id, String)

  @merge begin
    node(id) => (_, _, _, _, text)
    return text(id, text)
  end
])

function render(window, old_state, new_state)
  (removed, inserted) = Data.diff(old_state[:sorted_node], new_state[:sorted_node])
  (_, _, _, removed_id, _) = removed
  (_, parent, ix, id, kind) = inserted
  (_, (class_id, class)) = Data.diff(old_state[:class], new_state[:class])
  (_, (text_id, text)) = Data.diff(old_state[:text], new_state[:text])
  @js(window, render($removed_id, $parent, $ix, $id, $kind, $class_id, $class, $text_id, $text))
end

function render(window, state)
  (_, parent, ix, id, kind) = state[:sorted_node].columns
  (class_id, class) = state[:class].columns
  (text_id, text) = state[:text].columns
  @js(window, render($([]), $parent, $ix, $id, $kind, $class_id, $class, $text_id, $text))
end
```

Then the client just rolls through and applies the diffs:

``` js
function render(removed, parent, ix, id, kind, classNameId, className, textContentId, textContent) {
    trash = document.createElement(kind[i]);
    document.getElementById("root").appendChild(trash);

    for (var i = removed.length - 1; i >= 0; i--) {
        node = document.getElementById(removed[i]);
        trash.appendChild(node);
    }

    for (var i = 0; i < parent.length; i++) {
        node = document.getElementById(id[i]);
        if (node == null) {
            node = document.createElement(kind[i]);
        } else if (node.tagName != kind[i].toUpperCase()) {
            oldNode = node
            node = document.createElement(kind[i]);
            while (oldNode.hasChildNodes()) {
                node.appendChild(oldNode.firstChild);
            }
        }
        node.id = id[i];
        parentNode = document.getElementById(parent[i])
        parentNode.insertBefore(node, parentNode.children[ix[i]]);
    }

    for (var i = 0; i < classNameId.length; i++) {
        node = document.getElementById(classNameId[i]);
        node.className = className[i];
    }

    for (var i = 0; i < textContentId.length; i++) {
        node = document.getElementById(textContentId[i]);
        if (node.children.length == 0) {
            node.textContent = textContent[i];
        }
    }

    trash.remove();
}
```

I make a trash node so that I don't have to distinguish between nodes being removed and nodes being moved - anything that changes at all gets put in the trash where it can be found by the insert loop later.

I can't figure out how to do event handlers nicely without multiple returns, so I implemented that first. A bunch of mindless edits to the compiler later, I can write things like:

``` julia
@merge begin
  displaying() => name
  columns = world[Symbol(name)].columns
  c in 1:length(columns)
  column = columns[c]
  r in 1:length(column)
  value = column[r]
  # style = "height: 2em; flex: $(100/length(columns))%"
  # onclick = (c > world[Symbol(name)].num_keys) ? @event(editing() => (name, c, r, string(value))) : ""
  return node(@id(:cells, r, c)) => (@id(:cells, r), c, "div")
  return class(@id(:cells, r, c)) => "flex1"
  return text(@id(:cells, r, c)) => string(value)
end
```

I'm again running into problems with Blink getting blocked on a non-empty queue. Plagued me for half an hour and then went away again. Going to be tricky to fix if I can't reliably repro.

Got some basic event handlers up, but I'm running into the same old async problem. Eg if I get a click event for "tabs-1", how do I know if it means the current "tabs-1" or one from a previous frame. If I'm not going to switch to a synchronous UI framework then I have to make the events carry semantically meaningful data, which means passing more data back and forth over the wire.

For the moment I'm just ignoring that problem, and I've got the whole table interface otherwise working again.

Blink is blocking again! Why? Damned Heisenbug!

I've also added some watchers for the non-Julia files so that I can iterate quickly. It's the first time I've directly interacted with Julias concurrency primitives. It was pleasantly straightforward.

``` julia
function watch_and_load(window, file)
  load!(window, file)
  @schedule begin
    (waits, _) = open(`inotifywait -m $file`)
    while true
      readline(waits)
      load!(window, file)
    end
  end
end

function window(world)
  window = Window()
  opentools(window)
  watch_and_load(window, "src/Imp.js")
  watch_and_load(window, "src/Imp.css")
  ...
end
```

Had to fix a bug in the relation diff.

Also fixed a couple of missed cases in the client render function:

``` js
    for (var i = 0; i < parent.length; i++) {
        node = document.getElementById(id[i]);
        if (node == null) {
            node = document.createElement(tagName[i]);
        } else if (node.tagName != tagName[i].toUpperCase()) {
            oldNode = node
            node = document.createElement(tagName[i]);
            node.className = oldNode.className;
            while (oldNode.hasChildNodes()) {
                node.appendChild(oldNode.firstChild);
            }
            node.onclick = oldNode.onclick;
            node.onkeydown = oldNode.onkeydown;
        }
        node.id = id[i];
        parentNode = document.getElementById(parent[i])
        parentNode.insertBefore(node, parentNode.children[ix[i]-1]);
    }
```

I got fed up of editing css so I added support for in-place styles like:

``` julia
@merge begin
  displaying() => name
  columns = world[Symbol(name)].columns
  c in 1:length(columns)
  column = columns[c]
  r in 1:length(column)
  value = column[r]
  return node(@id(:cells, r, c)) => (@id(:cells, r), c, "div")
  return style(@id(:cells, r, c), "flex") => "1"
  return style(@id(:cells, r, c), "height") => "1.5em"
  return style(@id(:cells, r, c), "margin-left") => "0.5em"
  return style(@id(:cells, r, c), "margin-right") => "0.5em"
  return text(@id(:cells, r, c)) => string(value)
  return cell(@id(:cells, r, c)) => (r, c, string(value))
  return onclick(@id(:cells, r, c))
end
```

The rendering breaks in hard to reproduce ways, and it took me a while to figure out why. `node.style = oldNode.style` silently doesn't work. It just erases the style of node. The correct incantation is `node.style = oldNode.style.cssText`.

### 2016 Dec 28

I ported the minesweeper example to the new flow/UI system. It's noticably faster - building the hiccup.jl vdom was the majority of the runtime in the previous version, which is daft.

I also hooked in the table browser so I can poke about inside the minesweeper state.

### 2017 Apr 6

(Been a while. Was working on a parallel project. Details later.)

Having to create ids for every dom node sucks. It's boilerplate.

Also don't like that because I don't have a way to nest queries, I can't directly represent the nested structure of the dom and instead have to break it up into multiple queries.

Could solve the last problem by introducing nested queries to Imp, and I still want to do something like that at some point to solve the context problem, but for now I can solve both by introducing html templates.

``` julia
[div
  login(session) do
    [input "type"="text" "placeholder"="What should we call you?"]
  end

  chat(session) do
    [div
      message(message, text, time) do
        [div
          [span "class"="message-time" time]
          [span "class"="message-text" text]
        ]
      end
    ]
    [input "type"="text" "placeholder"="What do you want to say?"]
  end
]
```

Anything that looks like a datalog clause eg `login(session)` repeats the template inside it for every row, sorted in the order that the variables appear. Nested clauses implicitly join against all their ancestors, uh, which makes this a bad example because there are no joins. Later...

In my other project these get compiled into a bunch of datalog views that generate a relational dom model much like the one I used in imp, but once I had it working I realized that now I have templates it would be much simpler to just read data out of the relations and interpret the templates directly, rather than doing all the fiddly codegen.

``` julia
# dumb slow version just to get the logic right
# TODO not that

function interpret_value(value, bound_vars)
  string(isa(value, Symbol) ? bound_vars[value] : value)
end

function interpret_node(node::TextNode, bound_vars, data)
  return [interpret_value(node.text, bound_vars)]
end

function interpret_node(node::FixedNode, bound_vars, data)
  attributes = Dict{String, String}()
  for attribute in node.attributes
    attributes[interpret_value(attribute.key, bound_vars)] = interpret_value(attribute.val, bound_vars)
  end
  nodes = vcat([interpret_node(child, bound_vars, data) for child in node.children]...)
  return [Hiccup.Node(node.tag, attributes, nodes)]
end

function interpret_node(node::QueryNode, bound_vars, data)
  nodes = []
  columns = data[node.table].columns
  @assert length(node.vars) == length(columns)
  for r in 1:length(columns[1])
    if all((!(var.name in keys(bound_vars)) || (bound_vars[var.name] == columns[c][r]) for (c, var) in enumerate(node.vars)))
      new_bound_vars = copy(bound_vars)
      for (c, var) in enumerate(node.vars)
        new_bound_vars[var.name] = columns[c][r]
      end
      for child in node.children
        push!(nodes, interpret_node(child, new_bound_vars, data)...)
      end
    end
  end
  return nodes
end
```

Doing the diffing should be fairly easy if I track which dom nodes correspond to which query node + bound_vars. This is kinda similar to how Om has a much easier time diffing immutable data compared to React which needs programmer help. But even better, because we get automatic list keys too.

I think the next thing is to get events hooked up.

The tricky part about events is that they often need to grab values from the dom or the event, or run some js code before sending the event to the server. But they also need to grab values from the server. If I only cared about the latter I could do something like `"onclick" = add_message(next_id, "foo")`. If I only cared about the former I could do soemthing like `"onclick" = "imp.send_event('add_message', [1, this.value])"`. But if I need both? I could add js values to the first like `"onclick" = add_message(next_id, js"this.value")` but that still doesn't allow making decisions on the client side. I could attach the query values to the dom node itself, so the event would be `"onclick" = "imp.send_event('add_message', [this.data.next_id, this.value])"`, but that gets pretty verbose. I could splice server-side values into the js like `"onclick" = "imp.send_event('add_message', [$next_id, this.value])"` but that would create a different function for each dom node, and each function needs to be parsed, compiled and stored. I also don't like the lack of symmetry between query and event syntax.

How expensive are js functions? Every source I can find so far only seems to look at closures, where there is one version of the source code and multiple instantiations. If attaching the functions happens on the client I could maybe create a factory function for each event binding in the template.

```js
factory = function(next_id) {
  function (event) {
    imp.send_event('add_message', [next_id, this.value])
  }
}

node.onclick = factory(5).bind(node)
```

(That's probably wrong because js is crazy, but the idea is there.)

Or I could keep server-side data on the server and just send over some id that identifies the row. That would avoid problems with round-tripping interesting types through js, but it introduces concurrency problems where the client might send the id of a node that no longer exists on the server. Not sure which one is going to be messier.

Is there some 80% solution? Let's look at the most common use-cases:

1. Pressing a button to delete a todo.
2. Submitting the contents of a text box on pressing enter.
3. Submitting and clearing the contents of a text box on pressing enter.

1 doesn't require anything interesting to happen on the client. 2 will spam the server with data if we create an event on every button press, so we really want the client to look at the keypress first. 3 has to both submit a server event and call a js function, which ideally we would like to do without an extra roundtrip.

Splicing stuff into js functions seems like the only thing that will handle all three nicely. We just need to make the syntax cleaner and the avoid the cost of creating many similar functions.

If we tag specific relations as events then we can create js functions for them and write `"onclick" = "add_message($next_id, this.value)"`.

Avoiding many similar functions seems to *have* a feasible solution, which means I can put it off doing it until it actually becomes a problem.

Julia parses `"add_message($next_id, this.value)"` as `Expr(:string, "add_message(", :next_id, ", this.value)")` so it will be easy detect in the template parser.

I added support for string interpolation everywhere the template accepts string, so now this a valid template:

``` julia
[div
  login(session) do
    [input "type"="text" "placeholder"="What should we call you?"]
  end

  chat(session) do
    [div
      message(message, text, time) do
        [div
          [span "class"="message-time" "time: $time"]
          [span "class"="message-text" text]
        ]
      end
    ]
    next_message(id) do
      [input
        "type"="text"
        "placeholder"="What do you want to say?"
        "onkeydown"="if (event.keypress == 13) {new_message($id, this.value)}"
        ]
    end
  end
]
```

But now that I look at it I realize that with my intended diff semantics, this will replace the input node every time the next message id changes. Which would be fine except that that also wipes the contents of the input. It's the same problem for all the approaches I came up with above - the core problem is that we can't change attributes without replacing the node. Maybe I need to be able to move the query inside the node?

``` julia
[input
  "type"="text"
  "placeholder"="What do you want to say?"
  next_message(id) do "onkeydown"="if (event.keypress == 13) {new_message($id, this.value)}" end
]
```

I'd have to change the syntax and the interpeter, and it will make diffs a bit more complicated, but it should work.

It would also incidentally add the ability to do stuff like:

``` julia
[button
  style("funky", k, v) do k=v end
  "bring the funk"
]
```

Which is not super important, but it was the one thing that the current ui system can do that the templates can't.

Oh, I guess tags too. Let's make tags interpolatable.

``` julia
["div"
  login(session) do
    ["input" "type"="text" "placeholder"="What should we call you?"]
  end

  chat(session) do
    ["div"
      message(message, text, time) do
        ["div"
          ["span" "class"="message-time" "time: $time"]
          ["span" "class"="message-text" text]
        ]
      end
    ]
    next_message(id) do
      ["input"
        "type"="text"
        "placeholder"="What do you want to say?"
        "onkeydown"="if (event.keypress == 13) {new_message($id, this.value)}"
        ]
    end
  end
]
```

A little gross. An actual html parser would be better, but I don't have time to write one and I can't figure out a good way to reuse one while keeping the queries and template together.

Still don't like the asymmetry between queries and events either.

:S

### 2017 Apr 7

Parsing and interpreter needed a bit of tweaking to handle attributes inside queries. Treat them as nodes in their own right now rather than as a field of FixedNode. Get pushed into their parent node.

Decided to require string escaping rather than allowing raw symbols. Makes less typing in the template, makes it really clear when values are moving from the server to the client and makes it clear that values will be converted to strings.

``` julia
[div
  login(session) do
    [input placeholder="What should we call you?"]
  end

  chat(session) do
    [div
      message(message, text, time) do
        [div
          [span class="message-time" "time: $time"]
          [span class="message-text" "$text"]
        ]
      end
    ]
    [input
     placeholder="What do you want to say?"
     next_message(id) do
       onkeydown="if (event.keypress == 13) {new_message($id, this.value)}"
     end
     ]
  end
]
```

I feel much better about this. Glad I slept on it.

Let's hook it up.

Wrap the templates in a mutable thing to enable live-coding:

``` julia
type View
  template::Any
  parsed_template::Node
  watchers::Set{Any}
end

function View()
  template = quote [div] end
  View(template, parse_template(template), Set{Any}())
end

function set_template!(view::View, template)
  view.template = template
  view.parsed_template = parse_template(template)
  for watcher in view.watchers
    watcher()
  end
end

function Flows.watch(watcher, view::View)
  push!(view.watchers, watcher)
end
```

Render the whole template each time and use [diffhtml](https://diffhtml.org/) to patch the dom.

``` julia
function render(window, view, state)
  root = Hiccup.Node(:div)
  interpret_node(root, view.parsed_template, Dict{Symbol, Any}(:session => "my session"), state)
  @js(window, diff.innerHTML(document.body, $(string(root))))
end

function watch_and_load(window, file)
  load!(window, file)
  @schedule begin
    (waits, _) = open(`inotifywait -me CLOSE_WRITE $file`)
    while true
      readline(waits)
      load!(window, file)
    end
  end
end

function window(world, view)
  window = Window()
  opentools(window)
  load!(window, "src/diffhtml.js")
  # watch_and_load(window, "src/Imp.css")
  # watch_and_load(window, "src/Imp.js")
  sleep(3) # :(
  handle(window, "event") do event
    refresh(world, Symbol(event["table"]), tuple(event["values"]...))
  end
  watch(world) do old_state, new_state
    render(window, view, new_state)
  end
  watch(view) do
    render(window, view, world.state)
  end
  @js(window, document.body.innerHTML = $(string(Hiccup.Node(:div))))
  render(window, view, world.state)
  window
end
```

I checked that changing `next_message` updates the event listener without blowing away the input box.

Next thing is getting events hooked up, and then handling sessions properly.

Client-side we have:

``` js
function imp_event(table) {
    return function () {
        Blink.msg("event", {"table": table, "values": Array.from(arguments)});
        return false;
    }
}
```

Flows get extended with a new kind of relation, which is exactly like a transient except that it can be inserted into from the client:

``` julia
macro event(relation)
  (name, keys, vals) = parse_relation(relation)
  :(Create($(Expr(:quote, name)), [$(map(esc, keys)...)], [$(map(esc, vals)...)], true, true))
end
```

In render we create new event functions for every event:

``` julia
function render(window, view, world)
  for event in world.events
    js(window, Blink.JSString("$event = imp_event(\"$event\")"), callback=false)
  end
  ...
end
```

I repeatedly ran into the same old hangs with Blink. I'll try upgrading to the latest version and see if they continue to plague me.

Here is the chat with working events:

``` julia
world = World()
view = View()

world[:chat] = Relation((["my session"],), 1)

begin
  set_flow!(world, Sequence([
    @stateful login(String)
    @stateful chat(String)
    @stateful message(Int64) => (String, DateTime)
    @event new_message(String)

    @merge begin
      new_message(text)
      @query begin
        message(id) => (_, _)
      end
      return message(1 + length(id)) => (text, now())
    end
  ]))
  set_template!(view, quote
    [div
      login(session) do
        [input placeholder="What should we call you?"]
      end

      chat(session) do
        [div
          message(message, text, time) do
            [div
              [span class="message-time" "time: $time"]
              [span class="message-text" "$text"]
            ]
          end
        ]
        [input
          placeholder="What do you want to say?"
          onkeydown="if (event.which == 13) {new_message(this.value); this.value=''}"
        ]
      end
    ]
  end)
end

w = window(world, view)
```

So I need to deal with sessions and then add some css and we're done.

The window setup generates a 'unique' session id and stores it in a relation:

``` julia
function window(world, view)
  window = Window()
  session = string(now()) # TODO uuid
  ...
  refresh(world, :session, tuple(session))
  window
end
```

It also gets passed to every render call where it becomes an in-scope variable for the template:

``` julia
function render(window, view, world, session)
  ...
  interpret_node(root, view.parsed_template, Dict{Symbol, Any}(:session => session), world.state)
  ...
end
```

With sessions we can now handle logging in:

``` julia
set_flow!(world, Sequence([
  UI.pre

  @stateful username(String) => String
  @stateful message(Int64) => (String, String, DateTime)

  @transient not_logged_in(String)

  @event new_login() => (String, String)
  @event new_message() => (String, String)

  @merge begin
    new_login() => (session, username)
    return username(session) => username
  end

  @merge begin
    new_message() => (session, text)
    @query begin
      message(id) => (_, _)
    end
    return message(1 + length(id)) => (session, text, now())
  end

  @merge begin
    session(session)
    @query username(session) => un # TODO hygiene bug :(
    @when length(un) == 0
    return not_logged_in(session)
  end
]))
set_template!(view, quote
  [div
    not_logged_in(session) do
      [input
        placeholder="What should we call you?"
        onkeydown="if (event.which == 13) {new_login('$session', this.value)}"
        ]
    end

    username(session, _) do
      [div
        [span "$username"]
        message(message, message_session, text, time) do
          [div
            username(message_session, message_username) do
              [span class="message-username" "$message_username"]
            end
            [span class="message-time" "time: $time"]
            [span class="message-text" "$text"]
          ]
        end
      ]
      [input
        placeholder="What do you want to say?"
        onkeydown="if (event.which == 13) {new_message('$session', this.value); this.value=''}"
      ]
    end
  ]
end)
```

Uh, I realized that I'm handling string slicing poorly. I want `repr` in events but `string` inside attributes and text. That's why the session in the events is in single quotes. I can work around it for now, but need to think about it more carefully later.

Also I ran into a scoping/hygiene bug in subqueries that I had forgotten about. And I also forget that I don't have working negation anymore. The todo list grows faster and faster.

I can add css by just creating css nodes in the head and the diffing works fine. Styling inline works with existing attributes too.

``` julia
set_head!(view, quote
  [style
    "type"="text/css"
    """
    .vbox {
      display: flex;
      flex-direction: column;
    }

    .vbox * {
      flex: 1 1 auto;
    }

    .hbox {
      display: flex;
      flex-direction: row;
    }

    .hbox * {
      flex: 1 1 auto;
    }
    """]
end)
set_body!(view, quote
  [div
    not_logged_in(session) do
      [div
        class="hbox"
        [input
          style="margin: 50vh 30vw;"
          placeholder="What should we call you?"
          onkeydown="if (event.which == 13) {new_login('$session', this.value)}"
        ]
      ]
    end

    username(session, username) do
      [div
        class="vbox"
        style="height: 80vh; width: 80vw; margin: 10vh 10vw;"
        [div
          style="height: 100%; overflow: scroll;"
          [table
            style="width: 100%;"
            message(message, message_session, text, time) do
              [tr
                username(message_session, message_username) do
                  [td style="font-weight: bold" "$message_username:"]
                end
                [td style="width: 100%" "$text"]
                [td "$time"]
              ]
            end
          ]
        ]
        [input
          style="width: 100%; height: 2em"
          placeholder="What do you want to say?"
          onkeydown="if (event.which == 13) {new_message('$session', this.value); this.value=''}"
        ]
      ]
    end
  ]
end)
```

A nice touch for complex styles would be to concatenate multiple attributes.

``` julia
function interpret_node(parent, node::AttributeNode, bound_vars, state)
  key = interpret_value(node.key, bound_vars)
  val = interpret_value(node.val, bound_vars)
  parent.attrs[key] = string(get(parent.attrs, key, ""), val)
end
```

So everything is pretty now. What next?

Would be nice to scrollIntoView on new elements. Can we fit that into the existing event system?

Not without the cooperation of the dom patching. At some point I'll have to replace diffhtml with my own thing, and when I do that I can implement synthetic events like onmount.

Not sure what to do next. Ideas:

* Port over the other examples
* Get Blink attaching to a real browser rather than electron
* Write the diff algorithm

### 2017 Apr 13

Today I'm trying to write a simple betting exchange in each of Imp, Eve and Logicblox. Each one gets two hours.

The Imp version just barely works and exposed a bunch of bugs. I definitely need to rethink the syntax and the flow system.

``` julia
set_flow!(world, Sequence([
  UI.pre

  @stateful order(id::Order) => (time::DateTime, price::Dec64, quantity::Int64, side::Side)
  @stateful matched(buy::Order, sell::Order) => (price::Dec64, quantity::Int64)

  @event new_order(price::String, quantity::String, side::String)

  @merge begin
    new_order(price_string, quantity_string, side_string)
    time = now()
    price = parse(Dec64, price_string)
    quantity = parse(Int64, quantity_string)
    side = @match side_string begin
      "buy" => Buy
      "sell" => Sell
    end
    @query order(id) => (_,_,_,_)
    return order(1+length(id)) => (time, price, quantity, side)
  end

  @transient remaining(side::Side, price::Dec64, time::DateTime, id::Order) => quantity::Int64

  Fixpoint(Sequence([
    @clear remaining

    @merge begin
      order(order) => (time, price, quantity, side)
      @query matched(order, matched_buy) => (_, bought_quantity)
      @query matched(matched_sell, order) => (_, sold_quantity)
      remaining = quantity - reduce(+, 0, bought_quantity) - reduce(+, 0, sold_quantity)
      @when remaining > 0
      return remaining(side, price, time, order) => remaining
    end

    @merge begin
      @query remaining(Buy, buy_price, buy_time, buy_order) => buy_quantity
      @query remaining(Sell, sell_price, sell_time, sell_order) => sell_quantity
      @when length(buy_order) > 0
      @when length(sell_order) > 0
      b = length(buy_order) # max
      s = 1 # min
      @when buy_price[b] >= sell_price[s]
      price = (buy_time[b] < sell_time[s]) ? buy_price[b] : sell_price[s]
      quantity = min(buy_quantity[b], sell_quantity[s])
      return matched(buy_order[b], sell_order[s]) => (price, quantity)
    end
  ]))

  @transient to_buy(price::Dec64) => (printed_price::String, quantity::Int64)

  @merge begin
    remaining(Buy, price, _, _) => _
    @query remaining(Buy, price, time, order) => quantity
    printed_price = @sprintf("%.4f", Float64(Dec64(price)))
    return to_buy(price) => (printed_price, sum(quantity))
  end

  @transient to_sell(neg_price::Dec64) => (printed_price::String, quantity::Int64)

  @merge begin
    remaining(Sell, price, _, _) => _
    @query remaining(Sell, price, time, order) => quantity
    printed_price = @sprintf("%.4f", Float64(Dec64(price)))
    return to_sell(-price) => (printed_price, sum(quantity))
  end
]))

set_body!(view, quote
  [div
    [table
      to_buy(_, price, quantity) do
        [tr [td "$price"] [td "$quantity"]]
      end
      [tr
        [td [input placeholder="price"]]
        [td [input placeholder="quantity"]]
        onkeydown="if (event.which == 13) {new_order(this.children[0].children[0].value, this.children[1].children[0].value, 'buy')}"
      ]
      [tr
        [td [input placeholder="price"]]
        [td [input placeholder="quantity"]]
        onkeydown="if (event.which == 13) {new_order(this.children[0].children[0].value, this.children[1].children[0].value, 'sell')}"
      ]
      to_sell(_, price, quantity) do
        [tr [td "$price"] [td "$quantity"]]
      end
    ]
  ]
end)
```

### 2017 Jun 12

I missed a couple of entries, but nothing major.

I put a couple of hundred todos in the Imp todomvc. Running all the logic takes ~1ms. Generating the UI takes ~200ms. Diffing the UI takes < 1ms. So I need to fix the generating step.

It's a really dumb looping interpreter.

``` julia
function interpret_node(parent, node::QueryNode, bound_vars, state)
  columns = state[node.table].columns
  @assert length(node.vars) == length(columns)
  for r in 1:length(columns[1])
    if all((!(var in keys(bound_vars)) || (bound_vars[var] == columns[c][r]) for (c, var) in enumerate(node.vars)))
      new_bound_vars = copy(bound_vars)
      for (c, var) in enumerate(node.vars)
        new_bound_vars[var] = columns[c][r]
      end
      for child in node.children
        interpret_node(parent, child, new_bound_vars, state)
      end
    end
  end
end
```

Let's think about how this ought to work. The end result is really just a tree of query nodes - all the other node types become fixed html strings that depend only on their parent query node. (Ignore attributes for now). Query nodes don't really change - we only ever need to insert or delete them. We can generate a unique id for each instantiated query node by hashing it's name and variable values.

Let's say we generate a bunch of views that do the joins and generate ids and html strings. Every time a node disappears from one of these views we delete the corresponding node in the dom. Every time a node appears, we insert it's string in the correct place in the dom. What is the correct place? We can include parent ids in the view. The path from parent to children is fixed. The only thing we need to figure out is the position in the list of children. If we look at the previous row in the view, it will either have the same parent, in which case it is our previous sibling, or a different parent, in which case we are the first child of our parent. If we process the changes top-down in the tree and first to last in each view, this should give us the correct insertion order.

Let's gather up all the query nodes:

``` julia
function collect_query_nodes(node, query_nodes)
  if typeof(node) == QueryNode
    push!(query_nodes, node)
  end
  if typeof(node) in [QueryNode, FixedNode]
    for child in node.children
      collect_query_nodes(child, query_nodes)
    end
  end
end
```

And for this plan to work, I guess we need to implicitly wrap the template in a `session(session)` query node.

``` julia
function compile_node(node)
  wrapper = QueryNode(:session, [:session], [node])
  query_nodes = []
  collect_query_nodes(wrapper, query_nodes)
  @show query_nodes
end
```

And then for each query node we need an id and a parent id.

``` julia
type CompiledQueryNode
  id::Symbol
  parent_id::Symbol
  query_node::QueryNode
end

function compile_query_nodes(parent_id, node, compiled_query_nodes)
  if typeof(node) == QueryNode
    id = Symbol("query_node_", hash((parent_id, node)))
    compiled_query_node = CompiledQueryNode(id, parent_id, node)
    push!(compiled_query_nodes, compiled_query_node)
    for child in node.children
      compile_query_nodes(id, child, compiled_query_nodes)
    end
  end
  if typeof(node) == FixedNode
    for child in node.children
      compile_query_nodes(parent_id, child, compiled_query_nodes)
    end
  end
end
```

And a function that takes bound vars and returns a html fragment.

Ah, hang on, positioning doesn't work right with nested query nodes. Hmmm.... think about that later.

The fragment function needs to take a chunk of template like:

``` julia
[li
  [div
    class="view"
    [input
      class="toggle"
      "type"="checkbox"
      checked(todo) do
        checked="true"
      end
      onclick="toggle($todo)"
    ]
    [label "$text" ondblclick="start_editing('$session', $todo)"]
    [button class="destroy" onclick="delete_todo($todo)"]
  ]
]
```

And return a chunk of html generating code like:

``` julia
"""
<li>
  <div class="view">
    <input class="toggle" type="checkbox" onclick="toggle($todo)">
    </input>
    <label "$text" ondblclick="start_editing('$session', $todo)">
    </label>
    <button class="destroy" onclick="delete_todo($todo)">
    </button>
  </div>
</li>
"""
```

Which I can then dump into the body of a function and eval. Running the existing interpreter on the template pretty much does that correctly, if I ignore all the variables.

Eugh, no, that doesn't quite work because the $ gets escaped. Just have to do it by hand, I guess. Kinda gross:

``` julia
function generate_fragment(value::Union{String, Symbol}, fragment)
  push!(fragment, string(value))
end

function generate_fragment(expr::StringExpr, fragment)
  for value in expr.values
    push!(fragment, value)
  end
end

function generate_fragment(node::TextNode, fragment)
  generate_fragment(node.text, fragment)
end

function generate_fragment(node::AttributeNode, fragment)
  push!(fragment, " ")
  generate_fragment(node.key, fragment)
  push!(fragment, "=")
  generate_fragment(node.val, fragment)
end

function generate_fragment(node::FixedNode, fragment)
  push!(fragment, "<")
  generate_fragment(node.tag, fragment)
  for child in node.children
    if typeof(child) == AttributeNode
      generate_fragment(child, fragment)
    end
  end
  push!(fragment, ">")
  for child in node.children
    if typeof(child) != AttributeNode
      generate_fragment(child, fragment)
    end
  end
  push!(fragment, "</")
  generate_fragment(node.tag, fragment)
  push!(fragment, ">")
end

function generate_fragment(node::QueryNode, fragment)
  # TODO no html generated, but do we need to record the position or something? maybe put a dummy node in?
end

function concat_fragment(fragment)
  new_fragment = Union{Symbol, String}[]
  for value in fragment
    if isa(value, String) && (length(new_fragment) > 0) && isa(new_fragment[end], String)
      new_fragment[end] = string(new_fragment[end], value)
    else
      push!(new_fragment, value)
    end
  end
  new_fragment
end

function compile_fragment(id::Symbol, node::QueryNode, bound_vars::Vector{Symbol})
  fragment = Union{Symbol, String}[]
  for child in node.children
    generate_fragment(child, fragment)
  end
  fragment = concat_fragment(fragment)
  name = Symbol("fragment_", id)
  fun = @eval function $(name)($(bound_vars...))
    string($(fragment...))
  end
  (fragment, fun)
end
```

Ok, now I have to think about positioning. Tomorrow?

### 2017 Jun 19

I figured out why I'm having so much trouble making this incremental. There's really two steps involved.

We start off with a template:

``` julia
foo(w) do
  [A
    bar(w,x) do
      baz(x,y) do
        [B "$y"]
      end
      quux(x,z) do
        [C "$z"]
      end
    end
  ]
end
```

And then fill the template with data:

``` julia
foo(1) do
  [A
    bar(1,1) do
      baz(1,1) do
        [B "1"]
      end
      baz(1,2) do
        [B "2"]
      end
      baz(1,3) do
        [B "3"]
      end
    end
    bar(1,2) do
      baz(2,1) do
        [B "1"]
      end
      quux(2,1) do
        [C "1"]
      end
    end
  ]
end
```

And finally flatten the query nodes to produce a DOM tree:

``` julia
[A
  [B "1"]
  [B "2"]
  [B "3"]
  [B "1"]
  [C "1"]
]
```

The flattening is a complicated interleaving of rows from the various relations. Before having a clear picture of these two steps in my mind I was conflating the flattened tree with the intermediate tree.

The way to deal with this is to reify and incrementally maintain the intermediate state separately from the final state.

It's kind of fiddly, because we want to be able to write as much of the code as possible generically, rather than generating it all, but we don't have a good way to deal with tuples of varying lengths. So we'll generate code that handles the sorting and generates some kind of id for each tuple (probably a hash).

``` julia
@query begin
  foo(w)
  id = id(1, w)
  return foo_id(w) => id
end

@query begin
  foo_id(w) => parent_id
  id = id(2, w)
  return A_id(w) => id
  return parent(id) => parent_id
  return position(id) => 1
  return fragment(id) => "<A></A>"
end

@query begin
  A_id(w) => parent_id
  @query bar(w, xs)
  i in eachindex(xs)
  x = xs[i]
  id = id(3, w, x)
  return bar_id(w, x) => id
  return parent(id) => parent_id
  return position(id) => i
end

# etc...
```

And then we can do the flattening generically.

``` julia
@query begin
  fragment(id) => _
  return count(id) => 1
end

@query begin
  !(fragment(id) => _)
  @query begin
    parent(id, child)
    count(child) => count
  end
  return count(id) => sum(count)
end

@query begin
  fragment(id) => _
  return start(id) => 1
end

@fixpoint @query begin
  start(id) => start
  @query begin
    parent(id) => child
    count(id) => count
  end
  starts = vcat([0], cumsum(count))
  ix in eachindex(starts)
  return start(child[ix]) => start + starts[ix]
end
```

The fixpoint there is not quite right, but you get the idea.

I wonder what kind of data model and query compiler would allow writing all of the code generically, treating the template as pure data...

### 2017 Jul 3

I figured out a nicer way to do it. I thought of using some kind of sort key before, but couldn't figure out how to make the type stable. I spent a bunch of time thinking about algebraic types without realizing that I could just use nulls. Funny how you can get stuck in one line of thinking.

I'm going to id template nodes by their hashes.

I'll generate the whole intermediate tree for now, and worry about coalescing fixed nodes later once I have it working. That means that for now there will be a bunch of pointless queries that just shuffle data around:

``` julia
function compile_server_tree(node::FixedNode, parent_id, parent_vars, flows)
  id = Symbol("node_$(hash(node))")
  flow = @eval @merge begin
    $parent_id($(parent_vars...))
    return $id($(parent_vars...))
  end
  push!(flows, flow)
  for child in node.children
    compile_server_tree(child, id, parent_vars, flows)
  end
end
```

And only the query nodes will actually produce queries that do any work:

``` julia
function compile_server_tree(node::QueryNode, parent_id, parent_vars, flows)
  id = Symbol("node_$(hash(node))")
  vars = unique(vcat(parent_vars, node.vars))
  flow = @eval @merge begin
    $parent_id($(parent_vars...))
    $(node.table)($(node.vars...))
    return $id($(vars...))
  end
  push!(flows, flow)
  for child in node.children
    compile_server_tree(child, id, vars, flows)
  end
end
```

That's the easy part. Now we need to flatten the intermediate tree. So first let's divide it into flattenable groups. To make this easier I'm going to insist that the top node in any template is a fixed node. Then each group is formed by starting from a parent fixed node and following the tree downwards until each path is terminated by a child fixed node.

Then we need to figure out the path to each child. This is tricky to represent, because we need to represent in a such a way that the type of the path is the same for each child, even though they may contain different variables. So we'll gather up all the branches and query vars in the group and then null out the ones that aren't needed for each particular child.

I originally thought of this as two passes - figure out what the key is and then fill it out for each node - but it turned out to be easier to do both in the one pass and then tidy up the missing parts of the key afterwards.

``` julia
function collect_sort_key(node::FixedNode, parent_vars, key, keyed_children)
  push!(keyed_children, (copy(key), parent_vars, node))
end

function collect_sort_key(node::QueryNode, parent_vars, key, keyed_children)
  vars = unique(vcat(parent_vars, node.vars))
  new_vars = vars[(1+length(parent_vars)):end]
  start_ix = length(key)
  push!(key, new_vars)
  end_ix = length(key)
  collect_sort_key(node.children, vars, key, keyed_children)
  key[start_ix:end_ix] .= nothing
end

function collect_sort_key(nodes::Vector{Node}, parent_vars, key, keyed_children)
  push!(key, 0)
  for node in nodes
    if typeof(node) in [FixedNode, QueryNode] # TODO handle attributes and text
      key[end] += 1
      collect_sort_key(node, parent_vars, key, keyed_children)
    end
  end
  key[end] = 0
end

function collect_sort_key(node::FixedNode, parent_vars)
  key = Any[]
  keyed_children = Any[]
  collect_sort_key(node.children, parent_vars, key, keyed_children)
  # tidy up ragged ends of keys
  for (child_key, vars, child) in keyed_children
    append!(child_key, key[(length(child_key)+1):end])
  end
  keyed_children
end
```

And now for each group we need to spit out queries that collect nodes from the intermediate tree and merge them into their groups using the sort keys.

(It occurs to me that it would be much nicer to structure this as a series of smaller passes that elaborates fields on each node, but that's too big a change to make right now.)

``` julia
function key_expr(elem)
  @match typeof(elem) begin
    Integer => elem
    Symbol => :(Nullable($elem))
    Void => :(Nullable())
    _ => error("What are this: $elem")
  end
end

function compile_client_tree(node::FixedNode, parent_vars, flows)
  keyed_children = collect_sort_key(node, parent_vars)
  group_id = Symbol("group_$(hash(parent))")
  parent_node_id = Symbol("node_$(hash(parent))")
  for (key, child_vars, child) in keyed_children
    child_node_id = Symbol("node_$(hash(child))")
    key_exprs = map(key_expr, key)
    flow = @eval @merge begin
      $parent_node_id($(parent_vars...)) => parent_id
      $child_node_id($(child_vars...)) => child_id
      return $group_id($(key_exprs...)) => (parent_id, child_id, $(node.tag))
    end
    push!(flows, flow)
    compile_client_tree(child, child_vars, flows)
  end
end
```

A couple of bugfixes later, here is a single group:

``` julia
[ul
  class="todo-list"
  visible(session, todo) do
    text(todo, text) do
      displaying(session, todo) do
        [li
          ...
        ]
      end
      editing(session, todo) do
        [li
          ...
        ]
      end
    end
  end
]

quote  # /home/jamie/imp/src/UI.jl, line 304:
    node_10782481008382097060(session) => parent_id # /home/jamie/imp/src/UI.jl, line 305:
    node_752968304873089842(session,todo,text) => child_id # /home/jamie/imp/src/UI.jl, line 306:
    return group_10782481008382097060(1,Nullable(todo),1,Nullable(text),1,1,0) => (parent_id,child_id,"li")
end
quote  # /home/jamie/imp/src/UI.jl, line 304:
    node_10782481008382097060(session) => parent_id # /home/jamie/imp/src/UI.jl, line 305:
    node_18031626605480411109(session,todo,text) => child_id # /home/jamie/imp/src/UI.jl, line 306:
    return group_10782481008382097060(1,Nullable(todo),1,Nullable(text),2,0,1)
end
```

What have I missed out so far? It doesn't declare the relations either. To do that I need to know the type of each variable. Let's just use Any for now, for the sake of getting things going.

It doesn't handle attributes or text yet. I'll deal with most of that by compacting fragments together like the earlier code, but I'll also need a separate system for attributes that are the children of a query node.

I tried running this on todomvc and ran into the most annoying roadblock:

``` julia
LoadError: MethodError: no method matching isless(::Nullable{Any}, ::Nullable{Any})
```

Nullables aren't comparable. It's fixed in Julia 0.6. Should I try to upgrade?

[Nope!](https://github.com/kmsquire/Match.jl/issues/35). I used Match.jl for all my parsing. It doesn't work in 0.6, it hasn't been updated in 10 months and the last issue I filed several months ago received no response. So probably if I want to upgrade to 0.6 I'll have to fix Match.jl too. Doable, but not right now.

``` julia
# TODO this is defined in Julia 0.6 but can't currently upgrade because of https://github.com/kmsquire/Match.jl/issues/35
function Base.isless{T}(x::Nullable{T}, y::Nullable{T})
  !Base.isnull(x) && (Base.isnull(y) || (get(x) < get(y)))
end
```

Now it runs. Kind of hard to tell if it's right just by looking though.

Todo:

* hookup client side
* retrieve types from world
* compact fragments to handle text and fixed attributes
* handle query attributes

### 2017 Jul 4

Alright, time for the diffing.

``` julia
# TODO figure out how to handle changes in template
function render(window, view, world, session)
  for event in world.events
    js(window, Blink.JSString("$event = imp_event(\"$event\")"), callback=false) # these never return! :(
  end
  flow = Sequence([view.compiled_head.flow, view.compiled_body.flow])
  group_names = vcat(view.compiled_head.group_ids, view.compiled_body.group_ids)
  old_groups = Dict{Symbol, Union{Relation, Void}}(name => get(world.state, name, nothing) for name in group_names)
  Flows.init_flow(flow, world)
  Flows.run_flow(flow, world)
  new_groups = Dict{Symbol, Relation}(name => world.state[name] for name in group_names)
  for name in group_names
    if old_groups[name] == nothing
      old_groups[name] = empty(new_groups[name])
    end
  end
  deletes = Set{UInt64}()
  creates = Vector{Tuple{UInt64, Union{UInt64, Void}, UInt64, String}}()
  for name in group_names
    old_columns = old_groups[name].columns
    old_parent_ids = old_columns[end-2]
    old_child_ids = old_columns[end-1]
    new_columns = new_groups[name].columns
    new_parent_ids = new_columns[end-2]
    new_child_ids = new_columns[end-1]
    new_contents = new_columns[end-0]
    Data.foreach_diff(old_columns, new_columns, old_columns[1:end-3], new_columns[1:end-3],
      (o, i) -> begin
        if !(old_parent_ids[i] in deletes)
          push!(deletes, old_child_ids[i])
        end
      end,
      (n, i) -> begin
        if (i < length(new_parent_ids)) && (new_parent_ids[i] == new_parent_ids[i+1])
          sibling = new_child_ids[i+1]
        else
          sibling = nothing
        end
        push!(creates, (new_parent_ids[i], sibling, new_child_ids[i], new_contents[i]))
      end,
      (o, n, oi, ni) -> ()
    )
  end
  @js_(window, render($deletes, $creates))
end
```

Kinda verbose, but it looks like it's working. Now just need to hook it up to the client.

``` js
function render(deletes, creates) {
    for (i = 0; i < deletes.length; i++) {
        document.getElementById(deletes[i]).remove();
    }
    for (i = 0; i < creates.length; i++) {
        create = creates[i]
        parent = document.getElementById(create[0]);
        sibling = document.getElementById(create[1]);
        child = document.createElement(create[3]);
        child.id = create[2];
        parent.insertBefore(child, sibling);
    }
}
```

Crap, I forgot about roots. And sessions.

Let's do something super hacky to deal with rooting the template:

``` js
function render(deletes, creates) {
    console.time("render")
    for (i = 0; i < deletes.length; i++) {
        document.getElementById(deletes[i]).remove();
    }
    for (i = 0; i < creates.length; i++) {
        create = creates[i]
        // super hacky way to root things
        if (create[3] == "head") {
            document.head.id = create[2]
        } else if (create[3] == "body") {
            document.body.id = create[2]
        } else {
            parent = document.getElementById(create[0]);
            sibling = (create[1] == null) ? null : document.getElementById(create[1]);
            child = document.createElement(create[3]);
            child.id = create[2];
            parent.insertBefore(child, sibling);
        }
    }
    console.timeEnd("render")
}
```

It works! There's no actual content in it, but I can see the structure getting updated correctly when I fire events from the console.

Now text. Let's combine TextNode and FixedNode and just call the correct constructor client side:

``` julia
immutable FixedNode <: Node
  tag::Value
  kind::Symbol # :text or :html
  children::Vector{Node}
end
```

``` js
function render(deletes, creates) {
    console.time("render")
    for (i = 0; i < deletes.length; i++) {
        document.getElementById(deletes[i]).remove();
    }
    for (i = 0; i < creates.length; i++) {
        create = creates[i]
        // super hacky way to root things
        if (create[3] == "html") {
            if (create[4] == "head") {
                document.head.id = create[2]
            } else if (create[4] == "body") {
                document.body.id = create[2]
            } else {
                parent = document.getElementById(create[0]);
                sibling = (create[1] == null) ? null : document.getElementById(create[1]);
                child = document.createElement(create[4]);
                child.id = create[2];
                parent.insertBefore(child, sibling);
            }
        } else {
            parent = document.getElementById(create[0]);
            sibling = (create[1] == null) ? null : document.getElementById(create[1]);
            child = document.createTextNode(create[4]);
            child.id = create[2];
            parent.insertBefore(child, sibling);
        }
    }
    console.timeEnd("render")
}
```

Eugh, turns out text nodes in the DOM can't have ids. Not a complete roadblock. We can just specify deletes and inserts by parent id and child ix instead of child id and sibling id.

I also did some gross struct-of-arrays stuff while I was in there...

``` julia
function render(window, view, world, session)
  for event in world.events
    js(window, Blink.JSString("$event = imp_event(\"$event\")"), callback=false) # these never return! :(
  end
  old_groups = Dict{Symbol, Union{Relation, Void}}(name => get(world.state, name, nothing) for name in view.group_names)
  Flows.init_flow(view.compiled, world)
  Flows.run_flow(view.compiled, world)
  new_groups = Dict{Symbol, Relation}(name => world.state[name] for name in view.group_names)
  for name in view.group_names
    if old_groups[name] == nothing
      old_groups[name] = empty(new_groups[name])
    end
  end
  delete_parents = Vector{UInt64}()
  delete_childs = Set{UInt64}()
  delete_ixes = Vector{Int64}()
  html_create_parents = Vector{UInt64}()
  html_create_ixes = Vector{Int64}()
  html_create_childs = Vector{UInt64}()
  html_create_tags = Vector{String}()
  text_create_parents = Vector{UInt64}()
  text_create_ixes = Vector{Int64}()
  text_create_contents = Vector{String}()
  for name in view.group_names
    old_columns = old_groups[name].columns
    old_parent_ids = old_columns[end-3]
    old_child_ids = old_columns[end-2]
    new_columns = new_groups[name].columns
    new_parent_ids = new_columns[end-3]
    new_child_ids = new_columns[end-2]
    new_kinds = new_columns[end-1]
    new_contents = new_columns[end-0]
    Data.foreach_diff(old_columns, new_columns, old_columns[1:end-3], new_columns[1:end-3],
      (o, i) -> begin
        if !(old_parent_ids[i] in delete_childs)
          parent = old_parent_ids[i]
          prev_i = findprev((prev_parent) -> prev_parent != parent, old_parent_ids, i-1)
          ix = i - prev_i - 1 # 0-indexed
          push!(delete_parents, parent)
          push!(delete_childs, old_child_ids[i])
          push!(delete_ixes, ix)
        end
      end,
      (n, i) -> begin
        parent = new_parent_ids[i]
        prev_i = findprev((prev_parent) -> prev_parent != parent, new_parent_ids, i-1)
        ix = i - prev_i - 1 # 0-indexed
        if new_kinds[i] == :html
          push!(html_create_parents, parent)
          push!(html_create_ixes, ix)
          push!(html_create_childs, new_child_ids[i])
          push!(html_create_tags, new_contents[i])
        else
          push!(text_create_parents, parent)
          push!(text_create_ixes, ix)
          push!(text_create_contents, new_contents[i])
        end
      end,
      (o, n, oi, ni) -> ()
    )
  end
  # deletions have to be handled in reverse order to make sure the ixes are correct
  reverse!(delete_parents)
  reverse!(delete_ixes)
  @show delete_parents delete_ixes html_create_parents html_create_ixes html_create_childs html_create_tags text_create_parents text_create_ixes text_create_contents
  @js_(window, render($delete_parents, $delete_ixes, $html_create_parents, $html_create_ixes, $html_create_childs, $html_create_tags, $text_create_parents, $text_create_ixes, $text_create_contents))
end
```

``` js
function render(delete_parents, delete_ixes, html_create_parents, html_create_ixes, html_create_childs, html_create_tags, text_create_parents, text_create_ixes, text_create_contents) {
    console.time("render")
    for (i = 0; i < delete_parents.length; i++) {
        document.getElementById(delete_parents[i]).children[delete_ixes[i]].remove();
    }
    for (i = 0; i < html_create_parents.length; i++) {
        // super hacky way to root things
        if (html_create_tags[i] == "head") {
            document.head.id = html_create_childs[i]
        } else if (html_create_tags[i] == "body") {
            document.body.id = html_create_childs[i]
        } else {
            parent = document.getElementById(html_create_parents[i]);
            child = document.createElement(html_create_tags[i]);
            child.id = html_create_childs[i];
            parent.insertBefore(child, parent.children[html_create_ixes[i]]);
        }
    }
    for (i = 0; i < text_create_parents.length; i++) {
        parent = document.getElementById(text_create_parents[i]);
        child = document.createTextNode(text_create_contents[i]);
        parent.insertBefore(child, parent.children[text_create_ixes[i]]);
    }
    console.timeEnd("render")
}
```

It sort of works. I can add one todo and it shows up on screen, but if I add another it just deletes the first.

Oh, I need the whole chain of variables inside groups - not just the local variables. Now it works!

Ok, attributes. These can just go in a totally separate pathway.

``` julia
function compile_server_tree(node::AttributeNode, parent_id, parent_vars, flows)
  merge_flow = @eval @merge begin
    $parent_id($(parent_vars...)) => parent_id
    return attribute(parent_id, string($(flatten_value(node.key)...))) => string($(flatten_value(node.val)...))
  end
  push!(flows, merge_flow)
end
```

``` js
for (i = 0; i < attribute_delete_childs.length; i++) {
    document.getElementById(attribute_delete_childs[i]).removeAttribute(attribute_delete_keys[i]);
}
for (i = 0; i < attribute_create_childs.length; i++) {
    document.getElementById(attribute_create_childs[i]).setAttribute(attribute_create_keys[i], attribute_create_vals[i]);
}
```

Kind of works. CSS is working now, and some of the events. But it seems to get out of sync at times.

Oh, it's silently blowing up on some attributes. I wrapped the whole render in a try/catch and now I can see that attributes inside a query node get the wrong parent id. Easily fixed.

Another bug with not diffing properly, because of the order of init.

And another with deleting attributes of dom nodes that have themselves been deleted.

And finally, discovering that the `node.setAttribute("checked", true)` and `node.checked=true` are not the same. I'm trying to avoid special-casing stuff like this but it's getting harder. I *think* what I want to do is always set properties, not attributes. As far as I know, I only have to special-case class -> className to make that work.

Nope, doesn't work for events - the property has to be a function, not a string.

Also, deleting the checked property doesn't actually work. Maybe it has to be set to undefined?

Text nodes don't show up in `node.children`, only in `node.childNodes`.

Need to consider all deleted nodes when deleting properties, not just the root that I actually delete.

And everything else seems to be working :D

A few tweaks to handle ignoring vars in the template eg `filter_class(session, filter, _) do ... end`.

I want to get types into the generated code. This requires reading them out of the world, which requires changing the way the plumbing between world and ui works. And also propagating the types all through the compiler. Not today.

Todo:

* redo plumbing
* retrieve types from world
* handle sessions
* stop making node_ for FixedNode
* refactor compiler into normalized style

Couldn't resist benchmarking against the classic Om blogpost. Not very reliable measurements on either side, but I'm certainly within 2x, of which almost all the time is spent in the UI flows. Which are missing type annotations...

### 2017 Jul 11

I removed the watchers stuff, made View wrap World and then just wrapped all the mutation functions. Watchers are a thing I stole from clojure and they always seem like a good idea at first, but in the long run life is always better with linear control flow. Debugging is so much easier if you can follow code by just reading it in a straight line, rather than having to keep track of where callbacks were created.

Now templates have access to the World when they are being compiled, so I have the opportunity to pass type information through. But first I have to fix some new heisenbug inside Blink. Once again I have rpcs being called on the server and not showing up on the client.

I'm seriously fed up with Blink. The api is great but the constant dropping and hanging is killing my productivity.

Much debugging later, I've stripped out Blink and I'm using raw websockets. I don't think my threading is correct at the moment, but it's at least working well enough for development. The biggest annoyance I have at the moment is closing old versions of the server - it seems that old modules don't get GCed so I can't use finalizers, and I can't close things manually because I lose the reference when I recompile. I'll figure both out later.

Passing types through from the state moves my crude benchmark from 100ms + 9mb to 20ms + 5mb. The number of allocations is still huge, so I figure that `Nullable{String}` is probably landing on the heap.

``` julia
function f()
  x = "foo"
  [Nullable(x) for i in 1:1000000]
end

@time f()
```

Maybe I can unpack that manually?

Actually, better idea:

``` julia
function column_type{T}(_::Type{Val{T}})
  Vector{T}
end

function column_type{T}(_::Type{Val{Nullable{T}}})
  NullableVector{T}
end
```

Ok, that doesn't actually work, because the Nullables still get created and dumped on the stack when querying the vector. Manual it is.

``` julia
default{T <: Number}(::Type{T}) = zero(T)
default(::Type{String}) = ""

function key_expr(elem)
  @match elem begin
    _::Integer => elem
    (_::Symbol, _::Type) => elem[1]
    (_::Void, _::Type) => default(elem[2])
    _ => error("What are this: $elem")
  end
end

function key_type(elem)
  @match elem begin
    _::Integer => Int64
    (var::Symbol, typ::Type) => typ
    (_::Void, typ::Type) => typ
    _ => error("What are this: $elem")
  end
end
```

Uh, that didn't make much of a dent either. Am confused.

Maybe this line?

``` julia
child_id = hash(tuple($(node_real_vars...), parent_id), $(hash(node)))
```

Nope.

Oh, I only added types to half of the queries.

:|

With that addressed, we're at 20ms + 4mb. Progress.

I noticed that the codegen for the queries is pretty poor in places. This seems to be the core problem:

``` julia
SSAValue(10) = (Base.getfield)((Core.getfield)(node_14578074387523514055@_2::Data.Relation{Tuple{Array{String,1},Array{UInt64,1}}},:columns)::Tuple{Array{String,1},Array{UInt64,1}},1)::UNION{ARRAY{STRING,1},ARRAY{UINT64,1}}
```

Simplified:

``` julia
Base.getfield(_::Tuple{Array{String,1},Array{UInt64,1}},1)::UNION{ARRAY{STRING,1},ARRAY{UINT64,1}}
```

Seriously? You can't figure out what type that is?

The solution is bizaare. I changed `:(eltype($(return_clause.name)[$ix]))` to `:(eltype($(return_clause.name).columns[$ix]))` - but it had already done that inlining itself in the generated code.

Didn't help much though.

I notice that init_flow causes a fair bit of allocation too, which is weird because it doesn't really do anything. I tried to eliminate dynamic dispatch by pulling all the methods into one switch statement, and then doing the creation of the relation up front and just copying thereafter.

``` julia
function init_flow(flow::ANY, world::World)
  t = typeof(flow)
  if t == Create
    if flow.is_transient || !haskey(world.state, flow.output_name)
      world.state[flow.output_name] = copy(flow.empty)
    end
    if flow.is_event
      push!(world.events, flow.output_name)
    end
  elseif t == Sequence
    for child in flow.flows
      init_flow(child, world)
    end
  elseif t == Fixpoint
    for child in flow.flows
      init_flow(child, world)
    end
  end
end
```

That kills most of the allocations there.

Doing the same for run_flow makes things worse. It doesn't look like Julia is actually respecting my do-not-specialize hints. So I'll undo that change, but keep the better type hints.

Current status:

``` julia
0.000822 seconds (100 allocations: 12.500 KB)
@time(init_flow(world.flow,world)) = nothing

0.005367 seconds (2.79 k allocations: 372.141 KB)
@time(run_flow(world.flow,world)) = nothing

0.003834 seconds (335 allocations: 41.875 KB)
@time(Flows.init_flow(view.compiled,view.world)) = nothing

0.047323 seconds (18.52 k allocations: 3.962 MB)
@time(Flows.run_flow(view.compiled,view.world)) = nothing

render: 64.86ms
roundtrip: 153.92ms
```

Todo:

* handle sessions
* stop making node_ for FixedNode
* refactor compiler into normalized style

### 2017 Jul 12

I had 'stop making node_ for FixedNode' on the todo list but I just realised that I can't do that in the current setup because I need them for AttributeNodes. I would have to hunt down the group id for the FixedNode and pick them out by key instead. That will be easier after refactoring.

I noticed the codegen in render is pretty bad, so I spent a few hours tweaking it. Mostly it came down to inserting type hints in places where the types are static and removing closures that cause boxing. The latter is kind of annoying because it seems unpredictable and avoiding it rules out lots of nice things like array comprehensions.

Here's where we're at now:

``` julia
0.000509 seconds (100 allocations: 12.500 KB)
@time(init_flow(world.flow,world)) = nothing

0.002258 seconds (2.79 k allocations: 372.141 KB)
@time(run_flow(world.flow,world)) = nothing

0.001573 seconds (335 allocations: 41.875 KB)
@time(Flows.init_flow(view.compiled,view.world)) = nothing

0.009917 seconds (18.52 k allocations: 3.962 MB)
@time(Flows.run_flow(view.compiled,view.world)) = nothing

0.008938 seconds (15.96 k allocations: 1.568 MB)
@time(render(view,old_state,view.world.state)) = nothing

render: 25.35ms
roundtrip: 55.82ms
```

50-60ms of which around half is rendering client-side.

One thing that's really noticeable is that `run_flow(view.compiled,...)` is at ~10ms down from ~50ms. I didn't change anything though. Weird.

I also made some improvements in live coding. I added:

``` julia
type View
  ...
  clients::Dict{String, WebSocket}
  server::Nullable{Server}
end

function Base.close(view::View)
  if !isnull(view.server) && isopen(get(view.server))
    close(get(view.server))
  end
  for (_, client) in view.clients
    if isopen(get(view.server))
      close(client)
    end
  end
  view.server = Nullable{Server}()
  view.clients = Dict{String, WebSocket}()
end
```

And then rather than evalling inside individual files, I eval chunks from this top-level script:

``` julia
include("src/Data.jl")
include("src/Query.jl")
include("src/Flows.jl")
include("src/UI.jl")
if isdefined(:Todo)
  close(Todo.view)
end
include("examples/Todo.jl")
close(Todo.view)
UI.serve(Todo.view)
```

That avoids a fair number of restarts.

None of those things were actually on my todo list, so it's still:

* handle sessions
* stop making node_ for FixedNode
* refactor compiler into normalized style

The way I want to refactor this is similar to the compiler - identify everything by ids and store all the actual data in tables. The parser will spit out a list of ids in preorder and a parents table and then nothing else needs to be recursive.

``` julia
typealias Splice Vector{Union{String, Symbol}}

immutable AttributeNode
  key::Splice
  val::Splice
end

immutable FixedNode
  tag::Splice
  kind::Symbol # :text or :html
end

immutable QueryNode
  table::Symbol
  vars::Vector{Symbol}
end

typealias Node Union{AttributeNode, FixedNode, QueryNode}

immutable Parsed
  nodes::Vector{Node} # in pre-order
  parents::Vector{Int64} # parent[1] = 0, arbitrarily
end

function parse_value(expr)
  convert(Splice, @match expr begin
    _::String => [expr]
    _::Symbol => [string(expr)]
    Expr(:string, args, _) => args
    _ => error("What are this? $expr")
  end)
end

function parse(expr)
  nodes = Vector{Node}()
  parents = Vector{Int64}()

  parse_stack = Vector{Tuple{Int64, Any}}()
  push!(parse_stack, (0, expr))
  while !isempty(parse_stack)
    (parent, expr) = pop!(parse_stack)
    @match expr begin
      Expr(:line, _, _) => nothing
      Expr(:block, [Expr(:line, _, _), expr], _) => begin
        push!(parse_stack, (parent, expr))
      end
      Expr(:vect || :vcat || :hcat, exprs, _) => begin
        for expr in exprs
          push!(parse_stack, (parent, expr))
        end
      end
      Expr(:call, [table::Symbol, Expr(:->, [Expr(:tuple, [], _), Expr(:block, exprs, _)], _), vars...], _) => begin
        push!(nodes, QueryNode(table, vars))
        push!(parents, parent)
        for expr in exprs
          push!(parse_stack, (length(nodes), expr))
        end
      end
      [tag, exprs...] => begin
        push!(nodes, FixedNode(parse_value(tag), :html))
        push!(parents, parent)
        for expr in exprs
          push!(parse_stack, (length(nodes), expr))
        end
      end
      Expr(:(=), [key, val], _) => begin
        push!(nodes, AttributeNode(parse_value(key), parse_value(val)))
        push!(parents, parent)
      end
      other => begin
        push!(nodes, FixedNode(parse_value(other), :text))
        push!(parents, parent)
      end
    end
  end

  Parsed(nodes, parents)
end
```

That worked first time. Except that all the nodes came out in reverse order. I... what?

Aha:

``` julia
Expr(:vect || :vcat || :hcat, exprs, _) => begin
  push!(parse_stack, (parent, exprs))
end
```

Unpacking the vect/vcat/hcat made me treat the tags of fixed nodes as text nodes. Then I also need to reverse the order on the other nodes to keep pre-order instead of post-order.

``` julia
for expr in reverse(exprs)
  push!(parse_stack, (length(nodes), expr))
end
```

Now it looks good.

First half of the compiler is easy enough:

``` julia
varses = Dict{Int64, Vector{Symbol}}(0 => [:session])
free_varses = Dict{Int64, Vector{Symbol}}(0 => [:session])
var_typeses = Dict{Int64, Vector{Type}}(0 => [String])
for (id, node) in enumerate(nodes)
  @match node begin
    QueryNode(table, query_vars) => begin
      vars = copy(varses[parents[id]])
      free_vars = Symbol[]
      var_types = copy(var_typeses[parents[id]])
      columns = state[table].columns
      for (ix, var) in enumerate(query_vars)
        if (var != :(_)) && !(var in vars)
          push!(vars, var)
          push!(free_vars, var)
          push!(var_types, eltype(columns[ix]))
        end
      end
      varses[id] = vars
      free_varses[id] = free_vars
      var_typeses[id] = var_types
    end
    _ => begin
      varses[id] = varses[parents[id]]
      free_varses[id] = free_varses[parents[id]]
      var_typeses[id] = var_typeses[parents[id]]
    end
  end
end

fixed_parents = Dict{Int64, Int64}(1 => 0)
query_parents = Dict{Int64, Int64}(1 => 0)
for (id, nodes) in enumerate(nodes)
  if id != 1 # root node has no parent
    parent = parents[id]
    fixed_parent = fixed_parents[parent]
    query_parent = query_parents[parent]
    @match nodes[parent] begin
      _::QueryNode => query_parent = parent
      _::FixedNode => fixed_parent = parent
    end
    fixed_parents[id] = fixed_parent
    query_parents[id] = query_parent
  end
end
```

The next part is figuring out how to calculate keys, but I'm out of brainpower for today.

### 2017 Jul 13

Trying to upgrade to Julia 0.6 today, since kmsquire kindly upgraded Match.jl this week.

Representation of some Exprs changed. Relatively easy to fix apart from the typical problems with macro errors not giving stack traces or even a line number

The new worlds thing that makes interactive redefinitions work also breaks my workflow - you can no longer eval a function and then call it without returning to the repl in between. I don't really understand how this works, because the repl itself is written in Julia and so there must be a way around it. Let's read the [docs](https://docs.julialang.org/en/latest/manual/methods.html#Redefining-Methods-1).

Well, that was a simple change:

``` julia
outputs::Vector{Relation} = Base.invokelatest(flow.eval, map((name) -> world.state[name], flow.input_names)...)
```

Some keyword changes.

`isopen(::HttpServer.Server)` [disappeared](https://github.com/JuliaWeb/HttpServer.jl/pull/119).

Fix a couple of deprecation warnings and we're done.

Quick benchmark update:

``` julia
0.000064 seconds (100 allocations: 12.500 KiB)
@time(init_flow(world.flow, world)) = nothing

0.001338 seconds (2.25 k allocations: 341.719 KiB)
@time(run_flow(world.flow, world)) = nothing

0.001820 seconds (913 allocations: 77.469 KiB)
@time(Flows.init_flow(view.compiled, view.world)) = nothing

0.006001 seconds (14.51 k allocations: 3.721 MiB)
@time(Flows.run_flow(view.compiled, view.world)) = nothing

0.003617 seconds (16.14 k allocations: 1.119 MiB)
@time(render(view, old_state, view.world.state)) = nothing

render: 24.45ms
roundtrip: 55.35ms
```

They're pretty noisy so no point reading too much into small differences. Looks like it's pretty much the same.

Back to the UI compiler refactor.

Here's all the prep work:

``` julia
function compile(node, parent, column_type::Function)
  fixed_parent = Dict{Int64, Int64}(1 => 0)
  query_parent = Dict{Int64, Int64}(1 => 0)
  for id in 2:length(node) # node 1 has no real parents
    my_parent = parent[id]
    fixed_parent[id] = fixed_parent[my_parent]
    query_parent[id] = query_parent[my_parent]
    @match node[my_parent] begin
      _::QueryNode => query_parent[id] = my_parent
      _::FixedNode => fixed_parent[id] = my_parent
    end
  end

  vars = Dict{Int64, Vector{Symbol}}(0 => [:session])
  types = Dict{Int64, Vector{Type}}(0 => [String])
  free_vars = Dict{Int64, Vector{Symbol}}(0 => [:session])
  free_types = Dict{Int64, Vector{Type}}(0 => [String])
  for (id, my_node) in enumerate(node)
    my_vars = vars[id] = copy(vars[parent[id]])
    my_types = types[id] = copy(var_types[parent[id]])
    my_free_vars = free_vars[id] = Vector{Symbol}()
    my_free_types = free_types[id] = Vector{Type}()
    if my_node isa QueryNode
      for (ix, var) in enumerate(my_node.vars)
        if (var != :(_)) && !(var in my_vars)
          push!(my_vars, var)
          push!(my_types, column_type(my_node.table, ix))
          push!(my_free_vars, var)
          push!(my_free_types, column_type(my_node.table, ix))
        end
      end
    end
  end

  num_children = Dict{Int64, Int64}(id => 0 for id in 0:length(node))
  ix = Dict{Int64, Int64}()
  family = Dict{Int64, Vector{Int64}}(id => Vector{Int64}() for (_, id) in fixed_parent)
  ancestors = Dict{Int64, Vector{Int64}}()
  for (id, my_node) in enumerate(node)
    if !(my_node isa AttributeNode)
      ix[id] = (num_children[parent[id]] += 1)
      push!(family[fixed_parent[id]], id)
      ancestors[id] = (parent[id] == fixed_parent[id]) ? Vector{Int64}() : ancestors[parent[id]]
      push!(ancestors[id], id)
    end
  end

  key = Dict{Int64, Vector{Union{Int64, Type, Tuple{Symbol, Type}}}}()
  for (my_fixed_parent, my_family) in family
    base_key = Vector{Union{Int64, Type, Tuple{Symbol, Type}}}()
    append!(base_key, zip(vars[my_fixed_parent], types[my_fixed_parent]))
    for id in my_family
      if node[id] isa FixedNode
        my_key = copy(base_key)
        my_ancestors = ancestors[id]
        for other_id in my_family
          if other_id in my_ancestors
            push!(my_key, ix[other_id])
            append!(my_key, zip(free_vars[other_id], free_types[other_id]))
          else
            push!(my_key, 0)
            append!(my_key, free_types[other_id])
          end
        end
      end
    end
  end
```

Much cleaner than before, especially working out the keys. Just need to do the codegen and debug it now.

### 2017 Jul 14

Many hours of debugging later:

``` julia
0.000077 seconds (100 allocations: 12.500 KiB)
@time(init_flow(world.flow, world)) = nothing

0.002862 seconds (2.25 k allocations: 341.719 KiB)
@time(run_flow(world.flow, world)) = nothing

0.000132 seconds (150 allocations: 18.750 KiB)
@time(Flows.init_flow(view.compiled.flow, view.world)) = nothing

0.008996 seconds (12.36 k allocations: 2.285 MiB)
@time(Flows.run_flow(view.compiled.flow, view.world)) = nothing

0.005160 seconds (16.16 k allocations: 1.120 MiB)
@time(render(view, old_state, view.world.state)) = nothing

render: 24.5ms
roundtrip: 51.99ms
```

Overall times are very variable, but the allocations are deterministic and these are slightly lower, probably because I'm now able to omit the extra views on FixedNodes.

The new parser and compiler are structured totally differently to the old, and yet they each have almost exactly the same number of lines of code. It's eery.

Most of the complexity is in dealing with special cases at the root and with calculating the sort keys:

``` julia
family = Dict{Int64, Vector{Int64}}(id => [id] for (_, id) in fixed_parent)
for (id, my_node) in enumerate(node)
  if !(my_node isa AttributeNode)
    push!(family[fixed_parent[id]], id)
  end
end

num_children = Dict{Int64, Int64}(id => 0 for id in 0:length(node))
lineage = Dict{Tuple{Int64, Int64}, Int64}()
# lineage[hi, lo] = n iff lo is the nth child of hi or a descendant thereof
# lineage[hi, lo] = 0 otherwise
for (_, my_family) in family
  for hi_id in my_family
    for lo_id in my_family
      if hi_id >= lo_id # note ids are numbered depth-first
        lineage[hi_id, lo_id] = 0
      elseif hi_id == parent[lo_id]
        lineage[hi_id, lo_id] = (num_children[hi_id] += 1)
      else
        lineage[hi_id, lo_id] = lineage[hi_id, parent[lo_id]]
      end
    end
  end
end

const KeyElem = Union{Int64, Type, Tuple{Symbol, Type}}
key = Dict{Int64, Vector{KeyElem}}(0 => KeyElem[(:session, String)])
for (my_fixed_parent, my_family) in family
  base_key = Vector{KeyElem}()
  append!(base_key, zip(vars[my_fixed_parent], types[my_fixed_parent]))
  for lo_id in my_family[2:end] # don't include parent
    if node[lo_id] isa FixedNode
      @assert !haskey(key, lo_id)
      my_key = key[lo_id] = copy(base_key)
      for hi_id in my_family
        if (hi_id == my_fixed_parent) || (node[hi_id] isa QueryNode)
          if lineage[hi_id, lo_id] == 0
            append!(my_key, free_types[hi_id])
            push!(my_key, 0)
          else
            append!(my_key, zip(free_vars[hi_id], free_types[hi_id]))
            push!(my_key, lineage[hi_id, lo_id])
          end
        end
      end
    end
  end
end

key_vars = Dict{Int64, Vector{Any}}()
key_exprs = Dict{Int64, Vector{Any}}()
key_types = Dict{Int64, Vector{Type}}()
for (id, my_key) in key
  my_key_vars = key_vars[id] = Vector{Any}()
  my_key_exprs = key_exprs[id] = Vector{Any}()
  my_key_types = key_types[id] = Vector{Type}()
  for key_elem in my_key
    (var, expr, typ) = @match key_elem begin
      _::Int64 => (key_elem, key_elem, Int64)
      _::Type => (:(_), :(default($key_elem)), key_elem)
      (var, typ) => (var, var, typ)
    end
    push!(my_key_vars, var)
    push!(my_key_exprs, expr)
    push!(my_key_types, typ)
  end
end
```

I'm sure there are better ways to do both.

The compile time is disgusting - probably because of all the evals:

``` julia
:parse = :parse
  0.001876 seconds (3.12 k allocations: 206.344 KiB)
:compile = :compile
  1.212156 seconds (300.23 k allocations: 17.650 MiB, 1.31% gc time)
```

There's also some weird stuff going on in the inferred types for the compile. I narrowed it down to something involving chained assignment:

``` julia
function f()
  d = Dict{Int64, Vector{Int64}}()
  x = d[1] = Vector{Int64}()
  push!(x, 1)
end

@code_warntype f()

Variables:
  #self#::#f
  d::Dict{Int64,Array{Int64,1}}
  x::ANY
  n::Int64
  itemT::Int64

Body:
  begin
      $(Expr(:inbounds, false))
      # meta: location dict.jl Type 104
      SSAValue(6) = $(Expr(:invoke, MethodInstance for fill!(::Array{UInt8,1}, ::UInt8), :(Base.fill!), :($(Expr(:foreigncall, :(:jl_alloc_array_1d), Array{UInt8,1}, svec(Any, Int64), Array{UInt8,1}, 0, 16, 0))), :((Base.checked_trunc_uint)(UInt8, 0)::UInt8)))
      SSAValue(4) = $(Expr(:foreigncall, :(:jl_alloc_array_1d), Array{Int64,1}, svec(Any, Int64), Array{Int64,1}, 0, 16, 0))
      SSAValue(2) = $(Expr(:foreigncall, :(:jl_alloc_array_1d), Array{Array{Int64,1},1}, svec(Any, Int64), Array{Array{Int64,1},1}, 0, 16, 0))
      # meta: pop location
      $(Expr(:inbounds, :pop))
      d::Dict{Int64,Array{Int64,1}} = $(Expr(:new, Dict{Int64,Array{Int64,1}}, SSAValue(6), SSAValue(4), SSAValue(2), 0, 0, :((Base.bitcast)(UInt64, (Base.check_top_bit)(0)::Int64)), 1, 0)) # line 24:
      SSAValue(0) = $(Expr(:foreigncall, :(:jl_alloc_array_1d), Array{Int64,1}, svec(Any, Int64), Array{Int64,1}, 0, 0, 0))
      $(Expr(:invoke, MethodInstance for setindex!(::Dict{Int64,Array{Int64,1}}, ::Array{Int64,1}, ::Int64), :(Main.setindex!), :(d), SSAValue(0), 1)) # line 25:
      $(Expr(:inbounds, false))
      # meta: location array.jl push! 618
      SSAValue(8) = (Base.bitcast)(UInt64, (Base.check_top_bit)(1)::Int64)
      $(Expr(:foreigncall, :(:jl_array_grow_end), Void, svec(Any, UInt64), SSAValue(0), 0, SSAValue(8), 0)) # line 619:
      # meta: location abstractarray.jl endof 134
      # meta: location abstractarray.jl linearindices 99
      # meta: location abstractarray.jl indices1 71
      # meta: location abstractarray.jl indices 64
      SSAValue(11) = (Base.arraysize)(SSAValue(0), 1)::Int64
      # meta: pop location
      # meta: pop location
      # meta: pop location
      # meta: pop location
      (Base.arrayset)(SSAValue(0), 1, (Base.select_value)((Base.slt_int)(SSAValue(11), 0)::Bool, 0, SSAValue(11))::Int64)::Array{Int64,1}
      # meta: pop location
      $(Expr(:inbounds, :pop))
      return SSAValue(0)
  end::Array{Int64,1}
```

It claims not to know the type of x, but it generates code as if it does. Not really important right now, so I'll just [ask the mailing list about it](https://discourse.julialang.org/t/confusing-type-inference-from-chained-assignment/4861) and move on.

I've been using `@show @time ...` for timing stuff, but the output is a little hard to read and I have to be careful only to use for it statements that don't return any large data-structures that might be printed out. I replaced it with a cute macro:

``` julia
macro showtime(expr)
  quote
    @time $(esc(expr))
    println($(string("^ ", expr)))
    println()
  end
end
```

I also added some slightly finer grained timing to the client.

``` julia
  0.000042 seconds (15 allocations: 1.156 KiB)
^ event = JSON.parse(String(bytes))

  0.000047 seconds (100 allocations: 12.500 KiB)
^ init_flow(world.flow, world)

  0.000035 seconds (49 allocations: 3.672 KiB)
^ push!(world.state[event_table], event_row)

  0.001459 seconds (2.25 k allocations: 341.719 KiB)
^ run_flow(world.flow, world)

  0.000226 seconds (159 allocations: 19.031 KiB)
^ Flows.init_flow(view.compiled.flow, view.world)

  0.006604 seconds (12.39 k allocations: 2.286 MiB)
^ Flows.run_flow(view.compiled.flow, view.world)

  0.005303 seconds (16.16 k allocations: 1.120 MiB)
^ render(view, old_state, view.world.state)

  0.014123 seconds (31.47 k allocations: 3.788 MiB)
^ refresh(view, Symbol(event["table"]), tuple(event["values"]...))

parse: 0.69ms
event handlers: 0.47ms
parse: 2.56ms
render: 27.22ms
roundtrip: 63.21ms
```

We have here ~14ms spent in server code and ~31ms in client code for a total roundtrip of ~63ms. Who taught you math, computer? I guess that must be ~15ms of network and websocket code on either end.

I watched the exchange in wireshark and, weirdly, the server is telling the truth. The dead time must be on the client side.

I am sending two messages though, so let's try combining them into one and see if that helps at all. I might be eating a repaint or something in between the two.

Nope. Still >10ms missing.

I even tried taking all the console writes out of the client. No dice. No idea where that time is hiding.

One last thing I want to try today is specialising code for flows. I timed the individual queries and they add up to about the same amount as the whole flow, so actually this is kinda pointless. But I started so...

``` julia
struct Sequence{T <: Tuple} <: Flow
  flows::T # where T is a tuple of flows
end

function Sequence{T <: Flow}(flows::Vector{T})
  Sequence(tuple(flows...)) # for better specialization
end

@generated function run_flow{T}(flow::Sequence{T}, world::World)
  num_flows = length(T.parameters)
  quote
    $([:(run_flow(flow.flows[$i], world)) for i in 1:num_flows]...)
  end
end
```

So yeah, no difference. Which I knew to expect as soon as I bothered to do the timing. Lesson learned.

Let's try breaking down the times in the Merge flow to see if it's the query that's expensive or the plumbing around it.

I think I'm going crazy. Rather than use the client, I just fired an event from the repl. I'm seeing way fewer allocations across the board:

``` julia
0.000084 seconds (100 allocations: 12.500 KiB)
^ init_flow(world.flow, world)

0.000036 seconds (49 allocations: 3.672 KiB)
^ push!(world.state[event_table], event_row)

0.002866 seconds (2.14 k allocations: 304.063 KiB)
^ run_flow(world.flow, world)

0.000664 seconds (169 allocations: 19.344 KiB)
^ Flows.init_flow(view.compiled.flow, view.world)

0.005942 seconds (5.85 k allocations: 409.500 KiB)
^ Flows.run_flow(view.compiled.flow, view.world)

0.001325 seconds (1.20 k allocations: 64.000 KiB)
^ render(view, old_state, view.world.state)
```

Oh... it's because there is no session defined. Hey, that's also weird. It's managing to make 5.85k allocations to produce 73 empty relations.

I'm going to try moving the merges inside the query where their types are known. Let's see if that helps at all.

Lot's of complexity and some fair code debt created. No change. Dangnabbit.

Where are all those allocations coming from? I wondered if it's from calling Base.invokelatest which must guarantee dynamic dispatch, but moving it from the leaves of the tree to one call at the top caused 10x as many allocations. What is going on?

Hang on, aren't there tools for this?

Running with --track-allocation=all attributes most of the allocation to gallop and co:

```
jamie@machine:~/imp$ cat src/*.mem | sort -h | tail
    15200       $next_lo, c = gallop($column, $var, $lo, $hi, 0)
    30784   typeof(coll)()
    42112   deduped::typeof(columns) = map((column) -> empty(column), columns)
    55056           $body
    73792           $var = $(columns[1])[$(next_los[1])]
   109632   c = -1
   187232           $next_lo, c = gallop($column, $column_rot[$next_lo_rot], $next_lo, $hi, 0)
   208576         $(project(columns, los, his, next_los, next_his, esc(var), body))
   284576     $([:(push!($(Symbol("results_$(clause_ix)_$(var_ix)")), $(esc(var))))
   566752           $([:(($next_hi, _) = gallop($column, $column[$next_lo], $next_lo+1, $hi, 1)) for (next_hi, column, next_lo, hi) in zip(next_his, columns, next_los, his)]...)
```

It might be because my janky changes are breaking the type inference near gallop. Let's try reverting them.

```
jamie@machine:~/imp$ cat src/*.mem | sort -h | tail
     3264   for (output_name, output) in zip(flow.output_names, outputs)
     3520   Relation(deduped, num_keys, Dict{Vector{Int}, typeof(deduped)}(order => deduped))
     3920     columns = tuple(((ix in order) ? copy(column) : empty(column) for (ix, column) in enumerate(relation.columns))...)
     4944   foreach_diff(old_index, new_index, old_index[1:old.num_keys], new_index[1:new.num_keys],
     7040   get!(relation.indexes, order) do
     7856   result_columns::T = tuple((empty(column) for column in old.columns)...)
    30784   typeof(coll)()
    32832       $(results_inits...)
    42112   deduped::typeof(columns) = map((column) -> empty(column), columns)
   195776         $(project(columns, los, his, next_los, next_his, esc(var), body))
```

That's basically the same. This is pretty surprising to me, because project and gallop shouldn't allocate at all, and most of my queries barely allocate to begin with. Something is fishy.

It's also putting a lot on Relation and merge, both of which make sense.

``` julia
function f()
  Data.Relation(([1,2,3], [4,5,6]), 1)
end

@time f()

0.000022 seconds (34 allocations: 2.391 KiB)
0.000010 seconds (22 allocations: 1.516 KiB)
0.000011 seconds (22 allocations: 1.516 KiB)
0.000010 seconds (22 allocations: 1.516 KiB)
```

1.5kb. Huh.

``` julia
function g()
  Data.Relation(([1,2,3], [4,5,6]), 1, Dict{Vector{Int}, Tuple{Vector{Int}, Vector{Int}}}())
end

@time g()

0.031436 seconds (673 allocations: 37.284 KiB)
0.000006 seconds (12 allocations: 1.031 KiB)
0.000007 seconds (12 allocations: 1.031 KiB)
0.000006 seconds (12 allocations: 1.031 KiB)
```

Eg, it's not so bad.

How about merge?

``` julia
function h()
  x = Data.Relation(([1,2,3], [4,5,6]), 1)
  y = Data.Relation(([1,2,3], [4,5,6]), 1)
  merge(x, y)
end

0.161110 seconds (52.11 k allocations: 2.923 MiB)
0.000037 seconds (67 allocations: 4.813 KiB)
0.000033 seconds (67 allocations: 4.813 KiB)
0.000026 seconds (67 allocations: 4.813 KiB)
```

Meh, sounds about right.

Dunno. Too tired to come to conclusions tonight.

### 2017 Jul 19

Handling multiple sessions is mostly bookkeeping. Handling closed sessions is a little harder, and took a while to debug, but nothing interesting.

``` julia
0.000113 seconds (100 allocations: 12.500 KiB)
^ init_flow(world.flow, world)

0.003784 seconds (2.48 k allocations: 264.484 KiB)
^ run_flow(world.flow, world)

0.000741 seconds (159 allocations: 19.031 KiB)
^ Flows.init_flow(view.compiled.flow, view.world)

0.012622 seconds (9.12 k allocations: 1.065 MiB)
^ Flows.run_flow(view.compiled.flow, view.world)

0.012000 seconds (36.69 k allocations: 2.419 MiB)
^ render(view, old_state, view.world.state)

0.030685 seconds (48.96 k allocations: 3.791 MiB)
^ refresh(view, Symbol(event["table"]), tuple(event["values"]...))

parse: 2.22ms
render: 27.93ms
roundtrip: 115.9ms
```

The UI sections only take twice as long to do 10x the work, which further confirms my suspicion that I'm paying a lot of overhead in there somewhere, if I could just track it down.

What next? The UI stuff is still pretty far from being ready for real use, but I also have a ton of code debt in the underlying layers that is making life hard. And further, I know that the next thing I want to work on is graphical interfaces to Imp, which is going to be hard with the syntax-heavy all-at-once compilers I have right now. I need a more compositional query language.

On the other hand, I feel the need for some sort of milestone. Maybe it's worth writing up the UI library in it's current state before moving on to cleaning up code debt.

Ok, I put together a draft that seems reasonable. Meanwhile, I had an idea about how to simplify the rendering somewhat. Instead of diffing each group by hand, I can just spit them into one relation with the group number as the first column.

Bah, it's actually tricky to get the diffs to work right...

Ok, I beat my head against this for a few hours. I think I could get it working, but it would involve some awkward sorting inside `render` and piling everything into `node` would actually cause performance problems with current implementation, which dedupes the whole relation every time something new is added.

But! While I was working on that, I did at least figure out how to remove the gallops in `render`. I wanted to use sibling ids instead of ixes before, but text nodes aren't allow to have ids. But I realized that there is no reason I have to use DOM ids to track things. I can just build a big hashtable of my own.

``` julia
0.000043 seconds (100 allocations: 12.500 KiB)
^ init_flow(world.flow, world)

0.001380 seconds (2.25 k allocations: 341.719 KiB)
^ run_flow(world.flow, world)

0.000191 seconds (159 allocations: 19.031 KiB)
^ Flows.init_flow(view.compiled.flow, view.world)

0.005249 seconds (12.79 k allocations: 2.534 MiB)
^ Flows.run_flow(view.compiled.flow, view.world)

0.004150 seconds (16.63 k allocations: 1.252 MiB)
^ render(view, old_state, view.world.state)

0.011534 seconds (32.34 k allocations: 4.168 MiB)
^ refresh(view, Symbol(event["table"]), tuple(event["values"]...))

parse: 2.37ms
render: 28.04ms
roundtrip: 46.57ms
```

No real performance difference, but I'm much happier with the code.

### 2017 Jul 20

More work on the draft, plus a couple of bugfixes in Todo.jl.

### 2017 Jul 21

I worked on some simple benchmarks to put in the post. It's a bit tricky to frame so that it doesn't come off as claiming to be super-amazing-fast-you-should-use-this-in-your-startup.

Also, I tried to explain the performance and found that I couldn't, so I ended up spending a bunch of time on runtime and allocation profiling, which then inevitably led to optimization.

I found that almost all the time in the code is spent in quicksort, either from indexes or creating relations. A bunch of the remaining time is spent in merging. Now I check to see if things are sorted before sorting them (because queries often accidentally return things in sorted order) and I check if I'm merging against empty relations.

That cut about 50% off the runtime. To get the rest I'm probably going to have to rethink how I store relations. Which was going to be coming down the line when I worked on incremental maintenance anyway.

I'm still probably another day or two away from finishing the draft. Should be up by the end of August at least.

Oh, also it turned out that the dead time is specific to firefox - in chrome that 10-20ms delay doesn't happen.

### 2017 Jul 24

First draft is up. Waiting for feedback on clarity. Will need to do some editing for flow etc in addition.

### 2017 Jul 25

Yet more editing.

### 2017 Jul 26

Yet. More. Editing.

### 2017 Jul 28

And up it goes.

I think I'm reaching the limits of what can usefully be explained with text. Going forwards, I'm going to try creating animated debuggers for everything I build. I suspect it will be a similar amount of effort to the constant rewriting of examples that went into this post but with much more versatility.

### 2017 Aug 4

I spent this week deciding what to work on for the next 3-6 months. I always find this difficult. When I'm actually working on something concrete I find it pretty easy to schedule and prioritize work, but choosing a direction is so open-ended that it's easy to become paralyzed with indecision.

I settled on a somewhat meta- direction. I always complained at Eve that I didn't know who our users were and so didn't have clear goals for design but I've been perpetuating that bad habit in Imp.

I spoke to a couple of people who would be interested in using Imp in their day-to-day work if it were actually ready, and I also went through a bunch of imaginary users.

Long-term, I can divide the desired features into two rough groups:

* Acquiring, exploring and manipulating data (import tools, schemas, visual browser, query editor, graphs etc)
* Deploying stateful, collaborative services (deployment/sharing, persistence, collaborative editing of data and/or code, version control, permissions)

There's a third group that revolves around building websites/apps, which is the current focus of Eve, but I'm much less interested in that. Apps are a means to an end, the end is most often 'shared datastore + reasonable interface' and a big chunk of the time I suspect that that end is better served by some standard interface with the odd plugin rather than requiring people to build all their interactions from scratch. It's the wrong level of abstraction for most day-to-day problems.

That means that my focus on reactivity is probably misplaced. It's really cool and interesting that you can build webapps with a declarative, order-lite language, but it's not actually that relevant to the problems that I'm trying to solve.

Short-term, my immediate goal is to make the current feature set usable, so that I can actually put it in front of people and see what they do with it. I went through an intro for an imaginary friend and made a list of all the places where I had caveats or apologies:

1. syntax is verbose for normalized schemas
2. no support for deletion
3. no support for negation/existentials
4. aggregates are confusing
5. model for state/mutation is a huge hack - requires understanding operational semantics
6. no way to query previous states
7. zero-column relations don't work
8. parsing errors are unhelpful
9. runtime errors are unhelpful and aren't even raised from user code
10. the query compiler is hard to understand/maintain/extend
11. the query compiler has hygiene bugs
12. query compile times are way too long
13. no good way to display relations
14. query language is not composable/extensible
15. order matters in the control flow language, but this is not visually obvious and mistakes are not detected by the compiler

Breaking this down by layer:

* relations (2, 7, 13)
* query execution (3, 4, 7, 9, 10, 11, 12, 14)
* query parsing (1, 3, 4, 8, 9)
* control flow (2, 5, 6, 8, 9, 15)

I'm going to start by replacing the monolithic compiler with a staged interpreter. This directly addresses 10/11/14, will hopefully impact 12 and will make 2/3/4/7/9 easier to fix. It also dictates the interface to relations, which means it's worth doing before 7/13.

It's going to be constantly tempting to try out different query execution strategies and try to improve performance, but I have to keep reminding myself that the prime goal is to improve usability. The current performance is fine, and trying to mix research with refactoring is a recipe for overrunning deadlines and drained motivation. So as much as possible I want to generate more or less the same code as now, just via staging rather than direct codegen.

Random performance diversion:

``` julia
quicksort!((strings, ints)) # 2.415ms
quicksort!((hash.(strings), strings, ints)) # 0.887ms
```

If I only care about having some arbitrary order, I should sort most things by their hashes. Avoids jumping all over memory.

### 2017 Aug 9

Ok, I need to think this out even more.

The whole Imp vision includes:

1. Unified data model
2. Persistence
3. Version control / collaboration / offline editing
4. Query/view language
5. Model of time/change (eg queries across versions)
6. Some way to create UI
7. Good default viewing/exploring/editing UI
8. Good default query/view UI
9. Runs on phone and laptop, without deploy/install step
10. Soft automation / notifications / scheduling

Last year I figured out most of 4. This year I figured out most of 6. I have ideas but am still undecided on 1 and 5.

Old versions of Eve had some crude but good enough solutions to 2. We tried 7 and 8 but it was unconvincing and we backed off.

Currents versions of Eve seem to have settled down on 1,4,5. 6 is there but they seem to be leaning towards something more templatey like me.

Think about the size of other projects. Git = 3. Sqlite = 1,2,4,5. Fieldbook/Airtable/Ragic = 1,2,7.

If one of Fieldbook/Airtable/Ragic was open-source I would have a much better starting platform. Building that would be valuable in its own right, but UI is definitely not my strong point.

If I estimated, based on progress so far, another half year for each of those bullet points, it would take me another four years before this is usable. That's pretty fucking daunting.

Let's constrain the problem. Suppose I wanted to show someone a demo on my phone by the end of this year. That's five months. What could I do in that time?

### 2017 Aug 10

I can't run Julia on my phone. Not natively, not in the browser. So in the long run I need to port this to a different language. Java is the obvious choice for android. Rust would have some complexity overhead, but is nicer for runtime dev and would potentially let me run stuff in the browser too.

I'm considering using sqlite as a starting point. It would let me get up and running without porting all the Imp runtime, and would solve persistence too. But there may be enough unexpected niggles that it's not a time saver overall.

I also have to decide whether to use the android UI or to stick with all-html. The latter will make it easier to support multiple platforms but there is enough of a performance cost that react-native exists.

Speaking of react-native, would that a good way to bridge between Rust and Android?

https://tadeuzagallo.com/blog/react-native-bridge/

Looks like a lot of the setup work is done in the javascript code, and there are also a bunch of queues to make the communication between the Android thread and the JS thread asynchronous.

I found a couple of examples of calling into native libs from react-native, but they are all using the react UI still so it doens't help me figure out the protocol.

https://github.com/caseylmanus/go-react-native

Qt is also available cross-platform, but it doesn't seem to have enough advantages over html to make up for the learning curve. Also none of the Rust bindings seem to be complete.

Looks like nativescript does synchronous bindings:

http://developer.telerik.com/featured/nativescript-works/

Both seem to be pretty complicated. Android has an XML layout thing, so it must have some data-centric way to building UI. Oh, wait:

> For performance reasons, view inflation relies heavily on pre-processing of XML files that is done at build time. Therefore, it is not currently possible to use LayoutInflater with an XmlPullParser over a plain XML file at runtime; it only works with an XmlPullParser returned from a compiled resource (R.something file.)

But maybe?

https://stackoverflow.com/questions/1754714/android-and-reflection

https://stackoverflow.com/questions/16022615/how-to-load-programmatically-a-layout-xml-file-in-android

More react native internals:

https://medium.com/@rotemmiz/react-native-internals-a-wider-picture-part-1-messagequeue-js-thread-7894a7cba868

https://medium.com/@jondot/debugging-react-native-performance-snoopy-and-the-messagequeue-fe014cd047ac

https://github.com/facebook/react-native/blob/cb313569e526353a71755a6e40a78713e2d4e454/Libraries/BatchedBridge/MessageQueue.js

So it looks like I *can* call arbitrary stuff across their bridge. But that won't give me access to layout or anything useful like that, because that's partially managed by js and partially by another native module. I don't think I can reuse this usefully.

No decision reached yet, but I have at least a good idea of what the options are:

* webview - familiar, but every major app has moved away from hybrid
* react native - lots of complexity, probably too hard to glue together wihout using their entire renderer
* native and jni - simple, but requires hand-coding or reflection for api

I'm leaning towards the latter. It will at least give me simple apps with a sensible complexity load.

### 2017 Aug 13

Got the Rust tools installed and semi-working. VS Code seems to be the best supported editor. Had to install https://fonts.google.com/download?family=Droid%20Sans%20Mono to make it readable.

### 2017 Aug 16

Somewhat paralyzed by data model decisions. LBs [constructor predicates](https://developer.logicblox.com/content/docs4/core-reference/html/index.html#predicates-constructors) and Eves entities-as-a-bag-of-AVs both effectively allow constructing algebraic datatypes, the lack of which often makes life hard in SQL.

There is a natural symettry between the two. Entities-as-a-bag-of-AVs allows building n-way relationships out of the 2-way relationships that EAV provides. Relational models allow n-way relationships from the start, but if you want to do any metaprogramming you're going to end up with some sort of column-n-of-row function, which is effectively interpreting the relational model as it would be implemented in EAV.

Neither lends itself more to a particular level of structure. A relational model could just be a set of arbitrary-length named tuples. An EAV model could require types for every entity and attribute.

Both require information about relationship caridinality to be expressed separately too (although I suppose an EAV model where is always many-to-one is possible, I've never seen it in practice).

A downside of EAV as it is normally practiced is that you can only say things about entities, so if the natural key for a domain is, say, a string, you must create entities with a string AV. If the same string is used somewhere else but not constructed into an entity in the same way, you don't get equality.

But this might actually be useful in a GUI, because it tells you whether various string-valued KVs should be displayed together. It's much like creating a table with a single string column and then using it as a foreign key. I'd wager that in most actual applications, strings tend to name some real entity. It's only in programming where we abstract enough to consider as string as a thing in it's own right, say for string processing functions in the stdlib. (Does Eve treat functions as relations? Not really, but it also doesn't have many functions atm.)

Let's just do something.

``` rust
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Entity {
    values: Vec<(Attribute, Value)>,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Attribute {
    name: String,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
enum Value {
    Entity(Entity),
    Attribute(Attribute),
    String(String),
}

struct Data {
    eav: Vec<(Entity, Attribute, Value)>,
}

impl Data {
    fn add_eav(self:&mut Self, entity:Entity, attribute:Attribute, value:Value) {
        self.eav.push((entity, attribute, value));
    }

    fn add_e(self:&mut Self, entity:Entity) {
        for (attribute, value) in entity.values.clone() {
            self.add_eav(entity.clone(), attribute, value);
        }
    }
}
```

Don't think about performance at all yet. Just keep moving.

I want to print stuff out in nice tables. So there needs to be some kind of schema info.

``` rust
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Kind {
    name: String,
    attributes: Vec<Attribute>,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Entity {
    kind: Kind,
    values: Vec<Value>,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Attribute {
    name: String,
    kind: Kind,
}
```

It ought to be reflected into the db eventually, but right now it doesn't matter.

Some messy printing code.

``` rust

impl Debug for Data {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        let mut extra_attributes: HashMap<&Kind, HashSet<&Attribute>> = HashMap::new();
        let mut rows: HashMap<&Kind, HashMap<&Entity, HashMap<&Attribute, &Value>>> =
            HashMap::new();

        for &(ref e, ref a, ref v) in &self.eav {
            if !a.kind.attributes.contains(a) {
                extra_attributes
                    .entry(&a.kind)
                    .or_insert_with(|| HashSet::new())
                    .insert(a);
            }
            rows.entry(&e.kind)
                .or_insert_with(|| HashMap::new())
                .entry(e)
                .or_insert_with(|| HashMap::new())
                .insert(a, v);
        }

        f.write_str("Data {\n")?;
        for (kind, kind_extra_attributes) in extra_attributes {
            f.write_str(&kind.name)?;
            f.write_str("\n")?;
            for _ in 0..kind.name.len() {
                f.write_str("-")?;
            }
            f.write_str("\n")?;
            let attributes: Vec<&Attribute> = kind.attributes
                .iter()
                .chain(kind_extra_attributes.into_iter())
                .collect();
            for a in &attributes {
                f.write_str(&a.name)?;
                f.write_str(" ")?;
            }
            f.write_str("\n")?;
            let data = rows.get(kind).unwrap();
            for (_, as_to_vs) in data {
                for a in &attributes {
                    match as_to_vs.get(a) {
                        Some(value) => value.fmt(f)?,
                        None => f.write_str("_")?,
                    }
                    f.write_str(" ")?;
                }
                f.write_str("\n")?;
            }
            f.write_str("\n")?;
        }
        f.write_str("}")?;
        Result::Ok(())
    }
}
```

And then I realize that I made mutually recursive types, and this is rust land so we can't tie the knot.

``` rust
  let mut data = Data::new();
  let mut person = Kind{name: "Person".into(), attributes: vec![]};
  let mut national_insurance = Attribute{name: "national insurance".into, kind: person.clone()};
  // TODO tie the knot
  data.add_e()
  println!("{:?}", data);
```

Gonna have to reflect stuff after all.

### 2017 Sep 7

Ah, missed *some* days.

Rusty Imp is coming along slowly.

Spent some time investigating TiddlyWiki.

Today, playing with sonic-pi. Have to build from source to get the latest version (which has mic input).

```
sudo apt-get purge libaubio4*
sudo apt-get install libsndfile-dev
build-ubuntu-app

qjackctl &
# hit run
./sonic-pi
```

hangs on splash screen

```
sudo pkill -9 jack
sudo pasuspender -- jackd -R -d alsa
```

there is a `<defunct> scsynth` hanging around so maybe it's not starting correctly?

but I can start it just fine by itself:

```
jamie@machine:~$ scsynth -u 10000
Found 0 LADSPA plugins
*** ERROR: open directory failed '/home/jamie/.local/share/SuperCollider/synthdefs'
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
JackDriver: client name is 'SuperCollider'
SC_AudioDriver: sample rate = 48000.000000, driver's block size = 1024
Cannot use real-time scheduling (RR/5)(1: Operation not permitted)
JackClient::AcquireSelfRealTime error
SuperCollider 3 server ready.
Zeroconf: registered service 'SuperCollider'
```

Ok, found some log files:

```
==> /home/jamie/.sonic-pi/log/processes.log <==
No pids store found here: /tmp/sonic-pi-pids
Exiting

==> /home/jamie/.sonic-pi/log/gui.log <==
[GUI] - Detecting port numbers...
[GUI] - GUI OSC listen port 4558
[GUI] -    port: 4558 [OK]
[GUI] - Server OSC listen port 4557
[GUI] -    port: 4557 [OK]
[GUI] - Server incoming OSC cues port 4559
[GUI] -    port: 4559 [OK]
[GUI] - Scsynth port 4556
[GUI] -    port: 4556 [OK]
[GUI] - Server OSC out port 4558
[GUI] - GUI OSC out port 4557
[GUI] - Scsynth send port 4556
[GUI] - Erlang router port 4560
[GUI] -    port: 4560 [OK]
[GUI] - OSC MIDI out port 4561
[GUI] -    port: 4561 [OK]
[GUI] - OSC MIDI in port 4562
[GUI] -    port: 4562 [OK]
[GUI] - Init script completed
[GUI] - using default editor colours
[GUI] - launching Sonic Pi Server:
[GUI] - starting UDP OSC Server on port 4558...

==> /home/jamie/.sonic-pi/log/server-output.log <==

==> /home/jamie/.sonic-pi/log/gui.log <==

==> /home/jamie/.sonic-pi/log/server-errors.log <==

==> /home/jamie/.sonic-pi/log/gui.log <==
[GUI] - UDP OSC Server ready and listening

==> /home/jamie/.sonic-pi/log/debug.log <==

==> /home/jamie/.sonic-pi/log/processes.log <==
Creating pids store: /tmp/sonic-pi-pids
Started [2382] [-] ruby -E utf-8 /home/jamie/sonic-pi-3.0.1/app/gui/qt/../../../app/server/bin/sonic-pi-server.rb -u 4557 4558 4556 4556 4559 4560 4561 4562 [-] /tmp/sonic-pi-pids/2382

==> /home/jamie/.sonic-pi/log/gui.log <==
[GUI] - Ruby server pid registered: 2382
[GUI] - waiting for Sonic Pi Server to boot...

==> /home/jamie/.sonic-pi/log/server-output.log <==
Sonic Pi server booting...
Using protocol: udp
Detecting port numbers...
Send port: 4558
Listen port: 4557
  - OK
Scsynth port: 4556
  - OK
Scsynth send port: 4556
  - OK
OSC cues port: 4559
  - OK
Erlang port: 4560
  - OK
OSC MIDI out port: 4561
  - OK
OSC MIDI in port: 4562
  - OK
Booting server...


Booting Sonic Pi
----------------

Booting on Linux
Jackd not running on system. Starting...
tail: '/home/jamie/.sonic-pi/log/scsynth.log' has become inaccessible: No such file or directory
tail: '/home/jamie/.sonic-pi/log/scsynth.log' has appeared;  following new file
Boot - Starting the SuperCollider server...
Boot - scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096

==> /home/jamie/.sonic-pi/log/debug.log <==

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot connect to server socket err = No such file or directory
Cannot connect to server request channel

==> /home/jamie/.sonic-pi/log/processes.log <==
Started [2406] [-] scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096 [-] /tmp/sonic-pi-pids/2406

==> /home/jamie/.sonic-pi/log/server-output.log <==
Started [2406] [-] scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096 [-] /tmp/sonic-pi-pids/2406

==> /home/jamie/.sonic-pi/log/scsynth.log <==
# Starting SuperCollider 2017-09-07 15:59:48
Found 0 LADSPA plugins

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot create RT messagebuffer thread: Operation not permitted (1)
Retrying messagebuffer thread without RT scheduling
Messagebuffer not realtime; consider enabling RT scheduling for user
no message buffer overruns
Cannot create RT messagebuffer thread: Operation not permitted (1)
Retrying messagebuffer thread without RT scheduling
Messagebuffer not realtime; consider enabling RT scheduling for user
no message buffer overruns
Cannot create RT messagebuffer thread: Operation not permitted (1)
Retrying messagebuffer thread without RT scheduling
Messagebuffer not realtime; consider enabling RT scheduling for user
no message buffer overruns

==> /home/jamie/.sonic-pi/log/scsynth.log <==
jackdmp 1.9.11
Copyright 2001-2005 Paul Davis and others.

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot lock down 82274202 byte memory area (Cannot allocate memory)

==> /home/jamie/.sonic-pi/log/scsynth.log <==
Copyright 2004-2014 Grame.
jackdmp comes with ABSOLUTELY NO WARRANTY
This is free software, and you are welcome to redistribute it
under certain conditions; see the file COPYING for details
JACK server starting in realtime mode with priority 10
self-connect-mode is "Don't restrict self connect requests"
audio_reservation_init
Acquire audio card Audio0
creating alsa driver ... hw:0|hw:0|1024|2|44100|0|0|nomon|swmeter|-|32bit
configuring for 44100Hz, period = 1024 frames (23.2 ms), buffer = 2 periods
ALSA: final selected sample format for capture: 32bit integer little-endian
ALSA: use 2 periods for capture
ALSA: final selected sample format for playback: 32bit integer little-endian
ALSA: use 2 periods for playback

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot use real-time scheduling (RR/10)(1: Operation not permitted)
AcquireSelfRealTime error
Cannot lock down 82274202 byte memory area (Cannot allocate memory)

==> /home/jamie/.sonic-pi/log/scsynth.log <==
JackDriver: client name is 'SuperCollider'
SC_AudioDriver: sample rate = 44100.000000, driver's block size = 1024

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot use real-time scheduling (RR/5)(1: Operation not permitted)
JackClient::AcquireSelfRealTime error

==> /home/jamie/.sonic-pi/log/scsynth.log <==
SuperCollider 3 server ready.

==> /home/jamie/.sonic-pi/log/server-output.log <==
Boot - SuperCollider booted successfully.
Boot - Connecting to the SuperCollider server...
Boot - Sending /status to server: 127.0.0.1:4556
Boot - Receiving ack from scsynth
Boot - Server connection established

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot lock down 82274202 byte memory area (Cannot allocate memory)

==> /home/jamie/.sonic-pi/log/scsynth.log <==
JackDriver: max output latency 46.4 ms

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
ERROR system_capture_1 not a valid port
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
ERROR system_capture_2 not a valid port
JackEngine::XRun: client = SuperCollider was not finished, state = Running
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
JackEngine::XRun: client = SuperCollider was not finished, state = Triggered
JackAudioDriver::ProcessGraphAsyncMaster: Process error
Unknown error...
terminate called after throwing an instance of 'Jack::JackTemporaryException'
  what():

==> /home/jamie/.sonic-pi/log/gui.log <==
............................................................
[GUI] - Critical error! Could not boot Sonic Pi Server.
```

Looks like Jack is sad?

No, that's apparently just caused by it's parent exiting - <http://jack-audio.10948.n7.nabble.com/Re-LAU-jackd-terminates-on-its-own-td19503.html>. So the problem is elsewhere.

With `pasuspender -- jackd -R -d alsa`

```
==> /home/jamie/.sonic-pi/log/processes.log <==


Clearing pids: ["2406", "2382"]

Clearing [2406]
  -- command scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096
  -- removing /tmp/sonic-pi-pids/2406
  -- unable to get ProcTable info for: 2406
  -- process: 2406 not running

Clearing [2382]
  -- command ruby -E utf-8 /home/jamie/sonic-pi-3.0.1/app/gui/qt/../../../app/server/bin/sonic-pi-server.rb -u 4557 4558 4556 4556 4559 4560 4561 4562
  -- removing /tmp/sonic-pi-pids/2382
  -- unable to get ProcTable info for: 2382
  -- process: 2382 not running

Finished clearing pids


==> /home/jamie/.sonic-pi/log/gui.log <==
[GUI] - Detecting port numbers...
[GUI] - GUI OSC listen port 4558
[GUI] -    port: 4558 [OK]
[GUI] - Server OSC listen port 4557
[GUI] -    port: 4557 [OK]
[GUI] - Server incoming OSC cues port 4559
[GUI] -    port: 4559 [OK]
[GUI] - Scsynth port 4556
[GUI] -    port: 4556 [OK]
[GUI] - Server OSC out port 4558
[GUI] - GUI OSC out port 4557
[GUI] - Scsynth send port 4556
[GUI] - Erlang router port 4560
[GUI] -    port: 4560 [OK]
[GUI] - OSC MIDI out port 4561
[GUI] -    port: 4561 [OK]
[GUI] - OSC MIDI in port 4562
[GUI] -    port: 4562 [OK]
[GUI] - Init script completed
[GUI] - using default editor colours
[GUI] - launching Sonic Pi Server:

==> /home/jamie/.sonic-pi/log/server-output.log <==

==> /home/jamie/.sonic-pi/log/server-errors.log <==

==> /home/jamie/.sonic-pi/log/gui.log <==
[GUI] - starting UDP OSC Server on port 4558...
[GUI] - UDP OSC Server ready and listening

==> /home/jamie/.sonic-pi/log/debug.log <==

==> /home/jamie/.sonic-pi/log/processes.log <==
Started [3058] [-] ruby -E utf-8 /home/jamie/sonic-pi-3.0.1/app/gui/qt/../../../app/server/bin/sonic-pi-server.rb -u 4557 4558 4556 4556 4559 4560 4561 4562 [-] /tmp/sonic-pi-pids/3058

==> /home/jamie/.sonic-pi/log/gui.log <==
[GUI] - Ruby server pid registered: 3058
[GUI] - waiting for Sonic Pi Server to boot...

==> /home/jamie/.sonic-pi/log/server-output.log <==
Sonic Pi server booting...
Using protocol: udp
Detecting port numbers...
Send port: 4558
Listen port: 4557
  - OK
Scsynth port: 4556
  - OK
Scsynth send port: 4556
  - OK
OSC cues port: 4559
  - OK
Erlang port: 4560
  - OK
OSC MIDI out port: 4561
  - OK
OSC MIDI in port: 4562
  - OK
Booting server...


Booting Sonic Pi
----------------

Booting on Linux
tail: '/home/jamie/.sonic-pi/log/scsynth.log' has been replaced;  following new file
Jackd already running. Not starting another server...
Boot - Starting the SuperCollider server...
Boot - scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
Cannot use real-time scheduling (RR/5)(1: Operation not permitted)
JackClient::AcquireSelfRealTime error

==> /home/jamie/.sonic-pi/log/debug.log <==

==> /home/jamie/.sonic-pi/log/processes.log <==
Started [3080] [-] scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096 [-] /tmp/sonic-pi-pids/3080

==> /home/jamie/.sonic-pi/log/server-output.log <==
Started [3080] [-] scsynth -u 4556 -m 131072 -a 1024 -D 0 -R 0 -l 1 -i 16 -o 16 -b 4096 [-] /tmp/sonic-pi-pids/3080

==> /home/jamie/.sonic-pi/log/scsynth.log <==
# Starting SuperCollider 2017-09-07 16:03:36
Found 0 LADSPA plugins
JackDriver: client name is 'SuperCollider'
SC_AudioDriver: sample rate = 48000.000000, driver's block size = 1024
SuperCollider 3 server ready.

==> /home/jamie/.sonic-pi/log/server-output.log <==
Boot - SuperCollider booted successfully.
Boot - Connecting to the SuperCollider server...
Boot - Sending /status to server: 127.0.0.1:4556
Boot - Receiving ack from scsynth
Boot - Server connection established

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot lock down 82274202 byte memory area (Cannot allocate memory)

==> /home/jamie/.sonic-pi/log/scsynth.log <==
JackDriver: max output latency 42.7 ms

==> /home/jamie/.sonic-pi/log/server-errors.log <==
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
ERROR system_capture_1 not a valid port
Cannot lock down 82274202 byte memory area (Cannot allocate memory)
ERROR system_capture_2 not a valid port

==> /home/jamie/.sonic-pi/log/gui.log <==
............................................................
[GUI] - Critical error! Could not boot Sonic Pi Server.
```

Already spent a few hours on this and it looks like Sam is drowning in linux support requests, so let's just stick with 2.8 for a while.

And now my sound doesn't work.

### 2017 Sep 11

Yesterday I got a basic compiler and parser working and hooked it up the the UI.

Not super keen on Nom for parsing - code is hard to read and error messages are hard to deal with. I tried Pest too, but it was a pain to set up and the documentation is not illuminating.

Today is a tooling day. I'm getting really annoyed by unreliable tools, feature churn and broken muscle memory. Pretty much all the main tools I use day-to-day have serious issues. I want tools that are reliable and responsive and will still be here in five years time. I think the most likely way to achieve that is to avoid monolithic tools as much as possible. I shouldn't have to switch editors to get support for a new language.

I upgraded Ubuntu. I was planning to stay on 16.04 for a while longer, but it's getting increasingly hard to build code that relies on having newish header files around. Took most of the day, but nothing major seems to have broken.

Unity has been discontinued and will be replaced by Gnome 3 in November. I mostly use it for the nicely animated window manager. Some of the window management shortcuts are timing dependent - they do different things depending on whether or not the menu UI popped up in time. I used to use i3. I still have my old config. Switching back is a relief.

Gnome-terminal takes a couple of seconds to start. I often use disposable terminals, so that's annoying. st doesn't support deleting with the delete key. Terminology has insane UI. Xfce4-terminal starts faster than I can continue typing. Alacritty is even faster and feels like it has less typing latency, but it doesn't support mouse scrolling or copy/paste. Sakura feels equally fast and doesn't seem to be missing anything obvious.

### 2017 Sep 12

Continuing.

I touch-type, but if I lose position I look at the keyboard. Currently I have a US layout but a German keyboard, so this gives me the wrong answer. I bought a plastic marker to black out the keys and installed a typing tutor, which I'll practice with on tools days.

I used emacs for a long time, and then sublime because after a summer holiday I had forgetten 5+ years of emacs knowledge, and then atom for the Julia plugin and now visual studio code for the Rust plugin. The latter two are both unpleasant. Atom is slow enough that it messes with my typing. VSC has a ton of weird bugs like randomly jumping to the end of the file every few minutes, and it wastes a lot of screen space. Neither can handle opening the same file in multiple windows.

What do I want?

* Low latency, reliable interaction - no pauses for autocomplete or highlighting
* Multiple cursors
* Open same file in multiple windows
* Easy to extend

Atom:

* journal - ~20s, unusable, with highlighting off is merely laggy
* main.rs - typing is ok
* multiple cursors - yes
* multiple views - yes, but only within one window
* other - interactions other than typing feel laggy

VSC:

* journal - ~2s, typing is ok
* main.rs - typing with completions is ok
* multiple cursors - yes
* multiple views - only within one window
* other - some weird interaction bugs eg sometimes randomly jumps to the bottom of the file

Intellij:

* journal - even with zero latency mode I can start typing, go make a cup of tea, and still have characters appearing when I get back
* main.rs - typing on a single line is ok, inserting or deleting lines is ~1s, completions can't keep up with typing

Brackets:

* couldn't install - missing crypto libs on ubuntu 17.04

Howl:

* journal - opens instantly, highlighting is fast, completions have to be turned off
* main.rs - lexing broken, typing with completions is laggy, otherwise smooth
* multiple cursors - no
* multiple views - only within one window
* other - really nice ui for commands, completions are fast everywhere except in editor window, outline view is nice but slightly broken for markdown

Kakoune:

* journal - ~5s, unusable with highlighting on, typing with completions is laggy, smooth with both off
* main.rs - opens instantly, typing with completions is laggy
* multiple cursors - designed around them
* multiple views - yes, client-server
* other - really interesting multiple-cursor mechanisms, tries to be self-documenting, like the i3-style unixy extensions, probably high learning curve

Geany:

* journal - opens instantly, typing is smooth with highlighting (no completions)
* main.rs - opens instantly, typing is smooth with highlighting and completions
* multiple cursors - no
* multiple views - no

Textadept:

* journal - opens instantly, typing is smooth with highlighting (no completions)
* main.rs - opens instantly, typing is smooth with highlighting (no completions)
* multiple cursors - as a package which I didn't test
* multiple views - only within same window, occasionally feel out of sync
* other - rust module doesn't seem to work at all but generates no error messages

Neovim:

* journal - opens instantly, typing is smooth with highlighting (no completions)
* main.rs - opens instantly, typing is smooth with highlighting (no completions)
* multiple cursors - as a package which I didn't test
* multiple views - only within same window (despite client-server arch)
* other - couldn't get language server plugin installed to test completions, probably high learning curve

Sublime:

* journal - opens instantly, typing is smooth (no completions), highlighting is broken
* main.rs - opens instantly, typing is smooth with highlighting, laggy with completions
* multiple cursors - the original?
* multiple views - yes, but you have to explicitly ask for it or you'll get two copies

Kakoune and Howl are the most promising, but either would need some serious work before being usable. I'll stick with VSC for now but try writing an extension for both Kakoune and Howl next week.

### 2017 Sep 13

Need to figure out syntax. Currently just have 'e a v' but I need to handle creating new entities, and I want to handle chaining attributes and functions too.

Previous version of Imp just had relations, but for modelling I think it's worth separating into entities and attributes. Can treat entity creation as function from args to id, and then use the same syntax for functions in general.

Just need a way to distinguish between creating to an entity and asking if one exists.

Didn't really get anywhere - got derailed again with indecision about how to approach this project.

Poked at more editors in the evening.

Emacs:

* journal - opens instantly, scrolling is laggy, typing is smooth with highlighting, laggy if completions are turned on
* main.rs - opens instantly, typing is smooth with highlighting and completions from racer
* multiple cursors - as a package which I didn't test
* multiple views - yes, via emacsclient -t
* other - keep getting caught in M-x with the modal time-delayed error screen

I played around a bit with config and extra packages and I'm actually pretty happy with my setup already. 

It's funny how the old muscle memory comes back, but I think I'll probably heavily alter the keys to be more CUA-like. It's all very well having a million commands at your fingertips, but I'll probably only remember ten of them and then hit all the rest by accident. Not to mention being unable to use any other program if I redevelop that muscle memory.

### 2017 Sep 18

Put together a little live-coding plugin for Imp, where the editor sends code to the Imp server as you type, and sends cursor position so you can ask questions by pointing at things. 

Unfortunately way too slow to be a pleasant experience. Bunch of that is plumbing problems, but even with that out of the way it's taking 2s to run the TodoMVC UI tick. Which is really weird, because it was ~9ms back when I finished working on it. Did I break something?

### 2017 Sep 19

Sketched out a staged query compiler for the Julia version of Imp, but in the end I'm starting to add up just how much time I've spent working around the limitations of Julia and questioning whether it makes sense for my current goals. Right now I just want to get something running that I can use myself, with a live, responsive UI. 

So I cloned the same live-coding plugin for the nascent Rust version of Imp. It's way snappier.

Of course, that still leaves a lot of implementation work to get the language up to par with the Julia version...

### 2017 Sep 20

Started trying to implement constants and functions but got bogged down in details. Ended up refactoring the compiler a ton. In a better position for functions now, but I kinda resent the loss of time.

### 2017 Sep 21

Got variables and constants working. 

Also improved the error reporting, so that even if the runtime panics I still get a printout of as much of the parsing, compiling and executing as possible. Makes debugging a lot easier.

### 2017 Sep 22

Buried in paperwork and phone calls today. No imp.

### 2017 Sep 25

I've gotten out of the habit of writing here. Backfilled Sep 19 to today.

The interpeter side of functions was pretty easy. 

Could get away with just adding them to the current parser, but I'm going to want to make it more general anyway. Kind of getting fed up with Nom, so I'm just going to recursive descent by hand for the most part. It'll make it easier to return as many errors as possible, rather than just bailing out at the first.

Bogged myself down in design decisions that probably don't matter either way. Still no parser :(

### 2017 Sep 26

More yak-shaving, followed by backing off the whole design and trying to alter things incrementally. As I should have done to begin with.

Radical idea - no breaking changes that take more than one hour.

### 2017 Sep 27

I have a loop somewhere in my parser. 

Rust does not print traces on stack overflow, and it does something gnarly to its stack during overflow that prevents gdb from giving a useful trace. 

I want to wrap the nom combinators in something that will print out the name, but I can't get it to typecheck as a function or to parse as a macro. This shouldn't be hard.

``` rust
fn trace<'a, P, O: 'a>(msg: &str, parser: P) -> impl Fn(&'a [u8]) -> O
where
    P: Fn(&'a [u8]) -> O,
{
    |input| {
        println!("{}", msg);
        parser(input)
    }
}
```

```
error[E0564]: only named lifetimes are allowed in `impl Trait`, but `` was found in the type `[closure@src/main.rs:591:5: 594:6 msg:&&str, parser:&P]`
   --> src/main.rs:587:49
    |
587 | fn trace<'a, P, O: 'a>(msg: &str, parser: P) -> impl Fn(&'a [u8]) -> O
    |    
```

This typechecks, but the nom macros can't handle calling it.

``` rust
fn trace<'a, P: 'static>(msg: &'static str, parser: P) -> impl Fn(&'a [u8]) -> ExprAst + 'static
where
    P: Fn(&'a [u8]) -> ExprAst,
{
    move |input| {
        println!("{}", msg);
        parser(input)
    }
}
```

```
error: no rules expected the token `(`
   --> src/main.rs:627:41
    |
627 | named!(expr_ast(&[u8]) -> ExprAst, trace("expr", do_parse!(
    |                                         ^

error: Could not compile `imp`.
```

Starting to think that maybe using nom was not the pragmatic choice after all.

Worked out where the recursion is by hand. Not impressed. Shit like this is supposed to be what computers are for.

Omg nom is a streaming parser so I have to explicitly tell it for every rule that it's ok to stop at the end of the file. \

Tried using lalrpop. Their own example got bogged down in an infinite loop.

I was really hoping to get this done in one day. Tomorrow, back to hand-written recursive descent. It may be long and gruelling, but at least when it breaks I stand a chance of fixing it.

Ok, nm, I actually managed to hack around it. I'm in a rush to get stuff demoable, so I can come back and make it pretty later.

### 2017 Sep 28

Got the whole compiler working today, functions and all. I planned it out on paper and then sat down and implemented it without changing my mind about anything. Only took about 10 mins of debugging to get all my examples running correctly. Good day. More of this!

### 2017 Sep 29

Bogged down in school stuff today. Debugged moodle, figured out my timetable, read the course handbook. 

[Read stuff](http://scattered-thoughts.net/blog/2017/09/29/notes-on-how-to-become-a-straight-a-student/).

### 2017 Oct 02

School all day. Nothing exciting to report.

### 2017 Oct 03

Got a little done on the flight today. Sketched out my talk for Thursday. Fixed up older Imp examples. Added merging to the rust version, so asserts actually do something now.

Ran into an interesting compiler bug, saved at e31a019afee74866e07ade6c34562a31a2f97844. Will see later if I can narrow it down.

### 2017 Oct 12

Was in Toronto all last week. In school Mon/Tue this week. Wed and a chunk of today got eaten by office setup in my new house. 

Today I started looking at differential dataflow. Frank has a bunch of datalog examples but they all go through the Rust compiler. But he's fairly sure it should be possible to write an interpreter that dynamically builds dataflow graphs without recompiling. I got his graph example working on my machine and made sure I understand how it all works. Seems plausible.

Gonna timebox this to working by the end of next week, and one more week to hook it up to the editor plugin.

### 2017 Oct 13

Thoroughly confused today by rust continuously telling me that some trait wasn't implemented on my type. Turns out, after much head-scratching, that cargo won't always protect you from accidentally depending on two different versions of the same library. So I implemented lib1::Trait and tried to pass it to a library that expected lib2::Trait. The error message that results didn't unpack the impl chain enough to actually name that library, so it was totally unhelpful. Apparently this is a known issue. 

Compiled a simple query by hand, and made some progress towards doing it automatically. Got bogged down for a bit in the mismatch between my stateful interpreter and the stateless dataflow.

### 2017 Oct 16

School all day. Blah.

### 2017 Oct 17

School notes and reading. 

Read [this thing](https://web.princeton.edu/sites/opplab/papers/alteropp09.pdf) about fluency and discounting. Discounting sounds to me like a general purpose excuse for your experiment not working, and large chunks of the citations in the paper look like noise mining.

I realized that I could actually test this by using some fluency mechanism that I can vary continuously. The theory predicts that if I start legible and gradually make it less and less legible, I'll see a fluency effect which gradually increases until the stimulus becomes too obvious and it plummets back to baseline or below.

Mturk person-hours cost about minimum wage, so if I can come up with a task that takes ~10s per question I can get ~60 datapoints per $1. I need to check what the range of effect sizes is in previous questions, but I'm guessing I can get reasonable power for <$100. 

### 2017 Oct 18

Back to dataflow stuff. I got individual queries working in a fairly hacky inefficient way. I naively join blocks together, but I'm not sure how to treat it as an iteration, so that I get a single incrementally maintained store for the eavs rather than a separate store per block.

Maybe I can just index the variables and stream the eavs through.

### 2017 Oct 19 

Bunch of talking with Frank about about indexing. Convinced him that what I want is possible and he went away to try it out. 

### 2017 Oct 20

In the meantime, just trying to understand some example problems:

https://highlyscalable.wordpress.com/2015/03/10/data-mining-problems-in-retail/

https://www.kaggle.com/c/favorita-grocery-sales-forecasting

### 2017 Oct 23

School all day. Bunch of stuff about fluency that I still find dubious. 

### 2017 Oct 24

Mostly got eaten by social stuff and napping. Managed to finish most of my notes and reading, but no time to work on the experiment or prep for the exam next week. Will have to sneak it in somewhere.

### 2017 Oct 25

Finished reading early in the morning. 

Refactored both the interpreter and the dataflow branches so that I can have them as two backends for the same parser/planner/stdlib.

Painful switching from `Cow<Value>` to `Value<'a>` with an internal `Cow<str>`. Not sure if it was a good idea - every time I put a lifetime in a type it ends up causing extra work later on. Already had problems where I can't implement Borrow or ToOwned because the lifetimes don't quite work out. So now I have:

``` rust
impl<'a> Value<'a> {
    // for various reasons, we can't implement Borrow, Clone or ToOwned usefully

    pub fn really_borrow(&'a self) -> Self {
        match self {
            &Value::Boolean(bool) => Value::Boolean(bool),
            &Value::Integer(integer) => Value::Integer(integer),
            &Value::String(ref string) => Value::String(Cow::Borrowed(string.borrow())),
            &Value::Entity(entity) => Value::Entity(entity),
        }
    }

    pub fn really_to_owned(&self) -> Value<'static> {
        match self {
            &Value::Boolean(bool) => Value::Boolean(bool),
            &Value::Integer(integer) => Value::Integer(integer),
            &Value::String(ref string) => Value::String(Cow::Owned(string.as_ref().to_owned())),
            &Value::Entity(entity) => Value::Entity(entity),
        }
    }
}
```

But this will let me save a lot of storage space in the near future by storing single-type columns and just using `Value` as an interface type inside query execution.

### 2017 Oct 26

Backfilled.

Converted the EAV frontend to a relational system, so that we can use it as a baseline for other projects.

### 2017 Oct 27

Backfilled.

Switched the storage to a relational system too.

### 2017 Oct 30

Backfilled.

School. 

### 2017 Oct 31

Backfilled.

Stats exam. With a calculator and statistical table printouts, like it's the fucking 1800s.

Most of the rest of the day spent using that as an excuse to procrastinate.

### 2017 Nov 1

Backfilled.

Benchmarking infrastructure. Went down some major rabbit hole trying to get the `cargo bench` to run dynamically generated benchmarks. It worked, but it was a mess. Replaced with

``` rust
fn bench<F, T>(name: String, f: F)
    where
        F: Fn() -> T,
    {
        let samples = ::test::bench::benchmark(|b: &mut Bencher| b.iter(&f));
        println!("{} ... {}", name, ::test::fmt_bench_samples(&samples));
    }
    
fn main() {
    let args: Vec<String> = ::std::env::args().into_iter().collect();
    let args: Vec<&str> = args.iter().map(|s| &**s).collect();
    match *args {
        [_, "bench"] => bench::bench_all(),
        ...
    }
}
```

Which is what I should have done the first time.

### 2017 Nov 2

Backfilled.

More benchmark nonsense. After fixing many parser and compiler bugs, I got the first JOB query working. Only 7000x slower than the Julia version.

### 2017 Nov 3

Much of that 7000x slower is probably incorrect. What do I need to check before I'm sure what the actual cost is?

* Allocation-free
* Same join algorithm
* Same number of calls to gallop
* Only dispatch on type once in gallop
* Hand-compiled rust version
* Roughly same cost profile (eg not string ops that are the main difference)

Have some buffers in the join algorithm that are allocated on each step. Pre-allocating those has a small effect.

I'm using trie-join in the Julia version and something that is not even generic-join in the Rust version. I need to at least pick the smallest range to be generic-join. This makes barely any difference, probably because these are all foreign-key joins.

Then I need to gallop each column forwards rather than resetting on each loop. After a few failed attempts, I remember that I didn't do this before because it's really fiddly. Best bet is probably to fake a stack with variable shadowing.

Hang on a minute. I'm including sorting time. Duh... 7x slower. More things to do:

* Separate indexing from running
* Time indexing for Julia version

Ok - fake a stack with variable shadowing. About 2x improvement.

Only dispatch once in type in gallop:

``` rust
fn gallop_le_inner<T1: ::std::borrow::Borrow<T2>, T2: Ord + ?Sized>(
    values: &[T1],
    mut lo: usize,
    hi: usize,
    value: &T2,
) -> usize {
    if lo < hi && values[lo].borrow() < value {
        let mut step = 1;
        while lo + step < hi && values[lo + step].borrow() < value {
            lo = lo + step;
            step = step << 1;
        }

        step = step >> 1;
        while step > 0 {
            if lo + step < hi && values[lo + step].borrow() < value {
                lo = lo + step;
            }
            step = step >> 1;
        }

        lo += 1
    }
    lo
}

fn gallop_le(values: &Values, lo: usize, hi: usize, value: &Value) -> usize {
    match (values, value) {
        (&Values::Boolean(ref bools), &Value::Boolean(ref bool)) => {
            gallop_le_inner(bools, lo, hi, bool)
        }
        (&Values::Integer(ref integers), &Value::Integer(ref integer)) => {
            gallop_le_inner(integers, lo, hi, integer)
        }
        (&Values::String(ref strings), &Value::String(ref string)) => {
            gallop_le_inner(strings, lo, hi, string.as_ref())
        }
        _ => panic!("Type error: gallop {} in {:?}", value, values),
    }
}
```

About 30% faster.

Let's get the indexing separated from running so I can profile this properly.

```
pub struct Prepared {
    indexes: Vec<Relation>,
    ranges: Vec<LoHi>,
    locals: Vec<LoHi>,
    buffers: Vec<LoHi>,
}

pub fn prepare_block(block: &Block, db: &DB) -> Result<Prepared, String> 

pub fn run_block(block: &Block, prepared: &mut Prepared) -> Result<Vec<Value<'static>>, String> 
```

Can benchmark it properly now. 1.61ms vs 1.28ms for the julia version.

Figured out how to do conditional logging: `RUST_LOG='imp=debug'`

Figured out how to get valgrind to instrument only a specific functions: `RUST_BACKTRACE=1 valgrind --tool=callgrind --callgrind-out-file=callgrind.out --collect-atstart=no "--toggle-collect=imp::interpreter::run_block" target/release/imp profile`

(EDIT: Nope, that doesn't seem to be the right function name. Nothing collected.)

Tried to port some more queries but got bitten by a compiler bug I already knew about. I key stuff by exprs, but there can be duplicate exprs that get grouped together and mess with the variable ordering. In this case I have two things `= true` that should be executed separately. Fixing it is too involved for today though.

Stuff left to do:

* Fix compiler bug
* Fix the need to write `= true` for top-level functions
* Port more queries
* Add automatic tests for queries
* Profile Rust and Julia version
* Hand-compiled Rust version

List of remaining differences:

* Different string ops
* Imp-J uses TrieJoin, Imp-R uses GenericJoin
* Imp-J does early return
* Imp-J sorts and dedups output
* Imp-R has to clone output strings
* Imp-J uses a slightly more complicated array structure for columns
* Different sorting algorithms (only matters for indexing)

For callgrind, about 20m / 300 calls to gallop per Imp-R run of q1a. Can compare that to Imp-J next week.

### 2017 Nov 06

Holiday.

### 2017 Nov 07

School stuff in theory, procrastination in practice. Mostly reading through 'Principles: Life and Work'.

### 2017 Nov 08

Hand-compiling q1a today. Idea is to take the Prepared struct from the interpreter and then hand-write the loops based on the existing plan:

``` rust
pub fn q2c(
    prepared: &Prepared,
) -> (Vec<i64>, Vec<i64>, Vec<i64>, Vec<String>, Vec<i64>, Vec<i64>) {

    let mut results_k = vec![];
    let mut results_mk = vec![];
    let mut results_t = vec![];
    let mut results_title = vec![];
    let mut results_mc = vec![];
    let mut results_cn = vec![];

    let keyword_keyword0 = &prepared.indexes[0].columns[0].as_integers();
    let keyword_keyword1 = &prepared.indexes[0].columns[1].as_strings();
    let movie_keyword_keyword0 = &prepared.indexes[1].columns[0].as_integers();
    let movie_keyword_keyword1 = &prepared.indexes[1].columns[1].as_integers();
    let movie_keyword_movie0 = &prepared.indexes[2].columns[0].as_integers();
    let movie_keyword_movie1 = &prepared.indexes[2].columns[1].as_integers();
    let title_title0 = &prepared.indexes[3].columns[0].as_integers();
    let title_title1 = &prepared.indexes[3].columns[1].as_strings();
    let movie_companies_movie0 = &prepared.indexes[4].columns[0].as_integers();
    let movie_companies_movie1 = &prepared.indexes[4].columns[1].as_integers();
    let movie_companies_company0 = &prepared.indexes[5].columns[0].as_integers();
    let movie_companies_company1 = &prepared.indexes[5].columns[1].as_integers();
    let company_name_country_code0 = &prepared.indexes[6].columns[0].as_integers();
    let company_name_country_code1 = &prepared.indexes[6].columns[1].as_strings();

    let keyword_keyword_range = (0, keyword_keyword0.len());
    let movie_keyword_keyword_range = (0, movie_keyword_keyword0.len());
    let movie_keyword_movie_range = (0, movie_keyword_movie0.len());
    let title_title_range = (0, title_title0.len());
    let movie_companies_movie_range = (0, movie_companies_movie0.len());
    let movie_companies_company_range = (0, movie_companies_company0.len());
    let company_name_country_code_range = (0, company_name_country_code0.len());

    narrow(company_name_country_code1, company_name_country_code_range, "[sm]", |company_name_country_code_range| {
        narrow(keyword_keyword1, keyword_keyword_range, "character-name-in-title", |keyword_keyword_range| {
            // k
            join2(keyword_keyword0, movie_keyword_keyword1, keyword_keyword_range, movie_keyword_keyword_range, |keyword_keyword_range, movie_keyword_keyword_range| {
                // mk
                join2(movie_keyword_keyword0, movie_keyword_movie0, movie_keyword_keyword_range, movie_keyword_movie_range, |movie_keyword_keyword_range, movie_keyword_movie_range| {
                    // t
                    join3(movie_keyword_movie1, title_title0, movie_companies_movie1, movie_keyword_movie_range, title_title_range, movie_companies_movie_range, |movie_keyword_movie_range, title_title_range, movie_companies_movie_range| {
                        // title
                        join1(title_title1, title_title_range, |title_title_range| {
                            // mc
                            join2(movie_companies_movie0, movie_companies_company0, movie_companies_movie_range, movie_companies_company_range, |movie_companies_movie_range, movie_companies_company_range| {
                                // cn
                                join2(movie_companies_company1, company_name_country_code0, movie_companies_company_range, company_name_country_code_range, |movie_companies_company_range, _company_name_country_code_range| {
                                    results_k.push(keyword_keyword0[keyword_keyword_range.0]);
                                    results_mk.push(movie_keyword_keyword0[movie_keyword_keyword_range.0]);
                                    results_t.push(movie_keyword_movie1[movie_keyword_movie_range.0]);
                                    results_title.push(title_title1[title_title_range.0].clone());
                                    results_mc.push(movie_companies_movie0[movie_companies_movie_range.0]);
                                    results_cn.push(movie_companies_company1[movie_companies_company_range.0]);
                                });
                            });
                        });
                    });
                });
            });
        });
    });

    (
        results_k,
        results_mk,
        results_t,
        results_title,
        results_mc,
        results_cn,
    )
}
```

For q1a and q2c the results are similar - about 30% overhead. Seems likely that the cost of joins is high enough that the overhead of one dispatch per loop is not a big deal. 

I suspect that scalar functions might be more of a big deal though, so I tried a polynomial over two vectors too. Closer to 10x overhead, so that's a problem.

Options:

* Collect intermediate results whenever switching between joins and functions, so the interpreter overhead is only paid once. Still have cost of intermediate results for nested scalars.
* JIT-compile scalars so they know exactly where on the stack to look. Less complicated that JITing entire queries - only have to arrange data so we can probably get away with just emitting LLVM bitcode.

Can combine the two for extra points.

Also - currently have `Vec<Value>` as the variable stack, but would it make more sense to segment it by type instead?

### 2017 Nov 09

Let's try hardcoding the polynomial as a single function, to get an idea of how much JITing it would help.

```
baseline	polynomial ...  10,379,060 ns/iter (+/- 1,391,015)
compiled	polynomial ...  26,416,195 ns/iter (+/- 1,708,934)
interpreted	polynomial ... 295,634,860 ns/iter (+/- 10,519,509)
interpreted	polynomial_magic ... 171,333,423 ns/iter (+/- 5,893,485)
```

That's still pretty slow.

Collect intermediate results and dispatch once?

```
baseline	polynomial ...  10,396,029 ns/iter (+/- 1,289,018)
compiled	polynomial ...  26,617,876 ns/iter (+/- 1,960,687)
compiled	polynomial_intermediate ...  23,427,604 ns/iter (+/- 1,419,429)
interpreted	polynomial ... 298,961,934 ns/iter (+/- 14,059,010)
interpreted	polynomial_magic ... 173,026,472 ns/iter (+/- 9,618,527)
```

Faster. Weirdly. Maybe it's able to vectorize when the math is in it's own loop? I would be surprised.

Also want to try boxing the functions instead of match dispatch. I don't really have any intuition for how that will perform. In my mind dispatching on a tag byte is cheaper than calling a function pointer, but I don't really have any justification for that.

```
compiled	polynomial_boxfn ...  47,058,110 ns/iter (+/- 2,538,917)
interpreted	polynomial_magic ... 172,529,240 ns/iter (+/- 5,891,873)
```

Am surprised.

Is the compiler smart enough to unbox it? Surely not. Let's pull it out of the Prepared just to be sure.

``` rust 
let boxfn = match &block.constraints[3] {
    &Constraint::Apply(_, _, ref function) => function.compile(),
    _ => panic!(),
};
```

```
compiled	polynomial_boxfn ...  44,275,480 ns/iter (+/- 958,181)
interpreted	polynomial_magic ... 184,241,827 ns/iter (+/- 7,196,916)
```

Same results. So what's the deal?

Let's compare it to a near-identical compiled loop with a non-boxed fn, just to make sure we're comparing the right thing.

```
compiled	polynomial_boxfn ...  45,363,566 ns/iter (+/- 780,561)
compiled	polynomial_fn ...  46,074,598 ns/iter (+/- 1,391,750)
interpreted	polynomial_magic ... 185,038,151 ns/iter (+/- 8,161,306)
```

So the actual overhead is elsewhere. There is some extra work for error handling and also a switch on `result_already_fixed`. I tried removing the error handling yesterday (and foolishly didn't write down the results) and only got 270ms -> 210ms. 

But we did find out that the boxfns are not super expensive. Can we set this up so that the only cost at each step is a single boxfn call?

If we move errors out of band - pushing to a error vec rather than returning error - we can opt into them only for fns which need them.

The only additional cost is the fake stack for shared environment, but we can maybe ameliorate that if we are willing to be unsafe.

Another source of overhead in the interpreter - it pushs Value into results rather than i64.

### 2017 Nov 10

Tried staging the whole interpreter by glueing together closures. Made too many changes at once and at least one of them isn't going to work, so I need to roll stuff back a bunch. Sad face.

Must. Learn. Not. To. Change. Everything. At. Once.

### 2017 Nov 13

School! Social cognition, fun stuff, how do emotions work.

### 2017 Nov 14

Much procrastination, but caught up on notes and stats exercises, leaving reading for later in the week.

### 2017 Nov 15

My rust version of GenericJoin is way nicer than the julia version, so I'm porting some of the design improvements back. Will also give some good apples-to-apples comparison of complexity.

My age-old problem of mutable values getting boxed over rears up again, but I realized that using a Ref half-solves the problem. It's still getting heap-allocated, but it at least carries the type across. 

Came up with a really cutesy version that uses generated functions to do most of the heavy lifting, so the compiler just has to generate:

``` julia
const x_range_0 = Range(1, length(x_1) + 1)
const x_range_1 = Range(1, length(x_1) + 1)
const x_range_2 = Range(1, length(x_1) + 1)
const y_range_0 = Range(1, length(y_1) + 1)
const y_range_1 = Range(1, length(y_1) + 1)
const y_range_2 = Range(1, length(y_1) + 1)
const results_x = Int64[]
const results_y = Int64[]
const results_z = Int64[]
const j1 = Join_2(x_1, y_1, x_range_0, y_range_0, x_range_1, y_range_1)
const j2 = Join_1(x_2, x_range_1, x_range_2)
const j3 = Join_1(y_2, y_range_1, y_range_2)
@join(j1) do
  @join(j2) do
    @join(j3) do
      @inbounds x = x_2[x_range_2.lo]
      @inbounds y = y_2[y_range_2.lo]
      push!(results_x, x)
      push!(results_y, y)
      push!(results_z, (x * x) + (y * y) + (3 * x * y))
    end
  end
end
results_z
```

It's a bit slow at the moment though. Have to figure out how to avoid jumping all over the heap.

### 2017 Nov 16

Preparing a talk on my experiments in implementation strategies. Pushing pretty hard to do v0 in Julia.

### 2017 Nov 17

Gave the talk.

### 2017 Nov 20

School stuff. Slow day mostly. Really enjoyed learning about [decision by sampling](https://www.dectech.co.uk/our_company/papers/dectech_2006_decision_by_sampling.pdf).

Read talk slides about [Julia and Fortress](https://www.dropbox.com/s/2d8se4mr4hxrra2/Julia17.pdf?dl=0).

Went through our nascent language spec.

Tried out automatic differentiation in Imp. Seems to work without modification - props to Julia:

``` julia
Pkg.add("ForwardDiff")

using ForwardDiff
using Data
using Query

function vector_to_relation(vector)
  Relation((collect(1:length(vector)), vector), 1)
end

function my_dot(xx, yy) 
  xx = vector_to_relation(xx)
  yy = vector_to_relation(yy)
  zz = @query begin
    @query begin
      xx(i, x)
      yy(i, y)
      z = x*y
      return (i, z)
    end
    return (sum(z),)
  end
  zz.columns[1][1]
end

xx = rand(10)
yy = rand(10)

my_dot(xx, yy)
ForwardDiff.gradient((xx) -> my_dot(xx, yy), xx)
```

### 2017 Nov 21

Missed much of the day sleeping :(

### 2017 Nov 22

Wrote up the attempted staged interpreter in rust.

### 2017 Nov 23

Sketched out design for an extensible compiler for the FAQ problem. 

### 2017 Nov 24

Update julia packages, mostly for the new Juno.

Work from the compiled version I was playing with last week. Similar interface.

I'm not remotely happy with the interface I've come up with for finite functions, but I have a lot to do so I'll just implement it for now and go back to it later. Life was much easier with triejoin, but it's patented :(

Should probably read the taco paper to see how they deal with it. 

...

They have layers of sparse and dense representations per column and they don't use any other representations. Pretty neat though.

Did you know that [you can't use anything in a generated function that creates a closure](https://github.com/JuliaLang/julia/issues/21094#issuecomment-287649747). That's pretty annoying.

I got this working, but it's awfully slow and there is still a big blob of codegen in the middle and it's disappointingly slow compared to the previous version. 162ms vs 35ms on the dumb polynomial example.

Here's a plan:

* Move Ptr{Column} and Ptr{Columns} into RelationFinger and stop carrying funs around
* join_a just handles ixes and rearranging
* join_b handles finding min
* join_c handles looping and calls closure, which just takes fingers and opaque results baton

Bah, hiding things behind pointers [is totally slow](https://discourse.julialang.org/t/speed-and-type-stability-of-unsafe-pointer-to-objref/6478). Also, least helpful reply ever.

Ok, I can't pass stuff around on the stack between functions efficiently. Either everything goes on the heap or I generate one huge function. The latter seems likes it's gonna be a bitch to compose different behaviors, so I guess I should just heap it all. Seems like such a waste though.

### 2017 Nov 27

School. 

### 2017 Nov 28

Stats exam :(

### 2017 Nov 29

So we're going to store fingers on the heap. 

We need some way for type inference to know that at different points in the code, the finger will be pointing at different types of values. Could pass Val{column}, or could split the finger into separate columns. Former is less restrictive on future implementations. Latter avoids looking up the column each time. Returning a different type also works, but it doesn't allow reusing heap allocations. If we explicitly reuse the allocation, it looks a lot like splitting the finger. Let's do that.

It's a bit awkward, because we end up needing n+1 fingers for n columns. The last one is pointing at either an empty relation or a relation with a single zero-column row. I'll use a `Vector{nothing}` for the storage.

Oops, accessing a `Vector{nothing}` produces an undefined reference. Let's use a `Vector{Tuple{}}` instead.

Ok, this implementation with separate fingers works. On the polynomial, it gets 80ms vs 38ms for the monolithic triejoin. That's good enough for now.

### 2017 Nov 30

Need to get a move on. 

AST first. Just handle the simplest case for now:

``` julia
struct Ring{T}
  add::Function
  mult::Function
  one::T
  zero::T
end

struct Call
  fun # function, or anything which implements finite function interface
  args::Vector{Symbol}
end

struct Lambda
  ring::Ring
  vars::Vector{Symbol}
  domain::Vector{Call}
  value::Vector{Symbol}
end
```

Basic compiler for this, emits the right code. Need to figure out how to deal with type inference now, so that I can distinguish between relations and functions.

### 2017 Dec 1

The compiler is becoming a monolith again. A big part of it is that it needs to generate names for all the pre-allocated heap state, rather than just relying on shadowing. 

I wonder if I should push that into the indexes. Then each stage of the search could just take all of the relations and variables as arguments. But that might require allocating a closure inside join. Unless I inline that code into the stage itself.

I pulled back the separate on-stack fingers, and while it works and it makes the compiler somewhat simpler, it's slower (100ms) and I'm not sure to make it work for more complex index structures like be-trees that will need to store node pointers.

Let's think about this systematically. I want to break up the monolithic compiler output into multiple steps. I need to pass state between the steps. 

__Index state__. It's too expensive to heap-allocate on every iteration of a loop. Structures containing heap pointers have to be heap-allocated. Closures that close over state have to be heap-allocated. 

__Variable state__. Closures can't close over stack-allocated state. Inserting heap allocations into math functions prevents optimization (although I can maybe just fuse all scalar functions when intermediate values are not returned).

Part of the reason this is hard is that GenericJoin branches, so I can't just inline code to avoid the overhead of function boundaries. Can I avoid that somehow?

I suppose I can avoid a lot of stack motion by keeping all the fingers for each index in one structure and using the column number to give information to type inference. And then also store all indexes and vars in one heap structure for each query. Or, actually, only the latter really helps.

I guess the former helps with repeated variables within a single relation, because I don't have to worry about which storage to pass to it.

Ok, so I've rebuilt everything with all fingers in one structure per index. It's somewhat faster than the on-stack version (80ms vs 100ms), which baffles me. It's decently concise too, at just over 100 lines for the relation interface.

I have a skeleton of the compiler, which seems to work for joins but can't handle anything else yet. 

Rough todo list:

* Pass/store variables
* Functions
* Repeated variables
* Constants?
* Reduce
* Function vs materialize

## 2017 Dec 04

School.

## 2017 Dec 05

Need to pick an essay topic. Choices are:

1. Is navigation just relational memory? Or is memory just navigation in concept space? Are they mutually exclusive or just manifestations of the same process but studied/named differently?
2. Critically evaluate the concept of fluency as applied to cognition and behaviour.
3. What are the main arguments in the face-specificity debate? Why is this debate important for understanding functional specialisation in the brain?
4. Why does social cognition rely on both cognitive and affective processes?
5. On the one hand, the brain seems to be in the game of optimising beliefs about how its sensations are caused; while, on the other hand, our choices and decisions appear to be governed by value functions and reward. Are these formulations irreconcilable – or is there some underlying imperative that renders perceptual inference and decision-making two sides of the same coin?

I can only think of interesting things to say about 2 and 5. 

Fluency:

* Cognitive ease is hard to define
* No hard link between theory and effect
* Show table of experiments and effects, where directions are inconsistent
* Fragility of effect - does it matter in the real world if it only kicks in when there is no other signal
* P-curve analysis
* Discounting explains too much
* Experiment with continually varying intervention

Free-energy:

* Too loose to be explanatory model in itself?
  * Different priors produce different behavior
  * Are there any strong predictions across priors? Is there any behavior that it doesn't explain?
    * Variable reinforcement
    * Willpower problems
* What makes it different, if anything, from other Bayesian approximations?
  * Penalization of $H(Q)$
* Framework for comparing existing models
  * Are those models actually subsumed eg can all utility functions be encoded as priors?
* Plausible mechanism for implementation
  * Which versions of theory are supported by evidence?

I can reasonably expect to spend about 7 days on this. Max 3000 words, which is pretty short. Fluency seems like an easy grade and can potentially involve running an experiment. Free-energy is much more challenging, in terms of time, space and risk of not figuring out useful results. Grades aren't directly important, so actual attributes are:

Fluency:

* Picking apart vague theory
* Calculating a p-curve
* Running an experiment

Free-energy

* Interesting math
* Potentially novel connections to willpower, variable reinforcement
* Stress of not finishing

### 2017 Dec 06

Todo list from last time:

* Pass/store variables
* Functions
* Repeated variables
* Constants?
* Reduce
* Function vs materialize

Could add an index for functions that stores the output variable, but I suspect it's better to have them on the stack anyway so that the optimizer can reason about them easily. So I'll thread them through the downwards calls.

Hmmm, my hand-compiled version is fine but the version assembled by the compiler has a bajillion allocations. 

Oh, because I'm not typing the output vecs yet. Easily fixed.

Now I need to deal with functions. I think all I need to do is:

* Don't try to permute non-finite functions
* Filter out calls to non-finite functions where the join variable is not the last
* Call `make_seek` instead of `make_join` when there is at least one call to a non-finite function where the join variable is the last

Could do the first either in the compiler or by defining permute sensibly for functions. Latter seems like less work, but now it's fiddly to check whether a given var is the last argument. Probably safer to do former.

Working ast:

``` julia
zz(x, y) = (x * x) + (y * y) + (3 * x * y)

polynomial_ast1 = Lambda(
  Ring{Int64}(+,*,1,0),
  [:x, :y],
  [
    Call(:xx, [:i, :x]),
    Call(:yy, [:i, :y]),
    Call(:zz, [:x, :y, :z]),
  ],
  [:z]
  )
```

Remaining todos:

* Repeated variables - can I handle this as a pass before the compiler?
* Constants - how do I represent these in the ast?
* Reduce - may require nesting query to handle variable order
* Function vs materialize

### 2017 Dec 07

Quick fix for joining on partial functions. Just going to have them return `nothing` rather than a discriminated union, for the sake of easy embedded use.

Repeated variables. Could handle them in the index by making every operation go multiple times, but that requires solving it in every index that I build. Or can just solve it once in the compiler, at the cost of grossing up the joins. Seems like a better tradeoff.

The only tricky part is that non-repeated variables want to be initialized at the start of the loop, so that they benefit from the work done advancing them in each iteration, but repeated variables need to be initialized on every iteration so that they have the correct bounds from their parent. I added some poorly named helper functions:

``` julia
@inline function first_if(bool, index, column)
  if bool
    first(index, column)
  end
end

@inline function seek_if(bool, index, column)
  first_if(bool, index, column)
  seek(index, column)
end
```

Now this works:

``` julia
polynomial_ast2 = Lambda(
  Ring{Int64}(+,*,1,0),
  [:x, :y],
  [
    Call(:xx, [:x, :x]),
    Call(:yy, [:x, :y]),
    Call(:zz, [:x, :y, :z]),
  ],
  [:z]
  )
```

Random sadness: https://github.com/JunoLab/atom-julia-client/issues/400

Constants are easy to represent as zero-arg, inlineable functions. I'll add a pass that makes that transformation before the compiler. I'll also have to handle anonymous functions inside the ast to make that work. 

That was a bit tricky, but it worked out ok. 

``` julia
polynomial_ast3 = Lambda(
    Ring{Int64}(+,*,1,0),
    [:x, :y],
    [
      Call(:xx, [:i, :x]),
      Call(:yy, [:i, :y]),
      Call(*, [:x, :x, :t1]),
      Call(*, [:y, :y, :t2]),
      Call(*, [3, :x, :y, :t3]),
      Call(+, [:t1, :t2, :t3, :z])
    ],
    [:z]
    )
```

Now we're at reduce. Fun times. The actual reduce bit isn't too bad. The main difficulty is with the variable order. In most cases I need to factorize it into two nested reduces.

Once I have the second-order language working I can do this as a rewrite, but for now it will have to be a wrapper around compile.

This is getting gnarly. Maybe it would have been simpler to just add a tail aggregation in the base compiler? But then I would also have to add the early return optimization separately, whereas this way it's always on.

Ah, I'm doing this slightly wrong. I don't want two separate queries because the intermediate query wouldn't return a true relation.. I want to nest two sets of joins, with a different ring in each. Like `aggregate(+, join(&, join(+, ...)))`. Maybe I want to introduce an IR that looks like that as an intermediate step? Doesn't seem necessary right away though - main thing is that to figure out the two different join behaviors, plus the aggregate step at the end. But it might help to write out how early return transforms the IR from naive aggregation to something efficient.

I've got this roughly sketched out on paper. Will implement tomorrow.

### 2017 Dec 08

Thinking now of the compiler output as starting from the pretty factorization, but then we:

* iter over some finite factor to make it tractable
* carry state down to make lookups faster
* carry state up to make factor unions faster

Can I express those as optimizations after emitting the factorization? So the whole process might look like:

* parse
* lower nested expressions
* lower constants
* infer fun types
* infer var types
* choose variable order
* insert indexes
* insert prefixes
* factorize
* thread index state through levels and across iter
* thread either factor state or bound variables (depending on materialize vs function)
* emit code (identifying finite factors at each sumproduct)

Can also separate each iter into separate closure and directly call sum(index, f) rather than looping. (Nope, because then don't know how many args to pass to lower layer).

Need to figure out layers in here too. Not sure if it's going to come out in the classical lower/optimize dichotomy.

I ran a friend through the entire process on a big A1 sheet of paper and it seems to work out. Still a little unsure about how the last two optimizations will be expressed, but it's getting there.

How do I get there from here? Ignore the ring stuff for now and just get the IR working? Can coalesce some of these steps for now, just as long as the overall structure is there and the right info is available at each point.

I'll just walk my way down the stack now.

Parsing and lowering nested exprs doesn't exist yet.

Lowering constants is already a separate pass.

``` julia
function choose_variable_order(lambda::Lambda) ::Vector{Symbol}
  # for now just order variables by order of appearance
  union((call.args for call in lambda.domain)...)
end
```

Have to add the lowering step between 'choose variable order' and 'insert indexes' so that I can use `Let` to create the indexes. Or move 'insert indexes' down to the optimizations? But 'insert prefixes' kind of relies on it. 

This is hard.

I have two very similar IRs that I would like to reconcile, but I'm not sure if it's worth the confusion of the types.

High-level:

``` julia
struct Call
  fun::Union{Symbol, Function} # either global variable or closure
  args::Vector{Union{Symbol, Call, Constant}} 
end

struct Lambda
  ring::Ring
  args::Vector{Symbol}
  domain::Vector{Call}
  value::Vector{Union{Symbol, Call, Constant}}
end
```

Mid-level:

``` julia
struct Call
  fun::Union{Symbol, Function} # either global variable or closure
  args::Vector{Symbol} 
end

struct SumProduct # sum over var of product of values
  ring::Ring
  var::Symbol
  values::Vector{Union{SumProduct, Call, Symbol}}
end

struct Lambda
  args::Vector{Symbol}
  value::Union{SumProduct, Call}
end
```

Really, the main thing that changes is we stop allowing non-Symbol args and we don't distinguish as much between relations and functions. Let's say the latter is the IR and the former is the AST, and we'll just deal with the IR for now.

Cute!

``` julia
const IR = Union{Lambda, SumProduct, Call}

@generated function Base.foreach(f, ir::IR)
 quote
   $((:(f(ir.$fieldname)) for fieldname in fieldnames(ir))...)
 end
end

function choose_variable_order(ir::IR) ::Vector{Symbol}
  # for now just order variables by order of appearance
  vars = Symbol[]
  collect(ir::LocalVar) = push!(vars, ir.name)
  collect(ir::Union{IR, Vector}) = foreach(collect, ir)
  collect(ir) = nothing
  collect(ir)
  unique(vars)
end
```

So cute.

``` julia
function gather(ir::IR, typ::Type{T}) where {T}
  gathered = T[]
  gather(ir::T) = push!(gathered, ir)
  gather(ir::Union{IR, Vector}) = foreach(gather, ir)
  gather(ir) = nothing
  gather(ir)
  gathered
end

ir = Call(GlobalVar(:a), [LocalVar(:b), LocalVar(:c)])
gather(ir, LocalVar)
gather(ir, GlobalVar)
```

Now insert indexes. For each call we want to gensym a name for the index, replace the call with that, sort the args and then splice in a `Call` at the top that creates the index.

But actually, a `Call` needs to be inside some `SumReturn` which needs a variable which we don't have. So we need some other IR node to put this in. Or maybe we don't put them at the top yet, maybe we put it in the fun and we gather them up later when doing codegen.

``` julia
function insert_indexes(ir::IR, vars::Vector{LocalVar}, types::Dict{Var, Type}) ::IR
  insert(ir) = ir
  insert(ir::Union{IR, Vector}) = map(insert, ir)
  insert(ir::Call) = begin
    if ir.fun isa GlobalVar 
      # sort args in order they occur in vars
      sort_order = Vector(1:length(ir.args))
      sort!(sort_order, by=(i) -> findfirst(vars, ir.args[i]))
      Call(Index(ir.fun, sort_order), ir.args[sort_order])
    else
      ir
    end
  end
  insert(ir)
end
```

Next is 'insert prefixes'. Let's just do it in the same place.

``` julia
function insert_indexes(ir::IR, vars::Vector{LocalVar}, types::Dict{Var, Type}) ::IR
  insert(ir) = [ir]
  insert(ir::Call) = begin
    if (ir.fun isa GlobalVar) && is_finite(types[ir.fun])
      # sort args in order they occur in vars
      n = length(ir.args)
      sort_order = Vector(1:n)
      sort!(sort_order, by=(i) -> findfirst(vars, ir.args[i]))
      # emit call to index for each prefix of args
      [Call(Index(ir.fun, sort_order), ir.args[sort_order][1:i]) for i in 1:n]
    else
      [ir]
    end
  end
  insert(ir::SumProduct) = begin
    values = vcat(map(insert, ir.values)...)
    [SumProduct(ir.ring, ir.var, values)]
  end
  insert(ir)[1]
end
```

Next is 'factorize',

I just realized that choosing the variable order in this IR is silly, because it's going to be a nightmare to rearrange the SumProducts. 

If the steps actually look like:

* parse
* lower nested expressions
* lower constants
* infer fun types
* infer var types
* choose variable order
* emit factorized IR (with indexes and prefixes)

* thread index state through levels and across iter
* thread either factor state or bound variables (depending on materialize vs function)
* emit code (identifying finite factors at each sumproduct)

Then what I'm doing now is largely pointless. I should be reusing the original code and emitting this IR just before codegen. Like I said I was going to do.

Got to get better at staying on track.

I'll copy the existing `generate` function and modify it to emit an IR instead of code.

``` julia
function Compiled.factorize(lambda::Lambda, vars::Vector{Symbol}) ::SumProduct
  # permute all finite funs according to variable order
  calls = Call[]
  for call in lambda.domain
    if is_finite(fun_type(call.fun))
      n = length(call.args)
      sort_order = Vector(1:n)
      sort!(sort_order, by=(ix) -> findfirst(vars, call.args[ix]))
      for i in 1:n
        # add all prefixes of call
        push!(calls, Call(Index(call.fun, sort_order), call.args[sort_order][1:i]))
      end
    else
      push!(calls, call)
    end
  end

  # make return function
  # TODO think about namespace for var
  tail = SumProduct(lambda.ring, :value, lambda.value)

  # make join functions
  latest_var_nums = map(calls) do call
    maximum(call.args) do arg 
      findfirst(vars, arg)
    end
  end
  for (var_num, var) in reverse(collect(enumerate(vars)))
    values = Vector{Union{Call, SumProduct}}(calls[latest_var_nums .== var_num])
    push!(values, tail)
    tail = SumProduct(lambda.ring, var, values)
  end

  tail
end
```

And now modify another copy to do the code generation.

I got a bit stuck around what to do with the indexes. Think the best option is to make minimal changes - just spit out a list of indexes and handle them in a setup function. Can make the join functions close over the indexes later.

Eugh, called functions are in there too and they depend on knowing where in the call list it was. Or... I could just assume that they are literal functions rather than symbols and just splice them in.

Here is the main compiler bit.

``` julia
function compile(ir::SumProduct, vars::Vector{Symbol}, fun_type::Function, var_type::Function, setup::Vector{Expr}) ::Function
  # compile any nested SumProducts
  calls = Call[]
  values = Symbol[]
  for value in ir.values
    @match value begin
      SumProduct => begin
        args = push!(copy(vars), ir.var)
        fun = compile(value, args, fun_type, var_type, setup)
        push!(calls, Call(fun, args))
      end
      Call => push!(calls, value)
      Symbol => push!(values, value)
    end
  end
  
  # address indexes and variables by position
  index_and_column_nums = []
  fun_and_var_nums = []
  for (call_num, call) in enumerate(calls)
    if is_finite(fun_type(call.fun))
      push!(index_and_column_nums, (call_num, length(call.args)))
    else
      @assert call.args[end] == ir.var # TODO handle the case where ir.var is an argument and fun can only be used for testing
      var_nums = map((arg) -> findfirst(vars, arg), call.args[1:end-1])
      push!(fun_and_var_nums, (call.fun, var_nums))
    end
  end
  
  # TODO use values, once we are actually doing the sum
  
  # emit a function
  if isempty(fun_and_var_nums)
    eval(make_join(index_and_column_nums, length(vars)))
  else
    eval(make_seek(fun_and_var_nums, index_and_column_nums, length(vars)))
  end
end
```

Lot's of TODOs :(

Of course, this is not going to work at all with the non-reducey setup because it needs this tail to call and I've taken that away.

Let's temporarily drop the ability to return relations and just focus on the reduce stuff to get back to a testable state before I lose steam.

That means I can get rid of `make_return` and reduce `make_setup` to:

``` julia
function make_setup(indexes, tail)
  index_inits = [:(index(funs[$(Expr(:quote, index.fun))], $(Val{tuple(index.sort_order...)}))) for index in indexes]
  quote
    (funs) -> $tail(tuple($(index_inits...)))
  end
end
```

Now I just need to gen code for the reduce. I have a bunch of functions and a bunch of relations. And optionally, some function which can entirely determine the current var. If I have that I use it, otherwise I look for the smallest finite relation. If I have no finite relations, I can't solve the query.

Eugh, I'm petering out here. I think I've made a mistake by not separating value and domain functions in the compile step, and maybe even in the SumProduct.

The first chunk of the codegen works out what the ring value will be:

``` julia
  # calculate value returned by each iteration
  tail_vars = push!(copy(vars), ir.var)
  tails = []
  for value in ir.values
    @match value begin
      SumProduct => push!(tails, :($(compile(value, tail_vars))($(tail_vars...))))
      Symbol => push!(tails, value)
      Call => nothing
    end
  end
  tail = :(@product($(tails...)))
```

Next I need setup code and test code for each call.

Bah, I also just realized that my strategy for handling repeated vars is broken. Grrrrr. Will do it as a rewrite later.

Actually, maybe it's ok. I thought it was broken when there was a separating column in between them, but permutation will always put them together. I should trust awake me more than tonight me.

``` julia
  # check for repeated repeated variables eg foo(x,x) which need to be handled specially
  index_and_column_nums = (Int64, Int64)[]
  for call in ir.domain
    if call.fun isa Index
      push!(index_and_column_nums, (call.fun.num, length(call.args))
    end
  end
  is_repeat = map(ir.domain) do call
    (call.fun isa Index) &&
      contains(index_and_column_nums, (call.fun.num, length(call.args)-1))
  end
    
  # make code for setting up and testing each call
  setups = []
  tests = []
  for (call_num, call) in enumerarate(ir.domain) begin
    if call.fun isa Index
      if is_repeat[call_num]
        push!(setups, nothing)
        push!(tests, quote
          first(indexes[$(call.fun.num)], $(Val{length(call.args)}))
          seek(indexes[$(call.fun.num)], $(Val{length(call.args)}), $(ir.var))
        end)
      else
        push!(setups, :(first(indexes[$(call.fun.num)], $(Val{length(call.args)}))))
        push!(tests, :(seek(indexes[$(call.fun.num)], $(Val{length(call.args)}), $(ir.var))))
      end
    else
      push!(setups, nothing)
      push!(tests, :($(call.fun)($(call.args[1:end-1]...)) = $(call.args[end])))
    end
  end
```

Getting spaced now so I'll try to summarize where I'm at for tomorrow me:

* Codegen is unfinished
  * Check for fixing function
  * Gen min_count loop / sum
  * Wrap around tests and values
  * Implement @product or similar
* No way to return relations yet

Next time, make small incremental changes. And don't work an 11 hour day.

If I keep writing down the same advice I might eventually follow it.

### 2017 Dec 12

I had an idea how to simplify the repeated variable stuff: only emit a partial index for the last repetition of each variable, and then repeat first/next based on the number of repeats. But I need to salvage the existing code first before starting on another change.

I can also make the codegen nicer by creating macros for the verbose parts, so they don't obscure the overall structure. They are evaluated from inside out, so they play much nicer with Base.Cartesian than splicing in function calls.

Alternatively I could make a macro that makes splicing in array comprehensions easier.

``` julia
macro quote_for(iterator, body)
  @assert iterator.head == :call
  @assert iterator.args[1] == :in
  @show(iterator.args)
  quote
    Expr(:block, ($(esc(body)) for $(iterator.args[2]) in $(iterator.args[3]))...)
  end
end
```

``` julia
  quote
    product = $(ir.ring.one)
    $(@quote_for value in ir.value quote
      value = $(make_value(value))
      product = $(ir.ring.mult)(product, value)
    end)
  end
```

Then I'm not forced to make a new macro every time I want logic inside a loop.

I could do the same in Base.Cartesian style too:

``` julia
    product = $(ir.ring.one)
    @map $(ir.value) (value) -> begin
      value = @value(value)
      product = $(ir.ring.mult)(product, value)
    end
  end
```

Yeah, that's pretty confusing, mixing levels like that.

A lot of the complexity here comes from functions not obeying the same interface as relations. Can I fix that directly? What if I emit the naive interface and then put indexes in as a later optimization pass? Requires still knowing the type of each fun - either because I haven't mangled any symbols or because I've embedded the inferred type.

All of this feels pretty complicated.

Julia encourages thinking of all of this as variations on type-dispatch/specialization. But some kinds of optimizations can't be expressed that way eg using results of previous calls to optimize calls downstream. The latter also meshes poorly with the way I currently build code out of closures. If I want to express this as an optimization pass I need to return a big chunk of unevaled code at the end of this pass.

I wonder if all of this would be easier if I just implemented the caching inside the indexes. Would that be so much slower? It would entail a couple of comparisons on each lookup, but I already have to do a few for the lookup anyway. And it would make the compiler drastically simpler.

What's a cheap way to test this?

How will the arguments be passed? Implementing variadic functions efficiently in Julia is a pain. I think `args...` allocates, and probably loses type information. Let's test that.

``` julia
function foo(args...)
  args[1] + args[2]
end

@code_warntype foo(1,1)
```

``` julia
Variables:
  #self#::#foo
  args::Tuple{Int64,Int64}

Body:
  begin 
      return (Base.add_int)((Base.getfield)(args::Tuple{Int64,Int64}, 1)::Int64, (Base.getfield)(args::Tuple{Int64,Int64}, 2)::Int64)::Int64
  end::Int64
```

So it creates a tuple. Can that be optimized away?

``` julia
function bar(n)
  p = 0
  for i in 1:n
    p += foo(i, i+1)
  end
  p
end

@code_warntype bar(10000)
```

``` julia
Variables:
  #self#::#bar
  n::Int64
  i::Int64
  #temp#::Int64
  p::Int64

Body:
  begin 
      p::Int64 = 0 # line 71:
      SSAValue(3) = (Base.select_value)((Base.sle_int)(1, n::Int64)::Bool, n::Int64, (Base.sub_int)(1, 1)::Int64)::Int64
      #temp#::Int64 = 1
      5: 
      unless (Base.not_int)((#temp#::Int64 === (Base.add_int)(SSAValue(3), 1)::Int64)::Bool)::Bool goto 17
      SSAValue(4) = #temp#::Int64
      SSAValue(5) = (Base.add_int)(#temp#::Int64, 1)::Int64
      i::Int64 = SSAValue(4)
      #temp#::Int64 = SSAValue(5) # line 72:
      SSAValue(6) = i::Int64
      SSAValue(7) = (Base.add_int)(i::Int64, 1)::Int64
      p::Int64 = (Base.add_int)(p::Int64, (Base.add_int)(SSAValue(6), SSAValue(7))::Int64)::Int64
      15: 
      goto 5
      17:  # line 74:
      return p::Int64
  end::Int64
```

It got inlined and optimized away. What if it's too big to inline? Or if I pass something stringy?

Yeah, it allocates. No good. Would have to unroll it to something like the current interface anyway.

Could I wrap functions with something that implements the current interface? Assuming I know the types of the arguments, seems plausible.

Maybe I should just push the codegen all the way down to the edges. Seems like the more I codegen, the harder it is to test and the more potential for bugs, but I spend so much time working out calling conventions that don't allocate otherwise.

### 2017 Dec 11

School. Last of the year.

Also started working on testing display times for subliminal images used in psych experiments. So far there is huge variance and occasionally missing masks. Not sure whether anyone will care though, given the state of the field.

### 2017 Dec 12

Finished up notes for this years classes, and wrote up the display time experiment.

### 2017 Dec 13

Let's test the escape analysis in Julia 0.7 and see if it can handle tupled arguments.

Ok, in both 0.6 and 0.7 it can optimize them away iff I inline.

So I can move caching into the index if I inline all the calls to it, or if I replace them with macros.

What do the dispatch patterns look like?

Join and sum dispatch on number of calls. Product has to eval child SumProducts (which requires dispatching on value, not type). If they are evalled before-hand, we still need to pull the correct var. If the vars were in a tuple we could pass the index, but that would require allocating between steps.

Ok, spending too much time on trying to find some perfect solution. Just pick the least crufty / least risky thing and move on. Use macros everywhere, figure the rest out later.

Core api will just be `index` `count` `contains` `sum`. 

Sketched out compiler. Remaining fixes:

* Add args to join
* Compile child sum products
* Index num -> name

Now just need to debug all of this. Not sure how return stuff should work at the moment. Just count number of results for now and figure out materialization later.

My use of anonymous function exprs is broken. If I leave them in the output it breaks type inference. If I inline them with Base.Cartesian.inlinanonymous I risk making surprising changes.

This works better:

``` julia
function inline(function_expr::Expr, value)
  @match function_expr begin
    Expr(:->, [var::Symbol, body], _)  => quote
      let $var = $value
        $body
      end
    end
    _ => error("Can't inline $function_expr")
  end
end
```

Many many bugfixes later, I am getting a number. It is not the correct number, but it's a start.

Todo:

* Get the right answer
* Change all closed-over state to be passed through
* Hunt down allocations
* Push macros all the way down into relation api
* Push caching into relation index
* Consider changing macros to staged exprs

I got rid off the closed-over state and immediately got the right answer. Closures are hard.

Changing the inner functions to closures got rid off the world warnings. I guess those were actually creating global functions?

``` julia
julia> function foo()
       function bar(x) 
        x+1
       end
       bar(1)
       end
foo (generic function with 1 method)

julia> foo()
2

julia> bar(1)
ERROR: UndefVarError: bar not defined
```

No? I don't get a world warning here either. Not sure what the deal is. Best just avoid it for now.

Return value is Any. Willing to bet the allocations are down to type inference problems.

Todo:

* Hunt down allocations
* Push macros all the way down into relation api
* Push caching into relation index
* Consider changing macros to staged exprs

### 2017 Dec 14

Probably not going to bother with the staged exprs. There is just a lot of inherent hygiene violation in the compiler, don't think that there is a technical solution.

Todo:

* Hunt down allocations
* Push macros all the way down into relation api
* Push caching into relation index

So I'm going to go back to separating each join function, rather than wrapping them in a top-level function. Closing over state didn't work well anyway and I suspect inference might handle them better as top-level functions.

Sweet, it worked.

Fixed some bugs with constants getting ordered below other variables.

'Push macros all the way down into relation api'. First step is I need to carry types down into the macros. Let's stop using Index and make a new Call-like thing that carries type, args, original args etc. Want to push it down to the relation api so that the compiler doesn't have all these 'if is_finite(...' switches. Compiler just needs to know 'can I iterate over this'. 

Think this works:

``` julia
struct PartialCall{T} # type of fun, not of index
  name::Symbol # refers to whatever @index returned
  permutation::Vector{Int64} # passed to @index
  args::Vector{Symbol} # in post-permutation order
  bound::Int64 # args[1:bound] are already bound when this call is made
end

can_test(call::PartialCall{Function}) = length(call.args) == call.bound
can_iter(call::PartialCall{Function}, var::Symbol) = (length(call.args) == call.bound) && (call.args[call.bound] == 

can_test(call::PartialCall{Relation}) = true
can_iter(call::PartialCall{Relation}, var::Symbol) = true
```

So now factorize needs to emit these and keep track of the name->fun mapping.

Guess there is no need for can_test since we can just do it in @test, but we need can_iter to figure out if we fucked up the variable ordering.

I guess this is combining changes again - the current code doesn't handle misordered functions so the refactoring doesn't need to handle it yet either. Which means that we can use `can_index` for creating the partial calls. It's a coarse interface, but we don't have anything yet that would make use of a finer interface so there is no point trying to design it.

Let's first just put types into Call. Then one by one, make all the macros dispatch on the call type.

That was easy. Keep doing things incrementally like this.

Now put caching in the indexes. Basically gonna search for all the args, but start the search at the last point. Means I need to make sure that the los/his always point to a single value.

``` julia
function RelationIndex(relation::Relation{T}) ::RelationIndex{T} where {T}
  columns = relation.columns
  los = [1 for _ in columns]
  his = [gallop(column, 1, length(column)+1, column[1], 1) for column in columns]
  RelationIndex(columns, los, his)
end
```

Then in seek, I'll just check whether I can start from after the previous result.

Wait, there are two optimizations here. One where the old columns are already set at the correct value and we do nothing. One where they are set before the correct value and we start early. Got to be careful to get both.

Aaargh, this is hard to get right because I can point at empty regions and I need to be able to handle that correctly. If the array is non-empty then `hi-1` is always a valid value.

I think I have this right, but it's kind of ugly.

``` julia
function seek(index::RelationIndex, ::Type{Val{C}}, value) where {C}
  column = index.columns[C]
  outer_lo = index.los[C]
  outer_hi = index.his[C]
  prev_lo = index.los[C+1]
  prev_hi = index.his[C+1]
  # by default, start out beginning of outer region
  lo = outer_lo
  # check if previous search fell within this region
  if (outer_lo < prev_hi <= outer_hi) 
    compared = cmp(value, column[prev_hi-1]) # hi-1 is always within the column, so long as the column is not empty
    # check if this is the same as the last seek
    if compared == 0
      return true
    end
    # check if we can start this seek from wherever the previous one left off
    if compared == 1
      lo = prev_hi
    end
  end
  # check if there is anywhere left to seek
  if lo < outer_hi
    # seek
    lo = gallop(column, lo, outer_hi, value, 0)
    hi = gallop(column, lo+1, outer_hi, value, 1)
    index.los[C+1] = lo
    index.his[C+1] = hi
    lo < hi
  else
    false
  end
end
```

And it's just a bunch of extra work for the CPU, since I'm definitely calling these things in the correct order anyway. Let's ditch it.

One thing I will do is make the macros unpack their arguments, so that the interface side doesn't see any of the internal compiler structs.

There is still a lot of janky stuff in here that I don't look forward to explaining to people. 

* Index is gross, but permuting functions seems weird. Maybe I should only permute them in the compiler but not in the interface?
* Gross stateful interface that only works if called in the correct order.
* Fake first/seek in function, which only gets triggered on last call.

Maybe caching would be less gross if I stored only one ix and generated the row-wise comparison? A bit scary, because I'll have no way to test the speed until I fix materialization.

Todo:

* Try caching with only one ix
* Get materialization working again
* Benchmark
* Get non-materialization working (need a better name for that)
* Type inference
* Parsing

11 days / 4 weeks into this. Need to get faster.

### 2017 Dec 15

Derailed today by meetings and stuff. Have deadline to aim for now though.

### 2017 Dec 18

Deadline is Thursday. Need some time to prepare examples too, so effectively Wed night. 

Pushing caching into the indexes would be nice, but not essential. Leave it till last.

Materialization. Wrap the query in a setup function that initializes the result data-structure. Insert a function that pushes to the results and returns a value in some null ring. Push it down until all the args are available and change all the sumproducts in between to the null ring. Sort and reduce the result at the end of setup. Only support Relations for now.

Actually, not totally sure where the insert goes. Suppose args are x,y,z. Then we need x,y,z and the ring value, so it has to wrap the value of the sumproduct over z. Oh, because it changes from the original ring to the factor ring. 

Does that mean I also have to push down all the variables in the product? Yeah, will have to carry them along. But also still want them to be calculated earlier so I can short-circuit on zero.

What if I use some addressable structure instead? Then the last value can do += and all the prev levels can do *=. Does that make sense?

Nah, let's just carry them down. It works fine for now, and I can revisit it later if I want to allow more branchy structures. In that case I would probably need to actually return some factor-like data-structure. Or maybe have one result for each leaf and then combine them afterwards. Or do it bottom-up, FAQ style.

Eugh, partway through doing the rewrite but I'm realizing that it should actually occur at the lambda level, not at the ir level. We separate the lambda into two parts, one that is a fun and returns a singleton factor and one that materializes, calls the first and is over the factor ring. And maybe one more that permutes the result and reduces down again. So I should stash what I have so far and figure that out. 

Raises issues over when indexes get created and how stuff gets pulled out of the env. Maybe rather than emitting a single closure, I need to emit something that has an init_from_env and a call/run. And has to recursively call init_from_env on it's children and pass their state down to them.

Let's say at compile time we pass around an env that lists function definitions and state definitions, and then at runtime we bundle all the state into a heap struct and pass around a pointer to it. And then the calling convention is that any call to a lambda gets passed the state pointer. (Does that prevent creating recursive functions, or is it fine for those to share the state?)

Pipeline would look like:

* Lambda
* Inner, outer, reduce
* Sumproducts + inits

``` julia
struct Constant
  value::Any 
end

struct FunCall
  name::Union{Symbol, Function}
  typ::Type
  args::Vector{Union{Symbol, FunCall, Constant}}
end

struct Lambda
  ring::Ring
  args::Vector{Symbol}
  domain::Vector{FunCall}
  value::Vector{Expr} 
end

struct Funs
  funs::Dict{Symbol, Union{Lambda}}
end

struct ProcCall
  name::Symbol
  args::Vector{Symbol} # plus state pointer
end

struct Index
  name::Symbol
  typ::Type
  fun::Union{Symbol, Function} 
  permutation::Vector{Int64}
end

struct IndexCall
  name::Symbol
  typ::Type
  args::Vector{Symbol}
end

struct SumProduct
  ring::Ring
  var::Symbol
  domain::Vector{Union{FunCall, IndexCall}}
  value::Vector{Union{ProcCall, Symbol}}
end

struct Procs
  state::Dict{Symbol, Union{Index}} # (env) -> state
  procs::Dict{Symbol, Union{SumProduct}} # (state, args...) -> ring_type
end
```

Mostly happy with this. Tricky part is where to do indexes. Ideally would be a pass at the end that threads state between calls. Would still need a @setup at the beginning of loops though, or give up on restarting from parent region. 

Ok, how do I get there from here?

* Remove the type param from Call and Index.
* Split out the different kinds of Call.
* Write code that compiles Procs into a function
* Make a version of factorize that returns Procs.

Some gnarly bugs along the way, but works now. Next:

* Add a results state
* Leave ring along for now
* Break lambda into two parts at var line
* Add insert call to upper half 
* Functionalize lower half by adding constants
* Then do lowering constants

Is insert a funcall or a proccall? Maybe insert_indexes just creates a new fun and threads state through? Think I have too many types here. Let's simplify the types.

``` julia
struct Ring{T}
  add::Function
  mult::Function
  one::T
  zero::T
end

const count_ring = Ring(+, *, 1, 0)

struct Constant
  value::Any
end

struct FunCall
  name::Union{Symbol, Function}
  typ::Type
  args::Vector{Union{Symbol, FunCall, Constant}}
end

struct IndexCall
  name::Symbol
  typ::Type
  args::Vector{Symbol}
end

struct SumProduct
  ring::Ring
  domain::Vector{Union{FunCall, IndexCall}}
  value::Vector{Union{FunCall, Symbol}}
end

struct Lambda
  name::Symbol
  args::Vector{Symbol}
  body::SumProduct
end

struct Index
  name::Symbol
  typ::Type
  fun::Union{Symbol, Function}
  permutation::Vector{Int64}
end

struct Result
  typs::Vector{Type}
end

const State = Union{Index, Result}

struct Program
  main::Symbol
  states::Dict{Symbol, State} # (env) -> state
  funs::Dict{Symbol, Union{Lambda}}
end
```

Bah. Still didn't actually do materialization. Hopefully getting there.

Todo:

* Leave ring along for now
* Break lambda into two parts at var line
* Add insert call to upper half 
* Functionalize lower half by adding constants
* Then do lowering constants

### 2017 Dec 19

Need to be able to functionalize lower half. Causes some problems with variable naming - get a=a. So I need to rename the args.

Trouble with calling conventions again. Went down this rabbit hole of trying to wrap up all the state into a single pointer, but since I don't clearly differentiate between calls to Imp functions and calls to Julia functions I can't have different calling conventions for the two. Putting index names into the args as I currently do is definitely a mess semantically. Would be nice if I could close over the indexes but that caused problems with type inference before. Try once more?

The previous closures are getting boxed.

``` julia
result@_4::ANY = (*)(result@_4::Int64, ((Core.getfield)((Core.getfield)(#self#::Compiled.##35#39{Compiled.RelationIndex{Tuple{Array{Int64,1},Array{Int64,1}}}}, Symbol("##lambda#4318"))::CORE.BOX, :contents)::ANY)(i::Int64, x::Int64, value#4323::Int64)::ANY)::ANY # line 282:
```

Not sure why they are boxed, but the real problem is that they lose type info. What if I just put them in a ref?

It boxed that too `:|`

I'm unable to replicate this in simpler examples though.

Looks like it's https://github.com/JuliaLang/julia/issues/15276 or something similar. It fails to prove that the const closure always points to the same variable and so adds a type.

I clearly need to think this out properly.

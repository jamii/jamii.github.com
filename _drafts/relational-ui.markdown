---
layout: "post"
title: "A UI library for a relational language"
date: "2017-07-19 11:12"
---

* developing GUI apps in a relational language
* having tried a bunch of different approaches, I've settled on binding relational data to html templates
* binding has very simple semantics, including events and easy mental model for patching
* can be implemented almost entirely by compiling to relational queries
* for examples so far it performs on par with other libraries, and has lots of room for optimization



## background

typical object-relational mismatch problem

relational db <-> tree(ish) language <-> tree UI

lots of manual plumbing and changes of data structure

popular solutions

get rid off the relations!

tree db <-> tree(ish) language <-> tree UI

people who go for this often receive an object lesson in why relational databases where invented in the first place.

add a layer of abstraction!

relation db <-> magic <-> tree(ish) language <-> tree UI

older magic layers tended not to play well with dbs, causing n+1 queries etc, but newer magic layers like graphql are pretty reasonable.

many many different options for what to put in the magic layer, but they all go between the datastore and the logic, because everyone writes GUI apps in tree(ish) languages.

I have a slightly different problem

relational db <-> relational language <-> tree UI

(It's a datalog(ish) language with [extensions for talking about time](http://bloom-lang.net/), but the details of the language don't matter that much for the purpose of this post.)

It's a similar problem in that it still comes down to mapping between relations and trees, but it happens at a different layer.

Like the previous problem, you can do this by hand and it's not *terrible*, but it's less than satisfying.

Approaches I've tried before

put trees in the relations! if your relational language is good at aggregation and allows complex data types, you can build up a tree and store it in a table cell

``` julia
@table ui(Session) => Tree
```

get rid off the trees! we can model trees with relations and node ids. [add a little syntax sugar]

``` julia
@table root(Session) => Node
@table parent(Node) => Node
@table position(Node) => Int64
@table tag(Node) => String
@table attribute(Node, String) => String
```

My main objection to both of these approaches is that the code doesn't visually map well to the mental model of the ui. 

Problem exists in treeish languages too, which is why most UI libraries include some kind of template language that mimics the mental model of the tree while making it easy to splice in logic and data. 

[template]

[jsx]

So we want to create a template language that binds to relational data, rather than treeish data.

## limitations / goals

Interested in attaching UI to [Imp] programs. 

Using browser as UI purely for familiarity. Same approach should work with native UI toolkit too.

Focused on reducing the number of layers and concepts involved in writing GUI apps. Simplicity > scale/power.

Local app, or small number of users on local network - similar domain to [shiny](https://github.com/rstudio/shiny) or [nitrogen](http://nitrogenproject.com/learn)

## outside

templates look like this:

``` julia
[ul
  class="todo-list"
  visible(todo) do
    text(todo, text) do
      displaying(todo) do
        [li 
          [div 
            class="view" 
            [input 
              class="toggle" 
              "type"="checkbox" 
              checked(todo) do
                checked="checked"
              end
              onclick="toggle($todo)"
            ] 
            [label "$text" ondblclick="start_editing($todo)"]
            [button class="destroy" onclick="delete_todo($todo)"]
          ]
        ]
      end
      editing(todo) do
        [li
          class="editing"
          [input  
            class="edit"
            defaultValue="$text"
            onkeydown="""
              if (event.which == 13) finish_editing($todo, this.value)
              if (event.which == 27) escape_editing($todo)
            """
            onblur="escape_editing($todo)"
          ]
        ]
      end
    end
  end
]
```

Templates are made up of these pieces:

* DOM nodes like `[ul ...]`
* DOM attributes like `class="todo-list"`
* Text nodes like `"$text"`
* Query fragments like `text(todo, text) do ... end`

Combine this template with some data:

``` julia
visible(1)
visible(3)

todo(1, "foo")
todo(2, "bar")
todo(3, "quux")

displaying(1)
displaying(2)
editing(3)

checked(1)
```

``` julia
[ul
  class="todo-list"
  visible(todo=1) do
    text(todo=1, text="foo") do
      displaying(todo=1) do
        [li 
          [div 
            class="view" 
            [input 
              class="toggle" 
              "type"="checkbox" 
              checked(todo=1) do
                checked="checked"
              end
              onclick="toggle($todo)"
            ] 
            [label "$text" ondblclick="start_editing($todo)"]
            [button class="destroy" onclick="delete_todo($todo)"]
          ]
        ]
      end
    end
  end
  visible(todo=3) do
    text(todo=3, text="quux") do
      editing(todo=3) do
        [li
          class="editing"
          [input  
            class="edit"
            defaultValue="$text"
            onkeydown="""
              if (event.which == 13) finish_editing($todo, this.value)
              if (event.which == 27) escape_editing($todo)
            """
            onblur="escape_editing($todo)"
          ]
        ]
      end
    end
  end
]
```

The filled out query fragments are sorted by the values of their variables, in the order that the variables appear in the text.

``` julia
[ul
  class="todo-list"
  visible(todo=1) do
    text(todo=1, text="foo") do
      displaying(todo=1) do
        [li 
          [div 
            class="view" 
            [input 
              class="toggle" 
              "type"="checkbox" 
              checked(todo=1) do
                checked="checked"
              end
              onclick="toggle(1)"
            ] 
            [label "foo" ondblclick="start_editing(1)"]
            [button class="destroy" onclick="delete_todo(1)"]
          ]
        ]
      end
    end
  end
  visible(todo=3) do
    text(todo=3, text="quux") do
      editing(todo=3) do
        [li
          class="editing"
          [input  
            class="edit"
            defaultValue="quux"
            onkeydown="""
              if (event.which == 13) finish_editing(3, this.value)
              if (event.which == 27) escape_editing(3)
            """
            onblur="escape_editing(3)"
          ]
        ]
      end
    end
  end
]
```

``` julia
[ul
  class="todo-list"
  [li 
    [div 
      class="view" 
      [input 
        class="toggle" 
        "type"="checkbox" 
        checked="checked"
        onclick="toggle(1)"
      ] 
      [label "foo" ondblclick="start_editing(1)"]
      [button class="destroy" onclick="delete_todo(1)"]
    ]
  ]
  [li
    class="editing"
    [input  
      class="edit"
      defaultValue="quux"
      onkeydown="""
        if (event.which == 13) finish_editing(3, this.value)
        if (event.which == 27) escape_editing(3)
      """
      onblur="escape_editing(3)"
    ]
  ]
]
```

And finally this is sent to the browser to be rendered.

## incremental

as described so far, this is only good for one-off rendering. we need to define what happens when things change. 

let's say the underlying relations change

``` julia
+visible(2)
-visible(3)
-checked(1)
```

with the new data, the filled-out template looks like

``` julia
[ul
  class="todo-list"
  visible(todo=1) do
    text(todo=1, text="foo") do
      displaying(todo=1) do
        [li 
          [div 
            class="view" 
            [input 
              class="toggle" 
              "type"="checkbox" 
              onclick="toggle(1)"
            ] 
            [label "foo" ondblclick="start_editing(1)"]
            [button class="destroy" onclick="delete_todo(1)"]
          ]
        ]
      end
    end
  end
  visible(todo=2) do
    text(todo=2, text="bar") do
      displaying(todo=2) do
        [li 
          [div 
            class="view" 
            [input 
              class="toggle" 
              "type"="checkbox" 
              onclick="toggle(2)"
            ] 
            [label "bar" ondblclick="start_editing(2)"]
            [button class="destroy" onclick="delete_todo(2)"]
          ]
        ]
      end
    end
  end
]
```

Obviously, we want to guarantee that changes are made to the DOM so that the end result matches the new filled out template. But it's not enough to specify only the end result. Some DOM nodes have their own state that is not reflected in the template, such as scroll position or text entered by the user. It's not practical to manage this state from the server, both because of the latency involved and the inability to block the client or save up keystrokes. But deleting and recreating a node will erase its state. So as part of the semantics of the template library we have to specify exactly what changes it makes to the DOM to reach the correct end result.

Libraries like [React](https://facebook.github.io/react/) do this by [specifying](https://facebook.github.io/react/docs/reconciliation.html) an algorithm that compares the old and new DOM trees and computes a set of changes that will turn one into the other. When comparing large lists of elements, it recommends that users supply a unique key for each element to help React decide whether to mutate an old list element or delete and replace it. It warns:

> It is important to remember that the reconciliation algorithm is an implementation detail... We are regularly refining the heuristics in order to make common use cases faster.

> Keys should be stable, predictable, and unique. Unstable keys ... will cause many component instances and DOM nodes to be unnecessarily recreated, which can cause performance degradation and lost state in child components.

Given that varying the heuristics can result in lost state in child components, I'm reluctant to endorse describing them as an implementation detail. But it's difficult for React to do much better because the mapping from data to virtual DOM is defined by opaque javascript code.

In our templates we have much better information about how data maps to the filled out template, so we can adopt a much simpler set of rules:

* When a new row is added to a relation, everything under it in the filled out template is created from scratch.
* When a row is removed from a relation, everything under it in the filled out template is deleted.

So if the change to our data is:

``` julia
+visible(2)
-visible(3)
-checked(1)
```

Then the change to the DOM will be:

``` julia
+visible(todo=2) do
  text(todo=2, text="bar") do
    displaying(todo=2) do
      [li 
        [div 
          class="view" 
          [input 
            class="toggle" 
            "type"="checkbox" 
            onclick="toggle(2)"
          ] 
          [label "bar" ondblclick="start_editing(2)"]
          [button class="destroy" onclick="delete_todo(2)"]
        ]
      ]
    end
  end
end

-visible(todo=3) do
  text(todo=3, text="quux") do
    editing(todo=3) do
      [li
        class="editing"
        [input  
          class="edit"
          defaultValue="quux"
          onkeydown="""
            if (event.which == 13) finish_editing(3, this.value)
            if (event.which == 27) escape_editing(3)
          """
          onblur="escape_editing(3)"
        ]
      ]
    end
  end
end

-checked(todo=1) do
  checked="checked"
end
```

This provides a simple mental model that is easy to map to the visual appearance of the template. The user can easily control how the DOM is mutated by changing the position of the query fragments. 

For example, our template currently has `text(todo, text)` above the `li` node. 

``` julia
visible(todo) do
  text(todo, text) do
    displaying(todo) do
      [li 
        [div 
          class="view" 
          [input 
            class="toggle" 
            "type"="checkbox" 
            checked(todo) do
              checked="checked"
            end
            onclick="toggle($todo)"
          ] 
          [label 
            ondblclick="start_editing($todo)"
            "$text" 
          ]
          [button class="destroy" onclick="delete_todo($todo)"]
        ]
      ]
    end
    editing(todo) do
      [li
        class="editing"
        [input  
          class="edit"
          defaultValue="$text"
          onkeydown="""
            if (event.which == 13) finish_editing($todo, this.value)
            if (event.which == 27) escape_editing($todo)
          """
          onblur="escape_editing($todo)"
        ]
      ]
    end
  end
end
```

This means that if the text of a todo is changed, the entire `li` node will be deleted and recreated. If this is not acceptable, we could move the `text(todo, text)` down closer to the nodes that it actually affects.

``` julia
visible(todo) do
    displaying(todo) do
      [li 
        [div 
          class="view" 
          [input 
            class="toggle" 
            "type"="checkbox" 
            checked(todo) do
              checked="checked"
            end
            onclick="toggle($todo)"
          ] 
          [label 
            ondblclick="start_editing($todo)"
            text(todo, text) do
              "$text" 
            end
          ]
          [button class="destroy" onclick="delete_todo($todo)"]
        ]
      ]
    end
    editing(todo) do
      [li
        class="editing"
        [input  
          class="edit"
          text(todo, text) do
            defaultValue="$text"
          end
          onkeydown="""
            if (event.which == 13) finish_editing($todo, this.value)
            if (event.which == 27) escape_editing($todo)
          """
          onblur="escape_editing($todo)"
        ]
      ]
    end
  end
end
```

Now when the text is changed only the `"$text'` node or the `defaultValue="$text"` attribute will be replaced.

## events

need to be able to react to user input. 

can tag certain relations as event relations eg

``` julia
@event delete_todo(todo::Int64)
```

for every event relation, a matching js function is created that will insert a row into that relation. event handlers in the dom can call these functions to send data back to the server.

``` julia
[button class="destroy" onclick="delete_todo($todo)"]
```

but we also still allow arbitrary javascript in event handlers, which is useful for eg reading state from the DOM.

``` julia
[input  
  class="edit"
  text(todo, text) do
    defaultValue="$text"
  end
  onkeydown="""
    if (event.which == 13) finish_editing($todo, this.value) // enter
    if (event.which == 27) escape_editing($todo) // escape
  """
  onblur="escape_editing($todo)"
]
```

Again, if this was running in the browser itself or we were using a native UI toolkit it might be useful to manage such state directly. But in the current server/client implementation it's more practical to leave low-latency interactions such as typing and scrolling to the browser.

## sessions

want to be able to handle multiple users on same server. give each browser tab a unique session key. implicitly wrap each template in `session(session) do ... end` so that the template can behave differently. 

for example, in our todo list we want the filter to be set per tab, not globally. 

``` julia
filter(filter) do
  [li 
    [a 
      current_filter(session, filter) do
        class="selected"
      end 
      onclick="set_filter('$session', '$filter')" 
      "$filter"
    ]
  ]
end 
]
```

## implementation

template evaluation. as much as possible want to do the work in Imp queries. two reasons:

1. can take advantage of the query compiler
2. when I get around to implementing [incremental view maintenance](http://blogs.evergreen.edu/sosw/files/2014/04/Green-Vol5-DBS-017.pdf), I'll get incremental template evaluation for free

simple example

``` julia
# --- data ---

visible(1)
visible(2)
visible(3)

text(1, "foo")
text(2, "bar")
text(3, "quux")

displaying(1)
displaying(2)

editing(3)

# --- template ---

[div
  visible(todo) do
    displaying(todo) do
      text(todo, text) do
        "displaying: $text"
      end
    end
    editing(todo) do
      "editing: $todo"
    end
  end
]

# --- fill out query fragments ---

[div 
  visible(todo=1) do 
    displaying(todo=1) do 
      text(todo=1, text="foo") do 
        "displaying: foo" 
      end
    end
  end
  visible(todo=2) do 
    displaying(todo=2) do 
      text(todo=2, text="bar") do 
        "displaying: bar" 
      end
    end
  end
  visible(todo=3) do 
    editing(todo=3) do 
      "editing: 3" 
    end
  end
]

# --- collapse query fragments ---

[div 
  "displaying: foo" 
  "displaying: bar" 
  "editing: 3" 
]
```

first we number all the nodes, depth-first, to make it easier to refer to them.

``` julia
[div # 1
  visible(todo) do # 2
    displaying(todo) do # 3
      text(todo, text) do # 5
        "displaying: $text" # 7
      end
    end
    editing(todo) do # 4
      "editing: $todo" # 6
    end
  end
]
```

next, for each query fragment we create a corresponding query that performs the join against it's parent. we also create an id for each filled out fragment by hashing together the node id and all the variable values. (this id is just used as a shorthand reference - if hash collisions are worrying you could use some kind of lookup table or even just use the list of variable values directly.)

``` julia
@query begin # special dummy query for the root of the tree
    session(session) 
    return query_0(session) => hash(session)
end

@query begin
    query_0(session) => query_parent_hash 
    visible(todo) 
    my_hash = hash(todo, hash(2, query_parent_hash)) 
    return query_2(session, todo) => my_hash
end

@query begin
    query_2(session, todo) => query_parent_hash 
    displaying(todo) 
    my_hash = hash(todo, hash(3, query_parent_hash)) 
    return query_3(session, todo) => my_hash
end

@query begin
    query_2(session, todo) => query_parent_hash 
    editing(todo) 
    my_hash = hash(todo, hash(4, query_parent_hash)) 
    return query_4(session, todo) => my_hash
end

@query begin
    query_3(session, todo) => query_parent_hash 
    text(todo, text) 
    my_hash = hash(text, hash(todo, hash(5, query_parent_hash))) 
    return query_5(session, todo, text) => my_hash
end
```

``` julia
# with made-up hashes

query_0("my_session") => 0x0

query_2("my_session", 1) => 0x1
query_2("my_session", 2) => 0x2
query_2("my_session", 3) => 0x3

query_3("my_session", 1) => 0x4
query_3("my_session", 2) => 0x5

query_4("my_session", 3) => 0x6

query_5("my_session", 1, "foo") => 0x7
query_5("my_session", 2, "bar") => 0x8
```

Next we need to calculate what order the remaining nodes will be in after the query fragments are removed. Doing this in a way that is amenable to efficient incremental maintenance is tricky, but I eventually hit upon an elegant solution. 

The position of each node can be described by the positions and variable values of all the query nodes between it and its eventual parent:

``` julia
# --- template ---

[div # 1
  visible(todo) do # 2
    displaying(todo) do # 3
      text(todo, text) do # 5
        "displaying: $text" # 7
      end
    end
    editing(todo) do # 4
      "editing: $todo" # 6
    end
  end
]

# --- filled out template ---

[div # 1
  visible(todo=1) do # 2
    displaying(todo=1) do # 3
      text(todo=1, text="foo") do # 5
        "displaying: foo" # 1st child of node 1 -> todo=1 -> 1st child of node 2 -> 1st child of node 3 -> text="foo" -> 1st child of node 5
      end
    end
  end
  visible(todo=2) do # 2
    displaying(todo=2) do # 3
      text(todo=2, text="bar") do # 5
        "displaying: bar" # 1st child of node 1 -> todo=2 -> 1st child of node 2 -> 1st child of node 3 -> text="bar" -> 1st child of node 5
      end
    end
  end
  visible(todo=3) do # 2
    editing(todo=3) do # 4
      "editing: 3" # 1st child of node 1 -> todo=3 -> 2nd child of node 2 -> 1st child of node 4 
    end
  end
]
```

(A potential confusion - when we say "nth child of node x" we mean the nth child in the *template*, not in the resulting DOM tree. We can't use the positions in the DOM tree those are exactly what we are trying to calculate.)

If we represent these paths as tuples and use them as sort keys, the nodes will end up sorted in the correct order:

``` julia
(1, todo=1, 1, 1, text="foo", 1) => "displaying: foo"
(1, todo=2, 1, 1, text="bar", 1) => "displaying: bar"
(1, todo=3, 2, 1) => "editing: 3"
```

Julia can avoid dynamic dispatch when given stable types. To make sure all the sort keys have the same type, we can just fill in dummy columns.

``` julia
(1, todo=1, 1, 1, 0, text="foo", 1) => "displaying: foo"
(1, todo=2, 1, 1, 0, text="bar", 1) => "displaying: bar"
(1, todo=3, 2, 0, 1, text="", 0) => "editing: 3"
```

So for each non-query-fragment we create a query that calculates the correct sort key, as well as the node id, the parent node id, the type of DOM node to create and the content.

``` julia
@query begin
    query_0(session) => query_hash 
    my_hash = hash(0, query_hash) 
    return group_0(session, 1) => (UInt64(0), my_hash, Html, "div")
end

@query begin
    group_0(session, 1) => (_, fixed_parent_hash, _, _) 
    query_4(session, todo) => query_parent_hash 
    my_hash = hash(6, query_parent_hash) 
    return group_1(session, 1, todo, 2, 0, 1, "", 0) => (fixed_parent_hash, my_hash, Text, string("editing: ", todo))
end

@query begin
    group_0(session, 1) => (_, fixed_parent_hash, _, _) 
    query_5(session, todo, text) => query_parent_hash 
    my_hash = hash(7, query_parent_hash) 
    return group_1(session, 1, todo, 1, 1, 0, text, 1) => (fixed_parent_hash, my_hash, Text, string("displaying: ", text))
end
```

``` julia
# with made-up hashes

group_0("session_1", 1) => (0x0, 0x1, Html, "div")

group_1("session_1", 1, 1, 1, 1, 0, "foo", 1) => (0x1, 0x2, Text, "displaying: foo")
group_1("session_1", 1, 2, 1, 1, 0, "bar", 1) => (0x1, 0x3, Text, "displaying: bar")
group_1("session_1", 1, 3, 2, 0, 1, "", 0) => (0x1, 0x4, Text, "editing: 3")
```

Now we have a list of every DOM node together with a (probably) unique id and the id of its parent node. Since they are sorted in the correct order we can also easily find the siblings of each node. 

Suppose the source data in our example changes:

``` julia
-visible(2)

+visible(0)
+displaying(0)
+text(0, "make a todo list")

+visible(4)
+displaying(4)
+text(4, "more milk!")
```

We can use standard incremental maintenance algorithms to calculate the resulting changes to our list of nodes.

``` julia
+group_1("session_1", 1, 1, 0, 1, 0, "make a todo list", 1) => (0x1, 0x5, Text, "displaying: make a todo list")
-group_1("session_1", 1, 2, 1, 1, 0, "bar", 1) => (0x1, 0x3, Text, "displaying: bar")
+group_1("session_1", 1, 1, 4, 1, 0, "more milk!", 1) => (0x1, 0x6, Text, "displaying: more milk!")
```

We can look at the new list to find out that the next node after 0x5 "displaying: make a todo list" is 0x2 "displaying:foo" and that there is no node after 0x6 "displaying: more milk!". So we send the following commands to whichever client has `session="session_1"`:

``` julia
delete(0x3)
insertBefore(0x5, "text", "displaying: make a todo list", parent=0x1, sibling=0x2)
insertAtEnd(0x6, "text", "displaying: more milk!", parent=0x1)
```

The nodes in each group are sorted in the order they will appear in the DOM and the groups themselves are sorted in depth-first order, so if we generate these instructions by order of group and then reverse order within the group, we can be sure that by the time each instruction is run the parent and sibling will always exist.

Finally, attributes like `class="main"` are handled almost identically to html and text nodes except that their order doesn't matter.

## evaluation

### status

Implementation quality = not pretty. Works well enough to demonstrate that this is feasible for simple examples. 

Running everything on the server has obvious limitations wrt latency and maximum load. I *think* this approach could be scaled to handle public webapps with many users, but it would require a much more sophisticated implementation, with some way to run parts of the logic on the client. 

I haven't given much thought to security yet. A good start would be to track what events are present in the template and refuse to allow clients to submit any events that aren't on the list.

### expressiveness

can implement template fragments as a pass before query generation, so that we could write

``` julia
@template main()
  visible(todo) do
    displaying(todo) do
      displayed_todo(todo)
    end
    editing(todo) do
      "editing: $todo"
    end
  end
end

@template displayed_todo(id)
  text(id, text) do
    "displaying: $text"
  end
end
```

all the examples in this post only spliced data into text nodes, but the implementation allows splicing anywhere:

``` julia
dynamic_tag(tag) do
  ["$tag"
    dynamic_attributes(key, val) do
      "$key"="$val"
    end
  ]
end
```

currently, templates are limited to a fixed depth, so they can't express eg a file browser where the depth depends on the data. allowing template fragments to call themselves recursively would fix this, but it's non-obvious how to combine recursion with the query-based implementation here. probably not impossible, but I won't attempt to deal with it until I definitely need it.

### performance

[Todomvc example](https://github.com/jamii/imp/blob/master/examples/Todo.jl)

TODO benchmarks

Compare to [official React implementation](http://todomvc.com/examples/react/#/) and [some old Om implementation](http://swannodette.github.io/todomvc/labs/architecture-examples/om/index.html). Not a pissing contest, just trying to get a handle on whether performance is likely to be a problem.

Not particularly rigorous. Run through all the benchmarks a few times to warmup, and then record a profile.

Add first todo:
imp-1
imp-200
imp-201



Bear in mind also that this is recalculating the UI for each tab from scratch on each event. The UI calculation is built up entirely out of simple joins so in theory it should be easy to maintain incrementally.

201st todo, total time spent in server code, mean of 100 runs

| #tabs | time (ms) |
|-------|-----------|
| 1     | 9         |
| 10    | 22        |
| 100   | 168       |
| 1000* | 2056      |

* Chrome has a cunning optimization where after ~150 tabs it just stops loading pages, so the last row is 100 real tabs and 900 fake sessions.

The marginal cost per tab is about 1.6ms. The bulk of the time is spent sorting and resorting relations, rather than solving queries.

That leaves about ~7-8ms of overhead. This is probably because while the query compiler is pretty good, the dataflow layer that binds the queries together is a pile of poop. 

The marginal allocation rate per tab is 1mb across 5373 allocations. This is almost entirely in the template queries. Most of the individual allocations are from creating identical event strings on each of 200 todos x 100 tabs, but the bulk of the allocation size is from many, many copies of the columns in these relations. 

The biggest opportunities for improving performance are prob
Between incremental maintenance, removing the overhead from the dataflow layer, cleaning up the fanout and batching the incoming and outgoing events, it seems that there is a lot of potential to improve the performance.

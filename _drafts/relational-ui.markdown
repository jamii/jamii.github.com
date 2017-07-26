---
layout: "post"
title: "A UI library for a relational language"
date: "2017-07-19 11:12"
---

TLDR:

* [I'm working on a relational programming language intended for rapid GUI dev.](#imp)
* [Having tried a couple of different approaches to describing GUIs, I've settled on a React-like library that binds relational data to HTML templates.](#templates)
* [The library has very simple semantics, including an easy mental model for patching the DOM.](#patching)
* [The template language can be implemented almost entirely by compiling to relational queries.](#implementation)
* [The current implementation has been used to build a few simple examples, with performance on par with similar libraries in OOPy languages.](#performance)

## Background

The typical architecture for a small web or native app looks like:

```
datastore (relations) <-> application logic (objects) <-> GUI (trees)
```

Moving data back and forth between the first two layers is painful because of the [object-relational mismatch](https://en.wikipedia.org/wiki/Object-relational_impedance_mismatch). Developers typically try to solve this by [hiding](https://en.wikipedia.org/wiki/Object-relational_mapping) or [getting rid off](https://en.wikipedia.org/wiki/NoSQL) relations.

But relational data models have a lot of great qualities, so it's interesting to try getting rid off the objects instead by making a datastore query language that can comfortably express the application logic.

But that still leaves us with another data model mismatch - between the relational model in the application logic and the tree model that almost every GUI uses.

```
datastore + application logic (relations) <-> GUI (trees)
```

That's what we're going to deal with in this post.

To keep things concrete, we'll use this very simple chat app as a running example.

![](/imp/chat.png)

Yes, it is hideous, but it illustrates all the important points while being small enough to show the entire dataflow.

## Imp

[Imp](https://github.com/jamii/imp/) is a [datalog](https://en.wikipedia.org/wiki/Datalog)-ish language in the same family as [Eve](http://evelang.com/), [LogicBlox](http://www.logicblox.com/), [Bloom](http://bloom-lang.net/), [Dyna](http://www.cs.jhu.edu/~nwf/datalog20-paper.pdf) etc.

Imp is focused on reducing the number of layers and concepts involved in writing GUI apps - prioritizing simplicity over scale/power.

The goal is to build apps that run on one machine or that serve small number of users on a local network, and not so much to build public apps that scale to large numbers of users. Think [shiny](https://github.com/rstudio/shiny) or [nitrogen](http://nitrogenproject.com/learn), not [rails](http://rubyonrails.org/).

Imp data is stored in relations. The schema is usually [highly normalized](https://en.wikipedia.org/wiki/Sixth_normal_form) - this has several important advantages that we will see later.

Here are the relations used in the chat example:

``` julia
const Session = Int64
const Message = Int64

@relation username(Session) => String
@relation message(Message)
@relation text(Message) => String
@relation sent_by(Message) => String
@relation sent_at(Message) => DateTime
@relation likes(username::String, Message) 
```

And a direct translation into sql:

``` sql
create table username(session int, username varchar, primary key (session));
create table message(id int, primary key (id));
create table text(id int, text varchar, primary key (id));
create table sent_by(id int, username varchar, primary key (id));
create table sent_at(id int, time timestamp, primary key (id));
create table likes(username varchar, id int, primary key (username, id));
```

Imp programs are built out of relational queries. Each line within the query refers to a single relation and its columns. Whenever the same variable name is used for more than one column, those columns are joined together. Subqueries begin with `@query` and return an array of results for each column.

Here is a query that records data for each new message:

``` julia
@query begin
  new_message(session, text)
  username(session) => username
  @query begin 
    message(id) => (_, _)
  end
  new_message = 1 + length(id) 
  return message(new_message)
  return text(new_message) => text
  return sent_by(new_message) => username
  return sent_at(new_message) => now()
end
```

And again, a direct translation into sql:

``` sql
begin; 
create temporary table results as (
  select new_message.text as text, username.username as username, ((select count(*) from message) + 1) as next_message
  from new_message, username
  where new_message.session = username.session
);
insert into message select next_message from results;
insert into text select next_message, text from results;
insert into sent_by select next_message, username from results;
insert into sent_at select next_message, now() from results;
commit;
```

Imp is built on top of [Julia](https://julialang.org/) and can use any Julia types and functions. The `DateTime` and the `now()` function used above are part of the Julia standard library. 

## Previous approaches

In a typical OOPy language we would probably build these trees using a template language like this one:

{% raw %}
``` html
<table>
  {% for message in messages %}
    <tr>
      <td>{% message.sent_by %}:</td>
      <td>{% message.text %}</td>
      <td>
        {% for like in message.likes %}
          <div>{% like.liker %} likes this</div>
        {% endfor %}
      </td>
      <td>
        <button onclick="new_like({% session %}, {% message.id %})">
          like!
        </button>
      </td>
    </tr>
  {% endfor %}
</table>
```
{% endraw %}

There are all kinds of template languages, but what they generally have in common is that their visual appearance mimics the mental model of the tree they are producing. This makes them much easier to read and navigate.

In previous versions of Imp, I've tried two different approaches to building trees. Both are pretty hard to follow, so just let your eyes glaze over and see the rough outline.

The first approach was to just use an existing tree datatype and use subqueries and aggregation to build it up:

``` julia
using Hiccup # virtual DOM library

@relation tree() => Hiccup.Node

@query begin
  session(session)
  @query begin
    message(message)
    sent_by(message) => sent_by
    text(message) => text
    @query begin
      likes(liker, message)
      like_node = div("$liker likes this")
      return like_node
    end
    message_node = tr(
      td(sent_by),
      td(text),
      td(like_node...),
      button(onclick="new_like($session, $message)", "like!")
    )
    return message_node
  end
  table_node = table(message_node...)
  return tree(session) => table_node
end
```

The second was to represent the tree as a set of relations, using hashes to create unique node ids:

``` julia
struct Node 
  id::UInt64
end

@relation root(Session) => Node
@relation parent(Node) => Node
@relation sort_key(Node) => Any
@relation tag(Node) => String
@relation attribute(Node, String) => String

@query begin
  session(session)
  table_node = Node(hash(:table, session))
  return root(session) => table_node
  return tab(table_node) => "table"
end

@query begin
  session(session)
  message(message)
  sent_by(message) => sent_by
  text(message) => text
  table_node = Node(hash(:table, session))
  tr_node = Node(hash(:tr, session, message))
  td_node_1 = Node(hash(:td, session, message, 1))
  td_node_2 = Node(hash(:td, session, message, 2))
  td_node_3 = Node(hash(:td, session, message, 3))
  button_node = Node(hash(:button, session, message))
  return parent(tr_node) => table_node
  return tag(tr_node) => "tr"
  return parent(td_node_1) => tr_node
  return tag(td_node_1) => "td"
  return attribute(td_node_1, "textContent") => sent_by
  return sort_key(td_node_1) => 1
  return parent(td_node_2) => tr_node
  return tag(td_node_2) => "td"
  return attribute(td_node_2, "textContent") => text
  return sort_key(td_node_2) => 2
  return parent(td_node_3) => tr_node
  return tag(td_node_3) => "td"
  return sort_key(td_node_3) => 3
  return parent(button_node) => tr_node
  return tag(button_node) => "button"
  return attribute(button_node, "textContent") => "like!"
  return attribute(button_node, "onclick") => "new_like($session, $message)"
  return sort_key(button_node) => 4
end

@query begin
  session(session)
  likes(liker, message)
  td_node_3 = Node(hash(:td, session, message, 4))
  liker_node = Node(hash(:like, session, message, liker))
  return parent(liker_node) => td_node_3
  return tag(liker_node) => "div"
  return sort_key(liker_node) => "$liker likes this!"
  return attribute(liker_node, "textContent") => liker
end
```

The extreme verbosity of the second approach can be tamed with [a little syntax sugar](https://github.com/witheve/eve-starter/blob/master/programs/todomvc.eve#L99-L103), but both approaches still suffer from the lack of visual similarity between the code structure and the UI structure.

The core problem is these nested `for` loops in the OOPy template:

{% raw %}
``` julia
{% for message in messages %}
  ...
      {% for like in message.likes %}
        ...
      {% endfor %}
  ...
{% endfor %}
```
{% endraw %}

We can try to emulate this structure with a relational query:

``` sql 
select message.id, like.liker
from message, like
where message.id = like.message
```

But this query does not return any results for messages which have no likes. To generate the correct UI tree, we have to break this up into multiple queries, use subqueries or use [lateral joins](https://blog.heapanalytics.com/postgresqls-powerful-new-join-type-lateral/), and that leads to tangled query code that is hard to match up to the resulting tree.

So I created a relational analogue to the OOPy template language that allows expressing these nested lateral joins in a way that visually mimics the structure of the resulting tree.

## Templates

Imp templates look like this:

``` julia
[table
  @query message(message) begin
    [tr
      @query sent_by(message) => sent_by begin
        [td "$sent_by:"]
      end
      @query text(message) => text begin
        [td "$text"]
      end
      [td 
        @query likes(liker, message) begin
          [div "$liker likes this!"]
        end
      ]
      [td 
        [button "like!" onclick="new_like($session, $message)"]
      ]
    ]
  end
]
```

Templates are made up of four kinds of elements:

* DOM nodes like `[table ...]`
* DOM attributes like `onclick="new_like($session, $message)"`
* Text nodes like `"$liker likes this!"`
* Query fragments like `@query likes(liker, message) begin ... end`

The query fragment `@query likes(liker, message) begin ... end` acts much like a for loop. For each row in the `likes` relation, we create a copy of everything between `begin` and `end`. But any variables that have already appeared in a parent query fragment are already bound, so we keep only the rows that have matching values. The equivalent code in the OOPy template would be something like {% raw %}`{% for like in likes if like.message == message.id %} ... {% endfor %}`{% endraw %}. 

Let's see how this works out in practice. Here is the data behind the screenshot from the beginning of this post:

``` julia
message(1)
message(2)
message(3)
message(4)

sent_by(1) => "alice"
sent_by(2) => "bob"
sent_by(3) => "chia"
sent_by(4) => "chia"

text(1) => "hello"
text(2) => "hi"
text(3) => "greetings"
text(4) => "free tacos all round!"

likes("alice", 4)
likes("bob", 4)
```

YOU ARE HERE

To combine this data with the template above, we treat each query fragment just like a `for` loop over the rows in the corresponding relation, except that whenever we use a variable name that already appeared higher up in the tree we only loop over rows with the same value. For example, inside the filled out query fragment `visible(todo=1)` we repeat the query fragment `text(todo, text)` for every row that matches `todo=1`. (This is effectively a [lateral join](https://blog.heapanalytics.com/postgresqls-powerful-new-join-type-lateral/)).

The filled out query fragments are sorted by the values of their variables, in the order that the variables appear in the template text. So the `visible(todo)` fragments are sorted by `todo`, the `text(todo, text)` fragments are sorted by `todo, text` etc.

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

Next, anywhere that an interpolated variable such as `$todo` appears inside a string, we replace it with the value of that variable. So within the `visible(todo=1)` query fragment, `"escape_editing($todo)"` becomes `"escape_editing(1)"`.

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

Now that the data has been filled in we don't need the query fragments anymore, so they are each removed and replaced by their children.

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

## Patching

As described so far, this is only good for one-off rendering. We need to define what happens when the underlying data changes eg:

``` julia
+visible(2)
-visible(3)
-checked(1)
```

With the new data, the filled-out template now looks like:

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

* When a new row is added to a relation, everything under the corresponding query fragment is created from scratch.
* When a row is removed from a relation, everything under the corresponding query fragment is deleted.

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

This provides a simple mental model that is easy to map to the visual appearance of the template. 

The user can easily control how the DOM is mutated by changing the position of the query fragments. For example, our template currently has `text(todo, text)` above the `li` node. This means that if the text of a todo is changed, the entire `li` node will be deleted and recreated. If this is not acceptable, we could move the `text(todo, text)` down closer to the nodes that it actually affects.

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

## Events

We also need to be able to react to user input. 

In Imp, we can tag certain relations as event relations.

``` julia
@event delete_todo(todo::Int64)
```

For every event relation, a matching javascript function is created that will insert a row into that relation. Event handlers in the template can call these functions to send data back to the server.

``` julia
[button class="destroy" onclick="delete_todo($todo)"]
```

But we also still allow arbitrary javascript in event handlers, which is useful for eg reading state from the DOM.

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

## Sessions 

We give each browser tab a unique session key. The template is implicitly wrapped in `session(session) do ... end` so that it can behave differently for each session. 

For example, in our todo list we want the filter to be set per tab, not globally. 

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

## Implementation

As much as possible we want to do the work in Imp queries. This lets us take advantage of the query compiler for efficient joins. It also means that when I get around to implementing [incremental view maintenance](http://blogs.evergreen.edu/sosw/files/2014/04/Green-Vol5-DBS-017.pdf), I'll get incremental template evaluation for free.

Before we walk through the template compiler, let's pick a slightly simpler example.

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

The first thing the compiler does is number all the nodes, depth-first, to make it easier to refer to them.

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

Next, for each query fragment we create a corresponding query that performs the join against it's parent. We also create an id for each filled out query fragment by hashing together the node id and all the variable values. (This id is just used as a shorthand reference - if hash collisions are worrying you could use some kind of lookup table or even just use the list of variable values directly.)

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
# --- results (with made-up hashes) ---

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

Next we need to calculate what order the remaining nodes will be in after the query fragments are removed. Doing this in a way that is amenable to efficient incremental maintenance is tricky, but I eventually hit upon an elegant solution:

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

(A potential confusion - when we say "nth child of node x" we mean the nth child in the *template*, not in the resulting DOM tree. We can't use the positions in the DOM tree because those are exactly what we are trying to calculate.)

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

For each DOM node in the template we create a query that calculates the correct sort key, as well as the node id, the parent node id, the type of DOM node and the content.

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
# --- results (with made-up hashes) ---

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

Which results in these downstream changes:

``` julia
+group_1("session_1", 1, 1, 0, 1, 0, "make a todo list", 1) => (0x1, 0x5, Text, "displaying: make a todo list")
-group_1("session_1", 1, 2, 1, 1, 0, "bar", 1) => (0x1, 0x3, Text, "displaying: bar")
+group_1("session_1", 1, 1, 4, 1, 0, "more milk!", 1) => (0x1, 0x6, Text, "displaying: more milk!")
```

We can look at the updated `group_1` to find out that the next node after `0x5 displaying: make a todo list` is `0x2 displaying:foo` and that there is no node after `0x6 displaying: more milk!`. So we send the following commands to the client browser:

``` julia
delete(0x3)
insertBefore(0x5, "text", "displaying: make a todo list", parent=0x1, sibling=0x2)
insertAtEnd(0x6, "text", "displaying: more milk!", parent=0x1)
```

The nodes in each group are sorted in the order they will appear in the DOM and the groups themselves are sorted in depth-first order, so if we generate these instructions by order of group and then reverse order within the group, we can be sure that by the time each instruction is run the parent and sibling will always exist.

Finally, attributes like `class="main"` are handled almost identically to html and text nodes, except that their order doesn't matter so the sort key is empty.

## Expressiveness

All the examples in this post only spliced data into text nodes, but the implementation allows splicing anywhere:

``` julia
dynamic_tag(tag) do
  ["$tag"
    dynamic_attributes(key, val) do
      "$key"="$val"
    end
  ]
end
```

The current implementation expects one huge template for the entire app but it should be trivial to allow composable components eg we could break the example from the previous section into two components:

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

Currently templates are limited to a fixed depth, so they can't express eg a file browser where the depth depends on the data. Allowing components to include themselves recursively would fix this, but it's non-obvious how to combine recursion with the query-based implementation I described earlier. It's probably not impossible, but I won't attempt to deal with it until I definitely need it.

## Performance

I won't know for sure how well this will perform until I've built something more substantial, but for early feedback I ran some simple timings on the [Todomvc example](https://github.com/jamii/imp/blob/master/examples/Todo.jl) and compared it the [official React implementation](http://todomvc.com/examples/react/#/) and [some old Om implementation](http://swannodette.github.io/todomvc/labs/architecture-examples/om/index.html). This is not intended to be a pissing contest - I'm just trying to get a handle on whether performance is likely to be a problem.

My approach is not particularly rigorous. I just ran through all the benchmarks a few times to warmup, and then recorded a profile. 

Imp does all the hard work on the server, so its profiles just show the initial message send and then the patching at the end. React does all the work at once, leading to single long trace. Om does some work to update the app model, and then calculates the diff and patches the DOM on the next animation frame, resulting in two traces.

Adding 1st todo in Imp:

![](/img/imp-1.png)

Adding 1st todo in React:

![](/img/react-1.png)

Adding 1st todo in Om:

![](/img/om-1.png)

Adding 200 todos at once in Imp:

![](/img/imp-200.png)

(I couldn't be bothered to compile the React demo myself to add a button to add 200 todos.)

Adding 200 todos at once in Om:

![](/img/imp-200.png)

Adding the 201st todo in Imp:

![](/img/imp-201.png)

Adding the 201st todo in React:

![](/img/react-201.png)

Adding the 201st todo in Om:

![](/img/om-201.png)

I won't bother reading too much detail into those numbers, but it's clear that Imp is in the same ballpark as React and Om for this simple example.

Bear in mind also that this is recalculating the UI for each tab from scratch on each event. The UI calculation is built up entirely out of simple joins so in theory it should be easy to maintain incrementally.

I also tested how the server scales with multiple sessions connected. This table shows the total time taken by the server to add the 201st todo and update every client (mean of 100 runs).

| tabs | time (ms) |
|-------|-----------|
| 1     | 9         |
| 10    | 22        |
| 100   | 168       |
| 1000* | 2056      |

(\*Chrome has a cunning optimization where after ~150 tabs it just stops loading pages, so the last row is 100 real tabs and 900 fake sessions.)

This is the cost to recalculate everything from scratch and is not proportional to the number of events processed, so if I add some kind of event batching it looks like I could handle up to 100 clients with reasonable latency, even without incremental maintenance.

Breaking down the costs at 100 tabs:

* The marginal cost per tab is about 1.6ms. The bulk of the time is spent sorting and resorting relations, rather than solving queries.

* The marginal allocation rate per tab is 1mb across 5373 allocations. This is almost entirely in the template queries. Most of the individual allocations are from creating identical event strings on each of 200 todos x 100 tabs, but the bulk of the allocation size is from many, many copies of the columns in these relations.

So there is probably a lot of margin for improvement in the control flow layer that binds the queries together and handles sorting/indexing relations. Which is unsurprising, because one of the top items on my todo list is `control flow is a pile of poop - make it not that`.

Overall, I'm pleasantly surprised that it's already this fast.

## Status

The current implementation is not pretty, but it works well enough to demonstrate that this is feasible for simple examples. 

I targeted the browser purely for familiarity. The same approach should work with native UI toolkits too, and I may well switch in the future.

Running everything on the server has obvious limitations wrt latency and maximum load. I *think* this approach could be scaled to handle public webapps with many users, but it would require a much more sophisticated implementation, with some way to run parts of the logic on the client. 

I haven't given much thought to security yet. A good start would be to track what events are present in the template and refuse to allow clients to submit any events that aren't on the list.

The implementation strategy here produces non-recursive views which only use simple joins, string concatenation and hashing. It should be possible to target pretty much any relational system.

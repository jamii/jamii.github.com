---
layout: "post"
title: "Relational UI"
date: "2017-07-19 11:12"
---

* background
  * orm
  * different magic layer
  * previous approaches not good enough
  * goals / non-goals
* semantics
  * template example
  * incremental rendering, client-side state - change guarantees
  * events and async
* implementation
  * compile to imp as much as possible
  * generate query nodes
  * collapsing/sorting is hard - sort keys
  * diffing/rendering
  * sessions
* evaluation 
  * todomvc
  * benchmark, not incremental yet, x10
  * expresivity, expansion, unlimited trees

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

(I *think* this approach could be scaled to handle public webapps with many users, but it would require a much more sophisticated implementation, with some way to run parts of the logic on the client.)

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
            value="$text"
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
            value="$text"
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
            value="quux"
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
      value="quux"
      onkeydown="""
        if (event.which == 13) finish_editing(3, this.value)
        if (event.which == 27) escape_editing(3)
      """
      onblur="escape_editing(3)"
    ]
  ]
]
```

And finally send this to the client to be rendered as html.

blah blah about client-side state

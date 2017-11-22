---
layout: post
title: Staged interpreters in Rust
---

Last week I was writing an interpreter for a query language. On arithmetic-heavy queries the interpreter overhead was >10x compared to a compiled baseline. I tried staging the interpreter to move the overhead out of the inner loops. I didn't end up finishing it, but I think it's a neat idea anyway so I wrote a much simpler example to demonstrate. (It's essentially a [tagless staged interpreter](http://okmij.org/ftp/tagless-final/JFP.pdf) with the addition of shared mutable state).

Let's look at a much simpler example that I actually finished ([source code](https://github.com/jamii/rust-tagless/blob/master/src/main.rs)). It's an interpreter for a rather pointless little language that has just enough features to illustrate the idea.

``` rust
enum Type {
    Number,
    Bool,
}

enum Value {
    Number(i64),
    Bool(bool),
}

type Name = &'static str;

enum Expr {
    Constant(Value),
    Add(Box<Expr>, Box<Expr>), // e1 + e2
    LessThan(Box<Expr>, Box<Expr>), // e1 < e2
    Let(Name, Type, Box<Expr>, Box<Expr>), // let v::t = e1 in e2
    Get(Name), // v
    Set(Name, Box<Expr>), // v = e
    While(Box<Expr>, Box<Expr>), // while e1 { e2 }
}
```

This is enough to write a rather pointless little program:

``` rust
// let i = 1 {
//   while i < 1000 {
//     i = i + 1
//   }
// }
let expr = Expr::Let(
    "i", Type::Number, box Expr::Constant(Value::Number(1)),
    box Expr::While(
        box Expr::LessThan(box Expr::Get("i"), box Expr::Constant(Value::Number(1000))),
        box Expr::Set(
            "i",
            box Expr::Add(box Expr::Get("i"), box Expr::Constant(Value::Number(1))),
        ),
    ),
);
println!("{:?}", interpret(&HashMap::new(), &expr));
```

Let's look at what happens in the interpreter when we run this program.

``` rust
enum Variable {
    Number(Cell<i64>),
    Bool(Cell<bool>),
}

fn interpret(env: &HashMap<Name, Variable>, expr: &Expr) -> Value {
    match *expr {
        ...
        Expr::Add(ref expr1, ref expr2) => {
            let value1 = interpret(env, expr1);
            let value2 = interpret(env, expr2);
            match (value1, value2) {
                (Value::Number(number1), Value::Number(number2)) => Value::Number(
                    number1 + number2,
                ),
                _ => panic!("Type error!"),
            }
        }
        Expr::Get(ref name) => {
            match env.get(name).unwrap() {
                &Variable::Number(ref number_cell) => Value::Number(number_cell.get()),
                &Variable::Bool(ref bool_cell) => Value::Bool(bool_cell.get()),
            }
        }
        Expr::Set(ref name, ref expr) => {
            let value = interpret(env, expr);
            match (env.get(name).unwrap(), &value) {
                (&Variable::Number(ref number_cell), &Value::Number(number)) => {
                    number_cell.set(number);
                    value
                }
                (&Variable::Bool(ref bool_cell), &Value::Bool(bool)) => {
                    bool_cell.set(bool);
                    value
                }
                _ => panic!("Type error!"),
            }
        }
        Expr::While(ref expr1, ref expr2) => {
            while true {
                match interpret(env, expr1) {
                    Value::Bool(true) => {
                        interpret(env, expr2);
                    }
                    Value::Bool(false) => break,
                    _ => panic!("Type error!"),
                }
            }
            Value::Bool(false)
        }
    }
}
```

The loop in our program executes `i = i + 1` on each iteration, and on each iteration we:

1. Check what to do with each expression: `match *expr { ... }`
2. Get the variable `i` from the environment hashtable twice: `env.get(name)`
3. Check that the types of `i` and `1` are the same: `match (value1, value2) { ... }`
4. Check that the types of `i` and `i + 1` are the same: `match (env.get(name).unwrap(), &value) { ... }`

This is all wasted work. We know at the start of the loop that each of these decisions is going to come out the same way on every iteration. How can we avoid doing them on every iteration?

Suppose we have one pass that makes the decisions and another pass that actually runs the program. Something like:

``` rust
let staged: Staged = stage(&HashMap::new(), &expr);
let result = run(staged);
```

What is `Staged`? It's a thing that we can run and get back a `Value`. So the most general type we could use is a closure that returns `Value`:

``` rust
type Staged = Box<Fn() -> Value>
```

But we actually need a bit more information to build these efficiently. Remember we want to know the type of things ahead of time so that we don't have to check on every loop. So we need to pull the tag out of the `Value` and wrap the entire closure:

``` rust
enum Staged {
    Number(Box<Fn() -> i64>),
    Bool(Box<Fn() -> bool>),
}
```

These closures are going to close over variables, so we also need to make the variables shareable between multiple closures by adding a reference counted pointer:

``` rust
enum StagedVariable {
    Number(Rc<Cell<i64>>),
    Bool(Rc<Cell<bool>>),
}
```

Now we can just glue together bits of code to make these closures:

``` rust
fn stage(env: &HashMap<Name, StagedVariable>, expr: &Expr) -> Staged {
    match *expr {
        ...
        Expr::Add(ref expr1, ref expr2) => {
            let staged1 = stage(env, expr1);
            let staged2 = stage(env, expr2);
            match (staged1, staged2) {
                (Staged::Number(number1), Staged::Number(number2)) => Staged::Number(box move || {
                    number1() + number2()
                }),
                _ => panic!("Type error!"),
            }
        }
        Expr::Get(ref name) => {
            match env.get(name).unwrap() {
                &StagedVariable::Number(ref number_cell) => {
                    let number_cell = number_cell.clone();
                    Staged::Number(box move || number_cell.get())
                }
                &StagedVariable::Bool(ref bool_cell) => {
                    let bool_cell = bool_cell.clone();
                    Staged::Bool(box move || bool_cell.get())
                }
            }
        }
        Expr::Set(ref name, ref expr) => {
            let staged = stage(env, expr);
            match env.get(name).unwrap() {
                &StagedVariable::Number(ref number_cell) => {
                    match staged {
                        Staged::Number(number) => {
                            let number_cell = number_cell.clone();
                            Staged::Number(box move || {
                                let number = number();
                                number_cell.set(number);
                                number
                            })
                        }
                        _ => panic!("Type error!"),
                    }
                }
                &StagedVariable::Bool(ref bool_cell) => {
                    match staged {
                        Staged::Bool(bool) => {
                            let bool_cell = bool_cell.clone();
                            Staged::Bool(box move || {
                                let bool = bool();
                                bool_cell.set(bool);
                                bool
                            })
                        }
                        _ => panic!("Type error!"),
                    }
                }
            }
        }
        Expr::While(ref expr1, ref expr2) => {
            match stage(env, expr1) {
                Staged::Bool(bool1) => {
                    Staged::Bool(match stage(env, expr2) {
                        Staged::Bool(bool2) => {
                            box move || {
                                while bool1() {
                                    bool2();
                                }
                                false
                            }
                        }
                        Staged::Number(number2) => {
                            box move || {
                                while bool1() {
                                    number2();
                                }
                                false
                            }
                        }
                    })
                }
                _ => panic!("Type error"),
            }
        }
    }
}
```

Compared to before, on each iteration we now:

1. Call a function pointer to find out what to do with each expr
2. Close over the variable `i` and just need to dereference a pointer
3. Have already checked that the types of `i` and `1` are the same
4. Have already checked that the types of `i` and `i + 1` are the same

Calling a function pointer is cheaper than a single hashtable lookup. The actual interpreter I was working had much more overhead per bytecode and typically executed heavily nested loops, so this was a clear win.

It wasn't all positive though. I struggled with the increasing complexity of the code:

1. I needed to read external data, so the actual type was `type Staged<'a> = Box<Fn() -> Value + 'a>`. The lifetimes infected everything else.
2. Even though the closures themselves are typically polymorphic, we need to dispatch on type to get a specialized version of the closure for each type. In the example above we are only dispatching on a single two-way type so it isn't so bad. In the real version I had some MxN dispatches that created [astonishing amounts of boilerplate](https://github.com/jamii/imp/blob/3f442d30bd845a39f5cbeb7f5360529af068bc69/src/interpreter.rs#L660-L793). 
3. The compiled baseline keeps all state on the stack. To do the same in the staged interpreter we would have to allow each closure to take arguments instead of closing over shared mutable state. The trouble is that while we know the size of each argument in advance, we can't write code that is generic over the number of arguments. So we'd still end up having to heap-allocate a `Vec<Argument>` or similar. Unless we dispatched on the size too...

In the end the whole thing was nixed by the fact that the staged interpreter had already become way more complex than the compiler I had written previously and that the improvements in compile time were more than lost by the slower run time.

I'm still curious whether the complexity can be circumvented, but I don't have time to explore it further myself.



---
layout: post
title: Zero-copy deserialization in Julia
---

While working with [RelationalAI](http://relational.ai/) I wrote a library for zero-copy deserialization in Julia. Not super exciting in itself, but it nicely demonstrates the kinds of zero-overhead abstractions that are possible in Julia.

## The problem

Folks at RelationalAI want to build various complex on-disk data-structures, with these constraints:

* The system is typically bottle-necked on memory bandwidth already, so deserializing on-disk data-structures into a separate in-memory data-structure is unacceptable. They need to operate directly on mmap-ed memory.

* The data-structures will be mmap-ed into multiple different processes. The virtual memory mapping won't stay the same, so the data-structures have to use relative offsets instead of absolute pointers.

* The data-structures are large and most use-cases typically only touch a small portion of each mmap-ed chunk, so converting all offsets to pointers in place at load time (aka [pointer swizzling](https://en.wikipedia.org/wiki/Pointer_swizzling)) is too wasteful of memory bandwidth.

Additionally, the query compiler reading these data-structures is written in Julia. We still could implement the data-structures in C, but then the query compiler wouldn't be able to benefit from specializing on the types of the data-structures. In other words, there is a potential performance boost if we can do the whole thing in Julia.

Let's even throw in some additional constraints:

* When debugging, we want to do bounds-checking so we get exceptions instead of segfaults.

* When not debugging, we want to have minimal overhead vs writing the same code in C.

## Building blocks

Julia offers pointers:

``` julia
julia> p = Libc.malloc(2^5)
Ptr{Nothing} @0x00000000019887a0
```

Pointers are typed, but we can cast them to other types freely: 

``` julia
julia> p = convert(Ptr{Int64}, p)
Ptr{Int64} @0x00000000019887a0

julia> unsafe_store!(p, 42)
Ptr{Int64} @0x00000000019887a0

julia> unsafe_load(p)
42

julia> unsafe_store!(p+1, 0)
Ptr{Int64} @0x00000000019887a1

julia> unsafe_load(p+1)
0
```

And we can use any plain-old-data type, not just primitives:

``` julia
julia> struct Foo
         x::Int64
         y::Float64
         z::Bool
       end

julia> p = convert(Ptr{Foo}, p)
Ptr{Foo} @0x00000000019887a0

julia> unsafe_store!(p, Foo(42, 3.14, false))
Ptr{Foo} @0x00000000019887a0

julia> unsafe_load(p)
Foo(42, 3.14, false)
```

In [type-stable](http://www.johnmyleswhite.com/notebook/2013/12/06/writing-type-stable-code-in-julia/) code, these operations compile down to the corresponding llvm primitives, producing the same asm you would expect from C:

``` julia
julia> function f(p)
         p += sizeof(Int64) # skip Foo.x
         p = convert(Ptr{Float64}, p)
         unsafe_load(p) # read Foo.y
       end
f (generic function with 1 method)

julia> @code_native f(p)
	.text
; Function f {
; Location: REPL[11]:5
; Function unsafe_load; {
; Location: pointer.jl:105
; Function unsafe_load; {
; Location: REPL[11]:2
	vmovsd	8(%rdi), %xmm0          # xmm0 = mem[0],zero
;}}
	retq
	nopw	%cs:(%rax,%rax)
;}
```

But like C they are totally unsafe:

``` julia
julia> unsafe_load(p+2^32)

signal (11): Segmentation fault
```

And they require us to do all our offset calculation and pointer arithmetic by hand.

## Magic

The [Blobs](https://github.com/jamii/Blobs.jl/tree/c1c9061659b8480f7b7264a8cd1d4d0075e6bd44) library just adds some structure on top of these building blocks, while still compiling down to efficient native code. 

``` julia
julia> using Pkg

julia> Pkg.add(PackageSpec(url="git@github.com:jamii/Blobs.jl.git", rev="c1c906"))
...

julia> using Blobs

```

Blobs are created from raw pointers:

``` julia
julia> b = Blob{Foo}(Libc.malloc(2^5), 2^5)
Blob{Foo}(Ptr{Nothing} @0x0000000003a2fdc0, Ptr{Nothing} @0x0000000003a2fdc0, 32)
```

There is some syntax sugar for load/store:

``` julia
julia> b[] = Foo(42, 3.14, false)
Foo(42, 3.14, false)

julia> b[]
Foo(42, 3.14, false)
```

And for the pointer arithmetic needed to read individual fields:

``` julia
julia> b.y
Blob{Float64}(Ptr{Nothing} @0x0000000003a2fdc0, Ptr{Nothing} @0x0000000003a2fdc8, 32)

julia> b.y - b
0x0000000000000008

julia> b.y[] = 1.0
1.0

julia> b.y[]
1.0

julia> b[]
Foo(42, 1.0, false)
```

Dereferenceing is bounds-checked

``` julia
julia> (b - 1)[]
ERROR: BoundsError: attempt to access Blob{Foo}(Ptr{Nothing} @0x0000000003a2fdc0, Ptr{Nothing} @0x0000000003a2fdbf, 32)
Stacktrace:
 [1] boundscheck at /home/jamie/.julia/dev/Blobs/src/blob.jl:47 [inlined]
 [2] getindex(::Blob{Foo}) at /home/jamie/.julia/dev/Blobs/src/blob.jl:53
 [3] top-level scope at none:0

julia> (b + 2^5)[]
ERROR: BoundsError: attempt to access Blob{Foo}(Ptr{Nothing} @0x0000000003a2fdc0, Ptr{Nothing} @0x0000000003a2fde0, 32)
Stacktrace:
 [1] boundscheck at /home/jamie/.julia/dev/Blobs/src/blob.jl:47 [inlined]
 [2] getindex(::Blob{Foo}) at /home/jamie/.julia/dev/Blobs/src/blob.jl:53
 [3] top-level scope at none:0
```

Bounds-checking can be turned off, either locally with the `@inbounds` macro or globally by starting julia with `--check-bounds=no`. With bounds-checking disabled, the only overhead is a single extra `movq` to unpack the `Blob` struct.

``` julia
julia> function f(b)
         @inbounds b.y[]
       end
f (generic function with 1 method)

julia> @code_native f(b)
	.text
; Function f {
; Location: REPL[24]:2
; Function getproperty; {
; Location: blob.jl:150
; Function getindex; {
; Location: blob.jl:91
; Function macro expansion; {
; Location: blob.jl:95
; Function +; {
; Location: blob.jl:32
; Function +; {
; Location: pointer.jl:155
; Function Type; {
; Location: REPL[24]:2
	movq	8(%rdi), %rax
;}}}}}}
; Function getindex; {
; Location: blob.jl:54
; Function unsafe_load; {
; Location: blob.jl:110
; Function macro expansion; {
; Location: blob.jl:113
; Function unsafe_load; {
; Location: pointer.jl:105
; Function unsafe_load; {
; Location: pointer.jl:105
	vmovsd	8(%rax), %xmm0          # xmm0 = mem[0],zero
;}}}}}
	retq
	nopw	(%rax,%rax)
;}
```

Even for nested structs:

``` julia
julia> struct Bar
           x::Int64
           foo::Foo
       end

julia> struct Quux
           bar::Bar
           y::Int64
       end

julia> b = Blob{Quux}(b)
Blob{Quux}(Ptr{Nothing} @0x0000000003a2fdc0, Ptr{Nothing} @0x0000000003a2fdc0, 32)

julia> function g(b)
           @inbounds b.bar.foo.y[]
       end
g (generic function with 1 method)

julia> @code_native g(b)
	.text
; Function g {
; Location: REPL[29]:2
; Function getproperty; {
; Location: blob.jl:150
; Function getindex; {
; Location: blob.jl:91
; Function macro expansion; {
; Location: blob.jl:95
; Function +; {
; Location: blob.jl:32
; Function +; {
; Location: pointer.jl:155
; Function Type; {
; Location: REPL[29]:2
	movq	8(%rdi), %rax
;}}}}}}
; Function getindex; {
; Location: blob.jl:54
; Function unsafe_load; {
; Location: blob.jl:110
; Function macro expansion; {
; Location: blob.jl:113
; Function unsafe_load; {
; Location: pointer.jl:105
; Function unsafe_load; {
; Location: pointer.jl:105
	vmovsd	16(%rax), %xmm0         # xmm0 = mem[0],zero
;}}}}}
	retq
	nopw	(%rax,%rax)
;}
```

## Optimization

Let's unpack the magic step by step.

We start with a simple function call

``` julia
function f(b)
  @inbounds b.y[]
end

b = Blob{Foo}(b)

f(b)
```

`.` and `[]` are just syntactic sugar for `Base.getproperty` and `Base.getindex` respectively:

``` julia
function f(b)
    @inbounds begin
        tmp1 = getproperty(b, :y)
        getindex(tmp1)
    end
end
```

Although the function has no type declarations, Julia does just-in-time type-inference and specialization. To begin with, all it can figure out is the type of the argument `b`, so we have something like:

``` julia
function f(b::Blob{Foo})
    @inbounds begin
        tmp1 = getproperty(b::Blob{Foo}, :y)
        getindex(tmp1)
    end
end
```

Since it knows the types of all the arguments to `getproperty` it can find the correct method:

``` julia
@inline function Base.getproperty(b::Blob{Foo}, k::Symbol)
    if k === :x
        Blob{Int64}(blob + 8)
    elseif k === :y
        Blob{Float64}(blob + 16)
    elseif k === :z
        Blob{Bool}(blob + 24)
    else
        error("type Blob{Foo} has no field $k")
    end
end
```

And after inlining `Base.getproperty` our function looks like this:

``` julia
function f(b::Blob{Foo})
    @inbounds begin
        tmp1 = begin
            if :y === :x
                Blob{Int64}(blob + 8)
            elseif :y === :y
                Blob{Float64}(blob + 16)
            elseif :y === :z
                Blob{Bool}(blob + 24)
            else
                error("type Blob{Foo} has no field $(:y)")
            end
        end
        getindex(tmp1)
    end
end
```

Constant propagation has a field day with expressions like `if :y === :x`, leaving us with:

``` julia
function f(b::Blob{Foo})
    @inbounds begin
        tmp1 = Blob{Float64}(blob + 16)
        getindex(tmp1)
    end
end
```

Type inference kicks in again, figuring out the obvious type of `tmp`:

``` julia
function f(b::Blob{Foo})
    @inbounds begin
        tmp1::Blob{Float64} = Blob{Float64}(blob::Blob{Foo} + 16)
        getindex(tmp1::Blob{Float64})
    end
end
```

Now it can find the correct method for `getindex`:

``` julia
Base.@propagate_inbounds function Base.getindex(blob::Blob{T}) where T
    boundscheck(blob)
    unsafe_load(blob)
end

Base.@propagate_inbounds function boundscheck(blob::Blob{T}) where T
    @boundscheck begin
        if !(0 <= getfield(blob, :offset) - getfield(blob, :base) <= getfield(blob, :limit) - self_size(T))
            throw(BoundsError(blob))
        end
    end
end
```

After inlining again we have:

``` julia
function f(b::Blob{Foo})
    @inbounds begin
        tmp1::Blob{Float64} = Blob{Float64}(blob::Blob{Foo} + 16)
        @boundscheck begin
            if !(0 <= getfield(blob, :offset) - getfield(blob, :base) <= getfield(blob, :limit) - self_size(T))
                throw(BoundsError(blob))
            end
        end
        unsafe_load(blob)
    end
end
```

Any `@boundscheck` that is inside an `@inbounds`, either lexically or after inlining through `@propagate_inbounds`, is removed.

``` julia
function f(b::Blob{Foo})
    @inbounds begin
        tmp1::Blob{Float64} = Blob{Float64}(blob::Blob{Foo} + 16)
        unsafe_load(blob)
    end
end
```

Since we know at compile time that `tmp1` has type `Blob{Float64}`, which is an immutable value-type, it will be stack allocated, leaving us with some fairly tight LLVM bitcode:

``` julia
julia> @code_llvm f(b)

; Function f
; Location: REPL[31]:2
define double @julia_f_36819({ i64, i64, i64 } addrspace(11)* nocapture nonnull readonly dereferenceable(24)) {
top:
; Function getproperty; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:150
; Function getindex; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:91
; Function macro expansion; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:95
; Function +; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:32
  %1 = getelementptr inbounds { i64, i64, i64 }, { i64, i64, i64 } addrspace(11)* %0, i64 0, i32 1
; Function +; {
; Location: pointer.jl:155
; Function Type; {
; Location: boot.jl:728
  %2 = bitcast i64 addrspace(11)* %1 to i8* addrspace(11)*
  %3 = load i8*, i8* addrspace(11)* %2, align 8
;}
  %4 = getelementptr i8, i8* %3, i64 16
;}}}}}
; Function getindex; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:54
; Function unsafe_load; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:110
; Function macro expansion; {
; Location: /home/jamie/.julia/dev/Blobs/src/blob.jl:113
; Function unsafe_load; {
; Location: pointer.jl:105
; Function unsafe_load; {
; Location: pointer.jl:105
  %5 = bitcast i8* %4 to double*
  %6 = load double, double* %5, align 1
;}}}}}
  ret double %6
}
```

## Code generation

I glossed over one important step - where did this method of `Base.getproperty` come from?

``` julia
@inline function Base.getproperty(b::Blob{Foo}, k::Symbol)
    if k === :x
        Blob{Int64}(blob + 8)
    elseif k === :y
        Blob{Float64}(blob + 16)
    elseif k === :z
        Blob{Bool}(blob + 24)
    else
        error("type Blob{Foo} has no field $k")
    end
end
```

Obviously, we don't want to write this by hand.

We could do some metaprogramming trick where we register the types we want to use and this creates all the appropriate methods:

``` julia
function register_blob_type(T)
    code = quote
        function Base.getproperty(blob::Blob{$T}, field::Symbol)
           $(Expr(:meta, :inline))
           $(@splice (i, fieldname) in enumerate(fieldnames(T)) quote
               if field == $fieldname
                   return Blob{$(fieldtype(T, i))}(blob + blob_offset(T, $(Val{i})))
               end
           end)
           error("type $T has no field $field")
        end
    end
    eval(code)
end

register_blob_type(Foo)
```

But Julia offers us something nicer. Rather than registering types in advance, we can make a 'generated' function, one which hooks into Julia's just-in-time specialization and decides what code to compile based on the types of it's arguments.

``` julia
@generated function Base.getproperty(blob::Blob{T}, field::Symbol) where T
    quote
        $(Expr(:meta, :inline))
        $(@splice (i, fieldname) in enumerate(fieldnames(T)) quote
            if field == $fieldname
                return Blob{$(fieldtype(T, i))}(blob + blob_offset(T, $(Val{i})))
            end
        end)
        error("type $T has no field $field")
    end
end
```

From the outside, generated functions behave just like a normal function. This allows seamlessly mixing metaprogrammed code generation into normal code, without changing the outward interface or requiring consumers of the library to pre-register types. 

## More

The rest of the library packs in custom memory layout by adding new methods to the layout functions (which is how nested Blobs are [converted to/from offsets on read/write](https://github.com/jamii/Blobs.jl/blob/c1c9061659b8480f7b7264a8cd1d4d0075e6bd44/src/blob.jl#L157-L172)), implementations of [fixed size vectors](https://github.com/jamii/Blobs.jl/blob/c1c9061659b8480f7b7264a8cd1d4d0075e6bd44/src/vector.jl) / [bitvectors](https://github.com/jamii/Blobs.jl/blob/c1c9061659b8480f7b7264a8cd1d4d0075e6bd44/src/bit_vector.jl) / [strings](https://github.com/jamii/Blobs.jl/blob/c1c9061659b8480f7b7264a8cd1d4d0075e6bd44/src/string.jl) and [helper functions for initialization of complex data-structures](https://github.com/jamii/Blobs.jl/blob/c1c9061659b8480f7b7264a8cd1d4d0075e6bd44/src/layout.jl). All with similarly minimal overhead vs C.

As with the examples here, most of the work is done by the combination of type inference, type specialization and generated functions, with occasional uses of forced inlining to guarantee constant propagation. Unlike, say, a tracing JIT, this is predictable and deterministic. With some experience, it's easy to write this kind of code and predict what Julia will do with it, allowing libraries like Blobs to provide abstractions without overhead.

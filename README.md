# GeneratedTypes

`@Generated` — *Prepare for the end of types as we know them...*

[![Build Status](https://travis-ci.org/andyferris/GeneratedTypes.jl.svg?branch=master)](https://travis-ci.org/andyferris/GeneratedTypes.jl)

**NOTE:** This package appears to be Julia 0.4 only.

Julia's dynamic-yet-static type system is a careful balance between execution
speed and programmer convenience. Data can either be strongly-typed, creating
code with *C*-like speed, or boxed and inferred at run-time, which makes many
algorithms easier to write (with opportunities to optimize the most critical
code later).

However, underlying this, Julia *types* themselves are rather static objects.
While this is an understandable requirement to make compilation feasible (or
even sensible), there is room for a little extra freedom. Julia functions are
not only recompiled for each type *name*, but also for each unique set of
parameters of the input types. Thus, the system allows to decouple the
definition of the fields to the type-name, and bring this to a more granular
definition where the fields names, number and type may be fully-dependent on
the parameters of a type.

This is where `@Generated` types come in. Much like, `@generated` functions,
`@Generated` types allow one to generated code to specify the type definition
depending on the input. In this case, the input is not the types of the arguments
to the constructor, but rather is the parameters of the type itself. As a simple
example, take:

```julia
@Generated type MultiType{N,T}
    exprs = [:($(Symbol(string("x_",i))) :: T) for i = 1:N]
    Expr(:block, exprs...)
end
```

This creates what is more-or-less a static vector of length `N` and type `T`:

```julia
julia> MultiType{3,Float64}(1,2,3)
MultiType{3,Float64}(1.0,2.0,3.0)

julia> m.x_2
2.0
```

These generated types are (designed to be) fully-fledged Julia types that will
support all the features of the language, inference and codegen that apply to
standard `immutable` and `type` definitions.

### Implementation

The quickest explanation is the steps taken.

1) The @Generated macro takes the type definition and creates an abstract type
of the same name as given.
2) The macro also creates and registers an abstract type constructor, which
is a @generated function.
3) When the user calls this generated function, it will use `eval` to create a
concrete subtype without any remaining type parameters and having a mangled name
(inserting `#` and the type parameters to the end of the name). This occurs just
once, during the codegen phase (or if you call the constructor with different
input, Julia gracefully allows you to `eval` the exact same type definition more
than once).
4) It overloads `Base.show` on the type to hide what is happening, also during
the codegen phase.
5) The generated function's action is to call the (inner) constructor of the
concrete type.

This provides a mostly invisible experience to the user. Since multiple dispatch
works fine with the abstract type, it should be easy write functions for the
new type without knowing the mangled name. Outer constructors can also be
written for the abstract type (e.g. useful for where some of the type parameters
are not explicitly defined).

### Current limitations

The code inserted into the body of the type is an `Expr(:block, ...)`, not a
function definition like a `@generated` function. Thus `return` is to be
avoided and natural scoping rules must be utilized to return the desired output.

Also, hopefully somewhat obviously, the codegen can only depend on
the parameters of the type, and not for instance the type of the input to its
constructor. If it is not pure (constant in time), you may experience errors
for redefining a concrete type. If you wish to define your
type depending on the input to a constructor, you need to explicitly define extra
constructors on your abstract type (that call the fully-parameterized version).

Finally, calling `eval` from a generated function appears to be forbidden in Julia
0.5, making the package as it stands inoperable on the latest nightly builds.

### Some *very* simple examples

```julia

@Generated type SimpleType
end

@show SimpleType()

@Generated type FieldType
    if 1 < 2
        quote
            a::Int
        end
    else
        quote
            nothing
        end
    end
end

@show FieldType(1)

@Generated type MultiType{N, T}
    exprs = [:($(Symbol(string("x_",i))) :: T for i = 1:N]
    Expr(:block, exprs...)
end

@show MultiType{1, Int}(1)

@show MultiType{3, Float64}(10,11,12)

abstract MyAbstract{T,N}

@Generated type Foo{T} <: MyAbstract{T,1}
    if isbits(T)
        quote
            x::Vector{T}
        end
    else
        quote
            x::T
        end
    end
end

@show Foo{Int}([1,2,3])
@show Foo{ASCIIString}("abc")
```

using GeneratedTypes
using Base.Test

# write your own tests here
@test 1 == 1

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

@Generated type MultiType{N}
    exprs = [:($(Symbol(string("x_",i))) :: Int) for i = 1:N]
    Expr(:block, exprs...)
end

@show MultiType{1}(1)

@show MultiType{3}(10,11,12)

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

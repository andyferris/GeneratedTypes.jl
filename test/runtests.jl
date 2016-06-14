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

@Generated type MultiType{N, T}
    exprs = [:($(Symbol(string("x_",i))) :: T) for i = 1:N]
    Expr(:block, exprs...)
end

@show MultiType{1,Int}(1)

@show MultiType{3,Int}(10,11,12)

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

@Generated immutable A{T <: Integer} <: MyAbstract{T,1}
end

@show A{Int}()

@Generated immutable B{T <: Integer}
end

@show B{Int}()

module GeneratedTypes

export @Generated

#macro debug(x)
#    esc(x)
#end

macro debug(x)
    nothing
end

macro Generated( expr )
    if expr.head != :type || !isa(expr.args[1], Bool)
        error("invalid syntrax: @Generated must be used with a type definition")
    end

    mutable = expr.args[1]
    @debug println("Type is mutable: $mutable")

    # Check the "head" type (i.e. expr.args[2]) is well-formed and get its name
    head_expr = expr.args[2]
    head_params = Vector{Symbol}()
    if isa(head_expr, Symbol)
        head_typename = head_expr
        head_fulltype = head_typename
    elseif isa(head_expr, Expr)
        if head_expr.head == :curly
            head_typename = head_expr.args[1] :: Symbol
            head_fulltype = head_expr
            head_params = Symbol[head_expr.args[i] for i = 2:length(head_expr.args)]
        elseif head_expr.head == :(<:)
            if isa(head_expr.args[1], Symbol)
                head_typename = head_expr.args[1]
                head_fulltype = head_typename
            elseif isa(head_expr.args[1], Expr) && head_expr.args[1].head == :curly
                head_typename = head_expr.args[1].args[1] :: Symbol
                head_fulltype = head_expr.args[1]
                head_params = Symbol[head_expr.args[1].args[i] for i = 2:length(head_expr.args[1].args)]
            else
                error("Malformed type name definition: $head_expr")
            end
        else
            error("Malformed type name definition: $head_expr")
        end
    else
        error("Malformed type name definition: $head_expr")
    end

    @debug println("Head name is $head_typename")
    @debug println("Head type is $head_fulltype")
    @debug println("Head definition is $head_expr")
    @debug println("Head parameters are $head_params")


    if isdefined(head_typename)
        #error("Cannot redefine constant $head_typename")
    end

    # Create an abstract type of the given name
    abstract_expr = Expr(:abstract, head_expr)
    @debug println("Abstract definition is $abstract_expr")
    eval(current_module(), abstract_expr)

    my_module = current_module()

    # The generation code could be `nothing`, a symbol, an expression, or whatever, but it can be `eval`ed to make the expression block and then `eval`ed inside a type definition
    field_expr = expr.args[3]
    @debug println("Field expr: \n $field_expr \n")

    # Create a generated function to construct the type when necessary and to deal with the name-mangling
    @debug @show (quote; $(Expr(:call, Expr(:curly, :call, head_params...), Expr(:(::), Expr(:curly, :Type, head_fulltype)), Expr(:(...), :x))); end)

    f_name = length(head_params) == 0 ? :call : Expr(:curly, :call, head_params...)

    # Now we need to replace the need to replace

    constructor_expr = quote
        @generated function $(f_name)(::Type{$(head_fulltype)}, x...)
            #($(Expr(:(::), Expr(:curly, :Type, head_fulltype))),$(Expr(:(...), :x)))
            #$(Expr(:call, Expr(:curly, :call, head_params...), Expr(:(::), Expr(:curly, :Type, head_fulltype)), Expr(:(...), :x)))
#            {$(head_params...}(::Type{$(head_fulltype)}, x...) # Constructor format. Not sure about (::Type{head_fulltype}){parameters}(x...)
            parent_type = $(head_fulltype)

            GeneratedTypes.@debug @show parent_type

            # Make a mangled typename for a non-parametric type
            typename_str = string(parent_type.name.name)
            for i = 1:length($(head_fulltype).parameters)
                if i == 1
                    typename_str = typename_str * "{"
                end
                typename_str = typename_str * (isa($(head_fulltype).parameters[i], TypeVar) ? string($(head_fulltype).parameters[i].name) : string($(head_fulltype).parameters[i]))
                if i == length($(head_fulltype).parameters)
                    typename_str = typename_str * "}"
                else
                    typename_str = typename_str * ","
                end
            end
            typename_str = typename_str * "#"

            typename = Symbol(typename_str)
            GeneratedTypes.@debug @show typename

            # Make the full type name definition
            type_defn = Expr(:(<:), typename, parent_type)
            GeneratedTypes.@debug @show type_defn

            # Evaluates the field expr
            field_expr_gen = () -> $field_expr
            field_expr = field_expr_gen()
            if isa(field_expr, Symbol)
                field_expr = quote
                    $field_expr
                end
            elseif isa(field_expr, Expr)
                if field_expr.head == :(::)
                    field_expr = quote
                        $field_expr
                    end
                elseif  field_expr.head != :block
                    error("Bad generated code for generated type. Recieved $field_expr")
                end
            end
            GeneratedTypes.@debug @show field_expr

            # The returned quoted expression needs to have the TypeVar symbols replaced by their specefic parameters
            parent_params = parent_type.parameters
            if !isempty(parent_params)
                GeneratedTypes.replace_symbols!(field_expr, $head_params, parent_params)
            end
            GeneratedTypes.@debug @show field_expr

            type_expr = Expr(:type, $mutable, type_defn, field_expr)
            GeneratedTypes.@debug @show type_expr

            # Check if it's already constructed (rely on name-mangling?)
            if !isdefined($my_module, typename)
                eval(type_expr)
            else
                # Let's assume the type was already constructed
                # Can happen when calling this constructor with different input
                # data types but same type parameters
            end

            # Overload Base.show(::Type{typename}) to lie about the name mangling.
            show_expr = quote
                Base.show(io::IO, ::Type{$typename}) = show(io, $parent_type);
            end
            GeneratedTypes.@debug @show show_expr
            eval(current_module(), show_expr)

            return :( $(typename)(x...) ) # inline?
        end
    end

    @debug println("Constructor expr: \n $constructor_expr \n")
    eval(current_module(), constructor_expr)
end

function replace_symbols!(a::Expr, symbols::Vector{Symbol}, exprs)
    for i = 1:length(a.args)
		if isa(a.args[i], Expr) && a.args[i].head != :line && a.args[i].head != :.
		    replace_symbols!(a.args[i], symbols, exprs)
        elseif isa(a.args[i], Symbol)
            notfound = true
            for j = 1:length(symbols)
                if a.args[i] == symbols[j]
                    a.args[i] = exprs[j]
                    notfound = false
                    break
                end
            end
        end
    end
end


# TODO it would be nice to match the types of input x... with the free type parameters, like in typical parameteric types (e.g. Complex(1,1) -> Complex{Int}(1,1) automagically).
# Its difficult to detect which input types match to which type parameters when you
# have arbitrary code evaluation, however. Partial solution is to
# instruct users to define more outer constructors on the abstract type
# that create a fully-defined abstract type and then this.

end # module

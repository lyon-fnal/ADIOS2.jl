# IO functions

export AIO
"""
    struct AIO

Holds a C pointer `adios2_io *`.
"""
struct AIO
    ptr::Ptr{Cvoid}
end

export define_variable
"""
    variable = define_variable(io::AIO, name::AbstractString, type::Type,
                         shape::Union{Nothing,CartesianIndex}=nothing,
                         start::Union{Nothing,CartesianIndex}=nothing,
                         count::Union{Nothing,CartesianIndex}=nothing,
                         constant_dims::Bool=false)
    variable::Union{Nothing,Variable}

Define a variable within `io`.

# Arguments
- `io`: handler that owns the variable
- `name`: unique variable identifier
- `type`: primitive type
- `ndims`: number of dimensions
- `shape`: global dimension
- `start`: local offset
- `count`: local dimension
- `constant_dims`: `true`: shape, start, count won't change; `false`:
  shape, start, count will change after definition
"""
function define_variable(io::AIO, name::AbstractString, type::Type,
                         shape::Union{Nothing,CartesianIndex}=nothing,
                         start::Union{Nothing,CartesianIndex}=nothing,
                         count::Union{Nothing,CartesianIndex}=nothing,
                         constant_dims::Bool=false)
    ndims = max(length(maybe(shape, ())), length(maybe(start, ())),
                length(maybe(count, ())))
    @assert all(len -> len == 0 || len == ndims,
                [length(maybe(shape, ())), length(maybe(start, ())),
                 length(maybe(count, ()))])
    ptr = ccall((:adios2_define_variable, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cint, Csize_t, Ptr{Csize_t}, Ptr{Csize_t},
                 Ptr{Csize_t}, Cint), io.ptr, name, adios_type(type), ndims,
                shape ≡ nothing ? C_NULL : Csize_t[Tuple(shape)...],
                start ≡ nothing ? C_NULL : Csize_t[Tuple(start)...],
                count ≡ nothing ? C_NULL : Csize_t[Tuple(count)...],
                constant_dims)
    return ptr == C_NULL ? nothing : Variable(ptr)
end

function define_variable(io::AIO, name::AbstractString, var::Number)
    return define_variable(io, name, typeof(var))
end
function define_variable(io::AIO, name::AbstractString,
                         arr::AbstractArray{<:Number})
    return define_variable(io, name, eltype(arr), nothing, nothing,
                           CartesianIndex(size(arr)))
end

export inquire_variable
"""
    variable = inquire_variable(io::AIO, name::AbstractString)
    variable::Union{Nothing,Variable}

Retrieve a variable handler within current `io` handler.

# Arguments
- `io`: handler to variable `io` owner
- `name`: unique variable identifier within `io` handler
"""
function inquire_variable(io::AIO, name::AbstractString)
    ptr = ccall((:adios2_inquire_variable, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring), io.ptr, name)
    return ptr == C_NULL ? nothing : Variable(ptr)
end

export inquire_all_variables
"""
    variables = inquire_all_variables(io::AIO)
    variables::Union{Nothing,Vector{Variable}}

Returns an array of variable handlers for all variable present in the
`io` group.

# Arguments
- `io`: handler to variables io owner
"""
function inquire_all_variables(io::AIO)
    c_variables = Ref{Ptr{Ptr{Cvoid}}}()
    size = Ref{Csize_t}()
    err = ccall((:adios2_inquire_all_variables, libadios2_c), Cint,
                (Ref{Ptr{Ptr{Cvoid}}}, Ref{Csize_t}, Ptr{Cvoid}), c_variables,
                size, io.ptr)
    Error(err) ≠ error_none && return nothing
    variables = Array{Variable}(undef, size[])
    for n in 1:length(variables)
        ptr = unsafe_load(c_variables[], n)
        @assert ptr ≠ C_NULL
        variables[n] = Variable(ptr)
    end
    free(c_variables[])
    return variables
end

export define_attribute
"""
    attribute = define_attribute(io::AIO, name::AbstractString, value)
    attribute::Union{Nothing,Attribute}

Define an attribute value inside `io`.
"""
function define_attribute(io::AIO, name::AbstractString, value)
    T = typeof(value)
    ptr = ccall((:adios2_define_attribute, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cint, Ptr{Cvoid}), io.ptr, name,
                adios_type(T), Ref(value))
    return ptr == C_NULL ? nothing : Attribute(ptr)
end

export define_attribute_array
"""
    attribute = define_attribute_array(io::AIO, name::AbstractString,
                                       values::AbstractVector)
    attribute::Union{Nothing,Attribute}

Define an attribute array inside `io`.
"""
function define_attribute_array(io::AIO, name::AbstractString,
                                values::AbstractVector)
    T = eltype(values)
    ptr = ccall((:adios2_define_attribute_array, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cint, Ptr{Cvoid}, Csize_t), io.ptr, name,
                adios_type(T), values, length(values))
    return ptr == C_NULL ? nothing : Attribute(ptr)
end

export define_variable_attribute
"""
    attribute = define_variable_attribute(io::AIO, name::AbstractString, value,
                                          variable_name::AbstractString,
                                          separator::AbstractString="/")
    attribute::Union{Nothing,Attribute}

Define an attribute single value associated to an existing variable by
its name.
"""
function define_variable_attribute(io::AIO, name::AbstractString, value,
                                   variable_name::AbstractString,
                                   separator::AbstractString="/")
    T = typeof(value)
    ptr = ccall((:adios2_define_variable_attribute, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cint, Ptr{Cvoid}, Cstring, Cstring),
                io.ptr, name, adios_type(T), Ref(value), variable_name,
                separator)
    return ptr == C_NULL ? nothing : Attribute(ptr)
end

export define_variable_attribute_array
"""
    attribute = define_variable_attribute_array(io::AIO, name::AbstractString,
                                                values::AbstractVector,
                                                variable_name::AbstractString,
                                                separator::AbstractString="/")
    attribute::Union{Nothing,Attribute}

Define an attribute array associated to an existing variable by its
name.
"""
function define_variable_attribute_array(io::AIO, name::AbstractString,
                                         values::AbstractVector,
                                         variable_name::AbstractString,
                                         separator::AbstractString="/")
    T = eltype(values)
    ptr = ccall((:adios2_define_variable_attribute_array, libadios2_c),
                Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cint, Ptr{Cvoid}, Csize_t, Cstring,
                 Cstring), io.ptr, name, adios_type(T), values, length(values),
                variable_name, separator)
    return ptr == C_NULL ? nothing : Attribute(ptr)
end

export inquire_attribute
"""
    attribute = inquire_attribute(io::AIO, name::AbstractString)
    attribute::Union{Nothing,Attribute}

Return a handler to a previously defined attribute by name.
"""
function inquire_attribute(io::AIO, name::AbstractString)
    ptr = ccall((:adios2_inquire_attribute, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring), io.ptr, name)
    return ptr == C_NULL ? nothing : Attribute(ptr)
end

export inquire_variable_attribute
"""
    attribute = inquire_variable_attribute(io::AIO, name::AbstractString,
                                           variable_name::AbstractString,
                                           separator::AbstractString="/")
    attribute::Union{Nothing,Attribute}

Return a handler to a previously defined attribute by name.
"""
function inquire_variable_attribute(io::AIO, name::AbstractString,
                                    variable_name::AbstractString,
                                    separator::AbstractString="/")
    ptr = ccall((:adios2_inquire_variable_attribute, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cstring, Cstring), io.ptr, name,
                variable_name, separator)
    return ptr == C_NULL ? nothing : Attribute(ptr)
end

export inquire_all_attributes
"""
    attributes = inquire_all_attributes(io::AIO)
    attributes::Union{Nothing,Vector{Attribute}}

Return an array of attribute handlers for all attribute present in the
io group.
"""
function inquire_all_attributes(io::AIO)
    c_attributes = Ref{Ptr{Ptr{Cvoid}}}()
    size = Ref{Csize_t}()
    err = ccall((:adios2_inquire_all_attributes, libadios2_c), Cint,
                (Ref{Ptr{Ptr{Cvoid}}}, Ref{Csize_t}, Ptr{Cvoid}), c_attributes,
                size, io.ptr)
    Error(err) ≠ error_none && return nothing
    attributes = Array{Attribute}(undef, size[])
    for n in 1:length(attributes)
        ptr = unsafe_load(c_attributes[], n)
        @assert ptr ≠ C_NULL
        attributes[n] = Attribute(ptr)
    end
    free(c_attributes[])
    return attributes
end

"""
    engine = open(io::AIO, name::AbstractString, mode::Mode)
    engine::Union{Nothing,Engine}

 Open an Engine to start heavy-weight input/output operations.

In MPI version reuses the communicator from [`adios_init_mpi`](@ref).
MPI Collective function as it calls `MPI_Comm_dup`.

# Arguments
- `io`: engine owner
- `name`: unique engine identifier
- `mode`: `mode_write`, `mode_read`, `mode_append` (not yet supported)
"""
function Base.open(io::AIO, name::AbstractString, mode::Mode)
    ptr = ccall((:adios2_open, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring, Cint), io.ptr, name, Cint(mode))
    return ptr == C_NULL ? nothing : Engine(ptr)
end

export engine_type
"""
    type = engine_type(io::AIO)
    type::Union{Nothing,String}

Return engine type string.
"""
function engine_type(io::AIO)
    size = Ref{Csize_t}()
    err = ccall((:adios2_engine_type, libadios2_c), Cint,
                (Ptr{Cchar}, Ref{Csize_t}, Ptr{Cvoid}), C_NULL, size, io.ptr)
    Error(err) ≠ error_none && return nothing
    type = '\0'^size[]
    err = ccall((:adios2_engine_type, libadios2_c), Cint,
                (Ptr{Cchar}, Ref{Csize_t}, Ptr{Cvoid}), type, size, io.ptr)
    Error(err) ≠ error_none && return nothing
    return type
end

export get_engine
"""
    engine = get_engine(io::AIO, name::AbstractString)
    engine::Union{Nothing,Engine}
"""
function get_engine(io::AIO, name::AbstractString)
    ptr = ccall((:adios2_get_engin, libadios2_c), Ptr{Cvoid},
                (Ptr{Cvoid}, Cstring), io.ptr, name)
    return ptr == C_NULL ? nothing : Engine(ptr)
end
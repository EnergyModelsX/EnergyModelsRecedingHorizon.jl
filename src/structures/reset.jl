"""
    abstract type AbstractPath

Supertype for identification of the type which is resetted by a lens.
"""
abstract type AbstractPath end

"""
    abstract type AbstractInitDataPath <: AbstractPath

Supertype for identification of the [`AbstractPath`](@ref) types that are used for initial
data. If you create a new [`AbstractInitData`](@ref) type, you must also create a new
`AbstractInitDataPath` subtype
"""
abstract type AbstractInitDataPath <: AbstractPath end

"""
    struct OperPath <: AbstractPath

Internal type for paths pointing towards operational profiles.
"""
struct OperPath <: AbstractPath end

"""
    struct ElementPath <: AbstractPath

Internal type for paths pointing towards nodes.
"""
struct ElementPath <: AbstractPath end

"""
    struct InitDataPath <: AbstractPath

Internal type for paths pointing towards [`InitData`](@ref).

# Fields
- **`key::Symbol`** is the key in the [`InitData`](@ref) (and correspondingly in the JuMP
  model).
"""
struct InitDataPath <: AbstractInitDataPath
    key::Symbol
end

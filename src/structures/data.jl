"""
    struct RecedingAccumulating <: Accumulating

`StorageBehavior` which accumulates all inflow witin a strategic period.
`RecedingAccumulating` allows for initializing level values for the storages.
"""
struct RecedingAccumulating <: EMB.Accumulating end

"""
    abstract type AbstractInitData <: EMB.Data

Abstract type for initialization data.
"""
abstract type AbstractInitData <: EMB.Data end

"""
    struct InitData{T} <: AbstractInitData

Initialization data type for the inclusion of initial data before the first horizon.
The standard initialization data is using a single value for a given variable. Multiple
variables can be initialized simultaneously.

# Fields
- **`init_val_dict::Dict{Symbol,T}`** is a dictionary with the variable symbol as key and the
  value in the beginning of the analysis as value.
"""
struct InitData{T} <: AbstractInitData
    init_val_dict::Dict{Symbol,T}
end

abstract type TransInitData{T} <: AbstractInitData end

"""
    StorageInitData(val::Real)

Constructor for providing initialization for [`Storage`](@extref EnergyModelsBase.Storage)
nodes. A `StorageInitData` must be provided for each `Storage` node.

# Arguments
- **`val::Real`**: initial value for storage level.
"""
function StorageInitData(val::Real)
    return InitData(Dict(:stor_level => val))
end

"""
    is_init_data(data)

Checks whether the argument `data` has initialization settings.
"""
is_init_data(data) = (typeof(data) <: AbstractInitData)

"""
    has_init(n::Node)
    has_init(l::Link)

Checks whether the node `n` or link `l` has initialization data.
"""
has_init(n::EMB.Node) = any(is_init_data(data) for data ∈ node_data(n))
has_init(l::Link) = any(is_init_data(data) for data ∈ link_data(l))

"""
    data_init(n::EMB.Node)
    data_init(l::Link)

Returns initialization data for node `n` or link `l`.
"""
data_init(n::EMB.Node) = filter(is_init_data, node_data(n))[1]
data_init(l::Link) = filter(is_init_data, link_data(l))[1]

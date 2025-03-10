
"""
    RecedingAccumulating <: Accumulating

`StorageBehavior` which accumulates all inflow witin a strategic period.
`RecedingAccumulating` allows for initializing level values for the storages.
"""
struct RecedingAccumulating <: EMB.Accumulating end

"""
Abstract type for initialization data.
"""
abstract type AbstractInitData <: EMB.Data end

"""
Reference initialization data type. An `AbstractInitData` object should be defined for each
initializable node instance.

# Fields
- **`val`**: initial state for node.
"""
struct InitData{T} <: AbstractInitData
    init_val_dict::Dict{Symbol,T}
end

abstract type TransInitData{T} <: AbstractInitData end

"""
Provides initialization for storages. An `StorageInitData` should be defined
for each `Storage{RecedingAccumulating}` instance.

# Fields
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

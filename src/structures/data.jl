
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

"""
Provides initialization for storages. An `StorageInitData` should be defined
for each `Storage{RecedingAccumulating}` instance.

# Fields
- **`val::Real`**: initial value for storage level.
"""
function StorageInitData(val::Real)
    return InitData(Dict(:stor_level => val))
end
# TODO: RecHorData with init and cost_to_go; cost_to_go defined for each node

"""
    is_init_data(data)

Checks whether the argument `data` has initialization settings.
"""
is_init_data(data) = (typeof(data) <: AbstractInitData)

# is_initializable(n) = # (typeof(data) <: AbstractInitData)
"""
has_init(n::Node)

Checks whether the Node `n` has initialization data.
"""
has_init(n::EMB.Node) = any(is_init_data(data) for data ∈ node_data(n))

"""
    data_init(n::EMB.Node)

Returns initialization data for Node `n`
"""
data_init(n::EMB.Node) = filter(is_init_data, node_data(n))[1]

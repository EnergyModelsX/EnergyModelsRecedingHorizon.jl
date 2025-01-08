
"""
    RecedingAccumulating <: Accumulating

`StorageBehavior` which accumulates all inflow witin a strategic period.
`RecedingAccumulating` allows for initializing level values for the storages.
"""
struct RecedingAccumulating <: EMB.Accumulating end


"""
Abstract type for initialization data.
"""
abstract type InitData <: EMB.Data end


"""
Reference initialization data type. An `InitData` object should be defined for each
initializable node instance.

# Fields
- **`val`**: initial state for node.
"""
struct RefInitData{T} <: InitData
    val::T
end

"""
Provides initialization for storages. An `InitStorageData` should be defined
for each `Storage{RecedingAccumulating}` instance.

# Fields
- **`val::Real`**: initial value for storage level.
"""
InitStorageData = RefInitData{Real}
# TODO: RecHorData with init and cost_to_go; cost_to_go defined for each node
# Julian's example:
# struct InitData <: EMB.Data
#     init_state_var::Vector        # variable labels (ex: ":stor_level")
#     init_state_value::Vector      # initial value
# end

"""
    is_init_data(data)

Checks whether the argument `data` has initialization settings.
"""
is_init_data(data) = (typeof(data) <: InitData)

# is_initializable(n) = # (typeof(data) <: InitData)
"""
has_init(n::Node)

Checks whether the Node `n` has initialization data.
"""
has_init(n::EMB.Node) = any(is_init_data(data) for data ∈ node_data(n))

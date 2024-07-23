"""
This file can be used for introducing new `types` that are required in the receding horizon
framework.
"""

"""
    RefAccumulating <: Accumulating

`StorageBehavior` which accumulates all inflow witin a strategic period.
`RefAccumulating` allows for initializing level values for the storages.
"""
struct RefAccumulating <: EMB.Accumulating end

#= """
    StorCapOpexFixedInit <: AbstractStorageParameters

A storage parameter type for including a capacity and fixed operational expenditures.
This implies that the installed capacity has no direct impact on the objective function.
It includes additionally a value for initialization.

# Fields
- **`capacity::TimeProfile`** is the installed capacity.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
- **`init_level::Real`** is the fixed operating expense.
"""
struct StorCapOpexFixedInit <: EMB.AbstractStorageParameters
    capacity::TimeProfile
    opex_fixed::TimeProfile
    init_level::Real
end =#


"""
Provides initialization for storages. An `InitData` should be defined
for each `Storage{RefAccumulating}` instance.

# Fields
- **`init_level::Real`**: initial value for storage level.
"""
struct InitData <: EMB.Data # TODO: RecHorData with init and cost_to_go
    init_level::Real
    # init_level::Dict(EMB.Storage => Real) # if data is used for full case
end

"""
    is_init_data(data)

Checks whether the argument `data` has initialization settings.
"""
is_init_data(data) = (typeof(data) <: InitData)

"""
    init_level(n::Storage{RefAccumulating})

Gets initialization values for the Storage node `n` from its data fields.
"""
function init_level(n::Storage{RefAccumulating})
    initdata = filter(is_init_data, n.data)
    @assert (length(initdata) == 1) "InitData badly defined" # TODO: check data elsewhere
    return first(initdata).init_level
end

# function constraints_data(m, n::Storage, 𝒯, 𝒫, modeltype, data::InitData) = nothing
# # define if data is used for full case
# end

# is_initializable(n) = # (typeof(data) <: InitData)
# TODO: check has_emissions
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
Provides initialization for storages.

# Fields
- **`init_level::Real`**: initial value for storage level.
"""
struct InitData <: EMB.Data
    init_level::Real
end

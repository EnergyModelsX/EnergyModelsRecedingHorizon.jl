"""
This file should contain utilities that are used within the framework.
"""

"""
    previous_level(
        m,
        n::Storage{RefAccumulating},
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing` and the storage node
is an [`RefAccumulating`](@ref) storage node, the function returns the initial level value
(defined externally at the `data` field through an `InitData` object).
"""
function EMB.previous_level(
    m,
    n::Storage{RefAccumulating},
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, Nothing, Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return init_level(n)
end

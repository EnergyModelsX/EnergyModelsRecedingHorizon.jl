"""
This file should contain utilities that are used within the framework.
"""
function previous_level(
    m,
    n::Storage{RefAccumulating},
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, Nothing, Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    return previous_level_sp(m, n, cyclic_pers, modeltype)
end

"""
    previous_level(
        m,
        n::Storage,
        prev_pers::PreviousPeriods,
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

Returns the level used as previous level of a `Storage` node depending on the type of
[`PreviousPeriods`](@ref).

The basic functionality is used in the case when the previous operational period is a
`TimePeriod`, in which case it just returns the previous operational period.

    previous_level(
        m,
        n::Storage{RefAccumulating},
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing` and the storage node
is an [`RefAccumulating`](@ref) storage node, the function returns a value of 0.
"""
function previous_level(
    m,
    n::Storage{RefAccumulating},
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, Nothing, Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return n.level.init_level
end

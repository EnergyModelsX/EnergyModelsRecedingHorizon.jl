"""
    previous_level(
        m,
        n::Storage{RecedingAccumulating},
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing` and the storage node
has the parameter type [`RecedingAccumulating`](@ref), the function returns the initial
level value (defined externally at the `data` field through an `AbstractInitData` object).
"""
function EMB.previous_level(
    m,
    n::Storage{RecedingAccumulating},
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod,Nothing,Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return init_level(n)
end

"""
    Accessors.ConstructionBase.constructorof(obj::Type{<:Storage})

Allows using @reset for an `obj <: Storage`, which is declared as parametric type without
the possibility to deduce the possibility to deduce the type parameter from the provided
input.

!!! note
    Dispatch on this function for functions using inner constructors, in order for @reset
    to work.
"""
function Accessors.ConstructionBase.constructorof(obj::Type{<:Storage})
    return (args...) -> (obj(args...))
end

_get_key(::Vector{<:EMB.Node}) = :nodes
_get_key(::EMB.Node) = :nodes
_get_key(::Vector{<:Link}) = :links
_get_key(::Link) = :links
_get_key(::Vector{<:Resource}) = :products
_get_key(::Resource) = :products
_get_key(::TS.TimePeriod) = :opers

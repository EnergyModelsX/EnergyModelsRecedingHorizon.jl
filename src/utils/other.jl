"""
    EMB.previous_level(
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

"""
    _update_future_value!(𝒮ᵛ::Vector{FutureValueSub{T}}, time_elapsed::Real) where {T<:StorageValueCuts}

Update the value of [`TimeWeightReset`](@ref) based on the time `time_elapsed` at the end of
the TimeStructure.

If a cut is given at the end time of an operational period, the weight is 1 for the given
cut and 0 for other. When the optimization end time is between cuts, the weights scales the
weight of the nearest cuts such that they are weighted linearly.
"""
function _update_future_value!(
    𝒮ᵛ::Vector{FutureValueSub{T}},
    time_elapsed::Real,
) where {T<:StorageValueCuts}
    val_time(s_v) = cuts_time(s_v.org) - time_elapsed
    𝒮ᵛ⁰ = filter(s_v -> val_time(s_v) == 0, 𝒮ᵛ)
    𝒮ᵛ⁺ = filter(s_v -> val_time(s_v) > 0, 𝒮ᵛ)
    if !isempty(𝒮ᵛ⁰)
        for s_v ∈ 𝒮ᵛ
            if s_v ∈ 𝒮ᵛ⁰
                s_v.resets[1].val = 1.0
            else
                s_v.resets[1].val = 0.0
            end
        end
    elseif isempty(𝒮ᵛ⁺)
        time_pos = maximum(val_time(s_v) for s_v ∈ 𝒮ᵛ)
        for s_v ∈ 𝒮ᵛ
            if val_time(s_v) == time_pos
                s_v.resets[1].val = 1.0
            else
                s_v.resets[1].val = 0.0
            end
        end
    else
        𝒮ᵛ⁻ = filter(s_v -> val_time(s_v) < 0, 𝒮ᵛ)
        time_pos = minimum(val_time(s_v) for s_v ∈ 𝒮ᵛ⁺)
        time_neg = maximum(val_time(s_v) for s_v ∈ 𝒮ᵛ⁻)
        for s_v ∈ 𝒮ᵛ
            if val_time(s_v) == time_pos
                s_v.resets[1].val = 1.0 - time_pos / (time_pos - time_neg)
            elseif val_time(s_v) == time_neg
                s_v.resets[1].val = 1.0 + time_neg / (time_pos - time_neg)
            else
                s_v.resets[1].val = 0.0
            end
        end
    end
end

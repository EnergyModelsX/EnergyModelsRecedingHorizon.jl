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
the possibility to to deduce the type parameter from the provided input.

!!! note
    Dispatch on this function for functions using inner constructors, in order for @reset
    to work.
"""
function Accessors.ConstructionBase.constructorof(obj::Type{<:Storage})
    return (args...) -> (obj(args...))
end

"""
    _initialize_loop_variables(𝒰::UpdateCase)

Initialize and return the following loop variables:
- `𝒮ᵛ⁻ᵛᵉᶜ` is a vector of the future value substitution type vectors when the model includes
  future values or an empty vector.
- `𝒮ᵛᵉᶜᵢₙ` is a `Vector{Vector{AbstractSub}}` for all substitution types with initial data.
- `results` is an empty `Dict{Symbol,AbstractDataFrame}` used for saving the results.
"""
function _initialize_loop_variables(𝒰::UpdateCase)
    # Extract values
    𝒮ᵛᵉᶜ = get_sub_elements_vec(𝒰)

    # Initalize the results
    results = Dict{Symbol,AbstractDataFrame}()

    # Create a vector of vector of `AbstractSub` vectors which have future values
    if !isempty(filter(𝒮 -> typeof(𝒮) == Vector{_ele_to_sub(FutureValue)}, 𝒮ᵛᵉᶜ))
        # Extract the individual `FutureValue` types
        𝒮ᵛ = get_sub_ele(𝒰, FutureValue)
        val_types = unique([typeof(s_v) for s_v ∈ 𝒮ᵛ])
        𝒮ᵛ⁻ᵛᵉᶜ = [
            convert(Vector{fv_type}, filter(s_v -> typeof(s_v) == fv_type, 𝒮ᵛ))
        for fv_type ∈ val_types]
    else
        𝒮ᵛ⁻ᵛᵉᶜ = []
    end

    # Identify the vector of `AbstractSub` vectors that have initial values
    𝒮ᵛᵉᶜᵢₙ = Vector{AbstractSub}[filter(has_init, 𝒮) for 𝒮 ∈ 𝒮ᵛᵉᶜ]

    return 𝒮ᵛ⁻ᵛᵉᶜ, 𝒮ᵛᵉᶜᵢₙ, results
end

"""
    update_future_value!(𝒮ᵛ::Vector{FutureValueSub{T}}, time_elapsed::Real) where {T<:StorageValueCuts}
    update_future_value!(𝒮ᵛ::Vector{FutureValueSub{T}}, time_elapsed::Real) where {T<:TypeFutureValue}

Update the value of [`TimeWeightReset`](@ref) based on the time `time_elapsed` at the end of
the TimeStructure.

If a cut is given at the end time of an operational period, the weight is 1 for the given
cut and 0 for other. When the optimization end time is between cuts, the weights scales the
weight of the nearest cuts such that they are weighted linearly.
"""
function update_future_value!(
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
function update_future_value!(
    𝒮ᵛ::Vector{FutureValueSub{T}},
    time_elapsed::Real,
) where {T<:TypeFutureValue}
end

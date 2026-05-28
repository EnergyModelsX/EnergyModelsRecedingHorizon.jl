"""
    _update_update_case!(𝒰, opers, 𝒯ᵣₕ)

Update the UpdateCase `𝒰` with the new values in the optimization problem given by the
time structure 𝒯ᵣₕ.

In addition, the UpdateCase `𝒰` is updated with the new mapping between the operational
periods of the optimization (through `𝒯ᵣₕ`) and the original (through `opers`) problem.
"""
function _update_update_case!(𝒰, opers, 𝒯ᵣₕ)
    # Update the individual Substitution types within the `UpdateCase`
    _update_case_types!(get_sub_model(𝒰), 𝒰, opers)
    _update_case_types!(get_sub_products(𝒰), 𝒰, opers)
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        _update_case_types!(𝒮, 𝒰, opers)
    end
    𝒰.opers = Dict(zip(𝒯ᵣₕ, opers))
end

"""
    _update_case_types!(𝒮::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    _update_case_types!(s:::AbstractSub, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Updates the elements within the `Vector{<:AbstractSub}` or `AbstractSub` with the new values,
The update only takes place when the field `reset` of a given `AbstractSub` is not empty.
In this case, the subfunction [`_reset_field`](@ref) is called.
"""
function _update_case_types!(
    𝒮::Vector{<:AbstractSub},
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    for s ∈ 𝒮
        _update_case_types!(s, 𝒰, opers)
    end
end
function _update_case_types!(
    s::AbstractSub,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    if isempty(s.resets)
        s.new = deepcopy(original(s))
    else
        for res_type ∈ s.resets
            s.new = _reset_field(updated(s), res_type, 𝒰, opers)
        end
    end
end

"""
    _reset_field(x_rh, res_type::ElementReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    _reset_field(x_rh, res_type::Union{InitReset, TimeWeightReset}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    _reset_field(x_rh, res_type::OperReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Resets the field expressed through `res_type` of element `x_rh` with the new value. The type
of the new value is depending on the specified `res_type`:

1. `res_type::ElementReset` uses `𝒰` for identifying the new element,
2. `res_type::Union{InitReset, TimeWeightReset}` uses the value in `res_type` directly,
3. `res_type::OperReset` creates a new operational profile based on the original
   operational profile in `res_type` and the set of operational periods `opers`.
"""
function _reset_field(
    x_rh,
    res_type::ElementReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    @reset res_type.lens(x_rh) = updated(𝒰, res_type.val)
    return x_rh
end
function _reset_field(
    x_rh,
    res_type::Union{InitReset, TimeWeightReset},
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    @reset res_type.lens(x_rh) = res_type.val
    return x_rh
end
function _reset_field(
    x_rh,
    res_type::OperReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    @reset res_type.lens(x_rh) = OperationalProfile(res_type.val[opers])
    return x_rh
end

"""
    _create_updatetype(model::RecHorEnergyModel)
    _create_updatetype(model::RecHorEnergyModel, case::AbstractCase)

Initialize an [`UpdateCase`](@ref) based on the provided [`RecHorEnergyModel`](@ref) `model`.

Initialize and populate the [`UpdateCase`](@ref) if the function has as first argument an
[`AbstractCase`](@extref EnergyModelsBase.AbstractCase).
"""
function _create_updatetype(model::RecHorEnergyModel)
    paths_model = _find_update_paths(model)
    reset_model = AbstractReset[ResetType(field_id, field_id[end], model) for field_id ∈ paths_model]
    return UpdateCase(Substitution(model, reset_model), Dict(), ProductSub[], Vector[])
end
function _create_updatetype(case::AbstractCase, model::RecHorEnergyModel)
    # Create the `UpdateCase` based on the original `Case` structure
    𝒰 = _create_updatetype(model)
    _add_elements!(𝒰, get_products(case))
    for 𝒳 ∈ get_elements_vec(case)
        _add_elements!(𝒰, 𝒳)
    end
    return 𝒰
end

"""
    _add_elements!(𝒰::UpdateCase, 𝒫::Vector{T}) where {T<:Resource}
    _add_elements!(𝒰::UpdateCase, 𝒳::Vector{T}) where {T<:AbstractElement}

Add the vector of `Resource`s or `AbstractElement` substitution types to the [`UpdateCase`](@ref)
`𝒰` for a given `Vector{<:Resource}` or `Vector{<:AbstractElement}`.
"""
function _add_elements!(𝒰::UpdateCase, 𝒫::Vector{T}) where {T<:Resource}
    for p ∈ 𝒫
        paths_oper = _find_update_paths(p)
        reset_types = AbstractReset[ResetType(field_id, field_id[end], p) for field_id ∈ paths_oper]
        push!(get_sub_products(𝒰), Substitution(p, reset_types))
    end
end
function _add_elements!(𝒰::UpdateCase, 𝒳::Vector{T}) where {T<:AbstractElement}
    push!(get_sub_elements_vec(𝒰), _ele_to_sub(T)[])
    for x ∈ 𝒳
        paths_oper = _find_update_paths(x)
        reset_types = AbstractReset[ResetType(field_id, field_id[end], x) for field_id ∈ paths_oper]
        push!(get_sub_elements_vec(𝒰)[end], Substitution(x, reset_types))
    end
end

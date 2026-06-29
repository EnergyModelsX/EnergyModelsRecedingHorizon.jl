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
    𝒰.map_org["periods"] = Dict(zip(𝒯ᵣₕ, opers))
    𝒰.map_updated["periods"] = Dict(zip(opers, 𝒯ᵣₕ))
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
    _delete_mapping!(𝒰, s)
    if isempty(s.resets)
        s.new = deepcopy(original(s))
    else
        for res_type ∈ s.resets
            s.new = _reset_field(updated(s), res_type, 𝒰, opers)
        end
    end
    _add_mapping!(𝒰, s)
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
    _create_updatetype(modeltype::RecHorEnergyModel)
    _create_updatetype(modeltype::RecHorEnergyModel, case::AbstractCase)

Initialize an [`UpdateCase`](@ref) based on the provided [`RecHorEnergyModel`](@ref)
`modeltype`.

Initialize and populate the [`UpdateCase`](@ref) if the function has as first argument an
[`AbstractCase`](@extref EnergyModelsBase.AbstractCase).
"""
function _create_updatetype(modeltype::RecHorEnergyModel)
    paths_model = _find_update_paths(modeltype)
    reset_model = AbstractReset[ResetType(field_id, field_id[end], modeltype) for field_id ∈ paths_model]
    𝒰 = UpdateCase(Substitution(modeltype, reset_model), Dict(), Dict(), ProductSub[], Vector[])
    _init_mapping!(𝒰, modeltype)
    return 𝒰
end
function _create_updatetype(case::AbstractCase, modeltype::RecHorEnergyModel)
    # Create the `UpdateCase` based on the original `Case` structure
    𝒰 = _create_updatetype(modeltype)
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
`𝒰` for a given `Vector{<:Resource}` or `Vector{<:AbstractElement}` and initiate the mapping.
"""
function _add_elements!(𝒰::UpdateCase, 𝒫::Vector{T}) where {T<:Resource}
    _init_mapping!(𝒰, 𝒫)
    for p ∈ 𝒫
        paths_oper = _find_update_paths(p)
        reset_types = AbstractReset[ResetType(field_id, field_id[end], p) for field_id ∈ paths_oper]
        push!(get_sub_products(𝒰), Substitution(p, reset_types))
        _add_mapping!(𝒰, p)
    end
end
function _add_elements!(𝒰::UpdateCase, 𝒳::Vector{T}) where {T<:AbstractElement}
    push!(get_sub_elements_vec(𝒰), _ele_to_sub(T)[])
    _init_mapping!(𝒰, 𝒳)
    for x ∈ 𝒳
        paths_oper = _find_update_paths(x)
        reset_types = AbstractReset[ResetType(field_id, field_id[end], x) for field_id ∈ paths_oper]
        push!(get_sub_elements_vec(𝒰)[end], Substitution(x, reset_types))
        _add_mapping!(𝒰, x)
    end
end

function _init_mapping!(𝒰::UpdateCase, ::Vector{T}) where {T<:Union{Resource, AbstractElement}}
    𝒰.map_org[_type_to_string(T)] = Dict{T,T}()
    𝒰.map_updated[_type_to_string(T)] = Dict{T,T}()
end
function _init_mapping!(𝒰::UpdateCase, modeltype::T) where {T<:EnergyModel}
    𝒰.map_org[_type_to_string(T)] = Dict{T,T}(modeltype => modeltype)
    𝒰.map_updated[_type_to_string(T)] = Dict{T,T}(modeltype => modeltype)
end
function _delete_mapping!(𝒰::UpdateCase, s::T) where {T<:AbstractSub}
    delete!(𝒰.map_org[_type_to_string(T)], updated(s))
    delete!(𝒰.map_updated[_type_to_string(T)], original(s))
end
function _add_mapping!(𝒰::UpdateCase, x::T) where {T}
    𝒰.map_org[_type_to_string(T)][x] = x
    𝒰.map_updated[_type_to_string(T)][x] = x
end
function _add_mapping!(𝒰::UpdateCase, s::T) where {T<:AbstractSub}
    𝒰.map_org[_type_to_string(T)][updated(s)] = original(s)
    𝒰.map_updated[_type_to_string(T)][original(s)] = updated(s)
end

_type_to_string(::Type{T}) where {T<:Union{Resource, ProductSub}} = "products"
_type_to_string(::Type{T}) where {T<:Union{EMB.Node, NodeSub}} = "nodes"
_type_to_string(::Type{T}) where {T<:Union{Link, LinkSub}} = "links"
_type_to_string(::Type{T}) where {T<:Union{FutureValue, FutureValueSub}} = "future_values"
_type_to_string(::Type{T}) where {T<:Union{EnergyModel, ModelSub}} = "modeltype"

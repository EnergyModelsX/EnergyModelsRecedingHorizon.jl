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
    𝒰.map_org[:periods] = Dict(zip(𝒯ᵣₕ, opers))
    𝒰.map_updated[:periods] = Dict(zip(opers, 𝒯ᵣₕ))
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
    _reset_field(x_rh, res_type::PartitionReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    _reset_field(x_rh, res_type::EmptyReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Resets the field expressed through `res_type` of element `x_rh` with the new value. The type
of the new value is depending on the specified `res_type`:

1. `res_type::ElementReset` uses `𝒰` for identifying the new element,
2. `res_type::Union{InitReset, TimeWeightReset}` uses the value in `res_type` directly,
3. `res_type::OperReset` creates a new operational profile based on the original
   operational profile in `res_type` and the set of operational periods `opers`.
4. `res_type::PartitionReset` creates a new partition profile based on the original
   partition profile in `res_type` and the set of operational periods `opers`.
5. `res_type::EmptyReset` does not reset any field and is used to avoid problems with
   partition profile resetting.
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
function _reset_field(
    x_rh,
    res_type::PartitionReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    # Extract the required variables from the UpdateCase
    𝒯 = get_time_struct(𝒰)

    # Identify the partitions of the original problem that are used within the current
    # receding horizon problem
    𝒯ᵖᵈ = period_duration(res_type, 𝒯)
    parts = filter(t_pd -> isempty(setdiff(t_pd, opers)), 𝒯ᵖᵈ)

    # Reset the partition profile of the receding horizon problem based on the relevant
    # partitions
    @reset res_type.lens(x_rh) = PartitionProfile(res_type.val[parts])
    return x_rh
end
function _reset_field(
    x_rh,
    res_type::EmptyReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    return x_rh
end

"""
    _create_updatetype(case::AbstractCase, modeltype::RecHorEnergyModel)
    _create_updatetype(𝒯::TS.TimeStructure, modeltype::RecHorEnergyModel)

Initialize an [`UpdateCase`](@ref) based on the provided [`RecHorEnergyModel`](@ref)
`modeltype`.

Initialize and populate the [`UpdateCase`](@ref) if the function has as first argument an
[`AbstractCase`](@extref EnergyModelsBase.AbstractCase).
"""
function _create_updatetype(case::AbstractCase, modeltype::RecHorEnergyModel)
    # Create the `UpdateCase` based on the original `Case` structure
    𝒰 = _create_updatetype(get_time_struct(case), modeltype)
    _add_elements!(𝒰, get_products(case))
    for 𝒳 ∈ get_elements_vec(case)
        _add_elements!(𝒰, 𝒳)
    end
    return 𝒰
end
function _create_updatetype(𝒯::TS.TimeStructure, modeltype::RecHorEnergyModel)
    paths_model = _find_update_paths(modeltype)
    reset_model = AbstractReset[ResetType(field_id, field_id[end], modeltype) for field_id ∈ paths_model]
    𝒰 = UpdateCase(
        𝒯,
        Substitution(modeltype, reset_model),
        Dict(),
        Dict(),
        ProductSub[],
        Vector[],
    )
    _init_mapping!(𝒰, modeltype)
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

"""
    _init_mapping!(𝒰::UpdateCase, ::Vector{T}) where {T<:Union{Resource, AbstractElement}}
    _init_mapping!(𝒰::UpdateCase, modeltype::T) where {T<:EnergyModel}

Initialize the mapping dictionary used for mapping the original to the receding horizon
problem and *vice versa*.

!!! note "New, unconventional `AbstractElement`s"
    If you create a new unconventional `AbstractElement`, *i.e.*, an `AbstractElement` with
    fields that are used for variable indexing, you must create a new method for this
    function.
"""
function _init_mapping!(𝒰::UpdateCase, ::Vector{T}) where {T<:Union{Resource, AbstractElement}}
    𝒰.map_org[_type_to_key(T)] = Dict{T,T}()
    𝒰.map_updated[_type_to_key(T)] = Dict{T,T}()
end
function _init_mapping!(𝒰::UpdateCase, modeltype::T) where {T<:EnergyModel}
    𝒰.map_org[_type_to_key(T)] = Dict{T,T}(modeltype => modeltype)
    𝒰.map_updated[_type_to_key(T)] = Dict{T,T}(modeltype => modeltype)
end

"""
    _add_mapping!(𝒰::UpdateCase, x::T) where {T}
    _add_mapping!(𝒰::UpdateCase, s::T) where {T<:AbstractSub}

Add the mapping for `x` or `AbstractSub` `s` both from the original to the receding horizon
problem and *vice versa*.

!!! note "New, unconventional `AbstractElement`s"
    If you create a new unconventional `AbstractElement`, *i.e.*, an `AbstractElement` with
    fields that are used for variable indexing, you must create a new method for this
    function.
"""
function _add_mapping!(𝒰::UpdateCase, x::T) where {T}
    𝒰.map_org[_type_to_key(T)][x] = x
    𝒰.map_updated[_type_to_key(T)][x] = x
end
function _add_mapping!(𝒰::UpdateCase, s::T) where {T<:AbstractSub}
    𝒰.map_org[_type_to_key(T)][updated(s)] = original(s)
    𝒰.map_updated[_type_to_key(T)][original(s)] = updated(s)
end

"""
    _delete_mapping!(𝒰::UpdateCase, s::T) where {T<:AbstractSub}

Delete the mapping for `AbstractSub` `s` both from the original to the receding horizon
problem and *vice versa*.

!!! note "New, unconventional `AbstractElement`s"
    If you create a new unconventional `AbstractElement`, *i.e.*, an `AbstractElement` with
    fields that are used for variable indexing, you must create a new method for this
    function.
"""
function _delete_mapping!(𝒰::UpdateCase, s::T) where {T<:AbstractSub}
    delete!(𝒰.map_org[_type_to_key(T)], updated(s))
    delete!(𝒰.map_updated[_type_to_key(T)], original(s))
end

"""
    _type_to_key(::Type{T}) where {T<:Union{Resource, ProductSub}}
    _type_to_key(::Type{T}) where {T<:Union{EMB.Node, NodeSub}}
    _type_to_key(::Type{T}) where {T<:Union{Link, LinkSub}}
    _type_to_key(::Type{T}) where {T<:Union{FutureValue, FutureValueSub}}
    _type_to_key(::Type{T}) where {T<:Union{EnergyModel, ModelSub}}

Returns the symbol used for the type `T` when creating the mapping for the individual elements.
"""
_type_to_key(::Type{T}) where {T<:TS.TimePeriod} = :periods
_type_to_key(::Type{T}) where {T<:Union{Resource, ProductSub}} = :resources
_type_to_key(::Type{T}) where {T<:Union{EMB.Node, NodeSub}} = :nodes
_type_to_key(::Type{T}) where {T<:Union{Link, LinkSub}} = :links
_type_to_key(::Type{T}) where {T<:Union{FutureValue, FutureValueSub}} = :future_values
_type_to_key(::Type{T}) where {T<:Union{EnergyModel, ModelSub}} = :modeltype

"""
    _check_period_partitions(𝒰::UpdateCase, ℋ::AbstractHorizons, optimizer)
    _check_period_partitions(log::Dict{String, Vector{String}}, 𝒮::Vector{<:AbstractSub}, 𝒯::TS.TimeStructure, ℋ::AbstractHorizons, optimizer)
    _check_period_partitions(log::Dict{String, Vector{String}}, s::AbstractSub, 𝒯::TS.TimeStructure, ℋ::AbstractHorizons, optimizer)

Function for checking that the individual period partitions are in line with the horizon
structure `ℋ`.

Returns an `AssertionError` if any period partition is not consistent with `ℋ`. It furthermore
creates a log which points towards any inconsistent partitions and horizons.
"""
function _check_period_partitions(𝒰::UpdateCase, ℋ::AbstractHorizons, optimizer)
    # Extract the information from the `UpdateCase`
    𝒯 = get_time_struct(𝒰)

    # Collect all potential problems
    log = Dict{String, Vector{String}}()
    _check_period_partitions(log, get_sub_model(𝒰), 𝒯, ℋ, optimizer)
    _check_period_partitions(log, get_sub_products(𝒰), 𝒯, ℋ, optimizer)
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        _check_period_partitions(log, 𝒮, 𝒯, ℋ, optimizer)
    end

    # Throw an `ErrorException` if there are inconsistent partitions
    !isempty(log) && EMB.compile_logs(𝒰, log)
end

function _check_period_partitions(
    log::Dict{String, Vector{String}},
    𝒮::Vector{<:AbstractSub},
    𝒯::TS.TimeStructure,
    ℋ::AbstractHorizons,
    optimizer,
)
    for s ∈ 𝒮
        _check_period_partitions(log, s, 𝒯, ℋ, optimizer)
    end
end
function _check_period_partitions(
    log::Dict{String, Vector{String}},
    s::AbstractSub,
    𝒯::TS.TimeStructure,
    ℋ::AbstractHorizons,
    optimizer,
)
    opers = collect(𝒯)

    # Identify whether the `Substitution` has `PartitionReset`s
    part_res = filter(res_type -> isa(res_type, PartitionReset), resets(s))

    if !isempty(part_res)
        # Extract the period duration for the reset. It must be the same for all resets
        𝒯ᵖᵈ = period_duration(first(part_res), 𝒯)
        opers = collect(𝒯)

        # Iterate through all horizons
        x_org = original(s)
        opers_opt_ref = nothing
        n_opt_ref = nothing
        n_impl_ref = nothing
        log["$(x_org)"] = String[]
        for 𝒽 ∈ ℋ
            # Extract variables and reassign values
            opers_opt = opers[indices_optimization(𝒽)]
            opers_impl = opers[indices_implementation(𝒽)]
            if isnothing(opers_opt_ref)
                opers_opt_ref = deepcopy(opers_opt)
            end
            if length(opers_opt) < length(opers_opt_ref)
                n_opt_ref = nothing
                n_impl_ref = nothing
            end

            # Check the two horizons
            msg_opt, bool_opt, n_opt_ref =
                _check_horizon(n_opt_ref, 𝒯ᵖᵈ, opers_opt, "optimization", optimizer)
            msg_impl, bool_impl, n_impl_ref =
                _check_horizon(n_impl_ref, 𝒯ᵖᵈ, opers_impl, "implementation", optimizer)

            # Add to the logs
            (bool_opt || bool_impl) && push!(log["$(x_org)"], "Horizon $(𝒽): \n")
            if bool_opt
                log["$(x_org)"][end] *= msg_opt
            end
            if bool_impl
                log["$(x_org)"][end] *= msg_impl
            end
        end
    end
end

"""
    _check_horizon(n_ref::Union{Nothing, Vector{Int}}, 𝒯ᵖᵈ, opersᵣₕ, name::String, optimizer)

Function for identifying any potential inconsistencies between the operational periods of a
horizon `opersᵣₕ` and the period partitions `𝒯ᵖᵈ` for a given horizon `name`.

Returns a log, a boolean indicating whether there are inconsistencies and the reference
number of partitions within the horizon.
"""
function _check_horizon(n_ref::Union{Nothing, Vector{Int}}, 𝒯ᵖᵈ, opersᵣₕ, name::String, optimizer)
    parts = filter(t_pd -> isempty(setdiff(t_pd, opersᵣₕ)), 𝒯ᵖᵈ)
    n_parts = [length(part) for part ∈ parts]
    log = ""
    bool_op = nothing
    bool_poi = false
    try
        opersₚₐᵣₜ = reduce(vcat, [collect(part) for part ∈ parts])
        bool_op = any(t ∉ opersₚₐᵣₜ for t ∈ opersᵣₕ)
        if isnothing(n_ref)
            n_ref = n_parts
        else
            log = _check_number_op(n_parts, n_ref, name, optimizer)
            bool_poi = !isempty(log)
        end
    catch e
        bool_op = true
    end
    if bool_op
        log *= "  The partitions are inconsistent with the $(name) horizon.\n"
    end
    return log, bool_op || bool_poi, n_ref
end

_check_number_op(_::Vector{Int}, _::Vector{Int}, _::String, _) = ""

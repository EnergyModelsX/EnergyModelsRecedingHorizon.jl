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
    _update_periods_mapping!(𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod}, 𝒯ᵣₕ::TS.TimeStructure)
    _update_periods_mapping!(𝒰::UpdateCase, 𝒮::Vector{<:AbstractSub}, opers::Vector{<:TS.TimePeriod}, 𝒯ᵣₕ::TS.TimeStructure)
    _update_periods_mapping!(𝒰::UpdateCase, s::AbstractSub, opers::Vector{<:TS.TimePeriod}, 𝒯ᵣₕ::TS.TimeStructure)

Update the mappings between the periods (and period partitions, if present) of the receding
horizon problem (through `𝒯ᵣₕ`) and the periods (period partitions) of the original problem
(through `opers`) in the [`UpdateCase`](@ref) `𝒰`.

The mappings are stored under the keys
- `:periods` for operational periods and
- `:partitions` for period partitions, if present.

The mapping of the period partitions is stored separately for each element as different
elements can have the same period partitions in the receding horizon problem while the
corresponding period partitions of the original problem differ. Only
[`AbstractSub`](@ref)s with a [`PartitionReset`](@ref) contribute to the partition mapping.
"""
function _update_periods_mapping!(
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
    𝒯ᵣₕ::TS.TimeStructure,
)
    # Update period mapping
    𝒰.map_org[:periods] = Dict(zip(𝒯ᵣₕ, opers))
    𝒰.map_updated[:periods] = Dict(zip(opers, 𝒯ᵣₕ))

    # Update partition mapping
    𝒰.map_org[:partitions] = Dict{Any,Dict{TS.PeriodPartition,TS.PeriodPartition}}()
    𝒰.map_updated[:partitions] = Dict{Any,Dict{TS.PeriodPartition,TS.PeriodPartition}}()
    _update_periods_mapping!(𝒰, get_sub_model(𝒰), opers, 𝒯ᵣₕ)
    _update_periods_mapping!(𝒰, get_sub_products(𝒰), opers, 𝒯ᵣₕ)
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        _update_periods_mapping!(𝒰, 𝒮, opers, 𝒯ᵣₕ)
    end
end
function _update_periods_mapping!(
    𝒰::UpdateCase,
    𝒮::Vector{<:AbstractSub},
    opers::Vector{<:TS.TimePeriod},
    𝒯ᵣₕ::TS.TimeStructure,
)
    for s ∈ 𝒮
        _update_periods_mapping!(𝒰, s, opers, 𝒯ᵣₕ)
    end
end
function _update_periods_mapping!(
    𝒰::UpdateCase,
    s::AbstractSub,
    opers::Vector{<:TS.TimePeriod},
    𝒯ᵣₕ::TS.TimeStructure,
)
    # Identify whether the `Substitution` has `PartitionReset`s. The period duration is the
    # same for all resets of a given `AbstractSub`
    part_res = filter(res_type -> isa(res_type, PartitionReset), resets(s))
    isempty(part_res) && return nothing

    # Identify the partitions of the original problem that are used within the current
    # receding horizon problem and the corresponding partitions of the receding horizon problem
    𝒯 = get_time_struct(𝒰)
    parts = _partitions_within(period_duration(first(part_res), 𝒯), opers)
    partsᵣₕ = collect(partition_duration(𝒯ᵣₕ, period_duration(updated(s))))

    # Add the mapping in both directions
    # `zip` truncates silently to the shorter vector. Both vectors have the same length as
    # neither the optimization nor the implementation horizon may split a partition
    # (`_check_period_partitions`). In the POI implementation, `partsᵣₕ` is calculated from
    # the original profile (`NoResBehav`). Hence, it requires in addition the same pattern of
    # periods per partition in all horizons (`_check_number_op`).
    𝒰.map_org[:partitions][updated(s)] =
        Dict{TS.PeriodPartition,TS.PeriodPartition}(zip(partsᵣₕ, parts))
    𝒰.map_updated[:partitions][original(s)] =
        Dict{TS.PeriodPartition,TS.PeriodPartition}(zip(parts, partsᵣₕ))
end

"""
    _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)

Function which iterates through the nodes in `case[:nodes]` and `case_copy[:nodes]`, find all
`OperationalProfile{Real}` and changes them to `OperationalProfile{VariableRef}`

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)
    update_dict = Dict{EMB.Node,Dict}()
    lens_dict = Dict{EMB.Node,Dict}()
    for k ∈ 1:length(case[:nodes])
        n_new = case[:nodes][k]
        n_old = case_copy[:nodes][k]
        @assert n_new.id == n_old.id

        T = case[:T]
        update_dict[n_old] = Dict{Any,Any}()
        lens_dict[n_old] = Dict{Any,Any}()
        paths_oper = _find_paths_operational_profile(n_new)

        for field_id ∈ paths_oper
            lens = _create_lens_for_field(field_id)
            !isa(lens(n_old), OperationalProfile) && continue
            prof = OperationalProfile(MOI.Parameter.(lens(n_old)[T]))
            update_dict[n_old][field_id] = @variable(m, [T] ∈ prof[collect(T)])

            @reset lens(n_new) =
                OperationalProfile([update_dict[n_old][field_id][t] for t ∈ T])
            lens_dict[n_old][field_id] = lens
        end
        case[:nodes][k] = n_new
    end
    return case, update_dict, lens_dict
end

"""
    _get_elements_rh(m, 𝒩::Vector{<:EMB.Node}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
    _get_elements_rh(m, ℒ::Vector{<:Link}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)

Returns a new element vector identical to the original element vector`𝒩::Vector{<:EMB.Node}`
or ℒ::Vector{<:Link} with all fields identified through the lenses in `lens_dict` with JuMP
Parameter variables as well providing an `update_dict` that corresponds to the varaibels.s.

In the case of a `ℒ::Vector{<:Link}`, it furthermore update all connections in the fields
`to` and `from` with the respective nodes as outlined in the `map_dict`.
"""
function _get_elements_rh(m, 𝒩::Vector{<:EMB.Node}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
    update_dict = Dict{EMB.Node,Dict}()
    𝒩ʳʰ = deepcopy(𝒩)
    for (k, n) ∈ enumerate(𝒩)
        n_rh = 𝒩ʳʰ[k]
        if !isempty(lens_dict[n])
            update_dict[n] = Dict{Any,Any}()
            for (field_id, lens) ∈ lens_dict[n]
                val = lens(n)
                n_rh, update_dict[n][field_id] = _reset_field(m, n_rh, lens, val, 𝒯ᴿᴴ)
            end
        end
        𝒩ʳʰ[k] = n_rh
    end
    return 𝒩ʳʰ, update_dict
end
function _get_elements_rh(m, ℒ::Vector{<:Link}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
    update_dict = Dict{Link,Dict}()
    ℒʳʰ = deepcopy(ℒ)
    for (k, l) ∈ enumerate(ℒ)
        l_rh = ℒʳʰ[k]
        update_dict[l] = Dict{Any,Any}()
        for (field_id, lens) ∈ lens_dict[l]
            if field_id == [:to] || field_id == [:from]
                n = lens(l)
                @reset lens(l_rh) = map_dict[:nodes][n]
            else
                val = lens(l)
                l_rh, update_dict[n][field_id] = _reset_field(m, l_rh, lens, val, 𝒯ᴿᴴ)
            end
        end
        isempty(update_dict[l]) && delete!(update_dict, l)
        ℒʳʰ[k] = l_rh
    end
    return ℒʳʰ, update_dict
end

"""
    _get_model_rh(m, model::RecHorEnergyModel, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)

Returns a new model with adjustments in the values of `OperationalProfile`s due to the
change in the horizon as indicated through the operational periods array `𝒯ᴿᴴ`.
"""
function _get_model_rh(m, model::RecHorEnergyModel, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
    update_dict = Dict{Any,Any}()
    model_rh = deepcopy(model)
    if !isempty(lens_dict)
        for (field_id, lens) ∈ lens_dict
            val = lens(model)
            model_rh, update_dict[field_id] = _reset_field(m, model_rh, lens, val, 𝒯ᴿᴴ)
        end
    end
    return model_rh, update_dict
end

"""
    _reset_field(m, x_rh, lens::L, val::T, 𝒯ᴿᴴ::TimeStructure) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    _reset_field(m, x_rh, lens::L, val::Vector{T}, 𝒯ᴿᴴ::TimeStructure) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    _reset_field(m, x_rh, lens::L, val::OperationalProfile, 𝒯ᴿᴴ::TimeStructure) where {L <: Union{PropertyLens, ComposedFunction}}

Resets the field identified through `lens` of element `x_rh` with a JuMP parameter variable
and initialize the variable with the values provided in

1. the value `val` as single `Real`,
2. the values `Vector{T}` where `T<:Real`, indexed as `1:length(val)`, or
3. as operational profile using the operational periods in `𝒯ᴿᴴ`.
"""
function _reset_field(
    m,
    x_rh,
    lens::L,
    val::T,
    𝒯ᴿᴴ::TimeStructure,
) where {L<:Union{PropertyLens,ComposedFunction},T<:Real}
    val_par = MOI.Parameter(val)
    var = @variable(m, set = val_par)
    @reset lens(x_rh) = var
    return x_rh, var
end
function _reset_field(
    m,
    x_rh,
    lens::L,
    val::Vector{T},
    𝒯ᴿᴴ::TimeStructure,
) where {L<:Union{PropertyLens,ComposedFunction},T<:Real}
    val_par = MOI.Parameter.(val)
    var = @variable(m, [1:length(val)] ∈ val_par)
    @reset lens(x_rh) = var
    return x_rh, var
end
function _reset_field(
    m,
    x_rh,
    lens::L,
    val::OperationalProfile,
    𝒯ᴿᴴ::TimeStructure,
) where {L<:Union{PropertyLens,ComposedFunction}}
    val_par = OperationalProfile(MOI.Parameter.(val[𝒯ᴿᴴ]))
    var = @variable(m, [𝒯ᴿᴴ] ∈ val_par[collect(𝒯ᴿᴴ)])
    @reset lens(x_rh) = OperationalProfile([var[t] for t ∈ 𝒯ᴿᴴ])
    return x_rh, var
end

"""
    _set_elements_rh!(m, lens_dict, update_dict, init_data, opers::Vector{<:TS.TimePeriod})

Iterate through the inidividual elements (keys) in `update_dict` and extract the individual
variables for each element x.

The function calls the subroutine [`_set_parameter!`](@ref) to set the parameter to the new
    value, either through new init data or through slicing.

!!! warn
    The current system is not really robust. It assumes that all data provided that is not
    an `OperationalProfile` is pointing towards an `AbstractInitData`.

!!! todo "Internal if loop"
    The internal if loop is required as the lenses can point towards `AbstractInitData` objects.
    This is solved through the if loop that checks for `:init_val_dict`, which only works
    for the concrete `InitData`.
"""
function _set_elements_rh!(
    m,
    lens_dict,
    update_dict,
    init_data,
    opers::Vector{<:TS.TimePeriod},
)
    for (x, node_dict) ∈ update_dict
        for (field, var_arr) ∈ node_dict
            lens = lens_dict[x][field]
            val = nothing
            if :init_val_dict ∈ field
# TODO: check if field points to AbstractInitData in a better way
                init_field = field[findfirst(x -> x == :init_val_dict, field):end]
                lens_init = _create_lens_for_field(init_field)
                val = lens_init(init_data[x])
            else
                val = lens(x)[opers]
            end
            _set_parameter!(m, var_arr, val)
        end
    end
end

"""
    _set_parameter!(m, var, val::Real)
    _set_parameter!(m, var_arr, val::Vector)

Set the parameter of variable `var` or variable array `var_arr` depending on whether the
value is a `Real` or a `Vector`.
"""
function _set_parameter!(m, var, val::Real)
    MOI.set(m, POI.ParameterValue(), var, val)
end
function _set_parameter!(m, var_arr, val::Vector)
    for (i, var) ∈ enumerate(var_arr)
        MOI.set(m, POI.ParameterValue(), var, val[i])
    end
end

"""
    _set_values_operational_profile(
        m::JuMP.Model,
        case_copy,
        n::EMB.Node,
        update_dict::Dict{EMB.Node,Dict},
        lens_dict::Dict{EMB.Node,Dict};
        multiplier = 1,
    )

Updates the value of the POI parameter for node `n` based on the values of the node `n` in
`case_copy` for the period `𝒽`.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _set_values_operational_profile(
    m::JuMP.Model,
    case_copy,
    n::EMB.Node,
    update_dict::Dict{EMB.Node,Dict},
    lens_dict::Dict{EMB.Node,Dict};
    multiplier = 1,
)
    for (par, lens) ∈ lens_dict[n]
        new_values = _get_new_POI_values(n, lens; multiplier = multiplier)

        for (i, t) ∈ enumerate(case_copy[:T])
            MOI.set(m, POI.ParameterValue(), update_dict[n][par][t], new_values[i])
        end
    end
    return m
end

"""
    _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)

Currently, it returns the value lens(n).vals.

!!! note
    The idea is to slice the currently received value based on the horizon `𝒽`. This is
    not implemented yet.
    The `multiplier` is there for testing puroposes.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)
    return _get_new_POI_values(n, lens; multiplier = multiplier) #TODO: slice this based on h
end
function _get_new_POI_values(n::EMB.Node, lens; multiplier = 1)
    return lens(n).vals .* multiplier
end

"""
    init_rh_case_model(case, model, 𝒽, lens_dict, optimizer)

Initialize the provided receding horizon `case_rh` and `model_rh` types, the JuMP model `m`,
and the dictionary with the JuMP variables `update_dict` when utilizing `ParametricOptInterface`.

The initialization is utilizing the first horizon `𝒽`.
"""
function init_rh_case_model(case, model, 𝒽, lens_dict, optimizer)
    m = Model(() -> optimizer)

    # only works for operational profiles due to case[:T] definition and dispatches on get_property_rh,
    # must be improved to deal with more cases
    𝒯ᵣₕ = TwoLevel(1, 1, SimpleTimes(durations(𝒽)))
    𝒫ᵣₕ = get_products(case)
    𝒳ᵛᵉᶜ = get_elements_vec(case)

    # Initialize the dictionaries
    ele_dict = Dict{Symbol,Vector}()
    map_dict = Dict{Symbol,Dict}()
    update_dict = Dict{Symbol,Dict}()

    # Update the nodes with the parameter variables
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        ele = EMRH._get_key(𝒳)
        ele_dict[ele], map_dict, update_dict[ele] =
            EMRH._get_elements_rh(m, 𝒳, map_dict, lens_dict[ele], 𝒯ᵣₕ)
    end

    # Update the model with the parameter variables
    modelᵣₕ, update_dict[:model] =
        EMRH._get_model_rh(m, model, map_dict, lens_dict[:model], 𝒯ᵣₕ)

    caseᵣₕ = Case(𝒯ᵣₕ, 𝒫ᵣₕ, collect(values(ele_dict)), get_couplings(case))
    return caseᵣₕ, modelᵣₕ, map_dict, update_dict, m
end
"""
    update_model!(m, case, model, 𝒽, lens_dict, update_dict, init_data)

Update the JuMP model `m` with the new values for horizon `𝒽`.
"""
function update_model!(m, case, model, 𝒽, lens_dict, update_dict, init_data)
    # Identify the operational period
    𝒯 = get_time_struct(case)
    opers = collect(𝒯)[indices_optimization(𝒽)]

    # Update the parameters of the nodes, links, and the model
    for ele ∈ keys(lens_dict)
        _set_elements_rh!(m, lens_dict[ele], update_dict[ele], init_data, opers)
    end
end

"""
    EMRH._get_elements_rh(m, 𝒳::Vector{T}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure) where {T<:AbstractElement}
    EMRH._get_elements_rh(m, ℒ::Vector{<:Link}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)

Returns a new element vector identical to the original element vector`𝒩::Vector{<:EMB.Node}`
or ℒ::Vector{<:Link} with all fields identified through the lenses in `lens_dict` with JuMP
Parameter variables as well providing an `update_dict` that corresponds to the varaibels.s.

In the case of a `ℒ::Vector{<:Link}`, it furthermore update all connections in the fields
`to` and `from` with the respective nodes as outlined in the `map_dict`.
"""
function EMRH._get_elements_rh(
    m,
    𝒳::Vector{T},
    map_dict,
    lens_dict,
    𝒯ᴿᴴ::TimeStructure,
) where {T<:AbstractElement}
    update_dict = Dict{EMB.Node,Dict}()
    𝒳ʳʰ = deepcopy(𝒳)
    map_dict[EMRH._get_key(𝒳)] = Dict{T,T}()
    for (k, x) ∈ enumerate(𝒳)
        x_rh = 𝒳ʳʰ[k]
        if !isempty(lens_dict[x])
            update_dict[x] = Dict{Any,Any}()
            for (field_id, lens) ∈ lens_dict[x]
                val = lens(x)
                x_rh, update_dict[x][field_id] = EMRH._reset_field(m, x_rh, lens, val, 𝒯ᴿᴴ)
            end
        end
        𝒳ʳʰ[k] = x_rh
        map_dict[EMRH._get_key(𝒳)][𝒳[k]] = x_rh
    end
    return 𝒳ʳʰ, map_dict, update_dict
end
function EMRH._get_elements_rh(m, ℒ::Vector{<:Link}, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
    update_dict = Dict{Link,Dict}()
    ℒʳʰ = deepcopy(ℒ)
    map_dict[:links] = Dict{Link,Link}()
    for (k, l) ∈ enumerate(ℒ)
        l_rh = ℒʳʰ[k]
        update_dict[l] = Dict{Any,Any}()
        for (field_id, lens) ∈ lens_dict[l]
            if field_id == [:to] || field_id == [:from]
                n = lens(l)
                @reset lens(l_rh) = map_dict[:nodes][n]
            else
                val = lens(l)
                l_rh, update_dict[n][field_id] = EMRH._reset_field(m, l_rh, lens, val, 𝒯ᴿᴴ)
            end
        end
        isempty(update_dict[l]) && delete!(update_dict, l)
        ℒʳʰ[k] = l_rh
        map_dict[:links][ℒ[k]] = l_rh
    end
    return ℒʳʰ, map_dict, update_dict
end

"""
    EMRH._get_model_rh(m, model::EMRH.RecHorEnergyModel, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)

Returns a new model with adjustments in the values of `OperationalProfile`s due to the
change in the horizon as indicated through the operational periods array `𝒯ᴿᴴ`.
"""
function EMRH._get_model_rh(m, model::EMRH.RecHorEnergyModel, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
    update_dict = Dict{Any,Any}()
    model_rh = deepcopy(model)
    if !isempty(lens_dict)
        for (field_id, lens) ∈ lens_dict
            val = lens(model)
            model_rh, update_dict[field_id] = EMRH._reset_field(m, model_rh, lens, val, 𝒯ᴿᴴ)
        end
    end
    return model_rh, update_dict
end

"""
    EMRH._reset_field(m, x_rh, lens::L, val::T, 𝒯ᴿᴴ::TimeStructure) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    EMRH._reset_field(m, x_rh, lens::L, val::Vector{T}, 𝒯ᴿᴴ::TimeStructure) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    EMRH._reset_field(m, x_rh, lens::L, val::OperationalProfile, 𝒯ᴿᴴ::TimeStructure) where {L <: Union{PropertyLens, ComposedFunction}}

Resets the field identified through `lens` of element `x_rh` with a JuMP parameter variable
and initialize the variable with the values provided in

1. the value `val` as single `Real`,
2. the values `Vector{T}` where `T<:Real`, indexed as `1:length(val)`, or
3. as operational profile using the operational periods in `𝒯ᴿᴴ`.
"""
function EMRH._reset_field(
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
function EMRH._reset_field(
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
function EMRH._reset_field(
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
                lens_init = EMRH._create_lens_for_field(init_field)
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

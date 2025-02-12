"""
    init_rh_case_model(m, 𝒰, opers, 𝒯ᵣₕ)

Initialize the JuMP model `m` and the UpdateCase `𝒰` with the anonymous variables
corresponding to the inidividual fields of all types whose value(s) change(s).

In addition, the UpdateCase `𝒰` is updated with the new mapping between the operational
periods of the optimization (through `𝒯ᵣₕ`) and the original (through `opers`) problem.
"""
function init_rh_case_model(m, 𝒰, opers, 𝒯ᵣₕ)
    _update_elements_rh!(m, get_sub_model(𝒰), 𝒰, 𝒯ᵣₕ)
    _update_elements_rh!(m, get_sub_products(𝒰), 𝒰, 𝒯ᵣₕ)
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        _update_elements_rh!(m, 𝒮, 𝒰, 𝒯ᵣₕ)
    end
    𝒰.opers = Dict(zip(𝒯ᵣₕ, opers))
end
"""
    update_model!(m, 𝒰, opers, 𝒯ᵣₕ)

Update the JuMP model `m` with the new values given by the vector of operational periods of
the original problem `opers`.

In addition, the UpdateCase `𝒰` is updated with the new mapping between the operational
periods of the optimization (through `𝒯ᵣₕ`) and the original (through `opers`) problem.
"""
function update_model!(m, 𝒰, opers, 𝒯ᵣₕ)
    _set_elements_rh!(m, get_sub_model(𝒰), opers)
    _set_elements_rh!(m, get_sub_products(𝒰), opers)
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        _set_elements_rh!(m, 𝒮, opers)
    end
    𝒰.opers = Dict(zip(𝒯ᵣₕ, opers))
end

"""
    EMRH._update_elements_rh!(m, 𝒮::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    EMRH._update_elements_rh!(m, s:::AbstractSub, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Updates the elements within the `Vector{<:AbstractSub}` or `AbstractSub` with the new values,
The update only takes place when the field `reset` of a given `AbstractSub` is not empty.
In this case, the subfunction [`_reset_field`](@ref EMRH._reset_field(m, x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure)) is called.

The variables for `ParametricOptInterface` are saved in the model `m`.
"""
function EMRH._update_elements_rh!(
    m,
    𝒮::Vector{<:AbstractSub},
    𝒰::UpdateCase,
    𝒯ᴿᴴ::TimeStructure,
)
    for s ∈ 𝒮
        EMRH._update_elements_rh!(m, s, 𝒰, 𝒯ᴿᴴ)
    end
end
function EMRH._update_elements_rh!(
    m,
    s::AbstractSub,
    𝒰::UpdateCase,
    𝒯ᴿᴴ::TimeStructure,
)
    if isempty(resets(s))
        s.new = deepcopy(original(s))
    else
        for res_type ∈ resets(s)
            s.new = EMRH._reset_field(m, updated(s), res_type, 𝒰, 𝒯ᴿᴴ)
        end
    end
end

"""
    EMRH._reset_field(m, x_rh, res_type::ElementReset, 𝒰::UpdateCase, 𝒯ᴿᴴ::TimeStructure)
    EMRH._reset_field(m, x_rh, res_type::InitReset, 𝒰::UpdateCase, 𝒯ᴿᴴ::TimeStructure)
    EMRH._reset_field(m, x_rh, res_type::OperReset, 𝒰::UpdateCase, 𝒯ᴿᴴ::TimeStructure)

Resets the field identified through `lens` of element `x_rh` with a JuMP parameter variable
and initialize the variable with the values provided in `res_type`:

1. `res_type::ElementReset` uses the `map_dict` for identifying the correct node without
   creating a new variable,
2. `res_type::InitReset` creates a single new variables and uses the the value directly,
3. `res_type::OperReset` creates multiple new variables and a new operational profile based
   on the original operational profile and the set of operational periods in the time
   structure `𝒯ᴿᴴ`.
"""
function EMRH._reset_field(
    m,
    x_rh,
    res_type::ElementReset,
    𝒰::UpdateCase,
    𝒯ᴿᴴ::TimeStructure,
)
    @reset res_type.lens(x_rh) = updated(𝒰, res_type.val)
    return x_rh
end
function EMRH._reset_field(
    m,
    x_rh,
    res_type::InitReset,
    𝒰::UpdateCase,
    𝒯ᴿᴴ::TimeStructure,
)
    val_par = MOI.Parameter(res_type.val)
    res_type.var = @variable(m, set = val_par)
    @reset res_type.lens(x_rh) = res_type.var
    return x_rh
end
function EMRH._reset_field(
    m,
    x_rh,
    res_type::OperReset,
    𝒰::UpdateCase,
    𝒯ᴿᴴ::TimeStructure,
)
    val_par = OperationalProfile(MOI.Parameter.(res_type.val[𝒯ᴿᴴ]))
    res_type.var = @variable(m, [𝒯ᴿᴴ] ∈ val_par[collect(𝒯ᴿᴴ)])
    @reset res_type.lens(x_rh) = OperationalProfile([res_type.var[t] for t ∈ 𝒯ᴿᴴ])
    return x_rh
end

"""
    _set_elements_rh!(𝒮::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    _set_elements_rh!(s:::AbstractSub, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Updates the elements within the `Vector{<:AbstractSub}` or `AbstractSub` with the new values,
The update only takes place when the field `reset` of a given `AbstractSub` is not empty.
In this case, the subroutine [`_set_parameter!`](@ref) is called to set the parameter to the
new value.
"""
function _set_elements_rh!(
    m,
    𝒮::EMRH.Vector{<:AbstractSub},
    opers::Vector{<:TS.TimePeriod},
)
    for s ∈ 𝒮
        _set_elements_rh!(m, s, opers)
    end
end
function _set_elements_rh!(
    m,
    s::AbstractSub,
    opers::Vector{<:TS.TimePeriod},
)
    for res_type ∈ s.resets
        _set_parameter!(m, res_type, opers)
    end
end

"""
    _set_parameter!(m, res_type::ElementReset, opers::Vector)
    _set_parameter!(m, res_type::OperReset, opers::Vector)
    _set_parameter!(m, res_type::InitReset{EMRH.InitDataPath}, opers::Vector)

Set the parameter parameter value for a given `res_type`:

1. `res_type::ElementReset` results in no update,
2. `res_type::InitReset{EMRH.InitDataPath}` updates the value based on the value of the
   [`InitReset`](@ref EnergyModelsRecHorizon.InitReset) type,
3. `res_type::OperReset` creates a new operational profile based on the original
   operational profile and the set of operational periods in the time structure `𝒯ᴿᴴ`.
"""
_set_parameter!(m, res_type::ElementReset, opers::Vector) = nothing
function _set_parameter!(m, res_type::OperReset, opers::Vector)
    val = res_type.val[opers]
    for (i, var) ∈ enumerate(res_type.var)
        MOI.set(m, POI.ParameterValue(), var, val[i])
    end
end
function _set_parameter!(m, res_type::InitReset{EMRH.InitDataPath}, opers::Vector)
    MOI.set(m, POI.ParameterValue(), res_type.var, res_type.val)
end

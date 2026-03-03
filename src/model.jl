
"""
    run_model_rh(case::AbstractCase, model::RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true)

Take the variables `case` and `model` and optimize the problem in a receding horizon fashion
as a series of optimization problems.

!!! warning "Required input"
    While the [`Case`](@extref EnergyModelsBase.Case) type is flexible, we have to follow
    certain structures.
    - The `case` type requires as additional input in the dictionary field `misc` the entry
      `:horizons` corresponding to an [`AbstractHorizons`](@ref) type.
    - The order of the individual elements vector in the field `elements` cannot be arbitrary
      at the moment due to the structure of the code. You **must** use the following
      order:

      1. `Vector{<:EMB.Node}`
      2. `Vector{<:Link}`
      3. `Vector{<:Area}`
      4. `Vector{<:Transmission}`

      If you do not use this structure, the model will not run.

Returns `results` as a dataframe indexed by the model variables.
"""
function run_model_rh(
    case::AbstractCase,
    model::RecHorEnergyModel,
    optimizer;
    check_timeprofiles::Bool = true,
)
    # Extract the individual values from the `Case` structure
    𝒯 = get_time_struct(case)
    opers = collect(𝒯)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒫 = get_products(case)
    ℋ = case.misc[:horizons]
    has_future_value = !isempty(filter(el -> isa(el, Vector{<:FutureValue}), 𝒳ᵛᵉᶜ))
    n_𝒽 = length(ℋ)

    # Create the `UpdateCase` based on the original `Case` structure
    𝒰 = _create_updatetype(model)
    _add_elements!(𝒰, 𝒫)
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        _add_elements!(𝒰, 𝒳)
    end
    𝒮ᵛᵉᶜ = get_sub_elements_vec(𝒰)

    # Initialize loop variables
    results = Dict{Symbol,AbstractDataFrame}()
    𝒮ᵛᵉᶜᵢₙ = [filter(has_init, 𝒮) for 𝒮 ∈ 𝒮ᵛᵉᶜ]
    if has_future_value
        # Extract the individual `FutureValue` types
        𝒮ᵛ = get_sub_ele(𝒰, FutureValue)
        val_types = unique([typeof(s_v) for s_v ∈ 𝒮ᵛ])
        𝒮ᵛ⁻ᵛᵉᶜ = [convert(Vector{fv_type}, filter(s_v -> typeof(s_v) == fv_type, 𝒮ᵛ)) for fv_type ∈ val_types]
    end

    # Iterate through the different horizons and solve the problem
    for 𝒽 ∈ ℋ
        @info "Solving for horizon $(𝒽.id) of $n_𝒽"
        # Extract the time structure from the case to identify the used operational periods
        # and the receding horizon time structure
        𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽)), SimpleTimes(durations(𝒽)))
        ind_impl = indices_implementation(𝒽)
        opers_opt = opers[indices_optimization(𝒽)]
        opers_impl = opers[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]
        time_elapsed = end_oper_time(last(opers_opt), 𝒯)

        # Update the time weights/values of `FutureValue` types
        if has_future_value
            for 𝒮ᵛ⁻ˢᵘᵇ ∈ 𝒮ᵛ⁻ᵛᵉᶜ
                _update_future_value!(𝒮ᵛ⁻ˢᵘᵇ, time_elapsed)
            end
        end

        # Update the `UpdateCase` with the new values
        _update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

        # Extract the case and the model from the `UpdateCase`
        caseᵣₕ = Case(𝒯ᵣₕ, get_products(𝒰), get_elements_vec(𝒰), get_couplings(case))
        modelᵣₕ = updated(get_sub_model(𝒰))

        # Create and solve model
        m = create_model(caseᵣₕ, modelᵣₕ; check_timeprofiles)
        set_optimizer(m, optimizer)
        set_optimizer_attribute(m, MOI.Silent(), true)
        optimize!(m)

        # Update the results
        update_results!(results, m, 𝒰, opers_impl, 𝒽)

        # Update the value for the initial data
        for 𝒮ᵢₙ ∈ 𝒮ᵛᵉᶜᵢₙ, s_in ∈ 𝒮ᵢₙ
            reset_init = filter(is_init_reset, resets(s_in))
            for ri ∈ reset_init
                update_init_data!(m, ri, updated(s_in), ri.path, opers_implᵣₕ)
            end
        end
    end

    return results
end

"""
    EMB.variables_capacity(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add capacity variables for [`FutureValue`](@ref) elements.

!!! note "FutureValue"
    No variables are added.
"""
function EMB.variables_capacity(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end

"""
    EMB.variables_flow(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add flow variables for [`FutureValue`](@ref) elements.

!!! note "FutureValue"
    No variables are added
"""
function EMB.variables_flow(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end

"""
    EMB.variables_opex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add OPEX variables for [`FutureValue`](@ref) elements.

- `future_value[𝒱]` variables for all [`FutureValue`](@ref) in the model reflecting the value
  of the storages at the end of the optimization period.
"""
function EMB.variables_opex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    @variable(m, future_value[𝒱])
end

"""
    EMB.variables_capex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add CAPEX variables for [`FutureValue`](@ref) elements.

!!! note "FutureValue"
    No variables are added
"""
function EMB.variables_capex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end

"""
    EMB.variables_element(m, 𝒱::Vector{<:FutureValue}, 𝒯, modeltype::EnergyModel)

Default fallback method for a vector of elements if no other method is defined for a given
vector type.
"""
function EMB.variables_element(m, 𝒱::Vector{<:FutureValue}, 𝒯, modeltype::EnergyModel) end

"""
    EMB.variables_emission(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Declaration of functions to add emission variables for [`FutureValue`](@ref) elements.

!!! note "FutureValue"
    No variables are added
"""
function EMB.variables_emission(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel) end

"""
    EMB.constraints_elements(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Loop through all entries of the elements vector and call a subfunction for creating the
internal constraints of the entries of the elements vector.

- [`FutureValue`](@ref) - the subfunction is [`create_future_value`](@ref).

"""
function EMB.constraints_elements(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    for v ∈ 𝒱
        create_future_value(m, v, 𝒯, modeltype)
    end
end

"""
    EMB.constraints_couple(m, 𝒱::Vector{<:FutureValue}, 𝒫, 𝒯, modeltype::EnergyModel)
    EMB.constraints_couple(m, 𝒱::Vector{<:FutureValue}, 𝒩::Vector{<:EMB.Node}, 𝒫, 𝒯, modeltype::EnergyModel)
    EMB.constraints_couple(m, 𝒩::Vector{<:EMB.Node}, 𝒱::Vector{<:FutureValue}, 𝒫, 𝒯, modeltype::EnergyModel)

Creates the couple constraints for [`FutureValue`](@ref) elements.

The current implementation creates couplings for the sub-types `StorageValueCuts` and
`TypeFutureValue` by calling the function [`create_future_value_couple`](@ref).

!!! note "Required input"
    - If you only use [`StorageValueCuts`](@ref), it is sufficient to add coupling constraints
    through adding `[get_future_value]` to the couplings of the case type.

    - If you only use [`TypeFutureValue`](@ref), it is sufficient to add coupling constraints
    through adding `[get_future_value, get_nodes]` to the couplings of the case type.

    - If you utilize both types, you **must** add both type of couplings.
"""
function EMB.constraints_couple(m, 𝒱::Vector{<:FutureValue}, 𝒫, 𝒯, modeltype::EnergyModel)
    for v ∈ 𝒱
        create_future_value_couple(m, v, 𝒯, modeltype)
    end
end

function EMB.constraints_couple(m, 𝒱::Vector{<:FutureValue}, 𝒩::Vector{<:EMB.Node}, 𝒫, 𝒯, modeltype::EnergyModel)
    for v ∈ 𝒱
        create_future_value_couple(m, v, 𝒩, 𝒯, modeltype)
    end
end

function EMB.constraints_couple(m, 𝒩::Vector{<:EMB.Node}, 𝒱::Vector{<:FutureValue}, 𝒫, 𝒯, modeltype::EnergyModel)
    return EMB.constraints_couple(m, 𝒱, 𝒩, 𝒫, 𝒯, modeltype)
end

"""
    EMB.emissions_operational(m, 𝒱::Vector{<:FutureValue}, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)

Create JuMP expressions indexed over the operational periods `𝒯` for different elements.
The expressions correspond to the total emissions of a given type.

By default, emissions expressions are included for:
- `𝒳 = 𝒱::Vector{<:FutureValue}`. In the case of a vector of [`FutureValue`](@ref), the method
  returns a value of 0 for all operational periods and emission resources.

"""
function EMB.emissions_operational(m, 𝒱::Vector{<:FutureValue}, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)
    return @expression(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ], 0)
end

"""
    EMB.objective_operational(m, 𝒱::Vector{<:FutureValue}, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)

Create JuMP expressions indexed over the investment periods `𝒯ᴵⁿᵛ` for different elements.
The expressions correspond to the operational expenses of the different elements.
The expressions are not discounted and do not take the duration of the investment periods
into account.

By default, objective expressions are included for:
- `𝒳 = 𝒱::Vector{<:FutureValue}`. In the case of a vector of [`FutureValue`](@ref), the
  method returns the sum of the future value types as extracted through the function
  [`get_future_value_expression`](@ref).

"""
function EMB.objective_operational(
    m,
    𝒱::Vector{<:FutureValue},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)
    # Extract the individual `FutureValue` types
    val_types = unique([typeof(v) for v ∈ 𝒱])

    # Calculate the value for the future value
    future_value = JuMP.Containers.DenseAxisArray[]
    for val_type ∈ val_types
        𝒱ˢᵘᵇ = convert(Vector{val_type}, filter(v -> typeof(v) == val_type, 𝒱))
        push!(future_value, get_future_value_expression(m, 𝒱ˢᵘᵇ, 𝒯ᴵⁿᵛ, modeltype))
    end

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(𝒱ˢᵘᵇ[t_inv] for 𝒱ˢᵘᵇ ∈ future_value))
end

"""
    create_future_value(m, v::FutureValue, 𝒯, modeltype)

Set all constraints for an [`FutureValue`](@ref). Fallback option for all unspecified
subtypes of `FutureValue`.
"""
function create_future_value(m, v::FutureValue, 𝒯, modeltype) end

"""
    create_future_value_couple(m, v::StorageValueCuts, 𝒯, modeltype::EnergyModel)
    create_future_value_couple(m, v::StorageValueCuts, 𝒩::Vector{<:EMB.Node}, 𝒯, modeltype::EnergyModel)
    create_future_value_couple(m, v::TypeFutureValue, 𝒯, modeltype::EnergyModel)
    create_future_value_couple(m, v::TypeFutureValue, 𝒩::Vector{<:EMB.Node}, 𝒯, modeltype::EnergyModel)

Adds the constraints for the individual future values without the interaction with any other
[`AbstractElement`](@extref EnergyModelsBase.AbstractElement).

In the case of [`StorageValueCuts`](@ref):

- If `𝒩` is **not** added, that is in the instance for the single couplings, the function
  adds the cut constraints for all cuts.
- If `𝒩` is added, that is in the instance for `FutureValue`-`Node` couplings, the function
  returns nothing.

In the case of [`TypeFutureValue`](@ref):

- If `𝒩` is **not** added, that is in the instance for the single couplings, the function
  returns nothing.
- If `𝒩` is added, that is in the instance for `FutureValue`-`Node` couplings, the function
  calculates the future value for the given type.
"""
function create_future_value_couple(m, v::StorageValueCuts, 𝒯, modeltype::EnergyModel)

    @constraint(m, [svc ∈ cuts(v)],
        m[:future_value][v] +
        sum(m[:stor_level][rsv, last(𝒯)] * coeff for (rsv, coeff) ∈ coefficients(svc))
            ≤ cut_rhs(svc)
    )
end
function create_future_value_couple(m, v::StorageValueCuts, 𝒩::Vector{<:EMB.Node}, 𝒯, modeltype::EnergyModel)
end
function create_future_value_couple(m, v::TypeFutureValue, 𝒯, modeltype::EnergyModel) end
function create_future_value_couple(m, v::TypeFutureValue, 𝒩::Vector{<:EMB.Node}, 𝒯, modeltype::EnergyModel)
    # Identify all nodes with the given type
    𝒩ˢᵘᵇ = filter(n -> isa(n, element_type(v)), 𝒩)

    @constraint(m,
        m[:future_value][v] ==
            sum(sum(m[var][n, last(𝒯)] for n ∈ 𝒩ˢᵘᵇ) * val for (var, val) ∈ coefficients(v))
    )
end

"""
    get_future_value_expression(m, 𝒱::Vector{StorageValueCuts}, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)
    get_future_value_expression(m, 𝒱::Vector{TypeFutureValue}, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)

Returns the cost expression for the individual future values.

In the case of [`StorageValueCuts`](@ref), the expression equals the weighted sum of the
`future_value` of all active cuts. Inactive cuts are weighted with 0 but still included to
keep the number of variables unchanged.

In the case of [`TypeFutureValue`](@ref), the expression equals the sum of all values.
"""
function get_future_value_expression(
    m,
    𝒱::Vector{StorageValueCuts},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        -sum(m[:future_value][v] * weight(v) * time_weight(v) for v ∈ 𝒱) /
        duration_strat(t_inv)
    )
end
function get_future_value_expression(
    m,
    𝒱::Vector{TypeFutureValue},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        -sum(m[:future_value][v] for v ∈ 𝒱) / duration_strat(t_inv)
    )
end

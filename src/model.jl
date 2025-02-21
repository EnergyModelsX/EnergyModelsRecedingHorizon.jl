
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
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒫 = get_products(case)
    ℋ = case.misc[:horizons]

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

    # Iterate through the different horizons and solve the problem
    for 𝒽 ∈ ℋ
        @info "Solving for 𝒽: $𝒽"
        # Extract the time structure from the case to identify the used operational periods
        # and the receding horizon time structure
        𝒯 = get_time_struct(case)
        𝒯ᵣₕ = TwoLevel(1, 1, SimpleTimes(durations(𝒽)))
        opers_opt = collect(𝒯)[indices_optimization(𝒽)]
        ind_impl = indices_implementation(𝒽)
        opers_impl = collect(𝒯)[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]

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
        update_results!(results, m, 𝒰, opers_impl)

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

Declaration of functions to add capacity variables for FutureValue elements.

!!! note "FutureValue"
    No variables are added.
"""
function EMB.variables_capacity(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end

"""
    EMB.variables_flow(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add flow variables for FutureValue elements.

!!! note "FutureValue"
    No variables are added
"""
function EMB.variables_flow(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel) end

"""
    EMB.variables_opex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Declaration of functions to add opex variables for FutureValue elements.

- `future_value[𝒱]` variables for all `FutureValue` in the model reflecting the value of
  at the end of the optimization period.
"""
function EMB.variables_opex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)
    @variable(m, future_value[𝒱])
end

"""
    EMB.variables_capex(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add capex variables for FutureValue elements.

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
    EMB.variables_emission(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒯, modeltype::EnergyModel)

Declaration of functions to add emission variables for FutureValue elements.

!!! note "FutureValue"
    No variables are added
"""
function EMB.variables_emission(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel) end

"""
    EMB.constraints_elements(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)

Loop through all entries of the elements vector and call a subfunction for creating the
internal constraints of the entries of the elements vector.

- `FutureValue` - the subfunction is [`create_future_value`](@ref).

"""
function EMB.constraints_elements(m, 𝒱::Vector{<:FutureValue}, 𝒳ᵛᵉᶜ, 𝒫, 𝒯, modeltype::EnergyModel)
    for v ∈ 𝒱
        create_future_value(m, v, 𝒯, modeltype)
    end
end

"""
    constraints_couple(m, 𝒱::Vector{<:FutureValue}, 𝒫, 𝒯, modeltype::EnergyModel)

Creates the couple constraints for FutureValue elements. The current implementation only
implements couplings for the sub-type `StorageValueCuts` by calling the function
[`create_future_value_couple`](@ref).
"""
function EMB.constraints_couple(m, 𝒱::Vector{<:FutureValue},  𝒫, 𝒯, modeltype::EnergyModel)
    for v ∈ 𝒱
        create_future_value_couple(m, v, 𝒯, modeltype)
    end
end

"""
    EMB.emissions_operational(m, 𝒱::Vector{<:FutureValue}, 𝒫ᵉᵐ, 𝒯, modeltype::EnergyModel)

Create JuMP expressions indexed over the operational periods `𝒯` for different elements.
The expressions correspond to the total emissions of a given type.

By default, emissions expressions are included for:
- `𝒳 = 𝒱::Vector{<:FutureValue}`. In the case of a vector of FutureValue, the method returns
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
  method returns the sum of the future_value types as extracted through the function
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
        ℱˢᵘᵇ = filter(v -> typeof(v) == val_type, 𝒱)
        push!(future_value, get_future_value_expression(m, ℱˢᵘᵇ, 𝒯ᴵⁿᵛ, modeltype))
    end

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], sum(ℱˢᵘᵇ[t_inv] for ℱˢᵘᵇ ∈ future_value))
end

"""
    create_future_value(m, v::FutureValue, 𝒯, modeltype)

Set all constraints for an [`FutureValue`](@ref). Can serve as fallback option for all
unspecified subtypes of `FutureValue`.
"""
function create_future_value(m, v::FutureValue, 𝒯,  modeltype) end

"""
    create_future_value_couple(m, 𝒯, 𝒱::Vector{StorageValueCuts}, modeltype::RecHorOperationalModel)

Build cut constraints for all cuts in a `StorageValueCuts` element.
"""
function create_future_value_couple(m, v::StorageValueCuts, 𝒯, modeltype::RecHorOperationalModel)

    @constraint(m, [svc ∈ cuts(v)],
        m[:future_value][v] +
        sum(m[:stor_level][rsv, last(𝒯)] * coeff for (rsv, coeff) ∈ coefficients(svc))
            ≤ cut_rhs(svc)
    )
end

"""
    get_future_value_expression(m, 𝒱::Vector{StorageValueCuts}, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)

The method returns an experssion equal the sum of the future_value of all active cuts.
Inactive cuts are weightet with 0.
"""
function get_future_value_expression(
    m,
    𝒱::Vector{StorageValueCuts},
    𝒯ᴵⁿᵛ::TS.AbstractStratPers,
    modeltype::EnergyModel,
)

    # Set the weight of inactive cuts to 0
    time_weights = get_active_cut_time_weights(𝒱, sum(duration(t) for t ∈ first(𝒯ᴵⁿᵛ)))
    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        -sum(
            m[:future_value][v] * v.weight * time_weight
        for (v, time_weight) ∈ time_weights) / (duration_strat(t_inv))
    )
end

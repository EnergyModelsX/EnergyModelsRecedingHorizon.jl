
"""
    run_model_rh(case::AbstractCase, model::RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true)

Take the variables `case` and `model` and optimize the problem in a receding horizon fashion
as a series of optimization problems.

!!! warning "Required input"
    While the [`Case`](@extref EnergyModelsBase.Case) type is flexible, we have to follow
    certain structures.
    - The `case` type requires as additional input in the dictionary field `misc` the entry
      `:horizons` corresponding to to an [`AbstractHorizons`](@ref) type.
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

function update_objective(m, cost_to_go)
    # println("in emrh.objective with obj.func: $(objective_function(m))")
    original_objective = objective_function(m) #this is a JuMP function
    new_objective = @expression(m, original_objective + cost_to_go) #JuMP function/macro
    set_objective_function(m, new_objective) #this is a JuMP function
    return m_obj = objective_function(m) #this is a JuMP function
    # println("objective_function is now: $(objective_function(m))")
end

#= function EMB.run_model(case::Dict, model::EnergyModel, optimizer; check_timeprofiles=true)
    throw MethodError(2, "This method should is not used in EMRH")
end =#

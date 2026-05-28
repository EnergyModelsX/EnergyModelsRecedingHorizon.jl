"""
    EMRH.run_model_rh(case::AbstractCase, model::RecHorEnergyModel, optimizer::POI.Optimizer; check_timeprofiles::Bool = true)

When the optimizer is a `ParametricOptInterface.Optimizer` type, it utilizes
`ParametricOptInterface` (POI) for resetting the individual values.

!!! warning "Using POI"
    When using POI, the horizon type must be a [`PeriodHorizons`](@ref) type with each
    individual horizon having the same durations for its periods. This is checked using
    an `@assert` macro.
"""
function EMRH.run_model_rh(
    case::AbstractCase,
    model::RecHorEnergyModel,
    optimizer::POI.Optimizer;
    check_timeprofiles::Bool = true,
)
    # Extract the individual values from the `Case` structure
    𝒯 = get_time_struct(case)
    opers = collect(𝒯)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒫 = get_products(case)
    ℋ = case.misc[:horizons]
    𝒽₀ = first(ℋ)
    n_𝒽 = length(ℋ)

    # Assert that the horizon is functioning with the POI implementation.
    horizon_duration = all(
        durations(𝒽) == durations(𝒽₀) for
        𝒽 ∈ ℋ if length(𝒽) == length(𝒽₀)
    )
    @assert(
        isa(ℋ, PeriodHorizons),
        "The horizons type must be a `PeriodHorizons` in which all horizons have the same\n" *
        "duration length for the individual periods."
    )
    @assert(
        horizon_duration,
        "All horizon types must have the same duration length for the individual periods."
    )

    # Create the `UpdateCase` based on the original `Case` structure
    𝒰 = _create_updatetype(model)
    _add_elements!(𝒰, 𝒫)
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        _add_elements!(𝒰, 𝒳)
    end

    # Extract the time structure from the case to identify the used operational periods
    # and the receding horizon time structure
    𝒯 = get_time_struct(case)
    𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽₀)), SimpleTimes(durations(𝒽₀)))
    opers_opt = opers[indices_optimization(𝒽₀)]
    opers_impl = opers[indices_implementation(𝒽₀)]

    # Update the receding horizon case and model as well as JuMP model
    m = Model(() -> optimizer)
    set_optimizer_attribute(m, MOI.Silent(), true)
    _init_update_case!(m, 𝒰, opers_opt, 𝒯ᵣₕ)

    # Extract the case and the model from the `UpdateCase`
    caseᵣₕ = Case(𝒯ᵣₕ, get_products(𝒰), get_elements_vec(𝒰), get_couplings(case))
    modelᵣₕ = updated(get_sub_model(𝒰))

    # Create the EMX model
    m = create_model(caseᵣₕ, modelᵣₕ, m; check_timeprofiles, check_any_data = false)

    # Initialize loop variables
    𝒮ᵛ⁻ᵛᵉᶜ, 𝒮ᵛᵉᶜᵢₙ, results = _initialize_loop_variables(𝒰)

    # Iterate through the different horizons and solve the problem
    for 𝒽 ∈ ℋ
        @info "Solving for horizon $(𝒽.id) of $n_𝒽"
        # Necessary break as `ParametricOptInterface` requires that the number of operational
        # periods is always the same. In this case, we use the last values from the previous
        # horizon
        if length(𝒽) < length(𝒯ᵣₕ)
            opers_not_impl = setdiff(opers_opt, opers_impl)
            update_results!(results, m, 𝒰, opers_not_impl, 𝒽)
            break
        end

        # Extract the time structure from the case to identify the used operational periods
        # and the receding horizon time structure
        opers_opt = opers[indices_optimization(𝒽)]
        opers_impl = opers[indices_implementation(𝒽)]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[eachindex(opers_impl)]
        time_elapsed = end_oper_time(last(opers_opt), 𝒯)

        # Update the time weights/values of `FutureValue` types
        for 𝒮ᵛ⁻ˢᵘᵇ ∈ 𝒮ᵛ⁻ᵛᵉᶜ
            update_future_value!(𝒮ᵛ⁻ˢᵘᵇ, time_elapsed)
        end

        # Update and solve model
        isfirst(𝒽) || update_model!(m, 𝒰, opers_opt, 𝒯ᵣₕ)
        optimize!(m)

        # Update the results
        update_results!(results, m, 𝒰, opers_impl, 𝒽)

        # Update the value for the initial data
        update_init_data!(m, 𝒮ᵛᵉᶜᵢₙ, opers_implᵣₕ)
    end

    return results
end

"""
    EMRH.run_model_rh(case::AbstractCase, model::EMRH.RecHorEnergyModel, optimizer::POI.Optimizer; check_timeprofiles::Bool = true)

When the optimizer is a `ParametricOptInterface.Optimizer` type, it utilizes
`ParametricOptInterface` (POI) for resetting the individual values.

!!! warning "Using POI"
    When using POI, the horizon type must be a [`PeriodHorizons`](@ref) type with each
    individual horizon having the same durations for its periods. This is checked using
    an `@assert` macro.
"""
function EMRH.run_model_rh(
    case::AbstractCase,
    model::EMRH.RecHorEnergyModel,
    optimizer::POI.Optimizer;
    check_timeprofiles::Bool = true,
)
    # Extract the individual values from the `Case` structure
    𝒯 = get_time_struct(case)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒫 = get_products(case)
    ℋ = case.misc[:horizons]
    𝒽₀ = first(ℋ)
    n_𝒽 = length(ℋ)
    has_future_value = !isempty(filter(el -> isa(el, Vector{<:FutureValue}), 𝒳ᵛᵉᶜ))

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
    𝒮ᵛᵉᶜ = get_sub_elements_vec(𝒰)

    # Extract the time structure from the case to identify the used operational periods
    # and the receding horizon time structure
    𝒯 = get_time_struct(case)
    𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽₀)), SimpleTimes(durations(𝒽₀)))
    opers_opt = collect(𝒯)[indices_optimization(𝒽₀)]
    ind_impl = indices_implementation(𝒽₀)
    opers_impl = collect(𝒯)[ind_impl]
    opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]
    opers_not_impl = setdiff(opers_opt, opers_impl)

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
    results = Dict{Symbol,AbstractDataFrame}()
    𝒮ᵛᵉᶜᵢₙ = Vector{AbstractSub}[filter(has_init, 𝒮) for 𝒮 ∈ 𝒮ᵛᵉᶜ]
    if has_future_value
        # Extract the individual `FutureValue` types
        𝒮ᵛ = get_sub_ele(𝒰, FutureValue)
        val_types = unique([typeof(s_v) for s_v ∈ 𝒮ᵛ])
        𝒮ᵛ⁻ᵛᵉᶜ = [convert(Vector{fv_type}, filter(s_v -> typeof(s_v) == fv_type, 𝒮ᵛ)) for fv_type ∈ val_types]
    end

    # Iterate through the different horizons and solve the problem
    for 𝒽 ∈ ℋ
        @info "Solving for horizon $(𝒽.id) of $n_𝒽"
        # Necessary break as `ParametricOptInterface` requires that the number of operational
        # periods is always the same. In this case, we use the last values from the previous
        # horizon
        if length(𝒽) < length(𝒯ᵣₕ)
            update_results!(results, m, 𝒰, opers_not_impl, 𝒽)
            break
        end

        # Extract the time structure from the case to identify the used operational periods
        # and the receding horizon time structure
        opers_opt = collect(𝒯)[indices_optimization(𝒽)]
        ind_impl = indices_implementation(𝒽)
        opers_impl = collect(𝒯)[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]
        opers_not_impl = setdiff(opers_opt, opers_impl)
        time_elapsed = end_oper_time(last(opers_opt), 𝒯)

        # Update the time weights/values of `FutureValue` types
        if has_future_value
            for 𝒮ᵛ⁻ˢᵘᵇ ∈ 𝒮ᵛ⁻ᵛᵉᶜ
                update_future_value!(𝒮ᵛ⁻ˢᵘᵇ, time_elapsed)
            end
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

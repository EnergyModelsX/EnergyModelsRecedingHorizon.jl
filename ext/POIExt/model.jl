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

    # WIP Data structure
    𝒯 = get_time_struct(case)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒩 = get_nodes(𝒳ᵛᵉᶜ)
    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    ℋ = case.misc[:horizons]
    𝒽₀ = first(ℋ)

    # Assert that the horizon is functioning with the POI implementation.
    horizons = collect(ℋ)
    horizon_duration = all(
        durations(h) == durations(horizons[1]) for
        h ∈ horizons if length(h) == length(horizons[1])
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

    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    𝒾ⁱⁿⁱᵗ = collect(findfirst(map(is_init_data, node_data(n))) for n ∈ 𝒩ⁱⁿⁱᵗ)
    init_data = Dict(n => node_data(n)[i] for (n, i) ∈ zip(𝒩ⁱⁿⁱᵗ, 𝒾ⁱⁿⁱᵗ))

    lens_dict = Dict{Symbol,Dict}()
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        lens_dict[EMRH._get_key(𝒳)] = EMRH._create_lens_dict_oper_prof(𝒳)
    end
    lens_dict[:model] = EMRH._create_lens_dict_oper_prof(model)

    # initializing loop variables and receding horizon case
    results = Dict{Symbol,AbstractDataFrame}()
    caseᵣₕ, modelᵣₕ, convert_dict, update_dict, m =
        init_rh_case_model(case, model, 𝒽₀, lens_dict, optimizer)

    𝒯ᵣₕ = get_time_struct(caseᵣₕ)
    𝒩ᵣₕ = get_nodes(caseᵣₕ)
    𝒩ⁱⁿⁱᵗᵣₕ = filter(has_init, 𝒩ᵣₕ)
    opers_not_impl = collect(𝒯)[indices_implementation(𝒽₀)]

    # Create the model
    m = create_model(caseᵣₕ, modelᵣₕ, m; check_timeprofiles, check_any_data = false)
    set_optimizer_attribute(m, MOI.Silent(), true)

    for 𝒽 ∈ ℋ
        @info "Solving for 𝒽: $𝒽"

        # Necessary break as `ParametricOptInterface` requires that the number of operational
        # periods is always the same
        if length(𝒽) < length(𝒯ᵣₕ)
            EMRH.update_results!(results, m, convert_dict, opers_not_impl)
            break
        end

        # Update the conversion dictionary
        opers_opt = collect(𝒯)[indices_optimization(𝒽)]
        opers_impl = collect(𝒯)[indices_implementation(𝒽)]
        opers_not_impl = setdiff(opers_opt, opers_impl)
        convert_dict[:opers] = Dict(zip(𝒯ᵣₕ, opers_opt))

        # Update and solve model
        if !isfirst(𝒽)
            update_model!(m, case, model, 𝒽, lens_dict, update_dict, init_data)
        end
        optimize!(m)

        # Update the results
        # relies on overwriting - saves whole optimization results, not only implementation
        EMRH.update_results!(results, m, convert_dict, opers_impl)

        # get initialization data from nodes
        init_data =
            Dict(n => EMRH.get_init_state(m, nᵣₕ, 𝒯ᵣₕ, 𝒽) for (n, nᵣₕ) ∈ zip(𝒩ⁱⁿⁱᵗ, 𝒩ⁱⁿⁱᵗᵣₕ))
    end

    return results
end

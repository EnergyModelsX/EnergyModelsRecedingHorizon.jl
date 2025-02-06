
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
    𝒩 = get_nodes(𝒳ᵛᵉᶜ)
    𝒫 = get_products(case)
    ℋ = case.misc[:horizons]

    # Create the `UpdateCase` based on the original `Case` structure
    𝒰 = _create_updatetype(model)
    _add_elements!(𝒰, 𝒫)
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        _add_elements!(𝒰, 𝒳)
    end

    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    𝒾ⁱⁿⁱᵗ = collect(findfirst(map(is_init_data, node_data(n))) for n ∈ 𝒩ⁱⁿⁱᵗ) # index of init_data in nodes: depends on init data being unique
    init_data₀ = map((n, i) -> node_data(n)[i], 𝒩ⁱⁿⁱᵗ, 𝒾ⁱⁿⁱᵗ)

    # Initialize loop variables
    results = Dict{Symbol,AbstractDataFrame}()
    init_data = copy(init_data₀)

    # Iterate through the different horizons and solve the problem
    for 𝒽 ∈ ℋ
        @info "Solving for 𝒽: $𝒽"

        # Create the case description of the receding horizon model
        caseᵣₕ, modelᵣₕ, 𝒰 =
            get_rh_case_model(case, 𝒰, 𝒽, init_data)
        𝒯ᵣₕ = get_time_struct(caseᵣₕ)
        𝒩ᵣₕ = get_nodes(caseᵣₕ)
        𝒩ⁱⁿⁱᵗᵣₕ = filter(has_init, 𝒩ᵣₕ)
        opers_impl = collect(𝒯)[indices_implementation(𝒽)]

        # Create and solve model
        m = create_model(caseᵣₕ, modelᵣₕ; check_timeprofiles)
        set_optimizer(m, optimizer)
        set_optimizer_attribute(m, MOI.Silent(), true)
        optimize!(m)

        # Update the results
        update_results!(results, m, 𝒰, opers_impl)

        # get initialization data from nodes
        init_data = [get_init_state(m, n, 𝒯ᵣₕ, 𝒽) for n ∈ 𝒩ⁱⁿⁱᵗᵣₕ]
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

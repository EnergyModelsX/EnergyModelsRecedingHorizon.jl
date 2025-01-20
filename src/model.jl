
"""
    run_model_rh(case, model, optimizer; check_timeprofiles::Bool=true)

Take the variables `case` and `model` and optimize the problem in a receding horizon fashion
as a series of optimization problems.

`case` is a dictionary that requires the keys:
 - `:nodes::Vector{Node}`
 - `:links::Vector{Link}`
 - `:products::Vector{Resource}`
 - `:T::TimeStructure`
 - `:horizons::AbstractHorizons`

`model` is an instance of `RecHorEnergyModel`.

Returns `results` as a dictionary indexed by the model variables.
"""
function run_model_rh(
    case::Dict, model::RecHorEnergyModel, optimizer; check_timeprofiles::Bool = true,
)
    # TODO: dispatch over `EMB.run_model` in future releases

    # WIP Data structure
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    ℒ = case[:links]
    # 𝒫 = case[:products]
    ℋ = case[:horizons]

    lens_dict = Dict{Symbol, Dict}()
    lens_dict[:nodes] = _create_lens_dict_oper_prof(𝒩)
    lens_dict[:links] = _create_lens_dict_oper_prof(ℒ)
    lens_dict[:model] = _create_lens_dict_oper_prof(model)

    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    𝒾ⁱⁿⁱᵗ = collect(findfirst(map(is_init_data, node_data(n))) for n ∈ 𝒩ⁱⁿⁱᵗ) # index of init_data in nodes: depends on init data being unique
    init_data₀ = map((n, i) -> node_data(n)[i], 𝒩ⁱⁿⁱᵗ, 𝒾ⁱⁿⁱᵗ)

    # initializing loop variables
    results = Dict{Symbol,AbstractArray{Float64}}()
    init_data = copy(init_data₀)

    for 𝒽 ∈ ℋ
        @info "Solving for 𝒽: $𝒽"

        case_rh, model_rh = get_rh_case_model(case, model, 𝒽, lens_dict, init_data)

        𝒯_rh = case_rh[:T]
        𝒩_rh = case_rh[:nodes]
        𝒩ⁱⁿⁱᵗ_rh = filter(has_init, 𝒩_rh)

        # create and solve model
        m = create_model(case_rh, model_rh; check_timeprofiles)
        if !isnothing(optimizer)
            set_optimizer(m, optimizer)
            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)
        else
            @warn "No optimizer given"
        end
        update_results!(results, m, case_rh, case, 𝒽)
        # relies on overwriting - saves whole optimization results, not only implementation

        # get initialization data from nodes
        init_data = [get_init_state(m, n, 𝒯_rh, 𝒽) for n ∈ 𝒩ⁱⁿⁱᵗ_rh]
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

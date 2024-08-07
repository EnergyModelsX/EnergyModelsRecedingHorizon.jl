
"""
    run_model_rh(case_model_builder::Function, optimizer; check_timeprofiles::Bool=true)

Take the function `case_model_builder` that returns the tuple (case, model) and optimize the
problem in a receding horizon fashion as a series of optimization problems.

`case_model_builder` should take as input the TimeStructure for which the receding horizon
problem will be defined. If no input is provided, it should return the full problem.

`case` is a dictionary that requires the keys:
 - `:nodes::Vector{Node}`
 - `:links::Vector{Link}`
 - `:products::Vector{Resource}`
 - `:T::TimeStructure`

 `model` is an instance of `RecHorOperationalModel`.

Returns `(results, case, model)`, where `results` is a dictionary indexed by the model
variables, with containers indexed by the elements in `case`. The variables `case` and `model`
refer to the full problem.
"""
function run_model_rh(case_model_builder::Function, optimizer; check_timeprofiles::Bool=true)
    case, model = case_model_builder()

    # WIP Data structure
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    # ℒ = case[:links]
    # 𝒫 = case[:products]

    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    𝒾ⁱⁿⁱᵗ = collect( findfirst(map(is_init_data, node_data(n)))
        for n in 𝒩ⁱⁿⁱᵗ ) # index of init_data in nodes: depends on init data being unique
    init_data₀ = map((n,i)->node_data(n)[i], 𝒩ⁱⁿⁱᵗ,𝒾ⁱⁿⁱᵗ)

    # initializing loop variables
    results = Dict{Symbol, AbstractArray{Float64}}()
    init_data = copy(init_data₀)

    iter_𝒯 = collect(chunk(𝒯, opt_horizon(model)))[1:impl_horizon(model):end]
    # there is probably a more efficient constructor to the iterator
    for (idx,iter_𝒯ᴿᴴ) ∈ enumerate(iter_𝒯)
        𝒯ᴿᴴₒᵤₜ = collect(iter_𝒯ᴿᴴ)

        case_RH, model_RH = case_model_builder(𝒯ᴿᴴₒᵤₜ)

        𝒯_RH = case_RH[:T]
        𝒩_RH = case_RH[:nodes]

        𝒩ⁱⁿⁱᵗ_RH = filter(has_init, 𝒩_RH)
        # place initialization data in nodes
        for (n,i,init_dataₙ) ∈ zip(𝒩ⁱⁿⁱᵗ_RH,𝒾ⁱⁿⁱᵗ,init_data)
            node_data(n)[i] = init_dataₙ
        end

        # create and solve model
        m = create_model(case_RH, model_RH; check_timeprofiles)
        if !isnothing(optimizer)
            set_optimizer(m, optimizer)
            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)
        else
            @warn "No optimizer given"
        end
        update_results!(results, m, case_RH, case, 𝒯ᴿᴴₒᵤₜ)

        # get initialization data from nodes
        t_impl = collect(𝒯_RH)[impl_horizon(model)]
        init_data = [get_init_state(m, n, 𝒯_RH, t_impl) for n ∈ 𝒩ⁱⁿⁱᵗ_RH]

    end

    return results, case, model
end

"""Abstract type for receding horizon models"""
abstract type RecHorEnergyModel <: EnergyModel end

"""
Operational Energy Model without investments, receding horizon implementation.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** is a dictionary with \
individual emission limits as `TimeProfile` for each emission resource `ResourceEmit`.\n
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the prices for the \
different emissions types considered.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO₂.\n
- **`opt_horizon`** corresponds to the horizon for which the problem will be optimized \
at each iteration.\n
- **`impl_horizon`** corresponds to the horizon for which each solution will be implemented \
at each iteration.\n
"""
struct RecHorOperationalModel <: RecHorEnergyModel
    emission_limit::Dict{<:ResourceEmit, <:TimeProfile}
    emission_price::Dict{<:ResourceEmit, <:TimeProfile}
    co2_instance::ResourceEmit
    opt_horizon::Integer
    impl_horizon::Integer
end
opt_horizon(model::RecHorEnergyModel) = model.opt_horizon
impl_horizon(model::RecHorEnergyModel) = model.impl_horizon

function update_objective(m, cost_to_go)
    # println("in emrh.objective with obj.func: $(objective_function(m))")
    original_objective = objective_function(m) #this is a JuMP function
    new_objective = @expression(m, original_objective + cost_to_go) #JuMP function/macro
    set_objective_function(m, new_objective) #this is a JuMP function
    m_obj = objective_function(m) #this is a JuMP function
    # println("objective_function is now: $(objective_function(m))")
end

#= function EMB.run_model(case::Dict, model::EnergyModel, optimizer; check_timeprofiles=true)
    throw MethodError(2, "This method should is not used in EMRH")
end =#

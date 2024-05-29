"""
This file should contain the core code of the receding horizon framework.

Original idea: Create an objective function which overloads the default from EMB for AbstractInvestmentModel. The objective function should contain an additional term, cost_to_go(some_input).

What is implemented: an update_objective function. The standard objective is first created, and then the objective function is updated with the cost to go. 
NB: The case study can NOT use EMB.run_model() (so I tried to overwrite EMB.run:model to throw an error), but we need to do:
cost_to_go = some_function
m = emrh.create_model(case, model; check_timeprofiles)
emrh.update_objective(m, cost_to_go)
jp.set_optimizer(m, optimizer)
jp.set_optimizer_attribute(m, jp.MOI.Silent(), true)
jp.optimize!(m)
"""
#= function EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)

    #use objective function in EMB.objective
    EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype)

    #= println("in emrh.objective with obj.func: $(objective_function(m))")

    original_objective = objective_function(m) #this is a JuMP function
    new_objective = @expression(m, original_objective + 600) #JuMP function/macro
    set_objective_function(m, new_objective) #this is a JuMP function
    m_obj = objective_function(m) #this is a JuMP function
    println("objective_function is now: $(objective_function(m))")
 =#
end =#

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

# function initialize_states(case, m, x0)
    # t0 = first(case[:T])
    # 𝒩 = case[:nodes]
    # 𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    # # m[:stor_level][:,collect(t0)]
    # for n ∈ 𝒩ˢᵗᵒʳ
    #     # @constraint(m, init_level, x0 <= m[:stor_level][n,t0] <= x0)
    #     @constraint(m, init_level, x0 <= m[:stor_level][n, t0] - m[:stor_level_Δ_op][n, t0] * duration(t0) <= x0)
    # end
# end

# function constraints_level(m, n::Storage, 𝒯, 𝒫, modeltype::EnergyModel)
#     EMB.constraints_level(m, n, 𝒯, 𝒫, modeltype)
#     println("called")
# end
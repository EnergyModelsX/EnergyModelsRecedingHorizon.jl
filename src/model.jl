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

"""General model type for receding horizon problems"""
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

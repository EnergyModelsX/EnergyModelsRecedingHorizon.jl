using Pkg

# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
# Pkg.activate(@__DIR__)
# Install the dependencies.
Pkg.activate("test")

using HiGHS
using PrettyTables
import JuMP as JP
import EnergyModelsBase as EMB
import TimeStruct as TS
# using EnergyModelsBase
# using TimeStruct
import EnergyModelsRecHorizon as EMRH

silent_flag = true

function cost_to_go_func(opt_vars_input::Vector{JP.VariableRef})
    
    #Any of these cost-to-go functions work
    # cost_to_go = zeros(1, length(opt_vars_input))*opt_vars_input
    cost_to_go = ones(1, length(opt_vars_input))*opt_vars_input    

    return cost_to_go[1] #there is probably a more elegant way of converting a 1-element Vector into a number instead of using [1] (so that the number can be used in the objective function of the optimization problem)
end

function create_case(op_number, demand_profile, price_profile; case_config = "standard", init_state = 0)
    #Define resources with their emission intensities
    power = EMB.ResourceCarrier("power", 0.0)  #tCO2/MWh
    co2 = EMB.ResourceEmit("co2", 1.0) #tCO2/MWh
    products = [power, co2]

    #define time structure
    op_duration = 2 # duration of each operational period
    operational_periods = TS.SimpleTimes(op_number, op_duration)

    #number of operational periods within one strategic period
    op_per_strat = op_duration*op_number
    @assert op_per_strat == sum(operational_periods.duration)

    if true
        #create time structure
        T = TS.TwoLevel(1, #number of strategic periods
        1, #duration of strategic period
        operational_periods; #operational period
        op_per_strat)

        T2 = TS.TwoLevel([operational_periods, operational_periods])
    else 
        #purely operational period. However, this does not work for some reason (check_timeprofiles fails)
        T = TS.SimpleTimes(op_number, op_duration)
    end

    #define the model
    model = EMB.OperationalModel(
        Dict(co2 => TS.FixedProfile(10)), #upper bound for CO2 in t/8h
        Dict(co2 => TS.FixedProfile(0)), # emission price for CO2 in EUR/t
        co2    
    )

    #create individual nodes of the system
    nodes = [
        EMB.GenAvailability("Availability", products),
        EMB.RefSource(
            "electricity source", #Node id or name
            TS.FixedProfile(1e12), #Capacity in MW (Time profile)
            TS.OperationalProfile(price_profile), #variable OPEX (time structure) in EUR/MW
            TS.FixedProfile(0), #Fixed OPEN in EUR/8h
            Dict(power => 1), #output from the node 
        ),
        EMB.RefStorage{EMRH.RefAccumulating}(
            "electricity storage",
            EMB.StorCapOpexVar(TS.FixedProfile(100), TS.FixedProfile(100)), # rate_cap, opex_var
            EMRH.StorCapOpexFixed(TS.FixedProfile(10), TS.FixedProfile(100)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                EMRH.InitData(init_state), 
                EMB.EmptyData() # testing multiple data
            ])
        ),
        EMB.RefSink(
            "electricity demand", #node ID or name
            TS.OperationalProfile(demand_profile), #demand in MW (time profile)
            # OperationalProfile([20, 30, 40, 30]), #demand in MW (time profile)
            Dict(:surplus => TS.FixedProfile(0), :deficit => TS.FixedProfile(1e6)), #surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1), #energy demand and corresponding ratio
        ),
    ]

    #connect the nodes with links
    links = [
        EMB.Direct("av-source",   nodes[1], nodes[2], EMB.Linear() ),
        EMB.Direct("av-storage",  nodes[1], nodes[3], EMB.Linear() ),
        EMB.Direct("av-demand",   nodes[1], nodes[4], EMB.Linear() ),
        EMB.Direct("source-av",   nodes[2], nodes[1], EMB.Linear() ),
        EMB.Direct("storage-av",  nodes[3], nodes[1], EMB.Linear() ),
        EMB.Direct("demand-av",   nodes[4], nodes[1], EMB.Linear() ),
    ]

    #WIP(?) data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T
    )

    check_timeprofiles=true
    m = EMB.create_model(case, model; check_timeprofiles)
    JP.@expression(m, cost_RH, -0*sum((m[:stor_level]))) # TODO: incentive to stay at given level? Quadratic problem?
    # cost_RH = -100*sum((m[:stor_level]-2.5)) 

    #Can choose different ways of running the case study. 
    if case_config == "cost_to_go_scalar" #we simply add a scalar to the cost function (the scalar is the cost to go)
        
        cost_to_go = 0 #this should obviously be changed - it should be a function taking some input (e.g. storage capacity at the end of the operational period)
        cost_RH += cost_to_go

    elseif case_config == "cost_to_go_func" # does not work for storage

        #optimization variable at the end of the operating period
        vars_ref_emb = case[:nodes]
        opt_vars_input = [m[:cap_use][vars_ref_emb[i],end] for i=1:length(vars_ref_emb)] 

        cost_to_go = cost_to_go_func(opt_vars_input)
        cost_RH += cost_to_go

        EMRH.update_objective(m, cost_to_go)
    elseif case_config == "standard" #No cost-to-go: it is as in standard EMB
        nothing
    else
        throw(MethodError(case_config, "Not implemented"))
    end

    EMRH.update_objective(m, cost_RH)

    return case, nodes, m
end

#Check if we get the same solution by running i) the standard implementation already existing in EMB (i.e. we consider the full time-horizon in one optimization problem) and ii) the receding horizon implementation

optimizer = JP.optimizer_with_attributes(HiGHS.Optimizer, JP.MOI.Silent() => silent_flag)

#all-in-one
op_number = 8
demand_profile = [20, 30, 40, 30, 10, 50, 35, 20]
price_profile = [10, 10, 10, 10, 1000, 1000, 1000, 1000]
x0 = 5
@assert length(demand_profile) == op_number
@assert length(price_profile) == op_number
case, nodes, m = create_case(op_number, demand_profile, price_profile, init_state=x0)
JP.set_optimizer(m, optimizer)
JP.set_optimizer_attribute(m, JP.MOI.Silent(), silent_flag)
JP.optimize!(m)
av, source, stor, sink = case[:nodes]
power, co2 = case[:products]
solution_full_problem = JP.value.(m[:cap_use][source,:]).data
out_full_problem = JP.value.(m[:flow_in][sink, :, power]).data.vals
stor_full_problem = JP.value.(m[:stor_level][stor,:]).data
cost_full_problem = JP.objective_value(m)

original_objective = JP.objective_function(m)
println("Original objective is: \n$original_objective \n\n")

#receding horizon
println("Receding horizon implementation")
n_hor = 2
init_level_vec = zeros(op_number)
init_level_vec[1] = x0
out_rec_horizon = zeros(op_number) #store the solution of the receding horizon implementation here
stor_rec_horizon = zeros(op_number) #store the solution of the receding horizon implementation here
sol_rec_horizon = zeros(op_number) #store the solution of the receding horizon implementation here
cost_rec_horizon = zeros(op_number) #store the solution of the receding horizon implementation here
for i = 1:(op_number-n_hor+1)
    demand_hor = demand_profile[i:i+n_hor-1]
    price_hor = price_profile[i:i+n_hor-1]
    # case_i, nodes_i, m_i = create_case(n_hor, demand_hor, price_hor, case_config = "cost_to_go_func", init_state=init_level_vec[i])
    case_i, nodes_i, m_i = create_case(n_hor, demand_hor, price_hor, case_config = "cost_to_go_scalar", init_state=init_level_vec[i])
    JP.set_optimizer(m_i, optimizer)
    JP.set_optimizer_attribute(m_i, JP.MOI.Silent(), silent_flag)
    JP.optimize!(m_i)
    av_i, source_i, stor_i, sink_i = case_i[:nodes]
    power_i, co2_i = case_i[:products]
    sol_rec_horizon[i:i+n_hor-1] = JP.value.(m_i[:cap_use][source_i,:]).data
    stor_rec_horizon[i:i+n_hor-1] = JP.value.(m_i[:stor_level][stor_i,:]).data
    out_rec_horizon[i:i+n_hor-1] = JP.value.(m_i[:flow_in][sink_i, :, power_i]).data.vals
    cost_rec_horizon[i] = JP.objective_value(m_i)

    init_level_vec[i+1] = JP.value.(m_i[:stor_level][stor_i,first(case_i[:T])])
    ctg_objective = JP.objective_function(m_i)
    if i == 1
        println(ctg_objective)
    end
end # TODO: include final state as initial to next

# @assert solution_full_problem == sol_rec_horizon
println("\n\nReceding horizon source usage: $sol_rec_horizon")
println("\nOriginal problem source usage: $solution_full_problem")

println("\n\nReceding horizon demand delivery: $out_rec_horizon")
println("\nOriginal problem demand delivery: $out_full_problem")

println("\n\nReceding horizon storage level: $stor_rec_horizon")
println("\nOriginal problem storage level: $stor_full_problem")
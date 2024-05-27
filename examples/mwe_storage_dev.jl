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

function create_case(op_number, demand_profile; case_config = "standard")
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
        EMB.RefSource(
            "electricity source", #Node id or name
            TS.FixedProfile(1e12), #Capacity in MW (Time profile)
            TS.FixedProfile(30), #variable OPEX (time structure) in EUR/MW
            TS.FixedProfile(0), #Fixed OPEN in EUR/8h
            Dict(power => 1), #output from the node 
        ),
        EMB.RefSink(
            "electricity demand", #node ID or name
            TS.OperationalProfile(demand_profile), #demand in MW (time profile)
            # OperationalProfile([20, 30, 40, 30]), #demand in MW (time profile)
            Dict(:surplus => TS.FixedProfile(0), :deficit => TS.FixedProfile(1e6)), #surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1), #energy demand and corresponding ratio
        )
    ]

    #connect the nodes with links
    links = [EMB.Direct(
        "source-demand",
        nodes[1],
        nodes[2],
        EMB.Linear()
    )]

    #WIP(?) data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T
    )

    #Can choose different ways of running the case study. 
    if case_config == "cost_to_go_scalar" #we simply add a scalar to the cost function (the scalar is the cost to go)
        check_timeprofiles=true

        cost_to_go = 1 #this should obviously be changed - it should be a function taking some input (e.g. storage capacity at the end of the operational period)
        m = EMB.create_model(case, model; check_timeprofiles)
        EMRH.update_objective(m, cost_to_go)

    elseif case_config == "cost_to_go_func" #use the defined cost_to_go_func
        check_timeprofiles=true
        m = EMB.create_model(case, model; check_timeprofiles)

        #optimization variable at the end of the operating period
        vars_ref_emb = case[:nodes]
        opt_vars_input = [m[:cap_use][vars_ref_emb[i],end] for i=1:length(vars_ref_emb)] 

        cost_to_go = cost_to_go_func(opt_vars_input)

        EMRH.update_objective(m, cost_to_go)
    elseif case_config == "standard" #No cost-to-go: it is as in standard EMB
        m = EMB.create_model(case, model)
    else
        throw(MethodError(case_config, "Not implemented"))
    end

    return case, nodes, m
end

#Check if we get the same solution by running i) the standard implementation already existing in EMB (i.e. we consider the full time-horizon in one optimization problem) and ii) the receding horizon implementation

optimizer = JP.optimizer_with_attributes(HiGHS.Optimizer, JP.MOI.Silent() => silent_flag)

#all-in-one
op_number = 8
demand_profile = [20, 30, 40, 30, 10, 50, 35, 20]
@assert length(demand_profile) == op_number
case, nodes, m = create_case(op_number, demand_profile)
JP.set_optimizer(m, optimizer)
JP.set_optimizer_attribute(m, JP.MOI.Silent(), silent_flag)
JP.optimize!(m)
source, sink = case[:nodes]
solution_full_problem = JP.value.(m[:cap_use][source,:]).data
cost_full_problem = JP.objective_value(m)

original_objective = JP.objective_function(m)
println("Original objective is: $original_objective \n\n")

#receding horizon
println("Receding horizon implementation")
n_hor = 2
sol_rec_horizon = zeros(op_number) #store the solution of the receding horizon implementation here
cost_rec_horizon = zeros(op_number) #store the solution of the receding horizon implementation here
for i = 1:(op_number-n_hor+1)
    demand_hor = demand_profile[i:i+n_hor-1]
    # case_i, nodes_i, m_i = create_case(n_hor, demand_hor, case_config = "cost_to_go_func")
    case_i, nodes_i, m_i = create_case(n_hor, demand_hor, case_config = "cost_to_go_scalar")
    JP.set_optimizer(m_i, optimizer)
    JP.set_optimizer_attribute(m_i, JP.MOI.Silent(), silent_flag)
    JP.optimize!(m_i)
    source_i, sink_i = case_i[:nodes]
    sol_rec_horizon[i:i+n_hor-1] = JP.value.(m_i[:cap_use][source_i,:]).data
    cost_rec_horizon[i] = JP.objective_value(m_i)

    ctg_objective = JP.objective_function(m_i)
    if i == 1
        println(ctg_objective)
    end
end

@assert solution_full_problem == sol_rec_horizon
println("\n\nReceding horizon and original problem have same solution: $sol_rec_horizon")
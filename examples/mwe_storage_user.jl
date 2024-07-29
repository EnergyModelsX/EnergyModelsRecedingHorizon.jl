using Pkg

Pkg.activate("test") # to use solvers (HiGHS, Ipopt, ...)

using HiGHS
# using Ipopt
using PrettyTables
using JuMP
using EnergyModelsBase
using TimeStruct
using EnergyModelsRecHorizon
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true) # , "tol" => 1.0e-10

op_number = 8
op_duration = 2 # duration of each operational period
demand_profile_full = [20, 30, 40, 30, 10, 50, 35, 20]
price_profile_full = [10, 10, 10, 10, 1000, 1000, 1000, 1000]
@assert length(demand_profile_full) == op_number
@assert length(price_profile_full) == op_number

# https://sintefore.github.io/TimeStruct.jl/stable/manual/basic/

function create_case(t_RH = nothing; init_state = 0)
    #Define resources with their emission intensities
    power = ResourceCarrier("power", 0.0)  #tCO2/MWh
    co2 = ResourceEmit("co2", 1.0) #tCO2/MWh
    products = [power, co2]

    #define time structure
    T = TwoLevel(1, 1, SimpleTimes(op_number, op_duration))

    #define the model depending on input

    if isnothing(t_RH)
        price_profile = price_profile_full
        demand_profile = demand_profile_full
        model = RecHorOperationalModel(
            Dict(co2 => FixedProfile(10)), #upper bound for CO2 in t/8h
            Dict(co2 => FixedProfile(0)), # emission price for CO2 in EUR/t
            co2,
            4,  # optimization horizon
            1   # implementation horizon
        )
    else
        price_profile = OperationalProfile(price_profile_full)[t_RH]
        demand_profile = OperationalProfile(demand_profile_full)[t_RH]
        model = OperationalModel(
            Dict(co2 => FixedProfile(10)), #upper bound for CO2 in t/8h
            Dict(co2 => FixedProfile(0)), # emission price for CO2 in EUR/t
            co2
        )
    end

    #create individual nodes of the system
    nodes = [
        GenAvailability("Availability", products),
        RefSource(
            "electricity source", #Node id or name
            FixedProfile(1e12), #Capacity in MW (Time profile)
            OperationalProfile(price_profile), #variable OPEX (time structure) in EUR/MW
            FixedProfile(0), #Fixed OPEN in EUR/8h
            Dict(power => 1), #output from the node
        ),
        RefStorage{RefAccumulating}(
            "electricity storage",
            StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                InitData(init_state),
                EmptyData() # testing multiple data
            ])
        ),
        RefSink(
            "electricity demand", #node ID or name
            OperationalProfile(demand_profile), #demand in MW (time profile)
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)), #surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1), #energy demand and corresponding ratio
        ),
    ]

    #connect the nodes with links
    links = [
        Direct("av-source",   nodes[1], nodes[2], Linear() ),
        Direct("av-storage",  nodes[1], nodes[3], Linear() ),
        Direct("av-demand",   nodes[1], nodes[4], Linear() ),
        Direct("source-av",   nodes[2], nodes[1], Linear() ),
        Direct("storage-av",  nodes[3], nodes[1], Linear() ),
        Direct("demand-av",   nodes[4], nodes[1], Linear() ),
    ]

    #WIP(?) data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => isnothing(t_RH) ? T : TwoLevel(1, 1, SimpleTimes([duration(t) for t in t_RH]))
    )

    return case, model
end

x0 = 3
case, model = create_case(init_state=x0)
m = create_model(case, model)
set_optimizer(m, optimizer)
optimize!(m)

av, source, stor, sink = case[:nodes]
power, co2 = case[:products]
solution_full_problem = value.(m[:cap_use][source,:]).data
out_full_problem = value.(m[:flow_in][sink, :, power]).data.vals
stor_full_problem = value.(m[:stor_level][stor,:]).data
cost_full_problem = objective_value(m)

m_RH = run_model_RH((x=nothing)->create_case(x,init_state=x0), optimizer)

# x0 = 5
# set_optimizer(m, optimizer)
# optimize!(m)

# av, source, stor, sink = case[:nodes]
# power, co2 = case[:products]
# solution_modif_problem = value.(m[:cap_use][source,:]).data
# out_modif_problem = value.(m[:flow_in][sink, :, power]).data.vals
# stor_modif_problem = value.(m[:stor_level][stor,:]).data
# cost_modif_problem = objective_value(m)

# # println("\n\nReceding horizon source usage: $sol_rec_horizon")
println("\nOriginal problem source usage: $solution_full_problem")
# println("\nModified problem source usage: $solution_modif_problem")

# # println("\n\nReceding horizon demand delivery: $out_rec_horizon")
println("\nOriginal problem demand delivery: $out_full_problem")
# println("\nModified problem demand delivery: $out_modif_problem")

# # println("\n\nReceding horizon storage level: $stor_rec_horizon")
println("\nOriginal problem storage level: $stor_full_problem")
# println("\nModified problem storage level: $stor_modif_problem")

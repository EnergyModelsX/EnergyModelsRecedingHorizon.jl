using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

using HiGHS
# using Ipopt
using JuMP
using EnergyModelsBase
using TimeStruct
using EnergyModelsRecHorizon

const EMRH = EnergyModelsRecHorizon


op_dur_vec = [1, 2, 1, 4, 1, 3, 1, 3]
demand_profile_full = [20, 30, 40, 30, 10, 50, 35, 20]
price_profile_full = [10, 10, 10, 10, 1000, 1000, 1000, 1000]

# https://sintefore.github.io/TimeStruct.jl/stable/manual/basic/

function create_case(; init_state = 0)
    #Define resources with their emission intensities
    power = ResourceCarrier("power", 0.0)  #tCO2/MWh
    co2 = ResourceEmit("co2", 1.0) #tCO2/MWh
    𝒫 = [power, co2]

    #define time structure
    𝒯 = TwoLevel(1, 1, SimpleTimes(op_dur_vec))
    ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], 8, 4) # optimization and implementation horizons

    #define the model depending on input

    price_profile = price_profile_full
    demand_profile = demand_profile_full

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)), #upper bound for CO2 in t/8h
        Dict(co2 => FixedProfile(0)), # emission price for CO2 in EUR/t
        co2,
    )

    #create individual nodes of the system
    𝒩 = [
        GenAvailability("Availability", 𝒫),
        RefSource(
            "electricity source", #Node id or name
            FixedProfile(1e12), #Capacity in MW (Time profile)
            OperationalProfile(price_profile), #variable OPEX (time structure) in EUR/MW
            FixedProfile(0), #Fixed OPEN in EUR/8h
            Dict(power => 1), #output from the node
        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage",
            StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                StorageInitData(init_state),
                EmptyData() # testing multiple data
            ]),
        ),
        RefSink(
            "electricity demand", #node ID or name
            OperationalProfile(demand_profile), #demand in MW (time profile)
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)), #surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1), #energy demand and corresponding ratio
        ),
    ]

    #connect the nodes with links
    ℒ = [
        Direct("av-storage", 𝒩[1], 𝒩[3], Linear()),
        Direct("av-demand", 𝒩[1], 𝒩[4], Linear()),
        Direct("source-av", 𝒩[2], 𝒩[1], Linear()),
        Direct("storage-av", 𝒩[3], 𝒩[1], Linear()),
    ]

    # Data Structure
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]], Dict(:horizons => ℋ))

    return case, model
end

x0 = 5
case, model = create_case(init_state = x0)
m = create_model(case, model)
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true) # , "tol" => 1.0e-10
set_optimizer(m, optimizer)
optimize!(m)

av, source, stor, sink = get_nodes(case)
power, co2 = get_products(case)

results_full = EMRH.get_results_df(m)
solution_full_problem = filter(r -> r.x1 == source, results_full[:cap_use])
out_full_problem = filter(r -> r.x1 == sink && r.x3 == power, results_full[:flow_in])
stor_full_problem = filter(r -> r.x1 == stor, results_full[:stor_level])
cost_full_problem = objective_value(m)

results_EMRH = run_model_rh(case, model, optimizer)

# av, source, stor, sink = case_EMRH[:nodes]
# power, co2 = case_EMRH[:products]

solution_rec_horizon = filter(r -> r.x1 == source, results_EMRH[:cap_use])
out_rec_horizon = filter(r -> r.x1 == sink && r.x3 == power, results_EMRH[:flow_in])
stor_rec_horizon = filter(r -> r.x1 == stor, results_EMRH[:stor_level])

println("\n\nReceding horizon source usage: $solution_rec_horizon")
println("\nOriginal problem source usage: $solution_full_problem")
# println("\nModified problem source usage: $solution_modif_problem")

println("\n\nReceding horizon demand delivery: $out_rec_horizon")
println("\nOriginal problem demand delivery: $out_full_problem")
# println("\nModified problem demand delivery: $out_modif_problem")

println("\n\nReceding horizon storage level: $stor_rec_horizon")
println("\nOriginal problem storage level: $stor_full_problem")
# println("\nModified problem storage level: $stor_modif_problem")

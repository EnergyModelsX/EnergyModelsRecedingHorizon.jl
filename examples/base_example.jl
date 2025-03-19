using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using HiGHS
using JuMP
using EnergyModelsBase
using TimeStruct
using EnergyModelsRecedingHorizon
using DataFrames
using PrettyTables

const EMRH = EnergyModelsRecedingHorizon

"""
    create_case_base_ex(; init_state = 0)

Returns the pair `case, model` for the simple example based on EMB nodes.

This example illustrates the use of EnergyModelsRecedingHorizon for the reference nodes
provided in EnergyModelsBase.
"""
function create_case_base_ex(; init_state = 0)
    @info "Generate case data - Simple receding horizon example"

    # Define the different resources and their emission intensity in t CO₂/MWh
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [power, co2]

    # Variables for the individual entries of the time structure
    op_dur_vec = [1, 2, 1, 4, 1, 3, 1, 3]           # duration of operational periods (in hours)
    𝒯 = TwoLevel(1, 1, SimpleTimes(op_dur_vec))
    # Here, no input is provided for `op_per_strat`, which means that variables referring to
    # strategic periods are also calculated in hours.

    # Variables for the individual entries of the horizon structure
    optim_hor = 8                                   # optimization horizon (in hours)
    impl_hor = 4                                    # implementation horizon (in hours)
    ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], optim_hor, impl_hor)

    # Creation of the model type with global data
    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),              # Emission cap for CO₂ in t/h
        Dict(co2 => FixedProfile(0)),               # Emission price for CO₂ in €/t
        co2,                                        # CO₂ instance
    )

    # Values of operational profiles
    demand_profile = [20, 30, 40, 30, 10, 50, 35, 20]           # demand profile (MW)
    price_profile = [10, 10, 10, 10, 1000, 1000, 1000, 1000]    # electricity price at source (€/MWh)

    # Create nodes of the system
    𝒩 = [
        GenAvailability("Availability", 𝒫),
        RefSource(
            "electricity source",                   # Source id
            FixedProfile(1e5),                      # Capacity in MW (here, approx. infinite)
            OperationalProfile(price_profile),      # Variable OPEX in €/MWh
            FixedProfile(0),                        # Fixed OPEX in €/MW/h
            Dict(power => 1),                       # Output from the node
        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage",                  # Storage id
            StorCapOpexVar(
                FixedProfile(100),                  # Charging capacity (MW)
                FixedProfile(100),                  # Charging variable OPEX (€/MW)
            ),
            StorCap(
                FixedProfile(10),                   # Storage capacity (MWh)
            ),
            power,                                  # Stored resource
            Dict(power => 1),                       # Input resource with input ratio
            Dict(power => 1),                       # Output resource with output ratio
            Vector([
                StorageInitData(init_state),        # Initial state of charge
                EmptyData(),                        # Additional data may be provided
            ]),
        ),
        RefSink(
            "electricity demand",                   # Sink id
            OperationalProfile(demand_profile),     # Varying demand (MW)
            Dict(
                :surplus => FixedProfile(0),        # Surplus penalty (€/MWh)
                :deficit => FixedProfile(1e5),      # Deficit penalty (€/MWh)
            ),
            Dict(power => 1),                       # Energy demand and corresponding ratio
        ),
    ]

    # Connect the nodes with links
    ℒ = [
        Direct("av-storage", 𝒩[1], 𝒩[3], Linear()),
        Direct("av-demand", 𝒩[1], 𝒩[4], Linear()),
        Direct("source-av", 𝒩[2], 𝒩[1], Linear()),
        Direct("storage-av", 𝒩[3], 𝒩[1], Linear()),
    ]

    # Create case instance
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]], Dict(:horizons => ℋ))

    return case, model
end

# Instance case and model type
x0 = 5
case, model = create_case_base_ex(init_state = x0)

## RUN MODELS

# - EnergyModelsBase
# Create and solve JuMP model
m = create_model(case, model)
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
set_optimizer(m, optimizer)
optimize!(m)

# Convert EMB output to DataFrame
results_full = EMRH.get_results_df(m)

# - EnergyModelsRecedingHorizon
# Call EMRH solver
res_emrh = run_model_rh(case, model, optimizer)

## COMPARE RESULTS
"""
    process_base_results(res_full, res_emrh, res_emrhʷᵒ, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_base_results(res_emb, res_emrh)

    # Get nodes and resources - used as indexes
    av, source, stor, sink = get_nodes(case)
    power, co2 = get_products(case)

    # Extract the data from the full results
    solution_emb = filter(r -> r.x1 == source, res_emb[:cap_use])
    out_emb = filter(r -> r.x1 == sink && r.x3 == power, res_emb[:flow_in])
    stor_emb = filter(r -> r.x1 == stor, res_emb[:stor_level])

    # Extract the data from the receding horizon
    solution_emrh = filter(r -> r.x1 == source, res_emrh[:cap_use])
    out_emrh = filter(r -> r.x1 == sink && r.x3 == power, res_emrh[:flow_in])
    stor_emrh = filter(r -> r.x1 == stor, res_emrh[:stor_level])

    # Combine both into single dataframes
    solution = innerjoin(solution_emb, solution_emrh, on = [:x1, :x2]; makeunique=true)
    select!(solution, :x2 => (x -> repr.(x)) => :Period, :y => :full, :y_1 => :RH)
    out = innerjoin(out_emb, out_emrh, on = [:x1, :x2]; makeunique=true)
    select!(out, :x2 => (x -> repr.(x)) => :Period, :y => :full, :y_1 => :RH)
    stor = innerjoin(stor_emb, stor_emrh, on = [:x1, :x2]; makeunique=true)
    select!(stor, :x2 => (x -> repr.(x)) => :Period, :y => :full, :y_1 => :RH)

    return solution, out, stor
end

solution, out, stor = process_base_results(results_full, res_emrh)

@info "Source usage:"
pretty_table(solution)

@info "Demand delivery:"
pretty_table(out)

@info "Storage level:"
pretty_table(stor)

@info "Notice that, even though the demand is satisfied for both models, their storage use \
 is different in time."

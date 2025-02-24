using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(joinpath(@__DIR__, "."))
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using HiGHS
using JuMP
using DataFrames
using PrettyTables
using TimeStruct
using EnergyModelsBase
using EnergyModelsRecHorizon

const EMRH = EnergyModelsRecHorizon

"""
    generate_future_value_case(; init_state=0)

Generate the data for an example consisting of a simple electricity network with a storage
node. The market and sell are not connected.
The individual storage value cuts highlight that the system solves to the same result as
it is the case for running the full model.
"""
function generate_future_value_case(; init_state=0)
    @info "Generate case data - Future value calculations"

    # Define the different resources and their emission intensity in tCO2/MWh
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [CO2, Power]

    # Variables for the individual entries of the time structure
    # The operational period is
    dur_op = [1, 2, 1, 4, 1, 3, 1, 3, 1, 2, 1, 4]
    operational_periods = SimpleTimes(dur_op)

    # Creation of the time structure, the horizon, and the global data
    # The horizon consists of 8 h in the optimization horizon of which 4 h are implemented
    T = TwoLevel(1, sum(dur_op), operational_periods)
    ℋ = DurationHorizons([duration(t) for t ∈ T], 8, 4)
    model = RecHorOperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO₂ in t/24h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        CO2,
    )

    #define the model depending on input
    price_profile = [10, 20, 50, 100, 50, 40, 20, 70, 10, 5, 90, 42]

    # Create the individual test nodes, corresponding to a system with an electricity source,
    # electricity demand/sink, and a storage
    src = RefSource(
        "market_buy",           # Node id
        FixedProfile(10),       # Capacity in MW
        OperationalProfile(price_profile.+0.01),    # Variable OPEX in EUR/MW
        FixedProfile(0),        # Fixed OPEX in EUR/MW/24h
        Dict(Power => 1),       # Output from the Node, in this case, electricity
    )
    snk = RefSink(
        "market_sale",          # Node id
        FixedProfile(0),        # Demand in MW
        Dict(
            :surplus => OperationalProfile(-price_profile),
            :deficit => FixedProfile(1000)
        ),
        # Lines above: Surplus and deficit penalties for the node in EUR/MWh
        Dict(Power => 1),       # Energy demand and corresponding ratio
    )
    stor = RefStorage{RecedingAccumulating}(
        "storage",              # Node ID
        StorCap(FixedProfile(10)),  # Charge capacity in MW
        StorCap(FixedProfile(100)), # Storage capacity in MWh
        Power,                  # Stored resource
        Dict(Power => 1),       # Input resource with input ratio
        Dict(Power => 1),       # Output from the node with output ratio
        [StorageInitData(init_state)]   # Initial data in the first operational period
    )

    # Connect all nodes with links
    nodes = [src, snk, stor]
    links = [
        Direct("gen-ocean", src, stor),
        Direct("rsv-gen", stor, snk),
    ]

    future_values = [
        # Cut coefficients and rhs are negated compared to typical hydropower representation
        # since we consider future value and not future cost.
        StorageValueCuts("wv0", 0, 1, 0,
        # Line above: ID, time at which the cuts are valid, their weight, and the time weight
            [
                StorageValueCut(1, Dict(stor => -50), 0),
                StorageValueCut(2, Dict(stor => -40), 250),
                StorageValueCut(3, Dict(stor => -30), 750),
                StorageValueCut(4, Dict(stor => -20), 1400),
                StorageValueCut(5, Dict(stor => -10), 2150),
                StorageValueCut(6, Dict(stor => -5), 2600),
                StorageValueCut(7, Dict(stor => 0), 3100),
            ]
            # Lines above: The individual cuts are for the storage with the given right hand
            # side
        ),
        StorageValueCuts("wv24", 24, 1, 1,
        # Line above: ID, time at which the cuts are valid, their weight, and the time weight
            [
                StorageValueCut(1, Dict(stor => -100), 0),
                StorageValueCut(2, Dict(stor => -80), 500),
                StorageValueCut(3, Dict(stor => -60), 1500),
                StorageValueCut(4, Dict(stor => -40), 2800),
                StorageValueCut(5, Dict(stor => -20), 4300),
                StorageValueCut(6, Dict(stor => -10), 5200),
                StorageValueCut(7, Dict(stor => 0), 6200),
            ]
        )
    ]

    # Input data structure
    case = Case(
        T,
        products,
        [nodes, links, future_values],
        [[get_nodes, get_links], [get_future_value]],
        Dict(:horizons => ℋ)
    )
    return case, model
end


"""
    process_future_value_results(res_full, res_emrh, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_future_value_results(res_full, res_emrh, case)
    # Extract individual values from the case structure
    src, snk, stor = get_nodes(case)

    # Extract the data from the full results
    buy_full = filter(r -> r.x1 == src, res_full[:cap_use])
    sell_full = filter(r -> r.x1 == snk, res_full[:cap_use])
    lvl_full = filter(r -> r.x1 == stor, res_full[:stor_level])

    # Extract the data from the EMRH results
    buy_emrh = filter(r -> r.x1 == src, res_emrh[:cap_use])
    sell_emrh = filter(r -> r.x1 == snk, res_emrh[:cap_use])
    lvl_emrh = filter(r -> r.x1 == stor, res_emrh[:stor_level])

    # Combine both into single dataframes
    buy = innerjoin(buy_full, buy_emrh, on = [:x1, :x2]; makeunique=true)
    select!(buy, :x2 => (x -> repr.(x)) => :Period, :y => :full, :y_1 => :RH)
    sell = innerjoin(sell_full, sell_emrh, on = [:x1, :x2]; makeunique=true)
    select!(sell, :x2 => (x -> repr.(x)) => :Period, :y => :full, :y_1 => :RH)
    lvl = innerjoin(lvl_full, lvl_emrh, on = [:x1, :x2]; makeunique=true)
    select!(lvl, :x2 => (x -> repr.(x)) => :Period, :y => :full, :y_1 => :RH)
    return buy, sell, lvl
end

# Generate the case and model data
case, model = generate_future_value_case(init_state=50)

# Run the model without the receding horizon framework, but with the future value
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)
res_full = EMRH.get_results_df(m)

# Run the model with the receding horizon framework
res_emrh = run_model_rh(case, model, optimizer);

# Extract the individual data frames for the analysis
buy, sell, lvl = process_future_value_results(res_full, res_emrh, case)

@info "The following tables compare both the full and the receding horizon problem. " *
    "The problem is solved 6 times in the receding horizon framework."
@info "Buying from the market"
pretty_table(buy)

@info "Selling to the market"
pretty_table(buy)

@info "Storage level"
pretty_table(lvl)

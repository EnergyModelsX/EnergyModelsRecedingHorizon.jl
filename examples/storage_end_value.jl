using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(joinpath(@__DIR__, "."))
# Use dev version if run as part of tests
#haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
Pkg.develop(path = joinpath(@__DIR__, ".."))
#Pkg.develop(path=joinpath(@__DIR__, "../../energymodelsrechorizon.jl"))
# Install the dependencies.
Pkg.instantiate()

using HiGHS
using JuMP
using EnergyModelsBase
using TimeStruct
using EnergyModelsRecHorizon
using EnergyModelsRenewableProducers

const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecHorizon


optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)


op_dur_vec = [1, 2, 1, 4, 1, 3, 1, 3, 1, 2, 1, 4]
price_profile_full = [10, 20, 50, 100, 50, 40, 20, 70, 10, 5, 90, 42]
#op_dur_vec = [6,6,6,6]
#price_profile_full = [10,2, 80,100]
#demand_profile_full = [20, 30, 40, 30, 10, 50, 35, 20]


function create_future_value_case(; init_state=0)
    #Define resources with their emission intensities
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [CO2, Power]

    #define time structure
    T = TwoLevel(1, 24, SimpleTimes(op_dur_vec))
    #hor = DurationHorizons([duration(t) for t ∈ T], 2, 2)
    hor = DurationHorizons([duration(t) for t ∈ T], 8, 4)# optimization and implementation horizons

    #define the model depending on input

    price_profile = price_profile_full
    #demand_profile = demand_profile_full

    model = RecHorOperationalModel(
        Dict(CO2 => FixedProfile(10)), #upper bound for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)), # emission price for CO2 in EUR/t
        CO2,
    )

    # Create a hydro reservoir
    storage = RefStorage{RecedingAccumulating}(
        "storage",  # Node ID
        StorCap(FixedProfile(10)), # Charge
        StorCap(FixedProfile(100)), # level, UnionCap
        Power,              # stor_res, stored resource
        Dict(Power => 1),
        Dict(Power => 1),
        [
            StorageInitData(init_state)
        ]
    )

    # Create a electricity sale market
    electricity_sale = RefSink(
        "market_sale",
        FixedProfile(0),
        Dict(
            :surplus => OperationalProfile(-price_profile),
            :deficit => FixedProfile(1000)
        ),
        Dict(Power => 1),
        Data[]
    )

    # Create a electricity purchase market
    electricity_buy = RefSource(
        "market_buy",
        FixedProfile(10),
        OperationalProfile(price_profile.+0.01),
        FixedProfile(0),
        Dict(Power => 1),
        Data[]
    )


    #connect the nodes with links
    links = [
        Direct("rsv-gen", storage, electricity_sale),
        Direct("gen-ocean", electricity_buy, storage),
    ]


    future_value = [
        # Cut coefficients and rhs are negated compared to typical hydropower
        # representation since we consider future value and not future cost.
        StorageValueCuts(
            "wv0",
            1,
            0,
            [   #StorageValueCut(1, Dict(storage => -50), 0),
                StorageValueCut(1, Dict(storage => -50), 0),
                StorageValueCut(2, Dict(storage => -40), 250),
                StorageValueCut(3, Dict(storage => -30), 750),
                StorageValueCut(4, Dict(storage => -20), 1400),
                StorageValueCut(5, Dict(storage => -10), 2150),
                StorageValueCut(6, Dict(storage => -5), 2600),
                StorageValueCut(7, Dict(storage => 0), 3100),
            ]
        ),
        StorageValueCuts(
            "wv24",
            1,
            24,
            [   #StorageValueCut(1, Dict(storage => -100), 0),
                StorageValueCut(2, Dict(storage => -80), 500),
                StorageValueCut(3, Dict(storage => -60), 1500),
                StorageValueCut(4, Dict(storage => -40), 2800),
                StorageValueCut(5, Dict(storage => -20), 4300),
                StorageValueCut(6, Dict(storage => -10), 5200),
                StorageValueCut(7, Dict(storage => 0), 6200),
            ]
        )
    ]

        #create individual nodes of the system
        nodes = [storage, electricity_buy, electricity_sale]

    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
        :horizons => hor,
        #:future_value => future_value
    )

        # Data Structure
        case = Case(T, products, [nodes, future_value, links], [[get_nodes, get_links], [get_future_value]], Dict(:horizons => hor))

    return case, model
end


x0 = 50
case, model = create_future_value_case(init_state=x0)

m = create_model(case, model)
set_optimizer(m, optimizer)
optimize!(m)
@test objective_value(m) ≈ 15518.2

storage, electricity_buy, electricity_sale = get_nodes(case)
CO2, Power = get_products(case)

results_full = EMRH.get_results_df(m)
buy_full_problem = filter(r -> r.x1 == electricity_buy, results_full[:cap_use])
sale_full_problem = filter(r -> r.x1 == electricity_sale, results_full[:cap_use])

charge_full_problem = filter(r -> r.x1 == storage && r.x3 == Power, results_full[:flow_in])
discharge_full_problem = filter(r -> r.x1 == storage && r.x3 == Power, results_full[:flow_out])
stor_full_problem = filter(r -> r.x1 == storage, results_full[:stor_level])

cost_full_problem = objective_value(m)

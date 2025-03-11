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
using EnergyModelsGeography
using EnergyModelsRecHorizon

const EMRH = EnergyModelsRecHorizon

"""
    generate_geo_case(; init_state=0)

Generate the data for an example consisting of the transmission of hydrogen from a source
region to a sink region. The chosen transmission mode allows for line packing, and hence,
requires initial data.
"""
function generate_geo_case(; init_state=0)
    @info "Generate case data - Geography example"

    # Define the different resources and their emission intensity in tCO2/MWh
    H2_hp = ResourceCarrier("H2_hp", 0.0)
    H2_lp = ResourceCarrier("H2_lp", 0.0)
    el = ResourceCarrier("Power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [H2_hp, H2_lp, el, co2]

    # Variables for the individual entries of the time structure
    # The 8 operational periods of the full problem have the same length
    operational_periods = SimpleTimes(8, 1)

    # Creation of the time structure, the horizon, and the global data
    # The horizon consists of 4 h in the optimization horizon of which 2 h are implemented
    T = TwoLevel(1, 8, operational_periods)
    ℋ = PeriodHorizons([duration(t) for t ∈ T], 4, 2)
    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),  # Emission cap for CO₂ in t/8h
        Dict(co2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        co2,
    )

    # Define the price profile of the model for the energy supply
    price_profile = [25, 20, 40, 80, 20, 30, 10, 90]

    # Create the individual test nodes, corresponding to a system with a hydrogen source,
    # an electricity source, and a hydrogen demand
    h2_src = RefSource(
        "reg1_h2_src",      # Node id
        FixedProfile(30),   # Capacity in MW
        OperationalProfile(price_profile),      # Variable OPEX in EUR/MW
        FixedProfile(0),    # Fixed OPEX in EUR/MW/8h
        Dict(H2_hp => 1),   # Output from the Node, in this case, high pressure hydrogen
    )
    el_src = RefSource(
        "reg1_el_src",      # Node id
        FixedProfile(3),    # Capacity in MW
        OperationalProfile(price_profile.*1.5), # Variable OPEX in EUR/MW
        FixedProfile(0),    # Fixed OPEX in EUR/MW/8h
        Dict(el => 1),      # Output from the Node, in this case, electricity
    )
    sink = RefSink(
        "reg2_snk",         # Node id
        OperationalProfile([20, 10, 5, 25, 20, 10, 5, 25]), # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(100)),
        # Line above: Surplus and deficit penalties for the node in EUR/MWh
        Dict(H2_lp => 1),   # Energy demand, in this case, low pressure hydrogen
    )


    # Connect all nodes with links
    nodes = [
        GeoAvailability(1, resources), h2_src, el_src,
        GeoAvailability(2, resources), sink
    ]
    links = [
        Direct("reg1_h2-reg1_av", nodes[2], nodes[1], Linear())
        Direct("reg1_el-reg1_av", nodes[3], nodes[1], Linear())
        Direct("reg2_av-reg1_demand", nodes[4], nodes[5], Linear())
    ]

    # Create the single transmission mode, a pipeline with line packing potential
    pipe_lp = PipeLinepackSimple(
        "pipe_linepack",
        H2_hp,
        H2_lp,
        el,
        FixedProfile(0.02),
        FixedProfile(50),
        FixedProfile(0.0),
        FixedProfile(0.0),
        FixedProfile(0.0),
        0.2,
        [TransInitData(Dict(:linepack_stor_level => init_state))],
    )
    modes = [pipe_lp]

    # Creation of the two areas and the corresponding transmission corridor
    areas = [
        RefArea(1, "Region_1", 1, 1, nodes[1]),
        RefArea(2, "Region_2", 2, 2, nodes[4])
    ]
    transmissions = [Transmission(areas[1], areas[2], modes)]

    # Input data structure
    case = Case(
        T,
        resources,
        [nodes, links, areas, transmissions],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
        Dict(:horizons => ℋ)
    )
    return case, model
end


"""
    process_geo_results(res, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_geo_results(res, case)
    # Extract individual values from the case structure
    _, h2_src, _, _, snk = get_nodes(case)
    pipe_lp = modes(get_transmissions(case))[1]

    # Extract the data for the capacity usage
    cap_use_h2_src = filter(r -> r.x1 == h2_src, res[:cap_use])
    cap_use_snk = filter(r -> r.x1 == snk, res[:cap_use])

    # Extract the values for the line packing
    stor_lp = filter(r -> r.x1 == pipe_lp, res[:linepack_stor_level])

    # Combine both into single dataframes
    res_mod = innerjoin(cap_use_h2_src, cap_use_snk, stor_lp, on = [:x2]; makeunique=true)
    select!(res_mod, :x2 => (x -> repr.(x)) => :Period, :y => :source, :y_1 => :sink, :y_2 => :line_pack_level)
    return res_mod
end

# Generate the case and the model data
case,  model = generate_geo_case(init_state=0)

# Run the model
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
res = run_model_rh(case, model, optimizer);

# Extract the individual data frames for the analysis
res_mod = process_geo_results(res, case)

@info "The following table shows the source usage (source), the supply to the sink (sink) \n" *
    "and the energy stored in the pipeline (line_pack_level) at the end of the period.\n" *
    "The problem is solved 4 times in the receding horizon framework.\n" *
    "From these values, we can see how line packing is utilized in the periods 4, 6, and 8\n" *
    "due to higher prices while the level is increased in periods 2, 5, and 7 due to lower prices."
println(pretty_table(permutedims(res_mod, :Period)))

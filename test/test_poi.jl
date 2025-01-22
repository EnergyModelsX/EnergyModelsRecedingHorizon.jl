# Introduction of different profiles
price_profile = [10, 10, 10, 10, 1000, 1000, 1000, 1000]
deand_profile = [20, 30, 40, 30, 10, 50, 35, 20]
em_co2 = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]

# Function for creating a simple case
function create_poi_case(;
    dur_op = [1, 1, 1, 1, 1, 1, 1, 1],
    init_state = 10,
    HorizonType=PeriodHorizons
)
    #Define resources with their emission intensities
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    products = [power, co2]

    # Define time structure
    T = TwoLevel(1, 1, SimpleTimes(dur_op))
    hor = HorizonType(dur_op, 4, 2)

    # Define the model depending on input
    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(100)),
        Dict(co2 => FixedProfile(60)),
        co2,
    )

    #create individual nodes of the system
    nodes = [
        RefSource(
            "electricity source",
            FixedProfile(100),
            OperationalProfile(price_profile),
            FixedProfile(0),
            Dict(power => 1),
            Data[EmissionsProcess(Dict(co2 => OperationalProfile(em_co2)))]

        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage",
            StorCapOpexVar(FixedProfile(20), FixedProfile(10)),
            StorCapOpexFixed(FixedProfile(150), FixedProfile(0)),
            power,
            Dict(power => 1),
            Dict(power => 1),
            Data[InitStorageData(init_state)],
        ),
        RefSink(
            "electricity demand",
            OperationalProfile(deand_profile),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5)),
            Dict(power => 1),
        ),
    ]

    #connect the nodes with links
    links = [
        Direct("source-storage", nodes[1], nodes[2], Linear()),
        Direct("source-demand", nodes[1], nodes[3], Linear()),
        Direct("storage-demand", nodes[2], nodes[3], Linear()),
    ]

    #WIP(?) data structure - order of vectors (nodes, links, products) MUST NOT CHANGE
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
        :horizons => hor,
    )

    return case, model
end

@testset "POI integration functions" begin
    # The function `_get_value` is used to identify whether a node has initial data or not
    @testset "Function _get_value" begin
        𝒯 = SimpleTimes(10,1)
        oper = collect(𝒯)[3:5]
        prof = OperationalProfile([5,6,7,8,9,10])
        @test EMRH._get_value(5, RefInitData(10), oper) == 10
        @test EMRH._get_value([5, 6, 7], RefInitData(10), oper) == 10
        @test EMRH._get_value(prof, RefInitData(10), oper) == prof[oper]
    end
end

@testset "Variable replacement - standard" begin
    # Create the case and model
    case, model = create_poi_case()
    optimizer = POI.Optimizer(HiGHS.Optimizer())

    # Extract the data
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    ℒ = case[:links]
    # 𝒫 = case[:products]
    ℋ = case[:horizons]
    𝒽₀ = first(ℋ)

    # Create the lenses
    lens_dict = Dict{Symbol, Dict}()
    lens_dict[:nodes] = EMRH._create_lens_dict_oper_prof(𝒩)
    lens_dict[:links] = EMRH._create_lens_dict_oper_prof(ℒ)
    lens_dict[:model] = EMRH._create_lens_dict_oper_prof(model)

    # Test that the lenses are created for all nodes and links
    @test all(haskey(lens_dict[:nodes], n) for n ∈ 𝒩)
    @test all(haskey(lens_dict[:links], l) for l ∈ ℒ)
    @test isempty(lens_dict[:model])

    # Initialize the case
    case_rh, model_rh, update_dict, m =
        EMRH.init_rh_case_model(case, model, 𝒽₀, lens_dict, optimizer)

    # Test that the no variables are created for links and models
    @test isempty(update_dict[:links])
    @test isempty(update_dict[:model])

    # Extract the data from the receding horizon model
    source = case_rh[:nodes][1]
    stor = case_rh[:nodes][2]
    sink = case_rh[:nodes][3]
    co2 = case_rh[:products][2]

    # Test that all references are replaced correctly with the variables
    @test isa(opex_var(source), OperationalProfile{VariableRef})
    @test length(opex_var(source).vals) == length(𝒽₀)
    @test isa(process_emissions(node_data(source)[1], co2), OperationalProfile{VariableRef})
    @test length(process_emissions(node_data(source)[1], co2).vals) == length(𝒽₀)
    @test isa(node_data(stor)[1].val, VariableRef)
    @test length(node_data(stor)[1].val) == 1
    @test isa(capacity(sink), OperationalProfile{VariableRef})
    @test length(capacity(sink).vals) == length(𝒽₀)
end

@testset "Full model run" begin

    optimizer = POI.Optimizer(HiGHS.Optimizer())
    # Test that the wrong horizon type is caught
    dur_op = [1, 2, 1, 4, 1, 3, 1, 3]
    case, model = create_poi_case(;HorizonType=DurationHorizons, dur_op)
    @test_throws AssertionError run_model_rh(case, model, optimizer)

    # Test that a wrong duration vector is caught
    case, model = create_poi_case(;dur_op)
    @test_throws AssertionError run_model_rh(case, model, optimizer)

    # Run a working model
    case, model = create_poi_case()
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    results = run_model_rh(case, model, optimizer)

    # Extract data
    source = case[:nodes][1]
    stor = case[:nodes][2]
    sink = case[:nodes][3]
    ops = collect(case[:T])
    co2 = case[:products][2]

    # Test that the first period in the first horizon is correctly used
    @test node_data(stor)[1].val ≈
        results[:stor_level][stor, ops[1]] - results[:stor_level_Δ_op][stor, ops[1]]

    # Test that the subsequent first periods are used correctly
    first_ops = [ops[3], ops[5], ops[7]]
    last_ops = [ops[2], ops[4], ops[6]]
    @test all(
        results[:stor_level][stor, last_ops[k]] ≈
            results[:stor_level][stor, first_ops[k]] -
            results[:stor_level_Δ_op][stor, first_ops[k]]
    for k ∈ 1:3)

    # Test that the demand is equal to the profile and satisfied in all periods
    @test all(results[:cap_use][sink, ops[k]] ≈ deand_profile[k] for k ∈ 1:8)
    @test all(results[:sink_deficit][sink, ops[k]] ≈ 0 for k ∈ 1:8)

    # Test that the co2 process emissions are correctly updated
    @test all(
        results[:emissions_node][source, ops[k], co2] ≈
        results[:cap_use][source, ops[k]] * em_co2[k]
    for k ∈ 1:8)
end

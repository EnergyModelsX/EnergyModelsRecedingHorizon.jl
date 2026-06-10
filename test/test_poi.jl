# Creation of a new link type with associated capacity
struct CapDirect <: Link
    id::Any
    from::EMB.Node
    to::EMB.Node
    capacity::TimeProfile
end
function EMB.create_link(m, l::CapDirect, 𝒯, 𝒫, modeltype::EnergyModel)

    # Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p]
    )

    # Capacity constraint
    @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
        m[:link_out][l, t, p] ≤ m[:link_cap_inst][l, t]
    )
    constraints_capacity_installed(m, l, 𝒯, modeltype)
end
EMB.capacity(l::CapDirect) = l.capacity
EMB.capacity(l::CapDirect, t) = l.capacity[t]
EMB.has_capacity(l::CapDirect) = true

# Introduction of different profiles
price_profile = [10, 10, 10, 10, 1000, 1000, 1000, 1000]
cap_profile = [20, 30, 40, 30, 10, 50, 35, 20]
demand_profile = [20, 15, 20, 15, 10, 10, 20, 20]
em_co2 = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]

# Function for creating a simple case
function create_poi_case(;
    dur_op = [1, 1, 1, 1, 1, 1, 1, 1],
    init_state = 10,
    HorizonType = PeriodHorizons,
)
    #Define resources with their emission intensities
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [power, co2]

    # Define time structure
    𝒯 = TwoLevel(1, 1, SimpleTimes(dur_op))
    ℋ = HorizonType(dur_op, 4, 2)

    # Define the model depending on input
    modeltype = RecHorOperationalModel(
        Dict(co2 => FixedProfile(100)),
        Dict(co2 => FixedProfile(60)),
        co2,
    )

    #create individual nodes of the system
    𝒩 = [
        RefSource(
            "electricity source",
            FixedProfile(100),
            OperationalProfile(price_profile),
            FixedProfile(0),
            Dict(power => 1),
            Data[EmissionsProcess(Dict(co2 => OperationalProfile(em_co2)))]),
        RefStorage{RecedingAccumulating}(
            "electricity storage",
            StorCapOpexVar(FixedProfile(20), FixedProfile(10)),
            StorCapOpexFixed(FixedProfile(150), FixedProfile(0)),
            power,
            Dict(power => 1),
            Dict(power => 1),
            Data[StorageInitData(init_state)],
        ),
        RefSink(
            "electricity demand",
            OperationalProfile(demand_profile),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5)),
            Dict(power => 1),
        ),
    ]

    #connect the nodes with links
    ℒ = [
        CapDirect("source-storage", 𝒩[1], 𝒩[2], OperationalProfile(cap_profile)),
        Direct("source-demand", 𝒩[1], 𝒩[3], Linear()),
        Direct("storage-demand", 𝒩[2], 𝒩[3], Linear()),
    ]

    # Create the input case structure
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]], Dict(:horizons => ℋ))

    return case, modeltype
end

@testset "Variable replacement - standard" begin
    # Create the case and model
    case, modeltype = create_poi_case()
    optimizer = POI.Optimizer(HiGHS.Optimizer())

    # Extract the data
    𝒯 = get_time_struct(case)
    𝒳ᵛᵉᶜ = get_elements_vec(case)
    𝒫 = get_products(case)
    ℋ = case.misc[:horizons]
    𝒽₀ = first(ℋ)

    # Create the lenses
    𝒰 = EMRH._create_updatetype(modeltype)
    EMRH._add_elements!(𝒰, 𝒫)
    for 𝒳 ∈ 𝒳ᵛᵉᶜ
        EMRH._add_elements!(𝒰, 𝒳)
    end
    𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)

    # Test that the UpdateCase is correctly created with all types
    @test isempty(setdiff(get_nodes(case), get_nodes(𝒰)))
    @test isempty(setdiff(get_links(case), get_links(𝒰)))
    @test !EMRH.has_resets(EMRH.get_sub_model(𝒰))

    # Extract the time structure from the case to identify the used operational periods
    # and the receding horizon time structure
    𝒯 = get_time_struct(case)
    𝒯ᵣₕ = TwoLevel(1, 1, SimpleTimes(durations(𝒽₀)))
    opers_opt = collect(𝒯)[indices_optimization(𝒽₀)]

    # Update the receding horizon case and model as well as JuMP model
    m = Model(() -> optimizer)
    POIExt._init_update_case!(m, 𝒰, opers_opt, 𝒯ᵣₕ)

    # Extract the case and the model from the `UpdateCase`
    caseᵣₕ = Case(𝒯ᵣₕ, get_products(𝒰), get_elements_vec(𝒰), get_couplings(case))
    modelᵣₕ = EMRH.updated(EMRH.get_sub_model(𝒰))

    # Test that no variables are created for models
    # 4*4 for operational profiles and 1 for initial data
    @test length(all_variables(m)) == 17

    # Extract the data from the receding horizon model
    𝒩ᵣₕ = get_nodes(caseᵣₕ)
    ℒᵣₕ = get_links(caseᵣₕ)
    source = 𝒩ᵣₕ[1]
    stor = 𝒩ᵣₕ[2]
    sink = 𝒩ᵣₕ[3]
    co2 = get_products(caseᵣₕ)[2]
    cap_link = ℒᵣₕ[1]

    # Test that all references are replaced correctly with the variables
    @test isa(opex_var(source), OperationalProfile{VariableRef})
    @test length(opex_var(source).vals) == length(𝒽₀)
    @test isa(process_emissions(node_data(source)[1], co2), OperationalProfile{VariableRef})
    @test length(process_emissions(node_data(source)[1], co2).vals) == length(𝒽₀)
    @test isa(node_data(stor)[1].init_val_dict[:stor_level], AffExpr)
    @test length(node_data(stor)[1].init_val_dict) == 1
    @test isa(capacity(sink), OperationalProfile{VariableRef})
    @test length(capacity(sink).vals) == length(𝒽₀)
    @test isa(capacity(cap_link), OperationalProfile{VariableRef})
    @test length(capacity(cap_link).vals) == length(𝒽₀)
end

@testset "Full model run" begin
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    # Test that the wrong horizon type is caught
    case, modeltype = create_poi_case(; HorizonType = DurationHorizons)
    @test_throws AssertionError run_model_rh(case, modeltype, optimizer)

    # Test that a wrong duration vector is caught
    dur_op = [1, 2, 1, 4, 1, 3, 1, 3]
    case, modeltype = create_poi_case(; dur_op)
    @test_throws AssertionError run_model_rh(case, modeltype, optimizer)

    # Run a working model
    case, modeltype = create_poi_case()
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    results = run_model_rh(case, modeltype, optimizer)

    # Extract data
    𝒩 = get_nodes(case)
    ℒ = get_links(case)
    source = 𝒩[1]
    stor = 𝒩[2]
    sink = 𝒩[3]
    cap_link = ℒ[1]
    co2 = get_products(case)[2]
    ops = collect(get_time_struct(case))

    # Test that all results were saved
    @test length(results[:stor_level][!, :y]) == length(ops)

    # Test that the first period in the first horizon is correctly used
    @test EMRH.init_level(stor) == node_data(stor)[1].init_val_dict[:stor_level]
    @test node_data(stor)[1].init_val_dict[:stor_level] ≈
          filter(r -> r.x1 == stor && r.x2 == ops[1], results[:stor_level])[1, :y] -
          filter(r -> r.x1 == stor && r.x2 == ops[1], results[:stor_level_Δ_op])[1, :y]

    # Test that the subsequent first periods are used correctly
    first_ops = [ops[3], ops[5], ops[7]]
    last_ops = [ops[2], ops[4], ops[6]]
    @test all(
        filter(r -> r.x1 == stor && r.x2 == last_ops[k], results[:stor_level])[!, :y] ≈
        filter(r -> r.x1 == stor && r.x2 == first_ops[k], results[:stor_level])[!, :y] -
        filter(r -> r.x1 == stor && r.x2 == first_ops[k], results[:stor_level_Δ_op])[!, :y]
        for k ∈ 1:3)

    # Test that the demand is equal to the profile and satisfied in all periods
    @test all(
        filter(r -> r.x1 == sink && r.x2 == ops[k], results[:cap_use])[1, :y] ≈
        demand_profile[k] for k ∈ 1:8
    )
    @test all(
        filter(r -> r.x1 == sink && r.x2 == ops[k], results[:sink_deficit])[1, :y] ≈ 0 for
        k ∈ 1:8
    )

    # Test that the link capacity is equal to the profile
    @test all(
        filter(r -> r.x1 == cap_link && r.x2 == ops[k], results[:link_cap_inst])[1, :y] ≈
        cap_profile[k] for k ∈ 1:8
    )

    # Test that the co2 process emissions are correctly updated
    @test all(
        filter(
            r -> r.x1 == source && r.x2 == ops[k] && r.x3 == co2,
            results[:emissions_node],
        )[
            1,
            :y,
        ] ≈
        filter(r -> r.x1 == source && r.x2 == ops[k], results[:cap_use])[1, :y] * em_co2[k]
        for k ∈ 1:8)
end

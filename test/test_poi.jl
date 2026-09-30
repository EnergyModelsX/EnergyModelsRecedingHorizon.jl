# Introduction of different profiles
price_profile = [10, 10, 10, 10, 1000, 1000, 1000, 1000]
cap_profile = [20, 30, 40, 30, 10, 50, 35, 20]
mult_profile = [2, 1, 1.5, 1]
demand_profile = [20, 15, 20, 15, 10, 10, 20, 20]
em_co2 = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]

# Function for creating a simple case
function create_poi_case(;
    dur_op = [1, 1, 1, 1, 1, 1, 1, 1],
    init_state = 10,
    HorizonType = PeriodHorizons,
    hor_opt = 4,
    hor_impl = 2,
    part_profile = [2, 2, 2, 2],
    part_profile_add = nothing,
)
    #Define resources with their emission intensities
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [power, co2]

    # Define time structure
    𝒯 = TwoLevel(1, 1, SimpleTimes(dur_op))
    ℋ = HorizonType(dur_op, hor_opt, hor_impl)

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
            StorCapOpexVar(FixedProfile(30), FixedProfile(10)),
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
        CapDirect(
            "source-storage",
            𝒩[1],
            𝒩[2],
            OperationalProfile(cap_profile),
            PartitionProfile(part_profile),
            PartitionProfile(mult_profile),
        ),
        Direct("source-demand", 𝒩[1], 𝒩[3], Linear()),
        Direct("storage-demand", 𝒩[2], 𝒩[3], Linear()),
    ]

    # Add a second link with a different partition profile, if specified
    if !isnothing(part_profile_add)
        push!(ℒ,
            CapDirect(
                "source-demand-part",
                𝒩[1],
                𝒩[3],
                OperationalProfile(cap_profile),
                PartitionProfile(part_profile_add),
                PartitionProfile(mult_profile),
            ),
        )
    end

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
    𝒰 = EMRH._create_updatetype(case, modeltype)
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
    # 4*4 for operational profiles, 2 for partition profiles, and 1 for initial data
    @test length(all_variables(m)) == 19

    # Extract the data from the receding horizon model
    src, stor, snk = get_nodes(caseᵣₕ)
    cap_link = get_links(caseᵣₕ)[1]
    co2 = get_products(caseᵣₕ)[2]

    # Test that all references are replaced correctly with the variables
    @test isa(opex_var(src), OperationalProfile{VariableRef})
    @test length(opex_var(src).vals) == length(𝒽₀)
    @test isa(process_emissions(node_data(src)[1], co2), OperationalProfile{VariableRef})
    @test length(process_emissions(node_data(src)[1], co2).vals) == length(𝒽₀)
    @test isa(node_data(stor)[1].init_val_dict[:stor_level], AffExpr)
    @test length(node_data(stor)[1].init_val_dict) == 1
    @test isa(capacity(snk), OperationalProfile{VariableRef})
    @test length(capacity(snk).vals) == length(𝒽₀)
    @test isa(capacity(cap_link), OperationalProfile{VariableRef})
    @test length(capacity(cap_link).vals) == length(𝒽₀)
    @test isa(cap_link.part_mult, PartitionProfile{VariableRef})
    @test isa(cap_link.part_dur, PartitionProfile{Int64})
    @test length(cap_link.part_dur.vals) == 4
    @test length(cap_link.part_mult.vals) == 2
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

    # Test that a wrong partition profile is caught
    EMB.TEST_ENV = true
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    part_profile = [2, 1, 1, 2, 1, 1]
    case, modeltype = create_poi_case(; part_profile)
    @test_throws AssertionError run_model_rh(case, modeltype, optimizer)
    EMB.TEST_ENV = false

    # Run a working model
    case, modeltype = create_poi_case()
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    results = run_model_rh(case, modeltype, optimizer)

    # Extract data
    src, stor, snk = get_nodes(case)
    cap_link = get_links(case)[1]
    co2 = get_products(case)[2]
    ops = collect(get_time_struct(case))

    # Test that all results were saved
    @test length(results[:stor_level][!, :y]) == length(ops)

    # Test that the variable indexed over period partitions is saved once for each partition
    # of the original problem
    # - _get_values_from_obj(obj::SparseAxisArray, opers)
    # - original(𝒰::UpdateCase, x_new::T) where {T<:TS.PeriodPartition}
    𝒯ᵖᵈ = collect(partition_duration(get_time_struct(case), EMRH.period_duration(cap_link)))
    @test nrow(results[:part_variable]) == length(𝒯ᵖᵈ)
    @test results[:part_variable][!, :x1] == fill(cap_link, length(𝒯ᵖᵈ))
    @test results[:part_variable][!, :x2] == 𝒯ᵖᵈ

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
        filter(r -> r.x1 == snk && r.x2 == ops[k], results[:cap_use])[1, :y] ≈
            demand_profile[k]
    for k ∈ 1:8)
    @test all(
        filter(r -> r.x1 == snk && r.x2 == ops[k], results[:sink_deficit])[1, :y] ≈ 0
    for k ∈ 1:8)

    # Test that the link capacity is equal to the profile
    @test all(
        filter(r -> r.x1 == cap_link && r.x2 == ops[k], results[:link_cap_inst])[1, :y] ≈
            cap_profile[k]
    for k ∈ 1:8)

    # Test that the link capacity is equal to the profile
    @test all(
        filter(r -> r.x1 == cap_link && r.x2 == ops[k], results[:link_out])[1, :y] ≤
            cap_profile[k] * mult_profile[pd]
    for (k, pd) ∈ zip(1:8, [1, 1, 2, 2, 3, 3, 4, 4]))


    # Test that the co2 process emissions are correctly updated
    @test all(
        filter(
            r -> r.x1 == src && r.x2 == ops[k] && r.x3 == co2,
            results[:emissions_node],
        )[1, :y] ≈
            filter(r -> r.x1 == src && r.x2 == ops[k], results[:cap_use])[1, :y] * em_co2[k]
    for k ∈ 1:8)

    # Run a model with two links with different partition profiles. The first partition of
    # both links is `(1)` in each receding horizon problem, while the corresponding
    # partitions of the original problem differ from the second horizon onwards
    case, modeltype = create_poi_case(;
        dur_op = fill(1, 7),
        hor_impl = 3,
        part_profile = [1, 2, 1, 2, 1],
        part_profile_add = fill(1, 7),
    )
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    results = run_model_rh(case, modeltype, optimizer)

    # Test that the variable indexed over period partitions is indexed by the partitions of
    # the original problem of the respective link
    # - _add_partition_mapping!(𝒰, s::AbstractSub, opers, 𝒯ᵣₕ)
    for l ∈ filter(l -> isa(l, CapDirect), get_links(case))
        𝒯ᵖᵈ = collect(partition_duration(get_time_struct(case), EMRH.period_duration(l)))
        @test filter(r -> r.x1 == l, results[:part_variable])[!, :x2] == 𝒯ᵖᵈ
    end
end

@testset "Result containers" begin
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    products = [power, co2]

    T = TwoLevel(1, 1, SimpleTimes([2, 3, 4, 2, 1]))
    hor = PeriodHorizons([duration(t) for t ∈ T], 2, 1)

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)), Dict(co2 => FixedProfile(0)), co2,
    )

    nodes = [
        GenAvailability("Availability", products),
        RefSource(
            "electricity source", # id
            FixedProfile(1e12), # cap
            OperationalProfile([1, 10, 1, 10, 1]), # opex_var
            FixedProfile(0), # opex_fixed
            Dict(power => 1), # output
        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage", # id
            StorCapOpexVar(FixedProfile(100), FixedProfile(0.01)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(1.5), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                InitStorageData(0),
                EmptyData() # testing multiple data
            ]),
        ),
        RefSink(
            "electricity demand", # id
            OperationalProfile([3, 4, 5, 6, 3]), # cap
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)), # penalty
            Dict(power => 1), # input
        ),
    ]

    links = [
        Direct("av-source", nodes[1], nodes[2], Linear()),
        Direct("av-storage", nodes[1], nodes[3], Linear()),
        Direct("av-demand", nodes[1], nodes[4], Linear()),
        Direct("source-av", nodes[2], nodes[1], Linear()),
        Direct("storage-av", nodes[3], nodes[1], Linear()),
        Direct("demand-av", nodes[4], nodes[1], Linear()),
    ]

    case = Dict(
        :nodes => nodes, :links => links, :products => products, :T => T,
        :horizons => hor,
    )

    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    hor_test = first(hor)

    lens_dict = Dict{Symbol, Dict}()
    lens_dict[:nodes] = EMRH._create_lens_dict_oper_prof(case[:nodes])
    lens_dict[:links] = EMRH._create_lens_dict_oper_prof(case[:links])
    lens_dict[:model] = EMRH._create_lens_dict_oper_prof(model)
    case_rh, model_rh = EMRH.get_rh_case_model(case, model, hor_test, lens_dict)

    m_rh1 = run_model(case_rh, model_rh, optimizer)
    @test termination_status(m_rh1) == MOI.OPTIMAL

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    results_EMRH = Dict{Symbol,AbstractArray{Float64}}()
    EMRH.update_results!(results_EMRH, m_rh1, case_rh, case, hor_test)
    results_EMB = EMRH.get_results(m_EMB)
    @test Set(keys(results_EMB)) == union(
        keys(results_EMRH),
        [:opex_var, :emissions_strategic, :opex_fixed, # fields for strategic horizons - to be implemented
            :link_opex_fixed, :link_opex_var], #NEW fields when updated EMB. Are these important? Check with Julian
    )
    dense_containers(cont) =
        filter(kv -> (typeof(kv[2]) <: Containers.DenseAxisArray), cont)
    for (k_EMRH, _) ∈ dense_containers(results_EMRH)
        @test size(results_EMRH[k_EMRH].data) == size(results_EMB[k_EMRH].data)
    end
    sparse_containers(cont) =
        filter(kv -> (typeof(kv[2]) <: Containers.SparseAxisArray), cont)
    for (k_EMRH, _) ∈ sparse_containers(results_EMRH)
        @test Set(results_EMRH[k_EMRH].data.keys) ⊆ Set(results_EMB[k_EMRH].data.keys) # not all values are allocated initially
    end
end

@testset "Check nodes for OperationalProfile" begin
    el = ResourceCarrier("el", 0.2)
    heat = ResourceCarrier("heat", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [el, heat, co2]

    profile = [1, 2, 3]
    dim_t = length(profile)

    em_process_oper = EmissionsProcess(Dict(co2 => OperationalProfile(profile)))
    em_process_fixed = EmissionsProcess(Dict(co2 => FixedProfile(2)))

    data = [
        EmissionsEnergy(OperationalProfile(profile)),
        EmissionsProcess(Dict(co2 => OperationalProfile(profile))),
        EmissionsProcess(Dict(co2 => FixedProfile(2))),
    ]

    #create individual nodes of the system
    av = GenAvailability("Availability", resources)
    source_fixed = RefSource(
        "electricity source", #Node id or name
        FixedProfile(1e12), #Capacity
        FixedProfile(100), #variable OPEX
        FixedProfile(0), #Fixed OPEN in EUR/8h
        Dict(el => 1), #output from the node
    )
    source_oper = RefSource(
        "electricity source", #Node id or name
        FixedProfile(1e12), #Capacity
        OperationalProfile(profile), #variable OPEX
        FixedProfile(0), #Fixed OPEN in EUR/8h
        Dict(el => 1), #output from the node
    )
    network = RefNetworkNode(
        "el_to_heat",
        FixedProfile(1e12), #cap - This can be OperationalProfile
        OperationalProfile(profile), #opex variable
        FixedProfile(0),
        Dict(el => 1), #input
        Dict(heat => 1), #output
        data,
    )
    storage = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
    )
    storage_data = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
        data,
    )
    storage_charge_oper = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(OperationalProfile(profile), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
    )
    storage_level_oper = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(OperationalProfile(profile), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
    )
    storage_charge_level_data_oper = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(OperationalProfile(profile), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(OperationalProfile(profile), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
        data,
    )
    sink = RefSink(
        "heat demand", #node ID or name
        OperationalProfile(profile), #demand in MW (time profile)
        Dict(
            :surplus => FixedProfile(0),
            :deficit => OperationalProfile(1e6 * ones(dim_t)),
        ), #surplus and deficit penalty
        Dict(heat => 1), #energy demand and corresponding ratio
    )

    @test issetequal(EMRH._find_paths_operational_profile(source_fixed), Any[])
    @test issetequal(EMRH._find_paths_operational_profile(source_oper), [[:opex_var]])
    @test issetequal(
        EMRH._find_paths_operational_profile(sink),
        [[:cap], [:penalty, :deficit]],
    )
    @test issetequal(EMRH._find_paths_operational_profile(storage_charge_level_data_oper),
        [[:charge, :capacity],
            [:level, :capacity],
            [:data, "idx_2", :emissions, co2]],
    )

    all_paths = []
    current_path = Any[:a_path]
    a_dict = Dict(
        :a => Dict(
            :b1 => Dict(:c => OperationalProfile([1])),
            :b2 => OperationalProfile([1]),
            :b3 => [1],
        ),
    )
    EMRH._find_paths_operational_profile(a_dict, current_path, all_paths)
    @test issetequal(all_paths, [[:a_path, :a, :b2], [:a_path, :a, :b1, :c]])

    @test all(EMRH._fields_with_operational_profile(network) .== [:opex_var, :data])
    @test all(EMRH._fields_with_operational_profile(source_oper) .== [:opex_var])
    @test all(EMRH._fields_with_operational_profile(source_fixed) .== Symbol[])
    @test all(EMRH._fields_with_operational_profile(av) .== Symbol[])
    @test all(EMRH._fields_with_operational_profile(storage) .== Symbol[])
    @test all(EMRH._fields_with_operational_profile(storage_data) .== [:data])
    @test all(EMRH._fields_with_operational_profile(storage_charge_oper) .== [:charge])
    @test all(EMRH._fields_with_operational_profile(storage_level_oper) .== [:level])
    @test all(
        EMRH._fields_with_operational_profile(storage_charge_level_data_oper) .==
        [:charge, :level, :data],
    )
end

@testset "EMRH._has_field_operational_profile" begin
    @test EMRH._has_field_operational_profile(OperationalProfile([1]))
    @test EMRH._has_field_operational_profile(
        Dict(:a => Dict(:b => Dict(:c => OperationalProfile([1])))),
    ) # true
    @test !EMRH._has_field_operational_profile(
        Dict(:a => Dict(:b => Dict(:c => FixedProfile(1)))),
    ) # false
    @test_throws ErrorException EMRH._has_field_operational_profile(
        Dict(:a => StrategicProfile([1, 2])),
    ) # raises Error. EMRH should not be used with StrategicProfile

    #test for various Data
    #EmissionsEnergy accepts any input arguments, but does not use it.
    @test !EMRH._has_field_operational_profile(EmissionsEnergy(OperationalProfile([1])))
    @test EMRH._has_field_operational_profile(
        EmissionsProcess(Dict(co2 => OperationalProfile([1]))),
    )
    @test !EMRH._has_field_operational_profile(
        EmissionsProcess(Dict(co2 => FixedProfile(2))),
    )
    @test !EMRH._has_field_operational_profile(EmptyData())
    @test !EMRH._has_field_operational_profile(InitStorageData(4.0))

    #test for various AbstractStorageParameters
    @test EMRH._has_field_operational_profile(
        StorCapOpexFixed(OperationalProfile([1]), FixedProfile(0)),
    )
    @test !EMRH._has_field_operational_profile(
        StorCapOpexFixed(FixedProfile(1), FixedProfile(0)),
    )
    @test EMRH._has_field_operational_profile(
        StorCapOpexVar(OperationalProfile([1]), FixedProfile(0)),
    )
    @test !EMRH._has_field_operational_profile(
        StorCapOpexVar(FixedProfile(1), FixedProfile(0)),
    )
    @test EMRH._has_field_operational_profile(StorOpexVar(OperationalProfile([1])))
    @test !EMRH._has_field_operational_profile(StorOpexVar(FixedProfile(1)))
    @test EMRH._has_field_operational_profile(StorCap(OperationalProfile([1])))
    @test !EMRH._has_field_operational_profile(StorCap(FixedProfile(1)))
end

@testset "lenses_and_reset" begin
    cap_prof = [20, 300]
    price_prof = [1, 2]
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)

    @testset "lenses_and_reset_source" begin
        data_source = Data[
        # EmissionsEnergy(OperationalProfile(price_profile)),
            EmissionsProcess(Dict(co2 => OperationalProfile(price_prof))),
        # EmissionsProcess(Dict(co2 => FixedProfile(2))),
        ]
        source = RefSource(
            "a source", #Node id or name
            OperationalProfile(cap_prof),
            FixedProfile(100), #variable OPEX
            FixedProfile(0), #Fixed OPEX
            Dict(power => 1), #output from the node
            data_source,
        )

        #checks for source
        paths_oper_source = EMRH._find_paths_operational_profile(source)
        @test all(paths_oper_source .== Any[[:cap], [:data, "idx_1", :emissions, co2]])

        lens_source_cap = EMRH._create_lens_for_field(paths_oper_source[1])
        lens_source_data = EMRH._create_lens_for_field(paths_oper_source[2])
        @test all(cap_prof .== lens_source_cap(source).vals)
        @test all(price_prof .== lens_source_data(source).vals)

        cap_prof2 = [60, 32]
        price_prof2 = [90, 80]
        @reset lens_source_cap(source) = OperationalProfile(cap_prof2)
        @reset lens_source_data(source) = OperationalProfile(price_prof2)
        @test all(cap_prof2 .== lens_source_cap(source).vals)
        @test all(price_prof2 .== lens_source_data(source).vals)
    end

    @testset "lenses_and_reset_storage" begin
        #checks for storage
        init_state = 5.0
        data_storage = Vector([
            InitStorageData(init_state),
            EmptyData(),
            EmissionsProcess(Dict(co2 => OperationalProfile(price_prof))),
        ])
        storage = RefStorage{RecedingAccumulating}(
            "a storage",
            StorCapOpexVar(OperationalProfile(cap_prof), FixedProfile(100)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            data_storage,
        )
        paths_oper_storage = EMRH._find_paths_operational_profile(storage)
        @test all(
            paths_oper_storage .==
            Any[[:charge, :capacity], [:data, "idx_1", :val], [:data, "idx_3", :emissions, co2]],
        )

        #test getting values
        lens_storage_cap = EMRH._create_lens_for_field(paths_oper_storage[1])
        lens_storage_data = EMRH._create_lens_for_field(paths_oper_storage[3])
        @test all(cap_prof .== lens_storage_cap(storage).vals)
        @test all(price_prof .== lens_storage_data(storage).vals)

        #test resetting values
        cap_prof2 = [60,32]
        price_prof2 = [90,80]
        @reset lens_storage_cap(storage) = OperationalProfile(cap_prof2)
        @reset lens_storage_data(storage) = OperationalProfile(price_prof2)
        @test all(cap_prof2 .== lens_storage_cap(storage).vals)
        @test all(price_prof2 .== lens_storage_data(storage).vals)
    end
end

@testset "POI in OperationalProfile" begin
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    function check_equal_flows_av_node(m1, case1, m2, case2)
        @assert is_solved_and_feasible(m1) "We assume optimized models."
        @assert is_solved_and_feasible(m2) "We assume optimized models."

        av1 = case1[:nodes][1]
        av2 = case2[:nodes][1]

        #result dictionary
        res1 = EMRH.get_results(m1)
        res2 = EMRH.get_results(m2)

        for (r1, r2) ∈ zip(case1[:products], case2[:products])
            @assert r1.id == r2.id

            equal_in = (res1[:flow_in][av1, :, r1] .== res2[:flow_in][av2, :, r2])
            equal_out = (res1[:flow_out][av1, :, r1] .== res2[:flow_out][av2, :, r2])

            if !(all(equal_in) && all(equal_out))
                error("results are not equal for r1=$(r1) and r2=$(r2)")
            end
        end
        return true #no errors have been thrown
    end

    function solve_EMB_case(demand_profile, price_profile, price_profile_stor)
        println("demand profile = $(demand_profile)")
        case_EMB, modeltype_EMB = create_case(demand_profile, price_profile, price_profile_stor;
            init_state = 5, modeltype = OperationalModel,
        )
        @assert typeof(modeltype_EMB) <: OperationalModel
        m_EMB = run_model(case_EMB, modeltype_EMB, optimizer)
        termination_status(m_EMB)
        return m_EMB, case_EMB
    end

    function create_case(
        demand_profile,
        price_profile,
        price_profile_stor,
        ;
        init_state = 0,
        modeltype = RecHorOperationalModel,
    )
        #Define resources with their emission intensities
        power = ResourceCarrier("power", 0.0)
        co2 = ResourceEmit("co2", 1.0)
        products = [power, co2]

        #define time structure
        op_dur_vec = [1, 2, 1]
        T = TwoLevel(1, 1, SimpleTimes(op_dur_vec))
        hor = DurationHorizons([duration(t) for t ∈ T], 3, 3) # optimi and impl horizons

        model = modeltype(
            Dict(co2 => FixedProfile(10)),
            Dict(co2 => FixedProfile(0)), # emission price for CO2
            co2,
        )

        #create individual nodes of the system
        av = GenAvailability("Availability", products)
        source = RefSource(
            "electricity source", #Node id or name
            FixedProfile(1e7), #Capacity in MW (Time profile)
            OperationalProfile(price_profile), #variable OPEX (time structure) in EUR/MW
            FixedProfile(0), #Fixed OPEN in EUR/8h
            Dict(power => 1), #output from the node
        )
        storage = RefStorage{RecedingAccumulating}(
            "electricity storage",
            StorCapOpexVar(FixedProfile(100), OperationalProfile(price_profile_stor)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                InitStorageData(init_state),
                EmptyData() # testing multiple data
            ]),
        )
        sink = RefSink(
            "electricity demand", #node ID or name
            OperationalProfile(demand_profile), #demand in MW (time profile)
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e12)),
            Dict(power => 1), #energy demand and corresponding ratio
        )
        nodes = [
            av,
            source,
            storage,
            sink,
        ]
        links = create_links_from_nodes(nodes)
        case = Dict(
            :nodes => nodes, :links => links, :products => products, :T => T,#, :horizons => hor
        )

        return case, model
    end

    function create_links_from_nodes(nodes::Vector{<:EMB.Node})
        (av,
            source,
            storage,
            sink) = nodes
        #connect the nodes with links
        links = [
            Direct("source-av", source, av, Linear()),
            Direct("av-sink", av, sink, Linear()),
            Direct("av-storage", av, storage, Linear()),
            Direct("storage-av", storage, av, Linear()),
        ]
        return links
    end

    #provide data
    demand_prof = [20, 300, 40]
    price_prof = [1e3, 1e3, 1e3]
    price_prof_stor = [1e3, 7e2, 1e3]

    case_rh, modeltype_rh = create_case(demand_prof, price_prof, price_prof_stor;
        init_state = 5, modeltype = RecHorOperationalModel,
    )
    @assert typeof(modeltype_rh) <: RecHorOperationalModel
    case_rh_copy = deepcopy(case_rh)

    # Define JuMP.Model
    m_rh = Model(() -> ParametricOptInterface.Optimizer(HiGHS.Optimizer()))

    #change to paramtric OperationalProfiles
    case_rh, update_dict, lens_dict =
        EMRH._set_POI_par_as_operational_profile(m_rh, case_rh, case_rh_copy)

    # Regenerate links after modifying nodes
    case_rh[:links] = create_links_from_nodes(case_rh[:nodes])

    # Create model and optimize
    EMB.create_model(case_rh, modeltype_rh, m_rh; check_any_data = false)
    optimize!(m_rh)

    # check we get same values as EMB
    m_EMB1, case_EMB1 = solve_EMB_case(demand_prof, price_prof, price_prof_stor)
    @assert check_equal_flows_av_node(m_rh, case_rh, m_EMB1, case_EMB1)

    # change parameter values for the sink
    multiplier = 2
    n_sink = case_rh_copy[:nodes][end]
    @assert typeof(n_sink) <: Sink
    idx_sink = EMRH._get_node_index(n_sink, case_rh[:nodes])

    # check that EMRH._get_new_POI_values returns the same values as originally provided
    orig_cap_prof = EMRH._get_new_POI_values(n_sink, lens_dict[n_sink][Any[:cap]])
    @test all(demand_prof .== orig_cap_prof)

    demand_prof2 = EMRH._get_new_POI_values(
        n_sink,
        lens_dict[n_sink][Any[:cap]]; multiplier = multiplier)

    @test all(demand_prof2 .== (multiplier .* demand_prof)) #the multiplier works as intended

    #change values of the POI parameters
    m_rh = EMRH._set_values_operational_profile(
        m_rh,
        case_rh_copy,
        case_rh_copy[:nodes][idx_sink],
        update_dict,
        lens_dict;
        multiplier = multiplier,
        )

    # change parameter values for the storage node
    n_storage = case_rh_copy[:nodes][3]
    @assert typeof(n_storage) <: Storage
    idx_storage = EMRH._get_node_index(n_storage, case_rh[:nodes])

    # check that EMRH._get_new_POI_values returns the same values as originally provided
    orig_price_prof_stor = EMRH._get_new_POI_values(n_storage, lens_dict[n_storage][Any[:charge, :opex_var]])
    @test all(price_prof_stor .== orig_price_prof_stor)

    price_prof_stor2 = EMRH._get_new_POI_values(
        n_storage,
        lens_dict[n_storage][Any[:charge, :opex_var]]; multiplier = multiplier)

    @test all(price_prof_stor2 .== (multiplier .* price_prof_stor)) #the multiplier works as intended

    #change values of the POI parameters
    m_rh = EMRH._set_values_operational_profile(
        m_rh,
        case_rh_copy,
        case_rh_copy[:nodes][idx_storage],
        update_dict,
        lens_dict;
        multiplier = multiplier,
    )

    #re-optimize
    optimize!(m_rh)

    #check that we get the same values as EMB again
    m_EMB2, case_EMB2 = solve_EMB_case(demand_prof2, price_prof, price_prof_stor2)
    @test check_equal_flows_av_node(m_rh, case_rh, m_EMB2, case_EMB2)
end

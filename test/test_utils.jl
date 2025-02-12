@testset "Result containers" begin
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [power, co2]

    𝒯 = TwoLevel(1, 1, SimpleTimes([2, 3, 4, 2, 1]))
    ℋ = PeriodHorizons([duration(t) for t ∈ 𝒯], 2, 1)

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)), Dict(co2 => FixedProfile(0)), co2,
    )

    𝒩 = [
        GenAvailability("Availability", 𝒫),
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
                StorageInitData(0),
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

    ℒ = [
        Direct("av-storage", 𝒩[1], 𝒩[3], Linear()),
        Direct("av-demand", 𝒩[1], 𝒩[4], Linear()),
        Direct("source-av", 𝒩[2], 𝒩[1], Linear()),
        Direct("storage-av", 𝒩[3], 𝒩[1], Linear()),
    ]

    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]], Dict(:horizons => ℋ))

    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    hor_test = first(ℋ)

    𝒰 = EMRH._create_updatetype(model)
    EMRH._add_elements!(𝒰, 𝒫)
    for 𝒳 ∈ get_elements_vec(case)
        EMRH._add_elements!(𝒰, 𝒳)
    end
    𝒯ᵣₕ = TwoLevel(1, 1, SimpleTimes(durations(hor_test)))
    opers_opt = collect(𝒯)[indices_optimization(hor_test)]
    EMRH.get_rh_case_model(𝒰, opers_opt, 𝒯ᵣₕ)

    # Extract the case and the model from the `UpdateCase`
    case_rh = Case(𝒯ᵣₕ, get_products(𝒰), get_elements_vec(𝒰), get_couplings(case))
    model_rh = EMRH.updated(EMRH.get_sub_model(𝒰))

    m_rh1 = run_model(case_rh, model_rh, optimizer)
    @test termination_status(m_rh1) == MOI.OPTIMAL

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    results_EMRH = Dict{Symbol,AbstractDataFrame}()
    opers_impl = collect(𝒯)[indices_implementation(hor_test)]
    EMRH.update_results!(results_EMRH, m_rh1, 𝒰, opers_impl)
    results_EMB = EMRH.get_results(m_EMB)
    excl_var = [
        # Strategic indexed and empty
        :opex_var, :opex_fixed, :link_opex_var, :link_opex_fixed, :stor_level_Δ_sp,
        # Strategic index variables
        :emissions_strategic,
        # Empty variables
        :emissions_node, :emissions_link, :stor_discharge_inst, :link_cap_inst,
    ]
    @test Set(keys(results_EMB)) == union(keys(results_EMRH), excl_var)
    results_EMB_df = EMRH.get_results_df(m_EMB)
    @test Set(keys(results_EMB_df)) == union(keys(results_EMRH), excl_var)
end

@testset "Identification of data to be changed" begin
    el = ResourceCarrier("el", 0.2)
    heat = ResourceCarrier("heat", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [el, heat, co2]

    @testset "Identifiying operational changed types" begin
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
        @test !EMRH._has_field_operational_profile(StorageInitData(4.0))

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

    profile = [1, 2, 3]
    dim_t = length(profile)

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
        [StorageInitData(0.5)],
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
        [StorageInitData(0.5)],
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

    @testset "Identification - fields" begin
        @test all(EMRH._fields_with_operational_profile(av) .== Symbol[])
        @test all(EMRH._fields_with_operational_profile(source_fixed) .== Symbol[])
        @test all(EMRH._fields_with_operational_profile(source_oper) .== [:opex_var])
        @test all(EMRH._fields_with_operational_profile(network) .== [:opex_var, :data])
        @test all(EMRH._fields_with_operational_profile(storage) .== Symbol[])
        @test all(EMRH._fields_with_operational_profile(storage_data) .== [])
        @test all(EMRH._fields_with_operational_profile(storage_charge_oper) .== [:charge])
        @test all(EMRH._fields_with_operational_profile(storage_level_oper) .== [:level])
        @test all(
            EMRH._fields_with_operational_profile(storage_charge_level_data_oper) .==
            [:charge, :level],
        )
        @test all(EMRH._fields_with_operational_profile(sink) .== [:cap, :penalty])
    end

    # Creation of a new link type
    struct ProfDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
        profile::TimeProfile
    end

    link = ProfDirect(
        "prof_link",
        source_fixed,
        sink,
        Linear(),
        OperationalProfile(profile),
    )

    # Creation of a modeltype with OperationalProfile
    model = RecHorOperationalModel(
        Dict(co2 => OperationalProfile([100, 100, 100])),
        Dict(co2 => FixedProfile(60)),
        co2,
    )

    # Creation of new Node type
    struct StringDict <: EMB.NetworkNode
        profile::Dict{String,TimeProfile}
    end
    string_dict = StringDict(
        Dict(
            "a" => OperationalProfile([100, 100, 100]),
            "b" => FixedProfile(10),
            "c" => OperationalProfile([100, 100, 100]),
        ),
    )
    Base.show(io::IO, w::StringDict) = "StringDict"

    @testset "Identification - paths" begin
        # Test of all potential node input from EMRH
        @test issetequal(EMRH._find_paths_operational_profile(av), Any[])
        @test issetequal(EMRH._find_paths_operational_profile(source_fixed), Any[])
        @test issetequal(
            EMRH._find_paths_operational_profile(source_oper),
            [[:opex_var, EMRH.OperPath()]])
        @test issetequal(
            EMRH._find_paths_operational_profile(network),
            [
                [:opex_var, EMRH.OperPath()],
                [:data, "[2]", :emissions, co2, EMRH.OperPath()]
            ],
        )
        @test issetequal(EMRH._find_paths_operational_profile(storage), Any[])
        @test issetequal(
            EMRH._find_paths_operational_profile(storage_data),
            [[:data, "[1]", :init_val_dict, "[:stor_level]", EMRH.InitDataPath(:stor_level)]],
        )
        @test issetequal(
            EMRH._find_paths_operational_profile(storage_charge_oper),
            [[:charge, :capacity, EMRH.OperPath()]],
        )
        @test issetequal(
            EMRH._find_paths_operational_profile(storage_level_oper),
            [[:level, :capacity, EMRH.OperPath()]],
        )
        @test issetequal(
            EMRH._find_paths_operational_profile(storage_charge_level_data_oper),
            [
                [:charge, :capacity, EMRH.OperPath()],
                [:level, :capacity, EMRH.OperPath()],
                [:data, "[1]", :init_val_dict, "[:stor_level]", EMRH.InitDataPath(:stor_level)],
            ],
        )
        @test issetequal(
            EMRH._find_paths_operational_profile(sink),
            [[:cap, EMRH.OperPath()], [:penalty, "[:deficit]", EMRH.OperPath()]],
        )

        # Test of link and model
        @test issetequal(
            EMRH._find_paths_operational_profile(link),
            [[:from, EMRH.ElementPath()], [:to, EMRH.ElementPath()], [:profile, EMRH.OperPath()]],
        )
        @test issetequal(
            EMRH._find_paths_operational_profile(model),
            [[:emission_limit, co2, EMRH.OperPath()]],
        )

        # Test of the new node
        @test issetequal(
            EMRH._find_paths_operational_profile(string_dict),
            Any[
                [:profile, "[\"a\"]", EMRH.OperPath()],
                [:profile, "[\"c\"]", EMRH.OperPath()]
            ],
        )
    end

    @testset "Case creation - lenses and resets" begin
        𝒩 = EMB.Node[av, source_fixed, source_oper, network, storage_charge_level_data_oper]
        ℒ = Link[link]

        # Create the lenses
        lens_dict = Dict{Symbol,Dict}()
        lens_dict[:nodes] = EMRH._create_lens_dict_oper_prof(𝒩)
        lens_dict[:links] = EMRH._create_lens_dict_oper_prof(ℒ)
        lens_dict[:model] = EMRH._create_lens_dict_oper_prof(model)

        # Test that the lenses are created for all nodes and links
        @test all(haskey(lens_dict[:nodes], n) for n ∈ 𝒩)
        @test all(haskey(lens_dict[:links], l) for l ∈ ℒ)
        @test !isempty(lens_dict[:model])
    end
end

@testset "Lenses and direct reset" begin
    cap_prof = [20, 300]
    price_prof = [1, 2]
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)

    @testset "Source" begin
        data_source = Data[
            EmissionsProcess(Dict(co2 => OperationalProfile(price_prof))),
        ]
        source = RefSource(
            "source",
            OperationalProfile(cap_prof),
            FixedProfile(100),
            FixedProfile(0),
            Dict(power => 1),
            data_source,
        )

        #checks for source
        paths_oper_source = EMRH._find_paths_operational_profile(source)
        @test all(
            paths_oper_source .==
                Any[
                    [:cap, EMRH.OperPath()],
                    [:data, "[1]", :emissions, co2, EMRH.OperPath()]
                ]
        )

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

    @testset "Sink" begin
        sink = RefSink(
            "sink",
            OperationalProfile(cap_prof),
            Dict(:surplus => FixedProfile(0), :deficit => OperationalProfile(price_prof)),
            Dict(power => 1),
        )

        #checks for sink
        paths_oper_sink = EMRH._find_paths_operational_profile(sink)
        @test all(
            paths_oper_sink .==
                Any[[:cap, EMRH.OperPath()], [:penalty, "[:deficit]", EMRH.OperPath()]
            ]
        )

        lens_sink_cap = EMRH._create_lens_for_field(paths_oper_sink[1])
        lens_sink_data = EMRH._create_lens_for_field(paths_oper_sink[2])
        @test all(cap_prof .== lens_sink_cap(sink).vals)
        @test all(price_prof .== lens_sink_data(sink).vals)

        cap_prof2 = [60, 32]
        price_prof2 = [90, 80]
        @reset lens_sink_cap(sink) = OperationalProfile(cap_prof2)
        @reset lens_sink_data(sink) = OperationalProfile(price_prof2)
        @test all(cap_prof2 .== lens_sink_cap(sink).vals)
        @test all(price_prof2 .== lens_sink_data(sink).vals)
    end

    @testset "Storage" begin
        init_state = 5.0
        data_storage = Vector([
            StorageInitData(init_state),
            EmptyData(),
            EmissionsProcess(Dict(co2 => OperationalProfile(price_prof))),
        ])
        storage = RefStorage{RecedingAccumulating}(
            "a storage",
            StorCapOpexVar(OperationalProfile(cap_prof), FixedProfile(100)),
            StorCapOpexFixed(FixedProfile(10), FixedProfile(0)),
            power,
            Dict(power => 1),
            Dict(power => 1),
            data_storage,
        )
        paths_oper_storage = EMRH._find_paths_operational_profile(storage)
        @test all(
            paths_oper_storage .==
            Any[
                [:charge, :capacity, EMRH.OperPath()],
                [:data, "[1]", :init_val_dict, "[:stor_level]", EMRH.InitDataPath(:stor_level)],
                [:data, "[3]", :emissions, co2, EMRH.OperPath()],
            ],
        )

        #test getting values
        lens_storage_cap = EMRH._create_lens_for_field(paths_oper_storage[1])
        lens_storage_data = EMRH._create_lens_for_field(paths_oper_storage[3])
        @test all(cap_prof .== lens_storage_cap(storage).vals)
        @test all(price_prof .== lens_storage_data(storage).vals)

        #test resetting values
        cap_prof2 = [60, 32]
        price_prof2 = [90, 80]
        @reset lens_storage_cap(storage) = OperationalProfile(cap_prof2)
        @reset lens_storage_data(storage) = OperationalProfile(price_prof2)
        @test all(cap_prof2 .== lens_storage_cap(storage).vals)
        @test all(price_prof2 .== lens_storage_data(storage).vals)
    end

    @testset "NewType with Dict{String,TimeProfile}" begin
        string_dict = StringDict(
            Dict(
                "a" => OperationalProfile([100, 100]),
                "b" => FixedProfile(10),
                "c" => OperationalProfile([20, 40]),
            ),
        )

        paths_node = EMRH._find_paths_operational_profile(string_dict)

        #test getting values
        path_a = filter(path -> path[2] == "[\"a\"]", paths_node)
        path_c = filter(path -> path[2] == "[\"c\"]", paths_node)
        lens_a = EMRH._create_lens_for_field(path_a[1])
        lens_c = EMRH._create_lens_for_field(path_c[1])
        @test all([100, 100] .== lens_a(string_dict).vals)
        @test all([20, 40] .== lens_c(string_dict).vals)

        #test resetting values
        cap_prof2 = [60, 32]
        price_prof2 = [90, 80]
        @reset lens_a(string_dict) = OperationalProfile(cap_prof2)
        @reset lens_c(string_dict) = OperationalProfile(price_prof2)
        @test all(cap_prof2 .== lens_a(string_dict).vals)
        @test all(price_prof2 .== lens_c(string_dict).vals)
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
        res1 = EMRH.get_results_df(m1)
        res2 = EMRH.get_results_df(m2)

        for (r1, r2) ∈ zip(case1[:products], case2[:products])
            @assert r1.id == r2.id

            equal_in = (
                filter(r -> r.x1 == av1 && r.x3 == r1, res1[:flow_in])[!, :y] .==
                filter(r -> r.x1 == av2 && r.x3 == r2, res2[:flow_in])[!, :y]
            )
            equal_out = (
                filter(r -> r.x1 == av1 && r.x3 == r1, res1[:flow_out])[!, :y] .==
                filter(r -> r.x1 == av2 && r.x3 == r2, res2[:flow_out])[!, :y]
            )
            if !(all(equal_in) && all(equal_out))
                error("results are not equal for r1=$(r1) and r2=$(r2)")
            end
        end
        return true #no errors have been thrown
    end

    function solve_EMB_case(demand_profile, price_profile, price_profile_stor)
        case_EMB, modeltype_EMB =
            create_case(demand_profile, price_profile, price_profile_stor;
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
        𝒫 = [power, co2]

        #define time structure
        op_dur_vec = [1, 2, 1]
        𝒯 = TwoLevel(1, 1, SimpleTimes(op_dur_vec))
        ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], 3, 3) # optimi and impl horizons

        model = modeltype(
            Dict(co2 => FixedProfile(10)),
            Dict(co2 => FixedProfile(0)), # emission price for CO2
            co2,
        )

        #create individual nodes of the system
        av = GenAvailability("Availability", 𝒫)
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
                StorageInitData(init_state),
                EmptyData() # testing multiple data
            ]),
        )
        sink = RefSink(
            "electricity demand", #node ID or name
            OperationalProfile(demand_profile), #demand in MW (time profile)
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e12)),
            Dict(power => 1), #energy demand and corresponding ratio
        )
        𝒩 = [
            av,
            source,
            storage,
            sink,
        ]
        ℒ = create_links_from_nodes(𝒩)
        case = Dict(
            :nodes => 𝒩, :links => ℒ, :products => 𝒫, :T => 𝒯,
        )

        return case, model
    end

    function create_links_from_nodes(𝒩::Vector{<:EMB.Node})
        av, source, storage, sink = 𝒩
        #connect the nodes with links
        ℒ = [
            Direct("source-av", source, av, Linear()),
            Direct("av-sink", av, sink, Linear()),
            Direct("av-storage", av, storage, Linear()),
            Direct("storage-av", storage, av, Linear()),
        ]
        return ℒ
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
    𝒩ᵣₕ_copy = case_rh_copy[:nodes]

    # Define JuMP.Model
    m_rh = Model(() -> ParametricOptInterface.Optimizer(HiGHS.Optimizer()))
    set_optimizer_attribute(m_rh, MOI.Silent(), true)

    #change to paramtric OperationalProfiles
    case_rh, update_dict, lens_dict =
        POIExt._set_POI_par_as_operational_profile(m_rh, case_rh, case_rh_copy)

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
    n_sink = 𝒩ᵣₕ_copy[end]
    @assert typeof(n_sink) <: Sink
    idx_sink = EMRH._get_node_index(n_sink, case_rh[:nodes])

    # check that POIExt._get_new_POI_values returns the same values as originally provided
    orig_cap_prof =
        POIExt._get_new_POI_values(n_sink, lens_dict[n_sink][Any[:cap, EMRH.OperPath()]])
    @test all(demand_prof .== orig_cap_prof)

    demand_prof2 = POIExt._get_new_POI_values(
        n_sink,
        lens_dict[n_sink][Any[:cap, EMRH.OperPath()]]; multiplier = multiplier)

    @test all(demand_prof2 .== (multiplier .* demand_prof)) #the multiplier works as intended

    #change values of the POI parameters
    m_rh = POIExt._set_values_operational_profile(
        m_rh,
        case_rh_copy,
        𝒩ᵣₕ_copy[idx_sink],
        update_dict,
        lens_dict;
        multiplier = multiplier,
    )

    # change parameter values for the storage node
    n_storage = 𝒩ᵣₕ_copy[3]
    @assert typeof(n_storage) <: Storage
    idx_storage = EMRH._get_node_index(n_storage, case_rh[:nodes])

    # check that POIExt._get_new_POI_values returns the same values as originally provided
    orig_price_prof_stor =
        POIExt._get_new_POI_values(
            n_storage,
            lens_dict[n_storage][Any[:charge, :opex_var, EMRH.OperPath()]]
    )
    @test all(price_prof_stor .== orig_price_prof_stor)

    price_prof_stor2 = POIExt._get_new_POI_values(
        n_storage,
        lens_dict[n_storage][Any[:charge, :opex_var, EMRH.OperPath()]];
        multiplier = multiplier
    )

    @test all(price_prof_stor2 .== (multiplier .* price_prof_stor)) #the multiplier works as intended

    #change values of the POI parameters
    m_rh = POIExt._set_values_operational_profile(
        m_rh,
        case_rh_copy,
        𝒩ᵣₕ_copy[idx_storage],
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

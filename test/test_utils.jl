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
            "electricity source",
            FixedProfile(1e12),
            OperationalProfile([1, 10, 1, 10, 1]),
            FixedProfile(0),
            Dict(power => 1),
        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage",
            StorCapOpexVar(FixedProfile(100), FixedProfile(0.01)),
            StorCapOpexFixed(FixedProfile(1.5), FixedProfile(0)),
            power,
            Dict(power => 1),
            Dict(power => 1),
            Vector([
                StorageInitData(0),
                EmptyData()
            ]),
        ),
        RefSink(
            "electricity demand",
            OperationalProfile([3, 4, 5, 6, 3]),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(power => 1),
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
    EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

    # Extract the case and the model from the `UpdateCase`
    case_rh = Case(𝒯ᵣₕ, get_products(𝒰), get_elements_vec(𝒰), get_couplings(case))
    model_rh = EMRH.updated(EMRH.get_sub_model(𝒰))

    m_rh = run_model(case_rh, model_rh, optimizer)
    @test termination_status(m_rh) == MOI.OPTIMAL

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    res_EMRH = Dict{Symbol,AbstractDataFrame}()
    opers_impl = collect(𝒯)[indices_implementation(hor_test)]
    EMRH.update_results!(res_EMRH, m_rh, 𝒰, opers_impl)
    res_EMB = EMRH.get_results(m_EMB)
    excl_var = [
        # Strategic indexed and empty
        :opex_var, :opex_fixed, :link_opex_var, :link_opex_fixed, :stor_level_Δ_sp,
        # Strategic index variables
        :emissions_strategic,
        # Empty variables
        :emissions_node, :emissions_link, :stor_discharge_inst, :link_cap_inst,
    ]
    # Test that we have the correct keys when we extract the values
    # - If loop in update_results!(results, m, 𝒰, opers)
    # - get_results(m::JuMP.Model)
    # - _get_values_from_obj
    @test Set(keys(res_EMB)) == union(keys(res_EMRH), excl_var)
    res_EMB_df = EMRH.get_results_df(m_EMB)
    @test Set(keys(res_EMB_df)) == union(keys(res_EMRH), excl_var)

    # Extract the empty keys from the EMB dictionary
    res_EMB_red = Dict(k => val for (k, val) ∈ res_EMB if !isempty(val))

    # Test that the extraction results in the correct results for EnergyModelsBase
    # - get_results(m::JuMP.Model)
    @test all(
        all(value.(m_EMB[k][t.x1, t.x2]) == t.y for t ∈ val)
    for (k, val) ∈ res_EMB_red if length(val[1]) == 3)
    @test all(
        all(value.(m_EMB[k][t.x1, t.x2, t.x3]) == t.y for t ∈ val)
    for (k, val) ∈ res_EMB_red if length(val[1]) == 4)

    # Test that the extraction results in the correct results for EnergyModelsRecHorizon
    # - update_results!(results, m, 𝒰, opers)
    # - get_results(m::JuMP.Model)
    # - _get_values_from_obj
    t_dict = Dict(val => k for (k, val) ∈ EMRH.get_sub_periods(𝒰))
    EMRH.updated(𝒰::EMRH.UpdateCase, x_org::TS.TimePeriod) = t_dict[x_org]
    @test all(
        all(
            value.(m_rh[k][EMRH.updated(𝒰, r[:x1]), EMRH.updated(𝒰, r[:x2])]) ==
        r[:y] for r ∈ eachrow(val))
    for (k, val) ∈ res_EMRH if ncol(val) == 3)
    @test all(
        all(
            value.(m_rh[k][
                EMRH.updated(𝒰, r[:x1]), EMRH.updated(𝒰, r[:x2]), EMRH.updated(𝒰, r[:x3])
            ]) ==
        r[:y] for r ∈ eachrow(val))
    for (k, val) ∈ res_EMRH if ncol(val) == 4)
end

@testset "Identification - Nodes" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)
    heat = ResourceCarrier("heat", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [el, heat, co2]

    profile = OperationalProfile([1, 2, 3])
    em_data = [EmissionsProcess(Dict(co2 => profile))]

    struct TestInitData <: AbstractInitData end

    # Create individual nodes to checked for path creation
    av = GenAvailability("Availability", resources)
    source_initdata = RefSource(
        "source",
        FixedProfile(1e12),
        FixedProfile(100),
        FixedProfile(0),
        Dict(el => 1),
        Data[TestInitData()]
    )
    source_oper = RefSource(
        "source",
        FixedProfile(1e12),
        profile,
        FixedProfile(0),
        Dict(el => 1),
    )
    network = RefNetworkNode(
        "el_to_heat",
        FixedProfile(1e12),
        profile,
        FixedProfile(0),
        Dict(el => 1),
        Dict(heat => 1),
        [EmptyData(), EmissionsProcess(Dict(co2 => profile))],
    )
    storage = RefStorage{RecedingAccumulating}(
        "storage",
        StorCapOpexVar(profile, FixedProfile(100)),
        StorCapOpexFixed(profile, FixedProfile(0)),
        el,
        Dict(el => 1),
        Dict(el => 1),
        [StorageInitData(0.5)],
    )
    sink = RefSink(
        "demand",
        profile,
        Dict(
            :surplus => FixedProfile(0),
            :deficit => profile,
        ),
        Dict(heat => 1)
    )
    𝒩 = EMB.Node[av, source_oper, network, storage, sink]

    # Creation of new node type to test that the dictionary with string keys is correctly
    # considered
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

    @testset "Path creation" begin
        # Test of all potential node input from EMRH as called through the function
        # - _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})

        # The individual function flow is included on top

        # Test of a node with no lenses
        # - _find_update_paths(field::Any, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(EMRH._find_update_paths(av), Any[])

        # Test of a node with with a single operational profile
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(source_oper),
            [[:opex_var, EMRH.OperPath()]])

        # Test of a node with operational profile and resource dictionary
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::Vector{<:Data}, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _dict_key(key::Resource)
        @test issetequal(
            EMRH._find_update_paths(network),
            [
                [:opex_var, EMRH.OperPath()],
                [:data, "[2]", :emissions, co2, EMRH.OperPath()]
            ],
        )

        # Test of a storage node with both variations and initial data
        # - _find_update_paths(field::T, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:Union{Data, EMB.AbstractStorageParameters, ElementValue}}
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::Vector{<:Data}, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::InitData, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(storage),
            [
                [:charge, :capacity, EMRH.OperPath()],
                [:level, :capacity, EMRH.OperPath()],
                [:data, "[1]", :init_val_dict, "[:stor_level]", EMRH.InitDataPath(:stor_level)],
            ],
        )

        # Test of a node with operational profile and symbol dictionary
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _dict_key(key::Symbol)
        @test issetequal(
            EMRH._find_update_paths(sink),
            [[:cap, EMRH.OperPath()], [:penalty, "[:deficit]", EMRH.OperPath()]],
        )

        # Test of the new node with string dictionary
        # - _find_update_paths(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _dict_key(key::String)
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(string_dict),
            Any[
                [:profile, "[\"a\"]", EMRH.OperPath()],
                [:profile, "[\"c\"]", EMRH.OperPath()]
            ],
        )

        # Test that init data throws error, when the respective function is not included
        # - _find_update_paths(field::AbstractInitData, current_path::Vector{Any}, all_paths::Vector{Any})
        @test_throws ErrorException EMRH._find_update_paths(source_initdata)
    end

    @testset "Lens creation" begin
        # Create the lenses
        lens_dict = EMRH._create_lens_dict(𝒩)

        # Test that the lenses are created for all nodes
        # - _create_lens_dict(𝒳::Vector{<:AbstractElement}
        # - _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
        # - _create_lens_for_field(field_id::Vector{<:Any})
        @test all(haskey(lens_dict, n) for n ∈ 𝒩)
        @test isempty(lens_dict[av])

        # Test that the individual lenses are correctly created and working
        @test all(
            all(
                lens(n) == profile
            for (field, lens) ∈ lens_dict[n] if isa(typeof(field[end]), EMRH.OperPath))
        for n ∈ 𝒩)
        @test all(
            all(
                lens(n) == 0.5
            for (field, lens) ∈ lens_dict[n] if isa(typeof(field[end]), EMRH.InitDataPath))
        for n ∈ 𝒩)
    end
end


@testset "Identification - Links" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)
    profile = OperationalProfile([1, 2, 3])

    # Create individual nodes to checked for path creation
    src = RefSource(
        "source",
        FixedProfile(1e12),
        profile,
        FixedProfile(0),
        Dict(el => 1),
    )
    sink = RefSink(
        "demand",
        profile,
        Dict(:surplus => FixedProfile(0), :deficit => profile),
        Dict(el => 1)
    )

    # Creation of a new link type with an OperationalProfile
    struct ProfDirect <: Link
        id::Any
        from::EMB.Node
        to::EMB.Node
        formulation::EMB.Formulation
        profile::TimeProfile
    end

    link = ProfDirect(
        "prof_link",
        src,
        sink,
        Linear(),
        profile,
    )

    @testset "Path creation" begin
        # Test of all potential link input from EMRH as called through the function
        # - _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})

        # The individual function flow is included on top

        # Test of a link with operational profile
        # - _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(link),
            [[:from, EMRH.ElementPath()], [:to, EMRH.ElementPath()], [:profile, EMRH.OperPath()]],
        )
    end

    @testset "Lens creation" begin
        ℒ = Link[link]

        # Create the lenses
        lens_dict = EMRH._create_lens_dict(ℒ)

        # Test that the lenses are created for all nodes
        # - _create_lens_dict(𝒳::Vector{<:AbstractElement}
        # - _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
        # - _create_lens_for_field(field_id::Vector{<:Any})
        @test all(haskey(lens_dict, l) for l ∈ ℒ)

        # Test that the individual lenses are correctly created and working
        l = link
        @test lens_dict[l][[:from, EMRH.ElementPath()]](l) == src
        @test lens_dict[l][[:to, EMRH.ElementPath()]](l) == sink
        @test lens_dict[l][[:profile, EMRH.OperPath()]](l) == profile
    end
end

@testset "Identification - Links" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)
    co2 = ResourceEmit("co2", 1.0)

    # Create an operational modeltype
    modeltype = RecHorOperationalModel(
        Dict(co2 => OperationalProfile([100, 100, 100])),
        Dict(co2 => FixedProfile(60)),
        co2,
    )

    @testset "Path creation" begin
        # Test of all potential modelt input from EMRH as called through the function
        # - _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})

        # The individual function flow is included on top

        # Test of a link with operational profile
        # - _find_update_paths(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _dict_key(key::Resource)
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(modeltype),
            [[:emission_limit, co2, EMRH.OperPath()]],
        )
    end

    @testset "Lens creation" begin
        # Create the lenses
        lens_dict = EMRH._create_lens_dict(modeltype)

        # Test that the lenses are created for all nodes
        # - _create_lens_dict(𝒳::Vector{<:AbstractElement}
        # - _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
        # - _create_lens_for_field(field_id::Vector{<:Any})
        @test !isempty(lens_dict)

        # Test that the individual lenses are correctly created and working
        @test lens_dict[[:emission_limit, co2, EMRH.OperPath()]](modeltype).vals ==
            OperationalProfile([100, 100, 100]).vals
    end
end

@testset "Identification - FutureValue" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)
    co2 = ResourceEmit("co2", 1.0)
    profile = OperationalProfile([1, 2, 3])

    # Create individual nodes to checked for path creation
    storage_1 = RefStorage{RecedingAccumulating}(
        "storage_1",
        StorCapOpexVar(profile, FixedProfile(100)),
        StorCapOpexFixed(profile, FixedProfile(0)),
        el,
        Dict(el => 1),
        Dict(el => 1),
        [StorageInitData(0.5)],
    )
    storage_2 = RefStorage{RecedingAccumulating}(
        "storage_2",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)),
        StorCapOpexFixed(FixedProfile(100), FixedProfile(0)),
        el,
        Dict(el => 1),
        Dict(el => 1),
        [StorageInitData(0.5)],
    )

    # Create a StorageValueCuts type
    svcs = StorageValueCuts(
        "wv0", 0, 1, 1,
        [
            StorageValueCut(1, Dict(storage_1 => -50, storage_2 => -70), 0),
            StorageValueCut(2, Dict(storage_1 => -40, storage_2 => -30), 250),
        ]
    )

    @testset "Path creation" begin
        # Test of all potential modelt input from EMRH as called through the function
        # - _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})

        # The individual function flow is included on top

        # Test of a link with operational profile
        # - _find_update_paths(x::StorageValueCuts)
        # - _find_update_paths(field::StorageValueCut, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(svcs),
            Any[
                [:time_weight, EMRH.TimeWeightPath()],
                [:cuts, "[1]", :coeffs, "[1]", :element, EMRH.ElementPath()],
                [:cuts, "[1]", :coeffs, "[2]", :element, EMRH.ElementPath()],
                [:cuts, "[2]", :coeffs, "[1]", :element, EMRH.ElementPath()],
                [:cuts, "[2]", :coeffs, "[2]", :element, EMRH.ElementPath()],
            ],
        )
    end

    @testset "Lens creation" begin
        𝒱 = FutureValue[svcs]

        # Create the lenses
        lens_dict = EMRH._create_lens_dict(𝒱)

        # Test that the lenses are created for all nodes
        # - _create_lens_dict(𝒳::Vector{<:AbstractElement}
        # - _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
        # - _create_lens_for_field(field_id::Vector{<:Any})
        @test all(haskey(lens_dict, v) for v ∈ 𝒱)

        # Test that the individual lenses are correctly created and working
        @test all(
            lens(svcs) ∈ [storage_1, storage_2]
        for (field, lens) ∈ lens_dict[svcs] if isa(typeof(field[end]), EMRH.ElementPath))
        @test lens_dict[svcs][[:time_weight, EMRH.TimeWeightPath()]](svcs) == 1
    end
end

@testset "Lenses and direct reset" begin
    cap_prof = [20, 300]
    em_prof = [1, 2]
    price_prof = [40, 60]
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)

    @testset "Source" begin
        data_source = Data[
            EmissionsProcess(Dict(co2 => OperationalProfile(em_prof))),
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
        paths_source = EMRH._find_update_paths(source)
        @test all(
            paths_source .==
                Any[
                    [:cap, EMRH.OperPath()],
                    [:data, "[1]", :emissions, co2, EMRH.OperPath()]
                ]
        )

        lens_cap = EMRH._create_lens_for_field(paths_source[1])
        lens_emit = EMRH._create_lens_for_field(paths_source[2])
        @test all(cap_prof .== lens_cap(source).vals)
        @test all(em_prof .== lens_emit(source).vals)

        cap_prof_new = [60, 32]
        em_prof_new = [90, 80]
        @reset lens_cap(source) = OperationalProfile(cap_prof_new)
        @reset lens_emit(source) = OperationalProfile(em_prof_new)
        @test all(cap_prof_new .== lens_cap(source).vals)
        @test all(em_prof_new .== lens_emit(source).vals)
    end

    @testset "Sink" begin
        sink = RefSink(
            "sink",
            OperationalProfile(cap_prof),
            Dict(:surplus => FixedProfile(0), :deficit => OperationalProfile(price_prof)),
            Dict(power => 1),
        )

        #checks for sink
        paths = EMRH._find_update_paths(sink)
        @test all(
            paths .==
                Any[[:cap, EMRH.OperPath()], [:penalty, "[:deficit]", EMRH.OperPath()]
            ]
        )

        lens_cap = EMRH._create_lens_for_field(paths[1])
        lens_deficit = EMRH._create_lens_for_field(paths[2])
        @test all(cap_prof .== lens_cap(sink).vals)
        @test all(price_prof .== lens_deficit(sink).vals)

        cap_prof_new = [60, 32]
        price_prof_new = [90, 80]
        @reset lens_cap(sink) = OperationalProfile(cap_prof_new)
        @reset lens_deficit(sink) = OperationalProfile(price_prof_new)
        @test all(cap_prof_new .== lens_cap(sink).vals)
        @test all(price_prof_new .== lens_deficit(sink).vals)
    end

    @testset "Storage" begin
        init_state = 5.0
        data_storage = Vector([
            StorageInitData(init_state),
            EmptyData(),
            EmissionsProcess(Dict(co2 => OperationalProfile(price_prof))),
        ])
        storage = RefStorage{RecedingAccumulating}(
            "storage",
            StorCapOpexVar(OperationalProfile(cap_prof), FixedProfile(100)),
            StorCapOpexFixed(FixedProfile(10), FixedProfile(0)),
            power,
            Dict(power => 1),
            Dict(power => 1),
            data_storage,
        )
        paths_stor = EMRH._find_update_paths(storage)
        @test all(
            paths_stor .==
            Any[
                [:charge, :capacity, EMRH.OperPath()],
                [:data, "[1]", :init_val_dict, "[:stor_level]", EMRH.InitDataPath(:stor_level)],
                [:data, "[3]", :emissions, co2, EMRH.OperPath()],
            ],
        )

        # test getting values
        lens_storage_cap = EMRH._create_lens_for_field(paths_stor[1])
        lens_storage_data = EMRH._create_lens_for_field(paths_stor[3])
        @test all(cap_prof .== lens_storage_cap(storage).vals)
        @test all(price_prof .== lens_storage_data(storage).vals)

        #test resetting values
        cap_prof_new = [60, 32]
        price_prof_new = [90, 80]
        @reset lens_storage_cap(storage) = OperationalProfile(cap_prof_new)
        @reset lens_storage_data(storage) = OperationalProfile(price_prof_new)
        @test all(cap_prof_new .== lens_storage_cap(storage).vals)
        @test all(price_prof_new .== lens_storage_data(storage).vals)
    end

    @testset "NewType with Dict{String,TimeProfile}" begin
        string_dict = StringDict(
            Dict(
                "a" => OperationalProfile([100, 100]),
                "b" => FixedProfile(10),
                "c" => OperationalProfile([20, 40]),
            ),
        )

        paths_node = EMRH._find_update_paths(string_dict)

        #test getting values
        path_a = filter(path -> path[2] == "[\"a\"]", paths_node)
        path_c = filter(path -> path[2] == "[\"c\"]", paths_node)
        lens_a = EMRH._create_lens_for_field(path_a[1])
        lens_c = EMRH._create_lens_for_field(path_c[1])
        @test all([100, 100] .== lens_a(string_dict).vals)
        @test all([20, 40] .== lens_c(string_dict).vals)

        #test resetting values
        cap_prof_new = [60, 32]
        price_prof_new = [90, 80]
        @reset lens_a(string_dict) = OperationalProfile(cap_prof_new)
        @reset lens_c(string_dict) = OperationalProfile(price_prof_new)
        @test all(cap_prof_new .== lens_a(string_dict).vals)
        @test all(price_prof_new .== lens_c(string_dict).vals)
    end
end

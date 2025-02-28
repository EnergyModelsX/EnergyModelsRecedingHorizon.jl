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

    # Create the profiles
    n_op = 15
    dur_op = ones(n_op)
    profile = OperationalProfile(rand(n_op))
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

    @testset "Reset functionality" begin
        # Create an operational modeltype and the time structure
        modeltype = RecHorOperationalModel(
            Dict(co2 => FixedProfile(100)),
            Dict(co2 => FixedProfile(60)),
            co2,
        )

        # Create the update type
        𝒰 = EMRH._create_updatetype(modeltype)
        EMRH._add_elements!(𝒰, 𝒩)

        # Create all time related parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(dur_op))
        opers = collect(𝒯)
        ℋ = PeriodHorizons(dur_op, 4, 2)
        𝒽 = first(ℋ)
        𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽)), SimpleTimes(durations(𝒽)))
        ind_impl = indices_implementation(𝒽)
        opers_opt = opers[indices_optimization(𝒽)]
        opers_impl = opers[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]

        # Test that the individual reset types functions are working
        # All functions are located within the file src/structures/reset.jl
        𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)
        @test 𝒮ᵛᵉᶜ == 𝒰.elements
        @test isa(𝒮ᵛᵉᶜ[1], Vector{EMRH.NodeSub})
        @test EMRH.get_sub_ele(𝒰, EMB.Node) == 𝒰.elements[1]
        @test EMRH.get_sub_ele(𝒮ᵛᵉᶜ, EMB.Node) == 𝒰.elements[1]
        @test isempty(EMRH.resets(𝒮ᵛᵉᶜ[1][1]))

        # Test the source resets (OperReset)
        reset_src = EMRH.resets(𝒮ᵛᵉᶜ[1][2])[1]
        @test isa(reset_src, EMRH.OperReset)
        @test !EMRH.is_init_reset(reset_src)
        @test reset_src.lens(source_oper) == opex_var(source_oper)
        @test reset_src.val == opex_var(source_oper)
        @test isnothing(reset_src.var)

        # Test the storages resets (InitReset)
        reset_storage = EMRH.resets(𝒮ᵛᵉᶜ[1][4])[3]
        @test isa(reset_storage, EMRH.InitReset{EMRH.InitDataPath})
        @test EMRH.is_init_reset(reset_storage)
        @test reset_storage.lens(storage) == EMRH.data_init(storage).init_val_dict[:stor_level]
        @test reset_storage.val == EMRH.data_init(storage).init_val_dict[:stor_level]
        @test isnothing(reset_storage.var)
        @test reset_storage.path == EMRH.InitDataPath(:stor_level)

        # Test that the reset are working
        # - _update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)
        # - _update_case_types!
        # - reset_field
        reset_storage.val = 5
        EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

        # Extract the resetted nodes and test the functionality
        𝒩ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[1]]
        @test all(EMRH.updated(𝒮ᵛᵉᶜ[1], n) == n_new for (n, n_new) ∈ zip(𝒩, 𝒩ʳ))
        @test all(EMRH.updated(𝒰, n) == n_new for (n, n_new) ∈ zip(𝒩, 𝒩ʳ))
        @test all(EMRH.original(𝒮ᵛᵉᶜ[1], n_new) == n for (n, n_new) ∈ zip(𝒩, 𝒩ʳ))
        @test all(EMRH.original(𝒰, n_new) == n for (n, n_new) ∈ zip(𝒩, 𝒩ʳ))
        @test get_elements_vec(𝒰) == Vector[𝒩ʳ]
        @test get_nodes(𝒰) == 𝒩ʳ
        @test 𝒩ʳ ≠ 𝒩

        # Test the individual resets
        @test all(opex_var(𝒩ʳ[k]).vals == opex_var(𝒩[k])[opers_opt] for k ∈ [2,3])
        @test EMRH.data_init(𝒩ʳ[4]).init_val_dict[:stor_level] == 5.0
        @test deficit_penalty(𝒩ʳ[5]).vals == deficit_penalty(𝒩[5])[opers_opt]
    end
end


@testset "Identification - Links" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)

    # Create the profile
    n_op = 15
    dur_op = ones(n_op)
    profile = OperationalProfile(rand(n_op))

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
    𝒩 = [src, sink]

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
    ℒ = Link[link]

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

    @testset "Reset functionality" begin
        # Create an operational modeltype and the time structure
        modeltype = RecHorOperationalModel(
            Dict(co2 => FixedProfile(100)),
            Dict(co2 => FixedProfile(60)),
            co2,
        )

        # Create the update type
        𝒰 = EMRH._create_updatetype(modeltype)
        EMRH._add_elements!(𝒰, 𝒩)
        EMRH._add_elements!(𝒰, ℒ)

        # Create all time related parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(dur_op))
        opers = collect(𝒯)
        ℋ = PeriodHorizons(dur_op, 4, 2)
        𝒽 = first(ℋ)
        𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽)), SimpleTimes(durations(𝒽)))
        ind_impl = indices_implementation(𝒽)
        opers_opt = opers[indices_optimization(𝒽)]
        opers_impl = opers[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]

        # Test that the individual reset types functions are working
        # All functions are located within the file src/structures/reset.jl
        𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)
        @test 𝒮ᵛᵉᶜ == 𝒰.elements
        @test isa(𝒮ᵛᵉᶜ[2], Vector{EMRH.LinkSub})
        @test EMRH.get_sub_ele(𝒰, EMB.Link) == 𝒰.elements[2]
        @test EMRH.get_sub_ele(𝒮ᵛᵉᶜ, EMB.Link) == 𝒰.elements[2]

        # Test the resets (ElementReset)
        reset_link = EMRH.resets(𝒮ᵛᵉᶜ[2][1])
        @test all(isa(reset_link[k], EMRH.ElementReset) for k ∈ [1,2])
        @test reset_link[1].lens(link) == src
        @test reset_link[1].val == src
        @test reset_link[2].lens(link) == sink
        @test reset_link[2].val == sink

        # Test that the reset are working
        # - _update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)
        # - _update_case_types!
        # - reset_field
        EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

        # Extract the resetted nodes and links
        𝒩ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[1]]
        ℒʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[2]]
        @test get_elements_vec(𝒰) == Vector[𝒩ʳ, ℒʳ]
        @test get_links(𝒰) == ℒʳ
        @test 𝒩ʳ ≠ 𝒩
        @test ℒʳ ≠ ℒ

        # Test that the nodes are reset
        @test opex_var(𝒩ʳ[1]).vals == opex_var(𝒩[1])[opers_opt]
        @test capacity(𝒩ʳ[2]).vals == capacity(𝒩[2])[opers_opt]

        # Test the individual resets of the link
        @test ℒʳ[1].from == 𝒩ʳ[1]
        @test ℒʳ[1].to == 𝒩ʳ[2]
        @test ℒʳ[1].profile.vals == ℒ[1].profile[opers_opt]
    end
end

@testset "Identification - modeltype" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)
    co2 = ResourceEmit("co2", 1.0)

    # Create the profile
    n_op = 15
    dur_op = ones(n_op)
    profile = OperationalProfile(rand(n_op))

    # Create an operational modeltype
    modeltype = RecHorOperationalModel(
        Dict(co2 => profile),
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
        profile.vals
    end

    @testset "Reset functionality" begin
        # Create the update type
        𝒰 = EMRH._create_updatetype(modeltype)

        # Create all time related parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(dur_op))
        opers = collect(𝒯)
        ℋ = PeriodHorizons(dur_op, 4, 2)
        𝒽 = first(ℋ)
        𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽)), SimpleTimes(durations(𝒽)))
        ind_impl = indices_implementation(𝒽)
        opers_opt = opers[indices_optimization(𝒽)]
        opers_impl = opers[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]

        # Test that the individual reset types functions are working
        # All functions are located within the file src/structures/reset.jl
        sᵐ = EMRH.get_sub_model(𝒰)
        @test isa(EMRH.resets(sᵐ)[1], EMRH.OperReset)

        # Test that the reset are working
        # - _update_case_types!
        # - reset_field
        EMRH._update_case_types!(sᵐ, 𝒰, opers)
        modeltypeᵣₕ = sᵐ.new
        @test modeltypeᵣₕ == EMRH.updated(sᵐ)
        @test modeltypeᵣₕ ≠ modeltype
        @test modeltype == sᵐ.org
        @test modeltype == EMRH.original(sᵐ)
        @test emission_limit(modeltypeᵣₕ, co2).vals == emission_limit(modeltype, co2)[opers]
    end
end

@testset "Identification - FutureValue" begin
    # Create the individual resources
    el = ResourceCarrier("el", 0.2)
    co2 = ResourceEmit("co2", 1.0)

    # Create the profile
    n_op = 15
    dur_op = ones(n_op)
    profile = OperationalProfile(rand(n_op))

    # Create individual nodes to checked for path creation
    storage_1 = RefStorage{RecedingAccumulating}(
        "storage_1",
        StorCapOpexVar(profile, FixedProfile(40)),
        StorCapOpexFixed(FixedProfile(100), FixedProfile(0)),
        el,
        Dict(el => 1),
        Dict(el => 1),
        [StorageInitData(0.5)],
    )
    storage_2 = RefStorage{RecedingAccumulating}(
        "storage_2",
        StorCapOpexVar(profile, FixedProfile(100)),
        StorCapOpexFixed(FixedProfile(1000), FixedProfile(0)),
        el,
        Dict(el => 1),
        Dict(el => 1),
        [StorageInitData(0.5)],
    )
    𝒩 = [storage_1, storage_2]

    # Create a StorageValueCuts type
    svcs = StorageValueCuts(
        "wv0", 0, 1, 1,
        [
            StorageValueCut(1, Dict(storage_1 => -50, storage_2 => -70), 0),
            StorageValueCut(2, Dict(storage_1 => -40, storage_2 => -30), 250),
        ]
    )
    𝒱 = [svcs]

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

    @testset "Reset functionality" begin
        # Create an operational modeltype and the time structure
        modeltype = RecHorOperationalModel(
            Dict(co2 => FixedProfile(100)),
            Dict(co2 => FixedProfile(60)),
            co2,
        )

        # Create the update type
        𝒰 = EMRH._create_updatetype(modeltype)
        EMRH._add_elements!(𝒰, 𝒩)
        EMRH._add_elements!(𝒰, 𝒱)

        # Create all time related parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(dur_op))
        opers = collect(𝒯)
        ℋ = PeriodHorizons(dur_op, 4, 2)
        𝒽 = first(ℋ)
        𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽)), SimpleTimes(durations(𝒽)))
        ind_impl = indices_implementation(𝒽)
        opers_opt = opers[indices_optimization(𝒽)]
        opers_impl = opers[ind_impl]
        opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]

        # Test that the individual reset types functions are working
        # All functions are located within the file src/structures/reset.jl
        𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)
        @test isa(𝒮ᵛᵉᶜ[2], Vector{EMRH.FutureValueSub})
        @test EMRH.get_sub_ele(𝒰, EMRH.FutureValue) == 𝒰.elements[2]
        @test EMRH.get_sub_ele(𝒮ᵛᵉᶜ, EMRH.FutureValue) == 𝒰.elements[2]

        # Test the resets (ElementReset)
        reset_cuts = EMRH.resets(𝒮ᵛᵉᶜ[2][1])
        @test isa(reset_cuts[1], EMRH.TimeWeightReset)
        @test all(isa(reset_cuts[k], EMRH.ElementReset) for k ∈ [2,3,4,5])
        @test reset_cuts[1].lens(svcs) == 1
        @test isnothing(reset_cuts[1].var)
        @test reset_cuts[1].val == 1
        @test reset_cuts[2].lens(svcs) == storage_1
        @test reset_cuts[2].val == storage_1
        @test reset_cuts[3].lens(svcs) == storage_2
        @test reset_cuts[3].val == storage_2
        @test reset_cuts[4].lens(svcs) == storage_1
        @test reset_cuts[4].val == storage_1
        @test reset_cuts[5].lens(svcs) == storage_2
        @test reset_cuts[5].val == storage_2

        # Test that the reset are working
        # - _update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)
        # - _update_case_types!
        # - reset_field
        EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

        # Extract the resetted nodes and links
        𝒩ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[1]]
        𝒱ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[2]]
        @test get_elements_vec(𝒰) == Vector[𝒩ʳ, 𝒱ʳ]
        @test get_future_value(𝒰) == 𝒱ʳ
        @test 𝒩ʳ ≠ 𝒩
        @test 𝒱ʳ ≠ 𝒱

        # Test that the nodes are reset
        @test capacity(charge(𝒩ʳ[1])).vals == capacity(charge(𝒩[1]))[opers_opt]
        @test capacity(charge(𝒩ʳ[2])).vals == capacity(charge(𝒩[2]))[opers_opt]

        # Test the individual resets of the link
        @test 𝒱ʳ[1].cuts[1].coeffs[1].element == 𝒩ʳ[1]
        @test 𝒱ʳ[1].cuts[1].coeffs[2].element == 𝒩ʳ[2]
        @test 𝒱ʳ[1].cuts[2].coeffs[1].element == 𝒩ʳ[1]
        @test 𝒱ʳ[1].cuts[2].coeffs[2].element == 𝒩ʳ[2]
    end
end

@testset "Identification - Area" begin
    # Create the individual resources
    H2_hp = ResourceCarrier("H2_hp", 0.0)
    H2_lp = ResourceCarrier("H2_lp", 0.0)
    el = ResourceCarrier("Power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [H2_hp, H2_lp, el, co2]

    # Create the profiles
    n_op = 15
    dur_op = ones(n_op)
    prof_1 = OperationalProfile(rand(n_op))
    prof_2 = OperationalProfile(rand(n_op))

    # Create the Transmission corridors
    av = GeoAvailability(1, resources)
    𝒩 = EMB.Node[av]
    a_1 = RefArea(2, "RefArea", 1, 1, av)
    a_2 = LimitedExchangeArea(1, "LEArea", 1, 1, av, Dict(H2_hp => prof_1, el => prof_2))
    𝒜 = [a_1, a_2]

    @testset "Access functions" begin
        # Test for identifying initialization data
        # - has_init(a::Area)
        @test !has_init(a_1)
        # Test for extracting initialization data
        # - data_init(a::Area)
        @test isnothing(EMRH.data_init(a_1))
    end


    @testset "Path creation" begin
        # Test of all potential node input from EMRH as called through the function
        # - _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})

        # The individual function flow is included on top

        # Test of a transmission corridor with two modes
        # - _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(a_1),
            [
                [:node, EMRH.ElementPath()],
            ],
        )

        # Test of a transmission corridor with a pipeline mode
        # - _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _dict_key(key::Resource)
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(a_2),
            [
                [:node, EMRH.ElementPath()],
                [:limit, el, EMRH.OperPath()],
                [:limit, H2_hp, EMRH.OperPath()],
            ],
        )
    end

    @testset "Lens creation" begin
        # Create the lenses
        lens_dict = EMRH._create_lens_dict(𝒜)

        # Test that the lenses are created for all transmission corridors
        # - _create_lens_dict(𝒳::Vector{<:AbstractElement}
        # - _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
        # - _create_lens_for_field(field_id::Vector{<:Any})
        @test all(haskey(lens_dict, a) for a ∈ 𝒜)

        # Test that the individual lenses are correctly created and working
        @test lens_dict[a_1][[:node, EMRH.ElementPath()]](a_1) == av

        @test lens_dict[a_2][[:node, EMRH.ElementPath()]](a_2) == av
        @test lens_dict[a_2][[:limit, H2_hp, EMRH.OperPath()]](a_2) == prof_1
        @test lens_dict[a_2][[:limit, el, EMRH.OperPath()]](a_2) == prof_2
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
        EMRH._add_elements!(𝒰, 𝒜)

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
        @test isa(𝒮ᵛᵉᶜ[2], Vector{EMGExt.AreaSub})
        @test EMRH.get_sub_ele(𝒰, Area) == 𝒰.elements[2]
        @test EMRH.get_sub_ele(𝒮ᵛᵉᶜ, Area) == 𝒰.elements[2]

        # Test the resets (ElementReset)
        reset_area = EMRH.resets(𝒮ᵛᵉᶜ[2][1])
        @test isa(reset_area[1], EMRH.ElementReset)

        reset_area = EMRH.resets(𝒮ᵛᵉᶜ[2][2])
        @test isa(reset_area[1], EMRH.ElementReset)
        @test reset_area[1].lens(a_2) == av
        @test reset_area[1].val == av

        # Test that the reset are working
        # - _update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)
        # - _update_case_types!
        # - reset_field
        EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

        # Extract the resetted nodes and areas
        𝒩ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[1]]
        𝒜ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[2]]
        @test get_elements_vec(𝒰) == Vector[𝒩ʳ, 𝒜ʳ]
        @test get_areas(𝒰) == 𝒜ʳ
        @test 𝒜ʳ ≠ 𝒜
        @test 𝒩ʳ ≠ 𝒩

        # Test the individual resets of the areas
        @test availability_node(𝒜ʳ[1]) == 𝒩ʳ[1]
        @test availability_node(𝒜ʳ[2]) == 𝒩ʳ[1]
        @test exchange_limit(𝒜ʳ[2], H2_hp).vals == prof_1[opers_opt]
        @test exchange_limit(𝒜ʳ[2], el).vals == prof_2[opers_opt]
    end
end

@testset "Identification - TransmissionMode" begin
    # Create the individual resources
    H2_hp = ResourceCarrier("H2_hp", 0.0)
    H2_lp = ResourceCarrier("H2_lp", 0.0)
    el = ResourceCarrier("Power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [H2_hp, H2_lp, el, co2]

    # Create the profiles
    n_op = 15
    dur_op = ones(n_op)
    prof_1 = OperationalProfile(rand(n_op))
    prof_2 = OperationalProfile(rand(n_op))
    init_lp = TransInitData(Dict(:linepack_stor_level => 1.0))

    # Initialize the individual modes of the corridors
    static = RefStatic(
        "static",
        co2,
        prof_1,
        FixedProfile(0.01),
        FixedProfile(0.1),
        FixedProfile(1),
        2,
    )
    dynamic = RefDynamic(
        "dynamic",
        el,
        FixedProfile(30.0),
        prof_2,
        FixedProfile(0.1),
        FixedProfile(1),
        2,
    )
    pipe = PipeSimple(
        "pipe",
        H2_hp,
        H2_lp,
        el,
        prof_1,
        FixedProfile(20),
        FixedProfile(0.01),
        prof_2,
        FixedProfile(2.5),
    )
    pipe_linepack = PipeLinepackSimple(
        "pipe_linepack",
        H2_hp,
        H2_lp,
        el,
        FixedProfile(0.05),
        FixedProfile(50),
        FixedProfile(0.01),
        FixedProfile(0.1),
        FixedProfile(1.0),
        0.1,
        [init_lp]
    )

    # Create the Transmission corridors
    av = GeoAvailability(1, resources)
    𝒩 = EMB.Node[av]
    a_1 = RefArea(2, "RefArea", 1, 1, av)
    a_2 = LimitedExchangeArea(1, "LEArea", 1, 1, av, Dict(H2_hp => prof_1, el => prof_2))
    𝒜 = [a_1, a_2]
    l_stat_dyn = Transmission(a_1, a_2, [static, dynamic])
    l_pipe = Transmission(a_1, a_2, [pipe, pipe_linepack])
    ℒᵗʳᵃⁿˢ = [l_stat_dyn, l_pipe]

    @testset "Access functions" begin
        # Test for identifying initialization data
        # - has_init(l::Transmission)
        # - data_init(tm::TransmissionMode)
        @test !has_init(pipe)
        @test has_init(pipe_linepack)
        @test !has_init(l_stat_dyn)
        @test has_init(l_pipe)

        # Test for extracting initialization data
        # - data_init(l::Transmission)
        # - data_init(tm::TransmissionMode)
        @test EMRH.data_init(l_stat_dyn) == [nothing, nothing]
        @test EMRH.data_init(l_pipe) == [nothing, init_lp]
    end

    @testset "Path creation" begin
        # Test of all potential node input from EMRH as called through the function
        # - _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})

        # The individual function flow is included on top

        # Test of a transmission corridor with two modes
        # - _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::T, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:TransmissionMode}
        # - _find_update_paths(field::Vector{<:T}, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:TransmissionMode}
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(l_stat_dyn),
            [
                [:from, EMRH.ElementPath()],
                [:to, EMRH.ElementPath()],
                [:modes, "[1]", :trans_cap, EMRH.OperPath()],
                [:modes, "[2]", :trans_loss, EMRH.OperPath()],
            ],
        )

        # Test of a transmission corridor with a pipeline mode
        # - _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::T, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:TransmissionMode}
        # - _find_update_paths(field::Vector{<:T}, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:TransmissionMode}
        # - _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
        # - _find_update_paths(field::TransInitData, current_path::Vector{Any}, all_paths::Vector{Any})
        @test issetequal(
            EMRH._find_update_paths(l_pipe),
            [
                [:from, EMRH.ElementPath()],
                [:to, EMRH.ElementPath()],
                [:modes, "[1]", :consumption_rate, EMRH.OperPath()],
                [:modes, "[1]", :opex_var, EMRH.OperPath()],
                [
                    :modes, "[2]", :data, "[1]", :init_val_dict,
                    "[:linepack_stor_level]", EMGExt.TransInitDataPath(2, :linepack_stor_level)
                ]
            ],
        )
    end

    @testset "Lens creation" begin
        # Create the lenses
        lens_dict = EMRH._create_lens_dict(ℒᵗʳᵃⁿˢ)

        # Test that the lenses are created for all transmission corridors
        # - _create_lens_dict(𝒳::Vector{<:AbstractElement}
        # - _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
        # - _create_lens_for_field(field_id::Vector{<:Any})
        @test all(haskey(lens_dict, l) for l ∈ ℒᵗʳᵃⁿˢ)

        # Test that the individual lenses are correctly created and working
        l = l_stat_dyn
        @test lens_dict[l][[:from, EMRH.ElementPath()]](l) == a_1
        @test lens_dict[l][[:to, EMRH.ElementPath()]](l) == a_2
        @test lens_dict[l][[:modes, "[1]", :trans_cap, EMRH.OperPath()]](l) == prof_1
        @test lens_dict[l][[:modes, "[2]", :trans_loss, EMRH.OperPath()]](l) == prof_2

        l = l_pipe
        @test lens_dict[l][[:from, EMRH.ElementPath()]](l) == a_1
        @test lens_dict[l][[:to, EMRH.ElementPath()]](l) == a_2
        @test lens_dict[l][[:modes, "[1]", :consumption_rate, EMRH.OperPath()]](l) == prof_1
        @test lens_dict[l][[:modes, "[1]", :opex_var, EMRH.OperPath()]](l) == prof_2
        @test lens_dict[l][[
            :modes, "[2]", :data, "[1]", :init_val_dict,
            "[:linepack_stor_level]", EMGExt.TransInitDataPath(2, :linepack_stor_level)]
        ](l) == 1.0
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
        EMRH._add_elements!(𝒰, 𝒜)
        EMRH._add_elements!(𝒰, ℒᵗʳᵃⁿˢ)

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
        # All functions are located within the file src/structures/reset.jl and
        # ext/EMGExt/structures/reset.jl
        𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)
        𝒮ᵛᵉᶜᵢₙ = [filter(has_init, 𝒮) for 𝒮 ∈ 𝒮ᵛᵉᶜ]
        @test isa(𝒮ᵛᵉᶜ[3], Vector{EMGExt.TransmissionSub})
        @test EMRH.get_sub_ele(𝒰, Transmission) == 𝒰.elements[3]
        @test EMRH.get_sub_ele(𝒮ᵛᵉᶜ, Transmission) == 𝒰.elements[3]
        @test 𝒮ᵛᵉᶜᵢₙ == [EMRH.NodeSub[], EMGExt.AreaSub[], [𝒮ᵛᵉᶜ[3][2]]]

        # Test the resets (ElementReset)
        reset_trans = EMRH.resets(𝒮ᵛᵉᶜ[3][1])
        l = l_stat_dyn
        @test all(isa(reset_trans[k], EMRH.ElementReset) for k ∈ [1,2])
        @test reset_trans[1].lens(l) == a_1
        @test reset_trans[1].val == a_1
        @test reset_trans[2].lens(l) == a_2
        @test reset_trans[2].val == a_2

        # Test the resets (InitReset)
        reset_trans = EMRH.resets(𝒮ᵛᵉᶜ[3][2])
        l = l_pipe
        @test isa(reset_trans[5], EMRH.InitReset)

        # Test that the reset are working
        # - _update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)
        # - _update_case_types!
        # - reset_field
        EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

        # Extract the resetted nodes, areas, and transmission corridors
        𝒩ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[1]]
        𝒜ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[2]]
        ℒᵗʳᵃⁿˢ⁻ʳ = [s.new for s ∈ 𝒮ᵛᵉᶜ[3]]
        @test get_elements_vec(𝒰) == Vector[𝒩ʳ, 𝒜ʳ, ℒᵗʳᵃⁿˢ⁻ʳ]
        @test get_transmissions(𝒰) == ℒᵗʳᵃⁿˢ⁻ʳ
        @test 𝒩ʳ ≠ 𝒩
        @test 𝒜ʳ ≠ 𝒜
        @test ℒᵗʳᵃⁿˢ⁻ʳ ≠ ℒᵗʳᵃⁿˢ

        # Test the individual resets of the transmission corridor
        @test ℒᵗʳᵃⁿˢ⁻ʳ[1].from == 𝒜ʳ[1]
        @test ℒᵗʳᵃⁿˢ⁻ʳ[1].to == 𝒜ʳ[2]
        @test ℒᵗʳᵃⁿˢ⁻ʳ[1].modes[1].trans_cap.vals == prof_1[opers_opt]
        @test ℒᵗʳᵃⁿˢ⁻ʳ[1].modes[2].trans_loss.vals == prof_2[opers_opt]

        @test ℒᵗʳᵃⁿˢ⁻ʳ[2].from == 𝒜ʳ[1]
        @test ℒᵗʳᵃⁿˢ⁻ʳ[2].to == 𝒜ʳ[2]
        @test ℒᵗʳᵃⁿˢ⁻ʳ[2].modes[1].consumption_rate.vals == prof_1[opers_opt]
        @test ℒᵗʳᵃⁿˢ⁻ʳ[2].modes[1].opex_var.vals == prof_2[opers_opt]

        # Test that the function original and updated are working for `TransmissionMode`
        # - updated(𝒰::UpdateCase, tm_org::TransmissionMode)
        # - original(𝒰::UpdateCase, tm_new::TransmissionMode)
        ℳ = modes(ℒᵗʳᵃⁿˢ)
        ℳʳ = modes(ℒᵗʳᵃⁿˢ⁻ʳ)
        @test all(EMRH.updated(𝒰, tm_old) == tm_new for (tm_old, tm_new) ∈ zip(ℳ, ℳʳ))
        @test all(EMRH.original(𝒰, tm_new) == tm_old for (tm_old, tm_new) ∈ zip(ℳ, ℳʳ))
    end
end

@testset "Full model run" begin
    # Introduction of profiles
    demand_profile = [20, 10, 5, 25, 20, 10, 5, 25]
    pipe_profile = [10, 10, 10, 10, 0, 10, 10, 10]

    # Create the individual resources
    H2_hp = ResourceCarrier("H2_hp", 0.0)
    H2_lp = ResourceCarrier("H2_lp", 0.0)
    el = ResourceCarrier("Power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [H2_hp, H2_lp, el, co2]

    # Creation of the source and sink module as well as the arrays used for nodes and links
    h2_src = RefSource(
        "h2_src",
        FixedProfile(30),
        OperationalProfile([25, 20, 40, 80, 20, 30, 10, 90]),
        FixedProfile(0),
        Dict(H2_hp => 1),
    )
    el_src = RefSource(
        "el_src",
        FixedProfile(3),
        FixedProfile(0),
        FixedProfile(0),
        Dict(el => 1),
    )
    sink = RefSink(
        "snk",
        OperationalProfile(demand_profile),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(100)),
        Dict(H2_lp => 1),
    )

    nodes = [
        GeoAvailability(1, resources), h2_src, el_src,
        GeoAvailability(2, resources), sink]

    links = [
        Direct(31, nodes[2], nodes[1], Linear())
        Direct(31, nodes[3], nodes[1], Linear())
        Direct(24, nodes[4], nodes[5], Linear())
    ]

    init_lp = TransInitData(Dict(:linepack_stor_level => 1.0))

    pipe = PipeSimple(
        "pipe",
        H2_hp,
        H2_lp,
        el,
        FixedProfile(0.01),
        OperationalProfile(pipe_profile),
        FixedProfile(0.0),
        FixedProfile(0),
        FixedProfile(0),
    )
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
        [init_lp],
    )
    modes = [pipe, pipe_lp]

    # Creation of the two areas and potential transmission lines
    areas = [RefArea(1, "Oslo", 10.751, 59.921, nodes[1]),
            RefArea(2, "Trondheim", 10.398, 63.4366, nodes[4])]

    transmissions = [Transmission(areas[1], areas[2], modes)]

    # Creation of the time structure and the used global data
    T = TwoLevel(1, 1, SimpleTimes(8, 1);)
    ops = collect(T)
    ℋ = PeriodHorizons([duration(t) for t ∈ T], 4, 2)
    modeltype = RecHorOperationalModel(
                                Dict(co2 => FixedProfile(100)),
                                Dict(co2 => FixedProfile(0)),
                                co2,
    )

    # Input data structure
    case = Case(
        T,
        resources,
        [nodes, links, areas, transmissions],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
        Dict(:horizons => ℋ)
    )

    # Create the model and run it
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    results = run_model_rh(case, modeltype, optimizer)

    # Test that all results were saved (* 2 as we have two TransmissionModes)
    @test length(results[:trans_in][!, :y]) == length(ops) * 2

    # Test that the first period in the first horizon is correctly used
    @test mode_data(pipe_lp)[1].init_val_dict[:linepack_stor_level] ≈
          filter(r -> r.x1 == pipe_lp && r.x2 == ops[1], results[:linepack_stor_level])[1, :y] -
          filter(r -> r.x1 == pipe_lp && r.x2 == ops[1], results[:trans_in])[1, :y] +
          filter(r -> r.x1 == pipe_lp && r.x2 == ops[1], results[:trans_out])[1, :y] +
          filter(r -> r.x1 == pipe_lp && r.x2 == ops[1], results[:trans_loss])[1, :y]

    # Test that the subsequent first periods are used correctly
    first_ops = [ops[3], ops[5], ops[7]]
    last_ops = [ops[2], ops[4], ops[6]]
    @test all(
        filter(r -> r.x1 == pipe_lp && r.x2 == last_ops[k], results[:linepack_stor_level])[1, :y] ≈
            filter(r -> r.x1 == pipe_lp && r.x2 == first_ops[k], results[:linepack_stor_level])[1, :y] -
            filter(r -> r.x1 == pipe_lp && r.x2 == first_ops[k], results[:trans_in])[1, :y] +
            filter(r -> r.x1 == pipe_lp && r.x2 == first_ops[k], results[:trans_out])[1, :y] +
            filter(r -> r.x1 == pipe_lp && r.x2 == first_ops[k], results[:trans_loss])[1, :y]
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

    # Test that the mode capacities are equal to the values
    @test all(
        filter(r -> r.x1 == pipe && r.x2 == ops[k], results[:trans_cap])[1, :y] ==
        pipe_profile[k] for k ∈ 1:8
    )

    @test all(
        filter(r -> r.x1 == pipe_lp && r.x2 == ops[k], results[:trans_cap])[1, :y] ==
        50 for k ∈ 1:8
    )
end

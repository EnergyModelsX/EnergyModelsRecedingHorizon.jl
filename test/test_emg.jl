using EnergyModelsGeography
const EMG = EnergyModelsGeography
const EMGExt = Base.get_extension(EMRH, :EMGExt)

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

    # Create the Transmission corridors
    av = GeoAvailability(1, resources)
    𝒩 = EMB.Node[av]
    a_1 = RefArea(2, "RefArea", 1, 1, av)
    a_2 = LimitedExchangeArea(1, "LEArea", 1, 1, av, Dict(H2_hp => prof_1, el => prof_2))
    𝒜 = [a_1, a_2]
    l_stat_dyn = Transmission(a_1, a_2, [static, dynamic])
    l_pipe = Transmission(a_1, a_2, [pipe])
    ℒᵗʳᵃⁿˢ = [l_stat_dyn, l_pipe]

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
        @test issetequal(
            EMRH._find_update_paths(l_pipe),
            [
                [:from, EMRH.ElementPath()],
                [:to, EMRH.ElementPath()],
                [:modes, "[1]", :consumption_rate, EMRH.OperPath()],
                [:modes, "[1]", :opex_var, EMRH.OperPath()],
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
        # All functions are located within the file src/structures/reset.jl
        𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)
        @test isa(𝒮ᵛᵉᶜ[3], Vector{EMGExt.TransmissionSub})
        @test EMRH.get_sub_ele(𝒰, Transmission) == 𝒰.elements[3]
        @test EMRH.get_sub_ele(𝒮ᵛᵉᶜ, Transmission) == 𝒰.elements[3]

        # Test the resets (ElementReset)
        reset_trans = EMRH.resets(𝒮ᵛᵉᶜ[3][1])
        l = l_stat_dyn
        @test all(isa(reset_trans[k], EMRH.ElementReset) for k ∈ [1,2])
        @test reset_trans[1].lens(l) == a_1
        @test reset_trans[1].val == a_1
        @test reset_trans[2].lens(l) == a_2
        @test reset_trans[2].val == a_2

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
    end
end

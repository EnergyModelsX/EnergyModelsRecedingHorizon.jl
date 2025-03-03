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
    a_1 = RefArea(2, "RefArea", 1, 1, av)
    a_2 = LimitedExchangeArea(1, "LEArea", 1, 1, av, Dict(el => prof_2))
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
end

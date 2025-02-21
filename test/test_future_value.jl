@testset "StorageValueCut" begin
    # Introduce the node type for testing
    Power = ResourceCarrier("Power", 0.0)
    storage = RefStorage{RecedingAccumulating}(
        "storage",  # Node ID
        StorCap(FixedProfile(10)), # Charge
        StorCap(FixedProfile(100)), # level, UnionCap
        Power,              # stor_res, stored resource
        Dict(Power => 1),
        Dict(Power => 1),
        [
            StorageInitData(0)
        ]
    )
    # Create the StorageValueCut type
    svc = StorageValueCut("stor_1", [ElementValue(storage, 1)], 5)

    # Test that the access functions are working
    @test EMRH.cut_rhs(svc) == 5
    @test EMRH.coefficients(svc) == [(storage, 1)]
end

@testset "StorageValueCuts" begin
    @testset "Access functions" begin
        # Create the StorageValueCut type
        Power = ResourceCarrier("Power", 0.0)
        storage = RefStorage{RecedingAccumulating}(
            "storage",  # Node ID
            StorCap(FixedProfile(10)), # Charge
            StorCap(FixedProfile(100)), # level, UnionCap
            Power,              # stor_res, stored resource
            Dict(Power => 1),
            Dict(Power => 1),
            [StorageInitData(0)],
        )
        storage_value_cut = StorageValueCut("stor_1", [ElementValue(storage, 1)], 5)

        # Function for creating different StorageValueCuts
        stor_val_cuts(svc::StorageValueCut, time_profile::Vector) =
            [StorageValueCuts(j, k, j, j, [svc]) for (j, k) ∈ enumerate(time_profile)]

        time_vec = [0, 10, 10, 40, 70]
        𝒱 = stor_val_cuts(storage_value_cut, time_vec)

        # Test that the access functions are working
        @test all(EMRH.weight(𝒱[k]) == k for k ∈ eachindex(𝒱))
        @test all(EMRH.time_weight(𝒱[k]) == k for k ∈ eachindex(𝒱))
        @test all(EMRH.cuts_time(𝒱[k]) == time_vec[k] for k ∈ eachindex(𝒱))
        @test all(EMRH.cuts(𝒱[k]) == [storage_value_cut] for k ∈ eachindex(𝒱))
    end

    @testset "Resetting of values" begin
        # Create the StorageValueCuts type
        Power = ResourceCarrier("Power", 0.0)
        CO2 = ResourceEmit("CO2", 1.0)
        stor_a = RefStorage{RecedingAccumulating}(
            "stor_a",
            StorCap(FixedProfile(10)),
            StorCap(FixedProfile(100)),
            Power,
            Dict(Power => 1),
            Dict(Power => 1),
            [StorageInitData(0)],
        )
        stor_b = RefStorage{RecedingAccumulating}(
            "stor_b",
            StorCap(FixedProfile(10)),
            StorCap(FixedProfile(100)),
            Power,
            Dict(Power => 1),
            Dict(Power => 1),
            [StorageInitData(0)],
        )
        𝒩 = [stor_a, stor_b]

        model = RecHorOperationalModel(
            Dict(CO2 => FixedProfile(10)), #upper bound for CO2 in t/8h
            Dict(CO2 => FixedProfile(0)), # emission price for CO2 in EUR/t
            CO2,
        )

        stor_val_cuts(time_profile::Vector) = [
            StorageValueCuts(j, k, j, j,
                [
                    StorageValueCut(1, Dict(stor_a => -j*2, stor_b => -j*5), 0),
                    StorageValueCut(1, Dict(stor_a => -j*2, stor_b => -j*5), 0),
                ]
            )
        for (j, k) ∈ enumerate(time_profile)]

        # Create the cuts
        time_vec = [0, 10, 10, 40, 70]
        𝒱 = stor_val_cuts(time_vec)

        # Test that the path is correctly created
        # - _find_update_paths(x::StorageValueCuts)
        @test all(issetequal(
            EMRH._find_update_paths(v),
            Any[
                [:time_weight, EMRH.TimeWeightPath()],
                [:cuts, "[1]", :coeffs, "[1]", :element, EMRH.ElementPath()],
                [:cuts, "[1]", :coeffs, "[2]", :element, EMRH.ElementPath()],
                [:cuts, "[2]", :coeffs, "[1]", :element, EMRH.ElementPath()],
                [:cuts, "[2]", :coeffs, "[2]", :element, EMRH.ElementPath()],
            ],
        ) for v ∈ 𝒱)

        # Create the Update type
        𝒰 = EMRH._create_updatetype(model)
        EMRH._add_elements!(𝒰, 𝒩)
        EMRH._add_elements!(𝒰, 𝒱)
        𝒮ⁿ = EMRH.get_sub_elements_vec(𝒰)[1]
        𝒮ᵛ = EMRH.get_sub_elements_vec(𝒰)[2]

        # Test that the correct types are created
        # - Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:AbstractElement}
        # - ResetType(field_path::Vector, _::TimeWeightPath, x)
        @test all(typeof(s) == EMRH.FutureValueSub{EMRH.StorageValueCuts} for s ∈ 𝒮ᵛ)
        @test all(typeof(EMRH.resets(s)[1]) == EMRH.TimeWeightReset for s ∈ 𝒮ᵛ)

        # Test that the updates of the values are correctly calculated
        # - _update_future_value!(𝒱::Vector{FutureValueSub{T}}, time::Real) where {T<:StorageValueCuts}
        𝒮ᵛ = convert(Vector{EMRH.FutureValueSub{EMRH.StorageValueCuts}}, 𝒮ᵛ)
        EMRH._update_future_value!(𝒮ᵛ, 0)
        time_weights = [EMRH.resets(s)[1].val for s ∈ 𝒮ᵛ]
        @test all(iszero(tw) for (i, tw) ∈ enumerate(time_weights) if i ∉ [1])
        @test time_weights[1] == 1
        EMRH._update_future_value!(𝒮ᵛ, 3)
        time_weights = [EMRH.resets(s)[1].val for s ∈ 𝒮ᵛ]
        @test all(iszero(tw) for (i, tw) ∈ enumerate(time_weights) if i ∉ [1,2,3])
        @test time_weights[1] ≈ 0.7
        @test time_weights[2] ≈ 0.3
        @test time_weights[3] ≈ time_weights[2]

        # Test that the `StorageValueCut`s are correctly reset
        # - _update_case_types!(𝒮ᵛ::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        opers = collect(TwoLevel(1,12, SimpleTimes(12,1)))
        EMRH._update_case_types!(𝒮ⁿ, 𝒰, opers)
        EMRH._update_case_types!(𝒮ᵛ, 𝒰, opers)
        𝒱ᵣₕ = EMRH.get_future_value(𝒰)
        𝒩ᵣₕ = get_nodes(𝒰)

        # - reset_field(x_rh, res_type::Union{InitReset, TimeWeightReset}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        @test all(iszero(EMRH.time_weight(v)) for v ∈ 𝒱ᵣₕ if v.id ∉ [1,2,3])
        @test EMRH.time_weight(𝒱ᵣₕ[1]) ≈ 0.7
        @test EMRH.time_weight(𝒱ᵣₕ[2]) ≈ 0.3
        @test EMRH.time_weight(𝒱ᵣₕ[3]) ≈ EMRH.time_weight(𝒱ᵣₕ[2])

        # - reset_field(x_rh, res_type::ElementReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        @test all(rsv ∈ 𝒩ᵣₕ for v ∈ 𝒱ᵣₕ for c ∈ EMRH.cuts(v) for (rsv, coeff) ∈ EMRH.coefficients(c))
        @test all(rsv ∉ 𝒩 for v ∈ 𝒱ᵣₕ for c ∈ EMRH.cuts(v) for (rsv, coeff) ∈ EMRH.coefficients(c))
    end
end

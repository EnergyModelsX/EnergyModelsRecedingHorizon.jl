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
    svc = StorageValueCut("stor_1", Dict(storage => 1), 5)

    # Test that the access functions are working
    @test EMRH.cut_rhs(svc) == 5
    @test EMRH.coefficients(svc) == Dict(storage => 1)
end

@testset "StorageValueCuts" begin
    @testset "Direct functions" begin
        # Create the StorageValueCut type
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
        storage_value_cut = StorageValueCut("stor_1", Dict(storage => 1), 5)

        # Function for creating different StorageValueCuts
        stor_val_cuts(svc::StorageValueCut, time_profile::Vector) =
            [StorageValueCuts(j, j, k, [svc]) for (j, k) ∈ enumerate(time_profile)]

        time_vec = [0, 10, 10, 40, 70]
        𝒱 = stor_val_cuts(storage_value_cut, time_vec)

        # Test that the access functions are working
        @test all(EMRH.weight(𝒱[k]) == k for k ∈ eachindex(𝒱))
        @test all(EMRH.cuts_time(𝒱[k]) == time_vec[k] for k ∈ eachindex(𝒱))
        @test all(EMRH.cuts(𝒱[k]) == [storage_value_cut] for k ∈ eachindex(𝒱))

        # Test that the updating of the time weight is working
        # - get_active_cut_time_weights(𝒱::Vector{StorageValueCuts}, time::Int)
        𝒱ᶜᵘᵗ = EMRH.get_active_cut_time_weights(𝒱, 0)
        @test all(iszero(val) for (key, val) ∈ 𝒱ᶜᵘᵗ if key ∉ [𝒱[1]])
        @test 𝒱ᶜᵘᵗ[𝒱[1]] == 1
        𝒱ᶜᵘᵗ = EMRH.get_active_cut_time_weights(𝒱, 3)
        @test all(iszero(val) for (key, val) ∈ 𝒱ᶜᵘᵗ if key ∉ 𝒱[1:3])
        @test 𝒱ᶜᵘᵗ[𝒱[1]] ≈ 0.7
        @test 𝒱ᶜᵘᵗ[𝒱[2]] ≈ 𝒱ᶜᵘᵗ[𝒱[3]]
        @test 𝒱ᶜᵘᵗ[𝒱[3]] ≈ 0.3
    end
end

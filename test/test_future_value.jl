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
end

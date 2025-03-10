
@testset "SingleHorizon" begin
    # Test that all inner constructors are behaving as they should
    @testset "SingleHorizon - Inner constructors" begin
        @test_throws ArgumentError EMRH.SingleHorizon(1, [2], [1, 2], [1, 2])
        @test_throws ArgumentError EMRH.SingleHorizon(1, [2], [1], [1, 2])
        @test_throws ArgumentError EMRH.SingleHorizon(1, [2, 2, 2, 2], [1, 2, 3, 4], [1, 5])
    end

    # Test that the function `isfirst` is working for a `SingleHorizon`
    @testset "EMRH.SingleHorizon - isfirst()" begin
        @test isfirst(EMRH.SingleHorizon(1, [2, 2, 2, 2], [1, 2, 3, 4], [1, 2]))
        @test !isfirst(EMRH.SingleHorizon(2, [2, 2, 2, 2], [1, 2, 3, 4], [1, 2]))
    end

    # Test that the functions for extracting fields are working
    @testset "SingleHorizon - field functions" begin
        single_horizon = EMRH.SingleHorizon(1, [2, 2, 2, 2], [1, 2, 3, 4], [1, 2])
        @test durations(single_horizon) == [2, 2, 2, 2]
        @test indices_optimization(single_horizon) == [1, 2, 3, 4]
        @test indices_implementation(single_horizon) == [1, 2]
    end
end

@testset "PeriodHorizons" begin
    # Test that all constructors are behaving as they should
    @testset "PeriodHorizons - Constructors" begin
        per_horizons = PeriodHorizons(16, ones(Int64, 16), 4, 2)
        @test_throws ArgumentError PeriodHorizons(16, [2], 4, 2)
        @test_throws ArgumentError PeriodHorizons(16, ones(16), 4, 6)
        @test_throws ArgumentError PeriodHorizons(16, 3, 4, 2)
        @test_throws ArgumentError PeriodHorizons(ones(16) * 0.3, 4, 2)
        @test PeriodHorizons(16, 1, 4, 2).dur == ones(Int64, 16)
        @test PeriodHorizons(ones(Int64, 16), 4, 2).len == 16
        @test PeriodHorizons(ones(Int64, 16) * 2, 4, 2).len ≠ 16
    end

    # Test that the utilities are working
    @testset "PeriodHorizons - Utilities" begin
        per_horizons = PeriodHorizons(ones(Int64, 16), 4, 2)
        @test length(per_horizons) == 8
    end

    # Test that the iterators are working
    dur = [1, 1, 1, 1, 4, 2, 2, 3, 1, 1, 1, 1, 1, 4, 1, 3]
    per_horizons = PeriodHorizons(dur, 4, 2)
    @testset "PeriodHorizons - standard iterators" begin
        single_horizons = collect(per_horizons)
        # Test of the first period
        @test first(per_horizons).id == 1
        @test first(per_horizons).dur == [1, 1, 1, 1]
        @test first(per_horizons).idx_optim == [1, 2, 3, 4]
        @test first(per_horizons).idx_impl == [1, 2]

        # Test of the second period
        @test single_horizons[2].id == 2
        @test single_horizons[2].dur == [1, 1, 4, 2]
        @test single_horizons[2].idx_optim == [3, 4, 5, 6]
        @test single_horizons[2].idx_impl == [3, 4]

        # Test of the seventh period
        @test single_horizons[7].id == 7
        @test single_horizons[7].dur == [1, 4, 1, 3]
        @test single_horizons[7].idx_optim == [13, 14, 15, 16]
        @test single_horizons[7].idx_impl == [13, 14]
    end
    @testset "PeriodHorizons - withprev" begin
        single_horizons = collect(withprev(per_horizons))
        # Test of the previous periods
        @test isnothing(single_horizons[1][1])
        @test sum(
            single_horizons[k+1][1] == single_horizons[k][2] for
            k ∈ range(1, length(per_horizons) - 1)
        ) == length(per_horizons) - 1
    end
end

@testset "DurationHorizons" begin
    # Test that all constructors are behaving as they should
    @testset "DurationHorizons - Constructors" begin
        dur_horizons = DurationHorizons(16, ones(Int64, 16), 4, 2)
        @test_throws ArgumentError DurationHorizons(16, [2], 4, 2)
        @test_throws ArgumentError DurationHorizons(16, ones(16), 4, 6)
        @test_throws ArgumentError DurationHorizons(16, 3, 4, 2)
        @test_throws ArgumentError DurationHorizons(ones(16) * 0.3, 4, 2)
        @test DurationHorizons(16, 1, 4, 2).dur == ones(Int64, 16)
        @test DurationHorizons(ones(Int64, 16), 4, 2).len == 16
        @test DurationHorizons(ones(Int64, 16) * 2, 4, 2).len ≠ 16
    end

    # Test that the utilities are working
    @testset "DurationHorizons - Utilities" begin
        dur_horizons = DurationHorizons(ones(Int64, 16), 4, 2)
        @test length(dur_horizons) == 8
        dur_horizons = DurationHorizons(ones(Int64, 32), 4, 2)
        @test length(dur_horizons) == 16
    end

    # Test that the iterators are working
    # dur::Vector{Int64}
    dur = [1, 1, 1, 1, 4, 2, 2, 3, 1, 1, 1, 1, 1, 4, 1, 3]
    dur_horizons = DurationHorizons(dur, 8, 4)
    @testset "DurationHorizons - standard iterators" begin
        single_horizons = collect(dur_horizons)
        # Test of the first period
        @test first(dur_horizons).id == 1
        @test first(dur_horizons).dur == [1, 1, 1, 1, 4]
        @test first(dur_horizons).idx_optim == [1, 2, 3, 4, 5]
        @test first(dur_horizons).idx_impl == [1, 2, 3, 4]

        # Test of the second period
        @test single_horizons[2].id == 2
        @test single_horizons[2].dur == [4, 2, 2]
        @test single_horizons[2].idx_optim == [5, 6, 7]
        @test single_horizons[2].idx_impl == [5]

        # Test of the sixth period
        @test single_horizons[6].id == 6
        @test single_horizons[6].dur == [4, 1, 3]
        @test single_horizons[6].idx_optim == [14, 15, 16]
        @test single_horizons[6].idx_impl == [14]
    end
    @testset "DurationHorizons - withprev" begin
        single_horizons = collect(withprev(dur_horizons))
        # Test of the previous periods
        @test isnothing(single_horizons[1][1])
        @test sum(
            single_horizons[k+1][1] == single_horizons[k][2] for
            k ∈ range(1, length(dur_horizons) - 1)
        ) == length(dur_horizons) - 1
    end

    # dur::Vector{Float64}
    dur_fl = [1, 2, 3, 1.5, 1.7, 3, 2, 1, 2.3, 2.7]
    @test_throws ArgumentError DurationHorizons(dur_fl, 8, 3)
    dur_hor_float = DurationHorizons(8760, dur_fl, 8, 3)
    @testset "DurationHorizons - standard iterators (float)" begin
        single_horizons = collect(dur_hor_float)
        # Test of the first period
        @test first(dur_hor_float).id == 1
        @test first(dur_hor_float).dur ≈ [1.0, 2.0, 3.0, 1.5, 1.7]
        @test first(dur_hor_float).idx_optim == [1, 2, 3, 4, 5]
        @test first(dur_hor_float).idx_impl == [1, 2]

        # Test of the third period
        @test single_horizons[3].id == 3
        @test single_horizons[3].dur == [1.5, 1.7, 3.0, 2.0]
        @test single_horizons[3].idx_optim == [4, 5, 6, 7]
        @test single_horizons[3].idx_impl == [4, 5]

        # Test of the fourth period
        @test single_horizons[4].id == 4
        @test single_horizons[4].dur == [3.0, 2.0, 1.0, 2.3]
        @test single_horizons[4].idx_optim == [6, 7, 8, 9]
        @test single_horizons[4].idx_impl == [6]

        # Test of the last period
        @test single_horizons[end].id == 6
        @test single_horizons[end].dur ≈ [2.3, 2.7]
        @test single_horizons[end].idx_optim == [9, 10]
        @test single_horizons[end].idx_impl == [9, 10]
    end
    @testset "DurationHorizons - withprev" begin
        single_horizons = collect(withprev(dur_horizons))
        # Test of the previous periods
        @test isnothing(single_horizons[1][1])
        @test sum(
            single_horizons[k+1][1] == single_horizons[k][2] for
            k ∈ range(1, length(dur_horizons) - 1)
        ) == length(dur_horizons) - 1
    end

end

using EnergyModelsRecHorizon
using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStruct
using ParametricOptInterface
using Accessors

const EMRH = EnergyModelsRecHorizon
const EMB = EnergyModelsBase
const TS = TimeStruct
const POI = ParametricOptInterface

const TEST_ATOL = 1e-6

@testset "RecedingHorizons" begin
    include("test_general.jl")
    @testset "EMRecedingHorizon - Examples" begin
        include("test_examples.jl")
    end

    @testset verbose = true "EMRecedingHorizon - Utility functions" begin
        include("test_utils.jl")
    end

    @testset "RecedingHorizons - Horizon types" begin
        include("horizon_types.jl")
    end
end

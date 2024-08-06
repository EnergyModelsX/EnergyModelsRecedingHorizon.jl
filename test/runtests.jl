using EnergyModelsRecHorizon
using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStruct

const EMRH = EnergyModelsRecHorizon
const EMB = EnergyModelsBase
const TS = TimeStruct

const TEST_ATOL = 1e-6

@testset "RecedingHorizons" begin
    include("test_general.jl")
    @testset "RecedingHorizons - Examples" begin
        include("test_examples.jl")
    end

    @testset "RecedingHorizons - Horizon types" begin
        include("horizon_types.jl")
    end
end

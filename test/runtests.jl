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

@testset "EnergyModelsRecHorizon" begin
    include("test_general.jl")
    include("test_examples.jl")
end

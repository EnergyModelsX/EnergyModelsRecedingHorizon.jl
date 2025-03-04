using EnergyModelsRecHorizon
using EnergyModelsBase
using HiGHS
using JuMP
using Test
using TimeStruct
using ParametricOptInterface
using Accessors
using DataFrames
using Logging

# Declare shortcuts to the different packages
const EMRH = EnergyModelsRecHorizon
const EMB = EnergyModelsBase
const TS = TimeStruct
const POI = ParametricOptInterface

# Declare shortcut to the extension for simplified testing
const POIExt = Base.get_extension(EMRH, :POIExt)

# Set a tolerance which can be used in the following
const TEST_ATOL = 1e-6

# Get the global logger and set the loglevel to Error
logger_org = global_logger()
logger_new = ConsoleLogger(Error)
global_logger(logger_new)

@testset "RecedingHorizon" begin
    @testset "RecedingHorizon | General" begin
        include("test_general.jl")
    end

    @testset "RecedingHorizon | Examples" begin
        include("test_examples.jl")
    end

    @testset "RecedingHorizon | FutureValue" begin
        include("test_future_value.jl")
    end

    @testset verbose = true "RecedingHorizon | Utility functions" begin
        include("test_utils.jl")
    end

    @testset "RecedingHorizon | Horizon types" begin
        include("horizon_types.jl")
    end

    @testset "RecedingHorizon | Node initialization" begin
        include("test_init_data.jl")
    end

    @testset "RecedingHorizon | POI implementation" begin
        include("test_poi.jl")
    end
end
# Reset the loglevel
global_logger(logger_org)

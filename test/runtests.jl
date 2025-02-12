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

const TEST_ATOL = 1e-6

# Get the global logger and set the loglevel to Error
logger_org = global_logger()
logger_new = ConsoleLogger(Error)
global_logger(logger_new)

@testset "RecedingHorizons" begin
    include("test_general.jl")
    @testset "EMRecedingHorizon - Examples" begin
        include("test_examples.jl")
    end

    @testset "RecedingHorizon - POI implementation" begin
        include("test_poi.jl")
    end

    @testset verbose = true "EMRecedingHorizon - Utility functions" begin
        include("test_utils.jl")
    end

    @testset "RecedingHorizon - Horizon types" begin
        include("horizon_types.jl")
    end

    @testset "EMRecedingHorizon - Create new node" begin
        include("test_newnode.jl")
    end
end
# Reset the loglevel
global_logger(logger_org)

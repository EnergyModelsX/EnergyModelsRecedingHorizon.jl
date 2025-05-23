"""
Main module for `EnergyModelsRecedingHorizon`, a package that extends
[`EnergyModelsX`](https://github.com/EnergyModelsX) with the implementation of a receding
horizon framework for stress testing the invested energy system in an operational framework.
"""
module EnergyModelsRecedingHorizon

using EnergyModelsBase
using JuMP
using TimeStruct
using CSV
using Accessors
using DataFrames

const EMB = EnergyModelsBase
const TS = TimeStruct

include(joinpath("structures", "data.jl"))
include(joinpath("structures", "future_value.jl"))
include(joinpath("structures", "horizons.jl"))
include(joinpath("structures", "model.jl"))
include(joinpath("structures", "reset.jl"))
include(joinpath("structures", "node.jl"))

include(joinpath("utils", "case_setup.jl"))
include(joinpath("utils", "horizons.jl"))
include(joinpath("utils", "identification.jl"))
include(joinpath("utils", "other.jl"))
include(joinpath("utils", "results.jl"))

include("model.jl")

export RecHorOperationalModel

# Main function for receding horizon solver call
export run_model_rh

# Types used for case setup
export RecedingAccumulating
export AbstractInitData, InitData, StorageInitData, TransInitData
export AbstractPath, AbstractInitDataPath

# Auxiliary functions for nodes and node field checks
export has_init, is_init_data, data_init

# Types utilized in the instantiation of a model
export DurationHorizons, PeriodHorizons

# Functions for accessing the fields of `SingleHorizon` instances
export durations, indices_optimization, indices_implementation

# Types used for the future value
export FutureValue, ElementValue, StorageValueCuts, StorageValueCut, TypeFutureValue

# Auxiliary functions for future values
export get_future_value, has_cuts

end # module EnergyModelsRecedingHorizon

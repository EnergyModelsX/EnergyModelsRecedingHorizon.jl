"""
Main module for `EnergyModelsRecHorizon` a package that extends
[`EnergyModelsX`](https://github.com/EnergyModelsX) with the implementation of a a receding
horizon framework for stress testing the invested energy system in an operational framework.
"""
module EnergyModelsRecHorizon

using EnergyModelsBase
using JuMP
using TimeStruct
using CSV
using ParametricOptInterface
using Accessors

const EMB = EnergyModelsBase
const TS = TimeStruct
const POI = ParametricOptInterface

include(joinpath("structures", "horizons.jl"))
include(joinpath("structures", "model.jl"))
# include(joinpath("structures", "node.jl"))

include("constraint_functions.jl")
include("datastructures.jl")
include("model.jl")
include("utils.jl")

export RecHorOperationalModel

export run_model_rh
export get_rh_case_model

export RecedingAccumulating

export InitData, InitStorageData

export has_init, is_init_data

# Types utilized in the instantiation of a model
export DurationHorizons, PeriodHorizons

# Functions for accessing the fields of `SingleHorizon` instances
export durations, indices_optimization, indices_implementation

end # module EnergyModelsRecHorizon

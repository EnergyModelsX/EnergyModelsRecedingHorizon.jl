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

const EMB = EnergyModelsBase
const TS = TimeStruct

include("datastructures.jl")
include("model.jl")
include("utils.jl")

export RecHorOperationalModel

export run_model_rh
export opt_horizon, impl_horizon

export RecedingAccumulating

export InitData, InitStorageData

export has_init, is_init_data

# export previous_level

end # module EnergyModelsRecHorizon

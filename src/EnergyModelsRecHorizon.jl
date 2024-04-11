"""
Main module for `EnergyModelsRecHorizon` a package that extends
[`EnergyModelsX`](https://github.com/EnergyModelsX) with the implementation of a a receding
horizon framework for stress testing the invested energy system in an operational framework.
"""
module EnergyModelsRecHorizon

using EnergyModelsBase
using TimeStruct

include("datastructures.jl")
include("model.jl")
include("utils.jl")

end # module EnergyModelsRecHorizon

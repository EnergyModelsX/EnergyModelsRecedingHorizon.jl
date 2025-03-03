module EMGExt

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsRecHorizon
using .EnergyModelsRecHorizon: _find_update_paths,
AbstractSub, AbstractReset, get_sub_ele, UpdateCase

using JuMP
using TimeStruct
using Accessors
using DataFrames

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMRH = EnergyModelsRecHorizon
const TS = TimeStruct

include(joinpath("structures", "reset.jl"))

include(joinpath("utils", "identification.jl"))

end

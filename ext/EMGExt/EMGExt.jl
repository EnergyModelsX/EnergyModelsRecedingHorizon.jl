module EMGExt

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsRecedingHorizon
using .EnergyModelsRecedingHorizon: RecHorEnergyModel, _find_update_paths,
AbstractSub, AbstractReset, get_sub_ele, UpdateCase,
AbstractInitDataPath, InitReset, InitDataPath

using JuMP
using TimeStruct

const EMG = EnergyModelsGeography
const EMRH = EnergyModelsRecedingHorizon

include(joinpath("structures", "data.jl"))
include(joinpath("structures", "reset.jl"))
include(joinpath("structures", "node.jl"))

include(joinpath("utils", "identification.jl"))

include("constraint_functions.jl")
end

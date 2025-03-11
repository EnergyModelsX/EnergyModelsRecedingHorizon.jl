module EMGPOIExt

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsRecHorizon
using .EnergyModelsRecHorizon: RecHorEnergyModel, InitReset

using JuMP
using ParametricOptInterface
using TimeStruct

const EMG = EnergyModelsGeography
const EMRH = EnergyModelsRecHorizon
const POI = ParametricOptInterface
const POIExt = Base.get_extension(EMRH, :POIExt)
const EMGExt = Base.get_extension(EMRH, :EMGExt)

include(joinpath("utils", "case_setup.jl"))

include("constraint_functions.jl")
end

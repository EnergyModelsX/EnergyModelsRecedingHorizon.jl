module POIExt

using EnergyModelsBase
using EnergyModelsRecHorizon
using JuMP
using TimeStruct
using ParametricOptInterface
using Accessors
using DataFrames

const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecHorizon
const TS = TimeStruct
const POI = ParametricOptInterface

include("model.jl")

include(joinpath("utils", "case_setup.jl"))
include(joinpath("utils", "old_poi.jl"))

end

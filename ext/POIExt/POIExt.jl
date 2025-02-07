module POIExt

using EnergyModelsBase
using EnergyModelsRecHorizon
using .EnergyModelsRecHorizon: UpdateCase, AbstractSub, ElementReset, InitReset, OperReset,
_create_updatetype, _add_elements!, update_results!, _update_val!, _update_elements_rh!,
get_sub_model, get_sub_products, get_sub_elements_vec, update_to_case,
updated, original, resets

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

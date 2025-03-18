module POIExt

using EnergyModelsBase
using EnergyModelsRecedingHorizon
using .EnergyModelsRecedingHorizon: RecHorEnergyModel, UpdateCase, AbstractSub,
ElementReset, InitReset, TimeWeightReset, OperReset,
_create_updatetype, _add_elements!, update_results!, update_init_data!, _update_case_types!,
_update_future_value!, get_sub_model, get_sub_products, get_sub_elements_vec, get_sub_ele,
updated, original, resets

using JuMP
using TimeStruct
using ParametricOptInterface
using Accessors
using DataFrames

const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecedingHorizon
const TS = TimeStruct
const POI = ParametricOptInterface

include(joinpath("utils", "case_setup.jl"))

include("model.jl")
include("constraint_functions.jl")

end

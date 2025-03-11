
"""
    POIExt._update_parameter!(m, res_type::InitReset{EMGExt.TransInitDataPath}, opers::Vector)

Update the parameter value for a given `InitReset{EMGExt.TransInitDataPath}` to the provided
value of the [`InitReset`](@ref EnergyModelsRecHorizon.InitReset) type.
"""
POIExt._update_parameter!(m, res_type::InitReset{EMGExt.TransInitDataPath}, opers::Vector) =
    MOI.set(m, POI.ParameterValue(), res_type.var, res_type.val)

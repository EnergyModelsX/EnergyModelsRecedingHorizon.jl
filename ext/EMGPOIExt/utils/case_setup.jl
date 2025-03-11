POIExt._update_parameter!(m, res_type::InitReset{EMGExt.TransInitDataPath}, opers::Vector) =
    MOI.set(m, POI.ParameterValue(), res_type.var, res_type.val)

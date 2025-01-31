"""
    _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)

Function which iterates through the nodes in `case[:nodes]` and `case_copy[:nodes]`, find all
`OperationalProfile{Real}` and changes them to `OperationalProfile{VariableRef}`

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)
    update_dict = Dict{EMB.Node,Dict}()
    lens_dict = Dict{EMB.Node,Dict}()
    for k ∈ 1:length(case[:nodes])
        n_new = case[:nodes][k]
        n_old = case_copy[:nodes][k]
        @assert n_new.id == n_old.id

        T = case[:T]
        update_dict[n_old] = Dict{Any,Any}()
        lens_dict[n_old] = Dict{Any,Any}()
        paths_oper = EMRH._find_paths_operational_profile(n_new)

        for field_id ∈ paths_oper
            lens = EMRH._create_lens_for_field(field_id)
            !isa(lens(n_old), OperationalProfile) && continue
            prof = OperationalProfile(MOI.Parameter.(lens(n_old)[T]))
            update_dict[n_old][field_id] = @variable(m, [T] ∈ prof[collect(T)])

            @reset lens(n_new) =
                OperationalProfile([update_dict[n_old][field_id][t] for t ∈ T])
            lens_dict[n_old][field_id] = lens
        end
        case[:nodes][k] = n_new
    end
    return case, update_dict, lens_dict
end

"""
    _set_values_operational_profile(
        m::JuMP.Model,
        case_copy,
        n::EMB.Node,
        update_dict::Dict{EMB.Node,Dict},
        lens_dict::Dict{EMB.Node,Dict};
        multiplier = 1,
    )

Updates the value of the POI parameter for node `n` based on the values of the node `n` in
`case_copy` for the period `𝒽`.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _set_values_operational_profile(
    m::JuMP.Model,
    case_copy,
    n::EMB.Node,
    update_dict::Dict{EMB.Node,Dict},
    lens_dict::Dict{EMB.Node,Dict};
    multiplier = 1,
)
    for (par, lens) ∈ lens_dict[n]
        new_values = _get_new_POI_values(n, lens; multiplier = multiplier)

        for (i, t) ∈ enumerate(case_copy[:T])
            MOI.set(m, POI.ParameterValue(), update_dict[n][par][t], new_values[i])
        end
    end
    return m
end

"""
    _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)

Currently, it returns the value lens(n).vals.

!!! note
    The idea is to slice the currently received value based on the horizon `𝒽`. This is
    not implemented yet.
    The `multiplier` is there for testing puroposes.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)
    return _get_new_POI_values(n, lens; multiplier = multiplier) #TODO: slice this based on h
end
function _get_new_POI_values(n::EMB.Node, lens; multiplier = 1)
    return lens(n).vals .* multiplier
end

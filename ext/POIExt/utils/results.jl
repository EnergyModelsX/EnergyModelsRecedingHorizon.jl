"""
    update_results_last!(results, m, case, case_rh, map_dict, 𝒽)

Similarly to `update_results!`, update results dictionary `results` given the optimization
results `m`, but aiming to save the last iteration of a optimization loop, saving values in
the optimization horizon after the implementation horizon.
"""
function update_results_last!(results, m, case, case_rh, map_dict, 𝒽)
    𝒯 = get_time_struct(case)
    𝒯ᵣₕ = get_time_struct(case_rh)
    opers_opt = collect(𝒯)[indices_optimization(𝒽)]
    opers_impl = collect(𝒯)[indices_implementation(𝒽)]
    results_rh = EMRH.get_results(m)

    # adding time structure to conversion dictionary - changes at each implementation step
    convert_dict = Dict()
    convert_dict[:t] = Dict()
    for (tᵣₕ, tₐᵤₓ) ∈ zip(𝒯ᵣₕ, opers_opt)
        convert_dict[:t][tᵣₕ] = tₐᵤₓ
    end
    convert_dict[:products] = Dict{Resource}{Resource}()
    for (pᵣₕ, p) ∈ zip(get_products(case_rh), get_products(case))
        convert_dict[:products][pᵣₕ] = p
    end
    for (k, val_dict) ∈ map_dict
        convert_dict[k] = Dict()
        for (x, xᵣₕ) ∈ val_dict
            convert_dict[k][xᵣₕ] = x
        end
    end

    # place values of results_rh into results
    for (k, container) ∈ results
        if isempty(results_rh[k])
            continue
        end
        if any(typeof(val) <: TS.StrategicPeriod for val ∈ first(results_rh[k]))
            continue
        end
        oper_idx =
            findfirst([typeof(v) <: TS.OperationalPeriod for v ∈ first(results_rh[k])])
        results_rh_k_new = [
            NamedTuple(
                (ax == :y) ? ax => v : ax => convert_dict[EMRH._get_key(v)][v] for (ax, v) ∈ pairs(row)
            )
            for row ∈ results_rh[k] if (convert_dict[EMRH._get_key(row[oper_idx])][row[oper_idx]] ∉ opers_impl)
        ]
        append!(container, results_rh_k_new)
    end
end

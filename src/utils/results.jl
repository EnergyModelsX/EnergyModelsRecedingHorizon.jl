"""
    get_results(m::JuMP.Model)

Function returning the values of the optimized model `m`. Some types are, however, not
supported, and the function prints a warning message for those types and does not extract
its value.
"""
function get_results(m::JuMP.Model)
    res = Dict{Symbol,Vector}()
    for key ∈ keys(object_dictionary(m))
        val = _get_values_from_obj(m[key], key)
        if !isnothing(val)
            res[key] = val
        end
    end
    return res
end

function _get_values_from_obj(
    obj::Union{JuMP.Containers.SparseAxisArray,JuMP.Containers.DenseAxisArray},
    key::Symbol,
)
    if isempty(obj)
        return []
    else
        return JuMP.Containers.rowtable(value.(obj))
    end
end
function _get_values_from_obj(
    obj,
    key::Symbol,
)
    @warn "Extracting values from $(typeof(obj)) is not yet supported." maxlog = 1
    return []
end

"""
    update_results!(results, m, 𝒰, opers)

Update results dictionary `results` given the optimization results `m`. `m` was optimized using the
problem definition in `case_rh`, which is a slice of the original problem defined by `case`
at the time period `𝒽`. The containers in `results` are indexed by the elements in `case`.
"""
function update_results!(results, m, 𝒰, opers)
    results_rh = get_results(m)
    if isempty(results)
        # first iteration - create DataFrame instances
        for (k, container_rh) ∈ results_rh
            if isempty(container_rh)
                continue
            elseif any(typeof(val) <: TS.StrategicPeriod for val ∈ first(container_rh))
                @warn "$k cannot be exported as is is indexed with `StrategicPeriod`."
            else
                results[k] = DataFrame()
            end
        end
    end

    # place values of results_rh into results
    for (k, container) ∈ results
        oper_idx =
            findfirst([typeof(v) <: TS.OperationalPeriod for v ∈ first(results_rh[k])])
        results_rh_k_new = [
            NamedTuple(
                (ax == :y) ? ax => v : ax => old_el(𝒰, v) for (ax, v) ∈ pairs(row)
            )
            for row ∈ results_rh[k] if old_el(𝒰, row[oper_idx]) ∈ opers
        ]
        append!(container, results_rh_k_new)
    end
end

"""
    get_results_df(m::JuMP.Model)

Function returning the values of the optimized model `m` as a `DataFrame`. Some types are,
however, not supported, and the function prints a warning message for those types and does
not extract its value.
"""
function get_results_df(m::JuMP.Model)
    res = get_results(m)
    df = Dict(k => DataFrame(val) for (k, val) ∈ res)
    return df
end

"""
    save_results(model::Model; directory=joinpath(pwd(),"csv_files"))
    save_results(results::Dict{Symbol, AbstractDataFrame}; directory=joinpath(pwd(),"csv_files"))

Saves the model results of all variables as CSV files. The model results are saved in a new
directory.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in
the current working directory and save the files in said directory.
"""
function save_results(model::Model; directory = joinpath(pwd(), "csv_files"))
    vars = collect(keys(object_dictionary(model)))
    if !ispath(directory)
        mkpath(directory)
    end
    Threads.@threads for v ∈ vars
        if !isempty(model[v]) && !isa(model[v], VariableRef)
            fn = joinpath(directory, string(v) * ".csv")
            CSV.write(fn, JuMP.Containers.rowtable(value, model[v]))
        end
    end
end
function save_results(
    results::Dict{Symbol,AbstractDataFrame};
    directory = joinpath(pwd(), "csv_files"),
)
    vars = collect(keys(results))
    if !ispath(directory)
        mkpath(directory)
    end
    Threads.@threads for v ∈ vars
        if !isempty(results[v])
            fn = joinpath(directory, string(v) * ".csv")
            CSV.write(fn, results[v])
        end
    end
end

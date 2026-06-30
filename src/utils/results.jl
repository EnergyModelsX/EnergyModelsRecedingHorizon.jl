"""
    get_results(m::JuMP.Model, vars::Vector{Symbol}, opers::Vector{<:TS.TimePeriod})

Function returning the values of the optimized model `m` for the operational periods `opers`.
If the vector `opers` is empty, it returns the values for the complete horizon.
Prints a warning message for currently unsupported types without extracting their value.
"""
function get_results(m::JuMP.Model, vars::Vector{Symbol}, opers::Vector{<:TS.TimePeriod})
    res = Dict{Symbol,Vector}()
    for key ∈ vars
        val = _get_values_from_obj(m[key], opers)
        if !isnothing(val)
            res[key] = val
        end
    end
    return res
end

function _get_values_from_obj(
    obj::Union{JuMP.Containers.DenseAxisArray, JuMP.Containers.SparseAxisArray},
    opers::Vector{<:TS.TimePeriod},
)
    if isempty(obj)
        return []
    elseif isempty(opers)
        return JuMP.Containers.rowtable(value.(obj))
    else
        if isa(obj, JuMP.Containers.DenseAxisArray)
            iter = axes(obj)
            idx_t = findall(col -> isa(col, Vector{<:TS.TimePeriod}), iter)
        else
            iter = first(keys(obj.data))
            idx_t = findall(col -> isa(col, TS.TimePeriod), iter)
        end
        subset = Any[Colon() for _ ∈ iter]
        for k ∈ idx_t
            subset[k] = opers
        end

        return JuMP.Containers.rowtable(value.(obj[subset...]))
    end
end
function _get_values_from_obj(
    obj,
    opers::Vector{<:TS.TimePeriod},
)
    @warn "Extracting values from $(typeof(obj)) is not yet supported." maxlog = 1
    return []
end

"""
    update_results!(results, m, vars, 𝒰, opers, 𝒽)

Updates `results` given the optimization results `m` for the times `opers`, performed in
horizon `𝒽`.
The results are indexed by the elements in the provided `case` (here accessed using the
[`UpdateCase`](@ref) `𝒰`).
"""
function update_results!(results, m, vars, 𝒰, opers, 𝒽)
    opers_EMRH = [updated(𝒰, t) for t ∈ opers]
    if isempty(results)
        results_rh = get_results(m, collect(keys(object_dictionary(m))), opers_EMRH)
        # first iteration - create DataFrame instances
        for (k, container_rh) ∈ results_rh
            if isempty(container_rh)
                continue
            elseif any(typeof(val) <: TS.StrategicPeriod for val ∈ first(container_rh))
                @warn "$k cannot be exported as is is indexed with `StrategicPeriod`."
            elseif k == :future_value
                continue
            else
                results[k] = DataFrame()
                push!(vars, k)
            end
        end
        results[:opt_status] = DataFrame()
    else
        results_rh = get_results(m, vars, opers_EMRH)
    end

    # place values of results_rh into results
    for (k, container) ∈ results
        if k == :opt_status
            append!(container, [NamedTuple((:x1 => 𝒽, :y => termination_status(m)))])
        else
            df = DataFrame(results_rh[k])
            subnames = filter(n -> n ≠ "y", names(df))
            mapcols!(𝒳 -> [original(𝒰, x) for x ∈ 𝒳], df, cols=subnames)
            append!(container, df)
        end
    end
end

"""
    get_results_df(m::JuMP.Model)

Function returning the values of the optimized model `m` as a `DataFrame`. Prints a warning
message for currently unsupported types without extracting their value.
"""
function get_results_df(m::JuMP.Model)
    vars = collect(keys(object_dictionary(m)))
    res = get_results(m, vars, TS.TimePeriod[])
    df = Dict(k => DataFrame(val) for (k, val) ∈ res)
    return df
end

"""
    save_results(m::JuMP.Model; directory=joinpath(pwd(),"csv_files"))
    save_results(results::Dict{Symbol, AbstractDataFrame}; directory=joinpath(pwd(),"csv_files"))

Saves the model results of all variables as CSV files. The model results are saved in the
specified directory.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in
the current working directory and save the files in said directory.
"""
function save_results(m::JuMP.Model; directory = joinpath(pwd(), "csv_files"))
    vars = collect(keys(object_dictionary(m)))
    if !ispath(directory)
        mkpath(directory)
    end
    Threads.@threads for v ∈ vars
        if !isempty(m[v]) && !isa(m[v], VariableRef)
            fn = joinpath(directory, string(v) * ".csv")
            CSV.write(fn, JuMP.Containers.rowtable(value, m[v]))
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

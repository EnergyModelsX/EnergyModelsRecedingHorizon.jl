"""
    get_results(m::JuMP.Model)

Function returning the values of the optimized model `m`. Some types are, however, not
supported, and the function prints a warning message for those types and does not extract
its value.
"""
function get_results(m::JuMP.Model)
    res = Dict{Symbol, AbstractArray{<:Real}}()
    for key in keys(object_dictionary(m))
        val = _get_values_from_obj(m[key], key)
        if ! isnothing(val)
            res[key] = val
        end
    end
    return res
end

function _get_values_from_obj(
    obj::Union{JuMP.Containers.SparseAxisArray, JuMP.Containers.DenseAxisArray},
    key::Symbol
    )
    return value.(obj)
end
function _get_values_from_obj(
    obj::Union{EMB.SparseVariables.IndexedVarArray, EMB.SparseVariables.SparseArray},
    key::Symbol,
)
    @warn "Extracting values from $(typeof(obj)) is not yet supported. Return nothing for $(key)"
    return nothing
end

"""
    update_results!(results, m, case_rh, case, 𝒽)

Update results dictionary `results` given the optimization results `m`. `m` was optimized using the
problem definition in `case_rh`, which is a slice of the original problem defined by `case`
at the time period `𝒽`. The containers in `results` are indexed by the elements in `case`.
"""
function update_results!(results, m, case_rh, case, 𝒽)
    𝒯ᴿᴴₒᵤₜ = collect(case[:T])[indices_optimization(𝒽)]
    results_rh = get_results(m)
    convert_dict = Dict(
        n_rh => n for sym ∈ [:nodes, :links, :products] for
        (n, n_rh) ∈ zip(case[sym], case_rh[sym])
    ) # depends on elements being in same order
    if isempty(results)
        # allocate space in results
        for (k, container_rh) ∈ results_rh
            new_container = initialize_container(container_rh, convert_dict, case[:T])
            if !isnothing(new_container)
                results[k] = new_container
            else
                @warn "Ignoring result field $k"
            end
        end
    end
    # adding time structure to conversion dictionary - changes at each implementation step
    for (tᴿᴴₐᵤₓ, tᴿᴴ) ∈ zip(case_rh[:T], 𝒯ᴿᴴₒᵤₜ)
        convert_dict[tᴿᴴₐᵤₓ] = tᴿᴴ
    end
    # place values of results_rh into results
    for (k, container) ∈ results
        if isempty(results_rh[k])
            continue
        end
        if typeof(container) <: Containers.DenseAxisArray
            axes_new = tuple(
                ([convert_dict[el] for el ∈ ax] for ax ∈ axes(results_rh[k]))...,
            )
            container[axes_new...] = results_rh[k].data
        elseif typeof(container) <: Containers.SparseAxisArray
            for (key, value) ∈ results_rh[k].data
                key_new = tuple((convert_dict[ax] for ax ∈ key)...)
                container[key_new...] = value
            end
        end
    end
end

"""
    initialize_container(container_rh, convert_dict, 𝒯)

Returns an empty container of the same type as `container_rh`, changing its indexing according
to the mapping in `convert_dict`.

This supports the following container types:
- **`Containers.DenseAxisArray`**: An array is initialized for the whole period 𝒯.\n
- **`Containers.SparseAxisArray`**: This only requires type initialization.\n
"""
function initialize_container(container_rh::Containers.DenseAxisArray, convert_dict, 𝒯)
    # replace RH references for corresponding references of full problem
    axes_full = []
    for ax ∈ axes(container_rh)
        axtype = eltype(ax)
        if axtype <: Union{EMB.Node,EMB.Link,EMB.Resource}
            ax_full = [convert_dict[el] for el ∈ ax]
        elseif axtype <: TimeStruct.OperationalPeriod
            ax_full = collect(𝒯) # allocate space for full horizon
        else
            @warn "Unsuported indexing of type $axtype"
            return nothing
        end
        push!(axes_full, ax_full)
    end
    # if !isempty(axes_full)
    new_container = Containers.DenseAxisArray{Float64}(undef, axes_full...)
    # end
    return new_container
end
function initialize_container(container_rh::Containers.SparseAxisArray, convert_dict, 𝒯)
    # sparse arrays only get type allocation
    emptydict = JuMP.OrderedDict{eltype(keys(container_rh.data)),Float64}()
    new_container = Containers.SparseAxisArray(emptydict)
    return new_container
end
function initialize_container(container_rh, convert_dict, 𝒯)
    container_type = typeof(container_rh)
    @warn "Unsuported container type $container_type"
    return nothing
end

"""
    save_results(model::Model; directory=joinpath(pwd(),"csv_files"))

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

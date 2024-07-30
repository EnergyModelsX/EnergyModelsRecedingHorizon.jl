"""
This file should contain utilities that are used within the framework.
"""

"""
    previous_level(
        m,
        n::Storage{RefAccumulating},
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing` and the storage node
is an [`RefAccumulating`](@ref) storage node, the function returns the initial level value
(defined externally at the `data` field through an `InitData` object).
"""
function EMB.previous_level(
    m,
    n::Storage{RefAccumulating},
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, Nothing, Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return init_level(n)
end


"""
    get_init_state(m, n::Storage{RefAccumulating}, 𝒯_RH, t_impl)

Take the optimization solution `m` and find the initialization data of `n` corresponding to
the model state at `t_impl`. The model `m` is defined for the horizon `𝒯_RH`.
Returns an instance of `InitData` that can be used to initialize the system.
"""
function get_init_state(m, n::Storage{RefAccumulating}, 𝒯_RH, t_impl)
    level_t = value.(m[:stor_level][n,t_impl])
    return InitStorageData(level_t)
end
#= Ideas for implementing initialization constraints:
1) constraints_data(m, n, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)
    - sets initial state in model from data (not needed for storage, needed for new technologies)
2) get_init_state(m, n, 𝒯ᴿᴴₒᵤₜ, t_init)
    - gets initialization data at t_init from previous solution
3) constraints_state_time_iter(m, n, 𝒯) # in EnergyModelsHydrogen
4) constraints_x(m, n, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)
=#

"""
Update results in `results` given the optimization results `m`. `m` was optimized using the
problem definition in `case_RH`, which is a slice of the original problem defined by `case`
at the time period `𝒯ᴿᴴₒᵤₜ`. The containers in `results` are indexed by the elements in `case`.
"""
function update_results!(results, m, case_RH, case, 𝒯ᴿᴴₒᵤₜ)
    results_RH = Dict(k=>value.(m[k]) for k ∈ keys(object_dictionary(m)))
    convert_dict = Dict( n_RH => n for sym in [:nodes, :links, :products]
        for (n,n_RH) in zip(case[sym], case_RH[sym]) ) # depends on elements being in same order
    if isempty(results)
        # allocate space in results
        for k ∈ keys(results_RH)
            container_type = typeof(results_RH[k])
            if container_type <: Containers.DenseAxisArray
                # replace RH references for corresponding references of full problem
                axes_full = []
                for ax ∈ axes(results_RH[k])
                    axtype = eltype(ax)
                    if axtype <: Union{EMB.Node, EMB.Link, EMB.Resource}
                        ax_full = [convert_dict[el] for el ∈ ax]
                    elseif axtype <: TimeStruct.OperationalPeriod
                        ax_full = collect(case[:T]) # allocate space for full horizon
                    else
                        @warn "Ignoring result field $k as it uses $axtype"
                        axes_full = []
                        break
                    end
                    push!(axes_full, ax_full)
                end
                if !isempty(axes_full)
                    results[k] = Containers.DenseAxisArray{Float64}(undef, axes_full...)
                end
            elseif container_type <: Containers.SparseAxisArray
                # sparse arrays only get type allocation
                emptydict = JuMP.OrderedDict{eltype(keys(results_RH[k].data)), Float64}()
                results[k] = Containers.SparseAxisArray(emptydict)
            else
                @warn "Ignoring result field $k with unsuported container $container_type"
            end
        end
    end
    # adding time structure to conversion dictionary - changes at each implementation step
    for (tᴿᴴₐᵤₓ, tᴿᴴ) ∈ zip(case_RH[:T], 𝒯ᴿᴴₒᵤₜ)
        convert_dict[tᴿᴴₐᵤₓ] = tᴿᴴ
    end
    # place values of results_RH into results
    for k ∈ keys(results)
        if isempty(results_RH[k])
            continue
        end
        if typeof(results[k]) <: Containers.DenseAxisArray
            axes_new = tuple(([convert_dict[el] for el ∈ ax]
                for ax in axes(results_RH[k]))...)
            results[k][axes_new...] = results_RH[k].data
        elseif typeof(results[k]) <: Containers.SparseAxisArray
            for (key, value) ∈ results_RH[k].data
                key_new = tuple((convert_dict[ax] for ax in key)...)
                results[k][key_new...] = value
            end
        end
    end
end

"""
    save_results(model::Model; directory=joinpath(pwd(),"csv_files"))
Saves the model results of all variables as CSV files. The model results are saved in a new directory.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in the current
working directory and save the files in said directory.
"""
function save_results(model::Model; directory=joinpath(pwd(),"csv_files"))
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

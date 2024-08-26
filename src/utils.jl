
"""
    previous_level(
        m,
        n::Storage{RecedingAccumulating},
        prev_pers::PreviousPeriods{<:NothingPeriod, Nothing, Nothing},
        cyclic_pers::CyclicPeriods,
        modeltype::EnergyModel,
    )

When the previous operational and representative period are `Nothing` and the storage node
is an [`RecedingAccumulating`](@ref) storage node, the function returns the initial level value
(defined externally at the `data` field through an `InitData` object).
"""
function EMB.previous_level(
    m,
    n::Storage{RecedingAccumulating},
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, Nothing, Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return init_level(n)
end


"""
    get_init_state(m, n::Storage{RecedingAccumulating}, 𝒯_RH, t_impl)

Take the optimization solution `m` and find the initialization data of `n` corresponding to
the model state at `t_impl`. The model `m` is defined for the horizon `𝒯_RH`.
Returns an instance of `InitData` that can be used to initialize the system.
"""
function get_init_state(m, n::Storage{RecedingAccumulating}, 𝒯_RH, t_impl)
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
    update_results!(results, m, case_RH, case, 𝒯ᴿᴴₒᵤₜ)

Update results dictionary `results` given the optimization results `m`. `m` was optimized using the
problem definition in `case_RH`, which is a slice of the original problem defined by `case`
at the time period `𝒯ᴿᴴₒᵤₜ`. The containers in `results` are indexed by the elements in `case`.
"""
function update_results!(results, m, case_RH, case, 𝒯ᴿᴴₒᵤₜ)
    results_RH = Dict(k=>value.(m[k]) for k ∈ keys(object_dictionary(m)))
    convert_dict = Dict( n_RH => n for sym in [:nodes, :links, :products]
        for (n,n_RH) in zip(case[sym], case_RH[sym]) ) # depends on elements being in same order
    if isempty(results)
        # allocate space in results
        for (k, container_RH) ∈ results_RH
            new_container = initialize_container(container_RH, convert_dict, case[:T])
            if !isnothing(new_container)
                results[k] = new_container
            else
                @warn "Ignoring result field $k"
            end
        end
    end
    # adding time structure to conversion dictionary - changes at each implementation step
    for (tᴿᴴₐᵤₓ, tᴿᴴ) ∈ zip(case_RH[:T], 𝒯ᴿᴴₒᵤₜ)
        convert_dict[tᴿᴴₐᵤₓ] = tᴿᴴ
    end
    # place values of results_RH into results
    for (k,container) ∈ results
        if isempty(results_RH[k])
            continue
        end
        if typeof(container) <: Containers.DenseAxisArray
            axes_new = tuple(([convert_dict[el] for el ∈ ax]
                for ax in axes(results_RH[k]))...)
            container[axes_new...] = results_RH[k].data
        elseif typeof(container) <: Containers.SparseAxisArray
            for (key, value) ∈ results_RH[k].data
                key_new = tuple((convert_dict[ax] for ax in key)...)
                container[key_new...] = value
            end
        end
    end
end

"""
    initialize_container(container_RH, convert_dict, 𝒯)

Returns an empty container of the same type as `container_RH`, changing its indexing according
to the mapping in `convert_dict`.

This supports the following container types:
- **`Containers.DenseAxisArray`**: An array is initialized for the whole period 𝒯.\n
- **`Containers.SparseAxisArray`**: This only requires type initialization.\n
"""
function initialize_container(container_RH::Containers.DenseAxisArray, convert_dict, 𝒯)
    # replace RH references for corresponding references of full problem
    axes_full = []
    for ax ∈ axes(container_RH)
        axtype = eltype(ax)
        if axtype <: Union{EMB.Node, EMB.Link, EMB.Resource}
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
function initialize_container(container_RH::Containers.SparseAxisArray, convert_dict, 𝒯)
    # sparse arrays only get type allocation
    emptydict = JuMP.OrderedDict{eltype(keys(container_RH.data)), Float64}()
    new_container = Containers.SparseAxisArray(emptydict)
    return new_container
end
function initialize_container(container_RH, convert_dict, 𝒯)
    container_type = typeof(container_RH)
    @warn "Unsuported container type $container_type"
    return nothing
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

# Function for calculating the individual ranges
_take_range(itr::PeriodHorizons, _::Integer, _::Nothing) = (1:itr.optim, 1:itr.impl, 1)
function _take_range(itr::PeriodHorizons, _::Integer, state)
    rng_optim = (state*itr.impl)+1:minimum([(state*itr.impl)+itr.optim, length(itr.dur)])
    rng_impl = (state*itr.impl)+1:minimum([(state*itr.impl)+itr.impl, length(itr.dur)])
    return rng_optim, rng_impl, state+1
end

function _take_range(itr::DurationHorizons, _::Integer, _::Nothing)
    rng_optim = collect(take_horizon(itr.dur, itr.optim))
    rng_impl = collect(take_horizon(itr.dur, itr.impl))
    return rng_optim, rng_impl, 1
end
function _take_range(itr::DurationHorizons, init::Integer, state)
    rng_optim = collect(take_horizon(Iterators.rest(itr.dur, init...), itr.optim))
    rng_impl = collect(take_horizon(Iterators.rest(itr.dur, init...), itr.impl))
    return rng_optim, rng_impl, state+1
end

# Function for defining the individual SingleHorizon when interating through an AbstractHorizons
function Base.iterate(itr::AbstractHorizons, state = (1, nothing))
    state[2] === length(itr) && return nothing
    rng_optim, rng_impl, next = _take_range(itr, state[1], state[2])
    horizon = SingleHorizon(
        next,
        itr.dur[rng_optim],
        collect(rng_optim),
        collect(rng_impl)
    )
    return  horizon, (rng_impl[end]+1, next)
end

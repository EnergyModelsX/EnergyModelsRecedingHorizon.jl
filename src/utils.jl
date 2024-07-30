"""
This file should contain utilities that are used within the framework.
"""

"""
    run_model_RH(case_model_builder::Function, optimizer; check_timeprofiles::Bool=true)

Take the function `case_model_builder` that returns the tuple (case, model) and optimize the
problem in a receding horizon fashion as a series of optimization problems.

`case_model_builder` should take as input the TimeStructure for which the receding horizon
problem will be defined. If no input is provided, it should return the full problem.

`case` is a dictionary that requires the keys:
 - `:nodes::Vector{Node}`
 - `:links::Vector{Link}`
 - `:products::Vector{Resource}`
 - `:T::TimeStructure`

 `model` is an instance of `RecHorOperationalModel`.
"""
function run_model_RH(case_model_builder::Function, optimizer; check_timeprofiles::Bool=true)
    case, model = case_model_builder()
    # should I require two dispatches? One for full problem, another for RH subproblem
    # initializing data for loop

    # WIP Data structure
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    # ℒ = case[:links]
    # 𝒫 = case[:products]

    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    𝒾ⁱⁿⁱᵗ = collect( findfirst(map(is_init_data, node_data(n)))
        for n in 𝒩ⁱⁿⁱᵗ ) # index of init_data in nodes: depends on init data being unique
    init_data₀ = map((n,i)->node_data(n)[i], 𝒩ⁱⁿⁱᵗ,𝒾ⁱⁿⁱᵗ)

    # initializing loop variables
    results = Dict{Symbol, AbstractArray{Float64}}()
    init_data = copy(init_data₀)

    iter_𝒯 = collect(chunk(𝒯, opt_horizon(model)))[1:impl_horizon(model):end]
    # there is probably a more efficient constructor to the iterator
    for (idx,iter_𝒯ᴿᴴ) ∈ enumerate(iter_𝒯)
        𝒯ᴿᴴ = collect(iter_𝒯ᴿᴴ)

        case_RH, model_RH = case_model_builder(𝒯ᴿᴴ)

        𝒯_RH = case_RH[:T]
        𝒩_RH = case_RH[:nodes]

        𝒩ⁱⁿⁱᵗ_RH = filter(has_init, 𝒩_RH)
        # place initialization data in nodes
        for (n,i,init_dataₙ) ∈ zip(𝒩ⁱⁿⁱᵗ_RH,𝒾ⁱⁿⁱᵗ,init_data)
            node_data(n)[i] = init_dataₙ
        end

        # create and solve model
        m = create_model(case_RH, model_RH; check_timeprofiles) # using EnergyModel dispatch
        if !isnothing(optimizer)
            set_optimizer(m, optimizer)
            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)
        else
            @warn "No optimizer given"
        end
        update_results!(results, m, case_RH, case, 𝒯ᴿᴴ)

        # get initialization data from nodes
        t_impl = collect(𝒯_RH)[impl_horizon(model)]
        init_data = [get_init_state(m, n, 𝒯_RH, t_impl) for n ∈ 𝒩ⁱⁿⁱᵗ_RH]

    end

    return results, case, model
end


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
2) get_init_state(m, n, 𝒯ᴿᴴ, t_init)
    - gets initialization data at t_init from previous solution
3) constraints_state_time_iter(m, n, 𝒯) # in EnergyModelsHydrogen
=#

"""
Update results in `results` given the optimization results `m`. `m` was optimized using the
problem definition in `case_RH`, which is a slice of the original problem defined by `case`
at the time period `𝒯ᴿᴴ`. The containers in `results` are indexed by the elements in `case`.
"""
function update_results!(results, m, case_RH, case, 𝒯ᴿᴴ)
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
    for (tᴿᴴₐᵤₓ, tᴿᴴ) ∈ zip(case_RH[:T], 𝒯ᴿᴴ)
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

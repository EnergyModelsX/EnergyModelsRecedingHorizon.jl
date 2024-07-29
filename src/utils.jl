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

 `model` is an instance of `RecHorOperationalModel` if no argument is provided, or an instance
 of `EnergyModel` if a TimeStructure instance is provided as input.
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
        m = create_model(case_RH, model_RH; check_timeprofiles) # EnergyModel dispatch
        if !isnothing(optimizer)
            set_optimizer(m, optimizer)
            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)
        else
            @warn "No optimizer given"
        end
        save_results(m; directory=joinpath(pwd(),"csv_files","$idx"))
        # TODO: store results in a better way

        # get initialization data from nodes
        t_impl = collect(𝒯_RH)[impl_horizon(model)]
        init_data = [get_init_state(m, n, 𝒯_RH, t_impl) for n ∈ 𝒩ⁱⁿⁱᵗ_RH]

    end

    return 0
end

"""
    run_model(case::Dict, model::RecHorEnergyModel, optimizer)

Take the `case` data as a dictionary and the `model` and build and optimize the problem in
a receding horizon fashion as a series of optimization problems.

The dictionary requires the keys:
 - `:nodes::Vector{Node}`
 - `:links::Vector{Link}`
 - `:products::Vector{Resource}`
 - `:T::TimeStructure`
"""
function EMB.run_model(case::Dict, model::RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true)
    @debug "Run model" optimizer

    # WIP Data structure
    𝒯 = case[:T]
    𝒩 = case[:nodes]
    # ℒ = case[:links]
    # 𝒫 = case[:products]

    𝒩ⁱⁿⁱᵗ = filter(has_init, 𝒩)
    𝒾ⁱⁿⁱᵗ = collect( findfirst(map(is_init_data, node_data(n))) # depends on init data being unique
        for n in 𝒩ⁱⁿⁱᵗ )
    init_data₀ = map((n,i)->node_data(n)[i], 𝒩ⁱⁿⁱᵗ,𝒾ⁱⁿⁱᵗ)

    # initializing data for loop
    init_data = copy(init_data₀)
    case_RH = copy(case) # deepcopy needed if nodes are to be re-instanced

    iter_𝒯 = collect(chunk(𝒯, opt_horizon(model)))[1:impl_horizon(model):end]
    # there is probably a more efficient constructor to the iterator
    for iter_𝒯ᴿᴴ ∈ iter_𝒯
        𝒯ᴿᴴ = collect(iter_𝒯ᴿᴴ) # TODO: problem with building TimeStructure
        case_RH[:T] = 𝒯ᴿᴴ

        # place initialization data in nodes
        for (n,i,init_dataₙ) ∈ zip(𝒩ⁱⁿⁱᵗ,𝒾ⁱⁿⁱᵗ,init_data)
            node_data(n)[i] = init_dataₙ
        end

        # create and solve model
        m = create_model(case_RH, model; check_timeprofiles) # EnergyModel dispatch
        if !isnothing(optimizer)
            set_optimizer(m, optimizer)
            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)
        else
            @warn "No optimizer given"
        end

        # get initialization data from nodes
        init_data = [get_init_state(m, n, 𝒯ᴿᴴ, t_init) for n ∈ 𝒩ⁱⁿⁱᵗ]

    end


    # Restoring initialization data for initializable nodes
    for (n,i,init_dataₙ) = zip(𝒩ⁱⁿⁱᵗ, 𝒾ⁱⁿⁱᵗ, init_data₀)
        node_data(n)[i] = init_dataₙ
    end
    return m
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
    get_init_state(m, n::Storage{RefAccumulating}, 𝒯ᴿᴴ, t_init)

Take the solution

"""
function get_init_state(m, n::Storage{RefAccumulating}, 𝒯, t_impl)
    level_t = value.(m[:stor_level][n,t_impl])
    return InitData(level_t)
end
#= Ideas for implementing initialization constraints:
1) constraints_data(m, n, 𝒯, 𝒫, modeltype, data::InitData)
    - sets initial state in model from data (not needed for storage, needed for new technologies)
2) get_init_state(m, n, 𝒯ᴿᴴ, t_init)
    - gets initialization data at t_init from previous solution
3) constraints_state_time_iter(m, n, 𝒯) # in EnergyModelsHydrogen
=#

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

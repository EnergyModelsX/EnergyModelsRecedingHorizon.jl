
"""
    get_rh_case_model(case, model, 𝒽, init_data)
Returns a pair `(case_rh, model_rh)` that corresponds to the receding horizon problem of `(case, model)`
evaluated at the horizon indices `𝒽`, initialized using `init_data`.
"""
function get_rh_case_model(case, model, 𝒽, init_data=nothing)
    # only works for operational profiles due to case[:T] definition and dispatches on get_property_rh,
    # must be improved to deal with more cases
    𝒯ᴿᴴ = optimization_time_ref(case[:T], 𝒽)
    println("𝒯ᴿᴴ = $(𝒯ᴿᴴ)")
    case_rh = Dict(
        :products => case[:products],
        :T => TwoLevel(1, 1, SimpleTimes([duration(t) for t ∈ 𝒯ᴿᴴ])),
    )
    case_rh[:nodes] = collect(get_object_rh(n, 𝒯ᴿᴴ) for n ∈ case[:nodes])
    map_nodes = Dict(case[:nodes][i] => case_rh[:nodes][i] for i ∈ 1:length(case[:nodes]))
    case_rh[:links] = collect(get_new_link(l, map_nodes) for l ∈ case[:links])

    model_rh = get_object_rh(model, 𝒯ᴿᴴ)

    if !isnothing(init_data)
        𝒩ⁱⁿⁱᵗ_rh = filter(has_init, case_rh[:nodes])
        𝒾ⁱⁿⁱᵗ = collect(findfirst(map(is_init_data, node_data(n))) for n ∈ 𝒩ⁱⁿⁱᵗ_rh) # index of init_data in nodes: depends on init data being unique
        # place initialization data in nodes
        for (n, i, init_data_node) ∈ zip(𝒩ⁱⁿⁱᵗ_rh, 𝒾ⁱⁿⁱᵗ, init_data)
            node_data(n)[i] = init_data_node
        end
    end

    return (case_rh, model_rh)
end

"""
    get_new_link(l, map_nodes)
Returns a new link related to `l` linking the new nodes returned by `map_nodes`.
"""
function get_new_link(l, map_nodes)
    fields_link = []
    for field_sym ∈ fieldnames(typeof(l))
        field_val = getfield(l, field_sym)
        push!(fields_link, (field_val ∈ keys(map_nodes)) ? map_nodes[field_val] : field_val)
    end
    new_link = typeof(l)(fields_link...)
    return new_link
end

"""
    get_object_rh(obj, 𝒯ᴿᴴ)
Returns a new object derived from `obj` instantiated at the time steps `𝒯ᴿᴴ`.
"""
function get_object_rh(obj, 𝒯ᴿᴴ)
    fields_obj_rh = []
    for field_sym ∈ fieldnames(typeof(obj))
        field_val = getfield(obj, field_sym)
        push!(fields_obj_rh, get_property_rh(field_val, 𝒯ᴿᴴ))
    end
    new_obj = typeof(obj)(fields_obj_rh...)
    return new_obj
end
# TODO: same as get_property_RH(val, 𝒯ᴿᴴ) with val::EMB.Node ?

"""
    get_property_rh(val, 𝒯ᴿᴴ)
Returns the property `val` evaluated at the time steps `𝒯ᴿᴴ`.
"""
function get_property_rh(val::TS.TimeProfile, 𝒯ᴿᴴ)
    new_val = TS.OperationalProfile(val[𝒯ᴿᴴ])
    return new_val
end
function get_property_rh(val::TS.FixedProfile, 𝒯ᴿᴴ)
    new_val = val
    return new_val
end
function get_property_rh(val::Dict, 𝒯ᴿᴴ)
    new_val = Dict(key => get_property_rh(el, 𝒯ᴿᴴ) for (key, el) ∈ val)
    return new_val
end
function get_property_rh(val::Vector, 𝒯ᴿᴴ)
    new_val = deepcopy(val)
    return new_val
end
function get_property_rh(val::Any, 𝒯ᴿᴴ)
    new_val = val
    return new_val
end

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
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod,Nothing,Nothing},
    cyclic_pers::CyclicPeriods,
    modeltype::EnergyModel,
)

    # Previous storage level, as there are no changes
    return init_level(n)
end

"""
    get_init_state(m, n::Storage{RecedingAccumulating}, 𝒯_rh, 𝒽)

Take the optimization solution `m` and find the initialization data of `n` corresponding to
the model state at the end of the implementation horizon defined in `𝒽`. The model `m` is
internally defined for the time structure `𝒯_rh`.
Returns an instance of `InitData` that can be used to initialize the system.
"""
function get_init_state(m, n::Storage{RecedingAccumulating}, 𝒯_rh, 𝒽)
    t_impl = collect(𝒯_rh)[length(indices_implementation(𝒽))] # solution for internal time structure
    level_t = value.(m[:stor_level][n, t_impl])
    return InitStorageData(level_t)
end
#= Ideas for implementing initialization constraints:
1) constraints_data(m, n, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)
    - sets initial state in model from data (not needed for storage, needed for new technologies)
2) get_init_state(m, n, 𝒯ᴿᴴₒᵤₜ, 𝒽)
    - gets initialization data at end of implementation horizon in 𝒽 from previous solution
3) constraints_state_time_iter(m, n, 𝒯) # in EnergyModelsHydrogen
4) constraints_x(m, n, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)
=#

"""
    update_results!(results, m, case_rh, case, 𝒽)

Update results dictionary `results` given the optimization results `m`. `m` was optimized using the
problem definition in `case_rh`, which is a slice of the original problem defined by `case`
at the time period `𝒽`. The containers in `results` are indexed by the elements in `case`.
"""
function update_results!(results, m, case_rh, case, 𝒽)
    𝒯ᴿᴴₒᵤₜ = optimization_time_ref(case[:T], 𝒽)
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
                ([convert_dict[el] for el ∈ ax] for ax ∈ axes(results_rh[k]))...
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
Saves the model results of all variables as CSV files. The model results are saved in a new directory.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in the current
working directory and save the files in said directory.
"""
function save_results(model::Model; directory=joinpath(pwd(), "csv_files"))
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

"""
    optimization_time_ref(𝒯, 𝒽)
Returns an array of time references for the receding horizon optimization problem. The full
problem is defined by `𝒯`, and the horizon is defined by `𝒽`.
"""
function optimization_time_ref(𝒯, 𝒽)
    # TODO: not optimal to create array according to Julian, but a better solution was not found
    𝒯_vec = collect(𝒯)
    return 𝒯_vec[indices_optimization(𝒽)]
end

# Function for calculating the individual ranges
_take_range(itr::PeriodHorizons, _::Integer, _::Nothing) = (1:(itr.optim), 1:(itr.impl), 1)
function _take_range(itr::PeriodHorizons, _::Integer, state)
    rng_optim =
        ((state * itr.impl) + 1):minimum([(state * itr.impl) + itr.optim, length(itr.dur)])
    rng_impl =
        ((state * itr.impl) + 1):minimum([(state * itr.impl) + itr.impl, length(itr.dur)])
    return rng_optim, rng_impl, state + 1
end

function _take_range(itr::DurationHorizons, _::Integer, _::Nothing)
    rng_optim = collect(take_horizon(itr.dur, itr.optim))
    rng_impl = collect(take_horizon(itr.dur, itr.impl))
    return rng_optim, rng_impl, 1
end
function _take_range(itr::DurationHorizons, init::Integer, state)
    rng_optim = collect(take_horizon(Iterators.rest(itr.dur, init...), itr.optim))
    rng_impl = collect(take_horizon(Iterators.rest(itr.dur, init...), itr.impl))
    return rng_optim, rng_impl, state + 1
end

# Function for defining the individual SingleHorizon when interating through an AbstractHorizons
function Base.iterate(itr::AbstractHorizons, state=(1, nothing))
    state[2] === length(itr) && return nothing
    rng_optim, rng_impl, next = _take_range(itr, state[1], state[2])
    horizon = SingleHorizon(next, itr.dur[rng_optim], collect(rng_optim), collect(rng_impl))
    return horizon, (rng_impl[end] + 1, next)
end

"""
_fields_with_operational_profile(n::Union{NetworkNode, Source, Sink})
_fields_with_operational_profile(n::Storage)
_fields_with_operational_profile(n::Availability)
_fields_with_operational_profile(n::EMB.Node)

Function for returning the fields in a node containing an `OperationalProfile`. If no fields are found, it returns `Symbol[]`.

    Ex:
    el = ResourceCarrier("el", 0.2)
    heat = ResourceCarrier("heat", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    n = RefNetworkNode(
        "my_id", :id
        FixedProfile(1e12), # :cap
        OperationalProfile([1,2]), # :opex_var
        FixedProfile(0), # :opex_fixed
        Dict(el => 1), # :input
        Dict(heat => 1), # :output
        [EmissionsProcess(Dict(co2 => OperationalProfile([2,2])))] # :data
    )
    _fields_with_operational_profile(n) # returns [:opex_var, :data]
"""
function _fields_with_operational_profile(n::Union{NetworkNode, Source, Sink, Storage})
    return [fn for fn ∈ fieldnames(typeof(n)) if _has_field_operational_profile(getfield(n, fn))]
end

function _fields_with_operational_profile(n::Availability)
    return Symbol[]
end

function _fields_with_operational_profile(n::EMB.Node)
    error("We assume only subtypes of NetworkNode, Source, Sink and Storage.")
    return nothing
end


"""
    _has_field_operational_profile(field::OperationalProfile)
    _has_field_operational_profile(field::StrategicProfile)
    _has_field_operational_profile(field::Vector{Data})
    _has_field_operational_profile(field::Data)
    _has_field_operational_profile(field::EMB.AbstractStorageParameters)
    _has_field_operational_profile(field::Dict)
    _has_field_operational_profile(field)

Function for recursively checking if `field` contains an `OperationalProfile`, returning
true or false

# Examples
```julia

co2 = ResourceEmit("co2", 1.0)

# The following calls return true
_has_field_operational_profile(OperationalProfile([1]))
_has_field_operational_profile(EmissionsProcess(Dict(co2 => OperationalProfile(profile))))
_has_field_operational_profile(StorCapOpexFixed(OperationalProfile([1]), FixedProfile(0)))
_has_field_operational_profile(Dict(:a => Dict(:b => Dict(:c => OperationalProfile([1])))))

# The following calls return false
_has_field_operational_profile(Dict(:a => Dict(:b => Dict(:c => FixedProfile(1)))))
_has_field_operational_profile(EmissionsProcess(Dict(co2 => FixedProfile(2))))
_has_field_operational_profile(EmptyData())
_has_field_operational_profile(InitStorageData(4.0))

_has_field_operational_profile(EmissionsEnergy(OperationalProfile([1])))
# EmissionsEnergy accepts any inputs, but does not store `OperationalProfiles`

# The following calls return an error
_has_field_operational_profile(StrategicProfile([1]))
_has_field_operational_profile(Dict(:a => StrategicProfile([1, 2])))
```
"""
_has_field_operational_profile(field::OperationalProfile) = true
function _has_field_operational_profile(field::StrategicProfile)
    error("EMRH should not be used with strategic profiles")
    return nothing
end
function _has_field_operational_profile(field::Vector{<:Data})
    return any([_has_field_operational_profile(d) for d ∈ field])
end
function _has_field_operational_profile(field::Data)
    return any([_has_field_operational_profile(getfield(field, f)) for f ∈ fieldnames(typeof(field))])
end
function _has_field_operational_profile(field::Dict)
    return any([_has_field_operational_profile(val) for (key, val) ∈ field])
end
function _has_field_operational_profile(field::EMB.AbstractStorageParameters)
    return any([_has_field_operational_profile(getfield(field, f)) for f ∈ fieldnames(typeof(field))])
end
_has_field_operational_profile(field) = false

"""
_find_paths_operational_profile(n::Union{NetworkNode, Source, Sink, Storage})
_find_paths_operational_profile(field::Union{NetworkNode, Source, Sink, Storage}, current_path::Vector{Any}, all_paths::Vector{Any})
_find_paths_operational_profile(field::Vector{<:Data}, current_path::Vector{Any}, all_paths::Vector{Any})
_find_paths_operational_profile(field::Union{Data, EMB.AbstractStorageParameters}, current_path::Vector{Any}, all_paths::Vector{Any})
_find_paths_operational_profile(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
_find_paths_operational_profile(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
_find_paths_operational_profile(field::StrategicProfile, current_path::Vector{Any}, all_paths::Vector{Any})
_find_paths_operational_profile(field::Any, current_path::Vector{Any}, all_paths::Vector{Any})

Function for returning the fields in a node containing an `OperationalProfile`, returning a list of the path.


# Examples
```julia

co2 = ResourceEmit("co2", 1.0) 
sink = RefSink(
    "a_sink", # :id
    FixedProfile(1e5), # :cap
    Dict(:surplus => OperationalProfile(zeros(dim_t)), :deficit => OperationalProfile(1e6*ones(dim_t))), # :penalty
    Dict(heat => 1), # :input
    [EmptyData(), EmissionsProcess(Dict(co2 => OperationalProfile(profile)))] # :data
)

 EMRH._find_paths_operational_profile(sink)
# returns a 3-element Vector{Any}:
#  Any[:penalty, :deficit]
#  Any[:penalty, :surplus]
#  Any[:data, "idx_2", :emissions, co2]

# The function can also be used for checking other `types`:
all_paths = []
current_path = Any[:a_path]
a_dict = Dict(:a => Dict(:b1 => Dict(:c => OperationalProfile([1])), :b2 => OperationalProfile([1]), :b3 => [1]))
EMRH._find_paths(a_dict, current_path, all_paths)

#all_paths are now a 2-element Vector{Any}: [Any[:my_path, :a, :b2], Any[:my_path, :a, :b1, :c]]

```
"""

function _find_paths_operational_profile(n::Union{NetworkNode, Source, Sink, Storage})
    all_paths = []  # To store the paths to lists
    # Start recursion
    _find_paths_operational_profile(n, [], all_paths)
    return all_paths
end

function _find_paths_operational_profile(field::Union{NetworkNode, Source, Sink, Storage}, current_path::Vector{Any}, all_paths::Vector{Any})
    for f in fieldnames(typeof(field))
        new_path = vcat(current_path, f)
        _find_paths_operational_profile(getfield(field, f), new_path, all_paths)
    end
end

function _find_paths_operational_profile(field::Vector{<:Data}, current_path::Vector{Any}, all_paths::Vector{Any})
    for (i, d) in enumerate(field)
        new_path = vcat(current_path, ["idx_$(i)"]) 
        _find_paths_operational_profile(d, new_path, all_paths)  
    end
end

function _find_paths_operational_profile(field::Union{Data, EMB.AbstractStorageParameters}, current_path::Vector{Any}, all_paths::Vector{Any})
    for f in fieldnames(typeof(field))
        new_path = vcat(current_path, f)
        _find_paths_operational_profile(getfield(field, f), new_path, all_paths)
    end
end

function _find_paths_operational_profile(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
    for (key, value) in field
        new_path = vcat(current_path, key) 
        _find_paths_operational_profile(value, new_path, all_paths)  
    end
end

function _find_paths_operational_profile(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
    push!(all_paths, current_path)  # Add current_path to all_paths
end

function _find_paths_operational_profile(field::StrategicProfile, current_path::Vector{Any}, all_paths::Vector{Any})
    error("EMRH should not be used with strategic profiles")
end

function _find_paths_operational_profile(field::Any, current_path::Vector{Any}, all_paths::Vector{Any})
    # No action needed
end

function get_results(m::JuMP.Model)
    return Dict(k => value.(m[k]) for k ∈ keys(object_dictionary(m)) if (k != :stor_level_Δ_sp)) #NB! Added if.. block after updating EMB
end
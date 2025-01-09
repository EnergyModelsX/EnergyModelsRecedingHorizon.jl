
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
EMRH._find_paths_operational_profile(a_dict, current_path, all_paths)

#all_paths are now a 2-element Vector{Any}: [Any[:a_path, :a, :b2], Any[:a_path, :a, :b1, :c]]

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


"""
    get_results(m::JuMP.Model; types_not_supported = Union{EMB.SparseVariables.IndexedVarArray, EMB.SparseVariables.SparseArray})

Function returning the values of the optimized model `m`. It does, however, not extract values if the type is in `types_not_supported`.

"""
function get_results(m::JuMP.Model; types_not_supported = Union{EMB.SparseVariables.IndexedVarArray, EMB.SparseVariables.SparseArray})
    return Dict(k => value.(m[k]) for k ∈ keys(object_dictionary(m)) if !(typeof(m[k]) <: types_not_supported))
end

"""
    _set_POI_par_as_operational_profile(m::JuMP.Model, field::OperationalProfile, n::Union{Sink}, case::Dict)

Function which converts `field` from a "standard" OperationalProfile to an OperationalProfile containing POI-parameters.

Specifically, iy converts `field` from a type of `OperationalProfile{<:Real}` to `OperationalProfile{MathOptInterface.Parameter{Int64}}`

"""

"""
    _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)
Function which iterates through the nodes, find all 'OperationalProfile{Real}' and changes them to 'OperationalProfile{VariableRef}'

"""
function _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)

    update_dict = Dict{EMB.Node, Dict}()
    lens_dict = Dict{EMB.Node, Dict}()
    for k ∈ 1:length(case[:nodes])
        n_new = case[:nodes][k]
        n_old = case_copy[:nodes][k]
        @assert n_new.id == n_old.id

        T = case[:T]
        update_dict[n_old] = Dict{Any, Any}()
        lens_dict[n_old] = Dict{Any, Any}()
        paths_oper = _find_paths_operational_profile(n_new)

        for field_id ∈ paths_oper
            lens = _create_lens_for_field(field_id)
            prof = OperationalProfile(MOI.Parameter.(lens(n_old)[T]))
            update_dict[n_old][field_id] = @variable(m, [T] ∈ prof[collect(T)])

            # @reset lens(n_new) = OperationalProfile([update_dict[n_old][field_id][t] for t ∈ T])
            n_new = _reset_node(n_new, n_old, lens, field_id, update_dict, T)
            lens_dict[n_old][field_id] = lens
        end
        case[:nodes][k] = n_new
    end
    return case, update_dict, lens_dict
end

"""
    _reset_node(n_new::Union{Source, Sink, NetworkNode}, n_old::Union{Source, Sink, NetworkNode}, lens, field_id, update_dict, T)
    _reset_node(n_new::Storage, n_old::Storage, lens, field_id, update_dict, T)
Function for @reset n_new. Storage nodes are not yet supported.
"""
function _reset_node(n_new::Union{Source, Sink, NetworkNode}, n_old::Union{Source, Sink, NetworkNode}, lens, field_id, update_dict, T)
    @reset lens(n_new) = OperationalProfile([update_dict[n_old][field_id][t] for t ∈ T])
    return n_new
end
function _reset_node(n_new::Storage, n_old::Storage, lens, field_id, update_dict, T)
    error("Reset does not work for Storage yet.")
    return n_new
end

"""
    _create_lens_for_field(field_id::Vector{<:Any})

Creates a 'lens', which can be used to inspect or reset variables.

Example:
```julia
using Accessors: @reset
using EnergyModelsBase
using EnergyModelsRecHorizon
using TimeStruct
const EMRH = EnergyModelsRecHorizon

cap_prof = [20, 300]
price_prof = [1,2]
power = ResourceCarrier("power", 0.0)
co2 = ResourceEmit("co2", 1.0)

source = RefSource(
        "a source", #Node id or name
        OperationalProfile(cap_prof), # :cap
        FixedProfile(100), #variable OPEX
        FixedProfile(0), #Fixed OPEX
        Dict(power => 1), #output from the node
        [EmissionsProcess(Dict(co2 => OperationalProfile(price_prof)))]
    )

paths_oper_source = EMRH._find_paths_operational_profile(source)
@assert all(paths_oper_source .== Any[[:cap], [:data, "idx_1", :emissions, co2]])
lens_source_cap = EMRH._create_lens_for_field(paths_oper_source[1])
lens_source_data = EMRH._create_lens_for_field(paths_oper_source[2])

lens_source_cap(source) #returns OperationalProfile(cap_prof)
@assert all(cap_prof .== lens_source_cap(source).vals)
@assert all(price_prof .== lens_source_data(source).vals)

#lens can also be used for @reset
cap_prof2 = [90,100]
@reset lens_source_cap(source) = OperationalProfile(cap_prof2)
@assert all(cap_prof2 .== lens_source_cap(source).vals)

```
"""
function _create_lens_for_field(field_id::Vector{<:Any})
    str = _merge_path(field_id)
    global global_str_lens = "@o _" * str
    lens = eval(Meta.parse(global_str_lens))
    return lens
end

function _merge_path(oprof_path::Vector)
    path = ""
    for k ∈ oprof_path
        path *= _path_type(k)
    end
    return path
end

_path_type(val::Symbol) = "." * String(val)
function _path_type(val::String)
    _, idx = split(val, "_")
    return "[" * string(parse(Int64, idx)) * "]" #can return only idx, but this adds an extra check that idx is an int
end
function _path_type(val::Resource)
    global res = val
    return "[res]"
end

"""
    _set_values_operational_profile(m::JuMP.Model, case_copy, n::EMB.Node, update_dict::Dict{EMB.Node, Dict}, lens_dict::Dict{EMB.Node, Dict}; multiplier = 1)

Updates the value of the POI parameter for node 'n' based on the values of the node 'n' in 'case_copy' for the period '𝒽'.
"""
function _set_values_operational_profile(m::JuMP.Model, case_copy, n::EMB.Node, update_dict::Dict{EMB.Node, Dict}, lens_dict::Dict{EMB.Node, Dict}; multiplier = 1)
    n_paths_to_oper_prof = _find_paths_operational_profile(n)
    for n_path ∈ n_paths_to_oper_prof
        new_values = _get_new_POI_values(n, lens_dict[n][n_path]; multiplier = multiplier)

        for (i,t) in enumerate(case_copy[:T])
            MOI.set(m, POI.ParameterValue(), update_dict[n][n_path][t], new_values[i])
        end
    end
    return m
end

"""
    _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)
Currently, it returns the value lens(n).vals.

NB: The idea is to slice the currently received value based on the horizon 𝒽. The 'multiplier' is there for testing puroposes.

"""
function _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)
    return _get_new_POI_values(n, lens; multiplier = multiplier) #TODO: slice this based on h
end
function _get_new_POI_values(n::EMB.Node, lens; multiplier = 1)
    return lens(n).vals .* multiplier
end

"""
    _get_node_index(needle::EMB.Node, haystack::Vector{<:EMB.Node})
Returns the index of 'needle' in 'haystack', checking that the field 'id' are equal.

"""
function _get_node_index(needle::EMB.Node, haystack::Vector{<:EMB.Node})
    haystack_id = [h.id for h ∈ haystack]
    @assert _has_unique_strings(haystack_id) "'haystack' = $(haystack) has non-unique strings."
    return findfirst(isequal(needle.id), haystack_id)
end

function _has_unique_strings(v::Vector{String})
    return length(v) == length(Set(v)) #Set(v) contains only unique elements
end

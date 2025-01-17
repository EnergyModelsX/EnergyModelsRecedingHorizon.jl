"""
    get_rh_case_model(case, model, 𝒽, init_data)
Returns a pair `(case_rh, model_rh)` that corresponds to the receding horizon problem of `(case, model)`
evaluated at the horizon indices `𝒽`, initialized using `init_data`.
"""
function get_rh_case_model(case, model, 𝒽, lens_dict, init_data = nothing)
    # only works for operational profiles due to case[:T] definition and dispatches on get_property_rh,
    # must be improved to deal with more cases
    𝒯ᴿᴴ = optimization_time_ref(case[:T], 𝒽)
    println("𝒯ᴿᴴ = $(𝒯ᴿᴴ)")
    case_rh = Dict(
        :products => case[:products],
        :T => TwoLevel(1, 1, SimpleTimes([duration(t) for t ∈ 𝒯ᴿᴴ])),
    )
    case_rh[:nodes] = [_get_node_rh(n, lens_dict, 𝒯ᴿᴴ) for n ∈ case[:nodes]]

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
    _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)

Function which iterates through the nodes in `case[:nodes]` and `case_copy[:nodes]`, find all
`OperationalProfile{Real}` and changes them to `OperationalProfile{VariableRef}`

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _set_POI_par_as_operational_profile(m::JuMP.Model, case::Dict, case_copy::Dict)
    update_dict = Dict{EMB.Node,Dict}()
    lens_dict = Dict{EMB.Node,Dict}()
    for k ∈ 1:length(case[:nodes])
        n_new = case[:nodes][k]
        n_old = case_copy[:nodes][k]
        @assert n_new.id == n_old.id

        T = case[:T]
        update_dict[n_old] = Dict{Any,Any}()
        lens_dict[n_old] = Dict{Any,Any}()
        paths_oper = _find_paths_operational_profile(n_new)

        for field_id ∈ paths_oper
            lens = _create_lens_for_field(field_id)
            prof = OperationalProfile(MOI.Parameter.(lens(n_old)[T]))
            update_dict[n_old][field_id] = @variable(m, [T] ∈ prof[collect(T)])

            @reset lens(n_new) = OperationalProfile([update_dict[n_old][field_id][t] for t ∈ T])
            lens_dict[n_old][field_id] = lens
        end
        case[:nodes][k] = n_new
    end
    return case, update_dict, lens_dict
end

"""
    _reset_node(
        n_new::Union{Source,Sink,NetworkNode},
        n_old::Union{Source,Sink,NetworkNode},
        lens,
        field_id,
        update_dict,
        T)
    _reset_node(n_new::Storage, n_old::Storage, lens, field_id, update_dict, T)

Function for resetting nodes, using @reset. Storage nodes are not yet supported.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _reset_node(
    n_new::Union{Source,Sink,NetworkNode},
    n_old::Union{Source,Sink,NetworkNode},
    lens,
    field_id,
    update_dict,
    T,
)
    @reset lens(n_new) = OperationalProfile([update_dict[n_old][field_id][t] for t ∈ T])
    return n_new
end
function _reset_node(n_new::Storage, n_old::Storage, lens, field_id, update_dict, T)
    error("Reset does not work for Storage yet.")
    return n_new
end

"""
    _create_lens_dict_oper_prof(n::Vector{EMB.Node})
    _create_lens_dict_oper_prof(n::EMB.Node)

Function to create a dictionary for storing lenses pointing to `OperationalProfile` in a
node `n` or an array of nodes.

Example:
```julia
using EnergyModelsBase
using EnergyModelsRecHorizon
using TimeStruct
const EMRH = EnergyModelsRecHorizon

#generate objects
cap_prof = [20, 300]
price_prof = [1,2]
power = ResourceCarrier("power", 0.0)
co2 = ResourceEmit("co2", 1.0)
source1 = RefSource(
        "source1", #Node id or name
        OperationalProfile(cap_prof), # :cap
        FixedProfile(100), #variable OPEX
        FixedProfile(0), #Fixed OPEX
        Dict(power => 1), #output from the node
        [EmissionsProcess(Dict(co2 => OperationalProfile(price_prof)))]
    )
source2 = RefSource(
        "source2",
        FixedProfile(100),
        OperationalProfile(price_prof), #:opex_var
        FixedProfile(0), #
        Dict(power => 1),
    )

#create a dictionary containing lenses to the OperationalProfile
d_all = EMRH._create_lens_dict_oper_prof([source1, source2]) #Dict(source1 => [[:cap], [:data]])
d_s1 = EMRH._create_lens_dict_oper_prof(source1)

#keys to the dictionaries are the paths containing OperationalProfile
paths_oper_s1 = EMRH._find_paths_operational_profile(source1)

#example usage
lens_s1_cap = d_all[source1][paths_oper_s1[1]]
lens_s1_price = d_all[source1][paths_oper_s1[2]]
lens_s1_cap_v2 = d_s1[paths_oper_s1[1]]
@assert all(lens_s1_cap(source1).vals .== source1.cap.vals)
@assert all(lens_s1_price(source1).vals .== source1.data[1].emissions[co2].vals)
@assert all(lens_s1_cap_v2(source1).vals .== source1.cap.vals)
```
"""
function _create_lens_dict_oper_prof(n::Vector{<:EMB.Node})
    return Dict(ni => _create_lens_dict_oper_prof(ni) for ni ∈ n)
end
function _create_lens_dict_oper_prof(n::EMB.Node)
    paths_oper = _find_paths_operational_profile(n)
    return Dict(field_id => _create_lens_for_field(field_id) for field_id ∈ paths_oper)
end

"""
    _create_lens_for_field(field_id::Vector{<:Any})

Creates a `lens`, which can be used to inspect or reset variables.

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
    #can return only idx, but this adds an extra check that idx is an int
    return "[" * string(parse(Int64, idx)) * "]"
end
function _path_type(val::Resource)
    global res = val
    return "[res]"
end

"""
    _set_values_operational_profile(
        m::JuMP.Model,
        case_copy,
        n::EMB.Node,
        update_dict::Dict{EMB.Node,Dict},
        lens_dict::Dict{EMB.Node,Dict};
        multiplier = 1,
    )

Updates the value of the POI parameter for node `n` based on the values of the node `n` in
`case_copy` for the period `𝒽`.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _set_values_operational_profile(
    m::JuMP.Model,
    case_copy,
    n::EMB.Node,
    update_dict::Dict{EMB.Node,Dict},
    lens_dict::Dict{EMB.Node,Dict};
    multiplier = 1,
)
    n_paths_to_oper_prof = _find_paths_operational_profile(n)
    for n_path ∈ n_paths_to_oper_prof
        new_values = _get_new_POI_values(n, lens_dict[n][n_path]; multiplier = multiplier)

        for (i, t) ∈ enumerate(case_copy[:T])
            MOI.set(m, POI.ParameterValue(), update_dict[n][n_path][t], new_values[i])
        end
    end
    return m
end

"""
    _get_node_rh(n::EMB.Node, lens_dict, 𝒯ᴿᴴ)

Returns a new node identical to `n`, except that all its `OperationalProfile`s are sliced
contain only the values specified in `𝒯ᴿᴴ`.
"""
function _get_node_rh(n::EMB.Node, lens_dict, 𝒯ᴿᴴ)
    paths_oper = _find_paths_operational_profile(n)
    if isempty(paths_oper)
        #deepcopy is required to make the following work:
        #@test case[:nodes][3].data[1].val == 0.5 # InitStorageData object unchanged
        #which is found in @testset "Dummy numerical examples" (test_examples.jl)
        return deepcopy(n)
    else
        for p ∈ paths_oper
            lens = lens_dict[n][p]
            val = lens(n)
            @reset lens(n) = OperationalProfile(val[𝒯ᴿᴴ])
        end
        return n
    end
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
    _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)

Currently, it returns the value lens(n).vals.

!!! note
    The idea is to slice the currently received value based on the horizon `𝒽`. This is
    not implemented yet.
    The `multiplier` is there for testing puroposes.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _get_new_POI_values(n::EMB.Node, lens, 𝒽; multiplier = 1)
    return _get_new_POI_values(n, lens; multiplier = multiplier) #TODO: slice this based on h
end
function _get_new_POI_values(n::EMB.Node, lens; multiplier = 1)
    return lens(n).vals .* multiplier
end

"""
    _get_node_index(needle::EMB.Node, haystack::Vector{<:EMB.Node})

Returns the index of `needle` in `haystack`, checking that the field `id` are equal.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _get_node_index(needle::EMB.Node, haystack::Vector{<:EMB.Node})
    haystack_id = [h.id for h ∈ haystack]
    @assert _has_unique_strings(haystack_id) "'haystack' = $(haystack) has non-unique strings."
    return findfirst(isequal(needle.id), haystack_id)
end

"""
    _has_unique_strings(v::Vector{String})

Returns `true` if all the strings in `v` are unique, `false` otherwise.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.
"""
function _has_unique_strings(v::Vector{String})
    return length(v) == length(Set(v)) #Set(v) contains only unique elements
end

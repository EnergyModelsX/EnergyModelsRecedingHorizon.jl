"""
    init_rh_case_model(case, model, 𝒽, lens_dict, optimizer)

Initialize the provided receding horizon `case_rh` and `model_rh` types, the JuMP model `m`,
and the dictionary with the JuMP variables `update_dict` when utilizing `ParametricOptInterface`.

The initialization is utilizing the first horizon `𝒽`.
"""
function init_rh_case_model(case, model, 𝒽, lens_dict, optimizer)

    m = Model(() -> optimizer)

    # only works for operational profiles due to case[:T] definition and dispatches on get_property_rh,
    # must be improved to deal with more cases
    𝒯ᴿᴴ = TwoLevel(1, 1, SimpleTimes(durations(𝒽)))
    case_rh = Dict(
        :products => case[:products],
        :T => 𝒯ᴿᴴ,
    )

    # Initialize the dictionaries
    map_dict = Dict{Symbol, Dict}()
    update_dict = Dict{Symbol, Dict}()

    # Update the nodes with the parameter variables
    case_rh[:nodes], update_dict[:nodes] =
        _get_elements_rh(m, case[:nodes], map_dict, lens_dict[:nodes], 𝒯ᴿᴴ)
    map_dict[:nodes] =
        Dict(case[:nodes][i] => case_rh[:nodes][i] for i ∈ 1:length(case[:nodes]))

    # Update the links with the parameter variables
    case_rh[:links], update_dict[:links] =
        _get_elements_rh(m, case[:links], map_dict, lens_dict[:links], 𝒯ᴿᴴ)

    # Update the model with the parameter variables
    model_rh, update_dict[:model] = _get_model_rh(m, model, map_dict, lens_dict[:model], 𝒯ᴿᴴ)

    return case_rh, model_rh, update_dict, m
end
"""
    update_model!(m, case, model, 𝒽, lens_dict, update_dict, init_data)

Update the JuMP model `m` with the new values for horizon `𝒽`.
"""
function update_model!(m, case, model, 𝒽, lens_dict, update_dict, init_data)
    # Identify the operational period
    opers = collect(case[:T])[indices_optimization(𝒽)]

    # Update the parameters of the nodes, links, and the model
    _set_elements_rh!(m, lens_dict[:nodes], update_dict[:nodes], init_data, opers)
    _set_elements_rh!(m, lens_dict[:links], update_dict[:links], init_data, opers)
    _set_elements_rh!(m, lens_dict[:model], update_dict[:model], init_data, opers)
end

"""
    get_rh_case_model(case, model, 𝒽, lens_dict, init_data = nothing)

Returns a pair `(case_rh, model_rh)` that corresponds to the receding horizon problem of `(case, model)`
evaluated at the horizon indices `𝒽`, initialized using `init_data`.
"""
function get_rh_case_model(case, model, 𝒽, lens_dict, init_data = nothing)
    # only works for operational profiles due to case[:T] definition and dispatches on get_property_rh,
    # must be improved to deal with more cases
    opers = collect(case[:T])[indices_optimization(𝒽)]
    case_rh = Dict(
        :products => case[:products],
        :T => TwoLevel(1, 1, SimpleTimes(durations(𝒽))),
    )
    map_dict = Dict{Symbol, Dict}()
    case_rh[:nodes] =
        _get_elements_rh(case[:nodes], map_dict, lens_dict[:nodes], opers)
    map_dict[:nodes] =
        Dict(case[:nodes][i] => case_rh[:nodes][i] for i ∈ 1:length(case[:nodes]))

    case_rh[:links] = _get_elements_rh(case[:links], map_dict, lens_dict[:links], opers)
    model_rh = _get_model_rh(model, map_dict, lens_dict[:model], opers)

    if !isnothing(init_data)
        𝒩ⁱⁿⁱᵗ_rh = filter(has_init, case_rh[:nodes])
        # index of init_data in nodes: depends on init data being unique
        𝒾ⁱⁿⁱᵗ = collect(findfirst(map(is_init_data, node_data(n))) for n ∈ 𝒩ⁱⁿⁱᵗ_rh)
        # place initialization data in nodes
        for (n, i, init_data_node) ∈ zip(𝒩ⁱⁿⁱᵗ_rh, 𝒾ⁱⁿⁱᵗ, init_data)
            node_data(n)[i] = init_data_node
        end
    end

    return (case_rh, model_rh)
end

"""
    _create_lens_dict_oper_prof(n::Vector{EMB.Node})
    _create_lens_dict_oper_prof(ℒ::Vector{<:Link})
    _create_lens_dict_oper_prof(n::EMB.Node)
    _create_lens_dict_oper_prof(l::EMB.Link)
    _create_lens_dict_oper_prof(model::RecHorEnergyModel)

Function to create a dictionary for storing lenses pointing to fields that are updated in the
individual types.

In general, lenses are generated for fields with `OperationalProfile`s. In addition, in the
case of links, this includes as well the fields `to` and `from` as the nodes are changed,
and hence, the fields require an update.

# Example

```julia
using EnergyModelsBase
using EnergyModelsRecHorizon
using TimeStruct
const EMRH = EnergyModelsRecHorizon

# Generate objects
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

# Create a dictionary containing lenses to the OperationalProfile
d_all = EMRH._create_lens_dict_oper_prof([source1, source2]) #Dict(source1 => [[:cap], [:data]])
d_s1 = EMRH._create_lens_dict_oper_prof(source1)

# Keys to the dictionaries are the paths containing OperationalProfile
paths_oper_s1 = EMRH._find_paths_operational_profile(source1)

# Example usage
lens_s1_cap = d_all[source1][paths_oper_s1[1]]
lens_s1_price = d_all[source1][paths_oper_s1[2]]
lens_s1_cap_v2 = d_s1[paths_oper_s1[1]]
@assert all(lens_s1_cap(source1).vals .== source1.cap.vals)
@assert all(lens_s1_price(source1).vals .== source1.data[1].emissions[co2].vals)
@assert all(lens_s1_cap_v2(source1).vals .== source1.cap.vals)
```
"""
function _create_lens_dict_oper_prof(𝒩::Vector{<:EMB.Node})
    return Dict(n => _create_lens_dict_oper_prof(n) for n ∈ 𝒩)
end
function _create_lens_dict_oper_prof(ℒ::Vector{<:Link})
    return Dict(l => _create_lens_dict_oper_prof(l) for l ∈ ℒ)
end
function _create_lens_dict_oper_prof(n::EMB.Node)
    paths_oper = _find_paths_operational_profile(n)
    return Dict(field_id => _create_lens_for_field(field_id) for field_id ∈ paths_oper)
end
function _create_lens_dict_oper_prof(l::EMB.Link)
    paths_oper = _find_paths_operational_profile(l)
    return Dict(field_id => _create_lens_for_field(field_id) for field_id ∈ paths_oper)
end
function _create_lens_dict_oper_prof(model::RecHorEnergyModel)
    paths_oper = _find_paths_operational_profile(model)
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
    "power_source",                 # Node id or name
    OperationalProfile(cap_prof),   # Capacity
    FixedProfile(100),              # Variable OPEX
    FixedProfile(0),                # Fixed OPEX
    Dict(power => 1),               # Output from the node
    [EmissionsProcess(Dict(co2 => OperationalProfile(price_prof)))]
    # Line above: CO2 process emissions
)

paths_oper_source = EMRH._find_paths_operational_profile(source)
@assert all(paths_oper_source .== Any[[:cap], [:data, "idx_1", :emissions, co2]])
lens_source_cap = EMRH._create_lens_for_field(paths_oper_source[1])
lens_source_data = EMRH._create_lens_for_field(paths_oper_source[2])

lens_source_cap(source) #returns OperationalProfile(cap_prof)
@assert all(cap_prof .== lens_source_cap(source).vals)
@assert all(price_prof .== lens_source_data(source).vals)

# Lenses can also be used for @reset
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
    _get_elements_rh(𝒩::Vector{<:EMB.Node}, map_dict, lens_dict, opers::Vector{<:TS.TimePeriod})
    _get_elements_rh(ℒ::Vector{<:Link}, map_dict, lens_dict, opers::Vector{<:TS.TimePeriod})


Returns a new element vector identical to the original element vector`𝒩::Vector{<:EMB.Node}`
or ℒ::Vector{<:Link} with all fields identified through the lenses in `lens_dict `with
adjustments in the values of `OperationalProfile`s due to the change in the horizon as
indicated through the operational periods array `opers`.

!!! note "Node"
    All operational periods are reset with the values of the array of operational periods
    `opers`.

!!! tip "Link"
    All operational periods are reset with the values of the array of operational periods
    `opers`.
    All connections in the fields `to` and `from` are updated with the respective nodes as
    outlined in the `map_dict`.
"""
function _get_elements_rh(
    𝒩::Vector{<:EMB.Node},
    map_dict,
    lens_dict,
    opers::Vector{<:TS.TimePeriod}
)
    𝒩ʳʰ = deepcopy(𝒩)
    for (k, n) ∈ enumerate(𝒩)
        if isempty(lens_dict[n])
            𝒩ʳʰ[k] = deepcopy(n)
        else
            for (_, lens) ∈ lens_dict[n]
                val = lens(n)
                n = _reset_field(n, lens, val, map_dict, opers)
            end
            𝒩ʳʰ[k] = n
        end
    end
    return 𝒩ʳʰ
end
function _get_elements_rh(
    ℒ::Vector{<:Link},
    map_dict,
    lens_dict,
    opers::Vector{<:TS.TimePeriod}
)
    ℒʳʰ = deepcopy(ℒ)
    for (k, l) ∈ enumerate(ℒ)
        for (_, lens) ∈ lens_dict[l]
            val = lens(l)
            l = _reset_field(l, lens, val, map_dict, opers)
        end
        ℒʳʰ[k] = l
    end
    return ℒʳʰ
end

"""
    _reset_field(x_rh, lens::L, val::EMB.Node, map_dict, opers::Vector{<:TS.TimePeriod}) where {L <: Union{PropertyLens, ComposedFunction}}
    _reset_field(x_rh, lens::L, val::Real, map_dict, opers::Vector{<:TS.TimePeriod}) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    _reset_field(x_rh, lens::L, val::Vector{T}, map_dict, opers::Vector{<:TS.TimePeriod}) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    _reset_field(x_rh, lens::L, val::OperationalProfile, map_dict, opers::Vector{<:TS.TimePeriod}) where {L <: Union{PropertyLens, ComposedFunction}}


Resets the field expressed through `lens` of element `x_rh` with the value provided through
`val`. The following methods are implemented:

1. `val::EMB.Node` uses the `map_dict` for identifying the correct node,
2. `val::Real` uses the the value directly,
3. `Vector{T}` where `T<:Real` uses the the value directly, and
4. `val::OperationalProfile` creates a new operational profile based on the original
   operational profile and the set of operational periods `opers`.
"""
function _reset_field(
    x_rh,
    lens::L,
    val::EMB.Node,
    map_dict,
    opers::Vector{<:TS.TimePeriod}
)where {L <: Union{PropertyLens, ComposedFunction}}
    @reset lens(x_rh) = map_dict[:nodes][val]
    return x_rh
end
function _reset_field(
    x_rh,
    lens::L,
    val::T,
    map_dict,
    opers::Vector{<:TS.TimePeriod}
) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    @reset lens(x_rh) = val
    return x_rh
end
function _reset_field(
    x_rh,
    lens::L,
    val::Vector{T},
    map_dict,
    opers::Vector{<:TS.TimePeriod}
) where {L <: Union{PropertyLens, ComposedFunction}, T<:Real}
    @reset lens(x_rh) = val
    return x_rh
end
function _reset_field(
    x_rh,
    lens::L,
    val::OperationalProfile,
    map_dict,
    opers::Vector{<:TS.TimePeriod},
)where {L <: Union{PropertyLens, ComposedFunction}}
    @reset lens(x_rh) = OperationalProfile(val[opers])
    return x_rh
end

"""
    _get_model_rh(model::RecHorEnergyModel, map_dict, lens_dict, opers::Vector{<:TS.TimePeriod})

Returns a new model with adjustments in the values of `OperationalProfile`s due to the
change in the horizon as indicated through the operational periods array `opers`.
"""
function _get_model_rh(
    model::RecHorEnergyModel,
    map_dict,
    lens_dict,
    opers::Vector{<:TS.TimePeriod}
)
    if isempty(lens_dict)
        return deepcopy(model)
    else
        for (_, lens) ∈ lens_dict
            val = lens(model)
            @reset lens(model) = OperationalProfile(val[opers])
        end
        return model
    end
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

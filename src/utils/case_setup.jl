"""
    get_rh_case_model(𝒰, opers, 𝒯ᵣₕ)

Update the UpdateCase `𝒰` with the new values in the optimization problem given by the
time structure 𝒯ᵣₕ.

In addition, the UpdateCase `𝒰` is updated with the new mapping between the operational
periods of the optimization (through `𝒯ᵣₕ`) and the original (through `opers`) problem.
"""
function get_rh_case_model(𝒰, opers, 𝒯ᵣₕ)
    # Update the individual Substitution types within the `UpdateCase`
    _update_elements_rh!(get_sub_model(𝒰), 𝒰, opers)
    _update_elements_rh!(get_sub_products(𝒰), 𝒰, opers)
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        _update_elements_rh!(𝒮, 𝒰, opers)
    end
    𝒰.opers = Dict(zip(𝒯ᵣₕ, opers))
end

"""
    _create_lens_dict_oper_prof(𝒳::Vector{<:AbstractElement}
    _create_lens_dict_oper_prof(x::AbstractElement)
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
function _create_lens_dict_oper_prof(𝒳::Vector{<:AbstractElement})
    return Dict(x => _create_lens_dict_oper_prof(x) for x ∈ 𝒳)
end
function _create_lens_dict_oper_prof(x::AbstractElement)
    paths_oper = _find_paths_operational_profile(x)
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
_path_type(val::String) = val
function _path_type(val::Resource)
    global res = val
    return "[res]"
end
_path_type(val::AbstractPath) = ""

"""
    _update_elements_rh!(𝒮::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    _update_elements_rh!(s:::AbstractSub, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Updates the elements within the `Vector{<:AbstractSub}` or `AbstractSub` with the new values,
The update only takes place when the field `reset` of a given `AbstractSub` is not empty.
In this case, the subfunction [`_reset_field`](@ref) is called.
"""
function _update_elements_rh!(
    𝒮::Vector{<:AbstractSub},
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    for s ∈ 𝒮
        _update_elements_rh!(s, 𝒰, opers)
    end
end
function _update_elements_rh!(
    s::AbstractSub,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    if isempty(s.resets)
        s.new = deepcopy(original(s))
    else
        for res_type ∈ s.resets
            s.new = _reset_field(updated(s), res_type, 𝒰, opers)
        end
    end
end

"""
    reset_field(x_rh, res_type::ElementReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    reset_field(x_rh, res_type::InitReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
    reset_field(x_rh, res_type::OperReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})

Resets the field expressed through `res_type` of element `x_rh` with the new value. The type
of the new value is depending on the specified `res_type`:

1. `res_type::ElementReset` uses `𝒰` for identifying the new element,
2. `res_type::InitReset` uses the value in `res_type` directly,
3. `res_type::OperReset` creates a new operational profile based on the original
   operational profile and the set of operational periods `opers`.
"""
function _reset_field(
    x_rh,
    res_type::ElementReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    @reset res_type.lens(x_rh) = updated(𝒰, res_type.val)
    return x_rh
end
function _reset_field(
    x_rh,
    res_type::InitReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    @reset res_type.lens(x_rh) = res_type.val
    return x_rh
end
function _reset_field(
    x_rh,
    res_type::OperReset,
    𝒰::UpdateCase,
    opers::Vector{<:TS.TimePeriod},
)
    @reset res_type.lens(x_rh) = OperationalProfile(res_type.val[opers])
    return x_rh
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


function _create_updatetype(model::RecHorEnergyModel)
    paths_model = _find_paths_operational_profile(model)
    reset_model = AbstractReset[ResetType(field_id, field_id[end], x) for field_id ∈ paths_model]
    return UpdateCase(Substitution(model, reset_model), Dict(), ProductSub[], Vector[])
end
function _add_elements!(𝒰::UpdateCase, 𝒫::Vector{T}) where {T<:Resource}
    for p ∈ 𝒫
        paths_oper = _find_paths_operational_profile(p)
        reset_types = AbstractReset[ResetType(field_id, field_id[end], p) for field_id ∈ paths_oper]
        push!(get_sub_products(𝒰), Substitution(p, reset_types))
    end
end
function _add_elements!(𝒰::UpdateCase, 𝒳::Vector{T}) where {T <: AbstractElement}
    push!(get_sub_elements_vec(𝒰), _ele_to_sub(T)[])
    for x ∈ 𝒳
        paths_oper = _find_paths_operational_profile(x)
        reset_types = AbstractReset[ResetType(field_id, field_id[end], x) for field_id ∈ paths_oper]
        push!(get_sub_elements_vec(𝒰)[end], Substitution(x, reset_types))
    end
end

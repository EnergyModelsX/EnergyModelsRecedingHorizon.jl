"""
    _find_update_paths(x::Union{AbstractElement, Resource, RecHorEnergyModel})
    _find_update_paths(x::StorageValueCuts)

Returns all paths within an [`AbstractElement`](@extref EnergyModelsBase.AbstractElement),
a [`Resource`](@extref EnergyModelsBase.Resource), a [`RecHorEnergyModel`](@ref), or a
[`StorageValueCuts`](@ref) that **must** be updated in the receding horizon framework as
`Vector{Vector}`.

The individual subfunctions are given as:

    _find_update_paths(field::AbstractElement, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::StorageValueCut, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::Vector{<:Data}, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::T, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:Union{Data, EMB.AbstractStorageParameters, ElementValue}}
    _find_update_paths(field::AbstractDict, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::OperationalProfile, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::StrategicProfile, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::Any, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::AbstractInitData, current_path::Vector{Any}, all_paths::Vector{Any})
    _find_update_paths(field::InitData, current_path::Vector{Any}, all_paths::Vector{Any})

!!! note "Introducing new `AbstractInitData`"
    When introducing a new subtype to [`AbstractInitData`](@ref), you **must** also create a
    new method for this function as it is not possible to cover all potential cases in which
    the new data is designed.

# Example

```julia
power = ResourceCarrier("power", 0.0)
co2 = ResourceEmit("co2", 1.0)
sink = RefSink(
    "a_sink",                                               # Field `:id`
    FixedProfile(1e5),                                      # Field `:cap`
    Dict(:surplus => OperationalProfile(zeros(10)),
         :deficit => OperationalProfile(10*ones(10))),      # Field `:penalty`
    Dict(power => 1),                                       # Field `:input`
    [EmissionsProcess(Dict(co2 => OperationalProfile(rand(10))))] # Field `:data`
)

EMRH._find_update_paths(sink)
# returns a 3-element Vector{Any}:
 Any[:penalty, "[:deficit]", EnergyModelsRecHorizon.OperPath()]
 Any[:penalty, "[:surplus]", EnergyModelsRecHorizon.OperPath()]
 Any[:data, "[1]", :emissions, co2, EnergyModelsRecHorizon.OperPath()]

# The function can also be used for checking other `types`:
all_paths = []
current_path = Any[:a_path]
a_dict = Dict(:a => Dict(:b1 => Dict(:c => OperationalProfile([1])),
    :b2 => OperationalProfile([1]), :b3 => [1]))

EMRH._find_update_paths(a_dict, current_path, all_paths)
# all_paths is now a 2-element Vector{Any}:
 Any[:a_path, "[:a]", "[:b2]", EnergyModelsRecHorizon.OperPath()]
 Any[:a_path, "[:a]", "[:b1]", "[:c]", EnergyModelsRecHorizon.OperPath()]
```
"""
function _find_update_paths(
    x::T
) where {T <: Union{AbstractElement, Resource, RecHorEnergyModel}}
    all_paths = []
    current_path = []
    for f ∈ fieldnames(T)
        new_path = vcat(current_path, f)
        _find_update_paths(getfield(x, f), new_path, all_paths)
    end
    return all_paths
end
function _find_update_paths(x::StorageValueCuts)
    all_paths = Any[[:time_weight, TimeWeightPath()]]
    current_path = []
    for (i, c) ∈ enumerate(cuts(x))
        new_path = vcat(current_path, [:cuts, "[$(i)]"])
        _find_update_paths(c, new_path, all_paths)
    end
    return all_paths
end
function _find_update_paths(
    field::AbstractElement,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    new_path = vcat(current_path, [ElementPath()])
    push!(all_paths, new_path)
end
function _find_update_paths(
    field::StorageValueCut,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    for (i, c) ∈ enumerate(field.coeffs)
        new_path = vcat(current_path, [:coeffs, "[$(i)]"])
        _find_update_paths(c, new_path, all_paths)
    end
end
function _find_update_paths(
    field::Vector{<:Data},
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    for (i, d) ∈ enumerate(field)
        new_path = vcat(current_path, ["[$(i)]"])
        _find_update_paths(d, new_path, all_paths)
    end
end
function _find_update_paths(
    field::T,
    current_path::Vector{Any},
    all_paths::Vector{Any},
) where {T<:Union{Data, EMB.AbstractStorageParameters, ElementValue}}
    for f ∈ fieldnames(T)
        new_path = vcat(current_path, f)
        _find_update_paths(getfield(field, f), new_path, all_paths)
    end
end
function _find_update_paths(
    field::AbstractDict,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    for (key, value) ∈ field
        new_path = vcat(current_path, _dict_key(key))
        _find_update_paths(value, new_path, all_paths)
    end
end
function _find_update_paths(
    field::OperationalProfile,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    new_path = vcat(current_path, [OperPath()])
    push!(all_paths, new_path)  # Add current_path to all_paths
end
function _find_update_paths(
    field::StrategicProfile,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    @warn("EMRH should not be used with strategic profiles", maxlog=1)
end
function _find_update_paths(
    field::Any,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
end
function _find_update_paths(
    field::AbstractInitData,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    error(
        "No method of the function `_find_update_paths(field, current_path, all_path)` " *
        "defined for `$(typeof(field))`"
    )
end
function _find_update_paths(
    field::InitData,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    push!(current_path, :init_val_dict)
    for (key, _) ∈ field.init_val_dict    # all fields must be updated
        new_path = vcat(current_path, _dict_key(key))
        append!(new_path, [InitDataPath(key)])
        push!(all_paths, new_path)
    end
end

"""
    _dict_key(key::Symbol)
    _dict_key(key::String)
    _dict_key(key::Resource)

Function for translating a dictionary key type to an input which can be parsed into a lens.
"""
_dict_key(key::Symbol) = ["[:" * String(key) * "]"]
_dict_key(key::String) = ["[\"" * key * "\"]"]
_dict_key(key::Resource) = key


"""
    _create_lens_dict(𝒳::Vector{<:AbstractElement}
    _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})

Returns a dictionary with the field id as keys and lenses pointing to fields that are
updated in the individual type instances as values. The individual field ids are created
through calling the function [`_find_update_paths`](@ref), and the lenses are created with
[`_create_lens_for_field`](@ref).

Lenses are created for

1. all `OperationalProfile`s,
2. other `AbstractElement`, and
3. [`InitData`](@ref).

# Example

```julia
using EnergyModelsBase
using EnergyModelsRecHorizon
using TimeStruct
const EMRH = EnergyModelsRecHorizon

# Generate objects
cap_prof = OperationalProfile([20, 300])
em_prof = OperationalProfile([1, 2])
price_prof = OperationalProfile([40, 60])

power = ResourceCarrier("power", 0.0)
co2 = ResourceEmit("co2", 1.0)

source1 = RefSource(
    "source1",
    cap_prof,
    FixedProfile(100),
    FixedProfile(0),
    Dict(power => 1),
    [EmissionsProcess(Dict(co2 => em_prof))]
)
source2 = RefSource(
    "source2",
    FixedProfile(100),
    price_prof,
    FixedProfile(0),
    Dict(power => 1),
)

# Create a dictionary containing lenses to the OperationalProfile
d_all = EMRH._create_lens_dict([source1, source2])
# Returns Dict{RefSource, Dict{Vector{Any}}} with 2 entries:
 n_source1 => Dict{Vector{Any}, Any}([:data, "[1]", :emissions, co2, OperPath()]=>_.data[1].emissions[co2], [:cap, OperPath()]=>_.cap)
 n_source2 => Dict{Vector{Any}, PropertyLens{:opex_var}}([:opex_var, OperPath()]=>_.opex_var)

d_s1 = EMRH._create_lens_dict(source1)
# Returns Dict{Vector{Any}, Any} with 2 entries:
 [:data, "[1]", :emissions, co2, OperPath()] => _.data[1].emissions[co2]
 [:cap, OperPath()]                          => _.cap
```
"""
function _create_lens_dict(𝒳::Vector{<:AbstractElement})
    return Dict(x => _create_lens_dict(x) for x ∈ 𝒳)
end
function _create_lens_dict(x::Union{AbstractElement, RecHorEnergyModel})
    paths_oper = _find_update_paths(x)
    return Dict(field_id => _create_lens_for_field(field_id) for field_id ∈ paths_oper)
end

"""
    _create_lens_for_field(field_id::Vector{<:Any})

Returns a `lens`, which can be used to inspect or reset variables. The lens is based on the
`field_id` obtained through the function [`_find_update_paths`](@ref).

Example:
```julia
using Accessors: @reset
using EnergyModelsBase
using EnergyModelsRecHorizon
using TimeStruct
const EMRH = EnergyModelsRecHorizon

cap_prof = OperationalProfile([20, 300])
em_prof = OperationalProfile([1,2])
power = ResourceCarrier("power", 0.0)
co2 = ResourceEmit("co2", 1.0)

source = RefSource(
    "power_source",                         # Node id or name
    cap_prof,                               # Capacity
    FixedProfile(100),                      # Variable OPEX
    FixedProfile(0),                        # Fixed OPEX
    Dict(power => 1),                       # Output from the node
    [EmissionsProcess(Dict(co2 => em_prof))] # Line above: CO2 process emissions
)

paths_oper_source = EMRH._find_update_paths(source)
@assert all(paths_oper_source .== Any[
    [:cap, EMRH.OperPath()], [:data, "[1]", :emissions, co2, EMRH.OperPath()]
])
lens_source_cap = EMRH._create_lens_for_field(paths_oper_source[1])
lens_source_data = EMRH._create_lens_for_field(paths_oper_source[2])

# Check that the values returned through the lenses are based on the actual values
@assert all(cap_prof == lens_source_cap(source))
@assert all(em_prof == lens_source_data(source))

# Lenses can also be used for resetting values using @reset
cap_prof_new = OperationalProfile([90,100])
@reset lens_source_cap(source) = cap_prof_new
@assert all(cap_prof_new == lens_source_cap(source))
```
"""
function _create_lens_for_field(field_id::Vector{<:Any})
    str = ""
    for k ∈ field_id
        str *= _path_type(k)
    end
    global global_str_lens = "@o _" * str
    lens = eval(Meta.parse(global_str_lens))
    return lens
end

"""
    _path_type(val::Symbol)
    _path_type(val::String)
    _path_type(val::Resource)
    _path_type(val::AbstractPath)

Translate the individual value to the required format for creating the lense string.

In the case of a resource, it creates a global variable calles `res` which can be evaluated
in the parse.
"""
_path_type(val::Symbol) = "." * String(val)
_path_type(val::String) = val
function _path_type(val::Resource)
    global res = val
    return "[res]"
end
_path_type(val::AbstractPath) = ""

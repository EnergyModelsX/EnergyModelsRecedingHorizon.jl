
"""
    _fields_with_operational_profile(n::Union{NetworkNode, Source, Sink})
    _fields_with_operational_profile(n::Storage)
    _fields_with_operational_profile(n::Availability)
    _fields_with_operational_profile(n::EMB.Node)

Function for returning the fields in a node containing an `OperationalProfile`.
If no fields are found, it returns `Symbol[]`.

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.

# Example

```julia
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
```
"""
function _fields_with_operational_profile(n::EMB.Node)
    return [
        fn for fn ∈ fieldnames(typeof(n)) if _has_field_operational_profile(getfield(n, fn))
    ]
end

function _fields_with_operational_profile(n::Availability)
    return Symbol[]
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

!!! note
    This function is currently not in use. Function is kept since it may be beneficial later.

# Example

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
_has_field_operational_profile(StorageInitData(4.0))

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
    return any([
        _has_field_operational_profile(getfield(field, f)) for f ∈ fieldnames(typeof(field))
    ])
end
function _has_field_operational_profile(field::Dict)
    return any([_has_field_operational_profile(val) for (key, val) ∈ field])
end
function _has_field_operational_profile(field::EMB.AbstractStorageParameters)
    return any([
        _has_field_operational_profile(getfield(field, f)) for f ∈ fieldnames(typeof(field))
    ])
end
_has_field_operational_profile(field) = false

"""
    _find_paths_operational_profile(n::Union{NetworkNode, Source, Sink, Storage})
    _find_paths_operational_profile(field::Union{NetworkNode, Source, Sink, Storage},
        current_path::Vector{Any}, all_paths::Vector{Any})
    _find_paths_operational_profile(field::Vector{<:Data}, current_path::Vector{Any},
        all_paths::Vector{Any})
    _find_paths_operational_profile(field::Union{Data, EMB.AbstractStorageParameters},
        current_path::Vector{Any}, all_paths::Vector{Any})
    _find_paths_operational_profile(field::AbstractDict, current_path::Vector{Any},
        all_paths::Vector{Any})
    _find_paths_operational_profile(field::OperationalProfile, current_path::Vector{Any},
        all_paths::Vector{Any})
    _find_paths_operational_profile(field::StrategicProfile, current_path::Vector{Any},
        all_paths::Vector{Any})
    _find_paths_operational_profile(field::Any, current_path::Vector{Any},
        all_paths::Vector{Any})

Function for returning the fields in a node `n` containing an `OperationalProfile`, returning
a list of the path. The list can be nested, depending on the number of `OperationalProfile`said
within the type

# Example

```julia
co2 = ResourceEmit("co2", 1.0)
sink = RefSink(
    "a_sink", # :id
    FixedProfile(1e5), # :cap
    Dict(:surplus => OperationalProfile(zeros(dim_t)),
        :deficit => OperationalProfile(1e6*ones(dim_t))), # :penalty
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
a_dict = Dict(:a => Dict(:b1 => Dict(:c => OperationalProfile([1])),
    :b2 => OperationalProfile([1]), :b3 => [1]))
EMRH._find_paths_operational_profile(a_dict, current_path, all_paths)

# all_paths are now a 2-element Vector{Any}: [Any[:a_path, :a, :b2], Any[:a_path, :a, :b1, :c]]
```
"""
function _find_paths_operational_profile(x::AbstractElement)
    all_paths = []
    current_path = []
    for f ∈ fieldnames(typeof(x))
        new_path = vcat(current_path, f)
        _find_paths_operational_profile(getfield(x, f), new_path, all_paths)
    end
    return all_paths
end
function _find_paths_operational_profile(p::Resource)
    all_paths = []
    current_path = []
    for f ∈ fieldnames(typeof(p))
        new_path = vcat(current_path, f)
        _find_paths_operational_profile(getfield(p, f), new_path, all_paths)
    end
    return all_paths
end
function _find_paths_operational_profile(model::RecHorEnergyModel)
    all_paths = []  # To store the paths to lists
    current_path = []
    for f ∈ fieldnames(typeof(model))
        new_path = vcat(current_path, f)
        _find_paths_operational_profile(getfield(model, f), new_path, all_paths)
    end
    return all_paths
end
function _find_paths_operational_profile(
    field::AbstractElement,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    new_path = vcat(current_path, [ElementPath()])
    push!(all_paths, new_path)
end
function _find_paths_operational_profile(
    field::Vector{T},
    current_path::Vector{Any},
    all_paths::Vector{Any},
) where {T<:Data}
    for (i, d) ∈ enumerate(field)
        new_path = vcat(current_path, ["[$(i)]"])
        _find_paths_operational_profile(d, new_path, all_paths)
    end
end
function _find_paths_operational_profile(
    field::Union{Data,EMB.AbstractStorageParameters},
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    for f ∈ fieldnames(typeof(field))
        new_path = vcat(current_path, f)
        _find_paths_operational_profile(getfield(field, f), new_path, all_paths)
    end
end
function _find_paths_operational_profile(
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
function _find_paths_operational_profile(
    field::AbstractDict,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    for (key, value) ∈ field
        new_path = vcat(current_path, _dict_key(key))
        _find_paths_operational_profile(value, new_path, all_paths)
    end
end
function _find_paths_operational_profile(
    field::OperationalProfile,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    new_path = vcat(current_path, [OperPath()])
    push!(all_paths, new_path)  # Add current_path to all_paths
end
function _find_paths_operational_profile(
    field::StrategicProfile,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    error("EMRH should not be used with strategic profiles")
end
function _find_paths_operational_profile(
    field::Any,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
end

_dict_key(key::Symbol) = ["[:" * String(key) * "]"]
_dict_key(key::String) = ["[\"" * key * "\"]"]
_dict_key(key::Resource) = key

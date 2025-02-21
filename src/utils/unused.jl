
"""
    _fields_with_operational_profile(n::EMB.Node)
    _fields_with_operational_profile(n::Availability)

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
_fields_with_operational_profile(n::Availability) = Symbol[]

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

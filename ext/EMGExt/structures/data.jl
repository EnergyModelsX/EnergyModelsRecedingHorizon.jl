
"""
    TransInitData{T} <: AbstractInitData

Initialization data type for `TransmissionMode`. It follows the same structure as the standard
[`InitData`](@ref). It is required as the indexing is different for `TransmissionMode`s
compared to `Node`s, `Link`s, or `Area`s.

# Fields
- **`val`**: initial state for node.
"""
struct TransInitData{T} <: EMRH.TransInitData{T}
    init_val_dict::Dict{Symbol,T}
end
EMRH.TransInitData(args...) = TransInitData(args...)

"""
    EMRH.has_init(a::Area)
    EMRH.has_init(l::Transmission)
    EMRH.has_init(tm::TransmissionMode)

Checks whether the Transmission corridor `l` or TransmissionMode `tm` has initialization
data.

In the case of an Area `a`, it returns false.
"""
EMRH.has_init(a::Area) = false
EMRH.has_init(l::Transmission) = any(EMRH.has_init(tm) for tm ∈ modes(l))
EMRH.has_init(tm::TransmissionMode) = any(is_init_data(data) for data ∈ mode_data(tm))

"""
    EMRH.data_init(a::Area)
    EMRH.data_init(l::Transmission)
    EMRH.data_init(tm::TransmissionMode)

Returns initialization data for Transmission corridor `l` or TransmissionMode `tm`. In the
case of a Transmission corridor, it returns all initialization data as `Vector`.

In the case of an Area `a`, it returns nothing.
"""
EMRH.data_init(a::Area) = nothing
EMRH.data_init(l::Transmission) = [EMRH.data_init(tm) for tm ∈ modes(l)]
EMRH.data_init(tm::TransmissionMode) =
    EMRH.has_init(tm) ? filter(is_init_data, mode_data(tm))[1] : nothing

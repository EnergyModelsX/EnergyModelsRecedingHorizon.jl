"""
    struct TransInitDataPath <: AbstractInitDataPath

Internal type for paths pointing towards [`TransInitData`](@ref).

# Fields
- **`idx::Int`** is the index of the mode within the associated `Transmission` corridor.
- **`key::Symbol`** is the key in the [`TransInitData`](@ref) (and correspondingly in the JuMP
  model).
"""
struct TransInitDataPath <: AbstractInitDataPath
    idx::Int
    key::Symbol
end

"""
    model_key(idp::TransInitDataPath)

Returns the model key (field `key`) of TransInitDataPath `idp`.
"""
EMRH.model_key(idp::TransInitDataPath) = idp.key

"""
    mutable struct AreaSub{T<:Area} <: AbstractSub

[`AbstractSub`](@ref) for [`Area`](@extref EnergyModelsGeography.Area)s.

# Fields
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types
  for the given [`Area`](@extref EnergyModelsGeography.Area).
"""
mutable struct AreaSub{T<:Area} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

EMRH._ele_to_sub(::Type{<:Area}) = AreaSub

"""
    get_areas(𝒰::UpdateCase)

Method for the equivalent `EnergyModelsGeography` function to extract the **new** `Area`s
of the individual [`AreaSub`](@ref) types of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMG.get_areas(𝒰::UpdateCase) = Area[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, Area)]


"""
    mutable struct TransmissionSub{T<:Transmission} <: AbstractSub

[`AbstractSub`](@ref) for [`Transmission`](@extref EnergyModelsGeography.Transmission)
corridor.

# Fields
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types
  for the given [`Transmission`](@extref EnergyModelsGeography.Transmission) corridor.
"""
mutable struct TransmissionSub{T<:Transmission} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

EMRH._ele_to_sub(::Type{<:Transmission}) = TransmissionSub

"""
    get_transmissions(𝒰::UpdateCase)

Method for the equivalent `EnergyModelsGeography` function to extract the **new** `Transmission`
corridors of the individual [`TransmissionSub`](@ref) types of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMG.get_transmissions(𝒰::UpdateCase) = Transmission[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, Transmission)]

EMRH.updated(𝒰::UpdateCase, a_old::Area) = get_mapping_updated(𝒰, "areas")[a_old]
EMRH.updated(𝒰::UpdateCase, l_old::Transmission) = get_mapping_updated(𝒰, "transmissions")[l_old]
EMRH.updated(𝒰::UpdateCase, tm_old::TransmissionMode) = get_mapping_updated(𝒰, "modes")[tm_old]
EMRH.original(𝒰::UpdateCase, a_new::Area) = get_mapping_original(𝒰, "areas")[a_new]
EMRH.original(𝒰::UpdateCase, l_new::Transmission) = get_mapping_original(𝒰, "transmissions")[l_new]
EMRH.original(𝒰::UpdateCase, tm_new::TransmissionMode) = get_mapping_original(𝒰, "modes")[tm_new]

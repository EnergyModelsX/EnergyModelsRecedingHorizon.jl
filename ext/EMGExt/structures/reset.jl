"""
    mutable struct AreaSub{T<:Area} <: AbstractSub

[`AbstractSub`](@ref) for [`Area`](@extref EnergyModelsGeography.Area)s.

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
  [`Area`](@extref EnergyModelsGeography.Area).
"""
mutable struct AreaSub{T<:Area} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

EMRH._ele_to_sub(::Type{<:Area}) = AreaSub

EMG.get_areas(𝒰::UpdateCase) = Area[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, Area)]


"""
    mutable struct TransmissionSub{T<:Transmission} <: AbstractSub

[`AbstractSub`](@ref) for [`Transmission`](@extref EnergyModelsGeography.Transmission)
corridor.

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
  [`Transmission`](@extref EnergyModelsGeography.Transmission) corridor.
"""
mutable struct TransmissionSub{T<:Transmission} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

EMRH._ele_to_sub(::Type{<:Transmission}) = TransmissionSub

EMG.get_transmissions(𝒰::UpdateCase) = Transmission[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, Transmission)]

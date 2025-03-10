

"""
    struct InitDataPath <: AbstractPath

Internal type for paths pointing towards [`InitData`](@ref) in the case of `TransmissionMode`s.

# Fields
- **`idx::Int`** is the index of the mode within the `Transmission` corridor.
- **`key::Symbol`** is the key in the [`InitData`](@ref) (and correspondingly in the JuMP
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

function EMRH.original(𝒰::UpdateCase, tm_new::TransmissionMode)
    𝒮ˡ = get_sub_ele(𝒰, Transmission)
    tm_old = nothing
    for s_l ∈ 𝒮ˡ
        idx = findfirst(tm -> tm == tm_new, modes(s_l.new))
        if !isnothing(idx)
            tm_old = modes(s_l.org)[idx]
            break
        end
    end
    return tm_old
end
function EMRH.updated(𝒰::UpdateCase, tm_org::TransmissionMode)
    𝒮ˡ = get_sub_ele(𝒰, Transmission)
    tm_new = nothing
    for s_l ∈ 𝒮ˡ
        idx = findfirst(tm -> tm == tm_org, modes(s_l.org))
        if !isnothing(idx)
            tm_new = modes(s_l.new)[idx]
            break
        end
    end
    return tm_new
end

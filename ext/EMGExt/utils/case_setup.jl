function EMRH._init_mapping!(𝒰::UpdateCase, ::Vector{T}) where {T<:Transmission}
    𝒰.map_org[_type_to_key(T)] = Dict{T,T}()
    𝒰.map_updated[_type_to_key(T)] = Dict{T,T}()
    𝒰.map_org[_type_to_key(TransmissionMode)] = Dict{TransmissionMode,TransmissionMode}()
    𝒰.map_updated[_type_to_key(TransmissionMode)] = Dict{TransmissionMode,TransmissionMode}()
end

function EMRH._add_mapping!(𝒰::UpdateCase, x::Transmission)
    𝒰.map_org[_type_to_key(Transmission)][x] = x
    𝒰.map_updated[_type_to_key(Transmission)][x] = x
    for tm ∈ modes(x)
        𝒰.map_org[_type_to_key(TransmissionMode)][tm] = tm
        𝒰.map_updated[_type_to_key(TransmissionMode)][tm] = tm
    end
end
function EMRH._add_mapping!(𝒰::UpdateCase, s::T) where {T<:TransmissionSub}
    𝒰.map_org[_type_to_key(T)][updated(s)] = original(s)
    𝒰.map_updated[_type_to_key(T)][original(s)] = updated(s)
    for (tm_old, tm_new) ∈ zip(modes(s.org), modes(s.new))
        𝒰.map_org[_type_to_key(TransmissionMode)][tm_new] = tm_old
        𝒰.map_updated[_type_to_key(TransmissionMode)][tm_old] = tm_new
    end
end

function EMRH._delete_mapping!(𝒰::UpdateCase, s::T) where {T<:TransmissionSub}
    delete!(𝒰.map_org[_type_to_key(T)], updated(s))
    delete!(𝒰.map_updated[_type_to_key(T)], original(s))

    for (tm_old, tm_new) ∈ zip(modes(s.org), modes(s.new))
        delete!(𝒰.map_org[_type_to_key(TransmissionMode)], tm_new)
        delete!(𝒰.map_updated[_type_to_key(TransmissionMode)], tm_old)
    end
end

EMRH._type_to_key(::Type{T}) where {T<:Union{Area, AreaSub}} = :areas
EMRH._type_to_key(::Type{T}) where {T<:Union{Transmission, TransmissionSub}} =
    :transmissions
EMRH._type_to_key(::Type{T}) where {T<:TransmissionMode} = :transmission_modes

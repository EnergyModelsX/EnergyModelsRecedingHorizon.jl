function EMRH._find_update_paths(
    field::T,
    current_path::Vector{Any},
    all_paths::Vector{Any},
) where {T<:TransmissionMode}
    for f ∈ fieldnames(T)
        new_path = vcat(current_path, f)
        _find_update_paths(getfield(field, f), new_path, all_paths)
    end
end
function EMRH._find_update_paths(
    field::Vector{T},
    current_path::Vector{Any},
    all_paths::Vector{Any},
) where {T<:TransmissionMode}
    for (i, d) ∈ enumerate(field)
        new_path = vcat(current_path, ["[$(i)]"])
        _find_update_paths(d, new_path, all_paths)
    end
end

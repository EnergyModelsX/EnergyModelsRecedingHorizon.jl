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
    field::TransInitData,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    push!(current_path, :init_val_dict)
    idx = parse(Int, current_path[2][2:end-1])
    for (key, _) ∈ field.init_val_dict    # all fields must be updated

        new_path = vcat(current_path, EMRH._dict_key(key))
        append!(new_path, [TransInitDataPath(idx, key)])
        push!(all_paths, new_path)
    end
end

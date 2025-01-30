
"""
    init_level(n::Storage{RecedingAccumulating})

Gets initialization values for the Storage node `n` from its data fields.
"""
function init_level(n::Storage{RecedingAccumulating})
    initdata = filter(is_init_data, node_data(n))
    @assert (length(initdata) == 1) "AbstractInitData badly defined" # TODO: check data elsewhere
    return first(initdata).init_val_dict[:stor_level]
end

"""
    get_init_state(m, n::Node, 𝒯_rh, 𝒽)

Returns an instance of `AbstractInitData` that can be used to initialize the system.

This is a fallback function where no specific node was defined. A new `InitData` is
returned with the same fields as initially provided.
"""
function get_init_state(m, n::EMB.Node, 𝒯_rh, 𝒽)
    init_data₀ = data_init(n)
    t_impl = collect(𝒯_rh)[length(indices_implementation(𝒽))]
    new_val_dict =
        Dict(key => value.(m[key][n, t_impl]) for key ∈ keys(init_data₀.init_val_dict)) # TODO: will NOT work for differently indexed variables
    return InitData(new_val_dict)
end

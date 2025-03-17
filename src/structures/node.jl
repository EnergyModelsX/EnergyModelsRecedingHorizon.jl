
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
    update_init_data!(m, ri::AbstractReset, x::AbstractElement, idp::InitDataPath, opers_implᵣₕ)

Updates the values of AbstractElement `x` for the AbstractReset `ri` with the value specified
by the `key` of the `idp`.
"""
function update_init_data!(
    m,
    ri::AbstractReset,
    x::AbstractElement,
    idp::InitDataPath,
    opers_implᵣₕ,
)
    t_last = last(opers_implᵣₕ)
    ri.val = value.(m[model_key(idp)][x, t_last])
end

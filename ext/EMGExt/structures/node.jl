"""
    EMRH.update_init_data!(m, ri::AbstractReset, l::Transmission, idp::TransInitDataPath, opers_implᵣₕ)

Updates the initial values of Transmission  corridor `l` for the AbstractReset `ri` with the
value specified by the `key` of the TransInitDataPath `idp`.

The mode for the variable is identified through the field `idx` of TransInitDataPath.
"""
function EMRH.update_init_data!(
    m,
    ri::AbstractReset,
    l::Transmission,
    idp::TransInitDataPath,
    opers_implᵣₕ,
)
    t_last = last(opers_implᵣₕ)
    ri.val = value.(m[EMRH.model_key(idp)][modes(l)[idp.idx], t_last])
end

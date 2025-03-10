"""
    EMRH.update_init_data!(m, ri::AbstractReset, l::Transmission, idp::TransInitDataPath, opers_implᵣₕ)

Updats the values of Transmission `l` for the AbstractReset `ri` with the value specified
by the `key` of the `idp`. It uses the mode indexed through the field `idx` of idp.
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

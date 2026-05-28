"""
    EMRH.update_init_data!(m, ri::AbstractReset, l::Transmission, idp::TransInitDataPath, opers_implᵣₕ)

When an abstract reset `ri` for a Transmission corridor`l` and a data path `idp` is provided
instead of the vector of `AbstractSub` vectors `𝒮ᵛᵉᶜᵢₙ`, it updates the value in
AbstractReset `ri` of AbstractElement `x` with the value of the variable specified by the
`key` of the `idp` in the last period of `opers_implᵣₕ` for the `TransmissionMode` specified
by the the `idx` of `idp`.
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

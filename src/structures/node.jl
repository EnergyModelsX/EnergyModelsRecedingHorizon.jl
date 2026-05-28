
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
    update_init_data!(m, 𝒮ᵛᵉᶜᵢₙ::Vector{Vector{T}}, opers_implᵣₕ) where {T<:AbstractSub}
    update_init_data!(m, ri::AbstractReset, x::AbstractElement, idp::InitDataPath, opers_implᵣₕ)

Updates the initial values of all `AbstractSub` vectors in `𝒮ᵛᵉᶜᵢₙ` given the implementation
horizon `opers_implᵣₕ`

When an abstract reset `ri` for an element `x` and a data path `idp` is provided instead of
the vector of `AbstractSub` vectors `𝒮ᵛᵉᶜᵢₙ`, it updates the value in AbstractReset `ri` of
AbstractElement `x` with the value of the variable specified by the `key` of the `idp` in
the last period of `opers_implᵣₕ`.
"""
function update_init_data!(m, 𝒮ᵛᵉᶜᵢₙ::Vector{Vector{T}}, opers_implᵣₕ) where {T<:AbstractSub}
    for 𝒮ᵢₙ ∈ 𝒮ᵛᵉᶜᵢₙ, s_in ∈ 𝒮ᵢₙ
        reset_init = filter(is_init_reset, resets(s_in))
        for ri ∈ reset_init
            update_init_data!(m, ri, updated(s_in), ri.path, opers_implᵣₕ)
        end
    end
end
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

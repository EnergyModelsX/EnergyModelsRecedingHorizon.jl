
"""
    init_level(n::Storage{RecedingAccumulating})

Gets initialization values for the Storage node `n` from its data fields.
"""
function init_level(n::Storage{RecedingAccumulating})
    initdata = filter(is_init_data, node_data(n))
    @assert (length(initdata) == 1) "InitData badly defined" # TODO: check data elsewhere
    return first(initdata).val
end

"""
    get_init_state(m, n::Node, 𝒯_rh, 𝒽)

Returns an instance of `InitData` that can be used to initialize the system.

This is a fallback function where no specific node was defined. A new `RefInitData` is
returned with the same fields as initially provided.
"""
function get_init_state(m, n::EMB.Node, 𝒯_rh, 𝒽)
    @warn "Fallback dispatch for get_init_state; this is possibly not the intended behavior"
    # TODO: would be nice to implement a standard behavior for simple states; Julian's example in data.jl may give a way
    initdata = filter(is_init_data, node_data(n))
    return RefInitData(initdata.val)
end
"""
    get_init_state(m, n::Storage{RecedingAccumulating}, 𝒯_rh, 𝒽)

Take the optimization solution `m` and find the initialization data of `n` corresponding to
the model state at the end of the implementation horizon defined in `𝒽`. The model `m` is
internally defined for the time structure `𝒯_rh`.
"""
function get_init_state(m, n::Storage{RecedingAccumulating}, 𝒯_rh, 𝒽)
    t_impl = collect(𝒯_rh)[length(indices_implementation(𝒽))] # solution for internal time structure
    level_t = value.(m[:stor_level][n, t_impl])
    return InitStorageData(level_t)
end
#= Ideas for implementing initialization constraints:
1) constraints_data(m, n, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)
    - sets initial state in model from data (not needed for storage, needed for new technologies)
2) get_init_state(m, n, 𝒯ᴿᴴₒᵤₜ, 𝒽)
    - gets initialization data at end of implementation horizon in 𝒽 from previous solution
3) constraints_state_time_iter(m, n, 𝒯) # in EnergyModelsHydrogen
4) constraints_x(m, n, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)
=#

"""
    Accessors.ConstructionBase.constructorof(obj::Type{<:Storage})
Allows using @reset for an `obj <: Storage`, which is a parametric type. 

"""
function Accessors.ConstructionBase.constructorof(obj::Type{<:Storage})
    return (args...) -> (obj(args...))
 end

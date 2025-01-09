using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

using HiGHS
using JuMP
using EnergyModelsBase
using TimeStruct
using EnergyModelsRecHorizon
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

"""
Example node type with initializable state.
"""
struct IncrementInitNode{T<:Real} <: EMB.Node
    id::Any
    increment::T
    data::Vector{<:Data}
end

EMB.has_input(n::IncrementInitNode) = false
EMB.has_output(n::IncrementInitNode) = false

"""
    variables_node(m, 𝒩ˢᵘᵇ::Vector{<:IncrementInitNode}, 𝒯, modeltype::EnergyModel)

Declaration of the single variable of `IncrementInitNode`.
"""
function EMB.variables_node(m, 𝒩ˢᵘᵇ::Vector{<:IncrementInitNode}, 𝒯, modeltype::EnergyModel)
    @variable(m, state[𝒩ˢᵘᵇ, 𝒯])
end

function EMB.create_node(m, n::IncrementInitNode, 𝒯, 𝒫, modeltype::EnergyModel)
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end
    constraints_state(m, n, 𝒯, modeltype)
    constraints_extravars(m, n, 𝒯, modeltype)
end

"""
    constraints_extravars(m, n::IncrementInitNode, 𝒯::TimeStructure, modeltype::EnergyModel)

Defines extra variables not necessary for `IncrementInitNode`.
"""
function constraints_extravars(
    m,
    n::IncrementInitNode,
    𝒯::TimeStructure,
    modeltype::EnergyModel,
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @constraint(m, [t_sp ∈ 𝒯ᴵⁿᵛ], m[:opex_var][n, t_sp] == 0)
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] == 0)
    @constraint(m, [t ∈ 𝒯], m[:cap_inst][n, t] == 0)
    @constraint(m, [t_sp ∈ 𝒯ᴵⁿᵛ], m[:opex_fixed][n, t_sp] == 0)
end

"""
    constraints_state(m, n::IncrementInitNode, 𝒯, modeltype::EnergyModel)

Defines dynamic constraints for `IncrementInitNode`. Note that the initial behavior is not
described.
"""
function constraints_state(m, n::IncrementInitNode, 𝒯, modeltype::EnergyModel)
    for (t_prev, t) ∈ withprev(𝒯)
        isnothing(t_prev) && continue
        @constraint(m, m[:state][n, t] == m[:state][n, t_prev] + n.increment)
    end
end

"""
    constraints_data(m, n::IncrementInitNode, 𝒯, 𝒫, modeltype::RecHorEnergyModel, data::InitData)

Defines initialization constraints for `IncrementInitNode`. Makes reference to the `InitData`
object provided to the node.
"""
function EMB.constraints_data(
    m,
    n::IncrementInitNode,
    𝒯,
    𝒫,
    modeltype::EMRH.RecHorEnergyModel,
    data::InitData,
)
    @constraint(m, m[:state][n, first(𝒯)] == data.val + n.increment)
end

"""
    get_init_state(m, n::IncrementInitNode, 𝒯_rh, 𝒽)

Take the optimization solution `m` and find the initialization data of `n` corresponding to
the model state at the end of the implementation horizon defined in `𝒽`. The model `m` is
internally defined for the time structure `𝒯_rh`.
"""
function EMRH.get_init_state(m, n::IncrementInitNode, 𝒯_rh, 𝒽)
    t_impl = collect(𝒯_rh)[length(indices_implementation(𝒽))]
    level_t = value.(m[:state][n, t_impl])
    return RefInitData(level_t)
end

function create_case_newnode(; init_state = 0.0)
    co2 = ResourceEmit("co2", 1.0)
    products = [co2]

    T = TwoLevel(1, 1, SimpleTimes([1, 2, 1, 4, 1, 3, 1, 3]))
    hor = DurationHorizons([duration(t) for t ∈ T], 8, 4)

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),
        Dict(co2 => FixedProfile(0)),
        co2,
    )

    nodes = [
        IncrementInitNode(
            "init node",
            1.5,
            Vector([RefInitData(init_state)]),
        ),
    ]

    links = Vector{Direct}([])

    case = Dict(
        :nodes => nodes, :links => links, :products => products, :T => T,
        :horizons => hor,
    )

    return case, model
end

case, model = create_case_newnode(init_state = 1.0)
m = create_model(case, model)
set_optimizer(m, optimizer)
optimize!(m)

results_full = Dict(k => value.(m[k]) for k ∈ keys(object_dictionary(m)))
results_EMRH = run_model_rh(case, model, optimizer)

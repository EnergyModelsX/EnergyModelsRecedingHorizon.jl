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

const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecHorizon

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
EMB.has_opex(n::IncrementInitNode) = false
EMB.has_capacity(n::IncrementInitNode) = false

function EMB.variables_node(m, 𝒩ˢᵘᵇ::Vector{<:IncrementInitNode}, 𝒯, modeltype::EnergyModel)
    @variable(m, state[𝒩ˢᵘᵇ, 𝒯])
end
function EMB.create_node(m, n::IncrementInitNode, 𝒯, 𝒫, modeltype::EnergyModel)
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end
    constraints_state(m, n, 𝒯, modeltype)
end
function constraints_state(m, n::IncrementInitNode, 𝒯, modeltype::EnergyModel)
    for (t_prev, t) ∈ withprev(𝒯)
        isnothing(t_prev) && continue
        @constraint(m, m[:state][n, t] == m[:state][n, t_prev] + n.increment)
    end
end
function EMB.constraints_data(
    m,
    n::IncrementInitNode,
    𝒯,
    𝒫,
    modeltype::EMRH.RecHorEnergyModel,
    data::AbstractInitData,
)
    @constraint(m, m[:state][n, first(𝒯)] == data.init_val_dict[:state] + n.increment)
end
EMB.constraints_couple(m, 𝒫, 𝒯, modeltype::EMRH.RecHorEnergyModel) = nothing



function create_case_newnode(; init_state = 0.0)
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [co2]

    𝒯 = TwoLevel(1, 1, SimpleTimes([1, 2, 1, 4, 1, 3, 1, 3]))
    ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], 8, 4)

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),
        Dict(co2 => FixedProfile(0)),
        co2,
    )

    𝒩 = [
        IncrementInitNode(
            "init node",
            1.5,
            Vector([InitData(Dict(:state => init_state))]),
        ),
    ]

    ℒ = Link[]

    case = Case(𝒯, 𝒫, Vector{Vector}([𝒩]), [Function[]], Dict(:horizons => ℋ))

    return case, model
end

case, model = create_case_newnode(init_state = 1.0)
m = create_model(case, model)
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
set_optimizer(m, optimizer)
optimize!(m)

results_full = EMRH.get_results_df(m)
results_EMRH = run_model_rh(case, model, optimizer)

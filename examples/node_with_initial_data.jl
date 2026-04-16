using Pkg
# Activate the local environment including EnergyModelsBase, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using HiGHS
using JuMP
using EnergyModelsBase
using TimeStruct
using EnergyModelsRecedingHorizon
using PrettyTables
using DataFrames

const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecedingHorizon

############################################################################################
# ### GENERAL ENERGYMODELSBASE.NODE DEFINITIONS
############################################################################################

# Create new node type
"""
Example node type with initializable state. The node has a single state.
"""
struct IncrementInitNode{T<:Real} <: EMB.Node
    id::Any
    increment::T
    data::Vector{<:Data}
end

# Create function dispatches so that corresponding model variables are not created
EMB.inputs(n::IncrementInitNode) = Resource[]
EMB.outputs(n::IncrementInitNode) = Resource[]
EMB.has_input(n::IncrementInitNode) = false
EMB.has_output(n::IncrementInitNode) = false
EMB.has_opex(n::IncrementInitNode) = false
EMB.has_capacity(n::IncrementInitNode) = false

# Function dispatches for model creation
function EMB.variables_node(m, 𝒩ˢᵘᵇ::Vector{<:IncrementInitNode}, 𝒯, modeltype::EnergyModel)
    @variable(m, state[𝒩ˢᵘᵇ, 𝒯])
end
function EMB.create_node(m, n::IncrementInitNode, 𝒯, 𝒫, modeltype::EnergyModel)
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)   # includes initialization
    end
    constraints_state(m, n, 𝒯, modeltype)   # dynamic state update equations
end
# Dispatch only necessary due to case being a single node
EMB.constraints_couple(m, 𝒫, 𝒯, modeltype::EMRH.RecHorEnergyModel) = nothing

############################################################################################
# ### SPECIFIC DEFINITIONS FOR ENERGYMODELSRECEDINGHORIZON
############################################################################################
# The recursive equations describing the node dynamic state must be defined for all except
# the first operational period. The initialization data is used to define the first
# operational period, here using EMB.constraints_data.
############################################################################################

# Model definitions for generic operational periods
function constraints_state(m, n::IncrementInitNode, 𝒯, modeltype::EnergyModel)
    for (t_prev, t) ∈ withprev(𝒯)
        isnothing(t_prev) && continue   # ignore first operational period
        @constraint(m, m[:state][n, t] == m[:state][n, t_prev] + n.increment)
    end
end

# Model definition for initialization (first operational period)
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

############################################################################################
# ### CASE DEFINITION AND MODEL RUN
############################################################################################

"""
    create_case_newnode(; init_state = 0.0)

Creates a single-node case example, where the goal is to calculate the state of the
incrementing element for the considered time profile. The argument `init_state` can be used
for changing the node's initial state.
"""
function create_case_newnode(; init_state = 0.0)

    # Define basic resource for EMBase
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [co2]

    # Define time structure with compatible horizon structure
    𝒯 = TwoLevel(1, 1, SimpleTimes([1, 2, 1, 4, 1, 3, 1, 3]))
    ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], 8, 4)

    # Create model instance
    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),
        Dict(co2 => FixedProfile(0)),
        co2,
    )

    # Create node vector with incrementing node
    𝒩 = [
        IncrementInitNode(
            "init node",
            1.5,
            Vector([
                # Initialization data using standard EMRH implementation (InitData)
                InitData(Dict(:state => init_state)),
            ]),
        ),
    ]

    # Create case instance
    case = Case(𝒯, 𝒫, Vector{Vector}([𝒩]), [Function[]], Dict(:horizons => ℋ))

    return case, model
end

# Generate the case and model instances and run the receding horizon model
case, model = create_case_newnode(init_state = 1.0)
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

res_emrh = run_model_rh(case, model, optimizer)

# Process results
main_res = select(res_emrh[:state], :x2 => (x -> repr.(x)) => :Period, :y => :state)
node_inc = get_nodes(case)[1]
init_data = data_init(node_inc)

# Print model results
println("\n\nNode with increment = $(node_inc.increment)")
println(
    "Results for initialization with " *
    join(["$k = $v" for (k, v) ∈ init_data.init_val_dict], ", ") * ":",
)
println(pretty_table(permutedims(main_res, :Period)))

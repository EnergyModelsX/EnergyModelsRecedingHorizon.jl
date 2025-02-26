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
using EnergyModelsRecHorizon
using PrettyTables
using DataFrames

const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecHorizon

############################################################################################
# ### GENERAL ENERGYMODELSBASE.NODE DEFINITIONS
############################################################################################

# Create new node type
"""
Example initializable node with new data type. The node has two states, and its equations
use a different data structure for initialization data.
"""
struct NodeNewInitData{T<:Real} <: EMB.Node
    id::Any
    increment_1::T
    increment_2::T
    data::Vector{<:Data}
end

# Create function dispatches so that corresponding model variables are not created
EMB.has_input(n::NodeNewInitData) = false
EMB.has_output(n::NodeNewInitData) = false
EMB.has_opex(n::NodeNewInitData) = false
EMB.has_capacity(n::NodeNewInitData) = false

# Function dispatches for model creation
function EMB.variables_node(
    m,
    𝒩ˢᵘᵇ::Vector{<:NodeNewInitData},
    𝒯,
    modeltype::EnergyModel,
)
    @variable(m, state_1[𝒩ˢᵘᵇ, 𝒯])
    @variable(m, state_2[𝒩ˢᵘᵇ, 𝒯])
end
function EMB.create_node(m, n::NodeNewInitData, 𝒯, 𝒫, modeltype::EnergyModel)
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)   # includes initialization
    end
    constraints_state(m, n, 𝒯, modeltype)   # dynamic state update equations
end
# Dispatch only necessary due to case being a single node
EMB.constraints_couple(m, 𝒫, 𝒯, modeltype::EMRH.RecHorEnergyModel) = nothing

############################################################################################
# ### SPECIFIC DEFINITIONS FOR ENERGYMODELSRECHORIZON
############################################################################################

# Model definitions for generic operational periods
function constraints_state(m, n::NodeNewInitData, 𝒯, modeltype::EnergyModel)
    for (t_prev, t) ∈ withprev(𝒯)
        isnothing(t_prev) && continue   # ignore first operational period
        @constraint(m, m[:state_1][n, t] == m[:state_1][n, t_prev] + n.increment_1)
        @constraint(m, m[:state_2][n, t] == m[:state_2][n, t_prev] + n.increment_2)
    end
end

# Model definition for initialization (first operational period)
function EMB.constraints_data(
    m,
    n::NodeNewInitData,
    𝒯,
    𝒫,
    modeltype::EMRH.RecHorEnergyModel,
    data::EMRH.AbstractInitData,
)
    @constraint(m, m[:state_1][n, first(𝒯)] == data.state_1 + n.increment_1)
    @constraint(m, m[:state_2][n, first(𝒯)] == data.state_2 + n.increment_2)
end

############################################################################################
# # DEFINITIONS FOR NEW INITIALIZATION DATA
############################################################################################
# To define a new initialization data structure (here `ExNewInitData`), the user must define
# a corresponding `AbstractInitDataPath` subtype, that indicates each field to be updated in
# the receding horizon solver. Function dispatches are needed for `_find_update_paths` and
# `update_init_data!`.
############################################################################################

"""
Example custom initialization data type. It presents two fields (`state_1` and `state_2`)
for different state values.
"""
struct ExNewInitData <: EMRH.AbstractInitData
    state_1::Real
    state_2::Real
end

"""
Path type linked to `ExNewInitData`, where each instance is linked to a field in
`ExNewInitData`, given by `key`.
"""
struct ExNewInitDataPath <: EMRH.AbstractInitDataPath
    key::Any
end

# Function for detection of fields to be updated
function EMRH._find_update_paths(
    field::ExNewInitData,
    current_path::Vector{Any},
    all_paths::Vector{Any},
)
    for var_key ∈ [:state_1, :state_2]
        new_path = vcat(current_path, var_key)
        append!(new_path, [ExNewInitDataPath(var_key)])
        push!(all_paths, new_path)
    end
end

# Function for update of detected path based on optimization results
function EMRH.update_init_data!(
    m,
    ri::EMRH.AbstractReset,
    x::NodeNewInitData,
    idp::ExNewInitDataPath,
    opers_implᵣₕ,
)
    t_last = last(opers_implᵣₕ)
    ri.val = value.(m[idp.key][x, t_last])
end

############################################################################################
# ### CASE DEFINITION AND MODEL RUN
############################################################################################

"""
    create_case_newinitdata()

Creates a single-node case example, where the goal is to simulate a node with non-standard
initialization data definition.
"""
function create_case_newinitdata()

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
        NodeNewInitData(
            "init node",
            1.5,
            0.6,
            # Initialization data using custom implementation
            [ExNewInitData(1.0, 1.3)],
        ),
    ]

    # Create case instance
    case = Case(𝒯, 𝒫, Vector{Vector}([𝒩]), [Function[]], Dict(:horizons => ℋ))

    return case, model
end

# Generate the case and model instances and run the receding horizon model
case, model = create_case_newinitdata()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

results_new_initdata = run_model_rh(case, model, optimizer)

# Process results
main_res = innerjoin(
    results_new_initdata[:state_1],
    results_new_initdata[:state_2],
    on = [:x1, :x2];
    makeunique = true,
)
select!(main_res, :x2 => (x -> repr.(x)) => :Period, :y => :state_1, :y_1 => :state_2)
node_inc = get_nodes(case)[1]
init_data = EMRH.data_init(node_inc)

# Print model results
println(
    "\n\nNode with increment_1 = $(node_inc.increment_1), increment_2 = $(node_inc.increment_2)",
)
println(
    "Results for initialization with state_1 = $(init_data.state_1), state_2 = $(init_data.state_2):",
)
println(pretty_table(permutedims(main_res, :Period)))

# ---- Links ----

# Creation of a new link type with associated capacity and period partitions. The link is
# used in the test sets "Utility functions" (`test_utils.jl`) and "POI implementation"
# (`test_poi.jl`)
struct CapDirect <: Link
    id::Any
    from::EMB.Node
    to::EMB.Node
    capacity::TimeProfile
    part_dur::PartitionProfile
    part_mult::PartitionProfile
end

# Add methods to required functions
EMB.capacity(l::CapDirect) = l.capacity
EMB.capacity(l::CapDirect, t) = l.capacity[t]
EMB.has_capacity(l::CapDirect) = true
EMRH.period_duration(l::CapDirect) = l.part_dur

function EMB.create_link(m, l::CapDirect, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᵖᵈ = partition_duration(𝒯, EMRH.period_duration(l))

    # Generic link in which each output corresponds to the input
    @constraint(m, [t ∈ 𝒯, p ∈ EMB.link_res(l)],
        m[:link_out][l, t, p] == m[:link_in][l, t, p]
    )

    # Capacity constraint
    @constraint(m, [t_pd ∈ 𝒯ᵖᵈ, t ∈ t_pd, p ∈ EMB.link_res(l)],
        m[:link_out][l, t, p] ≤ m[:link_cap_inst][l, t] * l.part_mult[t_pd]
    )
    constraints_capacity_installed(m, l, 𝒯, modeltype)

    # Bound the inlet flow in each period by the variable of the corresponding partition
    @constraint(m, [t_pd ∈ 𝒯ᵖᵈ, t ∈ t_pd, p ∈ EMB.link_res(l)],
        m[:link_in][l, t, p] ≤ m[:part_variable][l, t_pd]
    )
end
function EMB.variables_link(m, ℒˢᵘᵇ::Vector{CapDirect}, 𝒯, modeltype::EnergyModel)
    # Add a test variable indexed over the period partitions of the individual links
    @variable(m, part_variable[l ∈ ℒˢᵘᵇ, partition_duration(𝒯, EMRH.period_duration(l))])

    # Add a test variable with an integer index set
    @variable(m, int_variable[ℒˢᵘᵇ, 𝒯, 1:2] ≥ 0)
end

# ---- Nodes ----

# Creation of a new node type with a dictionary with string keys. The node is used in the
# test set "Utility functions" (`test_utils.jl`)
struct StringDict <: EMB.NetworkNode
    profile::Dict{String,TimeProfile}
end
Base.show(io::IO, w::StringDict) = "StringDict"

# Creation of a new sink type with period partitions. The sink is used in the test set
# "Utility functions" (`test_utils.jl`)
struct PartSink <: EMB.Sink
    id::Any
    cap::TimeProfile
    penalty::Dict{Symbol,<:TimeProfile}
    input::Dict{<:Resource,<:Real}
    part_dur::PartitionProfile
    data::Vector{<:ExtensionData}
end
EMRH.period_duration(n::PartSink) = n.part_dur

# Creation of a new node type with two dynamic states. The node is used in the test set
# "Node initialization" (`test_init_data.jl`)
struct SampleInitNode{T<:Real} <: EMB.Node
    id::Any
    increment::T
    increment2::T
    data::Vector{<:ExtensionData}
end

EMB.inputs(n::SampleInitNode) = Resource[]
EMB.outputs(n::SampleInitNode) = Resource[]
EMB.has_input(n::SampleInitNode) = false
EMB.has_output(n::SampleInitNode) = false
EMB.has_opex(n::SampleInitNode) = false
EMB.has_capacity(n::SampleInitNode) = false

function EMB.variables_node(
    m,
    𝒩ˢᵘᵇ::Vector{<:SampleInitNode},
    𝒯,
    modeltype::EnergyModel,
)
    @variable(m, state[𝒩ˢᵘᵇ, 𝒯])
    @variable(m, state2[𝒩ˢᵘᵇ, 𝒯])
end

function EMB.create_node(m, n::SampleInitNode, 𝒯, 𝒫, modeltype::EnergyModel)
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end
    constraints_state(m, n, 𝒯, modeltype)
end

function constraints_state(m, n::SampleInitNode, 𝒯, modeltype::EnergyModel)
    for (t_prev, t) ∈ withprev(𝒯)
        isnothing(t_prev) && continue
        @constraint(m, m[:state][n, t] == m[:state][n, t_prev] + n.increment)
        @constraint(m, m[:state2][n, t] == m[:state2][n, t_prev] + n.increment2)
    end
end

# ---- `ExtensionData` and initial data ----

# Creation of a new `ExtensionData` type with period partitions. The data is used in the
# test sets "Utility functions" (`test_utils.jl`) and "POI implementation" (`test_poi.jl`)
struct PartData <: ExtensionData
    part_dur::PartitionProfile
    part_lim::PartitionProfile
end
EMRH.period_duration(data::PartData) = data.part_dur
part_data(n::EMB.Node) = first(filter(data -> isa(data, PartData), node_data(n)))

function EMB.variables_ext_data(
    m,
    _::Type{PartData},
    𝒩ˢᵘᵇ::Vector{<:EMB.Node},
    𝒯,
    𝒫,
    modeltype::EnergyModel,
)
    # Add a test variable indexed over the period partitions of the data of the nodes
    @variable(m,
        part_data_var[n ∈ 𝒩ˢᵘᵇ, partition_duration(𝒯, EMRH.period_duration(part_data(n)))]
    )
end
function EMB.constraints_ext_data(
    m,
    n::EMB.Node,
    𝒯,
    𝒫,
    modeltype::EnergyModel,
    data::PartData,
)
    # Declaration of the required subsets
    𝒯ᵖᵈ = partition_duration(𝒯, EMRH.period_duration(data))

    # The variable is the capacity usage within a partition and limited by the profile
    @constraint(m, [t_pd ∈ 𝒯ᵖᵈ],
        m[:part_data_var][n, t_pd] == sum(m[:cap_use][n, t] * duration(t) for t ∈ t_pd)
    )
    @constraint(m, [t_pd ∈ 𝒯ᵖᵈ], m[:part_data_var][n, t_pd] ≤ data.part_lim[t_pd])
end

# Creation of a new `ExtensionData` type with period partitions without a method for
# `period_duration`. The data is used in the test set "Utility functions"
# (`test_utils.jl`)
struct PartLimData <: ExtensionData
    part_lim::PartitionProfile
end

# Creation of a new `AbstractInitData` type without a method for `_find_update_paths`. The
# data is used in the test set "Utility functions" (`test_utils.jl`)
struct TestInitData <: AbstractInitData end

# ---- `TransmissionMode`s ----

# Creation of a new `TransmissionMode` type with period partitions. The mode is used in the
# test set "Geography" (`test_emg.jl`)
struct PartStatic <: TransmissionMode
    id::String
    resource::Resource
    trans_cap::TimeProfile
    trans_loss::TimeProfile
    part_dur::PartitionProfile
    part_lim::PartitionProfile
end
EMRH.period_duration(tm::PartStatic) = tm.part_dur
EMB.has_opex(tm::PartStatic) = false
EMG.is_bidirectional(tm::PartStatic) = false

function EMG.variables_trans_mode(m, 𝒯, ℳˢᵘᵇ::Vector{<:PartStatic}, modeltype::EnergyModel)
    # Add a test variable indexed over the period partitions of the individual modes
    @variable(m, trans_part[tm ∈ ℳˢᵘᵇ, partition_duration(𝒯, EMRH.period_duration(tm))])
end
function EMG.create_transmission_mode(m, tm::PartStatic, 𝒯, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒯ᵖᵈ = partition_duration(𝒯, EMRH.period_duration(tm))

    # Call of the constraint functions of a `TransmissionMode`
    EMG.constraints_trans_balance(m, tm, 𝒯, modeltype)
    EMG.constraints_trans_loss(m, tm, 𝒯, modeltype)
    EMG.constraints_capacity(m, tm, 𝒯, modeltype)

    # The variable is the transported energy within a partition and limited by the profile
    @constraint(m, [t_pd ∈ 𝒯ᵖᵈ],
        m[:trans_part][tm, t_pd] == sum(m[:trans_out][tm, t] * duration(t) for t ∈ t_pd)
    )
    @constraint(m, [t_pd ∈ 𝒯ᵖᵈ], m[:trans_part][tm, t_pd] ≤ tm.part_lim[t_pd])
end

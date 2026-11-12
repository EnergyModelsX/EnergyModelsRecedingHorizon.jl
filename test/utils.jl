# Creation of a new link type with associated capacity and period partitions. The link is
# used in the tests for the resetting of `PartitionProfile`s, the mapping of period
# partitions, and the extraction of variables indexed over period partitions
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

# Creation of a new `ExtensionData` type with period partitions. The data is used in the
# tests for partitions in `ExtensionData`
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

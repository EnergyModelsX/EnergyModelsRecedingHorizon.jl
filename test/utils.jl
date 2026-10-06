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
end

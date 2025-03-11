function EMG.constraints_capacity_installed(
    m,
    tm::TransmissionMode,
    𝒯::TimeStructure,
    modeltype::RecHorEnergyModel
)
    # Fix the installed capacity to the upper bound, required as the capacity is now a POI
    # variable
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_BOUNDS)
    @constraint(m, [t ∈ 𝒯], m[:trans_cap][tm, t] == capacity(tm, t))
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_CONSTRAINTS)
end

"""
    EMG.constraints_capacity_installed(m, tm::TransmissionMode, 𝒯::TimeStructure, modeltype::RecHorEnergyModel)

When the modeltype is a receding horizon model, the function utilizes constraints instead of
the function `JuMP.fix` for constraining the capacity as it is not possible to fix to a POI
parameter.

!!! info "Fixed variables"
    Fixing variables is not possible if the parameter is a POI parameter. It is instead
    necessary to utilize constraints. Improved speed can be achieved by calling

    ```julia
    # before the constraint
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_BOUNDS)
    # and
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_CONSTRAINTS)
    # after the constraint.
    ```
"""
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

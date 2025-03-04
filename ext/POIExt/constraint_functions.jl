"""
    EMB.constraints_capacity_installed(m, n::Node, 𝒯::TimeStructure, modeltype::RecHorEnergyModel)
    EMB.constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::RecHorEnergyModel)
    EMB.constraints_capacity_installed(m, l::Link, 𝒯::TimeStructure, modeltype::RecHorEnergyModel)

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
function EMB.constraints_capacity_installed(
    m,
    n::EMB.Node,
    𝒯::TimeStructure,
    modeltype::RecHorEnergyModel
)
    # Fix the installed capacity to the upper bound, required as the capacity is now a POI
    # variable
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_BOUNDS)
    @constraint(m, [t ∈ 𝒯], m[:cap_inst][n, t] == capacity(n, t))
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_CONSTRAINTS)
end

function EMB.constraints_capacity_installed(
    m,
    n::Storage,
    𝒯::TimeStructure,
    modeltype::RecHorEnergyModel,
)
    # Fix the installed capacity to the upper bound, required as the capacity is now a POI
    # variable
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_BOUNDS)
    @constraint(m, [t ∈ 𝒯], m[:stor_level_inst][n, t] == capacity(level(n), t))
    if EMB.has_charge_cap(n)
        @constraint(m, [t ∈ 𝒯], m[:stor_charge_inst][n, t] == capacity(charge(n), t))
    end
    if EMB.has_discharge_cap(n)
        @constraint(m, [t ∈ 𝒯], m[:stor_discharge_inst][n, t] == capacity(discharge(n), t))
    end
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_CONSTRAINTS)
end
function EMB.constraints_capacity_installed(
    m,
    l::Link,
    𝒯::TimeStructure,
    modeltype::RecHorEnergyModel,
)
    # Fix the installed capacity to the upper bound, required as the capacity is now a POI
    # variable
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_BOUNDS)
    @constraint(m, [t ∈ 𝒯], m[:link_cap_inst][l, t] == capacity(l, t))
    MOI.set(m, POI.ConstraintsInterpretation(), POI.ONLY_CONSTRAINTS)
end

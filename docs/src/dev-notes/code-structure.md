# [Code structure](@id dev-code)

[`EnergyModelsRecHorizon`](@ref EMRH.EnergyModelsRecHorizon) is based on setting up optimization subproblems given implementation and optimization horizons.
The horizons for the optimization subproblems are expressed through [AbstractHorizons](@ref EMRH.AbstractHorizons) objects, see the *[dedicated section on horizons](@ref man-phil-hortyp)*.
These will ultimately define how many optimization subproblems will be solved and how large they will be.

For every iteration over the horizons, the optimization subproblem needs to be updated for the time-dependent fields.
This is done through [`AbstractPath`](@ref EMRH.AbstractPath) objects, whose aim is to automatically identify the model variables that need updating.
Each [`AbstractPath`](@ref EMRH.AbstractPath) object corresponds to a field in the model structure to be updated.
The creation of the accessors to these fields (known as [lenses](https://juliaobjects.github.io/Accessors.jl/stable/lenses/)) is done through [`AbstractReset`](@ref EMRH.AbstractReset) objects, allowing for type checking of the fields to be updated.
This object must always be created through [`ResetType`](@ref EMRH.ResetType) constructors.
The element subject to updating is wrapped around an [`AbstractSub`](@ref EMRH.AbstractSub) object, where the original (full-problem) and new (receding horizon) instances of the element are included as fields, as well as the [`AbstractReset`](@ref EMRH.AbstractReset) objects linked to the element.
A unified constructor, [`Substitution`](@ref EMRH.Substitution), is used within the model.

As a general rule, the fields that require updating are either related to the initial conditions of the system or to the time profiles that the system is subject to.
For updating the time profiles, we read the originally provided time profile for the full optimization problem.
As for the initial conditions of the system, each element is assumed to be independently initializable through their own variables.
Initialization of the system is therefore done at the element level, which we describe in more detail in the *[dedicated page on initialization](@ref dev-init)*.
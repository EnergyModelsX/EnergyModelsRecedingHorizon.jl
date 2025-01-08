# [Philosophy](@id man-phil)

Receding horizon refers to a method for solving dynamic optimization problems where smaller dynamic optimization problems are solved repeatedly over changing horizons, which are updated based on previous solutions and new observations.
It is inspired by *model predictive control* (MPC), also known as receding horizon control [mattingley2011receding](@cite), where a control problem is defined by a dynamic optimization problem.
This problem is solved for a finite time horizon, the first calculated control action is implemented in the system, and a new dynamic optimization problem is formulated based on the new state of the system after implementing the control actions.

## [Code philosophy](@id man-phil-code)

This package is made to be an extension of the core EnergyModelsBase structure,
and therefore it follows the same principles of flexibility, extendability, and transparency 
(see the *[EnergyModelsBase page](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/philosophy/#man-phil-gen)* on its philosophy).

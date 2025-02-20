# [Philosophy](@id man-phil)

## [What is a receding horizon?](@id man-phil-rechor)

Receding horizon refers to a method for solving dynamic optimization problems where smaller dynamic optimization problems are solved repeatedly over changing horizons, which are updated based on previous solutions and new observations.
It is inspired by *model predictive control* (MPC), also known as receding horizon control [mattingley2011receding](@cite), where a control problem is defined by a dynamic optimization problem.
This problem is solved for a finite time horizon, the first calculated control action is implemented in the system, and a new dynamic optimization problem is formulated based on the new state of the system after implementing the control actions.

Here, we use the receding horizon concept to reduce the complexity of a full-scale optimization problem into smaller subproblems.
Each subproblem is solved over a finite time horizon (here denoted *optimization horizon*).
The solution for this subproblem is stored for a usually smaller time horizon (here denoted *implementation horizon*), and the next subproblem is posed to begin at the end of this implementation horizon, see illustration below.
Note that the individual operational periods do not need to have the same length.

![Illustration of receding horizon](./../figures/receding-horizon.svg)

This package is an extension of the core EnergyModelsBase structure,
and therefore it follows the same principles of flexibility, extendability, and transparency 
(see the *[EnergyModelsBase page](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/philosophy/#man-phil-gen)* on its philosophy).

## [Types of horizons](@id man-phil-hortyp)

This package is based on setting up optimization subproblems given implementation and optimization horizons, as described above.
How these horizons are defined and updated will dictate the behavior of the receding horizon solver.
The behavior of these horizons is considered as an abstract type [`AbstractHorizons`](@ref EMRH.AbstractHorizons), allowing for common treatment of these approaches.
Two horizon types are provided with `EnergyModelsRecHorizon`, as subtypes of [`AbstractHorizons`](@ref EMRH.AbstractHorizons):

- [`PeriodHorizons`](@ref): the original time structure is partitioned according to the number of operational periods.
  This means that each implementation and optimization horizons are of the same length across the optimization subproblems.

- [`DurationHorizons`](@ref): the original time structure is partitioned according to the duration of the operational periods.
  This means that each implementation and optimization horizons may have varying length across the optimization subproblems.

## [When should you use the package?](@id man-phil-when)

The package is intended for use in complex optimization problems in which it is not feasible to model a complete operational horizon in a single optimization run.
In these problems, the solution of smaller problems sequentially in time may allow tractability of the problem.

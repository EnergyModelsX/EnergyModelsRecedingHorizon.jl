# Release notes


## Version 0.4.0 (2025-XX-XX)

### Support for ParametricOptInterface and EMB 0.9.0

* Time-dependent fields are internally updated through lenses (see [Accessors.jl](https://juliaobjects.github.io/Accessors.jl/stable/lenses/))
* Introduced standard behavior for simple initializable objects
* `ParametricOptInterface` can be used for horizons with a constant length (`PeriodHorizons`)

## Version 0.3.2 (2025-01-08)

### Introduced documentation; added example of node initialization

* Current documentation has the basic information for EMX users to create EMRH-compliant nodes. Still needs improvement, especially for first-time users.
* New example for node initialization that does not rely on `Storage`-specific functionality.
* Introduced functions for checking for `OperationalProfile`s, which will be used to implement `ParametricOptInterface` in the future.

## Version 0.3.1 (2024-11-06)

### Bug fix

Initialization data provided by user is no longer changed when model runs.

## Version 0.3.0 (2024-09-30)

### Improved input requirements from user

* Requires from user a `(case, model)` pair definition for the full problem horizon, similar to other EMX packages.
* Includes auxiliary functions for slicing full problem for each horizon, currently relying on re-instancing nodes and links from `case`.

### Time iterators for the horizon

* Included new types for passing arguments for creating the iterators for the receding horizon framework:
  * `PeriodHorizons` defines the horizons by the number of operational periods,
  * `DurationHorizons` defines the horizons by the duration of the operational periods.
* Both types have an iterator in which the element is provided by a `SingleHorizon`:
  * it includes all information required for setting up a single horizon,
  * it allows for creating the individual models

## Version 0.2.0 (2024-08-07)

### First working version

* Requires from user a function that instances a `(case, model)` pair for any
slice of time from the original problem. This approach will be replaced in the
future.
* Introduces `InitData` as abstract type for initialization data.
* Introduces `RecHorEnergyModel` for dispatching functions that are relevant for
initialization.

## Version 0.1.0 (2024-04-11)

### Initial (skeleton) version

* Provides an initial skeleton version with the required files.
* Includes dependencies for `EnergyModelsBase` and `TimeStruct`.

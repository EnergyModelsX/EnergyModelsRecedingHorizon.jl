# Release notes


## Unversioned

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

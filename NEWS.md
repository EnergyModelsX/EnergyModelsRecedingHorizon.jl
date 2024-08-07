# Release notes

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

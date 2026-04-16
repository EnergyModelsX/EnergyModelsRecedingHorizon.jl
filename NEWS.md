# Release notes

## Version 0.2.0 (2026-04-15)

* Adjusted to [`EnergyModelsBase` v0.10.0](https://github.com/EnergyModelsX/EnergyModelsBase.jl/releases/tag/v0.10.0):
  * Model worked without adjustments.
  * Test set was adjusted as implemented nodes did not adhere to definition of nodes.
* Breaking change still included to maintain the possibility to do bug fixes in version 0.1.x for existing models with `EnergyModelsBase` v0.9.x.

## Version 0.1.2 (2026-03-04)

### Bugfix

* Fixed a bug when the `FutureValue` vector was of type `Vector{FutureValue}`.

## Version 0.1.1 (2025-04-25)

* Introduction of `TypeFutureValue` for assigning a value to a variable for all instances of a given nodal type.

## Version 0.1.0 (2025-03-27)

Initial version of the package:

* Includes a receding horizon framework which can be based on two different types of horizons, based on the number of periods and based on the duration of the periods.
* Implemented for `EnergyModelsBase` and `EnergyModelsGeography`.
* Allows for future value description through a new `AbstractElement`.
* Utilizes `Accessors` for faster parameter updating.
* Supports `ParametricOptInterface` through an extension.

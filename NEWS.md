# Release notes

## Version 0.1.0 (2025-03-27)

Initial version of the package:

* Includes a receding horizon framework which can be based on two different types of horizons, based on the number of periods and based on the duration of the periods.
* Implemented for `EnergyModelsBase` and `EnergyModelsGeography`.
* Allows for future value description through a new `AbstractElement`.
* Utilizes `Accessors` for faster parameter updating.
* Supports `ParametricOptInterface` through an extension.

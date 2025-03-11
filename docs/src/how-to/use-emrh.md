# [Use the package](@id how_to-use_emrh)

The main function of the [`EnergyModelsRecHorizon`](@ref) package is [`run_model_rh`](@ref run_model_rh(case::AbstractCase, model::EMRH.RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true)).
Similarly to [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/), a problem is defined by its case and model objects.
The following points should be accounted for when setting up a problem in [`EnergyModelsRecHorizon`](@ref):

- The provided case object should be an [`EMB.Case`](@extref EnergyModelsBase.Case) with problem horizons included in the case object through the `misc` dictionary using the `:horizons` key.
- The case must have its [`OperationalProfile`](@extref TimeStruct.OperationalProfile)s covering the full problem horizon, otherwise the last value in the time profile will be repeated.
- The horizon object must be compatible with the case's [`TimeStructure`](@extref TimeStruct.TimeStructure).
- The model object must be of a subtype of [`RecHorEnergyModel`](@ref EMRH.RecHorEnergyModel) for dispatching purposes.
- The elements in the problem case must have [`AbstractInitData`](@ref EMRH.AbstractInitData) objects in their data fields where applicable.
  This is a necessity for all `Storage` nodes that utilize the new behavior [`RecedingAccumulating`](@ref) which should be utilized irrespectively of the individual storage node.
  This initial data must be used to define the first operational period (see the *[initialization section](@ref dev-init)* for more details).

## [ParametricOptInterface extension](@id how_to-use_emrh-POIext)

If one wants to use the [`ParametricOptInterface`](https://jump.dev/ParametricOptInterface.jl/stable/) extension, the following adjustments must be made.
The only supported type for horizons is [`PeriodHorizons`](@ref EMRH.PeriodHorizons) (please refer to the *[horizons section](@ref man-phil-hortyp)*).
Additionally, the optimizer provided to [`run_model_rh`](@ref EMRH.run_model_rh) must be a [`POI.Optimizer`](https://jump.dev/ParametricOptInterface.jl/stable/reference/#ParametricOptInterface.Optimizer) object.

## [EnergyModelsGeography extension](@id how_to-use_emrh-EMGExt)

The basic version includes as well extensions that are loaded if you utilize [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/stable/).
The first extensions provides support for utilizing both [`Area`](@extref EnergyModelsGeography area_mode-areas)s and [`Transmission` corridors](@extref EnergyModelsGeography area_mode-trans_corr), including  [`TransmissionMode`](@extref EnergyModelsGeography area_mode-trans_mode)s.
The second extension provides a minor update to a function of `EnergyModelsGeography` when `ParametricOptInterface` is utilized.

In general, you do not have to take any specific precautions when using `EnergyModelsGeography` and `EnergyModelsRecHorizon`.
However, if you use the transmission mode [`PipeLinepackSimple`](@extref EnergyModelsGeography.PipeLinepackSimple), you must provide initialization data through the type [`TransInitData`](@ref EMGExt.TransInitData).
Similarly, if you have individual dynamic states in developed transmission modes, you must utilize the same initialization data as well.

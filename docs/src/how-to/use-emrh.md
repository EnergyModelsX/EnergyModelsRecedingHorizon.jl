# [Use the package](@id how_to-use_emrh)

The main function of the [`EnergyModelsRecedingHorizon`](@ref) package is [`run_model_rh`](@ref run_model_rh(case::AbstractCase, modeltype::EMRH.RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true)).
Similarly to [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/), a problem is defined by its case and model objects.
The following points should be accounted for when setting up a problem in [`EnergyModelsRecedingHorizon`](@ref):

- The modeltype object must be a subtype of [`RecHorEnergyModel`](@ref EMRH.RecHorEnergyModel) for dispatching purposes.
- The provided case object should be a [`Case`](@extref EnergyModelsBase.Case) with problem horizons included in the case object through the `misc` dictionary using the `:horizons` key.
- The case must have its [`OperationalProfile`](@extref TimeStruct.OperationalProfile)s covering the full problem horizon, otherwise the last value in the time profile will be repeated.
- The horizon object must be compatible with the case's [`TimeStructure`](@extref TimeStruct.TimeStructure).

  !!! note "Parameters indexed over strategic periods"
      Some parameters with a [`Case`](@extref EnergyModelsBase.Case) are indexed over strategic periods.
      Examples are the CO₂ limit of [`RecHorEnergyModel`](@ref EMRH.RecHorEnergyModel) or all fixed operating expenses.
      The time divisor (*e.g.*, year in €/kW/year) is per default given by the time of a duration of 1 of an operational period (see the description in *[the documentation of `EnergyModelsBase`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)).

      It can be manually chosen by changing the keyword argument `use_op_per_strat` of the function [`run_model_rh`](@ref run_model_rh(case::AbstractCase, modeltype::EMRH.RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true, use_op_per_strat::Bool=false, optimizer_param::Dict=Dict(MOI.Silent() => true))) to `true`.
      In this case, the specified value `op_per_strat` of the `TwoLevel` is used to scale the values correctly.

- The elements in the problem case must have [`AbstractInitData`](@ref EMRH.AbstractInitData) objects in their data fields where applicable.
  This is a necessity for all `Storage` nodes that utilize the new behavior [`RecedingAccumulating`](@ref) which should be utilized irrespectively of the individual storage node.
  This initial data must be used to define the first operational period (see the *[initialization section](@ref dev-init)* for more details).

Contrary to other [`EnergyModelsX`](https://github.com/EnergyModelsX) packages, the current package does not solve a single optimization problem, but it solves a sequence of optimization problems.
Therefore, the function [`run_model_rh`](@ref run_model_rh(case::AbstractCase, modeltype::EMRH.RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true, use_op_per_strat::Bool=false, optimizer_param::Dict=Dict(MOI.Silent() => true))) returns the overall results in a [`DataFrame`](https://dataframes.juliadata.org/stable/) format, containing only results related to the implementation horizons of the model.

## [ParametricOptInterface extension](@id how_to-use_emrh-POIext)

If one wants to use the [`ParametricOptInterface`](https://jump.dev/ParametricOptInterface.jl/stable/) extension, the following adjustments must be made.
The only supported type for horizons is [`PeriodHorizons`](@ref EMRH.PeriodHorizons) (please refer to the *[horizons section](@ref man-phil-hortyp)*).
Additionally, the optimizer provided to [`run_model_rh`](@ref run_model_rh(case::AbstractCase, modeltype::EMRH.RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true, use_op_per_strat::Bool=false, optimizer_param::Dict=Dict(MOI.Silent() => true))) must be a [`POI.Optimizer`](https://jump.dev/ParametricOptInterface.jl/stable/reference/#ParametricOptInterface.Optimizer) object.

## [EnergyModelsGeography extension](@id how_to-use_emrh-EMGExt)

The basic version includes as well extensions that are loaded if you utilize [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/stable/).
The first extensions provides support for utilizing both [`Area`](@extref EnergyModelsGeography area_mode-areas)s and [`Transmission` corridors](@extref EnergyModelsGeography area_mode-trans_corr), including  [`TransmissionMode`](@extref EnergyModelsGeography area_mode-trans_mode)s.
The second extension provides a minor update to a function of `EnergyModelsGeography` when `ParametricOptInterface` is utilized.

In general, you do not have to take any specific precautions when using `EnergyModelsGeography` and `EnergyModelsRecedingHorizon`.
However, if you use the transmission mode [`PipeLinepackSimple`](@extref EnergyModelsGeography.PipeLinepackSimple), you must provide initialization data through the type [`TransInitData`](@ref EMGExt.TransInitData).
Similarly, if you have individual dynamic states in developed transmission modes, you must utilize the same initialization data as well.

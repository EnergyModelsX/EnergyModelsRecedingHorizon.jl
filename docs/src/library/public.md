# [Public](@id lib-pub)

## [Index](@id lib-pub-idx)

```@index
Pages = ["public.md"]
```

## [Module](@id lib-pub-module)

```@docs
EnergyModelsRecHorizon
```

## [Model](@id lib-pub-mod)

```@docs
RecHorOperationalModel
run_model_rh(case::AbstractCase, model::EMRH.RecHorEnergyModel, optimizer; check_timeprofiles::Bool=true)
```

## [Horizon](@id lib-pub-hor)

### [Types](@id lib-pub-hor-typ)

```@docs
DurationHorizons
PeriodHorizons
```

### [Functions](@id lib-pub-hor-fcn)

```@docs
durations
indices_optimization
indices_implementation
```

## [Initialization](@id lib-pub-init)

### [Types](@id lib-pub-init-typ)

```@docs
AbstractInitData
InitData
StorageInitData
```

### [Functions](@id lib-pub-init-fcn)

```@docs
has_init
is_init_data
EMRH.data_init
```

## [Future value](@id lib-pub-fut_val)

### [Types](@id lib-pub-fut_val-typ)

```@docs
FutureValue
StorageValueCuts
StorageValueCut
```

### [Functions](@id lib-pub-fut_val-fcn)

```@docs
get_future_value
has_cuts
```

## [Miscellaneous](@id lib-pub-misc)

```@docs
RecedingAccumulating
```

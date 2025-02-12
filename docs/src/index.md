# EnergyModelsRecHorizon

This Julia package provides a framework for receding horizon optimization of an energy system model.
This package is developed as an extension to the multi carrier energy model [`EnergyModelsBase`](https://github.com/EnergyModelsX/EnergyModelsBase.jl).

!!! info
    This documentation is under development.

```@docs
EnergyModelsRecHorizon
```

`EnergyModelsRecHorizon` follows the same philosophy with respect to extendibility as `EnergyModelsBase`.
This means that users are able to implement new technologies as new nodes without changes to the core package structure.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/initialization.md",
    "manual/cost-to-go.md",
    "manual/simple-example.md",
    "manual/NEWS.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/create-new-node.md",
]
Depth = 1
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals/types-EMRH.md",
    "library/internals/methods-EMRH.md",
    "library/internals/methods-EMB.md",
    "library/internals/reference-POIExt.md",
    "library/internals/reset.md",
]
Depth = 1
```

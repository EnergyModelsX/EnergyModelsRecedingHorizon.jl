# EnergyModelsRecHorizon

This Julia package provides a framework for receding horizon optimization of an energy system model.
This package is developed as an extension to the multi carrier energy model [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/).

!!! info
    This documentation is under development.

`EnergyModelsRecHorizon` follows the same philosophy with respect to extendibility as `EnergyModelsBase`.
This means that users are able to implement new technologies as new nodes without changes to the core package structure.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/future-value.md",
    "manual/simple-example.md",
    "manual/NEWS.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/adapt-emx-elem.md",
    "how-to/use-emrh.md",
]
Depth = 1
```

## Developer notes

```@contents
Pages = [
    "dev-notes/code-structure.md",
    "dev-notes/initialization.md",
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

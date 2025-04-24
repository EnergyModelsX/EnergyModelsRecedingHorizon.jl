# EnergyModelsRecedingHorizon

This Julia package provides a framework for receding horizon optimization of an energy system model.
This package is developed as an extension to the multi carrier energy model [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/).

`EnergyModelsRecedingHorizon` follows the same philosophy with respect to extensibility as `EnergyModelsBase`.
This means that users are able to implement new technologies as new nodes without changes to the core package structure.
It may however be necessary to do minor adjustments to your existing nodes.
This is the case if dynamic constraints are included in your node.
An explanation of the required steps can be found in *[how to adapt an EMX element](@ref how_to-adapt_elem)*.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/future_value.md",
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
    "dev-notes/future_value.md",
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

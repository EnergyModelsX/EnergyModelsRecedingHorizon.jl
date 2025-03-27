# EnergyModelsRecedingHorizon

[![DOI](https://joss.theoj.org/papers/10.21105/joss.06619/status.svg)](https://doi.org/10.21105/joss.06619)
[![Build Status](https://github.com/EnergyModelsX/EnergyModelsRecedingHorizon.jl/workflows/CI/badge.svg)](https://github.com/EnergyModelsX/EnergyModelsRecedingHorizon.jl/actions?query=workflow%3ACI)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://energymodelsx.github.io/EnergyModelsRecedingHorizon.jl/stable/)
[![In Development](https://img.shields.io/badge/docs-dev-blue.svg)](https://energymodelsx.github.io/EnergyModelsRecedingHorizon.jl/dev/)

`EnergyModelsRecedingHorizon` is an extension package within the `EnergyModelsX` (`EMX`) framework.
The aim of this package to provide a receding horizon framework on top of `EMX` for operational stress testing the energy system model.
This allows a higher temporal, geographical, and technical resolution than conventional annual analyses.

## Usage

The usage of the package is best illustrated through the commented examples.
The examples are minimum working examples highlighting how to use the receding horizon framework.
In addition, they provide a user with an overview regarding potential adjustments to their elements.

> [!WARNING]
> The package is not yet registered.
> It is hence necessary to first clone the package and manually add the package to the example environment through:
>
> ```julia
> ] dev ..
> ```

## Cite

If you find `EnergyModelsRecedingHorizon` useful in your work, we kindly request that you cite the following [publication](https://doi.org/10.21105/joss.06619):

```bibtex
@article{hellemo2024energymodelsx,
  title = {EnergyModelsX: Flexible Energy Systems Modelling with Multiple Dispatch},
  author = {Hellemo, Lars and B{\o}dal, Espen Flo and Holm, Sigmund Eggen and Pinel, Dimitri and Straus, Julian},
  journal = {Journal of Open Source Software},
  volume = {9},
  number = {97},
  pages = {6619},
  year = {2024},
  doi = {https://doi.org/10.21105/joss.06619},
}
```

## Project Funding

The development of `EnergyModelsRecedingHorizon` was funded by the European Union’s Horizon Europe research and innovation programme in the project [iDesignRES](https://idesignres.eu/) under grant agreement [101095849](https://doi.org/10.3030/101095849).

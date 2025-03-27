# [Example](@id man-ex)

For the content of the individual examples, see the *[examples](https://github.com/EnergyModelsX/EnergyModelsRecedingHorizon.jl/tree/main/examples)* directory in the project repository.

## The package is installed with `] add`

From the Julia REPL, run

```julia
# Starts the Julia REPL
julia> using EnergyModelsRecedingHorizon
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsRecedingHorizon), "examples")
# Include the code into the Julia REPL to run the examples
julia> include(joinpath(exdir, "base_example.jl"))
```

The other examples can be run using

```julia
julia> include(joinpath(exdir, "geography.jl"))
julia> include(joinpath(exdir, "storage_end_value.jl"))
```

## The code was downloaded with `git clone`

The examples can be run from the terminal with

```shell script
/path/to/EnergyModelsRecedingHorizon.jl/examples $ julia base_example.jl
```

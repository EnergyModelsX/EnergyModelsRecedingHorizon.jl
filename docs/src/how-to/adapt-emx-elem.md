# [Adapt an EMX element](@id how_to-adapt_elem)

This package is based on [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/), and therefore several aspects of creating a new element are covered in *[its documentation](@extref EnergyModelsBase how_to-create_node)*.
On this page, we focus on the specific requirements for the introduction of new [`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s in the receding horizon framework.

## [Initialization settings](@id how_to-adapt_elem-init)

An element that presents dynamic states (*e.g.*, storage levels, ...) must have these states explicitly initialized.
In this package, this is done by the introduction of an [`AbstractInitData`](@ref) object.
[`AbstractInitData`](@ref) is an abstract type, and the concrete type [`InitData`](@ref) is provided with the minimum expected functionality for such an object.
The [`AbstractInitData`](@ref) must be used in the model equations to calculate the initial states of the corresponding element.

It is possible to initialize a node through dispatch on [`EMB.constraints_data`](@extref EnergyModelsBase.constraints_data).
An example of such implementation is provided in the test files for the creation of a new node `IncrementInitNode`, see the file *[node_with_initial_data.jl](https://github.com/EnergyModelsX/EnergyModelsRecedingHorizon.jl/tree/main/examples/node_with_initial_data.jl)*.
However, care must be taken when defining the initial state as such, so as to not overspecify the system of equations.

Some nodes have a more specialized way of initialization, such as [`Storage`](@extref EnergyModelsBase.Storage) nodes.
Here, we implement the [`RecedingAccumulating`](@ref) behavior, where the initial level state can be defined through an [`StorageInitData`](@ref) object.
Initialization here is defined by dispatching on [`previous_level`](@ref EMRH.EnergyModelsBase.previous_level), which is already used in the core [`Storage`](@extref EnergyModelsBase.Storage) functionality (see the *[EnergyModelsBase documentation](@extref EnergyModelsBase.previous_level))*.

Additionally, one must create dispatches upon [`update_init_data!`](@ref EMRH.update_init_data!) for new implementations of [`AbstractInitData`](@ref EMRH.AbstractInitData), as well as on other functions, see page on *[problem initialization](@ref dev-init)* for the full list.
This is not needed for elements that can use [`InitData`](@ref) and its default functionalities.

## [Elements with special constructors](@id how_to-adapt_elem-inner_con)

For elements with specific constructor needs, it is necessary to dispatch on `Accessors.ConstructionBase.constructorof`.
This includes elements with parametric types for which the parametric input cannot be deduced from the fields (*e.g.*, `Storage` nodes), as well as elements with inner constructors.
An example of how this can be done is shown in the package for the `Storage` node (see the [`constructorof` dispatch](@ref EMRH.Accessors.ConstructionBase.constructorof)).

## [Elements with partitions](@id how_to-adapt_elem-part)

If you have an [`AbstractElement`](@extref EnergyModelsBase.AbstractElement) that utilizes the concept of partitions *via* [`PartitionProfile`](@extref TimeStruct.PartitionProfile), you must create a new method for the function [`period_duration`](@ref EMRH.period_duration) for your type, which identifies the durations of the partitions.

As an example, consider the node [`PeriodDemandSink`](@extref EnergyModelsFlex.PeriodDemandSink), in which we have demand periods based on partitions.
This node extracts the durations of the partitions using the `EnergyModelsFlex` internal function [`period_duration`](@extref EnergyModelsFlex.period_duration-Tuple{EnergyModelsFlex.AbstractPeriodDemandSink}).

In this situation, you must declare a new method for [`period_duration`](@ref EMRH.period_duration) (the `EnergyModelsRecedingHorizon` function) as

```julia
const EMRH = EnergyModelsRecedingHorizon
const EMF = EnergyModelsFlex

EMRH.period_duration(n::EMF.AbstractPeriodDemandSink) = EMF.period_duration(n)
```

!!! warning "Caveats of period partitions"
    It is **not** possible to specify a `FixedProfile` for the duration of the period partitions due to the way the horizons are calculated.

    Using partitions is experimental:

    1. You must be careful that the structure of the chosen partitions are in line with both the optimization and implementation horizon such that partitions are not split in the receding horizon optimization problems.
    2. Partitions must be of the same length in all horizons if you utilize the `ParametricOptInterface` extension.
       This is checked in the

    See the examples below:

    ```julia
    # Time structure and chosen horizon
    𝒯 = TwoLevel(1, 1, SimpleTimes(15, 1))
    ℋ = PeriodHorizons(15, 1, 8, 4)

    # Consistent profiles
    pprof_1 = PartitionProfile([2, 2, 2, 2, 2, 2, 2, 1])
    pprof_2 = PartitionProfile([4, 4, 4, 3])

    # Inconsistent profile
    pprof_wrong_1 = PartitionProfile([3, 3, 3, 3, 3])

    # Inconsistent profile for the ParametricOptInterface extension
    pprof_wrong_2 = PartitionProfile([4, 2, 2, 4, 2, 1])
    ```

    * The profile `pprof_wrong_1` is inconsistent for the receding horizon framework as the individual partitions are not fully included in both the implementation and optimization horizons.
    * The profile `pprof_wrong_2` is inconsistent for the `ParametricOptInterface` extension as the partitions are different in the different horizons while it would work for the base design.
    The profiles would, however, be consistent for a standard perfect foresight model.

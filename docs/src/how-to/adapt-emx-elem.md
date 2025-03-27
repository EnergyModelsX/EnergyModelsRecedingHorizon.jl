# [Adapt an EMX element](@id how_to-adapt_elem)

This package is based on [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/), and therefore several aspects of creating a new element are covered in *[its documentation](@extref EnergyModelsBase how_to-create_node)*.
In this page, we will focus on the specific requirements for the introduction of new [`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s in the receding horizon framework.

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

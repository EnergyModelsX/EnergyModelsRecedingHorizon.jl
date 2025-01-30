# [Create a new node](@id how_to-create_node)

This package is based on [`EnergyModelsBase`](https://github.com/EnergyModelsX/EnergyModelsBase.jl), and therefore several aspects of creating a new node are covered in *[its documentation](@extref EnergyModelsBase how_to-create_node)*.
In this page, we will focus on the specific requirements for use in the receding horizon framework.

A node that presents dynamic states (*e.g.*, storage levels, ...) must have these states explicitly initialized.
In this package, this is done by the introduction of an [`AbstractInitData`](@ref) object.
[`AbstractInitData`](@ref) is an abstract type, and the concrete type [`InitData`](@ref) is provided with the minimum expected functionality for such an object.

The most general way of initializing a node is through dispatch on [`EMB.constraints_data`](@extref EnergyModelsBase.constraints_data).
An example of such implementation is provided in the test files for the creation of a new node [`SampleInitNode`], see the file *[test_newnode.jl](https://gitlab.sintef.no/idesignres/wp-2/energymodelsrechorizon.jl/-/tree/main/test/test_newnode.jl)*.

Some nodes may have a more specialized way of initialization, such as [`Storage`](@extref EnergyModelsBase.Storage) nodes.
Here, we implement the [`RecedingAccumulating`](@ref) behavior, where the initial level state can be defined through an [`StorageInitData`](@ref) object.
Initialization here is defined by dispatching on [`previous_level`](@ref EMRH.EnergyModelsBase.previous_level), which is already used in the core [`Storage`](@extref EnergyModelsBase.Storage) functionality (see the *[EnergyModelsBase documentation](@extref EnergyModelsBase.previous_level))*.

Additionally, one must create dispatches upon [`get_init_state`](@ref EMRH.get_init_state) for new nodes.
This function should return an [`AbstractInitData`](@ref) object based on the solution of the optimization problem in a previous time window, such that the system is initialized properly for the solution of the following receding horizon problems.

!!! todo "Rewrite"
    Rewrite the section based on what is really required.
    This includes as well dispatching on the function `EMRH.Accessors.ConstructionBase.constructorof(obj::Type{<:Storage})` if the type is parametric and its parametric input cannot be deduced from the fields (*e.g.*, `Storage` nodes) or if the node has an inner constructor.

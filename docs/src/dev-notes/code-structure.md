# [Code structure](@id dev-code)

[`EnergyModelsRecedingHorizon`](@ref EMRH.EnergyModelsRecedingHorizon) is based on setting up optimization subproblems given implementation and optimization horizons.
The horizons for the optimization subproblems are expressed through [`AbstractHorizons`](@ref EMRH.AbstractHorizons) objects, see the *[dedicated section on horizons](@ref man-phil-hortyp)*.
These will ultimately define how many optimization subproblems will be solved and how large they will be.

## [General concept](@id dev-code-gen)

For every iteration over the horizons, the optimization subproblem needs to be updated for the time-dependent fields.
This is done through [`AbstractPath`](@ref EMRH.AbstractPath) objects, whose aim is to automatically identify the model variables that need updating.
Each [`AbstractPath`](@ref EMRH.AbstractPath) object corresponds to a field in the model structure to be updated.
The creation of the accessors to these fields (known as [lenses](https://juliaobjects.github.io/Accessors.jl/stable/lenses/)) is done through [`AbstractReset`](@ref EMRH.AbstractReset) objects, allowing for type checking of the fields to be updated.
This object must always be created through [`ResetType`](@ref EMRH.ResetType) constructors.
The element subject to updating is wrapped around an [`AbstractSub`](@ref EMRH.AbstractSub) object, where the original (full-problem) and new (receding horizon) instances of the element are included as fields, as well as the [`AbstractReset`](@ref EMRH.AbstractReset) objects linked to the element.
A unified constructor, [`Substitution`](@ref EMRH.Substitution), is used within the model.

As a general rule, the fields that require updating are either related to the initial conditions of the system or to the time profiles that the system is subject to.
For updating the time profiles, we read the originally provided time profile for the full optimization problem.
As for the initial conditions of the system, each element is assumed to be independently initializable through their own variables.
Initialization of the system is therefore done at the element level, which we describe in more detail in the *[dedicated page on initialization](@ref dev-init)*.

## [Implemented reset types](@id dev-code-res_type)

The individual reset types correspond to fields of an element that should be replaced.
The reset types have as individual fields

- **`lens`** representing the lens pointing towards the field in the type,
- **`var`** corresponding to the parameter variable when using `ParametricOptInterface`, and
- **`val`** is the value which is used in the resets.
  Its meaning differs depending on the individual reset type.

`EnergyModelsRecedingHorizon` implements the following standard reset types:

- **`OperReset`** with `OperPath`: A reset type pointing towards a field with `OperationalProfile`.\
  The field `val` corresponds to the operational profile of the full time structure, **not** the profile of the individual horizon.
- **`ElementReset`** with `ElementPath`: A reset type pointing towards a field with an [`AbstractElement`](@extref EnergyModelsBase.AbstractElement).\
  The field `val` corresponds to the instance of the element of the original case type.
- **`TimeWeightReset`** with `TimeWeightPath`: A reset type for a time weight of a [`FutureValue`](@ref).\
  The field `val` is updated at the beginning of each iteration according to the optimization horizon end time.
- **`InitReset`** with `AbstractInitDataPath`: A reset type pointing towards fields of initial data.\
  In addition, it has the `AbstractInitDataPath` instance as second field.
  The field `val` is updated after each optimization iteration with the extracted value from the optimization results.

All reset types utilize an inner constructor for creating the lens in their construction.
Furthermore, all reset types are constructed only through the function [`EMRH.ResetType`](@ref).

!!! tip "New reset types"
    While the core structure includes the majority of the required reset types, it can be necessary to create new reset types.
    In this case, you must create:

    1. a subtype to [`AbstractPath`](@ref),
    2. a subtype to [`EMRH.AbstractReset`](@ref),
    3. a new method for the function [`ResetType`](@ref EMRH.ResetType) using the same arguments order,
    4. a new method for the function [`EMRH._find_update_paths`](@ref EMRH._find_update_paths(x::T) where {T <: Union{AbstractElement, Resource, EMRH.RecHorEnergyModel}}), and
    5. a new method for the function [`EMRH._reset_field`](@ref EMRH._reset_field(x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, opers::Vector{<:TS.TimePeriod})) and *[its `POI` extension](@ref EMRH._reset_field(m, x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure))*.

    In general, it should not be necessary to create a new reset type as we simplified the approach for initialization data through the utilization of a parametric type.

## [Implemented substitution types](@id dev-code-sub_type)

Substitution types unify all resets within an [`AbstractElement`](@extref EnergyModelsBase.AbstractElement).
All substitution types are parametric on the element type and have the fields

- **`new`** representing the new element instance that is used in the case for analysis,
- **`org`** representing the original element instance from the original case structure, and
- **`resets::Vector{<:AbstractReset}`** including all `AbstractReset`s that are relevant for the given type.

They are constructed through the function [`EMRH.Substitution`](@ref).

`EnergyModelsRecHorizon` implements the following standard reset types:

- **`ModelSub`** for resetting fields in the model type,
- **`ProductSub`** for resetting fields in [`Resource`](@extref EnergyModelsBase lib-pub-res)s,
- **`NodeSub`** for resetting fields in [`Node`](@extref EnergyModelsBase lib-pub-nodes),
- **`LinkSub`** for resetting fields in [`Link`](@extref EnergyModelsBase lib-pub-links), and
- **`FutureValueSub`** for resetting fields in [`FutureValue`](@ref).

The extension for `EnergyModelsGeography` adds the following additional reset types:

- **`AreaSub`** for resetting fields in [`Area`](@extref EnergyModelsGeography lib-pub-area)s and
- **`TransmissionSub`** for resetting fields in [`Transmission`](@extref EnergyModelsGeography lib-pub-transmission) corridors.

!!! tip "New `AbstractElement`s"
    If your `EnergyModelsBase` extension introduces new `AbstractElement`s, you must provide:

    1. a subtype to [`EMRH.AbstractSub`](@ref),
    2. a method to the function [`EMRH._ele_to_sub`](@ref), and
    3. a method for your function for extracting the `AbstractElement` from the `UpdateCase`, see, *e.g.*, [`EMB.get_nodes`](@ref).

    Depending on the structure of your `AbstractElement`, it can be furthermore necessary to provide new methods to the functions [`EMRH.original`](@ref) and [`EMRH.updated`](@ref).

## [Internal work flow](@id dev-code-int_flow)

While the internal work flow is in general the same whether you use [`ParametricOptInterface`](https://jump.dev/ParametricOptInterface.jl/stable/) or not, there are some differences in the individual function flow.
The following section provides the general overview with differentiation between the individual implementations.

1. The [`UpdateCase`](@ref EMRH.UpdateCase) is first created for all elements through the functions [`EMRH._create_updatetype`](@ref) and [`EMRH._add_elements!`](@ref).
   These functions create the individual substitution and reset types including the relevant lenses.
   The functions are agnostic whether you use `ParametricOptInterface` or not.

   !!! note "POI implementation"
       The `POI` implementation requires as additional step the initialization of the `JuMP` model through calling the function [`create_model`](@extref EnergyModelsBase.create_model) to avoid constructing the model in every single iteration.
       To this end, the specific case and model are initialized through the function [`POIExt._init_update_case!`](@ref) in which the first horizon is used for the initialization of the optimization problem and the creation of the additional auxiliary variables required for the parameters.

2. The individual elements with [`AbstractInitData`](@ref) are identified to avoid iterating through all elements in each iteration of the receding horizon framework.
   In addition, we rearrange the [`FutureValue`](@ref) substitution types for simplified later updating.
3. The algorithm iterates through all horizons sequentially and solves the optimization problem.
    1. If the system includes [`FutureValue`](@ref) types, we update `FutureValue`s whose weight is dependent on the elapsed time using the function [`EMRH._update_future_value!`](@ref).
       This is for example the case for [`StorageValueCuts`](@ref).
    2. The second step is different in the two implementations.

       !!! tip "Standard implementation"
           In the standard implementation, we first update the `UpdateCase` created in the first step through the function [`EMRH._update_update_case!`](@ref) and subsequently extract from the `UpdateCase` both the `model` and `case` required for creating an EMX model.
           Subsequently, we create the `JuMP` model through calling the function [`create_model`](@extref EnergyModelsBase.create_model).

       !!! note "POI implementation"
           In the `POI` implementation, we only have to update the values of the created parameter variables through the function [`POIExt.update_model!`](@ref).

       Subsequently, the model is optimized.
    3. Once the model is solved, the operational results for the implementation horizon are extracted from the model and saved as a `DataFrame` through the function [`EMRH.update_results!`](@ref).
       Variables that are indexed with strategic periods are **not** extracted.
    4. The value of the reset type for initialization data is updated using the results from the optimization problem using the function [`EMRH.update_init_data!`](@ref).

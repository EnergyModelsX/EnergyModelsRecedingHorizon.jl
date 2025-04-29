# [Implementation of future values](@id dev-fv)

As outlined on the page *[implementation of future values](@ref man-fv)*, we implemented a new [`AbstractElement`](@extref EnergyModelsBase.AbstractElement) for representing the future value in dynamic constraints.
So far, two subtype are implemented through [`StorageValueCuts`](@ref) and  [`TypeFutureValue`](@ref).
It is however possible to provide new subtypes representing different implementations for calculating or constraining a future value.

## [Function flow for incorporating future values](@id dev-fv-fun_flow)

As mentioned, [`FutureValue`](@ref) is implemented as subtype of [`AbstractElement`](@extref EnergyModelsBase.AbstractElement).
This implies that the package must provide methods for a variety of individual functions from `EnergyModelsBase`.

The new methods for variable creation are

- [`EMB.variables_capacity`](@ref), not incorporating any new variable,
- [`EMB.variables_flow`](@ref), not incorporating any new variable,
- [`EMB.variables_opex`](@ref), incorporating the new variable ``\texttt{future\_value}(v) ~ \forall v \in V``,
- [`EMB.variables_element`](@ref), not incorporating any new variable, and
- [`EMB.variables_emission`](@ref), not incorporating any new variable.

This implies that we currently only include a single additional variable for the future value, ``\texttt{future\_value}(v)``.
This variable is created for all subtypes of `FutureValue`.

The individual constraints are added through the methods

- [`EMB.constraints_elements`](@ref), calling the subfunction [`EMRH.create_future_value`](@ref),
- [`EMB.constraints_couple`](@ref), calling the subfunction [`EMRH.create_future_value_couple`](@ref),
- [`EMB.emissions_operational`](@ref), returning a `JuMP` expression of 0 with the required indices as [`FutureValue`](@ref)s do not result in emissions, and
- [`EMB.objective_operational`](@ref), calling the subfunction [`EMRH.get_future_value_expression`](@ref).

There are two things to highlight in this design:

1. the default method for [`EMRH.create_future_value`](@ref) does not create any constraints and
2. [`EMRH.create_future_value_couple`](@ref) is only declared for `StorageValueCuts`.

Point 1 implies that the variable ``\texttt{future\_value}(v)`` does not have any internal constraints by default.
It is instead constrained for the implementation of `StorageValueCuts` through the function [`EMRH.create_future_value_couple`](@ref).
The thought process behind this approach is that `StorageValueCuts` are constrained through `Storage` nodes.
It is hence a `constraints_couple` constraint, even if the function has only a single input, `𝒱::Vector{<:FutureValue}`.

We furthermore decided to split the overall contribution to the cost function in the current design into additional subfunctions through [`EMRH.get_future_value_expression`](@ref) for the individual supertypes.
While this is not strictly necessary, it is one approach for differentiating between subtypes of `FutureValue`.

Within the concept of `EnergyModelsRecedingHorizon`, we added as well an additional function [`EMRH._update_future_value!`](@ref) for updating parameters of the `FutureValue` before each optimization run.

!!! warning "Default methods"
    We do not include default methods for the subfunctions.
    These subfunctions are [`EMRH.create_future_value_couple`](@ref) and [`EMRH.get_future_value_expression`](@ref).
    As a consequence, you must declare them for your new type.

    The philosophy here is that it is preferable that the developer of new methods receives a method error instead of no error when he implements a wrong method.

## [Requirements for new future values](@id dev-fv-new)

It is possible to create new [`FutureValue`](@ref)s.
This requires a combination of new types and new metods.
The following steps must be conducted to incorporate a new type:

1. Create a new type as composite type:

   ```julia
   struct NewFutureValue <: FutureValue
       id::Any
   end
   ```

   It can include as many fields as desired, but it 1. **must** include the field `id` and 2. cannot include a dictionary in which a [`Node`](@extref EnergyModelsBase lib-pub-nodes) is a key (you may use [`ElementValue`](@ref) instead if necessary).
2. Create a new method for the function [`EMRH.create_future_value_couple`](@ref) for your `NewFutureValue`.
   In general, you should have the corresponding `Node` as field of your `NewFutureValue`.
   If this is not the case, *e.g.*, through assigning the same future value for all instances of a given variable of a type, it is necessary to provide new methods for [`EMB.constraints_couple`](@ref) which also includes a potentially empty method for `FutureValue`.
3. Create a new method for the function [`EMRH.get_future_value_expression`](@ref) which returns a `JuMP` expression indexed over the strategic periods which corresponds to the contribution to the cost function.
4. Create a new method for the function [`EMRH._update_future_value!`](@ref).
   This function is used for updating potential fields that are dependent on the elapsed time *before* the optimization problem is solved.
   If the future value for your `NewFutureValue` is independent of the elapsed time, you can provide an empty method.

!!! tip "Additional variables and internal constraints"
    If your `NewFutureValue` requires additional variables, you can create a new method for [`EMB.variables_element`](@ref).
    These variables will then be accessible in all potential subsequent functions.
    If you have internal constraints, that is constraints only accessing variables indexed over `Vector{<:NewFutureValue>}`, you must create a new method for [`EMRH.create_future_value`](@ref) and add these constraints in this function.

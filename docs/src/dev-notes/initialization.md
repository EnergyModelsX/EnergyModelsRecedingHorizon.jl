# [Problem initialization](@id dev-init)

Initialization functions are necessary for proper definition of the optimization problem.
The initialization of a node must be fully defined by an object of type [`AbstractInitData`](@ref).
The concrete type [`InitData`](@ref) is implemented with the expected functionality for most problems.
It features a dictionary with the keys being the labels of the states subjected to updates.
A standard behavior for [`InitData`](@ref) is provided, which allows for updating considering that the labeled states can be initialized by their previously calculated values at the corresponding time period, *i.e.* the last implementation time period.
The variables to be read from the model can only be indexed over the associated [`AbstractElement`](@extref EnergyModelsBase.AbstractElement) and [`TimePeriod`](@extref TimeStruct.TimePeriod).

To utilize the [`AbstractInitData`](@ref) object in the model calculations, additional equations must be provided.
That can be done in several ways, and the user is referred to the page on *[how to adapt EMX elements](@ref how_to-adapt_elem)* for examples.

## [Custom initialization objects](@id dev-init-custom)

The user that implements new [`AbstractInitData`](@ref) types must implement methods for the functions that process this object, as well as extra types.
The functions to be dispatched upon for a new [`AbstractInitData`](@ref) are

- [`_find_update_paths`](@ref EMRH._find_update_paths) is the function used to detect the fields in the [`AbstractInitData`](@ref) object to be updated over changing horizons and
- [`update_init_data!`](@ref EMRH.update_init_data!) is the function used to update the receding horizon [`AbstractInitData`](@ref) object based on the solution of the receding horizon problem in a previous time window.

These functions are automatically used in the main function [`run_model_rh`](@ref), and they can be easily dispatched upon for custom elements.

In addition, a new subtype of [`AbstractInitDataPath`](@ref EMRH.AbstractInitDataPath) associated to the new object must be created.
[`AbstractInitDataPath`](@ref EMRH.AbstractInitDataPath) refers to a subtype of [`AbstractPath`](@ref EMRH.AbstractPath), which serves to identify the model variables that need updating (see the section on the *[code structure](@ref dev-code)* for more details).
The standard behavior for this object is implemented in [`InitDataPath`](@ref EMRH.InitDataPath), which simply contains the variable key to be updated.

One example for the implementation of a new initial data is given by [`TransInitData`](@ref EMGExt.TransInitData) in the `EnergyModelsGeography` extension and its *[internal library](@ref lib-int-EMGExt)*:

- [`TransInitData`](@ref EMGExt.TransInitData),
- [`TransInitDataPath`](@ref EMGExt.TransInitDataPath),
- [`EMRH._find_update_paths`](@ref EMRH._find_update_paths(field::Vector{T}, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:TransmissionMode}),
- [`EMRH.update_init_data!`](@ref EMRH.update_init_data!(m, ri::EMRH.AbstractReset, l::Transmission, idp::EMGExt.TransInitDataPath, opers_implᵣₕ))
- [`POIExt._update_parameter!`](@ref POIExt._update_parameter!), only required for the `ParametricOptInterface` extension.

The extension `POIExt` can be accessed for dispatching through

```julia
using EnergyModelsRecedingHorizon
using ParametricOptInterface

const EMRH = EnergyModelsRecedingHorizon
const POIExt = Base.get_extension(EMRH, :POIExt)
```

!!! warning "New initial data with Vectors and POI"
    If you create a new `AbstractInitData` in which the values that are reset are vectors (or generally speaking, not single values), you must create a new method [`EnergyModelsRecedingHorizon._reset_field`](@ref EMRH._reset_field(m, x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure)) for the `res_type` argument for the `ParametricOptInterface` implementation.

    An example for a new type `VectorInitData` (with `VectorInitDataPath` for identifying the path) is given by

    ```julia
    function EMRH._reset_field(
        m,
        x_rh,
        res_type::InitReset{VectorInitDataPath},
        𝒰::UpdateCase,
        𝒯ᴿᴴ::TimeStructure,
    )
        val_par = MOI.Parameter.(res_type.val)
        res_type.var = @variable(m, [eachindex(res_type.val)] ∈ val_par)
        @reset res_type.lens(x_rh) = res_type.var
        return x_rh
    end
    ```

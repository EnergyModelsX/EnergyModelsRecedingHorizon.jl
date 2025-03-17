# [Resetting functionality](@id lib-int-reset)

## [Index](@id lib-int-reset-idx)

```@index
Pages = ["reset.md"]
```

## [Paths](@id lib-int-reset-path)

Path are internal types that are used for the identification of a reset.
They are used internally for dispatch.

```@docs
EMRH.AbstractPath
EMRH.OperPath
EMRH.ElementPath
EMRH.TimeWeightPath
EMRH.AbstractInitDataPath
EMRH.InitDataPath
```

The following function is included for extracting the values from paths:

```@docs
EMRH.model_key(idp::EMRH.InitDataPath)
```

!!! note "Resetting new values"
    If you must reset a different type of value than outlined below, you must also create a new type.
    This is especially important when creating a new [`AbstractInitData`](@ref).

## [Reset types](@id lib-int-reset-reset)

Reset types are introduced to differentiate on what must be reset in a given element.
They are used internally for dispatch.

```@docs
EMRH.AbstractReset
EMRH.ElementReset
EMRH.OperReset
EMRH.TimeWeightReset
EMRH.InitReset
EMRH.ResetType
```

The following function is included for identification purposes:

```@docs
EMRH.is_init_reset
```

!!! note "Resetting new values"
    If you **must** reset a different type of value than outlined below, you must also create a new type.
    If you create a new `AbstractPath`, it is not neccesary to create a new type.

    In this case, you **must** also create a new method for [`ResetType`](@ref EMRH.ResetType) as this function is used internally.

## [Substitution types](@id lib-int-reset-sub)

`Substitution` types correspond to types that store information of the individual original instance, the updated instance, and all required resets of an object:

```@docs
EMRH.AbstractSub
EMRH.ModelSub
EMRH.ProductSub
EMRH.NodeSub
EMRH.LinkSub
EMRH.FutureValueSub
EMRH.Substitution
```

The following function is included for extracting the values from substitution types:

```@docs
EMRH.resets
```

The following function is included for simplifying the overall code structure:

```@docs
EMRH._ele_to_sub
```

!!! note "Introducing new Elements"
    If you introduce new [`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s, you **must** also create a new subtype of [`AbstractSub`](@ref EMRH.AbstractSub), similar to [`NodeSub`](@ref EMRH.NodeSub) or [`LinkSub`](@ref EMRH.LinkSub).
    The new subtype should have the same fields as the other subtypes.

    In this case, you **must** also create a new method for [`_ele_to_sub`](@ref EMRH._ele_to_sub)

## [Update case type](@id lib-int-reset-update)

All update information for updating/resetting the case dictionary and the model is stored within a single type:

```@docs
EMRH.UpdateCase
```

The following functions are included for extracting the values from paths:

```@docs
EMRH.get_sub_model
EMRH.get_sub_periods
EMRH.get_sub_products
EMRH.get_sub_elements_vec
EMRH.get_sub_ele
EMRH.updated
EMRH.original
```

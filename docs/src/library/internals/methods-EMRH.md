# [Methods - Internal](@id lib-int-met)

## [Index](@id lib-int-met-idx)

```@index
Pages = ["methods-EMRH.md"]
```

### [Extension functions](@id lib-int-ext)

```@docs
EMRH.update_init_data!
```

### [Utility functions](@id lib-int-util)

```@docs
EMRH.update_results!
EMRH.save_results
EMRH.get_results
EMRH.get_results_df
```

### [Miscellaneous functions](@id lib-int-ext)

```@docs
EMRH.init_level
EMRH._create_lens_dict
```

### [Identification functions](@id lib-int-ident)

```@docs
EMRH._find_update_paths(x::T) where {T <: Union{AbstractElement, Resource, EMRH.RecHorEnergyModel}}
EMRH._dict_key
EMRH._create_lens_for_field
EMRH._path_type
```

### [Functions for resetting values](@id lib-int-reset)

```@docs
EMRH._create_updatetype
EMRH._add_elements!
EMRH._update_future_value!
EMRH._update_update_case!
EMRH._reset_field(x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, opers::Vector{<:TS.TimePeriod})
```

The following function is introduced for parametric types in which the type is not deducible from the input and for types with inner constructors:

```@docs
EMRH.Accessors.ConstructionBase.constructorof
```

### [Future value functions](@id lib-int-fut_val)

```@docs
EMRH.get_future_value_expression
EMRH.create_future_value
EMRH.create_future_value_couple
```

The following functions for accessing fields of the types are introduced:

```@docs
EMRH.coefficients
EMRH.cut_rhs
EMRH.weight
EMRH.time_weight
EMRH.cuts_time
EMRH.cuts
EMRH.element_type
```

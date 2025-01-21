# [Methods - Internal](@id lib-int-met)

## [Index](@id lib-int-met-idx)

```@index
Pages = ["methods-EMH.md"]
```

### [Extension functions](@id lib-int-ext)

```@docs
EMRH.get_init_state
```

### [Utility functions](@id lib-int-util)

```@docs
EMRH.initialize_container
EMRH.update_results!
EMRH.save_results
```

### [Miscellaneous functions](@id lib-int-ext)

```@docs
EMRH.init_level
EMRH._get_node_index
EMRH.get_results
EMRH._create_lens_dict_oper_prof
```

### [Identification functions](@id lib-int-ident)

```@docs
EMRH._has_unique_strings
EMRH._find_paths_operational_profile
EMRH._fields_with_operational_profile
EMRH._has_field_operational_profile
```

### [Functions for resetting values](@id lib-int-reset)

```@docs
get_rh_case_model
EMRH._get_element_rh
EMRH._get_model_rh(model::EMRH.RecHorEnergyModel, map_dict, lens_dict, 𝒯ᴿᴴ)
EMRH._create_lens_for_field
EMRH._reset_field(x_rh, lens, val::EMB.Node, map_dict, 𝒯ᴿᴴ)
```

The following function is introduced for parametric types in which the type
is not deducable from the input and for types with inner constructors:

```@docs
EMRH.Accessors.ConstructionBase.constructorof
```

### [ParametricOptInterface functions](@id lib-int-poi)

```@docs
EMRH.init_rh_case_model
EMRH.update_model!
EMRH._get_elements_rh
EMRH._reset_field(m, x_rh, lens, val::T, 𝒯ᴿᴴ) where {T<:Real}
EMRH._get_model_rh(m, model::EMRH.RecHorEnergyModel, map_dict, lens_dict, 𝒯ᴿᴴ::TimeStructure)
EMRH._set_elements_rh!
EMRH._get_value
EMRH._set_parameter!
```

The following functions are not in use, but remain in the code for potential
later use.

```@docs
EMRH._set_POI_par_as_operational_profile
EMRH._set_values_operational_profile
EMRH._get_new_POI_values
```

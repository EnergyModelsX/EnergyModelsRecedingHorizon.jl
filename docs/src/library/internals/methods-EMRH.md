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
EMRH.update_results!
EMRH.save_results
EMRH.get_results
EMRH.get_results_df
```

### [Miscellaneous functions](@id lib-int-ext)

```@docs
EMRH.init_level
EMRH._get_node_index
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
EMRH._get_elements_rh(𝒳::Vector{T}, map_dict, lens_dict, opers::Vector{<:TS.TimePeriod}) where {T<:AbstractElement}
EMRH._get_model_rh(model::EMRH.RecHorEnergyModel, map_dict, lens_dict, opers::Vector{<:TS.TimePeriod})
EMRH._create_lens_for_field
EMRH._reset_field(x_rh::AbstractElement, lens::L, val::EMB.Node, map_dict, opers::Vector{<:TS.TimePeriod}) where {L <: Union{EMRH.Accessors.PropertyLens, ComposedFunction}}
```

The following function is introduced for parametric types in which the type
is not deducible from the input and for types with inner constructors:

```@docs
EMRH.Accessors.ConstructionBase.constructorof
```

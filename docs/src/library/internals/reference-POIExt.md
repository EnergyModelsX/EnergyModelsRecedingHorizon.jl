# [Internals - ParametricOptInterface extension](@id lib-int-POIExt)

## [Index](@id lib-int-POIExt-idx)

```@index
Pages = ["reference_POIExt.md"]
```

```@meta
CurrentModule =
    Base.get_extension(EMRH, :POIExt)
```

## [Extension](@id lib-int-POIExt-ext)

### [Utility functions](@id lib-POIExt-ext-util)

```@docs
_init_update_case!
update_model!
```

```@docs
_update_parameter_values!
_update_parameter!
```

### [Unused functions](@id lib-POIExt-ext-unused)

```@docs
_set_POI_par_as_operational_profile
_set_values_operational_profile
_get_new_POI_values
```

## [EnergyModelsRecHorizon](@id lib-int-POIExt-EMRH)

### [Exported methods](@id lib-int-POIExt-EMRH-exp_met)

```@docs
EMRH.run_model_rh(case::AbstractCase, model::EMRH.RecHorEnergyModel, optimizer::POI.Optimizer; check_timeprofiles::Bool = true)
```

### [Internal methods](@id lib-int-POIExt-EMRH-int_met)

```@docs
EMRH._update_case_types!(m, 𝒮::Vector{<:EMRH.AbstractSub}, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure)
EMRH._reset_field(m, x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure)
```

# [Internals - ParametricOptInterface extension](@id lib-int-POIExt)

## [Index](@id lib-int-POIExt-idx)

```@index
Pages = ["reference-POIExt.md"]
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
_update_parameter!(m, res_type::EMRH.ElementReset, opers::Vector)
```

## [EnergyModelsRecedingHorizon](@id lib-int-POIExt-EMRH)

### [Exported methods](@id lib-int-POIExt-EMRH-exp_met)

Because the receding horizon implementation using [`ParametricOptInterface`](https://jump.dev/ParametricOptInterface.jl/dev/) relies on pre-allocation of the input parameters for time profiles, its use is only allowed with [`PeriodHorizons`](@ref), as it is a horizon type that preserves the length of the input time profiles.

```@docs
EMRH.run_model_rh(case::AbstractCase, model::EMRH.RecHorEnergyModel, optimizer::POI.Optimizer; check_timeprofiles::Bool = true)
```

### [Internal methods](@id lib-int-POIExt-EMRH-int_met)

```@docs
EMRH._update_case_types!(m, 𝒮::Vector{<:EMRH.AbstractSub}, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure)
EMRH._reset_field(m, x_rh, res_type::EMRH.ElementReset, 𝒰::EMRH.UpdateCase, 𝒯ᴿᴴ::TimeStructure)
```

## [EnergyModelsBase](@id lib-int-POIExt-EMB)

```@docs
EMB.constraints_capacity_installed
```

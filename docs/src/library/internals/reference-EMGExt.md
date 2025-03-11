# [Internals - EnergyModelsGeography extension](@id lib-int-EMGExt)

## [Index](@id lib-int-EMGExt-idx)

```@index
Pages = ["reference-EMGExt.md"]
```

## [Extension](@id lib-int-EMGExt-ext)

### [Utility functions](@id lib-EMGExt-ext-util)

```@docs
EMRH.update_init_data!(m, ri::EMRH.AbstractReset, l::Transmission, idp::EMGExt.TransInitDataPath, opers_implᵣₕ)
```

## [EnergyModelsRecHorizon](@id lib-int-EMGExt-EMRH)

### [Types](@id lib-int-EMGExt-EMRH-typ)

The following types are introduced for providing initial data for [`TransmissionMode`](@extref EnergyModelsGeography.TransmissionMode)s.
Only [`PipeLinepackSimple`](@extref EnergyModelsGeography.PipeLinepackSimple) supports at the moment initial data.

```@docs
EMGExt.TransInitData
EMGExt.TransInitDataPath
```

The following functions are included for extracting the values from a `TransmissionMode` and initial data type:

```@docs
data_init(a::Area)
EMRH.model_key(idp::EMGExt.TransInitDataPath)
```

In addition, we provide a new method for the identification of initial data:

```@docs
EMRH.has_init(a::Area)
```

The following types are introduced for the resetting of the fields

```@docs
EMGExt.AreaSub
EMGExt.TransmissionSub
```

### [Internal methods](@id lib-int-EMGExt-EMRH-int_met)

```@docs
EMRH._find_update_paths(field::Vector{T}, current_path::Vector{Any}, all_paths::Vector{Any}) where {T<:TransmissionMode}
```

## [EnergyModelsGeography](@id lib-int-EMGExt-EMG)

### [Constraint functions](@id lib-int-EMGExt-EMG-con)

```@docs
EMG.constraints_trans_balance
EMG.constraints_capacity_installed
```

`constraints_capacity_installed` only receives a new method if `ParametricOptInterface` is loaded.

### [Functions for accessing fields](@id lib-int-EMGExt-EMG-fun_field)

The following functions are introduced for [`UpdateCase`](@ref EMRH.UpdateCase) types.
They extract the [`updated`](@ref EMRH.updated) value.

```@docs
EMG.get_areas
EMG.get_transmissions
```

## [ParametricOptInterface](@id lib-int-EMGExt-POI)

```@docs
POIExt._update_parameter!(m, res_type::EMRH.InitReset{EMGExt.TransInitDataPath}, opers::Vector)
```

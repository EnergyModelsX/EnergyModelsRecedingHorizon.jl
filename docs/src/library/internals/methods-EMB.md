# [Methods - `EnergyModelsBase`](@id lib-int-met_emb)

## [Index](@id lib-int-met_emb-idx)

```@index
Pages = ["methods-EMB.md"]
```

## [Extension methods](@id lib-int-met_emb-ext)

```@docs
EnergyModelsBase.objective_operational
EnergyModelsBase.emissions_operational
EnergyModelsBase.constraints_elements
EnergyModelsBase.constraints_couple
EnergyModelsBase.previous_level
```

## [Variable methods](@id lib-int-met_emb-var)

```@docs
EnergyModelsBase.variables_capacity
EnergyModelsBase.variables_flow
EnergyModelsBase.variables_opex
EnergyModelsBase.variables_capex
EnergyModelsBase.variables_element
EnergyModelsBase.variables_emission
```

## [Functions for accessing different information](@id lib-int-met_emb-fun_field)

The following functions are introduced for [`UpdateCase`](@ref EMRH.UpdateCase) types.
They extract the [`updated`](@ref EMRH.updated) value.

```@docs
EnergyModelsBase.get_products
EnergyModelsBase.get_elements_vec
EnergyModelsBase.get_nodes
EnergyModelsBase.get_links
```


"""
    abstract type RecHorEnergyModel <: EnergyModel end

Abstract type for receding horizon models.
"""
abstract type RecHorEnergyModel <: EnergyModel end

"""
    struct RecHorOperationalModel <: RecHorEnergyModel

Operational energy model without investments, receding horizon implementation.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** is a dictionary with \
individual emission limits as `TimeProfile` for each emission resource `ResourceEmit`.\n
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the prices for the \
different emissions types considered.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO₂.\n
"""
struct RecHorOperationalModel <: RecHorEnergyModel
    emission_limit::Dict{<:ResourceEmit,<:TimeProfile}
    emission_price::Dict{<:ResourceEmit,<:TimeProfile}
    co2_instance::ResourceEmit
end

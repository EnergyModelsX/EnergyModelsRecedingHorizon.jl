
"""Abstract type for receding horizon models"""
abstract type RecHorEnergyModel <: EnergyModel end

"""
Operational Energy Model without investments, receding horizon implementation.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** is a dictionary with \
individual emission limits as `TimeProfile` for each emission resource `ResourceEmit`.\n
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the prices for the \
different emissions types considered.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO₂.\n
- **`opt_horizon`** corresponds to the horizon for which the problem will be optimized \
at each iteration.\n
- **`impl_horizon`** corresponds to the horizon for which each solution will be implemented \
at each iteration.\n
"""
struct RecHorOperationalModel <: RecHorEnergyModel
    emission_limit::Dict{<:ResourceEmit,<:TimeProfile}
    emission_price::Dict{<:ResourceEmit,<:TimeProfile}
    co2_instance::ResourceEmit
    horizons::AbstractHorizons
end

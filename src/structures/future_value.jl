"""
    abstract type  FutureValue <: AbstractElement

Declaration of the abstract type for future value descriptions in the optimization.
"""
abstract type  FutureValue <: AbstractElement end
Base.show(io::IO, v::FutureValue) = print(io, "fut_val_$(v.id)")

"""
    ElementValue{T<:Union{TimeProfile, Real}}

An `ElementValue` represents an instance of a given
[`AbstractElement`](@extref EnergyModelsBase.AbstractElement) with an assigned value.
It replaces dictionaries in which an `AbstractElement` is used as key value so that it is
possible to reset the `AbstractElement`

## Fields
- **`element::N`** is the instance of the element.
- **`value::T`** is the used value.
"""
struct ElementValue{T<:Union{TimeProfile, Real}}
    element::AbstractElement
    value::T
end

"""
    StorageValueCut

A `StorageValueCut` represents a cutting hyperplanes that puts an upper bound on
the value of the stored resource at the end of the optimization horizon.

## Fields
- **`id::Any`** is the name/identifier of the `StorageValueCut`.
- **`Vector{<:ElementValue}`** are the cut coefficients associated with the level of the
  given `Storage` nodes. They can also be provided as `Dict{<:Storage{<:Accumulating}, <:Real}`.
- **`rhs::Real`** is the cut right hand side constant.
"""
struct StorageValueCut
    id::Any
    coeffs::Vector{<:ElementValue}
    rhs::Real
end
function StorageValueCut(id, coeffs::Dict{<:Storage{<:Accumulating}, <:Real}, rhs::Real)
    ele_val_vect = [ElementValue(rsv, coeff) for (rsv, coeff) ∈ coeffs]
    return StorageValueCut(id, ele_val_vect, rhs)
end
Base.show(io::IO, svc::StorageValueCut) = print(io, "cut_$(svc.id)")

"""
    cut_rhs(svc::StorageValueCut)

Returns the cut right hand side constant.
"""
cut_rhs(svc::StorageValueCut) = svc.rhs

"""
    coefficients(svc::StorageValueCut)

Returns the cut coefficients associated with the level of the given `Storage` nodes.
"""
coefficients(svc::StorageValueCut) = [(eleval.element, eleval.value) for eleval ∈ svc.coeffs]

"""
    StorageValueCuts <: FutureValue

A collection of multiple `StorageValueCut` that constructs a piecewise linear upper
one the future value of the stored resource.

## Fields
- **`id::Any`** is the name/identifier of the `StorageValueCuts`.
- **`weight::Real`** is the weighting of the `StorageValueCuts` in the objective function.
  For example used if the end time of the optimization arrives between two different
  `StorageValueCuts`.
- **`time::Union{Int,Nothing}`** is the time where the cut is valid relative to the start
  of the operational period.
- **`cuts::Vector{StorageValueCut}`** is a vector of all the cuts that are included in the
  future value description.
"""
struct StorageValueCuts <: FutureValue
    id::Any
    weight::Real
    time::Union{Int,Nothing}
    cuts::Vector{StorageValueCut}
end

"""
    weight(svcs::StorageValueCuts)

Returns the weight of the storage value cuts `svcs`.
"""
weight(svcs::StorageValueCuts) = svcs.weight

"""
    cuts_time(svcs::StorageValueCuts)

Returns the time at which the storage value cuts `svcs` are valid relative to the total
horizon.
"""
cuts_time(svcs::StorageValueCuts) = svcs.time

"""
    cuts(svcs::StorageValueCuts)

Returns the different cuts of StorageValueCuts `svcs`
"""
cuts(svcs::StorageValueCuts) = svcs.cuts

"""
    get_active_cut_time_weights(𝒱::Vector{StorageValueCuts}, time::Int)

Get the time weights of the different cuts. If a cut is given at the end time of an
operational period, the weight is 1 for the given cut and 0 for other. When the
optimization end time is between cuts, the weights scales the weight of the nearest cuts
such that they are weighted linearly. The function returns a dictionary with the
involved cuts as keys and their weights as values.
"""
function get_active_cut_time_weights(𝒱::Vector{StorageValueCuts}, time::Real)
    cut_times = [cuts_time(v) for v ∈ 𝒱]
    time_diff = cut_times .- Int(time)
    time_zero = findall(x -> x == 0, time_diff)
    time_pos_arr = filter(x -> x > 0, time_diff)
    ret = Dict()
    if !isempty(time_zero)
        for i ∈ eachindex(𝒱)
            if i ∈ time_zero
                ret[𝒱[i]] = 1.0
            else
                ret[𝒱[i]] = 0
            end
        end
    elseif isempty(time_pos_arr)
        time_max = maximum(cut_times)
        max_elements = findall(x -> x == time_max, cut_times)
        for i ∈ eachindex(𝒱)
            if i ∈ max_elements
                ret[𝒱[i]] = 1.0
            else
                ret[𝒱[i]] = 0
            end
        end
    else
        time_pos = minimum(time_pos_arr)
        time_neg = maximum(filter(x -> x < 0, time_diff))
        pos_elements = findall(x -> x == time_pos, time_diff)
        neg_elements = findall(x -> x == time_neg, time_diff)
        for i ∈ eachindex(𝒱)
            if i ∈ pos_elements
                ret[𝒱[i]] = 1 - time_pos / (time_pos - time_neg)
            elseif i ∈ neg_elements
                ret[𝒱[i]] = 1 + time_neg / (time_pos - time_neg)
            else
                ret[𝒱[i]] = 0
            end
        end
    end
    return ret
end

"""
    has_cuts(v::FutureValue)
    has_cuts(v::StorageValueCuts)

Returns true if the `FutureValue` is of type `StorageValueCuts`.
"""
has_cuts(v::FutureValue) = false
has_cuts(v::StorageValueCuts) = true

"""
    get_future_value(case::Case)
    get_future_value(𝒳ᵛᵉᶜ::Vector{Vector})

Returns the vector of FutureValue of the Case `case` or the vector of elements vectors 𝒳ᵛᵉᶜ.
"""
get_future_value(case::Case) = filter(el -> isa(el, Vector{<:FutureValue}), get_elements_vec(case))[1]
get_future_value(𝒳ᵛᵉᶜ::Vector{Vector}) = filter(el -> isa(el, Vector{<:FutureValue}), 𝒳ᵛᵉᶜ)[1]

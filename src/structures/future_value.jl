"""
    abstract type  FutureValue <: AbstractElement

Declaration of the abstract type for future value descriptions in the optimization.
"""
abstract type  FutureValue <: AbstractElement end
Base.show(io::IO, v::FutureValue) = print(io, "fut_val_$(v.id)")

"""
    struct ElementValue{T<:Union{TimeProfile, Real}}

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
    struct StorageValueCut

A `StorageValueCut` represents a cutting hyperplane that puts an upper bound on
the value of the stored resource at the end of the optimization horizon.

## Fields
- **`id::Any`** is the name/identifier of the `StorageValueCut`.
- **`coeffs::Vector{<:ElementValue}`** are the cut coefficients associated with the level of the
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
    struct StorageValueCuts <: FutureValue

A collection of multiple `StorageValueCut` that constructs a piecewise linear upper bound
on the future value of the stored resource.

## Fields
- **`id::Any`** is the name/identifier of the `StorageValueCuts`.
- **`time::Int`** is the time where the cut is valid relative to the start of the operational
  period.
- **`weight::Real`** is the weighting of the `StorageValueCuts` in the objective function.
  For example used if the end time of the optimization arrives between two different
  `StorageValueCuts`.
- **`time_weight::Real`** is the weighting of the `StorageValueCuts` in the objective
  function due to the elapsed time.
- **`cuts::Vector{StorageValueCut}`** is a vector of all the cuts that are included in the
  future value description.
"""
struct StorageValueCuts <: FutureValue
    id::Any
    time::Int
    weight::Real
    time_weight::Union{Real, VariableRef}
    cuts::Vector{StorageValueCut}
end

"""
    weight(svcs::StorageValueCuts)

Returns the weight of the storage value cuts `svcs`.
"""
weight(svcs::StorageValueCuts) = svcs.weight

"""
    time_weight(svcs::StorageValueCuts)

Returns the time weight of the storage value cuts `svcs`.
"""
time_weight(svcs::StorageValueCuts) = svcs.time_weight

"""
    cuts_time(svcs::StorageValueCuts)

Returns the time at which the storage value cuts `svcs` are valid relative to the total
horizon.
"""
cuts_time(svcs::StorageValueCuts) = svcs.time

"""
    cuts(svcs::StorageValueCuts)

Returns the different cuts of StorageValueCuts `svcs`.
"""
cuts(svcs::StorageValueCuts) = svcs.cuts

has_init(v::FutureValue) = false

"""
    has_cuts(v::FutureValue)
    has_cuts(v::StorageValueCuts)

Returns true if the `FutureValue` is of type `StorageValueCuts`.
"""
has_cuts(v::FutureValue) = false
has_cuts(v::StorageValueCuts) = true

"""
    struct TypeFutureValue <: FutureValue
    TypeFutureValue(element_type::Type{<:AbstractElement}, key::Symbol, val::Real)

A future value for a given nodal type and model key. It utilizes only the final value and
directly adds it to the cost function for all instances of the given type.

## Fields
- **`element::Type{<:AbstractElement}`** is the nodal type for which the future value applies.
- **`val_dict::Dict{Symbol, Real}`** is a dictionary for including the variables provided as
  keys with a given value for calculating the future value. It is important to consider the
  unit of the value.

!!! info "Single variable"
    The field `val_dict` can also be provided as key and value input, if only a single variable
    should be restricted

!!! danger "Application of TypeFutureValue"
    `TypeFutureValue` assigns a future value to all instances of a given type. It should
    **never** be used on reference nodes. It should only be used on dynamic variables for other
    node types.
"""
struct TypeFutureValue <: FutureValue
    element_type::Type{<:AbstractElement}
    val_dict::Dict{Symbol, Real}
end
function TypeFutureValue(element_type::Type{<:AbstractElement}, key::Symbol, val::Real)
    return TypeFutureValue(element_type, Dict(key => val))
end

Base.show(io::IO, v::TypeFutureValue) = print(io, "fut_val_$(v.element_type)")
"""
    element_type(v::TypeFutureValue)

Returns the composite type who possesses a variable with a future value.
"""
element_type(v::TypeFutureValue) = v.element_type

"""
    coefficients(v::TypeFutureValue)

Returns the the cofficients dictionary of of the future value `v`.
"""
coefficients(v::TypeFutureValue) = v.val_dict

"""
    get_future_value(𝒳ᵛᵉᶜ::Vector{Vector})
    get_future_value(case::Case)
    get_future_value(𝒰::UpdateCase)

Returns the vector of FutureValue of the Case `case` or the vector of elements vectors `𝒳ᵛᵉᶜ`.

If the input is an [`UpdateCase`](@ref), it returns the **new** `FutureValues`s of the individual
[`FutureValueSub`](@ref) types of UpdateCase `𝒰`.
"""
get_future_value(𝒳ᵛᵉᶜ::Vector{Vector}) = filter(el -> isa(el, Vector{<:FutureValue}), 𝒳ᵛᵉᶜ)[1]
get_future_value(case::Case) = get_future_value(get_elements_vec(case))

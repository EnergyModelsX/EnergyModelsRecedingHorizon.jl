"""
    abstract type AbstractPath

Supertype for identification of the type which is resetted by a lens.
"""
abstract type AbstractPath end

"""
    abstract type AbstractInitDataPath <: AbstractPath

Supertype for identification of the [`AbstractPath`](@ref) types that are used for initial
data. If you create a new [`AbstractInitData`](@ref) type, you must also create a new
`AbstractInitDataPath` subtype
"""
abstract type AbstractInitDataPath <: AbstractPath end

"""
    struct OperPath <: AbstractPath

Internal type for paths pointing towards operational profiles.
"""
struct OperPath <: AbstractPath end

"""
    struct ElementPath <: AbstractPath

Internal type for paths pointing towards elements.
"""
struct ElementPath <: AbstractPath end

"""
    struct TimeWeightPath <: AbstractPath

Internal type for paths pointing towards the time weight of a future value.
"""
struct TimeWeightPath <: AbstractPath end

"""
    struct InitDataPath <: AbstractPath

Internal type for paths pointing towards [`InitData`](@ref).

# Fields
- **`key::Symbol`** is the key in the [`InitData`](@ref) (and correspondingly in the JuMP
  model).
"""
struct InitDataPath <: AbstractInitDataPath
    key::Symbol
end

"""
    model_key(idp::InitDataPath)

Returns the model key (field `key`) of InitDataPath `idp`.
"""
model_key(idp::InitDataPath) = idp.key

"""
    abstract type AbstractReset

Supertype for for types resetting values in fields in the individual
[`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s. The individual subtype is
related to the chosen [`AbstractPath`](@ref) as outlined above.

!!! note "New subtypes"
    We currently reset types for elements (*e.g.*, nodes, links, areas, or transmission),
    operational profiles, and initial data. The individual types are automatically deduced
    through the constructor [`ResetType`](@ref).

    If you require resetting different fields than the provided, you must include a new
    [`AbstractPath`](@ref) subtype, a new mutable composite type as subtype of `AbstractReset`,
    and a new method for the the constructor [`ResetType`](@ref) are required.
"""
abstract type AbstractReset end

"""
    mutable struct ElementReset <: AbstractReset

[`AbstractReset`](@ref) for resetting elements within another. The inner constructor is
utilized for automatically creating the lens to the field path.

# Inner constructor arguments
- **`field_path::Vector`** is the path towards the field as identified through the function
  [`_find_update_paths`](@ref).
- **`x`** is the instance of a type for which the reset type is created.

# Fields
- **`lens::Union{PropertyLens,ComposedFunction}`** is the lens for resetting the field.
- **`val::AbstractElement`** is the element in the field of the original type. It is used
  for identifying the linked `AbstractElement` after it is reset.
"""
mutable struct ElementReset <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    val::AbstractElement
    function ElementReset(field_path::Vector, x)
        lens = _create_lens_for_field(field_path)
        val = lens(x)
        new(lens, val)
    end
end

"""
    mutable struct OperReset <: AbstractReset

[`AbstractReset`](@ref) for resetting operational profiles within an element. The inner
constructor is utilized for automatically creating the lens to the field path.

# Inner constructor arguments
- **`field_path::Vector`** is the path towards the field as identified through the function
  [`_find_update_paths`](@ref).
- **`x`** is the instance of a type for which the reset type is created.

# Fields
- **`lens::Union{PropertyLens,ComposedFunction}`** is the lens for resetting the field.
- **`var`** is the variable when using `ParametricOptInterface`.
- **`val::OperationalProfile`** is the complete operational profile from the original
  element. The individual values are extracted from this profile in the receding horizon
  framework.
"""
mutable struct OperReset <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    var
    val::OperationalProfile
    function OperReset(field_path::Vector, x)
        lens = _create_lens_for_field(field_path)
        val = lens(x)
        new(lens, nothing, val)
    end
end

"""
    mutable struct TimeWeightReset <: AbstractReset

[`AbstractReset`](@ref) for resetting the time weight used in future value calculations.

# Inner constructor arguments
- **`field_path::Vector`** is the path towards the field as identified through the function
  [`_find_update_paths`](@ref).
- **`x`** is the instance of a type for which the reset type is created.

# Fields
- **`lens::Union{PropertyLens,ComposedFunction}`** is the lens for resetting the field.
- **`var`** is the variable when using `ParametricOptInterface`.
- **`val`** is the initial data value that should be used in the analyses
"""
mutable struct TimeWeightReset <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    var
    val
    function TimeWeightReset(field_path::Vector, x)
        lens = _create_lens_for_field(field_path)
        val = lens(x)
        new(lens, nothing, val)
    end
end

"""
    mutable struct InitReset{T} <: AbstractReset where {T<:AbstractInitDataPath}

[`AbstractReset`](@ref) for resetting initial data of an element. The inner constructor is
utilized for automatically creating the lens to the field path.

# Inner constructor arguments
- **`field_path::Vector`** is the path towards the field as identified through the function
  [`_find_update_paths`](@ref).
- **`path::AbstractInitDataPath`** is the [`AbstractPath`](@ref) of the init data. It
  includes additional information that is utilized when resetting an element.
- **`x`** is the instance of a type for which the reset type is created.

# Fields
- **`lens::Union{PropertyLens,ComposedFunction}`** is the lens for resetting the field.
- **`path::AbstractInitDataPath`** is the [`AbstractPath`](@ref) of the init data. It
  includes additional information that is utilized when resetting an element.
- **`var`** is the variable when using `ParametricOptInterface`.
- **`val`** is the initial data value that should be used in the analyses
"""
mutable struct InitReset{T} <: AbstractReset where {T<:AbstractInitDataPath}
    lens::Union{PropertyLens,ComposedFunction}
    path::T
    var
    val
    function InitReset(field_path::Vector, path::T, x) where {T<:AbstractInitDataPath}
        lens = _create_lens_for_field(field_path)
        val = lens(x)
        new{T}(lens, path, nothing, val)
    end
end

"""
    ResetType(field_path::Vector, _::OperPath, x)
    ResetType(field_path::Vector, _::ElementPath, x)
    ResetType(field_path::Vector, _::TimeWeightPath, x)
    ResetType(field_path::Vector, path::AbstractInitDataPath, x)

Constructor for [`AbstractReset`](@ref) types depending on their specified [`AbstractPath`](@ref).

!!! note "New types"
    If you create a new [`AbstractReset`](@ref) type (due to the creation of a new
    [`AbstractPath`] type), you must also create a new method for this function.

    This is **not** necessary for a new subtype of [`AbstractInitDataPath`](@ref).
"""
ResetType(field_path::Vector, _::OperPath, x) = OperReset(field_path, x)
ResetType(field_path::Vector, _::ElementPath, x) = ElementReset(field_path, x)
ResetType(field_path::Vector, _::TimeWeightPath, x) = TimeWeightReset(field_path, x)
ResetType(field_path::Vector, path::AbstractInitDataPath, x) =
    InitReset(field_path, path, x)

"""
    is_init_reset(rt::AbstractReset)

Function fo identifying whether the AbstractReset `rt` is of type `InitReset`.
"""
is_init_reset(rt::AbstractReset) = false
is_init_reset(rt::InitReset) = true

"""
    abstract type AbstractSub

Supertype for the creation of *Substitution* types.

*Substitution* types are used for simpler identification of the structures for substitutions.

!!! note "New elements"
    If you include a new element, you **must** introduce a new `AbstractSub` type for the
    element.
"""
abstract type AbstractSub end

"""
    mutable struct ModelSub{T<:RecHorEnergyModel} <: AbstractSub

[`AbstractSub`](@ref) for [`RecHorEnergyModel`](@ref).

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
  [`RecHorEnergyModel`](@ref).
"""
mutable struct ModelSub{T<:RecHorEnergyModel} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

"""
    mutable struct ProductSub{T<:Resource} <: AbstractSub

[`AbstractSub`](@ref) for [`Resource`](@extref EnergyModelsBase.Resource)s.

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
  [`Resource`](@extref EnergyModelsBase.Resource).
"""
mutable struct ProductSub{T<:Resource} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

"""
    mutable struct NodeSub{T<:EMB.Node} <: AbstractSub

[`AbstractSub`](@ref) for [`Node`](@extref EnergyModelsBase.Node)s.

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
  [`Node`](@extref EnergyModelsBase.Node).
"""
mutable struct NodeSub{T<:EMB.Node} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

"""
    mutable struct LinkSub{T<:Link} <: AbstractSub

[`AbstractSub`](@ref) for [`Link`](@extref EnergyModelsBase.Link)s.

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
  [`Link`](@extref EnergyModelsBase.Link).
"""
mutable struct LinkSub{T<:Link} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

"""
    mutable struct FutureValueSub{T<:FutureValue} <: AbstractSub

[`AbstractSub`](@ref) for [`FutureValue`](@ref)s.

# Fields
- **`new::T`** is the new type after resetting its values
- **`org::T`** is the original type before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref)(@ref) types for the given
  [`FutureValue`](@ref).
"""
mutable struct FutureValueSub{T<:FutureValue} <: AbstractSub
    new::T
    org::T
    resets::Vector{<:AbstractReset}
end

"""
    Substitution(x::T, resets::Vector{<:AbstractReset}) where {T}
    Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:Resource}
    Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:RecHorEnergyModel}
    Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:AbstractElement}

Constructor for [`AbstractSub`](@ref) types depending on the specified type of the input.
"""
Substitution(x::T, resets::Vector{<:AbstractReset}) where {T} = Substitution(x, x, resets)
Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:Resource} =
    ProductSub(new, org, resets)
Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:RecHorEnergyModel} =
    ModelSub(new, org, resets)
Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:AbstractElement} =
    _ele_to_sub(T)(new, org, resets)

"""
    resets(s::AbstractSub)

Returns the `Vector{AbstractReset}` of the AbstractSub `s`.
"""
resets(s::AbstractSub) = s.resets

"""
    _ele_to_sub(::Type{<:EMB.Node})
    _ele_to_sub(::Type{<:Link})
    _ele_to_sub(::Type{<:FutureValue})

Returns the subtype of [`AbstractSub`](@ref) for a given element.

!!! note "New elements"
    If you include a new element, you **must** introduce a new method for this function.
"""
_ele_to_sub(::Type{<:EMB.Node}) = NodeSub
_ele_to_sub(::Type{<:Link}) = LinkSub
_ele_to_sub(::Type{<:FutureValue}) = FutureValueSub

has_init(s::AbstractSub) = has_init(s.org)
has_init(𝒮::Vector{<:AbstractSub}) = any(has_init(s) for s ∈ 𝒮)

has_resets(s::AbstractSub) = !isempty(resets(s))

"""
    mutable struct UpdateCase <: AbstractCase

Type including all information required for updating the individual fields of the elements
in a receding horizon model.

This type follows in general the same structure as the [`Case`](@extref EnergyModelsBase.Case)
type introduced in `EnergyModelsBase` in which the individual vectors of `Resource`s or
`AbstractElement`s are replaced with the corresponding vectors of [`AbstractSub`].

# Fields
- **`model::ModelSub`** is the substitution type for the [`RecHorEnergyModel`](@ref).
- **`opers::Dict`** is a dictionary for mapping the operational periods of the receding
  horizon problem to the operational periods of the full problem.
- **`products::Vector{<:ProductSub}`** is a vector of substitution types for the individual
  [`Resource`](@extref EnergyModelsBase.Resource)s.
- **`elements::elements::Vector{Vector}`** is a vector of vectors of substitution types for
  the individual [`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s.
"""
mutable struct UpdateCase <: AbstractCase
    model::ModelSub
    opers::Dict
    products::Vector{<:ProductSub}
    elements::Vector{Vector}
end


"""
    get_sub_model(𝒰::UpdateCase)

Returns the [`ModelSub`](@ref) type of UpdateCase `𝒰`.
"""
get_sub_model(𝒰::UpdateCase) = 𝒰.model
"""
    get_sub_periods(𝒰::UpdateCase)

Returns the periods mapping dictionary of UpdateCase `𝒰`.
"""
get_sub_periods(𝒰::UpdateCase) = 𝒰.opers
"""
    get_sub_products(𝒰::UpdateCase)

Returns the products `Vector` of UpdateCase `𝒰`.
"""
get_sub_products(𝒰::UpdateCase) = 𝒰.products
"""
    get_sub_elements_vec(𝒰::UpdateCase)

Returns the elements `Vector{Vector}` of UpdateCase `𝒰`.
"""
get_sub_elements_vec(𝒰::UpdateCase) = 𝒰.elements

"""
    get_sub_ele(𝒮ᵛᵉᶜ::Vector{Vector}, x::Type{<:AbstractElement})
    get_sub_ele(𝒰::UpdateCase, x::Type{<:AbstractElement})

Returns the `Vector` of [`AbstractSub`](@ref) corresponding to the type provided by `x`.

The function can be used both on an [`UpdateCase`](@ref) and the corresponding
`Vector{Vector}`.
"""
get_sub_ele(𝒮ᵛᵉᶜ::Vector{Vector}, x::Type{<:AbstractElement}) =
    filter(𝒮 -> typeof(𝒮) == Vector{_ele_to_sub(x)}, 𝒮ᵛᵉᶜ)[1]
get_sub_ele(𝒰::UpdateCase, x::Type{<:AbstractElement}) = get_sub_ele(get_sub_elements_vec(𝒰), x)

"""
    get_products(𝒰::UpdateCase)

Method for the equivalent `EnergyModelsBase` function to extract the **new** `Resource`s of
the individual [`ProductSub`](@ref) types.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMB.get_products(𝒰::UpdateCase) = Resource[𝒮.new for 𝒮 ∈ get_sub_products(𝒰)]

"""
    get_elements_vec(𝒰::UpdateCase)

Method for the equivalent `EnergyModelsBase` function to extract the **new** vector of
element vectors `𝒳ᵛᵉᶜ` of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
function EMB.get_elements_vec(𝒰::UpdateCase)
    𝒳ᵛᵉᶜ = Vector[]
    for 𝒮 ∈ get_sub_elements_vec(𝒰)
        𝒳 = [updated(s) for s ∈ 𝒮]
        isempty(𝒳) || push!(𝒳ᵛᵉᶜ, 𝒳)
    end
    return 𝒳ᵛᵉᶜ
end

"""
    get_nodes(𝒰::UpdateCase)

Method for the equivalent `EnergyModelsBase` function to extract the **new** `Node`s of
the individual [`NodeSub`](@ref) types of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMB.get_nodes(𝒰::UpdateCase) = EMB.Node[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, EMB.Node)]
"""
    get_links(𝒰::UpdateCase)

Method for the equivalent `EnergyModelsBase` function to extract the **new** `Link`s of
the individual [`LinkSub`](@ref) types of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMB.get_links(𝒰::UpdateCase) = Link[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, EMB.Link)]

get_future_value(𝒰::UpdateCase) = FutureValue[s.new for s ∈ get_sub_ele(𝒰, FutureValue)]

"""
    updated(𝒰::UpdateCase, x_org::AbstractElement)
    updated(𝒰::UpdateCase, x_org::Resource)
    updated(𝒮::Vector{<:AbstractSub}, x_org::AbstractElement)
    updated(s::AbstractSub)

Returns the updated (resetted) type of the original type `x_org` for a given `UpdateCase`.
It is used for mapping and replacing instances of the type in fields.

If the input is an `AbstractSub`, it returns the value of the field `new`.
"""
updated(𝒰::UpdateCase, x_org::AbstractElement) =
    updated(get_sub_ele(𝒰, typeof(x_org)), x_org)
updated(𝒰::UpdateCase, x_org::Resource) =
    updated(filter(x -> original(x) == x_org, get_sub_products(𝒰))[1])
updated(𝒮::Vector{<:AbstractSub}, x_org::AbstractElement) =
    updated(filter(x -> original(x) == x_org, 𝒮)[1])
updated(s::AbstractSub) = s.new

"""
    original(𝒰::UpdateCase, x_new::AbstractElement)
    original(𝒰::UpdateCase, x_new::Resource)
    original(𝒰::UpdateCase, x_new::TS.TimePeriod)
    original(𝒮::Vector{<:AbstractSub}, x_new::AbstractElement)
    original(s::AbstractSub)

Returns the original type of the new (resetted) type `x_new` for a given `UpdateCase`.
It is used for results extraction.

If the input is an `AbstractSub`, it returns the value of the field `org`.
"""
original(𝒰::UpdateCase, x_new::AbstractElement) =
    original(get_sub_ele(𝒰, typeof(x_new)), x_new)
original(𝒮::Vector{<:AbstractSub}, x_new::AbstractElement) =
    original(filter(x -> updated(x) == x_new, 𝒮)[1])
original(𝒰::UpdateCase, x_new::Resource) =
    original(filter(x -> updated(x) == x_new, get_sub_products(𝒰))[1])
original(𝒰::UpdateCase, x_new::TS.TimePeriod) = get_sub_periods(𝒰)[x_new]
original(s::AbstractSub) = s.org

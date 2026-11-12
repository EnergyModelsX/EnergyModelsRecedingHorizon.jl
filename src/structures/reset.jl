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
    struct PartitionPath <: AbstractPath

Internal type for paths pointing towards partitioned profiles.
"""
struct PartitionPath <: AbstractPath end

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
    struct InitDataPath <: AbstractInitDataPath

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
    abstract type AbstractResetBehavior

Supertype for behaviors of resets, that is how the reset or if the reset should take place.
The behavior is only utilized for the `ParametricOptInterface` extension as some profiles
should never be substituted with a variable.
"""
abstract type AbstractResetBehavior end

"""
    struct StandResBehav <: AbstractResetBehavior

`AbstractResetBehavior` in which the reset should operate as standardized, *i.e.*, the
`AbstractReset` subtype will allow for the standard reset.
"""
struct StandResBehav <: AbstractResetBehavior end

"""
    struct NoResBehav <: AbstractResetBehavior

`AbstractResetBehavior` in which the reset should not occur in the `ParametricOptInterface`
extension.
"""
struct NoResBehav <: AbstractResetBehavior end

"""
    abstract type AbstractReset

Supertype for types resetting values in fields in the individual
[`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s. The individual subtype is
related to the chosen [`AbstractPath`](@ref) as outlined above.

!!! note "New subtypes"
    We currently have reset types for elements (*e.g.*, nodes, links, areas, or transmission),
    operational profiles, and initial data. The individual types are automatically deduced
    through the constructor [`ResetType`](@ref).

    If you require resetting different fields than the provided, you must include a new
    [`AbstractPath`](@ref) subtype, a new mutable composite type as subtype of `AbstractReset`,
    and a new method for the constructor [`ResetType`](@ref).
"""
abstract type AbstractReset end


"""
    struct EmptyReset <: AbstractReset

Empty reset type, introduced for fields not subject to resetting.
"""
struct EmptyReset <: AbstractReset end

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
- **`val::AbstractElement`** is the element in the field of the original instance. It is used
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
    mutable struct PartitionReset{AbstractResetBehavior} <: AbstractReset

[`AbstractReset`](@ref) for resetting partition profiles within an element. The inner
constructor is utilized for

- automatically creating the lens to the field path and
- to decide whether the reset behaviour is
  - [`StandResBehav`](@ref) for the standard behavior with reset or
  - [`NoResBehav`](@ref) if it is called for the profile representing the `period_duration`
    of the node.

This differentiation only affects the `ParametricOptInterface` extension. The core structure
will always apply the reset.

The duration of the partitions is provided by the deepest object on the field path with a
method for [`period_duration`](@ref), *e.g.*, an `ExtensionData` of an element. The search
stops at the index object of the JuMP variables (see [`_index_path`](@ref)).

# Inner constructor arguments
- **`field_path::Vector`** is the path towards the field as identified through the function
  [`_find_update_paths`](@ref).
- **`x`** is the instance of a type for which the reset type is created.

# Fields
- **`lens::Union{PropertyLens,ComposedFunction}`** is the lens for resetting the field.
- **`var`** is the variable when using `ParametricOptInterface`.
- **`val::PartitionProfile`** is the complete partition profile from the original
  element. The individual values are extracted from this profile in the receding horizon
  framework.
- **`pps::PartitionProfile`** is the partition profile corresponding to the duration of the
  individual partition periods.
- **`pps_lens`** is the lens from the element to the object providing the `period_duration`.
- **`idx_lens`** is the lens from the element to the object used as index of the JuMP
  variables over the partitions, *e.g.*, the element itself or a `TransmissionMode`.

!!! warning "PartitionReset"
    The `PartitionReset` type requires the user to declare a new method `period_duration`
    for the type `x` or a type on the field path which utilizes the concept of partitions.
    An error is provided if no method is declared.
"""
mutable struct PartitionReset{AbstractResetBehavior} <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    var
    val::PartitionProfile
    pps::PartitionProfile
    pps_lens::Union{typeof(identity),PropertyLens,ComposedFunction}
    idx_lens::Union{typeof(identity),PropertyLens,ComposedFunction}
    function PartitionReset(field_path::Vector, x)
        lens = _create_lens_for_field(field_path)
        val = lens(x)
        idx_path = _index_path(x, field_path)
        idx_lens = _create_prefix_lens(idx_path)
        pps_lens = _period_duration_lens(x, field_path, idx_path)
        pps = period_duration(pps_lens(x))
        if val ≠ pps
            new{StandResBehav}(lens, nothing, val, pps, pps_lens, idx_lens)
        else
            new{NoResBehav}(lens, nothing, val, pps, pps_lens, idx_lens)
        end
    end
end

"""
    _pps_lens(res_type::PartitionReset)
    _pps_lens(res_type::PartitionReset, x)

Returns the lens from the element to the object providing the `period_duration` of the
[`PartitionReset`](@ref) `res_type`. If the element `x` is provided, it returns the object
of `x` providing the `period_duration`.
"""
_pps_lens(res_type::PartitionReset) = res_type.pps_lens
_pps_lens(res_type::PartitionReset, x) = res_type.pps_lens(x)

"""
    _idx_lens(res_type::PartitionReset)
    _idx_lens(res_type::PartitionReset, x)

Returns the lens from the element to the index object of the JuMP variables over the
partitions of the [`PartitionReset`](@ref) `res_type`. If the element `x` is provided, it
returns the index object of `x`.
"""
_idx_lens(res_type::PartitionReset) = res_type.idx_lens
_idx_lens(res_type::PartitionReset, x) = res_type.idx_lens(x)

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
- **`val`** is the time weight that should be used in the analysis.
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
- **`val`** is the initial data value that should be used in the analysis.
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
    ResetType(field_path::Vector, _::PartitionPath, x)
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
ResetType(field_path::Vector, _::PartitionPath, x) = PartitionReset(field_path, x)
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
    period_duration(x)
    period_duration(res_type::PartitionReset, 𝒯::TS.TimeStructure)

Returns the duration of the period partitions of the element `x` or the period partitions of
the `PartitionReset` `res_type` for a given time structure `𝒯`.
"""
function period_duration(x)
    x_type = typeof(x)
    throw(
        ErrorException(
            "No method for `period_duration` is defined for $(x_type).\n" *
            "This error is caused by including a `PartitionProfile` in $(x_type) which " *
            "requires a method for the `EnergyModelsRecedingHorizon` function " *
            "`period_duration(x)` to be defined."
        )
    )
end
function period_duration(res_type::PartitionReset, 𝒯::TS.TimeStructure)
    return partition_duration(𝒯, res_type.pps)
end

"""
    _has_period_duration(x)

Returns `true` if a method of [`period_duration`](@ref) other than the fallback is declared
for the type of `x`.
"""
_has_period_duration(x) =
    which(period_duration, Tuple{typeof(x)}) !== which(period_duration, Tuple{Any})

"""
    _index_path(x, field_path::Vector)

Returns the path from the element `x` to the object which is used as index of the JuMP
variables over the partitions of the profile at `field_path`. The default is the element
itself (empty path).

Extensions with nested index objects, *e.g.*, `TransmissionMode`s, require a new method.
"""
_index_path(x, field_path::Vector) = Any[]

"""
    _create_prefix_lens(path::Vector)

Returns the lens for the (sub)path `path`. An empty path returns `identity`.
"""
_create_prefix_lens(path::Vector) = isempty(path) ? identity : _create_lens_for_field(path)

"""
    _period_duration_lens(x, field_path::Vector, idx_path::Vector)

Returns the lens from the element `x` to the deepest object on the path `field_path` with a
method for [`period_duration`](@ref). The search starts at the object holding the profile
and stops at the index object at `idx_path`.

Throws the error of the [`period_duration`](@ref) fallback if no such object exists.
"""
function _period_duration_lens(x, field_path::Vector, idx_path::Vector)
    # The last entry is the `AbstractPath` and the second to last the profile itself
    for k ∈ length(field_path)-2:-1:length(idx_path)
        lens = _create_prefix_lens(field_path[1:k])
        _has_period_duration(lens(x)) && return lens
    end

    # Throw the error of the fallback for the object holding the profile
    period_duration(_create_prefix_lens(field_path[1:end-2])(x))
end

"""
    _partitions_within(𝒯ᵖᵈ, opers::Vector{<:TS.TimePeriod})

Returns the period partitions in `𝒯ᵖᵈ` that are fully included in the operational periods
`opers`.
"""
_partitions_within(𝒯ᵖᵈ, opers::Vector{<:TS.TimePeriod}) =
    filter(t_pd -> isempty(setdiff(t_pd, opers)), 𝒯ᵖᵈ)

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
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
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
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
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
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
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
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
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
- **`new::T`** is the new instance after resetting its values.
- **`org::T`** is the original instance before resetting its values.
- **`resets::Vector{<:AbstractReset}`** are [`AbstractReset`](@ref) types for the given
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
    _partition_groups(s::AbstractSub)

Returns the [`PartitionReset`](@ref)s of the `AbstractSub` `s` grouped by the index object of
the JuMP variables over the partitions as `Vector{Vector{PartitionReset}}`.
"""
function _partition_groups(s::AbstractSub)
    x_org = original(s)
    groups = Vector{PartitionReset}[]
    for res_type ∈ resets(s)
        isa(res_type, PartitionReset) || continue
        x_idx = _idx_lens(res_type, x_org)
        k = findfirst(grp -> _idx_lens(first(grp), x_org) === x_idx, groups)
        isnothing(k) ? push!(groups, PartitionReset[res_type]) : push!(groups[k], res_type)
    end
    return groups
end

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
`AbstractElement`s are replaced with the corresponding vectors of [`AbstractSub`](@ref).

# Fields
- **`T::TS.TimeStructure`** is the time structure of the original problem.
- **`model::ModelSub`** is the substitution type for the [`RecHorEnergyModel`](@ref).
- **`map_org::Dict`** is a dictionary for mapping the types of the receding horizon problem
  to the types of the full problem.
- **`map_updated::Dict`** is a dictionary for mapping the types of the full problem to the
   types of the receding horizon problem.
- **`products::Vector{<:ProductSub}`** is a vector of substitution types for the individual
  [`Resource`](@extref EnergyModelsBase.Resource)s.
- **`elements::elements::Vector{Vector}`** is a vector of vectors of substitution types for
  the individual [`AbstractElement`](@extref EnergyModelsBase.AbstractElement)s.
"""
mutable struct UpdateCase <: AbstractCase
    T::TS.TimeStructure
    model::ModelSub
    map_org::Dict
    map_updated::Dict
    products::Vector{<:ProductSub}
    elements::Vector{Vector}
end


"""
    get_sub_model(𝒰::UpdateCase)

Returns the [`ModelSub`](@ref) type of UpdateCase `𝒰`.
"""
get_sub_model(𝒰::UpdateCase) = 𝒰.model
"""
    get_mapping_original(𝒰::UpdateCase, symb::Symbol)

Returns the mapping dictionary of UpdateCase `𝒰` from the receding horizon problem to the
full problem for the given `symb`.
"""
get_mapping_original(𝒰::UpdateCase, symb::Symbol) = 𝒰.map_org[symb]
"""
    get_mapping_updated(𝒰::UpdateCase, symb::Symbol)

Returns the mapping dictionary of UpdateCase `𝒰` from the full problem to the receding
horizon problem for the given `symb`.
"""
get_mapping_updated(𝒰::UpdateCase, symb::Symbol) = 𝒰.map_updated[symb]
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
    EMB.get_time_struct(𝒰::UpdateCase)

Method for the `EnergyModelsBase` function to extract the original time structure of the
update case
"""
EMB.get_time_struct(𝒰::UpdateCase) = 𝒰.T

"""
    EMB.get_products(𝒰::UpdateCase)

Method for the `EnergyModelsBase` function to extract the **new** `Resource`s of the
individual [`ProductSub`](@ref) types.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMB.get_products(𝒰::UpdateCase) = Resource[𝒮.new for 𝒮 ∈ get_sub_products(𝒰)]

"""
    EMB.get_elements_vec(𝒰::UpdateCase)

Method for the `EnergyModelsBase` function to extract the **new** vector of element vectors
`𝒳ᵛᵉᶜ` of UpdateCase `𝒰`.

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
    EMB.get_nodes(𝒰::UpdateCase)

Method for the `EnergyModelsBase` function to extract the **new** `Node`s of the individual
[`NodeSub`](@ref) types of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMB.get_nodes(𝒰::UpdateCase) = EMB.Node[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, EMB.Node)]

"""
    EMB.get_links(𝒰::UpdateCase)

Method for the `EnergyModelsBase` function to extract the **new** `Link`s of the individual
[`LinkSub`](@ref) types of UpdateCase `𝒰`.

This element vector can be directly utilized for the field elements of a
[`Case`](@extref EnergyModelsBase.Case).
"""
EMB.get_links(𝒰::UpdateCase) = Link[𝒮.new for 𝒮 ∈ get_sub_ele(𝒰, EMB.Link)]

get_future_value(𝒰::UpdateCase) = FutureValue[s.new for s ∈ get_sub_ele(𝒰, FutureValue)]

"""
    updated(𝒰::UpdateCase, x_org::T) where {T<:Union{TS.TimePeriod, Resource, AbstractElement}}
    updated(𝒰::UpdateCase, x_org::Integer)
    updated(𝒰::UpdateCase, x_org, x_ele)
    updated(𝒰::UpdateCase, t_pd_org::T, x_org) where {T<:TS.PeriodPartition}
    updated(𝒮::Vector{<:AbstractSub}, x_org::AbstractElement)
    updated(s::AbstractSub)

Returns the updated (resetted) instance of the original instance `x_org` for a given [`UpdateCase`](@ref).
It is used for mapping and replacing instances of the type in fields. Integers, *e.g.*,
used as index of a variable, are not changed.

If a third argument is provided, it returns the updated instance of the original instance
`x_org` through the two argument method, except for period partitions. The updated period
partition of the original period partition `t_pd_org` depends on the original instance
`x_org` in which the partition is used.

If the input is an `AbstractSub`, it returns the value of the field `new`.

!!! note "Period partitions"
    The mapping of period partitions is only available for partitions of elements that
    utilize a `PartitionProfile`, see [`_update_periods_mapping!`](@ref).
"""
updated(𝒰::UpdateCase, x_org::T) where {T<:Union{TS.TimePeriod, Resource, AbstractElement}} =
    get_mapping_updated(𝒰, _type_to_key(T))[x_org]
updated(::UpdateCase, x_org::Integer) = x_org
updated(𝒰::UpdateCase, x_org, _) = updated(𝒰, x_org)
updated(𝒰::UpdateCase, t_pd_org::T, x_org) where {T<:TS.PeriodPartition} =
    get_mapping_updated(𝒰, _type_to_key(T))[x_org][t_pd_org]
updated(𝒮::Vector{<:AbstractSub}, x_org::AbstractElement) =
    updated(filter(x -> original(x) == x_org, 𝒮)[1])
updated(s::AbstractSub) = s.new

"""
    original(𝒰::UpdateCase, x_new::T) where {T<:Union{TS.TimePeriod, Resource, AbstractElement}}
    original(𝒰::UpdateCase, x_new::Integer)
    original(𝒰::UpdateCase, x_new, x_ele)
    original(𝒰::UpdateCase, t_pd_new::T, x_new) where {T<:TS.PeriodPartition}
    original(𝒮::Vector{<:AbstractSub}, x_new::AbstractElement)
    original(s::AbstractSub)

Returns the original instance of the new (resetted) instance `x_new` for a given [`UpdateCase`](@ref).
It is used for results extraction. Integers, *e.g.*, used as index of a variable, are not
changed.

If a third argument is provided, it returns the original instance of the new instance
`x_new` through the two argument method, except for period partitions. The original period
partition of the new period partition `t_pd_new` depends on the new instance `x_new` in
which the partition is used.

If the input is an `AbstractSub`, it returns the value of the field `org`.

!!! note "Period partitions"
    The mapping of period partitions is only available for partitions of elements that
    utilize a `PartitionProfile`, see [`_update_periods_mapping!`](@ref).
"""
original(𝒰::UpdateCase, x_new::T) where {T<:Union{TS.TimePeriod, Resource, AbstractElement}} =
    get_mapping_original(𝒰, _type_to_key(T))[x_new]
original(::UpdateCase, x_new::Integer) = x_new
original(𝒰::UpdateCase, x_new, _) = original(𝒰, x_new)
original(𝒰::UpdateCase, t_pd_new::T, x_new) where {T<:TS.PeriodPartition} =
    get_mapping_original(𝒰, _type_to_key(T))[x_new][t_pd_new]
original(𝒮::Vector{<:AbstractSub}, x_new::AbstractElement) =
    original(filter(x -> updated(x) == x_new, 𝒮)[1])
original(s::AbstractSub) = s.org
